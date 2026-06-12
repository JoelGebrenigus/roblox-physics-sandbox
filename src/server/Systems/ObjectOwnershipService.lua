--!strict

local PhysicsService = game:GetService("PhysicsService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)

export type CollisionSnapshot = { [BasePart]: string }

local ObjectOwnershipService = {}

local function registerCollisionGroup(name: string)
	pcall(function()
		PhysicsService:RegisterCollisionGroup(name)
	end)
end

local function setCharacterPart(part: BasePart)
	part.CollisionGroup = Constants.CollisionGroups.Characters
end

function ObjectOwnershipService.initialize()
	registerCollisionGroup(Constants.CollisionGroups.Characters)
	registerCollisionGroup(Constants.CollisionGroups.HeldObjects)

	PhysicsService:CollisionGroupSetCollidable(
		Constants.CollisionGroups.HeldObjects,
		Constants.CollisionGroups.Characters,
		false
	)
	PhysicsService:CollisionGroupSetCollidable(Constants.CollisionGroups.HeldObjects, "Default", true)
end

function ObjectOwnershipService.initializeCharacter(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			setCharacterPart(descendant)
		end
	end

	character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			setCharacterPart(descendant)
		end
	end)
end

function ObjectOwnershipService.takeForPlayer(
	root: BasePart,
	parts: { BasePart },
	player: Player
): (boolean, CollisionSnapshot)
	local snapshot: CollisionSnapshot = {}
	for _, part in parts do
		snapshot[part] = part.CollisionGroup
		part.CollisionGroup = Constants.CollisionGroups.HeldObjects
	end

	local success = pcall(function()
		local canSet, reason = root:CanSetNetworkOwnership()
		if not canSet then
			error(reason)
		end
		root:SetNetworkOwner(player)
	end)

	if not success then
		for part, collisionGroup in snapshot do
			if part.Parent then
				part.CollisionGroup = collisionGroup
			end
		end
	end

	return success, snapshot
end

function ObjectOwnershipService.releaseToServer(
	root: BasePart,
	snapshot: CollisionSnapshot,
	restoreDelay: number,
	automaticOwnershipDelay: number
)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	task.delay(restoreDelay, function()
		for part, collisionGroup in snapshot do
			if part.Parent then
				part.CollisionGroup = collisionGroup
			end
		end
	end)

	task.delay(automaticOwnershipDelay, function()
		if root.Parent and not root.Anchored then
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
	end)
end

return table.freeze(ObjectOwnershipService)
