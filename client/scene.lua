-- The line-up: one ped per slot, the cameras, rings, lights and the labels' screen positions.
Scene = { active = false }

local UP = vector3(0.0, 0.0, 1.0)
local ASPECT = 16.0 / 9.0
local FADE_MS = 320          -- peds fading in and out
local ANCHOR_MS = 33         -- how often label positions are checked

-- Look of the scene. Only the position is in config.lua; the rest is tuned to work together.
local S = {
    Spacing = 1.45,                                    -- metres between characters
    Time = { hour = 23, minute = 0 },                  -- clock while choosing
    Weather = 'EXTRASUNNY',
    EmptyAlpha = 110, EmptyAlphaHover = 200,           -- how see-through an empty slot is
    -- Lobby idles: each slot gets a different one, so the line-up never moves in sync. Missing ones are skipped.
    Idles = {
        male = {
            { 'anim@heists@heist_corona@single_team', 'single_team_loop_boss' },
            { 'anim@mp_corona_idles@male_c@idle_a', 'idle_a' },
            { 'anim@heists@heist_corona@team_idles@male_a', 'idle' },
            { 'anim@mp_corona_idles@male_d@idle_a', 'idle_a' },
            { 'amb@world_human_hang_out_street@male_b@idle_a', 'idle_b' },
        },
        female = {
            { 'anim@heists@heist_corona@team_idles@female_a', 'idle' },
            { 'anim@mp_corona_idles@female_b@idle_a', 'idle_a' },
            { 'anim@heists@heist_corona@single_team', 'single_team_loop_boss' },
            { 'amb@world_human_hang_out_street@female_hold_arm@idle_a', 'idle_a' },
        },
    },
    -- Played once over the idle (upper body only) when a character is hovered or opened.
    Gesture = {
        male = { 'gestures@m@standing@casual', 'gesture_hello' },
        female = { 'gestures@f@standing@casual', 'gesture_hello' },
    },
    GestureCooldown = 4000,   -- ms before the same character gestures again
    Stagger = 110,            -- ms between characters fading in when the line-up opens
    CamShake = 0.12,          -- slight hand-held drift on every shot (0 = locked off)
    Lineup = { Fov = 38.0, Height = 0.15, Pitch = -1.5, Margin = 1.4 },
    Detail = { Fov = 38.0, Distance = 3.0, Height = 0.2, ScreenX = 0.5 },
    Ring = { size = 0.95, color = { 255, 255, 255 }, alpha = 45, alphaHover = 190 },
    Light = { color = { 255, 245, 235 }, brightness = 1.4, brightnessHover = 3.6 },   -- spotlight on each character
    DetailLight = { color = { 255, 245, 235 }, range = 5.0, intensity = 1.1 },          -- key and rim light on one character
    Transition = { Drift = 1600, DriftDistance = 0.35 },   -- the camera settles this far (m) over this long (ms)
}
Scene.settings = S

local basis = nil            -- { origin, forward, right, heading, camHeading }
local slots = {}             -- [slot] = { pos (waist), feet (z), ped, ghost, alpha, shown, character }
local order = {}             -- slots shown, left to right: every character, then one free slot to create in
local layout                 -- defined below

-- for slot, s in eachSlot() do ... end, over the slots shown
local function eachSlot()
    local i = 0
    return function()
        i = i + 1
        local slot = order[i]
        if slot then return slot, slots[slot] end
    end
end

-- A full line-up stands a little closer together.
local function spacing()
    return #order > 5 and S.Spacing * 0.82 or S.Spacing
end
local cam = nil
local view = 'lineup'        -- 'lineup' | 'detail'
local selected, hovered = nil, nil
local lineupMix = 1.0        -- 1 in the line-up, 0 on a single character (rings and spotlights)
local lastAnchors = nil

-- ------------------------------------------------------------
-- The player's own ped waits out of sight while they choose
-- ------------------------------------------------------------
-- The ped is never set invisible: that flag sticks to the ped and every spawn path would have to undo
-- it (qbx_core and esx_multicharacter don't use it either). The scene hides it locally, one frame at a
-- time (SetEntityLocallyInvisible in the frame loop), which stops by itself when the scene ends.
PlayerState = { hidden = false }

function PlayerState.hide(coords)
    local ped = PlayerPedId()
    PlayerState.hidden = true
    SetEntityCollision(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    if coords then
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    end
end

-- Undo anything that could leave the player unseen: an invisible flag, alpha, or network invisibility.
-- Earlier versions of this resource, clothing scripts swapping the model and spawn selectors can all leave one behind.
function PlayerState.show()
    local ped = PlayerPedId()
    if not IsEntityVisible(ped) then SetEntityVisible(ped, true, false) end
    ResetEntityAlpha(ped)
    NetworkSetEntityInvisibleToNetwork(ped, false)
end

-- After spawning, keep making sure the player can be seen for a few seconds. With a spawn selector
-- (qb-spawn, apartments) it waits until the selector's camera is gone and the screen is faded in, since
-- the selector hides the player on purpose while you choose.
local guardId = 0
function PlayerState.guard(selector)
    guardId = guardId + 1
    local id = guardId
    CreateThread(function()
        local deadline = GetGameTimer() + (selector and 120000 or 0)
        if selector then
            while id == guardId and GetGameTimer() < deadline
                and (GetRenderingCam() ~= -1 or not IsScreenFadedIn() or IsPlayerSwitchInProgress()) do
                Wait(250)
            end
        end
        local stop = GetGameTimer() + 5000
        while id == guardId and GetGameTimer() < stop and not Scene.active do
            PlayerState.show()
            Wait(250)
        end
    end)
end

-- keepFrozen: a spawn selector takes over and places the player itself.
function PlayerState.restore(keepFrozen)
    local ped = PlayerPedId()
    PlayerState.hidden = false
    SetEntityCollision(ped, true, true)
    SetEntityInvincible(ped, false)
    if not keepFrozen then FreezeEntityPosition(ped, false) end
    PlayerState.guard(keepFrozen)
end

-- ------------------------------------------------------------
-- Layout
-- ------------------------------------------------------------
local function buildBasis()
    local c = Config.LineupCoords
    local h = math.rad(c.w)
    local camHeading = (c.w + 180.0) % 360.0
    local ch = math.rad(camHeading)
    basis = {
        origin = vector3(c.x, c.y, c.z),
        forward = vector3(-math.sin(h), math.cos(h), 0.0),   -- from the characters towards the camera
        right = vector3(math.cos(ch), math.sin(ch), 0.0),    -- screen-right
        heading = c.w,
        camHeading = camHeading,
    }
end

local function slotPosition(index, count)
    local pos = basis.origin + basis.right * ((index - (count + 1) / 2.0) * spacing())
    local feet = pos.z - 1.0
    local found, ground = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    if found and math.abs(ground - feet) < 2.5 then feet = ground end
    return vector3(pos.x, pos.y, feet + 1.0), feet
end

local function lineupCamera()
    local cfg = S.Lineup
    local tanV = math.tan(math.rad(cfg.Fov) / 2.0)
    local halfW = (#order - 1) / 2.0 * spacing() + cfg.Margin
    local dist = math.max(halfW / (tanV * GetAspectRatio(false)), 1.6 / tanV)
    local centre = vector3(basis.origin.x, basis.origin.y, order[1] and slots[order[1]].pos.z or basis.origin.z)
    return centre + basis.forward * dist + UP * cfg.Height, vector3(cfg.Pitch, 0.0, basis.camHeading), cfg.Fov
end

local function detailCamera(slot)
    local cfg = S.Detail
    local halfW = cfg.Distance * math.tan(math.rad(cfg.Fov) / 2.0) * ASPECT
    local shift = (0.5 - cfg.ScreenX) * 2.0 * halfW
    local pos = slots[slot].pos + basis.forward * cfg.Distance + basis.right * shift + UP * cfg.Height
    return pos, vector3(0.0, 0.0, basis.camHeading), cfg.Fov
end

-- ------------------------------------------------------------
-- Camera
-- ------------------------------------------------------------
local function newCam(pos, rot, fov)
    return CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, fov, false, 2)
end

-- Every view change is a hard cut, made while the UI's shutter covers the screen (web/src/components/Shutter.tsx).
-- The camera starts a little off its mark and settles into it, so the shot still moves when the shutter opens.
-- drift: direction the camera starts from (it moves the opposite way).
local function cutTo(pos, rot, fov, drift)
    local cfg = S.Transition
    local distance, ms = cfg.DriftDistance or 0.0, cfg.Drift or 0
    if cam then DestroyCam(cam, false) end

    if distance <= 0.0 or ms <= 0 or not drift then
        cam = newCam(pos, rot, fov)
        if S.CamShake > 0 then ShakeCam(cam, 'HAND_SHAKE', S.CamShake) end
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
        return
    end

    local from = newCam(pos + drift * distance, rot, fov)
    local to = newCam(pos, rot, fov)
    if S.CamShake > 0 then
        ShakeCam(from, 'HAND_SHAKE', S.CamShake)
        ShakeCam(to, 'HAND_SHAKE', S.CamShake)
    end
    SetCamActive(from, true)
    RenderScriptCams(true, false, 0, true, true)
    SetCamActiveWithInterp(to, from, ms, 0, 1)
    SetTimeout(ms + 250, function() DestroyCam(from, false) end)
    cam = to
end

-- ------------------------------------------------------------
-- Peds
-- ------------------------------------------------------------
local function loadModel(model)
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
    return HasModelLoaded(model)
end

local function loadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
    return HasAnimDictLoaded(dict)
end

local function pedGender(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01` and 'female' or (IsPedMale(ped) and 'male' or 'female')
end

-- A different lobby idle per slot, started at a random point so nobody moves in step.
local function playIdle(ped, slot)
    local pool = S.Idles[pedGender(ped)] or S.Idles.male
    for i = 0, #pool - 1 do
        local idle = pool[((slot - 1 + i) % #pool) + 1]
        if loadDict(idle[1]) then
            if not DoesEntityExist(ped) then return end
            TaskPlayAnim(ped, idle[1], idle[2], 8.0, -8.0, -1, 1, math.random() * 0.8, false, false, false)
            RemoveAnimDict(idle[1])
            return
        end
    end
end

-- A quick hello over the idle, upper body only. Not too often per character.
local function playGesture(slot)
    local s = slots[slot]
    if not s or s.ghost or not s.ped or not DoesEntityExist(s.ped) then return end
    local now = GetGameTimer()
    if s.gestured and now - s.gestured < S.GestureCooldown then return end
    s.gestured = now
    local ped = s.ped
    CreateThread(function()
        local g = S.Gesture[pedGender(ped)] or S.Gesture.male
        if not loadDict(g[1]) or not DoesEntityExist(ped) then return end
        TaskPlayAnim(ped, g[1], g[2], 4.0, -4.0, -1, 48, 0.0, false, false, false)
        RemoveAnimDict(g[1])
    end)
end

local function removePed(slot)
    local s = slots[slot]
    if s and s.ped and DoesEntityExist(s.ped) then DeleteEntity(s.ped) end
    if s then s.ped = nil end
end

-- character = nil makes an empty-slot ghost of the given gender.
local function spawnPed(slot, character, gender)
    local s = slots[slot]
    removePed(slot)
    local model = character and Appearance.model(character) or Appearance.emptyModel(gender)
    if not loadModel(model) then
        model = Appearance.emptyModel('male')
        if not loadModel(model) then return end
    end
    if not Scene.active then return SetModelAsNoLongerNeeded(model) end

    local ped = CreatePed(4, model, s.pos.x, s.pos.y, s.feet, basis.heading, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityAsMissionEntity(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetEntityAlpha(ped, 0, false)   -- fades in from the frame loop

    Appearance.default(ped)
    if character then Appearance.apply(ped, character.skin) end

    s.ped, s.ghost, s.character = ped, character == nil, character
    s.alpha, s.shown, s.gestured = 0.0, nil, nil
    if character then playIdle(ped, slot) end
end

local function targetAlpha(slot, s)
    if view == 'detail' then return slot == selected and 255.0 or 0.0 end
    if s.revealAt and GetGameTimer() < s.revealAt then return 0.0 end   -- the line-up fades in one by one
    if not s.ghost then return 255.0 end
    return slot == hovered and S.EmptyAlphaHover or S.EmptyAlpha
end

-- Peds, rings and lights jump straight to the new view; the shutter hides the change.
local function snapVisuals()
    lineupMix = view == 'lineup' and 1.0 or 0.0
    for slot, s in eachSlot() do s.alpha = targetAlpha(slot, s) end
end

local function updatePeds(dt)
    local step = 255.0 * dt / FADE_MS
    for slot, s in eachSlot() do
        if s.ped and DoesEntityExist(s.ped) then
            local target = targetAlpha(slot, s)
            if s.alpha < target then s.alpha = math.min(target, s.alpha + step)
            elseif s.alpha > target then s.alpha = math.max(target, s.alpha - step) end

            local a = math.floor(s.alpha)
            if a ~= s.shown then
                s.shown = a
                SetEntityVisible(s.ped, a > 0, false)
                if a >= 255 then ResetEntityAlpha(s.ped) else SetEntityAlpha(s.ped, a, false) end
            end
        end
    end
end

-- ------------------------------------------------------------
-- Rings, lights, label positions
-- ------------------------------------------------------------
local function drawLineup()
    if lineupMix <= 0.01 then return end
    local ring, light = S.Ring, S.Light
    for slot, s in eachSlot() do
        local hot = slot == hovered
        local alpha = math.floor((hot and ring.alphaHover or ring.alpha) * lineupMix)
        if alpha > 0 then
            DrawMarker(25, s.pos.x, s.pos.y, s.feet + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, ring.size, ring.size, ring.size,
                ring.color[1], ring.color[2], ring.color[3], alpha, false, false, 2, false, nil, nil, false)
        end
        if not s.ghost or hot then
            local from = s.pos + basis.forward * 1.4 + UP * 3.4
            local dir = s.pos - from
            dir = dir / #dir
            DrawSpotLight(from.x, from.y, from.z, dir.x, dir.y, dir.z, light.color[1], light.color[2], light.color[3],
                8.0, (hot and light.brightnessHover or light.brightness) * lineupMix, 0.0, 11.0, 1.0)
        end
    end
end

local function drawDetailLight()
    if lineupMix >= 0.99 or not selected or not slots[selected] then return end
    local light, s = S.DetailLight, slots[selected]
    local k = 1.0 - lineupMix
    local key = s.pos + basis.forward * 2.2 + basis.right * 1.2 + UP * 0.9
    local rim = s.pos - basis.forward * 0.55 - basis.right * 0.9 + UP * 1.0
    DrawLightWithRange(key.x, key.y, key.z, light.color[1], light.color[2], light.color[3], light.range, light.intensity * k)
    DrawLightWithRange(rim.x, rim.y, rim.z, light.color[1], light.color[2], light.color[3], light.range * 0.5, light.intensity * 0.8 * k)
end

-- Where each slot is on screen (0-1), so the UI can put labels over the heads.
local function sendAnchors()
    local list, key = {}, {}
    local half = basis.right * (spacing() / 2.0)
    for slot, s in eachSlot() do
        local on, x, top = GetScreenCoordFromWorldCoord(s.pos.x, s.pos.y, s.pos.z + 0.98)
        local _, _, bottom = GetScreenCoordFromWorldCoord(s.pos.x, s.pos.y, s.feet)
        local _, left = GetScreenCoordFromWorldCoord(s.pos.x - half.x, s.pos.y - half.y, s.pos.z)
        local _, right = GetScreenCoordFromWorldCoord(s.pos.x + half.x, s.pos.y + half.y, s.pos.z)
        list[#list + 1] = { slot = slot, x = x, top = top, bottom = bottom, width = math.abs(right - left), visible = on }
        key[#key + 1] = ('%d:%.4f:%.4f:%.4f'):format(slot, x, top, bottom)
    end
    local joined = table.concat(key, '|')
    if joined == lastAnchors then return end
    lastAnchors = joined
    Nui.send('anchors', list)
end

-- ------------------------------------------------------------
-- Frame loop
-- ------------------------------------------------------------
local function loop()
    local last, lastAnchor = GetGameTimer(), 0
    while Scene.active do
        local now = GetGameTimer()
        local dt = math.min(100, now - last)
        last = now

        HideHudAndRadarThisFrame()
        DisableAllControlActions(0)
        SetEntityLocallyInvisible(PlayerPedId())   -- the player waits behind the line-up, unseen
        ThefeedHideThisFrame()

        local time = S.Time
        if time then NetworkOverrideClockTime(time.hour, time.minute or 0, 0) end

        local mixTarget = view == 'lineup' and 1.0 or 0.0
        local mixStep = dt / 450.0
        if lineupMix < mixTarget then lineupMix = math.min(mixTarget, lineupMix + mixStep)
        elseif lineupMix > mixTarget then lineupMix = math.max(mixTarget, lineupMix - mixStep) end

        updatePeds(dt)
        drawLineup()
        drawDetailLight()
        Backdrop.draw(dt)

        if now - lastAnchor >= ANCHOR_MS then
            lastAnchor = now
            sendAnchors()
        end
        Wait(0)
    end
end

-- ------------------------------------------------------------
-- Public
-- ------------------------------------------------------------

-- Who stands in the line-up: every character in slot order, then the first free slot (to create in).
-- The other free slots aren't shown; the UI says how many there are.
layout = function(characters, count)
    for slot in eachSlot() do removePed(slot) end
    slots, order = {}, {}
    local bySlot = {}
    for _, c in ipairs(characters) do bySlot[c.slot] = c end
    for slot = 1, count do
        if bySlot[slot] then order[#order + 1] = slot end
    end
    for slot = 1, count do
        if not bySlot[slot] then
            order[#order + 1] = slot
            break
        end
    end

    for i, slot in ipairs(order) do
        local pos, feet = slotPosition(i, #order)
        slots[slot] = { pos = pos, feet = feet, alpha = 0.0 }
    end
    for slot in eachSlot() do spawnPed(slot, bySlot[slot], 'male') end
    -- fade in one after another, starting as the UI's shutter opens
    local reveal = GetGameTimer() + 600
    for i, slot in ipairs(order) do slots[slot].revealAt = reveal + (i - 1) * S.Stagger end
    lastAnchors = nil
end

-- characters: list from the server. count: number of slots.
function Scene.start(characters, count)
    if Scene.active then Scene.stop() end
    Scene.active = true
    buildBasis()
    view, selected, hovered, lineupMix, lastAnchors = 'lineup', nil, nil, 1.0, nil

    -- the player stands behind the wall, so the area streams in and collision loads
    local hide = basis.origin - basis.forward * 6.0
    PlayerState.hide(hide)
    local ped = PlayerPedId()
    local deadline = GetGameTimer() + 6000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(50) end

    Bridge.pauseWeatherSync(true)
    if S.Weather then
        SetWeatherTypeNowPersist(S.Weather)
        SetOverrideWeather(S.Weather)
    end

    layout(characters, count)

    local pos, rot, fov = lineupCamera()
    cutTo(pos, rot, fov, -basis.forward)   -- opens with a slow pull back
    Backdrop.create()
    CreateThread(loop)
end

function Scene.stop()
    if not Scene.active then return end
    Scene.active = false
    for slot in eachSlot() do removePed(slot) end
    slots, order = {}, {}
    Backdrop.destroy()

    RenderScriptCams(false, false, 0, true, true)
    if cam then DestroyCam(cam, false) end
    cam = nil

    if S.Time then NetworkClearClockTimeOverride() end
    if S.Weather then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
    end
    Bridge.pauseWeatherSync(false)
end

-- Swap the ped in one slot (after a delete, or a gender change while creating).
function Scene.setSlot(slot, character, gender)
    if not Scene.active or not slots[slot] then return end
    spawnPed(slot, character, gender)
end

-- After a delete: stand the line-up again (the UI's shutter is closing over it).
function Scene.relayout(characters, count)
    if Scene.active then layout(characters, count) end
end

function Scene.hover(slot)
    local next = slot and slots[slot] and slot or nil
    if next and next ~= hovered and view == 'lineup' then playGesture(next) end
    hovered = next
end

-- Camera onto one character, backdrop behind them. poster = data for web/src/dui (slot, server ...).
-- Called while the UI's shutter is closed: everything changes in one frame.
function Scene.detail(slot, poster)
    if not Scene.active or not slots[slot] then return end
    view, selected, hovered = 'detail', slot, nil
    snapVisuals()

    local pos, rot, fov = detailCamera(slot)
    cutTo(pos, rot, fov, basis.forward)   -- a slow push in towards the character

    local s = slots[slot]
    local geometry = Backdrop.place(pos, basis.forward, basis.right, s.pos, s.feet)
    for k, v in pairs(geometry or {}) do poster[k] = v end
    Backdrop.send('show', poster)
    Backdrop.show(true)
    SetTimeout(450, function()   -- once the shutter has opened: they greet you
        if view == 'detail' and selected == slot then playGesture(slot) end
    end)
end

function Scene.lineup()
    if not Scene.active then return end
    view, selected = 'lineup', nil
    snapVisuals()
    Backdrop.send('hide')
    Backdrop.hide(true)
    local pos, rot, fov = lineupCamera()
    cutTo(pos, rot, fov, -basis.forward)
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for slot in eachSlot() do removePed(slot) end
    if Scene.active then
        RenderScriptCams(false, false, 0, true, true)
        if S.Time then NetworkClearClockTimeOverride() end
    end
end)
