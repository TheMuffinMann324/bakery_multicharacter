-- The introduction shown once the character is in the world: logo, their name, and where / when they are.
-- Drawn by the NUI (web/src/components/Intro.tsx) without taking focus, so the player can move straight away.
Intro = {}

local WEATHER = {
    EXTRASUNNY = 'Sunny', CLEAR = 'Clear', CLOUDS = 'Cloudy', OVERCAST = 'Overcast', RAIN = 'Rain',
    CLEARING = 'Clearing', THUNDER = 'Thunderstorm', SMOG = 'Smog', FOGGY = 'Fog', XMAS = 'Snow',
    SNOW = 'Snow', SNOWLIGHT = 'Light snow', BLIZZARD = 'Blizzard', HALLOWEEN = 'Halloween', NEUTRAL = 'Mild',
}
local WEATHER_BY_HASH = {}
for name, label in pairs(WEATHER) do WEATHER_BY_HASH[joaat(name)] = label end

local playing = 0

local function clock()
    local h, m = GetClockHours(), GetClockMinutes()
    local suffix = h < 12 and 'AM' or 'PM'
    h = h % 12
    if h == 0 then h = 12 end
    return ('%d:%02d %s'):format(h, m, suffix)
end

local function partOfDay(h)
    if h < 5 then return 'Late night' end
    if h < 12 then return 'Morning' end
    if h < 17 then return 'Afternoon' end
    if h < 21 then return 'Evening' end
    return 'Night'
end

-- Where the player is standing right now.
local function surroundings()
    local pos = GetEntityCoords(PlayerPedId())
    local streetHash, crossHash = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local street = streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or nil
    local cross = crossHash ~= 0 and GetStreetNameFromHashKey(crossHash) or nil
    local zone = GetLabelText(GetNameOfZone(pos.x, pos.y, pos.z))
    if zone == 'NULL' or zone == '' then zone = nil end
    local interior = GetInteriorFromEntity(PlayerPedId()) ~= 0

    return {
        zone = zone or 'San Andreas',
        street = street ~= '' and street or nil,
        cross = cross ~= '' and cross or nil,
        indoors = interior,
        time = clock(),
        partOfDay = partOfDay(GetClockHours()),
        weather = WEATHER_BY_HASH[GetPrevWeatherTypeHashName()] or nil,
    }
end

-- Is the player really looking at the world? Not faded out, no spawn selector or clothing menu on screen.
local function inWorld()
    return IsScreenFadedIn()
        and GetRenderingCam() == -1
        and not IsPlayerSwitchInProgress()
        and not IsNuiFocused()
        and IsEntityVisible(PlayerPedId())
end

-- character: { firstName, lastName }, isNew: just created. For a new character this is only called once the
-- character creator is done (bridge/clothing.lua), so the intro never plays over it.
function Intro.play(character, isNew)
    if not Config.Intro then return end
    playing = playing + 1
    local id = playing
    CreateThread(function()
        -- spawn selectors, apartments and the first clothing menu all come first
        local deadline = GetGameTimer() + 10 * 60000
        local settled = 0
        while id == playing and GetGameTimer() < deadline do
            if inWorld() then
                settled = settled + 1
                -- about a second in the world; two for a new character, whose creator may close and reopen on save
                if settled >= (isNew and 8 or 4) then break end
            else
                settled = 0
            end
            Wait(250)
        end
        if id ~= playing or GetGameTimer() >= deadline or Selection.active then return end

        local info = surroundings()
        info.server = Config.ServerName
        info.firstName = character and character.firstName or ''
        info.lastName = character and character.lastName or ''
        info.isNew = isNew == true
        info.duration = 6500
        Nui.send('intro', info)
    end)
end

function Intro.cancel()
    playing = playing + 1
    Nui.send('intro', false)
end
