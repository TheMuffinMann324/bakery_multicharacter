-- Character screen (client): opens the line-up, follows the UI and hands the result to the framework.
local EV = Utils.event

Selection = { active = false }

local data = nil          -- what the server sent when the screen opened
local opening = false
local busy = false        -- a play / create / delete request is running
local uiPayload = nil     -- last 'open' message, resent if the UI loads late

local function characterAt(slot)
    if not data then return nil end
    for _, c in ipairs(data.characters) do
        if c.slot == slot then return c end
    end
    return nil
end

-- Looks stay on the client side of the scene; the UI doesn't need them.
local function forUi(characters)
    local out = {}
    for i, c in ipairs(characters) do
        local copy = {}
        for k, v in pairs(c) do
            if k ~= 'skin' and k ~= 'model' then copy[k] = v end
        end
        out[i] = copy
    end
    return out
end

-- What the backdrop behind the character is told (client/scene.lua adds where the floor is).
local function poster(slot)
    return {
        server = data.server, slot = slot, total = data.slots, empty = characterAt(slot) == nil,
        units = Config.HeightUnits == 'metric' and 'metric' or 'imperial',
    }
end

local function fadeOut(ms)
    DoScreenFadeOut(ms)
    local deadline = GetGameTimer() + ms + 1000
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(0) end
end

-- ------------------------------------------------------------
-- Open / close
-- ------------------------------------------------------------
function Selection.open()
    if Selection.active or opening then return end
    opening = true
    Intro.cancel()
    fadeOut(300)

    local res
    for _ = 1, 20 do
        res = lib.callback.await(EV('enter'), false)
        if res and (res.ok or res.error == 'loaded') then break end
        Wait(1500)   -- the server may still be starting
    end
    if not res or not res.ok then
        if not res or res.error ~= 'loaded' then
            print('^1[bakery_multicharacter] The character screen could not be opened: ' .. tostring(res and res.error or 'no answer from the server') .. '^7')
        end
        opening = false
        DoScreenFadeIn(300)
        return
    end

    data = res
    Selection.active = true
    Scene.start(data.characters, data.slots)

    uiPayload = {
        characters = forUi(data.characters), slots = data.slots, server = data.server, framework = data.framework,
        allowDelete = data.allowDelete, deleteHold = data.deleteHold, rules = data.rules, now = data.now,
        logo = Nui.logo(),
    }
    Nui.send('open', uiPayload)

    -- Shutting the loading screen down clears NUI focus, so focus is taken after it.
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    Nui.focus(true)
    Wait(400)
    DoScreenFadeIn(800)
    opening = false

    -- Keep the mouse on the UI while the screen is open: the framework, spawnmanager or another
    -- resource starting up can call SetNuiFocus(false) and leave the player unable to click.
    CreateThread(function()
        while Selection.active do
            if not IsNuiFocused() then Nui.focus(true) end
            Wait(100)
        end
    end)
end

local function close()
    Selection.active = false
    uiPayload = nil
    Nui.focus(false)
    Nui.send('close')
    Scene.stop()
end

-- ------------------------------------------------------------
-- UI callbacks
-- ------------------------------------------------------------

-- The UI finished loading; if the screen opened before that, send it again.
Nui.on('ready', function()
    if Selection.active and uiPayload then
        Nui.send('open', uiPayload)
        Nui.focus(true)
    end
    return { ok = true, logo = Nui.logo() }
end)

Nui.on('hover', function(body)
    Scene.hover(tonumber(body.slot))
end)

-- A slot was picked: camera onto it, backdrop behind it. The UI's shutter is closed while this runs;
-- the short wait lets the new shot render before the UI opens it again.
Nui.on('select', function(body)
    local slot = tonumber(body.slot)
    if not Selection.active or not slot or slot < 1 or slot > data.slots then return { ok = false } end
    Scene.detail(slot, poster(slot))
    Wait(60)
end)

Nui.on('back', function()
    if not Selection.active then return end
    Scene.lineup()
    Wait(60)
end)

-- Switching gender on the creation form swaps the ped.
local previewGender = {}
Nui.on('preview', function(body)
    local slot = tonumber(body.slot)
    if not Selection.active or not slot or characterAt(slot) then return end
    local gender = body.gender == 'female' and 'female' or 'male'
    if (previewGender[slot] or 'male') ~= gender then
        previewGender[slot] = gender
        Scene.setSlot(slot, nil, gender)
    end
end)

-- Shared by play and create: fade out, ask the server, then let the framework spawn the player.
-- intro: { firstName, lastName, isNew } for the introduction once the character is in the world.
local function load(callback, payload, after, intro)
    if not Selection.active or busy then return { ok = false, error = 'Not available right now.' } end
    busy = true
    fadeOut(500)
    Bridge.expect()
    local res = lib.callback.await(EV(callback), false, payload)
    if not res or not res.ok then
        Bridge.cancel()
        busy = false
        DoScreenFadeIn(400)
        return res or { ok = false, error = 'No answer from the server.' }
    end

    close()
    previewGender = {}
    CreateThread(function()
        local ok, entered = pcall(after, res)
        busy = false
        if not ok then print(('^1[bakery_multicharacter] spawn failed: %s^7'):format(entered)) end
        if not ok or entered == false then
            -- the framework never loaded the character: back to the character screen
            Selection.open()
        elseif intro then
            Intro.play(intro, intro.isNew)
        end
    end)
    return { ok = true }
end

Nui.on('play', function(body)
    local slot = tonumber(body.slot)
    local character = slot and characterAt(slot)
    if not character then return { ok = false, error = 'That slot is empty.' } end
    return load('play', slot, function(res) return Bridge.enter(res, character) end,
        { firstName = character.firstName, lastName = character.lastName })
end)

Nui.on('create', function(body)
    return load('create', body, function(res) return Bridge.created(res) end,
        { firstName = body.firstName, lastName = body.lastName, isNew = true })
end)

Nui.on('delete', function(body)
    local slot = tonumber(body.slot)
    if not Selection.active or busy or not slot then return { ok = false, error = 'Not available right now.' } end
    busy = true
    local res = lib.callback.await(EV('delete'), false, slot)
    busy = false
    if not res then return { ok = false, error = 'No answer from the server.' } end

    if res.characters then
        data.characters = res.characters
        data.slots = res.slots or data.slots
        res.characters = forUi(res.characters)
    end
    if res.ok then Scene.relayout(data.characters, data.slots) end   -- the UI then shutters back to the line-up
    return res
end)

-- ------------------------------------------------------------
-- When the screen opens
-- ------------------------------------------------------------
RegisterNetEvent(EV('open'), function()
    Selection.open()
end)

-- Other resources log players out through these.
RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
    if Bridge.name() == 'qb' then Selection.open() end
end)
RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
    if Bridge.name() == 'qbx' then Selection.open() end
end)

-- First join.
CreateThread(function()
    pcall(function() exports.spawnmanager:setAutoSpawn(false) end)
    while not NetworkIsSessionStarted() or not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    Wait(1000)   -- give the framework's client a moment to start
    if Bridge.isLoggedIn() then return end
    Selection.open()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() or not Selection.active then return end
    Nui.focus(false)
    PlayerState.restore()
    DoScreenFadeIn(0)
end)
