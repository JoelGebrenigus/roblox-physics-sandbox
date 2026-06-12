--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ObjectUtility = require(ReplicatedStorage.Shared.ObjectUtility)
local Types = require(ReplicatedStorage.Shared.Types)

local CameraController = require(script.Parent.CameraController)
local InputController = require(script.Parent.InputController)
local UIController = require(script.Parent.UIController)

type RemoteSet = Types.RemoteSet
type TelekinesisFeedback = Types.TelekinesisFeedback
type CameraControllerType = CameraController.CameraController
type InputControllerType = InputController.InputController
type UIControllerType = UIController.UIController

local TelekinesisController = {}
TelekinesisController.__index = TelekinesisController

type TelekinesisControllerInternal = {
	player: Player,
	remotes: RemoteSet,
	cameraController: CameraControllerType,
	inputController: InputControllerType?,
	uiController: UIControllerType,
	highlight: Highlight,
	currentTarget: BasePart?,
	heldRoot: BasePart?,
	heldName: string,
	heldMass: number,
	holdDistance: number,
	charging: boolean,
	chargeStartedAt: number,
	updateAccumulator: number,
	targetAccumulator: number,
	sequence: number,
	connections: { RBXScriptConnection },
}

export type TelekinesisController =
	typeof(setmetatable({} :: TelekinesisControllerInternal, TelekinesisController))

local function getDisplayName(root: BasePart): string
	local model = root:FindFirstAncestorOfClass("Model")
	if model and model.Parent ~= workspace then
		return model.Name
	end
	return root.Name
end

function TelekinesisController.new(remotes: RemoteSet): TelekinesisController
	local self = setmetatable({
		player = Players.LocalPlayer,
		remotes = remotes,
		cameraController = CameraController.new(),
		inputController = nil,
		uiController = UIController.new(),
		highlight = Instance.new("Highlight"),
		currentTarget = nil,
		heldRoot = nil,
		heldName = "",
		heldMass = 0,
		holdDistance = Constants.MinHoldDistance,
		charging = false,
		chargeStartedAt = 0,
		updateAccumulator = 0,
		targetAccumulator = 0,
		sequence = 0,
		connections = {},
	}, TelekinesisController)

	self.highlight.Name = "TelekinesisHighlight"
	self.highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	self.highlight.FillTransparency = 0.82
	self.highlight.OutlineTransparency = 0.05
	self.highlight.Enabled = false
	self.highlight.Parent = workspace

	self.inputController = InputController.new({
		onToggleGrab = function()
			self:toggleGrab()
		end,
		onChargeStart = function()
			self:startCharge()
		end,
		onChargeRelease = function()
			self:releaseCharge()
		end,
		onDistanceChanged = function(direction)
			self:changeHoldDistance(direction)
		end,
		onRotationChanged = function(delta)
			self:rotateObject(delta)
		end,
	})

	table.insert(self.connections, remotes.Feedback.OnClientEvent:Connect(function(feedback)
		self:handleFeedback(feedback)
	end))
	table.insert(self.connections, RunService.RenderStepped:Connect(function(deltaTime)
		self:onRenderStep(deltaTime)
	end))

	return self
end

function TelekinesisController.updateHoverTarget(self: TelekinesisController)
	local target = self.cameraController:getAimTarget(Constants.MaxGrabDistance, self.heldRoot)
	self.currentTarget = target

	if not target then
		self.highlight.Enabled = false
		self.highlight.Adornee = nil
		self.uiController:setTarget(nil, nil, nil, false, nil)
		return
	end

	local candidate, reason = ObjectUtility.validateCandidate(target)
	local cameraPosition = self.cameraController:getCameraCFrame().Position
	local distance = (target.Position - cameraPosition).Magnitude
	local valid = candidate ~= nil and distance <= Constants.MaxGrabDistance
	local mass = if candidate then candidate.mass else target.AssemblyMass

	self.highlight.Adornee = if candidate then candidate.container else target
	self.highlight.Enabled = true
	self.highlight.FillColor = if valid then Color3.fromRGB(61, 159, 255) else Color3.fromRGB(235, 75, 92)
	self.highlight.OutlineColor =
		if valid then Color3.fromRGB(159, 215, 255) else Color3.fromRGB(255, 173, 181)
	self.uiController:setTarget(
		getDisplayName(if candidate then candidate.root else target),
		mass,
		distance,
		valid,
		if distance > Constants.MaxGrabDistance then "Out of range" else reason
	)
end

function TelekinesisController.toggleGrab(self: TelekinesisController)
	if self.heldRoot then
		self.remotes.Action:FireServer({
			kind = "Drop",
		})
	elseif self.currentTarget then
		self.remotes.Action:FireServer({
			kind = "Grab",
			target = self.currentTarget,
		})
	else
		self.uiController:showMessage("No physics object targeted")
	end
end

function TelekinesisController.startCharge(self: TelekinesisController)
	if not self.heldRoot or self.charging then
		return
	end

	self.charging = true
	self.chargeStartedAt = os.clock()
	self.remotes.Action:FireServer({
		kind = "ChargeStart",
	})
end

function TelekinesisController.releaseCharge(self: TelekinesisController)
	if not self.charging then
		return
	end

	self.charging = false
	self.uiController:setCharge(false, 0)
	self.remotes.Action:FireServer({
		kind = "ChargeRelease",
	})
end

function TelekinesisController.changeHoldDistance(self: TelekinesisController, direction: number)
	if not self.heldRoot or direction == 0 then
		return
	end

	self.holdDistance = math.clamp(
		self.holdDistance + math.sign(direction) * Constants.HoldDistanceStep,
		Constants.MinHoldDistance,
		Constants.MaxHoldDistance
	)
	self.uiController:setHoldDistance(self.heldName, self.heldMass, self.holdDistance)
end

function TelekinesisController.rotateObject(self: TelekinesisController, delta: Vector2)
	if self.heldRoot then
		self.cameraController:rotateObject(delta)
	end
end

function TelekinesisController.handleFeedback(self: TelekinesisController, feedback: TelekinesisFeedback)
	if typeof(feedback) ~= "table" or typeof(feedback.kind) ~= "string" then
		return
	end

	if feedback.kind == "Grabbed" then
		self.heldRoot = feedback.root
		self.heldMass = feedback.mass
		self.holdDistance = feedback.holdDistance
		self.heldName = getDisplayName(feedback.root)
		self.charging = false
		self.cameraController:setObjectRotation(feedback.rotation)
		self.highlight.Adornee = feedback.root
		self.highlight.FillColor = Color3.fromRGB(61, 159, 255)
		self.highlight.OutlineColor = Color3.fromRGB(159, 215, 255)
		self.highlight.Enabled = true
		self.uiController:setHolding(self.heldName, self.heldMass, self.holdDistance)
	elseif feedback.kind == "Released" then
		self.heldRoot = nil
		self.heldMass = 0
		self.heldName = ""
		self.charging = false
		self.highlight.Enabled = false
		self.highlight.Adornee = nil
		self.uiController:setCharge(false, 0)
		if feedback.reason ~= "Dropped" and feedback.reason ~= "Thrown" then
			self.uiController:showMessage(feedback.reason)
		end
	elseif feedback.kind == "Rejected" then
		self.charging = false
		self.uiController:setCharge(false, 0)
		self.uiController:showMessage(feedback.message)
	elseif feedback.kind == "Charge" then
		self.charging = feedback.active and self.heldRoot ~= nil
		if self.charging then
			self.chargeStartedAt = os.clock()
		end
	end
end

function TelekinesisController.sendHoldUpdate(self: TelekinesisController)
	if not self.heldRoot then
		return
	end

	self.sequence += 1
	local massRatio = math.clamp(self.heldMass / Constants.MaxObjectMass, 0, 1)
	local now = os.clock()
	local swayScale = 0.35 + massRatio * 0.65
	local swayPitch = math.rad(Constants.SwayRotationDegrees) * math.sin(now * 1.7) * swayScale
	local swayYaw = math.rad(Constants.SwayRotationDegrees) * math.sin(now * 1.13 + 1.2) * swayScale
	local distanceSway = Constants.SwayPositionAmplitude * math.sin(now * 1.4) * swayScale

	local cameraCFrame = self.cameraController:getCameraCFrame()
	local requestedCamera = cameraCFrame * CFrame.Angles(swayPitch * 0.35, swayYaw * 0.35, 0)
	local targetRotation =
		self.cameraController:getObjectRotation() * CFrame.Angles(swayPitch, swayYaw, 0)

	self.remotes.Update:FireServer({
		cameraCFrame = requestedCamera,
		targetCFrame = targetRotation,
		holdDistance = math.clamp(
			self.holdDistance + distanceSway,
			Constants.MinHoldDistance,
			Constants.MaxHoldDistance
		),
		sequence = self.sequence,
	})
end

function TelekinesisController.onRenderStep(self: TelekinesisController, deltaTime: number)
	if self.heldRoot and not self.heldRoot.Parent then
		self.heldRoot = nil
		self.charging = false
		self.highlight.Enabled = false
		self.highlight.Adornee = nil
		self.uiController:setCharge(false, 0)
		self.uiController:setHolding(nil, nil, nil)
	end

	self.updateAccumulator += deltaTime
	if self.heldRoot and self.updateAccumulator >= 1 / Constants.ClientUpdateRate then
		self.updateAccumulator %= 1 / Constants.ClientUpdateRate
		self:sendHoldUpdate()
	end

	self.targetAccumulator += deltaTime
	if not self.heldRoot and self.targetAccumulator >= 1 / Constants.ClientTargetRefreshRate then
		self.targetAccumulator %= 1 / Constants.ClientTargetRefreshRate
		self:updateHoverTarget()
	end

	if self.charging then
		local ratio = math.clamp(
			(os.clock() - self.chargeStartedAt) / Constants.MaximumChargeTime,
			0,
			1
		)
		self.uiController:setCharge(true, ratio)
	end
end

return TelekinesisController
