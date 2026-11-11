export type Framework = 'qb' | 'qbx' | 'esx'
export type Gender = 'male' | 'female'

export interface Character {
  slot: number
  /** citizenid (QBCore / QBX) or identifier (ESX) */
  id: string
  firstName: string
  lastName: string
  /** YYYY-MM-DD */
  dob?: string
  gender: Gender
  nationality?: string
  phone?: string
  height?: number
  cash: number
  bank: number
  job?: string
  grade?: string
  gang?: string
  /** unix seconds */
  lastPlayed?: number
  disabled?: boolean
}

export interface Rules {
  minAge: number
  maxAge: number
  nameMin: number
  nameMax: number
  /** QBCore / QBX ask for a nationality */
  nationality: boolean
  defaultNationality: string
  /** ESX asks for a height (cm) */
  height: false | { min: number; max: number }
}

/** Sent by client/main.lua when the screen opens. */
export interface OpenData {
  characters: Character[]
  slots: number
  server: string
  framework: Framework
  allowDelete: boolean
  deleteHold: number
  rules: Rules
  /** server time, unix seconds */
  now: number
  /** Config.Logo as a link, or null for the default */
  logo?: string | null
}

/** Where a slot is on screen, as fractions of the screen (client/scene.lua). */
export interface Anchor {
  slot: number
  x: number
  top: number
  bottom: number
  width: number
  visible: boolean
}

export interface Result {
  ok: boolean
  error?: string
  characters?: Character[]
  slots?: number
}

export interface NewCharacter {
  slot: number
  firstName: string
  lastName: string
  dob: { d: number; m: number; y: number }
  gender: Gender
  nationality?: string
  height?: number
}

/** What the backdrop behind the character is told (web/src/dui). */
export interface PosterData {
  server: string
  slot: number
  total: number
  empty: boolean
  /** page pixels per metre, filled in by client/backdrop.lua */
  scale?: number
  /** page y of the floor under the character */
  floor?: number
  /** page x of the character */
  centre?: number
  /** height chart in feet and inches (default) or metres */
  units?: 'imperial' | 'metric'
}

/** The introduction once the character is in the world (client/intro.lua). */
export interface IntroData {
  server: string
  firstName: string
  lastName: string
  isNew: boolean
  zone: string
  street?: string
  cross?: string
  indoors: boolean
  time: string
  partOfDay: string
  weather?: string
  /** ms on screen */
  duration: number
}

export type View = 'lineup' | 'detail' | 'create'

/** One place on the spawn map (client/spawn.lua). */
export interface SpawnPoint {
  id: string
  /** drop = where the little guy was dropped (Config.Spawn.FreeSpawn) */
  /** home = the character's own house / apartment (Config.Spawn.Homes) */
  kind: 'last' | 'location' | 'drop' | 'home'
  label: string
  zone: string
  street?: string
  /** metres from where the character last was */
  distance?: number
  /** a home with no known door: no pin on the map */
  nopin?: boolean
}

/** Sent when the spawn map opens. */
export interface SpawnData {
  server: string
  logo?: string | null
  points: SpawnPoint[]
  /** the little guy can be dragged onto the map (Config.Spawn.FreeSpawn) */
  freeSpawn: boolean
  /** a housing script is running (Config.Spawn.Homes), so the properties section shows even when empty */
  homesEnabled?: boolean
  /** point in focus when the map opens */
  selected?: string | null
  firstName?: string
  lastName?: string
  isNew: boolean
}

/** Where everything is on screen, sent by the game whenever the camera moves. */
export interface SpawnFrame {
  /** camera heading, degrees (0 = north) */
  heading: number
  /** 0 = whole city, 1 = street level */
  zoom: number
  /** metres above the ground */
  altitude: number
  pins: { id: string; x: number; y: number; visible: boolean }[]
}
