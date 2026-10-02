<?php

declare(strict_types=1);

final class StockController
{
    public static function index(): never
    {
        $productId = trim((string) ($_GET['product_id'] ?? ''));
        $sql = 'SELECT sm.*, p.name AS product_name, p.unit
                FROM stock_movements sm
                INNER JOIN products p ON p.id = sm.product_id
                WHERE sm.deleted_at IS NULL';
        $params = [];

        if ($productId !== '') {
            if (!Uuid::valid($productId)) {
                Response::error('ID produk tidak valid.', 422);
            }
            $sql .= ' AND sm.product_id = :product_id';
            $params['product_id'] = $productId;
        }

        $sql .= ' ORDER BY sm.occurred_at DESC, sm.created_at DESC LIMIT 500';
        $statement = Database::connection()->prepare($sql);
        $statement->execute($params);
        Response::success(['movements' => $statement->fetchAll()]);
    }

    public static function lowStock(): never
    {
        $statement = Database::connection()->query(
            'SELECT *, (selling_price - cost_price) AS profit_per_unit
             FROM products
             WHERE deleted_at IS NULL
               AND is_active = 1
               AND track_stock = 1
               AND stock_quantity <= minimum_stock
             ORDER BY stock_quantity ASC, name ASC'
        );
        Response::success(['products' => $statement->fetchAll()]);
    }

    public static function storeIncoming(): never
    {
        $data = Request::json();
        $productId = trim((string) ($data['product_id'] ?? ''));
        $quantity = (int) ($data['quantity'] ?? 0);
        $costPrice = $data['cost_price'] ?? null;
        $errors = [];

        if (!Uuid::valid($productId)) {
            $errors['product_id'] = 'ID produk tidak valid.';
        }
        if ($quantity <= 0) {
            $errors['quantity'] = 'Jumlah stok masuk harus lebih dari nol.';
        }
        if (!is_numeric($costPrice) || (float) $costPrice < 0) {
            $errors['cost_price'] = 'Harga modal harus berupa angka nol atau lebih.';
        }
        if ($errors !== []) {
            Response::error('Data stok masuk belum valid.', 422, $errors);
        }

        $pdo = Database::connection();
        $now = self::date($data['occurred_at'] ?? null);

        try {
            $pdo->beginTransaction();

            $statement = $pdo->prepare(
                'SELECT id, name, track_stock, stock_quantity
                 FROM products
                 WHERE id = :id AND deleted_at IS NULL
                 LIMIT 1 FOR UPDATE'
            );
            $statement->execute(['id' => $productId]);
            $product = $statement->fetch();

            if (!$product) {
                $pdo->rollBack();
                Response::error('Produk tidak ditemukan.', 404);
            }
            if ((int) $product['track_stock'] !== 1) {
                $pdo->rollBack();
                Response::error('Produk ini tidak menggunakan pelacakan stok.', 422);
            }

            $before = (int) $product['stock_quantity'];
            $after = $before + $quantity;

            $update = $pdo->prepare(
                'UPDATE products
                 SET stock_quantity = :stock_quantity,
                     cost_price = :cost_price,
                     updated_at = :updated_at
                 WHERE id = :id'
            );
            $update->execute([
                'id' => $productId,
                'stock_quantity' => $after,
                'cost_price' => (float) $costPrice,
                'updated_at' => $now,
            ]);

            $movementId = isset($data['id']) && Uuid::valid((string) $data['id'])
                ? (string) $data['id']
                : Uuid::v4();
            $insert = $pdo->prepare(
                'INSERT INTO stock_movements
                (id, product_id, movement_type, quantity_change, quantity_before, quantity_after,
                 latest_cost_price, reference_type, reference_id, notes, occurred_at, created_at, updated_at)
                VALUES
                (:id, :product_id, :movement_type, :quantity_change, :quantity_before, :quantity_after,
                 :latest_cost_price, :reference_type, :reference_id, :notes, :occurred_at, :created_at, :updated_at)'
            );
            $insert->execute([
                'id' => $movementId,
                'product_id' => $productId,
                'movement_type' => 'in',
                'quantity_change' => $quantity,
                'quantity_before' => $before,
                'quantity_after' => $after,
                'latest_cost_price' => (float) $costPrice,
                'reference_type' => 'stock_in',
                'reference_id' => $movementId,
                'notes' => self::nullable($data['notes'] ?? null),
                'occurred_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $pdo->commit();
            Response::success([
                'movement_id' => $movementId,
                'product_id' => $productId,
                'product_name' => $product['name'],
                'quantity_before' => $before,
                'quantity_added' => $quantity,
                'quantity_after' => $after,
                'latest_cost_price' => number_format((float) $costPrice, 2, '.', ''),
            ], 'Stok masuk berhasil dicatat.', 201);
        } catch (Throwable $exception) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            throw $exception;
        }
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
}

