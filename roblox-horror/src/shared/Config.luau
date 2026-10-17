-- All the numbers you might want to tweak live here.

local Config = {}

Config.IntermissionTime = 20 -- seconds in the lobby between rounds
Config.RoundTime = 480 -- seconds players have to escape
Config.KeysRequired = 3 -- keys needed to unlock the exit door
Config.MinPlayers = 1

Config.Player = {
	WalkSpeed = 12,
	SprintSpeed = 21,
	StaminaMax = 100,
	StaminaDrain = 22, -- per second while sprinting
	StaminaRegen = 14, -- per second while not sprinting
}

Config.Flashlight = {
	BatteryMax = 100,
	DrainPerSecond = 0.9,
	Range = 55,
	Brightness = 2.6,
	Angle = 50,
}

Config.Monster = {
	GraceTime = 12, -- seconds after the round starts before it wakes up
	WanderSpeed = 10,
	SearchSpeed = 15,
	ChaseSpeed = 18.5,
	SightRangeDark = 32, -- how far it sees you with your flashlight off
	SightRangeLit = 75, -- ...and with it on
	HearRange = 38, -- hears you sprinting within this distance
	FieldOfView = 80, -- degrees either side of where it's looking
	KillRange = 5,
	SearchTime = 6, -- seconds it keeps hunting your last known position
}

-- Sound ids. Roblox no longer ships free horror sounds by id, so paste your own
-- here from the Creator Store (Toolbox > Audio). Example: "rbxassetid://1234567".
-- Any sound left as "" is simply skipped.
Config.Sounds = {
	Ambience = "", -- looping dark drone
	Heartbeat = "", -- looping heartbeat, gets louder near the monster
	Jumpscare = "", -- loud scream / sting
	MonsterGrowl = "", -- looping growl attached to the monster
	MonsterScream = "", -- plays when it spots someone
	Thunder = "",
	DoorCreak = "",
	DoorSlam = "",
	KeyPickup = "",
	Whisper = "",
	Escape = "",
}

return Config
