-- Waking up after spawning, like loading back into single player: the character plays the wake-up from
-- Trevor's safehouse while a camera beside them follows them up, then glides back behind them.
-- No shake, blur or other camera effects. Config.WakeUp turns it off.
Wake = {}

-- The wake-up animation(s). More can be added; one is picked at random each time.
local ANIMS = {
    { 'safe@trevor@ig_8', 'ig_8_wake_up_right_player' },
}

local HEAD = 31086          -- SKEL_Head
local FOV = 45.0
local OFFSET = { front = 2.2, side = 1.4, up = 0.35 }   -- camera from the head, in the direction they face at the start
local FOLLOW_MS = 220.0     -- how closely the camera keeps up with them (lower = tighter)
local EASE_BACK = 1500      -- ms to glide back to the normal camera at the end

local function loadDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
    return HasAnimDictLoaded(dict)
end

-- A random wake-up that this game build has: { dict, anim, ms } or nil.
local function pickAnim()
    local first = math.random(#ANIMS)
    for i = 0, #ANIMS - 1 do
        local a = ANIMS[((first - 1 + i) % #ANIMS) + 1]
        if loadDict(a[1]) then
            local ms = GetAnimDuration(a[1], a[2]) * 1000.0
            if ms > 0 then return { dict = a[1], anim = a[2], ms = math.floor(ms) } end
        end
    end
    return nil
end

local function lerp(a, b, t) return a + (b - a) * t end

-- Plays a wake-up and returns once the character is on their feet. Called with the screen still black
-- (faded out, the UI's shutter closed). Returns false when it couldn't play: the caller fades in as usual.
function Wake.play()
    if not Config.WakeUp then return false end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return false end
    local wake = pickAnim()
    if not wake then return false end

    -- start straight in the first pose (no blend), still behind the black screen
    TaskPlayAnim(ped, wake.dict, wake.anim, 1000.0, -4.0, -1, 0, 0.0, false, false, false)
    RemoveAnimDict(wake.dict)
    Wait(100)

    -- the camera's angle is fixed to the way they face as it starts; its position follows them
    local h = math.rad(GetEntityHeading(ped))
    local fwd = vector3(-math.sin(h), math.cos(h), 0.0)
    local right = vector3(math.cos(h), math.sin(h), 0.0)
    local function want()
        local head = GetPedBoneCoords(ped, HEAD, 0.0, 0.0, 0.0)
        return head + fwd * OFFSET.front + right * OFFSET.side + vector3(0.0, 0.0, OFFSET.up), head
    end

    local camPos, look = want()
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, FOV, false, 2)
    PointCamAtCoord(cam, look.x, look.y, look.z)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    local following = true
    CreateThread(function()
        local last = GetGameTimer()
        while following do
            local now = GetGameTimer()
            local t = 1.0 - math.exp(-(now - last) / FOLLOW_MS)
            last = now
            local p, l = want()
            camPos = vector3(lerp(camPos.x, p.x, t), lerp(camPos.y, p.y, t), lerp(camPos.z, p.z, t))
            look = vector3(lerp(look.x, l.x, t), lerp(look.y, l.y, t), lerp(look.z, l.z, t))
            SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
            PointCamAtCoord(cam, look.x, look.y, look.z)
            DisableAllControlActions(0)
            EnableControlAction(0, 249, true)   -- push to talk
            Wait(0)
        end
    end)

    Nui.shutter(false)
    DoScreenFadeIn(800)

    -- near the end of the animation, glide back to the normal camera behind them
    local deadline = GetGameTimer() + wake.ms - EASE_BACK
    while GetGameTimer() < deadline and IsEntityPlayingAnim(ped, wake.dict, wake.anim, 3) do Wait(50) end
    SetGameplayCamRelativeHeading(0.0)
    SetGameplayCamRelativePitch(0.0, 1.0)
    RenderScriptCams(false, true, EASE_BACK, true, true)
    deadline = GetGameTimer() + EASE_BACK + 500
    while GetGameTimer() < deadline do Wait(50) end

    following = false
    DestroyCam(cam, false)
    return true
end
