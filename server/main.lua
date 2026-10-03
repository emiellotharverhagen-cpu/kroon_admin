-- ══════════════════════════════════════════════════════════════
--  Kroon Admin - Server
--  Auth (ACE groups + license lijst), staffdienst, spelersbeheer,
--  okokGarage voertuigen, ox_inventory, warns, noclip/spectate sync
-- ══════════════════════════════════════════════════════════════

--- Auth ---------------------------------------------------------

local function IsLicenseAdmin(src)
    if not Config.AdminLicenses then return false end
    local license
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, 8) == 'license:' then license = id break end
    end
    if not license then return false end
    for _, allowed in ipairs(Config.AdminLicenses) do
        if allowed == license then return true end
    end
    return false
end

--- Bepaalt of de speler staff is (group.admin / group.staff of license lijst)
function IsStaff(src)
    if not src or src == 0 then return false end
    if Config.UseAceGroups then
        if IsPlayerAceAllowed(src, 'kroon_admin.admin')
            or IsPlayerAceAllowed(src, 'kroon_admin.staff')
            or IsPlayerAceAllowed(src, 'group.admin')
            or IsPlayerAceAllowed(src, 'group.staff') then
            return true
        end
    end
    return IsLicenseAdmin(src)
end

--- Bepaalt de hoogste group van een speler: 'admin', 'staff' of nil
function GetStaffGroup(src)
    if Config.UseAceGroups then
        if IsPlayerAceAllowed(src, 'kroon_admin.admin') or IsPlayerAceAllowed(src, 'group.admin') then
            return 'admin'
        end
        if IsPlayerAceAllowed(src, 'kroon_admin.staff') or IsPlayerAceAllowed(src, 'group.staff') then
            return 'staff'
        end
    end
    if IsLicenseAdmin(src) then return 'admin' end
    return nil
end

--- Helpers ------------------------------------------------------

local function GetIdentifier(src, kind)
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and id:sub(1, #kind + 1) == kind .. ':' then return id end
    end
    return nil
end

--- Warns (bestand-gebaseerd, geen DB nodig) ----------------------

local Warns = nil

local function LoadWarns()
    if Warns then return Warns end
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/warns.json')
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        Warns = (ok and decoded) or {}
    else
        Warns = {}
    end
    return Warns
end

local function SaveWarns()
    if not Warns then return end
    SaveResourceFile(GetCurrentResourceName(), 'data/warns.json', json.encode(Warns, { indent = true }), -1)
end

--- Staffdienst state ---------------------------------------------

local OnDuty = {}      -- [src] = true
local Noclippers = {}  -- [src] = true (voor noclip sync tussen staff)

RegisterNetEvent('kroon_admin:server:toggleDuty', function()
    local src = source
    if not IsStaff(src) then return end
    if OnDuty[src] then OnDuty[src] = nil else OnDuty[src] = true end
    local state = OnDuty[src] == true
    TriggerClientEvent('kroon_admin:client:dutyState', src, state)
    print(('[kroon_admin] %s (%s) is nu %s staffdienst'):format(
        GetPlayerName(src) or 'onbekend', src, state and 'IN' or 'UIT'))
end)

AddEventHandler('playerDropped', function()
    OnDuty[source] = nil
    Noclippers[source] = nil
end)

--- Spelerslijst ---------------------------------------------------

local function BuildPlayerList()
    local list = {}
    for _, pid in ipairs(GetPlayers()) do
        pid = tonumber(pid)
        local ped = GetEntityCoords(GetPlayerPed(pid))
        list[#list + 1] = {
            id = pid,
            name = GetPlayerName(pid) or 'onbekend',
            license = GetIdentifier(pid, 'license'),
            ping = GetPlayerPing(pid),
            group = GetStaffGroup(pid),
            onDuty = OnDuty[pid] == true,
            coords = ped and { x = ped.x, y = ped.y, z = ped.z } or nil,
        }
    end
    return list
end

RegisterNetEvent('kroon_admin:server:getPlayers', function()
    local src = source
    if not IsStaff(src) then return end
    TriggerClientEvent('kroon_admin:client:receivePlayers', src, BuildPlayerList())
end)

--- Kick / Warn / Teleport / Spectate -------------------------------

RegisterNetEvent('kroon_admin:server:kick', function(targetId, reason)
    local src = source
    if not IsStaff(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    reason = tostring(reason or 'Geen reden opgegeven'):sub(1, 128)
    print(('[kroon_admin] %s kickt %s (%s): %s'):format(
        GetPlayerName(src) or '?', GetPlayerName(targetId) or '?', targetId, reason))
    DropPlayer(targetId, ('[Kroon Staff] Je bent gekickt. Reden: %s'):format(reason))
end)

RegisterNetEvent('kroon_admin:server:warn', function(targetId, reason)
    local src = source
    if not IsStaff(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    reason = tostring(reason or 'Geen reden opgegeven'):sub(1, 128)
    local license = GetIdentifier(targetId, 'license') or ('id:' .. targetId)
    local warns = LoadWarns()
    warns[license] = warns[license] or {}
    warns[license][#warns[license] + 1] = {
        reason = reason,
        by = GetPlayerName(src) or 'onbekend',
        at = os.date('%Y-%m-%d %H:%M:%S'),
    }
    SaveWarns()
    TriggerClientEvent('chat:addMessage', targetId, {
        color = { 255, 60, 60 },
        args = { '[Kroon Staff]', ('Je hebt een warn ontvangen: %s'):format(reason) },
    })
    TriggerClientEvent('kroon_admin:client:notify', src, ('Warn gegeven aan %s'):format(GetPlayerName(targetId) or targetId))
end)

RegisterNetEvent('kroon_admin:server:getWarns', function(targetId)
    local src = source
    if not IsStaff(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    local license = GetIdentifier(targetId, 'license') or ('id:' .. targetId)
    local warns = LoadWarns()[license] or {}
    TriggerClientEvent('kroon_admin:client:receiveWarns', src, targetId, warns)
end)

RegisterNetEvent('kroon_admin:server:goto', function(targetId)
    local src = source
    if not IsStaff(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    local coords = GetEntityCoords(GetPlayerPed(targetId))
    if coords then
        TriggerClientEvent('kroon_admin:client:goto', src, { x = coords.x, y = coords.y, z = coords.z })
    end
end)

RegisterNetEvent('kroon_admin:server:bring', function(targetId)
    local src = source
    if not IsStaff(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    local coords = GetEntityCoords(GetPlayerPed(src))
    if coords then
        TriggerClientEvent('kroon_admin:client:goto', targetId, { x = coords.x, y = coords.y, z = coords.z })
    end
end)

RegisterNetEvent('kroon_admin:server:spectate', function(targetId)
    local src = source
    if not IsStaff(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    local coords = GetEntityCoords(GetPlayerPed(targetId))
    if coords then
        TriggerClientEvent('kroon_admin:client:spectate', src, targetId,
            { x = coords.x, y = coords.y, z = coords.z })
    end
end)

--- Noclip sync (broadcast state zodat staff elkaar kan zien) -------

RegisterNetEvent('kroon_admin:server:noclipState', function(active)
    local src = source
    if not IsStaff(src) then return end
    Noclippers[src] = active and true or nil
    for _, pid in ipairs(GetPlayers()) do
        pid = tonumber(pid)
        if pid ~= src and OnDuty[pid] then
            TriggerClientEvent('kroon_admin:client:noclipState', pid, src, active == true)
        end
    end
end)

--- okokGarage integratie -------------------------------------------

local function GetAllGarageVehicles()
    local g = exports['okokGarage']
    if not g then return {} end
    for _, name in ipairs(Config.Garage.ExportCandidates or {}) do
        local ok, result = pcall(function() return g[name](g) end)
        if ok and type(result) == 'table' then return result end
    end
    return {}
end

local function NormalizeVehicles(raw)
    local out = {}
    if type(raw) ~= 'table' then return out end
    for _, v in pairs(raw) do
        if type(v) == 'table' then
            local plate = v.plate or v.vehicle_plate or v.platenumber
            local owner = v.owner or v.identifier or v.citizenid or v.owner_identifier
            local model = v.vehicle or v.model or v.model_name or v.vehicle_name
            out[#out + 1] = {
                plate = plate and tostring(plate) or nil,
                owner = owner and tostring(owner) or nil,
                model = model and tostring(model) or 'onbekend',
                garage = v.garage or v.garage_name,
                stored = v.stored or v.state or v.parked,
                fuel = v.fuel or v.fuelLevel,
                engine = v.engine or v.engineHealth,
                body = v.body or v.bodyHealth,
                raw = v,
            }
        end
    end
    return out
end

RegisterNetEvent('kroon_admin:server:getGarageVehicles', function(filterOwner)
    local src = source
    if not IsStaff(src) then return end
    local vehicles = NormalizeVehicles(GetAllGarageVehicles())
    if filterOwner and filterOwner ~= '' then
        local filtered = {}
        for _, v in ipairs(vehicles) do
            if v.owner == filterOwner then filtered[#filtered + 1] = v end
        end
        vehicles = filtered
    end
    TriggerClientEvent('kroon_admin:client:receiveGarageVehicles', src, vehicles)
end)

RegisterNetEvent('kroon_admin:server:vehicleAction', function(action, plate)
    local src = source
    if not IsStaff(src) then return end
    plate = tostring(plate or '')
    if plate == '' then return end
    action = tostring(action)
    if action == 'spawn' then
        local vehicle
        for _, v in ipairs(NormalizeVehicles(GetAllGarageVehicles())) do
            if v.plate == plate then vehicle = v break end
        end
        if not vehicle then
            TriggerClientEvent('kroon_admin:client:notify', src, 'Voertuig niet gevonden in garage.')
            return
        end
        TriggerClientEvent('kroon_admin:client:spawnVehicle', src, vehicle.model, plate)
    elseif action == 'repair' then
        TriggerClientEvent('kroon_admin:client:repairVehicleByPlate', src, plate)
    elseif action == 'delete' then
        TriggerClientEvent('kroon_admin:client:deleteVehicleByPlate', src, plate)
    end
end)

--- ox_inventory integratie ------------------------------------------

local function GetOxInventory()
    local ok, ox = pcall(function() return exports[Config.OxInventoryResource or 'ox_inventory'] end)
    if ok then return ox end
    return nil
end

local function NormalizeInventory(inv)
    local items = {}
    if type(inv) ~= 'table' then return items end
    local slotSource = inv.items or inv
    for _, item in pairs(slotSource) do
        if type(item) == 'table' and item.name then
            items[#items + 1] = {
                slot = item.slot,
                name = item.name,
                label = item.label or item.name,
                count = item.count or item.amount or 1,
                metadata = item.metadata or item.info,
            }
        end
    end
    return items
end

RegisterNetEvent('kroon_admin:server:getInventory', function(targetId)
    local src = source
    if not IsStaff(src) then return end
    targetId = tonumber(targetId)
    if not targetId or not GetPlayerName(targetId) then return end
    local ox = GetOxInventory()
    if not ox then
        TriggerClientEvent('kroon_admin:client:notify', src, 'ox_inventory export niet beschikbaar.')
        return
    end
    local ok, inv = pcall(function() return ox:GetInventory(targetId) end)
    if not ok or not inv then
        TriggerClientEvent('kroon_admin:client:notify', src, 'Kon inventory niet openen.')
        return
    end
    TriggerClientEvent('kroon_admin:client:receiveInventory', src, targetId, NormalizeInventory(inv))
end)

RegisterNetEvent('kroon_admin:server:inventoryGive', function(targetId, item, count)
    local src = source
    if not IsStaff(src) then return end
    targetId, count = tonumber(targetId), tonumber(count) or 1
    if not targetId or not GetPlayerName(targetId) then return end
    item = tostring(item or '')
    if item == '' or count < 1 or count > 10000 then return end
    local ox = GetOxInventory()
    if not ox then return end
    local ok = pcall(function() ox:AddItem(targetId, item, count) end)
    if ok then
        TriggerClientEvent('kroon_admin:client:notify', src, ('%dx %s gegeven.'):format(count, item))
        TriggerClientEvent('kroon_admin:server:getInventory', src, targetId)
    end
end)

RegisterNetEvent('kroon_admin:server:inventoryRemove', function(targetId, item, count, slot)
    local src = source
    if not IsStaff(src) then return end
    targetId, count = tonumber(targetId), tonumber(count) or 1
    if not targetId or not GetPlayerName(targetId) then return end
    item = tostring(item or '')
    if item == '' or count < 1 or count > 10000 then return end
    local ox = GetOxInventory()
    if not ox then return end
    local ok
    if slot then
        ok = pcall(function() ox:RemoveItem(targetId, item, count, nil, tonumber(slot)) end)
    else
        ok = pcall(function() ox:RemoveItem(targetId, item, count) end)
    end
    if ok then
        TriggerClientEvent('kroon_admin:client:notify', src, ('%dx %s weggenomen.'):format(count, item))
        TriggerClientEvent('kroon_admin:server:getInventory', src, targetId)
    end
end)

-- Web staffpanel is bewust niet geimplementeerd; alles gebeurt ingame via F9.
