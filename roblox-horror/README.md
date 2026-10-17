# The Hollow Manor (Roblox horror game)

A complete multiplayer horror round for Roblox. The whole map is built from code when the server starts. That covers the lobby chapel, the foggy graveyard, the manor with six rooms and a hallway, and the back garden with the exit gate.

**Goal:** sneak into the manor, find **3 keys**, unlock the exit door at the end of the hallway and run through the glowing gate in the garden before **The Pale** catches you.

## Play it

### Option A: just open it (easiest)
1. Download `HollowManor.rbxlx` from this folder.
2. Double-click it to open it in Roblox Studio.
3. Press **Play**. The map builds itself in a second or two. It's empty in edit mode because it's generated when the game runs.

### Option B: live-sync with Rojo (for editing the code)
1. Install Rojo: in VS Code, add the **Rojo** extension, or follow https://rojo.space/docs.
2. Install the Rojo plugin in Studio.
3. In this folder run `rojo serve`, then click **Connect** in the Studio Rojo plugin.
4. Press **Play**.

If Rojo can't set them, change these by hand: **Lighting → Technology = Future** and **Workspace → StreamingEnabled = off**.

## Controls

| | PC | Mobile |
|---|---|---|
| Move | WASD | Thumbstick |
| Flashlight | F | "Light" button |
| Sprint | Left Shift | "Run" button |
| Interact (doors, keys) | E | Tap prompt |

## How it plays

- **Lobby → round → results**, looping forever. Each round starts after a 20 s countdown.
- The 3 keys appear in random rooms every round. Candidate spots: parlor, library, nursery, dining hall, kitchen, bedroom, hallway and the mausoleum outside.
- **The Pale** sleeps in the master bedroom for 12 s, then hunts:
  - it **sees** you much further away when your **flashlight is on**, so turning it off lets you hide;
  - it **hears** you when you **sprint** nearby;
  - it smashes doors open, searches your last known position, and drifts toward survivors if it loses everyone.
- Picking up a key causes a **blackout** and draws the monster toward that spot.
- Your flashlight battery drains while it's on and slowly recharges while it's off. Stamina limits sprinting.

## Effects

- Future lighting, thick atmosphere fog, colour grading, bloom, depth of field
- Candles, lamps and sconces flicker. Lights near the monster stutter and die.
- Lightning flashes through the windows, with thunder
- Blackouts that make the portrait eyes glow red
- Fear effects as the monster gets close: red pulsing vignette, desaturation, blur, camera shake and heartbeat
- Jumpscare camera locked on the monster's face, then TV static
- Apparitions only you see: a pale girl standing behind you, and shadows darting across rooms
- Whispers, blood writing that appears on the walls as keys are found, and doors slamming by themselves
- Procedural animation: the monster's twitching walk, chase and attack poses; swinging chandeliers, meat hooks and pendulum; rocking chair and rocking horse; a rattling wardrobe; floating keys; a doll and a statue whose heads turn to stare at you
- Fog, dust, smoke, sparkle and fire particles

## Sounds

Roblox doesn't ship free horror sounds you can reference by ID. To add them:

1. In Studio, open **Toolbox → Audio** and search for things like "horror ambience", "heartbeat", "jumpscare", "thunder" or "door creak".
2. Copy each sound's ID.
3. Paste the IDs into `src/shared/Config.luau` under `Config.Sounds`, for example `Jumpscare = "rbxassetid://123456789"`.

Empty entries are skipped, so the game works without sounds. It's much scarier with them.

## Tweaking

Everything tunable is in `src/shared/Config.luau`: round length, keys needed, monster speeds, sight and hearing ranges, flashlight battery and stamina.

## Code layout

```
src/
  shared/Config.luau          settings
  server/Main.server.luau     lighting, round loop, keys, exit, scares
  server/MapBuilder.luau      builds the whole map
  server/Monster.luau         monster rig + AI (pathfinding, sight, hearing)
  client/Main.client.luau     wires everything up, objective text
  client/UI.luau              HUD, vignette, flashes, static
  client/Controls.luau        flashlight, sprint, battery, stamina, head bob
  client/Effects.luau         lights, fear, lightning, jumpscare, ghosts, sounds
  client/Animator.luau        monster animation + swinging/rocking/staring props
```

Note: the server deletes `Baseplate`, the default `SpawnLocation` and any existing **Terrain** when it starts. Use an empty place.
