# Kroon Admin PHP staffpanel

PHP 8.1+ variant voor shared hosting met PDO MySQL, cURL en HTTPS. De bestaande FiveM-resource en het Node-panel blijven apart en ongewijzigd.

## Architectuur en vereisten

- Upload **alleen de inhoud van `staff-panel-php/public/`** naar de document root van het subdomein, bijvoorbeeld `staff.example.nl`. Bouw eerst de frontend; de `public/` map bevat dan `index.html`, `api.php`, `.htaccess` en de `assets/`.
- De PHP API en staffaccounts draaien op je webhosting; stafflogin en loginpogingen staan in de MySQL database van die hosting.
- De browser stuurt acties naar dezelfde origin naar PHP. PHP stuurt serverbeheer door naar de HTTPS-API van de FiveM gameserver; de browser krijgt het servergeheim nooit.
- Vereist: PHP 8.1+, `pdo_mysql`, `curl`, `openssl`, HTTPS, een MySQL database en uitgaand HTTPS-verkeer vanaf de hosting.
- Node is alleen nodig om een keer de React-bestanden te bouwen; PHP is nodig om het online panel te draaien.

**Belangrijk:** de PHP-hosting en gameserver staan op aparte machines. De PHP-panelcode weigert een niet-HTTPS gameserver-API. Publiceer de FiveM HTTP-handler dus niet rechtstreeks over onbeveiligd HTTP. Vraag je gameserverprovider om een HTTPS-endpoint of reverse proxy met geldig certificaat naar `127.0.0.1:30120`. Sta zo nodig alleen verbindingen vanaf je webhost toe. Als je provider dit niet kan aanbieden en je geen beveiligde tunnel kunt instellen, is de PHP-shared-hostopstelling niet veilig bruikbaar.

## 1. Webhosting database

Maak in het hostingpaneel een aparte MySQL database en databasegebruiker aan. Importeer `staff-panel-php/sql/schema.sql` via phpMyAdmin of de database-importfunctie. Dit zijn uitsluitend staffaccounts en aanmeldpogingen; de spelers, bans en auditlogs blijven in de database van de FiveM-resource.

Maak je geheime configuratiemap **buiten** de publieke document root. Kopieer `private/config.example.php` als `private/config.php` en vul de echte waarden in:

```php
return [
    'panel_origin' => 'https://staff.example.nl',
    'shared_token' => '64_OF_MEER_HEX_TEKENS',
    'fivem_api_url' => 'https://secure-api.example.nl/kroon_admin/api',
    'db_dsn' => 'mysql:host=localhost;dbname=HOSTING_DATABASE;charset=utf8mb4',
    'db_user' => 'HOSTING_DATABASE_USER',
    'db_password' => 'HOSTING_DATABASE_PASSWORD',
    'rate_limit_secret' => 'APART_RANDOM_GEHEIM_VAN_MINIMAAL_32_TEKENS',
];
```

Als je hosting geen bestanden buiten de document root toestaat, stel dan een omgevingsvariabele `KROON_ADMIN_PANEL_CONFIG` in naar een privé configbestand. Plaats `config.php` nooit in de publieke `public/` map en commit echte geheimen niet.

Genereer voor `shared_token` en `rate_limit_secret` ieder een eigen willekeurig geheim. Bijvoorbeeld:

```sh
php -r 'echo bin2hex(random_bytes(32)), PHP_EOL;'
```

De panel origin is exact de HTTPS-origin (geen pad, query of afsluitende slash). Zet de HTTPS force/redirect-optie aan in je hostingpaneel.

## 2. FiveM gameserver

Gebruik **dezelfde** `shared_token` als in PHP in de `server.cfg`:

```cfg
set kroon_admin_panel_token "ZELFDE_64_OF_MEER_HEX_TEKENS"
ensure oxmysql
ensure kroon_admin
```

De huidige resource geeft `/kroon_admin/api` via `SetHttpHandler` uit. Je `fivem_api_url` moet een geldig HTTPS-adres zijn dat veilig naar die FiveM HTTP-handler proxyt. Configureer die TLS-proxy bij de gameserverprovider; PHP en de FiveM-server moeten elkaar via HTTPS kunnen bereiken. Open geen willekeurige FiveM-admin/API-poort naar het internet zonder TLS, sterk token en provider-firewall.

De `kroon_admin` resource gebruikt zijn eigen oxmysql database voor bans, waarschuwingen en auditlogs. Geef de PHP-website geen toegang tot die database; de PHP-API leest logs/spelers en voert acties uit via de beveiligde FiveM API.

## 3. Frontend bouwen en uploaden

In een ontwikkelomgeving met Node.js 20+:

```sh
npm ci
npm run build:panel-php
```

Upload daarna **de bestanden in** `staff-panel-php/public/` naar de subdomein-document root. Zorg dat `api.php` PHP mag uitvoeren en dat `.htaccess` wordt gelezen (Apache). Bij Nginx-hosting moet de provider de document root en PHP-FPM correct instellen. Laat de private config en SQL nooit in de document root staan.

## 4. Eerste staffaccount

Nadat het schema en de private config zijn ingesteld, maak je een staffaccount via SSH/PHP CLI. Voer het wachtwoord verborgen in en geef het via stdin door:

```sh
read -s -p "Nieuw staffwachtwoord (minimaal 14 tekens): " STAFF_PASSWORD; echo
printf '%s' "$STAFF_PASSWORD" | php /pad/naar/staff-panel-php/bin/create-user.php staffnaam
unset STAFF_PASSWORD
```

Op hosting zonder PHP-CLI: maak de hash op je eigen computer met PHP CLI, en voeg die via phpMyAdmin toe met een prepared/query-safe invoer:

```sql
INSERT INTO staff_users (username, password_hash) VALUES ('staffnaam', 'PLAK_HIER_DE_OUTPUT_VAN_PASSWORD_HASH');
```

Gebruik hiervoor `password_hash($wachtwoord, PASSWORD_DEFAULT)`; sla nooit een plaintextwachtwoord op. Verwijder tijdelijke wachtwoordbestanden na gebruik. Elk staffaccount heeft volledige beheerrechten.

## Ondersteunde webacties

Kick, tijdelijke/permanente ban, waarschuwing, mute/unmute, freeze/unfreeze, revive, geld/items geven, voertuig spawnen, godmode/noclip/onzichtbaar, teleport naar opgeslagen locaties, servermededeling en auditlog. Geld/items vereisen ESX of QBCore. Een webbrowser heeft geen in-game waypoint of eigen gamepersonage; waypoint/goto/bring blijven uitsluitend beschikbaar in de in-game NUI.

Sessies zijn server-side PHP-sessies met beveiligde cookies en CSRF/origin-controles. Aanmeldpogingen worden per gehashte IP beperkt. Hou PHP, hosting, MySQL en TLS actueel; maak periodieke databaseback-ups en geef de databasegebruiker alleen toegang tot deze paneldatabase.
