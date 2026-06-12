--!strict

local Players = game:GetService("Players")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)

local CameraController = {}
CameraController.__index = CameraController

type CameraControllerInternal = {
	player: Player,
	objectRotation: CFrame,
}

export type CameraController = typeof(setmetatable({} :: CameraControllerInternal, CameraController))

function CameraController.new(): CameraController
	return setmetatable({
		player = Players.LocalPlayer,
		objectRotation = CFrame.identity,
	}, CameraController)
end

function CameraController.getCameraCFrame(_self: CameraController): CFrame
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame else CFrame.identity
end

function CameraController.getAimTarget(self: CameraController, maximumDistance: number, ignored: Instance?): BasePart?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end

	local ignoredInstances: { Instance } = {}
	if self.player.Character then
		table.insert(ignoredInstances, self.player.Character)
	end
	if ignored then
		table.insert(ignoredInstances, ignored)
	end

	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = ignoredInstances
	parameters.IgnoreWater = true

	local result = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * maximumDistance, parameters)
	if result and result.Instance:IsA("BasePart") then
		return result.Instance
	end

	return nil
end

function CameraController.setObjectRotation(self: CameraController, rotation: CFrame)
	self.objectRotation = rotation.Rotation
end

function CameraController.rotateObject(self: CameraController, mouseDelta: Vector2)
	local cameraCFrame = self:getCameraCFrame()
	local yaw = CFrame.fromAxisAngle(Vector3.yAxis, -mouseDelta.X * Constants.MouseRotationSensitivity)
	local pitch = CFrame.fromAxisAngle(
		cameraCFrame.RightVector,
		-mouseDelta.Y * Constants.MouseRotationSensitivity
	)
	self.objectRotation = (pitch * yaw * self.objectRotation).Rotation
end

function CameraController.getObjectRotation(self: CameraController): CFrame
	return self.objectRotation
end

return CameraController
