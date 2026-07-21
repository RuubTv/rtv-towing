local T = RTVTowing
local S = T.State

local function startTowPhysicsLoop(ropeId, towingNet, targetNet, towingOffset, targetOffset)
    if S.towLoops[ropeId] then return end

    S.towLoops[ropeId] = {
        towingNet = towingNet,
        targetNet = targetNet,
        towingOffset = towingOffset,
        targetOffset = targetOffset
    }

    CreateThread(function()
        while S.towLoops[ropeId] do
            local towingVeh = T.GetEntityFromNet(towingNet)
            local targetVeh = T.GetEntityFromNet(targetNet)

            if towingVeh == 0 or targetVeh == 0 then break end

            local towingPoint = GetOffsetFromEntityInWorldCoords(towingVeh, towingOffset.x, towingOffset.y, towingOffset.z)
            local targetPoint = GetOffsetFromEntityInWorldCoords(targetVeh, targetOffset.x, targetOffset.y, targetOffset.z)
            local dist = #(towingPoint - targetPoint)

            if dist > Config.Rope.detachDistance then
                TriggerServerEvent('rtv-towing:server:stopTow')
                break
            end

            if dist > Config.Rope.towMaxLength + Config.Rope.towSlack then
                local speed = GetEntitySpeed(targetVeh)
                if speed < Config.Rope.towMaxVehicleSpeed then
                    local dir = (towingPoint - targetPoint) / dist
                    local force = math.min((dist - Config.Rope.towMaxLength) * Config.Rope.towPullForce, 4.0)
                    T.RequestControl(targetVeh, 500)
                    SetVehicleHandbrake(targetVeh, false)
                    ApplyForceToEntity(targetVeh, 1, dir.x * force, dir.y * force, math.max(dir.z * force, 0.03), targetOffset.x, targetOffset.y, targetOffset.z, 0, false, true, true, false, true)
                end
            end

            Wait(80)
        end

        S.towLoops[ropeId] = nil
    end)
end

local function isPlayerNearTow(ropeId)
    local data = S.towLoops[ropeId]
    if not data then return false end

    local playerCoords = GetEntityCoords(PlayerPedId())
    local maxDistance = Config.Rope.controlDistance or 25.0

    local towingVeh = T.GetEntityFromNet(data.towingNet)
    if towingVeh ~= 0 and DoesEntityExist(towingVeh) and #(playerCoords - GetEntityCoords(towingVeh)) <= maxDistance then return true end

    local targetVeh = T.GetEntityFromNet(data.targetNet)
    if targetVeh ~= 0 and DoesEntityExist(targetVeh) and #(playerCoords - GetEntityCoords(targetVeh)) <= maxDistance then return true end

    return false
end

local function startOwnedTowControls(ropeId)
    if S.activeOwnedTowId == ropeId then
        return
    end

    T.ResetKeyPresses()

    S.activeOwnedTowId = ropeId

    CreateThread(function()
        T.ShowControlsText(('[%s] Sleepkabel verwijderen | keybind aanpasbaar in FiveM instellingen'):format(
            T.GetDefaultKeyLabel('cancel')
        ))

        while S.activeOwnedTowId == ropeId do
            local nearEnough = isPlayerNearTow(ropeId)
            local pressedCancel = T.WasKeyPressed('cancel', Config.ItemControls.cancel or 177)

            if pressedCancel then
                if not nearEnough then
                    T.Notify(
                        ('Je staat te ver weg van de sleepkabel. Max afstand: %sm'):format(Config.Rope.controlDistance or 25.0),
                        'error'
                    )
                else
                    if T.DoWorkAnim('Sleepkabel losmaken...', 1600, 'cable') then
                        TriggerServerEvent('rtv-towing:server:stopTow')
                    end
                end
            end

            Wait(0)
        end

        T.HideControlsText()
    end)
end

RegisterNetEvent('rtv-towing:client:startOwnedTowControls', function(ropeId)
    startOwnedTowControls(ropeId)
end)

RegisterNetEvent('rtv-towing:client:syncTowRope', function(ropeId, owner, towingNet, targetNet, towingOffset, targetOffset)
    local towingVeh = T.GetEntityFromNet(towingNet)
    local targetVeh = T.GetEntityFromNet(targetNet)
    if towingVeh == 0 or targetVeh == 0 then return end

    towingOffset = towingOffset or { x = 0.0, y = -4.8, z = 0.55 }
    targetOffset = targetOffset or { x = 0.0, y = 2.2, z = 0.35 }

    T.CreateVisualRope('tow:' .. ropeId, towingVeh, targetVeh, vec3(towingOffset.x, towingOffset.y, towingOffset.z), vec3(targetOffset.x, targetOffset.y, targetOffset.z), Config.Rope.towMaxLength)

    local myServerId = GetPlayerServerId(PlayerId())
    if owner == myServerId then
        startTowPhysicsLoop(ropeId, towingNet, targetNet, towingOffset, targetOffset)
        startOwnedTowControls(ropeId)
    end
end)

RegisterNetEvent('rtv-towing:client:removeTowRope', function(ropeId)
    T.DeleteRopeByKey('tow:' .. ropeId)
    S.towLoops[ropeId] = nil
    if S.activeOwnedTowId == ropeId then
        S.activeOwnedTowId = nil
        T.HideControlsText()
    end
end)

function T.UseTowRopeItem()
    local allowed = lib.callback.await('rtv-towing:server:canUse', false, 'tow')
    if not allowed then return T.Notify(_L('no_access'), 'error') end

    T.Notify(_L('tow_item_start'), 'inform')
    local towingPoint, towingVeh = T.PickWorldPoint(_L('tow_item_start'), true)
    if not towingPoint or not towingVeh then return T.Notify(_L('tow_item_cancelled'), 'error') end
    if not T.IsVehicleEntity(towingVeh) then return T.Notify(_L('no_vehicle'), 'error') end

    T.Notify(_L('tow_item_target'), 'inform')
    local targetPoint, targetVeh = T.PickWorldPoint(_L('tow_item_target'), true)
    if not targetPoint or not targetVeh then return T.Notify(_L('tow_item_cancelled'), 'error') end
    if not T.IsVehicleEntity(targetVeh) then return T.Notify(_L('no_vehicle'), 'error') end
    if towingVeh == targetVeh then return T.Notify(_L('tow_wrong_vehicle'), 'error') end

    local towingOffset = T.GetVehicleHookOffset(towingVeh, towingPoint)
    local targetOffset = T.GetVehicleHookOffset(targetVeh, targetPoint)

    if not T.DoWorkAnim('Sleepkabel aankoppelen...', 3500, 'cable') then
        return T.Notify(_L('tow_item_cancelled'), 'error')
    end

    TriggerServerEvent('rtv-towing:server:startTow', T.GetNetId(towingVeh), T.GetNetId(targetVeh), towingOffset, targetOffset)
    T.Notify(_L('tow_item_active'), 'success')
end

RegisterNetEvent('rtv-towing:client:useTowRope', function()
    T.UseTowRopeItem()
end)
