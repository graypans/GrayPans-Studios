--!strict
-- Small shared helpers: logging with a consistent prefix, guarded calls, timeout WaitForChild (R4).

local Util = {}

local PREFIX = "[Porcelain]"

function Util.log(...: any)
	print(PREFIX, ...)
end

function Util.warn(...: any)
	warn(PREFIX, ...)
end

-- pcall wrapper that logs failures and never throws (R3).
function Util.safeCall<T...>(label: string, fn: (T...) -> (), ...: T...)
	local ok, err = pcall(fn, ...)
	if not ok then
		Util.warn(("safeCall '%s' failed: %s"):format(label, tostring(err)))
	end
	return ok
end

-- WaitForChild with a logged timeout instead of an infinite yield (R4).
function Util.waitForChild(parent: Instance, name: string, timeout: number?): Instance?
	local child = parent:WaitForChild(name, timeout or 10)
	if not child then
		Util.warn(("waitForChild timed out: %s.%s"):format(parent:GetFullName(), name))
	end
	return child
end

-- Shallow copy
function Util.copy<K, V>(t: { [K]: V }): { [K]: V }
	local out = {}
	for k, v in t do
		out[k] = v
	end
	return out
end

function Util.playerCount(players: { any }): number
	return #players
end

return Util
