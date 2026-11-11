// Browser preview only: a stand-in for the aerial camera in client/spawn.lua, with the same maths,
// so the spawn map UI can be built and checked without the game.
import type { SpawnData, SpawnFrame } from './types'

const PITCH = -58
const FOV = 48
const MIN_DIST = 70
const MAX_DIST = 4200
const FOCUS_DIST = 240
const SMOOTH_MS = 110

export const MOCK_SPAWN: SpawnData = {
  server: 'Bakery Roleplay',
  firstName: 'Tahokani',
  lastName: 'Huang',
  isNew: false,
  freeSpawn: true,
  homesEnabled: true,
  selected: 'last',
  points: [
    { id: 'last', kind: 'last', label: 'Last location', zone: 'Pillbox Hill', street: 'Elgin Ave' },
    { id: 'home1', kind: 'home', label: '3671 Whispymound Dr', zone: 'Vinewood Hills', street: 'Whispymound Dr', distance: 1290 },
    { id: 'home2', kind: 'home', label: 'Apartment 12', zone: 'Your home', nopin: true },
    { id: 'loc1', kind: 'location', label: 'Legion Square', zone: 'Legion Square', street: 'Strawberry Ave', distance: 230 },
    { id: 'loc2', kind: 'location', label: 'Mission Row PD', zone: 'Mission Row', street: 'Sinner St', distance: 310 },
    { id: 'loc3', kind: 'location', label: 'Pink Cage Motel', zone: 'Alta', street: 'Meteor St', distance: 520 },
    { id: 'loc4', kind: 'location', label: 'LS International', zone: 'Los Santos International Airport', street: 'New Empire Way', distance: 2390 },
    { id: 'loc5', kind: 'location', label: 'Sandy Shores', zone: 'Sandy Shores', street: 'Marina Dr', distance: 4520 },
    { id: 'loc6', kind: 'location', label: 'Paleto Bay', zone: 'Paleto Bay', street: 'Paleto Blvd', distance: 7150 },
  ],
}

const WORLD: Record<string, [number, number, number]> = {
  last: [270, -720, 30],
  home1: [-174, 497, 137],
  loc1: [195, -934, 30],
  loc2: [428, -984, 30],
  loc3: [327, -205, 54],
  loc4: [-1036, -2732, 14],
  loc5: [1836, 3672, 34],
  loc6: [80, 6424, 32],
}

interface Cam { x: number; y: number; z: number; heading: number; dist: number }
export const camera = {
  want: { x: 270, y: -720, z: 30, heading: 0, dist: 1300 } as Cam,
  cur: { x: 270, y: -720, z: 30, heading: -25, dist: MAX_DIST } as Cam,
  keys: { rotate: 0, x: 0, y: 0 },
}

const clamp = (n: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, n))
const rad = (d: number) => (d * Math.PI) / 180
const aspect = () => window.innerWidth / window.innerHeight

function viewSize(dist: number) {
  const height = 2 * dist * Math.tan(rad(FOV) / 2)
  return { tall: height / Math.sin(rad(-PITCH)), wide: height * aspect() }
}

function axes(heading: number) {
  const h = rad(heading)
  return { right: [Math.cos(h), Math.sin(h)], up: [-Math.sin(h), Math.cos(h)] }
}

export function cameraBasis(c: Cam = camera.cur) {
  const p = rad(PITCH), h = rad(c.heading)
  const f = [-Math.sin(h) * Math.cos(p), Math.cos(h) * Math.cos(p), Math.sin(p)]
  const r = [Math.cos(h), Math.sin(h), 0]
  const u = [Math.sin(h) * Math.sin(p), -Math.cos(h) * Math.sin(p), Math.cos(p)]
  const pos = [c.x - f[0] * c.dist, c.y - f[1] * c.dist, c.z - f[2] * c.dist]
  return { f, r, u, pos }
}

/** World point to screen fractions, like GetScreenCoordFromWorldCoord. */
export function project(x: number, y: number, z: number, b = cameraBasis()) {
  const d = [x - b.pos[0], y - b.pos[1], z - b.pos[2]]
  const zc = d[0] * b.f[0] + d[1] * b.f[1] + d[2] * b.f[2]
  if (zc <= 1) return null
  const t = Math.tan(rad(FOV) / 2)
  const xc = d[0] * b.r[0] + d[1] * b.r[1] + d[2] * b.r[2]
  const yc = d[0] * b.u[0] + d[1] * b.u[1] + d[2] * b.u[2]
  return { x: 0.5 + xc / (zc * t * aspect()) / 2, y: 0.5 - yc / (zc * t) / 2 }
}

function clampWant() {
  const w = camera.want
  w.x = clamp(w.x, -3900, 4400)
  w.y = clamp(w.y, -4100, 8100)
  w.dist = clamp(w.dist, MIN_DIST, MAX_DIST)
}

export function mockSpawnCallback(event: string, data: any): unknown {
  const w = camera.want
  if (event === 'spawnPan') {
    const { right, up } = axes(w.heading)
    const { tall, wide } = viewSize(camera.cur.dist)
    w.x += -right[0] * data.dx * wide + up[0] * data.dy * tall
    w.y += -right[1] * data.dx * wide + up[1] * data.dy * tall
  } else if (event === 'spawnZoom') {
    if (data.level !== undefined) w.dist = MIN_DIST * (MAX_DIST / MIN_DIST) ** (1 - clamp(data.level, 0, 1))
    else w.dist *= 0.82 ** data.steps
  } else if (event === 'spawnKeys') {
    camera.keys = { rotate: data.rotate ?? 0, x: data.x ?? 0, y: data.y ?? 0 }
  } else if (event === 'spawnNorth') {
    w.heading = 0
  } else if (event === 'spawnFocus') {
    const p = WORLD[data.id]
    if (p) [w.x, w.y, w.z, w.dist] = [p[0], p[1], p[2], Math.min(w.dist, FOCUS_DIST)]
  } else if (event === 'spawnDrop') {
    const b = cameraBasis()
    const t = Math.tan(rad(FOV) / 2)
    const sx = (data.x - 0.5) * 2 * t * aspect(), sy = (0.5 - data.y) * 2 * t
    const dir = [0, 1, 2].map((i) => b.f[i] + b.r[i] * sx + b.u[i] * sy)
    if (dir[2] >= -0.01) return { ok: false, error: "You can't spawn there." }
    const k = (camera.cur.z - b.pos[2]) / dir[2]
    const x = b.pos[0] + dir[0] * k, y = b.pos[1] + dir[1] * k
    if (y < -3300 && x < -1500) return { ok: false, error: "That's in the water. Pick some dry land." }
    WORLD.drop = [x, y, camera.cur.z]
    return { ok: true, point: { id: 'drop', kind: 'drop', label: 'Dropped pin', zone: 'Pillbox Hill', street: 'Power St' } }
  } else if (event === 'spawnConfirm') {
    const p = WORLD[data.id]
    if (p) [w.x, w.y, w.z, w.dist] = [p[0], p[1], p[2], 26]
    // as client/spawn.lua: drop down, shut the blades, spawn, open them on the world, then the intro
    const post = (ms: number, action: string, payload?: unknown) => window.setTimeout(() => window.postMessage({ action, data: payload }, '*'), ms)
    post(1100, 'shutter', { closed: true, label: 'Waking up' })
    post(1450, 'spawn', false)
    post(2300, 'shutter', { closed: false })
    post(5600, 'intro', { server: 'Bakery Roleplay', firstName: MOCK_SPAWN.firstName, lastName: MOCK_SPAWN.lastName, isNew: false, zone: 'Legion Square', street: 'Strawberry Ave', cross: 'Vespucci Blvd', indoors: false, time: '11:04 PM', partOfDay: 'Night', weather: 'Clear', duration: 6500 })
  }
  clampWant()
  return { ok: true }
}

let running = false
let lastKey = ''
/** Runs the stand-in camera and posts spawnFrame messages, as client/spawn.lua does. */
export function startMockCamera() {
  if (running) return
  running = true
  let last = performance.now()
  const tick = (now: number) => {
    const dt = Math.min(100, now - last)
    last = now
    const { want: w, cur: c, keys } = camera
    if (keys.rotate) w.heading = (w.heading + keys.rotate * 70 * dt / 1000) % 360
    if (keys.x || keys.y) {
      const { right, up } = axes(w.heading)
      const move = viewSize(c.dist).tall * 0.9 * dt / 1000
      w.x += (right[0] * keys.x + up[0] * keys.y) * move
      w.y += (right[1] * keys.x + up[1] * keys.y) * move
      clampWant()
    }
    const t = 1 - Math.exp(-dt / SMOOTH_MS)
    c.x += (w.x - c.x) * t
    c.y += (w.y - c.y) * t
    c.z += (w.z - c.z) * t
    c.heading = (c.heading + (((w.heading - c.heading + 540) % 360) - 180) * t + 360) % 360
    c.dist = Math.exp(Math.log(c.dist) + (Math.log(w.dist) - Math.log(c.dist)) * t * 0.8)

    const b = cameraBasis(c)
    const pins = Object.entries(WORLD).map(([id, p]) => {
      const s = project(p[0], p[1], p[2] + 1, b)
      return { id, x: s?.x ?? -1, y: s?.y ?? -1, visible: !!s && s.x > -0.1 && s.x < 1.1 && s.y > -0.1 && s.y < 1.1 }
    })
    const frame: SpawnFrame = {
      heading: c.heading,
      zoom: 1 - Math.log(c.dist / MIN_DIST) / Math.log(MAX_DIST / MIN_DIST),
      altitude: Math.round(b.pos[2] - c.z),
      pins,
    }
    const key = `${frame.heading.toFixed(1)}|${frame.zoom.toFixed(3)}|${pins.map((p) => `${p.x.toFixed(4)}:${p.y.toFixed(4)}`).join('|')}`
    if (key !== lastKey) {
      lastKey = key
      window.postMessage({ action: 'spawnFrame', data: frame }, '*')
    }
    requestAnimationFrame(tick)
  }
  requestAnimationFrame(tick)
}
