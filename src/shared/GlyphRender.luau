--!strict
-- Draws a glyph (Defs/Glyphs stroke data) as Frames inside any GuiObject. Zero image assets.

local Glyphs = require(script.Parent.Defs.Glyphs)

local GlyphRender = {}

function GlyphRender.render(glyphId: string, parent: GuiObject, color: Color3?)
	local glyph = (Glyphs :: any).byId[glyphId]
	if not glyph then
		return
	end
	local tint = color or Color3.fromRGB(200, 180, 230)
	for _, stroke in glyph.strokes do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = UDim2.fromScale(stroke.x, stroke.y)
		frame.Size = UDim2.fromScale(stroke.w, stroke.h)
		frame.Rotation = stroke.rot or 0
		frame.BackgroundColor3 = tint
		frame.BorderSizePixel = 0
		if stroke.round then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = frame
		end
		frame.Parent = parent
	end
end

function GlyphRender.clear(parent: GuiObject)
	for _, child in parent:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

return GlyphRender
