--!strict

local Constants = require(script.Parent.Constants)

local PhysicsUtility = {}

function PhysicsUtility.isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function PhysicsUtility.isFiniteCFrame(value: any): boolean
	if typeof(value) ~= "CFrame" then
		return false
	end

	for _, component in { value:GetComponents() } do
		if not PhysicsUtility.isFiniteNumber(component) then
			return false
		end
	end

	return true
end

function PhysicsUtility.massRatio(mass: number): number
	return math.clamp(mass / Constants.MaxObjectMass, 0, 1)
end

function PhysicsUtility.distanceRatio(distance: number): number
	return math.clamp(
		(distance - Constants.MinHoldDistance) / (Constants.MaxHoldDistance - Constants.MinHoldDistance),
		0,
		1
	)
end

function PhysicsUtility.controlAcceleration(mass: number): number
	return Constants.MaximumControlAcceleration
		+ (Constants.MinimumControlAcceleration - Constants.MaximumControlAcceleration)
			* PhysicsUtility.massRatio(mass)
end

function PhysicsUtility.responsiveness(mass: number): number
	return Constants.MaximumResponsiveness
		+ (Constants.MinimumResponsiveness - Constants.MaximumResponsiveness) * PhysicsUtility.massRatio(mass)
end

function PhysicsUtility.controlSpeed(mass: number): number
	return Constants.MaximumControlSpeed
		+ (Constants.MinimumControlSpeed - Constants.MaximumControlSpeed) * PhysicsUtility.massRatio(mass)
end

function PhysicsUtility.throwSpeed(mass: number, chargeRatio: number): number
	local chargedSpeed = Constants.MinimumThrowSpeed
		+ (Constants.MaximumThrowSpeed - Constants.MinimumThrowSpeed) * math.clamp(chargeRatio, 0, 1)
	local massMultiplier = 1 - 0.6 * PhysicsUtility.massRatio(mass)
	return chargedSpeed * massMultiplier
end

function PhysicsUtility.energyDrainPerSecond(mass: number, holdDistance: number): number
	return Constants.EnergyDrainBase
		+ Constants.EnergyDrainMass * PhysicsUtility.massRatio(mass)
		+ Constants.EnergyDrainDistance * PhysicsUtility.distanceRatio(holdDistance)
end

function PhysicsUtility.clampVectorStep(current: Vector3, desired: Vector3, maximumStep: number): Vector3
	local offset = desired - current
	if offset.Magnitude <= maximumStep then
		return desired
	end

	return current + offset.Unit * maximumStep
end

function PhysicsUtility.clampRotation(current: CFrame, desired: CFrame, maximumRadians: number): CFrame
	local relative = current:ToObjectSpace(desired.Rotation)
	local axis, angle = relative:ToAxisAngle()
	if angle <= maximumRadians then
		return desired.Rotation
	end

	return current.Rotation * CFrame.fromAxisAngle(axis, maximumRadians)
end

function PhysicsUtility.createHoverConstraints(root: BasePart, mass: number): (Attachment, AlignPosition, AlignOrientation)
	local attachment = Instance.new("Attachment")
	attachment.Name = "TelekinesisAttachment"
	attachment.Parent = root

	local alignPosition = Instance.new("AlignPosition")
	alignPosition.Name = "TelekinesisAlignPosition"
	alignPosition.Mode = Enum.PositionAlignmentMode.OneAttachment
	alignPosition.Attachment0 = attachment
	alignPosition.ApplyAtCenterOfMass = true
	alignPosition.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	alignPosition.MaxForce = mass * (workspace.Gravity + PhysicsUtility.controlAcceleration(mass))
	alignPosition.MaxVelocity = PhysicsUtility.controlSpeed(mass)
	alignPosition.Responsiveness = PhysicsUtility.responsiveness(mass)
	alignPosition.RigidityEnabled = false
	alignPosition.Parent = root

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "TelekinesisAlignOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.MaxAngularVelocity = math.rad(Constants.RotationSpeedDegrees)
	alignOrientation.MaxTorque = mass * workspace.Gravity * math.max(root.Size.Magnitude, 4)
	alignOrientation.Responsiveness = PhysicsUtility.responsiveness(mass)
	alignOrientation.RigidityEnabled = false
	alignOrientation.Parent = root

	return attachment, alignPosition, alignOrientation
end

function PhysicsUtility.hasLineOfSight(
	origin: Vector3,
	target: Vector3,
	ignoredInstances: { Instance },
	allowedParts: { BasePart }
): boolean
	local direction = target - origin
	if direction.Magnitude < 0.05 then
		return true
	end

	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = ignoredInstances
	parameters.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, parameters)
	if not result then
		return true
	end

	for _, part in allowedParts do
		if result.Instance == part then
			return true
		end
	end

	return false
end

return table.freeze(PhysicsUtility)
