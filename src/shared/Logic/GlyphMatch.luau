--!strict
-- Pure logic: ordered glyph-code matching (no `game` references — unit-tested via Luau CLI).

local GlyphMatch = {}

-- Returns true only when slots exactly equal the spirit code, in order.
function GlyphMatch.matches(code: { string }, slots: { string? }): boolean
	if #code == 0 then
		return false
	end
	for i, glyphId in code do
		if slots[i] ~= glyphId then
			return false
		end
	end
	-- reject extra slotted glyphs beyond the code length
	for i in slots do
		if i > #code and slots[i] ~= nil then
			return false
		end
	end
	return true
end

-- Given every spirit and the current slots, return the single spirit id that matches, or nil.
function GlyphMatch.identify(spirits: { { id: string, code: { string } } }, slots: { string? }): string?
	for _, spirit in spirits do
		if GlyphMatch.matches(spirit.code, slots) then
			return spirit.id
		end
	end
	return nil
end

-- Validation used by tests: every spirit code must reference only defined glyph ids and be unique.
function GlyphMatch.validateDefs(
	spirits: { { id: string, code: { string } } },
	glyphIds: { [string]: any }
): (boolean, string?)
	local seen: { [string]: string } = {}
	for _, spirit in spirits do
		if #spirit.code ~= 3 then
			return false, ("spirit %s code length %d ~= 3"):format(spirit.id, #spirit.code)
		end
		for _, glyphId in spirit.code do
			if glyphIds[glyphId] == nil then
				return false, ("spirit %s references unknown glyph %s"):format(spirit.id, glyphId)
			end
		end
		local key = table.concat(spirit.code, "|")
		if seen[key] then
			return false, ("spirits %s and %s share code %s"):format(seen[key], spirit.id, key)
		end
		seen[key] = spirit.id
	end
	return true, nil
end

return GlyphMatch
