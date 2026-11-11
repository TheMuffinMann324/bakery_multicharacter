# bakery_multicharacter

Multicharacter and spawn selector for **QBX**, **QBCore** and **ESX**.

**[Preview video](https://youtu.be/yEcGf1Lzots)** · More scripts at [bakeryscripts.com](https://bakeryscripts.com)

## Features

- **Character line-up**: your characters stand in the world, each with their own idle, plus one see-through slot
  to create the next. Scales from 1 to many slots.
- **Character details**: name, job, cash, bank, age, phone, with a studio backdrop and a height chart behind them.
- **Character creation**: name, date of birth, gender (the ped swaps live), nationality (QB) or height (ESX).
- **Live spawn map**: an aerial camera over the real city. Drag, zoom and rotate, then pick a pin:
  - your last location
  - your own houses and apartments (spawn inside them)
  - preset locations from the config
  - or drag the little guy anywhere on the map
- **Wake-up**: the character wakes up and gets up after spawning, with the camera following them.
- **Intro**: name, area, time and weather on screen once you're in the world.
- **Character creator**: new characters get illenium-appearance / qb-clothing / esx_skin, and the intro waits for it.
- **Starting apartments** (QBX): new characters can pick a qbx_properties apartment first.
- Smooth shutter transitions between every screen, your own logo, routing bucket per player while choosing.

## Supports

| | |
| --- | --- |
| Frameworks | qbx_core, qb-core, es_extended (Legacy) |
| Clothing | illenium-appearance, qb-clothing, fivem-appearance, skinchanger / esx_skin |
| Housing | rtx_housing, nolag_properties, rcore_housing, kartik-properties, vms_housing, qs-housing, qbx_properties, qb-houses |
| Weather sync (paused while choosing) | qb-weathersync, cd_easytime, Renewed-Weathersync |

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql)
- One of the frameworks above

## Install

1. Remove your old character / spawn resources: `qb-multicharacter`, `esx_multicharacter`, `qb-spawn`, `qbx_spawn`.
2. Put `bakery_multicharacter` in your resources and start it **after** your framework:

   ```cfg
   ensure ox_lib
   ensure oxmysql
   ensure qbx_core        # or qb-core / es_extended
   ensure bakery_multicharacter
   ```

3. Framework notes:
   - **QBX**: set `useExternalCharacters = true` in `qbx_core/config/client.lua`. If you use qbx_properties starting
     apartments, also set `characters.startingApartment = false` there.
   - **QBCore**: nothing else.
   - **ESX**: nothing else on current ESX Legacy (this resource provides `esx_multicharacter`). If the console says
     `Config.Multichar` is off, turn it on in es_extended's config.

## Config

Everything is in `config.lua`:

| Option | What it does |
| --- | --- |
| `ServerName`, `Logo` | Name and logo shown on the screens. `Logo` takes an image link or a file in the `logo` folder. |
| `Slots`, `PlayerSlots` | Character slots per player, and per-player overrides. |
| `AllowDelete` | Players can delete their own characters. |
| `LogoutCommand` | Command back to the character screen (ace `command.logout`). Other resources: `exports.bakery_multicharacter:Logout(source)`. |
| `LineupCoords` | Where the line-up stands. Needs flat, open ground. |
| `HeightUnits` | Height chart in `imperial` or `metric`. |
| `Intro`, `WakeUp` | Turn the intro and the wake-up on or off. |
| `Spawn.LastLocation` | Offer the spot they logged out at. |
| `Spawn.FreeSpawn` | Drag the little guy anywhere on the map. |
| `Spawn.Homes` | Spawn inside owned houses / apartments (`'auto'`, a housing script name, or `false`). |
| `Spawn.StartingApartment` | QBX: new characters pick a qbx_properties apartment first. |
| `Spawn.Locations` | Preset spawn points. |
| `Framework`, `ESX`, `Debug` | Advanced: force a framework, ESX identifier/date format, extra console logs. |

## Controls on the spawn map

Drag to move, scroll or `+` / `-` to zoom, `Q` / `E` to rotate, `N` for north, `1`-`9` for preset locations,
`L` for your last location, `Enter` to wake up.

## Adding support

- **Another housing script**: copy an adapter at the bottom of `bridge/housing.lua`.
- **Another clothing script**: fill in `Appearance.custom` in `bridge/appearance.lua` (how preview peds are dressed).

## Building the UI

The compiled UI is included in `web/dist`. Only needed if you edit it:

```bash
cd web
npm install
npm run dev     # browser preview with stand-in data (#spawn opens the spawn map)
npm run build
```
