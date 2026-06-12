--!strict

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)

local TestArenaService = {}

local function addLabel(part: BasePart, text: string)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "TestLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 36)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y * 0.5 + 1.5, 0)
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(18, 22, 30)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.Text = text
	label.TextColor3 = Color3.fromRGB(235, 241, 255)
	label.TextScaled = true
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
end

local function createPart(
	parent: Instance,
	name: string,
	position: Vector3,
	size: Vector3,
	color: Color3,
	density: number,
	anchored: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = anchored == true
	part.CustomPhysicalProperties = PhysicalProperties.new(density, 0.45, 0.15, 1, 1)
	part.Parent = parent
	return part
end

function TestArenaService.initialize()
	if not RunService:IsStudio() then
		return
	end

	local physicsObjects = workspace:FindFirstChild("PhysicsObjects")
	local testArena = workspace:FindFirstChild("TestArena")
	if not physicsObjects or not testArena or testArena:GetAttribute("TelekinesisTestArenaCreated") then
		return
	end
	testArena:SetAttribute("TelekinesisTestArenaCreated", true)

	local floor = createPart(
		testArena,
		"ArenaFloor",
		Vector3.new(0, -1, 0),
		Vector3.new(90, 2, 70),
		Color3.fromRGB(54, 60, 72),
		1,
		true
	)
	floor.Material = Enum.Material.Slate

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TestSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 30)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Material = Enum.Material.Neon
	spawn.Color = Color3.fromRGB(72, 126, 196)
	spawn.Parent = testArena

	createPart(
		testArena,
		"LineOfSightWall",
		Vector3.new(0, 7, -7),
		Vector3.new(18, 14, 1),
		Color3.fromRGB(78, 84, 98),
		1,
		true
	)

	local light = createPart(
		physicsObjects,
		"LightCrate",
		Vector3.new(-18, 3, 8),
		Vector3.new(3, 3, 3),
		Color3.fromRGB(91, 184, 255),
		0.7
	)
	addLabel(light, "LIGHT - valid")

	local heavy = createPart(
		physicsObjects,
		"HeavyCrate",
		Vector3.new(-10, 3, 8),
		Vector3.new(4, 4, 4),
		Color3.fromRGB(255, 171, 64),
		2.5
	)
	addLabel(heavy, "HEAVY - valid")

	local overweight = createPart(
		physicsObjects,
		"OverweightCrate",
		Vector3.new(0, 3, 8),
		Vector3.new(4, 4, 4),
		Color3.fromRGB(230, 88, 88),
		5
	)
	addLabel(overweight, "OVERWEIGHT - rejected")

	local oversized = createPart(
		physicsObjects,
		"OversizedBeam",
		Vector3.new(14, 3, 9),
		Vector3.new(26, 2, 2),
		Color3.fromRGB(190, 92, 230),
		0.7
	)
	addLabel(oversized, "OVERSIZED - rejected")

	local anchored = createPart(
		physicsObjects,
		"AnchoredCrate",
		Vector3.new(-18, 3, 19),
		Vector3.new(4, 4, 4),
		Color3.fromRGB(110, 116, 130),
		0.7,
		true
	)
	addLabel(anchored, "ANCHORED - rejected")

	local protected = createPart(
		physicsObjects,
		"ProtectedCrate",
		Vector3.new(-9, 3, 19),
		Vector3.new(4, 4, 4),
		Color3.fromRGB(255, 93, 166),
		0.7
	)
	CollectionService:AddTag(protected, Constants.Tags.Protected)
	addLabel(protected, "PROTECTED - rejected")

	local locked = createPart(
		physicsObjects,
		"LockedCrate",
		Vector3.new(0, 3, 19),
		Vector3.new(4, 4, 4),
		Color3.fromRGB(145, 108, 78),
		0.7
	)
	locked.Locked = true
	addLabel(locked, "LOCKED - rejected")

	local weldedModel = Instance.new("Model")
	weldedModel.Name = "WeldedAssembly"
	weldedModel.Parent = physicsObjects
	local weldedRoot = createPart(
		weldedModel,
		"Root",
		Vector3.new(10, 3, 19),
		Vector3.new(4, 3, 3),
		Color3.fromRGB(92, 220, 152),
		0.7
	)
	local weldedWing = createPart(
		weldedModel,
		"Wing",
		Vector3.new(14, 3, 19),
		Vector3.new(4, 1.5, 2),
		Color3.fromRGB(66, 176, 122),
		0.7
	)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = weldedRoot
	weld.Part1 = weldedWing
	weld.Parent = weldedRoot
	weldedModel.PrimaryPart = weldedRoot
	addLabel(weldedRoot, "WELDED - valid")

	local disconnectedModel = Instance.new("Model")
	disconnectedModel.Name = "DisconnectedAssembly"
	disconnectedModel.Parent = physicsObjects
	local disconnectedA = createPart(
		disconnectedModel,
		"PartA",
		Vector3.new(22, 3, 18),
		Vector3.new(3, 3, 3),
		Color3.fromRGB(242, 214, 86),
		0.7
	)
	createPart(
		disconnectedModel,
		"PartB",
		Vector3.new(26, 3, 18),
		Vector3.new(3, 3, 3),
		Color3.fromRGB(208, 179, 60),
		0.7
	)
	addLabel(disconnectedA, "DISCONNECTED - rejected")
end

return table.freeze(TestArenaService)
