--[[
	Main client entry point.
	Everything in src/client runs on each player's device.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(("[%s] Client started (v%s)"):format(Config.GameName, Config.Version))
