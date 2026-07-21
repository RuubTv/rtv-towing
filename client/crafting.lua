local T = RTVTowing

local craftingZones = {}

local function getLocationById(locationId)
    for _, location in ipairs(Config.Crafting.locations or {}) do
        if location.id == locationId then return location end
    end
    return nil
end

local function formatIngredients(recipe)
    local lines = {}
    for _, ingredient in ipairs(recipe.ingredients or {}) do
        lines[#lines + 1] = ('%sx %s'):format(ingredient.count or 1, ingredient.item)
    end
    if #lines == 0 then return 'Geen materialen nodig.' end
    return table.concat(lines, ', ')
end

local function craftRecipe(locationId, recipeId)
    local location = getLocationById(locationId)
    if not location then return T.Notify(_L('crafting_failed'), 'error') end

    local recipe = Config.Crafting.recipes and Config.Crafting.recipes[recipeId]
    if not recipe then return T.Notify(_L('crafting_failed'), 'error') end

    local canCraft, reason = lib.callback.await('rtv-towing:server:canCraft', false, locationId, recipeId)
    if not canCraft then return T.Notify(reason or _L('crafting_no_access'), 'error') end

    local output = recipe.output or {}
    local outputLabel = recipe.label or output.item or recipeId

    local confirmed = T.UI.Confirm({
        title = outputLabel,
        message = ('Wil je dit craften?\n\nBenodigd: %s'):format(formatIngredients(recipe)),
        confirmLabel = 'Craften',
        cancelLabel = 'Annuleren'
    })

    if not confirmed then return end

    local success = T.UI.Progress({
        title = location.label or 'Crafting',
        label = ('Crafting: %s'):format(outputLabel),
        duration = recipe.duration or 5000,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }
    })

    if not success then return T.Notify(_L('crafting_cancelled'), 'error') end

    local crafted, msg = lib.callback.await('rtv-towing:server:craftItem', false, locationId, recipeId)
    if not crafted then return T.Notify(msg or _L('crafting_failed'), 'error') end

    T.Notify(msg or (_L('crafting_success')):format(output.count or 1, outputLabel), 'success')
end

local function openCraftingMenu(locationId)
    local canOpen, reason = lib.callback.await('rtv-towing:server:canUseCraftingLocation', false, locationId)
    if not canOpen then return T.Notify(reason or _L('crafting_no_access'), 'error') end

    local location = getLocationById(locationId)
    if not location then return T.Notify(_L('crafting_failed'), 'error') end

    local options = {}
    for _, recipeId in ipairs(location.recipes or {}) do
        local recipe = Config.Crafting.recipes and Config.Crafting.recipes[recipeId]
        if recipe then
            local output = recipe.output or {}
            options[#options + 1] = {
                title = recipe.label or recipeId,
                description = recipe.description or ('Benodigd: ' .. formatIngredients(recipe)),
                icon = '🛠',
                metadata = {
                    { label = 'Resultaat', value = ('%sx %s'):format(output.count or 1, output.item or 'unknown') },
                    { label = 'Benodigd', value = formatIngredients(recipe) }
                },
                onSelect = function() craftRecipe(locationId, recipeId) end
            }
        end
    end

    if #options == 0 then options[#options + 1] = { title = _L('crafting_no_recipes'), disabled = true } end

    T.UI.OpenMenu({
        id = 'rtv_towing_crafting_' .. locationId,
        title = location.label or _L('crafting_menu'),
        subtitle = 'Selecteer wat je wilt craften',
        options = options
    })
end

function T.RegisterCraftingZones()
    if not Config.Crafting or not Config.Crafting.enabled then return end
    if not Config.Crafting.locations then return end

    for _, zoneId in pairs(craftingZones) do
        pcall(function() exports.ox_target:removeZone(zoneId) end)
    end
    craftingZones = {}

    for _, location in ipairs(Config.Crafting.locations) do
        if location.id and location.coords then
            local zoneId = exports.ox_target:addSphereZone({
                coords = location.coords,
                radius = location.radius or 1.5,
                debug = Config.Debug or false,
                options = {
                    {
                        name = 'rtv_towing_crafting_' .. location.id,
                        icon = location.icon or 'fa-solid fa-screwdriver-wrench',
                        label = location.targetLabel or _L('crafting_open'),
                        distance = 2.0,
                        onSelect = function() openCraftingMenu(location.id) end
                    }
                }
            })
            craftingZones[#craftingZones + 1] = zoneId
        end
    end
end

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(1200)
    if T.RegisterCraftingZones then T.RegisterCraftingZones() end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, zoneId in pairs(craftingZones) do
        pcall(function() exports.ox_target:removeZone(zoneId) end)
    end
    craftingZones = {}
end)
