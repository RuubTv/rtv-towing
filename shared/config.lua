--============================================================
-- BASIS
--============================================================

Config = {}

Config.Locale = 'nl'
Config.Debug = false

Config.Notify = {
    position = 'top-right',
    duration = 4500,
}

Config.UI = {
    -- 'custom' = RTV NUI
    -- 'ox' = standaard ox_lib UI
    type = 'custom',

    -- Zet onderdelen op nil om Config.UI.type te gebruiken.
    components = {
        notifications = 'custom',
        controls = 'custom',
        pointSelector = 'custom',
        repoNote = 'custom',
        repoMenu = 'custom',
        craftingMenu = 'custom',
        progress = 'custom',
        confirm = 'custom',
        bedMenu = 'custom',
        remoteMenu = 'custom',
    }
}

--============================================================
-- JOBS & ITEMS
--============================================================

Config.Jobs = {
    towJob = 'sandytow',
    requireDuty = false,

    repoJobs = {
        'sandytow'
    },

    requireJobForBed = true,
    bedJobs = {
        'sandytow',
        'mechanic',
        'bennys',
        'cruisin',
        'goldcoast',
        'occasion'
    },

    towJobs = {
        'sandytow',
        'mechanic',
        'bennys',
        'cruisin',
        'goldcoast',
    },

    winchEveryone = true,
}

Config.Items = {
    towRope = 'rtv_towrope',
    winch = 'rtv_winch',
    remote = 'rtv_tow_remote',
}

Config.VehicleKeys = {
    enabled = true,
    giveCompanyTruckKeys = true,
    giveRepoVehicleKeys = true,

    -- True voorkomt qbx_vehiclekeys standaardmelding.
    skipNotification = false,

    -- eld stuurt daarna zelf een melding via de ingestelde UI.
    notifyInEld = false,
    keyMessage = 'Je hebt voertuigsleutels ontvangen.',
    unlockRepoVehicle = true,
}

Config.Remote = {
    enabled = true,
    requireItem = true,
    allowBed = true,
    allowRamp = false,
    allowTow = false,
    allowWinch = false,
}

--============================================================
-- KEYBINDS & ANIMATIES
--============================================================

Config.ItemControls = {
    confirm = 24, -- Linkermuisknop
    cancel = 177, -- Backspace
    winchPull = 38, -- E
    winchRelease = 44, -- Q
    winchPause = 73, -- X
}

Config.Animations = {
    cable = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    ramp = { dict = 'mini@repair', clip = 'fixing_a_ped' },
    bed = { dict = 'mini@repair', clip = 'fixing_a_ped' }
}

Config.Controls = {
    disableFmltowBedKeys = true,
    disabledInTowTruck = {
        21, -- LEFT SHIFT
        36, -- LEFT CTRL
    }
}

--============================================================
-- ROPE / WINCH / TOW
--============================================================

Config.Rope = {
    towMaxLength = 5.0,
    towMinLength = 1.0,
    towSlack = 1.25,
    towPullForce = 0.42,
    towMaxVehicleSpeed = 16.0,

    winchMaxLength = 70.0,
    winchMinLength = 2.2,
    ropeType = 1,
    winchForce = 2.0,
    winchTick = 85,
    winchMaxVehicleSpeed = 3.2,

    detachDistance = 35.0,

    -- Winch/tow bediening mag alleen dichtbij.
    controlDistance = 15.0,
}

--============================================================
-- RAMP FALLBACK
--============================================================

Config.Ramp = {
    enabled = true,
    model = 'imp_prop_flatbed_ramp',
    twoRamps = false,
    singleOffset = vec3(0.0, -9.5, -1.2),
    offsets = {
        left = vec3(-0.75, -7.35, -0.92),
        right = vec3(0.75, -7.35, -0.92),
    },
    rotation = vec3(0.0, 0.0, 180.0),
    freeze = true,
    removeDistance = 8.0,
    removeCommand = {
        enabled = true,
        command = 'ramp',
        distance = 15.0
    }
}

--============================================================
-- TRUCKS / FLATBEDS
--============================================================

Config.Trucks = {
    [`FMLtow1`] = {
        label = 'FML Tow',
        model = 'FMLtow1',

        bed = {
            enabled = true,
            bone = 'chassis',
            searchRadius = 9.0,
            offsets = {
                center = { label = 'Midden op laadbed', pos = vec3(0.0, -2.15, 0.9), rot = vec3(0.0, 0.0, 0.0) },
            }
        },

        rope = {
            towRearOffset = vec3(0.0, -4.8, 0.55),
            winchOffset = vec3(0.0, -4.4, 0.75),
        },

        ramp = {
            enabled = true,
            model = 'imp_prop_flatbed_ramp',
            twoRamps = false,

            singleOffset = vec3(0.0, -9.0, -1.15),
            
            offsets = {
                left = vec3(-0.75, -7.35, -0.92),
                right = vec3(0.75, -7.35, -0.92),
            },

            rotation = vec3(0.0, 0.0, 180.0),
            freeze = true,
        }
    },

    [`tcguardow`] = {
        label = 'TC Guard Tow',
        model = 'tcguardow',

        bed = {
            enabled = true,
            bone = 'bodyshell',
            searchRadius = 9.0,
            offsets = {
                center = { label = 'Midden op laadbed', pos = vec3(0.0, -3.2, 0.4), rot = vec3(0.0, 0.0, 0.0) },
            }
        },

        rope = {
            towRearOffset = vec3(0.0, -4.8, 0.55),
            winchOffset = vec3(0.0, -4.4, 0.75),
        },

        ramp = {
            enabled = true,
            model = 'imp_prop_flatbed_ramp',
            twoRamps = false,

            -- Deze offset kun je per voertuig tunen
            singleOffset = vec3(0.0, -9.3, -1.7),

            offsets = {
                left = vec3(-0.75, -6.85, -0.75),
                right = vec3(0.75, -6.85, -0.75),
            },

            rotation = vec3(0.0, 0.0, 180.0),
            freeze = true,
        }
    },
}

--============================================================
-- REPO JOB
--============================================================

Config.Repo = {
    enabled = true,
    cooldownSeconds = 45,

    noteItem = 'rtv_repo_note',
    searchLocationsAmount = 3,
    autoWaypoint = false,
    deliveryVehicleRadius = 18.0,

    useCompanyTruck = true,
    companyTruckModel = 'FMLtow1',
    
    vehicleSpawnDistance = 180.0,
    vehicleSpawnRetries = 3,

    lockRepoVehicle = true,
    spawnAngryPeds = true,

    plate = {
    prefix = 'RTV',
    digits = 5,
},

    dropoffPed = {
        enabled = true,
        model = 's_m_m_autoshop_02',
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        spawnDistance = 190.0
    },

    startPed = {
        model = 'mp_m_waremech_01',
        coords = vec4(1186.650, 2644.544, 38.402, 181.68),
        scenario = 'WORLD_HUMAN_CLIPBOARD',
        blip = { enabled = true, sprite = 596, color = 43, scale = 0.75, label = 'Repo/Towing' }
    },

    truckSpawns = {
        vec4(1204.64, 2636.16, 37.90, 304.19),
        vec4(1208.10, 2632.72, 37.90, 306.20),
    },

    dropoffs = {
        { ped = vec4(2897.38, 4398.55, 50.24, 201.19), truck = vec4(2894.85, 4392.36, 50.41, 203.27) },
        { ped = vec4(1705.76, 3757.80, 34.38, 222.11), truck = vec4(1710.17, 3752.59, 34.21, 218.00) },
        { ped = vec4(43.24, 2794.63, 57.88, 60.81), truck = vec4(40.81, 2802.11, 57.88, 146.82) },
    },

    repoVehicles = {
        'blista', 'asea', 'sultan', 'primo', 'intruder', 'buffalo',
        'jackal', 'stanier', 'washington', 'seminole', 'baller', 'oracle',
        'sentinel', 'zion', 'schafter2', 'rhapsody', 'boor', 'cinquemila',
        'tailgater2', 'issi7', 'glendale2', 'fr36', 'kanjosj', 'futo',
        'novak', 'radi', 'vivanite', 'champion', 'yosemite2', 'buffalo5',
    },

    pickupSpawns = {
            --Sandy Shores South
        vec4(1499.31, 1120.69, 113.69, 0.22), 
        vec4(1488.37, 1082.02, 113.69, 268.74),
        vec4(1534.7, 1702.46, 109.07, 81.51),
        vec4(1222.59, 1872.4, 78.26, 92.73),
        vec4(1259.37, 1914.59, 77.86, 229.39),
        vec4(1151.15, 2092.72, 55.12, 231.79),
        vec4(862.75, 2147.01, 51.74, 329.94),
        vec4(847.75, 2195.92, 51.43, 359.42),
        vec4(873.73, 2335.6, 51.02, 311.19),
        vec4(875.94, 2354.6, 51.05, 93.9),
        vec4(854.84, 2425.37, 53.99, 271.35),
        vec4(1090.08, 2544.52, 54.09, 88.89),
        vec4(740.43, 2576.04, 74.79, 18.05),
        vec4(756.8, 2532.51, 72.51, 87.17),
        vec4(389.18, 2589.3, 42.88, 41.86),
        vec4(362.26, 2586.02, 42.88, 43.19),
        vec4(344.19, 2590.29, 43.09, 298.06),
        vec4(196.57, 2456.64, 55.12, 266.77),
        vec4(164.58, 2746.33, 42.82, 283.38),
        vec4(273.27, 2593.83, 43.98, 104.06),
        vec4(247.83, 2599.07, 44.4, 63.65),
        vec4(261.2, 2578.87, 44.43, 99.69),
        vec4(221.98, 2580.14, 45.18, 100.34),
        vec4(332.65, 2611.64, 43.85, 13.36),
        vec4(354.75, 2626.69, 43.86, 213.63),
        vec4(374.1, 2634.04, 43.85, 32.07),
        vec4(462.75, 2606.87, 42.63, 9.65),
        vec4(497.56, 2613.69, 42.32, 10.02),
        vec4(558.96, 2599.35, 42.23, 61.19),
        vec4(545.82, 2653.68, 41.6, 95.53),
        vec4(555.34, 2677.71, 41.5, 280.07),
        vec4(559.68, 2718.9, 41.42, 2.17),
        vec4(558.83, 2734.99, 41.42, 3.99),
        vec4(602.82, 2722.07, 41.25, 183.54),
        vec4(642.37, 2735.66, 41.24, 273.81),
        vec4(639.4, 2775.84, 41.33, 264.9),
        vec4(603.47, 2787.53, 41.55, 10.31),
        vec4(572.45, 2795.84, 41.41, 330.81),
        vec4(554.43, 2806.15, 41.62, 144.51),
        vec4(869.59, 2870.97, 56.27, 199.69),
        vec4(927.16, 2736.73, 39.05, 187.96),
        vec4(969.65, 2719.18, 38.84, 175.14),
        vec4(994.12, 2653.74, 39.49, 0.03),
        vec4(1020.7, 2663.26, 38.93, 269.42),
        vec4(1020.24, 2652.54, 38.93, 321.92),
        vec4(1040.26, 2650.16, 38.91, 269.09),
        vec4(1063.57, 2655.91, 38.91, 23.28),
        vec4(1063.96, 2667.25, 38.91, 88.74),
        vec4(1101.85, 2663.57, 37.33, 359.98),
        vec4(1093.34, 2644.04, 37.29, 2.83),
        vec4(1112.94, 2628.56, 37.35, 90.89),
        vec4(1138.04, 2627.54, 37.36, 269.98),
        vec4(1154.85, 2657.39, 37.36, 359.76),
        vec4(1177.44, 2724.16, 37.36, 296.46),
        vec4(1235.3, 2739.22, 37.36, 181.59),
        vec4(1478.99, 2719.25, 37.19, 304.47),
        vec4(1432.02, 2787.34, 51.61, 347.24),
        vec4(1438.82, 2811.73, 52.01, 151.21),
        vec4(1345.39, 2739.44, 51.53, 331.15),
        vec4(1337.6, 2759.53, 50.72, 359.21),
        vec4(1854.87, 2668.51, 45.03, 270.03),
        vec4(1855.28, 2627.89, 45.03, 270.96),
        vec4(1876.78, 2625.67, 45.03, 269.51),
        vec4(1870.46, 2563.98, 45.03, 271.45),
        vec4(1854.68, 2538.44, 45.03, 269.48),
        vec4(2053.55, 2944.88, 47.04, 215.19),
        vec4(2366.42, 3162.54, 47.49, 94.55),
        vec4(2243.22, 3194.37, 47.98, 284.42),
        vec4(2207.16, 3306.64, 45.53, 299.06),
        vec4(2171.24, 3356.51, 44.7, 312.57),
        vec4(2169.46, 3368.36, 44.71, 299.76),
        vec4(2176.3, 3503.62, 44.73, 62.13),
        vec4(2097.3, 3563.59, 41.35, 120.11),
        vec4(2029.13, 3422.06, 43.72, 313.81),
        vec4(2040.22, 3457.0, 43.16, 270.54),
        vec4(2062.49, 3418.67, 43.79, 168.63),
        vec4(2076.52, 3199.46, 44.4, 48.37),
        vec4(2050.74, 3193.49, 44.54, 173.01),
        vec4(2062.99, 3185.69, 44.54, 120.49),
        vec4(2016.24, 3061.85, 46.41, 111.12),
        vec4(1990.85, 3023.54, 46.42, 58.12),
        vec4(1981.63, 3044.68, 46.42, 238.68),
        vec4(1967.09, 3034.89, 46.41, 341.4),
        vec4(1730.07, 3295.06, 40.57, 230.08),
        vec4(1748.48, 3323.82, 40.48, 247.32),
        vec4(1764.88, 3338.71, 40.64, 301.35),
        -- Sandy Shores Town
        vec4(1686.51, 3602.66, 34.78, 278.72),
        vec4(1703.32, 3602.75, 34.78, 211.85),
        vec4(1714.68, 3598.08, 34.62, 129.67),
        vec4(1838.47, 3640.95, 34.01, 282.18),
        vec4(1852.3, 3670.69, 33.81, 210.89),
        vec4(1885.2, 3711.38, 32.63, 298.16),
        vec4(1880.91, 3716.43, 32.18, 117.27),
        vec4(1891.94, 3725.0, 31.94, 28.5),
        vec4(1921.17, 3749.92, 31.75, 50.58),
        vec4(1966.69, 3769.7, 31.55, 65.87),
        vec4(1952.91, 3761.14, 31.56, 30.2),
        vec4(1963.25, 3755.31, 31.59, 253.9),
        vec4(1981.36, 3787.14, 31.54, 168.41),
        vec4(1976.38, 3776.3, 31.54, 225.7),
        vec4(2007.3, 3792.76, 31.54, 299.46),
        vec4(1978.86, 3828.32, 31.74, 301.05),
        vec4(1978.01, 3807.21, 31.54, 123.42),
        vec4(1909.69, 3819.27, 31.59, 27.35),
        vec4(1891.98, 3796.18, 32.14, 118.93),
        vec4(1883.95, 3768.73, 32.23, 29.79),
        vec4(1853.83, 3753.14, 32.48, 33.66),
        vec4(1869.66, 3782.47, 32.21, 287.95),
        vec4(1864.77, 3796.15, 32.23, 28.51),
        vec4(1839.35, 3740.99, 33.19, 30.78),
        vec4(1824.62, 3717.04, 33.63, 298.23),
        vec4(1770.02, 3757.57, 33.9, 296.52),
        vec4(1761.98, 3791.53, 33.31, 31.89),
        vec4(1917.81, 3866.81, 32.58, 119.14),
        vec4(1918.72, 3950.38, 32.44, 240.79),
        vec4(1847.18, 3923.1, 33.07, 282.33),
        vec4(1804.93, 3932.93, 33.75, 99.2),
        vec4(1774.97, 3926.74, 34.48, 105.63),
        vec4(1720.01, 3898.25, 35.05, 126.32),
        vec4(1691.43, 3902.09, 34.06, 248.88),
        vec4(1670.38, 3821.9, 34.26, 321.69),
        vec4(1737.01, 3794.02, 34.37, 299.74),
        vec4(1670.18, 3744.96, 34.59, 211.63),
        vec4(1689.16, 3734.59, 34.05, 117.48),
        vec4(1660.0, 3741.39, 33.78, 30.57),
        vec4(1651.2, 3735.38, 34.51, 28.84),
        vec4(1567.19, 3795.89, 33.51, 339.1),
        vec4(1463.33, 3740.97, 32.91, 170.98),
        vec4(1459.37, 3718.24, 33.28, 277.64),
        vec4(1431.59, 3649.84, 34.32, 288.71),
        vec4(1402.49, 3597.78, 34.23, 111.36),
        vec4(1366.41, 3620.84, 34.25, 110.53),
        vec4(1287.22, 3627.47, 32.39, 248.4),
        -- Grapeseed
        vec4(1944.24, 4628.57, 39.81, 342.65),
        vec4(1956.84, 4651.27, 40.1, 287.59),
        vec4(1975.41, 4635.97, 40.28, 219.34),
        vec4(1903.96, 4921.46, 48.16, 336.64),
        vec4(2009.21, 4985.72, 40.63, 41.62),
        vec4(2303.7, 4881.57, 41.17, 358.79),
        vec4(2327.74, 4897.01, 41.17, 224.3),
        vec4(2414.39, 4991.38, 45.58, 314.67),
        vec4(2452.04, 4996.71, 45.36, 15.12),
        vec4(2487.52, 4960.27, 44.16, 135.93),
        vec4(2565.81, 4685.82, 33.43, 248.24),
        vec4(2155.27, 4791.26, 40.4, 13.04),
        vec4(2111.84, 4768.83, 40.54, 102.94),
        vec4(2028.35, 4728.36, 40.98, 23.65),
        vec4(1734.58, 4635.49, 42.74, 118.62),
        vec4(1681.17, 4681.87, 42.48, 65.72),
        vec4(1729.39, 4664.68, 43.02, 93.25),
        vec4(1728.19, 4719.13, 41.49, 357.73),
        vec4(1703.6, 4738.22, 41.53, 72.8),
        vec4(1668.79, 4750.64, 41.3, 109.22),
        vec4(1691.21, 4784.87, 41.34, 88.25),
        vec4(1694.99, 4834.55, 41.37, 315.08),
        vec4(1705.39, 4827.9, 41.44, 181.86),
        vec4(1644.04, 4842.41, 41.45, 354.28),
        vec4(1640.7, 4863.07, 41.45, 331.39),
        vec4(1685.57, 4888.61, 41.45, 273.19),
        vec4(1668.8, 4972.36, 41.7, 314.29),
        vec4(1704.14, 4912.87, 41.5, 256.66),
        vec4(1687.36, 4915.65, 41.5, 331.1),
        vec4(1717.46, 4932.15, 41.5, 3.64),
        vec4(1973.97, 5167.53, 47.06, 310.33),
        vec4(1977.27, 5180.38, 47.28, 102.82),
        vec4(2240.57, 5153.04, 56.61, 231.55),
        -- Grapeseed North
        vec4(2583.1, 5060.78, 44.34, 194.22),
        vec4(2196.68, 5607.11, 52.92, 155.97),
        vec4(2198.07, 5560.3, 53.26, 329.92),
        vec4(1683.12, 6436.92, 31.62, 192.93),
        vec4(1585.63, 6447.67, 24.58, 154.04),
        vec4(1720.86, 3714.49, 33.21, 18.48),
        vec4(1852.84, 3768.99, 31.94, 119.96),
        vec4(1959.16, 3773.37, 31.2, 91.73),
        vec4(1630.03, 3558.89, 34.17, 299.78),
    },

    angryPeds = {
        chance1 = 55,
        chance2 = 35,
        models = {
            'g_m_y_mexgoon_01', 
            'g_m_y_lost_01', 
            'a_m_m_hillbilly_01', 
            'a_m_m_skater_01',
            "a_m_y_soucent_04",
            "s_f_y_sweatshop_01",
            "ig_car3guy2",
            "ig_djgeneric_01",
            "a_m_y_beach_02",
            "mp_m_waremech_01",
        },
        weapons = { 
            "weapon_bat",
            "weapon_hammer",
            "weapon_golfclub",
            "weapon_bottle",
            "weapon_crowbar",
            "weapon_wrench",
            "weapon_poolcue", 
        },
    },

    reward = {
        money = { account = 'cash', min = 450, max = 950 },
        rep = { metadata = 'rtv_towing_rep', min = 25, max = 45 },
        materialMultiplier = 1.0,
        materials = {
            { item = 'carparts', min = 40, max = 100, chance = 80 },

        },
        rare = { item = 'md_metalcan', chance = 2 },
        progression = {
            { rep = 0, multiplier = 1.0 },
            { rep = 720, multiplier = 1.25 },
            { rep = 1830, multiplier = 1.45 },
            { rep = 2540, multiplier = 1.55 },
            { rep = 5600, multiplier = 1.75 },
            { rep = 9200, multiplier = 2.0 },
        }
    }
}


--============================================================
-- REPO PROGRESSIE / SKILL TREE
--============================================================

Config.RepoProgression = {
    enabled = true,
    tableName = 'rtv_towing_progression',

    -- XP instellingen
    baseXp = 100,
    levelBase = 125,
    levelCurve = 1.25,
    maxLevel = 25,

    -- Bonus XP
    fastBonusSeconds = 600,
    fastBonusXp = 25,
    premiumBonusXp = 35,

    -- Premium contract bonus
    premiumMoneyMultiplier = 1.15,
    premiumMaterialBonus = 10,

    -- Items die meetellen als carparts/craftparts in stats en skill bonussen.
    materialItems = {
        carparts = true,
        craftparts = true,
    },

    skills = {
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
}

--============================================================
-- CRAFTING
--============================================================

Config.Crafting = {
    enabled = false, 
    serverDistance = 5.0,

    locations = {
    {
        id = 'towyard_crafting',
        label = 'Tow Crafting',
        coords = vec3(1176.35, 2634.95, 38.45),
        radius = 1.6,
        job = 'sandytow',
        minGrade = 4,
        requireDuty = true,
        icon = 'fa-solid fa-screwdriver-wrench',
        targetLabel = 'Open Tow Crafting',
    },
},

    recipes = {
        rtv_towrope = {
            label = 'Tow Rope', description = 'Craft een tow rope.', duration = 5000,
            output = { item = 'rtv_towrope', count = 1 },
            ingredients = { { item = 'craftparts', count = 2 }}
        },
        rtv_winch = {
            label = 'Winch', description = 'Craft een winch.', duration = 5000,
            output = { item = 'rtv_winch', count = 1 },
            ingredients = { { item = 'craftparts', count = 2 }}
        },
        duct_tape = {
            label = 'Duct Tape', description = 'Craft duct tape met aluminium en plastic.', duration = 5000,
            output = { item = 'duct_tape', count = 1 },
            ingredients = { { item = 'craftparts', count = 2 }}
        },
        tyre_replacement = {
            label = 'Tyre Replacement', description = 'Craft een tyre replacement.', duration = 5000,
            output = { item = 'tyre_replacement', count = 1 },
            ingredients = { { item = 'craftparts', count = 2 }}
        },
        spark_plug = {
            label = 'Spark Plug', description = 'Craft een spark plug.', duration = 5000,
            output = { item = 'spark_plug', count = 1 },
            ingredients = { { item = 'craftparts', count = 2 }}
        },
        ev_battery = {
            label = 'EV Battery', description = 'Craft een EV battery.', duration = 6000,
            output = { item = 'ev_battery', count = 1 },
            ingredients = { { item = 'craftparts', count = 2 }}
        },
        suspension_parts = {
            label = 'Suspension Parts', description = 'Craft suspension parts.', duration = 6000,
            output = { item = 'suspension_parts', count = 1 },
            ingredients = { { item = 'craftparts', count = 2 }}
        },
        craftparts = {
            label = 'Craftparts', description = 'Craft een craftpart.', duration = 7000,
            output = { item = 'craftparts', count = 1 },
            ingredients = { { item = 'carparts', count = 4 }}
        },
        air_repair_kit = {
            label = 'Air Repair Kit', description = 'Craft een air repair kit.', duration = 9000,
            output = { item = 'air_repair_kit', count = 1 },
            ingredients = { { item = 'craftparts', count = 6}}
        },
        boat_paintkit = {
            label = 'Boat Paintkit', description = 'Craft een boat paintkit.', duration = 7500,
            output = { item = 'boat_paintkit', count = 1 },
           ingredients = { { item = 'craftparts', count = 6 }}
        },
        air_paintkit = {
            label = 'Air Paintkit', description = 'Craft een air paintkit.', duration = 7500,
            output = { item = 'air_paintkit', count = 1 },
           ingredients = { { item = 'craftparts', count = 4 }}
        },
        boat_repair_kit = {
            label = 'Boat Repair Kit', description = 'Craft een boat repair kit.', duration = 9000,
            output = { item = 'boat_repair_kit', count = 1 },
            ingredients = { { item = 'craftparts', count = 4 }}
        },
        WEAPON_BATTLEAXE = {
            label = 'Battle Axe', description = 'Craft een battle axe.', duration = 10000,
            output = { item = 'WEAPON_BATTLEAXE', count = 1 },
            ingredients = { { item = 'craftparts', count = 10 }}
        },
        WEAPON_DAGGER = {
            label = 'Dagger', description = 'Craft een dagger.', duration = 10000,
            output = { item = 'WEAPON_DAGGER', count = 1 },
            ingredients = { { item = 'craftparts', count = 8 }}
        },
        stancing_kit = {
            label = 'Stancing Kit', description = 'Craft een stancing kit.', duration = 8500,
            output = { item = 'stancing_kit', count = 1 },
            ingredients = { { item = 'craftparts', count = 5 }}
        },
    }
}

