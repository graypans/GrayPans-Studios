--!strict
-- Client bootstrap (placeholder while controllers are built; final wiring lands with M1 integration).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any

Util.log(("client up — v%s"):format(Config.Version))
