local T = RTVTowing
local S = T.State

S.activeRepos = S.activeRepos or {}
S.repoCooldowns = S.repoCooldowns or {}
S.repoCounter = S.repoCounter or 0

local function normalizePlate(plate)
    return tostring(plate or ''):upper():gsub('%s+', '')
end

local function getSafeVehiclePlate(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return ''
    end

    local ok, plate = pcall(function()
        return GetVehicleNumberPlateText(vehicle)
    end)

    if not ok or not plate then
        return ''
    end

    return normalizePlate(plate)
end

local function getSafeAllVehicles()
    local ok, vehicles = pcall(function()
        return GetAllVehicles()
    end)

    if not ok or not vehicles then
        return {}
    end

    return vehicles
end

local function generateUniqueRepoPlate()
    local usedPlates = {}

    for _, job in pairs(S.activeRepos or {}) do
        if job and job.plate then
            usedPlates[normalizePlate(job.plate)] = true
        end
    end

    for _, vehicle in ipairs(getSafeAllVehicles()) do
        local plate = getSafeVehiclePlate(vehicle)

        if plate ~= '' then
            usedPlates[plate] = true
        end
    end

    local plateConfig = Config.Repo.plate or {}
    local prefix = tostring(plateConfig.prefix or 'RTV'):upper():gsub('%s+', '')
    local digits = tonumber(plateConfig.digits or 5) or 5

    if #prefix + digits > 8 then
        digits = 8 - #prefix
    end

    if digits < 1 then
        prefix = prefix:sub(1, 7)
        digits = 1
    end

    local maxNumber = (10 ^ digits) - 1
    local format = '%0' .. digits .. 'd'

    for _ = 1, 250 do
        local plate = prefix .. string.format(format, math.random(0, maxNumber))
        local normalizedPlate = normalizePlate(plate)

        if not usedPlates[normalizedPlate] then
            return plate
        end
    end

    local fallback = prefix .. tostring(math.random(100000, 999999))
    return fallback:sub(1, 8)
end

local function getVehicleNetId(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local ok, netId = pcall(function()
        return NetworkGetNetworkIdFromEntity(vehicle)
    end)

    if ok and netId and netId ~= 0 then
        return netId
    end

    return nil
end

local function randomFrom(list)
    if not list or #list == 0 then
        return nil
    end

    return list[math.random(#list)]
end

local function sameLocation(a, b)
    return a
        and b
        and math.abs(a.x - b.x) < 0.01
        and math.abs(a.y - b.y) < 0.01
        and math.abs(a.z - b.z) < 0.01
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end

    return list
end

local function pickSearchLocations(realPickup)
    local amount = Config.Repo.searchLocationsAmount or 3
    local results = { realPickup }
    local attempts = 0

    while #results < amount and attempts < 100 do
        attempts = attempts + 1

        local candidate = randomFrom(Config.Repo.pickupSpawns)
        local exists = false

        for _, loc in ipairs(results) do
            if sameLocation(loc, candidate) then
                exists = true
                break
            end
        end

        if candidate and not exists then
            results[#results + 1] = candidate
        end
    end

    return shuffle(results)
end

local function formatRepoNoteDescription(vehicleModel, plate, locationsAmount)
    return ('Repo Opdracht\nVoertuig: %s\nKenteken: %s\nMogelijke locaties: %s\nControleer je GPS.'):format(
        vehicleModel,
        plate,
        locationsAmount or 3
    )
end

local function addRepoNote(src, job)
    local item = Config.Repo.noteItem or 'rtv_repo_note'

    if not item then
        return true
    end

    local metadata = {
        repoId = job.id,
        opdracht = job.id,
        vehicle = job.vehicleModel,
        kenteken = job.plate,
        plate = job.plate,
        locaties = tostring(#job.searchLocations),
        description = formatRepoNoteDescription(job.vehicleModel, job.plate, #job.searchLocations)
    }

    job.noteMetadata = metadata

    if not exports.ox_inventory:CanCarryItem(src, item, 1, metadata) then
        return false, _L('repo_note_missing_space')
    end

    exports.ox_inventory:AddItem(src, item, 1, metadata)

    return true
end

local function removeRepoNote(src, job)
    if not job or not job.noteMetadata then
        return
    end

    local item = Config.Repo.noteItem or 'rtv_repo_note'

    if not item then
        return
    end

    pcall(function()
        exports.ox_inventory:RemoveItem(src, item, 1, job.noteMetadata)
    end)
end

local function getRepoMultiplier(rep)
    local multiplier = 1.0

    for _, row in ipairs(Config.Repo.reward.progression or {}) do
        if rep >= row.rep then
            multiplier = row.multiplier
        end
    end

    return multiplier
end

local function getRep(src)
    local key = Config.Repo.reward.rep.metadata
    local value = exports.qbx_core:GetMetadata(src, key)

    return tonumber(value) or 0
end

local function setRep(src, value)
    exports.qbx_core:SetMetadata(src, Config.Repo.reward.rep.metadata, value)
end

local function addMoney(src, account, amount)
    local player = T.GetPlayer(src)

    if not player then
        return false
    end

    if player.Functions and player.Functions.AddMoney then
        player.Functions.AddMoney(account, amount, 'rtv-towing-repo')
        return true
    end

    return false
end

local function addItem(src, item, amount, metadata)
    if amount <= 0 then
        return false
    end

    if exports.ox_inventory:CanCarryItem(src, item, amount, metadata) then
        return exports.ox_inventory:AddItem(src, item, amount, metadata)
    end

    T.Notify(src, _L('inventory_full'), 'error')

    return false
end

local function payoutRepo(src, job)
    local currentRep = getRep(src)
    local multiplier = getRepoMultiplier(currentRep)
    local effects = T.GetRepoSkillEffects and T.GetRepoSkillEffects(src) or {}
    local progressCfg = Config.RepoProgression or {}

    local moneyMultiplier = multiplier

    if job and job.premium then
        moneyMultiplier = moneyMultiplier * (effects.premiumMoneyMultiplier or progressCfg.premiumMoneyMultiplier or 1.15)
    end

    local baseMoney = math.random(Config.Repo.reward.money.min, Config.Repo.reward.money.max)
    local finalMoney = math.floor(baseMoney * moneyMultiplier + 0.5)

    addMoney(src, Config.Repo.reward.money.account, finalMoney)

    local repGain = math.random(Config.Repo.reward.rep.min, Config.Repo.reward.rep.max)

    setRep(src, currentRep + repGain)

    local materialText = {}
    local payoutData = {
        money = finalMoney,
        rep = repGain,
        materials = 0,
        items = {}
    }

    local materialItems = progressCfg.materialItems or { carparts = true, craftparts = true }

    for _, reward in ipairs(Config.Repo.reward.materials or {}) do
        if math.random(100) <= reward.chance then
            local amount = math.random(reward.min, reward.max)

            if not reward.ignoreMultiplier then
                amount = math.floor(
                    amount
                    * multiplier
                    * (Config.Repo.reward.materialMultiplier or 1.0)
                    + 0.5
                )
            end

            if materialItems[reward.item] then
                amount = math.floor(amount * (effects.materialMultiplier or 1.0) + 0.5)

                if job and job.premium then
                    amount = amount + (effects.premiumMaterialBonus or progressCfg.premiumMaterialBonus or 10)
                end
            end

            if addItem(src, reward.item, amount) then
                materialText[#materialText + 1] = ('%sx %s'):format(amount, reward.item)
                payoutData.items[#payoutData.items + 1] = { item = reward.item, amount = amount }

                if materialItems[reward.item] then
                    payoutData.materials = payoutData.materials + amount
                end
            end
        end
    end

    if Config.Repo.reward.rare and math.random(100) <= Config.Repo.reward.rare.chance then
        addItem(src, Config.Repo.reward.rare.item, 1)
    end

    local msg = ('+€%s, +%s rep'):format(finalMoney, repGain)

    if #materialText > 0 then
        msg = msg .. ' | ' .. table.concat(materialText, ', ')
    end

    return msg, payoutData
end

local function findRepoVehicleByPlateNearDropoff(job)
    if not job or not job.plate or not job.dropoff or not job.dropoff.truck then
        return 0, nil
    end

    local targetPlate = normalizePlate(job.plate)

    if targetPlate == '' then
        return 0, nil
    end

    local drop = vector3(
        job.dropoff.truck.x,
        job.dropoff.truck.y,
        job.dropoff.truck.z
    )

    local radius = Config.Repo.deliveryVehicleRadius or 18.0
    local closestVehicle = 0
    local closestNet = nil
    local closestDistance = radius + 0.01

    for _, vehicle in ipairs(getSafeAllVehicles()) do
        if DoesEntityExist(vehicle) then
            local plate = getSafeVehiclePlate(vehicle)

            if plate == targetPlate then
                local distance = #(GetEntityCoords(vehicle) - drop)

                if distance <= closestDistance then
                    closestVehicle = vehicle
                    closestNet = getVehicleNetId(vehicle)
                    closestDistance = distance
                end
            end
        end
    end

    return closestVehicle, closestNet
end

local function findReturnTruckNearStart(truckNet, truckPlate, truckModel)
    local expectedPlate = normalizePlate(truckPlate)

    if expectedPlate == '' then
        return 0
    end

    local startCoords = Config.Repo.startPed.coords
    local startVec = vector3(startCoords.x, startCoords.y, startCoords.z)
    local radius = Config.Repo.returnTruckDistance or 18.0

    truckNet = tonumber(truckNet)
    truckModel = tonumber(truckModel)

    if truckNet then
        local vehicle = T.GetVehicleFromNetId(truckNet)

        if vehicle ~= 0 and DoesEntityExist(vehicle) then
            local plate = getSafeVehiclePlate(vehicle)
            local distance = #(GetEntityCoords(vehicle) - startVec)

            if plate == expectedPlate and distance <= radius then
                return vehicle
            end
        end
    end

    local closestVehicle = 0
    local closestDistance = radius + 0.01

    for _, vehicle in ipairs(getSafeAllVehicles()) do
        if DoesEntityExist(vehicle) then
            local plate = getSafeVehiclePlate(vehicle)
            local modelOk = not truckModel or truckModel == 0 or GetEntityModel(vehicle) == truckModel

            if plate == expectedPlate and modelOk then
                local distance = #(GetEntityCoords(vehicle) - startVec)

                if distance <= closestDistance then
                    closestVehicle = vehicle
                    closestDistance = distance
                end
            end
        end
    end

    return closestVehicle
end


local function deleteVehicleEntity(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return true
    end

    pcall(function()
        SetEntityAsMissionEntity(vehicle, true, true)
    end)

    for _ = 1, 8 do
        DeleteEntity(vehicle)
        Wait(100)

        if not DoesEntityExist(vehicle) then
            return true
        end
    end

    return not DoesEntityExist(vehicle)
end

local function deleteVehicleByNet(netId)
    netId = tonumber(netId)

    if not netId then
        return true
    end

    local vehicle = T.GetVehicleFromNetId(netId)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return true
    end

    return deleteVehicleEntity(vehicle)
end

local function isAnyVehicleNearCoords(coords, radius)
    local origin = vector3(coords.x, coords.y, coords.z)

    for _, vehicle in ipairs(getSafeAllVehicles()) do
        if DoesEntityExist(vehicle) then
            local distance = #(GetEntityCoords(vehicle) - origin)

            if distance <= radius then
                return true
            end
        end
    end

    return false
end

local function generateUniqueCompanyPlate()
    local usedPlates = {}

    for _, job in pairs(S.activeRepos or {}) do
        if job and job.companyTruckPlate then
            usedPlates[normalizePlate(job.companyTruckPlate)] = true
        end
    end

    for _, vehicle in ipairs(getSafeAllVehicles()) do
        local plate = getSafeVehiclePlate(vehicle)

        if plate ~= '' then
            usedPlates[plate] = true
        end
    end

    for _ = 1, 250 do
        local plate = ('SAN%03d'):format(math.random(0, 999))
        local normalizedPlate = normalizePlate(plate)

        if not usedPlates[normalizedPlate] then
            return plate
        end
    end

    return ('TOW%s'):format(math.random(10000, 99999)):sub(1, 8)
end


local repoVehicleColors = {
    { index = 0, label = 'Zwart' },
    { index = 1, label = 'Grafiet' },
    { index = 4, label = 'Zilvergrijs' },
    { index = 27, label = 'Rood' },
    { index = 38, label = 'Oranje' },
    { index = 49, label = 'Groen' },
    { index = 64, label = 'Blauw' },
    { index = 88, label = 'Geel' },
    { index = 106, label = 'Wit' },
    { index = 111, label = 'IJs wit' },
    { index = 145, label = 'Brons' },
}

local function pickRepoVehicleColor()
    return repoVehicleColors[math.random(#repoVehicleColors)] or repoVehicleColors[1]
end

local function createServerVehicle(modelName, coords, plate, locked, colorIndex)
    if not modelName or not coords then
        return 0, nil
    end

    local modelHash = modelName

    if type(modelName) ~= 'number' then
        local okHash, hashed = pcall(function()
            return joaat(modelName)
        end)

        if okHash and hashed then
            modelHash = hashed
        else
            modelHash = GetHashKey(modelName)
        end
    end
    local spawnZ = (coords.z or 0.0) + 0.35
    local heading = coords.w or 0.0

    local vehicle = 0

    local okSetter, setterVehicle = pcall(function()
        if CreateVehicleServerSetter then
            return CreateVehicleServerSetter(modelHash, 'automobile', coords.x, coords.y, spawnZ, heading)
        end

        return 0
    end)

    if okSetter and setterVehicle and setterVehicle ~= 0 then
        vehicle = setterVehicle
    else
        local okCreate, createdVehicle = pcall(function()
            return CreateVehicle(modelHash, coords.x, coords.y, spawnZ, heading, true, true)
        end)

        if okCreate and createdVehicle and createdVehicle ~= 0 then
            vehicle = createdVehicle
        end
    end

    if not vehicle or vehicle == 0 then
        return 0, nil
    end

    for _ = 1, 50 do
        if DoesEntityExist(vehicle) then
            break
        end

        Wait(100)
    end

    if not DoesEntityExist(vehicle) then
        return 0, nil
    end

    pcall(function()
        SetEntityAsMissionEntity(vehicle, true, true)
    end)

    if plate then
        pcall(function()
            SetVehicleNumberPlateText(vehicle, plate)
        end)
    end

    if colorIndex then
        pcall(function()
            SetVehicleColours(vehicle, colorIndex, colorIndex)
        end)
    end

    pcall(function()
        SetVehicleOnGroundProperly(vehicle)
    end)

    if locked ~= nil then
        pcall(function()
            SetVehicleDoorsLocked(vehicle, locked and 2 or 1)
        end)
    end

    local netId = getVehicleNetId(vehicle)

    if not netId then
        deleteVehicleEntity(vehicle)
        return 0, nil
    end

    return vehicle, netId
end

local function pickCompanyTruckSpawn()
    for _, coords in ipairs(Config.Repo.truckSpawns or {}) do
        if not isAnyVehicleNearCoords(coords, 4.0) then
            return coords
        end
    end

    return (Config.Repo.truckSpawns or {})[1]
end

local function spawnCompanyTruckForJob(src, job, existingTruckNet)
    existingTruckNet = tonumber(existingTruckNet)

    if existingTruckNet then
        local existingTruck = T.GetVehicleFromNetId(existingTruckNet)

        if existingTruck ~= 0 and DoesEntityExist(existingTruck) then
            job.companyTruckNet = existingTruckNet
            job.companyTruckPlate = getSafeVehiclePlate(existingTruck)
            job.companyTruckModel = GetEntityModel(existingTruck)

            if Config.VehicleKeys and Config.VehicleKeys.enabled and Config.VehicleKeys.giveCompanyTruckKeys then
                T.GiveVehicleKeys(src, existingTruckNet, Config.VehicleKeys.skipNotification)
            end

            return existingTruckNet, job.companyTruckPlate
        end
    end

    if not Config.Repo.useCompanyTruck then
        return nil, nil
    end

    local spawn = pickCompanyTruckSpawn()

    if not spawn then
        return nil, 'Geen truck spawnlocatie gevonden in Config.Repo.truckSpawns.'
    end

    local plate = generateUniqueCompanyPlate()
    local vehicle, netId = createServerVehicle(Config.Repo.companyTruckModel, spawn, plate, false)

    if vehicle == 0 or not netId then
        return nil, 'Company towtruck kon server-side niet gespawned worden.'
    end

    job.companyTruckNet = netId
    job.companyTruckPlate = plate
    job.companyTruckModel = GetEntityModel(vehicle)

    if Config.VehicleKeys and Config.VehicleKeys.enabled and Config.VehicleKeys.giveCompanyTruckKeys then
        T.GiveVehicleKeys(src, netId, Config.VehicleKeys.skipNotification)
    end

    return netId, plate
end

local function isPlayerNearCoords(src, coords, radius)
    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local target = vector3(coords.x, coords.y, coords.z)

    return #(playerCoords - target) <= radius
end


RegisterNetEvent('rtv-towing:server:giveRepoKeys', function(repoId, vehicleNet, keyType)
    local src = source
    local job = S.activeRepos[src]

    if not job or job.id ~= repoId then
        return
    end

    if keyType == 'company' then
        if not Config.VehicleKeys.giveCompanyTruckKeys then
            return
        end

        job.companyTruckNet = vehicleNet

        T.GiveVehicleKeys(src, vehicleNet, Config.VehicleKeys.skipNotification)
        return
    end

    if keyType == 'repo' then
        if not Config.VehicleKeys.giveRepoVehicleKeys then
            return
        end

        if tonumber(job.targetNet) ~= tonumber(vehicleNet) then
            return
        end

        T.GiveVehicleKeys(src, vehicleNet, Config.VehicleKeys.skipNotification)
    end
end)

local function createRepoForPlayer(src, existingTruckNet)
    S.repoCounter = (S.repoCounter or 0) + 1

    local pickup = randomFrom(Config.Repo.pickupSpawns)
    local searchLocations = pickSearchLocations(pickup)
    local dropoff = randomFrom(Config.Repo.dropoffs)
    local vehicleModel = randomFrom(Config.Repo.repoVehicles)
    local id = ('repo:%s:%s'):format(src, S.repoCounter)
    local plate = generateUniqueRepoPlate()

    if not pickup or not dropoff or not vehicleModel then
        return nil, 'Repo configuratie mist pickup/dropoff/voertuigen.'
    end

    local contractMeta = T.BuildRepoContractMeta and T.BuildRepoContractMeta(src) or {}
    local vehicleColor = pickRepoVehicleColor()

    local job = {
        id = id,
        pickup = pickup,
        searchLocations = searchLocations,
        dropoff = dropoff,
        vehicleModel = vehicleModel,
        truckModel = Config.Repo.companyTruckModel,
        plate = plate,
        vehicleColor = vehicleColor and vehicleColor.label or nil,
        vehicleColorIndex = vehicleColor and vehicleColor.index or nil,
        startedAt = os.time(),
        targetNet = nil,
        targetSpawned = false,
        companyTruckNet = nil,
        companyTruckPlate = nil,
        secured = false,
        premium = contractMeta.premium == true,
        riskLevel = contractMeta.riskLevel or 'Onbekend',
        riskVisible = contractMeta.riskVisible == true,
        noteExtra = contractMeta.noteExtra == true,
        angryChanceModifier = contractMeta.angryChanceModifier or 1.0,
    }

    S.activeRepos[src] = job

    local companyTruckNet, companyTruckErr = spawnCompanyTruckForJob(src, job, existingTruckNet)

    if Config.Repo.useCompanyTruck and not companyTruckNet then
        S.activeRepos[src] = nil
        return nil, companyTruckErr or 'Company towtruck kon niet server-side gespawned worden.'
    end

    local noteOk, noteErr = addRepoNote(src, job)

    if not noteOk then
        deleteVehicleByNet(job.companyTruckNet)
        S.activeRepos[src] = nil
        return nil, noteErr or _L('repo_note_missing_space')
    end

    return {
        id = id,
        pickup = pickup,
        searchLocations = searchLocations,
        dropoff = dropoff,
        vehicleModel = vehicleModel,
        truckModel = Config.Repo.companyTruckModel,
        plate = plate,
        vehicleColor = job.vehicleColor,
        companyTruckNet = job.companyTruckNet,
        companyTruckPlate = job.companyTruckPlate,
        targetNet = nil,
        premium = job.premium == true,
        riskLevel = job.riskLevel,
        riskVisible = job.riskVisible == true,
        noteExtra = job.noteExtra == true,
        angryChanceModifier = job.angryChanceModifier or 1.0,
    }
end

lib.callback.register('rtv-towing:server:startRepo', function(src, existingTruckNet)
    if not T.CanUse(src, 'repo') then
        return nil, _L('repo_not_tow')
    end

    if S.activeRepos[src] then
        return nil, _L('repo_active')
    end

    local now = os.time()

    if S.repoCooldowns[src] and now < S.repoCooldowns[src] then
        return nil, _L('repo_cooldown')
    end

    return createRepoForPlayer(src, existingTruckNet)
end)

lib.callback.register('rtv-towing:server:spawnRepoVehicle', function(src, repoId)
    local job = S.activeRepos[src]

    if not job or job.id ~= repoId then
        return false, nil, _L('repo_none')
    end

    if job.targetNet then
        local existingVehicle = T.GetVehicleFromNetId(job.targetNet)

        if existingVehicle ~= 0 and DoesEntityExist(existingVehicle) then
            return true, job.targetNet, nil, job.vehicleColor
        end

        job.targetNet = nil
        job.targetSpawned = false
    end

    local spawnDistance = (Config.Repo.vehicleSpawnDistance or 180.0) + 35.0

    if not isPlayerNearCoords(src, job.pickup, spawnDistance) then
        return false, nil, 'Je staat te ver weg van de repo pickup locatie om het voertuig te spawnen.'
    end

    local vehicle, netId = createServerVehicle(job.vehicleModel, job.pickup, job.plate, Config.Repo.lockRepoVehicle, job.vehicleColorIndex)

    if vehicle == 0 or not netId then
        return false, nil, 'Repo voertuig kon server-side niet gespawned worden.'
    end

    job.targetNet = netId
    job.targetSpawned = true

    if Config.VehicleKeys and Config.VehicleKeys.enabled and Config.VehicleKeys.giveRepoVehicleKeys then
        T.GiveVehicleKeys(src, netId, Config.VehicleKeys.skipNotification)
    end

    return true, netId, nil, job.vehicleColor
end)

RegisterNetEvent('rtv-towing:server:setRepoVehicle', function(repoId, vehicleNet)
    local src = source
    local job = S.activeRepos[src]

    if not job or job.id ~= repoId then
        return
    end

    job.targetNet = tonumber(vehicleNet) or vehicleNet
end)

function T.TryMarkRepoVehicleSecured(vehicleNet, onlySource)
    if not vehicleNet then
        return false
    end

    vehicleNet = tonumber(vehicleNet)

    if not vehicleNet then
        return false
    end

    if not S.bedState or not S.bedState[vehicleNet] then
        return false
    end

    for src, job in pairs(S.activeRepos or {}) do
        if not onlySource or tonumber(src) == tonumber(onlySource) then
            if job and tonumber(job.targetNet) == vehicleNet then
                if job.secured then
                    return true
                end

                job.secured = true

                TriggerClientEvent(
                    'rtv-towing:client:repoVehicleSecured',
                    src,
                    vehicleNet,
                    job.id
                )

                return true
            end
        end
    end

    return false
end

RegisterNetEvent('rtv-towing:server:checkRepoSecured', function(silent)
    local src = source
    local job = S.activeRepos[src]

    silent = silent == true

    if not job then
        if not silent then
            T.Notify(src, _L('repo_none'), 'error')
        end

        return
    end

    if not job.targetNet then
        if not silent then
            T.Notify(src, 'Repo voertuig is nog niet geregistreerd.', 'error')
        end

        return
    end

    local secured = T.TryMarkRepoVehicleSecured(job.targetNet, src)

    if not secured and not silent then
        T.Notify(src, 'Het juiste repo voertuig staat nog niet vast op het laadbed.', 'error')
    end
end)

lib.callback.register('rtv-towing:server:finishRepo', function(src, repoId, vehicleNet, clientPlate)
    local job = S.activeRepos[src]

    if not job or job.id ~= repoId then
        return false, _L('repo_none')
    end

    vehicleNet = tonumber(vehicleNet)

    local expectedPlate = normalizePlate(job.plate)
    local sentPlate = normalizePlate(clientPlate)

    if sentPlate ~= '' and expectedPlate ~= '' and sentPlate ~= expectedPlate then
        return false, 'Dit is niet het juiste repo-voertuig.'
    end

    local vehicle = 0
    local finalNet = vehicleNet

    if vehicleNet then
        vehicle = T.GetVehicleFromNetId(vehicleNet)
    end

    if vehicle == 0 and job.targetNet then
        finalNet = tonumber(job.targetNet)
        vehicle = T.GetVehicleFromNetId(finalNet)
    end

    if vehicle == 0 then
        vehicle, finalNet = findRepoVehicleByPlateNearDropoff(job)
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, _L('repo_need_vehicle')
    end

    local actualPlate = getSafeVehiclePlate(vehicle)

    if expectedPlate ~= '' and actualPlate ~= expectedPlate then
        return false, 'Dit is niet het juiste repo-voertuig.'
    end

    if finalNet then
        job.targetNet = finalNet
    end

    if finalNet and S.bedState[finalNet] then
        return false, _L('repo_unload_first')
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    local drop = vector3(
        job.dropoff.truck.x,
        job.dropoff.truck.y,
        job.dropoff.truck.z
    )

    local deliveryRadius = Config.Repo.deliveryVehicleRadius or 18.0

    if #(vehicleCoords - drop) > deliveryRadius then
        return false, _L('repo_vehicle_not_at_dropoff')
    end

    local msg, payoutData = payoutRepo(src, job)

    if T.AddRepoCompletionProgress then
        local xpText = T.AddRepoCompletionProgress(src, job, payoutData or {})

        if xpText and xpText ~= '' then
            msg = msg .. ' | ' .. xpText
        end
    end

    removeRepoNote(src, job)

    -- Repo doelvoertuig wordt server-side verwijderd na succesvolle aflevering.
    deleteVehicleEntity(vehicle)

    S.activeRepos[src] = nil
    S.repoCooldowns[src] = nil

    return true, (_L('repo_finished') .. ' ' .. msg)
end)

lib.callback.register('rtv-towing:server:returnRepoTruck', function(src, truckNet, truckPlate, truckModel)
    if S.activeRepos[src] then
        return false, 'Je kunt de vrachtwagen niet terugbrengen tijdens een actieve repo-opdracht.'
    end

    if not T.CanUse(src, 'repo') then
        return false, _L('repo_not_tow')
    end

    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then
        return false, 'Speler niet gevonden.'
    end

    local startCoords = Config.Repo.startPed.coords
    local startVec = vector3(startCoords.x, startCoords.y, startCoords.z)
    local playerCoords = GetEntityCoords(ped)
    local returnDistance = Config.Repo.returnTruckDistance or 18.0

    if #(playerCoords - startVec) > returnDistance then
        return false, ('Je staat te ver van de startlocatie. Max afstand: %sm'):format(returnDistance)
    end

    local vehicle = findReturnTruckNearStart(truckNet, truckPlate, truckModel)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false, _L('repo_no_return_truck')
    end

    local deleted = deleteVehicleEntity(vehicle)

    if not deleted then
        return false, 'Repo vrachtwagen kon niet verwijderd worden. Probeer opnieuw of stap eerst uit.'
    end

    return true, _L('repo_truck_returned')
end)

RegisterNetEvent('rtv-towing:server:cancelRepo', function(repoId)
    local src = source

    if S.activeRepos[src] and S.activeRepos[src].id == repoId then
        local job = S.activeRepos[src]

        removeRepoNote(src, job)

        if T.AddRepoCancelled then
            T.AddRepoCancelled(src)
        end

        deleteVehicleByNet(job.targetNet)
        deleteVehicleByNet(job.companyTruckNet)

        S.activeRepos[src] = nil
        S.repoCooldowns[src] = os.time() + math.floor(Config.Repo.cooldownSeconds / 2)
    end
end)
