Config = {}

-- ============================================================
-- General
-- ============================================================
Config.ServerName = 'Bakery Roleplay'   -- shown top-left and on the backdrop

-- Your own logo instead of ours: an image link ('https://i.imgur.com/abc.png') or a file in the
-- logo folder ('logo/mylogo.png'). false = default logo.
Config.Logo = false

Config.Slots = 8                        -- character slots per player
Config.PlayerSlots = {                  -- give single players a different number
    --['license:1234567890abcdef'] = 6,
}

Config.AllowDelete = true               -- players can delete their own characters (hold to delete)
Config.LogoutCommand = 'logout'         -- back to the character screen (ace: command.logout), false = off

-- ============================================================
-- Character screen
-- ============================================================
-- Where the line-up stands. Needs flat, open ground (about 4 m behind, 10 m in front).
Config.LineupCoords = vec4(-75.0, -818.9, 326.18, 180.0)   -- Maze Bank roof

Config.HeightUnits = 'imperial'         -- height chart: 'imperial' or 'metric'

-- ============================================================
-- Spawning
-- ============================================================
Config.Intro = true                     -- name, area, time and weather on screen after spawning
Config.WakeUp = true                    -- the character wakes up and gets up after spawning

Config.Spawn = {
    LastLocation = true,                -- offer the spot they logged out at
    FreeSpawn = true,                   -- drag the little guy anywhere on the map to spawn there

    -- Spawn inside their own house / apartment. 'auto' finds your housing script, or name one:
    -- rtx_housing, nolag_properties, rcore_housing, kartik-properties, vms_housing, qs-housing,
    -- qbx_properties, qb-houses. false = off.
    Homes = 'auto',

    -- QBX: new characters pick a starting apartment with qbx_properties, then get the creator.
    -- Also set characters.startingApartment = false in qbx_core/config/client.lua.
    StartingApartment = true,

    -- Places on the map everyone can spawn at.
    Locations = {
        { label = 'Legion Square',    coords = vec4(195.17, -933.77, 30.69, 144.5) },
        { label = 'Mission Row PD',   coords = vec4(428.23, -984.28, 29.76, 3.5) },
        { label = 'Pink Cage Motel',  coords = vec4(327.56, -205.08, 54.08, 163.5) },
        { label = 'LS International', coords = vec4(-1035.71, -2731.87, 13.76, 330.0) },
        { label = 'Sandy Shores',     coords = vec4(1836.47, 3672.36, 34.28, 210.0) },
        { label = 'Paleto Bay',       coords = vec4(80.35, 6424.12, 31.67, 45.5) },
    },
}

-- ============================================================
-- Advanced
-- ============================================================
Config.Framework = 'auto'               -- 'auto', or force 'qbx' / 'qb' / 'esx'

Config.ESX = {                          -- ESX only: how your database stores characters
    Prefix = 'char',                    -- identifiers look like char1:license
    DateFormat = 'DD/MM/YYYY',          -- format of users.dateofbirth
}

Config.Debug = false                    -- extra console messages
