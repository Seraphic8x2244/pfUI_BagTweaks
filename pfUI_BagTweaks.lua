-- pfUI_BagTweaks 0.1.8-dev
-- User-defined visual groups, per-group sorting, optional Quest automation,
-- and per-group account/character scope.
-- Grouping and sorting never move the underlying inventory slots.

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
    local HEADER_HEIGHT = 14
    local SORT_WIDTH = 54
    local CONTROL_WIDTH = 14
    local ORDER_WIDTH = 14
    local QUEST_WIDTH = 16
    local SCOPE_WIDTH = 16
    local QUEST_CLASS_ID = 12
    local GENERAL_OVERRIDE = 0

    local SORT_MODES = { "bag", "name", "value", "slot" }
    local SORT_LABEL = { bag="Bag", name="Name", value="Value", slot="Slot" }

    -- Character-sheet order. "Slot" means equipment slot/type, never bag slot.
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
    local headers, sections = {}, {}
    local selectedItemID = nil
    local nameDialog, deleteDialog
    local Relayout

    -- pfUI runs modules in pfUI.env via setfenv(). Use the real global table
    -- for SavedVariables so WoW serializes the same database we mutate here.
    G.pfUIBagTweaksDB = G.pfUIBagTweaksDB or {}
    local db = G.pfUIBagTweaksDB
    db.groups = db.groups or {}
    db.nextGroupID = tonumber(db.nextGroupID) or 1
    db.generalSort = db.generalSort or "bag"
    if db.generalReverse == nil then db.generalReverse = false end

    -- Migrate the old single assignment table to account-wide assignments.
    db.accountAssignments = db.accountAssignments or db.assignments or {}
    db.assignments = nil
    db.charAssignments = db.charAssignments or {}

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

    local function IsGroupActive(g)
      if not g then return false end
      if g.scope ~= "char" then return true end
      return g.owner == CharacterKey()
    end

    local function GroupExists(id)
      return FindGroup(id) ~= nil
    end

    local function ActiveGroupIndices()
      local indices = {}
      for i = 1, table.getn(db.groups) do
        if IsGroupActive(db.groups[i]) then table.insert(indices, i) end
      end
      return indices
    end

    -- Migrate older group records and older single quest-group setting.
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

    local function CleanState()
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

    local function MoveGroup(id, delta)
      local indices = ActiveGroupIndices()
      local position = nil

      for i = 1, table.getn(indices) do
        if db.groups[indices[i]].id == id then
          position = i
          break
        end
      end

      if not position then return end
      local targetPosition = position + delta
      if targetPosition < 1 or targetPosition > table.getn(indices) then return end

      local a, b = indices[position], indices[targetPosition]
      db.groups[a], db.groups[b] = db.groups[b], db.groups[a]
      Relayout()
    end

    local function ToggleScope(id)
      local g = FindGroup(id)
      if not g then return end

      local charAssignments = CharAssignments(true)

      if g.scope == "char" then
        -- Character -> Account: assignments in this group become account-wide.
        for itemID, groupID in pairs(charAssignments) do
          if groupID == id then
            db.accountAssignments[itemID] = id
            charAssignments[itemID] = nil
          end
        end
        g.scope = "account"
        g.owner = nil
      else
        -- Account -> Character: preserve this character's membership, remove it globally.
        for itemID, groupID in pairs(db.accountAssignments) do
          if groupID == id then
            if charAssignments[itemID] == nil then charAssignments[itemID] = id end
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
        -- Keep one Quest group among the groups visible to this character.
        for i = 1, table.getn(db.groups) do
          local other = db.groups[i]
          if IsGroupActive(other) then other.quest = false end
        end
        g.quest = true
      end

      Relayout()
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
      if not link then return nil end
      local _, _, name = string.find(link, "%[([^%]]+)%]")
      return name
    end

    local function InstantInfo(id)
      if not id or not G.C_Item or type(G.C_Item.GetItemInfoInstant) ~= "function" then
        return nil, nil, nil, nil
      end

      -- ClassicAPI: itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID
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
      local fullName, fullType, fullEquipLoc, fullClassID

      -- FullInfo also warms ClassicAPI's cache when InstantInfo is cold.
      if not name or not equipLoc or equipLoc == "" or classID == nil then
        fullName, fullType, fullEquipLoc, fullClassID = FullInfo(id, link)
      end

      if not name or name == "" then
        if G.C_Item and type(G.C_Item.GetItemNameByID) == "function" and id then
          name = G.C_Item.GetItemNameByID(id)
        end
        name = name or fullName or ""
      end

      itemType = itemType or fullType
      if not equipLoc or equipLoc == "" then equipLoc = fullEquipLoc or "" end
      classID = classID or fullClassID

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
        link = link,
        name = string.lower(name or ""),
        equipLoc = equipLoc or "",
        rank = SLOT_ORDER[equipLoc or ""] or 999,
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

    local function PhysicalLess(a, b)
      if a.bag ~= b.bag then return a.bag < b.bag end
      return a.slot < b.slot
    end

    local function PhysicalOrderedLess(a, b, reverse)
      if reverse then return PhysicalLess(b, a) end
      return PhysicalLess(a, b)
    end

    local function EntryLess(a, b, mode, reverse)
      if mode == "bag" then return PhysicalOrderedLess(a, b, reverse) end

      -- Empty bag slots always remain after actual items.
      if a.itemID and not b.itemID then return true end
      if not a.itemID and b.itemID then return false end
      if not a.itemID and not b.itemID then return PhysicalOrderedLess(a, b, reverse) end

      local av, bv
      if mode == "name" then
        av, bv = a.meta.name, b.meta.name
      elseif mode == "value" then
        if a.meta.value == nil and b.meta.value ~= nil then return false end
        if a.meta.value ~= nil and b.meta.value == nil then return true end
        av, bv = a.meta.value or 0, b.meta.value or 0
      elseif mode == "slot" then
        av, bv = a.meta.rank, b.meta.rank
      else
        av, bv = 0, 0
      end

      if av ~= bv then
        if reverse then return av > bv end
        return av < bv
      end

      if a.meta.name ~= b.meta.name then
        if reverse then return a.meta.name > b.meta.name end
        return a.meta.name < b.meta.name
      end

      return PhysicalOrderedLess(a, b, reverse)
    end

    local function SortEntries(entries, mode, reverse)
      if table.getn(entries) < 2 then return end
      table.sort(entries, function(a, b)
        return EntryLess(a, b, mode or "bag", reverse)
      end)
    end

    local function GetSort(id)
      if id == nil then return db.generalSort or "bag", db.generalReverse end
      local g = FindGroup(id)
      return g and (g.sort or "bag") or "bag", g and g.reverse or false
    end

    local function NextSort(mode)
      for i = 1, table.getn(SORT_MODES) do
        if SORT_MODES[i] == mode then
          if i == table.getn(SORT_MODES) then return SORT_MODES[1] end
          return SORT_MODES[i + 1]
        end
      end
      return "bag"
    end

    local function ChangeSort(id, reverseOnly)
      if id == nil then
        if reverseOnly then db.generalReverse = not db.generalReverse
        else db.generalSort = NextSort(db.generalSort) end
      else
        local g = FindGroup(id)
        if not g then return end
        if reverseOnly then g.reverse = not g.reverse
        else g.sort = NextSort(g.sort) end
      end
      Relayout()
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
            table.insert(db.groups, {
              id=db.nextGroupID,
              name=name,
              sort="bag",
              reverse=false,
              scope="account",
              quest=false,
            })
            db.nextGroupID = db.nextGroupID + 1
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
        nameDialog.title:SetText("Rename Group")
        nameDialog.edit:SetText(g.name)
      else
        nameDialog.title:SetText("New Group")
        nameDialog.edit:SetText("")
      end

      nameDialog:Show()
      nameDialog.edit:SetFocus()
      nameDialog.edit:HighlightText()
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
          local group, index = FindGroup(f.groupID)
          if index then
            -- Preserve "return to General" in the same scope the group used.
            if group.scope == "char" then
              local ca = CharAssignments(true)
              for itemID, assigned in pairs(ca) do
                if assigned == f.groupID then ca[itemID] = GENERAL_OVERRIDE end
              end
            else
              for itemID, assigned in pairs(db.accountAssignments) do
                if assigned == f.groupID then db.accountAssignments[itemID] = GENERAL_OVERRIDE end
              end
            end

            for _, assignments in pairs(db.charAssignments) do
              for itemID, assigned in pairs(assignments) do
                if assigned == f.groupID then assignments[itemID] = GENERAL_OVERRIDE end
              end
            end

            table.remove(db.groups, index)
          end

          f:Hide()
          Relayout()
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
        return false
      end

      local itemKey = tostring(selectedItemID)
      local ca = CharAssignments(true)

      if groupID == nil then
        -- General preserves the scope of an existing manual assignment.
        if ca[itemKey] ~= nil then
          ca[itemKey] = GENERAL_OVERRIDE
        elseif db.accountAssignments[itemKey] ~= nil then
          db.accountAssignments[itemKey] = GENERAL_OVERRIDE
        else
          -- For automatic Quest classification, a General override is local by default.
          ca[itemKey] = GENERAL_OVERRIDE
        end
      else
        local g = FindGroup(groupID)
        if not g or not IsGroupActive(g) then return false end

        if g.scope == "char" then
          ca[itemKey] = groupID
        else
          db.accountAssignments[itemKey] = groupID
          -- The user's action on this character should take effect immediately.
          ca[itemKey] = nil
        end
      end

      if type(ClearCursor) == "function" then ClearCursor() end
      selectedItemID = nil
      Relayout()
      return true
    end

    local function Tooltip(text, line)
      GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
      GameTooltip:SetText(text)
      if line then GameTooltip:AddLine(line, 1, 1, 1) end
      GameTooltip:Show()
    end

    local function MakeTextButton(parent, width, anchor, rel, relPoint, x, text, tooltip, click)
      local b = CreateFrame("Button", nil, parent)
      b:SetWidth(width)
      b:SetHeight(HEADER_HEIGHT)
      b:SetPoint(anchor, rel, relPoint, x, 0)
      b:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      b:SetTextColor(.7, .7, .7, 1)
      b:SetText(text)
      b:SetScript("OnClick", click)
      b:SetScript("OnEnter", function() Tooltip(tooltip) end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      return b
    end

    local function NewHeader(key)
      local h = CreateFrame("Frame", nil, pfUI.bag.right)
      h:SetHeight(HEADER_HEIGHT)
      h:EnableMouse(1)

      h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      h.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      h.text:SetPoint("LEFT", h, "LEFT", 2, 0)
      h.text:SetJustifyH("LEFT")

      h.line = h:CreateTexture(nil, "ARTWORK")
      h.line:SetTexture(1, 1, 1, 1)
      h.line:SetVertexColor(.25, .25, .25, 1)
      h.line:SetHeight(1)
      h.line:SetPoint("BOTTOMLEFT", h)
      h.line:SetPoint("BOTTOMRIGHT", h)

      h.sort = CreateFrame("Button", nil, h)
      h.sort:SetWidth(SORT_WIDTH)
      h.sort:SetHeight(HEADER_HEIGHT)
      h.sort:SetPoint("RIGHT", h, "RIGHT", -1, 0)
      h.sort:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      h.sort:SetTextColor(.75, .75, .75, 1)
      h.sort:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      h.sort:SetScript("OnClick", function()
        if AssignSelected(h.groupID) then return end
        ChangeSort(h.groupID, arg1 == "RightButton")
      end)
      h.sort:SetScript("OnEnter", function()
        Tooltip("Visual Sort", "Left-click: type   Right-click: reverse")
      end)
      h.sort:SetScript("OnLeave", function() GameTooltip:Hide() end)
      h.sort:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

      h:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)
      h:SetScript("OnMouseUp", function()
        if AssignSelected(h.groupID) then return end
        if h.groupID and arg1 == "RightButton" then ShowNameDialog(h.groupID) end
      end)
      h:SetScript("OnEnter", function()
        if h.groupID then
          Tooltip(h.text:GetText(), "Drop/click an item into this group; right-click to rename")
        else
          Tooltip("General", "Drop/click an item here to keep it in General")
        end
      end)
      h:SetScript("OnLeave", function() GameTooltip:Hide() end)

      if key == "general" then
        h.control = MakeTextButton(h, CONTROL_WIDTH, "RIGHT", h.sort, "LEFT", -2, "+", "Add Group", function()
          if AssignSelected(nil) then return end
          ShowNameDialog(nil)
        end)
        h.control:SetScript("OnReceiveDrag", function() AssignSelected(nil) end)
        h.text:SetPoint("RIGHT", h.control, "LEFT", -2, 0)
      else
        h.control = MakeTextButton(h, CONTROL_WIDTH, "RIGHT", h.sort, "LEFT", -2, "x", "Delete Group", function()
          if AssignSelected(h.groupID) then return end
          if h.groupID then ShowDeleteDialog(h.groupID) end
        end)
        h.control:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.down = MakeTextButton(h, ORDER_WIDTH, "RIGHT", h.control, "LEFT", -1, "v", "Move Group Down", function()
          if AssignSelected(h.groupID) then return end
          if h.groupID then MoveGroup(h.groupID, 1) end
        end)
        h.down:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.up = MakeTextButton(h, ORDER_WIDTH, "RIGHT", h.down, "LEFT", -1, "^", "Move Group Up", function()
          if AssignSelected(h.groupID) then return end
          if h.groupID then MoveGroup(h.groupID, -1) end
        end)
        h.up:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.quest = MakeTextButton(h, QUEST_WIDTH, "RIGHT", h.up, "LEFT", -1, "Q", "Automatic Quest Items", function()
          if AssignSelected(h.groupID) then return end
          if h.groupID then ToggleQuestGroup(h.groupID) end
        end)
        h.quest:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.scope = MakeTextButton(h, SCOPE_WIDTH, "RIGHT", h.quest, "LEFT", -1, "A", "Group Scope", function()
          if AssignSelected(h.groupID) then return end
          if h.groupID then ToggleScope(h.groupID) end
        end)
        h.scope:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.text:SetPoint("RIGHT", h.scope, "LEFT", -2, 0)
      end

      headers[key] = h
      return h
    end

    local function Header(key, name, groupID)
      local h = headers[key] or NewHeader(key)
      h.groupID = groupID
      h.text:SetText(name)

      local mode, reverse = GetSort(groupID)
      h.sort:SetText((SORT_LABEL[mode] or "Bag") .. (reverse and " v" or " ^"))

      if groupID then
        local g = FindGroup(groupID)
        if h.quest then
          if g and g.quest then h.quest:SetTextColor(.2, 1, .2, 1)
          else h.quest:SetTextColor(.7, .7, .7, 1) end
        end
        if h.scope and g then
          if g.scope == "char" then
            h.scope:SetText("C")
            h.scope:SetTextColor(.75, .75, .75, 1)
          else
            h.scope:SetText("A")
            h.scope:SetTextColor(1, .82, 0, 1)
          end
        end
      end

      h:Show()
      return h
    end

    local function Section(key, groupID)
      local s = sections[key]
      if not s then
        s = CreateFrame("Frame", nil, pfUI.bag.right)
        s:EnableMouse(1)
        sections[key] = s
      end

      s.groupID = groupID
      s:SetScript("OnReceiveDrag", function() AssignSelected(s.groupID) end)
      s:SetScript("OnMouseUp", function()
        if arg1 == "LeftButton" then AssignSelected(s.groupID) end
      end)
      s:SetScript("OnEnter", function()
        if selectedItemID and CursorStillHasItem() then
          if s.groupID then Tooltip("Add to Group", "Release/click to classify the selected item here")
          else Tooltip("Move to General", "Release/click to keep the selected item in General") end
        end
      end)
      s:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
      local general, grouped = {}, {}
      local questGroupID = ActiveQuestGroupID()

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
            local id = ItemID(bag, slot)
            local meta = id and SortMetadata(bag, slot, id) or {
              link=nil,
              name="",
              equipLoc="",
              rank=999,
              itemType=nil,
              classID=nil,
              value=nil,
            }
            local entry = { bag=bag, slot=slot, frame=frame, itemID=id, meta=meta }
            local groupID = nil

            if id then
              local itemKey = tostring(id)
              local manual = EffectiveManualAssignment(itemKey)

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
      local spacing = border * 3
      local pitch = size + spacing
      local rows = RowsFor(list, columns)
      local sectionHeight = HEADER_HEIGHT + border + rows * pitch + border
      local s = Section(key, groupID)
      local h = Header(key, name, groupID)

      s:SetHeight(sectionHeight)

      h:ClearAllPoints()
      h:SetPoint("TOPLEFT", s, "TOPLEFT", border, 0)
      h:SetPoint("TOPRIGHT", s, "TOPRIGHT", -border, 0)

      local row, col = 0, 0
      for i = 1, table.getn(list) do
        local f = list[i].frame
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

      return s, sectionHeight
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

      local columns = tonumber(C.appearance.bags.bagrowlength) or 10
      local size = frame.button_size
      local topSpace = frame.close:GetHeight() + border * 2
      local bottomSpace = pfUI.panel and pfUI.panel.right:IsShown()
        and pfUI.panel.right:GetHeight() + border
        or 16 + border

      local general, grouped = Collect()
      local active = {}
      local totalSections = 0

      SortEntries(general, db.generalSort, db.generalReverse)
      local generalSection, generalHeight = LayoutSection(
        "general", "General", nil, general, columns, size, border
      )
      active["general"] = true
      totalSections = totalSections + generalHeight

      generalSection:ClearAllPoints()
      generalSection:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, bottomSpace)
      generalSection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomSpace)

      local below = generalSection

      for i = table.getn(db.groups), 1, -1 do
        local g = db.groups[i]
        if IsGroupActive(g) then
          local list = grouped[g.id] or {}
          SortEntries(list, g.sort, g.reverse)

          local section, height = LayoutSection(g.id, g.name, g.id, list, columns, size, border)
          active[g.id] = true
          totalSections = totalSections + height

          section:ClearAllPoints()
          section:SetPoint("BOTTOMLEFT", below, "TOPLEFT", 0, 0)
          section:SetPoint("BOTTOMRIGHT", below, "TOPRIGHT", 0, 0)
          below = section
        end
      end

      for key, h in pairs(headers) do if not active[key] then h:Hide() end end
      for key, s in pairs(sections) do if not active[key] then s:Hide() end end

      frame:SetHeight(bottomSpace + totalSections + topSpace + border * 2)
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

    -- ClassicAPI fills cold item metadata asynchronously. Re-sort as data arrives.
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