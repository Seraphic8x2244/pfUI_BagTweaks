-- pfUI_BagTweaks toolbar prototype
-- Dev-branch experiment only. Keeps the main grouping implementation isolated.

if not pfUI then return end

local TOOLBAR_HEIGHT = 12
local TOOLBAR_GAP = 2
local SEARCH_GAP = 2
local SEARCH_HEIGHT = 14
local UPDATE_INTERVAL = .20

local state = {
  initialized = false,
  searchOpen = false,
  searchButton = nil,
  activeMode = nil,
  wasTargeting = false,
  awaitingCompletion = false,
  rearmAt = nil,
  lastUpdate = 0,
  oldBagOnHide = nil,
}

local function FontSize()
  local size = 9
  if pfUI_config and pfUI_config.global and pfUI_config.global.font_size then
    size = tonumber(pfUI_config.global.font_size) or size
  end
  if size > 9 then size = 9 end
  if size < 7 then size = 7 end
  return size
end

local function FriendlyLabel(frame, bag)
  if frame == state.searchButton then return "Search" end
  if frame == bag.sort then return "Sort" end
  if frame == bag.keys then return "Keys" end
  if frame == bag.picklock then return "Pick Lock" end
  if frame == bag.disenchant then return "Disenchant" end
  if frame == bag.open then return "Open" end
  if frame == bag.bags then return "Bags" end

  if frame.GetText then
    local text = frame:GetText()
    if text and text ~= "" then return text end
  end

  if frame.GetName then
    local name = frame:GetName()
    if name and name ~= "" then
      name = string.gsub(name, "^pfBag", "")
      name = string.gsub(name, "^pfUIBag", "")
      name = string.gsub(name, "Button$", "")
      name = string.gsub(name, "Slot", "")
      if name ~= "" then return name end
    end
  end

  return "Button"
end

local function KnownRank(frame, bag)
  if frame == state.searchButton then return 10 end
  if frame == bag.sort then return 20 end
  if frame == bag.keys then return 30 end
  if frame == bag.picklock then return 40 end
  if frame == bag.disenchant then return 50 end
  if frame == bag.open then return 60 end
  if frame == bag.bags then return 70 end
  return 100
end

local function EnsureLabel(button, text)
  if not button.bagtweaks_toolbar_label then
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", button, "LEFT", 2, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    label:SetJustifyH("CENTER")
    button.bagtweaks_toolbar_label = label
  end

  local label = button.bagtweaks_toolbar_label
  label:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, FontSize(), "OUTLINE")
  label:SetText(text)
  label:Show()

  if button.texture and button.texture.SetAlpha then
    button.texture:SetAlpha(0)
  end
end

local function EnsureActiveOverlay(button)
  if not button then return end
  if not button.bagtweaks_active_overlay then
    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(button)
    tex:SetTexture(1, 1, 1, 1)
    tex:SetVertexColor(.15, 1, .15, .20)
    tex:Hide()
    button.bagtweaks_active_overlay = tex
  end
end

local function UpdateActiveVisuals()
  local bag = pfUI.bag and pfUI.bag.right
  if not bag then return end

  EnsureActiveOverlay(state.searchButton)
  EnsureActiveOverlay(bag.disenchant)
  EnsureActiveOverlay(bag.picklock)

  if state.searchButton and state.searchButton.bagtweaks_active_overlay then
    if state.searchOpen then state.searchButton.bagtweaks_active_overlay:Show()
    else state.searchButton.bagtweaks_active_overlay:Hide() end
  end

  if bag.disenchant and bag.disenchant.bagtweaks_active_overlay then
    if state.activeMode == "disenchant" then bag.disenchant.bagtweaks_active_overlay:Show()
    else bag.disenchant.bagtweaks_active_overlay:Hide() end
  end

  if bag.picklock and bag.picklock.bagtweaks_active_overlay then
    if state.activeMode == "picklock" then bag.picklock.bagtweaks_active_overlay:Show()
    else bag.picklock.bagtweaks_active_overlay:Hide() end
  end
end

local function ApplySearchState()
  local bag = pfUI.bag and pfUI.bag.right
  local search = bag and bag.search
  if not search then return end

  search:Show()
  search:ClearAllPoints()
  search:SetPoint("BOTTOMLEFT", bag, "TOPLEFT", 0, SEARCH_GAP)
  search:SetPoint("BOTTOMRIGHT", bag, "TOPRIGHT", 0, SEARCH_GAP)
  search:SetHeight(SEARCH_HEIGHT)

  if state.searchOpen then
    search:SetAlpha(1)
    search:EnableMouse(1)
    if search.edit then search.edit:EnableMouse(1) end
  else
    if search.edit then
      search.edit:ClearFocus()
      search.edit:EnableMouse(0)
    end
    search:EnableMouse(0)
    search:SetAlpha(0)
  end

  UpdateActiveVisuals()
end

local function ToggleSearch()
  state.searchOpen = not state.searchOpen
  ApplySearchState()

  local bag = pfUI.bag and pfUI.bag.right
  if state.searchOpen and bag and bag.search and bag.search.edit then
    bag.search.edit:SetFocus()
  end
end

local function EnsureSearchButton(bag)
  if state.searchButton then return state.searchButton end

  local b = CreateFrame("Button", nil, bag)
  b.bagtweaks_toolbar_control = true
  b:SetHeight(TOOLBAR_HEIGHT)
  b:EnableMouse(1)
  b:SetScript("OnClick", ToggleSearch)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
    GameTooltip:SetText("Search")
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function()
    if GameTooltip:IsOwned(this) then GameTooltip:Hide() end
  end)

  b:SetBackdrop({
    bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true,
    tileSize=16,
    edgeSize=8,
    insets={left=2,right=2,top=2,bottom=2},
  })
  b:SetBackdropColor(0, 0, 0, .85)
  b:SetBackdropBorderColor(.25, .25, .25, 1)

  state.searchButton = b
  EnsureLabel(b, "Search")
  EnsureActiveOverlay(b)
  return b
end

local function IsToolbarCandidate(child, bag)
  if not child or child == bag.close or child == state.searchButton then return false end
  if child.bagtweaks_toolbar_ignore or child.bagtweaks_header then return false end
  if not child.GetObjectType or child:GetObjectType() ~= "Button" then return false end
  if not child.GetName or not child:GetName() then return false end

  if child == bag.sort or child == bag.keys or child == bag.picklock or
     child == bag.disenchant or child == bag.open or child == bag.bags then
    return true
  end

  local h = child.GetHeight and child:GetHeight() or 0
  return h > 0 and h <= 24
end

local function DiscoverToolbarButtons(bag)
  local buttons = {}
  table.insert(buttons, EnsureSearchButton(bag))

  local children = { bag:GetChildren() }
  for i = 1, table.getn(children) do
    local child = children[i]
    if IsToolbarCandidate(child, bag) and child:IsShown() then
      if not child.bagtweaks_original_left and child.GetLeft then
        child.bagtweaks_original_left = child:GetLeft()
      end
      table.insert(buttons, child)
    end
  end

  table.sort(buttons, function(a, b)
    local ar = KnownRank(a, bag)
    local br = KnownRank(b, bag)
    if ar ~= 100 or br ~= 100 then
      if ar ~= br then return ar < br end
    end

    local al = a.bagtweaks_original_left or (a.GetLeft and a:GetLeft()) or 99999
    local bl = b.bagtweaks_original_left or (b.GetLeft and b:GetLeft()) or 99999
    if al ~= bl then return al < bl end

    local an = a.GetName and a:GetName() or ""
    local bn = b.GetName and b:GetName() or ""
    return an < bn
  end)

  return buttons
end

local function LayoutToolbar()
  local bag = pfUI.bag and pfUI.bag.right
  if not bag or not bag.close or not bag.GetWidth then return end

  local buttons = DiscoverToolbarButtons(bag)
  local count = table.getn(buttons)
  if count == 0 then return end

  local closeWidth = bag.close:GetWidth() or 12
  local width = bag:GetWidth() or 0
  local available = width - closeWidth - TOOLBAR_GAP * 2
  if available < count then return end

  local gaps = (count - 1) * TOOLBAR_GAP
  local base = math.floor((available - gaps) / count)
  local remainder = (available - gaps) - base * count
  local previous = nil

  for i = 1, count do
    local button = buttons[i]
    local buttonWidth = base
    if remainder > 0 then
      buttonWidth = buttonWidth + 1
      remainder = remainder - 1
    end

    button:ClearAllPoints()
    button:SetHeight(TOOLBAR_HEIGHT)
    button:SetWidth(buttonWidth)

    if previous then
      button:SetPoint("TOPLEFT", previous, "TOPRIGHT", TOOLBAR_GAP, 0)
    else
      button:SetPoint("TOPLEFT", bag, "TOPLEFT", 0, 0)
    end

    EnsureLabel(button, FriendlyLabel(button, bag))
    previous = button
  end

  ApplySearchState()
end

local function CancelTargeting()
  if SpellIsTargeting and SpellIsTargeting() and SpellStopTargeting then
    SpellStopTargeting()
  end
end

local function CastPersistentMode(mode)
  local bag = pfUI.bag and pfUI.bag.right
  if not bag then return false end

  local button = mode == "disenchant" and bag.disenchant or bag.picklock
  if not button or not button:IsShown() then return false end

  local id = button:GetID()
  if not id or id <= 0 then return false end

  -- brues-code stores real spell IDs; Shagu stores spellbook indices.
  if (mode == "disenchant" and id == 13262) or (mode == "picklock" and id == 1804) then
    if CastSpellByName then
      CastSpellByName(id)
      return true
    end
  elseif CastSpell then
    CastSpell(id, BOOKTYPE_SPELL)
    return true
  end

  return false
end

local function DisablePersistentMode()
  state.activeMode = nil
  state.wasTargeting = false
  state.awaitingCompletion = false
  state.rearmAt = nil
  CancelTargeting()
  UpdateActiveVisuals()
end

local function ActivatePersistentMode(mode, button, oldOnClick)
  if state.activeMode == mode then
    DisablePersistentMode()
    return
  end

  if state.activeMode then CancelTargeting() end

  state.activeMode = mode
  state.wasTargeting = false
  state.awaitingCompletion = false
  state.rearmAt = nil
  UpdateActiveVisuals()

  if oldOnClick then oldOnClick() end
  if SpellIsTargeting and SpellIsTargeting() then state.wasTargeting = true end
end

local function HookPersistentButton(button, mode)
  if not button or button.bagtweaks_persistent_hooked then return end

  local oldOnClick = button:GetScript("OnClick")
  button.bagtweaks_original_onclick = oldOnClick
  button:SetScript("OnClick", function()
    ActivatePersistentMode(mode, button, oldOnClick)
  end)
  button.bagtweaks_persistent_hooked = true
end

local function PlayerIsCasting()
  return CastingBarFrame and (CastingBarFrame.casting or CastingBarFrame.channeling)
end

local function UpdatePersistentMode(now)
  if not state.activeMode then return end

  local bag = pfUI.bag and pfUI.bag.right
  local button = bag and (state.activeMode == "disenchant" and bag.disenchant or bag.picklock)
  if not button or not button:IsShown() or (button:GetID() or 0) <= 0 then
    DisablePersistentMode()
    return
  end

  local targeting = SpellIsTargeting and SpellIsTargeting()
  if targeting then
    state.wasTargeting = true
    state.awaitingCompletion = false
    state.rearmAt = nil
    return
  end

  if state.wasTargeting then
    state.wasTargeting = false
    state.awaitingCompletion = true
    state.rearmAt = now + .75
  end

  if state.awaitingCompletion and state.rearmAt and now >= state.rearmAt and not PlayerIsCasting() then
    state.awaitingCompletion = false
    state.rearmAt = nil
    if CastPersistentMode(state.activeMode) then
      -- targeting normally becomes true on the following frame.
      state.rearmAt = now + .30
    end
  elseif not state.awaitingCompletion and state.rearmAt and now >= state.rearmAt then
    if SpellIsTargeting and SpellIsTargeting() then
      state.wasTargeting = true
      state.rearmAt = nil
    elseif not PlayerIsCasting() then
      -- Retry quietly if the first re-arm happened while another action was finishing.
      if CastPersistentMode(state.activeMode) then state.rearmAt = now + .30 end
    end
  end
end

local function OnSpellFinished()
  if not state.activeMode or not state.awaitingCompletion then return end
  state.rearmAt = GetTime() + .10
end

local function Setup()
  local bag = pfUI.bag and pfUI.bag.right
  if not bag or not bag.search or not bag.close then return false end

  EnsureSearchButton(bag)
  HookPersistentButton(bag.disenchant, "disenchant")
  HookPersistentButton(bag.picklock, "picklock")

  if not state.initialized then
    state.oldBagOnHide = bag:GetScript("OnHide")
    bag:SetScript("OnHide", function()
      if state.oldBagOnHide then state.oldBagOnHide() end
      state.searchOpen = false
      ApplySearchState()
    end)
    state.initialized = true
  end

  LayoutToolbar()
  return true
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("SPELLS_CHANGED")
watcher:RegisterEvent("SPELLCAST_STOP")
watcher:RegisterEvent("SPELLCAST_FAILED")
watcher:RegisterEvent("SPELLCAST_INTERRUPTED")

watcher:SetScript("OnEvent", function()
  if event == "SPELLCAST_STOP" or event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
    OnSpellFinished()
  end
  Setup()
end)

watcher:SetScript("OnUpdate", function()
  local now = GetTime()
  UpdatePersistentMode(now)

  if now - state.lastUpdate < UPDATE_INTERVAL then return end
  state.lastUpdate = now

  if Setup() and pfUI.bag.right:IsShown() then
    LayoutToolbar()
  end
end)

Setup()
