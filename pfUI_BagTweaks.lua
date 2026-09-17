-- pfUI_BagTweaks 0.1.13-dev-toolbar
-- User-defined visual groups for pfUI unified bags.
-- Groups can be account-wide or character-specific, may optionally collect Quest items,
-- can be arranged as one or two columns, and never move physical inventory slots.

if not pfUI then return end

local ADDON_NAME = "pfUI_BagTweaks"
local initialized = false

local function Initialize()
  if initialized then return end
  initialized = true

  pfUI.bagtweaks = pfUI.bagtweaks or {}

  if pfUI.UpdateConfig then
    pfUI:UpdateConfig("bagtweaks", nil, "show_search", "1")
  else
    pfUI_config = pfUI_config or {}
    pfUI_config.bagtweaks = pfUI_config.bagtweaks or {}
    if pfUI_config.bagtweaks.show_search == nil then
      pfUI_config.bagtweaks.show_search = "1"
    end
  end

  pfUI:RegisterModule("bagtweaks", "vanilla", function()
    if not pfUI.bag or not pfUI.bag.CreateBags or pfUI.bag.bagtweaks_hooked then return end

    local G = _G
    local HEADER_HEIGHT = 15
    local QUEST_CLASS_ID = 12
    local GENERAL_OVERRIDE = 0
    local MENU_WIDTH = 170
    local MENU_ROW_HEIGHT = 18
    local ROW_GAP = 3
    local INSERT_LINE_HEIGHT = 3

    local SORT_MODES = { "bag", "name", "value", "slot" }
    local SORT_LABEL = {
      bag = "Bag Order",
      name = "Name",
      value = "Vendor Value",
      slot = "Character Slot",
    }

    local SLOT_ORDER = {
      INVTYPE_HEAD=1,
      INVTYPE_NECK=2,
      INVTYPE_SHOULDER=3,
      INVTYPE_CLOAK=4,
      INVTYPE_CHEST=5,
      INVTYPE_ROBE=5,
      INVTYPE_BODY=6,
      INVTYPE_TABARD=7,
      INVTYPE_WRIST=8,
      INVTYPE_HAND=9,
      INVTYPE_WAIST=10,
      INVTYPE_LEGS=11,
      INVTYPE_FEET=12,
      INVTYPE_FINGER=13,
      INVTYPE_TRINKET=14,
      INVTYPE_WEAPONMAINHAND=15,
      INVTYPE_2HWEAPON=15,
      INVTYPE_WEAPON=15,
      INVTYPE_SHIELD=16,
      INVTYPE_HOLDABLE=16,
      INVTYPE_WEAPONOFFHAND=16,
      INVTYPE_RANGED=17,
      INVTYPE_RANGEDRIGHT=17,
      INVTYPE_THROWN=17,
      INVTYPE_RELIC=17,
      INVTYPE_BAG=18,
      INVTYPE_QUIVER=18,
      INVTYPE_AMMO=19,
    }

    local oldCreateBags = pfUI.bag.CreateBags
    local oldUpdateBag = pfUI.bag.UpdateBag

    local headers = {}
    local sections = {}
    local rowFrames = {}
    local selectedItemID = nil
    local itemHighlightSection = nil
    local nameDialog, deleteDialog, menu, sortMenu
    local dragPreview, dragInsertLine, dragWatcher
    local Relayout

    local draggingGroupID = nil
    local dragTargetID = nil
    local dragTargetSection = nil
    local dragIntent = nil
    local dragSide = nil
    local lastDragStop = 0

    G.pfUIBagTweaksDB = G.pfUIBagTweaksDB or {}
    local db = G.pfUIBagTweaksDB
    db.groups = db.groups or {}
    db.nextGroupID = tonumber(db.nextGroupID) or 1
    db.generalSort = db.generalSort or "bag"
    if db.generalReverse == nil then db.generalReverse = false end
    db.accountAssignments = db.accountAssignments or db.assignments or {}
    db.assignments = nil
    db.charAssignments = db.charAssignments or {}
    db.rows = db.rows or {}

    local function CharacterKey()
      local realm = GetRealmName and GetRealmName() or ""
      local name = UnitName and UnitName("player") or ""
      return tostring(realm or "") .. "\031" .. tostring(name or "")
    end

    local function CharAssignments(create)
      local key = CharacterKey()
      local tab = db.charAssignments[key]
      if not tab and create then
        tab = {}
        db.charAssignments[key] = tab
      end
      return tab
    end

    local function Trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      return string.gsub(s, "%s+$", "")
    end

    local function FindGroup(id)
      for i = 1, table.getn(db.groups) do
        if db.groups[i].id == id then return db.groups[i], i end
      end
    end

    local function GroupExists(id)
      return FindGroup(id) ~= nil
    end

    local function IsGroupActive(g)
      if not g then return false end
      if g.scope ~= "char" then return true end
      return g.owner == CharacterKey()
    end

    local function NormalizeRows()
      local clean = {}
      local seen = {}

      for r = 1, table.getn(db.rows) do
        local source = db.rows[r]
        local row = {}

        for c = 1, table.getn(source) do
          local id = tonumber(source[c])
          if id and GroupExists(id) and not seen[id] then
            table.insert(row, id)
            seen[id] = true
            if table.getn(row) == 2 then break end
          end
        end

        if table.getn(row) > 0 then table.insert(clean, row) end
      end

      for i = 1, table.getn(db.groups) do
        local id = db.groups[i].id
        if not seen[id] then
          table.insert(clean, { id })
          seen[id] = true
        end
      end

      db.rows = clean
    end

    for i = 1, table.getn(db.groups) do
      local g = db.groups[i]

      if not g.id then
        g.id = db.nextGroupID
        db.nextGroupID = db.nextGroupID + 1
      elseif g.id >= db.nextGroupID then
        db.nextGroupID = g.id + 1
      end

      g.name = g.name or ("Group " .. tostring(g.id))
      g.sort = g.sort or "bag"
      if g.reverse == nil then g.reverse = false end
      if g.scope == "character" then g.scope = "char" end
      if g.scope ~= "char" then g.scope = "account" end
      if g.scope == "char" and not g.owner then g.owner = CharacterKey() end

      if db.questGroupID and g.id == tonumber(db.questGroupID) then
        g.quest = true
      end
    end
    db.questGroupID = nil
    NormalizeRows()

    local function ActiveRows()
      local result = {}

      for r = 1, table.getn(db.rows) do
        local source = db.rows[r]
        local row = {}

        for c = 1, table.getn(source) do
          local g = FindGroup(source[c])
          if g and IsGroupActive(g) then table.insert(row, g.id) end
        end

        if table.getn(row) > 0 then table.insert(result, row) end
      end

      return result
    end

    local function CleanState()
      NormalizeRows()

      for itemID, groupID in pairs(db.accountAssignments) do
        if groupID ~= GENERAL_OVERRIDE and not GroupExists(groupID) then
          db.accountAssignments[itemID] = GENERAL_OVERRIDE
        end
      end

      for _, assignments in pairs(db.charAssignments) do
        for itemID, groupID in pairs(assignments) do
          if groupID ~= GENERAL_OVERRIDE and not GroupExists(groupID) then
            assignments[itemID] = GENERAL_OVERRIDE
          end
        end
      end
    end

    local function RemoveGroupFromRows(id)
      for r = table.getn(db.rows), 1, -1 do
        local row = db.rows[r]

        for c = table.getn(row), 1, -1 do
          if row[c] == id then table.remove(row, c) end
        end

        if table.getn(row) == 0 then table.remove(db.rows, r) end
      end
    end

    local function FindRowIndex(id)
      for r = 1, table.getn(db.rows) do
        local row = db.rows[r]
        for c = 1, table.getn(row) do
          if row[c] == id then return r, c end
        end
      end
    end

    local function ToggleScope(id, scope)
      local g = FindGroup(id)
      if not g then return end

      local ca = CharAssignments(true)

      if scope == "account" and g.scope == "char" then
        for itemID, groupID in pairs(ca) do
          if groupID == id then
            db.accountAssignments[itemID] = id
            ca[itemID] = nil
          end
        end

        g.scope = "account"
        g.owner = nil
      elseif scope == "char" and g.scope ~= "char" then
        for itemID, groupID in pairs(db.accountAssignments) do
          if groupID == id then
            if ca[itemID] == nil then ca[itemID] = id end
            db.accountAssignments[itemID] = nil
          end
        end

        g.scope = "char"
        g.owner = CharacterKey()
      end

      Relayout()
    end

    local function ToggleQuestGroup(id)
      local g = FindGroup(id)
      if not g or not IsGroupActive(g) then return end

      if g.quest then
        g.quest = false
      else
        for i = 1, table.getn(db.groups) do
          local other = db.groups[i]
          if IsGroupActive(other) then other.quest = false end
        end
        g.quest = true
      end

      Relayout()
    end

    local function SetSort(id, mode)
      if id == nil then
        db.generalSort = mode
      else
        local g = FindGroup(id)
        if not g then return end
        g.sort = mode
      end
      Relayout()
    end

    local function ToggleReverse(id)
      if id == nil then
        db.generalReverse = not db.generalReverse
      else
        local g = FindGroup(id)
        if not g then return end
        g.reverse = not g.reverse
      end
      Relayout()
    end

    local function GetSort(id)
      if id == nil then return db.generalSort or "bag", db.generalReverse end
      local g = FindGroup(id)
      return g and (g.sort or "bag") or "bag", g and g.reverse or false
    end

    local function ItemID(bag, slot)
      if G.C_Container and type(G.C_Container.GetContainerItemID) == "function" then
        local id = G.C_Container.GetContainerItemID(bag, slot)
        if id then return tonumber(id) end
      end

      local link = GetContainerItemLink(bag, slot)
      if not link then return nil end
      local _, _, id = string.find(link, "item:(%d+)")
      return tonumber(id)
    end

    local function NameFromLink(link)
      if not link then return "" end
      local _, _, name = string.find(link, "%[([^%]]+)%]")
      return string.lower(name or "")
    end

    local function InstantInfo(id)
      if not id or not G.C_Item or type(G.C_Item.GetItemInfoInstant) ~= "function" then
        return nil, nil, nil
      end

      local _, itemType, _, equipLoc, _, classID = G.C_Item.GetItemInfoInstant(id)
      return itemType, equipLoc, tonumber(classID)
    end

    local function FullInfo(id, link)
      local name, itemType, equipLoc, classID

      if id and G.C_Item and type(G.C_Item.GetItemInfo) == "function" then
        local n, _, _, _, _, t, _, _, e, _, _, c = G.C_Item.GetItemInfo(id)
        name, itemType, equipLoc, classID = n, t, e, tonumber(c)
      end

      if not name or not itemType or not equipLoc or equipLoc == "" then
        local n, _, _, _, _, t, _, _, e = GetItemInfo(link or id)
        name = name or n
        itemType = itemType or t
        if not equipLoc or equipLoc == "" then equipLoc = e end
      end

      return name, itemType, equipLoc, classID
    end

    local function SortMetadata(bag, slot, id)
      local link = GetContainerItemLink(bag, slot)
      local name = NameFromLink(link)
      local itemType, equipLoc, classID = InstantInfo(id)

      if id and (name == "" or not equipLoc or equipLoc == "" or classID == nil) then
        local fullName, fullType, fullEquipLoc, fullClassID = FullInfo(id, link)
        if name == "" then name = string.lower(fullName or "") end
        itemType = itemType or fullType
        if not equipLoc or equipLoc == "" then equipLoc = fullEquipLoc or "" end
        classID = classID or fullClassID
      end

      local value = nil
      if id and G.C_Item and type(G.C_Item.GetItemInfo) == "function" then
        local _, _, _, _, _, _, _, _, _, _, sellPrice = G.C_Item.GetItemInfo(id)
        if sellPrice ~= nil then value = tonumber(sellPrice) end
      end
      if value == nil and type(G.GetSellValue) == "function" then
        local ok, v = pcall(G.GetSellValue, link or id)
        if ok and v ~= nil then value = tonumber(v) end
      end
      if value == nil and type(G.GetItemSellPrice) == "function" and id then
        local ok, v = pcall(G.GetItemSellPrice, id)
        if ok and v ~= nil then value = tonumber(v) end
      end

      return {
        name = name or "",
        rank = SLOT_ORDER[equipLoc or ""] or 999,
        equipLoc = equipLoc or "",
        itemType = itemType,
        classID = classID,
        value = value,
      }
    end

    local function IsQuestMetadata(meta)
      if not meta then return false end
      if meta.classID ~= nil then return meta.classID == QUEST_CLASS_ID end
      if G.ITEM_CLASS_QUESTITEM and meta.itemType == G.ITEM_CLASS_QUESTITEM then return true end
      if G.ITEM_CLASS_QUEST and meta.itemType == G.ITEM_CLASS_QUEST then return true end
      return meta.itemType == "Quest"
    end

    local function EntryLess(a, b, mode, reverse)
      local av, bv

      if mode == "bag" then
        av, bv = a.ordinal, b.ordinal
      else
        if a.itemID and not b.itemID then return true end
        if not a.itemID and b.itemID then return false end
        if not a.itemID and not b.itemID then
          if reverse then return a.ordinal > b.ordinal end
          return a.ordinal < b.ordinal
        end

        if mode == "name" then
          av, bv = a.meta.name, b.meta.name
        elseif mode == "value" then
          if a.meta.value == nil and b.meta.value ~= nil then return false end
          if a.meta.value ~= nil and b.meta.value == nil then return true end
          av, bv = a.meta.value or 0, b.meta.value or 0
        elseif mode == "slot" then
          av, bv = a.meta.rank, b.meta.rank
        else
          av, bv = a.ordinal, b.ordinal
        end
      end

      if av ~= bv then
        if reverse then return av > bv end
        return av < bv
      end

      if mode ~= "name" and a.meta.name ~= b.meta.name then
        if reverse then return a.meta.name > b.meta.name end
        return a.meta.name < b.meta.name
      end

      return a.ordinal < b.ordinal
    end

    local function SortEntries(entries, mode, reverse)
      if table.getn(entries) < 2 then return end
      table.sort(entries, function(a, b)
        return EntryLess(a, b, mode or "bag", reverse and true or false)
      end)
    end

    local function Backdrop(frame)
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true,
        tileSize=16,
        edgeSize=16,
        insets={left=4,right=4,top=4,bottom=4},
      })
      frame:SetBackdropColor(0, 0, 0, .95)
    end

    local function Tooltip(title, line)
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(title)
      if line then GameTooltip:AddLine(line, 1, 1, 1) end
      GameTooltip:Show()
    end

    local function HideMenus()
      if menu then
        menu:Hide()
        menu.anchor = nil
      end
      if sortMenu then sortMenu:Hide() end
    end

    local function HideItemHighlight()
      if itemHighlightSection and itemHighlightSection.itemHighlight then
        itemHighlightSection.itemHighlight:Hide()
      end
      itemHighlightSection = nil
    end

    local function ShowItemHighlight(section)
      if not section or draggingGroupID then return end
      if not selectedItemID then return end
      if type(CursorHasItem) == "function" and not CursorHasItem() then return end

      if itemHighlightSection ~= section then
        HideItemHighlight()
        itemHighlightSection = section
      end
      if section.itemHighlight then section.itemHighlight:Show() end
    end

    local function HideDragVisuals()
      if dragPreview then dragPreview:Hide() end
      if dragInsertLine then dragInsertLine:Hide() end
    end

    local function EnsureDragVisuals()
      local baseLevel = pfUI.bag.right:GetFrameLevel() or 0

      if not dragPreview then
        dragPreview = CreateFrame("Frame", nil, pfUI.bag.right)
        dragPreview:EnableMouse(false)
        dragPreview.texture = dragPreview:CreateTexture(nil, "BACKGROUND")
        dragPreview.texture:SetAllPoints(dragPreview)
        dragPreview.texture:SetTexture(1, 1, 1, 1)
        dragPreview.texture:SetVertexColor(.15, 1, .15, .20)
        dragPreview:Hide()
      end
      dragPreview:SetFrameLevel(baseLevel + 2)

      if not dragInsertLine then
        dragInsertLine = CreateFrame("Frame", nil, pfUI.bag.right)
        dragInsertLine:EnableMouse(false)
        dragInsertLine.texture = dragInsertLine:CreateTexture(nil, "ARTWORK")
        dragInsertLine.texture:SetAllPoints(dragInsertLine)
        dragInsertLine.texture:SetTexture(1, 1, 1, 1)
        dragInsertLine.texture:SetVertexColor(.15, 1, .15, .95)
        dragInsertLine:SetHeight(INSERT_LINE_HEIGHT)
        dragInsertLine:Hide()
      end
      dragInsertLine:SetFrameLevel(baseLevel + 6)
    end

    local function ShowNameDialog(groupID)
      if not nameDialog then
        local f = CreateFrame("Frame", "pfBagTweaksGroupEditor", UIParent)
        f:SetWidth(250)
        f:SetHeight(86)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(1)
        Backdrop(f)

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)

        f.edit = CreateFrame("EditBox", "pfBagTweaksGroupNameEdit", f, "InputBoxTemplate")
        f.edit:SetWidth(226)
        f.edit:SetHeight(20)
        f.edit:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
        f.edit:SetAutoFocus(false)

        f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.ok:SetWidth(70)
        f.ok:SetHeight(20)
        f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 8)
        f.ok:SetText("OK")

        f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.cancel:SetWidth(70)
        f.cancel:SetHeight(20)
        f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 8)
        f.cancel:SetText("Cancel")

        local function Accept()
          local name = Trim(f.edit:GetText())
          if name == "" then return end

          if f.groupID then
            local g = FindGroup(f.groupID)
            if g then g.name = name end
          else
            local id = db.nextGroupID
            table.insert(db.groups, {
              id=id,
              name=name,
              sort="bag",
              reverse=false,
              scope="account",
              quest=false,
            })
            table.insert(db.rows, { id })
            db.nextGroupID = id + 1
          end

          f:Hide()
          Relayout()
        end

        f.ok:SetScript("OnClick", Accept)
        f.cancel:SetScript("OnClick", function() f:Hide() end)
        f.edit:SetScript("OnEnterPressed", Accept)
        f.edit:SetScript("OnEscapePressed", function() f:Hide() end)
        f:Hide()
        nameDialog = f
      end

      nameDialog.groupID = groupID

      if groupID then
        local g = FindGroup(groupID)
        if not g then return end
        nameDialog.title:SetText("Rename Category")
        nameDialog.edit:SetText(g.name)
      else
        nameDialog.title:SetText("New Category")
        nameDialog.edit:SetText("")
      end

      nameDialog:Show()
      nameDialog.edit:SetFocus()
      nameDialog.edit:HighlightText()
    end

    local function DeleteGroup(groupID)
      local g, index = FindGroup(groupID)
      if not g or not index then return end

      if g.scope == "char" then
        local ca = CharAssignments(true)
        for itemID, assigned in pairs(ca) do
          if assigned == groupID then ca[itemID] = GENERAL_OVERRIDE end
        end
      else
        for itemID, assigned in pairs(db.accountAssignments) do
          if assigned == groupID then db.accountAssignments[itemID] = GENERAL_OVERRIDE end
        end
      end

      for _, assignments in pairs(db.charAssignments) do
        for itemID, assigned in pairs(assignments) do
          if assigned == groupID then assignments[itemID] = GENERAL_OVERRIDE end
        end
      end

      RemoveGroupFromRows(groupID)
      table.remove(db.groups, index)
      NormalizeRows()
      Relayout()
    end

    local function ShowDeleteDialog(groupID)
      local g = FindGroup(groupID)
      if not g then return end

      if not deleteDialog then
        local f = CreateFrame("Frame", "pfBagTweaksDeleteConfirm", UIParent)
        f:SetWidth(270)
        f:SetHeight(86)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(1)
        Backdrop(f)

        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.text:SetPoint("TOP", f, "TOP", 0, -16)
        f.text:SetWidth(246)
        f.text:SetJustifyH("CENTER")

        f.ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.ok:SetWidth(80)
        f.ok:SetHeight(20)
        f.ok:SetPoint("BOTTOMRIGHT", f, "BOTTOM", -4, 8)
        f.ok:SetText("Delete")

        f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.cancel:SetWidth(80)
        f.cancel:SetHeight(20)
        f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 8)
        f.cancel:SetText("Cancel")

        f.ok:SetScript("OnClick", function()
          local id = f.groupID
          f:Hide()
          DeleteGroup(id)
        end)

        f.cancel:SetScript("OnClick", function() f:Hide() end)
        f:Hide()
        deleteDialog = f
      end

      deleteDialog.groupID = groupID
      deleteDialog.text:SetText('Delete "' .. tostring(g.name) .. '"? Items return to General.')
      deleteDialog:Show()
    end

    local function CursorStillHasItem()
      if type(CursorHasItem) ~= "function" then return true end
      return CursorHasItem() and true or false
    end

    local function AssignSelected(groupID)
      if not selectedItemID then return false end

      if not CursorStillHasItem() then
        selectedItemID = nil
        HideItemHighlight()
        return false
      end

      local itemKey = tostring(selectedItemID)
      local ca = CharAssignments(true)

      if groupID == nil then
        if ca[itemKey] ~= nil then
          ca[itemKey] = GENERAL_OVERRIDE
        elseif db.accountAssignments[itemKey] ~= nil then
          db.accountAssignments[itemKey] = GENERAL_OVERRIDE
        else
          ca[itemKey] = GENERAL_OVERRIDE
        end
      else
        local g = FindGroup(groupID)
        if not g or not IsGroupActive(g) then return false end

        if g.scope == "char" then
          ca[itemKey] = groupID
        else
          db.accountAssignments[itemKey] = groupID
          ca[itemKey] = nil
        end
      end

      if type(ClearCursor) == "function" then ClearCursor() end
      selectedItemID = nil
      HideItemHighlight()
      Relayout()
      return true
    end

    local function MenuButton(parent, index)
      parent.buttons = parent.buttons or {}

      if not parent.buttons[index] then
        local b = CreateFrame("Button", nil, parent)
        b:SetHeight(MENU_ROW_HEIGHT)
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -(4 + (index - 1) * MENU_ROW_HEIGHT))
        b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -(4 + (index - 1) * MENU_ROW_HEIGHT))
        b:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
        b:SetTextColor(1, 1, 1, 1)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        b:GetHighlightTexture():SetAlpha(.25)
        b:SetText("")
        parent.buttons[index] = b
      end

      return parent.buttons[index]
    end

    local function ConfigureMenuFrame(frame, rows)
      frame:SetWidth(MENU_WIDTH)
      frame:SetHeight(rows * MENU_ROW_HEIGHT + 8)
      frame:SetFrameStrata("DIALOG")
      frame:EnableMouse(1)
      Backdrop(frame)
    end

    local function ShowSortMenu(anchor, groupID)
      if not sortMenu then
        sortMenu = CreateFrame("Frame", "pfBagTweaksSortMenu", UIParent)
        sortMenu:Hide()
      end

      ConfigureMenuFrame(sortMenu, 5)
      sortMenu.groupID = groupID
      sortMenu:ClearAllPoints()
      sortMenu:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -2, 0)

      local current, reverse = GetSort(groupID)

      for i = 1, table.getn(SORT_MODES) do
        local b = MenuButton(sortMenu, i)
        b.sortMode = SORT_MODES[i]
        b:SetText((current == b.sortMode and "[x] " or "[ ] ") .. SORT_LABEL[b.sortMode])
        b:SetScript("OnClick", function()
          local mode = this.sortMode
          SetSort(sortMenu.groupID, mode)
          HideMenus()
        end)
        b:Show()
      end

      local reverseButton = MenuButton(sortMenu, 5)
      reverseButton.sortMode = nil
      reverseButton:SetText((reverse and "[x] " or "[ ] ") .. "Reverse")
      reverseButton:SetScript("OnClick", function()
        ToggleReverse(sortMenu.groupID)
        HideMenus()
      end)
      reverseButton:Show()

      sortMenu:Show()
    end

    local function ShowGroupMenu(anchor, groupID)
      if not menu then
        menu = CreateFrame("Frame", "pfBagTweaksGroupMenu", UIParent)
        menu:Hide()
      end

      menu.groupID = groupID
      menu.anchor = anchor
      menu:ClearAllPoints()
      menu:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -2, 0)

      if groupID == nil then
        ConfigureMenuFrame(menu, 2)

        local add = MenuButton(menu, 1)
        add:SetText("New Category")
        add:SetScript("OnClick", function()
          HideMenus()
          ShowNameDialog(nil)
        end)
        add:Show()

        local sorting = MenuButton(menu, 2)
        local mode = GetSort(nil)
        sorting:SetText("Sorting: " .. SORT_LABEL[mode] .. "  >")
        sorting:SetScript("OnClick", function()
          ShowSortMenu(menu, nil)
        end)
        sorting:Show()

        for i = 3, table.getn(menu.buttons or {}) do menu.buttons[i]:Hide() end
      else
        local g = FindGroup(groupID)
        if not g then return end

        ConfigureMenuFrame(menu, 6)

        local rename = MenuButton(menu, 1)
        rename:SetText("Rename Category")
        rename:SetScript("OnClick", function()
          local id = menu.groupID
          HideMenus()
          ShowNameDialog(id)
        end)
        rename:Show()

        local account = MenuButton(menu, 2)
        account:SetText((g.scope ~= "char" and "[x] " or "[ ] ") .. "Account Wide")
        account:SetScript("OnClick", function()
          local id = menu.groupID
          HideMenus()
          ToggleScope(id, "account")
        end)
        account:Show()

        local character = MenuButton(menu, 3)
        character:SetText((g.scope == "char" and "[x] " or "[ ] ") .. "Per Character")
        character:SetScript("OnClick", function()
          local id = menu.groupID
          HideMenus()
          ToggleScope(id, "char")
        end)
        character:Show()

        local quest = MenuButton(menu, 4)
        quest:SetText((g.quest and "[x] " or "[ ] ") .. "Quest Items")
        quest:SetScript("OnClick", function()
          local id = menu.groupID
          HideMenus()
          ToggleQuestGroup(id)
        end)
        quest:Show()

        local sorting = MenuButton(menu, 5)
        sorting:SetText("Sorting: " .. SORT_LABEL[g.sort or "bag"] .. "  >")
        sorting:SetScript("OnClick", function()
          ShowSortMenu(menu, menu.groupID)
        end)
        sorting:Show()

        local delete = MenuButton(menu, 6)
        delete:SetText("|cffff6666Delete Category|r")
        delete:SetScript("OnClick", function()
          local id = menu.groupID
          HideMenus()
          ShowDeleteDialog(id)
        end)
        delete:Show()

        for i = 7, table.getn(menu.buttons or {}) do menu.buttons[i]:Hide() end
      end

      if sortMenu then sortMenu:Hide() end
      menu:Show()
    end

    local function CursorPositionFor(frame)
      if not frame or not frame.GetLeft then return nil, nil end

      local x, y = GetCursorPosition()
      local scale = frame:GetEffectiveScale() or 1
      x = x / scale
      y = y / scale

      local left = frame:GetLeft()
      local right = frame:GetRight()
      local top = frame:GetTop()
      local bottom = frame:GetBottom()

      if not left or not right or not top or not bottom then return nil, nil end
      if right == left or top == bottom then return nil, nil end
      if x < left or x > right or y < bottom or y > top then return nil, nil end

      return (x - left) / (right - left), (y - bottom) / (top - bottom)
    end

    local function SectionKeyForGroupID(id)
      if id == nil or id == "general" then return "general" end
      return id
    end

    local function FindDragTargetUnderCursor()
      for _, s in pairs(sections) do
        if s:IsShown() then
          local rx, ry = CursorPositionFor(s)
          if rx and ry then
            local id = s.groupID or "general"
            if id ~= draggingGroupID then return id, s, rx, ry end
          end
        end
      end
      return nil, nil, nil, nil
    end

    local function RowForSection(section)
      if not section then return nil end
      return section.bagtweaks_rowFrame or section
    end

    local function ShowInsertLine(section, before)
      EnsureDragVisuals()
      dragPreview:Hide()

      local row = RowForSection(section)
      if not row then
        dragInsertLine:Hide()
        return
      end

      dragInsertLine:ClearAllPoints()
      if before then
        dragInsertLine:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 0)
        dragInsertLine:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, 0)
      else
        dragInsertLine:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
        dragInsertLine:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 0)
      end
      dragInsertLine:Show()
    end

    local function ShowPairPreview(section, side)
      EnsureDragVisuals()
      dragInsertLine:Hide()

      local row = RowForSection(section)
      if not row then
        dragPreview:Hide()
        return
      end

      dragPreview:ClearAllPoints()
      if side == "left" then
        dragPreview:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        dragPreview:SetPoint("BOTTOMRIGHT", row, "BOTTOM", -1, 0)
      else
        dragPreview:SetPoint("TOPLEFT", row, "TOP", 1, 0)
        dragPreview:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
      end
      dragPreview:Show()
    end

    local function DetermineDragIntent(targetID, section, rx, ry)
      if not targetID or not section then return nil, nil end
      if targetID == "general" then return "before", nil end

      local targetRow = FindRowIndex(targetID)
      if not targetRow then return nil, nil end

      local sourceRow = FindRowIndex(draggingGroupID)
      local sameRow = sourceRow and sourceRow == targetRow
      local row = db.rows[targetRow]
      local rowCount = table.getn(row)

      if rowCount == 1 then
        if ry > .75 then return "before", nil end
        if ry < .25 then return "after", nil end
        if rx < .5 then return "pair", "left" end
        return "pair", "right"
      end

      if sameRow then
        if ry > .75 then return "before", nil end
        if ry < .25 then return "after", nil end
        if rx < .5 then return "pair", "left" end
        return "pair", "right"
      end

      if ry >= .5 then return "before", nil end
      return "after", nil
    end

    local function UpdateDragVisual()
      if not draggingGroupID then
        dragTargetID = nil
        dragTargetSection = nil
        dragIntent = nil
        dragSide = nil
        HideDragVisuals()
        return
      end

      local targetID, section, rx, ry = FindDragTargetUnderCursor()
      if not targetID then
        dragTargetID = nil
        dragTargetSection = nil
        dragIntent = nil
        dragSide = nil
        HideDragVisuals()
        return
      end

      local intent, side = DetermineDragIntent(targetID, section, rx, ry)
      dragTargetID = targetID
      dragTargetSection = section
      dragIntent = intent
      dragSide = side

      if intent == "pair" then
        ShowPairPreview(section, side)
      elseif intent == "before" then
        ShowInsertLine(section, true)
      elseif intent == "after" then
        ShowInsertLine(section, false)
      else
        HideDragVisuals()
      end
    end

    local function PlaceDraggedGroup(sourceID, targetID, intent, side)
      if not sourceID or not targetID or not intent then return end

      if targetID == "general" then
        RemoveGroupFromRows(sourceID)
        table.insert(db.rows, { sourceID })
        NormalizeRows()
        Relayout()
        return
      end

      if sourceID == targetID or not GroupExists(targetID) then return end

      local sourceRowBefore = FindRowIndex(sourceID)
      local targetRowBefore = FindRowIndex(targetID)
      if not targetRowBefore then return end

      if intent == "pair" and sourceRowBefore and sourceRowBefore == targetRowBefore then
        local row = db.rows[targetRowBefore]
        if table.getn(row) == 2 then
          local otherID = row[1] == sourceID and row[2] or row[1]
          if side == "left" then
            row[1], row[2] = sourceID, otherID
          else
            row[1], row[2] = otherID, sourceID
          end
          NormalizeRows()
          Relayout()
          return
        end
      end

      RemoveGroupFromRows(sourceID)

      local targetRow = FindRowIndex(targetID)
      if not targetRow then
        table.insert(db.rows, { sourceID })
        NormalizeRows()
        Relayout()
        return
      end

      if intent == "before" then
        table.insert(db.rows, targetRow, { sourceID })
      elseif intent == "after" then
        table.insert(db.rows, targetRow + 1, { sourceID })
      elseif intent == "pair" then
        local row = db.rows[targetRow]
        if table.getn(row) == 1 then
          if side == "left" then table.insert(row, 1, sourceID)
          else table.insert(row, sourceID) end
        else
          if side == "left" then table.insert(db.rows, targetRow, { sourceID })
          else table.insert(db.rows, targetRow + 1, { sourceID }) end
        end
      end

      NormalizeRows()
      Relayout()
    end

    local function BeginGroupDrag(id)
      if selectedItemID and CursorStillHasItem() then return end
      if not id then return end

      draggingGroupID = id
      dragTargetID = nil
      dragTargetSection = nil
      dragIntent = nil
      dragSide = nil
      HideItemHighlight()
      HideMenus()
      EnsureDragVisuals()

      if not dragWatcher then
        dragWatcher = CreateFrame("Frame")
        dragWatcher:SetScript("OnUpdate", function()
          if draggingGroupID then UpdateDragVisual() end
        end)
      end
    end

    local function EndGroupDrag()
      if not draggingGroupID then return end

      UpdateDragVisual()

      local source = draggingGroupID
      local target = dragTargetID
      local intent = dragIntent
      local side = dragSide

      draggingGroupID = nil
      dragTargetID = nil
      dragTargetSection = nil
      dragIntent = nil
      dragSide = nil
      lastDragStop = GetTime and GetTime() or 0
      HideDragVisuals()

      if target and intent then PlaceDraggedGroup(source, target, intent, side) end
    end

    local function Header(key, name, groupID)
      local h = headers[key]

      if not h then
        h = CreateFrame("Button", nil, pfUI.bag.right)
        h:SetHeight(HEADER_HEIGHT)
        h:EnableMouse(1)
        h:RegisterForDrag("LeftButton")

        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
        h.text:SetPoint("LEFT", h, "LEFT", 2, 0)
        h.text:SetPoint("RIGHT", h, "RIGHT", -2, 0)
        h.text:SetJustifyH("LEFT")

        h.line = h:CreateTexture(nil, "ARTWORK")
        h.line:SetTexture(1, 1, 1, 1)
        h.line:SetVertexColor(.25, .25, .25, 1)
        h.line:SetHeight(1)
        h.line:SetPoint("BOTTOMLEFT", h)
        h.line:SetPoint("BOTTOMRIGHT", h)

        h:SetScript("OnDragStart", function()
          if h.groupID then BeginGroupDrag(h.groupID) end
        end)

        h:SetScript("OnDragStop", function()
          EndGroupDrag()
        end)

        h:SetScript("OnMouseUp", function()
          if arg1 ~= "LeftButton" and arg1 ~= "RightButton" then return end
          if AssignSelected(h.groupID) then return end
          if GetTime and lastDragStop > 0 and (GetTime() - lastDragStop) < .15 then return end

          if arg1 == "RightButton" and menu and menu:IsShown() and menu.anchor == h then
            HideMenus()
            return
          end

          ShowGroupMenu(h, h.groupID)
        end)

        h:SetScript("OnReceiveDrag", function()
          if not draggingGroupID then AssignSelected(h.groupID) end
        end)

        h:SetScript("OnEnter", function()
          if draggingGroupID then return end

          local section = sections[SectionKeyForGroupID(h.groupID)]
          if selectedItemID and CursorStillHasItem() then
            ShowItemHighlight(section)
            return
          end

          if h.groupID then
            local g = FindGroup(h.groupID)
            local mode = g and SORT_LABEL[g.sort or "bag"] or ""
            local scope = g and g.scope == "char" and "Per Character" or "Account Wide"
            local quest = g and g.quest and " - Quest Items" or ""
            Tooltip(h.text:GetText(), scope .. quest .. " - " .. mode .. " - click menu / drag header")
          else
            Tooltip("General", "Click for category/sorting menu")
          end
        end)

        h:SetScript("OnLeave", function()
          HideItemHighlight()
          GameTooltip:Hide()
        end)

        headers[key] = h
      end

      h.groupID = groupID
      h.text:SetText(name)
      h:Show()
      return h
    end

    local function Section(key, groupID)
      local s = sections[key]

      if not s then
        s = CreateFrame("Frame", nil, pfUI.bag.right)
        s:EnableMouse(1)

        s.itemHighlight = s:CreateTexture(nil, "BACKGROUND")
        s.itemHighlight:SetAllPoints(s)
        s.itemHighlight:SetTexture(1, 1, 1, 1)
        s.itemHighlight:SetVertexColor(.15, 1, .15, .16)
        s.itemHighlight:Hide()

        s:SetScript("OnReceiveDrag", function()
          if not draggingGroupID then AssignSelected(s.groupID) end
        end)

        s:SetScript("OnMouseUp", function()
          if arg1 == "LeftButton" and not draggingGroupID then AssignSelected(s.groupID) end
        end)

        s:SetScript("OnEnter", function()
          if draggingGroupID then return end
          if selectedItemID and CursorStillHasItem() then
            ShowItemHighlight(s)
            if s.groupID then
              Tooltip("Add to Category", "Release/click to classify the selected item here")
            else
              Tooltip("Move to General", "Release/click to keep the selected item in General")
            end
          end
        end)

        s:SetScript("OnLeave", function()
          if itemHighlightSection == s then HideItemHighlight() end
          GameTooltip:Hide()
        end)

        sections[key] = s
      end

      s.groupID = groupID
      s:Show()
      return s
    end

    local function ActiveQuestGroupID()
      local accountQuest = nil

      for i = 1, table.getn(db.groups) do
        local g = db.groups[i]
        if IsGroupActive(g) and g.quest then
          if g.scope == "char" then return g.id end
          accountQuest = g.id
        end
      end

      return accountQuest
    end

    local function EffectiveManualAssignment(itemKey)
      local ca = CharAssignments(false)
      if ca and ca[itemKey] ~= nil then return ca[itemKey] end
      return db.accountAssignments[itemKey]
    end

    local function Collect()
      local general = {}
      local grouped = {}
      local questGroupID = ActiveQuestGroupID()
      local ordinal = 0

      for i = 1, table.getn(db.groups) do
        local g = db.groups[i]
        if IsGroupActive(g) then grouped[g.id] = {} end
      end

      for i = 1, table.getn(pfUI.BACKPACK) do
        local bag = pfUI.BACKPACK[i]
        local count = GetContainerNumSlots(bag)
        if bag == -2 and pfUI.bag.showKeyring == true then count = GetKeyRingSize() end

        for slot = 1, count do
          local data = pfUI.bags[bag] and pfUI.bags[bag].slots[slot]
          local frame = data and data.frame

          if frame then
            ordinal = ordinal + 1
            local id = ItemID(bag, slot)
            local meta

            if id then
              meta = SortMetadata(bag, slot, id)
            else
              meta = {
                name="",
                rank=999,
                equipLoc="",
                itemType=nil,
                classID=nil,
                value=nil,
              }
            end

            local entry = {
              bag=bag,
              slot=slot,
              frame=frame,
              itemID=id,
              meta=meta,
              ordinal=ordinal,
            }

            local groupID = nil

            if id then
              local manual = EffectiveManualAssignment(tostring(id))

              if manual ~= nil then
                if manual ~= GENERAL_OVERRIDE and grouped[manual] then groupID = manual end
              elseif questGroupID and grouped[questGroupID] and IsQuestMetadata(meta) then
                groupID = questGroupID
              end
            end

            if groupID then table.insert(grouped[groupID], entry)
            else table.insert(general, entry) end
          end
        end
      end

      return general, grouped
    end

    local function HookItemSelection()
      for i = 1, table.getn(pfUI.BACKPACK) do
        local bag = pfUI.BACKPACK[i]
        local count = GetContainerNumSlots(bag)
        if bag == -2 and pfUI.bag.showKeyring == true then count = GetKeyRingSize() end

        for slot = 1, count do
          local data = pfUI.bags[bag] and pfUI.bags[bag].slots[slot]
          local frame = data and data.frame

          if frame and not frame.bagtweaks_select_hooked then
            local oldMouseDown = frame:GetScript("OnMouseDown")
            local oldDragStart = frame:GetScript("OnDragStart")
            local b, s = bag, slot

            frame:SetScript("OnMouseDown", function()
              if arg1 == "LeftButton" then selectedItemID = ItemID(b, s) end
              if oldMouseDown then oldMouseDown() end
            end)

            frame:SetScript("OnDragStart", function()
              selectedItemID = ItemID(b, s)
              if oldDragStart then oldDragStart() else PickupContainerItem(b, s) end
            end)

            frame.bagtweaks_select_hooked = true
          end
        end
      end
    end

    local function RowsFor(list, columns)
      local n = table.getn(list)
      if n == 0 then return 0 end
      return math.floor((n - 1) / columns) + 1
    end

    local function LayoutSection(key, name, groupID, list, columns, size, border)
      if columns < 1 then columns = 1 end

      local spacing = border * 3
      local pitch = size + spacing
      local rows = RowsFor(list, columns)
      local wantedHeight = HEADER_HEIGHT + border + rows * pitch + border
      local s = Section(key, groupID)
      local h = Header(key, name, groupID)
      local baseLevel = pfUI.bag.right:GetFrameLevel() or 0

      s:SetFrameLevel(baseLevel + 1)
      h:SetFrameLevel(baseLevel + 4)

      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", s, "TOPLEFT", border, 0)
      h:SetPoint("TOPRIGHT", s, "TOPRIGHT", -border, 0)

      local row, col = 0, 0

      for i = 1, table.getn(list) do
        local f = list[i].frame
        f:SetFrameLevel(baseLevel + 3)
        f:ClearAllPoints()
        f:SetPoint(
          "TOPLEFT",
          s,
          "TOPLEFT",
          border + col * pitch,
          -(HEADER_HEIGHT + border + row * pitch)
        )
        f:SetWidth(size)
        f:SetHeight(size)

        col = col + 1
        if col >= columns then
          col = 0
          row = row + 1
        end
      end

      return s, wantedHeight
    end

    local function RowFrame(index)
      if not rowFrames[index] then rowFrames[index] = CreateFrame("Frame", nil, pfUI.bag.right) end
      rowFrames[index]:Show()
      return rowFrames[index]
    end

    local function ApplyHeaderOptions()
      local frame = pfUI.bag.right
      if frame and frame.search then
        if C.bagtweaks and C.bagtweaks.show_search == "0" then frame.search:Hide()
        else frame.search:Show() end
      end
    end
    pfUI.bagtweaks.ApplyHeaderOptions = ApplyHeaderOptions

    local function StabilizeBottomAnchor(frame)
      if C.appearance.bags.movable == "1" then return end
      if not frame.GetNumPoints or not frame.GetPoint then return end
      if frame:GetNumPoints() < 2 then return end

      local point, relativeTo, relativePoint, x, y

      for i = 1, frame:GetNumPoints() do
        local p, r, rp, ox, oy = frame:GetPoint(i)
        if p and string.find(p, "BOTTOM") then
          point, relativeTo, relativePoint, x, y = p, r, rp, ox, oy
          break
        end
      end

      if point then
        frame:ClearAllPoints()
        frame:SetPoint(point, relativeTo, relativePoint, x, y)
      end
    end

    Relayout = function()
      local frame = pfUI.bag.right
      if not frame or not frame.button_size or not frame.close or not pfUI.BACKPACK or not pfUI.bags then return end

      ApplyHeaderOptions()
      HookItemSelection()
      CleanState()
      StabilizeBottomAnchor(frame)

      local _, border = GetBorderSize("bags")
      border = border or 1

      local fullColumns = tonumber(C.appearance.bags.bagrowlength) or 10
      if fullColumns < 1 then fullColumns = 1 end
      local halfColumns = math.floor(fullColumns / 2)
      if halfColumns < 1 then halfColumns = 1 end

      local size = frame.button_size
      local topSpace = frame.close:GetHeight() + border * 2
      local bottomSpace = pfUI.panel and pfUI.panel.right:IsShown()
        and pfUI.panel.right:GetHeight() + border
        or 16 + border

      local general, grouped = Collect()
      local active = {}
      local totalHeight = 0

      SortEntries(general, db.generalSort, db.generalReverse)

      local generalSection, generalHeight = LayoutSection(
        "general", "General", nil, general, fullColumns, size, border
      )

      active["general"] = true
      totalHeight = totalHeight + generalHeight

      generalSection:ClearAllPoints()
      generalSection:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, bottomSpace)
      generalSection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomSpace)
      generalSection:SetHeight(generalHeight)
      generalSection.bagtweaks_rowFrame = generalSection

      local below = generalSection
      local activeRows = ActiveRows()
      local visibleRowCount = table.getn(activeRows)
      local rowFrameIndex = 0

      for r = visibleRowCount, 1, -1 do
        local row = activeRows[r]
        rowFrameIndex = rowFrameIndex + 1

        local rf = RowFrame(rowFrameIndex)
        local leftID = row[1]
        local rightID = row[2]
        local leftGroup = FindGroup(leftID)
        local rightGroup = rightID and FindGroup(rightID) or nil

        local leftList = grouped[leftID] or {}
        local rightList = rightID and (grouped[rightID] or {}) or nil

        SortEntries(leftList, leftGroup and leftGroup.sort or "bag", leftGroup and leftGroup.reverse or false)
        if rightGroup then SortEntries(rightList, rightGroup.sort or "bag", rightGroup.reverse) end

        local leftSection, leftHeight = LayoutSection(
          leftID,
          leftGroup and leftGroup.name or "Category",
          leftID,
          leftList,
          rightID and halfColumns or fullColumns,
          size,
          border
        )

        local rightSection, rightHeight
        if rightID and rightGroup then
          rightSection, rightHeight = LayoutSection(
            rightID,
            rightGroup.name,
            rightID,
            rightList,
            halfColumns,
            size,
            border
          )
        end

        local rowHeight = leftHeight
        if rightHeight and rightHeight > rowHeight then rowHeight = rightHeight end

        rf:ClearAllPoints()
        rf:SetPoint("BOTTOMLEFT", below, "TOPLEFT", 0, ROW_GAP)
        rf:SetPoint("BOTTOMRIGHT", below, "TOPRIGHT", 0, ROW_GAP)
        rf:SetHeight(rowHeight)

        leftSection:ClearAllPoints()
        leftSection.bagtweaks_rowFrame = rf
        if rightSection then
          leftSection:SetPoint("TOPLEFT", rf, "TOPLEFT", 0, 0)
          leftSection:SetPoint("BOTTOMLEFT", rf, "BOTTOMLEFT", 0, 0)
          leftSection:SetPoint("RIGHT", rf, "CENTER", -border, 0)

          rightSection:ClearAllPoints()
          rightSection:SetPoint("TOPRIGHT", rf, "TOPRIGHT", 0, 0)
          rightSection:SetPoint("BOTTOMRIGHT", rf, "BOTTOMRIGHT", 0, 0)
          rightSection:SetPoint("LEFT", rf, "CENTER", border, 0)
          rightSection.bagtweaks_rowFrame = rf

          active[rightID] = true
        else
          leftSection:SetAllPoints(rf)
        end

        active[leftID] = true
        totalHeight = totalHeight + rowHeight + ROW_GAP
        below = rf
      end

      for i = rowFrameIndex + 1, table.getn(rowFrames) do rowFrames[i]:Hide() end
      for key, h in pairs(headers) do if not active[key] then h:Hide() end end
      for key, s in pairs(sections) do
        if not active[key] then
          if itemHighlightSection == s then HideItemHighlight() end
          s:Hide()
        end
      end

      frame:SetHeight(bottomSpace + totalHeight + topSpace + border * 2)
      if draggingGroupID then UpdateDragVisual() end
    end

    pfUI.bagtweaks.Relayout = Relayout
    pfUI.bagtweaks.ShowGroupEditor = ShowNameDialog

    pfUI.bag.CreateBags = function(self, object)
      oldCreateBags(self, object)
      if object ~= "bank" then Relayout() end
    end

    if oldUpdateBag then
      pfUI.bag.UpdateBag = function(self, bag)
        oldUpdateBag(self, bag)
        if bag == -2 or (bag >= 0 and bag <= 4) then Relayout() end
      end
    end

    local bagFrame = pfUI.bag.right
    if bagFrame and not bagFrame.bagtweaks_menu_hide_hooked then
      local oldOnHide = bagFrame:GetScript("OnHide")
      bagFrame:SetScript("OnHide", function()
        if oldOnHide then oldOnHide() end
        HideMenus()
      end)
      bagFrame.bagtweaks_menu_hide_hooked = true
    end

    if G.C_Item and type(G.C_Item.GetItemInfo) == "function" then
      local itemDataWatcher = CreateFrame("Frame")
      itemDataWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
      itemDataWatcher:SetScript("OnEvent", function()
        if Relayout then Relayout() end
      end)
      pfUI.bagtweaks.itemDataWatcher = itemDataWatcher
    end

    pfUI.bag.bagtweaks_hooked = true
    CleanState()
    if pfUI.bag.right then Relayout() end
  end)

  if pfUI.gui and pfUI.gui.CreateGUIEntry and pfUI.gui.CreateConfig then
    local thirdParty = "Thirdparty"
    if pfUI.env and pfUI.env.T and pfUI.env.T["Thirdparty"] then
      thirdParty = pfUI.env.T["Thirdparty"]
    end

    pfUI.gui.CreateGUIEntry(thirdParty, "Bag Tweaks", function()
      pfUI.gui.CreateConfig(nil, "pfUI_BagTweaks", nil, nil, "header")
      pfUI.gui.CreateConfig(function()
        if pfUI.bagtweaks and pfUI.bagtweaks.ApplyHeaderOptions then
          pfUI.bagtweaks.ApplyHeaderOptions()
        end
      end, "Show Search Bar", pfUI_config.bagtweaks, "show_search", "checkbox")
    end)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    Initialize()
    this:UnregisterAllEvents()
  end
end)

-- ---------------------------------------------------------------------------
-- Toolbar prototype (dev branch only)
-- ---------------------------------------------------------------------------

local TOOLBAR_HEIGHT = 12
local TOOLBAR_GAP = 2
local SEARCH_GAP = 2
local SEARCH_HEIGHT = 14
local UPDATE_INTERVAL = .20

local toolbarState = {
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

local function ToolbarFontSize()
  local size = 9
  if pfUI_config and pfUI_config.global and pfUI_config.global.font_size then
    size = tonumber(pfUI_config.global.font_size) or size
  end
  if size > 9 then size = 9 end
  if size < 7 then size = 7 end
  return size
end

local function ToolbarFriendlyLabel(frame, bag)
  if frame == toolbarState.searchButton then return "Search" end
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

local function ToolbarKnownRank(frame, bag)
  if frame == toolbarState.searchButton then return 10 end
  if frame == bag.sort then return 20 end
  if frame == bag.keys then return 30 end
  if frame == bag.picklock then return 40 end
  if frame == bag.disenchant then return 50 end
  if frame == bag.open then return 60 end
  if frame == bag.bags then return 70 end
  return 100
end

local function ToolbarEnsureLabel(button, text)
  if not button.bagtweaks_toolbar_label then
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", button, "LEFT", 2, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    label:SetJustifyH("CENTER")
    button.bagtweaks_toolbar_label = label
  end

  local label = button.bagtweaks_toolbar_label
  label:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, ToolbarFontSize(), "OUTLINE")
  label:SetText(text)
  label:Show()

  if button.texture and button.texture.SetAlpha then
    button.texture:SetAlpha(0)
  end
end

local function ToolbarEnsureActiveOverlay(button)
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

local function ToolbarUpdateActiveVisuals()
  local bag = pfUI.bag and pfUI.bag.right
  if not bag then return end

  ToolbarEnsureActiveOverlay(toolbarState.searchButton)
  ToolbarEnsureActiveOverlay(bag.disenchant)
  ToolbarEnsureActiveOverlay(bag.picklock)

  if toolbarState.searchButton and toolbarState.searchButton.bagtweaks_active_overlay then
    if toolbarState.searchOpen then toolbarState.searchButton.bagtweaks_active_overlay:Show()
    else toolbarState.searchButton.bagtweaks_active_overlay:Hide() end
  end

  if bag.disenchant and bag.disenchant.bagtweaks_active_overlay then
    if toolbarState.activeMode == "disenchant" then bag.disenchant.bagtweaks_active_overlay:Show()
    else bag.disenchant.bagtweaks_active_overlay:Hide() end
  end

  if bag.picklock and bag.picklock.bagtweaks_active_overlay then
    if toolbarState.activeMode == "picklock" then bag.picklock.bagtweaks_active_overlay:Show()
    else bag.picklock.bagtweaks_active_overlay:Hide() end
  end
end

local function ToolbarApplySearchState()
  local bag = pfUI.bag and pfUI.bag.right
  local search = bag and bag.search
  if not search then return end

  search:Show()
  search:ClearAllPoints()
  search:SetPoint("BOTTOMLEFT", bag, "TOPLEFT", 0, SEARCH_GAP)
  search:SetPoint("BOTTOMRIGHT", bag, "TOPRIGHT", 0, SEARCH_GAP)
  search:SetHeight(SEARCH_HEIGHT)

  if toolbarState.searchOpen then
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

  ToolbarUpdateActiveVisuals()
end

local function ToolbarToggleSearch()
  toolbarState.searchOpen = not toolbarState.searchOpen
  ToolbarApplySearchState()

  local bag = pfUI.bag and pfUI.bag.right
  if toolbarState.searchOpen and bag and bag.search and bag.search.edit then
    bag.search.edit:SetFocus()
  end
end

local function ToolbarEnsureSearchButton(bag)
  if toolbarState.searchButton then return toolbarState.searchButton end

  local b = CreateFrame("Button", nil, bag)
  b.bagtweaks_toolbar_control = true
  b:SetHeight(TOOLBAR_HEIGHT)
  b:EnableMouse(1)
  b:SetScript("OnClick", ToolbarToggleSearch)
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

  toolbarState.searchButton = b
  ToolbarEnsureLabel(b, "Search")
  ToolbarEnsureActiveOverlay(b)
  return b
end

local function ToolbarIsCandidate(child, bag)
  if not child or child == bag.close or child == toolbarState.searchButton then return false end
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

local function ToolbarDiscoverButtons(bag)
  local buttons = {}
  table.insert(buttons, ToolbarEnsureSearchButton(bag))

  local children = { bag:GetChildren() }
  for i = 1, table.getn(children) do
    local child = children[i]
    if ToolbarIsCandidate(child, bag) and child:IsShown() then
      if not child.bagtweaks_original_left and child.GetLeft then
        child.bagtweaks_original_left = child:GetLeft()
      end
      table.insert(buttons, child)
    end
  end

  table.sort(buttons, function(a, b)
    local ar = ToolbarKnownRank(a, bag)
    local br = ToolbarKnownRank(b, bag)
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

local function ToolbarLayout()
  local bag = pfUI.bag and pfUI.bag.right
  if not bag or not bag.close or not bag.GetWidth then return end

  local buttons = ToolbarDiscoverButtons(bag)
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

    ToolbarEnsureLabel(button, ToolbarFriendlyLabel(button, bag))
    previous = button
  end

  ToolbarApplySearchState()
end

local function ToolbarCancelTargeting()
  if SpellIsTargeting and SpellIsTargeting() and SpellStopTargeting then
    SpellStopTargeting()
  end
end

local function ToolbarCastPersistentMode(mode)
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

local function ToolbarDisablePersistentMode()
  toolbarState.activeMode = nil
  toolbarState.wasTargeting = false
  toolbarState.awaitingCompletion = false
  toolbarState.rearmAt = nil
  ToolbarCancelTargeting()
  ToolbarUpdateActiveVisuals()
end

local function ToolbarActivatePersistentMode(mode, oldOnClick)
  if toolbarState.activeMode == mode then
    ToolbarDisablePersistentMode()
    return
  end

  if toolbarState.activeMode then ToolbarCancelTargeting() end

  toolbarState.activeMode = mode
  toolbarState.wasTargeting = false
  toolbarState.awaitingCompletion = false
  toolbarState.rearmAt = nil
  ToolbarUpdateActiveVisuals()

  if oldOnClick then oldOnClick() end
  if SpellIsTargeting and SpellIsTargeting() then toolbarState.wasTargeting = true end
end

local function ToolbarHookPersistentButton(button, mode)
  if not button or button.bagtweaks_persistent_hooked then return end

  local oldOnClick = button:GetScript("OnClick")
  button.bagtweaks_original_onclick = oldOnClick
  button:SetScript("OnClick", function()
    ToolbarActivatePersistentMode(mode, oldOnClick)
  end)
  button.bagtweaks_persistent_hooked = true
end

local function ToolbarPlayerIsCasting()
  return CastingBarFrame and (CastingBarFrame.casting or CastingBarFrame.channeling)
end

local function ToolbarUpdatePersistentMode(now)
  if not toolbarState.activeMode then return end

  local bag = pfUI.bag and pfUI.bag.right
  local button = bag and (toolbarState.activeMode == "disenchant" and bag.disenchant or bag.picklock)
  if not button or not button:IsShown() or (button:GetID() or 0) <= 0 then
    ToolbarDisablePersistentMode()
    return
  end

  local targeting = SpellIsTargeting and SpellIsTargeting()
  if targeting then
    toolbarState.wasTargeting = true
    toolbarState.awaitingCompletion = false
    toolbarState.rearmAt = nil
    return
  end

  if toolbarState.wasTargeting then
    toolbarState.wasTargeting = false
    toolbarState.awaitingCompletion = true
    toolbarState.rearmAt = now + .75
  end

  if toolbarState.awaitingCompletion and toolbarState.rearmAt and now >= toolbarState.rearmAt and not ToolbarPlayerIsCasting() then
    toolbarState.awaitingCompletion = false
    toolbarState.rearmAt = nil
    if ToolbarCastPersistentMode(toolbarState.activeMode) then
      toolbarState.rearmAt = now + .30
    end
  elseif not toolbarState.awaitingCompletion and toolbarState.rearmAt and now >= toolbarState.rearmAt then
    if SpellIsTargeting and SpellIsTargeting() then
      toolbarState.wasTargeting = true
      toolbarState.rearmAt = nil
    elseif not ToolbarPlayerIsCasting() then
      if ToolbarCastPersistentMode(toolbarState.activeMode) then toolbarState.rearmAt = now + .30 end
    end
  end
end

local function ToolbarOnSpellFinished()
  if not toolbarState.activeMode or not toolbarState.awaitingCompletion then return end
  toolbarState.rearmAt = GetTime() + .10
end

local function ToolbarSetup()
  local bag = pfUI.bag and pfUI.bag.right
  if not bag or not bag.search or not bag.close then return false end

  ToolbarEnsureSearchButton(bag)
  ToolbarHookPersistentButton(bag.disenchant, "disenchant")
  ToolbarHookPersistentButton(bag.picklock, "picklock")

  if not toolbarState.initialized then
    toolbarState.oldBagOnHide = bag:GetScript("OnHide")
    bag:SetScript("OnHide", function()
      if toolbarState.oldBagOnHide then toolbarState.oldBagOnHide() end
      toolbarState.searchOpen = false
      ToolbarApplySearchState()
    end)
    toolbarState.initialized = true
  end

  ToolbarLayout()
  return true
end

local toolbarWatcher = CreateFrame("Frame")
toolbarWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
toolbarWatcher:RegisterEvent("SPELLS_CHANGED")
toolbarWatcher:RegisterEvent("SPELLCAST_STOP")
toolbarWatcher:RegisterEvent("SPELLCAST_FAILED")
toolbarWatcher:RegisterEvent("SPELLCAST_INTERRUPTED")

toolbarWatcher:SetScript("OnEvent", function()
  if event == "SPELLCAST_STOP" or event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
    ToolbarOnSpellFinished()
  end
  ToolbarSetup()
end)

toolbarWatcher:SetScript("OnUpdate", function()
  local now = GetTime()
  ToolbarUpdatePersistentMode(now)

  if now - toolbarState.lastUpdate < UPDATE_INTERVAL then return end
  toolbarState.lastUpdate = now

  if ToolbarSetup() and pfUI.bag.right:IsShown() then
    ToolbarLayout()
  end
end)

ToolbarSetup()
