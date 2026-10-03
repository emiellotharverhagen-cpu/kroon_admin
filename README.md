# kroon_admin

Nederlandstalige FiveM admin resource met Lua-serverlogica, ACE-autorisatie en een React/NUI-dashboard.

## Functies

- Online spelerslijst met server-ID, ping en license.
- Speleracties: kick, permanente/tijdelijke ban, waarschuwing, mute, freeze, teleport naar speler, speler hierheen halen en revive.
- Teleport naar waypoint en configureerbare opgeslagen locaties.
- God mode, noclip en onzichtbaarheid.
- Geld en items uitdelen aan spelers met ESX of QBCore.
- Voertuigen spawnen, servermededelingen sturen en auditlogs inzien.
- MySQL-opslag voor bans, waarschuwingen en beheeracties; optionele Discord-webhook.
- Commando `/admin` en standaard sneltoets F10.
- Apart, optioneel zelf te hosten staffwebpanel met login, sessiebeveiliging en dezelfde server-side managementacties.

## Vereisten en installatie

1. Installeer en configureer `oxmysql` en een MySQL-database.
2. Plaats de map `kroon_admin` in de FiveM `resources`-map. De gebouwde NUI-bestanden staan al in `web/dist`.
3. Zorg dat `oxmysql` vóór deze resource start en voeg aan `server.cfg` toe:

   ```cfg
   ensure oxmysql
   ensure kroon_admin
   ```

4. Geef ACE-toegang aan een vertrouwde identifier of groep. Bijvoorbeeld:

   ```cfg
   add_ace group.admin kroon_admin allow
   add_principal identifier.license:VUL_HIER_JE_LICENSE_IN group.admin
   ```

   Verander `Config.Permission` in `config.lua` als je een andere ACE-node wilt gebruiken. Beheerdersacties worden server-side opnieuw gecontroleerd; een geopende NUI is geen autorisatie.
5. Tabellen worden bij het starten automatisch aangemaakt door `database.lua`. De gelijkwaardige SQL staat in `sql/schema.sql` als je de tabellen liever vooraf zelf aanmaakt.

## NUI bouwen

De resource bevat direct bruikbare output in `web/dist`. Om de React-interface na wijzigingen opnieuw te bouwen:

```sh
npm ci
npm run build
```

Deploy de resulterende `web/dist`-bestanden samen met de resource. Er is geen externe webserver nodig.

## Configuratie

Pas `config.lua` aan voor:

- `Config.Permission`: ACE-permission node.
- `Config.Webhook`: Discord webhook URL; leeg laten om Discord-uitvoer uit te schakelen.
- `Config.SavedLocations`: locaties voor de teleportatielijst.
- `Config.MaxReasonLength`, `Config.MaxMoney`, `Config.MaxItemCount` en `Config.LogLimit`: invoer- en limietinstellingen.

Gebruik de webhook placeholder pas nadat je een eigen webhook hebt geconfigureerd. Deel de URL niet publiekelijk.

## Frameworkintegratie en beperkingen

- Geld/items geven gebruikt automatisch QBCore (`qb-core`) of ESX (`es_extended`) wanneer die resource gestart is. ESX geld gaat naar contant (`money`) of bank; QBCore gebruikt `cash` of `bank`. Itemnamen zijn framework-specifiek.
- Zonder ESX/QBCore blijven andere beheerfuncties beschikbaar, maar geld/items geven is uitgeschakeld.
- Mute blokkeert standaard de client voice/chat controls 249 en 245; een externe voice-resource kan hiervoor eigen server-side mute-integratie vereisen. Gebruik voor productie de mute-functie van je voice-resource.
- Noclip, god mode en onzichtbaarheid zijn client-side gameplay-toggles. Gebruik uitsluitend met vertrouwde ACE-rechten en controleer eventuele framework- of anticheatregels.
- Discord-webhooks en database-auditlogs bevatten beheeractiegegevens. Stel toegang en bewaartermijn passend in voor je server.

## Commando's en exports

- `/admin` of F10: open het adminmenu (ACE vereist).
- `/kroon_unban license:...`: verwijder bans voor die license (console of ACE-beheerder).
- `exports['kroon_admin']:HasPermission(source)`: controleer de ingestelde ACE-permission.
- `exports['kroon_admin']:GetPlayerWarnings(license)`: haal waarschuwingen voor een FiveM license identifier op.

## Bestanden

- `fxmanifest.lua`: FiveM resource-metadata en scripts.
- `config.lua`: permissions, webhook, limieten en locaties.
- `server.lua`, `client.lua`, `nui.lua`: autorisatie, events en gameplay/NUI-brug.
- `database.lua`, `sql/schema.sql`: database-initialisatie en schema.
- `web/src`: React-interface en styling.
- `web/dist`: NUI-output die door FiveM geladen wordt.

## Staffwebpanel (zelf hosten)

Het staffwebpanel is een afzonderlijke Node.js-service die met een gedeeld geheim met de FiveM-resource communiceert. Het is optioneel; de in-game NUI blijft werken als het panel uit staat. Deze repository levert de code en deploymentbestanden, maar **host of publiceer het panel niet**. Je hebt zelf een VPS, domein en TLS-certificaat nodig. Gebruik Node.js 20 of hoger.

### FiveM-server configuratie

Genereer een lang, willekeurig geheim op de VPS:

```sh
openssl rand -hex 32
```

Gebruik hetzelfde token in de `server.cfg` van FiveM en het afgeschermde omgevingsbestand van het panel. Bewaar echte tokens en wachtwoordhashes buiten Git:

```cfg
set kroon_admin_panel_token "PLAK_HIER_HET_64_TEKENS_LANGE_HEX_TOKEN"
ensure oxmysql
ensure kroon_admin
```

De resource registreert de HTTP-bridge alleen als deze convar is ingesteld. De panelservice praat standaard uitsluitend via `127.0.0.1:30120`; stel dit niet in op een openbaar of extern adres. De bridge controleert het gedeelde token op elke aanvraag. `SetHttpHandler` is een gedeelde FiveM-serverhandler: controleer of een andere resource deze al registreert voordat je de panel-API inschakelt.

### Staffaccounts en panel bouwen

Maak voor elk staffaccount een aparte scrypt-hash; wachtwoorden worden niet als plaintext opgeslagen. Voer dit uit op de VPS en plak de JSON-uitvoer in `PANEL_USERS_JSON`:

```sh
read -s -p "Staffwachtwoord: " PANEL_PASSWORD; echo
printf '%s' "$PANEL_PASSWORD" | node /opt/kroon_admin/staff-panel/hash-password.mjs
unset PANEL_PASSWORD
```

Kopieer `staff-panel/.env.example` buiten de repository naar `/etc/kroon_admin/staff-panel.env`. Vul `PANEL_ORIGIN` in met de publieke HTTPS-origin, plaats de account-hashes in `PANEL_USERS_JSON` en gebruik hetzelfde willekeurige token als in `server.cfg`. Beperk de toegang tot het env-bestand:

```sh
sudo chown root:kroon-admin /etc/kroon_admin/staff-panel.env
sudo chmod 640 /etc/kroon_admin/staff-panel.env
cd /opt/kroon_admin
npm ci
npm run build:panel
```

Maak een beperkte Linux-servicegebruiker aan, installeer de repo in `/opt/kroon_admin` en zorg dat die gebruiker de resourcebestanden en gebouwde frontend kan lezen. Installeer de meegeleverde `staff-panel/deploy/kroon-admin-panel.service` als `/etc/systemd/system/kroon-admin-panel.service` (pas `/opt/kroon_admin` in de unit aan als je een andere installatiemap kiest), daarna:

```sh
sudo useradd --system --no-create-home --shell /usr/sbin/nologin kroon-admin
sudo install -d -o root -g kroon-admin -m 750 /etc/kroon_admin
sudo install -o root -g kroon-admin -m 640 staff-panel/.env.example /etc/kroon_admin/staff-panel.env
sudoedit /etc/kroon_admin/staff-panel.env
sudo install -o root -g root -m 644 staff-panel/deploy/kroon-admin-panel.service /etc/systemd/system/kroon-admin-panel.service
sudo systemctl daemon-reload
sudo systemctl enable --now kroon-admin-panel
sudo systemctl status kroon-admin-panel
```

De Node-service bindt bewust alleen op `127.0.0.1`.

Voor updates: haal je eigen deployment bij, voer `npm ci && npm run build:panel` uit en herstart de systemd-service. De React-source staat in `staff-panel/ui`; productie-output staat in `staff-panel/public`.

### HTTPS reverse proxy (Nginx voorbeeld)

Configureer eerst TLS voor je domein (bijvoorbeeld met Certbot). Plaats binnen de HTTPS `server`-sectie:

```nginx
location / {
    proxy_pass http://127.0.0.1:3080;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
    proxy_set_header X-Forwarded-Proto https;
}
```

De Node-service vertrouwt `X-Real-IP` alleen omdat hij op loopback hoort te binden en de reverse proxy deze header overschrijft. Laat poort 3080 niet publiek toegankelijk zijn. Configureer de firewall alleen voor SSH, HTTPS en de benodigde FiveM-poorten.

### Panelfuncties en beveiliging

- Login vereist staffaccounts met wachtwoordhashes; accounts en wachtwoorden worden niet in de repository gezet.
- Elk account heeft volledige staffbevoegdheden; er is geen rol- of permissieniveau per account.
- Sessies zijn tijdelijk, in-memory, `HttpOnly`, `Secure` en `SameSite=Strict`. POST-aanvragen vereisen een geldige origin en CSRF-token; aanmeldpogingen worden beperkt.
- Het panel gebruikt dezelfde server-side acties: kick, ban, warn, mute, freeze, revive, geld/items, voertuigen, toggles, teleport naar opgeslagen locaties, servermededelingen en auditgeschiedenis. Geld/items vereisen ESX of QBCore.
- God mode, noclip, onzichtbaarheid en teleportlocaties worden vanaf het panel op de geselecteerde speler toegepast. Een webbrowser heeft geen in-game waypoint of eigen FiveM-personage, dus `goto`, `bring` en waypoint-teleport zijn bewust niet beschikbaar in het webpanel.
- De gebruikerslijst en auditgeschiedenis zijn alleen na aanmelden beschikbaar; ongeldige of verlopen sessies moeten opnieuw aanmelden.
- Het panelproces houdt sessies tijdelijk in geheugen; na een serviceherstart melden staffleden zich opnieuw aan. Deel geen tokens of wachtwoordhashes en zet het panel niet online zonder HTTPS.
