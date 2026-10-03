Config = {}

-- ══════════════════════════════════════════════════════════════
--  Kroon Admin - Configuratie
-- ══════════════════════════════════════════════════════════════

-- Welke spelers mogen het staffmenu gebruiken.
-- Groepen worden bepaald via ACE principals (server.cfg):
--   add_principal identifier.license:JOUWLICENSE group.admin
--   add_principal identifier.license:ANDERELICENSE group.staff
-- Zet Config.AdminLicenses aan als je daarnaast een vaste lijst wilt gebruiken.
Config.UseAceGroups = true
Config.AdminLicenses = {
    -- 'license:1234567890abcdef1234567890abcdef12345678',
}

-- Gedeeld geheim tussen de FiveM resource en het web staffpanel.
-- Stel dit in via server.cfg (verander dit naar iets unieks!):
--   setr kroon_admin_panel_token "jouw-super-geheime-token"
-- Gebruik dezelfde waarde als PANEL_SHARED_TOKEN in staff-panel/server.mjs
Config.PanelTokenConvar = 'kroon_admin_panel_token'

-- Toetsen (GTA control ids)
Config.Keys = {
    StaffDuty = 344,   -- F11
    Menu      = 56,    -- F9
}

-- Noclip (TxAdmin-stijl: rechtermuisknop togglet, muis-look, WASD bewegen)
Config.Noclip = {
    ToggleControl = 25,     -- INPUT_AIM (rechtermuisknop) terwijl staffdienst aan staat
    Forward       = 32,     -- W
    Backward      = 33,     -- S
    Left          = 34,     -- A
    Right         = 35,     -- D
    Up            = 44,     -- Q
    Down          = 46,     -- E
    Boost         = 21,     -- Shift
    Slow          = 19,     -- Alt
    BaseSpeed     = 0.6,    -- snelheid per frame bij normale stand
    BoostMult     = 6.0,
    SlowMult      = 0.25,
    MaxSpeed      = 4.0,
}

-- Kleding die automatisch wordt aangetrokken bij het aangaan van staffdienst.
-- De oude outfit wordt opgeslagen en hersteld bij het verlaten van staffdienst.
Config.AdminOutfits = {
    male = {
        model = 'mp_m_freemode_01',
        components = {
            { component = 1,  drawable = 121, texture = 0 },  -- masker
            { component = 3,  drawable = 1,   texture = 0 },  -- armen
            { component = 4,  drawable = 52,  texture = 2 },  -- broek
            { component = 6,  drawable = 24,  texture = 0 },  -- schoenen
            { component = 8,  drawable = 15,  texture = 0 },  -- shirt
            { component = 11, drawable = 250, texture = 0 },  -- jas
        },
    },
    female = {
        model = 'mp_f_freemode_01',
        components = {
            { component = 1,  drawable = 121, texture = 0 },
            { component = 3,  drawable = 1,   texture = 0 },
            { component = 4,  drawable = 52,  texture = 2 },
            { component = 6,  drawable = 24,  texture = 0 },
            { component = 8,  drawable = 15,  texture = 0 },
            { component = 11, drawable = 250, texture = 0 },
        },
    },
}

-- okokGarage: pas dit export-patroon aan als jouw versie een andere exportnaam gebruikt.
-- De resource probeert automatisch meerdere veelgebruikte exports.
Config.Garage = {
    ExportCandidates = {
        'getAllVehicles',
        'getGarageVehicles',
        'GetAllVehicles',
    },
}

-- ox_inventory
Config.OxInventoryResource = 'ox_inventory'

-- Web staffpanel standaardpoort (alleen ter info, de poort staat in staff-panel/server.mjs)
Config.PanelPort = 30121
