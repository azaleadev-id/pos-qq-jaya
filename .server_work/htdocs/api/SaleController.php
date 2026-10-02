<?php

declare(strict_types=1);

final class SaleController
{
    public static function index(): never
    {
        $from = self::queryDate($_GET['from'] ?? null, false);
        $to = self::queryDate($_GET['to'] ?? null, true);
        $paymentMethod = trim((string) ($_GET['payment_method'] ?? ''));
        $sql = 'SELECT s.*,
                       (SELECT COUNT(*) FROM sale_items si
                        WHERE si.sale_id = s.id AND si.deleted_at IS NULL) AS item_count,
                       (SELECT GROUP_CONCAT(si.product_name ORDER BY si.created_at ASC SEPARATOR ", ")
                        FROM sale_items si
                        WHERE si.sale_id = s.id AND si.deleted_at IS NULL) AS item_names,
                       (SELECT GROUP_CONCAT(DISTINCT COALESCE(p.category, "") ORDER BY p.category ASC SEPARATOR ", ")
                        FROM sale_items si
                        LEFT JOIN products p ON p.id = si.product_id
                        WHERE si.sale_id = s.id AND si.deleted_at IS NULL) AS item_categories
                FROM sales s WHERE s.deleted_at IS NULL';
        $params = [];

        if ($from !== null) {
            $sql .= ' AND s.sold_at >= :date_from';
            $params['date_from'] = $from;
        }
        if ($to !== null) {
            $sql .= ' AND s.sold_at <= :date_to';
            $params['date_to'] = $to;
        }
        if ($paymentMethod !== '') {
            if (!in_array($paymentMethod, ['cash', 'transfer', 'qris'], true)) {
                Response::error('Metode pembayaran tidak valid.', 422);
            }
            $sql .= ' AND s.payment_method = :payment_method';
            $params['payment_method'] = $paymentMethod;
        }

        $sql .= ' ORDER BY s.sold_at DESC, s.created_at DESC LIMIT 500';
        $statement = Database::connection()->prepare($sql);
        $statement->execute($params);
        Response::success(['sales' => $statement->fetchAll()]);
    }

    public static function show(string $id): never
    {
        Response::success(self::detail($id));
    }

    public static function store(): never
    {
        $data = Request::json();
        self::validate($data);
        $pdo = Database::connection();
        $hasClientId = isset($data['id']) && Uuid::valid((string) $data['id']);
        $id = $hasClientId ? (string) $data['id'] : Uuid::v4();

        if ($hasClientId && self::saleExists($pdo, $id)) {
            Response::success(self::detail($id), 'Transaksi penjualan sudah tersimpan.');
        }

        try {
            $pdo->beginTransaction();
            self::writeSale($pdo, $id, $data, false);
            $pdo->commit();
            Response::success(self::detail($id), 'Transaksi penjualan berhasil disimpan.', 201);
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            if ($hasClientId && $exception instanceof PDOException && (string) $exception->getCode() === '23000' && self::saleExists($pdo, $id)) {
                Response::success(self::detail($id), 'Transaksi penjualan sudah tersimpan.');
            }
            self::handleException($exception);
        }
    }

    public static function update(string $id): never
    {
        if (!Uuid::valid($id)) {
            Response::error('ID transaksi tidak valid.', 422);
        }
        $data = Request::json();
        self::validate($data);
        $pdo = Database::connection();

        try {
            $pdo->beginTransaction();
            $currentSale = self::lockSale($pdo, $id);
            if (trim((string) ($data['transaction_number'] ?? '')) === '') {
                $data['transaction_number'] = $currentSale['transaction_number'];
            }
            self::restoreStock($pdo, $id, 'Penjualan diedit');
            $now = gmdate('Y-m-d H:i:s');
            $statement = $pdo->prepare(
                'UPDATE sale_items SET deleted_at = :deleted_at, updated_at = :updated_at
                 WHERE sale_id = :sale_id AND deleted_at IS NULL'
            );
            $statement->execute(['deleted_at' => $now, 'updated_at' => $now, 'sale_id' => $id]);
            self::writeSale($pdo, $id, $data, true);
            $pdo->commit();
            Response::success(self::detail($id), 'Transaksi penjualan berhasil diperbarui.');
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            self::handleException($exception);
        }
    }

    public static function destroy(string $id): never
    {
        if (!Uuid::valid($id)) {
            Response::error('ID transaksi tidak valid.', 422);
        }
        $pdo = Database::connection();

        try {
            $pdo->beginTransaction();
            self::lockSale($pdo, $id);
            self::restoreStock($pdo, $id, 'Penjualan dibatalkan');
            $now = gmdate('Y-m-d H:i:s');
            $statement = $pdo->prepare(
                'UPDATE sales SET deleted_at = :deleted_at, updated_at = :updated_at
                 WHERE id = :id AND deleted_at IS NULL'
            );
            $statement->execute(['deleted_at' => $now, 'updated_at' => $now, 'id' => $id]);
            $statement = $pdo->prepare(
                'UPDATE sale_items SET deleted_at = :deleted_at, updated_at = :updated_at
                 WHERE sale_id = :sale_id AND deleted_at IS NULL'
            );
            $statement->execute(['deleted_at' => $now, 'updated_at' => $now, 'sale_id' => $id]);
            $pdo->commit();
            Response::success([], 'Transaksi dibatalkan dan stok telah dikembalikan.');
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            self::handleException($exception);
        }
    }

    private static function writeSale(PDO $pdo, string $id, array $data, bool $updating): void
    {
        $now = self::date($data['updated_at'] ?? null);
        $soldAt = self::date($data['sold_at'] ?? $now);
        $items = [];
        $subtotal = 0.0;
        $totalCost = 0.0;

        foreach ($data['items'] as $position => $input) {
            $productId = trim((string) ($input['product_id'] ?? ''));
            $quantity = (int) $input['quantity'];
            $product = null;

            if ($productId !== '') {
                $statement = $pdo->prepare(
                    'SELECT id, name, cost_price, selling_price, track_stock, stock_quantity
                     FROM products
                     WHERE id = :id AND deleted_at IS NULL AND is_active = 1
                     LIMIT 1 FOR UPDATE'
                );
                $statement->execute(['id' => $productId]);
                $product = $statement->fetch();
                if (!$product) {
                    throw new DomainException('Produk pada item ke-' . ($position + 1) . ' tidak ditemukan atau tidak aktif.');
                }
            }

            $unitPrice = isset($input['unit_price']) && is_numeric($input['unit_price'])
                ? (float) $input['unit_price']
                : (float) ($product['selling_price'] ?? 0);
            if ($unitPrice < 0) {
                throw new DomainException('Harga jual tidak boleh negatif.');
            }
            $unitCost = $product !== null
                ? (float) $product['cost_price']
                : (float) ($input['unit_cost'] ?? 0);
            if ($unitCost < 0) {
                throw new DomainException('Harga modal tidak boleh negatif.');
            }
            $lineTotal = $quantity * $unitPrice;
            $lineCost = $quantity * $unitCost;
            $subtotal += $lineTotal;
            $totalCost += $lineCost;

            if ($product !== null && (int) $product['track_stock'] === 1) {
                $before = (int) $product['stock_quantity'];
                if ($before < $quantity) {
                    throw new DomainException('Stok ' . $product['name'] . ' tidak cukup. Tersedia ' . $before . '.');
                }
                $after = $before - $quantity;
                $update = $pdo->prepare(
                    'UPDATE products SET stock_quantity = :stock, updated_at = :updated_at WHERE id = :id'
                );
                $update->execute(['stock' => $after, 'updated_at' => $now, 'id' => $productId]);
                self::stockMovement($pdo, $productId, -$quantity, $before, $after, $unitCost, $id, 'Penjualan ' . $id, $soldAt, $now);
            }

            $items[] = [
                'id' => isset($input['id']) && Uuid::valid((string) $input['id']) ? (string) $input['id'] : Uuid::v4(),
                'product_id' => $product !== null ? $productId : null,
                'product_name' => $product !== null ? (string) $product['name'] : trim((string) ($input['product_name'] ?? '')),
                'quantity' => $quantity,
                'unit_cost' => $unitCost,
                'unit_price' => $unitPrice,
                'line_cost' => $lineCost,
                'line_total' => $lineTotal,
                'line_profit' => $lineTotal - $lineCost,
            ];
        }

        $total = $subtotal;
        $paid = (float) $data['paid_amount'];
        if ($paid < $total) {
            throw new DomainException('Pembayaran kurang. Aplikasi tidak menerima hutang.');
        }
        $change = $paid - $total;
        $transactionNumber = trim((string) ($data['transaction_number'] ?? ''));
        if ($transactionNumber === '') {
            $transactionNumber = self::transactionNumber();
        }

        if ($updating) {
            $statement = $pdo->prepare(
                'UPDATE sales SET transaction_number = :transaction_number, subtotal = :subtotal,
                 total_amount = :total_amount, total_cost = :total_cost, total_profit = :total_profit,
                 payment_method = :payment_method, paid_amount = :paid_amount, change_amount = :change_amount,
                 notes = :notes, sold_at = :sold_at, updated_at = :updated_at
                 WHERE id = :id AND deleted_at IS NULL'
            );
        } else {
            $statement = $pdo->prepare(
                'INSERT INTO sales
                 (id, transaction_number, subtotal, total_amount, total_cost, total_profit,
                  payment_method, paid_amount, change_amount, notes, sold_at, created_at, updated_at)
                 VALUES
                 (:id, :transaction_number, :subtotal, :total_amount, :total_cost, :total_profit,
                  :payment_method, :paid_amount, :change_amount, :notes, :sold_at, :created_at, :updated_at)'
            );
        }
        $params = [
            'id' => $id,
            'transaction_number' => $transactionNumber,
            'subtotal' => $subtotal,
            'total_amount' => $total,
            'total_cost' => $totalCost,
            'total_profit' => $total - $totalCost,
            'payment_method' => $data['payment_method'],
            'paid_amount' => $paid,
            'change_amount' => $change,
            'notes' => self::nullable($data['notes'] ?? null),
            'sold_at' => $soldAt,
            'updated_at' => $now,
        ];
        if (!$updating) {
            $params['created_at'] = self::date($data['created_at'] ?? $now);
        }
        $statement->execute($params);

        $insert = $pdo->prepare(
            'INSERT INTO sale_items
             (id, sale_id, product_id, product_name, quantity, unit_cost, unit_price,
              line_cost, line_total, line_profit, created_at, updated_at)
             VALUES
             (:id, :sale_id, :product_id, :product_name, :quantity, :unit_cost, :unit_price,
              :line_cost, :line_total, :line_profit, :created_at, :updated_at)'
        );
        foreach ($items as $item) {
            $insert->execute($item + ['sale_id' => $id, 'created_at' => $now, 'updated_at' => $now]);
        }
    }

    private static function saleExists(PDO $pdo, string $id): bool
    {
        $statement = $pdo->prepare('SELECT 1 FROM sales WHERE id = :id AND deleted_at IS NULL LIMIT 1');
        $statement->execute(['id' => $id]);
        return (bool) $statement->fetchColumn();
    }

    private static function restoreStock(PDO $pdo, string $saleId, string $notes): void
    {
        $statement = $pdo->prepare(
            'SELECT product_id, quantity, unit_cost FROM sale_items
             WHERE sale_id = :sale_id AND deleted_at IS NULL AND product_id IS NOT NULL'
        );
        $statement->execute(['sale_id' => $saleId]);
        $now = gmdate('Y-m-d H:i:s');

        foreach ($statement->fetchAll() as $item) {
            $lock = $pdo->prepare(
                'SELECT id, track_stock, stock_quantity FROM products WHERE id = :id LIMIT 1 FOR UPDATE'
            );
            $lock->execute(['id' => $item['product_id']]);
            $product = $lock->fetch();
            if (!$product || (int) $product['track_stock'] !== 1) {
                continue;
            }
            $before = (int) $product['stock_quantity'];
            $quantity = (int) $item['quantity'];
            $after = $before + $quantity;
            $update = $pdo->prepare('UPDATE products SET stock_quantity = :stock, updated_at = :now WHERE id = :id');
            $update->execute(['stock' => $after, 'now' => $now, 'id' => $item['product_id']]);
            self::stockMovement($pdo, $item['product_id'], $quantity, $before, $after, (float) $item['unit_cost'], $saleId, $notes, $now, $now, 'correction');
        }
    }

    private static function stockMovement(
        PDO $pdo,
        string $productId,
        int $change,
        int $before,
        int $after,
        float $cost,
        string $saleId,
        string $notes,
        string $occurredAt,
        string $now,
        string $type = 'sale'
    ): void {
        $statement = $pdo->prepare(
            'INSERT INTO stock_movements
             (id, product_id, movement_type, quantity_change, quantity_before, quantity_after,
              latest_cost_price, reference_type, reference_id, notes, occurred_at, created_at, updated_at)
             VALUES
             (:id, :product_id, :movement_type, :quantity_change, :quantity_before, :quantity_after,
              :latest_cost_price, :reference_type, :reference_id, :notes, :occurred_at, :created_at, :updated_at)'
        );
        $statement->execute([
            'id' => Uuid::v4(), 'product_id' => $productId, 'movement_type' => $type,
            'quantity_change' => $change, 'quantity_before' => $before, 'quantity_after' => $after,
            'latest_cost_price' => $cost, 'reference_type' => 'sale', 'reference_id' => $saleId,
            'notes' => $notes, 'occurred_at' => $occurredAt, 'created_at' => $now, 'updated_at' => $now,
        ]);
    }

    private static function detail(string $id): array
    {
        if (!Uuid::valid($id)) {
            Response::error('ID transaksi tidak valid.', 422);
        }
        $statement = Database::connection()->prepare('SELECT * FROM sales WHERE id = :id AND deleted_at IS NULL LIMIT 1');
        $statement->execute(['id' => $id]);
        $sale = $statement->fetch();
        if (!$sale) {
            Response::error('Transaksi penjualan tidak ditemukan.', 404);
        }
        $statement = Database::connection()->prepare(
            'SELECT si.*, p.category AS product_category
             FROM sale_items si
             LEFT JOIN products p ON p.id = si.product_id
             WHERE si.sale_id = :sale_id AND si.deleted_at IS NULL
             ORDER BY si.created_at ASC'
        );
        $statement->execute(['sale_id' => $id]);
        return ['sale' => $sale, 'items' => $statement->fetchAll()];
    }

    private static function lockSale(PDO $pdo, string $id): array
    {
        $statement = $pdo->prepare('SELECT * FROM sales WHERE id = :id AND deleted_at IS NULL LIMIT 1 FOR UPDATE');
        $statement->execute(['id' => $id]);
        $sale = $statement->fetch();
        if (!$sale) {
            throw new DomainException('Transaksi penjualan tidak ditemukan.');
        }
        return $sale;
    }

    private static function validate(array $data): void
    {
        $errors = [];
        if (!isset($data['items']) || !is_array($data['items']) || $data['items'] === []) {
            $errors['items'] = 'Minimal satu produk wajib dipilih.';
        } else {
            foreach ($data['items'] as $index => $item) {
                if (!is_array($item)) {
                    $errors['items.' . $index] = 'Item penjualan tidak valid.';
                    continue;
                }
                $productId = trim((string) ($item['product_id'] ?? ''));
                if ($productId !== '' && !Uuid::valid($productId)) {
                    $errors['items.' . $index . '.product_id'] = 'ID produk tidak valid.';
                }
                if ($productId === '') {
                    if (trim((string) ($item['product_name'] ?? '')) === '') {
                        $errors['items.' . $index . '.product_name'] = 'Nama barang manual wajib diisi.';
                    }
                    if (!isset($item['unit_cost']) || !is_numeric($item['unit_cost']) || (float) $item['unit_cost'] < 0) {
                        $errors['items.' . $index . '.unit_cost'] = 'Harga modal tidak valid.';
                    }
                }
                if (!isset($item['quantity']) || filter_var($item['quantity'], FILTER_VALIDATE_INT) === false || (int) $item['quantity'] <= 0) {
                    $errors['items.' . $index . '.quantity'] = 'Jumlah harus berupa bilangan lebih dari nol.';
                }
                if (!isset($item['unit_price']) || !is_numeric($item['unit_price']) || (float) $item['unit_price'] < 0) {
                    $errors['items.' . $index . '.unit_price'] = 'Harga jual tidak valid.';
                }
            }
        }
        if (!in_array((string) ($data['payment_method'] ?? ''), ['cash', 'transfer', 'qris'], true)) {
            $errors['payment_method'] = 'Metode pembayaran harus cash, transfer, atau qris.';
        }
        if (!isset($data['paid_amount']) || !is_numeric($data['paid_amount']) || (float) $data['paid_amount'] < 0) {
            $errors['paid_amount'] = 'Jumlah pembayaran tidak valid.';
        }
        if (isset($data['id']) && !Uuid::valid((string) $data['id'])) {
            $errors['id'] = 'ID transaksi harus menggunakan UUID.';
        }
        if ($errors !== []) {
            Response::error('Data penjualan belum valid.', 422, $errors);
        }
    }

    private static function transactionNumber(): string
    {
        return 'PJ-' . gmdate('Ymd-His') . '-' . strtoupper(substr(str_replace('-', '', Uuid::v4()), 0, 5));
    }

    private static function queryDate(mixed $value, bool $end): ?string
    {
        $value = trim((string) ($value ?? ''));
        if ($value === '') {
            return null;
        }
        $time = strtotime($value);
        if ($time === false) {
            Response::error('Filter tanggal tidak valid.', 422);
        }
        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $value) === 1) {
            return gmdate('Y-m-d', $time) . ($end ? ' 23:59:59' : ' 00:00:00');
        }
        return gmdate('Y-m-d H:i:s', $time);
    }

    private static function nullable(mixed $value): ?string
    {
        $value = trim((string) ($value ?? ''));
        return $value === '' ? null : $value;
    }

    private static function date(mixed $value): string
    {
        if (is_string($value) && preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/', $value) === 1) {
            return $value;
        }
        if (is_string($value) && strtotime($value) !== false) {
            return gmdate('Y-m-d H:i:s', strtotime($value));
        }
        return gmdate('Y-m-d H:i:s');
    }

    private static function handleException(Throwable $exception): never
    {
        if ($exception instanceof DomainException) {
            Response::error($exception->getMessage(), 422);
        }
        if ($exception instanceof PDOException && (string) $exception->getCode() === '23000') {
            Response::error('ID item atau nomor transaksi sudah digunakan.', 409);
        }
        throw $exception;
    }
}
