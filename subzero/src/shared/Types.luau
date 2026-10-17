--!strict
-- Gemeinsame Typen für Server und Client

export type Stance = "Stand" | "Crouch" | "Prone" | "Downed"

-- Lobby: wartet; Alive/Downed/Grabbed: in der Runde; Dead/Missing/Escaped: raus
export type PlayerState = "Lobby" | "Alive" | "Downed" | "Grabbed" | "Dead" | "Missing" | "Escaped"

export type HypoStage = "Overheated" | "Normal" | "Mild" | "Moderate" | "Severe" | "Collapse"

export type AIState =
	"Sleeping"
	| "Patrol"
	| "Investigate"
	| "Hunt"
	| "Search"
	| "Attracted"
	| "Frenzy"
	| "Retreat"

export type ZoneId = "Lobby" | "Zone1" | "Zone2" | "Zone3" | "Zone4" | "Helipad" | "None"

export type RoundPhase =
	"Lobby"
	| "Countdown"
	| "Transition"
	| "Zone1"
	| "Zone2"
	| "Zone3"
	| "Zone4"
	| "Extraction"
	| "Victory"
	| "Defeat"

export type ItemId = string

export type HeatSource = {
	Id: number,
	Kind: string, -- Schlüssel in Config.HeatSources
	Position: Vector3,
	Active: boolean,
	Owner: Player?, -- z. B. Fackel in der Hand
	Part: BasePart?, -- optional: Position folgt diesem Teil
}

export type NoiseEvent = {
	Position: Vector3,
	Radius: number,
	Kind: string,
	Source: Player?,
	Time: number,
}

export type Beacon = {
	Id: number,
	Kind: string,
	Position: Vector3,
	Radius: number,
	Active: boolean,
	Owner: Player?,
	Part: BasePart?,
}

export type RoundStats = {
	StartTime: number,
	EndTime: number?,
	LowestTemp: number,
	Distractions: number,
	Revives: number,
	Detected: number,
	Escaped: boolean,
}

return {}
