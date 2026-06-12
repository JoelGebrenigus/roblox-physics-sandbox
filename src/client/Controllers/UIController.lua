--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Constants = require(game:GetService("ReplicatedStorage").Shared.Constants)

local UIController = {}
UIController.__index = UIController

type UIControllerInternal = {
	player: Player,
	screenGui: ScreenGui,
	reticle: Frame,
	targetLabel: TextLabel,
	stateLabel: TextLabel,
	energyFill: Frame,
	energyText: TextLabel,
	chargeFrame: Frame,
	chargeFill: Frame,
	messageLabel: TextLabel,
	messageSerial: number,
	attributeConnections: { RBXScriptConnection },
}

export type UIController = typeof(setmetatable({} :: UIControllerInternal, UIController))

local function create(className: string, properties: { [string]: any }, parent: Instance?): Instance
	local instance = Instance.new(className)
	for key, value in properties do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function addCorner(parent: Instance, radius: number)
	create("UICorner", {
		CornerRadius = UDim.new(0, radius),
	}, parent)
end

local function addStroke(parent: Instance, color: Color3, transparency: number)
	create("UIStroke", {
		Color = color,
		Transparency = transparency,
		Thickness = 1,
	}, parent)
end

function UIController.new(): UIController
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local screenGui = playerGui:WaitForChild("TelekinesisGui") :: ScreenGui

	local oldRoot = screenGui:FindFirstChild("Root")
	if oldRoot then
		oldRoot:Destroy()
	end

	local root = create("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, screenGui)

	local reticle = create("Frame", {
		Name = "Reticle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(220, 226, 238),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(8, 8),
	}, root) :: Frame
	addCorner(reticle, 8)
	addStroke(reticle, Color3.fromRGB(20, 24, 32), 0.25)

	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(220, 226, 238),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.5, -10),
		Size = UDim2.fromOffset(2, 8),
	}, root)
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(220, 226, 238),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(2, 8),
	}, root)
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(220, 226, 238),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, -10, 0.5, 0),
		Size = UDim2.fromOffset(8, 2),
	}, root)
	create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(220, 226, 238),
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 10, 0.5, 0),
		Size = UDim2.fromOffset(8, 2),
	}, root)

	local targetPanel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(16, 20, 28),
		BackgroundTransparency = 0.14,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 0.5, 28),
		Size = UDim2.fromOffset(310, 62),
	}, root)
	addCorner(targetPanel, 8)
	addStroke(targetPanel, Color3.fromRGB(118, 152, 210), 0.55)

	local targetLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.fromOffset(12, 7),
		Size = UDim2.new(1, -24, 0, 24),
		Text = "Aim at a physics object",
		TextColor3 = Color3.fromRGB(233, 238, 248),
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, targetPanel) :: TextLabel

	local stateLabel = create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -24, 0, 20),
		Text = "E: grab",
		TextColor3 = Color3.fromRGB(151, 166, 190),
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, targetPanel) :: TextLabel

	local energyPanel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(16, 20, 28),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, -54),
		Size = UDim2.fromOffset(360, 42),
	}, root)
	addCorner(energyPanel, 9)
	addStroke(energyPanel, Color3.fromRGB(118, 152, 210), 0.55)

	create("TextLabel", {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		Position = UDim2.fromOffset(12, 5),
		Size = UDim2.fromOffset(72, 15),
		Text = "ENERGY",
		TextColor3 = Color3.fromRGB(154, 193, 255),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, energyPanel)

	local energyTrack = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(42, 48, 62),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 23),
		Size = UDim2.new(1, -24, 0, 8),
	}, energyPanel)
	addCorner(energyTrack, 6)

	local energyFill = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(75, 163, 255),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, energyTrack) :: Frame
	addCorner(energyFill, 6)

	local energyText = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(1, -12, 0, 4),
		Size = UDim2.fromOffset(80, 16),
		Text = "100 / 100",
		TextColor3 = Color3.fromRGB(205, 217, 236),
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, energyPanel) :: TextLabel

	local chargeFrame = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = Color3.fromRGB(16, 20, 28),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.fromOffset(240, 24),
		Visible = false,
	}, root) :: Frame
	addCorner(chargeFrame, 7)

	local chargeTrack = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(42, 48, 62),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
	}, chargeFrame)
	addCorner(chargeTrack, 5)

	local chargeFill = create("Frame", {
		BackgroundColor3 = Color3.fromRGB(186, 107, 255),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, chargeTrack) :: Frame
	addCorner(chargeFill, 5)

	local controls = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		Position = UDim2.new(0.5, 0, 1, -15),
		Size = UDim2.fromOffset(650, 24),
		Text = "E Grab/Drop     LMB Hold/Release Throw     Wheel Distance     R + Mouse Rotate",
		TextColor3 = Color3.fromRGB(154, 164, 183),
		TextSize = 12,
	}, root)
	controls.Name = "Controls"

	local messageLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(20, 23, 31),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(0.5, 0, 0.16, 0),
		Size = UDim2.fromOffset(430, 38),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 204, 117),
		TextSize = 14,
		TextTransparency = 1,
	}, root) :: TextLabel
	addCorner(messageLabel, 8)

	local self = setmetatable({
		player = player,
		screenGui = screenGui,
		reticle = reticle,
		targetLabel = targetLabel,
		stateLabel = stateLabel,
		energyFill = energyFill,
		energyText = energyText,
		chargeFrame = chargeFrame,
		chargeFill = chargeFill,
		messageLabel = messageLabel,
		messageSerial = 0,
		attributeConnections = {},
	}, UIController)

	local function updateEnergy()
		local energy = player:GetAttribute(Constants.PlayerAttributes.Energy)
		local maximum = player:GetAttribute(Constants.PlayerAttributes.MaxEnergy)
		local currentValue = if typeof(energy) == "number" then energy else Constants.MaxEnergy
		local maximumValue = if typeof(maximum) == "number" then maximum else Constants.MaxEnergy
		self:setEnergy(currentValue, maximumValue)
	end

	table.insert(
		self.attributeConnections,
		player:GetAttributeChangedSignal(Constants.PlayerAttributes.Energy):Connect(updateEnergy)
	)
	table.insert(
		self.attributeConnections,
		player:GetAttributeChangedSignal(Constants.PlayerAttributes.MaxEnergy):Connect(updateEnergy)
	)
	updateEnergy()

	return self
end

function UIController.setTarget(
	self: UIController,
	name: string?,
	mass: number?,
	distance: number?,
	valid: boolean,
	reason: string?
)
	if not name then
		self.targetLabel.Text = "Aim at a physics object"
		self.stateLabel.Text = "E: grab"
		self.stateLabel.TextColor3 = Color3.fromRGB(151, 166, 190)
		self.reticle.BackgroundColor3 = Color3.fromRGB(220, 226, 238)
		return
	end

	self.targetLabel.Text = string.format(
		"%s  |  %.0f mass  |  %.0f studs",
		name,
		mass or 0,
		distance or 0
	)
	if valid then
		self.stateLabel.Text = "E: grab"
		self.stateLabel.TextColor3 = Color3.fromRGB(121, 224, 180)
		self.reticle.BackgroundColor3 = Color3.fromRGB(91, 224, 171)
	else
		self.stateLabel.Text = reason or "Cannot grab"
		self.stateLabel.TextColor3 = Color3.fromRGB(236, 128, 128)
		self.reticle.BackgroundColor3 = Color3.fromRGB(238, 101, 101)
	end
end

function UIController.setHolding(self: UIController, name: string?, mass: number?, holdDistance: number?)
	if name then
		self.targetLabel.Text = string.format(
			"Holding %s  |  %.0f mass  |  %.0f studs",
			name,
			mass or 0,
			holdDistance or 0
		)
		self.stateLabel.Text = "E: drop  |  Hold LMB: charge throw"
		self.stateLabel.TextColor3 = Color3.fromRGB(154, 193, 255)
		self.reticle.BackgroundColor3 = Color3.fromRGB(104, 169, 255)
	else
		self:setTarget(nil, nil, nil, false, nil)
	end
end

function UIController.setHoldDistance(self: UIController, name: string, mass: number, holdDistance: number)
	self:setHolding(name, mass, holdDistance)
end

function UIController.setEnergy(self: UIController, energy: number, maximum: number)
	local ratio = if maximum > 0 then math.clamp(energy / maximum, 0, 1) else 0
	self.energyFill.Size = UDim2.fromScale(ratio, 1)
	self.energyText.Text = string.format("%d / %d", math.floor(energy + 0.5), math.floor(maximum + 0.5))
end

function UIController.setCharge(self: UIController, active: boolean, ratio: number)
	self.chargeFrame.Visible = active
	self.chargeFill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
end

function UIController.showMessage(self: UIController, message: string)
	self.messageSerial += 1
	local serial = self.messageSerial
	self.messageLabel.Text = message
	self.messageLabel.TextTransparency = 0
	self.messageLabel.BackgroundTransparency = 0.18

	task.delay(2.2, function()
		if serial ~= self.messageSerial then
			return
		end
		TweenService:Create(self.messageLabel, TweenInfo.new(0.3), {
			TextTransparency = 1,
			BackgroundTransparency = 1,
		}):Play()
	end)
end

return UIController
