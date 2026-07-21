local T = RTVTowing

local allowedCraftItems = {
    plastic = true,
    rubber = true,
    metalscrap = true,
    fabric = true,
    leather = true,
    copper = true,
    iron = true,
    steel = true,

    rtv_towrope = true,
    rtv_winch = true,

    repair_kit = true,
    boat_paintkit = true,
    air_paintkit = true,
    boat_repair_kit = true,
    air_repair_kit = true,

    WEAPON_DAGGER = true,
    WEAPON_BATTLEAXE = true,
}

local function notify(src, message, nType)
    if T and T.Notify then
        T.Notify(src, message, nType or 'error')
    end
end

local function getSleepdienstCraftLocation()
    for _, location in ipairs((Config.Crafting and Config.Crafting.locations) or {}) do
        if location.id == 'towyard_crafting' then
            return location
        end
    end

    return {
        id = 'towyard_crafting',
        coords = vec3(1176.35, 2634.95, 38.45),
        job = 'sandytow',
        minGrade = 4,
        requireDuty = true,
    }
end

local function getJobGrade(job)
    if not job then
        return 0
    end

    if type(job.grade) == 'table' then
        return tonumber(job.grade.level or job.grade.grade or job.grade.value or 0) or 0
    end

    return tonumber(job.grade or 0) or 0
end

local function isNearLocation(src, location, extraDistance)
    if not location or not location.coords then
        return false
    end

    local ped = GetPlayerPed(src)

    if not ped or ped == 0 then
        return false
    end

    local playerCoords = GetEntityCoords(ped)
    local locationCoords = vector3(location.coords.x, location.coords.y, location.coords.z)
    local maxDistance = (Config.Crafting and Config.Crafting.serverDistance or 5.0) + (extraDistance or 0.0)

    return #(playerCoords - locationCoords) <= maxDistance
end

local function isSleepdienstBench(payload)
    local benchId = tostring(payload.benchId or '')

    if benchId == 'sleepdienst_crafting' or benchId == 'towyard_crafting' then
        return true
    end

    -- Fallback voor ox_inventory builds die een numerieke benchIndex doorgeven:
    -- alleen afdwingen als speler daadwerkelijk bij de sleepdienst werkbank staat.
    return isNearLocation(payload.source, getSleepdienstCraftLocation(), 2.0)
end

local function canUseSleepdienstCrafting(src)
    local location = getSleepdienstCraftLocation()

    if not isNearLocation(src, location, 0.0) then
        return false, 'Je staat te ver weg van de sleepdienst werkbank.'
    end

    local player = T and T.GetPlayer and T.GetPlayer(src) or exports.qbx_core:GetPlayer(src)

    if not player or not player.PlayerData or not player.PlayerData.job then
        return false, 'Geen geldige job gevonden.'
    end

    local job = player.PlayerData.job
    local requiredJob = location.job or 'sandytow'

    if job.name ~= requiredJob then
        return false, 'Je hebt geen toegang tot deze werkbank.'
    end

    local minGrade = tonumber(location.minGrade or 0) or 0
    local grade = getJobGrade(job)

    if grade < minGrade then
        return false, ('Je rang is te laag voor deze werkbank. Minimaal rang %s.'):format(minGrade)
    end

    if location.requireDuty and job.onduty == false then
        return false, 'Je moet in dienst zijn om deze werkbank te gebruiken.'
    end

    return true
end

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(500)
    end

    exports.ox_inventory:registerHook('craftItem', function(payload)
        if not payload or not payload.source or not payload.recipe then
            return
        end

        local itemName = payload.recipe.name

        if not allowedCraftItems[itemName] then
            return
        end

        if not isSleepdienstBench(payload) then
            return
        end

        local allowed, reason = canUseSleepdienstCrafting(payload.source)

        if not allowed then
            notify(payload.source, reason or 'Je mag deze werkbank niet gebruiken.', 'error')
            return false
        end
    end, {
        itemFilter = allowedCraftItems
    })

    if Config.Debug then
        print('[rtv-towing] ox_inventory craftItem duty hook geregistreerd voor sleepdienst crafting.')
    end
end)