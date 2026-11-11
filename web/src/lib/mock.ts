// Stand-in data for running the UI in a browser (npm run dev), where there is no game behind it.
import type { Anchor, IntroData, OpenData, Result } from './types'
import { shownSlots } from './utils'
import { MOCK_SPAWN, mockSpawnCallback, startMockCamera } from './mockMap'

const now = Math.floor(Date.now() / 1000)

export const MOCK_OPEN: OpenData = {
  server: 'Bakery Roleplay',
  framework: 'qb',
  slots: 8,
  allowDelete: true,
  deleteHold: 1.5,
  now,
  rules: { minAge: 18, maxAge: 90, nameMin: 2, nameMax: 16, nationality: true, defaultNationality: 'American', height: false },
  characters: [
    {
      slot: 1, id: 'D9AX0XM0', firstName: 'Tahokani', lastName: 'Huang', dob: '2003-11-20', gender: 'male',
      nationality: 'Greek', phone: '2587315062', cash: 6917, bank: 5070, job: 'Civilian', grade: 'Freelancer',
      gang: 'Ballas', lastPlayed: now - 40,
    },
    {
      slot: 3, id: 'K3J9X0AA', firstName: 'Marisol', lastName: 'Vandersteen', dob: '1994-02-08', gender: 'female',
      nationality: 'Dutch', phone: '3105550144', cash: 420, bank: 128450, job: 'Police', grade: 'Sergeant',
      lastPlayed: now - 3 * 86400,
    },
  ],
}

// Where the game would put each shown slot on screen.
export function mockAnchors(data: OpenData): Anchor[] {
  const order = shownSlots(data.characters, data.slots)
  const step = Math.min(0.18, 0.8 / order.length)
  return order.map((slot, i) => ({
    slot, x: 0.5 + (i - (order.length - 1) / 2) * step, top: 0.3, bottom: 0.76, width: step * 0.9, visible: true,
  }))
}

export const MOCK_INTRO: IntroData = {
  server: 'Bakery Roleplay', firstName: 'Tahokani', lastName: 'Huang', isNew: false,
  zone: 'Legion Square', street: 'Strawberry Ave', cross: 'Vespucci Blvd', indoors: false,
  time: '11:04 PM', partOfDay: 'Night', weather: 'Clear', duration: 6500,
}

const wait = (ms: number) => new Promise((r) => setTimeout(r, ms))

export async function mockNui(event: string, data?: unknown): Promise<unknown> {
  if (event.startsWith('spawn')) return mockSpawnCallback(event, data ?? {})
  if (event === 'play' || event === 'create') {
    // what the game does: load the character, take the character screen down, open the spawn map
    await wait(1400)
    window.postMessage({ action: 'close' }, '*')
    startMockCamera()
    window.setTimeout(() => window.postMessage({ action: 'spawn', data: { ...MOCK_SPAWN, isNew: event === 'create' } }, '*'), 900)
    return { ok: true } satisfies Result
  }
  if (event === 'delete') {
    await wait(300)
    const slot = (data as { slot: number }).slot
    MOCK_OPEN.characters = MOCK_OPEN.characters.filter((c) => c.slot !== slot)
    return { ok: true, characters: MOCK_OPEN.characters, slots: MOCK_OPEN.slots } satisfies Result
  }
  return { ok: true }
}
