--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ObjectUtility = require(ReplicatedStorage.Shared.ObjectUtility)
local PhysicsUtility = require(ReplicatedStorage.Shared.PhysicsUtility)
local Types = require(ReplicatedStorage.Shared.Types)

local AntiExploitService = require(script.Parent.AntiExploitService)
local CooldownService = require(script.Parent.CooldownService)
local ObjectOwnershipService = require(script.Parent.ObjectOwnershipService)

type Candidate = Types.Candidate
type RemoteSet = Types.RemoteSet
type CollisionSnapshot = ObjectOwnershipService.CollisionSnapshot

type HeldState = {
	player: Player,
	root: BasePart,
	parts: { BasePart },
	mass: number,
	holdDistance: number,
	targetPosition: Vector3,
	targetRotation: CFrame,
	lastLookVector: Vector3,
	lastUpdateAt: number,
	lastSequence: number,
	lastOwnershipCheckAt: number,
	obstructedSince: number?,
	chargeStartedAt: number?,
	attachment: Attachment,
	alignPosition: AlignPosition,
	alignOrientation: AlignOrientation,
	collisionSnapshot: CollisionSnapshot,
}

local TelekinesisService = {}

local remotes: RemoteSet
local heldByPlayer: { [Player]: HeldState } = {}
local holderByRoot: { [BasePart]: Player } = {}
local lastEnergyUse: { [number]: number } = {}

local function getAliveCharacter(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end

	local head = character:FindFirstChild("Head")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not head or not head:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil, nil, nil
	end

	return character, head, humanoid
end

local function getEnergy(player: Player): number
	local value = player:GetAttribute(Constants.PlayerAttributes.Energy)
	return if typeof(value) == "number" then value else Constants.MaxEnergy
end

local function setEnergy(player: Player, value: number)
	player:SetAttribute(Constants.PlayerAttributes.Energy, math.clamp(value, 0, Constants.MaxEnergy))
end

local function sendRejected(player: Player, code: string, message: string)
	remotes.Feedback:FireClient(player, {
		kind = "Rejected",
		code = code,
		message = message,
	})
end

local function markEnergyUse(player: Player)
	lastEnergyUse[player.UserId] = os.clock()
end

local function destroyConstraints(state: HeldState)
	state.alignPosition:Destroy()
	state.alignOrientation:Destroy()
	state.attachment:Destroy()
end

local function releaseState(player: Player, reason: string, throwObject: boolean)
	local state = heldByPlayer[player]
	if not state then
		return
	end

	heldByPlayer[player] = nil
	holderByRoot[state.root] = nil
	player:SetAttribute(Constants.PlayerAttributes.Holding, false)

	local chargeStartedAt = state.chargeStartedAt
	local throwDirection = state.lastLookVector
	local root = state.root
	local mass = state.mass
	local snapshot = state.collisionSnapshot

	destroyConstraints(state)

	if throwObject and (not chargeStartedAt or not root.Parent) then
		throwObject = false
		reason = "Object unavailable"
	end

	if throwObject and chargeStartedAt and root.Parent then
		local energy = getEnergy(player)
		if energy < Constants.ThrowEnergyCost then
			throwObject = false
			reason = "Not enough energy to throw"
		else
			setEnergy(player, energy - Constants.ThrowEnergyCost)
			markEnergyUse(player)
			local chargeRatio = math.clamp(
				(os.clock() - chargeStartedAt) / Constants.MaximumChargeTime,
				0,
				1
			)
			local speed = PhysicsUtility.throwSpeed(mass, chargeRatio)
			ObjectOwnershipService.releaseToServer(
				root,
				snapshot,
				Constants.ServerOwnershipDuration,
				Constants.ServerOwnershipDuration
			)
			local impulseApplied = pcall(function()
				root:ApplyImpulse(throwDirection.Unit * mass * speed)
			end)
			if not impulseApplied then
				throwObject = false
				reason = "Throw impulse failed"
			end
		end
	end

	if not throwObject then
		ObjectOwnershipService.releaseToServer(root, snapshot, 0.15, Constants.ServerOwnershipDuration)
	end

	remotes.Feedback:FireClient(player, {
		kind = "Released",
		reason = reason,
		thrown = throwObject,
	})
end

local function rejectOrReleaseForViolation(player: Player, reason: string)
	if AntiExploitService.recordViolation(player, reason) and heldByPlayer[player] then
		releaseState(player, "Invalid control data", false)
	end
end

local function beginGrab(player: Player, target: Instance)
	if heldByPlayer[player] then
		sendRejected(player, "AlreadyHolding", "Drop the current object first")
		return
	end

	if not CooldownService.consume(player, "Grab", Constants.GrabCooldown) then
		return
	end

	local character, head = getAliveCharacter(player)
	if not character or not head then
		sendRejected(player, "NoCharacter", "Your character is not ready")
		return
	end

	if getEnergy(player) < Constants.MinimumGrabEnergy then
		sendRejected(player, "NoEnergy", "Not enough telekinesis energy")
		return
	end

	if not target:IsA("BasePart") then
		sendRejected(player, "InvalidObject", "Target is not a physics part")
		return
	end

	local candidate, rejection = ObjectUtility.validateCandidate(target)
	if not candidate then
		sendRejected(player, "InvalidObject", rejection or "Object cannot be grabbed")
		return
	end

	if holderByRoot[candidate.root] then
		sendRejected(player, "InUse", "Another player is controlling this object")
		return
	end

	local targetDistance = (target.Position - head.Position).Magnitude
	if targetDistance > Constants.MaxGrabDistance then
		sendRejected(player, "OutOfRange", "Object is out of range")
		return
	end

	if not PhysicsUtility.hasLineOfSight(head.Position, target.Position, { character }, candidate.parts) then
		sendRejected(player, "NoLineOfSight", "A solid object blocks telekinesis")
		return
	end

	local holdDistance = math.clamp(targetDistance, Constants.MinHoldDistance, Constants.MaxHoldDistance)
	local targetPosition = head.Position + head.CFrame.LookVector * holdDistance
	local attachment, alignPosition, alignOrientation =
		PhysicsUtility.createHoverConstraints(candidate.root, candidate.mass)
	alignPosition.Position = targetPosition
	alignOrientation.CFrame = candidate.root.CFrame.Rotation

	local ownershipSet, collisionSnapshot =
		ObjectOwnershipService.takeForPlayer(candidate.root, candidate.parts, player)
	if not ownershipSet then
		attachment:Destroy()
		alignPosition:Destroy()
		alignOrientation:Destroy()
		sendRejected(player, "OwnershipUnavailable", "Object physics ownership is unavailable")
		return
	end

	local now = os.clock()
	local state: HeldState = {
		player = player,
		root = candidate.root,
		parts = candidate.parts,
		mass = candidate.mass,
		holdDistance = holdDistance,
		targetPosition = targetPosition,
		targetRotation = candidate.root.CFrame.Rotation,
		lastLookVector = head.CFrame.LookVector,
		lastUpdateAt = now,
		lastSequence = -1,
		lastOwnershipCheckAt = now,
		obstructedSince = nil,
		chargeStartedAt = nil,
		attachment = attachment,
		alignPosition = alignPosition,
		alignOrientation = alignOrientation,
		collisionSnapshot = collisionSnapshot,
	}

	heldByPlayer[player] = state
	holderByRoot[candidate.root] = player
	player:SetAttribute(Constants.PlayerAttributes.Holding, true)
	markEnergyUse(player)

	remotes.Feedback:FireClient(player, {
		kind = "Grabbed",
		root = candidate.root,
		mass = candidate.mass,
		holdDistance = holdDistance,
		rotation = candidate.root.CFrame.Rotation,
	})
end

local function handleAction(player: Player, action: any)
	if
		not AntiExploitService.allowRequest(
			player,
			"Action",
			Constants.ActionRequestsPerWindow,
			Constants.RateLimitWindow
		)
	then
		rejectOrReleaseForViolation(player, "action rate limit exceeded")
		return
	end

	if not AntiExploitService.validateAction(action) then
		rejectOrReleaseForViolation(player, "malformed action")
		return
	end

	if action.kind == "Grab" then
		beginGrab(player, action.target)
	elseif action.kind == "Drop" then
		if CooldownService.consume(player, "Drop", Constants.DropCooldown) then
			releaseState(player, "Dropped", false)
		end
	elseif action.kind == "ChargeStart" then
		local state = heldByPlayer[player]
		if state and CooldownService.consume(player, "Charge", Constants.ChargeCooldown) then
			state.chargeStartedAt = os.clock()
			remotes.Feedback:FireClient(player, {
				kind = "Charge",
				active = true,
			})
		end
	elseif action.kind == "ChargeRelease" then
		local state = heldByPlayer[player]
		if state and state.chargeStartedAt and CooldownService.consume(player, "Throw", Constants.ThrowCooldown) then
			releaseState(player, "Thrown", true)
		end
	end
end

local function handleUpdate(player: Player, update: any)
	if
		not AntiExploitService.allowRequest(
			player,
			"Update",
			Constants.UpdateRequestsPerWindow,
			Constants.RateLimitWindow
		)
	then
		rejectOrReleaseForViolation(player, "update rate limit exceeded")
		return
	end

	if not AntiExploitService.validateUpdate(update) then
		rejectOrReleaseForViolation(player, "malformed hold update")
		return
	end

	local state = heldByPlayer[player]
	if not state then
		return
	end

	local character, head = getAliveCharacter(player)
	if not character or not head then
		releaseState(player, "Character unavailable", false)
		return
	end

	if update.sequence <= state.lastSequence then
		return
	end

	local cameraCFrame: CFrame = update.cameraCFrame
	if (cameraCFrame.Position - head.Position).Magnitude > Constants.MaxCameraOffsetFromHead then
		rejectOrReleaseForViolation(player, "camera origin too far from character")
		return
	end

	local now = os.clock()
	local elapsed = math.clamp(now - state.lastUpdateAt, 1 / 60, 0.25)
	local holdDistance = math.clamp(
		update.holdDistance,
		Constants.MinHoldDistance,
		Constants.MaxHoldDistance
	)

	-- The client requests camera direction and rotation, but the server reconstructs
	-- and speed-limits the world-space target instead of trusting a supplied position.
	local requestedPosition = cameraCFrame.Position + cameraCFrame.LookVector * holdDistance
	local maximumStep = PhysicsUtility.controlSpeed(state.mass) * elapsed + 0.5
	local targetPosition =
		PhysicsUtility.clampVectorStep(state.targetPosition, requestedPosition, maximumStep)
	local requestedRotation = update.targetCFrame.Rotation
	local targetRotation = PhysicsUtility.clampRotation(
		state.targetRotation,
		requestedRotation,
		math.rad(Constants.RotationSpeedDegrees) * elapsed
	)

	state.holdDistance = holdDistance
	state.targetPosition = targetPosition
	state.targetRotation = targetRotation
	state.lastLookVector = cameraCFrame.LookVector
	state.lastUpdateAt = now
	state.lastSequence = update.sequence
	state.alignPosition.Position = targetPosition
	state.alignOrientation.CFrame = targetRotation
end

local function hasSameParts(first: { BasePart }, second: { BasePart }): boolean
	if #first ~= #second then
		return false
	end

	for _, part in first do
		if not table.find(second, part) then
			return false
		end
	end

	return true
end

local function monitorState(state: HeldState, now: number): string?
	local character, head = getAliveCharacter(state.player)
	if not character or not head then
		return "Character unavailable"
	end

	if not state.root.Parent then
		return "Object removed"
	end

	if now - state.lastUpdateAt > Constants.UpdateTimeout then
		return "Control updates stopped"
	end

	if (state.root.Position - head.Position).Magnitude > Constants.MaxGrabDistance + 10 then
		return "Object moved out of range"
	end

	if (state.root.Position - state.targetPosition).Magnitude > Constants.MaxPositionError then
		return "Object position became invalid"
	end

	local velocityLimit = PhysicsUtility.controlSpeed(state.mass) * 4 + 20
	if state.root.AssemblyLinearVelocity.Magnitude > velocityLimit then
		return "Object velocity became invalid"
	end

	if PhysicsUtility.hasLineOfSight(head.Position, state.root.Position, { character }, state.parts) then
		state.obstructedSince = nil
	elseif not state.obstructedSince then
		state.obstructedSince = now
	elseif now - state.obstructedSince >= Constants.LineOfSightGracePeriod then
		return "Line of sight lost"
	end

	if now - state.lastOwnershipCheckAt >= Constants.OwnershipCheckInterval then
		state.lastOwnershipCheckAt = now
		local candidate, rejection = ObjectUtility.validateCandidate(state.root)
		if not candidate or candidate.root ~= state.root then
			return rejection or "Object assembly changed"
		end
		if not hasSameParts(state.parts, candidate.parts) then
			return "Object assembly changed"
		end

		state.mass = candidate.mass
		state.parts = candidate.parts
		state.alignPosition.MaxForce =
			state.mass * (workspace.Gravity + PhysicsUtility.controlAcceleration(state.mass))
		state.alignPosition.MaxVelocity = PhysicsUtility.controlSpeed(state.mass)
		state.alignPosition.Responsiveness = PhysicsUtility.responsiveness(state.mass)
		state.alignOrientation.Responsiveness = PhysicsUtility.responsiveness(state.mass)

		local ownershipValid = pcall(function()
			local canSet = state.root:CanSetNetworkOwnership()
			if not canSet then
				error("network ownership locked")
			end
			local owner = state.root:GetNetworkOwner()
			if owner and owner ~= state.player then
				error("network ownership changed")
			end
		end)
		if not ownershipValid then
			return "Object ownership became invalid"
		end
	end

	return nil
end

local function onHeartbeat(deltaTime: number)
	local now = os.clock()
	local releases: { { player: Player, reason: string } } = {}

	for player, state in heldByPlayer do
		local invalidReason = monitorState(state, now)
		if invalidReason then
			table.insert(releases, {
				player = player,
				reason = invalidReason,
			})
		else
			local drain = PhysicsUtility.energyDrainPerSecond(state.mass, state.holdDistance) * deltaTime
			setEnergy(player, getEnergy(player) - drain)
			markEnergyUse(player)
			if getEnergy(player) <= 0 then
				table.insert(releases, {
					player = player,
					reason = "Energy exhausted",
				})
			end
		end
	end

	for _, release in releases do
		releaseState(release.player, release.reason, false)
	end

	for _, player in Players:GetPlayers() do
		if not heldByPlayer[player] then
			local lastUse = lastEnergyUse[player.UserId] or 0
			if now - lastUse >= Constants.EnergyRegenerationDelay then
				setEnergy(player, getEnergy(player) + Constants.EnergyRegenerationRate * deltaTime)
			end
		end
	end
end

local function initializePlayer(player: Player)
	player:SetAttribute(Constants.PlayerAttributes.MaxEnergy, Constants.MaxEnergy)
	setEnergy(player, Constants.MaxEnergy)
	player:SetAttribute(Constants.PlayerAttributes.Holding, false)
	lastEnergyUse[player.UserId] = 0

	local function onCharacterAdded(character: Model)
		releaseState(player, "Character respawned", false)
		ObjectOwnershipService.initializeCharacter(character)

		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				releaseState(player, "Character died", false)
			end)
		end
	end

	if player.Character then
		task.defer(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

function TelekinesisService.initialize(remoteSet: RemoteSet)
	remotes = remoteSet

	ObjectOwnershipService.initialize()
	for _, player in Players:GetPlayers() do
		initializePlayer(player)
	end

	Players.PlayerAdded:Connect(initializePlayer)
	Players.PlayerRemoving:Connect(function(player)
		releaseState(player, "Player left", false)
		CooldownService.clearPlayer(player)
		AntiExploitService.clearPlayer(player)
		lastEnergyUse[player.UserId] = nil
	end)

	remotes.Action.OnServerEvent:Connect(handleAction)
	remotes.Update.OnServerEvent:Connect(handleUpdate)
	RunService.Heartbeat:Connect(onHeartbeat)
end

return table.freeze(TelekinesisService)
