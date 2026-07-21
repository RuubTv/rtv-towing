local T = RTVTowing
local S = T.State

local function isSourceNearWinch(src, winch)
    if not winch then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local maxDistance = Config.Rope.controlDistance or 25.0

    local vehicle = T.GetVehicleFromNetId(winch.vehicleNet)
    if vehicle ~= 0 and DoesEntityExist(vehicle) and #(coords - GetEntityCoords(vehicle)) <= maxDistance then return true end

    if winch.anchorCoords then
        local anchorCoords = vector3(winch.anchorCoords.x, winch.anchorCoords.y, winch.anchorCoords.z)
        if #(coords - anchorCoords) <= maxDistance then return true end
    end

    return false
end

RegisterNetEvent('rtv-towing:server:startWinch', function(vehicleNet, anchorNet, anchorCoords, vehicleOffset)
    local src = source
    if not T.CanUse(src, 'winch') then return T.Notify(src, _L('no_access'), 'error') end
    if not vehicleNet or not anchorCoords then return end

    S.ropeCounter = S.ropeCounter + 1
    local winchId = ('%s:%s'):format(src, S.ropeCounter)

    S.activeWinches[src] = {
        id = winchId,
        vehicleNet = vehicleNet,
        anchorNet = anchorNet,
        anchorCoords = anchorCoords,
        vehicleOffset = vehicleOffset or { x = 0.0, y = -2.0, z = 0.4 },
        mode = 'stop'
    }

    TriggerClientEvent('rtv-towing:client:syncWinch', -1, winchId, src, vehicleNet, anchorNet, anchorCoords, S.activeWinches[src].vehicleOffset)
    TriggerClientEvent('rtv-towing:client:startOwnedWinchControls', src, winchId)
end)

RegisterNetEvent('rtv-towing:server:winchMode', function(mode, silent)
    local src = source
    local winch = S.activeWinches[src]

    silent = silent == true

    if not winch then
        return
    end

    if not isSourceNearWinch(src, winch) then
        winch.mode = 'stop'

        TriggerClientEvent('rtv-towing:client:setWinchMode', -1, winch.id, 'stop')

        if not silent then
            T.Notify(
                src,
                ('Je staat te ver weg van de winch. Max afstand: %sm'):format(Config.Rope.controlDistance or 25.0),
                'error'
            )
        end

        return
    end

    if mode ~= 'pull' and mode ~= 'release' then
        mode = 'stop'
    end

    winch.mode = mode

    TriggerClientEvent('rtv-towing:client:setWinchMode', -1, winch.id, mode)

    if mode == 'pull' then
        T.Notify(src, _L('winch_pull'), 'inform')
    elseif mode == 'release' then
        T.Notify(src, _L('winch_release'), 'inform')
    end
end)
RegisterNetEvent('rtv-towing:server:stopWinch', function()
    local src = source
    local winch = S.activeWinches[src]
    if not winch then return end

    S.activeWinches[src] = nil
    TriggerClientEvent('rtv-towing:client:removeWinch', -1, winch.id)
    T.Notify(src, _L('winch_stopped'), 'success')
end)
