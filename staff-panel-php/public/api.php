<?php
declare(strict_types=1);

function respond(int $status, array $body, array $headers = []): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store, private');
    header('X-Content-Type-Options: nosniff');
    header('Referrer-Policy: no-referrer');
    header('X-Frame-Options: DENY');
    header("Content-Security-Policy: default-src 'none'; frame-ancestors 'none'; base-uri 'none'");
    foreach ($headers as $name => $value) {
        header($name . ': ' . $value);
    }
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

function config(): array
{
    $path = getenv('KROON_ADMIN_PANEL_CONFIG') ?: dirname(__DIR__) . '/private/config.php';
    if (!is_file($path) || !is_readable($path)) {
        respond(503, ['ok' => false, 'error' => 'Panelconfiguratie ontbreekt.']);
    }
    $config = require $path;
    if (!is_array($config)) {
        respond(503, ['ok' => false, 'error' => 'Panelconfiguratie is ongeldig.']);
    }
    foreach (['panel_origin', 'shared_token', 'fivem_api_url', 'db_dsn', 'db_user', 'db_password', 'rate_limit_secret'] as $key) {
        if (!isset($config[$key]) || !is_string($config[$key]) || trim($config[$key]) === '') {
            respond(503, ['ok' => false, 'error' => 'Panelconfiguratie is onvolledig.']);
        }
    }
    if (!preg_match('/\A[a-f0-9]{64,}\z/i', $config['shared_token'])
        || strlen($config['rate_limit_secret']) < 32) {
        respond(503, ['ok' => false, 'error' => 'Panelconfiguratie bevat ongeldige beveiligingsinstellingen.']);
    }
    $origin = parse_url($config['panel_origin']);
    $api = parse_url($config['fivem_api_url']);
    if (!is_array($origin) || ($origin['scheme'] ?? '') !== 'https' || !isset($origin['host'])
        || isset($origin['path']) && $origin['path'] !== ''
        || isset($origin['query']) || isset($origin['fragment'])
        || !is_array($api) || ($api['scheme'] ?? '') !== 'https' || !isset($api['host'])
        || isset($api['user']) || isset($api['pass']) || isset($api['query']) || isset($api['fragment'])) {
        respond(503, ['ok' => false, 'error' => 'Panel en gameserver-API moeten met een HTTPS-adres zijn ingesteld.']);
    }
    return $config;
}

function database(array $settings): PDO
{
    static $connection = null;
    if ($connection instanceof PDO) {
        return $connection;
    }
    $connection = new PDO($settings['db_dsn'], $settings['db_user'], $settings['db_password'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
    return $connection;
}

function requestData(): array
{
    $length = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
    if ($length > 16384) {
        respond(413, ['ok' => false, 'error' => 'Aanvraag te groot.']);
    }
    $raw = file_get_contents('php://input', false, null, 0, 16385);
    if ($raw === false || strlen($raw) > 16384) {
        respond(413, ['ok' => false, 'error' => 'Aanvraag te groot.']);
    }
    $decoded = json_decode($raw, true);
    if (!is_array($decoded)) {
        respond(400, ['ok' => false, 'error' => 'Ongeldige JSON-aanvraag.']);
    }
    return $decoded;
}

function requireHttps(): void
{
    if (($_SERVER['HTTPS'] ?? '') !== 'on' && ($_SERVER['HTTPS'] ?? '') !== '1') {
        respond(400, ['ok' => false, 'error' => 'Gebruik HTTPS om het staffpaneel te openen.']);
    }
}

function validOrigin(array $settings): bool
{
    $origin = $_SERVER['HTTP_ORIGIN'] ?? '';
    return is_string($origin) && hash_equals($settings['panel_origin'], $origin);
}

function requireCsrf(array $settings): void
{
    if (!validOrigin($settings)
        || !isset($_SERVER['HTTP_X_CSRF_TOKEN'], $_SESSION['csrf'])
        || !hash_equals($_SESSION['csrf'], $_SERVER['HTTP_X_CSRF_TOKEN'])) {
        respond(403, ['ok' => false, 'error' => 'Aanvraag geweigerd.']);
    }
}

function requireStaff(): array
{
    if (!isset($_SESSION['staff_id'], $_SESSION['username'], $_SESSION['csrf'], $_SESSION['expires_at'])
        || (int)$_SESSION['expires_at'] < time()) {
        session_unset();
        session_destroy();
        respond(401, ['ok' => false, 'error' => 'Je sessie is verlopen. Meld je opnieuw aan.']);
    }
    $_SESSION['expires_at'] = time() + 28800;
    return ['id' => (int)$_SESSION['staff_id'], 'username' => (string)$_SESSION['username']];
}

function login(array $settings, PDO $db): never
{
    if (!validOrigin($settings)) {
        respond(403, ['ok' => false, 'error' => 'Aanvraag geweigerd.']);
    }
    $body = requestData();
    $username = trim(is_string($body['username'] ?? null) ? $body['username'] : '');
    $password = is_string($body['password'] ?? null) ? $body['password'] : '';
    if (!preg_match('/\A[\p{L}\p{N}_.@-]{1,64}\z/u', $username) || strlen($password) > 200) {
        respond(401, ['ok' => false, 'error' => 'Gebruikersnaam of wachtwoord onjuist.']);
    }
    $remoteAddress = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $ipHash = hash_hmac('sha256', $remoteAddress, $settings['rate_limit_secret']);
    $db->beginTransaction();
    try {
        $createAttempt = $db->prepare(
            'INSERT IGNORE INTO staff_login_attempts (ip_hash, attempt_count, window_started_at) VALUES (?, 0, UTC_TIMESTAMP())'
        );
        $createAttempt->execute([$ipHash]);
        $attemptQuery = $db->prepare('SELECT attempt_count, window_started_at, blocked_until FROM staff_login_attempts WHERE ip_hash = ? FOR UPDATE');
        $attemptQuery->execute([$ipHash]);
        $attempt = $attemptQuery->fetch();
        if ($attempt && $attempt['blocked_until'] !== null && strtotime($attempt['blocked_until'] . ' UTC') > time()) {
            $db->commit();
            respond(429, ['ok' => false, 'error' => 'Te veel mislukte aanmeldingen. Probeer het later opnieuw.']);
        }
        $windowStart = $attempt ? strtotime($attempt['window_started_at'] . ' UTC') : 0;
        if (!$attempt || $windowStart < time() - 900) {
            $attempt = ['attempt_count' => 0, 'window_started_at' => gmdate('Y-m-d H:i:s'), 'blocked_until' => null];
        }
        $staffQuery = $db->prepare('SELECT id, username, password_hash FROM staff_users WHERE username = ? LIMIT 1');
        $staffQuery->execute([$username]);
        $staff = $staffQuery->fetch();
        $passwordValid = $staff
            ? password_verify($password, $staff['password_hash'])
            : password_verify($password, '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2uheWG/igi.');
        if (!$staff || !$passwordValid) {
            $count = (int)$attempt['attempt_count'] + 1;
            $blockedUntil = $count >= 10 ? gmdate('Y-m-d H:i:s', time() + 900) : null;
            $updateAttempt = $db->prepare(
                'UPDATE staff_login_attempts SET attempt_count = ?, window_started_at = ?, blocked_until = ? WHERE ip_hash = ?'
            );
            $updateAttempt->execute([$count, $attempt['window_started_at'], $blockedUntil, $ipHash]);
            $db->commit();
            respond($count >= 10 ? 429 : 401, [
                'ok' => false,
                'error' => $count >= 10 ? 'Te veel mislukte aanmeldingen. Probeer het later opnieuw.' : 'Gebruikersnaam of wachtwoord onjuist.',
            ]);
        }
        $db->prepare('DELETE FROM staff_login_attempts WHERE ip_hash = ?')->execute([$ipHash]);
        $db->prepare('UPDATE staff_users SET last_login_at = UTC_TIMESTAMP() WHERE id = ?')->execute([$staff['id']]);
        $db->commit();
    } catch (Throwable $error) {
        if ($db->inTransaction()) {
            $db->rollBack();
        }
        error_log('kroon_admin staff login database error: ' . $error->getMessage());
        respond(503, ['ok' => false, 'error' => 'Aanmelden is tijdelijk niet beschikbaar.']);
    }

    session_regenerate_id(true);
    $_SESSION = [
        'staff_id' => (int)$staff['id'],
        'username' => $staff['username'],
        'csrf' => bin2hex(random_bytes(32)),
        'expires_at' => time() + 28800,
    ];
    respond(200, ['ok' => true, 'username' => $staff['username'], 'csrf' => $_SESSION['csrf']]);
}

function proxyGameServer(array $settings, string $route, string $method, ?array $payload = null): never
{
    $url = rtrim($settings['fivem_api_url'], '/') . '/' . $route;
    $handle = curl_init($url);
    if ($handle === false) {
        respond(502, ['ok' => false, 'error' => 'Gameserver-verbinding kon niet worden gestart.']);
    }
    $headers = ['Authorization: Bearer ' . $settings['shared_token'], 'Accept: application/json'];
    curl_setopt_array($handle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => false,
        CURLOPT_CONNECTTIMEOUT => 5,
        CURLOPT_TIMEOUT => 10,
        CURLOPT_SSL_VERIFYPEER => true,
        CURLOPT_SSL_VERIFYHOST => 2,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_CUSTOMREQUEST => $method,
    ]);
    if ($payload !== null) {
        $json = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            curl_close($handle);
            respond(400, ['ok' => false, 'error' => 'Ongeldige aanvraag.']);
        }
        $headers[] = 'Content-Type: application/json';
        curl_setopt($handle, CURLOPT_HTTPHEADER, $headers);
        curl_setopt($handle, CURLOPT_POSTFIELDS, $json);
    }
    $response = curl_exec($handle);
    $status = (int)curl_getinfo($handle, CURLINFO_RESPONSE_CODE);
    $curlError = curl_error($handle);
    curl_close($handle);
    if ($response === false) {
        error_log('kroon_admin staff gameserver request failed: ' . $curlError);
        respond(502, ['ok' => false, 'error' => 'De gameserver is niet bereikbaar via HTTPS.']);
    }
    $decoded = json_decode($response, true);
    if (!is_array($decoded)) {
        respond(502, ['ok' => false, 'error' => 'Ongeldig antwoord van de gameserver.']);
    }
    $status = $status >= 200 && $status <= 599 ? $status : 502;
    respond($status, $decoded);
}

$settings = config();
requireHttps();
header('Strict-Transport-Security: max-age=31536000');
header('Permissions-Policy: camera=(), microphone=(), geolocation=()');
ini_set('session.use_strict_mode', '1');
ini_set('session.use_only_cookies', '1');
ini_set('session.cookie_httponly', '1');
ini_set('session.cookie_secure', '1');
ini_set('session.cookie_samesite', 'Strict');
session_set_cookie_params([
    'lifetime' => 0,
    'path' => '/',
    'secure' => true,
    'httponly' => true,
    'samesite' => 'Strict',
]);
session_start();

$route = $_GET['route'] ?? '';
if (!is_string($route)) {
    respond(400, ['ok' => false, 'error' => 'Ongeldige route.']);
}
$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($route === 'session' && $method === 'GET') {
    if (isset($_SESSION['staff_id'], $_SESSION['expires_at']) && (int)$_SESSION['expires_at'] >= time()) {
        respond(200, ['authenticated' => true, 'username' => $_SESSION['username'], 'csrf' => $_SESSION['csrf']]);
    }
    respond(200, ['authenticated' => false]);
}
if ($route === 'login' && $method === 'POST') {
    try {
        login($settings, database($settings));
    } catch (Throwable $error) {
        error_log('kroon_admin staff database error: ' . $error->getMessage());
        respond(503, ['ok' => false, 'error' => 'Aanmelden is tijdelijk niet beschikbaar.']);
    }
}

$staff = requireStaff();
if ($method === 'POST') {
    requireCsrf($settings);
    if ($route === 'logout') {
        $_SESSION = [];
        if (ini_get('session.use_cookies')) {
            $params = session_get_cookie_params();
            setcookie(session_name(), '', [
                'expires' => time() - 42000,
                'path' => $params['path'],
                'secure' => true,
                'httponly' => true,
                'samesite' => 'Strict',
            ]);
        }
        session_destroy();
        respond(200, ['ok' => true]);
    }

    $body = requestData();
    if ($route === 'action') {
        $allowed = ['kick', 'ban', 'warn', 'mute', 'unmute', 'freeze', 'unfreeze', 'revive'];
        $target = filter_var($body['target'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        $reason = $body['reason'] ?? '';
        $days = $body['days'] ?? 0;
        if (!in_array($body['action'] ?? null, $allowed, true) || $target === false
            || !is_string($reason) || strlen($reason) > 960
            || filter_var($days, FILTER_VALIDATE_INT) === false || (int)$days < 0 || (int)$days > 3650) {
            respond(400, ['ok' => false, 'error' => 'Ongeldige speleractie.']);
        }
        proxyGameServer($settings, 'action', 'POST', [
            'action' => $body['action'],
            'target' => (int)$target,
            'reason' => $reason,
            'days' => (int)$days,
            'admin' => $staff['username'],
        ]);
    }
    if ($route === 'tool') {
        $action = $body['action'] ?? null;
        $allowed = ['announce', 'giveMoney', 'giveItem', 'spawnVehicle', 'toggle', 'teleportLocation'];
        if (!in_array($action, $allowed, true)) {
            respond(400, ['ok' => false, 'error' => 'Onbekende beheertool.']);
        }
        $target = filter_var($body['target'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
        if ($action === 'announce') {
            if (!is_string($body['message'] ?? null) || trim($body['message']) === '' || strlen($body['message']) > 2000) {
                respond(400, ['ok' => false, 'error' => 'Ongeldige mededeling.']);
            }
        } elseif ($target === false) {
            respond(400, ['ok' => false, 'error' => 'Selecteer een geldige speler.']);
        }
        if (in_array($action, ['giveMoney', 'giveItem'], true)) {
            $amount = filter_var($body['amount'] ?? null, FILTER_VALIDATE_INT);
            $maxAmount = $action === 'giveItem' ? 1000 : 1000000;
            if ($amount === false || $amount < 1 || $amount > $maxAmount) {
                respond(400, ['ok' => false, 'error' => 'Ongeldig bedrag of aantal.']);
            }
        }
        if ($action === 'giveMoney' && !in_array($body['account'] ?? null, ['cash', 'bank'], true)) {
            respond(400, ['ok' => false, 'error' => 'Ongeldige rekening.']);
        }
        if ($action === 'giveItem' && (!is_string($body['item'] ?? null) || !preg_match('/\A[\w-]{1,50}\z/', $body['item']))) {
            respond(400, ['ok' => false, 'error' => 'Ongeldige itemnaam.']);
        }
        if ($action === 'spawnVehicle' && (!is_string($body['model'] ?? null) || !preg_match('/\A[\w]{1,50}\z/', $body['model']))) {
            respond(400, ['ok' => false, 'error' => 'Ongeldige voertuigmodelnaam.']);
        }
        if ($action === 'toggle' && (!in_array($body['toggle'] ?? null, ['godmode', 'noclip', 'invisible'], true)
            || !is_bool($body['enabled'] ?? null))) {
            respond(400, ['ok' => false, 'error' => 'Ongeldige toggle.']);
        }
        if ($action === 'teleportLocation') {
            $index = filter_var($body['index'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1, 'max_range' => 100]]);
            if ($index === false) {
                respond(400, ['ok' => false, 'error' => 'Ongeldige locatie.']);
            }
        }
        $payload = ['action' => $action, 'admin' => $staff['username']];
        foreach (['target', 'message', 'amount', 'account', 'item', 'model', 'toggle', 'enabled', 'index'] as $key) {
            if (array_key_exists($key, $body)) {
                $payload[$key] = $body[$key];
            }
        }
        proxyGameServer($settings, 'tool', 'POST', $payload);
    }
    respond(404, ['ok' => false, 'error' => 'Niet gevonden.']);
}

if ($method === 'GET' && in_array($route, ['players', 'logs'], true)) {
    proxyGameServer($settings, $route, 'GET');
}
respond(404, ['ok' => false, 'error' => 'Niet gevonden.']);
