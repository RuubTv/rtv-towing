RTVTowing = RTVTowing or {}

local T = RTVTowing

T.ResourceName = GetCurrentResourceName()

T.State = {
    repoPed = nil,
    repoBlip = nil,
    activeRepo = nil,
    repoDropoffRevealed = false,
    returnableRepoTruck = nil,

    activeRopes = {},
    bedAttachments = {},
    activeRamps = {},
    winchLoops = {},
    towLoops = {},
    spawnedRepoEntities = {},

    activeOwnedTowId = nil,
    activeOwnedWinchId = nil,

    activeControlsUi = {
        enabled = false,
        text = nil
    }
}

T.KeyPressed = {
    confirm = false,
    cancel = false,
    winchPull = false,
    winchRelease = false,
    winchPause = false
}

T.DefaultKeyLabels = {
    confirm = 'LMB',
    cancel = 'Backspace',
    winchPull = 'E',
    winchRelease = 'Q',
    winchPause = 'X'
}

T.PointSelectBlockedControls = {
    24, 25, 44, 140, 141, 142, 257, 263, 264
}

T.WinchBlockedControls = {
    44, 140, 141, 142, 263, 264
}

function T.DebugPrint(...)
    if Config.Debug then
        print(('[%s]'):format(T.ResourceName), ...)
    end
end

function T.Notify(description, nType, title)
    -- Alleen eigen RTV NUI meldingen gebruiken. Geen ox_lib notify meer.
    local mappedType = nType or 'info'
    if mappedType == 'inform' then mappedType = 'info' end
    if mappedType == 'warn' then mappedType = 'warning' end

    if T.UI and T.UI.ShowToast then
        T.UI.ShowToast({
            title = title or 'RTV Towing',
            message = description or '',
            type = mappedType,
            duration = Config.Notify and Config.Notify.duration or 4500
        })
        return
    end

    SendNUIMessage({
        action = 'showToast',
        data = {
            title = title or 'RTV Towing',
            message = description or '',
            type = mappedType,
            duration = Config.Notify and Config.Notify.duration or 4500
        }
    })
end

function T.RegisterTowingKeybinds()
    if T.KeybindsRegistered then return end
    T.KeybindsRegistered = true

    RegisterCommand('+rtv_towing_confirm_point', function() T.KeyPressed.confirm = true end, false)
    RegisterCommand('-rtv_towing_confirm_point', function() end, false)

    RegisterCommand('+rtv_towing_cancel', function() T.KeyPressed.cancel = true end, false)
    RegisterCommand('-rtv_towing_cancel', function() end, false)

    RegisterCommand('+rtv_towing_winch_pull', function() T.KeyPressed.winchPull = true end, false)
    RegisterCommand('-rtv_towing_winch_pull', function() end, false)

    RegisterCommand('+rtv_towing_winch_release', function() T.KeyPressed.winchRelease = true end, false)
    RegisterCommand('-rtv_towing_winch_release', function() end, false)

    RegisterCommand('+rtv_towing_winch_pause', function() T.KeyPressed.winchPause = true end, false)
    RegisterCommand('-rtv_towing_winch_pause', function() end, false)

    RegisterKeyMapping('+rtv_towing_confirm_point', 'Towing: punt bevestigen', 'mouse_button', 'MOUSE_LEFT')
    RegisterKeyMapping('+rtv_towing_cancel', 'Towing: annuleren / kabel verwijderen', 'keyboard', 'BACK')
    RegisterKeyMapping('+rtv_towing_winch_pull', 'Towing: winch intrekken', 'keyboard', 'E')
    RegisterKeyMapping('+rtv_towing_winch_release', 'Towing: winch vieren', 'keyboard', 'Q')
    RegisterKeyMapping('+rtv_towing_winch_pause', 'Towing: winch pauze', 'keyboard', 'X')
end

function T.ResetKeyPresses()
    T.KeyPressed.confirm = false
    T.KeyPressed.cancel = false
    T.KeyPressed.winchPull = false
    T.KeyPressed.winchRelease = false
    T.KeyPressed.winchPause = false
end

function T.WasKeyPressed(keyName, fallbackControl)
    if T.KeyPressed[keyName] then
        T.KeyPressed[keyName] = false
        return true
    end

    if fallbackControl then
        if IsControlJustPressed(0, fallbackControl) or IsDisabledControlJustPressed(0, fallbackControl) then
            return true
        end
    end

    return false
end

function T.DisablePointSelectControls()
    DisablePlayerFiring(PlayerId(), true)
    for _, control in ipairs(T.PointSelectBlockedControls) do
        DisableControlAction(0, control, true)
    end
end

function T.DisableWinchControls()
    for _, control in ipairs(T.WinchBlockedControls) do
        DisableControlAction(0, control, true)
    end
end

function T.GetDefaultKeyLabel(keyName)
    return T.DefaultKeyLabels[keyName] or keyName
end

function T.ShowControlsText(text)
    local ui = T.State.activeControlsUi

    if ui.enabled and ui.text == text then return end

    ui.enabled = true
    ui.text = text

    if T.UI and T.UI.ShowTextAsActionBar then
        T.UI.ShowTextAsActionBar(text, 'RTV Towing', 'Actieve bediening')
    else
        SendNUIMessage({
            action = 'showActionBar',
            data = {
                title = 'RTV Towing',
                subtitle = 'Actieve bediening',
                keys = { { key = 'INFO', label = text or '' } }
            }
        })
    end
end

function T.HideControlsText()
    local ui = T.State.activeControlsUi
    if not ui.enabled then return end

    ui.enabled = false
    ui.text = nil

    if T.UI and T.UI.HideActionBar then
        T.UI.HideActionBar()
    else
        SendNUIMessage({ action = 'hideActionBar' })
    end
end

function T.IsVehicleEntity(entity)
    return entity and entity ~= 0 and DoesEntityExist(entity) and GetEntityType(entity) == 2
end

function T.RequestControl(entity, timeout)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    timeout = timeout or 1500
    local endTime = GetGameTimer() + timeout

    NetworkRequestControlOfEntity(entity)
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < endTime do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

function T.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    lib.requestModel(hash, 10000)
    return hash
end

function T.DoWorkAnim(label, duration, animType)
    duration = duration or 2500
    animType = animType or 'cable'

    local anim = Config.Animations[animType] or Config.Animations.cable

    if T.UI and T.UI.Progress then
        return T.UI.Progress({
            title = 'Towing',
            label = label or 'Bezig...',
            duration = duration,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = { dict = anim.dict, clip = anim.clip }
        })
    end

    -- Veiligheidsfallback zonder ox_lib progress: normaal wordt T.UI.Progress gebruikt,
    -- omdat client/ui.lua direct na main.lua wordt geladen.
    Wait(duration)
    return true
end

function T.ModelConfig(vehicle)
    if not T.IsVehicleEntity(vehicle) then return nil end

    local model = GetEntityModel(vehicle)
    if Config.Trucks[model] then return Config.Trucks[model] end

    if Config.AllowAnyTruckWithCommand and GetVehicleClass(vehicle) == 20 then
        return Config.DefaultTruck
    end

    return nil
end

function T.GetRampConfig(vehicle)
    local truckCfg = T.ModelConfig(vehicle)

    if not truckCfg then
        return nil
    end

    local base = Config.Ramp or {}
    local custom = truckCfg.ramp or {}

    return {
        enabled = custom.enabled ~= nil and custom.enabled or base.enabled,
        model = custom.model or base.model,

        twoRamps = custom.twoRamps ~= nil and custom.twoRamps or base.twoRamps,

        singleOffset = custom.singleOffset or base.singleOffset,
        offsets = custom.offsets or base.offsets,

        rotation = custom.rotation or base.rotation,
        freeze = custom.freeze ~= nil and custom.freeze or base.freeze,

        removeDistance = custom.removeDistance or base.removeDistance
    }
end

function T.GetNetId(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end

    if not NetworkGetEntityIsNetworked(entity) then
        NetworkRegisterEntityAsNetworked(entity)
        Wait(50)
    end

    return NetworkGetNetworkIdFromEntity(entity)
end

function T.GetEntityFromNet(netId)
    netId = tonumber(netId)

    if not netId or netId == 0 then
        return 0
    end

    if not NetworkDoesNetworkIdExist(netId) then
        return 0
    end

    if not NetworkDoesEntityExistWithNetworkId(netId) then
        return 0
    end

    local entity = NetworkGetEntityFromNetworkId(netId)

    if entity and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end

    return 0
end

function T.GetVehicleFromNetIdSafe(netId)
    local entity = T.GetEntityFromNet(netId)

    if entity == 0 then
        return 0
    end

    if GetEntityType(entity) ~= 2 then
        return 0
    end

    return entity
end

function T.GetObjectFromNetIdSafe(netId)
    local entity = T.GetEntityFromNet(netId)

    if entity == 0 then
        return 0
    end

    if GetEntityType(entity) ~= 3 then
        return 0
    end

    return entity
end

function T.GetVehicleFromNetId(netId)
    return T.GetVehicleFromNetIdSafe(netId)
end

function T.GetClosestVehicle(coords, radius, ignore)
    local closest = 0
    local closestDistance = radius or 8.0

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if vehicle ~= ignore and DoesEntityExist(vehicle) then
            local distance = #(coords - GetEntityCoords(vehicle))
            if distance < closestDistance then
                closest = vehicle
                closestDistance = distance
            end
        end
    end

    return closest, closestDistance
end

function T.GetClosestTruck(coords, radius)
    local closest = 0
    local closestDistance = radius or 12.0

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) and T.ModelConfig(vehicle) then
            local distance = #(coords - GetEntityCoords(vehicle))
            if distance < closestDistance then
                closest = vehicle
                closestDistance = distance
            end
        end
    end

    return closest, closestDistance
end

function T.HasClientJob(jobList)
    if not jobList or #jobList == 0 then return true end

    local ok, result = pcall(function()
        return exports.qbx_core:HasGroup(jobList)
    end)

    if ok then return result == true end

    for _, jobName in ipairs(jobList) do
        local okSingle, resultSingle = pcall(function()
            return exports.qbx_core:HasGroup(jobName)
        end)
        if okSingle and resultSingle == true then return true end
    end

    return false
end

function T.CanUseClient(action)
    if action == 'bed' then
        if not Config.Jobs.requireJobForBed then return true end
        return T.HasClientJob(Config.Jobs.bedJobs)
    elseif action == 'tow' then
        return T.HasClientJob(Config.Jobs.towJobs)
    elseif action == 'repo' then
        return T.HasClientJob(Config.Jobs.repoJobs)
    elseif action == 'winch' then
        return Config.Jobs.winchEveryone or T.HasClientJob(Config.Jobs.towJobs)
    end

    return false
end

function T.GetBedOffset(truck, method)
    local cfg = T.ModelConfig(truck)
    if not cfg or not cfg.bed or not cfg.bed.offsets then return nil end
    return cfg.bed.offsets[method or 'center'] or cfg.bed.offsets.center
end

function T.RotationToDirection(rotation)
    local adjustedRotation = {
        x = math.rad(rotation.x),
        y = math.rad(rotation.y),
        z = math.rad(rotation.z)
    }

    return vector3(
        -math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)),
        math.sin(adjustedRotation.x)
    )
end

function T.RaycastFromCamera(distance)
    local camRot = GetGameplayCamRot(2)
    local camCoord = GetGameplayCamCoord()
    local direction = T.RotationToDirection(camRot)
    local destination = camCoord + direction * (distance or 25.0)

    local rayHandle = StartShapeTestRay(camCoord.x, camCoord.y, camCoord.z, destination.x, destination.y, destination.z, -1, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

    return hit == 1, endCoords, surfaceNormal, entityHit
end

function T.PickWorldPoint(label, requireVehicle, requiredVehicle)
    T.ResetKeyPresses()
    T.Notify(label or _L('winch_select_help'), 'inform')

    local uiShown = false
    local text = ('[%s] Bevestigen  |  [%s] Annuleren'):format(T.GetDefaultKeyLabel('confirm'), T.GetDefaultKeyLabel('cancel'))

    while true do
        Wait(0)
        T.DisablePointSelectControls()

        local hit, coords, _, entity = T.RaycastFromCamera(35.0)

        if hit then
            DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25, 212, 175, 55, 185, false, false, 2, false, nil, nil, false)

            if not uiShown then
                T.ShowControlsText(text)
                uiShown = true
            end

            if T.WasKeyPressed('confirm', Config.ItemControls.confirm or 24) then
                T.HideControlsText()
                T.ResetKeyPresses()

                if requireVehicle then
                    if not T.IsVehicleEntity(entity) then
                        T.Notify('Je moet een punt op een voertuig kiezen.', 'error')
                        Wait(350)
                    elseif requiredVehicle and entity ~= requiredVehicle then
                        T.Notify('Je moet het geselecteerde voertuig aanwijzen.', 'error')
                        Wait(350)
                    else
                        return coords, entity
                    end
                else
                    return coords, entity
                end
            end
        elseif uiShown then
            T.HideControlsText()
            uiShown = false
        end

        if T.WasKeyPressed('cancel', Config.ItemControls.cancel or 177) then
            T.HideControlsText()
            T.ResetKeyPresses()
            T.Notify(_L('winch_cancelled'), 'error')
            return nil, nil
        end
    end
end

function T.GetVehicleHookOffset(vehicle, worldCoords)
    local offset = GetOffsetFromEntityGivenWorldCoords(vehicle, worldCoords.x, worldCoords.y, worldCoords.z)
    return { x = offset.x, y = offset.y, z = offset.z }
end

function T.HasRemoteItem()
    if not Config.Remote.enabled then return false end
    if not Config.Remote.requireItem or not Config.Items.remote then return true end
    return lib.callback.await('rtv-towing:server:hasRemote', false)
end

function T.EnsureRopeTextures()
    RopeLoadTextures()
    local untilTime = GetGameTimer() + 1500
    while not RopeAreTexturesLoaded() and GetGameTimer() < untilTime do
        Wait(0)
    end
end

function T.CreateVisualRope(ropeKey, entityA, entityB, offsetA, offsetB, length)
    local ropes = T.State.activeRopes

    if ropes[ropeKey] and ropes[ropeKey].rope then
        DeleteRope(ropes[ropeKey].rope)
    end

    T.EnsureRopeTextures()

    local a = GetOffsetFromEntityInWorldCoords(entityA, offsetA.x, offsetA.y, offsetA.z)
    local b = GetOffsetFromEntityInWorldCoords(entityB, offsetB.x, offsetB.y, offsetB.z)

    local rope = AddRope(a.x, a.y, a.z, 0.0, 0.0, 0.0, length, Config.Rope.ropeType, length, 0.4, 1.0, false, true, true, 1.0, false, 0)
    AttachEntitiesToRope(rope, entityA, entityB, a.x, a.y, a.z, b.x, b.y, b.z, length, false, false, 0, 0)

    ropes[ropeKey] = { rope = rope, entityA = entityA, entityB = entityB, length = length }
    return rope
end

function T.DeleteRopeByKey(ropeKey)
    local data = T.State.activeRopes[ropeKey]

    if data and data.rope then DeleteRope(data.rope) end
    if data and data.dummy and DoesEntityExist(data.dummy) then DeleteEntity(data.dummy) end

    T.State.activeRopes[ropeKey] = nil
end

function T.CreateBlip(coords, sprite, color, scale, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite or 1)
    SetBlipColour(blip, color or 0)
    SetBlipScale(blip, scale or 0.8)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label or 'Towing')
    EndTextCommandSetBlipName(blip)
    return blip
end

RegisterNetEvent('rtv-towing:client:notify', function(message, nType)
    T.Notify(message, nType)
end)

T.RegisterTowingKeybinds()

T.Startup = T.Startup or {
    running = false,
    targets = false,
    repoMonitor = false,
    controlBlocker = false,
    crafting = false
}

function T.StartClientSystems()
    if T.Startup.running then return end
    T.Startup.running = true

    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(250) end
        while PlayerPedId() == 0 do Wait(250) end
        while GetResourceState('ox_target') ~= 'started' do Wait(500) end

        Wait(1500)

        if not T.Startup.targets and T.RegisterTowTruckTargets then
            T.RegisterTowTruckTargets()
            T.Startup.targets = true
        end

        if Config.Repo and Config.Repo.enabled and T.SpawnRepoPed then
            T.SpawnRepoPed()
        end

        if not T.Startup.repoMonitor and T.StartRepoMonitor then
            T.StartRepoMonitor()
            T.Startup.repoMonitor = true
        end

        if not T.Startup.controlBlocker and T.StartTowTruckControlBlocker then
            T.StartTowTruckControlBlocker()
            T.Startup.controlBlocker = true
        end

        if not T.Startup.crafting and T.RegisterCraftingZones then
            T.RegisterCraftingZones()
            T.Startup.crafting = true
        end

        T.Startup.running = false
    end)
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= T.ResourceName then return end
    T.StartClientSystems()
end)

CreateThread(function()
    Wait(2500)
    T.StartClientSystems()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= T.ResourceName then return end

    T.HideControlsText()
    T.State.activeOwnedTowId = nil
    T.State.activeOwnedWinchId = nil

    for key in pairs(T.State.activeRopes) do T.DeleteRopeByKey(key) end
    for truckNet in pairs(T.State.activeRamps) do TriggerEvent('rtv-towing:client:removeRamp', truckNet) end

    if T.State.repoPed and DoesEntityExist(T.State.repoPed) then DeleteEntity(T.State.repoPed) end
    if T.State.repoBlip then RemoveBlip(T.State.repoBlip) end

    if T.ClearRepoEntities then T.ClearRepoEntities(false) end
end)

exports('OpenBedMenu', function(...) return T.OpenBedMenu(...) end)
exports('OpenRemoteMenu', function(...) return T.OpenRemoteMenu(...) end)
exports('PlaceRampForTruck', function(...) return T.PlaceRampForTruck(...) end)
exports('RemoveRampForTruck', function(...) return T.RemoveRampForTruck(...) end)
exports('AttachVehicleToBed', function(...) return T.AttachVehicleToBed(...) end)
exports('DetachVehicleFromBed', function(...) return T.DetachVehicleFromBed(...) end)
exports('UseTowRope', function(...) return T.UseTowRopeItem(...) end)
exports('UseWinch', function(...) return T.UseWinchItem(...) end)
exports('IsVehicleOnBed', function(vehicle)
    local net = T.GetNetId(vehicle)
    return net and T.State.bedAttachments[net] ~= nil or false
end)