-- Housing bridge: lets players spawn inside their own house or apartment from the spawn map.
--
-- Each housing script gets one adapter with:
--   list(src, cid)          server: the character's homes, as { id, label, address, coords }
--   enterServer(src, id)    server: put the player inside (scripts that do it server side)
--   enterClient(id)         client: put the local player inside (scripts that do it client side)
--
-- The server lists the homes when a character is picked and only lets the player enter one of those.
-- Not listed here? Add an adapter at the bottom, same shape as the others.
Housing = {}

local EV = Utils.event
local SERVER = IsDuplicityVersion()
local ORDER = { 'rtx_housing', 'nolag_properties', 'rcore_housing', 'kartik-properties', 'vms_housing', 'qs-housing', 'qbx_properties', 'qb-houses' }
local MAX_HOMES = 8
local adapters = {}

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------

-- Any coords a housing script hands back (vector3 / vector4 / { x, y, z, h } / JSON text) -> { x, y, z, w } or nil.
local function toCoords(value, heading)
    if type(value) == 'string' then value = Utils.decode(value) end
    local t = type(value)
    if t ~= 'table' and t ~= 'vector3' and t ~= 'vector4' then return nil end
    local x, y, z = tonumber(value.x), tonumber(value.y), tonumber(value.z)
    if not x or not y or not z or (math.abs(x) < 1.0 and math.abs(y) < 1.0) then return nil end
    local w = tonumber(heading) or (t == 'vector4' and value.w) or tonumber(value.w) or tonumber(value.h) or tonumber(value.heading) or 0.0
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = w + 0.0 }
end

local function call(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        Utils.debug('housing:', result)
        return nil
    end
    return result
end

-- Which housing script is in use, or nil.
function Housing.active()
    local setting = Config.Spawn and Config.Spawn.Homes
    if not setting then return nil end
    if setting ~= 'auto' then
        return adapters[setting] and Utils.started(setting) and setting or nil
    end
    for _, name in ipairs(ORDER) do
        if adapters[name] and Utils.started(name) then return name end
    end
    return nil
end

-- ------------------------------------------------------------
-- Adapters (docs links are in the README)
-- ------------------------------------------------------------

adapters['rtx_housing'] = {
    list = function(src)
        local out = {}
        for key, p in pairs(exports.rtx_housing:GetPlayerOwnedProperties(src) or {}) do
            local id = p.id or p.propertyid or key
            local enter = type(p.enter) == 'table' and p.enter or {}
            local door = toCoords(enter.coords, enter.heading)
            if not door then
                local full = call(function() return exports.rtx_housing:GetPropertyData(id) end) or {}
                local fe = type(full.enter) == 'table' and full.enter or {}
                door = toCoords(fe.coords, fe.heading)
            end
            out[#out + 1] = { id = id, label = p.propertyname or p.adress, address = p.adress, coords = door }
        end
        return out
    end,
    enterServer = function(src, id) exports.rtx_housing:EnterPropertyPlayer(src, tonumber(id) or id) end,
}

adapters['nolag_properties'] = {
    list = function(_, cid)
        local out = {}
        for _, p in ipairs(exports.nolag_properties:GetAllProperties(cid, 'user', true) or {}) do
            out[#out + 1] = { id = p.id, label = p.label, address = p.address, coords = toCoords(p.coords) }
        end
        return out
    end,
    -- false for MLO homes, which have no interior to wrap into: the player stays at the door
    enterClient = function(id) return exports.nolag_properties:WrapIntoProperty(tonumber(id)) end,
}

adapters['rcore_housing'] = {
    list = function(src)
        local out = {}
        for _, p in ipairs(exports.rcore_housing:GetPlayerProperties(src) or {}) do
            local door
            for _, point in ipairs(p.points or {}) do
                if point.type == 'entry' then
                    door = toCoords(point.coords, point.heading)
                    break
                end
            end
            out[#out + 1] = { id = p.id, label = p.name, address = p.address, coords = door or toCoords(p.coords) }
        end
        return out
    end,
    enterServer = function(src, id) exports.rcore_housing:EnterProperty(src, tonumber(id) or id) end,
}

adapters['kartik-properties'] = {
    list = function(_, cid)
        local out = {}
        for _, p in ipairs(exports['kartik-properties']:GetPlayerHousingData(cid) or {}) do
            out[#out + 1] = { id = tonumber(p.houseId) or p.houseId, label = p.label, coords = toCoords(p.coords) }
        end
        return out
    end,
    enterClient = function(id) exports['kartik-properties']:EnterProperty(id, true) end,
}

adapters['vms_housing'] = {
    list = function(src)
        local out = {}
        for _, p in ipairs(exports.vms_housing:GetPlayerProperties(src) or {}) do
            local meta = Utils.decode(p.metadata)
            out[#out + 1] = { id = p.id, label = p.name, address = p.address, coords = toCoords(meta.enter) }
        end
        return out
    end,
    enterServer = function(src, id) exports.vms_housing:EnterProperty(src, id) end,
}

adapters['qs-housing'] = {
    list = function(src, cid)
        local out, seen = {}, {}
        local detailed = call(function() return exports['qs-housing']:GetPlayerPropertiesByIdentifier(cid) end) or {}
        for key, p in pairs(detailed) do
            if type(p) == 'table' then
                local id = p.house or p.name or p.id or key
                local c = type(p.coords) == 'table' and (p.coords.enter or p.coords) or p.coords
                seen[id] = true
                out[#out + 1] = { id = id, label = p.label, address = p.address, coords = toCoords(c) }
            end
        end
        -- names only, for houses the detailed export didn't return
        for _, id in ipairs(call(function() return exports['qs-housing']:GetPlayerHouses(src) end) or {}) do
            if not seen[id] then out[#out + 1] = { id = id, label = tostring(id) } end
        end
        return out
    end,
    enterClient = function(id) exports['qs-housing']:enterHouse(id, false) end,
}

-- qbx_properties has no exports: its `properties` table and the enter event qbx_spawn uses.
-- The event re-checks on its own server that the player owns the property or holds a key.
adapters['qbx_properties'] = {
    list = function(_, cid)
        local rows = call(function()
            return MySQL.query.await(
                'SELECT id, property_name, coords FROM properties WHERE owner = ? OR JSON_CONTAINS(keyholders, JSON_QUOTE(?))',
                { cid, cid })
        end)
        -- older MySQL / MariaDB without JSON_CONTAINS: owned only
        rows = rows or MySQL.query.await('SELECT id, property_name, coords FROM properties WHERE owner = ?', { cid }) or {}
        local out = {}
        for _, row in ipairs(rows) do
            out[#out + 1] = { id = row.id, label = row.property_name, coords = toCoords(row.coords) }
        end
        return out
    end,
    -- isSpawn skips its "standing at the door" distance check
    enterClient = function(id) TriggerServerEvent('qbx_properties:server:enterProperty', { id = tonumber(id) or id, isSpawn = true }) end,
}

adapters['qb-houses'] = {
    list = function(_, cid)
        local out = {}
        local rows = MySQL.query.await([[
            SELECT ph.house, hl.label, hl.coords FROM player_houses ph
            LEFT JOIN houselocations hl ON hl.name = ph.house
            WHERE ph.citizenid = ? OR ph.keyholders LIKE ?
        ]], { cid, ('%%"%s"%%'):format(cid) }) or {}
        for _, row in ipairs(rows) do
            local coords = Utils.decode(row.coords)
            out[#out + 1] = { id = row.house, label = row.label, coords = toCoords(coords.enter) }
        end
        return out
    end,
    -- what qb-spawn does; qb-houses has the house list by now (bridge/qb.lua sends it on login)
    enterClient = function(id) TriggerEvent('qb-houses:client:enterOwnedHouse', id) end,
}

-- ------------------------------------------------------------
-- Server
-- ------------------------------------------------------------
if SERVER then
    local allowed = {}   -- [src] = { adapter, ids = { [tostring(id)] = id } }

    -- The character's homes, for the spawn map. Called once the character is loaded.
    -- Returns { adapter, list = { { id, label, address, coords } } } or nil.
    function Housing.list(src, cid)
        allowed[src] = nil
        local name = Housing.active()
        local adapter = name and adapters[name]
        if not adapter or not cid then return nil end

        local raw = call(adapter.list, src, cid) or {}
        local list, ids = {}, {}
        for _, home in ipairs(raw) do
            if home.id ~= nil and #list < MAX_HOMES and not ids[tostring(home.id)] then
                ids[tostring(home.id)] = home.id
                list[#list + 1] = {
                    id = home.id,
                    label = (home.label and home.label ~= '') and tostring(home.label) or ('Home ' .. #list + 1),
                    address = home.address and tostring(home.address) or nil,
                    coords = home.coords,
                }
            end
        end
        if #list == 0 then return nil end
        allowed[src] = { adapter = name, ids = ids }
        Utils.debug(('housing: %d home(s) from %s for %s'):format(#list, name, src))
        return { adapter = name, list = list }
    end

    -- The client asks to be put inside a home it was offered. Only server-side scripts come through here.
    lib.callback.register(EV('enterHome'), function(src, id)
        local entry = allowed[src]
        allowed[src] = nil
        local realId = entry and entry.ids[tostring(id)]
        local adapter = entry and adapters[entry.adapter]
        if realId == nil or not adapter or not adapter.enterServer then return false end
        local ok, err = pcall(adapter.enterServer, src, realId)
        if not ok then print(('^1[bakery_multicharacter] %s could not put %s inside home %s: %s^7'):format(entry.adapter, src, tostring(realId), err)) end
        return ok
    end)

    AddEventHandler('playerDropped', function()
        allowed[source] = nil
    end)

-- ------------------------------------------------------------
-- Client
-- ------------------------------------------------------------
else
    -- home = { adapter, id }. Called once the player is in the world, still behind the shutter.
    function Housing.enter(home)
        local adapter = home and adapters[home.adapter]
        if not adapter then return false end
        if adapter.enterServer then
            local ok = lib.callback.await(EV('enterHome'), false, home.id)
            Wait(1200)   -- the housing script moves the player and builds the interior
            return ok == true
        end
        if adapter.enterClient then
            local ok, result = pcall(adapter.enterClient, home.id)
            if not ok then print(('^1[bakery_multicharacter] %s could not put you inside: %s^7'):format(home.adapter, result)) end
            Wait(800)
            return ok and result ~= false
        end
        return false
    end
end
