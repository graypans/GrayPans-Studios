--!strict
-- Remote registry (R4): every remote name exists exactly once, here.
-- Server calls Remotes.init() once to create instances; both sides look up via Remotes.get().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Util = require(script.Parent.Util)

export type RemoteKind = "Event" | "Unreliable"

local DEFS: { [string]: RemoteKind } = {
	-- Server -> Client
	StateChanged = "Event", -- (stateName: string, payload: {}?)  payload includes objective text, shift number
	ShiftData = "Event", -- (shiftNumber: number, dolls: {DollInfo}) manifest at shift start
	DollUpdate = "Event", -- (dollId: string, update: {}) care progress / name changes
	GlyphFound = "Event", -- (glyphId: string, foundList: {string}, finderName: string)
	PresenceTier = "Event", -- (tier: number) 0..3
	HauntFired = "Event", -- (hauntId: string, params: {}?) client renders visuals
	BanishResult = "Event", -- (payload: {correct: boolean, dollName: string, spiritName: string?, strikes: number})
	Recap = "Event", -- (payload: recap card data)
	Toast = "Event", -- (message: string, seconds: number?)
	ReadyCountdown = "Event", -- (secondsLeft: number?) nil cancels
	MinigameStart = "Event", -- (dollId: string, stepId: string, seed: number) server granted the lock
	MinigameCancel = "Event", -- (dollId: string, stepId: string) lock expired / released
	BanishPrompt = "Event", -- (dollId: string, dollName: string) confirm UI open/close
	DebugInfo = "Event", -- (payload: {}) overlay feed, DebugMode only

	-- Client -> Server
	RequestMinigame = "Event", -- (dollId: string, stepId: string)
	MinigameDone = "Event", -- (dollId: string, stepId: string, success: boolean)
	ChooseName = "Event", -- (dollId: string, choiceIndex: number?, freeText: string?)
	PickupDoll = "Event", -- (dollId: string)
	DropDoll = "Event", -- ()
	DepositDoll = "Event", -- () at the banish box
	ConfirmBanish = "Event", -- (confirm: boolean)
	SlotGlyph = "Event", -- (slotIndex: number, glyphId: string?) shared ledger slotting
	CollectGlyph = "Event", -- (tokenId: string)
	TieRibbon = "Event", -- (dollId: string)
	Panic = "Event", -- ()
	ReadyPad = "Event", -- (standing: boolean) redundancy for pad touch detection
	CameraReport = "Unreliable", -- (cframe: CFrame) ~8 Hz watched-check stream
}

local FOLDER_NAME = "Remotes"

local Remotes = {}
Remotes.Names = {} :: { [string]: string }
for name in DEFS do
	Remotes.Names[name] = name
end

function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server-only")
	local folder: Instance
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
	for name, kind in DEFS do
		if not folder:FindFirstChild(name) then
			local remote: Instance
			if kind == "Unreliable" then
				remote = Instance.new("UnreliableRemoteEvent")
			else
				remote = Instance.new("RemoteEvent")
			end
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.get(name: string): RemoteEvent
	assert(DEFS[name] ~= nil, ("Unknown remote '%s' — add it to Remotes.luau"):format(tostring(name)))
	local folder = Util.waitForChild(ReplicatedStorage, FOLDER_NAME, 15)
	assert(folder, "Remotes folder missing")
	local remote = Util.waitForChild(folder, name, 15)
	assert(remote, ("Remote '%s' missing"):format(name))
	return remote :: RemoteEvent
end

return Remotes
