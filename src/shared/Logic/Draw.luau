--!strict
-- Pure logic: seeded weighted draws for tells/haunts (no `game` references — unit-tested).
-- Deterministic given a Random object, so schedules are reproducible in tests.

export type Weighted = { id: string, weight: number }

-- Structural rng type: satisfied by Roblox's Random and by test mocks (keeps this module CLI-testable)
export type RngLike = {
	NextNumber: (self: RngLike) -> number,
	NextInteger: (self: RngLike, min: number, max: number) -> number,
}

local Draw = {}

-- Weighted pick from candidates; returns nil for an empty/zero-weight pool.
function Draw.weighted(rng: RngLike, candidates: { Weighted }): string?
	local total = 0
	for _, c in candidates do
		if c.weight > 0 then
			total += c.weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = rng:NextNumber() * total
	local acc = 0
	for _, c in candidates do
		if c.weight > 0 then
			acc += c.weight
			if roll <= acc then
				return c.id
			end
		end
	end
	return candidates[#candidates].id
end

-- Pick n distinct entries from list (uniform, seeded). Returns fewer if list is short.
function Draw.sample<T>(rng: RngLike, list: { T }, n: number): { T }
	local pool = table.clone(list)
	local out: { T } = {}
	for _ = 1, math.min(n, #pool) do
		local i = rng:NextInteger(1, #pool)
		table.insert(out, pool[i])
		table.remove(pool, i)
	end
	return out
end

-- Uniform pick
function Draw.one<T>(rng: RngLike, list: { T }): T?
	if #list == 0 then
		return nil
	end
	return list[rng:NextInteger(1, #list)]
end

return Draw
