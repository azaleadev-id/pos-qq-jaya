<?php

declare(strict_types=1);

final class ProductController
{
    public static function index(): never
    {
        $pdo = Database::connection();
        $search = trim((string) ($_GET['search'] ?? ''));
        $active = $_GET['active'] ?? null;

        $sql = 'SELECT *, (selling_price - cost_price) AS profit_per_unit
                FROM products
                WHERE deleted_at IS NULL';
        $params = [];

        if ($search !== '') {
            $sql .= ' AND (name LIKE :search OR category LIKE :search OR barcode LIKE :search OR qr_code LIKE :search)';
            $params['search'] = '%' . $search . '%';
        }

        if ($active !== null && in_array((string) $active, ['0', '1'], true)) {
            $sql .= ' AND is_active = :active';
            $params['active'] = (int) $active;
        }

        $sql .= ' ORDER BY name ASC LIMIT 500';
        $statement = $pdo->prepare($sql);
        $statement->execute($params);

        Response::success(['products' => $statement->fetchAll()]);
    }

    public static function show(string $id): never
    {
        $product = self::find($id);
        Response::success(['product' => $product]);
    }

    public static function store(): never
    {
        $data = Request::json();
        $errors = self::validate($data, true);

        if ($errors !== []) {
            Response::error('Data produk belum valid.', 422, $errors);
        }

        $pdo = Database::connection();
        $id = isset($data['id']) && Uuid::valid((string) $data['id'])
            ? (string) $data['id']
            : Uuid::v4();
        $now = self::date($data['updated_at'] ?? null);
        $trackStock = self::boolValue($data['track_stock'] ?? true);
        $stock = $trackStock ? max(0, (int) ($data['stock_quantity'] ?? 0)) : 0;

        try {
            $pdo->beginTransaction();

            $statement = $pdo->prepare(
                'INSERT INTO products
                (id, name, category, cost_price, selling_price, track_stock, stock_quantity,
                 minimum_stock, unit, barcode, qr_code, is_active, created_at, updated_at)
                VALUES
                (:id, :name, :category, :cost_price, :selling_price, :track_stock, :stock_quantity,
                 :minimum_stock, :unit, :barcode, :qr_code, :is_active, :created_at, :updated_at)'
            );
            $statement->execute([
                'id' => $id,
                'name' => trim((string) $data['name']),
                'category' => self::nullable($data['category'] ?? null),
                'cost_price' => (float) $data['cost_price'],
                'selling_price' => (float) $data['selling_price'],
                'track_stock' => $trackStock ? 1 : 0,
                'stock_quantity' => $stock,
                'minimum_stock' => max(0, (int) ($data['minimum_stock'] ?? 0)),
                'unit' => self::nullable($data['unit'] ?? null),
                'barcode' => self::nullable($data['barcode'] ?? null),
                'qr_code' => self::nullable($data['qr_code'] ?? null),
                'is_active' => self::boolValue($data['is_active'] ?? true) ? 1 : 0,
                'created_at' => self::date($data['created_at'] ?? $now),
                'updated_at' => $now,
            ]);

            if ($trackStock && $stock > 0) {
                self::recordInitialStock($pdo, $id, $stock, (float) $data['cost_price'], $now);
            }

            $pdo->commit();
            Response::success(['product' => self::find($id)], 'Produk berhasil ditambahkan.', 201);
        } catch (PDOException $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            self::databaseError($exception);
        }
    }

    public static function update(string $id): never
    {
        $current = self::find($id);
        $data = array_merge($current, Request::json());
        $errors = self::validate($data, false);

        if ($errors !== []) {
            Response::error('Data produk belum valid.', 422, $errors);
        }

        $pdo = Database::connection();
        $trackStock = self::boolValue($data['track_stock']);

        try {
            $statement = $pdo->prepare(
                'UPDATE products SET
                    name = :name,
                    category = :category,
                    cost_price = :cost_price,
                    selling_price = :selling_price,
                    track_stock = :track_stock,
                    stock_quantity = :stock_quantity,
                    minimum_stock = :minimum_stock,
                    unit = :unit,
                    barcode = :barcode,
                    qr_code = :qr_code,
                    is_active = :is_active,
                    updated_at = :updated_at
                 WHERE id = :id AND deleted_at IS NULL'
            );
            $statement->execute([
                'id' => $id,
                'name' => trim((string) $data['name']),
                'category' => self::nullable($data['category'] ?? null),
                'cost_price' => (float) $data['cost_price'],
                'selling_price' => (float) $data['selling_price'],
                'track_stock' => $trackStock ? 1 : 0,
                'stock_quantity' => $trackStock ? max(0, (int) ($data['stock_quantity'] ?? 0)) : 0,
                'minimum_stock' => max(0, (int) ($data['minimum_stock'] ?? 0)),
                'unit' => self::nullable($data['unit'] ?? null),
                'barcode' => self::nullable($data['barcode'] ?? null),
                'qr_code' => self::nullable($data['qr_code'] ?? null),
                'is_active' => self::boolValue($data['is_active'] ?? true) ? 1 : 0,
                'updated_at' => self::date($data['updated_at'] ?? null),
            ]);

            Response::success(['product' => self::find($id)], 'Produk berhasil diperbarui.');
        } catch (PDOException $exception) {
            self::databaseError($exception);
        }
    }

    public static function destroy(string $id): never
    {
        self::find($id);
        $now = gmdate('Y-m-d H:i:s');
        $statement = Database::connection()->prepare(
            'UPDATE products SET is_active = 0, barcode = NULL, qr_code = NULL, deleted_at = :deleted_at, updated_at = :updated_at WHERE id = :id'
        );
        $statement->execute(['id' => $id, 'deleted_at' => $now, 'updated_at' => $now]);
        Response::success([], 'Produk berhasil dihapus.');
    }

    private static function find(string $id): array
    {
        if (!Uuid::valid($id)) {
            Response::error('ID produk tidak valid.', 422);
        }

        $statement = Database::connection()->prepare(
            'SELECT *, (selling_price - cost_price) AS profit_per_unit
             FROM products WHERE id = :id AND deleted_at IS NULL LIMIT 1'
        );
        $statement->execute(['id' => $id]);
        $product = $statement->fetch();

        if (!$product) {
            Response::error('Produk tidak ditemukan.', 404);
        }

        return $product;
    }

    private static function validate(array $data, bool $creating): array
    {
        $errors = [];

        if (trim((string) ($data['name'] ?? '')) === '') {
            $errors['name'] = 'Nama produk wajib diisi.';
        }

        foreach (['cost_price' => 'Harga modal', 'selling_price' => 'Harga jual'] as $field => $label) {
            if (!isset($data[$field]) || !is_numeric($data[$field]) || (float) $data[$field] < 0) {
                $errors[$field] = $label . ' harus berupa angka nol atau lebih.';
            }
        }

        if (isset($data['stock_quantity']) && (!is_numeric($data['stock_quantity']) || (int) $data['stock_quantity'] < 0)) {
            $errors['stock_quantity'] = 'Stok harus berupa angka nol atau lebih.';
        }

        if ($creating && isset($data['id']) && !Uuid::valid((string) $data['id'])) {
            $errors['id'] = 'ID produk harus menggunakan UUID v4.';
        }

        return $errors;
    }

    private static function recordInitialStock(PDO $pdo, string $productId, int $stock, float $cost, string $now): void
    {
        $statement = $pdo->prepare(
            'INSERT INTO stock_movements
            (id, product_id, movement_type, quantity_change, quantity_before, quantity_after,
             latest_cost_price, reference_type, reference_id, notes, occurred_at, created_at, updated_at)
            VALUES
            (:id, :product_id, :movement_type, :quantity_change, 0, :quantity_after,
             :latest_cost_price, :reference_type, :reference_id, :notes, :occurred_at, :created_at, :updated_at)'
        );
        $statement->execute([
            'id' => Uuid::v4(),
            'product_id' => $productId,
            'movement_type' => 'in',
            'quantity_change' => $stock,
            'quantity_after' => $stock,
            'latest_cost_price' => $cost,
            'reference_type' => 'initial_stock',
            'reference_id' => $productId,
            'notes' => 'Stok awal produk',
            'occurred_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private static function nullable(mixed $value): ?string
    {
        $value = trim((string) ($value ?? ''));
        return $value === '' ? null : $value;
    }

    private static function boolValue(mixed $value): bool
    {
        return filter_var($value, FILTER_VALIDATE_BOOL, FILTER_NULL_ON_FAILURE) ?? false;
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

    private static function databaseError(PDOException $exception): never
    {
        if ((string) $exception->getCode() === '23000') {
            Response::error('Barcode atau QR sudah digunakan produk lain.', 409);
        }

        throw $exception;
    }
}
