--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TelekinesisService = require(script.Parent.Systems.TelekinesisService)
local TestArenaService = require(script.Parent.Systems.TestArenaService)

local remoteSet = Remotes.ensureServer()
TestArenaService.initialize()
TelekinesisService.initialize(remoteSet)
