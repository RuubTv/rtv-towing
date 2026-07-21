local T = RTVTowing
local S = T.State

function T.AttachVehicleLocal(truckNet, vehicleNet, method)
    local truck = T.GetEntityFromNet(truckNet)
    local vehicle = T.GetEntityFromNet(vehicleNet)
    if truck == 0 or vehicle == 0 then return false end

    local cfg = T.ModelConfig(truck)
    local offset = T.GetBedOffset(truck, method)
    if not cfg or not offset then return false end

    T.RequestControl(vehicle, 1200)

    SetVehicleOnGroundProperly(vehicle)
    SetVehicleHandbrake(vehicle, true)
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleUndriveable(vehicle, true)
    FreezeEntityPosition(vehicle, true)

    local bone = GetEntityBoneIndexByName(truck, cfg.bed.bone or 'chassis')
    if bone == -1 then bone = 0 end

    AttachEntityToEntity(vehicle, truck, bone, offset.pos.x, offset.pos.y, offset.pos.z, offset.rot.x, offset.rot.y, offset.rot.z, false, false, true, false, 2, true)

    S.bedAttachments[vehicleNet] = { truckNet = truckNet, method = method or 'center' }
    return true
end

function T.DetachVehicleLocal(vehicleNet)
    local vehicle = T.GetEntityFromNet(vehicleNet)
    if vehicle == 0 then return false end

    local attachData = S.bedAttachments[vehicleNet]
    local truck = attachData and T.GetEntityFromNet(attachData.truckNet) or 0

    T.RequestControl(vehicle, 1500)

    local unloadCoords = GetEntityCoords(vehicle)
    local unloadHeading = GetEntityHeading(vehicle)

    if truck ~= 0 and DoesEntityExist(truck) then
        unloadCoords = GetOffsetFromEntityInWorldCoords(truck, 0.0, -8.25, 0.45)
        unloadHeading = GetEntityHeading(truck)
    end

    SetEntityCollision(vehicle, false, false)
    DetachEntity(vehicle, true, true)
    Wait(100)

    FreezeEntityPosition(vehicle, false)
    SetVehicleUndriveable(vehicle, false)
    SetVehicleHandbrake(vehicle, true)
    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    SetEntityAngularVelocity(vehicle, 0.0, 0.0, 0.0)

    SetEntityCoordsNoOffset(vehicle, unloadCoords.x, unloadCoords.y, unloadCoords.z + 0.25, false, false, false)
    SetEntityHeading(vehicle, unloadHeading)

    Wait(150)
    SetVehicleOnGroundProperly(vehicle)
    Wait(150)

    SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
    SetEntityAngularVelocity(vehicle, 0.0, 0.0, 0.0)
    SetEntityCollision(vehicle, true, true)

    CreateThread(function()
        Wait(750)
        if DoesEntityExist(vehicle) then
            SetVehicleHandbrake(vehicle, false)
            SetEntityVelocity(vehicle, 0.0, 0.0, 0.0)
            SetEntityAngularVelocity(vehicle, 0.0, 0.0, 0.0)
        end
    end)

    S.bedAttachments[vehicleNet] = nil
    return true
end

RegisterNetEvent('rtv-towing:client:syncBedAttach', function(truckNet, vehicleNet, method)
    T.AttachVehicleLocal(truckNet, vehicleNet, method)
end)

RegisterNetEvent('rtv-towing:client:syncBedDetach', function(vehicleNet)
    T.DetachVehicleLocal(vehicleNet)
end)

function T.AttachVehicleToBed(truck, target, method)
    if truck == 0 or target == 0 then return T.Notify(_L('no_vehicle'), 'error') end
    if truck == target then return T.Notify(_L('no_target_vehicle'), 'error') end

    local cfg = T.ModelConfig(truck)
    if not cfg then return T.Notify(_L('no_truck'), 'error') end

    local allowed = lib.callback.await('rtv-towing:server:canUse', false, 'bed')
    if not allowed then return T.Notify(_L('no_access'), 'error') end

    local truckNet = T.GetNetId(truck)
    local vehicleNet = T.GetNetId(target)
    if not truckNet or not vehicleNet then return T.Notify(_L('no_vehicle'), 'error') end

    T.RequestControl(target, 1500)

    if not T.DoWorkAnim('Voertuig vastzetten op laadbed...', 3000, 'bed') then
        return T.Notify('Vastzetten geannuleerd.', 'error')
    end

    TriggerServerEvent('rtv-towing:server:attachBed', truckNet, vehicleNet, method or 'center')
    T.Notify(_L('attached'), 'success')
end

function T.DetachVehicleFromBed(vehicle)
    if vehicle == 0 then return T.Notify(_L('no_vehicle'), 'error') end

    local vehicleNet = T.GetNetId(vehicle)
    if not vehicleNet then return end

    if not T.DoWorkAnim('Voertuig losmaken van laadbed...', 2200, 'bed') then
        return T.Notify('Losmaken geannuleerd.', 'error')
    end

    TriggerServerEvent('rtv-towing:server:detachBed', vehicleNet)
    T.Notify(_L('detached'), 'success')
end

local function createRampObject(modelName, coords, heading, rot, freeze)
    local model = T.LoadModel(modelName)

    if not model then
        T.Notify(('Ramp model niet gevonden: %s'):format(modelName), 'error')
        return 0
    end

    local obj = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)

    SetEntityHeading(obj, heading)
    SetEntityRotation(obj, rot.x, rot.y, heading + rot.z, 2, true)
    SetEntityAsMissionEntity(obj, true, true)

    if freeze then
        FreezeEntityPosition(obj, true)
    end

    return obj
end

function T.PlaceRampForTruck(truck)
    if not truck or truck == 0 then
        truck = T.GetClosestTruck(GetEntityCoords(PlayerPedId()), 10.0)
    end

    if truck == 0 or not T.ModelConfig(truck) then
        return T.Notify(_L('ramp_no_truck'), 'error')
    end

    local rampCfg = T.GetRampConfig(truck)

    if not rampCfg or not rampCfg.enabled then
        return T.Notify('Deze towtruck heeft geen ramp configuratie.', 'error')
    end

    local allowed = lib.callback.await('rtv-towing:server:canUse', false, 'bed')

    if not allowed then
        return T.Notify(_L('no_access'), 'error')
    end

    local truckNet = T.GetNetId(truck)

    if S.activeRamps[truckNet] then
        return T.Notify(_L('ramp_already'), 'error')
    end

    if not T.DoWorkAnim('Ramp neerzetten...', 3500, 'ramp') then
        return T.Notify('Ramp plaatsen geannuleerd.', 'error')
    end

    local heading = GetEntityHeading(truck)
    local rampNets = {}

    if rampCfg.twoRamps then
        local leftOffset = rampCfg.offsets.left
        local rightOffset = rampCfg.offsets.right

        local left = GetOffsetFromEntityInWorldCoords(
            truck,
            leftOffset.x,
            leftOffset.y,
            leftOffset.z
        )

        local right = GetOffsetFromEntityInWorldCoords(
            truck,
            rightOffset.x,
            rightOffset.y,
            rightOffset.z
        )

        local leftObj = createRampObject(
            rampCfg.model,
            left,
            heading,
            rampCfg.rotation,
            rampCfg.freeze
        )

        local rightObj = createRampObject(
            rampCfg.model,
            right,
            heading,
            rampCfg.rotation,
            rampCfg.freeze
        )

        if leftObj ~= 0 then
            rampNets[#rampNets + 1] = T.GetNetId(leftObj)
        end

        if rightObj ~= 0 then
            rampNets[#rampNets + 1] = T.GetNetId(rightObj)
        end
    else
        local offset = rampCfg.singleOffset

        local rampCoords = GetOffsetFromEntityInWorldCoords(
            truck,
            offset.x,
            offset.y,
            offset.z
        )

        local rampObj = createRampObject(
            rampCfg.model,
            rampCoords,
            heading,
            rampCfg.rotation,
            rampCfg.freeze
        )

        if rampObj ~= 0 then
            rampNets[#rampNets + 1] = T.GetNetId(rampObj)
        end
    end

    S.activeRamps[truckNet] = rampNets

    TriggerServerEvent('rtv-towing:server:setRamp', truckNet, rampNets)

    T.Notify(_L('ramp_placed'), 'success')
end

function T.RemoveRampForTruck(truck)
    if not truck or truck == 0 then truck = T.GetClosestTruck(GetEntityCoords(PlayerPedId()), 10.0) end
    if truck == 0 then return T.Notify(_L('ramp_no_truck'), 'error') end

    local truckNet = T.GetNetId(truck)
    if not S.activeRamps[truckNet] then return T.Notify('Er staat geen ramp achter deze truck.', 'error') end

    if not T.DoWorkAnim('Ramp opruimen...', 2500, 'ramp') then
        return T.Notify('Ramp opruimen geannuleerd.', 'error')
    end

    for _, rampNet in ipairs(S.activeRamps[truckNet]) do
        local obj = T.GetEntityFromNet(rampNet)
        if obj ~= 0 and DoesEntityExist(obj) then
            T.RequestControl(obj, 750)
            DeleteEntity(obj)
        end
    end

    S.activeRamps[truckNet] = nil
    TriggerServerEvent('rtv-towing:server:removeRamp', truckNet)
    T.Notify(_L('ramp_removed'), 'success')
end

RegisterNetEvent('rtv-towing:client:removeRamp', function(truckNet)
    if not S.activeRamps[truckNet] then return end
    for _, rampNet in ipairs(S.activeRamps[truckNet]) do
        local obj = T.GetEntityFromNet(rampNet)
        if obj ~= 0 and DoesEntityExist(obj) then
            T.RequestControl(obj, 750)
            DeleteEntity(obj)
        end
    end
    S.activeRamps[truckNet] = nil
end)

local function removeNearbyRampObjects()
    local allowed = lib.callback.await('rtv-towing:server:canUse', false, 'bed')
    if not allowed then return T.Notify(_L('no_access'), 'error') end
    if not Config.Ramp or not Config.Ramp.model then return T.Notify('Ramp model staat niet goed ingesteld in de config.', 'error') end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local rampModels = {}

if Config.Ramp and Config.Ramp.model then
    rampModels[joaat(Config.Ramp.model)] = true
end

for _, truckCfg in pairs(Config.Trucks or {}) do
    if truckCfg.ramp and truckCfg.ramp.model then
        rampModels[joaat(truckCfg.ramp.model)] = true
    end
end
    local distance = Config.Ramp.removeCommand and Config.Ramp.removeCommand.distance or 15.0
    local removed = 0

    for _, object in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(object) and rampModels[GetEntityModel(object)] then
            local objCoords = GetEntityCoords(object)
            if #(playerCoords - objCoords) <= distance then
                T.RequestControl(object, 1500)
                SetEntityAsMissionEntity(object, true, true)
                DetachEntity(object, true, true)
                DeleteEntity(object)
                removed = removed + 1
            end
        end
    end

    for truckNet, rampNets in pairs(S.activeRamps) do
        local shouldClear = false
        for _, rampNet in ipairs(rampNets) do
            local ramp = T.GetEntityFromNet(rampNet)
            if ramp == 0 or not DoesEntityExist(ramp) then
                shouldClear = true
                break
            end
            local rampCoords = GetEntityCoords(ramp)
            if #(playerCoords - rampCoords) <= distance then
                shouldClear = true
                break
            end
        end
        if shouldClear then
            S.activeRamps[truckNet] = nil
            TriggerServerEvent('rtv-towing:server:removeRamp', truckNet)
        end
    end

    if removed > 0 then
        T.Notify(('Alle nabije ramps zijn verwijderd. Aantal: %s'):format(removed), 'success', 'Ramp')
    else
        T.Notify('Geen ramp gevonden in de buurt.', 'inform', 'Ramp')
    end
end

CreateThread(function()
    Wait(500)
    if not Config.Ramp.removeCommand or Config.Ramp.removeCommand.enabled ~= true then return end
    RegisterCommand(Config.Ramp.removeCommand.command or 'ramp', function()
        removeNearbyRampObjects()
    end, false)
end)

function T.OpenBedMenu(truck)
    if not truck or truck == 0 then truck = T.GetClosestTruck(GetEntityCoords(PlayerPedId()), 10.0) end
    if truck == 0 or not T.ModelConfig(truck) then return T.Notify(_L('no_truck'), 'error') end

    local cfg = T.ModelConfig(truck)
    local coords = GetEntityCoords(truck)
    local target = T.GetClosestVehicle(coords, cfg.bed.searchRadius or 8.0, truck)
    local useCustom = true
    local options = {}

    if target ~= 0 then
        for method, data in pairs(cfg.bed.offsets) do
            options[#options + 1] = {
                title = ('Vastmaken: %s'):format(data.label or method),
                description = 'Zet het dichtstbijzijnde voertuig vast op het laadbed.',
                icon = useCustom and '🔒' or 'truck-ramp-box',
                metadata = { { label = 'Positie', value = data.label or method } },
                onSelect = function() T.AttachVehicleToBed(truck, target, method) end
            }
        end
    else
        options[#options + 1] = { title = _L('no_target_vehicle'), description = 'Er staat geen voertuig dichtbij genoeg.', icon = useCustom and '!' or 'triangle-exclamation', disabled = true }
    end

    local attachedOnTruck = false
    local truckNet = T.GetNetId(truck)

    for vehicleNet, data in pairs(S.bedAttachments) do
        if data.truckNet == truckNet then
            attachedOnTruck = true
            options[#options + 1] = {
                title = 'Losmaken voertuig op laadbed',
                description = 'Haal het voertuig van het laadbed af.',
                icon = useCustom and '🔓' or 'unlock',
                onSelect = function() T.DetachVehicleFromBed(T.GetEntityFromNet(vehicleNet)) end
            }
            options[#options + 1] = {
                title = 'Force re-snap laadbed',
                description = 'Zet de laadbed-attach opnieuw vast.',
                icon = useCustom and '↻' or 'arrows-rotate',
                onSelect = function()
                    TriggerServerEvent('rtv-towing:server:attachBed', truckNet, vehicleNet, data.method or 'center')
                    T.Notify('Laadbed-attach opnieuw gezet.', 'success')
                end
            }
        end
    end

    if not attachedOnTruck then
        options[#options + 1] = { title = 'Geen voertuig vast op dit laadbed', description = 'Er is momenteel geen voertuig gekoppeld aan deze truck.', icon = useCustom and 'ℹ' or 'circle-info', disabled = true }
    end

    local rampCfg = T.GetRampConfig(truck)

if rampCfg and rampCfg.enabled then
        options[#options + 1] = { title = 'Ramp neerzetten', description = 'Plaats de ramp achter de towtruck.', icon = useCustom and '▰' or 'road', onSelect = function() T.PlaceRampForTruck(truck) end }
        options[#options + 1] = { title = 'Ramp opruimen', description = 'Verwijder de ramp achter de towtruck.', icon = useCustom and '🧹' or 'broom', onSelect = function() T.RemoveRampForTruck(truck) end }
    end

    T.UI.OpenMenu({
        id = 'rtv_towing_bed_menu',
        title = _L('menu_bed'),
        subtitle = 'Laadbed, voertuigbevestiging en rampbediening',
        options = options
    })
end

function T.OpenRemoteMenu()
    if not Config.Remote.enabled then return end
    if not T.HasRemoteItem() then return T.Notify(_L('remote_no_item'), 'error') end

    local truck = T.GetClosestTruck(GetEntityCoords(PlayerPedId()), 12.0)
    local rampCfg = truck ~= 0 and T.GetRampConfig(truck) or nil
    local useCustom = true
    local options = {}

    if Config.Remote.allowBed then
        options[#options + 1] = { title = 'Laadbed menu openen', description = 'Open het laadbedmenu van de dichtstbijzijnde towtruck.', icon = useCustom and '🚚' or 'truck-ramp-box', disabled = truck == 0, onSelect = function() T.OpenBedMenu(truck) end }
    end

    if Config.Remote.allowRamp then
        options[#options + 1] = { title = 'Ramp neerzetten', description = 'Plaats de ramp achter de dichtstbijzijnde towtruck.', icon = useCustom and '▰' or 'road', disabled = truck == 0 or not rampCfg or not rampCfg.enabled, onSelect = function() T.PlaceRampForTruck(truck) end }
        options[#options + 1] = { title = 'Ramp opruimen', description = 'Verwijder de ramp achter de dichtstbijzijnde towtruck.', icon = useCustom and '🧹' or 'broom', disabled = truck == 0 or not rampCfg or not rampCfg.enabled, onSelect = function() T.RemoveRampForTruck(truck) end }
    end

    if Config.Remote.allowTow then
        options[#options + 1] = { title = 'Tow rope gebruiken', description = 'Start het sleepkabel punt-selectie systeem.', icon = useCustom and '🔗' or 'link', onSelect = function() T.UseTowRopeItem() end }
    end

    if Config.Remote.allowWinch then
        options[#options + 1] = { title = 'Winch gebruiken', description = 'Start het winch punt-selectie systeem.', icon = useCustom and '⚓' or 'anchor', onSelect = function() T.UseWinchItem() end }
    end

    if #options == 0 then
        options[#options + 1] = { title = 'Geen remote opties beschikbaar', description = 'Er zijn geen functies actief voor deze remote.', icon = useCustom and 'ℹ' or 'circle-info', disabled = true }
    end

    T.UI.OpenMenu({
        id = 'rtv_towing_remote_menu',
        title = _L('remote_menu'),
        subtitle = 'Towtruck remote bediening',
        options = options
    })
end

RegisterNetEvent('rtv-towing:client:openRemote', function()
    T.OpenRemoteMenu()
end)

function T.RegisterTowTruckTargets()
    exports.ox_target:addGlobalVehicle({
        {
            name = 'rtv_towing_bed_menu',
            icon = 'fa-solid fa-truck-ramp-box',
            label = 'Laadbed menu',
            distance = 3.0,
            canInteract = function(entity) return T.ModelConfig(entity) ~= nil and T.CanUseClient('bed') end,
            onSelect = function(data) T.OpenBedMenu(data.entity) end
        },
        {
            name = 'rtv_towing_place_ramp',
            icon = 'fa-solid fa-road',
            label = 'Ramp neerzetten',
            distance = 3.0,
            canInteract = function(entity)
    local rampCfg = T.GetRampConfig(entity)

    return rampCfg and rampCfg.enabled and T.CanUseClient('bed')
end,
            onSelect = function(data) T.PlaceRampForTruck(data.entity) end
        },
        {
            name = 'rtv_towing_remove_ramp',
            icon = 'fa-solid fa-broom',
            label = 'Ramp opruimen',
            distance = 3.0,
            canInteract = function(entity)
    local rampCfg = T.GetRampConfig(entity)

    return rampCfg and rampCfg.enabled and T.CanUseClient('bed')
end,
            onSelect = function(data) T.RemoveRampForTruck(data.entity) end
        }
    })
end

function T.StartTowTruckControlBlocker()
    if not Config.Controls.disableFmltowBedKeys then return end

    CreateThread(function()
        while true do
            local sleep = 1000
            local ped = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped then
                local model = GetEntityModel(vehicle)
                if Config.Trucks[model] then
                    sleep = 0
                    for _, control in ipairs(Config.Controls.disabledInTowTruck) do
                        DisableControlAction(0, control, true)
                    end
                end
            end
            Wait(sleep)
        end
    end)
end
