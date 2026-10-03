local function reply(cb)
    cb({ ok = true })
end

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    reply(cb)
end)

RegisterNUICallback('players', function(_, cb)
    TriggerServerEvent('kroon_admin:server:requestPlayers')
    reply(cb)
end)

RegisterNUICallback('logs', function(_, cb)
    TriggerServerEvent('kroon_admin:server:requestLogs')
    reply(cb)
end)

RegisterNUICallback('playerAction', function(data, cb)
    TriggerServerEvent('kroon_admin:server:action', data)
    reply(cb)
end)

RegisterNUICallback('tool', function(data, cb)
    TriggerServerEvent('kroon_admin:server:tool', data)
    reply(cb)
end)
