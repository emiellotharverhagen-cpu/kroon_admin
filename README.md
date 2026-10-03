# kroon_admin

Volledig **ingame** staffpanel voor FiveM (Lua + NUI), vergelijkbaar met QS-AdminMenu. Geen externe website nodig — alles gebeurt ingame.

## Features

- **F11 — Staffdienst**: trekt automatisch staffkleding aan (configureerbaar in `config.lua`), oude outfit wordt hersteld bij uitdienst gaan.
- **F9 — Staffmenu** (alleen in staffdienst):
  - **Spelerslijst** met naam, ID, ping en group
  - **Spectate** (camera volgt de speler, staff is onzichtbaar)
  - **Kick** met reden
  - **Warn** met reden + warns-overzicht per speler (opgeslagen in `data/warns.json`)
  - **Ga naar / Breng** teleports
- **Garage (okokGarage)**: alle voertuigen van spelers bekijken, **spawnen**, **repareren** en **verwijderen** op kenteken.
- **Inventory (ox_inventory)**: inventory van elke speler openen, items **bekijken**, **geven** en **wegnemen** (met slot-ondersteuning).
- **Noclip zoals in TxAdmin**: rechtermuisknop togglet (tijdens staffdienst), muis kijkt rond, WASD beweegt, Q/E omhoog/omlaag, Shift = snel, Alt = traag.

## Groups

De resource gebruikt de bestaande groups `group.admin` en `group.staff` via ACE principals.

## Installatie

1. Plaats de map `kroon_admin` in je `resources` folder.
2. Zorg dat `ox_inventory` en `okokGarage` gestart zijn.
3. Voeg toe aan je `server.cfg`:

```cfg
ensure kroon_admin

# Geef staff toegang (vervang door de echte licenses)
add_principal identifier.license:JOUWLICENSE group.admin
add_principal identifier.license:ANDERELICENSE group.staff

# Rechten voor deze resource
add_ace group.admin kroon_admin.admin allow
add_ace group.staff kroon_admin.staff allow
```

Alternatief: zet vaste licenses in `config.lua` onder `Config.AdminLicenses` en/of zet `Config.UseAceGroups = false`.

## Configuratie

Alles staat in `config.lua`:

- `Config.Noclip` — noclip controls en snelheden
- `Config.AdminOutfits` — staffkleding per model (male/female)
- `Config.Garage.ExportCandidates` — export-namen die geprobeerd worden voor okokGarage

De toetsen **F11** (staffdienst) en **F9** (menu) worden via `RegisterKeyMapping` gebonden;
spelers kunnen ze zelf aanpassen via *Instellingen → Keybindings → FiveM*.

## Bestandsstructuur

```
kroon_admin/
├── fxmanifest.lua
├── config.lua          # alle instellingen
├── client/main.lua     # staffdienst, kleding, noclip, spectate, NUI callbacks
├── server/main.lua     # auth, acties, okokGarage + ox_inventory integratie
├── web/index.html      # ingame staffmenu (NUI)
└── data/warns.json     # warns (wordt automatisch aangemaakt, zit in .gitignore)
```

## Afhankelijkheden

- [ox_inventory](https://github.com/overextended/ox_inventory)
- okokGarage
