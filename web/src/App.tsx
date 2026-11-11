import { useCallback, useEffect, useRef, useState } from 'react'
import { isNui, nui, useNuiEvent } from '@/lib/nui'
import { shownSlots } from '@/lib/utils'
import { mockAnchors, MOCK_INTRO, MOCK_OPEN } from '@/lib/mock'
import { MOCK_SPAWN, startMockCamera } from '@/lib/mockMap'
import type { Anchor, IntroData, NewCharacter, OpenData, Result, SpawnData, View } from '@/lib/types'
import { setCustomLogo, Toast } from '@/components/common'
import DevStage from '@/components/DevStage'
import DevMap from '@/components/DevMap'
import TopBar from '@/components/TopBar'
import Intro from '@/components/Intro'
import Shutter, { ShutterProvider, useShutter, useShutterState } from '@/components/Shutter'
import Lineup from '@/views/Lineup'
import Detail from '@/views/Detail'
import Create from '@/views/Create'
import SpawnMap from '@/views/SpawnMap'

const typing = (target: EventTarget | null) => target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement

// Browser preview: the whole flow can be walked through (character screen, spawn map, intro).
// #spawn opens straight on the spawn map, #intro on the introduction, ?logo=<url> tries a custom logo.
const hash = !isNui && typeof window !== 'undefined' ? window.location.hash : ''
const previewIntro = hash === '#intro'
const previewSpawn = hash === '#spawn'
if (previewSpawn) startMockCamera()
if (!isNui && typeof window !== 'undefined') setCustomLogo(new URLSearchParams(window.location.search).get('logo'))

export default function App() {
  const [shutterState, shutter] = useShutterState()
  useNuiEvent<{ closed: boolean; label?: string | null } | false>('shutter', (d) => (d && d.closed ? shutter.close(d.label ?? null) : shutter.open()))

  const [intro, setIntro] = useState<{ id: number; data: IntroData } | null>(previewIntro ? { id: 0, data: MOCK_INTRO } : null)
  useNuiEvent<IntroData | false>('intro', (d) => setIntro(d ? { id: Date.now(), data: d } : null))
  const endIntro = useCallback(() => setIntro(null), [])

  // The spawn map, once a character has been picked (client/spawn.lua).
  const [spawn, setSpawn] = useState<{ id: number; data: SpawnData } | null>(previewSpawn ? { id: 0, data: MOCK_SPAWN } : null)
  const [world, setWorld] = useState(previewIntro)   // browser preview: stand-in for the game world after spawning
  useNuiEvent<SpawnData | false>('spawn', (d) => {
    if (d) setCustomLogo(d.logo)
    setSpawn(d ? { id: Date.now(), data: d } : null)
    if (!isNui && !d) setWorld(true)
  })
  useNuiEvent('open', () => setWorld(false))

  // The game answers with the server's own logo, if it has one.
  useEffect(() => {
    if (isNui) nui<{ logo?: string | null }>('ready').then((r) => setCustomLogo(r?.logo))
  }, [])

  return (
    <ShutterProvider value={shutter}>
      {!isNui && world && !spawn && <div className="fixed inset-0 bg-[radial-gradient(ellipse_at_60%_30%,#4a5160,#14161b_75%)]" />}
      {!isNui && spawn && <div className="fixed inset-0"><DevMap /></div>}
      {!previewIntro && !previewSpawn && <Selection />}
      {spawn && <SpawnMap key={spawn.id} data={spawn.data} />}
      {intro && <Intro key={intro.id} data={intro.data} onDone={endIntro} />}
      <Shutter {...shutterState} />
    </ShutterProvider>
  )
}

function Selection() {
  const [data, setData] = useState<OpenData | null>(isNui ? null : MOCK_OPEN)
  const [anchors, setAnchors] = useState<Anchor[]>(isNui ? [] : mockAnchors(MOCK_OPEN))
  const [view, setView] = useState<View>('lineup')
  const [slot, setSlot] = useState(1)
  const [hover, setHover] = useState<number | null>(null)
  const [toast, setToast] = useState<string | null>(null)
  const toastTimer = useRef(0)

  const shutter = useShutter()
  const busy = useRef(false)

  const notify = useCallback((message?: string) => {
    window.clearTimeout(toastTimer.current)
    setToast(message || 'Something went wrong.')
    toastTimer.current = window.setTimeout(() => setToast(null), 4500)
  }, [])

  const close = useCallback(() => shutter.close(null), [shutter])
  const open = useCallback(() => shutter.open(), [shutter])

  // Close, change everything (game camera + UI), open. One change at a time.
  const swapBehind = useCallback(async (swap: () => Promise<unknown> | void) => {
    if (busy.current) return
    busy.current = true
    await close()
    await swap()
    await open()
    busy.current = false
  }, [close, open])

  // The screen opens behind shut blades; they open once the game has faded in.
  const reveal = useCallback(() => {
    busy.current = true
    shutter.close(null)
    window.setTimeout(() => {
      shutter.open()
      busy.current = false
    }, isNui ? 900 : 400)
  }, [shutter])

  useNuiEvent<OpenData>('open', (d) => {
    setCustomLogo(d.logo)
    setData(d)
    setView('lineup')
    setHover(null)
    setToast(null)
    reveal()
  })
  useNuiEvent('close', () => {
    setData(null)
    setAnchors([])
  })
  useNuiEvent<Anchor[]>('anchors', (list) => setAnchors(list ?? []))

  useEffect(() => {
    if (!isNui) reveal()
  }, [reveal])

  const characters = data?.characters ?? []
  // only the slots standing in the line-up are browsed: characters, then one free slot
  const order = data ? shownSlots(data.characters, data.slots) : []
  const step = (from: number, dir: 1 | -1) => order[(order.indexOf(from) + dir + order.length) % order.length] ?? from

  // browser preview: the stand-in line-up follows the characters
  useEffect(() => {
    if (!isNui && data) setAnchors(mockAnchors(data))
  }, [data])
  const current = characters.find((c) => c.slot === slot)

  const hoverSlot = useCallback((s: number | null) => {
    setHover(s)
    nui('hover', { slot: s })
  }, [])

  const select = useCallback((s: number) => {
    if (!data) return
    const next = data.characters.some((c) => c.slot === s) ? 'detail' : 'create'
    if (s === slot && view === next) return
    swapBehind(async () => {
      setHover(null)
      nui('hover', { slot: null })
      setSlot(s)
      setView(next)
      await nui('select', { slot: s })
    })
  }, [data, slot, view, swapBehind])

  const back = useCallback(() => {
    swapBehind(async () => {
      setView('lineup')
      await nui('back')
    })
  }, [swapBehind])

  // Play / create: the shutter shuts and stays shut while the character loads; the spawn map
  // (or the world itself) opens it again.
  const load = useCallback(async (event: 'play' | 'create', payload: unknown) => {
    if (busy.current) return
    busy.current = true
    await shutter.close(event === 'play' ? 'Entering the city' : 'Creating character')
    const res = await nui<Result>(event, payload, 90000)
    if (!res.ok) {
      await open()
      notify(res.error)
    }
    busy.current = false
  }, [shutter, open, notify])

  const play = useCallback(() => {
    if (current && !current.disabled) load('play', { slot: current.slot })
  }, [current, load])

  const create = useCallback((character: NewCharacter) => load('create', character), [load])

  const remove = useCallback(async () => {
    if (!current || !data || busy.current) return
    const res = await nui<Result>('delete', { slot: current.slot })
    if (res.characters) setData({ ...data, characters: res.characters, slots: res.slots ?? data.slots })
    if (res.ok) back()
    else notify(res.error)
  }, [current, data, back, notify])

  useEffect(() => {
    if (!data) return
    const onKey = (e: KeyboardEvent) => {
      if (busy.current) return
      const key = e.key.toLowerCase()
      const prev = step(slot, -1)
      const next = step(slot, 1)

      if (view === 'lineup') {
        if (key === 'arrowleft' || key === 'arrowright' || key === 'a' || key === 'd') {
          const dir = key === 'arrowleft' || key === 'a' ? -1 : 1
          hoverSlot(hover === null ? order[dir === 1 ? 0 : order.length - 1] : step(hover, dir))
        } else if (key === 'enter' && hover) {
          select(hover)
        }
        return
      }

      if (key === 'escape') return back()
      if (typing(e.target)) return
      if (view === 'detail' && key === 'enter') play()
      else if (key === 'q' || (view === 'detail' && key === 'arrowleft')) select(prev)
      else if (key === 'e' || (view === 'detail' && key === 'arrowright')) select(next)
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [data, view, slot, hover, hoverSlot, select, back, play])

  if (!data) return null

  return (
    <div className="fixed inset-0 overflow-clip">
      {!isNui && <DevStage view={view} data={data} slot={slot} anchors={anchors} hover={hover} />}

      {view === 'lineup' && (
        <Lineup anchors={anchors} characters={characters} slots={data.slots} hover={hover} onHover={hoverSlot} onSelect={select} />
      )}
      {view === 'detail' && current && (
        <Detail key={current.id} data={data} character={current} onPlay={play} onDelete={remove} />
      )}
      {view === 'create' && !current && (
        <Create key={slot} data={data} slot={slot} onCreate={create} />
      )}

      <TopBar
        server={data.server}
        slot={view === 'lineup' ? null : slot}
        slots={data.slots}
        onBack={back}
        onPrev={() => select(step(slot, -1))}
        onNext={() => select(step(slot, 1))}
      />

      <Toast message={toast} />
    </div>
  )
}
