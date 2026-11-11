-- Character screen (server): lists characters and hands play / create / delete to the framework.
local EV = Utils.event
local Bridge = nil
local frameworkName = nil

-- Players currently on the character screen: [src] = { bySlot = { [slot] = character }, slots = n, busy = bool }
local sessions = {}
local awaitingApartment = {}   -- [src] = true: new character choosing a qbx_properties starting apartment
local lastEnter = {}           -- [src] = GetGameTimer() of the last 'enter' request (it reads the database)

-- Rules for new characters.
local RULES = {
    MinAge = 18, MaxAge = 90,
    NameMin = 2, NameMax = 16,                -- letters per name
    DefaultNationality = 'American',          -- QBCore / QBX
    Height = { min = 140, max = 210 },        -- ESX (cm)
}
local DELETE_HOLD = 1.5        -- seconds the delete button has to be held
local BUCKET_OFFSET = 5000     -- each player picks their character in their own routing bucket
local ENTER_COOLDOWN = 1000    -- ms between 'enter' requests per player

CreateThread(function()
    frameworkName = Utils.framework()
    Bridge = frameworkName and Frameworks[frameworkName]
    if not Bridge then
        print('^1[bakery_multicharacter] No framework found. Start qbx_core, qb-core or es_extended before this resource (or set Config.Framework).^7')
        return
    end
    Bridge.init()
    Utils.debug('framework: ' .. frameworkName)
end)

local function ready()
    return Bridge ~= nil
end

local function slotCount(src)
    local n = Config.Slots
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if Config.PlayerSlots[id] then n = Config.PlayerSlots[id] end
    end
    return math.max(1, math.floor(tonumber(n) or 1))
end

-- Characters keyed by slot. Nobody loses a character to a low slot count: the screen grows to fit them.
local function fetch(src)
    local list = Bridge.characters(src)
    local slots = math.max(slotCount(src), #list)
    for _, c in ipairs(list) do
        if c.slot and c.slot > slots and c.slot <= 32 then slots = c.slot end
    end

    local bySlot, homeless = {}, {}
    table.sort(list, function(a, b) return (a.slot or 999) < (b.slot or 999) end)
    for _, c in ipairs(list) do
        if c.slot and c.slot >= 1 and c.slot <= slots and not bySlot[c.slot] then
            bySlot[c.slot] = c
        else
            homeless[#homeless + 1] = c
        end
    end
    for _, c in ipairs(homeless) do
        for slot = 1, slots do
            if not bySlot[slot] then
                c.slot = slot
                bySlot[slot] = c
                break
            end
        end
    end

    local out = {}
    for slot = 1, slots do
        if bySlot[slot] then out[#out + 1] = bySlot[slot] end
    end
    return out, bySlot, slots
end

local function enterBucket(src)
    local bucket = BUCKET_OFFSET + src
    SetPlayerRoutingBucket(src, bucket)
    SetRoutingBucketPopulationEnabled(bucket, false)
end

local function leaveBucket(src)
    SetPlayerRoutingBucket(src, 0)
end

local function fail(message)
    return { ok = false, error = message }
end

-- ------------------------------------------------------------
-- Opening the screen
-- ------------------------------------------------------------
lib.callback.register(EV('enter'), function(src)
    if not ready() then return fail('The server is still starting. Try again in a moment.') end
    if Bridge.isLoaded(src) then return fail('loaded') end
    local now = GetGameTimer()
    if lastEnter[src] and now - lastEnter[src] < ENTER_COOLDOWN then return fail('Slow down.') end
    lastEnter[src] = now

    local characters, bySlot, slots = fetch(src)
    sessions[src] = { bySlot = bySlot, slots = slots, busy = false }
    enterBucket(src)

    return {
        ok = true,
        characters = characters,
        slots = slots,
        server = Config.ServerName,
        framework = frameworkName,
        allowDelete = Config.AllowDelete,
        deleteHold = DELETE_HOLD,
        now = os.time(),
        rules = {
            minAge = RULES.MinAge,
            maxAge = RULES.MaxAge,
            nameMin = RULES.NameMin,
            nameMax = RULES.NameMax,
            nationality = frameworkName ~= 'esx',
            defaultNationality = RULES.DefaultNationality,
            height = frameworkName == 'esx' and RULES.Height or false,
        },
    }
end)

-- One request at a time per player, and only while they are on the character screen.
local function begin(src)
    local session = sessions[src]
    if not ready() or not session or session.busy then return nil end
    if Bridge.isLoaded(src) then
        sessions[src] = nil
        return nil
    end
    session.busy = true
    return session
end

-- ------------------------------------------------------------
-- Play
-- ------------------------------------------------------------
lib.callback.register(EV('play'), function(src, slot)
    local session = begin(src)
    if not session then return fail('Not available right now.') end

    local character = session.bySlot[tonumber(slot) or -1]
    if not character then
        session.busy = false
        return fail('That slot is empty.')
    end
    if character.disabled then
        session.busy = false
        return fail('This character is disabled.')
    end

    leaveBucket(src)
    local ok, loaded = pcall(Bridge.login, src, character)
    if not ok or not loaded then
        if not ok then print(('^1[bakery_multicharacter] login failed: %s^7'):format(loaded)) end
        enterBucket(src)
        session.busy = false
        return fail('Could not load this character.')
    end

    sessions[src] = nil
    Utils.debug(('%s loaded character %s'):format(GetPlayerName(src) or src, character.id))
    return { ok = true, id = character.id, position = Bridge.position(src), homes = Housing.list(src, Bridge.citizenId(src)) }
end)

-- ------------------------------------------------------------
-- Create
-- ------------------------------------------------------------
-- Whole number or nil (numbers from the UI can arrive as floats or text).
local function int(value)
    local n = tonumber(value)
    if not n or n % 1 ~= 0 then return nil end
    return math.floor(n)
end

local function utf8len(s)
    return utf8.len(s) or #s
end

-- Letters only (any alphabet), plus spaces, hyphens and apostrophes inside the name.
local function cleanName(value)
    if type(value) ~= 'string' then return nil end
    local name = value:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    local len = utf8len(name)
    if len < RULES.NameMin or len > RULES.NameMax then return nil end
    local letters = name:gsub("[ '%-]", '')
    if letters == '' or letters:find('[%d%p%c]') then return nil end
    if name:find("^[ '%-]") or name:find("[ '%-]$") then return nil end
    return name:sub(1, 1):upper() .. name:sub(2)
end

local function cleanDob(dob)
    if type(dob) ~= 'table' then return nil end
    local d, m, y = int(dob.d), int(dob.m), int(dob.y)
    if not d or not m or not y or y < 1900 or y > 2100 or m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    -- reject days that don't exist (31 April, 30 February)
    local check = os.date('*t', os.time({ year = y, month = m, day = d, hour = 12 }))
    if check.day ~= d or check.month ~= m then return nil end
    local today = os.date('*t')
    local age = today.year - y
    if today.month < m or (today.month == m and today.day < d) then age = age - 1 end
    if age < RULES.MinAge or age > RULES.MaxAge then return nil end
    return { d = d, m = m, y = y }
end

lib.callback.register(EV('create'), function(src, payload)
    local session = begin(src)
    if not session then return fail('Not available right now.') end
    local function stop(message)
        session.busy = false
        return fail(message)
    end

    if type(payload) ~= 'table' then return stop('Bad request.') end
    local slot = int(payload.slot)
    if not slot or slot < 1 or slot > session.slots then return stop('That slot does not exist.') end
    if session.bySlot[slot] then return stop('That slot is taken.') end

    local rules = RULES   -- shorter below
    local firstName, lastName = cleanName(payload.firstName), cleanName(payload.lastName)
    if not firstName or not lastName then
        return stop(('Names are %d-%d letters, without numbers or symbols.'):format(rules.NameMin, rules.NameMax))
    end
    local dob = cleanDob(payload.dob)
    if not dob then
        return stop(('Enter a real date of birth. Characters are %d-%d years old.'):format(rules.MinAge, rules.MaxAge))
    end

    local data = {
        firstName = firstName,
        lastName = lastName,
        dob = dob,
        gender = payload.gender == 'female' and 'female' or 'male',
    }
    if frameworkName == 'esx' then
        local height = int(payload.height)
        if not height or height < rules.Height.min or height > rules.Height.max then
            return stop(('Height is %d-%d cm.'):format(rules.Height.min, rules.Height.max))
        end
        data.height = height
    else
        data.nationality = cleanName(payload.nationality) or rules.DefaultNationality
    end

    -- Recheck against the database: the slot may have been filled from another session.
    local _, bySlot = fetch(src)
    if bySlot[slot] then
        session.bySlot = bySlot
        return stop('That slot is taken.')
    end

    -- qb-apartments' starting apartment keeps them in their own bucket and moves them back itself
    if Utils.startingApartment() ~= 'legacy' then leaveBucket(src) end

    local ok, created = pcall(Bridge.create, src, slot, data)
    if not ok or not created then
        if not ok then print(('^1[bakery_multicharacter] create failed: %s^7'):format(created)) end
        enterBucket(src)
        return stop('Could not create this character.')
    end

    sessions[src] = nil
    Utils.debug(('%s created %s %s (slot %d)'):format(GetPlayerName(src) or src, firstName, lastName, slot))
    if Utils.startingApartment() == 'qbx_properties' then awaitingApartment[src] = true end
    return {
        ok = true,
        slot = slot,
        id = Bridge.citizenId(src),
        gender = data.gender,
        charinfo = { firstname = firstName, lastname = lastName, nationality = data.nationality, gender = data.gender == 'female' and 1 or 0 },
    }
end)

-- ------------------------------------------------------------
-- Delete
-- ------------------------------------------------------------
lib.callback.register(EV('delete'), function(src, slot)
    if not Config.AllowDelete then return fail('Deleting characters is turned off.') end
    local session = begin(src)
    if not session then return fail('Not available right now.') end

    local character = session.bySlot[tonumber(slot) or -1]
    if not character then
        session.busy = false
        return fail('That slot is empty.')
    end

    local ok, deleted = pcall(Bridge.delete, src, character)
    if not ok then print(('^1[bakery_multicharacter] delete failed: %s^7'):format(deleted)) end

    local characters, bySlot, slots = fetch(src)
    session.bySlot, session.slots, session.busy = bySlot, slots, false
    if not ok or not deleted or bySlot[character.slot] then
        return { ok = false, error = 'Could not delete this character.', characters = characters, slots = slots }
    end
    Utils.debug(('%s deleted character %s'):format(GetPlayerName(src) or src, character.id))
    return { ok = true, characters = characters, slots = slots }
end)

-- ------------------------------------------------------------
-- Back to the character screen
-- ------------------------------------------------------------
local function logout(src)
    if not ready() or not Bridge.isLoaded(src) then return false end
    Bridge.logout(src)
    SetTimeout(500, function()
        if GetPlayerName(src) then TriggerClientEvent(EV('open'), src) end
    end)
    return true
end

exports('Logout', logout)

if Config.LogoutCommand then
    RegisterCommand(Config.LogoutCommand, function(src)
        if src and src > 0 then logout(src) end
    end, true)
end

-- ------------------------------------------------------------
-- Starting apartment (qbx_properties)
-- ------------------------------------------------------------
-- qbx_properties' picker sends the chosen apartment to its own server. We hear the same event, so our
-- client knows the apartment has been picked and opens the character creator itself, once the player
-- is inside (qbx_properties' own creator call comes too early to work: before the player is loaded).
RegisterNetEvent('qbx_properties:server:apartmentSelect', function()
    local src = source
    if not awaitingApartment[src] then return end
    awaitingApartment[src] = nil
    TriggerClientEvent(EV('apartmentChosen'), src)
end)

AddEventHandler('playerDropped', function()
    awaitingApartment[source], sessions[source], lastEnter[source] = nil, nil, nil
end)
