<?php

declare(strict_types=1);

return [
    'name' => 'QQ Jaya Cell API',
    'environment' => getenv('APP_ENV') ?: 'local',
    'debug' => (getenv('APP_DEBUG') ?: 'true') === 'true',
    'api_key' => getenv('APP_API_KEY') ?: 'qq-jaya-cell-local-key',
];

