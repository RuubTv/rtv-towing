RTVTowing = RTVTowing or {}
local T = RTVTowing
T.UI = T.UI or {}

local uiReady = false
local pendingMessages = {}
local activeMenuCallbacks = {}
local activeConfirmPromise = nil

local notifyTypeMap = {
    inform = 'info', info = 'info', success = 'success', error = 'error', warning = 'warning', warn = 'warning'
}

local function getUiMode(component)
    local ui = Config.UI or {}
    local defaultMode = ui.type or 'custom'
    if ui.components and ui.components[component] ~= nil then return ui.components[component] end
    return defaultMode
end

function T.UI.IsCustom(component)
    return getUiMode(component) == 'custom'
end

local function sendUI(action, data)
    if not uiReady and action ~= 'hideAll' then
        pendingMessages[#pendingMessages + 1] = { action = action, data = data or {} }
        return
    end
    SendNUIMessage({ action = action, data = data or {} })
end

local function flushPendingMessages()
    for _, payload in ipairs(pendingMessages) do
        SendNUIMessage({ action = payload.action, data = payload.data or {} })
    end
    pendingMessages = {}
end

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function parseControlsText(text)
    local keys = {}
    for key, label in tostring(text or ''):gmatch('%[([^%]]+)%]%s*([^|]+)') do
        keys[#keys + 1] = { key = trim(key), label = trim(label) }
    end
    if #keys == 0 then keys[#keys + 1] = { key = 'INFO', label = text or '' } end
    return keys
end

function T.UI.ShowActionBar(data)
    sendUI('showActionBar', {
        title = data.title or 'Towing',
        subtitle = data.subtitle or 'Controls',
        keys = data.keys or {},
        accent = data.accent or 'gold'
    })
end

function T.UI.HideActionBar()
    sendUI('hideActionBar')
end

function T.UI.ShowTextAsActionBar(text, title, subtitle)
    T.UI.ShowActionBar({
        title = title or 'Towing',
        subtitle = subtitle or 'Actieve bediening',
        keys = parseControlsText(text)
    })
end

function T.UI.ShowToast(data)
    sendUI('showToast', {
        title = data.title or 'Towing',
        message = data.message or '',
        type = notifyTypeMap[data.type] or data.type or 'info',
        duration = data.duration or 4500
    })
end

function T.UI.ShowRepoNote(data)
    sendUI('showRepoNote', {
        title = data.title or 'RTV Repo Note',
        vehicle = data.vehicle or 'Onbekend',
        plate = data.plate or 'Onbekend',
        hint = data.hint or nil,
        hintLabel = data.hintLabel or 'Voertuig hint',
        persistent = data.persistent == true,
        duration = data.duration or 0
    })
end

function T.UI.HideRepoNote()
    sendUI('hideRepoNote', {})
end

function T.UI.OpenMenu(data)
    activeMenuCallbacks = {}
    local options = {}
    for index, option in ipairs(data.options or {}) do
        local optionId = option.id or ('option_' .. index)
        if option.onSelect then activeMenuCallbacks[optionId] = option.onSelect end
        options[#options + 1] = {
            id = optionId,
            title = option.title or 'Optie',
            description = option.description or '',
            icon = option.icon or '',
            disabled = option.disabled == true,
            metadata = option.metadata or {},
            variant = option.variant or 'default'
        }
    end
    SetNuiFocus(true, true)
    sendUI('openMenu', {
        id = data.id or 'rtv_menu',
        title = data.title or 'RTV Towing',
        subtitle = data.subtitle or '',
        options = options
    })
end

function T.UI.CloseMenu()
    SetNuiFocus(false, false)
    activeMenuCallbacks = {}
    sendUI('closeMenu')
end

function T.UI.Confirm(data)
    -- Eigen RTV NUI confirm. Geen ox_lib alertDialog meer.
    if activeConfirmPromise then
        activeConfirmPromise:resolve(false)
        activeConfirmPromise = nil
    end

    local p = promise.new()
    activeConfirmPromise = p
    SetNuiFocus(true, true)
    sendUI('openConfirm', {
        title = data.title or 'Bevestigen',
        message = data.message or '',
        confirmLabel = data.confirmLabel or 'Bevestigen',
        cancelLabel = data.cancelLabel or 'Annuleren'
    })

    local result = Citizen.Await(p)
    SetNuiFocus(false, false)
    return result == true
end

function T.UI.Progress(data)
    -- Eigen RTV NUI progress. Geen ox_lib progressCircle meer.
    local duration = data.duration or 5000
    local canCancel = data.canCancel ~= false
    local start = GetGameTimer()
    local cancelled = false
    local ped = PlayerPedId()

    if data.anim and data.anim.dict and data.anim.clip then
        RequestAnimDict(data.anim.dict)
        local timeout = GetGameTimer() + 3000
        while not HasAnimDictLoaded(data.anim.dict) and GetGameTimer() < timeout do Wait(0) end
        if HasAnimDictLoaded(data.anim.dict) then
            TaskPlayAnim(ped, data.anim.dict, data.anim.clip, 3.0, 3.0, -1, 49, 0.0, false, false, false)
        end
    end

    sendUI('showProgress', {
        title = data.title or 'RTV Towing',
        label = data.label or 'Bezig...',
        duration = duration,
        canCancel = canCancel
    })

    while GetGameTimer() - start < duration do
        Wait(0)
        if data.disable then
            if data.disable.move then
                DisableControlAction(0, 30, true)
                DisableControlAction(0, 31, true)
                DisableControlAction(0, 21, true)
                DisableControlAction(0, 22, true)
            end
            if data.disable.car then
                DisableControlAction(0, 71, true)
                DisableControlAction(0, 72, true)
                DisableControlAction(0, 75, true)
            end
            if data.disable.combat then
                DisablePlayerFiring(PlayerId(), true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
            end
        end
        if canCancel and IsControlJustPressed(0, Config.ItemControls.cancel or 177) then
            cancelled = true
            break
        end
    end

    ClearPedTasks(ped)
    sendUI('hideProgress')
    return not cancelled
end


function T.UI.OpenRepoDashboard(data)
    SetNuiFocus(true, true)
    sendUI('openRepoDashboard', data or {})
end

function T.UI.CloseRepoDashboard()
    SetNuiFocus(false, false)
    sendUI('closeRepoDashboard')
end

function T.UI.HideAll()
    SetNuiFocus(false, false)
    activeMenuCallbacks = {}
    sendUI('hideAll')
end

RegisterNUICallback('rtvTowingUiReady', function(_, cb)
    uiReady = true
    flushPendingMessages()
    cb(true)
end)

RegisterNUICallback('rtvTowingMenuSelect', function(data, cb)
    local optionId = data and data.optionId
    local callback = optionId and activeMenuCallbacks[optionId]
    SetNuiFocus(false, false)
    sendUI('closeMenu')
    if callback then CreateThread(function() callback() end) end
    cb(true)
end)

RegisterNUICallback('rtvTowingMenuClose', function(_, cb)
    SetNuiFocus(false, false)
    activeMenuCallbacks = {}
    sendUI('closeMenu')
    cb(true)
end)

RegisterNUICallback('rtvTowingConfirmResult', function(data, cb)
    local accepted = data and data.accepted == true
    if activeConfirmPromise then
        activeConfirmPromise:resolve(accepted)
        activeConfirmPromise = nil
    end
    sendUI('closeConfirm')
    cb(true)
end)

do
    function T.Notify(description, nType, title)
        T.UI.ShowToast({
            title = title or 'RTV Towing',
            message = description or '',
            type = nType or 'info',
            duration = Config.Notify and Config.Notify.duration or 4500
        })
    end
end

do
    function T.ShowControlsText(text)
        if not T.State or not T.State.activeControlsUi then return end
        T.State.activeControlsUi.enabled = true
        T.State.activeControlsUi.text = text

        local lowered = string.lower(text or '')
        local title = 'RTV Towing'
        local subtitle = 'Actieve bediening'

        if lowered:find('winch') or lowered:find('intrekken') or lowered:find('vieren') then
            title = 'RTV Winch System'
            subtitle = 'Kabelbediening actief'
        elseif lowered:find('sleepkabel') then
            title = 'RTV Tow System'
            subtitle = 'Sleepkabel actief'
        end

        T.UI.ShowTextAsActionBar(text, title, subtitle)
    end

    function T.HideControlsText()
        if T.State and T.State.activeControlsUi then
            T.State.activeControlsUi.enabled = false
            T.State.activeControlsUi.text = nil
        end
        T.UI.HideActionBar()
    end
end

do
    function T.PickWorldPoint(label, requireVehicle, requiredVehicle)
        T.ResetKeyPresses()
        T.Notify(label or _L('winch_select_help'), 'info', 'RTV Punt Selectie')
        T.UI.ShowActionBar({
            title = 'RTV Point Selector',
            subtitle = label or 'Selecteer een punt',
            keys = {
                { key = T.GetDefaultKeyLabel and T.GetDefaultKeyLabel('confirm') or 'LMB', label = 'Bevestigen' },
                { key = T.GetDefaultKeyLabel and T.GetDefaultKeyLabel('cancel') or 'Backspace', label = 'Annuleren' }
            }
        })

        while true do
            Wait(0)
            if T.DisablePointSelectControls then T.DisablePointSelectControls() end
            local hit, coords, _, entity = T.RaycastFromCamera(35.0)
            if hit then
                DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.25, 212, 175, 55, 190, false, false, 2, false, nil, nil, false)
                if T.WasKeyPressed('confirm', Config.ItemControls.confirm or 24) then
                    if requireVehicle then
                        if not T.IsVehicleEntity(entity) then
                            T.Notify('Je moet een punt op een voertuig kiezen.', 'error')
                            Wait(350)
                        elseif requiredVehicle and entity ~= requiredVehicle then
                            T.Notify('Je moet het geselecteerde voertuig aanwijzen.', 'error')
                            Wait(350)
                        else
                            T.UI.HideActionBar()
                            T.ResetKeyPresses()
                            return coords, entity
                        end
                    else
                        T.UI.HideActionBar()
                        T.ResetKeyPresses()
                        return coords, entity
                    end
                end
            end
            if T.WasKeyPressed('cancel', Config.ItemControls.cancel or 177) then
                T.UI.HideActionBar()
                T.ResetKeyPresses()
                T.Notify(_L('winch_cancelled'), 'error')
                return nil, nil
            end
        end
    end
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    T.UI.HideAll()
end)

CreateThread(function()
    Wait(1500)
    if not uiReady then sendUI('hideAll') end
end)

-- RegisterCommand('eldtestui', function()
--     T.UI.ShowActionBar({
--         title = 'RTV Winch System',
--         subtitle = 'Test mode',
--         keys = {
--             { key = 'E', label = 'Intrekken' },
--             { key = 'Q', label = 'Vieren' },
--             { key = 'X', label = 'Pauze' },
--             { key = 'Backspace', label = 'Verwijderen' },
--         }
--     })
--     T.Notify('Custom UI werkt.', 'success', 'RTV UI')
-- end, false)

-- RegisterCommand('eldtestnotify', function()
--     T.Notify('Dit is een inform melding via jouw ingestelde UI.', 'info', 'RTV Info')
--     Wait(500)
--     T.Notify('Dit is een success melding via jouw ingestelde UI.', 'success', 'RTV Success')
--     Wait(500)
--     T.Notify('Dit is een error melding via jouw ingestelde UI.', 'error', 'RTV Error')
-- end, false)

-- RegisterCommand('eldtestmenu', function()
--     T.UI.OpenMenu({
--         id = 'rtv_test_menu',
--         title = 'RTV Test Menu',
--         subtitle = 'Custom menu test',
--         options = {
--             { title = 'Success melding', description = 'Klik om een testmelding te sturen.', icon = '✓', onSelect = function() T.Notify('Custom menu werkt.', 'success', 'RTV UI') end },
--             { title = 'Sluiten', description = 'Menu sluiten.', icon = '×', variant = 'danger', onSelect = function() T.Notify('Menu gesloten.', 'info', 'RTV UI') end }
--         }
--     })
-- end, false)

-- RegisterCommand('eldtestprogress', function()
--     local ok = T.UI.Progress({
--         title = 'RTV Crafting',
--         label = 'Test progress...',
--         duration = 5000,
--         canCancel = true,
--         disable = { move = true, car = true, combat = true },
--         anim = { dict = 'mini@repair', clip = 'fixing_a_ped' }
--     })
--     if ok then T.Notify('Progress voltooid.', 'success') else T.Notify('Progress geannuleerd.', 'error') end
-- end, false)

-- RegisterCommand('eldhideui', function()
--     T.UI.HideAll()
-- end, false)
