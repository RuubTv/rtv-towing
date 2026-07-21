RTVTowing = RTVTowing or {}
local T = RTVTowing

T.State = {
    activeTowRopes = {},
    activeWinches = {},
    bedState = {},
    rampState = {},
    activeRepos = {},
    repoCooldowns = {},
    ropeCounter = 0,
    repoCounter = 0
}

function T.DebugPrint(...)
    if Config.Debug then print(('[%s]'):format(GetCurrentResourceName()), ...) end
end

function T.Notify(src, message, nType)
    TriggerClientEvent('rtv-towing:client:notify', src, message, nType or 'inform')
end

function T.GetPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

function T.TableContains(list, value)
    for _, v in ipairs(list or {}) do
        if v == value then return true end
    end
    return false
end

function T.PlayerHasJob(src, jobs, requireDuty)
    local player = T.GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.job then return false end

    local job = player.PlayerData.job
    if not T.TableContains(jobs, job.name) then return false end
    if requireDuty and job.onduty == false then return false end
    return true
end

function T.HasItem(src, itemName)
    if not itemName then return true end
    local count = exports.ox_inventory:Search(src, 'count', itemName)
    return (count or 0) > 0
end

function T.CanUse(src, action)
    if action == 'repo' then
        return T.PlayerHasJob(src, Config.Jobs.repoJobs, Config.Jobs.requireDuty)
    elseif action == 'bed' then
        if not Config.Jobs.requireJobForBed then return true end
        return T.PlayerHasJob(src, Config.Jobs.bedJobs, false)
    elseif action == 'tow' then
        return T.PlayerHasJob(src, Config.Jobs.towJobs, Config.Jobs.requireDuty) and T.HasItem(src, Config.Items.towRope)
    elseif action == 'winch' then
        if not T.HasItem(src, Config.Items.winch) then return false end
        if Config.Jobs.winchEveryone then return true end
        return T.PlayerHasJob(src, Config.Jobs.towJobs, Config.Jobs.requireDuty)
    end
    return false
end

function T.GetVehicleFromNetId(vehicleNet)
    vehicleNet = tonumber(vehicleNet)

    if not vehicleNet or vehicleNet == 0 then
        return 0
    end

    local vehicles = GetAllVehicles()

    for _, vehicle in ipairs(vehicles or {}) do
        if DoesEntityExist(vehicle) and GetEntityType(vehicle) == 2 then
            local netId = NetworkGetNetworkIdFromEntity(vehicle)

            if tonumber(netId) == vehicleNet then
                return vehicle
            end
        end
    end

    return 0
end

function T.GetVehicleFromNetIdSafe(vehicleNet)
    return T.GetVehicleFromNetId(vehicleNet)
end

function T.GiveVehicleKeys(src, vehicleNet, skipNotification)
    if not Config.VehicleKeys or not Config.VehicleKeys.enabled then return false end

    local vehicle = T.GetVehicleFromNetId(vehicleNet)
    if vehicle == 0 then
        T.Notify(src, 'Kon geen voertuigsleutels geven: voertuig niet gevonden.', 'error')
        return false
    end

    local shouldSkipNotification = skipNotification
    if shouldSkipNotification == nil then shouldSkipNotification = Config.VehicleKeys.skipNotification == true end

    exports.qbx_vehiclekeys:GiveKeys(src, vehicle, shouldSkipNotification == true)

    if Config.VehicleKeys.notifyInEld ~= false then
        T.Notify(src, Config.VehicleKeys.keyMessage or 'Je hebt voertuigsleutels ontvangen.', 'success')
    end

    return true
end

lib.callback.register('rtv-towing:server:canUse', function(src, action)
    return T.CanUse(src, action)
end)

lib.callback.register('rtv-towing:server:hasRemote', function(src)
    if not Config.Items.remote then return true end
    local count = exports.ox_inventory:Search(src, 'count', Config.Items.remote)
    return (count or 0) > 0
end)

AddEventHandler('playerDropped', function()
    local src = source
    local S = T.State
    local rope = S.activeTowRopes[src]
    if rope then TriggerClientEvent('rtv-towing:client:removeTowRope', -1, rope.id) end
    local winch = S.activeWinches[src]
    if winch then TriggerClientEvent('rtv-towing:client:removeWinch', -1, winch.id) end
    S.activeTowRopes[src] = nil
    S.activeWinches[src] = nil
    S.activeRepos[src] = nil
end)

exports('CanUseTow', function(src) return T.CanUse(src, 'tow') end)
exports('CanUseWinch', function(src) return T.CanUse(src, 'winch') end)
exports('CanUseBed', function(src) return T.CanUse(src, 'bed') end)
exports('CanUseRepo', function(src) return T.CanUse(src, 'repo') end)
exports('IsVehicleOnBed', function(vehicleNet) return T.State.bedState[vehicleNet] ~= nil end)
exports('GetBedState', function() return T.State.bedState end)
exports('GetRampState', function() return T.State.rampState end)
exports('GetRepoState', function(src) return T.State.activeRepos[src] end)