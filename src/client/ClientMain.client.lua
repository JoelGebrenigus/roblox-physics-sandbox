--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TelekinesisController = require(script.Parent.Controllers.TelekinesisController)

local remoteSet = Remotes.getClient()
TelekinesisController.new(remoteSet)
