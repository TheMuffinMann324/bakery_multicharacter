-- Small helpers shared by the client and the server.
Utils = {}

local RES = GetCurrentResourceName()

-- Event / callback names belong to this resource, even after a folder rename.
function Utils.event(name)
    return ('%s:%s'):format(RES, name)
end

function Utils.started(resource)
    return GetResourceState(resource) == 'started'
end

-- Which framework is running. qbx_core is checked first because it also answers to "qb-core".
function Utils.framework()
    local forced = Config.Framework
    if forced and forced ~= 'auto' then return forced end
    if Utils.started('qbx_core') then return 'qbx' end
    if Utils.started('qb-core') then return 'qb' end
    if Utils.started('es_extended') then return 'esx' end
    return nil
end

function Utils.clamp(n, lo, hi)
    if n < lo then return lo end
    if n > hi then return hi end
    return n
end

-- json.decode that never throws and always gives a table.
function Utils.decode(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return {} end
    local ok, out = pcall(json.decode, value)
    return ok and type(out) == 'table' and out or {}
end

-- Which starting-apartment picker new QBCore / QBX characters get, or nil for the spawn map.
--   'qbx_properties'  Config.Spawn.StartingApartment with qbx_properties running
--   'legacy'          qb-apartments / qbx_apartments, which can only show their picker through qb-spawn / qbx_spawn
function Utils.startingApartment()
    if Utils.framework() == 'esx' then return nil end
    if Config.Spawn.StartingApartment and Utils.started('qbx_properties') then return 'qbx_properties' end
    if (Utils.started('qb-apartments') or Utils.started('qbx_apartments'))
        and (Utils.started('qb-spawn') or Utils.started('qbx_spawn')) then
        return 'legacy'
    end
    return nil
end

-- Prints only when Config.Debug is on.
function Utils.debug(...)
    if Config.Debug then print('^5[bakery_multicharacter]^7', ...) end
end
