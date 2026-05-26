local BattleArenaUpgradeHud = {}
BattleArenaUpgradeHud.__index = BattleArenaUpgradeHud
BattleArenaUpgradeHud._warnedMissingTemplate = false
BattleArenaUpgradeHud._warnedInvalidTemplate = false
BattleArenaUpgradeHud._warnedTemplateVisualChildren = false

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local sharedConfigs = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local UpgradeIconConfig = require(sharedConfigs:WaitForChild("UpgradeIconConfig"))

local UPGRADE_ICON_SLOT_COUNT = 5
local MOBILE_SAFE_UPGRADE_TOP_Y_MIN = 136
local MOBILE_SAFE_UPGRADE_TOP_Y_MAX = 158

local function getMobileSafeUpgradeTopY(viewportSize)
	local viewportHeight = viewportSize ~= nil and viewportSize.Y or 768

	return math.clamp(
		math.floor(viewportHeight * 0.18),
		MOBILE_SAFE_UPGRADE_TOP_Y_MIN,
		MOBILE_SAFE_UPGRADE_TOP_Y_MAX
	)
end

local function warnTemplateIssueOnce(flagName, message)
	if BattleArenaUpgradeHud[flagName] then
		return
	end

	BattleArenaUpgradeHud[flagName] = true
	warn(message)
end

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

local function isIconGui(instance)
	return isTextGui(instance) or isImageGui(instance)
end

local function isChoiceRoot(instance)
	return instance ~= nil and (instance:IsA("Frame") or instance:IsA("TextButton"))
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

	local imageName = getIconImageName(iconGui)
	local image = parent:FindFirstChild(imageName)

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
	self._shieldState = {
		Active = false,
		Charges = 0,
		SpawnShieldUntil = 0,
	}
	self._usesTemplate = false
	self._templateLayoutOwned = false
	self._templateLayouts = nil
	self._activeTemplateLayout = nil
	self._paidReflectSlot = nil

	local templateClone = self:_tryLoadTemplate()
	if templateClone ~= nil and self:_bindTemplate(templateClone) then
		self._usesTemplate = true
		self._templateLayoutOwned = true
	else
		self._usesTemplate = false
		self._templateLayoutOwned = false

		if templateClone == nil then
			warnTemplateIssueOnce(
				"_warnedMissingTemplate",
				"[WOB] BattleArenaUpgradeBeltTemplate not found in ReplicatedStorage — using scripted fallback"
			)
		end
		self:_createRoot()
		self:_createOfferPanel()
		self:_createIconStrip()
	end
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

function BattleArenaUpgradeHud:_tryLoadTemplate()
	local ok, clone = pcall(function()
		local rs = game:GetService("ReplicatedStorage")
		local node = rs:FindFirstChild("Shared")
		if not node then return nil end
		node = node:FindFirstChild("Assets")
		if not node then return nil end
		node = node:FindFirstChild("UI")
		if not node then return nil end
		node = node:FindFirstChild("BattleArena")
		if not node then return nil end
		local template = node:FindFirstChild("BattleArenaUpgradeBeltTemplate")
		if not template then return nil end
		return template:Clone()
	end)
	if not ok then return nil end
	return clone
end

function BattleArenaUpgradeHud:_bindTemplate(clone)
	local visualWarnings = {}

	if clone == nil or not clone:IsA("Frame") then
		warnTemplateIssueOnce(
			"_warnedInvalidTemplate",
			"[WOB] BattleArenaUpgradeBeltTemplate is invalid (BattleArenaUpgradeBeltTemplate must be a Frame) — using scripted fallback"
		)
		return false
	end

	local function bindPaidReflectSlot(choices, layoutName)
		local card = choices:FindFirstChild("PaidReflectChoice") or choices:FindFirstChild("Choice4")

		if card == nil then
			return nil
		end

		if not isChoiceRoot(card) then
			table.insert(visualWarnings, layoutName .. ".PaidReflectChoice is not a Frame or TextButton")
			return nil
		end

		local button = card:FindFirstChild("Button")

		if button ~= nil and not button:IsA("TextButton") then
			table.insert(visualWarnings, layoutName .. ".PaidReflectChoice.Button is not a TextButton")
			button = nil
		elseif button == nil and card:IsA("TextButton") then
			button = card
		end

		local icon = card:FindFirstChild("Icon")
		local iconImage = card:FindFirstChild("IconImage")
		local title = card:FindFirstChild("Title")
		local costLabel = card:FindFirstChild("CostLabel")

		if icon ~= nil and not isIconGui(icon) then
			table.insert(visualWarnings, layoutName .. ".PaidReflectChoice.Icon is not a supported icon gui")
			icon = nil
		end

		if icon == nil and isImageGui(iconImage) then
			icon = iconImage
		elseif icon ~= nil then
			getOrCreateIconImage(icon)
		end

		if title ~= nil and not isTextGui(title) then
			table.insert(visualWarnings, layoutName .. ".PaidReflectChoice.Title is not text")
			title = nil
		end

		if costLabel ~= nil and not isTextGui(costLabel) then
			table.insert(visualWarnings, layoutName .. ".PaidReflectChoice.CostLabel is not text")
			costLabel = nil
		end

		if icon ~= nil then
			applyUpgradeIcon(icon, "ReflectShield")
		end

		if title ~= nil then
			title.Text = "REFLECT"
		end

		if costLabel ~= nil then
			costLabel.Text = "10"
		end

		card.Visible = false
		card:SetAttribute("UpgradeId", nil)

		if button ~= nil then
			button.Active = false
			button:SetAttribute("UpgradeId", nil)
		end

		return {
			Card = card,
			Button = button,
			Icon = icon,
			Title = title,
			CostLabel = costLabel,
		}
	end

	local function bindTemplateLayout(layoutRoot, layoutName)
		local invalidReasons = {}
		local templateChoices = {}
		local iconSlots = {}
		local belt = layoutRoot ~= nil and layoutRoot:FindFirstChild("UpgradeChoiceBelt") or nil

		if layoutRoot == nil or not layoutRoot:IsA("GuiObject") then
			table.insert(invalidReasons, layoutName .. " layout root must be a GuiObject")
		end

		if belt == nil or not belt:IsA("Frame") then
			table.insert(invalidReasons, layoutName .. " missing Frame UpgradeChoiceBelt")
		end

		local choices = belt ~= nil and belt:FindFirstChild("Choices") or nil
		if choices == nil or not choices:IsA("Frame") then
			table.insert(invalidReasons, layoutName .. " missing Frame UpgradeChoiceBelt.Choices")
		end

		local iconStrip = layoutRoot ~= nil and layoutRoot:FindFirstChild("ActiveIcons") or nil
		if iconStrip == nil or not iconStrip:IsA("Frame") then
			table.insert(invalidReasons, layoutName .. " missing Frame ActiveIcons")
		end

		local title = belt ~= nil and belt:FindFirstChild("TitleLabel") or nil
		if not isTextGui(title) then
			table.insert(visualWarnings, layoutName .. ".UpgradeChoiceBelt.TitleLabel is missing or not text")
			title = nil
		end

		local subtitle = belt ~= nil and belt:FindFirstChild("Subtitle") or nil
		if not isTextGui(subtitle) then
			table.insert(visualWarnings, layoutName .. ".UpgradeChoiceBelt.Subtitle is missing or not text")
			subtitle = nil
		end

		if choices ~= nil and choices:IsA("Frame") then
			for index = 1, 3 do
				local choiceName = "Choice" .. tostring(index)
				local card = choices:FindFirstChild(choiceName)

				if not isChoiceRoot(card) then
					table.insert(invalidReasons, layoutName .. " missing Frame or TextButton UpgradeChoiceBelt.Choices." .. choiceName)
				else
					local button = nil
					local templateButton = card:FindFirstChild("Button")

					if templateButton ~= nil then
						if templateButton:IsA("TextButton") then
							button = templateButton
						else
							table.insert(visualWarnings, layoutName .. ".UpgradeChoiceBelt.Choices." .. choiceName .. ".Button is not a TextButton")
						end
					end

					if button == nil and card:IsA("TextButton") then
						button = card
					end

					if button == nil then
						table.insert(invalidReasons, layoutName .. " missing clickable Button for UpgradeChoiceBelt.Choices." .. choiceName)
					end

					local icon = card:FindFirstChild("Icon")
					local iconImage = card:FindFirstChild("IconImage")
					if not isIconGui(icon) then
						if isImageGui(iconImage) then
							icon = iconImage
						else
							table.insert(visualWarnings, layoutName .. ".UpgradeChoiceBelt.Choices." .. choiceName .. ".Icon is missing or not a supported icon gui")
							icon = nil
						end
					elseif icon ~= nil then
						getOrCreateIconImage(icon)
					end

					local name = card:FindFirstChild("Title")
					if not isTextGui(name) then
						table.insert(visualWarnings, layoutName .. ".UpgradeChoiceBelt.Choices." .. choiceName .. ".Title is missing or not text")
						name = nil
					end

					local effect = card:FindFirstChild("Effect")
					if effect ~= nil and not isTextGui(effect) then
						table.insert(visualWarnings, layoutName .. ".UpgradeChoiceBelt.Choices." .. choiceName .. ".Effect is not text")
						effect = nil
					end

					table.insert(templateChoices, {
						Card = card,
						Icon = icon,
						Name = name,
						Effect = effect,
						Button = button,
						UpgradeId = nil,
					})
				end
			end
		end

		if iconStrip ~= nil and iconStrip:IsA("Frame") then
			for index = 1, UPGRADE_ICON_SLOT_COUNT do
				local slotName = "Slot" .. tostring(index)
				local slot = iconStrip:FindFirstChild(slotName)

				if isIconGui(slot) then
					table.insert(iconSlots, slot)
				else
					table.insert(visualWarnings, layoutName .. ".ActiveIcons." .. slotName .. " is missing or not a supported icon gui")
				end
			end
		end

		local overflow = iconStrip ~= nil and iconStrip:FindFirstChild("Overflow") or nil
		if not isTextGui(overflow) then
			table.insert(visualWarnings, layoutName .. ".ActiveIcons.Overflow is missing or not text")
			overflow = nil
		end

		if #invalidReasons > 0 then
			return nil, invalidReasons
		end

		return {
			Root = layoutRoot,
			OfferPanel = belt,
			Title = title,
			Subtitle = subtitle,
			ChoiceCards = templateChoices,
			IconStrip = iconStrip,
			IconSlots = iconSlots,
			Overflow = overflow,
			PaidReflectSlot = choices ~= nil and bindPaidReflectSlot(choices, layoutName) or nil,
		}, nil
	end

	local desktopRoot = clone:FindFirstChild("DesktopLayout")
	local mobileRoot = clone:FindFirstChild("MobileLayout")
	local templateLayouts = nil
	local invalidReasons = {}

	if desktopRoot ~= nil or mobileRoot ~= nil then
		local desktopLayout, desktopInvalidReasons = bindTemplateLayout(desktopRoot, "DesktopLayout")
		local mobileLayout, mobileInvalidReasons = bindTemplateLayout(mobileRoot, "MobileLayout")

		if desktopLayout ~= nil and mobileLayout ~= nil then
			templateLayouts = {
				Desktop = desktopLayout,
				Mobile = mobileLayout,
			}
		else
			if desktopInvalidReasons ~= nil then
				for _, reason in ipairs(desktopInvalidReasons) do
					table.insert(invalidReasons, reason)
				end
			end

			if mobileInvalidReasons ~= nil then
				for _, reason in ipairs(mobileInvalidReasons) do
					table.insert(invalidReasons, reason)
				end
			end
		end
	else
		local defaultLayout, defaultInvalidReasons = bindTemplateLayout(clone, "DefaultLayout")

		if defaultLayout ~= nil then
			templateLayouts = {
				Desktop = defaultLayout,
				Mobile = defaultLayout,
			}
		elseif defaultInvalidReasons ~= nil then
			for _, reason in ipairs(defaultInvalidReasons) do
				table.insert(invalidReasons, reason)
			end
		end
	end

	if #invalidReasons > 0 or templateLayouts == nil then
		warnTemplateIssueOnce(
			"_warnedInvalidTemplate",
			"[WOB] BattleArenaUpgradeBeltTemplate is invalid (" .. table.concat(invalidReasons, "; ") .. ") — using scripted fallback"
		)
		clone:Destroy()
		return false
	end

	if #visualWarnings > 0 then
		warnTemplateIssueOnce(
			"_warnedTemplateVisualChildren",
			"[WOB] BattleArenaUpgradeBeltTemplate has missing optional visual children: "
				.. table.concat(visualWarnings, "; ")
		)
	end

	clone.Parent = self._parent
	self._root = clone
	self._templateLayouts = templateLayouts

	local connectedLayouts = {}

	for _, layoutState in pairs(templateLayouts) do
		if connectedLayouts[layoutState] then
			continue
		end

		connectedLayouts[layoutState] = true
		layoutState.Root.Visible = false

		for index = 1, 3 do
			local entry = layoutState.ChoiceCards[index]

			entry.Button.Activated:Connect(function()
				if typeof(entry.UpgradeId) ~= "string" or entry.UpgradeId == "" then
					return
				end
				if self._onChoiceSelected ~= nil then
					self._onChoiceSelected(entry.UpgradeId)
				end
			end)
		end
	end

	self:_selectTemplateLayout(templateLayouts.Desktop)

	return true
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

function BattleArenaUpgradeHud:SetShieldState(shieldState)
	shieldState = typeof(shieldState) == "table" and shieldState or {}
	self._shieldState = {
		Active = shieldState.Active == true,
		Charges = math.max(0, math.floor(tonumber(shieldState.Charges) or 0)),
		SpawnShieldUntil = math.max(0, tonumber(shieldState.SpawnShieldUntil) or 0),
	}
	self:_render()
end

function BattleArenaUpgradeHud:Destroy()
	if self._root ~= nil then
		self._root:Destroy()
		self._root = nil
	end
end

function BattleArenaUpgradeHud:_applyLayout()
	if self._usesTemplate then
		self:_applyTemplateLayoutState()
		return
	end

	if self._isMobile then
		self:_applyMobileLayout()
	else
		self:_applyDesktopLayout()
	end
end

function BattleArenaUpgradeHud:_selectTemplateLayout(layoutState)
	if layoutState == nil then
		return
	end

	self._activeTemplateLayout = layoutState
	self._offerPanel = layoutState.OfferPanel
	self._title = layoutState.Title
	self._subtitle = layoutState.Subtitle
	self._choiceCards = layoutState.ChoiceCards
	self._iconStrip = layoutState.IconStrip
	self._iconSlots = layoutState.IconSlots
	self._overflow = layoutState.Overflow
	self._paidReflectSlot = layoutState.PaidReflectSlot

	local seenLayouts = {}

	for _, candidateLayout in pairs(self._templateLayouts or {}) do
		if not seenLayouts[candidateLayout] then
			seenLayouts[candidateLayout] = true
			candidateLayout.Root.Visible = candidateLayout == layoutState
		end
	end
end

function BattleArenaUpgradeHud:_applyTemplateLayoutState()
	if self._root ~= nil then
		self._root:SetAttribute("IsMobileLayout", self._isMobile)
	end

	if self._templateLayouts ~= nil then
		local layoutState = self._isMobile and self._templateLayouts.Mobile or self._templateLayouts.Desktop
		self:_selectTemplateLayout(layoutState)

		if self._isMobile then
			local safeTopY = getMobileSafeUpgradeTopY(self._viewportSize)

			layoutState.OfferPanel.AnchorPoint = Vector2.new(0.5, 0)
			layoutState.OfferPanel.Position = UDim2.new(0.5, 0, 0, safeTopY)

			if layoutState.IconStrip ~= nil then
				layoutState.IconStrip.AnchorPoint = Vector2.new(0.5, 0)
				layoutState.IconStrip.Position = UDim2.new(0.5, 0, 0, safeTopY)
			end
		end
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
	local safeTopY = getMobileSafeUpgradeTopY(viewportSize)

	self._offerPanel.AnchorPoint = Vector2.new(0.5, 0)
	self._offerPanel.Position = UDim2.new(0.5, 0, 0, safeTopY)
	self._offerPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)

	if self._title ~= nil then
		self._title.Position = UDim2.fromOffset(8, 4)
		self._title.Size = UDim2.new(1, -16, 0, 18)
		self._title.TextSize = 13
	end

	if self._subtitle ~= nil then
		self._subtitle.Visible = false
	end

	for index, entry in ipairs(self._choiceCards) do
		local x = rowX + (index - 1) * (buttonSize + buttonGap)
		entry.Card.Position = UDim2.fromOffset(x, 24)
		entry.Card.Size = UDim2.fromOffset(buttonSize, buttonSize)
		if entry.Icon ~= nil then
			entry.Icon.Position = UDim2.fromOffset(0, 4)
			entry.Icon.Size = UDim2.new(1, 0, 0, math.floor(buttonSize * 0.56))
			if isTextGui(entry.Icon) then
				entry.Icon.TextSize = math.floor(buttonSize * 0.42)
			end
		end

		if entry.Name ~= nil then
			entry.Name.Position = UDim2.new(0, 3, 1, -20)
			entry.Name.Size = UDim2.new(1, -6, 0, 17)
			entry.Name.TextSize = math.max(8, math.floor(buttonSize * 0.16))
			entry.Name.TextXAlignment = Enum.TextXAlignment.Center
		end

		if entry.Effect ~= nil then
			entry.Effect.Visible = false
		end
		entry.Button.Position = UDim2.fromScale(0, 0)
		entry.Button.Size = UDim2.fromScale(1, 1)
	end

	self:_layoutIconStrip({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, safeTopY),
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

	if self._title ~= nil then
		self._title.Position = UDim2.fromOffset(14, 8)
		self._title.Size = UDim2.new(1, -28, 0, 22)
		self._title.TextSize = 15
	end

	if self._subtitle ~= nil then
		self._subtitle.Visible = true
		self._subtitle.Position = UDim2.fromOffset(14, 30)
		self._subtitle.Size = UDim2.new(1, -28, 0, 18)
		self._subtitle.TextSize = 11
	end

	for index, entry in ipairs(self._choiceCards) do
		local x = 14 + (index - 1) * (cardWidth + cardGap)
		entry.Card.Position = UDim2.fromOffset(x, 54)
		entry.Card.Size = UDim2.fromOffset(cardWidth, cardHeight)

		if entry.Icon ~= nil then
			entry.Icon.Position = UDim2.fromOffset(0, 4)
			entry.Icon.Size = UDim2.new(1, 0, 0, 34)
			if isTextGui(entry.Icon) then
				entry.Icon.TextSize = 24
			end
		end

		if entry.Name ~= nil then
			entry.Name.Position = UDim2.fromOffset(5, 40)
			entry.Name.Size = UDim2.new(1, -10, 0, 17)
			entry.Name.TextSize = 11
			entry.Name.TextXAlignment = Enum.TextXAlignment.Center
		end

		if entry.Effect ~= nil then
			entry.Effect.Visible = true
			entry.Effect.Position = UDim2.fromOffset(5, 56)
			entry.Effect.Size = UDim2.new(1, -10, 0, 13)
			entry.Effect.TextSize = 8
			entry.Effect.TextXAlignment = Enum.TextXAlignment.Center
		end

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
	if self._templateLayoutOwned then
		return
	end

	if self._iconStrip == nil or self._overflow == nil then
		return
	end

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
		if isTextGui(slot) then
			slot.TextSize = math.max(12, math.floor(slotSize * 0.52))
		end
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
	self:_renderPaidReflectSlot()

	if hasOffer then
		self:_renderOffer()
		self._iconStrip.Visible = false
	else
		self:_renderIconStrip()
	end
end

function BattleArenaUpgradeHud:_renderPaidReflectSlot()
	local slot = self._paidReflectSlot

	if slot == nil then
		return
	end

	slot.Card.Visible = false
	slot.Card:SetAttribute("UpgradeId", nil)

	if slot.Button ~= nil then
		slot.Button.Active = false
		slot.Button:SetAttribute("UpgradeId", nil)
	end

	if slot.Icon ~= nil then
		applyUpgradeIcon(slot.Icon, "ReflectShield")
	end

	if slot.Title ~= nil then
		slot.Title.Text = "REFLECT"
	end

	if slot.CostLabel ~= nil then
		slot.CostLabel.Text = "10"
	end
end

function BattleArenaUpgradeHud:_renderOffer()
	local offer = self._offer
	local choices = offer.Choices or {}
	local source = tostring(offer.Source or "LevelUp")
	local arenaLevel = tonumber(offer.ArenaLevel) or 1

	if self._title ~= nil then
		self._title.Text = source == "SupplyCrate" and "SUPPLY" or "LEVEL UP"
	end

	if self._subtitle ~= nil then
		self._subtitle.Text = "Arena Level " .. tostring(math.floor(arenaLevel)) .. " upgrade"
	end

	for index, entry in ipairs(self._choiceCards) do
		local choice = choices[index]

		if choice ~= nil then
			local choiceId = tostring(choice.Id or "")
			entry.UpgradeId = choiceId
			entry.Card.Visible = true
			entry.Card:SetAttribute("UpgradeId", choiceId)
			entry.Button.Active = true
			entry.Button:SetAttribute("UpgradeId", choiceId)

			if entry.Icon ~= nil then
				applyUpgradeIcon(entry.Icon, choiceId)
			end

			if entry.Name ~= nil then
				entry.Name.Text = self._isMobile and getShortUpgradeTitle(choice) or tostring(choice.Title or choice.Id or "Upgrade")
			end

			if entry.Effect ~= nil then
				entry.Effect.Text = getDescription(choice)
			end
		else
			entry.UpgradeId = nil
			entry.Card.Visible = false
			entry.Card:SetAttribute("UpgradeId", nil)
			entry.Button.Active = false
			entry.Button:SetAttribute("UpgradeId", nil)

			if entry.Name ~= nil then
				entry.Name.Text = ""
			end

			if entry.Icon ~= nil then
				clearUpgradeIcon(entry.Icon)
			end

			if entry.Effect ~= nil then
				entry.Effect.Text = ""
			end
		end
	end
end

function BattleArenaUpgradeHud:_renderIconStrip()
	local ids = splitUpgradeIds(self._activeUpgradeIds)
	local displayIds = {}
	local hasShieldIcon = false

	for _, upgradeId in ipairs(ids) do
		if upgradeId == "ReflectShield" then
			hasShieldIcon = true
		else
			table.insert(displayIds, upgradeId)
		end
	end

	if self._shieldState.Active == true then
		if hasShieldIcon then
			table.insert(displayIds, "ReflectShield")
		else
			table.insert(displayIds, 1, "ReflectShield")
		end
	end

	local visible = self._visible and #displayIds > 0

	self._iconStrip.Visible = visible

	if not visible then
		for _, slot in ipairs(self._iconSlots) do
			slot.Visible = false
		end

		if self._overflow ~= nil then
			self._overflow.Visible = false
		end

		return
	end

	local displayCount = math.min(#displayIds, UPGRADE_ICON_SLOT_COUNT)
	local overflow = #displayIds - displayCount

	for index, slot in ipairs(self._iconSlots) do
		if index <= displayCount then
			applyUpgradeIcon(slot, displayIds[index])
			slot.Visible = true
		else
			clearUpgradeIcon(slot)
			slot.Visible = false
		end
	end

	if overflow > 0 then
		if self._overflow ~= nil then
			self._overflow.Text = "+" .. tostring(overflow)
			self._overflow.Visible = true
		end
	elseif self._overflow ~= nil then
		self._overflow.Visible = false
	end
end

return BattleArenaUpgradeHud
