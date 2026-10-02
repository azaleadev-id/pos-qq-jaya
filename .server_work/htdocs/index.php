<?php

declare(strict_types=1);

require __DIR__ . '/core/Response.php';
require __DIR__ . '/core/Request.php';
require __DIR__ . '/core/Database.php';
require __DIR__ . '/core/Auth.php';
require __DIR__ . '/core/Uuid.php';
require __DIR__ . '/api/ProductController.php';
require __DIR__ . '/api/StockController.php';
require __DIR__ . '/api/SaleController.php';
require __DIR__ . '/api/ServiceController.php';
require __DIR__ . '/api/PhoneController.php';
require __DIR__ . '/api/ExpenseController.php';
require __DIR__ . '/api/ReportController.php';

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-API-Key');
header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');

if (Request::method() === 'OPTIONS') {
    http_response_code(204);
    exit;
}

$app = require __DIR__ . '/config/app.php';

try {
    $method = Request::method();
    $path = Request::path();

    if ($method === 'GET' && $path === '/') {
        Response::success([
            'name' => $app['name'],
            'version' => '1.7.0',
        ], 'API aktif.');
    }

    if ($method === 'GET' && $path === '/api/health') {
        Database::connection()->query('SELECT 1');
        Response::success([
            'api' => 'online',
            'database' => 'connected',
            'php_version' => PHP_VERSION,
        ], 'API dan database terhubung.');
    }

    Auth::requireApiKey();

    if ($method === 'GET' && $path === '/api/products') {
        ProductController::index();
    }

    if ($method === 'POST' && $path === '/api/products') {
        ProductController::store();
    }

    if ($method === 'GET' && $path === '/api/stock-movements') {
        StockController::index();
    }

    if ($method === 'GET' && $path === '/api/stock/low') {
        StockController::lowStock();
    }

    if ($method === 'POST' && $path === '/api/stock/in') {
        StockController::storeIncoming();
    }

    if ($method === 'GET' && $path === '/api/sales') {
        SaleController::index();
    }

    if ($method === 'POST' && $path === '/api/sales') {
        SaleController::store();
    }

    if ($method === 'GET' && $path === '/api/services') ServiceController::index();
    if ($method === 'POST' && $path === '/api/services') ServiceController::store();
    if ($method === 'GET' && $path === '/api/service-presets') ServiceController::presets();

    if (preg_match('#^/api/services/([0-9a-f-]{36})$#i', $path, $matches) === 1) {
        if ($method === 'GET') ServiceController::show($matches[1]);
        if ($method === 'PUT' || $method === 'PATCH') ServiceController::update($matches[1]);
        if ($method === 'DELETE') ServiceController::destroy($matches[1]);
    }

    if (preg_match('#^/api/services/([0-9a-f-]{36})/status$#i', $path, $matches) === 1 && $method === 'PATCH') {
        ServiceController::changeStatus($matches[1]);
    }

    if (preg_match('#^/api/services/([0-9a-f-]{36})/payments$#i', $path, $matches) === 1 && $method === 'POST') {
        ServiceController::addPayment($matches[1]);
    }

    if ($method === 'GET' && $path === '/api/phones') PhoneController::index();
    if ($method === 'POST' && $path === '/api/phones/purchases') PhoneController::storePurchase();
    if ($method === 'POST' && $path === '/api/phones/direct-sale') PhoneController::directSale();

    if ($method === 'GET' && $path === '/api/expenses') ExpenseController::index();
    if ($method === 'POST' && $path === '/api/expenses') ExpenseController::store();
    if ($method === 'GET' && $path === '/api/dashboard') ReportController::dashboard();
    if ($method === 'GET' && $path === '/api/recaps') ReportController::recap();
    if ($method === 'GET' && $path === '/api/recaps/overall') ReportController::overall();
    if ($method === 'GET' && $path === '/api/recaps/products') ReportController::products();
    if ($method === 'GET' && $path === '/api/recaps/services') ReportController::services();
    if ($method === 'GET' && $path === '/api/recaps/phones') ReportController::phones();
    if ($method === 'GET' && $path === '/api/recaps/expenses') ReportController::expenses();
    if ($method === 'GET' && $path === '/api/recaps/payments') ReportController::payments();

    if (preg_match('#^/api/expenses/([0-9a-f-]{36})$#i', $path, $matches) === 1) {
        if ($method === 'GET') ExpenseController::show($matches[1]);
        if ($method === 'PUT' || $method === 'PATCH') ExpenseController::update($matches[1]);
        if ($method === 'DELETE') ExpenseController::destroy($matches[1]);
    }

    if (preg_match('#^/api/phones/([0-9a-f-]{36})$#i', $path, $matches) === 1) {
        if ($method === 'GET') PhoneController::show($matches[1]);
        if ($method === 'PUT' || $method === 'PATCH') PhoneController::update($matches[1]);
        if ($method === 'DELETE') PhoneController::destroy($matches[1]);
    }

    if (preg_match('#^/api/phones/([0-9a-f-]{36})/sell$#i', $path, $matches) === 1 && $method === 'POST') {
        PhoneController::sell($matches[1]);
    }

    if (preg_match('#^/api/sales/([0-9a-f-]{36})$#i', $path, $matches) === 1) {
        $id = $matches[1];

        if ($method === 'GET') {
            SaleController::show($id);
        }

        if ($method === 'PUT' || $method === 'PATCH') {
            SaleController::update($id);
        }

        if ($method === 'DELETE') {
            SaleController::destroy($id);
        }
    }

    if (preg_match('#^/api/products/([0-9a-f-]{36})$#i', $path, $matches) === 1) {
        $id = $matches[1];

        if ($method === 'GET') {
            ProductController::show($id);
        }

        if ($method === 'PUT' || $method === 'PATCH') {
            ProductController::update($id);
        }

        if ($method === 'DELETE') {
            ProductController::destroy($id);
        }
    }

    Response::error('Endpoint tidak ditemukan.', 404);
} catch (PDOException $exception) {
    $message = $app['debug'] ? $exception->getMessage() : 'Koneksi database gagal.';
    Response::error($message, 500);
} catch (Throwable $exception) {
    $message = $app['debug'] ? $exception->getMessage() : 'Terjadi kesalahan pada server.';
    Response::error($message, 500);
}
