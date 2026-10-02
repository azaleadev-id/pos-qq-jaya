<?php

declare(strict_types=1);

final class Auth
{
    public static function requireApiKey(): void
    {
        $config = require __DIR__ . '/../config/app.php';
        $provided = $_SERVER['HTTP_X_API_KEY'] ?? '';

        if ($provided === '') {
            $authorization = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
            if (preg_match('/^Bearer\s+(.+)$/i', $authorization, $matches) === 1) {
                $provided = trim($matches[1]);
            }
        }

        if ($provided === '' || !hash_equals($config['api_key'], $provided)) {
            Response::error('API key tidak valid.', 401);
        }
    }
}

