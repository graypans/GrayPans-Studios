--!strict
-- Tells: real tells on the marked doll, fake tells framing innocents. Generation-countered loops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any
local Util = require(Shared:WaitForChild("Util")) :: any
local Tells = require(Shared:WaitForChild("Defs"):WaitForChild("Tells")) :: any
local Draw = require(Shared:WaitForChild("Logic"):WaitForChild("Draw")) :: any

local TellService = {}

local ctx: any
local generation = 0
local stitchDoneThisShift = false

function TellService.init(context: any)
	ctx = context
end

local function pickTell(rng: any, forMarked: boolean, dollModel: Model?): string?
	local candidates = {}
	local WatchService = ctx.services.WatchService
	local watched = dollModel ~= nil and WatchService.isWatched(dollModel)
	for _, def in Tells.list do
		local ok = true
		if def.unwatchedOnly and watched then
			ok = false
		end
		if not forMarked and not def.fakeable then
			ok = false
		end
		if def.id == "StitchMark" then
			if not forMarked or stitchDoneThisShift or ctx.services.PresenceService.getTier() < 2 then
				ok = false
			end
		end
		if ok then
			table.insert(candidates, { id = def.id, weight = def.weight })
		end
	end
	return Draw.weighted(rng, candidates)
end

function TellService.startShift(shiftParams: any, rng: any)
	generation += 1
	stitchDoneThisShift = false
	local myGen = generation
	task.spawn(function()
		while generation == myGen do
			local interval = shiftParams.tellIntervalMin + rng:NextNumber() * (shiftParams.tellIntervalMax - shiftParams.tellIntervalMin)
			task.wait(interval)
			if generation ~= myGen then
				break
			end
			local DollService = ctx.services.DollService
			-- REAL tell on the marked doll
			local markedId = DollService.getMarkedId()
			if markedId then
				local model = DollService.getModel(markedId)
				local tellId = pickTell(rng, true, model)
				if tellId then
					if tellId == "StitchMark" then
						stitchDoneThisShift = true
					end
					Util.safeCall("realTell", function()
						DollService.performTell(markedId, tellId)
					end)
				end
			end
			-- FAKE tell on an innocent (framing)
			if Config.Features.FakeTells and rng:NextNumber() < shiftParams.fakeTellChance then
				local innocents = {}
				for _, id in DollService.getDollIds() do
					if not DollService.isMarked(id) then
						table.insert(innocents, id)
					end
				end
				local victim = Draw.one(rng, innocents)
				if victim then
					-- slight delay so fake and real tells don't visibly pair up
					task.delay(2 + rng:NextNumber() * 6, function()
						if generation ~= myGen then
							return
						end
						local model = ctx.services.DollService.getModel(victim)
						local tellId = pickTell(rng, false, model)
						if tellId then
							Util.safeCall("fakeTell", function()
								ctx.services.DollService.performTell(victim, tellId)
							end)
						end
					end)
				end
			end
		end
	end)
end

function TellService.stopShift()
	generation += 1
end

return TellService
