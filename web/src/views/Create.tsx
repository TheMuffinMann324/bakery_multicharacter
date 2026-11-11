import { useEffect, useRef, useState, type FormEvent, type ReactNode } from 'react'
import { ChevronRight } from 'lucide-react'
import { ageOn, cn, realDate } from '@/lib/utils'
import { nui } from '@/lib/nui'
import type { Gender, NewCharacter, OpenData } from '@/lib/types'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Kbd, SlotNumber } from '@/components/common'
import { Dock } from '@/views/Detail'

const digits = (value: string, max: number) => value.replace(/\D/g, '').slice(0, max)

// A new character for an empty slot, laid out in the same bottom dock as the details.
// The gender switch swaps the ped standing above it.
export default function Create({
  data, slot, onCreate,
}: {
  data: OpenData
  slot: number
  onCreate: (character: NewCharacter) => void
}) {
  const rules = data.rules
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [day, setDay] = useState('')
  const [month, setMonth] = useState('')
  const [year, setYear] = useState('')
  const [gender, setGender] = useState<Gender>('male')
  const [nationality, setNationality] = useState(rules.defaultNationality)
  const [height, setHeight] = useState('183')   // 6 ft, the default ped height
  const [error, setError] = useState<string | null>(null)
  const firstRef = useRef<HTMLInputElement>(null)
  const monthRef = useRef<HTMLInputElement>(null)
  const yearRef = useRef<HTMLInputElement>(null)

  useEffect(() => firstRef.current?.focus({ preventScroll: true }), [])

  // the ped above the form follows the gender switch
  useEffect(() => {
    nui('preview', { slot, gender })
  }, [slot, gender])

  // Date of birth: digits that don't fit carry on into the next box, so typing fast or pasting 14031998 works.
  const fillDate = (from: 'day' | 'month' | 'year', raw: string) => {
    let rest = raw.replace(/\D/g, '')
    if (from === 'day') {
      setDay(rest.slice(0, 2))
      if (rest.length < 2) return
      rest = rest.slice(2)
      if (!rest) return monthRef.current?.focus({ preventScroll: true })
      from = 'month'
    }
    if (from === 'month') {
      setMonth(rest.slice(0, 2))
      if (rest.length < 2) return monthRef.current?.focus({ preventScroll: true })
      rest = rest.slice(2)
      yearRef.current?.focus({ preventScroll: true })
      if (!rest) return
    }
    setYear(rest.slice(0, 4))
  }

  const check = (): string | null => {
    const nameOk = (name: string) => {
      const n = name.trim()
      return n.length >= rules.nameMin && n.length <= rules.nameMax && !/[\d!-&(-,.-/:-@[-`{-~]/.test(n)
    }
    if (!nameOk(firstName) || !nameOk(lastName)) return `Names are ${rules.nameMin}-${rules.nameMax} letters, without numbers or symbols.`
    const d = Number(day), m = Number(month), y = Number(year)
    if (!day || !month || year.length !== 4 || !realDate(y, m, d)) return 'Enter a real date of birth.'
    const age = ageOn(y, m, d, data.now)
    if (age < rules.minAge || age > rules.maxAge) return `Characters are ${rules.minAge}-${rules.maxAge} years old.`
    if (rules.height) {
      const h = Number(height)
      if (!h || h < rules.height.min || h > rules.height.max) return `Height is ${rules.height.min}-${rules.height.max} cm.`
    }
    return null
  }

  const submit = (e: FormEvent) => {
    e.preventDefault()
    const problem = check()
    setError(problem)
    if (problem) return
    onCreate({
      slot,
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      dob: { d: Number(day), m: Number(month), y: Number(year) },
      gender,
      nationality: rules.nationality ? nationality.trim() : undefined,
      height: rules.height ? Number(height) : undefined,
    })
  }

  const preview = [firstName.trim(), lastName.trim()].filter(Boolean).join(' ')
  // their age, as soon as the date of birth is a real one
  const dobOk = day && month && year.length === 4 && realDate(Number(year), Number(month), Number(day))
  const age = dobOk ? ageOn(Number(year), Number(month), Number(day), data.now) : null
  const ageOk = age !== null && age >= rules.minAge && age <= rules.maxAge

  return (
    <form onSubmit={submit}>
      <Dock>
        {/* who */}
        <div className="min-w-[14rem] flex-1">
          <div className="flex items-center gap-1.5">
            <SlotNumber slot={slot} active className="size-6 text-[0.625rem]" />
            <span className="inline-flex h-6 items-center rounded-[0.25rem] border border-dashed border-white/20 px-2 text-[0.59375rem] font-extrabold tracking-[0.12em] text-white/60 uppercase">
              New character
            </span>
          </div>
          <h2 className={cn('display mt-3 truncate text-[3rem]', preview ? 'text-white' : 'text-white/25')}>
            {preview || 'Your name here'}
          </h2>
          <p className={cn('mt-2 h-4 truncate text-[0.65625rem] font-extrabold uppercase', error ? 'tracking-[0.06em] text-bad' : 'tracking-[0.14em] text-white/35')}>
            {error ?? 'Choose carefully, names are permanent'}
          </p>
        </div>

        {/* form */}
        <div className="grid w-[36rem] grid-cols-3 gap-x-3 gap-y-4">
          <Field label="First name" htmlFor="first">
            <Input id="first" ref={firstRef} autoComplete="off" spellCheck={false} maxLength={rules.nameMax} placeholder="John" value={firstName} onChange={(e) => setFirstName(e.target.value)} />
          </Field>
          <Field label="Last name" htmlFor="last">
            <Input id="last" autoComplete="off" spellCheck={false} maxLength={rules.nameMax} placeholder="Doe" value={lastName} onChange={(e) => setLastName(e.target.value)} />
          </Field>
          {rules.height ? (
            <Field label="Height (cm)" htmlFor="height">
              <Input id="height" inputMode="numeric" autoComplete="off" className="tnum" value={height} onChange={(e) => setHeight(digits(e.target.value, 3))} />
            </Field>
          ) : rules.nationality ? (
            <Field label="Nationality" htmlFor="nationality">
              <Input id="nationality" autoComplete="off" spellCheck={false} maxLength={rules.nameMax} value={nationality} onChange={(e) => setNationality(e.target.value)} />
            </Field>
          ) : <span />}

          <Field
            label={age === null ? 'Date of birth' : <>Date of birth <span className={cn('tnum ml-1', ageOk ? 'text-white' : 'text-bad')}>{age} yrs</span></>}
            htmlFor="day"
          >
            <div className="grid grid-cols-[1fr_1fr_1.5fr] gap-1">
              <Input id="day" inputMode="numeric" autoComplete="off" placeholder="DD" className="tnum px-1 text-center" value={day}
                onChange={(e) => fillDate('day', e.target.value)} />
              <Input ref={monthRef} inputMode="numeric" autoComplete="off" placeholder="MM" className="tnum px-1 text-center" value={month}
                onChange={(e) => fillDate('month', e.target.value)} />
              <Input ref={yearRef} inputMode="numeric" autoComplete="off" placeholder="YYYY" className="tnum px-1 text-center" value={year}
                onChange={(e) => setYear(digits(e.target.value, 4))} />
            </div>
          </Field>
          <Field label="Gender" className="col-span-2">
            <div className="grid h-11 grid-cols-2 gap-1 rounded-md border border-white/[0.08] bg-field p-1">
              {(['male', 'female'] as const).map((g) => (
                <button
                  key={g}
                  type="button"
                  onClick={() => setGender(g)}
                  className={cn(
                    'rounded-[0.25rem] text-[0.6875rem] font-extrabold tracking-[0.1em] uppercase transition-all',
                    gender === g ? 'bg-white text-ink' : 'text-white/45 hover:bg-white/[0.07] hover:text-white',
                  )}
                >
                  {g}
                </button>
              ))}
            </div>
          </Field>
        </div>

        {/* action */}
        <div className="w-[17rem]">
          <Button type="submit" size="xl" className="w-full justify-between">
            Create
            <span className="flex items-center gap-2"><Kbd className="bg-ink text-white shadow-none">Enter</Kbd><ChevronRight /></span>
          </Button>
          <p className="mt-2 flex h-8 items-center justify-center text-[0.625rem] font-extrabold tracking-[0.12em] text-white/25 uppercase">
            {rules.minAge}+ years · {rules.nameMin}-{rules.nameMax} letter names
          </p>
        </div>
      </Dock>
    </form>
  )
}

function Field({ label, htmlFor, className, children }: { label: ReactNode; htmlFor?: string; className?: string; children: ReactNode }) {
  return (
    <div className={className}>
      <Label htmlFor={htmlFor} className="mb-2">{label}</Label>
      {children}
    </div>
  )
}
