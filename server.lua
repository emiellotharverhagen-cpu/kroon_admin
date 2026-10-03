local mutedPlayers = {}

local function hasPermission(source)
    return source == 0 or IsPlayerAceAllowed(source, Config.Permission)
end

local function getLicense(source)
    for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
        if identifier:sub(1, 8) == 'license:' then
            return identifier
        end
    end
    return GetPlayerIdentifiers(source)[1] or ('source:%s'):format(source)
end

local function playerName(source)
    return GetPlayerName(source) or 'Onbekend'
end

local function safeText(value, maxLength)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[\r\n]', ' '):gsub('^%s*(.-)%s*$', '%1')
    return value:sub(1, maxLength)
end

local function logAction(admin, action, target, details)
    local adminName = admin == 0 and 'Console' or playerName(admin)
    local adminLicense = admin ~= 0 and getLicense(admin) or nil
    local targetName = target and playerName(target) or nil
    local targetLicense = target and getLicense(target) or nil
    local detailText = safeText(details or '', 1000)
    MySQL.insert(('INSERT INTO `%s` (admin_name, admin_license, action, target_name, target_license, details) VALUES (?, ?, ?, ?, ?, ?)'):format(Config.Tables.logs), {
        adminName, adminLicense, action, targetName, targetLicense, detailText
    })
    if Config.Webhook and Config.Webhook ~= '' then
        PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
            username = Config.WebhookName,
            embeds = { {
                title = ('Beheeractie: %s'):format(action),
                description = ('**Beheerder:** %s\n**Speler:** %s\n**Details:** %s'):format(adminName, targetName or '-', detailText),
                color = 15158332
            } }
        }), { ['Content-Type'] = 'application/json' })
    end
end

local function deny(source)
    TriggerClientEvent('kroon_admin:client:notify', source, Config.Locale.noPermission, 'error')
end

local function requirePermission(source)
    if hasPermission(source) then return true end
    deny(source)
    return false
end

local function validTarget(source, target)
    target = tonumber(target)
    if not target or target <= 0 or not GetPlayerName(target) or target == source then
        TriggerClientEvent('kroon_admin:client:notify', source, Config.Locale.invalidPlayer, 'error')
        return nil
    end
    return target
end

local function getFramework()
    if GetResourceState('qb-core') == 'started' then
        return 'qb', exports['qb-core']:GetCoreObject()
    end
    if GetResourceState('es_extended') == 'started' then
        return 'esx', exports['es_extended']:getSharedObject()
    end
    return nil, nil
end

local function findPlayerByLicense(license)
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if getLicense(src) == license then return src end
    end
end

RegisterNetEvent('kroon_admin:server:requestOpen', function()
    local source = source
    if not requirePermission(source) then return end
    TriggerClientEvent('kroon_admin:client:open', source)
end)

RegisterNetEvent('kroon_admin:server:requestPlayers', function()
    local source = source
    if not requirePermission(source) then return end
    local players = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        players[#players + 1] = {
            id = src,
            name = playerName(src),
            ping = GetPlayerPing(src),
            identifiers = { license = getLicense(src) },
            muted = mutedPlayers[src] == true
        }
    end
    TriggerClientEvent('kroon_admin:client:players', source, players)
end)

RegisterNetEvent('kroon_admin:server:requestLogs', function()
    local source = source
    if not requirePermission(source) then return end
    local rows = MySQL.query.await(('SELECT id, admin_name, action, target_name, details, created_at FROM `%s` ORDER BY id DESC LIMIT ?'):format(Config.Tables.logs), { Config.LogLimit })
    TriggerClientEvent('kroon_admin:client:logs', source, rows or {})
end)

RegisterNetEvent('kroon_admin:server:action', function(data)
    local source = source
    if not requirePermission(source) or type(data) ~= 'table' then return end
    local action = safeText(data.action, 40)
    local target = validTarget(source, data.target)
    local reason = safeText(data.reason, Config.MaxReasonLength)
    if not target then return end
    local targetName, targetLicense = playerName(target), getLicense(target)

    if action == 'kick' then
        DropPlayer(target, reason ~= '' and reason or Config.Locale.kicked)
        logAction(source, action, target, reason)
    elseif action == 'ban' then
        if reason == '' then reason = 'Geen reden opgegeven' end
        local days = math.max(0, math.min(3650, tonumber(data.days) or Config.BanDefaultDays))
        local expiresAt = days > 0 and os.date('%Y-%m-%d %H:%M:%S', os.time() + days * 86400) or nil
        MySQL.insert.await(('INSERT INTO `%s` (name, license, reason, admin, expires_at) VALUES (?, ?, ?, ?, ?)'):format(Config.Tables.bans), {
            targetName, targetLicense, reason, playerName(source), expiresAt
        })
        logAction(source, action, target, reason)
        DropPlayer(target, ('%s Reden: %s'):format(Config.Locale.banned, reason))
    elseif action == 'warn' then
        if reason == '' then reason = 'Geen reden opgegeven' end
        MySQL.insert(('INSERT INTO `%s` (player_name, license, reason, admin) VALUES (?, ?, ?, ?)'):format(Config.Tables.warnings), {
            targetName, targetLicense, reason, playerName(source)
        })
        TriggerClientEvent('kroon_admin:client:notify', target, ('Waarschuwing: %s'):format(reason), 'error')
        logAction(source, action, target, reason)
    elseif action == 'mute' or action == 'unmute' then
        local isMuted = action == 'mute'
        mutedPlayers[target] = isMuted and true or nil
        TriggerClientEvent('kroon_admin:client:setMuted', target, isMuted)
        TriggerClientEvent('kroon_admin:client:notify', target, isMuted and Config.Locale.muted or Config.Locale.unmuted, 'info')
        logAction(source, action, target, reason)
    elseif action == 'freeze' or action == 'unfreeze' then
        TriggerClientEvent('kroon_admin:client:freeze', target, action == 'freeze')
        logAction(source, action, target, reason)
    elseif action == 'goto' then
        TriggerClientEvent('kroon_admin:client:teleportTo', source, GetEntityCoords(GetPlayerPed(target)), GetEntityHeading(GetPlayerPed(target)))
        logAction(source, action, target, '')
    elseif action == 'bring' then
        TriggerClientEvent('kroon_admin:client:teleportTo', target, GetEntityCoords(GetPlayerPed(source)), GetEntityHeading(GetPlayerPed(source)))
        logAction(source, action, target, '')
    elseif action == 'revive' then
        TriggerClientEvent('kroon_admin:client:revive', target)
        logAction(source, action, target, '')
    else
        TriggerClientEvent('kroon_admin:client:notify', source, 'Onbekende speleractie.', 'error')
    end
end)

RegisterNetEvent('kroon_admin:server:tool', function(data)
    local source = source
    if not requirePermission(source) or type(data) ~= 'table' then return end
    local action = safeText(data.action, 40)
    if action == 'announce' then
        local message = safeText(data.message, Config.MaxAnnouncementLength)
        if message == '' then return end
        TriggerClientEvent('kroon_admin:client:announce', -1, playerName(source), message)
        logAction(source, action, nil, message)
    elseif action == 'teleportWaypoint' or action == 'teleportLocation' then
        if action == 'teleportWaypoint' then
            TriggerClientEvent('kroon_admin:client:teleportWaypoint', source)
        else
            local index = tonumber(data.index)
            local location = index and Config.SavedLocations[index]
            if not location then return end
            TriggerClientEvent('kroon_admin:client:teleportTo', source, location.coords, location.coords.heading)
        end
        logAction(source, action, nil, safeText(data.label, 100))
    elseif action == 'giveMoney' or action == 'giveItem' then
        local target = validTarget(source, data.target)
        if not target then return end
        local framework, core = getFramework()
        if not framework then
            TriggerClientEvent('kroon_admin:client:notify', source, 'Geld/items geven vereist ESX of QBCore.', 'error')
            return
        end
        local amount = math.floor(tonumber(data.amount) or 0)
        if amount <= 0 or amount > (action == 'giveMoney' and Config.MaxMoney or Config.MaxItemCount) then return end
        local ok, err = pcall(function()
            if action == 'giveMoney' then
                local account = safeText(data.account, 20)
                if framework == 'qb' then
                    local player = core.Functions.GetPlayer(target)
                    if not player then error('Speler niet geladen') end
                    player.Functions.AddMoney(account == 'bank' and 'bank' or 'cash', amount, 'kroon_admin')
                else
                    local player = core.GetPlayerFromId(target)
                    if not player then error('Speler niet geladen') end
                    player.addAccountMoney(account == 'bank' and 'bank' or 'money', amount)
                end
            else
                local item = safeText(data.item, 50)
                if item == '' then error('Itemnaam ontbreekt') end
                if framework == 'qb' then
                    local player = core.Functions.GetPlayer(target)
                    if not player or not player.Functions.AddItem(item, amount) then error('Item kon niet worden toegevoegd') end
                else
                    local player = core.GetPlayerFromId(target)
                    if not player then error('Speler niet geladen') end
                    player.addInventoryItem(item, amount)
                end
            end
        end)
        if not ok then
            print(('[kroon_admin] Uitdelen mislukt: %s'):format(err))
            TriggerClientEvent('kroon_admin:client:notify', source, 'Uitdelen is mislukt; controleer framework en itemnaam.', 'error')
            return
        end
        logAction(source, action, target, ('%s x%s'):format(action == 'giveItem' and safeText(data.item, 50) or safeText(data.account, 20), amount))
    elseif action == 'spawnVehicle' then
        local model = safeText(data.model, 50):lower()
        if not model:match('^[%w_]+$') then return end
        TriggerClientEvent('kroon_admin:client:spawnVehicle', source, model)
        logAction(source, action, nil, model)
    elseif action == 'toggle' then
        local allowed = { godmode = true, noclip = true, invisible = true }
        if not allowed[data.toggle] then return end
        TriggerClientEvent('kroon_admin:client:toggle', source, data.toggle)
        logAction(source, data.toggle, nil, '')
    else
        TriggerClientEvent('kroon_admin:client:notify', source, 'Onbekende beheeractie.', 'error')
    end
end)

AddEventHandler('playerConnecting', function(_, _, deferrals)
    local source = source
    deferrals.defer()
    Wait(0)
    local license = getLicense(source)
    local ban = MySQL.single.await(('SELECT reason, expires_at FROM `%s` WHERE license = ? AND (expires_at IS NULL OR expires_at > NOW()) ORDER BY id DESC LIMIT 1'):format(Config.Tables.bans), { license })
    if ban then
        deferrals.done(('%s Reden: %s'):format(Config.Locale.banned, ban.reason))
    else
        deferrals.done()
    end
end)

AddEventHandler('playerDropped', function()
    mutedPlayers[source] = nil
end)

RegisterCommand('kroon_unban', function(source, args)
    if source ~= 0 and not requirePermission(source) then return end
    local license = safeText(args[1] or '', 80)
    if license == '' then
        if source ~= 0 then TriggerClientEvent('kroon_admin:client:notify', source, 'Gebruik: /kroon_unban license:...', 'error') end
        return
    end
    local affected = MySQL.update.await(('DELETE FROM `%s` WHERE license = ?'):format(Config.Tables.bans), { license })
    logAction(source, 'unban', nil, ('%s (%s regels)'):format(license, affected or 0))
    if source ~= 0 then TriggerClientEvent('kroon_admin:client:notify', source, 'Verbanning verwijderd.', 'success') end
end, false)

exports('HasPermission', hasPermission)
exports('GetPlayerWarnings', function(license)
    return MySQL.query.await(('SELECT id, reason, admin, created_at FROM `%s` WHERE license = ? ORDER BY id DESC'):format(Config.Tables.warnings), { license })
end)
