--!strict

local Constants = {
	RemoteFolderName = "TelekinesisRemotes",
	RemoteNames = {
		Action = "TelekinesisAction",
		Update = "TelekinesisUpdate",
		Feedback = "TelekinesisFeedback",
	},

	Tags = {
		Allowed = "TelekinesisGrabbable",
		Protected = "TelekinesisProtected",
		Blocked = "NoTelekinesis",
	},

	PlayerAttributes = {
		Energy = "TelekinesisEnergy",
		MaxEnergy = "TelekinesisMaxEnergy",
		Holding = "TelekinesisHolding",
	},

	CollisionGroups = {
		Characters = "TelekinesisCharacters",
		HeldObjects = "TelekinesisHeldObjects",
	},

	MaxGrabDistance = 60,
	MinHoldDistance = 7,
	MaxHoldDistance = 28,
	MaxObjectMass = 250,
	MaxObjectParts = 50,
	MaxObjectBounds = 24,
	MinimumGrabEnergy = 5,

	MinimumControlAcceleration = 45,
	MaximumControlAcceleration = 180,
	MinimumResponsiveness = 8,
	MaximumResponsiveness = 20,
	MinimumControlSpeed = 25,
	MaximumControlSpeed = 70,
	RotationSpeedDegrees = 120,
	MaxPositionError = 45,
	MaxCameraOffsetFromHead = 12,
	LineOfSightGracePeriod = 0.35,
	UpdateTimeout = 1.25,
	OwnershipCheckInterval = 0.5,

	MinimumThrowSpeed = 20,
	MaximumThrowSpeed = 90,
	MaximumChargeTime = 1.5,
	ThrowEnergyCost = 10,
	ServerOwnershipDuration = 0.35,

	MaxEnergy = 100,
	EnergyDrainBase = 5,
	EnergyDrainMass = 14,
	EnergyDrainDistance = 6,
	EnergyRegenerationRate = 18,
	EnergyRegenerationDelay = 1.25,

	ClientUpdateRate = 20,
	ClientTargetRefreshRate = 20,
	ActionRequestsPerWindow = 12,
	UpdateRequestsPerWindow = 30,
	RateLimitWindow = 1,
	ViolationReleaseThreshold = 8,
	ViolationWindow = 5,

	GrabCooldown = 0.25,
	DropCooldown = 0.1,
	ChargeCooldown = 0.15,
	ThrowCooldown = 0.1,

	MouseRotationSensitivity = 0.0045,
	HoldDistanceStep = 1.5,
	SwayPositionAmplitude = 0.12,
	SwayRotationDegrees = 1.25,
}

return table.freeze(Constants)
