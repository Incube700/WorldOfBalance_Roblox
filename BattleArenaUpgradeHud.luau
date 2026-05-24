local BattleArenaUpgradeHud = {}
BattleArenaUpgradeHud.__index = BattleArenaUpgradeHud

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedConfigs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local UpgradeIconConfig = require(sharedConfigs:WaitForChild("UpgradeIconConfig"))

local UPGRADE_ICON_SLOT_COUNT = 5

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = parent

	return corner
end

local function addStroke(parent, color, transparency, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = thickness
	stroke.Parent = parent

	return stroke
end

local function makeLabel(parent, name, textSize, font, zIndex)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font or Enum.Font.GothamBold
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(241, 255, 248)
	label.TextSize = textSize
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = zIndex
	label.Parent = parent

	return label
end

local function splitUpgradeIds(upgradeIds)
	local ids = {}

	if typeof(upgradeIds) ~= "string" or upgradeIds == "" then
		return ids
	end

	for id in string.gmatch(upgradeIds, "[^,]+") do
		local trimmed = string.gsub(id, "^%s*(.-)%s*$", "%1")

		if trimmed ~= "" then
			table.insert(ids, trimmed)
		end
	end

	return ids
end

local function getUpgradeIconConfig(upgradeId)
	if typeof(upgradeId) ~= "string" then
		return nil
	end

	local icons = UpgradeIconConfig.Icons

	if typeof(icons) ~= "table" then
		return nil
	end

	return icons[upgradeId]
end

local function getUpgradeIconImage(upgradeId)
	local iconConfig = getUpgradeIconConfig(upgradeId)
	local image = iconConfig ~= nil and iconConfig.Image or nil

	if typeof(image) == "string" and image ~= "" then
		return image
	end

	return nil
end

local function getUpgradeIconFallbackText(upgradeId)
	local iconConfig = getUpgradeIconConfig(upgradeId)
	local fallbackText = iconConfig ~= nil and iconConfig.FallbackText or nil

	if typeof(fallbackText) == "string" and fallbackText ~= "" then
		return fallbackText
	end

	fallbackText = UpgradeIconConfig.FallbackText

	if typeof(fallbackText) == "string" and fallbackText ~= "" then
		return fallbackText
	end

	return "★"
end

local function getShortUpgradeTitle(choice)
	local title = tostring(choice.Title or choice.Id or "UPG")
	title = string.upper(title)

	local replacements = {
		["FIRE RATE"] = "RELOAD",
		["FIRERATE"] = "RELOAD",
		["DAMAGE UP"] = "DAMAGE",
		["PROJECTILE DAMAGE"] = "DAMAGE",
		["RICOCHET"] = "BOUNCE",
		["REPAIR"] = "REPAIR",
		["ARMOR"] = "ARMOR",
		["SPEED"] = "SPEED",
		["TURBO"] = "TURBO",
	}

	for pattern, replacement in pairs(replacements) do
		if string.find(title, pattern) then
			return replacement
		end
	end

	if #title > 8 then
		return string.sub(title, 1, 8)
	end

	return title
end

local function getDescription(choice)
	local description = tostring(choice.Description or "")

	if description == "" then
		return tostring(choice.Id or "Run upgrade")
	end

	return description
end

local function isTextGui(instance)
	return instance ~= nil and (instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox"))
end

local function isImageGui(instance)
	return instance ~= nil and instance:IsA("ImageLabel")
end

local function getIconImageName(iconGui)
	if iconGui ~= nil and iconGui.Name == "Icon" then
		return "IconImage"
	end

	return tostring(iconGui ~= nil and iconGui.Name or "Icon") .. "IconImage"
end

local function findIconImage(iconGui)
	if iconGui == nil or not iconGui:IsA("GuiObject") then
		return nil
	end

	if isImageGui(iconGui) then
		return iconGui
	end

	local parent = iconGui.Parent

	if parent == nil then
		return nil
	end

	local image = parent:FindFirstChild(getIconImageName(iconGui))

	if image ~= nil and not image:IsA("ImageLabel") then
		image:Destroy()
		image = nil
	end

	return image
end

local function syncIconImageLayout(image, sourceGui)
	if image == nil or sourceGui == nil then
		return
	end

	image.AnchorPoint = sourceGui.AnchorPoint
	image.Position = sourceGui.Position
	image.Size = sourceGui.Size
	image.Rotation = sourceGui.Rotation
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Active = false
	image.Selectable = false
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = sourceGui.ZIndex + 1
end

local function getOrCreateIconImage(iconGui)
	if iconGui == nil or not iconGui:IsA("GuiObject") then
		return nil
	end

	if isImageGui(iconGui) then
		iconGui.BackgroundTransparency = 1
		iconGui.BorderSizePixel = 0
		iconGui.Active = false
		iconGui.Selectable = false
		iconGui.ScaleType = Enum.ScaleType.Fit
		return iconGui
	end

	local parent = iconGui.Parent

	if parent == nil then
		return nil
	end

	local imageName = getIconImageName(iconGui)
	local image = parent:FindFirstChild(imageName)

	if image ~= nil and not image:IsA("ImageLabel") then
		image:Destroy()
		image = nil
	end

	local nestedImage = iconGui:FindFirstChild("IconImage")

	if image == nil and nestedImage ~= nil and nestedImage:IsA("ImageLabel") then
		image = nestedImage
		image.Name = imageName
		image.Parent = parent
	elseif nestedImage ~= nil and nestedImage:IsA("ImageLabel") and nestedImage ~= image then
		nestedImage.Visible = false
	end

	if image == nil then
		image = Instance.new("ImageLabel")
		image.Name = imageName
		image.Parent = parent
	end

	syncIconImageLayout(image, iconGui)

	return image
end

local function applyUpgradeIcon(iconGui, upgradeId)
	if iconGui == nil then
		return
	end

	local imageId = getUpgradeIconImage(upgradeId)
	local fallbackText = getUpgradeIconFallbackText(upgradeId)
	local image = getOrCreateIconImage(iconGui)

	if image ~= nil then
		image.Image = imageId or ""
		image.Visible = imageId ~= nil
	end

	if isTextGui(iconGui) then
		iconGui.Text = imageId ~= nil and "" or fallbackText
		iconGui.Visible = imageId == nil
	elseif isImageGui(iconGui) then
		iconGui.Image = imageId or ""
		iconGui.Visible = imageId ~= nil
	end
end

local function clearUpgradeIcon(iconGui)
	if iconGui == nil then
		return
	end

	if isTextGui(iconGui) then
		iconGui.Text = ""
	end

	local image = findIconImage(iconGui)

	if image ~= nil and image:IsA("ImageLabel") then
		image.Image = ""
		image.Visible = false
	end

	local nestedImage = iconGui:IsA("GuiObject") and iconGui:FindFirstChild("IconImage") or nil

	if nestedImage ~= nil and nestedImage:IsA("ImageLabel") and nestedImage ~= image then
		nestedImage.Image = ""
		nestedImage.Visible = false
	end

	if isImageGui(iconGui) then
		iconGui.Image = ""
		iconGui.Visible = false
	end
end

function BattleArenaUpgradeHud.new(params)
	assert(typeof(params) == "table", "BattleArenaUpgradeHud.new requires params")
	assert(params.Parent ~= nil, "BattleArenaUpgradeHud.new requires params.Parent")

	local self = setmetatable({}, BattleArenaUpgradeHud)

	self._parent = params.Parent
	self._zIndex = tonumber(params.ZIndex) or 30
	self._onChoiceSelected = params.OnChoiceSelected
	self._visible = true
	self._isMobile = false
	self._viewportSize = Vector2.new(1024, 768)
	self._offer = nil
	self._activeUpgradeIds = ""

	self:_createRoot()
	self:_createOfferPanel()
	self:_createIconStrip()
	self:SetLayout({
		IsMobile = false,
		ViewportSize = self._viewportSize,
	})
	self:_render()

	return self
end

function BattleArenaUpgradeHud:_createRoot()
	local root = Instance.new("Frame")
	root.Name = "BattleArenaUpgradeHud"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Position = UDim2.fromScale(0, 0)
	root.Size = UDim2.fromScale(1, 1)
	root.Active = false
	root.ZIndex = self._zIndex
	root.Parent = self._parent

	self._root = root
end

function BattleArenaUpgradeHud:_createOfferPanel()
	local panel = Instance.new("Frame")
	panel.Name = "UpgradeChoiceBelt"
	panel.BackgroundColor3 = Color3.fromRGB(13, 17, 23)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Active = false
	panel.ZIndex = self._zIndex
	panel.Parent = self._root
	addCorner(panel, UDim.new(0, 8))
	addStroke(panel, Color3.fromRGB(250, 204, 21), 0.3, 1)

	local title = makeLabel(panel, "Title", 14, Enum.Font.GothamBlack, self._zIndex + 1)
	title.Text = "LEVEL UP"
	title.TextColor3 = Color3.fromRGB(250, 204, 21)

	local subtitle = makeLabel(panel, "Subtitle", 11, Enum.Font.GothamMedium, self._zIndex + 1)
	subtitle.Text = ""
	subtitle.TextColor3 = Color3.fromRGB(178, 238, 205)

	self._offerPanel = panel
	self._title = title
	self._subtitle = subtitle
	self._choiceCards = {}

	for index = 1, 3 do
		local card = Instance.new("Frame")
		card.Name = "Choice" .. tostring(index)
		card.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
		card.BackgroundTransparency = 0.06
		card.BorderSizePixel = 0
		card.Visible = false
		card.ZIndex = self._zIndex + 1
		card.Parent = panel
		addCorner(card, UDim.new(0, 7))
		addStroke(card, Color3.fromRGB(249, 115, 22), 0.42, 1)

		local icon = makeLabel(card, "Icon", 24, Enum.Font.GothamBold, self._zIndex + 2)
		icon.Text = "★"

		local name = makeLabel(card, "Name", 10, Enum.Font.GothamBold, self._zIndex + 2)
		name.Text = "UPG"
		name.TextColor3 = Color3.fromRGB(241, 255, 248)

		local effect = makeLabel(card, "Effect", 11, Enum.Font.GothamMedium, self._zIndex + 2)
		effect.Text = ""
		effect.TextColor3 = Color3.fromRGB(178, 238, 205)
		effect.TextXAlignment = Enum.TextXAlignment.Left

		local button = Instance.new("TextButton")
		button.Name = "Button"
		button.BackgroundTransparency = 1
		button.BorderSizePixel = 0
		button.Text = ""
		button.AutoButtonColor = false
		button.Active = true
		button.ZIndex = self._zIndex + 3
		button.Parent = card

		local entry = {
			Card = card,
			Icon = icon,
			Name = name,
			Effect = effect,
			Button = button,
			UpgradeId = nil,
		}

		button.Activated:Connect(function()
			if typeof(entry.UpgradeId) ~= "string" or entry.UpgradeId == "" then
				return
			end

			if self._onChoiceSelected ~= nil then
				self._onChoiceSelected(entry.UpgradeId)
			end
		end)

		table.insert(self._choiceCards, entry)
	end
end

function BattleArenaUpgradeHud:_createIconStrip()
	local strip = Instance.new("Frame")
	strip.Name = "ActiveUpgradeIconStrip"
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.Visible = false
	strip.ZIndex = self._zIndex - 1
	strip.Parent = self._root

	self._iconStrip = strip
	self._iconSlots = {}

	for index = 1, UPGRADE_ICON_SLOT_COUNT do
		local slot = makeLabel(strip, "Slot" .. tostring(index), 16, Enum.Font.GothamBold, self._zIndex)
		slot.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
		slot.BackgroundTransparency = 0.22
		slot.Visible = false
		addCorner(slot, UDim.new(0, 6))
		addStroke(slot, Color3.fromRGB(250, 204, 21), 0.58, 1)
		table.insert(self._iconSlots, slot)
	end

	local overflow = makeLabel(strip, "Overflow", 12, Enum.Font.GothamBold, self._zIndex)
	overflow.BackgroundColor3 = Color3.fromRGB(20, 28, 38)
	overflow.BackgroundTransparency = 0.22
	overflow.TextColor3 = Color3.fromRGB(178, 238, 205)
	overflow.Visible = false
	addCorner(overflow, UDim.new(0, 6))

	self._overflow = overflow
end

function BattleArenaUpgradeHud:SetVisible(isVisible)
	self._visible = isVisible == true
	self:_render()
end

function BattleArenaUpgradeHud:SetLayout(layout)
	layout = layout or {}
	self._isMobile = layout.IsMobile == true
	self._viewportSize = layout.ViewportSize or self._viewportSize

	self:_applyLayout()
	self:_render()
end

function BattleArenaUpgradeHud:SetOffer(offer)
	self._offer = offer
	self:_render()
end

function BattleArenaUpgradeHud:SetActiveUpgradeIds(upgradeIds)
	self._activeUpgradeIds = typeof(upgradeIds) == "string" and upgradeIds or ""
	self:_render()
end

function BattleArenaUpgradeHud:Destroy()
	if self._root ~= nil then
		self._root:Destroy()
		self._root = nil
	end
end

function BattleArenaUpgradeHud:_applyLayout()
	if self._isMobile then
		self:_applyMobileLayout()
	else
		self:_applyDesktopLayout()
	end
end

function BattleArenaUpgradeHud:_applyMobileLayout()
	local viewportSize = self._viewportSize
	local panelWidth = math.clamp(math.floor(viewportSize.X * 0.56), 196, 248)
	local panelHeight = 90
	local buttonGap = 6
	local buttonSize = math.floor((panelWidth - 24 - buttonGap * 2) / 3)
	buttonSize = math.clamp(buttonSize, 50, 66)
	local rowWidth = buttonSize * 3 + buttonGap * 2
	local rowX = math.floor((panelWidth - rowWidth) * 0.5)

	self._offerPanel.AnchorPoint = Vector2.new(0.5, 1)
	self._offerPanel.Position = UDim2.new(0.5, 0, 1, -96)
	self._offerPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)

	self._title.Position = UDim2.fromOffset(8, 4)
	self._title.Size = UDim2.new(1, -16, 0, 18)
	self._title.TextSize = 13

	self._subtitle.Visible = false

	for index, entry in ipairs(self._choiceCards) do
		local x = rowX + (index - 1) * (buttonSize + buttonGap)
		entry.Card.Position = UDim2.fromOffset(x, 24)
		entry.Card.Size = UDim2.fromOffset(buttonSize, buttonSize)
		entry.Icon.Position = UDim2.fromOffset(0, 4)
		entry.Icon.Size = UDim2.new(1, 0, 0, math.floor(buttonSize * 0.56))
		entry.Icon.TextSize = math.floor(buttonSize * 0.42)

		entry.Name.Position = UDim2.new(0, 3, 1, -20)
		entry.Name.Size = UDim2.new(1, -6, 0, 17)
		entry.Name.TextSize = math.max(8, math.floor(buttonSize * 0.16))
		entry.Name.TextXAlignment = Enum.TextXAlignment.Center

		entry.Effect.Visible = false
		entry.Button.Position = UDim2.fromScale(0, 0)
		entry.Button.Size = UDim2.fromScale(1, 1)
	end

	self:_layoutIconStrip({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -88),
		SlotSize = 32,
		Gap = 4,
	})
end

function BattleArenaUpgradeHud:_applyDesktopLayout()
	local panelWidth = 428
	local panelHeight = 140
	local cardHeight = 72
	local cardGap = 6
	local cardWidth = math.floor((panelWidth - 28 - cardGap * 2) / 3)

	self._offerPanel.AnchorPoint = Vector2.new(0.5, 0)
	self._offerPanel.Position = UDim2.new(0.5, 0, 0, 106)
	self._offerPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)

	self._title.Position = UDim2.fromOffset(14, 8)
	self._title.Size = UDim2.new(1, -28, 0, 22)
	self._title.TextSize = 15

	self._subtitle.Visible = true
	self._subtitle.Position = UDim2.fromOffset(14, 30)
	self._subtitle.Size = UDim2.new(1, -28, 0, 18)
	self._subtitle.TextSize = 11

	for index, entry in ipairs(self._choiceCards) do
		local x = 14 + (index - 1) * (cardWidth + cardGap)
		entry.Card.Position = UDim2.fromOffset(x, 54)
		entry.Card.Size = UDim2.fromOffset(cardWidth, cardHeight)

		entry.Icon.Position = UDim2.fromOffset(0, 4)
		entry.Icon.Size = UDim2.new(1, 0, 0, 34)
		entry.Icon.TextSize = 24

		entry.Name.Position = UDim2.fromOffset(5, 40)
		entry.Name.Size = UDim2.new(1, -10, 0, 17)
		entry.Name.TextSize = 11
		entry.Name.TextXAlignment = Enum.TextXAlignment.Center

		entry.Effect.Visible = true
		entry.Effect.Position = UDim2.fromOffset(5, 56)
		entry.Effect.Size = UDim2.new(1, -10, 0, 13)
		entry.Effect.TextSize = 8
		entry.Effect.TextXAlignment = Enum.TextXAlignment.Center

		entry.Button.Position = UDim2.fromScale(0, 0)
		entry.Button.Size = UDim2.fromScale(1, 1)
	end

	self:_layoutIconStrip({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 182),
		SlotSize = 30,
		Gap = 4,
	})
end

function BattleArenaUpgradeHud:_layoutIconStrip(config)
	local slotSize = config.SlotSize
	local gap = config.Gap
	local stripWidth = UPGRADE_ICON_SLOT_COUNT * slotSize + (UPGRADE_ICON_SLOT_COUNT - 1) * gap
	local overflowWidth = math.floor(slotSize * 1.25)

	self._iconStrip.AnchorPoint = config.AnchorPoint
	self._iconStrip.Position = config.Position
	self._iconStrip.Size = UDim2.fromOffset(stripWidth + gap + overflowWidth, slotSize)

	for index, slot in ipairs(self._iconSlots) do
		slot.Position = UDim2.fromOffset((index - 1) * (slotSize + gap), 0)
		slot.Size = UDim2.fromOffset(slotSize, slotSize)
		slot.TextSize = math.max(12, math.floor(slotSize * 0.52))
	end

	self._overflow.Position = UDim2.fromOffset(UPGRADE_ICON_SLOT_COUNT * (slotSize + gap), 0)
	self._overflow.Size = UDim2.fromOffset(overflowWidth, slotSize)
	self._overflow.TextSize = math.max(10, math.floor(slotSize * 0.38))
end

function BattleArenaUpgradeHud:_hasOffer()
	local offer = self._offer
	local choices = offer ~= nil and offer.Choices or {}

	return offer ~= nil and #choices > 0
end

function BattleArenaUpgradeHud:_render()
	if self._root == nil then
		return
	end

	local hasOffer = self._visible and self:_hasOffer()

	self._root.Visible = self._visible
	self._offerPanel.Visible = hasOffer
	self._offerPanel.Active = hasOffer

	if hasOffer then
		self:_renderOffer()
		self._iconStrip.Visible = false
	else
		self:_renderIconStrip()
	end
end

function BattleArenaUpgradeHud:_renderOffer()
	local offer = self._offer
	local choices = offer.Choices or {}
	local source = tostring(offer.Source or "LevelUp")
	local arenaLevel = tonumber(offer.ArenaLevel) or 1

	self._title.Text = source == "SupplyCrate" and "SUPPLY" or "LEVEL UP"
	self._subtitle.Text = "Arena Level " .. tostring(math.floor(arenaLevel)) .. " upgrade"

	for index, entry in ipairs(self._choiceCards) do
		local choice = choices[index]

		if choice ~= nil then
			local choiceId = tostring(choice.Id or "")
			entry.UpgradeId = choiceId
			entry.Card.Visible = true
			applyUpgradeIcon(entry.Icon, choiceId)
			entry.Name.Text = self._isMobile and getShortUpgradeTitle(choice) or tostring(choice.Title or choice.Id or "Upgrade")
			entry.Effect.Text = getDescription(choice)
		else
			entry.UpgradeId = nil
			entry.Card.Visible = false
			clearUpgradeIcon(entry.Icon)
			entry.Name.Text = ""
			entry.Effect.Text = ""
		end
	end
end

function BattleArenaUpgradeHud:_renderIconStrip()
	local ids = splitUpgradeIds(self._activeUpgradeIds)
	local visible = self._visible and #ids > 0

	self._iconStrip.Visible = visible

	if not visible then
		return
	end

	local displayCount = math.min(#ids, UPGRADE_ICON_SLOT_COUNT)
	local overflow = #ids - displayCount

	for index, slot in ipairs(self._iconSlots) do
		if index <= displayCount then
			applyUpgradeIcon(slot, ids[index])
			slot.Visible = true
		else
			clearUpgradeIcon(slot)
			slot.Visible = false
		end
	end

	if overflow > 0 then
		self._overflow.Text = "+" .. tostring(overflow)
		self._overflow.Visible = true
	else
		self._overflow.Visible = false
	end
end

return BattleArenaUpgradeHud
