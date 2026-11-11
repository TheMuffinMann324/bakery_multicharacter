-- The spawn map: a live aerial camera over the real city, with the UI drawn on top
-- (web/src/views/SpawnMap.tsx). The UI sends drags, scrolls and keys; this moves the camera and tells the
-- UI where each spawn point is on screen every frame it changes.
Spawn = { active = false }

local PITCH = -58.0                     -- camera tilt, degrees below the horizon
local FOV = 48.0
local MIN_DIST, MAX_DIST = 70.0, 4200.0 -- metres from the camera to the ground it looks at
local START_DIST = 1300.0
local FOCUS_DIST = 240.0                -- when a spawn point is picked
local LAND_DIST = 26.0                  -- the camera drops this close before cutting to the player
local ROTATE_SPEED = 70.0               -- degrees per second with Q / E
local PAN_SPEED = 0.9                   -- screen heights per second with WASD
local SMOOTH_MS = 110.0                 -- how quickly the camera catches up with where it should be
local BOUNDS = { minX = -3900.0, maxX = 4400.0, minY = -4100.0, maxY = 8100.0 }
local FALLBACK = vec4(-1035.71, -2731.87, 13.76, 330.0)   -- no spawn points at all

local cam = nil
local want, cur = nil, nil    -- { x, y, z, heading, dist }: where the camera is going, where it is
local keys = { rotate = 0, x = 0, y = 0 }
local points = {}
local selected = nil
local picked = nil
local landing = false
local lastFrame = nil

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
local function lerp(a, b, t) return a + (b - a) * t end

local function angleDiff(a, b)
    return (b - a + 540.0) % 360.0 - 180.0
end

local function zoneLabel(x, y, z)
    local label = GetLabelText(GetNameOfZone(x, y, z))
    if label == 'NULL' or label == '' then return 'San Andreas' end
    return label
end

local function streetName(x, y, z)
    local hash = GetStreetNameAtCoord(x, y, z)
    local name = hash ~= 0 and GetStreetNameFromHashKey(hash) or ''
    return name ~= '' and name or nil
end

local function validCoords(c)
    return c and tonumber(c.x) and tonumber(c.y) and tonumber(c.z)
        and (math.abs(c.x) > 1.0 or math.abs(c.y) > 1.0)
end

local function pointById(id)
    for _, p in ipairs(points) do
        if p.id == id then return p end
    end
    return nil
end

-- zoom 0 = whole city, 1 = street level (what the UI's zoom rail shows)
local function zoomLevel(dist)
    return 1.0 - math.log(dist / MIN_DIST) / math.log(MAX_DIST / MIN_DIST)
end

local function distForLevel(level)
    return MIN_DIST * (MAX_DIST / MIN_DIST) ^ (1.0 - Utils.clamp(level, 0.0, 1.0))
end

local function clampWant()
    want.x = Utils.clamp(want.x, BOUNDS.minX, BOUNDS.maxX)
    want.y = Utils.clamp(want.y, BOUNDS.minY, BOUNDS.maxY)
    want.dist = Utils.clamp(want.dist, MIN_DIST, MAX_DIST)
end

-- Ground vectors for the current heading: screen-right and screen-up as seen from above.
local function groundAxes(heading)
    local h = math.rad(heading)
    return vector2(math.cos(h), math.sin(h)), vector2(-math.sin(h), math.cos(h))
end

-- Metres of ground per screen height / width at the current zoom.
local function viewSize(dist)
    local height = 2.0 * dist * math.tan(math.rad(FOV) / 2.0)
    return height / math.sin(math.rad(-PITCH)), height * GetAspectRatio(false)
end

local function focusOn(x, y, z, dist)
    want.x, want.y = x, y
    if z then want.z = z end
    if dist then want.dist = dist end
    clampWant()
end

-- ------------------------------------------------------------
-- Camera
-- ------------------------------------------------------------
local function cameraPosition(s)
    local p, h = math.rad(PITCH), math.rad(s.heading)
    local fx, fy, fz = -math.sin(h) * math.cos(p), math.cos(h) * math.cos(p), math.sin(p)
    return vector3(s.x - fx * s.dist, s.y - fy * s.dist, s.z - fz * s.dist)
end

local function applyCamera()
    local pos = cameraPosition(cur)
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    SetCamRot(cam, PITCH, 0.0, cur.heading, 2)
    -- stream the world where the camera looks, not where the player stands
    SetFocusPosAndVel(cur.x, cur.y, cur.z, 0.0, 0.0, 0.0)
end

-- The ground under the middle of the screen, once it has loaded; until then the last known height.
local function trackGround()
    local found, z = GetGroundZFor_3dCoord(want.x, want.y, 1000.0, false)
    if found and z > -50.0 then want.z = z end
end

-- The line from the camera through a point on screen (0-1).
local function screenRay(sx, sy)
    local from = cameraPosition(cur)
    local p, h = math.rad(PITCH), math.rad(cur.heading)
    local f = vector3(-math.sin(h) * math.cos(p), math.cos(h) * math.cos(p), math.sin(p))
    local r = vector3(math.cos(h), math.sin(h), 0.0)
    local u = vector3(math.sin(h) * math.sin(p), -math.cos(h) * math.sin(p), math.cos(p))
    local t = math.tan(math.rad(FOV) / 2.0)
    local dir = f + r * ((sx - 0.5) * 2.0 * t * GetAspectRatio(false)) + u * ((0.5 - sy) * 2.0 * t)
    return from, dir / #dir
end

-- Where a point on screen meets the world. solid = false when collision there hasn't loaded yet and
-- the flat ground under the camera was used instead (the height is found again before spawning).
local function groundAt(sx, sy)
    local from, dir = screenRay(sx, sy)
    local to = from + dir * 15000.0
    local probe = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1, 0, 7)
    local _, hit, coords = GetShapeTestResult(probe)
    if (hit == 1 or hit == true) and coords then return coords, true end
    if dir.z >= -0.01 then return nil end
    return from + dir * ((cur.z - from.z) / dir.z), false
end

-- Height of the ground at a dropped spot, once the camera has landed and the area has loaded.
local function settle(p)
    local top = p.solid and p.z + 2.0 or 1000.0
    local deadline = GetGameTimer() + 2500
    repeat
        RequestCollisionAtCoord(p.x, p.y, p.z)
        local found, z = GetGroundZFor_3dCoord(p.x, p.y, top, false)
        if found then
            p.z = z
            break
        end
        Wait(50)
    until GetGameTimer() > deadline
    p.z = p.z + 1.0   -- the ped stands with its middle 1 m above the ground
end

local origin = nil   -- where the character last was, for "how far away" in the list

local function forUi(p)
    local distance = nil
    if origin and not p.nopin and p.kind ~= 'last' then
        distance = math.floor(#(vector2(p.x, p.y) - vector2(origin.x, origin.y)) + 0.5)
    end
    return { id = p.id, kind = p.kind, label = p.label, zone = p.zone, street = p.street, distance = distance, nopin = p.nopin or nil }
end

local function step(dt)
    -- keys held in the UI
    if keys.rotate ~= 0 then want.heading = (want.heading + keys.rotate * ROTATE_SPEED * dt / 1000.0) % 360.0 end
    if keys.x ~= 0 or keys.y ~= 0 then
        local right, up = groundAxes(want.heading)
        local tall = viewSize(cur.dist)
        local move = tall * PAN_SPEED * dt / 1000.0
        want.x = want.x + (right.x * keys.x + up.x * keys.y) * move
        want.y = want.y + (right.y * keys.x + up.y * keys.y) * move
        clampWant()
    end

    local t = 1.0 - math.exp(-dt / (landing and 260.0 or SMOOTH_MS))
    cur.x = lerp(cur.x, want.x, t)
    cur.y = lerp(cur.y, want.y, t)
    cur.z = lerp(cur.z, want.z, t)
    cur.heading = (cur.heading + angleDiff(cur.heading, want.heading) * t) % 360.0
    cur.dist = math.exp(lerp(math.log(cur.dist), math.log(want.dist), landing and t * 0.6 or t * 0.8))
end

-- Where everything is on screen, sent only when it changed.
local function sendFrame()
    local pins, key = {}, {}
    for i, p in ipairs(points) do
        local on, x, y = GetScreenCoordFromWorldCoord(p.x, p.y, p.z + 1.0)
        if p.nopin then on = false end
        pins[i] = { id = p.id, x = x, y = y, visible = on }
        key[i] = on and ('%.4f:%.4f'):format(x, y) or '-'
    end
    local frame = {
        heading = cur.heading,
        zoom = zoomLevel(cur.dist),
        altitude = math.floor(cameraPosition(cur).z - cur.z + 0.5),
        pins = pins,
    }
    local joined = ('%.1f|%.3f|%s'):format(frame.heading, frame.zoom, table.concat(key, '|'))
    if joined == lastFrame then return end
    lastFrame = joined
    Nui.send('spawnFrame', frame)
end

local function loop()
    local last = GetGameTimer()
    local lastGround = 0
    while Spawn.active do
        local now = GetGameTimer()
        local dt = math.min(100, now - last)
        last = now

        HideHudAndRadarThisFrame()
        DisableAllControlActions(0)
        ThefeedHideThisFrame()
        SetEntityLocallyInvisible(PlayerPedId())

        if now - lastGround > 150 then
            lastGround = now
            trackGround()
        end
        step(dt)
        applyCamera()
        sendFrame()
        Wait(0)
    end
end

-- ------------------------------------------------------------
-- UI callbacks
-- ------------------------------------------------------------

-- Mouse drag: dx / dy are fractions of the screen. The map follows the cursor.
Nui.on('spawnPan', function(body)
    if not Spawn.active or landing then return end
    local dx, dy = tonumber(body.dx) or 0.0, tonumber(body.dy) or 0.0
    local right, up = groundAxes(want.heading)
    local tall, wide = viewSize(cur.dist)
    want.x = want.x - right.x * dx * wide + up.x * dy * tall
    want.y = want.y - right.y * dx * wide + up.y * dy * tall
    clampWant()
end)

-- Scroll wheel (steps: + is in, - is out) or the zoom rail (level 0-1).
Nui.on('spawnZoom', function(body)
    if not Spawn.active or landing then return end
    if body.level ~= nil then
        want.dist = distForLevel(tonumber(body.level) or 0.5)
    else
        want.dist = want.dist * (0.82 ^ (tonumber(body.steps) or 0))
    end
    clampWant()
end)

-- Keys held down: rotate -1 / 0 / 1 (Q / E), x / y -1 / 0 / 1 (WASD).
Nui.on('spawnKeys', function(body)
    keys.rotate = Utils.clamp(tonumber(body.rotate) or 0, -1, 1)
    keys.x = Utils.clamp(tonumber(body.x) or 0, -1, 1)
    keys.y = Utils.clamp(tonumber(body.y) or 0, -1, 1)
end)

Nui.on('spawnNorth', function()
    if Spawn.active and not landing then want.heading = 0.0 end
end)

-- Fly to a spawn point and select it.
Nui.on('spawnFocus', function(body)
    if not Spawn.active or landing then return end
    local p = pointById(body.id)
    if not p then return { ok = false } end
    selected = p.id
    if not p.nopin then focusOn(p.x, p.y, p.z, math.min(want.dist, FOCUS_DIST)) end
end)

-- The little guy was dropped on the map at x / y (fractions of the screen).
Nui.on('spawnDrop', function(body)
    if not Spawn.active or landing or not Config.Spawn.FreeSpawn then return { ok = false } end
    local sx, sy = tonumber(body.x), tonumber(body.y)
    if not sx or not sy then return { ok = false } end

    local at, solid = groundAt(sx, sy)
    if not at or at.x < BOUNDS.minX or at.x > BOUNDS.maxX or at.y < BOUNDS.minY or at.y > BOUNDS.maxY then
        return { ok = false, error = "You can't spawn there." }
    end
    local wet, water = GetWaterHeight(at.x, at.y, at.z)
    if wet and water >= at.z - 0.3 then
        return { ok = false, error = "That's in the water. Pick some dry land." }
    end

    for i = #points, 1, -1 do
        if points[i].kind == 'drop' then table.remove(points, i) end
    end
    local p = {
        id = 'drop', kind = 'drop', label = 'Dropped pin', x = at.x, y = at.y, z = at.z, w = cur.heading, solid = solid,
        zone = zoneLabel(at.x, at.y, at.z), street = streetName(at.x, at.y, at.z),
    }
    table.insert(points, 1, p)
    selected, lastFrame = p.id, nil
    return { ok = true, point = forUi(p) }
end)

Nui.on('spawnConfirm', function(body)
    if not Spawn.active or landing then return { ok = false } end
    local p = pointById(body.id)
    if not p then return { ok = false, error = 'Pick somewhere to spawn.' } end
    picked = p
    return { ok = true }
end)

-- ------------------------------------------------------------
-- Public
-- ------------------------------------------------------------

-- Shows the map and waits until the player picks a spot. Returns { x, y, z, w, home = { adapter, id } or nil }.
-- opts: { last = coords or nil, homes = { adapter, list } or nil (bridge/housing.lua), firstName, lastName, isNew }
function Spawn.choose(opts)
    opts = opts or {}
    points = {}
    origin = validCoords(opts.last) and opts.last or nil
    if Config.Spawn.LastLocation and validCoords(opts.last) then
        local c = opts.last
        points[#points + 1] = { id = 'last', kind = 'last', label = 'Last location', x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, w = (c.w or c.heading or 0.0) + 0.0 }
    end
    -- their own homes come next. A home with no known door has no pin; the player is still put inside it,
    -- standing at their last location (or the first spawn point) while the housing script takes over.
    local homes = type(opts.homes) == 'table' and type(opts.homes.list) == 'table' and opts.homes or nil
    local standIn = validCoords(opts.last) and opts.last or (Config.Spawn.Locations and Config.Spawn.Locations[1] and Config.Spawn.Locations[1].coords) or FALLBACK
    for i, home in ipairs(homes and homes.list or {}) do
        local c = validCoords(home.coords) and home.coords or nil
        local at = c or standIn
        points[#points + 1] = {
            id = 'home' .. i, kind = 'home', label = home.label, address = home.address, nopin = c == nil,
            x = at.x + 0.0, y = at.y + 0.0, z = at.z + 0.0, w = (at.w or 0.0) + 0.0,
            home = { adapter = homes.adapter, id = home.id },
        }
    end
    for i, loc in ipairs(Config.Spawn.Locations or {}) do
        local c = loc.coords
        if validCoords(c) then
            points[#points + 1] = { id = 'loc' .. i, kind = 'location', label = loc.label or ('Spawn ' .. i), x = c.x, y = c.y, z = c.z, w = c.w or 0.0 }
        end
    end

    local free = Config.Spawn.FreeSpawn == true
    if #points == 0 and not free then return FALLBACK end
    if #points == 1 and not free then
        local p = points[1]
        return { x = p.x, y = p.y, z = p.z, w = p.w, home = p.home }
    end

    for _, p in ipairs(points) do
        if p.nopin then
            p.zone, p.street = p.address or 'Your home', nil
        else
            p.zone = zoneLabel(p.x, p.y, p.z)
            p.street = p.address or streetName(p.x, p.y, p.z)
        end
    end

    -- open over the last location, or the middle of Los Santos
    local first = points[1]
    local onLast = first and first.kind == 'last'
    local startX, startY, startZ = onLast and first.x or 150.0, onLast and first.y or -900.0, onLast and first.z or 30.0
    want = { x = startX, y = startY, z = startZ, heading = 0.0, dist = START_DIST }
    cur = { x = startX, y = startY, z = startZ, heading = -25.0, dist = MAX_DIST }
    keys = { rotate = 0, x = 0, y = 0 }
    selected, picked, landing, lastFrame = onLast and first.id or nil, nil, false, nil

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityInvincible(ped, true)
    NetworkSetEntityInvisibleToNetwork(ped, true)   -- PlayerState.restore shows them again
    DisplayRadar(false)

    cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', 0.0, 0.0, 0.0, PITCH, 0.0, cur.heading, FOV, false, 2)
    SetCamFarClip(cam, 12000.0)
    applyCamera()
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    Spawn.active = true
    CreateThread(loop)

    -- give the city a moment to stream in under the camera
    Wait(900)
    local ui = {}
    for i, p in ipairs(points) do ui[i] = forUi(p) end
    Nui.send('spawn', {
        server = Config.ServerName,
        logo = Nui.logo(),
        points = ui,
        freeSpawn = free,
        homesEnabled = Housing.active() ~= nil,
        selected = selected,
        firstName = opts.firstName, lastName = opts.lastName, isNew = opts.isNew == true,
    })
    Nui.focus(true)
    ShutdownLoadingScreen()
    DoScreenFadeIn(300)   -- under the UI's shutter, which the map opens itself

    -- keep the mouse on the map: other resources starting up can take focus away
    while not picked and Spawn.active do
        if not IsNuiFocused() then Nui.focus(true) end
        Wait(100)
    end
    if not Spawn.active then return FALLBACK end

    -- drop down onto the spot, then cut to the player (a home with no door just cuts)
    Nui.focus(false)
    keys = { rotate = 0, x = 0, y = 0 }
    landing = true
    if not picked.nopin then
        want.x, want.y, want.z, want.dist = picked.x, picked.y, picked.z, LAND_DIST
        want.heading = picked.w
        Wait(1100)
    else
        Wait(400)
    end
    -- the blades shut over the landing; they open again on the player (bridge/client.lua fadeIn)
    Nui.shutter(true, 'Waking up')
    Wait(320)
    DoScreenFadeOut(0)
    if picked.kind == 'drop' then settle(picked) end

    Spawn.stop()
    return { x = picked.x, y = picked.y, z = picked.z, w = picked.w, home = picked.home }
end

function Spawn.stop()
    if not Spawn.active then return end
    Spawn.active = false
    landing = false
    Nui.send('spawn', false)
    Nui.focus(false)
    RenderScriptCams(false, false, 0, true, true)
    if cam then DestroyCam(cam, false) end
    cam = nil
    ClearFocus()
    DisplayRadar(true)
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() or not Spawn.active then return end
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
    NetworkSetEntityInvisibleToNetwork(PlayerPedId(), false)
    FreezeEntityPosition(PlayerPedId(), false)
    SetEntityCollision(PlayerPedId(), true, true)
    DisplayRadar(true)
    DoScreenFadeIn(0)
end)
