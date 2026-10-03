-- ══════════════════════════════════════════════════════════════
--  Kroon Admin - Client
--  F11 staffdienst (+ staffkleding), TxAdmin-stijl noclip,
--  spectate, voertuig-acties, F9 staffmenu (NUI)
-- ══════════════════════════════════════════════════════════════

local IsAdmin = false      -- server heeft bevestigd dat we staff zijn
local OnDuty = false
local MenuOpen = false
local SavedOutfit = nil
local NoclipActive = false
local Spectating = false
local SpectateTarget = nil
local SpectateCam = nil
local FrozenBeforeNoclip = false

--- Notificaties ----------------------------------------------------

local function Notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(msg))
    EndTextCommandThefeedPostTicker(false, false)
end

RegisterNetEvent('kroon_admin:client:notify', Notify)

--- Staffdienst (F11) ------------------------------------------------

local function SaveCurrentOutfit()
    local ped = PlayerPedId()
    local outfit = { model = GetEntityModel(ped), components = {}, props = {} }
    for component = 0, 12 do
        outfit.components[#outfit.components + 1] = {
            component = component,
            drawable = GetPedDrawableVariation(ped, component),
            texture = GetPedTextureVariation(ped, component),
        }
    end
    for prop = 0, 7 do
        outfit.props[#outfit.props + 1] = {
            prop = prop,
            drawable = GetPedPropIndex(ped, prop),
            texture = GetPedPropTextureIndex(ped, prop),
        }
    end
    SavedOutfit = outfit
end

local function RestoreOutfit()
    if not SavedOutfit then return end
    local ped = PlayerPedId()
    local model = SavedOutfit.model
    if model and IsModelValid(model) and model ~= GetEntityModel(ped) then
        RequestModel(model)
        while not HasModelLoaded(model) do Wait(10) end
        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)
        ped = PlayerPedId()
    end
    for _, c in ipairs(SavedOutfit.components or {}) do
        SetPedComponentVariation(ped, c.component, c.drawable or 0, c.texture or 0, 0)
    end
    for _, p in ipairs(SavedOutfit.props or {}) do
        if p.drawable and p.drawable >= 0 then
            SetPedPropIndex(ped, p.prop, p.drawable, p.texture or 0, true)
        else
            ClearPedProp(ped, p.prop)
        end
    end
    SavedOutfit = nil
end

local function ApplyAdminOutfit()
    local ped = PlayerPedId()
    local model = GetEntityModel(ped)
    local key = (model == joaat('mp_f_freemode_01')) and 'female' or 'male'
    local outfit = (Config.AdminOutfits or {})[key] or (Config.AdminOutfits or {}).male
    if not outfit then return end
    for _, c in ipairs(outfit.components or {}) do
        SetPedComponentVariation(ped, c.component, c.drawable or 0, c.texture or 0, 0)
    end
    for _, p in ipairs(outfit.props or {}) do
        SetPedPropIndex(ped, p.prop, p.drawable or 0, p.texture or 0, true)
    end
end

RegisterNetEvent('kroon_admin:client:dutyState', function(state)
    IsAdmin = true
    OnDuty = state == true
    if OnDuty then
        SaveCurrentOutfit()
        ApplyAdminOutfit()
        Notify('Je bent nu ~b~in staffdienst~s~. Druk op F9 voor het staffmenu.')
    else
        if NoclipActive then ToggleNoclip(false) end
        if Spectating then StopSpectate() end
        if MenuOpen then SetMenuOpen(false) end
        RestoreOutfit()
        Notify('Je bent nu ~r~uit staffdienst~s~.')
    end
end)

local function RequestToggleDuty()
    TriggerServerEvent('kroon_admin:server:toggleDuty')
end

RegisterCommand('kroon_staffdienst', RequestToggleDuty, false)
RegisterKeyMapping('kroon_staffdienst', 'Kroon: staffdienst aan/uit', 'keyboard', 'F11')

--- Noclip (TxAdmin-stijl) --------------------------------------------
-- Rechtermuisknop (standaard) togglet noclip tijdens staffdienst.
-- Muis kijkt, WASD beweegt, Q/E omhoog/omlaag, Shift snel, Alt traag.

local noclipPos = nil
local noclipCam = nil

local function RotationToDirection(rot)
    local rad = math.pi / 180.0
    local x = -math.sin(rot.z * rad) * math.abs(math.cos(rot.x * rad))
    local y = math.cos(rot.z * rad) * math.abs(math.cos(rot.x * rad))
    local z = math.sin(rot.x * rad)
    return vector3(x, y, z)
end

function ToggleNoclip(state)
    NoclipActive = state
    local ped = PlayerPedId()
    if NoclipActive then
        noclipPos = GetEntityCoords(ped)
        noclipCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamCoord(noclipCam, noclipPos.x, noclipPos.y, noclipPos.z)
        SetCamRot(noclipCam, GetGameplayCamRot(2), 2)
        SetCamActive(noclipCam, true)
        RenderScriptCams(true, true, 500, true, true)
        FrozenBeforeNoclip = IsEntityPositionFrozen(ped)
        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, false, false)
        SetEntityCollision(ped, false, false)
        SetEntityAlpha(ped, 0, false)
        TriggerServerEvent('kroon_admin:server:noclipState', true)
        Notify('Noclip ~g~aan~s~.')
    else
        if noclipCam then
            RenderScriptCams(false, true, 500, true, true)
            DestroyCam(noclipCam, false)
            noclipCam = nil
        end
        local coords = noclipPos or GetEntityCoords(ped)
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        FreezeEntityPosition(ped, FrozenBeforeNoclip)
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        ResetEntityAlpha(ped)
        TriggerServerEvent('kroon_admin:server:noclipState', false)
        Notify('Noclip ~r~uit~s~.')
    end
end

RegisterNetEvent('kroon_admin:client:noclipState', function() end)

CreateThread(function()
    while true do
        if OnDuty and IsControlJustPressed(0, Config.Noclip.ToggleControl or 25) then
            ToggleNoclip(not NoclipActive)
        end
        Wait(NoclipActive and 0 or 250)
    end
end)

CreateThread(function()
    while true do
        if NoclipActive then
            local nc = Config.Noclip
            -- vergrendel controls zoals TxAdmin
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)   -- muis X
            EnableControlAction(0, 2, true)   -- muis Y
            EnableControlAction(0, nc.ToggleControl or 25, true)

            local lookX = GetDisabledControlNormal(0, 1) * 6.0
            local lookY = GetDisabledControlNormal(0, 2) * 6.0
            local rot = GetCamRot(noclipCam, 2)
            local newRot = vector3(
                math.max(-89.0, math.min(89.0, rot.x - lookY)),
                rot.y,
                rot.z - lookX
            )
            SetCamRot(noclipCam, newRot, 2)

            local speed = nc.BaseSpeed or 0.6
            if IsDisabledControlPressed(0, nc.Boost or 21) then
                speed = math.min(speed * (nc.BoostMult or 6.0), nc.MaxSpeed or 4.0)
            elseif IsDisabledControlPressed(0, nc.Slow or 19) then
                speed = speed * (nc.SlowMult or 0.25)
            end

            local dir = RotationToDirection(newRot)
            local move = vector3(0.0, 0.0, 0.0)
            if IsDisabledControlPressed(0, nc.Forward or 32) then move = move + dir end
            if IsDisabledControlPressed(0, nc.Backward or 33) then move = move - dir end
            if IsDisabledControlPressed(0, nc.Left or 34) then
                move = move + vector3(-dir.y, dir.x, 0.0)
            end
            if IsDisabledControlPressed(0, nc.Right or 35) then
                move = move - vector3(-dir.y, dir.x, 0.0)
            end
            if IsDisabledControlPressed(0, nc.Up or 44) then move = move + vector3(0.0, 0.0, 1.0) end
            if IsDisabledControlPressed(0, nc.Down or 46) then move = move - vector3(0.0, 0.0, 1.0) end

            if #move > 0.0 then
                noclipPos = noclipPos + (move / #move) * speed
            end
            SetCamCoord(noclipCam, noclipPos.x, noclipPos.y, noclipPos.z)
            local ped = PlayerPedId()
            SetEntityCoords(ped, noclipPos.x, noclipPos.y, noclipPos.z, false, false, false, false)
            Wait(0)
        else
            Wait(250)
        end
    end
end)

--- Spectate ----------------------------------------------------------

function StopSpectate()
    if not Spectating then return end
    Spectating = false
    SpectateTarget = nil
    if SpectateCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(SpectateCam, false)
        SpectateCam = nil
    end
    local ped = PlayerPedId()
    SetEntityVisible(ped, true, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
    Notify('Spectate ~r~gestopt~s~.')
end

RegisterNetEvent('kroon_admin:client:spectate', function(targetId, targetCoords)
    if not IsAdmin then return end
    local wasSpectating = Spectating
    local oldTarget = SpectateTarget
    if Spectating then StopSpectate() end
    if wasSpectating and oldTarget == targetId then
        return -- nogmaals op dezelfde speler = stop spectaten
    end
    local ped = PlayerPedId()
    SetEntityCoords(ped, targetCoords.x, targetCoords.y, targetCoords.z - 3.0, false, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    Spectating = true
    SpectateTarget = targetId
    SpectateCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamActive(SpectateCam, true)
    RenderScriptCams(true, true, 500, true, true)
    Notify(('Spectate: ~b~%s~s~ (nogmaals spectaten om te stoppen)'):format(GetPlayerName(GetPlayerFromServerId(targetId)) or targetId))
end)

CreateThread(function()
    while true do
        if Spectating and SpectateCam then
            local target = GetPlayerFromServerId(SpectateTarget)
            local targetPed = (target ~= -1) and GetPlayerPed(target) or 0
            if targetPed and targetPed ~= 0 then
                local coords = GetEntityCoords(targetPed)
                SetCamCoord(SpectateCam, coords.x, coords.y, coords.z + 2.2)
                PointCamAtEntity(SpectateCam, targetPed, 0.0, 0.0, 0.5, true)
            else
                StopSpectate()
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

--- Teleport ------------------------------------------------------------

RegisterNetEvent('kroon_admin:client:goto', function(coords)
    local ped = PlayerPedId()
    SetEntityCoords(ped, coords.x, coords.y, coords.z + 1.0, false, false, false, false)
end)

--- Voertuig acties -------------------------------------------------------

RegisterNetEvent('kroon_admin:client:spawnVehicle', function(model, plate)
    local modelHash = joaat(model)
    if not IsModelValid(modelHash) then
        Notify(('Model ~r~%s~s~ is ongeldig.'):format(tostring(model)))
        return
    end
    RequestModel(modelHash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(modelHash) and GetGameTimer() < timeout do Wait(10) end
    if not HasModelLoaded(modelHash) then
        Notify('Model kon niet geladen worden.')
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local veh = CreateVehicle(modelHash, coords.x, coords.y, coords.z, heading, true, false)
    SetVehicleNumberPlateText(veh, plate or 'KROON')
    SetVehicleOnGroundProperly(veh)
    SetPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(modelHash)
    Notify(('Voertuig ~g~%s~s~ gespawnd (%s).'):format(tostring(model), tostring(plate)))
end)

local function ForEachVehicle(cb)
    local pool = GetGamePool('CVehicle')
    for _, veh in ipairs(pool) do cb(veh) end
end

RegisterNetEvent('kroon_admin:client:repairVehicleByPlate', function(plate)
    local found = false
    ForEachVehicle(function(veh)
        local p = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
        if p == (tostring(plate):gsub('%s+', '')) then
            SetVehicleFixed(veh)
            SetVehicleDeformationFixed(veh)
            SetVehicleUndriveable(veh, false)
            SetVehicleEngineOn(veh, true, true, false)
            found = true
        end
    end)
    Notify(found and ('Voertuig %s gerepareerd.'):format(plate) or ('Geen voertuig met kenteken %s in de buurt.'):format(plate))
end)

RegisterNetEvent('kroon_admin:client:deleteVehicleByPlate', function(plate)
    local found = false
    ForEachVehicle(function(veh)
        local p = (GetVehicleNumberPlateText(veh) or ''):gsub('%s+', '')
        if p == (tostring(plate):gsub('%s+', '')) then
            SetEntityAsMissionEntity(veh, true, true)
            DeleteVehicle(veh)
            found = true
        end
    end)
    Notify(found and ('Voertuig %s verwijderd.'):format(plate) or ('Geen voertuig met kenteken %s in de buurt.'):format(plate))
end)

--- F9 Menu (NUI) ---------------------------------------------------------

function SetMenuOpen(open)
    MenuOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({ action = open and 'open' or 'close' })
end

RegisterCommand('kroon_staffmenu', function()
    if not OnDuty then
        Notify('Je moet eerst in staffdienst (~b~F11~s~).')
        return
    end
    SetMenuOpen(not MenuOpen)
end, false)
RegisterKeyMapping('kroon_staffmenu', 'Kroon: staffmenu openen', 'keyboard', 'F9')

RegisterNUICallback('close', function(_, cb)
    SetMenuOpen(false)
    cb({ ok = true })
end)

RegisterNUICallback('getPlayers', function(_, cb)
    local handler
    handler = AddEventHandler('kroon_admin:client:receivePlayers', function(players)
        RemoveEventHandler(handler)
        SendNUIMessage({ action = 'players', players = players })
    end)
    TriggerServerEvent('kroon_admin:server:getPlayers')
    cb({ ok = true })
end)

local function NuiAction(event, data)
    return function(_, cb)
        TriggerServerEvent(event, data and data.id, data and data.reason)
        cb({ ok = true })
    end
end

RegisterNUICallback('spectate', function(data, cb)
    TriggerServerEvent('kroon_admin:server:spectate', data and data.id)
    SetMenuOpen(false)
    cb({ ok = true })
end)
RegisterNUICallback('kick', NuiAction('kroon_admin:server:kick'))
RegisterNUICallback('warn', NuiAction('kroon_admin:server:warn'))
RegisterNUICallback('goto', function(data, cb)
    TriggerServerEvent('kroon_admin:server:goto', data and data.id)
    cb({ ok = true })
end)
RegisterNUICallback('bring', function(data, cb)
    TriggerServerEvent('kroon_admin:server:bring', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('getWarns', function(data, cb)
    local handler
    handler = AddEventHandler('kroon_admin:client:receiveWarns', function(_, warns)
        RemoveEventHandler(handler)
        SendNUIMessage({ action = 'warns', warns = warns })
    end)
    TriggerServerEvent('kroon_admin:server:getWarns', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('getGarageVehicles', function(data, cb)
    local handler
    handler = AddEventHandler('kroon_admin:client:receiveGarageVehicles', function(vehicles)
        RemoveEventHandler(handler)
        SendNUIMessage({ action = 'vehicles', vehicles = vehicles })
    end)
    TriggerServerEvent('kroon_admin:server:getGarageVehicles', data and data.owner)
    cb({ ok = true })
end)

RegisterNUICallback('vehicleAction', function(data, cb)
    TriggerServerEvent('kroon_admin:server:vehicleAction', data and data.action, data and data.plate)
    cb({ ok = true })
end)

RegisterNUICallback('getInventory', function(data, cb)
    local handler
    handler = AddEventHandler('kroon_admin:client:receiveInventory', function(targetId, items)
        RemoveEventHandler(handler)
        SendNUIMessage({ action = 'inventory', target = targetId, items = items })
    end)
    TriggerServerEvent('kroon_admin:server:getInventory', data and data.id)
    cb({ ok = true })
end)

RegisterNUICallback('inventoryGive', function(data, cb)
    TriggerServerEvent('kroon_admin:server:inventoryGive', data and data.id, data and data.item, data and data.count)
    cb({ ok = true })
end)

RegisterNUICallback('inventoryRemove', function(data, cb)
    TriggerServerEvent('kroon_admin:server:inventoryRemove', data and data.id, data and data.item, data and data.count, data and data.slot)
    cb({ ok = true })
end)

RegisterNUICallback('toggleNoclip', function(_, cb)
    if OnDuty then ToggleNoclip(not NoclipActive) end
    cb({ ok = true })
end)
