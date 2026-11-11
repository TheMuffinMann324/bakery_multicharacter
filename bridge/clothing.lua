-- Clothing bridge (client): opens the character creator for a brand-new character and waits until the
-- player has finished it, so nothing else (the intro) starts on top of it.
--
-- Supported: illenium-appearance, qb-clothing (QBCore / QBX). On ESX the creator opens through
-- esx_skin:openSaveableMenu, which skinchanger / esx_skin and illenium-appearance all answer.
Clothing = {}

local MALE, FEMALE = `mp_m_freemode_01`, `mp_f_freemode_01`
local OPEN_TIMEOUT = 6000          -- ms to wait for a creator to appear before trying another way
local MAX_MS = 60 * 60000          -- nobody spends an hour in the creator; never wait forever

-- Which creator is running, or nil.
function Clothing.name()
    if Utils.started('illenium-appearance') then return 'illenium-appearance' end
    if Utils.started('qb-clothing') then return 'qb-clothing' end
    if Utils.started('fivem-appearance') then return 'fivem-appearance' end
    if Utils.started('skinchanger') or Utils.started('esx_skin') then return 'esx_skin' end
    return nil
end

-- A creator is on screen while it has the mouse or its own camera.
local function menuOpen()
    return IsNuiFocused() or GetRenderingCam() ~= -1
end

local function waitOpen(timeout)
    local deadline = GetGameTimer() + timeout
    while GetGameTimer() < deadline do
        if menuOpen() then return true end
        Wait(100)
    end
    return false
end

-- Until the creator has been closed for a moment (some close and reopen between tabs or on save).
local function waitClosed()
    local deadline = GetGameTimer() + MAX_MS
    local closedFor = 0
    while GetGameTimer() < deadline do
        if menuOpen() then closedFor = 0 else closedFor = closedFor + 100 end
        if closedFor >= 1500 then return end
        Wait(100)
    end
end

function Clothing.isOpen()
    return menuOpen()
end

-- Freemode model for the character's gender, so they are never left as the default story character.
function Clothing.setModel(gender)
    Appearance.setPlayerModel(gender == 'female' and FEMALE or MALE)
end

-- illenium-appearance / fivem-appearance opened straight through their export. illenium's result is
-- saved the way illenium saves it itself.
local function openDirect(name, gender)
    Clothing.setModel(gender)
    local done = false
    exports[name]:startPlayerCustomization(function(appearance)
        if appearance and name == 'illenium-appearance' then TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance) end
        done = true
    end, { ped = false, headBlend = true, faceFeatures = true, headOverlays = true, components = true, props = true, tattoos = false })
    local deadline = GetGameTimer() + MAX_MS
    while not done and GetGameTimer() < deadline do Wait(200) end
end

-- QBCore / QBX: open the creator for a new character and wait until it is done.
-- gender: 'male' | 'female'. Returns once the player is back in the world.
function Clothing.firstCharacter(gender)
    local name = Clothing.name()
    Utils.debug('clothing: first character with', name or 'nothing')
    if not name then return end

    -- illenium-appearance and qb-clothing both answer this; it uses their own new-character settings
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    if waitOpen(OPEN_TIMEOUT) then
        waitClosed()
        return
    end

    -- nothing opened (an older build, or a framework hook that never ran): open it ourselves
    if name == 'illenium-appearance' or name == 'fivem-appearance' then
        print(('^3[bakery_multicharacter] %s did not open on qb-clothes:client:CreateFirstCharacter, opening it directly.^7'):format(name))
        openDirect(name, gender)
        waitClosed()
    else
        print(('^1[bakery_multicharacter] %s did not open its character creator for the new character.^7'):format(name))
    end
end

-- Another resource opens the creator (the starting-apartment flow): wait for it to show up and be done.
-- Menus that open one after another (apartment picker, then the creator) all count.
function Clothing.waitForCreator(firstTimeout)
    if not menuOpen() and not waitOpen(firstTimeout) then return end
    -- the gap between the apartment picker closing and the creator opening can be several seconds
    repeat waitClosed() until not waitOpen(10000)
end

-- ESX: esx_skin:openSaveableMenu with submit / cancel callbacks. Returns once the player is done.
function Clothing.firstCharacterEsx(gender)
    local name = Clothing.name()
    if not name then return end
    local done = false
    local function finish() done = true end

    if name == 'illenium-appearance' or name == 'fivem-appearance' then
        TriggerEvent('esx_skin:openSaveableMenu', finish, finish)
    else
        TriggerEvent('skinchanger:loadSkin', { sex = gender == 'female' and 1 or 0 }, function()
            TriggerEvent('esx_skin:openSaveableMenu', finish, finish)
        end)
    end

    -- some versions never call back: fall back to watching the menu itself
    if not waitOpen(OPEN_TIMEOUT) and not done then
        print(('^1[bakery_multicharacter] %s did not open its character creator for the new character.^7'):format(name))
        return
    end
    local deadline = GetGameTimer() + MAX_MS
    while not done and GetGameTimer() < deadline do
        if not menuOpen() then
            waitClosed()
            return
        end
        Wait(200)
    end
end
