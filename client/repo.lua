local T = RTVTowing
local S = T.State

local function normalizePlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', '')
end

local function clearReturnableRepoTruck()
    S.returnableRepoTruck = nil
    S.returnableRepoTruckNet = nil
    S.returnableRepoTruckPlate = nil
    S.returnableRepoTruckModel = nil
end

local function rememberReturnableRepoTruck(truck)
    if not truck or truck == 0 or not DoesEntityExist(truck) then
        return false
    end

    S.returnableRepoTruck = truck
    S.returnableRepoTruckNet = T.GetNetId(truck)
    S.returnableRepoTruckPlate = normalizePlate(GetVehicleNumberPlateText(truck))
    S.returnableRepoTruckModel = GetEntityModel(truck)

    return true
end

local function findReturnableRepoTruckNearStart()
    local startCoords = Config.Repo.startPed.coords
    local startVec = vector3(startCoords.x, startCoords.y, startCoords.z)
    local radius = Config.Repo.returnTruckDistance or 18.0

    local wantedPlate = normalizePlate(S.returnableRepoTruckPlate)
    local wantedModel = S.returnableRepoTruckModel

    if not wantedModel and Config.Repo.companyTruckModel then
        wantedModel = joaat(Config.Repo.companyTruckModel)
    end

    if S.returnableRepoTruck and DoesEntityExist(S.returnableRepoTruck) then
        local truck = S.returnableRepoTruck
        local dist = #(GetEntityCoords(truck) - startVec)

        if dist <= radius then
            local plate = normalizePlate(GetVehicleNumberPlateText(truck))

            if wantedPlate == '' or plate == wantedPlate then
                return truck, T.GetNetId(truck), plate
            end
        end
    end

    local closestTruck = 0
    local closestNet = nil
    local closestPlate = nil
    local closestDistance = radius + 0.01

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local modelOk = not wantedModel or GetEntityModel(vehicle) == wantedModel
            local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))
            local plateOk = wantedPlate == '' or plate == wantedPlate

            if modelOk and plateOk then
                local distance = #(GetEntityCoords(vehicle) - startVec)

                if distance <= closestDistance then
                    closestTruck = vehicle
                    closestNet = T.GetNetId(vehicle)
                    closestPlate = plate
                    closestDistance = distance
                end
            end
        end
    end

    return closestTruck, closestNet, closestPlate
end

local function removeBlipSafe(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end

local function removeSearchBlips()
    if not S.activeRepo or not S.activeRepo.searchBlips then return end
    for _, blip in ipairs(S.activeRepo.searchBlips) do removeBlipSafe(blip) end
    S.activeRepo.searchBlips = {}
end

local function removeDropoffPed()
    if not S.activeRepo or not S.activeRepo.dropoffPed then return end
    local ped = S.activeRepo.dropoffPed
    if DoesEntityExist(ped) then
        pcall(function()
            exports.ox_target:removeLocalEntity(ped, { 'rtv_towing_dropoff_deliver' })
        end)
        T.RequestControl(ped, 500)
        DeleteEntity(ped)
    end
    S.activeRepo.dropoffPed = nil
end

function T.ClearRepoEntities(keepTruck)
    removeSearchBlips()
    removeDropoffPed()

    if T.UI and T.UI.HideRepoNote then
        T.UI.HideRepoNote()
    end

    local keepEntity = nil
    if keepTruck and S.activeRepo and S.activeRepo.truck and DoesEntityExist(S.activeRepo.truck) then
        keepEntity = S.activeRepo.truck
        rememberReturnableRepoTruck(keepEntity)
    end

    for _, entity in ipairs(S.spawnedRepoEntities) do
        if DoesEntityExist(entity) and entity ~= keepEntity then
            T.RequestControl(entity, 500)
            DeleteEntity(entity)
        end
    end

    S.spawnedRepoEntities = {}

    if S.activeRepo and S.activeRepo.pickupBlip then removeBlipSafe(S.activeRepo.pickupBlip) end
    if S.activeRepo and S.activeRepo.dropoffBlip then removeBlipSafe(S.activeRepo.dropoffBlip) end

    S.activeRepo = nil
    S.repoDropoffRevealed = false
end

local function createSearchBlips(searchLocations)
    local blips = {}
    for index, coords in ipairs(searchLocations or {}) do
        local label = ('Mogelijke repo locatie %s'):format(index)
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 225)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.82)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(label)
        EndTextCommandSetBlipName(blip)
        blips[#blips + 1] = blip
    end
    return blips
end


local function waitForVehicleFromNet(netId, timeoutMs)
    netId = tonumber(netId)

    if not netId or netId == 0 then
        return 0
    end

    local timeout = GetGameTimer() + (timeoutMs or 5000)

    while GetGameTimer() < timeout do
        local vehicle = T.GetVehicleFromNetIdSafe(netId)

        if vehicle ~= 0 then
            return vehicle
        end

        Wait(50)
    end

    return 0
end

local function resolveCompanyTruck(data, existingTruck)
    local truck = 0

    if data and data.companyTruckNet then
        truck = waitForVehicleFromNet(data.companyTruckNet, 7000)

        if truck ~= 0 then
            return truck
        end

        T.Notify('Repo vrachtwagen is server-side gespawned, maar nog niet ingeladen bij jouw client.', 'inform')
    end

    if existingTruck and existingTruck ~= 0 and DoesEntityExist(existingTruck) then
        return existingTruck
    end

    if S.returnableRepoTruck and DoesEntityExist(S.returnableRepoTruck) then
        return S.returnableRepoTruck
    end

    return T.GetClosestTruck(GetEntityCoords(PlayerPedId()), 20.0)
end

local function spawnAngryPedsAround(coords)
    if not Config.Repo.spawnAngryPeds then return end

    local modifier = S.activeRepo and S.activeRepo.angryChanceModifier or 1.0
    local chance1 = math.floor((Config.Repo.angryPeds.chance1 or 0) * modifier + 0.5)
    local chance2 = math.floor((Config.Repo.angryPeds.chance2 or 0) * modifier + 0.5)

    local pedsToSpawn = 0
    if math.random(100) <= chance1 then pedsToSpawn = pedsToSpawn + 1 end
    if pedsToSpawn > 0 and math.random(100) <= chance2 then pedsToSpawn = pedsToSpawn + 1 end

    for _ = 1, pedsToSpawn do
        local modelName = Config.Repo.angryPeds.models[math.random(#Config.Repo.angryPeds.models)]
        local model = T.LoadModel(modelName)
        if model then
            local offset = vec3(math.random(-5, 5) + 0.0, math.random(-5, 5) + 0.0, 0.0)
            local ped = CreatePed(4, model, coords.x + offset.x, coords.y + offset.y, coords.z, math.random(0, 360) + 0.0, true, true)
            if ped and ped ~= 0 and DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                SetPedCombatAttributes(ped, 46, true)
                SetPedCombatAbility(ped, 1)
                SetPedCombatRange(ped, 1)
                GiveWeaponToPed(ped, Config.Repo.angryPeds.weapons[math.random(#Config.Repo.angryPeds.weapons)], 1, false, true)
                TaskCombatPed(ped, PlayerPedId(), 0, 16)
                S.spawnedRepoEntities[#S.spawnedRepoEntities + 1] = ped
            end
        end
    end
end

local function spawnDropoffPed()
    if not S.activeRepo then return false end

    local pedCfg = Config.Repo.dropoffPed or { enabled = true, model = 's_m_m_autoshop_02', scenario = 'WORLD_HUMAN_CLIPBOARD', spawnDistance = 120.0 }
    if pedCfg.enabled == false then return false end
    if S.activeRepo.dropoffPed and DoesEntityExist(S.activeRepo.dropoffPed) then return true end

    local dropCoords = S.activeRepo.dropoff and (S.activeRepo.dropoff.ped or S.activeRepo.dropoff.truck)
    if not dropCoords then return false end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local dropVec = vector3(dropCoords.x, dropCoords.y, dropCoords.z)
    local spawnDistance = pedCfg.spawnDistance or 120.0
    if #(playerCoords - dropVec) > spawnDistance then return false end

    local model = T.LoadModel(pedCfg.model or 's_m_m_autoshop_02')
    if not model then return false end

    RequestCollisionAtCoord(dropCoords.x, dropCoords.y, dropCoords.z)
    local timeout = GetGameTimer() + 3000
    while GetGameTimer() < timeout do
        RequestCollisionAtCoord(dropCoords.x, dropCoords.y, dropCoords.z)
        Wait(0)
    end

    local foundGround, groundZ = GetGroundZFor_3dCoord(dropCoords.x, dropCoords.y, dropCoords.z + 5.0, false)
    local spawnZ = foundGround and groundZ or dropCoords.z
    local heading = dropCoords.w or 0.0
    local ped = CreatePed(4, model, dropCoords.x, dropCoords.y, spawnZ, heading, true, true)

    Wait(250)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end

    SetEntityAsMissionEntity(ped, true, true)
    SetEntityCoords(ped, dropCoords.x, dropCoords.y, spawnZ, false, false, false, false)
    SetEntityHeading(ped, heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    if pedCfg.scenario then TaskStartScenarioInPlace(ped, pedCfg.scenario, 0, true) end

    S.activeRepo.dropoffPed = ped
    S.spawnedRepoEntities[#S.spawnedRepoEntities + 1] = ped

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'rtv_towing_dropoff_deliver',
            icon = 'fa-solid fa-clipboard-check',
            label = 'Repo voertuig afleveren',
            distance = 2.5,
            canInteract = function() return S.activeRepo ~= nil and S.activeRepo.secured == true end,
            onSelect = function() T.FinishRepoMission() end
        }
    })

    T.Notify(_L('repo_dropoff_ready'), 'success')
    return true
end

local function revealDropoff()
    if not S.activeRepo or S.activeRepo.dropoffRevealed then return end

    removeSearchBlips()
    S.activeRepo.dropoffBlip = T.CreateBlip(S.activeRepo.dropoff.truck, 68, 43, 0.85, 'Repo afleverpunt')
    S.activeRepo.dropoffRevealed = true
    S.repoDropoffRevealed = true
    spawnDropoffPed()
    T.Notify(_L('repo_vehicle_secured'), 'success')
end

RegisterNetEvent('rtv-towing:client:repoVehicleSecured', function(vehicleNet, repoId)
    if not S.activeRepo then
        return
    end

    if repoId and S.activeRepo.id ~= repoId then
        return
    end

    if vehicleNet and S.activeRepo.targetNet and tonumber(vehicleNet) ~= tonumber(S.activeRepo.targetNet) then
        return
    end

    if S.activeRepo.secured then
        return
    end

    S.activeRepo.secured = true

    revealDropoff()
end)

local function getZoneLabel(coords)
    local zone = GetNameOfZone(coords.x, coords.y, coords.z)
    local label = GetLabelText(zone)
    if label and label ~= 'NULL' then return label end
    return zone or 'Onbekend gebied'
end

local function getStreetLabel(coords)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)
    if streetName and streetName ~= '' then return streetName end
    return nil
end

local function formatRepoLocationsForUi(searchLocations)
    local locations = {}
    for index, coords in ipairs(searchLocations or {}) do
        local letter = string.char(64 + index)
        local zone = getZoneLabel(coords)
        local street = getStreetLabel(coords)
        if street then
            locations[#locations + 1] = ('Locatie %s - %s / %s'):format(letter, zone, street)
        else
            locations[#locations + 1] = ('Locatie %s - %s'):format(letter, zone)
        end
    end
    return locations
end

local function showRepoNoteUi(data)
    if not T.UI or not T.UI.ShowRepoNote then return end

    local hint = nil

    -- Eerste skill: Betere Repo Note.
    -- Geen locaties meer in beeld; alleen voertuig, kenteken en eventueel kleurhint.
    if data.noteExtra and data.vehicleColor then
        hint = ('Kleur: %s'):format(data.vehicleColor)
    end

    if data.premium then
        hint = hint and (hint .. ' • Premium contract') or 'Premium contract'
    end

    T.UI.ShowRepoNote({
        title = data.premium and 'Premium Repo' or 'Repo Note',
        vehicle = data.vehicleModel or 'Onbekend',
        plate = data.plate or 'Onbekend',
        hint = hint,
        hintLabel = 'Voertuig hint',
        persistent = true,
        duration = 0
    })
end

local function getSafeRepoSpawnCoords(spawn)
    local offsets = {
        vec3(0.0, 0.0, 0.0),
        vec3(2.5, 0.0, 0.0),
        vec3(-2.5, 0.0, 0.0),
        vec3(0.0, 2.5, 0.0),
        vec3(0.0, -2.5, 0.0),
        vec3(4.0, 0.0, 0.0),
        vec3(-4.0, 0.0, 0.0),
    }

    for _, offset in ipairs(offsets) do
        local x = spawn.x + offset.x
        local y = spawn.y + offset.y
        local z = spawn.z + offset.z

        RequestCollisionAtCoord(x, y, z)

        local foundGround, groundZ = GetGroundZFor_3dCoord(x, y, z + 35.0, false)
        local finalZ = foundGround and groundZ + 0.35 or z + 0.35

        if not IsAnyVehicleNearPoint(x, y, finalZ, 2.5) then
            return vec4(x, y, finalZ, spawn.w or 0.0)
        end
    end

    return vec4(spawn.x, spawn.y, spawn.z + 0.35, spawn.w or 0.0)
end


local function spawnRepoTargetVehicle()
    if not S.activeRepo then
        return false
    end

    if S.activeRepo.targetVehicle and DoesEntityExist(S.activeRepo.targetVehicle) then
        return true
    end

    if S.activeRepo.targetSpawned and S.activeRepo.targetNet then
        local existingVehicle = waitForVehicleFromNet(S.activeRepo.targetNet, 250)

        if existingVehicle ~= 0 then
            S.activeRepo.targetVehicle = existingVehicle
            return true
        end
    end

    local pickup = S.activeRepo.pickup

    if not pickup then
        return false
    end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local pickupVec = vector3(pickup.x, pickup.y, pickup.z)
    local spawnDistance = Config.Repo.vehicleSpawnDistance or 180.0

    if #(playerCoords - pickupVec) > spawnDistance then
        return false
    end

    local now = GetGameTimer()

    -- Voorkomt dat de monitor elke seconde opnieuw een spawn request stuurt.
    if S.activeRepo.lastSpawnAttempt and now - S.activeRepo.lastSpawnAttempt < 10000 then
        return false
    end

    S.activeRepo.lastSpawnAttempt = now

    local ok, targetNet, msg, vehicleColor = lib.callback.await(
        'rtv-towing:server:spawnRepoVehicle',
        false,
        S.activeRepo.id
    )

    if vehicleColor and not S.activeRepo.vehicleColor then
        S.activeRepo.vehicleColor = vehicleColor
    end

    if not ok or not targetNet then
        if not S.activeRepo.spawnFailedNotified then
            S.activeRepo.spawnFailedNotified = true
            T.Notify(msg or 'Repo voertuig kon niet server-side gespawned worden.', 'error')
        end

        return false
    end

    local targetVehicle = waitForVehicleFromNet(targetNet, 7000)

    if targetVehicle == 0 or not DoesEntityExist(targetVehicle) then
        S.activeRepo.targetNet = targetNet
        S.activeRepo.targetSpawned = false

        if not S.activeRepo.spawnFailedNotified then
            S.activeRepo.spawnFailedNotified = true
            T.Notify('Repo voertuig is server-side gespawned, maar nog niet ingeladen. Benader de locatie opnieuw.', 'inform')
        end

        return false
    end

    SetEntityAsMissionEntity(targetVehicle, true, true)
    SetVehicleOnGroundProperly(targetVehicle)
    SetVehicleDirtLevel(targetVehicle, math.random(1, 10) + 0.0)

    if Config.Repo.lockRepoVehicle then
        SetVehicleDoorsLocked(targetVehicle, 2)
    end

    if Config.VehicleKeys and Config.VehicleKeys.enabled and Config.VehicleKeys.unlockRepoVehicle then
        SetVehicleDoorsLocked(targetVehicle, 1)
        SetVehicleDoorsLockedForAllPlayers(targetVehicle, false)
    end

    S.activeRepo.targetVehicle = targetVehicle
    S.activeRepo.targetNet = targetNet
    S.activeRepo.targetSpawned = true
    S.activeRepo.spawnFailedNotified = false

    S.spawnedRepoEntities[#S.spawnedRepoEntities + 1] = targetVehicle

    if not S.activeRepo.angryPedsSpawned then
        S.activeRepo.angryPedsSpawned = true
        spawnAngryPedsAround(vector3(pickup.x, pickup.y, pickup.z))
    end

    if Config.Debug then
        print(('[rtv-towing] Repo voertuig ontvangen van server. NetID: %s'):format(targetNet))
    end

    return true
end


local function startRepoMission(data, existingTruck)
    if S.activeRepo then
        return T.Notify(_L('repo_active'), 'error')
    end

    local truck = resolveCompanyTruck(data, existingTruck)

    if existingTruck and existingTruck ~= 0 and DoesEntityExist(existingTruck) then
        clearReturnableRepoTruck()
    elseif S.returnableRepoTruck and DoesEntityExist(S.returnableRepoTruck) then
        clearReturnableRepoTruck()
    end

    S.activeRepo = {
        id = data.id,
        truck = truck,
        companyTruckNet = data.companyTruckNet,

        -- Repo voertuig wordt server-side gespawned zodra de speler dichtbij de echte pickup komt.
        targetVehicle = nil,
        targetNet = data.targetNet,
        targetSpawned = false,
        angryPedsSpawned = false,
        lastSpawnAttempt = nil,
        spawnFailedNotified = false,

        pickup = data.pickup,
        searchLocations = data.searchLocations or {},
        searchBlips = createSearchBlips(data.searchLocations or { data.pickup }),
        dropoff = data.dropoff,
        plate = data.plate,
        vehicleModel = data.vehicleModel,
        vehicleColor = data.vehicleColor,
        premium = data.premium == true,
        riskLevel = data.riskLevel,
        riskVisible = data.riskVisible == true,
        noteExtra = data.noteExtra == true,
        angryChanceModifier = data.angryChanceModifier or 1.0,
        dropoffBlip = nil,
        dropoffPed = nil,
        secured = false,
        dropoffRevealed = false
    }

    S.repoDropoffRevealed = false

    T.Notify((_L('repo_note_received')):format(data.vehicleModel, data.plate), 'success', 'Repo')
    T.Notify(_L('repo_search_started'), 'inform', 'Repo')
    showRepoNoteUi(data)

    if Config.Repo.autoWaypoint then
        SetNewWaypoint(data.pickup.x, data.pickup.y)
    end

    -- Als de speler toevallig al dichtbij staat, vraagt hij direct server-side spawn aan.
    spawnRepoTargetVehicle()
end

local function openAfterDeliveryMenu(existingTruck)
    if existingTruck and existingTruck ~= 0 and DoesEntityExist(existingTruck) then
        rememberReturnableRepoTruck(existingTruck)
    end

    if T.OpenRepoDashboard then
        T.OpenRepoDashboard()
    else
        T.Notify(_L('repo_finished'), 'success', 'Repo')
    end
end

local function findRepoVehicleNearDropoff()
    if not S.activeRepo then
        return 0, nil
    end

    local repoPlate = normalizePlate(S.activeRepo.plate)

    if repoPlate == '' then
        return 0, nil
    end

    local drop = vector3(
        S.activeRepo.dropoff.truck.x,
        S.activeRepo.dropoff.truck.y,
        S.activeRepo.dropoff.truck.z
    )

    local radius = Config.Repo.deliveryVehicleRadius or 18.0
    local closestVehicle = 0
    local closestDistance = radius + 0.01

    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(vehicle) then
            local plate = normalizePlate(GetVehicleNumberPlateText(vehicle))

            if plate == repoPlate then
                local distance = #(GetEntityCoords(vehicle) - drop)

                if distance <= closestDistance then
                    closestVehicle = vehicle
                    closestDistance = distance
                end
            end
        end
    end

    if closestVehicle ~= 0 then
        return closestVehicle, T.GetNetId(closestVehicle)
    end

    return 0, nil
end

function T.FinishRepoMission()
    if not S.activeRepo then
        return T.Notify(_L('repo_none'), 'error')
    end

    local repoVehicle = 0
    local targetNet = nil

    -- Eerst proberen via opgeslagen entity handle.
    if S.activeRepo.targetVehicle and DoesEntityExist(S.activeRepo.targetVehicle) then
        repoVehicle = S.activeRepo.targetVehicle
        targetNet = T.GetNetId(repoVehicle)
    end

    -- Fallback: opnieuw zoeken op kenteken bij afleverpunt.
    if repoVehicle == 0 or not targetNet then
        repoVehicle, targetNet = findRepoVehicleNearDropoff()
    end

    if repoVehicle == 0 or not targetNet then
        return T.Notify(_L('repo_need_vehicle'), 'error')
    end

    -- Update lokale repo state met verse entity/netId.
    S.activeRepo.targetVehicle = repoVehicle
    S.activeRepo.targetNet = targetNet

    -- Voertuig moet eerst van het laadbed af.
    if S.bedAttachments[targetNet] then
        return T.Notify(_L('repo_unload_first'), 'error')
    end

    local vehicleCoords = GetEntityCoords(repoVehicle)
    local drop = vector3(
        S.activeRepo.dropoff.truck.x,
        S.activeRepo.dropoff.truck.y,
        S.activeRepo.dropoff.truck.z
    )

    local deliveryRadius = Config.Repo.deliveryVehicleRadius or 18.0

    if #(vehicleCoords - drop) > deliveryRadius then
        return T.Notify(_L('repo_vehicle_not_at_dropoff'), 'error')
    end

    local existingTruck = S.activeRepo.truck

    local ok, msg = lib.callback.await(
        'rtv-towing:server:finishRepo',
        false,
        S.activeRepo.id,
        targetNet,
        normalizePlate(GetVehicleNumberPlateText(repoVehicle))
    )

    if not ok then
        return T.Notify(msg or _L('repo_need_vehicle'), 'error')
    end

    Wait(500)

    -- true = vrachtwagen blijft staan.
    T.ClearRepoEntities(true)

    T.Notify(msg or _L('repo_finished'), 'success')

    Wait(500)

    openAfterDeliveryMenu(existingTruck)
end


local function returnRepoTruck()
    if S.activeRepo then
        return T.Notify('Je kunt de vrachtwagen niet terugbrengen tijdens een actieve repo-opdracht.', 'error')
    end

    local startCoords = Config.Repo.startPed.coords
    local playerCoords = GetEntityCoords(PlayerPedId())
    local startVec = vector3(startCoords.x, startCoords.y, startCoords.z)
    local returnDistance = Config.Repo.returnTruckDistance or 18.0

    if #(playerCoords - startVec) > returnDistance then
        return T.Notify(('Je moet bij de repo startlocatie staan om de vrachtwagen terug te brengen. Max afstand: %sm'):format(returnDistance), 'error')
    end

    local truck, truckNet, truckPlate = findReturnableRepoTruckNearStart()

    if not truck or truck == 0 or not DoesEntityExist(truck) then
        clearReturnableRepoTruck()
        return T.Notify(_L('repo_no_return_truck'), 'error')
    end

    local ped = PlayerPedId()

    if IsPedInVehicle(ped, truck, false) then
        TaskLeaveVehicle(ped, truck, 0)

        local timeout = GetGameTimer() + 3500

        while IsPedInVehicle(ped, truck, false) and GetGameTimer() < timeout do
            Wait(100)
        end
    end

    truckNet = truckNet or T.GetNetId(truck)
    truckPlate = truckPlate or normalizePlate(GetVehicleNumberPlateText(truck))

    local ok, msg = lib.callback.await(
        'rtv-towing:server:returnRepoTruck',
        false,
        truckNet,
        truckPlate or S.returnableRepoTruckPlate,
        S.returnableRepoTruckModel
    )

    if not ok then
        return T.Notify(msg or 'Repo vrachtwagen kon niet verwijderd worden.', 'error')
    end

    Wait(500)

    if DoesEntityExist(truck) then
        T.RequestControl(truck, 1500)
        SetEntityAsMissionEntity(truck, true, true)
        DeleteVehicle(truck)
        DeleteEntity(truck)
    end

    clearReturnableRepoTruck()

    T.Notify(msg or _L('repo_truck_returned'), 'success')
end


local function getExistingRepoTruck()
    if S.returnableRepoTruck and DoesEntityExist(S.returnableRepoTruck) then
        return S.returnableRepoTruck
    end

    if S.returnableRepoTruckPlate or S.returnableRepoTruckModel then
        local foundTruck = findReturnableRepoTruckNearStart()

        if foundTruck and foundTruck ~= 0 and DoesEntityExist(foundTruck) then
            rememberReturnableRepoTruck(foundTruck)
            return foundTruck
        end
    end

    return nil
end

function T.GetRepoDashboardClientState()
    local existingTruck = getExistingRepoTruck()

    return {
        activeRepo = S.activeRepo ~= nil,
        canStartRepo = S.activeRepo == nil,
        canCancelRepo = S.activeRepo ~= nil,
        canReturnTruck = S.activeRepo == nil and existingTruck ~= nil,
        hasReturnableTruck = existingTruck ~= nil,
        returnTruckPlate = existingTruck and normalizePlate(GetVehicleNumberPlateText(existingTruck)) or S.returnableRepoTruckPlate,
        activeStatus = S.activeRepo and {
            id = S.activeRepo.id,
            vehicle = S.activeRepo.vehicleModel,
            plate = S.activeRepo.plate,
            premium = S.activeRepo.premium == true,
            secured = S.activeRepo.secured == true,
            targetSpawned = S.activeRepo.targetSpawned == true,
            dropoffRevealed = S.activeRepo.dropoffRevealed == true,
            status = S.activeRepo.dropoffRevealed and 'Afleveren'
                or (S.activeRepo.secured and 'Afleverpunt actief')
                or (S.activeRepo.targetSpawned and 'Voertuig zoeken/laden')
                or 'Zoeken'
        } or nil
    }
end

local function refreshDashboardAfterAction(delay)
    CreateThread(function()
        Wait(delay or 350)

        if T.RefreshRepoDashboard then
            T.RefreshRepoDashboard()
        elseif T.OpenRepoDashboard then
            T.OpenRepoDashboard()
        end
    end)
end

function T.StartRepoFromDashboard()
    if S.activeRepo then
        T.Notify(_L('repo_active'), 'error', 'Repo')
        refreshDashboardAfterAction(250)
        return false
    end

    local existingTruck = getExistingRepoTruck()
    local existingTruckNet = existingTruck and DoesEntityExist(existingTruck) and T.GetNetId(existingTruck) or nil
    local data, err = lib.callback.await('rtv-towing:server:startRepo', false, existingTruckNet)

    if not data then
        T.Notify(err or _L('repo_not_tow'), 'error', 'Repo')
        refreshDashboardAfterAction(250)
        return false
    end

    startRepoMission(data, existingTruck)
    T.Notify(_L('repo_new_started'), 'success', 'Repo')
    refreshDashboardAfterAction(600)

    return true
end

function T.CancelRepoFromDashboard()
    if not S.activeRepo then
        T.Notify(_L('repo_none'), 'error', 'Repo')
        refreshDashboardAfterAction(250)
        return false
    end

    TriggerServerEvent('rtv-towing:server:cancelRepo', S.activeRepo.id)
    T.ClearRepoEntities(false)
    T.Notify(_L('repo_cancelled'), 'inform', 'Repo')
    refreshDashboardAfterAction(500)

    return true
end

function T.ReturnRepoTruckFromDashboard()
    if S.activeRepo then
        T.Notify('Je kunt de vrachtwagen niet terugbrengen tijdens een actieve repo-opdracht.', 'error', 'Repo')
        refreshDashboardAfterAction(250)
        return false
    end

    returnRepoTruck()
    refreshDashboardAfterAction(700)

    return true
end

RegisterNUICallback('rtvTowingRepoAction', function(data, cb)
    local action = data and data.action
    local ok = false

    if action == 'start' then
        ok = T.StartRepoFromDashboard() == true
    elseif action == 'cancel' then
        ok = T.CancelRepoFromDashboard() == true
    elseif action == 'returnTruck' then
        ok = T.ReturnRepoTruckFromDashboard() == true
    elseif action == 'refresh' then
        refreshDashboardAfterAction(50)
        ok = true
    else
        T.Notify('Onbekende dashboard actie.', 'error', 'Repo')
    end

    cb({ ok = ok })
end)

local function openRepoMenu()
    local existingTruck = getExistingRepoTruck()

    local options = {
        {
            title = 'Repo Dashboard',
            description = 'Bekijk je repo level, XP, statistieken en skill tree.',
            icon = '📊',
            onSelect = function()
                if T.OpenRepoDashboard then
                    T.OpenRepoDashboard()
                else
                    T.Notify('Repo dashboard is nog niet geladen.', 'error')
                end
            end
        },
        {
            title = 'Start Repo opdracht',
            description = existingTruck and 'Start een nieuwe repo-opdracht met je huidige repo vrachtwagen.' or 'Ontvang een repo note en drie mogelijke zoeklocaties.',
            icon = '📋',
            disabled = S.activeRepo ~= nil,
            onSelect = function()
                local existingTruckNet = existingTruck and DoesEntityExist(existingTruck) and T.GetNetId(existingTruck) or nil
                local data, err = lib.callback.await('rtv-towing:server:startRepo', false, existingTruckNet)
                if not data then return T.Notify(err or _L('repo_not_tow'), 'error') end
                startRepoMission(data, existingTruck)
            end
        },
        {
            title = 'Annuleer actieve repo-missie',
            description = 'Annuleer je huidige repo-opdracht.',
            icon = '×',
            variant = 'danger',
            disabled = not S.activeRepo,
            onSelect = function()
                if S.activeRepo then TriggerServerEvent('rtv-towing:server:cancelRepo', S.activeRepo.id) end
                T.ClearRepoEntities(false)
                T.Notify(_L('repo_cancelled'), 'inform')
            end
        },
    }

    if existingTruck and not S.activeRepo then
        options[#options + 1] = {
            title = _L('repo_return_truck'),
            description = _L('repo_return_truck_desc'),
            icon = '🚚',
            variant = 'danger',
            onSelect = function() returnRepoTruck() end
        }
    end

    T.UI.OpenMenu({
        id = 'rtv_towing_repo_menu',
        title = _L('menu_repo'),
        subtitle = 'Repo-opdrachten en actieve missie',
        options = options
    })
end

function T.SpawnRepoPed()
    if S.repoPed and DoesEntityExist(S.repoPed) then return end
    if not Config.Repo or not Config.Repo.enabled then return end
    if not Config.Repo.startPed or not Config.Repo.startPed.coords then return T.Notify('Repo startped config ontbreekt.', 'error') end

    while GetResourceState('ox_target') ~= 'started' do Wait(500) end

    local pedCfg = Config.Repo.startPed
    local model = T.LoadModel(pedCfg.model)
    if not model then return T.Notify(('Repo NPC model niet gevonden: %s'):format(pedCfg.model), 'error') end

    RequestCollisionAtCoord(pedCfg.coords.x, pedCfg.coords.y, pedCfg.coords.z)
    local timeout = GetGameTimer() + 3000
    while GetGameTimer() < timeout do
        RequestCollisionAtCoord(pedCfg.coords.x, pedCfg.coords.y, pedCfg.coords.z)
        Wait(0)
    end

    local ped = CreatePed(0, model, pedCfg.coords.x, pedCfg.coords.y, pedCfg.coords.z - 1.0, pedCfg.coords.w, false, false)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return T.Notify('Repo NPC kon niet gespawned worden.', 'error') end

    S.repoPed = ped
    SetEntityAsMissionEntity(S.repoPed, true, true)
    FreezeEntityPosition(S.repoPed, true)
    SetEntityInvincible(S.repoPed, true)
    SetBlockingOfNonTemporaryEvents(S.repoPed, true)
    if pedCfg.scenario then TaskStartScenarioInPlace(S.repoPed, pedCfg.scenario, 0, true) end

    exports.ox_target:addLocalEntity(S.repoPed, {
        {
            name = 'rtv_towing_repo_ped',
            icon = 'fa-solid fa-truck-ramp-box',
            label = 'Repo Job',
            canInteract = function() return T.CanUseClient('repo') end,
            onSelect = function()
                if T.OpenRepoDashboard then
                    T.OpenRepoDashboard()
                else
                    openRepoMenu()
                end
            end
        }
    })

    if pedCfg.blip and pedCfg.blip.enabled and not S.repoBlip then
        S.repoBlip = T.CreateBlip(pedCfg.coords, pedCfg.blip.sprite, pedCfg.blip.color, pedCfg.blip.scale, pedCfg.blip.label)
        SetBlipAsShortRange(S.repoBlip, true)
    end
end



function T.StartRepoMonitor()
    CreateThread(function()
        local lastServerCheck = 0

        while true do
            if S.activeRepo then
                if S.activeRepo.companyTruckNet and (not S.activeRepo.truck or not DoesEntityExist(S.activeRepo.truck)) then
                    local truck = waitForVehicleFromNet(S.activeRepo.companyTruckNet, 100)

                    if truck ~= 0 then
                        S.activeRepo.truck = truck
                    end
                end

                if not S.activeRepo.targetSpawned then
                    spawnRepoTargetVehicle()
                end

                if S.activeRepo.targetVehicle and DoesEntityExist(S.activeRepo.targetVehicle) then
                    local targetNet = T.GetNetId(S.activeRepo.targetVehicle)

                    if targetNet and not S.activeRepo.secured then
                        local now = GetGameTimer()

                        if S.bedAttachments[targetNet] and now - lastServerCheck > 1500 then
                            TriggerServerEvent('rtv-towing:server:checkRepoSecured', true)
                            lastServerCheck = now
                        end

                        if now - lastServerCheck > 10000 then
                            TriggerServerEvent('rtv-towing:server:checkRepoSecured', true)
                            lastServerCheck = now
                        end
                    end
                end

                if S.activeRepo.secured and S.activeRepo.dropoffRevealed then
                    if not S.activeRepo.dropoffPed or not DoesEntityExist(S.activeRepo.dropoffPed) then
                        local spawned = spawnDropoffPed()

                        if Config.Debug and not spawned then
                            print('[rtv-towing] Dropoff ped nog niet gespawned. Mogelijk nog te ver weg of coords/model issue.')
                        end
                    end
                end
            end

            Wait(1000)
        end
    end)
end

RegisterCommand('repocheck', function()
    TriggerServerEvent('rtv-towing:server:checkRepoSecured', false)
end, false)