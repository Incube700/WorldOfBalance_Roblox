-- HudWidgetFactory
--
-- Reusable, display-only HUD UI primitives (corner, stroke, panel, label, bar,
-- button). These were previously duplicated as local helpers inside the overlay
-- scripts (WOBBattleArenaOverlay, WOBDuelHudOverlay, ...). This module owns the
-- construction of Instances only.
--
-- Rules:
-- - It must NOT own gameplay decisions, attribute reads, remotes, or visibility
--   logic. Those stay in the presenter/overlay and in HudVisibilityRules.
-- - Defaults reproduce the exact values the BattleArena overlay used so callers
--   can migrate without any visual change. Callers may override any value.
--
-- API:
--   addCorner(parent, radius)                       -> UICorner
--   addStroke(parent, color, transparency, thickness) -> UIStroke
--   createPanel(options)                            -> Frame
--   createLabel(options)                            -> TextLabel
--   createBar(options)                              -> fill: Frame, back: Frame
--   styleButton(button, text)                       -> button (styles in place)
--   createButton(options)                           -> TextButton

local HudWidgetFactory = {}

local DEFAULT_PANEL_COLOR = Color3.fromRGB(13, 17, 23)
local DEFAULT_PANEL_TRANSPARENCY = 0.1
local DEFAULT_PANEL_CORNER = UDim.new(0, 8)
local DEFAULT_STROKE_COLOR = Color3.fromRGB(31, 41, 55)
local DEFAULT_STROKE_TRANSPARENCY = 0.25
local DEFAULT_STROKE_THICKNESS = 1

local DEFAULT_LABEL_COLOR = Color3.fromRGB(241, 255, 248)
local DEFAULT_LABEL_FONT = Enum.Font.GothamBold

local DEFAULT_BAR_BACK_COLOR = Color3.fromRGB(35, 42, 45)
local DEFAULT_BAR_CORNER = UDim.new(0, 4)

local DEFAULT_BUTTON_COLOR = Color3.fromRGB(250, 204, 21)
local DEFAULT_BUTTON_TEXT_COLOR = Color3.fromRGB(13, 17, 23)
local DEFAULT_BUTTON_STROKE_COLOR = Color3.fromRGB(249, 115, 22)
local DEFAULT_BUTTON_TEXT = "Return to Lobby"

-- Computes the ZIndex a child should receive: one above its parent when the
-- parent is a GuiObject, otherwise the supplied fallback. Mirrors the original
-- inline logic in the overlay scripts.
local function resolveChildZIndex(parent, fallbackZIndex)
	if typeof(parent) == "Instance" and parent:IsA("GuiObject") then
		return parent.ZIndex + 1
	end

	return fallbackZIndex or 1
end

function HudWidgetFactory.addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent

	return corner
end

function HudWidgetFactory.addStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent

	return stroke
end

-- options:
--   Name, Parent, Position, Size            (positioning)
--   ZIndex                                  (defaults 10)
--   BackgroundColor3, BackgroundTransparency
--   CornerRadius                            (UDim; nil disables corner)
--   StrokeColor, StrokeTransparency, StrokeThickness (nil StrokeColor disables stroke)
function HudWidgetFactory.createPanel(options)
	options = options or {}

	local panel = Instance.new("Frame")
	panel.Name = options.Name or "Panel"

	if options.Position ~= nil then
		panel.Position = options.Position
	end

	if options.Size ~= nil then
		panel.Size = options.Size
	end

	if options.AnchorPoint ~= nil then
		panel.AnchorPoint = options.AnchorPoint
	end

	panel.BackgroundColor3 = options.BackgroundColor3 or DEFAULT_PANEL_COLOR
	panel.BackgroundTransparency = options.BackgroundTransparency ~= nil
		and options.BackgroundTransparency
		or DEFAULT_PANEL_TRANSPARENCY
	panel.BorderSizePixel = 0
	panel.ZIndex = options.ZIndex or 10

	local cornerRadius = options.CornerRadius
	if cornerRadius == nil then
		cornerRadius = DEFAULT_PANEL_CORNER
	end
	if cornerRadius ~= false then
		HudWidgetFactory.addCorner(panel, cornerRadius)
	end

	local strokeColor = options.StrokeColor
	if strokeColor == nil then
		strokeColor = DEFAULT_STROKE_COLOR
	end
	if strokeColor ~= false then
		HudWidgetFactory.addStroke(
			panel,
			strokeColor,
			options.StrokeTransparency ~= nil and options.StrokeTransparency or DEFAULT_STROKE_TRANSPARENCY,
			options.StrokeThickness or DEFAULT_STROKE_THICKNESS
		)
	end

	if options.Parent ~= nil then
		panel.Parent = options.Parent
	end

	return panel
end

-- options:
--   Parent, Name, Position, Size, TextSize
--   Font                (defaults GothamBold)
--   TextColor3          (defaults 241,255,248)
--   Text                (defaults "")
--   TextWrapped         (defaults true)
--   TextTruncate        (defaults AtEnd)
--   TextXAlignment      (defaults Left)
--   TextYAlignment      (defaults Center)
--   FallbackZIndex      (used when Parent is not a GuiObject)
function HudWidgetFactory.createLabel(options)
	options = options or {}

	local label = Instance.new("TextLabel")
	label.Name = options.Name or "Label"

	if options.Position ~= nil then
		label.Position = options.Position
	end

	if options.Size ~= nil then
		label.Size = options.Size
	end

	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = options.Font or DEFAULT_LABEL_FONT
	label.Text = options.Text or ""
	label.TextColor3 = options.TextColor3 or DEFAULT_LABEL_COLOR
	label.TextSize = options.TextSize
	if options.TextWrapped ~= nil then
		label.TextWrapped = options.TextWrapped
	else
		label.TextWrapped = true
	end
	label.TextTruncate = options.TextTruncate or Enum.TextTruncate.AtEnd
	label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = options.TextYAlignment or Enum.TextYAlignment.Center
	label.ZIndex = resolveChildZIndex(options.Parent, options.FallbackZIndex or 11)

	if options.Parent ~= nil then
		label.Parent = options.Parent
	end

	return label
end

-- options:
--   Parent, Name, Position, Size, FillColor
--   BackColor           (defaults 35,42,45)
--   CornerRadius        (UDim; defaults UDim.new(0, 4))
--   FallbackZIndex      (used when Parent is not a GuiObject)
-- Returns: fill, back
function HudWidgetFactory.createBar(options)
	options = options or {}

	local name = options.Name or "Bar"
	local cornerRadius = options.CornerRadius
	if cornerRadius == nil then
		cornerRadius = DEFAULT_BAR_CORNER
	end

	local back = Instance.new("Frame")
	back.Name = name .. "Back"

	if options.Position ~= nil then
		back.Position = options.Position
	end

	if options.Size ~= nil then
		back.Size = options.Size
	end

	back.BackgroundColor3 = options.BackColor or DEFAULT_BAR_BACK_COLOR
	back.BorderSizePixel = 0
	back.ZIndex = resolveChildZIndex(options.Parent, options.FallbackZIndex or 11)

	if cornerRadius ~= false then
		HudWidgetFactory.addCorner(back, cornerRadius)
	end

	if options.Parent ~= nil then
		back.Parent = options.Parent
	end

	local fill = Instance.new("Frame")
	fill.Name = name .. "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = options.FillColor or DEFAULT_LABEL_COLOR
	fill.BorderSizePixel = 0
	fill.ZIndex = back.ZIndex + 1
	fill.Parent = back

	if cornerRadius ~= false then
		HudWidgetFactory.addCorner(fill, cornerRadius)
	end

	return fill, back
end

-- Styles an existing TextButton in place. Matches the original styleButton.
function HudWidgetFactory.styleButton(button, text)
	button.BackgroundColor3 = DEFAULT_BUTTON_COLOR
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text or DEFAULT_BUTTON_TEXT
	button.TextColor3 = DEFAULT_BUTTON_TEXT_COLOR
	button.TextSize = 16
	button.TextWrapped = true
	button.AutoButtonColor = true
	button.Active = true
	HudWidgetFactory.addCorner(button, UDim.new(0, 8))
	HudWidgetFactory.addStroke(button, DEFAULT_BUTTON_STROKE_COLOR, 0.3, 1)

	return button
end

-- options:
--   Parent, Name, Position, Size, AnchorPoint, ZIndex, Visible, Text
-- Creates a TextButton and applies the default button style.
function HudWidgetFactory.createButton(options)
	options = options or {}

	local button = Instance.new("TextButton")
	button.Name = options.Name or "Button"

	if options.AnchorPoint ~= nil then
		button.AnchorPoint = options.AnchorPoint
	end

	if options.Position ~= nil then
		button.Position = options.Position
	end

	if options.Size ~= nil then
		button.Size = options.Size
	end

	if options.ZIndex ~= nil then
		button.ZIndex = options.ZIndex
	end

	if options.Visible ~= nil then
		button.Visible = options.Visible
	end

	HudWidgetFactory.styleButton(button, options.Text)

	if options.Parent ~= nil then
		button.Parent = options.Parent
	end

	return button
end

return HudWidgetFactory
