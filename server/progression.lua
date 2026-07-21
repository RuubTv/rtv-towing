local T = RTVTowing
local S = T.State

S.repoProgressionCache = S.repoProgressionCache or {}

local tableReady = false
local ensureTable

local defaultSkills = {
    {
        id = 'better_note',
        tree = 'Repo Specialist',
        label = 'Betere Repo Note',
        description = 'De repo note toont extra contractinformatie.',
        cost = 1,
        level = 1,
        icon = '📝',
        effects = { noteExtra = true }
    },
    {
        id = 'risk_reader',
        tree = 'Repo Specialist',
        label = 'Risico Inschatting',
        description = 'Toont het risico van de repo-opdracht in je dashboard en note.',
        cost = 1,
        level = 2,
        icon = '⚠',
        requires = { 'better_note' },
        effects = { riskVisible = true }
    },
    {
        id = 'material_specialist_1',
        tree = 'Materiaalhandel',
        label = 'Netjes Demonteren I',
        description = '+5% extra carparts/craftparts bij succesvolle repo ritten.',
        cost = 1,
        level = 2,
        icon = '⚙',
        effects = { materialBonus = 0.05 }
    },
    {
        id = 'material_specialist_2',
        tree = 'Materiaalhandel',
        label = 'Netjes Demonteren II',
        description = 'Nog eens +5% extra carparts/craftparts.',
        cost = 1,
        level = 4,
        icon = '⚙',
        requires = { 'material_specialist_1' },
        effects = { materialBonus = 0.05 }
    },
    {
        id = 'speed_bonus',
        tree = 'Recovery Operator',
        label = 'Snelle Afhandeling',
        description = '+25 XP als je een repo snel afrondt.',
        cost = 1,
        level = 3,
        icon = '⏱',
        effects = { fastBonus = true }
    },
    {
        id = 'calm_operator',
        tree = 'Risico & Conflict',
        label = 'Rustige Aanpak',
        description = 'Iets minder kans op boze eigenaren bij de pickup.',
        cost = 1,
        level = 3,
        icon = '🛡',
        effects = { angryChanceModifier = 0.85 }
    },
    {
        id = 'contract_expert',
        tree = 'Repo Specialist',
        label = 'Contract Expert',
        description = 'Kans op premium repo-contracten met extra beloning en XP.',
        cost = 1,
        level = 5,
        icon = '★',
        requires = { 'better_note' },
        effects = { premiumChance = 12 }
    },
    {
        id = 'master_operator',
        tree = 'Recovery Operator',
        label = 'Master Operator',
        description = '+10% XP op succesvolle repo ritten.',
        cost = 2,
        level = 7,
        icon = '◆',
        requires = { 'speed_bonus', 'calm_operator' },
        effects = { xpMultiplier = 1.10 }
    },
}

local function cfg()
    Config.RepoProgression = Config.RepoProgression or {}
    local c = Config.RepoProgression

    if c.enabled == nil then c.enabled = true end
    c.tableName = c.tableName or 'rtv_towing_progression'
    c.baseXp = c.baseXp or 100
    c.levelBase = c.levelBase or 125
    c.levelCurve = c.levelCurve or 1.25
    c.maxLevel = c.maxLevel or 25
    c.fastBonusSeconds = c.fastBonusSeconds or 600
    c.fastBonusXp = c.fastBonusXp or 25
    c.premiumBonusXp = c.premiumBonusXp or 35
    c.premiumMoneyMultiplier = c.premiumMoneyMultiplier or 1.15
    c.premiumMaterialBonus = c.premiumMaterialBonus or 10
    c.materialItems = c.materialItems or { carparts = true, craftparts = true }
    c.skills = c.skills or defaultSkills

    return c
end

local function getCitizenId(src)
    local player = T.GetPlayer(src)

    if not player or not player.PlayerData then
        return nil
    end

    return player.PlayerData.citizenid
        or player.PlayerData.citizenId
        or player.PlayerData.citizen
        or player.PlayerData.license
end

local function trimText(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function decodeCharInfo(charinfo)
    if type(charinfo) == 'table' then
        return charinfo
    end

    if type(charinfo) == 'string' and charinfo ~= '' then
        local ok, decoded = pcall(function()
            return json.decode(charinfo)
        end)

        if ok and type(decoded) == 'table' then
            return decoded
        end
    end

    return {}
end

local function getDisplayName(src, citizenid)
    local player = T.GetPlayer(src)

    if player and player.PlayerData then
        local data = player.PlayerData or {}
        local charinfo = decodeCharInfo(data.charinfo)

        local first = trimText(
            charinfo.firstname
            or charinfo.firstName
            or charinfo.first_name
            or charinfo.givenName
            or ''
        )

        local last = trimText(
            charinfo.lastname
            or charinfo.lastName
            or charinfo.last_name
            or charinfo.familyName
            or ''
        )

        local fullName = trimText(('%s %s'):format(first, last))

        if fullName ~= '' then
            return fullName
        end

        local charName = trimText(
            data.charname
            or data.characterName
            or data.fullname
            or data.fullName
            or data.name
            or ''
        )

        if charName ~= '' then
            return charName
        end
    end

    local playerName = trimText(GetPlayerName(src) or '')

    if playerName ~= '' then
        return playerName
    end

    local fallbackCitizenId = trimText(citizenid or '')

    if fallbackCitizenId ~= '' then
        return ('Burger %s'):format(fallbackCitizenId:sub(-4))
    end

    return ('Speler %s'):format(src)
end

local function isFallbackDisplayName(name)
    name = trimText(name)

    return name == ''
        or name:find('^Burger%s+') ~= nil
        or name:find('^Speler%s+') ~= nil
        or name == 'Onbekende speler'
end

local function safeLeaderboardName(row)
    local name = trimText(row and row.display_name or '')

    if name ~= '' and not isFallbackDisplayName(name) then
        return name
    end

    local citizenid = trimText(row and row.citizenid or '')

    if citizenid ~= '' then
        return ('Burger %s'):format(citizenid:sub(-4))
    end

    return 'Onbekende speler'
end

local function updateDisplayNameIfNeeded(src, row)
    if not row or not row.citizenid then
        return row
    end

    local displayName = getDisplayName(src, row.citizenid)

    if displayName ~= '' and (row.display_name ~= displayName or isFallbackDisplayName(row.display_name)) then
        row.display_name = displayName

        if ensureTable() then
            MySQL.update.await(
                ('UPDATE `%s` SET `display_name` = ? WHERE `citizenid` = ?'):format(cfg().tableName),
                { displayName, row.citizenid }
            )
        end
    end

    return row
end

local function encodeSkills(skills)
    return json.encode(skills or {})
end

local function decodeSkills(raw)
    if type(raw) == 'table' then
        return raw
    end

    if not raw or raw == '' then
        return {}
    end

    local ok, decoded = pcall(function()
        return json.decode(raw)
    end)

    if ok and type(decoded) == 'table' then
        return decoded
    end

    return {}
end

local function xpForLevel(level)
    level = tonumber(level or 1) or 1

    if level <= 1 then
        return 0
    end

    local c = cfg()
    local total = 0

    for i = 1, level - 1 do
        total = total + math.floor((c.levelBase or 125) * (i ^ (c.levelCurve or 1.25)) + 0.5)
    end

    return total
end

local function calculateLevel(totalXp)
    local c = cfg()
    local xp = tonumber(totalXp or 0) or 0
    local level = 1

    while level < (c.maxLevel or 25) and xp >= xpForLevel(level + 1) do
        level = level + 1
    end

    return level
end

local function getSkillConfig(skillId)
    for _, skill in ipairs(cfg().skills or {}) do
        if skill.id == skillId then
            return skill
        end
    end

    return nil
end

local function dependenciesUnlocked(skill, unlocked)
    for _, dependency in ipairs(skill.requires or {}) do
        if unlocked[dependency] ~= true then
            return false
        end
    end

    return true
end

function ensureTable()
    if tableReady then
        return true
    end

    local c = cfg()

    local ok, err = pcall(function()
        MySQL.query.await(([[
            CREATE TABLE IF NOT EXISTS `%s` (
                `citizenid` varchar(64) NOT NULL,
                `display_name` varchar(96) NULL,
                `xp` int NOT NULL DEFAULT 0,
                `level` int NOT NULL DEFAULT 1,
                `skill_points` int NOT NULL DEFAULT 0,
                `skills` longtext NULL,
                `successful_repos` int NOT NULL DEFAULT 0,
                `failed_repos` int NOT NULL DEFAULT 0,
                `cancelled_repos` int NOT NULL DEFAULT 0,
                `total_money` int NOT NULL DEFAULT 0,
                `total_materials` int NOT NULL DEFAULT 0,
                `total_xp` int NOT NULL DEFAULT 0,
                `weekly_repos` int NOT NULL DEFAULT 0,
                `weekly_xp` int NOT NULL DEFAULT 0,
                `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
                `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                PRIMARY KEY (`citizenid`)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        ]]):format(c.tableName))

        pcall(function()
            MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `display_name` varchar(96) NULL AFTER `citizenid`'):format(c.tableName))
        end)
    end)

    if not ok then
        print(('[rtv-towing] Progression table error: %s'):format(err or 'unknown'))
        return false
    end

    tableReady = true
    return true
end

local function defaultRow(citizenid)
    return {
        citizenid = citizenid,
        display_name = nil,
        xp = 0,
        level = 1,
        skill_points = 0,
        skills = {},
        successful_repos = 0,
        failed_repos = 0,
        cancelled_repos = 0,
        total_money = 0,
        total_materials = 0,
        total_xp = 0,
        weekly_repos = 0,
        weekly_xp = 0,
    }
end

local function normalizeRow(row, citizenid)
    row = row or defaultRow(citizenid)
    row.citizenid = row.citizenid or citizenid
    row.display_name = row.display_name
    row.xp = tonumber(row.xp or 0) or 0
    row.level = tonumber(row.level or 1) or 1
    row.skill_points = tonumber(row.skill_points or 0) or 0
    row.skills = decodeSkills(row.skills)
    row.successful_repos = tonumber(row.successful_repos or 0) or 0
    row.failed_repos = tonumber(row.failed_repos or 0) or 0
    row.cancelled_repos = tonumber(row.cancelled_repos or 0) or 0
    row.total_money = tonumber(row.total_money or 0) or 0
    row.total_materials = tonumber(row.total_materials or 0) or 0
    row.total_xp = tonumber(row.total_xp or 0) or 0
    row.weekly_repos = tonumber(row.weekly_repos or 0) or 0
    row.weekly_xp = tonumber(row.weekly_xp or 0) or 0

    return row
end

local function loadProgression(src, forceRefresh)
    if cfg().enabled == false then
        return nil
    end

    local citizenid = getCitizenId(src)

    if not citizenid then
        return nil
    end

    if not ensureTable() then
        return nil
    end

    if S.repoProgressionCache[citizenid] and not forceRefresh then
        return S.repoProgressionCache[citizenid]
    end

    local c = cfg()

    MySQL.insert.await(
        ('INSERT IGNORE INTO `%s` (`citizenid`, `display_name`, `skills`) VALUES (?, ?, ?)'):format(c.tableName),
        { citizenid, getDisplayName(src, citizenid), encodeSkills({}) }
    )

    local row = MySQL.single.await(
        ('SELECT * FROM `%s` WHERE `citizenid` = ? LIMIT 1'):format(c.tableName),
        { citizenid }
    )

    row = normalizeRow(row, citizenid)
    row = updateDisplayNameIfNeeded(src, row)
    S.repoProgressionCache[citizenid] = row

    return row
end

local function saveProgression(row)
    if not row or not row.citizenid or cfg().enabled == false then
        return false
    end

    if not ensureTable() then
        return false
    end

    local c = cfg()

    MySQL.update.await(
        ([[UPDATE `%s`
            SET `display_name` = ?, `xp` = ?, `level` = ?, `skill_points` = ?, `skills` = ?,
                `successful_repos` = ?, `failed_repos` = ?, `cancelled_repos` = ?,
                `total_money` = ?, `total_materials` = ?, `total_xp` = ?,
                `weekly_repos` = ?, `weekly_xp` = ?
            WHERE `citizenid` = ?]]):format(c.tableName),
        {
            row.display_name,
            row.xp or 0,
            row.level or 1,
            row.skill_points or 0,
            encodeSkills(row.skills or {}),
            row.successful_repos or 0,
            row.failed_repos or 0,
            row.cancelled_repos or 0,
            row.total_money or 0,
            row.total_materials or 0,
            row.total_xp or 0,
            row.weekly_repos or 0,
            row.weekly_xp or 0,
            row.citizenid
        }
    )

    S.repoProgressionCache[row.citizenid] = row
    return true
end

local function buildSkillList(row)
    row = row or {}
    local unlocked = row.skills or {}
    local list = {}

    for _, skill in ipairs(cfg().skills or {}) do
        local isUnlocked = unlocked[skill.id] == true
        local hasDependencies = dependenciesUnlocked(skill, unlocked)
        local cost = tonumber(skill.cost or 1) or 1
        local requiredLevel = tonumber(skill.level or 1) or 1

        list[#list + 1] = {
            id = skill.id,
            tree = skill.tree or 'Repo',
            label = skill.label or skill.id,
            description = skill.description or '',
            icon = skill.icon or '•',
            cost = cost,
            level = requiredLevel,
            requires = skill.requires or {},
            unlocked = isUnlocked,
            canUnlock = not isUnlocked
                and hasDependencies
                and (tonumber(row.level or 1) or 1) >= requiredLevel
                and (tonumber(row.skill_points or 0) or 0) >= cost,
            lockedReason = isUnlocked and 'Vrijgespeeld'
                or ((tonumber(row.level or 1) or 1) < requiredLevel and ('Level %s nodig'):format(requiredLevel))
                or (not hasDependencies and 'Vereiste skill ontbreekt')
                or ((tonumber(row.skill_points or 0) or 0) < cost and 'Niet genoeg skill points')
                or nil
        }
    end

    return list
end

function T.HasRepoSkill(src, skillId)
    local row = loadProgression(src)

    if not row then
        return false
    end

    return row.skills and row.skills[skillId] == true
end

function T.GetRepoSkillEffects(src)
    local row = loadProgression(src)
    local effects = {
        materialMultiplier = 1.0,
        premiumChance = 0,
        premiumMoneyMultiplier = cfg().premiumMoneyMultiplier or 1.15,
        premiumMaterialBonus = cfg().premiumMaterialBonus or 10,
        angryChanceModifier = 1.0,
        xpMultiplier = 1.0,
        fastBonus = false,
        noteExtra = false,
        riskVisible = false,
    }

    if not row then
        return effects
    end

    for _, skill in ipairs(cfg().skills or {}) do
        if row.skills and row.skills[skill.id] == true and skill.effects then
            if skill.effects.materialBonus then
                effects.materialMultiplier = effects.materialMultiplier + (tonumber(skill.effects.materialBonus) or 0.0)
            end

            if skill.effects.premiumChance then
                effects.premiumChance = effects.premiumChance + (tonumber(skill.effects.premiumChance) or 0)
            end

            if skill.effects.angryChanceModifier then
                effects.angryChanceModifier = math.min(effects.angryChanceModifier, tonumber(skill.effects.angryChanceModifier) or 1.0)
            end

            if skill.effects.xpMultiplier then
                effects.xpMultiplier = effects.xpMultiplier * (tonumber(skill.effects.xpMultiplier) or 1.0)
            end

            if skill.effects.fastBonus then
                effects.fastBonus = true
            end

            if skill.effects.noteExtra then
                effects.noteExtra = true
            end

            if skill.effects.riskVisible then
                effects.riskVisible = true
            end
        end
    end

    return effects
end

function T.BuildRepoContractMeta(src)
    local effects = T.GetRepoSkillEffects(src)
    local riskRoll = math.random(100)
    local riskLevel = 'Laag'

    if riskRoll >= 76 then
        riskLevel = 'Hoog'
    elseif riskRoll >= 42 then
        riskLevel = 'Middel'
    end

    local premium = effects.premiumChance > 0 and math.random(100) <= effects.premiumChance

    return {
        premium = premium == true,
        riskLevel = riskLevel,
        riskVisible = effects.riskVisible == true,
        noteExtra = effects.noteExtra == true,
        angryChanceModifier = effects.angryChanceModifier or 1.0,
    }
end

function T.AddRepoCompletionProgress(src, job, payoutData)
    if cfg().enabled == false then
        return nil
    end

    local row = loadProgression(src)

    if not row then
        return nil
    end

    local effects = T.GetRepoSkillEffects(src)
    local now = os.time()
    local duration = job and job.startedAt and (now - job.startedAt) or nil
    local xpGain = cfg().baseXp or 100

    if job and job.premium then
        xpGain = xpGain + (cfg().premiumBonusXp or 35)
    end

    if effects.fastBonus and duration and duration <= (cfg().fastBonusSeconds or 600) then
        xpGain = xpGain + (cfg().fastBonusXp or 25)
    end

    xpGain = math.floor(xpGain * (effects.xpMultiplier or 1.0) + 0.5)

    local oldLevel = row.level or 1
    row.xp = (row.xp or 0) + xpGain
    row.total_xp = (row.total_xp or 0) + xpGain
    row.weekly_xp = (row.weekly_xp or 0) + xpGain
    row.successful_repos = (row.successful_repos or 0) + 1
    row.weekly_repos = (row.weekly_repos or 0) + 1
    row.total_money = (row.total_money or 0) + ((payoutData and payoutData.money) or 0)
    row.total_materials = (row.total_materials or 0) + ((payoutData and payoutData.materials) or 0)
    row.level = calculateLevel(row.xp)

    local gainedLevels = math.max(0, row.level - oldLevel)

    if gainedLevels > 0 then
        row.skill_points = (row.skill_points or 0) + gainedLevels
    end

    saveProgression(row)

    if gainedLevels > 0 then
        return ('+%s XP, level %s (+%s skill point%s)'):format(
            xpGain,
            row.level,
            gainedLevels,
            gainedLevels == 1 and '' or 's'
        )
    end

    return ('+%s XP'):format(xpGain)
end

function T.AddRepoCancelled(src)
    local row = loadProgression(src)

    if not row then
        return
    end

    row.cancelled_repos = (row.cancelled_repos or 0) + 1
    saveProgression(row)
end


local function buildLeaderboard()
    if not ensureTable() then
        return {
            weekly = {},
            allTime = {},
            materials = {},
        }
    end

    local c = cfg()
    local leaderboard = {
        weekly = {},
        allTime = {},
        materials = {},
    }

    local function mapRows(rows, scoreType)
        local list = {}

        for index, row in ipairs(rows or {}) do
            list[#list + 1] = {
                rank = index,
                name = safeLeaderboardName(row),
                citizenid = row.citizenid,
                level = tonumber(row.level or 1) or 1,
                scoreType = scoreType,
                weeklyRepos = tonumber(row.weekly_repos or 0) or 0,
                weeklyXp = tonumber(row.weekly_xp or 0) or 0,
                successfulRepos = tonumber(row.successful_repos or 0) or 0,
                totalXp = tonumber(row.total_xp or 0) or 0,
                totalMaterials = tonumber(row.total_materials or 0) or 0,
                totalMoney = tonumber(row.total_money or 0) or 0,
            }
        end

        return list
    end

    local weeklyRows = MySQL.query.await(
        ([[SELECT `citizenid`, `display_name`, `level`, `weekly_repos`, `weekly_xp`, `successful_repos`, `total_xp`, `total_materials`, `total_money`
            FROM `%s`
            WHERE `weekly_repos` > 0 OR `weekly_xp` > 0
            ORDER BY `weekly_repos` DESC, `weekly_xp` DESC, `successful_repos` DESC
            LIMIT 10]]):format(c.tableName)
    ) or {}

    local allTimeRows = MySQL.query.await(
        ([[SELECT `citizenid`, `display_name`, `level`, `weekly_repos`, `weekly_xp`, `successful_repos`, `total_xp`, `total_materials`, `total_money`
            FROM `%s`
            WHERE `successful_repos` > 0 OR `total_xp` > 0
            ORDER BY `successful_repos` DESC, `total_xp` DESC, `total_materials` DESC
            LIMIT 10]]):format(c.tableName)
    ) or {}

    local materialRows = MySQL.query.await(
        ([[SELECT `citizenid`, `display_name`, `level`, `weekly_repos`, `weekly_xp`, `successful_repos`, `total_xp`, `total_materials`, `total_money`
            FROM `%s`
            WHERE `total_materials` > 0
            ORDER BY `total_materials` DESC, `successful_repos` DESC, `total_xp` DESC
            LIMIT 10]]):format(c.tableName)
    ) or {}

    leaderboard.weekly = mapRows(weeklyRows, 'weekly')
    leaderboard.allTime = mapRows(allTimeRows, 'allTime')
    leaderboard.materials = mapRows(materialRows, 'materials')

    return leaderboard
end

function T.GetRepoDashboardData(src)
    local row = loadProgression(src)

    if not row then
        return nil, 'Progressie kon niet worden geladen.'
    end

    local level = row.level or 1
    local levelStartXp = xpForLevel(level)
    local nextLevelXp = xpForLevel(level + 1)
    local xpIntoLevel = math.max(0, (row.xp or 0) - levelStartXp)
    local xpNeeded = math.max(1, nextLevelXp - levelStartXp)
    local activeRepo = S.activeRepos and S.activeRepos[src] or nil

    return {
        player = {
            citizenid = row.citizenid,
            xp = row.xp or 0,
            level = level,
            skillPoints = row.skill_points or 0,
            totalXp = row.total_xp or 0,
            xpIntoLevel = xpIntoLevel,
            xpNeeded = xpNeeded,
            nextLevelXp = nextLevelXp,
            progress = math.min(1.0, xpIntoLevel / xpNeeded),
        },
        stats = {
            successfulRepos = row.successful_repos or 0,
            failedRepos = row.failed_repos or 0,
            cancelledRepos = row.cancelled_repos or 0,
            totalMoney = row.total_money or 0,
            totalMaterials = row.total_materials or 0,
            weeklyRepos = row.weekly_repos or 0,
            weeklyXp = row.weekly_xp or 0,
        },
        active = activeRepo and {
            id = activeRepo.id,
            vehicle = activeRepo.vehicleModel,
            plate = activeRepo.plate,
            vehicleColor = activeRepo.vehicleColor,
            premium = activeRepo.premium == true,
            riskLevel = activeRepo.riskLevel,
            secured = activeRepo.secured == true,
            startedAt = activeRepo.startedAt,
            status = activeRepo.secured and 'Afleveren' or (activeRepo.targetNet and 'Voertuig gevonden' or 'Zoeken')
        } or nil,
        skills = buildSkillList(row),
        leaderboard = buildLeaderboard(),
        config = {
            fastBonusSeconds = cfg().fastBonusSeconds,
            premiumBonusXp = cfg().premiumBonusXp,
            baseXp = cfg().baseXp,
        }
    }
end

lib.callback.register('rtv-towing:server:getRepoDashboard', function(src)
    return T.GetRepoDashboardData(src)
end)

lib.callback.register('rtv-towing:server:unlockRepoSkill', function(src, skillId)
    local row = loadProgression(src, true)

    if not row then
        return false, 'Progressie kon niet worden geladen.'
    end

    skillId = tostring(skillId or '')

    local skill = getSkillConfig(skillId)

    if not skill then
        return false, 'Onbekende skill.'
    end

    row.skills = row.skills or {}

    if row.skills[skillId] == true then
        return false, 'Deze skill is al vrijgespeeld.'
    end

    local requiredLevel = tonumber(skill.level or 1) or 1

    if (row.level or 1) < requiredLevel then
        return false, ('Je hebt level %s nodig.'):format(requiredLevel)
    end

    if not dependenciesUnlocked(skill, row.skills) then
        return false, 'Je mist nog een vereiste skill.'
    end

    local cost = tonumber(skill.cost or 1) or 1

    if (row.skill_points or 0) < cost then
        return false, 'Niet genoeg skill points.'
    end

    row.skill_points = row.skill_points - cost
    row.skills[skillId] = true

    saveProgression(row)

    return true, ('Skill vrijgespeeld: %s'):format(skill.label or skillId), T.GetRepoDashboardData(src)
end)

CreateThread(function()
    Wait(1000)
    if cfg().enabled ~= false then
        ensureTable()
    end
end)
