-- The studio backdrop behind the selected character.
-- ------------------------------------------------------------
-- web/dist/dui.html is rendered by a DUI and drawn on a flat quad in the world, just behind the
-- character. The quad is sized to fill the detail camera exactly, so the page lines up with the screen
-- while the character stands in front of it. A plain black wall sits right behind the quad and covers
-- the rest of the world; the page is black too, so the edge between the two can't be seen.
--
-- The page is told where the floor and the character are on it (in page pixels), so its height
-- chart lines up with the ped's real height.
-- ------------------------------------------------------------
Backdrop = {}

local DUI_URL = ('nui://%s/web/dist/dui.html'):format(GetCurrentResourceName())
local DUI_W, DUI_H = 1920, 1080
local TXD = 'bakery_multichar_dui'
local WALL_HALF_WIDTH, WALL_BELOW, WALL_ABOVE = 80.0, 6.0, 60.0
local FADE_MS = 250
local OFFSET = 0.8        -- metres between the character and the wall
local BRIGHTNESS = 235   -- 0-255, keeps the height chart from glowing at night

local dui = { obj = nil, tex = nil, txd = nil, n = 0, queue = {} }
local alpha, target = 0.0, 0.0
local quad = nil    -- { tl, tr, br, bl } corners of the page
local wall = nil    -- { tl, tr, br, bl } corners of the black wall

local function enabled()
    return true
end

function Backdrop.create()
    if not enabled() or dui.obj then return end
    dui.txd = dui.txd or CreateRuntimeTxd(TXD)
    dui.n = dui.n + 1
    dui.tex = 'backdrop' .. dui.n   -- a fresh texture name each time the DUI is recreated
    dui.obj = CreateDui(DUI_URL, DUI_W, DUI_H)
    CreateRuntimeTextureFromDuiHandle(dui.txd, dui.tex, GetDuiHandle(dui.obj))
    alpha, target = 0.0, 0.0
end

function Backdrop.destroy()
    if dui.obj then DestroyDui(dui.obj) end
    dui.obj, dui.queue = nil, {}
    quad, wall = nil, nil
    alpha, target = 0.0, 0.0
end

-- Messages sent before the page has loaded are kept and sent once it is up.
function Backdrop.send(action, data)
    if not dui.obj then return end
    local payload = json.encode({ action = action, data = data })
    if IsDuiAvailable(dui.obj) and #dui.queue == 0 then
        SendDuiMessage(dui.obj, payload)
    else
        dui.queue[#dui.queue + 1] = payload
    end
end

local function flush()
    if #dui.queue == 0 or not dui.obj or not IsDuiAvailable(dui.obj) then return end
    for _, payload in ipairs(dui.queue) do SendDuiMessage(dui.obj, payload) end
    dui.queue = {}
end

-- Put the backdrop behind a character. camPos is the detail camera for that character, forward points
-- from the characters to the camera, right is screen-right. pedPos is the ped's waist, feetZ its floor.
-- Returns where the floor and the ped are on the page: { scale = px per metre, floor = y, centre = x }.
function Backdrop.place(camPos, forward, right, pedPos, feetZ)
    if not enabled() then return nil end
    local detail = Scene.settings.Detail
    local up = vector3(0.0, 0.0, 1.0)
    local depth = detail.Distance + OFFSET
    local halfH = depth * math.tan(math.rad(detail.Fov) / 2.0)
    local halfW = halfH * (DUI_W / DUI_H)
    local centre = camPos - forward * depth
    quad = {
        tl = centre - right * halfW + up * halfH,
        tr = centre + right * halfW + up * halfH,
        br = centre + right * halfW - up * halfH,
        bl = centre - right * halfW - up * halfH,
    }
    local wallCentre = pedPos - forward * (OFFSET + 0.06)
    wall = {
        tl = wallCentre - right * WALL_HALF_WIDTH + up * WALL_ABOVE,
        tr = wallCentre + right * WALL_HALF_WIDTH + up * WALL_ABOVE,
        br = wallCentre + right * WALL_HALF_WIDTH - up * WALL_BELOW,
        bl = wallCentre - right * WALL_HALF_WIDTH - up * WALL_BELOW,
    }

    local scale = DUI_H / (halfH * 2.0)
    local d = pedPos - centre
    local side = d.x * right.x + d.y * right.y   -- how far right of the page centre the ped stands
    return {
        scale = scale,
        floor = (centre.z + halfH - feetZ) * scale,
        centre = DUI_W / 2.0 + side * scale,
    }
end

-- instant = true jumps straight there (used while the UI's shutter covers the screen).
function Backdrop.show(instant)
    target = 255.0
    if instant then alpha = target end
end

function Backdrop.hide(instant)
    target = 0.0
    if instant then alpha = target end
end

local function poly(a, b, c, al)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, 0, 0, 0, al)
end

local function spritePoly(a, b, c, ua, va, ub, vb, uc, vc, tint, al)
    DrawSpritePoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, tint, tint, tint, al, TXD, dui.tex,
        ua, va, 1.0, ub, vb, 1.0, uc, vc, 1.0)
end

-- Called every frame by the scene. dt is the frame time in ms.
function Backdrop.draw(dt)
    if not enabled() or not dui.obj then return end
    flush()

    local step = 255.0 * dt / FADE_MS
    if alpha < target then alpha = math.min(target, alpha + step)
    elseif alpha > target then alpha = math.max(target, alpha - step) end
    if alpha <= 1.0 or not quad then return end

    local a = math.floor(alpha)

    -- black wall, both windings so it shows whichever side the game culls
    poly(wall.tl, wall.bl, wall.br, a)
    poly(wall.tl, wall.br, wall.tr, a)
    poly(wall.tl, wall.br, wall.bl, a)
    poly(wall.tl, wall.tr, wall.br, a)

    if not IsDuiAvailable(dui.obj) then return end
    local u0, u1, v0, v1 = 0.0, 1.0, 0.0, 1.0
    local tint = BRIGHTNESS

    spritePoly(quad.tl, quad.bl, quad.br, u0, v0, u0, v1, u1, v1, tint, a)
    spritePoly(quad.tl, quad.br, quad.tr, u0, v0, u1, v1, u1, v0, tint, a)
    spritePoly(quad.tl, quad.br, quad.bl, u0, v0, u1, v1, u0, v1, tint, a)
    spritePoly(quad.tl, quad.tr, quad.br, u0, v0, u1, v0, u1, v1, tint, a)
end

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Backdrop.destroy() end
end)
