local T = RTVTowing
local S = T.State

local function enrichDashboardData(data)
    data = data or {}

    if T.GetRepoDashboardClientState then
        data.client = T.GetRepoDashboardClientState()
    end

    return data
end

function T.RefreshRepoDashboard()
    local data, err = lib.callback.await('rtv-towing:server:getRepoDashboard', false)

    if not data then
        T.Notify(err or 'Repo dashboard kon niet worden vernieuwd.', 'error', 'Repo Dashboard')
        return nil
    end

    data = enrichDashboardData(data)
    T.UI.OpenRepoDashboard(data)

    return data
end

function T.OpenRepoDashboard()
    local data, err = lib.callback.await('rtv-towing:server:getRepoDashboard', false)

    if not data then
        return T.Notify(err or 'Repo dashboard kon niet worden geladen.', 'error', 'Repo Dashboard')
    end

    data = enrichDashboardData(data)
    T.UI.OpenRepoDashboard(data)
end

RegisterCommand('repodashboard', function()
    T.OpenRepoDashboard()
end, false)

RegisterNUICallback('rtvTowingRepoDashboardClose', function(_, cb)
    if T.UI and T.UI.CloseRepoDashboard then
        T.UI.CloseRepoDashboard()
    else
        SetNuiFocus(false, false)
    end

    cb(true)
end)

RegisterNUICallback('rtvTowingRepoSkillUnlock', function(data, cb)
    local skillId = data and data.skillId

    if not skillId then
        cb({ ok = false, message = 'Geen skill gekozen.' })
        return
    end

    local ok, message, dashboard = lib.callback.await('rtv-towing:server:unlockRepoSkill', false, skillId)

    if ok then
        T.Notify(message or 'Skill vrijgespeeld.', 'success', 'Repo Skills')

        if dashboard and T.UI and T.UI.OpenRepoDashboard then
            T.UI.OpenRepoDashboard(enrichDashboardData(dashboard))
        end
    else
        T.Notify(message or 'Skill kon niet worden vrijgespeeld.', 'error', 'Repo Skills')
    end

    cb({ ok = ok == true, message = message or '', dashboard = dashboard })
end)
