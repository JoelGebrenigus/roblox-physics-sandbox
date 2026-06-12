--!strict

local UserInputService = game:GetService("UserInputService")

export type Callbacks = {
	onToggleGrab: () -> (),
	onChargeStart: () -> (),
	onChargeRelease: () -> (),
	onDistanceChanged: (number) -> (),
	onRotationChanged: (Vector2) -> (),
}

local InputController = {}
InputController.__index = InputController

type InputControllerInternal = {
	callbacks: Callbacks,
	rotating: boolean,
	connections: { RBXScriptConnection },
}

export type InputController = typeof(setmetatable({} :: InputControllerInternal, InputController))

function InputController.new(callbacks: Callbacks): InputController
	local self = setmetatable({
		callbacks = callbacks,
		rotating = false,
		connections = {},
	}, InputController)

	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.E then
			self.callbacks.onToggleGrab()
		elseif input.KeyCode == Enum.KeyCode.R then
			self.rotating = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.callbacks.onChargeStart()
		end
	end))

	table.insert(self.connections, UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.R then
			self.rotating = false
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			self.callbacks.onChargeRelease()
		end
	end))

	table.insert(self.connections, UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			self.callbacks.onDistanceChanged(input.Position.Z)
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and self.rotating then
			self.callbacks.onRotationChanged(Vector2.new(input.Delta.X, input.Delta.Y))
		end
	end))

	return self
end

function InputController.destroy(self: InputController)
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)
end

return InputController
