--!strict
-- Client bootstrap: init every controller, each pcall'd so one failure can't kill the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"Toast",
	"Hud",
	"MinigameController",
	"NamingUI",
	"LedgerUI",
	"BanishConfirmUI",
	"RecapUI",
	"Shop",
	"Classes",
	"Journal",
	"InviteButton",
	"JoinSquareUI",
	"LobbyHud",
	"PresenceClient",
	"HauntClient",
	"DetectorClient",
	"CameraReporter",
	"PanicEmote",
	"DebugOverlay",
	"ErrorPanel",
}

for _, name in ORDER do
	local module = Controllers:WaitForChild(name, 10)
	if module and module:IsA("ModuleScript") then
		local ok, err = pcall(function()
			(require(module) :: any).init()
		end)
		if not ok then
			Util.warn(("Controller '%s' FAILED to init: %s"):format(name, tostring(err)))
		end
	else
		Util.warn(("Controller '%s' missing"):format(name))
	end
end

Util.log(("client up — v%s (%s)"):format(Config.Version, Config.BuildStamp))
