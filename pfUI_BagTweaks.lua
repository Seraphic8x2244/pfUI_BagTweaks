-- pfUI_BagTweaks 0.1.6-dev
-- User-defined visual groups, per-group sorting, and optional Quest automation.
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
    local QUEST_CLASS_ID = 12
    local GENERAL_OVERRIDE = 0

    local SORT_MODES = { "bag", "name", "value", "slot" }
    local SORT_LABEL = { bag="Bag", name="Name", value="Value", slot="Slot" }

    -- "Slot" means equipment slot/type, not the physical bag slot.
    local SLOT_ORDER = {
      INVTYPE_HEAD=1, INVTYPE_NECK=2, INVTYPE_SHOULDER=3, INVTYPE_BODY=4,
      INVTYPE_CHEST=5, INVTYPE_ROBE=5, INVTYPE_CLOAK=6, INVTYPE_WRIST=7,
      INVTYPE_HAND=8, INVTYPE_WAIST=9, INVTYPE_LEGS=10, INVTYPE_FEET=11,
      INVTYPE_FINGER=12, INVTYPE_TRINKET=13, INVTYPE_WEAPONMAINHAND=14,
      INVTYPE_2HWEAPON=15, INVTYPE_WEAPON=16, INVTYPE_SHIELD=17,
      INVTYPE_HOLDABLE=18, INVTYPE_WEAPONOFFHAND=19, INVTYPE_RANGED=20,
      INVTYPE_RANGEDRIGHT=20, INVTYPE_THROWN=20, INVTYPE_RELIC=20,
      INVTYPE_TABARD=21, INVTYPE_BAG=22, INVTYPE_QUIVER=22, INVTYPE_AMMO=23,
    }

    local oldCreateBags = pfUI.bag.CreateBags
    local oldUpdateBag = pfUI.bag.UpdateBag
    local headers, sections = {}, {}
    local selectedItemID = nil
    local nameDialog, deleteDialog
    local Relayout

    -- This function only runs after this addon's ADDON_LOADED event,
    -- so the SavedVariables table has already been restored by WoW.
    pfUIBagTweaksDB = pfUIBagTweaksDB or {}
    local db = pfUIBagTweaksDB
    db.groups = db.groups or {}
    db.assignments = db.assignments or {}
    db.nextGroupID = tonumber(db.nextGroupID) or 1
    db.generalSort = db.generalSort or "bag"
    if db.generalReverse == nil then db.generalReverse = false end
    db.questGroupID = tonumber(db.questGroupID)

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

    local function CleanState()
      if db.questGroupID and not GroupExists(db.questGroupID) then
        db.questGroupID = nil
      end

      for itemID, groupID in pairs(db.assignments) do
        if groupID ~= GENERAL_OVERRIDE and not GroupExists(groupID) then
          db.assignments[itemID] = GENERAL_OVERRIDE
        end
      end
    end

    local function MoveGroup(id, delta)
      local _, index = FindGroup(id)
      if not index then return end

      local target = index + delta
      if target < 1 or target > table.getn(db.groups) then return end

      db.groups[index], db.groups[target] = db.groups[target], db.groups[index]
      Relayout()
    end

    local function ToggleQuestGroup(id)
      if not id or not GroupExists(id) then return end

      if db.questGroupID == id then
        db.questGroupID = nil
      else
        db.questGroupID = id
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
      if not link then return "" end
      local _, _, name = string.find(link, "%[(.-)%]")
      return string.lower(name or "")
    end

    local function InstantInfo(id)
      if not id or not G.C_Item or type(G.C_Item.GetItemInfoInstant) ~= "function" then
        return nil, nil, nil, nil
      end

      -- ClassicAPI mirrors the modern tuple:
      -- itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subclassID
      local _, itemType, _, equipLoc, _, classID = G.C_Item.GetItemInfoInstant(id)
      return itemType, equipLoc, tonumber(classID)
    end

    local function FullInfo(id, link)
      local name, itemType, equipLoc, classID

      if G.C_Item and type(G.C_Item.GetItemInfo) == "function" then
        local n, _, _, _, _, t, _, _, e, _, _, c = G.C_Item.GetItemInfo(id)
        name, itemType, equipLoc, classID = n, t, e, tonumber(c)
      end

      if not name or not itemType or not equipLoc then
        local n, _, _, _, _, t, _, _, e = GetItemInfo(link or id)
        name = name or n
        itemType = itemType or t
        equipLoc = equipLoc or e
      end

      return name, itemType, equipLoc, classID
    end

    local function EquipLoc(id, link)
      local _, instantEquipLoc = InstantInfo(id)
      if instantEquipLoc and instantEquipLoc ~= "" then
        return instantEquipLoc
      end

      local _, _, equipLoc = FullInfo(id, link)
      return equipLoc or ""
    end

    local function IsQuestItem(id, link)
      if not id then return false end

      local instantType, _, instantClassID = InstantInfo(id)
      if instantClassID ~= nil then
        return instantClassID == QUEST_CLASS_ID
      end

      local _, itemType, _, classID = FullInfo(id, link)
      if classID ~= nil then
        return classID == QUEST_CLASS_ID
      end

      itemType = itemType or instantType
      if G.ITEM_CLASS_QUESTITEM and itemType == G.ITEM_CLASS_QUESTITEM then return true end
      if G.ITEM_CLASS_QUEST and itemType == G.ITEM_CLASS_QUEST then return true end

      return itemType == "Quest"
    end

    local function VendorValue(id, link)
      if G.C_Item and type(G.C_Item.GetItemInfo) == "function" then
        local _, _, _, _, _, _, _, _, _, _, value = G.C_Item.GetItemInfo(id)
        if value ~= nil then return tonumber(value) end
      end

      if type(G.GetSellValue) == "function" then
        local ok, value = pcall(G.GetSellValue, link or id)
        if ok and value ~= nil then return tonumber(value) end
      end

      if type(G.GetItemSellPrice) == "function" then
        local ok, value = pcall(G.GetItemSellPrice, id)
        if ok and value ~= nil then return tonumber(value) end
      end
    end

    local function Meta(entry)
      if entry.meta then return entry.meta end

      local link = GetContainerItemLink(entry.bag, entry.slot)
      local m = {
        name = NameFromLink(link),
        rank = 999,
        value = nil,
      }

      if entry.itemID then
        -- The link itself already contains the display name for carried items,
        -- so Name sorting does not depend on asynchronous GetItemInfo.
        if m.name == "" then
          local name = FullInfo(entry.itemID, link)
          m.name = string.lower(name or "")
        end

        local equipLoc = EquipLoc(entry.itemID, link)
        m.rank = SLOT_ORDER[equipLoc] or 999
        m.value = VendorValue(entry.itemID, link)
      end

      entry.meta = m
      return m
    end

    local function PhysicalLess(a, b)
      if a.bag ~= b.bag then return a.bag < b.bag end
      return a.slot < b.slot
    end

    local function OrderedLess(a, b, reverse)
      if reverse then return PhysicalLess(b, a) end
      return PhysicalLess(a, b)
    end

    local function EntryLess(a, b, mode, reverse)
      if mode == "bag" then
        return OrderedLess(a, b, reverse)
      end

      if a.itemID and not b.itemID then return true end
      if not a.itemID and b.itemID then return false end
      if not a.itemID and not b.itemID then
        return OrderedLess(a, b, reverse)
      end

      local am, bm = Meta(a), Meta(b)
      local av, bv

      if mode == "name" then
        av, bv = am.name, bm.name
      elseif mode == "value" then
        if am.value == nil and bm.value ~= nil then return false end
        if am.value ~= nil and bm.value == nil then return true end
        av, bv = am.value or 0, bm.value or 0
      elseif mode == "slot" then
        av, bv = am.rank, bm.rank
      else
        av, bv = 0, 0
      end

      if av ~= bv then
        if reverse then return av > bv end
        return av < bv
      end

      if am.name ~= bm.name then
        if reverse then return am.name > bm.name end
        return am.name < bm.name
      end

      return OrderedLess(a, b, reverse)
    end

    local function SortEntries(entries, mode, reverse)
      if table.getn(entries) < 2 then return end

      table.sort(entries, function(a, b)
        return EntryLess(a, b, mode or "bag", reverse)
      end)
    end

    local function GetSort(id)
      if id == nil then
        return db.generalSort or "bag", db.generalReverse
      end

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
        if reverseOnly then
          db.generalReverse = not db.generalReverse
        else
          db.generalSort = NextSort(db.generalSort)
        end
      else
        local g = FindGroup(id)
        if not g then return end

        if reverseOnly then
          g.reverse = not g.reverse
        else
          g.sort = NextSort(g.sort)
        end
      end

      Relayout()
    end

    local function Backdrop(frame)
      frame:SetBackdrop({
        bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
        tile=true, tileSize=16, edgeSize=16,
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
          local _, index = FindGroup(f.groupID)
          if index then table.remove(db.groups, index) end

          if db.questGroupID == f.groupID then
            db.questGroupID = nil
          end

          for itemID, id in pairs(db.assignments) do
            if id == f.groupID then
              db.assignments[itemID] = GENERAL_OVERRIDE
            end
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
      if type(G.CursorHasItem) ~= "function" then return true end
      return G.CursorHasItem() and true or false
    end

    local function AssignSelected(groupID)
      if not selectedItemID then return false end

      if not CursorStillHasItem() then
        selectedItemID = nil
        return false
      end

      if groupID == nil then
        db.assignments[tostring(selectedItemID)] = GENERAL_OVERRIDE
      else
        db.assignments[tostring(selectedItemID)] = groupID
      end

      if type(G.ClearCursor) == "function" then
        G.ClearCursor()
      end

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
        if h.groupID and arg1 == "RightButton" then
          ShowNameDialog(h.groupID)
        end
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
        h.control = MakeTextButton(
          h, CONTROL_WIDTH, "RIGHT", h.sort, "LEFT", -2,
          "+", "Add Group",
          function()
            if AssignSelected(nil) then return end
            ShowNameDialog(nil)
          end
        )
        h.control:SetScript("OnReceiveDrag", function() AssignSelected(nil) end)
        h.text:SetPoint("RIGHT", h.control, "LEFT", -2, 0)
      else
        h.control = MakeTextButton(
          h, CONTROL_WIDTH, "RIGHT", h.sort, "LEFT", -2,
          "x", "Delete Group",
          function()
            if AssignSelected(h.groupID) then return end
            if h.groupID then ShowDeleteDialog(h.groupID) end
          end
        )
        h.control:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.down = MakeTextButton(
          h, ORDER_WIDTH, "RIGHT", h.control, "LEFT", -1,
          "v", "Move Group Down",
          function()
            if AssignSelected(h.groupID) then return end
            if h.groupID then MoveGroup(h.groupID, 1) end
          end
        )
        h.down:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.up = MakeTextButton(
          h, ORDER_WIDTH, "RIGHT", h.down, "LEFT", -1,
          "^", "Move Group Up",
          function()
            if AssignSelected(h.groupID) then return end
            if h.groupID then MoveGroup(h.groupID, -1) end
          end
        )
        h.up:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.quest = MakeTextButton(
          h, QUEST_WIDTH, "RIGHT", h.up, "LEFT", -1,
          "Q", "Automatic Quest Items",
          function()
            if AssignSelected(h.groupID) then return end
            if h.groupID then ToggleQuestGroup(h.groupID) end
          end
        )
        h.quest:SetScript("OnReceiveDrag", function() AssignSelected(h.groupID) end)

        h.text:SetPoint("RIGHT", h.quest, "LEFT", -2, 0)
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

      if h.quest then
        if db.questGroupID == groupID then
          h.quest:SetTextColor(.2, 1, .2, 1)
        else
          h.quest:SetTextColor(.7, .7, .7, 1)
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
        if arg1 == "LeftButton" then
          AssignSelected(s.groupID)
        end
      end)
      s:SetScript("OnEnter", function()
        if selectedItemID and CursorStillHasItem() then
          if s.groupID then
            Tooltip("Add to Group", "Release/click to classify the selected item here")
          else
            Tooltip("Move to General", "Release/click to keep the selected item in General")
          end
        end
      end)
      s:SetScript("OnLeave", function() GameTooltip:Hide() end)
      s:Show()

      return s
    end

    local function Collect()
      local general, grouped = {}, {}

      for i = 1, table.getn(db.groups) do
        grouped[db.groups[i].id] = {}
      end

      for i = 1, table.getn(pfUI.BACKPACK) do
        local bag = pfUI.BACKPACK[i]
        local count = GetContainerNumSlots(bag)

        if bag == -2 and pfUI.bag.showKeyring == true then
          count = GetKeyRingSize()
        end

        for slot = 1, count do
          local data = pfUI.bags[bag] and pfUI.bags[bag].slots[slot]
          local frame = data and data.frame

          if frame then
            local id = ItemID(bag, slot)
            local entry = { bag=bag, slot=slot, frame=frame, itemID=id }
            local manual = id and db.assignments[tostring(id)]
            local groupID = nil

            if manual ~= nil then
              if manual ~= GENERAL_OVERRIDE and grouped[manual] then
                groupID = manual
              end
            elseif id and db.questGroupID and grouped[db.questGroupID] then
              local link = GetContainerItemLink(bag, slot)
              if IsQuestItem(id, link) then
                groupID = db.questGroupID
              end
            end

            if groupID then
              table.insert(grouped[groupID], entry)
            else
              table.insert(general, entry)
            end
          end
        end
      end

      return general, grouped
    end

    local function HookItemSelection()
      for i = 1, table.getn(pfUI.BACKPACK) do
        local bag = pfUI.BACKPACK[i]
        local count = GetContainerNumSlots(bag)

        if bag == -2 and pfUI.bag.showKeyring == true then
          count = GetKeyRingSize()
        end

        for slot = 1, count do
          local data = pfUI.bags[bag] and pfUI.bags[bag].slots[slot]
          local frame = data and data.frame

          if frame and not frame.bagtweaks_select_hooked then
            local oldMouseDown = frame:GetScript("OnMouseDown")
            local oldDragStart = frame:GetScript("OnDragStart")
            local b, s = bag, slot

            frame:SetScript("OnMouseDown", function()
              if arg1 == "LeftButton" then
                selectedItemID = ItemID(b, s)
              end

              if oldMouseDown then oldMouseDown() end
            end)

            frame:SetScript("OnDragStart", function()
              selectedItemID = ItemID(b, s)

              if oldDragStart then
                oldDragStart()
              else
                PickupContainerItem(b, s)
              end
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
        if C.bagtweaks and C.bagtweaks.show_search == "0" then
          frame.search:Hide()
        else
          frame.search:Show()
        end
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

      if not frame or not frame.button_size or not frame.close or not pfUI.BACKPACK or not pfUI.bags then
        return
      end

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
        local list = grouped[g.id] or {}

        SortEntries(list, g.sort, g.reverse)

        local section, height = LayoutSection(
          g.id, g.name, g.id, list, columns, size, border
        )

        active[g.id] = true
        totalSections = totalSections + height

        section:ClearAllPoints()
        section:SetPoint("BOTTOMLEFT", below, "TOPLEFT", 0, 0)
        section:SetPoint("BOTTOMRIGHT", below, "TOPRIGHT", 0, 0)
        below = section
      end

      for key, h in pairs(headers) do
        if not active[key] then h:Hide() end
      end

      for key, s in pairs(sections) do
        if not active[key] then s:Hide() end
      end

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
        if bag == -2 or (bag >= 0 and bag <= 4) then
          Relayout()
        end
      end
    end

    -- ClassicAPI can return nil for cold item metadata and fires this event
    -- after the cache fills. Re-run the visual sort when that happens.
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

    if pfUI.bag.right then
      Relayout()
    end
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

-- In Vanilla, SavedVariables are not safe to bind at file execution time.
-- Wait for this addon's ADDON_LOADED before taking a local reference to them.
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("VARIABLES_LOADED")
loader:SetScript("OnEvent", function()
  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    Initialize()
    this:UnregisterAllEvents()
  elseif event == "VARIABLES_LOADED" and not initialized then
    if not IsAddOnLoaded or IsAddOnLoaded(ADDON_NAME) then
      Initialize()
      this:UnregisterAllEvents()
    end
  end
end)
