-- Framework bridge (client): what happens after a character is picked or created.
-- By the time these run the screen is faded out and the line-up is gone.
Bridge = {}

local ESX = nil

function Bridge.name()
    return Utils.framework()
end

local function esx()
    if not ESX then ESX = exports.es_extended:getSharedObject() end
    return ESX
end

function Bridge.isLoggedIn()
    local name = Bridge.name()
    if name == 'esx' then
        local ok, loaded = pcall(function() return esx().IsPlayerLoaded() end)
        return ok and loaded == true
    end
    return LocalPlayer.state.isLoggedIn == true
end

-- Stop the server's time / weather sync from fighting the scene's own clock and weather.
function Bridge.pauseWeatherSync(paused)
    if Utils.started('qb-weathersync') then
        TriggerEvent(paused and 'qb-weathersync:client:DisableSync' or 'qb-weathersync:client:EnableSync')
    end
    if Utils.started('cd_easytime') then
        TriggerEvent('cd_easytime:PauseSync', paused)
    end
    if Utils.started('Renewed-Weathersync') then
        LocalPlayer.state.syncWeather = not paused
    end
end

-- ------------------------------------------------------------
-- Shared pieces
-- ------------------------------------------------------------
local function fadeIn(ms)
    ShutdownLoadingScreen()
    Nui.shutter(false)   -- the UI's blades open on the world as it fades in
    DoScreenFadeIn(ms or 600)
end

-- Put the player in the world at coords (x, y, z, w / heading) and give them back control.
local function place(coords)
    local ped = PlayerPedId()
    local heading = coords.w or coords.heading or 0.0
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    FreezeEntityPosition(ped, true)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, heading)
    local deadline = GetGameTimer() + 6000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(50) end
    if IsEntityDead(ped) then NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, true, false) end
    PlayerState.restore()
    SetGameplayCamRelativeHeading(0.0)
end

-- The apartments resource takes it from here. It places the player and fades the screen in itself;
-- the timer only makes sure nobody is left on a black screen, and PlayerState.guard makes sure
-- the player is visible once it is done.
local function handOff()
    Nui.shutter(false)
    PlayerState.restore(true)
    SetTimeout(4000, function()
        if IsScreenFadedOut() then DoScreenFadeIn(500) end
    end)
end

-- Like fadeIn, but the character wakes up off the ground (client/wake.lua). Returns once they are on
-- their feet, so the intro plays after it.
local function wakeIn()
    ShutdownLoadingScreen()
    if not Wake.play() then fadeIn() end
end

local function qbLoadedEvents()
    TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
    TriggerServerEvent('qb-houses:server:SetInsideMeta', 0, false)
    TriggerServerEvent('qb-apartments:server:SetInsideMeta', 0, 0, false)
end

-- ------------------------------------------------------------
-- QBCore / QBX
-- ------------------------------------------------------------
local function qbEnter(_, result, character)
    local spawn = Spawn.choose({ last = result.position, homes = result.homes, firstName = character.firstName, lastName = character.lastName })
    place(spawn)
    qbLoadedEvents()
    if spawn.home then Housing.enter(spawn.home) end
    Wait(300)
    wakeIn()
    return true
end

-- qbx_properties starting apartment: how long after the player is inside the apartment the creator opens.
local CREATOR_DELAY = 1500
local apartmentChosen = false
RegisterNetEvent(Utils.event('apartmentChosen'), function()
    apartmentChosen = true
end)

-- Returns once the character has been made (creator closed), so the intro plays after it, never on top.
local function qbCreated(_, result)
    local apartment = Utils.startingApartment()

    -- qbx_properties: its picker places the player, sets its own camera and fades in. Once an apartment is
    -- chosen, its server puts them inside and opens the character creator. We open nothing ourselves,
    -- only wait for picker -> creator to finish so the intro plays after both.
    if apartment == 'qbx_properties' then
        Clothing.setModel(result.gender)
        apartmentChosen = false
        handOff()
        TriggerEvent('qb-weathersync:client:EnableSync')
        TriggerEvent('apartments:client:setupSpawnUI', { cid = result.slot, citizenid = result.id, charinfo = result.charinfo })

        -- the picker: wait until an apartment has been chosen (our server hears qbx_properties' event)
        local deadline = GetGameTimer() + 30 * 60000
        while not apartmentChosen and GetGameTimer() < deadline do Wait(200) end

        -- qbx_properties moves them inside and fades in; give the interior a moment, then the creator
        local fadeDeadline = GetGameTimer() + 8000
        while not IsScreenFadedIn() and GetGameTimer() < fadeDeadline do Wait(100) end
        Wait(CREATOR_DELAY)
        if IsScreenFadedOut() then DoScreenFadeIn(500) end
        Clothing.setModel(result.gender)   -- in case anything swapped the model while entering

        if Clothing.isOpen() then
            Clothing.waitForCreator(0)     -- something else already opened it: just wait for it
        else
            Clothing.firstCharacter(result.gender)
        end
        return true
    end

    if apartment == 'legacy' then
        handOff()
        TriggerEvent('apartments:client:setupSpawnUI', { cid = result.slot, citizenid = result.id, charinfo = result.charinfo })
        Clothing.waitForCreator(5 * 60000)   -- apartment picker first, then the apartments resource opens the creator
        if IsScreenFadedOut() then DoScreenFadeIn(500) end
        return true
    end

    local info = result.charinfo or {}
    place(Spawn.choose({ firstName = info.firstname, lastName = info.lastname, isNew = true }))
    qbLoadedEvents()
    Wait(300)
    fadeIn()
    TriggerEvent('qb-weathersync:client:EnableSync')
    Wait(500)   -- let the clothing resource pick up the new player data first
    Clothing.firstCharacter(result.gender)
    return true
end

-- ------------------------------------------------------------
-- ESX
-- ------------------------------------------------------------
-- The server asks es_extended to load the character; es_extended answers with esx:playerLoaded.
-- That answer can arrive before our own server callback returns, so Bridge.expect() starts
-- listening first and the spawn runs later, once the line-up has been taken down.
local pending = nil   -- { loaded = { playerData, isNew, skin } } while a character is loading

RegisterNetEvent('esx:playerLoaded', function(playerData, isNew, skin)
    if pending then pending.loaded = { playerData, isNew, skin } end
end)

local function esxSpawn(playerData, isNew, skin, homes)
    local female = playerData.sex == 'f'
    local hasSkin = type(skin) == 'table' and next(skin) ~= nil
    local fresh = isNew or not hasSkin
    local spawn = Spawn.choose({
        last = not isNew and playerData.coords or nil,
        homes = not isNew and homes or nil,
        firstName = playerData.firstName or playerData.firstname, lastName = playerData.lastName or playerData.lastname,
        isNew = isNew,
    })

    if fresh then
        -- first time in the world: default look, then the clothing menu
        Clothing.setModel(female and 'female' or 'male')
        place(spawn)
        Wait(400)
        fadeIn()
        Clothing.firstCharacterEsx(female and 'female' or 'male')
    else
        Appearance.setPlayerModel(Appearance.model({ skin = skin, gender = female and 'female' or 'male' }))
        place(spawn)
        TriggerEvent('skinchanger:loadSkin', skin)
        Wait(400)
        if spawn.home then Housing.enter(spawn.home) end
        wakeIn()
    end

    TriggerServerEvent('esx:onPlayerSpawn')
    TriggerEvent('esx:onPlayerSpawn')
    TriggerEvent('playerSpawned')
    TriggerEvent('esx:restoreLoadout')
end

local function esxEnter(result)
    local job = pending
    if not job then return false end
    local deadline = GetGameTimer() + 20000
    while not job.loaded and GetGameTimer() < deadline do Wait(100) end
    if pending == job then pending = nil end
    if not job.loaded then return false end
    esxSpawn(job.loaded[1], job.loaded[2], job.loaded[3], result and result.homes)
    return true
end

-- ------------------------------------------------------------
-- Entry points used by client/main.lua. Return false to send the player back to the character screen.
-- ------------------------------------------------------------

-- Called right before the server is asked to load or create a character.
function Bridge.expect()
    pending = Bridge.name() == 'esx' and {} or nil
end

-- The server said no.
function Bridge.cancel()
    pending = nil
end

-- result: { id, position } from the server. character: the one that was picked.
function Bridge.enter(result, character)
    local name = Bridge.name()
    if name == 'esx' then return esxEnter(result) end
    return qbEnter(name, result, character)
end

-- result: { id, slot, gender, charinfo } from the server.
function Bridge.created(result)
    local name = Bridge.name()
    if name == 'esx' then return esxEnter() end
    return qbCreated(name, result)
end
