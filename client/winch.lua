local T = RTVTowing
local S = T.State

local function startWinchLoop(winchId, vehicleNet, anchorNet, anchorCoords, vehicleOffset)
    if S.winchLoops[winchId] then return end

    S.winchLoops[winchId] = {
        pulling = false,
        releasing = false,
        vehicleNet = vehicleNet,
        anchorNet = anchorNet,
        anchorCoords = anchorCoords,
        vehicleOffset = vehicleOffset
    }

    CreateThread(function()
        while S.winchLoops[winchId] do
            local vehicle = T.GetEntityFromNet(vehicleNet)
            if vehicle == 0 then break end

            local anchor = anchorNet and T.GetEntityFromNet(anchorNet) or 0
            local anchorPos = anchor ~= 0 and GetEntityCoords(anchor) or vector3(anchorCoords.x, anchorCoords.y, anchorCoords.z)
            local attachWorld = GetOffsetFromEntityInWorldCoords(vehicle, vehicleOffset.x, vehicleOffset.y, vehicleOffset.z)
            local dist = #(anchorPos - attachWorld)

            if dist > Config.Rope.detachDistance then
                TriggerServerEvent('rtv-towing:server:stopWinch')
                break
            end

            if S.winchLoops[winchId].pulling and dist > Config.Rope.winchMinLength then
                local speed = GetEntitySpeed(vehicle)
                if speed < Config.Rope.winchMaxVehicleSpeed then
                    local dir = (anchorPos - attachWorld) / dist
                    T.RequestControl(vehicle, 500)
                    ApplyForceToEntity(vehicle, 1, dir.x * Config.Rope.winchForce, dir.y * Config.Rope.winchForce, math.max(dir.z * Config.Rope.winchForce, 0.03), vehicleOffset.x, vehicleOffset.y, vehicleOffset.z, 0, false, true, true, false, true)
                end
            elseif S.winchLoops[winchId].releasing then
                T.RequestControl(vehicle, 250)
                SetVehicleHandbrake(vehicle, false)
            end

            Wait(Config.Rope.winchTick)
        end

        S.winchLoops[winchId] = nil
    end)
end

local function isPlayerNearWinch(winchId)
    local data = S.winchLoops[winchId]
    if not data then return false end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local maxDistance = Config.Rope.controlDistance or 25.0

    local vehicle = T.GetEntityFromNet(data.vehicleNet)
    if vehicle ~= 0 and DoesEntityExist(vehicle) and #(playerCoords - GetEntityCoords(vehicle)) <= maxDistance then return true end

    if data.anchorNet then
        local anchor = T.GetEntityFromNet(data.anchorNet)
        if anchor ~= 0 and DoesEntityExist(anchor) and #(playerCoords - GetEntityCoords(anchor)) <= maxDistance then return true end
    end

    if data.anchorCoords then
        local anchorCoords = vector3(data.anchorCoords.x, data.anchorCoords.y, data.anchorCoords.z)
        if #(playerCoords - anchorCoords) <= maxDistance then return true end
    end

    return false
end

local function startOwnedWinchControls(winchId)
    if S.activeOwnedWinchId == winchId then
        return
    end

    T.ResetKeyPresses()

    S.activeOwnedWinchId = winchId

    CreateThread(function()
        T.ShowControlsText(('[%s] Intrekken  |  [%s] Vieren  |  [%s] Pauze  |  [%s] Verwijderen  |  keybinds aanpasbaar'):format(
            T.GetDefaultKeyLabel('winchPull'),
            T.GetDefaultKeyLabel('winchRelease'),
            T.GetDefaultKeyLabel('winchPause'),
            T.GetDefaultKeyLabel('cancel')
        ))

        local distanceStopped = false

        while S.activeOwnedWinchId == winchId do
            T.DisableWinchControls()

            local nearEnough = isPlayerNearWinch(winchId)

            local pressedPull = T.WasKeyPressed('winchPull', Config.ItemControls.winchPull or 38)
            local pressedRelease = T.WasKeyPressed('winchRelease', Config.ItemControls.winchRelease or 44)
            local pressedPause = T.WasKeyPressed('winchPause', Config.ItemControls.winchPause or 73)
            local pressedCancel = T.WasKeyPressed('cancel', Config.ItemControls.cancel or 177)

            if not nearEnough then
                -- Als speler wegloopt terwijl de winch actief is:
                -- stil stoppen, zonder melding.
                if not distanceStopped then
                    distanceStopped = true
                    TriggerServerEvent('rtv-towing:server:winchMode', 'stop', true)
                end

                -- Alleen melding tonen als speler echt probeert te bedienen.
                if pressedPull or pressedRelease or pressedPause or pressedCancel then
                    T.Notify(
                        ('Je staat te ver weg van de winch. Max afstand: %sm'):format(Config.Rope.controlDistance or 25.0),
                        'error'
                    )
                end

                Wait(0)
            else
                distanceStopped = false

                if pressedPull then
                    TriggerServerEvent('rtv-towing:server:winchMode', 'pull')
                end

                if pressedRelease then
                    TriggerServerEvent('rtv-towing:server:winchMode', 'release')
                end

                if pressedPause then
                    TriggerServerEvent('rtv-towing:server:winchMode', 'stop')
                end

                if pressedCancel then
                    if T.DoWorkAnim('Winch kabel losmaken...', 1800, 'cable') then
                        TriggerServerEvent('rtv-towing:server:stopWinch')
                    end
                end

                Wait(0)
            end
        end

        T.HideControlsText()
    end)
end

RegisterNetEvent('rtv-towing:client:startOwnedWinchControls', function(winchId)
    startOwnedWinchControls(winchId)
end)

RegisterNetEvent('rtv-towing:client:syncWinch', function(winchId, owner, vehicleNet, anchorNet, anchorCoords, vehicleOffset)
    local vehicle = T.GetEntityFromNet(vehicleNet)
    if vehicle == 0 then return end

    local anchor = anchorNet and T.GetEntityFromNet(anchorNet) or 0
    vehicleOffset = vehicleOffset or { x = 0.0, y = -2.0, z = 0.4 }

    if anchor ~= 0 then
        T.CreateVisualRope('winch:' .. winchId, vehicle, anchor, vec3(vehicleOffset.x, vehicleOffset.y, vehicleOffset.z), vec3(0.0, 0.0, 0.0), Config.Rope.winchMaxLength)
    else
        local model = T.LoadModel('prop_tool_box_04')
        if not model then return end
        local dummy = CreateObjectNoOffset(model, anchorCoords.x, anchorCoords.y, anchorCoords.z, false, false, false)
        SetEntityVisible(dummy, false, false)
        FreezeEntityPosition(dummy, true)
        T.CreateVisualRope('winch:' .. winchId, vehicle, dummy, vec3(vehicleOffset.x, vehicleOffset.y, vehicleOffset.z), vec3(0.0, 0.0, 0.0), Config.Rope.winchMaxLength)
        S.activeRopes['winch:' .. winchId].dummy = dummy
    end

    local myServerId = GetPlayerServerId(PlayerId())
    if owner == myServerId then
        startWinchLoop(winchId, vehicleNet, anchorNet, anchorCoords, vehicleOffset)
        startOwnedWinchControls(winchId)
    end
end)

RegisterNetEvent('rtv-towing:client:removeWinch', function(winchId)
    T.DeleteRopeByKey('winch:' .. winchId)
    S.winchLoops[winchId] = nil
    if S.activeOwnedWinchId == winchId then
        S.activeOwnedWinchId = nil
        T.HideControlsText()
    end
end)

RegisterNetEvent('rtv-towing:client:setWinchMode', function(winchId, mode)
    if not S.winchLoops[winchId] then return end
    S.winchLoops[winchId].pulling = mode == 'pull'
    S.winchLoops[winchId].releasing = mode == 'release'
end)

function T.UseWinchItem()
    local allowed = lib.callback.await('rtv-towing:server:canUse', false, 'winch')
    if not allowed then return T.Notify(_L('no_access'), 'error') end

    T.Notify(_L('winch_item_start'), 'inform')
    local vehiclePoint, vehicle = T.PickWorldPoint(_L('winch_item_start'), true)
    if not vehiclePoint or not vehicle then return T.Notify(_L('winch_cancelled'), 'error') end
    if not T.IsVehicleEntity(vehicle) then return T.Notify(_L('no_vehicle'), 'error') end

    T.Notify(_L('winch_item_anchor'), 'inform')
    local anchorPoint, anchorEntity = T.PickWorldPoint(_L('winch_item_anchor'), false)
    if not anchorPoint then return T.Notify(_L('winch_cancelled'), 'error') end

    local vehicleOffset = T.GetVehicleHookOffset(vehicle, vehiclePoint)

    if not T.DoWorkAnim('Winch kabel koppelen...', 3500, 'cable') then
        return T.Notify(_L('winch_cancelled'), 'error')
    end

    local vehicleNet = T.GetNetId(vehicle)
    local anchorNet = nil
    if anchorEntity and anchorEntity ~= 0 and NetworkGetEntityIsNetworked(anchorEntity) then
        anchorNet = NetworkGetNetworkIdFromEntity(anchorEntity)
    end

    TriggerServerEvent('rtv-towing:server:startWinch', vehicleNet, anchorNet, { x = anchorPoint.x, y = anchorPoint.y, z = anchorPoint.z }, vehicleOffset)
    T.Notify(_L('winch_item_active'), 'success')
end

RegisterNetEvent('rtv-towing:client:useWinch', function()
    T.UseWinchItem()
end)
