#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path.cwd()
OVERLAY = ROOT / "src/StarterPlayer/StarterPlayerScripts/Client/WOBBattleArenaOverlay.client.luau"
MODULE = ROOT / "src/StarterPlayer/StarterPlayerScripts/Client/Hud/BattleArenaUpgradeHud.luau"

MODULE_CODE = 'local BattleArenaUpgradeHud = {}\nBattleArenaUpgradeHud.__index = BattleArenaUpgradeHud\n\nlocal UPGRADE_ICON_SLOT_COUNT = 5\n\nlocal function addCorner(parent, radius)\n\tlocal corner = Instance.new("UICorner")\n\tcorner.CornerRadius = radius\n\tcorner.Parent = parent\n\n\treturn corner\nend\n\nlocal function addStroke(parent, color, transparency, thickness)\n\tlocal stroke = Instance.new("UIStroke")\n\tstroke.Color = color\n\tstroke.Transparency = transparency\n\tstroke.Thickness = thickness\n\tstroke.Parent = parent\n\n\treturn stroke\nend\n\nlocal function makeLabel(parent, name, textSize, font, zIndex)\n\tlocal label = Instance.new("TextLabel")\n\tlabel.Name = name\n\tlabel.BackgroundTransparency = 1\n\tlabel.BorderSizePixel = 0\n\tlabel.Font = font or Enum.Font.GothamBold\n\tlabel.Text = ""\n\tlabel.TextColor3 = Color3.fromRGB(241, 255, 248)\n\tlabel.TextSize = textSize\n\tlabel.TextWrapped = false\n\tlabel.TextTruncate = Enum.TextTruncate.AtEnd\n\tlabel.TextXAlignment = Enum.TextXAlignment.Center\n\tlabel.TextYAlignment = Enum.TextYAlignment.Center\n\tlabel.ZIndex = zIndex\n\tlabel.Parent = parent\n\n\treturn label\nend\n\nlocal function splitUpgradeIds(upgradeIds)\n\tlocal ids = {}\n\n\tif typeof(upgradeIds) ~= "string" or upgradeIds == "" then\n\t\treturn ids\n\tend\n\n\tfor id in string.gmatch(upgradeIds, "[^,]+") do\n\t\tlocal trimmed = string.gsub(id, "^%s*(.-)%s*$", "%1")\n\n\t\tif trimmed ~= "" then\n\t\t\ttable.insert(ids, trimmed)\n\t\tend\n\tend\n\n\treturn ids\nend\n\nlocal function getUpgradeIcon(upgradeId)\n\tif typeof(upgradeId) ~= "string" then\n\t\treturn "★"\n\tend\n\n\tlocal lower = string.lower(upgradeId)\n\n\tif string.find(lower, "firerate") or string.find(lower, "fire_rate") or string.find(lower, "reload") then\n\t\treturn "⚡"\n\telseif string.find(lower, "damage") or string.find(lower, "heavy") then\n\t\treturn "💥"\n\telseif string.find(lower, "ricochet") or string.find(lower, "bounce") then\n\t\treturn "🔁"\n\telseif string.find(lower, "repair") or string.find(lower, "armor") or string.find(lower, "hp") or string.find(lower, "health") then\n\t\treturn "🛡"\n\telseif string.find(lower, "speed") or string.find(lower, "turbo") or string.find(lower, "move") then\n\t\treturn "🏎"\n\telseif string.find(lower, "shield") then\n\t\treturn "🔵"\n\telseif string.find(lower, "triple") or string.find(lower, "double") or string.find(lower, "explosion") or string.find(lower, "bigboom") then\n\t\treturn "🔥"\n\telseif string.find(lower, "bolt") or string.find(lower, "reward") or string.find(lower, "magnet") then\n\t\treturn "🧲"\n\telse\n\t\treturn "★"\n\tend\nend\n\nlocal function getShortUpgradeTitle(choice)\n\tlocal title = tostring(choice.Title or choice.Id or "UPG")\n\ttitle = string.upper(title)\n\n\tlocal replacements = {\n\t\t["FIRE RATE"] = "RELOAD",\n\t\t["FIRERATE"] = "RELOAD",\n\t\t["DAMAGE UP"] = "DAMAGE",\n\t\t["PROJECTILE DAMAGE"] = "DAMAGE",\n\t\t["RICOCHET"] = "BOUNCE",\n\t\t["REPAIR"] = "REPAIR",\n\t\t["ARMOR"] = "ARMOR",\n\t\t["SPEED"] = "SPEED",\n\t\t["TURBO"] = "TURBO",\n\t}\n\n\tfor pattern, replacement in pairs(replacements) do\n\t\tif string.find(title, pattern) then\n\t\t\treturn replacement\n\t\tend\n\tend\n\n\tif #title > 8 then\n\t\treturn string.sub(title, 1, 8)\n\tend\n\n\treturn title\nend\n\nlocal function getDescription(choice)\n\tlocal description = tostring(choice.Description or "")\n\n\tif description == "" then\n\t\treturn tostring(choice.Id or "Run upgrade")\n\tend\n\n\treturn description\nend\n\nfunction BattleArenaUpgradeHud.new(params)\n\tassert(typeof(params) == "table", "BattleArenaUpgradeHud.new requires params")\n\tassert(params.Parent ~= nil, "BattleArenaUpgradeHud.new requires params.Parent")\n\n\tlocal self = setmetatable({}, BattleArenaUpgradeHud)\n\n\tself._parent = params.Parent\n\tself._zIndex = tonumber(params.ZIndex) or 30\n\tself._onChoiceSelected = params.OnChoiceSelected\n\tself._visible = true\n\tself._isMobile = false\n\tself._viewportSize = Vector2.new(1024, 768)\n\tself._offer = nil\n\tself._activeUpgradeIds = ""\n\n\tself:_createRoot()\n\tself:_createOfferPanel()\n\tself:_createIconStrip()\n\tself:SetLayout({\n\t\tIsMobile = false,\n\t\tViewportSize = self._viewportSize,\n\t})\n\tself:_render()\n\n\treturn self\nend\n\nfunction BattleArenaUpgradeHud:_createRoot()\n\tlocal root = Instance.new("Frame")\n\troot.Name = "BattleArenaUpgradeHud"\n\troot.BackgroundTransparency = 1\n\troot.BorderSizePixel = 0\n\troot.Position = UDim2.fromScale(0, 0)\n\troot.Size = UDim2.fromScale(1, 1)\n\troot.Active = false\n\troot.ZIndex = self._zIndex\n\troot.Parent = self._parent\n\n\tself._root = root\nend\n\nfunction BattleArenaUpgradeHud:_createOfferPanel()\n\tlocal panel = Instance.new("Frame")\n\tpanel.Name = "UpgradeChoiceBelt"\n\tpanel.BackgroundColor3 = Color3.fromRGB(13, 17, 23)\n\tpanel.BackgroundTransparency = 0.08\n\tpanel.BorderSizePixel = 0\n\tpanel.Visible = false\n\tpanel.Active = false\n\tpanel.ZIndex = self._zIndex\n\tpanel.Parent = self._root\n\taddCorner(panel, UDim.new(0, 8))\n\taddStroke(panel, Color3.fromRGB(250, 204, 21), 0.3, 1)\n\n\tlocal title = makeLabel(panel, "Title", 14, Enum.Font.GothamBlack, self._zIndex + 1)\n\ttitle.Text = "LEVEL UP"\n\ttitle.TextColor3 = Color3.fromRGB(250, 204, 21)\n\n\tlocal subtitle = makeLabel(panel, "Subtitle", 11, Enum.Font.GothamMedium, self._zIndex + 1)\n\tsubtitle.Text = ""\n\tsubtitle.TextColor3 = Color3.fromRGB(178, 238, 205)\n\n\tself._offerPanel = panel\n\tself._title = title\n\tself._subtitle = subtitle\n\tself._choiceCards = {}\n\n\tfor index = 1, 3 do\n\t\tlocal card = Instance.new("Frame")\n\t\tcard.Name = "Choice" .. tostring(index)\n\t\tcard.BackgroundColor3 = Color3.fromRGB(20, 26, 34)\n\t\tcard.BackgroundTransparency = 0.06\n\t\tcard.BorderSizePixel = 0\n\t\tcard.Visible = false\n\t\tcard.ZIndex = self._zIndex + 1\n\t\tcard.Parent = panel\n\t\taddCorner(card, UDim.new(0, 7))\n\t\taddStroke(card, Color3.fromRGB(249, 115, 22), 0.42, 1)\n\n\t\tlocal icon = makeLabel(card, "Icon", 24, Enum.Font.GothamBold, self._zIndex + 2)\n\t\ticon.Text = "★"\n\n\t\tlocal name = makeLabel(card, "Name", 10, Enum.Font.GothamBold, self._zIndex + 2)\n\t\tname.Text = "UPG"\n\t\tname.TextColor3 = Color3.fromRGB(241, 255, 248)\n\n\t\tlocal effect = makeLabel(card, "Effect", 11, Enum.Font.GothamMedium, self._zIndex + 2)\n\t\teffect.Text = ""\n\t\teffect.TextColor3 = Color3.fromRGB(178, 238, 205)\n\t\teffect.TextXAlignment = Enum.TextXAlignment.Left\n\n\t\tlocal button = Instance.new("TextButton")\n\t\tbutton.Name = "Button"\n\t\tbutton.BackgroundTransparency = 1\n\t\tbutton.BorderSizePixel = 0\n\t\tbutton.Text = ""\n\t\tbutton.AutoButtonColor = false\n\t\tbutton.Active = true\n\t\tbutton.ZIndex = self._zIndex + 3\n\t\tbutton.Parent = card\n\n\t\tlocal entry = {\n\t\t\tCard = card,\n\t\t\tIcon = icon,\n\t\t\tName = name,\n\t\t\tEffect = effect,\n\t\t\tButton = button,\n\t\t\tUpgradeId = nil,\n\t\t}\n\n\t\tbutton.Activated:Connect(function()\n\t\t\tif typeof(entry.UpgradeId) ~= "string" or entry.UpgradeId == "" then\n\t\t\t\treturn\n\t\t\tend\n\n\t\t\tif self._onChoiceSelected ~= nil then\n\t\t\t\tself._onChoiceSelected(entry.UpgradeId)\n\t\t\tend\n\t\tend)\n\n\t\ttable.insert(self._choiceCards, entry)\n\tend\nend\n\nfunction BattleArenaUpgradeHud:_createIconStrip()\n\tlocal strip = Instance.new("Frame")\n\tstrip.Name = "ActiveUpgradeIconStrip"\n\tstrip.BackgroundTransparency = 1\n\tstrip.BorderSizePixel = 0\n\tstrip.Visible = false\n\tstrip.ZIndex = self._zIndex - 1\n\tstrip.Parent = self._root\n\n\tself._iconStrip = strip\n\tself._iconSlots = {}\n\n\tfor index = 1, UPGRADE_ICON_SLOT_COUNT do\n\t\tlocal slot = makeLabel(strip, "Slot" .. tostring(index), 16, Enum.Font.GothamBold, self._zIndex)\n\t\tslot.BackgroundColor3 = Color3.fromRGB(20, 28, 38)\n\t\tslot.BackgroundTransparency = 0.22\n\t\tslot.Visible = false\n\t\taddCorner(slot, UDim.new(0, 6))\n\t\taddStroke(slot, Color3.fromRGB(250, 204, 21), 0.58, 1)\n\t\ttable.insert(self._iconSlots, slot)\n\tend\n\n\tlocal overflow = makeLabel(strip, "Overflow", 12, Enum.Font.GothamBold, self._zIndex)\n\toverflow.BackgroundColor3 = Color3.fromRGB(20, 28, 38)\n\toverflow.BackgroundTransparency = 0.22\n\toverflow.TextColor3 = Color3.fromRGB(178, 238, 205)\n\toverflow.Visible = false\n\taddCorner(overflow, UDim.new(0, 6))\n\n\tself._overflow = overflow\nend\n\nfunction BattleArenaUpgradeHud:SetVisible(isVisible)\n\tself._visible = isVisible == true\n\tself:_render()\nend\n\nfunction BattleArenaUpgradeHud:SetLayout(layout)\n\tlayout = layout or {}\n\tself._isMobile = layout.IsMobile == true\n\tself._viewportSize = layout.ViewportSize or self._viewportSize\n\n\tself:_applyLayout()\n\tself:_render()\nend\n\nfunction BattleArenaUpgradeHud:SetOffer(offer)\n\tself._offer = offer\n\tself:_render()\nend\n\nfunction BattleArenaUpgradeHud:SetActiveUpgradeIds(upgradeIds)\n\tself._activeUpgradeIds = typeof(upgradeIds) == "string" and upgradeIds or ""\n\tself:_render()\nend\n\nfunction BattleArenaUpgradeHud:Destroy()\n\tif self._root ~= nil then\n\t\tself._root:Destroy()\n\t\tself._root = nil\n\tend\nend\n\nfunction BattleArenaUpgradeHud:_applyLayout()\n\tif self._isMobile then\n\t\tself:_applyMobileLayout()\n\telse\n\t\tself:_applyDesktopLayout()\n\tend\nend\n\nfunction BattleArenaUpgradeHud:_applyMobileLayout()\n\tlocal viewportSize = self._viewportSize\n\tlocal panelWidth = math.clamp(math.floor(viewportSize.X * 0.56), 196, 248)\n\tlocal panelHeight = 90\n\tlocal buttonGap = 6\n\tlocal buttonSize = math.floor((panelWidth - 24 - buttonGap * 2) / 3)\n\tbuttonSize = math.clamp(buttonSize, 50, 66)\n\tlocal rowWidth = buttonSize * 3 + buttonGap * 2\n\tlocal rowX = math.floor((panelWidth - rowWidth) * 0.5)\n\n\tself._offerPanel.AnchorPoint = Vector2.new(0.5, 1)\n\tself._offerPanel.Position = UDim2.new(0.5, 0, 1, -104)\n\tself._offerPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)\n\n\tself._title.Position = UDim2.fromOffset(8, 4)\n\tself._title.Size = UDim2.new(1, -16, 0, 18)\n\tself._title.TextSize = 13\n\n\tself._subtitle.Visible = false\n\n\tfor index, entry in ipairs(self._choiceCards) do\n\t\tlocal x = rowX + (index - 1) * (buttonSize + buttonGap)\n\t\tentry.Card.Position = UDim2.fromOffset(x, 24)\n\t\tentry.Card.Size = UDim2.fromOffset(buttonSize, buttonSize)\n\t\tentry.Icon.Position = UDim2.fromOffset(0, 4)\n\t\tentry.Icon.Size = UDim2.new(1, 0, 0, math.floor(buttonSize * 0.56))\n\t\tentry.Icon.TextSize = math.floor(buttonSize * 0.42)\n\n\t\tentry.Name.Position = UDim2.new(0, 3, 1, -20)\n\t\tentry.Name.Size = UDim2.new(1, -6, 0, 17)\n\t\tentry.Name.TextSize = math.max(8, math.floor(buttonSize * 0.16))\n\t\tentry.Name.TextXAlignment = Enum.TextXAlignment.Center\n\n\t\tentry.Effect.Visible = false\n\t\tentry.Button.Position = UDim2.fromScale(0, 0)\n\t\tentry.Button.Size = UDim2.fromScale(1, 1)\n\tend\n\n\tself:_layoutIconStrip({\n\t\tAnchorPoint = Vector2.new(0.5, 1),\n\t\tPosition = UDim2.new(0.5, 0, 1, -96),\n\t\tSlotSize = 32,\n\t\tGap = 4,\n\t})\nend\n\nfunction BattleArenaUpgradeHud:_applyDesktopLayout()\n\tlocal panelWidth = 380\n\tlocal panelHeight = 260\n\tlocal cardHeight = 58\n\tlocal cardGap = 6\n\n\tself._offerPanel.AnchorPoint = Vector2.new(0.5, 0)\n\tself._offerPanel.Position = UDim2.new(0.5, 0, 0, 106)\n\tself._offerPanel.Size = UDim2.fromOffset(panelWidth, panelHeight)\n\n\tself._title.Position = UDim2.fromOffset(14, 10)\n\tself._title.Size = UDim2.new(1, -28, 0, 26)\n\tself._title.TextSize = 16\n\n\tself._subtitle.Visible = true\n\tself._subtitle.Position = UDim2.fromOffset(14, 36)\n\tself._subtitle.Size = UDim2.new(1, -28, 0, 20)\n\tself._subtitle.TextSize = 12\n\n\tfor index, entry in ipairs(self._choiceCards) do\n\t\tlocal y = 62 + (index - 1) * (cardHeight + cardGap)\n\t\tentry.Card.Position = UDim2.fromOffset(14, y)\n\t\tentry.Card.Size = UDim2.fromOffset(panelWidth - 28, cardHeight)\n\n\t\tentry.Icon.Position = UDim2.fromOffset(0, 0)\n\t\tentry.Icon.Size = UDim2.fromOffset(50, cardHeight)\n\t\tentry.Icon.TextSize = 22\n\n\t\tentry.Name.Position = UDim2.fromOffset(54, 4)\n\t\tentry.Name.Size = UDim2.new(1, -58, 0, 26)\n\t\tentry.Name.TextSize = 14\n\t\tentry.Name.TextXAlignment = Enum.TextXAlignment.Left\n\n\t\tentry.Effect.Visible = true\n\t\tentry.Effect.Position = UDim2.fromOffset(54, 30)\n\t\tentry.Effect.Size = UDim2.new(1, -58, 0, 22)\n\t\tentry.Effect.TextSize = 11\n\n\t\tentry.Button.Position = UDim2.fromScale(0, 0)\n\t\tentry.Button.Size = UDim2.fromScale(1, 1)\n\tend\n\n\tself:_layoutIconStrip({\n\t\tAnchorPoint = Vector2.new(1, 0),\n\t\tPosition = UDim2.new(1, -22, 0, 182),\n\t\tSlotSize = 30,\n\t\tGap = 4,\n\t})\nend\n\nfunction BattleArenaUpgradeHud:_layoutIconStrip(config)\n\tlocal slotSize = config.SlotSize\n\tlocal gap = config.Gap\n\tlocal stripWidth = UPGRADE_ICON_SLOT_COUNT * slotSize + (UPGRADE_ICON_SLOT_COUNT - 1) * gap\n\tlocal overflowWidth = math.floor(slotSize * 1.25)\n\n\tself._iconStrip.AnchorPoint = config.AnchorPoint\n\tself._iconStrip.Position = config.Position\n\tself._iconStrip.Size = UDim2.fromOffset(stripWidth + gap + overflowWidth, slotSize)\n\n\tfor index, slot in ipairs(self._iconSlots) do\n\t\tslot.Position = UDim2.fromOffset((index - 1) * (slotSize + gap), 0)\n\t\tslot.Size = UDim2.fromOffset(slotSize, slotSize)\n\t\tslot.TextSize = math.max(12, math.floor(slotSize * 0.52))\n\tend\n\n\tself._overflow.Position = UDim2.fromOffset(UPGRADE_ICON_SLOT_COUNT * (slotSize + gap), 0)\n\tself._overflow.Size = UDim2.fromOffset(overflowWidth, slotSize)\n\tself._overflow.TextSize = math.max(10, math.floor(slotSize * 0.38))\nend\n\nfunction BattleArenaUpgradeHud:_hasOffer()\n\tlocal offer = self._offer\n\tlocal choices = offer ~= nil and offer.Choices or {}\n\n\treturn offer ~= nil and #choices > 0\nend\n\nfunction BattleArenaUpgradeHud:_render()\n\tif self._root == nil then\n\t\treturn\n\tend\n\n\tlocal hasOffer = self._visible and self:_hasOffer()\n\n\tself._root.Visible = self._visible\n\tself._offerPanel.Visible = hasOffer\n\tself._offerPanel.Active = hasOffer\n\n\tif hasOffer then\n\t\tself:_renderOffer()\n\t\tself._iconStrip.Visible = false\n\telse\n\t\tself:_renderIconStrip()\n\tend\nend\n\nfunction BattleArenaUpgradeHud:_renderOffer()\n\tlocal offer = self._offer\n\tlocal choices = offer.Choices or {}\n\tlocal source = tostring(offer.Source or "LevelUp")\n\tlocal arenaLevel = tonumber(offer.ArenaLevel) or 1\n\n\tself._title.Text = source == "SupplyCrate" and "SUPPLY" or "LEVEL UP"\n\tself._subtitle.Text = "Arena Level " .. tostring(math.floor(arenaLevel)) .. " upgrade"\n\n\tfor index, entry in ipairs(self._choiceCards) do\n\t\tlocal choice = choices[index]\n\n\t\tif choice ~= nil then\n\t\t\tlocal choiceId = tostring(choice.Id or "")\n\t\t\tentry.UpgradeId = choiceId\n\t\t\tentry.Card.Visible = true\n\t\t\tentry.Icon.Text = getUpgradeIcon(choiceId)\n\t\t\tentry.Name.Text = self._isMobile and getShortUpgradeTitle(choice) or tostring(choice.Title or choice.Id or "Upgrade")\n\t\t\tentry.Effect.Text = getDescription(choice)\n\t\telse\n\t\t\tentry.UpgradeId = nil\n\t\t\tentry.Card.Visible = false\n\t\t\tentry.Name.Text = ""\n\t\t\tentry.Effect.Text = ""\n\t\tend\n\tend\nend\n\nfunction BattleArenaUpgradeHud:_renderIconStrip()\n\tlocal ids = splitUpgradeIds(self._activeUpgradeIds)\n\tlocal visible = self._visible and #ids > 0\n\n\tself._iconStrip.Visible = visible\n\n\tif not visible then\n\t\treturn\n\tend\n\n\tlocal displayCount = math.min(#ids, UPGRADE_ICON_SLOT_COUNT)\n\tlocal overflow = #ids - displayCount\n\n\tfor index, slot in ipairs(self._iconSlots) do\n\t\tif index <= displayCount then\n\t\t\tslot.Text = getUpgradeIcon(ids[index])\n\t\t\tslot.Visible = true\n\t\telse\n\t\t\tslot.Visible = false\n\t\tend\n\tend\n\n\tif overflow > 0 then\n\t\tself._overflow.Text = "+" .. tostring(overflow)\n\t\tself._overflow.Visible = true\n\telse\n\t\tself._overflow.Visible = false\n\tend\nend\n\nreturn BattleArenaUpgradeHud\n'

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Pattern not found: {label}")
    return text.replace(old, new, 1)

def sub_once(text: str, pattern: str, repl: str, label: str) -> str:
    new_text, count = re.subn(pattern, repl, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"Regex replacement failed ({count} matches): {label}")
    return new_text

def main() -> None:
    if not OVERLAY.exists():
        raise FileNotFoundError(f"Missing overlay file: {OVERLAY}")

    MODULE.parent.mkdir(parents=True, exist_ok=True)
    MODULE.write_text(MODULE_CODE, encoding="utf-8")

    text = OVERLAY.read_text(encoding="utf-8")

    if 'BattleArenaUpgradeHud' not in text:
        text = replace_once(
            text,
            'local CompactStatsFormatter = require(hudModules:WaitForChild("CompactStatsFormatter"))\n',
            'local CompactStatsFormatter = require(hudModules:WaitForChild("CompactStatsFormatter"))\n'
            'local BattleArenaUpgradeHud = require(hudModules:WaitForChild("BattleArenaUpgradeHud"))\n',
            "require BattleArenaUpgradeHud",
        )

    text = sub_once(
        text,
        r'-- Upgrade offer panel -+\n.*?\nlocal function isArenaMode\(\)',
        '''local upgradeHud
upgradeHud = BattleArenaUpgradeHud.new({
\tParent = screenGui,
\tZIndex = POPUP_Z_INDEX,
\tOnChoiceSelected = function(upgradeId)
\t\tif currentUpgradeOffer == nil then
\t\t\treturn
\t\tend

\t\tif typeof(upgradeId) ~= "string" or upgradeId == "" then
\t\t\treturn
\t\tend

\t\tupgradeChoiceEvent:FireServer({
\t\t\tOfferId = currentUpgradeOffer.OfferId,
\t\t\tUpgradeId = upgradeId,
\t\t})
\t\tcurrentUpgradeOffer = nil
\t\tupgradeHud:SetOffer(nil)
\tend,
})

local function isArenaMode()''',
        "replace old inline upgrade UI block",
    )

    text = sub_once(
        text,
        r'\n\t-- Upgrade panel: 3 cards .*?\n\tlayoutIconStrip\(30, 4\)\n',
        '''\n\tlocal camera = Workspace.CurrentCamera
\tlocal viewportSize = camera ~= nil and camera.ViewportSize or Vector2.new(1024, 768)
\tupgradeHud:SetLayout({
\t\tIsMobile = false,
\t\tViewportSize = viewportSize,
\t})
''',
        "desktop upgrade layout",
    )

    text = sub_once(
        text,
        r'\n\t-- Upgrade panel: top-center .*?\n\tlayoutIconStrip\(36, 4\)\n',
        '''\n\tupgradeHud:SetLayout({
\t\tIsMobile = true,
\t\tViewportSize = viewportSize,
\t})
''',
        "mobile upgrade layout",
    )

    text = sub_once(
        text,
        r'\nlocal function updateUpgradeOfferPanel\(\).*?\nlocal function updateHealth\(',
        '\nlocal function updateHealth(',
        "remove old upgrade update functions",
    )

    text = text.replace(
        '\t\tupgradeOfferPanel.Visible = false\n\t\tupgradeIconStrip.Visible = false\n\t\treturn\n',
        '\t\tupgradeHud:SetVisible(false)\n\t\tupgradeHud:SetOffer(nil)\n\t\treturn\n',
    )

    text = text.replace(
        '\tupdateHealth(ownedTank, mobileLayout)\n\tupdateUpgradeOfferPanel()\n\tupdateUpgradeIconStrip()\n',
        '\tupdateHealth(ownedTank, mobileLayout)\n\tupgradeHud:SetVisible(true)\n\tupgradeHud:SetOffer(currentUpgradeOffer)\n\tupgradeHud:SetActiveUpgradeIds(upgrades)\n',
    )

    text = sub_once(
        text,
        r'\nfor _, entry in ipairs\(upgradeCards\) do\n.*?\nend\n\nupgradeChoiceEvent\.OnClientEvent',
        '\nupgradeChoiceEvent.OnClientEvent',
        "remove old upgradeCards click handlers",
    )

    text = text.replace(
        '\tcurrentUpgradeOffer = payload\n\tupdateLayout()\n\tupdateUpgradeOfferPanel()\n',
        '\tcurrentUpgradeOffer = payload\n\tupdateOverlay()\n',
    )

    for forbidden in [
        "upgradeOfferPanel",
        "upgradeOfferTitle",
        "upgradeOfferSubtitle",
        "upgradeCards",
        "upgradeIconStrip",
        "upgradeIconSlots",
        "upgradeIconOverflow",
        "layoutIconStrip",
        "updateUpgradeOfferPanel",
        "updateUpgradeIconStrip",
    ]:
        if forbidden in text:
            raise RuntimeError(f"Old inline upgrade symbol still present in overlay: {forbidden}")

    OVERLAY.write_text(text, encoding="utf-8")
    print("OK: wrote BattleArenaUpgradeHud.luau and refactored WOBBattleArenaOverlay.client.luau")

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
