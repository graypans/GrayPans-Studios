--[[
	Main server entry point.
	Everything in src/server runs on the Roblox server only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(("[%s] Server started (v%s)"):format(Config.GameName, Config.Version))

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	print(("[%s] %s joined the game"):format(Config.GameName, player.Name))
end)

Players.PlayerRemoving:Connect(function(player)
	print(("[%s] %s left the game"):format(Config.GameName, player.Name))
end)
