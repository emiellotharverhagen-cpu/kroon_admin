<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$username = $argv[1] ?? '';
if (!preg_match('/\A[\p{L}\p{N}_.@-]{1,64}\z/u', $username)) {
    fwrite(STDERR, "Gebruik: php bin/create-user.php STAFFNAAM < wachtwoord-via-stdin\n");
    exit(1);
}
$password = stream_get_contents(STDIN);
if ($password === false || str_ends_with($password, "\n")) {
    $password = rtrim((string)$password, "\r\n");
}
if (strlen($password) < 14 || strlen($password) > 200) {
    fwrite(STDERR, "Gebruik een wachtwoord van 14 tot 200 bytes en voer het via stdin aan.\n");
    exit(1);
}

$configPath = getenv('KROON_ADMIN_PANEL_CONFIG') ?: dirname(__DIR__) . '/private/config.php';
if (!is_file($configPath) || !is_readable($configPath)) {
    fwrite(STDERR, "Panelconfiguratie ontbreekt. Configureer eerst private/config.php.\n");
    exit(1);
}
$settings = require $configPath;
try {
    $db = new PDO($settings['db_dsn'], $settings['db_user'], $settings['db_password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    $statement = $db->prepare('INSERT INTO staff_users (username, password_hash) VALUES (?, ?)');
    $statement->execute([$username, password_hash($password, PASSWORD_DEFAULT)]);
    fwrite(STDOUT, "Staffaccount aangemaakt: {$username}\n");
} catch (Throwable $error) {
    fwrite(STDERR, "Staffaccount kon niet worden aangemaakt: " . $error->getMessage() . "\n");
    exit(1);
}
