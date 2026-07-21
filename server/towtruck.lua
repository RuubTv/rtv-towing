local T = RTVTowing
local S = T.State

RegisterNetEvent('rtv-towing:server:attachBed', function(truckNet, vehicleNet, method)
    local src = source
    if not T.CanUse(src, 'bed') then return T.Notify(src, _L('no_access'), 'error') end
    if not truckNet or not vehicleNet or truckNet == vehicleNet then return end

    S.bedState[vehicleNet] = { truckNet = truckNet, method = method or 'center', by = src, at = os.time() }
    TriggerClientEvent('rtv-towing:client:syncBedAttach', -1, truckNet, vehicleNet, method or 'center')
    
    if T.TryMarkRepoVehicleSecured then
    T.TryMarkRepoVehicleSecured(vehicleNet)
end
end)

RegisterNetEvent('rtv-towing:server:detachBed', function(vehicleNet)
    local src = source
    if not T.CanUse(src, 'bed') and not T.CanUse(src, 'repo') then return T.Notify(src, _L('no_access'), 'error') end
    S.bedState[vehicleNet] = nil
    TriggerClientEvent('rtv-towing:client:syncBedDetach', -1, vehicleNet)
end)

RegisterNetEvent('rtv-towing:server:setRamp', function(truckNet, rampNets)
    local src = source
    if not T.CanUse(src, 'bed') then return T.Notify(src, _L('no_access'), 'error') end
    S.rampState[truckNet] = { by = src, ramps = rampNets or {}, at = os.time() }
end)

RegisterNetEvent('rtv-towing:server:removeRamp', function(truckNet)
    local src = source
    if not T.CanUse(src, 'bed') then return T.Notify(src, _L('no_access'), 'error') end
    S.rampState[truckNet] = nil
    TriggerClientEvent('rtv-towing:client:removeRamp', -1, truckNet)
end)
