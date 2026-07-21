local T = RTVTowing

local function getLocationById(locationId)
    for _, location in ipairs(Config.Crafting.locations or {}) do
        if location.id == locationId then return location end
    end
    return nil
end

local function getRecipeById(recipeId)
    if not Config.Crafting or not Config.Crafting.recipes then return nil end
    return Config.Crafting.recipes[recipeId]
end

local function getPlayerJobData(src)
    local player = T.GetPlayer(src)
    if not player or not player.PlayerData or not player.PlayerData.job then return nil end
    return player.PlayerData.job
end

local function getJobGrade(job)
    if not job then return 0 end
    if type(job.grade) == 'table' then
        return tonumber(job.grade.level or job.grade.grade or job.grade.value or 0) or 0
    end
    return tonumber(job.grade or 0) or 0
end

local function isPlayerNearLocation(src, location)
    if not location or not location.coords then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local playerCoords = GetEntityCoords(ped)
    local locCoords = vector3(location.coords.x, location.coords.y, location.coords.z)
    local maxDistance = Config.Crafting.serverDistance or 5.0
    return #(playerCoords - locCoords) <= maxDistance
end

local function locationHasRecipe(location, recipeId)
    for _, id in ipairs(location.recipes or {}) do
        if id == recipeId then return true end
    end
    return false
end

local function canUseCraftingLocation(src, locationId)
    if not Config.Crafting or not Config.Crafting.enabled then return false, _L('crafting_no_access') end
    local location = getLocationById(locationId)
    if not location then return false, _L('crafting_no_access') end
    if not isPlayerNearLocation(src, location) then return false, _L('crafting_too_far') end

    local job = getPlayerJobData(src)
    if location.job and (not job or job.name ~= location.job) then return false, _L('crafting_no_access') end
    if location.requireDuty and job and job.onduty == false then return false, _L('crafting_not_on_duty') end

    local grade = getJobGrade(job)
    local minGrade = tonumber(location.minGrade or 0) or 0
    if grade < minGrade then return false, _L('crafting_grade_low') end

    return true
end

local function hasIngredients(src, recipe)
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        local item = ingredient.item
        local count = ingredient.count or 1
        local hasCount = exports.ox_inventory:Search(src, 'count', item)
        if (hasCount or 0) < count then return false end
    end
    return true
end

local function removeIngredients(src, recipe)
    local removed = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        local item = ingredient.item
        local count = ingredient.count or 1
        local success = exports.ox_inventory:RemoveItem(src, item, count)
        if not success then
            for _, old in ipairs(removed) do exports.ox_inventory:AddItem(src, old.item, old.count) end
            return false
        end
        removed[#removed + 1] = { item = item, count = count }
    end
    return true
end

lib.callback.register('rtv-towing:server:canUseCraftingLocation', function(src, locationId)
    return canUseCraftingLocation(src, locationId)
end)

lib.callback.register('rtv-towing:server:canCraft', function(src, locationId, recipeId)
    local canUse, reason = canUseCraftingLocation(src, locationId)
    if not canUse then return false, reason end

    local location = getLocationById(locationId)
    if not location or not locationHasRecipe(location, recipeId) then return false, _L('crafting_no_access') end

    local recipe = getRecipeById(recipeId)
    if not recipe then return false, _L('crafting_failed') end
    if not hasIngredients(src, recipe) then return false, _L('crafting_missing_items') end

    local output = recipe.output or {}
    if not output.item then return false, _L('crafting_failed') end
    if not exports.ox_inventory:CanCarryItem(src, output.item, output.count or 1, output.metadata) then return false, _L('inventory_full') end

    return true
end)

lib.callback.register('rtv-towing:server:craftItem', function(src, locationId, recipeId)
    local canUse, reason = canUseCraftingLocation(src, locationId)
    if not canUse then return false, reason end

    local location = getLocationById(locationId)
    if not location or not locationHasRecipe(location, recipeId) then return false, _L('crafting_no_access') end

    local recipe = getRecipeById(recipeId)
    if not recipe then return false, _L('crafting_failed') end
    if not hasIngredients(src, recipe) then return false, _L('crafting_missing_items') end

    local output = recipe.output or {}
    if not output.item then return false, _L('crafting_failed') end
    if not exports.ox_inventory:CanCarryItem(src, output.item, output.count or 1, output.metadata) then return false, _L('inventory_full') end
    if not removeIngredients(src, recipe) then return false, _L('crafting_missing_items') end

    local added = exports.ox_inventory:AddItem(src, output.item, output.count or 1, output.metadata)
    if not added then return false, _L('inventory_full') end

    local label = recipe.label or output.item
    return true, (_L('crafting_success')):format(output.count or 1, label)
end)
