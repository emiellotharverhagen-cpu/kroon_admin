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

-- Toetsen
-- Staffdienst (F11) en menu (F9) worden via RegisterKeyMapping gebonden zodat
-- spelers ze zelf kunnen aanpassen in Instellingen > Keybindings > FiveM.

-- Noclip (TxAdmin-stijl)
-- De toggle-toets is instelbaar via GTA: Instellingen > Keybindings > FiveM
-- (commando: kroon_noclip, standaard Page Down). De onderstaande controls zijn
-- de bediening terwijl noclip actief is (GTA control ids).
Config.Noclip = {
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
