--!strict
-- Server bootstrap: build world, wire services, start the machine.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Remotes = require(Shared:WaitForChild("Remotes")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any

Remotes.init()

local ServicesFolder = script:WaitForChild("Services")

local MapBuilder = require(ServicesFolder:WaitForChild("MapBuilder")) :: any
local DataService = require(ServicesFolder:WaitForChild("DataService")) :: any
local WatchService = require(ServicesFolder:WaitForChild("WatchService")) :: any
local DollService = require(ServicesFolder:WaitForChild("DollService")) :: any
local GlyphService = require(ServicesFolder:WaitForChild("GlyphService")) :: any
local TellService = require(ServicesFolder:WaitForChild("TellService")) :: any
local PresenceService = require(ServicesFolder:WaitForChild("PresenceService")) :: any
local HauntService = require(ServicesFolder:WaitForChild("HauntService")) :: any
local BanishService = require(ServicesFolder:WaitForChild("BanishService")) :: any
local ClassService = require(ServicesFolder:WaitForChild("ClassService")) :: any
local LobbyService = require(ServicesFolder:WaitForChild("LobbyService")) :: any
local ShiftManager = require(ServicesFolder:WaitForChild("ShiftManager")) :: any
local JoinSquareService = require(ServicesFolder:WaitForChild("JoinSquareService")) :: any
local QuestService = require(ServicesFolder:WaitForChild("QuestService")) :: any
local DebugService = require(ServicesFolder:WaitForChild("DebugService")) :: any

local manifest, failures = MapBuilder.build()

local ctx: any = {
	rng = Random.new(),
	manifest = manifest,
	services = {
		MapBuilder = MapBuilder,
		DataService = DataService,
		WatchService = WatchService,
		DollService = DollService,
		GlyphService = GlyphService,
		TellService = TellService,
		PresenceService = PresenceService,
		HauntService = HauntService,
		BanishService = BanishService,
		ClassService = ClassService,
		LobbyService = LobbyService,
		ShiftManager = ShiftManager,
		JoinSquareService = JoinSquareService,
		QuestService = QuestService,
		DebugService = DebugService,
	},
}

local initOrder = {
	"MapBuilder",
	"DataService",
	"WatchService",
	"DollService",
	"GlyphService",
	"TellService",
	"PresenceService",
	"HauntService",
	"BanishService",
	"ClassService", -- needs DataService + DollService already initialized (StartWithRibbon buff)
	"LobbyService",
	"ShiftManager",
	"JoinSquareService", -- additive; calls into ShiftManager.beginShiftFor only from event handlers
	"QuestService", -- needs ShiftManager.onShiftCleared + DollService.onRibbonTied already registerable
	"DebugService",
}

for _, name in initOrder do
	local ok, err = pcall(function()
		ctx.services[name].init(ctx)
	end)
	if not ok then
		Util.warn(("Service '%s' FAILED to init: %s"):format(name, tostring(err)))
	end
end

DollService.wireWorld(manifest)

if #failures > 0 then
	-- loud on-screen banner for the team (plan review: broken segments must be visible)
	task.delay(5, function()
		Remotes.get(Remotes.Names.Toast):FireAllClients(
			"MAP SEGMENTS FAILED: " .. table.concat(failures, ", ") .. " — screenshot this + Output window",
			30
		)
	end)
end

Util.log(("server up — v%s (%s), %d map failures"):format(Config.Version, Config.BuildStamp, #failures))
