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
