--!strict
-- Notizen und Tonband-Logs (Abschnitt 7, Hintergrund): Projekt THERMOPHAGE.
-- Kind: "Paper" (vergilbtes Papier), "Clipboard" (Klemmbrett mit Grundriss), "Tape" (CRT-Log)

export type Note = {
	Id: string,
	Title: string,
	Kind: string,
	Zone: string,
	Body: string,
}

local Notes: { [string]: Note } = {
	L1 = {
		Id = "L1",
		Title = "DESCENT BRIEFING",
		Kind = "Clipboard",
		Zone = "Lobby",
		Body = [[EREBOS RESEARCH STATION - RECOVERY TEAM

Contact with Erebos was lost 19 days ago.
Last transmission: "it is drawn to the heat - keep the lights off".

OBJECTIVES
1. Restore main power (Habitation fuse room).
2. Recover the sample key from the Bio-Labs.
3. Bring the cargo lift online (diesel generator).
4. Scram the reactor - all four control rods.
5. Extract from the surface helipad.

Stay warm. But not too warm.]],
	},
	Z1_1 = {
		Id = "Z1_1",
		Title = "FLOOR PLAN - HABITATION",
		Kind = "Clipboard",
		Zone = "Zone1",
		Body = [[HABITATION RING - LEVEL 1

 [AIRLOCK 01]==[ MAIN CORRIDOR ===========]==[ BIO-LABS ]
                |      |        |      |
           CANTEEN  MEDBAY   BUNKS  STORAGE  FUSE ROOM

FUSE ROOM: far end of the corridor, south side.
Main power needs TWO 40A fuses. Spares were
"borrowed" all over the ring - check drawers,
lockers, the toolbox, even the bunks.]],
	},
	Z1_2 = {
		Id = "Z1_2",
		Title = "CANTEEN NOTICE",
		Kind = "Clipboard",
		Zone = "Zone1",
		Body = [[TO WHOEVER KEEPS TAKING THE FUSES:

The emergency radiator runs on a hand crank.
Ninety seconds of heat per crank. Use it.

And somebody put a FUSE in the MICROWAVE again.
We are scientists. Behave like it.

Fuse room is down the corridor, last door on the
left when you face the labs.  - Logistics]],
	},
	Z1_3 = {
		Id = "Z1_3",
		Title = "MEDBAY LOG 14 (TAPE)",
		Kind = "Tape",
		Zone = "Zone1",
		Body = [[> PLAYBACK ... DR. HALVORSEN, MEDICAL

Patient Okafor presented with core temperature 26.1.
No exposure. He was INSIDE. He said something
"breathed on him" in the corridor and he felt
the warmth leave his chest.

The heat injector brought him back. We have one left.
Whatever is out there does not see us.
It feels us.

> END OF RECORDING]],
	},
	Z1_4 = {
		Id = "Z1_4",
		Title = "LETTER, UNSENT",
		Kind = "Paper",
		Zone = "Zone1",
		Body = [[Mira,

They found something in the ice core at 2,400 meters.
Not a fossil. It was cold to the touch and the
thermometers around it kept dropping. Vasquez calls it
THERMOPHAGE - "heat eater". Funding came through
the same day, which tells you everything.

I sleep in my parka now. Everybody does.
The ones who sleep near the radiator wake up tired.

I love you. I'll be home by spring.]],
	},
	Z2_1 = {
		Id = "Z2_1",
		Title = "DECON WARNING",
		Kind = "Paper",
		Zone = "Zone2",
		Body = [[DECONTAMINATION SHOWERS - OUT OF ORDER

Pipes burst during the cold snap. Water is near
freezing. DO NOT stand under the leaks - you will
be soaked and lose heat fast.

Watch for the ice puddles. Listen for the dripping.]],
	},
	Z2_2 = {
		Id = "Z2_2",
		Title = "CHIEF SCIENTIST VASQUEZ (TAPE)",
		Kind = "Tape",
		Zone = "Zone2",
		Body = [[> PLAYBACK ... DR. E. VASQUEZ, CHIEF SCIENTIST

Specimen T-1 is not dead. It was never dead.
It slows down when the room is cold and wakes when
the room is warm. Heat is food. Movement is heat.

It cannot see. It tracks infrared and vibration.
Anyone lying perfectly still on cold floor is
practically invisible to it. Holding your breath helps.

I wrote the centrifuge load order on my whiteboard.
The sample key will not release without it.
God forgive me, I fed it the reactor coolant.

> END OF RECORDING]],
	},
	Z2_3 = {
		Id = "Z2_3",
		Title = "LAB JOURNAL - DAY 31",
		Kind = "Paper",
		Zone = "Zone2",
		Body = [[Day 31. Vault B-7 breached from the INSIDE.
Tank 3 is empty. Frozen prints lead into the vents.

It uses the ventilation network. You hear scratching
in the walls a moment before it comes out, and frost
creeps over the grille. If the grate frosts over - RUN.

Flares draw it. It circles them like a moth.
Good to know if you ever need a distraction.]],
	},
	Z3_1 = {
		Id = "Z3_1",
		Title = "GEN-2 START PROCEDURE",
		Kind = "Paper",
		Zone = "Zone3",
		Body = [[GEN-2 DIESEL GENERATOR

1. Fill the tank (diesel can from the workshop).
2. Prime the starter. Engage ONLY when the needle
   swings through the GREEN band.
3. A failed start will backfire. LOUDLY.

Once running, the generator powers the heaters and
the cargo lift down to the reactor level.
NOTE: 105 dB at full load. Everything in this
station will hear it.]],
	},
	Z3_2 = {
		Id = "Z3_2",
		Title = "CARGO MANIFEST",
		Kind = "Clipboard",
		Zone = "Zone3",
		Body = [[CARGO BAY MANIFEST - RESUPPLY 7

- 40x diesel (WORKSHOP)
- 12x signal flares
- 1x cargo lift motor (installed)
- 3x radiant heaters (install near GEN-2)
- 2x "biological containment" crates
  (DO NOT OPEN - VASQUEZ)

Lift travel time to reactor level: approx. 45 s.
The lift will not wait forever.]],
	},
	Z4_1 = {
		Id = "Z4_1",
		Title = "REACTOR CONTROL (TAPE)",
		Kind = "Tape",
		Zone = "Zone4",
		Body = [[> PLAYBACK ... OPERATOR KADE

It nests near the core now. The reactor is a buffet.
If we scram the reactor - all four rods down - the
heat goes away and so do the roof hatches' locks.
Maintenance ladder leads straight to the helipad.

With a full crew the rods must drop together, within
thirty seconds, or the safety pulls them back up.
Alone you can latch them one by one, but every latch
sets off the alarm.

Steam is your friend. Inside the steam it cannot
tell you from the vents.

> END OF RECORDING]],
	},
	Z4_2 = {
		Id = "Z4_2",
		Title = "LAST ENTRY",
		Kind = "Paper",
		Zone = "Zone4",
		Body = [[Helicopter is on standby above the station.
Pilot will wait thirty seconds after the hatches
open and the first of us reaches the pad. No longer.

It will follow us up. It always follows the heat.

If you are reading this: do not wait for us.]],
	},
}

return Notes
