local menuOpen = false
local muted = false
local toggles = { godmode = false, noclip = false, invisible = false }

local function notify(message, kind)
    SendNUIMessage({ type = 'notification', message = message, kind = kind or 'info' })
end

RegisterNetEvent('kroon_admin:client:open', function()
    menuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'open',
        locations = Config.SavedLocations,
        toggles = toggles
    })
end)

RegisterNetEvent('kroon_admin:client:close', function()
    menuOpen = false
end)

RegisterNetEvent('kroon_admin:client:players', function(players)
    SendNUIMessage({ type = 'players', players = players })
end)

RegisterNetEvent('kroon_admin:client:logs', function(logs)
    SendNUIMessage({ type = 'logs', logs = logs })
end)

RegisterNetEvent('kroon_admin:client:notify', notify)

RegisterNetEvent('kroon_admin:client:announce', function(adminName, message)
    SendNUIMessage({ type = 'announcement', title = Config.Locale.announcement, message = message, admin = adminName })
end)

RegisterNetEvent('kroon_admin:client:setMuted', function(state)
    muted = state == true
end)

RegisterNetEvent('kroon_admin:client:freeze', function(state)
    FreezeEntityPosition(PlayerPedId(), state == true)
end)

RegisterNetEvent('kroon_admin:client:teleportTo', function(coords, heading)
    if type(coords) ~= 'table' then return end
    local ped = PlayerPedId()
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ped, x, y, z, false, false, false, false)
    if heading then SetEntityHeading(ped, tonumber(heading) or 0.0) end
end)

RegisterNetEvent('kroon_admin:client:teleportWaypoint', function()
    local waypoint = GetFirstBlipInfoId(8)
    if not DoesBlipExist(waypoint) then
        notify('Plaats eerst een waypoint op de kaart.', 'error')
        return
    end
    local coords = GetBlipInfoIdCoord(waypoint)
    local found, groundZ = false, 0.0
    for height = 1, 1000 do
        SetPedCoordsKeepVehicle(PlayerPedId(), coords.x, coords.y, height + 0.0)
        Wait(5)
        found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, height + 0.0, false)
        if found then break end
    end
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, found and groundZ + 1.0 or 1000.0, false, false, false, false)
end)

RegisterNetEvent('kroon_admin:client:revive', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId()))
    ClearPedBloodDamage(PlayerPedId())
end)

RegisterNetEvent('kroon_admin:client:spawnVehicle', function(modelName)
    local model = joaat(modelName)
    if not IsModelInCdimage(model) or not IsModelAVehicle(model) then
        notify('Dit voertuigmodel bestaat niet.', 'error')
        return
    end
    RequestModel(model)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(model) then
        notify('Het voertuigmodel kon niet worden geladen.', 'error')
        return
    end
    local ped = PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(ped, 0.0, 4.0, 0.0)
    local vehicle = CreateVehicle(model, coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    if vehicle and vehicle ~= 0 then
        SetPedIntoVehicle(ped, vehicle, -1)
        SetVehicleOnGroundProperly(vehicle)
        SetEntityAsMissionEntity(vehicle, true, true)
        notify(('Voertuig %s gespawned.'):format(modelName), 'success')
    end
    SetModelAsNoLongerNeeded(model)
end)

RegisterNetEvent('kroon_admin:client:toggle', function(toggle)
    if toggles[toggle] == nil then return end
    toggles[toggle] = not toggles[toggle]
    if toggle == 'invisible' then
        SetEntityVisible(PlayerPedId(), not toggles.invisible, false)
    end
    notify(('%s %s'):format(toggle, toggles[toggle] and 'ingeschakeld' or 'uitgeschakeld'), 'success')
    SendNUIMessage({ type = 'toggleState', toggle = toggle, enabled = toggles[toggle] })
end)

RegisterCommand(Config.Command, function()
    TriggerServerEvent('kroon_admin:server:requestOpen')
end, false)

RegisterKeyMapping(Config.Command, 'Open het Kroon Admin-menu', 'keyboard', 'F10')

RegisterCommand('kroon_admin:close', function()
    if not menuOpen then return end
    menuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end, false)

CreateThread(function()
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        if toggles.godmode then
            sleep = 0
            SetPlayerInvincible(PlayerId(), true)
            SetEntityCanBeDamaged(ped, false)
        else
            SetPlayerInvincible(PlayerId(), false)
            SetEntityCanBeDamaged(ped, true)
        end

        if toggles.noclip then
            sleep = 0
            SetEntityCollision(ped, false, false)
            local coords = GetEntityCoords(ped)
            local heading = GetGameplayCamRot(2).z
            local speed = IsControlPressed(0, 21) and 3.0 or 1.0
            local forward = IsControlPressed(0, 32) or IsControlPressed(0, 172)
            local backward = IsControlPressed(0, 33) or IsControlPressed(0, 173)
            local left = IsControlPressed(0, 34) or IsControlPressed(0, 174)
            local right = IsControlPressed(0, 35) or IsControlPressed(0, 175)
            local vertical = IsControlPressed(0, 22) and 1.0 or (IsControlPressed(0, 36) and -1.0 or 0.0)
            local direction = vector3(0.0, 0.0, 0.0)
            if forward then direction = direction + vector3(-math.sin(math.rad(heading)), math.cos(math.rad(heading)), 0.0) end
            if backward then direction = direction - vector3(-math.sin(math.rad(heading)), math.cos(math.rad(heading)), 0.0) end
            if right then direction = direction + vector3(math.cos(math.rad(heading)), math.sin(math.rad(heading)), 0.0) end
            if left then direction = direction - vector3(math.cos(math.rad(heading)), math.sin(math.rad(heading)), 0.0) end
            SetEntityVelocity(ped, 0.0, 0.0, 0.0)
            SetEntityCoordsNoOffset(ped, coords.x + direction.x * speed * GetFrameTime(), coords.y + direction.y * speed * GetFrameTime(), coords.z + vertical * speed * GetFrameTime(), true, true, true)
            SetEntityHeading(ped, heading)
        else
            SetEntityCollision(ped, true, true)
        end

        if muted then
            sleep = 0
            DisableControlAction(0, 249, true)
            DisableControlAction(0, 245, true)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    SetPlayerInvincible(PlayerId(), false)
    SetEntityCanBeDamaged(PlayerPedId(), true)
    SetEntityVisible(PlayerPedId(), true, false)
end)
