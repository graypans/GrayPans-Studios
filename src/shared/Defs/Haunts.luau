--!strict
-- Haunt event pool. tier = minimum Presence tier (1..3) before the event can draw.
-- weight = relative draw chance. cooldown = seconds before the same event may repeat.
-- Every event has BOTH a sound slot and a visual so the beta reads fully muted (audio ships ID=0).
-- Implementations live server-side (world changes) + client-side (camera/screen effects), keyed by id.

export type HauntDef = {
	id: string,
	tier: number,
	weight: number,
	cooldown: number,
	scope: "world" | "client", -- world = server manipulates instances; client = per-client screen/camera effect
}

local Haunts: { HauntDef } = {
	{ id = "BenchRattle", tier = 1, weight = 10, cooldown = 40, scope = "world" },
	{ id = "DoorCreakSlam", tier = 1, weight = 8, cooldown = 50, scope = "world" },
	{ id = "MusicBoxSwell", tier = 1, weight = 8, cooldown = 60, scope = "world" },
	{ id = "WhisperPass", tier = 2, weight = 8, cooldown = 45, scope = "client" },
	{ id = "SilhouetteDoorway", tier = 2, weight = 7, cooldown = 70, scope = "world" },
	{ id = "WindowFigure", tier = 2, weight = 6, cooldown = 80, scope = "world" },
	{ id = "DollHeadSnap", tier = 2, weight = 9, cooldown = 45, scope = "world" },
	{ id = "LightsOutBeat", tier = 3, weight = 7, cooldown = 90, scope = "world" },
	{ id = "Taken", tier = 3, weight = 4, cooldown = 180, scope = "client" }, -- stub; off by default (Config)
}

local byId: { [string]: HauntDef } = {}
for _, h in Haunts do
	byId[h.id] = h
end

return {
	list = Haunts,
	byId = byId,
}
