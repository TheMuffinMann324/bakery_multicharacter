-- Framework bridge (server). Each framework file fills in Frameworks.<name> with the same functions:
--
--   init()                        called once when the resource starts
--   isLoaded(src)                 is this player already playing a character?
--   characters(src)               list of characters (see the shape below)
--   login(src, character)         load an existing character, true on success
--   create(src, slot, data)       make a new character and load it, true on success
--   delete(src, character)        remove a character and everything it owns
--   logout(src)                   unload the character (back to the character screen)
--   position(src)                 last saved position of the loaded character (or nil)
--
-- Character shape sent to the UI:
--   { slot, id, firstName, lastName, dob = 'YYYY-MM-DD', gender = 'male'|'female', nationality, phone,
--     height, cash, bank, job, grade, gang, lastPlayed = unix seconds, disabled, model, skin }
--
-- data given to create(): { firstName, lastName, dob = { d, m, y }, gender, nationality, height }
Frameworks = {}

BridgeUtil = {}

-- oxmysql gives timestamps as milliseconds; some setups give a string. Returns unix seconds or nil.
function BridgeUtil.unix(value)
    if type(value) == 'number' then
        return value > 100000000000 and math.floor(value / 1000) or math.floor(value)
    end
    if type(value) == 'string' then
        local y, mo, d, h, mi, s = value:match('(%d+)-(%d+)-(%d+)[ T](%d+):(%d+):(%d+)')
        if y then
            return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) })
        end
    end
    return nil
end

-- Any saved date of birth -> 'YYYY-MM-DD'. order is the saved format, e.g. 'DD/MM/YYYY'.
function BridgeUtil.isoDate(value, order)
    if type(value) ~= 'string' then return nil end
    local a, b, c = value:match('(%d+)%D+(%d+)%D+(%d+)')
    if not a then return nil end
    local y, m, d
    if #a == 4 then y, m, d = a, b, c
    elseif order and order:upper():sub(1, 2) == 'MM' then m, d, y = a, b, c
    else d, m, y = a, b, c end
    return ('%04d-%02d-%02d'):format(tonumber(y), tonumber(m), tonumber(d))
end

-- { d, m, y } -> text in the given format ('YYYY-MM-DD', 'DD/MM/YYYY', 'MM/DD/YYYY' ...).
function BridgeUtil.formatDate(dob, format)
    local out = format:upper()
    out = out:gsub('YYYY', ('%04d'):format(dob.y))
    out = out:gsub('MM', ('%02d'):format(dob.m))
    out = out:gsub('DD', ('%02d'):format(dob.d))
    return out
end

-- Waits until fn() gives something, up to timeout ms.
function BridgeUtil.waitFor(fn, timeout)
    local deadline = GetGameTimer() + (timeout or 10000)
    while GetGameTimer() < deadline do
        local value = fn()
        if value then return value end
        Wait(50)
    end
    return nil
end
