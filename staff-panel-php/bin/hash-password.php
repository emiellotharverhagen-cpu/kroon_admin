<?php

if (PHP_SAPI !== 'cli') {
    http_response_code(404);
    exit;
}

$password = getenv('PANEL_NEW_PASSWORD');
if ($password === false) {
    fwrite(STDERR, "Stel PANEL_NEW_PASSWORD tijdelijk in en voer dit script via PHP CLI uit.\n");
    exit(1);
}

if (strlen($password) < 14 || strlen($password) > 200) {
    fwrite(STDERR, "Gebruik een wachtwoord van 14 tot 200 bytes.\n");
    exit(1);
}

$hash = password_hash($password, PASSWORD_DEFAULT);
if ($hash === false) {
    fwrite(STDERR, "Het wachtwoord kon niet worden gehasht.\n");
    exit(1);
}

echo $hash . PHP_EOL;
