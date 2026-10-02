<?php

declare(strict_types=1);

return [
    'host' => getenv('DB_HOST') ?: 'sql107.ezyro.com',
    'port' => getenv('DB_PORT') ?: '3306',
    'database' => getenv('DB_DATABASE') ?: 'ezyro_43014941_api',
    'username' => getenv('DB_USERNAME') ?: 'ezyro_43014941',
    'password' => getenv('DB_PASSWORD') ?: '37aaa104ffa',
    'charset' => 'utf8mb4',
];