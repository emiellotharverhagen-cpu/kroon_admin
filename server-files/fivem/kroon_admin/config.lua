Config = {}

Config.Permission = 'kroon_admin'
Config.Command = 'admin'
Config.Webhook = '' -- Vul hier optioneel een Discord webhook URL in.
Config.WebhookName = 'Kroon Admin'
Config.MaxReasonLength = 240
Config.MaxAnnouncementLength = 500
Config.MaxMoney = 1000000
Config.MaxItemCount = 1000
Config.BanDefaultDays = 0 -- 0 betekent permanent.
Config.LogLimit = 100

Config.Tables = {
    bans = 'kroon_admin_bans',
    warnings = 'kroon_admin_warnings',
    logs = 'kroon_admin_logs'
}

Config.SavedLocations = {
    { label = 'Centrum', coords = { x = 215.76, y = -810.12, z = 30.73, heading = 157.0 } },
    { label = 'Ziekenhuis', coords = { x = 298.62, y = -584.27, z = 43.26, heading = 70.0 } },
    { label = 'Politiebureau', coords = { x = 425.13, y = -979.56, z = 30.71, heading = 90.0 } }
}

Config.Locale = {
    noPermission = 'Je hebt geen toestemming voor deze actie.',
    invalidPlayer = 'Speler niet gevonden.',
    kicked = 'Je bent van de server verwijderd.',
    banned = 'Je bent verbannen van deze server.',
    muted = 'Je bent tijdelijk gedempt door een beheerder.',
    unmuted = 'Je mag weer spreken.',
    announcement = 'SERVERMEDEDELING'
}
