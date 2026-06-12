--!strict

local CollectionService = game:GetService("CollectionService")

local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

type Candidate = Types.Candidate

local ObjectUtility = {}

local function hasTagOnSelfOrAncestor(instance: Instance, tag: string): boolean
	local current: Instance? = instance
	while current and current ~= workspace.Parent do
		if CollectionService:HasTag(current, tag) then
			return true
		end
		current = current.Parent
	end
	return false
end

local function getNearestModel(instance: Instance): Model?
	local current = instance.Parent
	while current and current ~= workspace do
		if current:IsA("Model") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function isCharacterPart(part: BasePart): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function getAssemblyParts(root: BasePart): { BasePart }
	local parts = root:GetConnectedParts(true)
	if not table.find(parts, root) then
		table.insert(parts, root)
	end
	return parts
end

local function getBounds(parts: { BasePart }): Vector3
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in parts do
		local halfSize = part.Size * 0.5
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local corner = part.CFrame:PointToWorldSpace(
						Vector3.new(halfSize.X * x, halfSize.Y * y, halfSize.Z * z)
					)
					minimum = Vector3.new(
						math.min(minimum.X, corner.X),
						math.min(minimum.Y, corner.Y),
						math.min(minimum.Z, corner.Z)
					)
					maximum = Vector3.new(
						math.max(maximum.X, corner.X),
						math.max(maximum.Y, corner.Y),
						math.max(maximum.Z, corner.Z)
					)
				end
			end
		end
	end

	return maximum - minimum
end

local function modelIsSingleAssembly(model: Model, assemblyParts: { BasePart }): boolean
	local assemblySet: { [BasePart]: boolean } = {}
	for _, part in assemblyParts do
		assemblySet[part] = true
	end

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not assemblySet[descendant] then
			return false
		end
	end

	return true
end

function ObjectUtility.validateCandidate(target: Instance): (Candidate?, string?)
	if not target:IsA("BasePart") or not target:IsDescendantOf(workspace) then
		return nil, "Target is not a world physics part"
	end

	if isCharacterPart(target) then
		return nil, "Characters cannot be grabbed"
	end

	local physicsObjects = workspace:FindFirstChild("PhysicsObjects")
	local isInPhysicsFolder = physicsObjects ~= nil and target:IsDescendantOf(physicsObjects)
	if not isInPhysicsFolder and not hasTagOnSelfOrAncestor(target, Constants.Tags.Allowed) then
		return nil, "Object is not marked as telekinesis-enabled"
	end

	if
		hasTagOnSelfOrAncestor(target, Constants.Tags.Protected)
		or hasTagOnSelfOrAncestor(target, Constants.Tags.Blocked)
	then
		return nil, "Object is protected"
	end

	local root = target.AssemblyRootPart or target
	local parts = getAssemblyParts(root)
	if #parts > Constants.MaxObjectParts then
		return nil, string.format("Object has too many connected parts (%d/%d)", #parts, Constants.MaxObjectParts)
	end

	local mass = 0
	for _, part in parts do
		if part.Anchored then
			return nil, "Anchored objects cannot be grabbed"
		end
		if part.Locked then
			return nil, "Locked objects cannot be grabbed"
		end
		if isCharacterPart(part) then
			return nil, "Character assemblies cannot be grabbed"
		end
		if
			hasTagOnSelfOrAncestor(part, Constants.Tags.Protected)
			or hasTagOnSelfOrAncestor(part, Constants.Tags.Blocked)
		then
			return nil, "Object is protected"
		end
		mass += part:GetMass()
	end

	if mass > Constants.MaxObjectMass then
		return nil, string.format("Object is too heavy (%.0f/%.0f)", mass, Constants.MaxObjectMass)
	end

	local model = getNearestModel(target)
	if model and not modelIsSingleAssembly(model, parts) then
		return nil, "Object model contains disconnected parts"
	end

	local bounds = getBounds(parts)
	if math.max(bounds.X, bounds.Y, bounds.Z) > Constants.MaxObjectBounds then
		return nil, string.format("Object is too large (maximum %.0f studs)", Constants.MaxObjectBounds)
	end

	return {
		root = root,
		parts = parts,
		mass = mass,
		bounds = bounds,
		container = model or root,
	}, nil
end

function ObjectUtility.containsPart(parts: { BasePart }, instance: Instance): boolean
	for _, part in parts do
		if instance == part then
			return true
		end
	end
	return false
end

return table.freeze(ObjectUtility)
