local T = RTVTowing
local S = T.State

local function isSourceNearTow(src, rope)
    if not rope then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local maxDistance = Config.Rope.controlDistance or 25.0

    local towingVehicle = T.GetVehicleFromNetId(rope.towingNet)
    if towingVehicle ~= 0 and DoesEntityExist(towingVehicle) and #(coords - GetEntityCoords(towingVehicle)) <= maxDistance then return true end

    local targetVehicle = T.GetVehicleFromNetId(rope.targetNet)
    if targetVehicle ~= 0 and DoesEntityExist(targetVehicle) and #(coords - GetEntityCoords(targetVehicle)) <= maxDistance then return true end

    return false
end

RegisterNetEvent('rtv-towing:server:startTow', function(towingNet, targetNet, towingOffset, targetOffset)
    local src = source
    if not T.CanUse(src, 'tow') then return T.Notify(src, _L('no_access'), 'error') end
    if not towingNet or not targetNet or towingNet == targetNet then return end

    S.ropeCounter = S.ropeCounter + 1
    local ropeId = ('%s:%s'):format(src, S.ropeCounter)

    S.activeTowRopes[src] = {
        id = ropeId,
        towingNet = towingNet,
        targetNet = targetNet,
        towingOffset = towingOffset or { x = 0.0, y = -4.8, z = 0.55 },
        targetOffset = targetOffset or { x = 0.0, y = 2.2, z = 0.35 }
    }

    TriggerClientEvent('rtv-towing:client:syncTowRope', -1, ropeId, src, towingNet, targetNet, S.activeTowRopes[src].towingOffset, S.activeTowRopes[src].targetOffset)
    TriggerClientEvent('rtv-towing:client:startOwnedTowControls', src, ropeId)
end)

RegisterNetEvent('rtv-towing:server:stopTow', function()
    local src = source
    local rope = S.activeTowRopes[src]
    if not rope then return end

    if not isSourceNearTow(src, rope) then
        return T.Notify(src, ('Je staat te ver weg van de sleepkabel. Max afstand: %sm'):format(Config.Rope.controlDistance or 25.0), 'error')
    end

    S.activeTowRopes[src] = nil
    TriggerClientEvent('rtv-towing:client:removeTowRope', -1, rope.id)
    T.Notify(src, _L('tow_stopped'), 'success')
end)
