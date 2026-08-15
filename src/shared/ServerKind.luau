--!strict
-- ServerKind: single source of truth for "what kind of server is this," now that a shift can run
-- either in-place (Studio, or the Config.Features.PrivateShiftServers kill switch) or in a
-- dedicated live reserved private server (TeleportService:TeleportAsync + ShouldReserveServer).
-- MapBuilder and JoinSquareService both read this so their branches can never disagree.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config")) :: any

local ServerKind = {}

-- True when this server should run the CURRENT single-server flow: MapBuilder builds both Lobby
-- and Workshop, and join squares resolve via ShiftManager.beginShiftFor instead of a real
-- cross-server teleport. True in Studio (TeleportService never functions there) OR when the team
-- has thrown Config.Features.PrivateShiftServers off (R3 escape hatch if live teleporting misbehaves).
function ServerKind.isSameServerMode(): boolean
	return RunService:IsStudio() or not Config.Features.PrivateShiftServers
end

-- True only for a live, published server that booted as a TeleportAsync-reserved instance.
function ServerKind.isReservedShiftServer(): boolean
	return (not ServerKind.isSameServerMode()) and game.PrivateServerId ~= ""
end

-- True for a live public server that is NOT a reserved shift instance -- i.e. the lobby.
function ServerKind.isPublicLobbyServer(): boolean
	return (not ServerKind.isSameServerMode()) and game.PrivateServerId == ""
end

return ServerKind
