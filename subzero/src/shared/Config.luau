--!strict
-- SUB-ZERO: THE HEAT HUNTER
-- Config: ALLE Zahlen des Spiels stehen hier (Regel 1 der Spezifikation).
-- Einheiten: Studs, Sekunden, Grad Celsius. Nichts davon steht hart im Code.

local Config = {}

----------------------------------------------------------------------
-- Allgemein / Runde
----------------------------------------------------------------------
Config.Round = {
	MaxPlayersPerServer = 6,
	MaxPlayersPerRound = 4,
	CountdownTime = 10, -- s, nach dem Hebel
	LeverHoldTime = 1.5, -- s, E halten am Hebel
	PowerOutageTime = 240, -- s (Minute 4)
	PowerFlickerTime = 3, -- s Flackern vor dem Ausfall
	TransitionBlackTime = 1.2, -- s Schwarzbild beim Teleport
	VictoryScreenTime = 20, -- s, danach zurück in die Lobby
	DefeatScreenTime = 12, -- s
	AirlockCloseTime = 1.0, -- s pneumatisches Schließen der Schleuse
	LobbyTerminalRefresh = 0.5, -- s
}

----------------------------------------------------------------------
-- Temperatur (Abschnitt 3.1)
----------------------------------------------------------------------
Config.Temperature = {
	TickRate = 5, -- Hz
	Start = 37.0,
	Max = 38.5,
	Collapse = 24.0,
	LobbyTarget = 37.0, -- Lobby wärmt bis 37 °C auf
	ReviveTemp = 28.0,

	ZoneRate = { -- A: °C pro Sekunde
		Lobby = 0.50,
		Zone1 = -0.04,
		Zone2 = -0.06,
		Zone3 = -0.07,
		Zone4 = -0.05,
		Helipad = -0.07,
		None = -0.05,
	} :: { [string]: number },

	Movement = { -- B: °C pro Sekunde
		Still = 0,
		Crouch = 0.01,
		Walk = 0.02,
		Sprint = 0.06,
		Prone = -0.03,
		Downed = -0.03,
	} :: { [string]: number },

	ParkaLossFactor = 0.7, -- K Kleidung
	WetLossFactor = 1.6, -- K Nass
	WetDuration = 30, -- s
	WetHitDamage = 1.0, -- °C sofort beim Treffer
	WetRetriggerCooldown = 2.0, -- s bis ein Tropfen erneut trifft

	HandWarmerRate = 0.04, -- °C/s
	HandWarmerDuration = 90, -- s
	InjectorBoost = 4.0, -- °C sofort
	MovingThreshold = 0.8, -- Studs/s, darunter gilt man als stillstehend
}

-- Wärmequellen (W): Rate in °C/s, Radius in Studs, Falloff = linear nach außen
Config.HeatSources = {
	Stove = { Rate = 0.50, Radius = 15, Falloff = false },
	Radiator = { Rate = 0.25, Radius = 12, Falloff = true },
	Heater = { Rate = 0.15, Radius = 15, Falloff = false },
	SteamVent = { Rate = 0.20, Radius = 8, Falloff = false },
	FlareHand = { Rate = 0.08, Radius = 6, Falloff = false },
	FlareGround = { Rate = 0.10, Radius = 6, Falloff = false },
} :: { [string]: { Rate: number, Radius: number, Falloff: boolean } }

----------------------------------------------------------------------
-- Unterkühlungs-Stufen (Abschnitt 3.2)
----------------------------------------------------------------------
Config.Hypo = {
	OverheatAbove = 37.5,
	NormalAbove = 34.0,
	MildAbove = 31.0,
	ModerateAbove = 28.0,
	-- darunter bis Collapse = Severe
	ModerateSpeedFactor = 0.85, -- Gehtempo -15 %
	ModerateStaminaRegenFactor = 0.70, -- Regeneration -30 %
}

----------------------------------------------------------------------
-- Wärmesignatur (Abschnitt 3.3)
----------------------------------------------------------------------
Config.Signature = {
	TickRate = 5,
	TempBase = 30, -- (T - 30) * 4
	TempFactor = 4,
	Max = 100,
	Movement = { Still = 0, Crouch = 4, Walk = 10, Sprint = 30, Prone = 0, Downed = 0 } :: { [string]: number },
	Items = {
		FlashlightOn = 8,
		HandWarmer = 10,
		FlareInHand = 60,
		ScannerPing = 15,
		ScannerPingTime = 1.0,
		Overheated = 10,
		Injector = 25,
		InjectorTime = 10,
		Revive = 20,
	},
	SourceBonus = 20, -- solange man an einer Wärmequelle steht
	Posture = {
		Normal = 1.0,
		Crouch = 0.8,
		ProneHolding = 0.1,
		ProneBreathing = 0.3,
		Locker = 0.2,
		Downed = 0.3,
		Steam = 0.3, -- zusätzlicher Faktor im Dampf
	},
	SightPerSig = 1.0, -- Sichtweite = S * 1.0 Studs
}

----------------------------------------------------------------------
-- Bewegung (Abschnitt 4.1)
----------------------------------------------------------------------
Config.Movement = {
	Speed = { Prone = 2, Crouch = 6, Walk = 10, Sprint = 18, Downed = 1 } :: { [string]: number },
	NoiseRadius = { Prone = 0, Crouch = 4, Walk = 10, Sprint = 35, Downed = 0 } :: { [string]: number },
	GrateNoiseFactor = 2.0,
	SnowNoiseFactor = 0.5,
	StepInterval = { Prone = 1.2, Crouch = 0.7, Walk = 0.5, Sprint = 0.33, Downed = 1.5 } :: { [string]: number },
	ProneDownTime = 0.4,
	ProneUpTime = 0.6,
	CrouchTime = 0.2,
	OverallSpeedFactor = 1.10, -- Leichter Overall: +10 % Gehtempo
	DieselSpeedFactor = 0.8,
	-- Haltungs-Höhen: Faktor auf die Original-HipHeight des Avatars (Liegen: Wurzel am Boden),
	-- Kamera-Offset so, dass die Kamera liegend 1,5 Studs über dem Boden ist
	HipHeightFactor = { Stand = 1.0, Crouch = 0.5, Prone = 0.0, Downed = 0.0 } :: { [string]: number },
	CameraOffsetY = { Stand = 0, Crouch = -0.5, Prone = -1.0, Downed = -1.0 } :: { [string]: number },
	SpeedCheckTolerance = 1.6, -- Server-Tempo-Prüfung: erlaubt Faktor
	SpeedCheckGrace = 2.0, -- s Überschreitung, bevor zurückgesetzt wird
	LeanMaxDeg = 8, -- prozedurale Vorneigung
}

----------------------------------------------------------------------
-- Stamina (Abschnitt 4.2)
----------------------------------------------------------------------
Config.Stamina = {
	Max = 100,
	SprintCost = 12, -- pro Sekunde
	ParkaSprintCostFactor = 1.2, -- Parka: Sprint kostet 20 % mehr
	RegenDelay = 1.5,
	RegenRate = 15,
	PantDuration = 2.0,
	PantNoiseRadius = 15,
	MinToStartSprint = 5,
}

----------------------------------------------------------------------
-- Atem (Abschnitt 4.3)
----------------------------------------------------------------------
Config.Breath = {
	Max = 100,
	HoldDuration = 10, -- s bis der Balken leer ist
	RefillDuration = 6, -- s bis wieder voll
	GaspNoiseRadius = 15,
}

----------------------------------------------------------------------
-- Herzfrequenz (Abschnitt 4.4)
----------------------------------------------------------------------
Config.Heart = {
	Base = 70,
	Min = 50,
	Max = 180,
	SmoothTime = 1.0,
	Sprint = 40,
	EntityRange = 60,
	EntityMax = 80,
	HypoModerate = 10,
	HypoSevere = 20,
	SoundBaseBpm = 60, -- PlaybackSpeed = 1 + (BPM - 60)/100 * 0.8
	SoundFactor = 0.8,
	EkgAlarmBpm = 120,
}

----------------------------------------------------------------------
-- Kollaps / Wiederbelebung / Tod (Abschnitt 4.5)
----------------------------------------------------------------------
Config.Health = {
	DownedTime = 30,
	ReviveHoldTime = 4,
	MaxRevivesPerRound = 2,
	ReviveRange = 7,
	InjectorReviveRange = 7,
	CorpseSearchHold = 1.0,
	KillCinematicTime = 2.5,
	KillLiftHeight = 3,
	FallKillY = -110, -- unterhalb davon: Sturz in den Abgrund = tot
}

----------------------------------------------------------------------
-- Versteck-Spinde (Abschnitt 4.3)
----------------------------------------------------------------------
Config.Locker = {
	EnterHold = 0.3,
	ExitDelay = 0.4,
	RipOpenAttention = 70,
	RipOpenRange = 6,
	RipOpenTime = 1.5,
}

----------------------------------------------------------------------
-- Das Wesen (Abschnitt 5)
----------------------------------------------------------------------
Config.Entity = {
	Height = 9,
	AgentRadius = 2.5,
	AgentHeight = 9,
	DecisionRate = 10, -- Hz
	SenseRate = 5, -- Hz
	WaypointSpacing = 4,

	Speed = {
		Sleeping = 0,
		Patrol = 8,
		Investigate = 14,
		Hunt = 20,
		Search = 10,
		Attracted = 14,
		Frenzy = 23,
		Retreat = 12,
	} :: { [string]: number },

	-- Aufmerksamkeit (5.2)
	AttentionHeatPerSec = 40,
	AttentionHeatCloseRange = 15,
	AttentionHeatCloseFactor = 2,
	AttentionNoiseEvent = 25,
	AttentionSprintStep = 10,
	-- Schritte anderer Haltungen (nicht im Dokument festgelegt, eigene Werte)
	AttentionStep = { Sprint = 10, Walk = 6, Crouch = 3, Prone = 0, Downed = 0 } :: { [string]: number },
	AttentionDecayPerSec = 10,
	InvestigateThreshold = 30,
	HuntThreshold = 100,

	InvestigateProbeTime = 4, -- s Luft abtasten
	InvestigateGiveUp = 8, -- s ohne Reiz -> Patrouille
	HuntLoseContact = 3, -- s kein Kontakt -> Suchen
	HuntRepath = 0.3,
	HuntGrabGrace = 3, -- s am Jagdbeginn ohne Zupacken
	HuntMaxDuration = 90, -- s erfolglose Jagd -> Rückzug
	SearchDuration = 15,
	SearchRadius = 25,
	AttractedDuration = 25,
	AttractedBreakSig = 40,
	AttractedBreakRange = 20,
	AttractedOrbitRadius = 6,
	FrenzySenseFactor = 1.5,
	FrenzyDecayFactor = 0.5,
	GeneratorFrenzyTime = 60,
	RetreatDuration = 20,
	GrabRange = 4,
	DirectChaseRange = 18, -- direkte Verfolgung ohne Pfad, wenn freie Sicht

	-- Hören/Wände
	WallNoiseFactor = 0.5,
	-- Leuchtfeuer (5.1)
	Beacon = { Generator = 250, Radiator = 60, Flare = 80, SteamVent = 30 } :: { [string]: number },
	BeaconRefresh = 1.0,

	-- Lüftungsschächte (5.5)
	VentScratchTime = 2.0,
	VentEnterTime = 1.2,
	VentTravelTime = 3.0,

	-- Türen
	DoorBreakTime = 2.5,
	DoorBreakNoise = 45,
	DoorCheckDistance = 7,

	-- Spannungs-Regisseur
	DirectorPressureLimit = 60,
	DirectorAwayTime = 30,
	DirectorCalmLimit = 90,

	-- Diegetische Warnung / Aura
	AuraFlickerRange = 20,
	DiegeticRange = 40,
	FovWobbleRange = 30,
	FovWobbleDeg = 1.5,
	InfrasoundRange = 70,

	-- Frost-Spuren
	FootprintSpacing = 4.5,
	FootprintLifetime = 20,
	FootprintPoolSize = 40,

	-- Erwachen
	WakeRoarDelay = 1.5,

	-- Patrouille
	PatrolWaitMin = 1.0,
	PatrolWaitMax = 3.5,
	StuckTime = 3.0,
	StuckMoveEps = 1.0,

	-- Skalierung nach Spielerzahl (5.6)
	Scaling = {
		[1] = { Speed = 0.9, Range = 0.85, Attention = 0.9 },
		[2] = { Speed = 0.95, Range = 0.95, Attention = 1.0 },
		[3] = { Speed = 1.0, Range = 1.0, Attention = 1.1 },
		[4] = { Speed = 1.0, Range = 1.0, Attention = 1.2 },
	} :: { [number]: { Speed: number, Range: number, Attention: number } },
}

----------------------------------------------------------------------
-- Items (Abschnitt 6)
----------------------------------------------------------------------
Config.Items = {
	BeltSlots = 4,
	LoadoutItems = 2,
	PickupRange = 10,
	DropNoiseRadius = 6,
	VialDropNoiseRadius = 20,
	DropDistance = 3,

	Flashlight = {
		Battery = 180,
		Range = 60,
		Angle = 50,
		Brightness = 4,
		Color = Color3.fromRGB(255, 236, 205),
	},
	Scanner = {
		Duration = 3,
		Radius = 80,
		Cooldown = 20,
		PingNoise = 8,
	},
	Flare = {
		BurnTime = 25,
		ThrowDistance = 40,
		ThrowSpeed = 48,
		LightRange = 24,
		LightBrightness = 3,
		LightColor = Color3.fromRGB(255, 40, 30),
		MaxLoadout = 2,
		PoolSize = 10,
	},
	HandWarmer = { Duration = 90 },
	Injector = { PerRound = 1 },
	-- Welche Items im Lobby-Spind wählbar sind
	LoadoutChoices = { "Flashlight", "Scanner", "Flare", "HandWarmer" },
	ClothingChoices = { "Parka", "Overall" },
	DefaultClothing = "Parka",
	DefaultLoadout = { "Flashlight", "Flare" },
}

-- Anzeigenamen und Eigenschaften
Config.ItemInfo = {
	Flashlight = { Name = "FLASHLIGHT", Quest = false, TwoHanded = false, Color = Color3.fromRGB(70, 70, 75) },
	Scanner = { Name = "THERMAL SCANNER", Quest = false, TwoHanded = false, Color = Color3.fromRGB(90, 95, 80) },
	Flare = { Name = "FLARE", Quest = false, TwoHanded = false, Color = Color3.fromRGB(200, 30, 25) },
	HandWarmer = { Name = "HAND WARMER", Quest = false, TwoHanded = false, Color = Color3.fromRGB(220, 120, 40) },
	Battery = { Name = "BATTERY", Quest = false, TwoHanded = false, Color = Color3.fromRGB(200, 170, 40) },
	Injector = { Name = "HEAT INJECTOR", Quest = false, TwoHanded = false, Color = Color3.fromRGB(230, 90, 40) },
	Fuse = { Name = "FUSE", Quest = true, TwoHanded = false, Color = Color3.fromRGB(180, 140, 60) },
	VialBlue = { Name = "VIAL (BLUE)", Quest = true, TwoHanded = false, Color = Color3.fromRGB(60, 140, 255) },
	VialGreen = { Name = "VIAL (GREEN)", Quest = true, TwoHanded = false, Color = Color3.fromRGB(60, 255, 120) },
	VialRed = { Name = "VIAL (RED)", Quest = true, TwoHanded = false, Color = Color3.fromRGB(255, 60, 60) },
	Keycard = { Name = "KEYCARD", Quest = true, TwoHanded = false, Color = Color3.fromRGB(230, 230, 235) },
	Diesel = { Name = "DIESEL CAN", Quest = true, TwoHanded = true, Color = Color3.fromRGB(170, 30, 25) },
} :: { [string]: { Name: string, Quest: boolean, TwoHanded: boolean, Color: Color3 } }

Config.ClothingInfo = {
	Parka = { Name = "PARKA", Desc = "Heat loss x0.7 / sprint costs +20% stamina", Color = Color3.fromRGB(150, 60, 30) },
	Overall = { Name = "LIGHT OVERALL", Desc = "No insulation / +10% walk speed", Color = Color3.fromRGB(70, 80, 90) },
} :: { [string]: { Name: string, Desc: string, Color: Color3 } }

----------------------------------------------------------------------
-- Türen und Interaktion
----------------------------------------------------------------------
Config.Doors = {
	NormalOpenTime = 0.6,
	NormalNoise = 5,
	AirlockCloseNoise = 12,
	BrokenTilt = 12, -- Grad, aufgebrochene Tür hängt schief
}

Config.Prompt = {
	MaxDistance = 8,
	ItemMaxDistance = 7,
	NoteMaxDistance = 6,
}

----------------------------------------------------------------------
-- Rätsel (Abschnitt 7)
----------------------------------------------------------------------
Config.Puzzle = {
	-- Zone 1
	FuseCount = 2,
	FuseInsertHold = 2,
	SearchHold = 1.0,
	MainLeverHold = 1.5,
	ArmorDoorOpenTime = 8,
	KeycardDoorOpenTime = 3,
	ArmorDoorNoise = 40,
	RadiatorCrankHold = 5,
	RadiatorCrankNoise = 20,
	RadiatorRunTime = 90,
	-- Zone 2
	VialCabinets = 6,
	CentrifugeRunTime = 20,
	CentrifugeNoise = 25,
	CentrifugeNoiseInterval = 2,
	CentrifugeAlarmNoise = 60,
	CentrifugeLockout = 10,
	CentrifugeRange = 10,
	KeycardSwipeHold = 1.0,
	DripNoiseInterval = 1.4,
	-- Zone 3
	DieselPourHold = 3,
	GeneratorStutterNoise = 50,
	GeneratorNeedlePeriod = 1.6, -- s pro Pendelschwingung (hin und zurück)
	GeneratorGreenWidth = 0.16, -- Anteil der Skala (0..1)
	GeneratorTolerance = 0.05, -- Server-Toleranz (Netzwerk)
	GeneratorAttemptCooldown = 0.6,
	ElevatorArrivalTime = 45,
	ElevatorMaxWait = 15,
	ElevatorReturnTime = 30,
	ElevatorRideTime = 8,
	ElevatorTrips = 2,
	-- Zone 4
	RodCrankHold = 6,
	RodCrankNoise = 30,
	RodSyncWindow = 30, -- 3-4 Spieler
	RodAlarmNoise = 100, -- 1-2 Spieler
	SteamBurstTime = 4,
	SteamVentOn = 6,
	SteamVentOff = 7,
	-- Extraktion
	HatchCinematicTime = 5,
	HelicopterWait = 30,
	EntityFollowDelay = 10,
	HelicopterBoardHold = 0.5,
	HelicopterNoPlayerTimeout = 120, -- s, falls niemand den Landeplatz erreicht
}

----------------------------------------------------------------------
-- Herzschlag-/Notiz-/HUD
----------------------------------------------------------------------
Config.HUD = {
	DialMin = 24,
	DialMax = 39,
	FrostStart = 34, -- Transparenz 1 bei 34 °C
	FrostFull = 26, -- Transparenz 0 bei 26 °C
	BlurStart = 28,
	BlurMax = 12,
	HotbarSpringStiffness = 300,
	HotbarSpringDamping = 20,
	HotbarActiveScale = 1.15,
	ViewmodelSpringStiffness = 180,
	ViewmodelSpringDamping = 16,
	EkgHistory = 90,
	ScanlineSpacing = 4,
	ScanlineScrollSpeed = 6,
	CrtOnTime = 0.3,
	CrtOffTime = 0.35,
	NotifyTime = 4,
	TrainingDisplayRange = 30,
}

----------------------------------------------------------------------
-- Kamera / Effekte (Abschnitt 10)
----------------------------------------------------------------------
Config.Camera = {
	FieldOfView = 70,
	HuntShakeAmp = 0.35,
	InfrasoundShakeAmp = 0.25,
	HypoShakeAmp = 0.12,
	KillTweenTime = 0.4,
	KillFrostTime = 1.0,
	BobAmplitude = 0.08,
	BobFrequency = 1.6,
	LeanSideDeg = 4,
}

Config.Effects = {
	BreathInterval = 2.5,
	ActiveRange = 80, -- Client-Effekte nur in 80 Studs
	MaxShadowLights = 6,
	MaxParticles = 1500,
	EmitterCullInterval = 0.5,
	FlickerRange = 20,
	SteamFogTransparency = 0.25,
}

----------------------------------------------------------------------
-- Licht-Presets (Abschnitt 10.5)
----------------------------------------------------------------------
export type LightPreset = {
	Ambient: Color3,
	Density: number,
	Haze: number,
	AtmosphereColor: Color3,
	Decay: Color3,
	Tint: Color3,
	Saturation: number,
	Contrast: number,
	Reverb: Enum.ReverbType,
}

Config.LightTween = 1.5
Config.LightPresets = {
	Lobby = {
		Ambient = Color3.fromRGB(25, 15, 10),
		Density = 0.25,
		Haze = 0.5,
		AtmosphereColor = Color3.fromRGB(80, 50, 35),
		Decay = Color3.fromRGB(40, 25, 15),
		Tint = Color3.fromRGB(255, 225, 200),
		Saturation = 0.05,
		Contrast = 0.1,
		Reverb = Enum.ReverbType.LivingRoom,
	},
	Zone1 = {
		Ambient = Color3.fromRGB(20, 24, 30),
		Density = 0.35,
		Haze = 1,
		AtmosphereColor = Color3.fromRGB(120, 130, 140),
		Decay = Color3.fromRGB(60, 70, 80),
		Tint = Color3.fromRGB(225, 235, 255),
		Saturation = -0.15,
		Contrast = 0.1,
		Reverb = Enum.ReverbType.Hallway,
	},
	Zone1Dark = {
		Ambient = Color3.fromRGB(8, 4, 4),
		Density = 0.45,
		Haze = 1.5,
		AtmosphereColor = Color3.fromRGB(60, 20, 20),
		Decay = Color3.fromRGB(30, 10, 10),
		Tint = Color3.fromRGB(255, 215, 215),
		Saturation = -0.2,
		Contrast = 0.15,
		Reverb = Enum.ReverbType.Hallway,
	},
	Zone2 = {
		Ambient = Color3.fromRGB(8, 16, 12),
		Density = 0.45,
		Haze = 1.5,
		AtmosphereColor = Color3.fromRGB(40, 80, 60),
		Decay = Color3.fromRGB(15, 35, 25),
		Tint = Color3.fromRGB(215, 255, 230),
		Saturation = -0.1,
		Contrast = 0.15,
		Reverb = Enum.ReverbType.Hallway,
	},
	Zone3 = {
		Ambient = Color3.fromRGB(0, 0, 0),
		Density = 0.5,
		Haze = 2,
		AtmosphereColor = Color3.fromRGB(10, 10, 12),
		Decay = Color3.fromRGB(5, 5, 6),
		Tint = Color3.fromRGB(230, 235, 255),
		Saturation = -0.3,
		Contrast = 0.2,
		Reverb = Enum.ReverbType.Hangar,
	},
	Zone3Lit = {
		Ambient = Color3.fromRGB(20, 12, 6),
		Density = 0.5,
		Haze = 2,
		AtmosphereColor = Color3.fromRGB(110, 70, 40),
		Decay = Color3.fromRGB(50, 30, 15),
		Tint = Color3.fromRGB(255, 225, 195),
		Saturation = 0,
		Contrast = 0.15,
		Reverb = Enum.ReverbType.Hangar,
	},
	Zone4 = {
		Ambient = Color3.fromRGB(15, 8, 5),
		Density = 0.55,
		Haze = 2,
		AtmosphereColor = Color3.fromRGB(140, 70, 40),
		Decay = Color3.fromRGB(70, 30, 15),
		Tint = Color3.fromRGB(255, 220, 200),
		Saturation = 0.05,
		Contrast = 0.2,
		Reverb = Enum.ReverbType.Cave,
	},
	Helipad = {
		Ambient = Color3.fromRGB(60, 70, 85),
		Density = 0.4,
		Haze = 2,
		AtmosphereColor = Color3.fromRGB(160, 190, 220),
		Decay = Color3.fromRGB(110, 130, 160),
		Tint = Color3.fromRGB(215, 230, 255),
		Saturation = -0.25,
		Contrast = 0.05,
		Reverb = Enum.ReverbType.Mountains,
	},
} :: { [string]: LightPreset }

----------------------------------------------------------------------
-- Daten (Abschnitt 12)
----------------------------------------------------------------------
Config.Data = {
	StoreName = "PlayerStats_v1",
	AutosaveInterval = 120,
	Retries = 3,
	RetryDelay = 1.5,
	LeaderboardInterval = 60,
	LeaderboardSize = 8,
	OrderedStores = {
		Evacuations = "LB_Evacuations_v1",
		MinutesSurvived = "LB_MinutesSurvived_v1",
		Distractions = "LB_Distractions_v1",
	} :: { [string]: string },
}

----------------------------------------------------------------------
-- Leistung (Abschnitt 13.2)
----------------------------------------------------------------------
Config.Performance = {
	MaxSounds3D = 30,
	StreamRadius = 256,
}

----------------------------------------------------------------------
-- Sound-IDs (Abschnitt 11)
-- Leere Strings = Platzhalter (_PH): der Sound wird stumm übersprungen.
-- Eintragen: "rbxassetid://<ID>" aus dem Creator Store (frei nutzbar).
----------------------------------------------------------------------
Config.Sounds = {
	-- Schritte (4 Varianten pro Untergrund; Fallback = eingebauter Roblox-Schritt)
	StepFallback = "rbxasset://sounds/action_footsteps_plastic.mp3",
	StepGrate = {} :: { string },
	StepSnow = {} :: { string },
	StepConcrete = {} :: { string },
	StepIce = {} :: { string },
	StepMetal = {} :: { string },
	-- Biometrie
	Heartbeat = "",
	TeethChatter = "",
	ShiverBreath = "",
	Pant = "",
	Gasp = "",
	-- Wesen
	Infrasound = "",
	TuningFork = "",
	HuntScreech = "",
	EntityStep = "",
	VentScratch = "",
	DoorBang = "",
	-- Welt
	Wind = "",
	IceCrack = "",
	Drip = "rbxasset://sounds/impact_water.mp3",
	Hiss = "",
	Alarm = "",
	GeneratorRun = "",
	GeneratorStutter = "",
	CentrifugeHum = "",
	ElevatorRumble = "",
	ArmorDoor = "",
	StoveCrackle = "",
	RadiatorCrank = "",
	FlareBurn = "",
	GlassBreak = "",
	Clink = "",
	ScannerPing = "",
	ItemDrop = "",
	Pickup = "",
	UiClick = "",
	UiBeep = "",
	EkgBeep = "",
	Helicopter = "",
	MetalScreech = "",
	-- Musik
	HuntPulse = "",
	ExtractionDrone = "",
} :: { [string]: any }

Config.SoundVolume = {
	Generator = 2,
	GeneratorRollOff = 400,
	Default = 0.8,
	DefaultRollOff = 120,
	Footstep = 0.45,
	FootstepRollOff = 60,
	PitchJitter = 0.08,
	Heartbeat = 0.7,
	Music = 0.5,
	Effects = 1.0,
}

----------------------------------------------------------------------
-- Bild-IDs für UI (Abschnitt 13.1, Punkt 4) – leer = Platzhalter aus Frames
----------------------------------------------------------------------
Config.Images = {
	FrostVignette = "",
	Scanlines = "",
	LeatherPouch = "",
	DialFace = "",
	CrackOverlay = "",
	MonitorFrame = "",
}

----------------------------------------------------------------------
-- Farben (UI / Welt)
----------------------------------------------------------------------
Config.Colors = {
	StoveLight = Color3.fromRGB(255, 147, 41),
	Beacon = Color3.fromRGB(255, 170, 0),
	CrtGreen = Color3.fromRGB(80, 255, 120),
	CrtAmber = Color3.fromRGB(255, 176, 0),
	CrtDim = Color3.fromRGB(20, 60, 30),
	Ice = Color3.fromRGB(150, 210, 255),
	HudWhite = Color3.fromRGB(230, 235, 240),
	Danger = Color3.fromRGB(255, 50, 40),
	EmergencyRed = Color3.fromRGB(255, 30, 20),
	Neon = Color3.fromRGB(215, 230, 255),
	TankGreen = Color3.fromRGB(70, 255, 140),
	Reactor = Color3.fromRGB(255, 110, 40),
	Heater = Color3.fromRGB(255, 120, 40),
}

----------------------------------------------------------------------
-- Kollisionsgruppen
----------------------------------------------------------------------
Config.CollisionGroups = {
	Players = "Players",
	Limbs = "Limbs",
	Creature = "Creature",
	ThermalClear = "ThermalClear", -- Glas, Gitter, Props: blockieren keine Wärme
	ThermalRay = "ThermalRay", -- nur für Wärme-/Geräusch-Strahlen
	Items = "Items",
}

----------------------------------------------------------------------
-- Map
----------------------------------------------------------------------
Config.Map = {
	StationOrigin = Vector3.new(1000, 0, 0),
	LobbyOrigin = Vector3.new(0, 0, 0),
}

return Config
