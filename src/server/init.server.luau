--!strict
-- Server bootstrap (placeholder while services are built; final wiring lands with M1 integration).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any

Remotes.init()
Util.log(("server up — v%s (%s)"):format(Config.Version, Config.BuildStamp))
