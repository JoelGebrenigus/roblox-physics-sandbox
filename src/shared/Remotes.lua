--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Constants)
local Types = require(script.Parent.Types)

type RemoteSet = Types.RemoteSet

local Remotes = {}

local function getRemote(folder: Instance, name: string): RemoteEvent
	local remote = folder:FindFirstChild(name)
	assert(remote and remote:IsA("RemoteEvent"), string.format("Missing RemoteEvent %s", name))
	return remote
end

function Remotes.ensureServer(): RemoteSet
	assert(RunService:IsServer(), "Remotes.ensureServer can only be used on the server")

	local folder = ReplicatedStorage:FindFirstChild(Constants.RemoteFolderName)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Constants.RemoteFolderName
		folder.Parent = ReplicatedStorage
	end

	for _, name in Constants.RemoteNames do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	return {
		Action = getRemote(folder, Constants.RemoteNames.Action),
		Update = getRemote(folder, Constants.RemoteNames.Update),
		Feedback = getRemote(folder, Constants.RemoteNames.Feedback),
	}
end

function Remotes.getClient(): RemoteSet
	assert(RunService:IsClient(), "Remotes.getClient can only be used on the client")

	local folder = ReplicatedStorage:WaitForChild(Constants.RemoteFolderName)
	return {
		Action = folder:WaitForChild(Constants.RemoteNames.Action) :: RemoteEvent,
		Update = folder:WaitForChild(Constants.RemoteNames.Update) :: RemoteEvent,
		Feedback = folder:WaitForChild(Constants.RemoteNames.Feedback) :: RemoteEvent,
	}
end

return table.freeze(Remotes)
