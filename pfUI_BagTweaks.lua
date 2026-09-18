-- pfUI_BagTweaks 0.1.26-dev
-- User-defined visual groups for pfUI unified bags.
-- Groups can be account-wide or character-specific, with an optional default Quest category,
-- can be arranged as one or two columns, and never move physical inventory slots.

if not pfUI then return end

local L = pfUIBagTweaks_L or {}

local ADDON_NAME = "pfUI_BagTweaks"
local initialized = false

local function Initialize()
  if initialized then return end
  initialized = true

  pfUI.bagtweaks = pfUI.bagtweaks or {}

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
      bag = L.SORT_BAG,
      name = L.SORT_NAME,
      value = L.SORT_VENDOR_VALUE,
      slot = L.SORT_CHARACTER_SLOT,
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

    local headers = { backpack={}, bank={} }
    local sections = { backpack={}, bank={} }
    local rowFrames = { backpack={}, bank={} }
    local selectedItemID = nil
    local itemHighlightSection = nil
    local nameDialog, deleteDialog, menu, sortMenu
    local dragPreviews = {}
    local dragInsertLines = {}
    local dragWatcher
    local itemMetaCache = {}
    local questObjectiveItemIDs = {}
    local questObjectiveItemNames = {}
    local questLogStructureSignature = nil
    local questObjectiveScanIncomplete = false
    local questScanBusy = false
    local questScanIgnoreUntil = 0
    local Relayout

    local draggingGroupID = nil
    local draggingView = nil
    local dragTargetID = nil
    local dragTargetSection = nil
    local dragIntent = nil
    local dragSide = nil
    local lastDragStop = 0

    G.pfUIBagTweaksDB = G.pfUIBagTweaksDB or {}
    local db = G.pfUIBagTweaksDB

    -- Only write defaults/migrations when the stored value actually needs it.
    -- Normal logins and relayouts should leave an already-valid DB untouched.
    if db.groups == nil then db.groups = {} end

    local nextID = tonumber(db.nextGroupID)
    if not nextID or nextID < 1 then nextID = 1 end
    if db.nextGroupID ~= nextID then db.nextGroupID = nextID end

    if db.generalSort == nil then db.generalSort = "bag" end
    if db.generalReverse == nil then db.generalReverse = false end

    if db.accountAssignments == nil then
      db.accountAssignments = db.assignments or {}
    end
    if db.assignments ~= nil then db.assignments = nil end

    if db.charAssignments == nil then db.charAssignments = {} end
    if db.rows == nil then db.rows = {} end
    if db.showEmptyCategories == nil then db.showEmptyCategories = true end

    local legacyQuestEnabled = db.questGroupID ~= nil

    local function CharacterKey()
      local realm = GetRealmName and GetRealmName() or ""
      local name = UnitName and UnitName("player") or ""
      return tostring(realm or "") .. "\031" .. tostring(name or "")
    end

    local characterKey = CharacterKey()
    local currentCharAssignments = db.charAssignments[characterKey]

    local function CharAssignments(create)
      if not currentCharAssignments and create then
        currentCharAssignments = {}
        db.charAssignments[characterKey] = currentCharAssignments
      end
      return currentCharAssignments
    end

    local function PruneCurrentCharAssignments()
      if currentCharAssignments and not next(currentCharAssignments) then
        db.charAssignments[characterKey] = nil
        currentCharAssignments = nil
      end
    end

    local function Trim(s)
      s = tostring(s or "")
      s = string.gsub(s, "^%s+", "")
      return string.gsub(s, "%s+$", "")
    end

    local function ViewFrame(view)
      if view == "bank" then return pfUI.bag and pfUI.bag.left end
      return pfUI.bag and pfUI.bag.right
    end

    local function ViewBags(view)
      if view == "bank" then return pfUI.BANK end
      return pfUI.BACKPACK
    end

    local function ViewRowLength(view)
      local value
      if view == "bank" then
        value = C.appearance.bags.bankrowlength
      else
        value = C.appearance.bags.bagrowlength
      end

      local columns = tonumber(value) or 10
      if columns < 1 then columns = 1 end
      return columns
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
      if g.system == "quest" then return db.questEnabled and true or false end
      if g.scope ~= "char" then return true end
      return g.owner == characterKey
    end

    local function RowsEqual(a, b)
      if table.getn(a) ~= table.getn(b) then return false end

      for r = 1, table.getn(a) do
        local ar = a[r]
        local br = b[r]
        if not br or table.getn(ar) ~= table.getn(br) then return false end

        for c = 1, table.getn(ar) do
          if ar[c] ~= br[c] then return false end
        end
      end

      return true
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

      if not RowsEqual(db.rows, clean) then
        db.rows = clean
      end
    end

    local questSystem = nil
    for i = 1, table.getn(db.groups) do
      local g = db.groups[i]

      local id = tonumber(g.id)
      if not id then
        id = db.nextGroupID
        g.id = id
        db.nextGroupID = id + 1
      else
        if g.id ~= id then g.id = id end
        if id >= db.nextGroupID then db.nextGroupID = id + 1 end
      end

      if g.system ~= "quest" and g.name == nil then
        g.name = string.format(L.DEFAULT_GROUP, g.id)
      end
      if g.sort == nil then g.sort = "bag" end
      if g.reverse == nil then g.reverse = false end

      if g.scope == "character" then
        g.scope = "char"
      elseif g.scope ~= "char" and g.scope ~= "account" then
        g.scope = "account"
      end

      if g.scope == "char" and not g.owner then g.owner = characterKey end

      if g.quest then legacyQuestEnabled = true end
      if g.quest ~= nil then g.quest = nil end

      if g.system == "quest" and not questSystem then
        questSystem = g
      end
    end

    if db.questGroupID ~= nil then db.questGroupID = nil end
    if db.questEnabled == nil then
      db.questEnabled = legacyQuestEnabled
    elseif db.questEnabled ~= true and db.questEnabled ~= false then
      db.questEnabled = db.questEnabled and true or false
    end

    if not questSystem then
      questSystem = {
        id=db.nextGroupID,
        sort="bag",
        reverse=false,
        scope="account",
        system="quest",
      }
      db.nextGroupID = db.nextGroupID + 1
      table.insert(db.groups, questSystem)
    else
      if questSystem.scope ~= "account" then questSystem.scope = "account" end
      if questSystem.owner ~= nil then questSystem.owner = nil end
      if questSystem.system ~= "quest" then questSystem.system = "quest" end
    end

    NormalizeRows()

    local function ActiveRows(grouped)
      local result = {}

      for r = 1, table.getn(db.rows) do
        local source = db.rows[r]
        local row = {}

        for c = 1, table.getn(source) do
          local g = FindGroup(source[c])
          if g and IsGroupActive(g) then
            local visible = db.showEmptyCategories ~= false
            if not visible then
              local items = grouped and grouped[g.id]
              visible = items and table.getn(items) > 0
            end
            if visible then table.insert(row, g.id) end
          end
        end

        if table.getn(row) > 0 then table.insert(result, row) end
      end

      return result
    end

    local function CleanAssignments(assignments)
      for itemID, groupID in pairs(assignments) do
        local normalized = tonumber(groupID)
        if normalized == nil then normalized = GENERAL_OVERRIDE end
        if normalized ~= GENERAL_OVERRIDE and not GroupExists(normalized) then
          normalized = GENERAL_OVERRIDE
        end
        if normalized ~= groupID then assignments[itemID] = normalized end
      end
    end

    local function CleanState()
      NormalizeRows()
      CleanAssignments(db.accountAssignments)

      for key, assignments in pairs(db.charAssignments) do
        CleanAssignments(assignments)
        if not next(assignments) then
          db.charAssignments[key] = nil
          if key == characterKey then currentCharAssignments = nil end
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
      if not g or g.system then return end

      local ca = CharAssignments(false)

      if scope == "account" and g.scope == "char" then
        if ca then
          for itemID, groupID in pairs(ca) do
            if groupID == id then
              db.accountAssignments[itemID] = id
              ca[itemID] = nil
            end
          end
        end

        g.scope = "account"
        g.owner = nil
        PruneCurrentCharAssignments()
      elseif scope == "char" and g.scope ~= "char" then
        for itemID, groupID in pairs(db.accountAssignments) do
          if groupID == id then
            if not ca then ca = CharAssignments(true) end
            if ca[itemID] == nil then ca[itemID] = id end
            db.accountAssignments[itemID] = nil
          end
        end

        g.scope = "char"
        g.owner = characterKey
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
      local cacheKey = link or (id and tostring(id))
      if cacheKey and itemMetaCache[cacheKey] then return itemMetaCache[cacheKey] end

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

      local meta = {
        name = name or "",
        rank = SLOT_ORDER[equipLoc or ""] or 999,
        equipLoc = equipLoc or "",
        itemType = itemType,
        classID = classID,
        value = value,
      }

      if cacheKey and meta.name ~= "" and meta.itemType ~= nil then
        itemMetaCache[cacheKey] = meta
      end

      return meta
    end

    local function IsQuestMetadata(meta)
      if not meta then return false end
      if meta.classID ~= nil then return meta.classID == QUEST_CLASS_ID end
      if G.ITEM_CLASS_QUESTITEM and meta.itemType == G.ITEM_CLASS_QUESTITEM then return true end
      if G.ITEM_CLASS_QUEST and meta.itemType == G.ITEM_CLASS_QUEST then return true end
      return meta.itemType == L.ITEM_CLASS_QUEST
    end

    local function SetEquals(a, b)
      for key in pairs(a) do
        if not b[key] then return false end
      end
      for key in pairs(b) do
        if not a[key] then return false end
      end
      return true
    end

    local function QuestObjectiveItemName(text)
      if not text then return nil end

      local label = tostring(text)
      label = string.gsub(label, "%s*:%s*%d+%s*/%s*%d+%s*$", "")
      label = string.gsub(label, "^%s*%d+%s*/%s*%d+%s+", "")
      label = string.lower(Trim(label))

      if label == "" then return nil end
      return label
    end

    local function QuestLogStructureSignature()
      if type(GetNumQuestLogEntries) ~= "function" or type(GetQuestLogTitle) ~= "function" then
        return ""
      end

      local entries, quests = GetNumQuestLogEntries()
      entries = entries or 0

      local parts = { tostring(entries), tostring(quests or 0) }
      for index = 1, entries do
        local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)
        if title then
          table.insert(parts,
            (isHeader and "H" or "Q") ..
            (isCollapsed and "1" or "0") ..
            ":" .. tostring(title))
        end
      end

      return table.concat(parts, "\031")
    end

    local function QuestHeaderKey(title, occurrence)
      return tostring(title or "") .. "\031" .. tostring(occurrence or 1)
    end

    local function CaptureCollapsedQuestHeaders()
      local collapsed = {}
      local occurrences = {}
      local anyCollapsed = false
      local entries = GetNumQuestLogEntries() or 0

      for index = 1, entries do
        local title, _, _, isHeader, isCollapsed = GetQuestLogTitle(index)
        if title and isHeader then
          local count = (occurrences[title] or 0) + 1
          occurrences[title] = count

          if isCollapsed then
            collapsed[QuestHeaderKey(title, count)] = true
            anyCollapsed = true
          end
        end
      end

      return collapsed, anyCollapsed
    end

    local function ScanQuestObjectiveItems(collapsedHeaders)
      local scannedIDs = {}
      local scannedNames = {}
      local restore = {}
      local occurrences = {}
      local incomplete = false
      local entries = GetNumQuestLogEntries() or 0

      for questIndex = 1, entries do
        local title, _, _, isHeader = GetQuestLogTitle(questIndex)

        if title and isHeader then
          local count = (occurrences[title] or 0) + 1
          occurrences[title] = count

          if collapsedHeaders and collapsedHeaders[QuestHeaderKey(title, count)] then
            table.insert(restore, questIndex)
          end
        elseif title then
          local objectives = GetNumQuestLeaderBoards(questIndex) or 0

          for objectiveIndex = 1, objectives do
            local text, objectiveType = GetQuestLogLeaderBoard(objectiveIndex, questIndex)

            if objectiveType == "item" then
              local name = QuestObjectiveItemName(text)
              if name then
                scannedNames[name] = true
              else
                incomplete = true
              end

              -- ClassicAPI is optional. Vanilla name matching above remains the
              -- dependency-free path; this only adds exact IDs when available.
              if type(G.GetQuestLogLeaderBoardID) == "function" then
                local ok, id, kind = pcall(G.GetQuestLogLeaderBoardID, objectiveIndex, questIndex)
                id = ok and tonumber(id) or nil
                if id and (kind == nil or kind == "item") then scannedIDs[id] = true end
              end
            end
          end
        end
      end

      return scannedIDs, scannedNames, restore, incomplete
    end

    local function RefreshQuestObjectiveItems()
      if questScanBusy then return false end
      questScanBusy = true

      local scannedIDs = {}
      local scannedNames = {}
      local incomplete = false

      if db.questEnabled and type(GetNumQuestLogEntries) == "function" and
         type(GetQuestLogTitle) == "function" and
         type(GetNumQuestLeaderBoards) == "function" and
         type(GetQuestLogLeaderBoard) == "function" then
        local collapsedHeaders, anyCollapsed = CaptureCollapsedQuestHeaders()
        local canRestore = type(ExpandQuestHeader) == "function" and
          type(CollapseQuestHeader) == "function"

        if anyCollapsed and canRestore then
          -- Vanilla removes child quest rows from the visible log while a
          -- header is collapsed. Expand all only for the duration of this scan,
          -- then restore the user's exact collapsed headers bottom-to-top.
          questScanIgnoreUntil = (GetTime and GetTime() or 0) + .10
          pcall(ExpandQuestHeader, 0)

          local restore
          scannedIDs, scannedNames, restore, incomplete =
            ScanQuestObjectiveItems(collapsedHeaders)

          for i = table.getn(restore), 1, -1 do
            pcall(CollapseQuestHeader, restore[i])
          end

          questScanIgnoreUntil = (GetTime and GetTime() or 0) + .10
        else
          scannedIDs, scannedNames, _, incomplete = ScanQuestObjectiveItems(nil)
        end
      end

      local changed = not SetEquals(questObjectiveItemIDs, scannedIDs) or
        not SetEquals(questObjectiveItemNames, scannedNames)

      questObjectiveItemIDs = scannedIDs
      questObjectiveItemNames = scannedNames
      questObjectiveScanIncomplete = incomplete
      questLogStructureSignature = QuestLogStructureSignature()
      questScanBusy = false
      return changed
    end

    local function IsQuestObjectiveItem(id, meta)
      if id and questObjectiveItemIDs[id] then return true end
      if meta and meta.name and meta.name ~= "" and questObjectiveItemNames[meta.name] then
        return true
      end
      return false
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
      for _, frame in pairs(dragPreviews) do frame:Hide() end
      for _, frame in pairs(dragInsertLines) do frame:Hide() end
    end

    local function EnsureDragVisuals(view)
      local parent = ViewFrame(view)
      if not parent then return nil, nil end

      local baseLevel = parent:GetFrameLevel() or 0
      local preview = dragPreviews[view]
      local insertLine = dragInsertLines[view]

      if not preview then
        preview = CreateFrame("Frame", nil, parent)
        preview:EnableMouse(false)
        preview.texture = preview:CreateTexture(nil, "BACKGROUND")
        preview.texture:SetAllPoints(preview)
        preview.texture:SetTexture(1, 1, 1, 1)
        preview.texture:SetVertexColor(.15, 1, .15, .20)
        preview:Hide()
        dragPreviews[view] = preview
      end
      preview:SetFrameLevel(baseLevel + 2)

      if not insertLine then
        insertLine = CreateFrame("Frame", nil, parent)
        insertLine:EnableMouse(false)
        insertLine.texture = insertLine:CreateTexture(nil, "ARTWORK")
        insertLine.texture:SetAllPoints(insertLine)
        insertLine.texture:SetTexture(1, 1, 1, 1)
        insertLine.texture:SetVertexColor(.15, 1, .15, .95)
        insertLine:SetHeight(INSERT_LINE_HEIGHT)
        insertLine:Hide()
        dragInsertLines[view] = insertLine
      end
      insertLine:SetFrameLevel(baseLevel + 6)

      return preview, insertLine
    end

    local function ShowNameDialog(groupID)
      if groupID then
        local group = FindGroup(groupID)
        if group and group.system then return end
      end

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
        f.ok:SetText(L.OK)

        f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.cancel:SetWidth(70)
        f.cancel:SetHeight(20)
        f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 8)
        f.cancel:SetText(L.CANCEL)

        local function Accept()
          local name = Trim(f.edit:GetText())
          if name == "" then return end

          if f.groupID then
            local g = FindGroup(f.groupID)
            if g and not g.system then g.name = name end
          else
            local id = db.nextGroupID
            table.insert(db.groups, {
              id=id,
              name=name,
              sort="bag",
              reverse=false,
              scope="account",
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
        nameDialog.title:SetText(L.RENAME_CATEGORY)
        nameDialog.edit:SetText(g.name)
      else
        nameDialog.title:SetText(L.NEW_CATEGORY)
        nameDialog.edit:SetText("")
      end

      nameDialog:Show()
      nameDialog.edit:SetFocus()
      nameDialog.edit:HighlightText()
    end

    local function DeleteGroup(groupID)
      local g, index = FindGroup(groupID)
      if not g or not index or g.system then return end

      for itemID, assigned in pairs(db.accountAssignments) do
        if assigned == groupID then db.accountAssignments[itemID] = GENERAL_OVERRIDE end
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
      if not g or g.system then return end

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
        f.ok:SetText(L.DELETE)

        f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.cancel:SetWidth(80)
        f.cancel:SetHeight(20)
        f.cancel:SetPoint("BOTTOMLEFT", f, "BOTTOM", 4, 8)
        f.cancel:SetText(L.CANCEL)

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
      deleteDialog.text:SetText(string.format(L.DELETE_PROMPT, tostring(g.name)))
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
      local ca = CharAssignments(false)

      if groupID == nil then
        if ca and ca[itemKey] ~= nil then
          ca[itemKey] = GENERAL_OVERRIDE
        elseif db.accountAssignments[itemKey] ~= nil then
          db.accountAssignments[itemKey] = GENERAL_OVERRIDE
        else
          ca = ca or CharAssignments(true)
          ca[itemKey] = GENERAL_OVERRIDE
        end
      else
        local g = FindGroup(groupID)
        if not g or not IsGroupActive(g) then return false end

        if g.scope == "char" then
          ca = ca or CharAssignments(true)
          ca[itemKey] = groupID
        else
          db.accountAssignments[itemKey] = groupID
          if ca then ca[itemKey] = nil end
        end
      end

      PruneCurrentCharAssignments()

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
      reverseButton:SetText((reverse and "[x] " or "[ ] ") .. L.REVERSE)
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
        add:SetText(L.NEW_CATEGORY)
        add:SetScript("OnClick", function()
          HideMenus()
          ShowNameDialog(nil)
        end)
        add:Show()

        local sorting = MenuButton(menu, 2)
        local mode = GetSort(nil)
        sorting:SetText(string.format(L.SORTING, SORT_LABEL[mode]))
        sorting:SetScript("OnClick", function()
          ShowSortMenu(menu, nil)
        end)
        sorting:Show()

        for i = 3, table.getn(menu.buttons or {}) do menu.buttons[i]:Hide() end
      else
        local g = FindGroup(groupID)
        if not g then return end

        if g.system == "quest" then
          ConfigureMenuFrame(menu, 1)

          local sorting = MenuButton(menu, 1)
          sorting:SetText(string.format(L.SORTING, SORT_LABEL[g.sort or "bag"]))
          sorting:SetScript("OnClick", function()
            ShowSortMenu(menu, menu.groupID)
          end)
          sorting:Show()

          for i = 2, table.getn(menu.buttons or {}) do menu.buttons[i]:Hide() end
        else
          ConfigureMenuFrame(menu, 5)

          local rename = MenuButton(menu, 1)
          rename:SetText(L.RENAME_CATEGORY)
          rename:SetScript("OnClick", function()
            local id = menu.groupID
            HideMenus()
            ShowNameDialog(id)
          end)
          rename:Show()

          local account = MenuButton(menu, 2)
          account:SetText((g.scope ~= "char" and "[x] " or "[ ] ") .. L.ACCOUNT_WIDE)
          account:SetScript("OnClick", function()
            local id = menu.groupID
            HideMenus()
            ToggleScope(id, "account")
          end)
          account:Show()

          local character = MenuButton(menu, 3)
          character:SetText((g.scope == "char" and "[x] " or "[ ] ") .. L.PER_CHARACTER)
          character:SetScript("OnClick", function()
            local id = menu.groupID
            HideMenus()
            ToggleScope(id, "char")
          end)
          character:Show()

          local sorting = MenuButton(menu, 4)
          sorting:SetText(string.format(L.SORTING, SORT_LABEL[g.sort or "bag"]))
          sorting:SetScript("OnClick", function()
            ShowSortMenu(menu, menu.groupID)
          end)
          sorting:Show()

          local delete = MenuButton(menu, 5)
          delete:SetText("|cffff6666" .. L.DELETE_CATEGORY .. "|r")
          delete:SetScript("OnClick", function()
            local id = menu.groupID
            HideMenus()
            ShowDeleteDialog(id)
          end)
          delete:Show()

          for i = 6, table.getn(menu.buttons or {}) do menu.buttons[i]:Hide() end
        end
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
      local viewSections = sections[draggingView] or {}
      for _, s in pairs(viewSections) do
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
      local preview, insertLine = EnsureDragVisuals(draggingView)
      if not preview or not insertLine then return end
      preview:Hide()

      local row = RowForSection(section)
      if not row then
        insertLine:Hide()
        return
      end

      insertLine:ClearAllPoints()
      if before then
        insertLine:SetPoint("BOTTOMLEFT", row, "TOPLEFT", 0, 0)
        insertLine:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", 0, 0)
      else
        insertLine:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
        insertLine:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 0)
      end
      insertLine:Show()
    end

    local function ShowPairPreview(section, side)
      local preview, insertLine = EnsureDragVisuals(draggingView)
      if not preview or not insertLine then return end
      insertLine:Hide()

      local row = RowForSection(section)
      if not row then
        preview:Hide()
        return
      end

      preview:ClearAllPoints()
      if side == "left" then
        preview:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        preview:SetPoint("BOTTOMRIGHT", row, "BOTTOM", -1, 0)
      else
        preview:SetPoint("TOPLEFT", row, "TOP", 1, 0)
        preview:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
      end
      preview:Show()
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

    local function BeginGroupDrag(id, view)
      if selectedItemID and CursorStillHasItem() then return end
      if not id or not view then return end

      draggingGroupID = id
      draggingView = view
      dragTargetID = nil
      dragTargetSection = nil
      dragIntent = nil
      dragSide = nil
      HideItemHighlight()
      HideMenus()
      EnsureDragVisuals(view)

      if not dragWatcher then
        dragWatcher = CreateFrame("Frame")
        dragWatcher:SetScript("OnUpdate", function()
          if draggingGroupID then UpdateDragVisual() end
        end)
        dragWatcher:Hide()
      end
      dragWatcher:Show()
    end

    local function EndGroupDrag()
      if not draggingGroupID then return end

      UpdateDragVisual()

      local source = draggingGroupID
      local target = dragTargetID
      local intent = dragIntent
      local side = dragSide

      draggingGroupID = nil
      draggingView = nil
      dragTargetID = nil
      dragTargetSection = nil
      dragIntent = nil
      dragSide = nil
      lastDragStop = GetTime and GetTime() or 0
      HideDragVisuals()
      if dragWatcher then dragWatcher:Hide() end

      if target and intent then PlaceDraggedGroup(source, target, intent, side) end
    end

    local function Header(view, key, name, groupID)
      local viewHeaders = headers[view]
      local h = viewHeaders[key]
      local parent = ViewFrame(view)
      if not parent then return nil end

      if not h then
        h = CreateFrame("Button", nil, parent)
        h:SetHeight(HEADER_HEIGHT)
        h:EnableMouse(1)
        h:RegisterForDrag("LeftButton")
        h.bagtweaks_header = true
        h.bagtweaks_view = view

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
          if h.groupID then BeginGroupDrag(h.groupID, h.bagtweaks_view) end
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

          local section = sections[h.bagtweaks_view][SectionKeyForGroupID(h.groupID)]
          if selectedItemID and CursorStillHasItem() then
            ShowItemHighlight(section)
            return
          end

          if h.groupID then
            local g = FindGroup(h.groupID)
            local mode = g and SORT_LABEL[g.sort or "bag"] or ""
            if g and g.system == "quest" then
              Tooltip(L.QUEST, string.format(L.QUEST_TOOLTIP, mode))
            else
              local scope = g and g.scope == "char" and L.PER_CHARACTER or L.ACCOUNT_WIDE
              Tooltip(h.text:GetText(), string.format(L.CATEGORY_TOOLTIP, scope, mode))
            end
          else
            Tooltip(L.GENERAL, L.GENERAL_TOOLTIP)
          end
        end)

        h:SetScript("OnLeave", function()
          HideItemHighlight()
          GameTooltip:Hide()
        end)

        viewHeaders[key] = h
      end

      h.bagtweaks_view = view
      h.groupID = groupID
      h.text:SetText(name)
      h:Show()
      return h
    end

    local function Section(view, key, groupID)
      local viewSections = sections[view]
      local s = viewSections[key]
      local parent = ViewFrame(view)
      if not parent then return nil end

      if not s then
        s = CreateFrame("Frame", nil, parent)
        s.bagtweaks_view = view
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
              Tooltip(L.ADD_TO_CATEGORY, L.ADD_TO_CATEGORY_TOOLTIP)
            else
              Tooltip(L.MOVE_TO_GENERAL, L.MOVE_TO_GENERAL_TOOLTIP)
            end
          end
        end)

        s:SetScript("OnLeave", function()
          if itemHighlightSection == s then HideItemHighlight() end
          GameTooltip:Hide()
        end)

        viewSections[key] = s
      end

      s.bagtweaks_view = view
      s.groupID = groupID
      s:Show()
      return s
    end

    local function ActiveQuestGroupID()
      if not db.questEnabled or not questSystem then return nil end
      return questSystem.id
    end

    local EMPTY_META = {
      name="",
      rank=999,
      equipLoc="",
      itemType=nil,
      classID=nil,
      value=nil,
    }

    local function GroupDisplayName(g)
      if not g then return L.CATEGORY end
      if g.system == "quest" then return L.QUEST end
      return g.name or L.CATEGORY
    end

    local function Collect(view)
      local general = {}
      local grouped = {}
      local questGroupID = ActiveQuestGroupID()
      local ca = CharAssignments(false)
      local ordinal = 0
      local bags = ViewBags(view) or {}

      for i = 1, table.getn(db.groups) do
        local g = db.groups[i]
        if IsGroupActive(g) then grouped[g.id] = {} end
      end

      for i = 1, table.getn(bags) do
        local bag = bags[i]
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
              meta = EMPTY_META
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
              local itemKey = tostring(id)
              local manual = ca and ca[itemKey]
              if manual == nil then manual = db.accountAssignments[itemKey] end

              if manual ~= nil then
                if manual ~= GENERAL_OVERRIDE and grouped[manual] then groupID = manual end
              elseif questGroupID and grouped[questGroupID] and
                     (IsQuestMetadata(meta) or IsQuestObjectiveItem(id, meta)) then
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

    local function HookItemSelection(view)
      local bags = ViewBags(view) or {}

      for i = 1, table.getn(bags) do
        local bag = bags[i]
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

    local function LayoutSection(view, key, name, groupID, list, columns, size, border)
      if columns < 1 then columns = 1 end

      local spacing = border * 3
      local pitch = size + spacing
      local rows = RowsFor(list, columns)
      local wantedHeight = HEADER_HEIGHT + border + rows * pitch + border
      local s = Section(view, key, groupID)
      local h = Header(view, key, name, groupID)
      local parent = ViewFrame(view)
      if not s or not h or not parent then return nil, 0 end
      local baseLevel = parent:GetFrameLevel() or 0

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

    local function RowFrame(view, index)
      local viewRows = rowFrames[view]
      local parent = ViewFrame(view)
      if not parent then return nil end

      if not viewRows[index] then viewRows[index] = CreateFrame("Frame", nil, parent) end
      viewRows[index]:Show()
      return viewRows[index]
    end

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

    local function RelayoutView(view)
      local frame = ViewFrame(view)
      local bags = ViewBags(view)
      if not frame or not frame.button_size or not frame.close or not bags or not pfUI.bags then return end

      HookItemSelection(view)
      StabilizeBottomAnchor(frame)

      local _, border = GetBorderSize("bags")
      border = border or 1

      local fullColumns = ViewRowLength(view)
      local halfColumns = math.floor(fullColumns / 2)
      if halfColumns < 1 then halfColumns = 1 end

      local size = frame.button_size
      local topSpace = frame.close:GetHeight() + border * 2
      local panel = pfUI.panel and (view == "bank" and pfUI.panel.left or pfUI.panel.right)
      local bottomSpace = panel and panel:IsShown()
        and panel:GetHeight() + border
        or 16 + border

      local general, grouped = Collect(view)
      local active = {}
      local totalHeight = 0
      local viewRows = rowFrames[view]
      local viewHeaders = headers[view]
      local viewSections = sections[view]

      SortEntries(general, db.generalSort, db.generalReverse)

      local generalSection, generalHeight = LayoutSection(
        view, "general", L.GENERAL, nil, general, fullColumns, size, border
      )
      if not generalSection then return end

      active["general"] = true
      totalHeight = totalHeight + generalHeight

      generalSection:ClearAllPoints()
      generalSection:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, bottomSpace)
      generalSection:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomSpace)
      generalSection:SetHeight(generalHeight)
      generalSection.bagtweaks_rowFrame = generalSection

      local below = generalSection
      local activeRows = ActiveRows(grouped)
      local visibleRowCount = table.getn(activeRows)
      local rowFrameIndex = 0

      for r = visibleRowCount, 1, -1 do
        local row = activeRows[r]
        rowFrameIndex = rowFrameIndex + 1

        local rf = RowFrame(view, rowFrameIndex)
        local leftID = row[1]
        local rightID = row[2]
        local leftGroup = FindGroup(leftID)
        local rightGroup = rightID and FindGroup(rightID) or nil

        local leftList = grouped[leftID] or {}
        local rightList = rightID and (grouped[rightID] or {}) or nil

        SortEntries(leftList, leftGroup and leftGroup.sort or "bag", leftGroup and leftGroup.reverse or false)
        if rightGroup then SortEntries(rightList, rightGroup.sort or "bag", rightGroup.reverse) end

        local leftSection, leftHeight = LayoutSection(
          view,
          leftID,
          GroupDisplayName(leftGroup),
          leftID,
          leftList,
          rightID and halfColumns or fullColumns,
          size,
          border
        )

        local rightSection, rightHeight
        if rightID and rightGroup then
          rightSection, rightHeight = LayoutSection(
            view,
            rightID,
            GroupDisplayName(rightGroup),
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

      for i = rowFrameIndex + 1, table.getn(viewRows) do viewRows[i]:Hide() end
      for key, h in pairs(viewHeaders) do if not active[key] then h:Hide() end end
      for key, s in pairs(viewSections) do
        if not active[key] then
          if itemHighlightSection == s then HideItemHighlight() end
          s:Hide()
        end
      end

      frame:SetHeight(bottomSpace + totalHeight + topSpace + border * 2)
      if draggingGroupID and draggingView == view then UpdateDragVisual() end
    end

    Relayout = function()
      RelayoutView("backpack")
      RelayoutView("bank")
    end

    local relayoutDriver
    local relayoutPending = false

    local function RequestRelayout()
      if relayoutPending then return end
      relayoutPending = true

      if not relayoutDriver then
        relayoutDriver = CreateFrame("Frame")
        relayoutDriver:SetScript("OnUpdate", function()
          this:Hide()
          relayoutPending = false
          if Relayout then Relayout() end
        end)
        relayoutDriver:Hide()
      end

      relayoutDriver:Show()
    end

    pfUI.bagtweaks.Relayout = Relayout
    pfUI.bagtweaks.ShowGroupEditor = ShowNameDialog
    pfUI.bagtweaks.HideMenus = HideMenus
    pfUI.bagtweaks.ToggleQuestCategory = function()
      db.questEnabled = not db.questEnabled
      RefreshQuestObjectiveItems()
      Relayout()
    end
    pfUI.bagtweaks.QuestEnabled = function()
      return db.questEnabled and true or false
    end
    pfUI.bagtweaks.ToggleEmptyCategories = function()
      db.showEmptyCategories = not db.showEmptyCategories
      Relayout()
    end
    pfUI.bagtweaks.ShowEmptyCategories = function()
      return db.showEmptyCategories ~= false
    end

    pfUI.bag.CreateBags = function(self, object)
      oldCreateBags(self, object)
      if object == "bank" then
        RelayoutView("bank")
      else
        RelayoutView("backpack")
      end
    end

    if oldUpdateBag then
      pfUI.bag.UpdateBag = function(self, bag)
        oldUpdateBag(self, bag)
        if bag and bag >= -2 and bag <= 11 then RequestRelayout() end
      end
    end

    local function HookFrameHide(frame)
      if not frame or frame.bagtweaks_menu_hide_hooked then return end

      local oldOnHide = frame:GetScript("OnHide")
      frame:SetScript("OnHide", function()
        if oldOnHide then oldOnHide() end
        HideMenus()
        HideItemHighlight()
        if draggingView == "bank" and frame == pfUI.bag.left then EndGroupDrag() end
      end)
      frame.bagtweaks_menu_hide_hooked = true
    end

    HookFrameHide(pfUI.bag.right)
    HookFrameHide(pfUI.bag.left)

    if G.C_Item and type(G.C_Item.GetItemInfo) == "function" then
      local itemDataWatcher = CreateFrame("Frame")
      itemDataWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
      itemDataWatcher:SetScript("OnEvent", function()
        itemMetaCache = {}
        RequestRelayout()
      end)
      pfUI.bagtweaks.itemDataWatcher = itemDataWatcher
    end

    local questLogWatcher = CreateFrame("Frame")
    questLogWatcher:RegisterEvent("QUEST_LOG_UPDATE")
    questLogWatcher:SetScript("OnEvent", function()
      if questScanBusy then return end

      local now = GetTime and GetTime() or 0
      if now < questScanIgnoreUntil then return end

      local signature = QuestLogStructureSignature()
      if signature == questLogStructureSignature and not questObjectiveScanIncomplete then
        return
      end

      if RefreshQuestObjectiveItems() then RequestRelayout() end
    end)
    pfUI.bagtweaks.questLogWatcher = questLogWatcher

    pfUI.bag.bagtweaks_hooked = true
    CleanState()
    RefreshQuestObjectiveItems()
    if pfUI.bag.right then Relayout() end
  end)

  if pfUI.gui and pfUI.gui.CreateGUIEntry and pfUI.gui.CreateConfig then
    local thirdParty = "Thirdparty"
    if pfUI.env and pfUI.env.T and pfUI.env.T["Thirdparty"] then
      thirdParty = pfUI.env.T["Thirdparty"]
    end

    pfUI.gui.CreateGUIEntry(thirdParty, L.PLUGIN_NAME, function()
      pfUI.gui.CreateConfig(nil, L.PLUGIN_HEADER, nil, nil, "header")
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
-- Labelled bag toolbar
-- ---------------------------------------------------------------------------

local TOOLBAR_UPDATE_INTERVAL = .20
local TOOLBAR_MENU_ROW_HEIGHT = 18
local TOOLBAR_SEARCH_GAP = 2

local toolbarState = {
  initialized = false,
  searchOpen = false,
  activeMode = nil,
  castBusy = false,
  rearmAt = nil,
  lastUpdate = 0,
  buttons = {},
  native = {},
  menu = nil,
  menuOwner = nil,
  baseOnHide = nil,
  onHideWrapper = nil,
}

local bankToolbarState = {
  initialized = false,
  searchOpen = false,
  buttons = {},
  native = {},
  search = nil,
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

local function ToolbarMetrics(bag)
  local close = bag and bag.close
  local height = close and close:GetHeight() or 12
  local border = 1
  local topInset = 1

  if close and close.GetPoint then
    local _, _, _, x, y = close:GetPoint(1)
    if x and x ~= 0 then border = math.abs(x) end
    if y and y ~= 0 then topInset = math.abs(y) end
  end

  if border < 1 then border = 1 end
  if topInset < 1 then topInset = border end

  return height, border, border * 3, topInset
end

local function ToolbarCreateBackdrop(frame, border)
  if frame.bagtweaks_toolbar_backdrop then return end

  if pfUI.api and type(pfUI.api.CreateBackdrop) == "function" then
    pfUI.api.CreateBackdrop(frame, border)
  else
    frame:SetBackdrop({
      bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
      tile=true,
      tileSize=16,
      edgeSize=8,
      insets={left=2,right=2,top=2,bottom=2},
    })
    frame:SetBackdropColor(0, 0, 0, .85)
    frame.bagtweaks_toolbar_direct_backdrop = true
  end

  frame.bagtweaks_toolbar_backdrop = true
end

local function ToolbarSetBorderColor(frame, r, g, b, a)
  if frame.backdrop and frame.backdrop.SetBackdropBorderColor then
    frame.backdrop:SetBackdropBorderColor(r, g, b, a or 1)
  elseif frame.SetBackdropBorderColor then
    frame:SetBackdropBorderColor(r, g, b, a or 1)
  end
end

local function ToolbarSetHover(frame, hover)
  if hover then
    ToolbarSetBorderColor(frame, 1, 1, .25, 1)
    if frame.bagtweaks_toolbar_label then
      frame.bagtweaks_toolbar_label:SetTextColor(1, 1, .25, 1)
    end
  else
    ToolbarSetBorderColor(frame, .25, .25, .25, 1)
    if frame.bagtweaks_toolbar_label then
      frame.bagtweaks_toolbar_label:SetTextColor(.82, .82, .82, 1)
    end
  end
end

local function ToolbarHideIcon(frame)
  if not frame then return end
  if frame.texture and frame.texture.Hide then frame.texture:Hide() end
  if frame.GetNormalTexture then
    local texture = frame:GetNormalTexture()
    if texture and texture.SetAlpha then texture:SetAlpha(0) end
  end
end

local function ToolbarEnsureLabel(button, text)
  local created = false

  if not button.bagtweaks_toolbar_label then
    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", button, "LEFT", 2, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -2, 0)
    label:SetJustifyH("CENTER")
    button.bagtweaks_toolbar_label = label
    created = true
  end

  local label = button.bagtweaks_toolbar_label
  label:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, ToolbarFontSize(), "OUTLINE")
  label:SetText(text)
  if created then label:SetTextColor(.82, .82, .82, 1) end
  label:Show()
  ToolbarHideIcon(button)
end

local function ToolbarEnsureActiveOverlay(button)
  if not button or button.bagtweaks_active_overlay then return end
  local tex = button:CreateTexture(nil, "ARTWORK")
  tex:SetAllPoints(button)
  tex:SetTexture(1, 1, 1, 1)
  tex:SetVertexColor(.15, 1, .15, .18)
  tex:Hide()
  button.bagtweaks_active_overlay = tex
end

local function ToolbarHideMenu()
  if toolbarState.menu then toolbarState.menu:Hide() end
  toolbarState.menuOwner = nil
end

local function ToolbarSetActive(button, active)
  if not button then return end
  ToolbarEnsureActiveOverlay(button)
  if active then button.bagtweaks_active_overlay:Show()
  else button.bagtweaks_active_overlay:Hide() end
end

local function ToolbarUpdateActiveVisuals()
  ToolbarSetActive(toolbarState.buttons.search, toolbarState.searchOpen)

  local questEnabled = false
  if pfUI.bagtweaks and pfUI.bagtweaks.QuestEnabled then
    questEnabled = pfUI.bagtweaks.QuestEnabled()
  end

  ToolbarSetActive(toolbarState.buttons.quest, questEnabled)
  ToolbarSetActive(toolbarState.buttons.disenchant, toolbarState.activeMode == "disenchant")
  ToolbarSetActive(toolbarState.buttons.picklock, toolbarState.activeMode == "picklock")
  ToolbarSetActive(bankToolbarState.buttons.search, bankToolbarState.searchOpen)
  ToolbarSetActive(bankToolbarState.buttons.quest, questEnabled)
end

local function ToolbarApplySearchState()
  local bag = pfUI.bag and pfUI.bag.right
  local search = bag and bag.search
  if not search then return end

  local _, border = ToolbarMetrics(bag)

  search:Show()
  search:ClearAllPoints()
  search:SetPoint("BOTTOMLEFT", bag, "TOPLEFT", border, TOOLBAR_SEARCH_GAP)
  search:SetPoint("BOTTOMRIGHT", bag, "TOPRIGHT", -border, TOOLBAR_SEARCH_GAP)
  search:SetHeight(bag.close and bag.close:GetHeight() or 12)

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
  ToolbarHideMenu()
  toolbarState.searchOpen = not toolbarState.searchOpen
  ToolbarApplySearchState()

  local bag = pfUI.bag and pfUI.bag.right
  if toolbarState.searchOpen and bag and bag.search and bag.search.edit then
    bag.search.edit:SetFocus()
  end
end

local function ToolbarAddCategory()
  ToolbarHideMenu()
  if pfUI.bagtweaks and pfUI.bagtweaks.ShowGroupEditor then
    pfUI.bagtweaks.ShowGroupEditor(nil)
  end
end

local function ToolbarToggleQuest()
  ToolbarHideMenu()
  if pfUI.bagtweaks and pfUI.bagtweaks.ToggleQuestCategory then
    pfUI.bagtweaks.ToggleQuestCategory()
  end
  ToolbarUpdateActiveVisuals()
end

local function ToolbarCancelTargeting()
  if SpellIsTargeting and SpellIsTargeting() and SpellStopTargeting then
    SpellStopTargeting()
  end
end

local function ToolbarModeButton(mode)
  local bag = pfUI.bag and pfUI.bag.right
  if not bag then return nil end
  if mode == "disenchant" then return bag.disenchant end
  if mode == "picklock" then return bag.picklock end
  return nil
end

local function ToolbarInvokeNativeMode(mode)
  local button = ToolbarModeButton(mode)
  if not button or (button:GetID() or 0) <= 0 or not button.Click then return false end
  button:Click()
  return true
end

local function ToolbarDisablePersistentMode()
  toolbarState.activeMode = nil
  toolbarState.castBusy = false
  toolbarState.rearmAt = nil
  ToolbarCancelTargeting()
  ToolbarUpdateActiveVisuals()
end

local function ToolbarToggleDisenchantMode()
  ToolbarHideMenu()

  if toolbarState.activeMode == "disenchant" then
    ToolbarDisablePersistentMode()
    return
  end

  ToolbarCancelTargeting()
  toolbarState.activeMode = "disenchant"
  toolbarState.castBusy = false
  toolbarState.rearmAt = nil
  ToolbarUpdateActiveVisuals()
end

local function ToolbarTogglePickLockMode()
  ToolbarHideMenu()

  if toolbarState.activeMode == "picklock" then
    ToolbarDisablePersistentMode()
    return
  end

  ToolbarCancelTargeting()
  toolbarState.activeMode = "picklock"
  toolbarState.castBusy = false
  toolbarState.rearmAt = nil
  ToolbarUpdateActiveVisuals()

  if not ToolbarInvokeNativeMode("picklock") then
    ToolbarDisablePersistentMode()
  end
end

local function ToolbarPlayerIsCasting()
  return CastingBarFrame and (CastingBarFrame.casting or CastingBarFrame.channeling)
end

local function ToolbarUpdatePickLock(now)
  if toolbarState.activeMode ~= "picklock" then return end

  local button = ToolbarModeButton("picklock")
  if not button or (button:GetID() or 0) <= 0 then
    ToolbarDisablePersistentMode()
    return
  end

  if SpellIsTargeting and SpellIsTargeting() then return end
  if toolbarState.castBusy or ToolbarPlayerIsCasting() then return end

  if not toolbarState.rearmAt then toolbarState.rearmAt = now + .15 end
  if now < toolbarState.rearmAt then return end

  if ToolbarInvokeNativeMode("picklock") then
    toolbarState.rearmAt = now + .50
  else
    ToolbarDisablePersistentMode()
  end
end

local function ToolbarOnSpellStarted()
  if toolbarState.activeMode == "picklock" then toolbarState.castBusy = true end
end

local function ToolbarOnSpellFinished()
  if toolbarState.activeMode ~= "picklock" then return end
  toolbarState.castBusy = false
  toolbarState.rearmAt = GetTime() + .15
end

local function ToolbarGetClickedBagSlot()
  local itemButton = this
  if not itemButton or not itemButton.GetParent or not itemButton.GetID then
    return nil, nil
  end

  local parent = itemButton:GetParent()
  if not parent or not parent.GetID then return nil, nil end

  return parent:GetID(), itemButton:GetID()
end

local function ToolbarTryDisenchantClick(button)
  if toolbarState.activeMode ~= "disenchant" then return false end
  if button ~= "RightButton" then return false end
  if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then return false end
  if CursorHasItem() or (SpellIsTargeting and SpellIsTargeting()) then return false end

  local bag, slot = ToolbarGetClickedBagSlot()
  if bag == nil or slot == nil or not GetContainerItemLink(bag, slot) then return false end

  -- Let pfUI itself arm Disenchant. This preserves each fork's spell lookup
  -- and localization behaviour; BagTweaks only supplies the clicked target.
  if not ToolbarInvokeNativeMode("disenchant") then return false end

  if SpellIsTargeting and SpellIsTargeting() then
    PickupContainerItem(bag, slot)
    return true
  end

  return false
end

local function ToolbarMenuButton(parent, index)
  parent.buttons = parent.buttons or {}

  if not parent.buttons[index] then
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(TOOLBAR_MENU_ROW_HEIGHT)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -(4 + (index - 1) * TOOLBAR_MENU_ROW_HEIGHT))
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -(4 + (index - 1) * TOOLBAR_MENU_ROW_HEIGHT))
    button:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, ToolbarFontSize(), "OUTLINE")
    button:SetTextColor(.9, .9, .9, 1)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    if button:GetHighlightTexture() then button:GetHighlightTexture():SetAlpha(.20) end
    button:SetScript("OnClick", function()
      if this.action then this.action() end
    end)
    parent.buttons[index] = button
  end

  return parent.buttons[index]
end

local function ToolbarEnsureMenu()
  if toolbarState.menu then return toolbarState.menu end

  local menu = CreateFrame("Frame", "pfBagTweaksToolbarMenu", UIParent)
  menu:SetFrameStrata("DIALOG")
  menu:EnableMouse(1)
  ToolbarCreateBackdrop(menu, 1)
  menu:Hide()
  toolbarState.menu = menu
  return menu
end

local function ToolbarShowMenu(owner, width, entries)
  local menu = ToolbarEnsureMenu()

  if menu:IsShown() and toolbarState.menuOwner == owner then
    ToolbarHideMenu()
    return
  end

  toolbarState.menuOwner = owner
  menu:ClearAllPoints()
  menu:SetPoint("BOTTOMLEFT", owner, "TOPLEFT", 0, 2)
  menu:SetWidth(width or 150)
  menu:SetHeight(table.getn(entries) * TOOLBAR_MENU_ROW_HEIGHT + 8)

  for i = 1, table.getn(entries) do
    local row = ToolbarMenuButton(menu, i)
    row:SetText(entries[i].text or "")
    row.action = entries[i].action
    row:Show()
  end

  for i = table.getn(entries) + 1, table.getn(menu.buttons or {}) do
    menu.buttons[i]:Hide()
    menu.buttons[i].action = nil
  end

  menu:Show()
end

local function ToolbarToggleBagSlots()
  local bag = pfUI.bag and pfUI.bag.right
  local slots = bag and bag.bagslots
  if not slots then return end
  if slots:IsShown() then slots:Hide() else slots:Show() end
end

local function ToolbarToggleKeys()
  if not pfUI.bag then return end
  if pfUI.bag.showKeyring then pfUI.bag.showKeyring = nil
  else pfUI.bag.showKeyring = true end

  if pfUI.bag.CheckFullUpdate then pfUI.bag:CheckFullUpdate()
  elseif pfUI.bag.CreateBags then pfUI.bag:CreateBags() end
end

local function ToolbarToggleEmptyCategories()
  if pfUI.bagtweaks and pfUI.bagtweaks.ToggleEmptyCategories then
    pfUI.bagtweaks.ToggleEmptyCategories()
  end
end

local function ToolbarShowViewMenu(owner)
  local bag = pfUI.bag and pfUI.bag.right
  local bagsOn = bag and bag.bagslots and bag.bagslots:IsShown()
  local keysOn = pfUI.bag and pfUI.bag.showKeyring
  local emptyOn = true

  if pfUI.bagtweaks and pfUI.bagtweaks.ShowEmptyCategories then
    emptyOn = pfUI.bagtweaks.ShowEmptyCategories()
  end

  ToolbarShowMenu(owner, 145, {
    { text=(bagsOn and "[x] " or "[ ] ") .. L.BAGS, action=function()
        ToolbarToggleBagSlots()
        ToolbarHideMenu()
      end },
    { text=(keysOn and "[x] " or "[ ] ") .. L.KEYS, action=function()
        ToolbarToggleKeys()
        ToolbarHideMenu()
      end },
    { text=(emptyOn and "[x] " or "[ ] ") .. L.EMPTY_CATEGORIES, action=function()
        ToolbarToggleEmptyCategories()
        ToolbarHideMenu()
      end },
  })
end

local function ToolbarOpenOptions()
  ToolbarHideMenu()
  if not pfUI.gui or not pfUI.gui.frames then return end

  local thirdParty = "Thirdparty"
  if pfUI.env and pfUI.env.T and pfUI.env.T["Thirdparty"] then
    thirdParty = pfUI.env.T["Thirdparty"]
  end

  local root = pfUI.gui.frames[thirdParty]
  local child = root and root[L.PLUGIN_NAME]
  if not root or not child then return end

  pfUI.gui:Show()
  if root.Click then root:Click() end
  if child.Click then child:Click() end
end

local function ToolbarNativeClick(which)
  ToolbarHideMenu()
  local func = toolbarState.native[which]
  if func then func() end
end

local function ToolbarMakeButton(key, text, onclick)
  local button = toolbarState.buttons[key]
  if button then
    ToolbarEnsureLabel(button, text)
    button:Show()
    return button
  end

  local bag = pfUI.bag and pfUI.bag.right
  if not bag then return nil end

  button = CreateFrame("Button", nil, bag)
  button.bagtweaks_toolbar_control = true
  button:EnableMouse(1)

  local _, border = ToolbarMetrics(bag)
  ToolbarCreateBackdrop(button, border)
  ToolbarEnsureLabel(button, text)
  ToolbarEnsureActiveOverlay(button)
  button:SetScript("OnClick", onclick)
  button:SetScript("OnEnter", function()
    ToolbarSetHover(this, true)
  end)
  button:SetScript("OnLeave", function()
    ToolbarSetHover(this, false)
  end)

  ToolbarSetHover(button, false)
  toolbarState.buttons[key] = button
  return button
end

local function ToolbarFriendlyExtraLabel(frame)
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

  return L.BUTTON
end

local function ToolbarIsKnownNative(child, bag)
  return child == bag.bags or child == bag.open or child == bag.disenchant or
    child == bag.picklock or child == bag.keys or child == bag.sort
end

local function ToolbarSuppressNative(bag)
  local natives = { bag.bags, bag.open, bag.disenchant, bag.picklock, bag.keys, bag.sort }

  if bag.open and not toolbarState.native.open then
    toolbarState.native.open = bag.open:GetScript("OnClick")
  end

  if bag.sort and not toolbarState.native.sort then
    toolbarState.native.sort = bag.sort:GetScript("OnClick")
  end

  for i = 1, table.getn(natives) do
    local button = natives[i]
    if button and not button.bagtweaks_toolbar_suppressed then
      button:SetAlpha(0)
      button:EnableMouse(0)
      ToolbarHideIcon(button)
      button.bagtweaks_toolbar_suppressed = true
    end
  end
end

local function ToolbarPrepareExtra(button, border)
  if not button.bagtweaks_toolbar_extra then
    button.bagtweaks_toolbar_extra = true
    button.bagtweaks_extra_enter = button:GetScript("OnEnter")
    button.bagtweaks_extra_leave = button:GetScript("OnLeave")

    button:SetScript("OnEnter", function()
      if this.bagtweaks_extra_enter then this.bagtweaks_extra_enter() end
      ToolbarHideIcon(this)
      ToolbarSetHover(this, true)
    end)

    button:SetScript("OnLeave", function()
      if this.bagtweaks_extra_leave then this.bagtweaks_extra_leave() end
      ToolbarHideIcon(this)
      ToolbarSetHover(this, false)
    end)

    ToolbarSetHover(button, false)
  end

  ToolbarCreateBackdrop(button, border)
  ToolbarEnsureLabel(button, ToolbarFriendlyExtraLabel(button))
  ToolbarHideIcon(button)
end

local function ToolbarClickSort()
  ToolbarNativeClick("sort")
end

local function ToolbarClickView()
  ToolbarShowViewMenu(this)
end

local function ToolbarClickOpen()
  ToolbarNativeClick("open")
end

local function ToolbarDiscoverExtras(bag, border)
  local result = {}
  local children = { bag:GetChildren() }

  for i = 1, table.getn(children) do
    local child = children[i]
    if child and child ~= bag.close and not ToolbarIsKnownNative(child, bag) and
       not child.bagtweaks_toolbar_control and not child.bagtweaks_header and
       child.GetObjectType and child:GetObjectType() == "Button" and
       child.GetName and child:GetName() and child:IsShown() then
      local height = child.GetHeight and child:GetHeight() or 0
      if height > 0 and height <= 24 then
        ToolbarPrepareExtra(child, border)
        table.insert(result, child)
      end
    end
  end

  return result
end

local function BankToolbarFilter(query)
  query = string.lower(tostring(query or ""))
  query = string.gsub(query, "^%s+", "")
  query = string.gsub(query, "%s+$", "")

  local bags = pfUI.BANK or {}
  for i = 1, table.getn(bags) do
    local bagID = bags[i]
    local count = GetContainerNumSlots(bagID)

    for slot = 1, count do
      local data = pfUI.bags and pfUI.bags[bagID] and pfUI.bags[bagID].slots[slot]
      local frame = data and data.frame

      if frame then
        local alpha = 1
        if query ~= "" then
          alpha = .25
          local link = GetContainerItemLink(bagID, slot)
          if link then
            local _, _, name = string.find(link, "%[([^%]]+)%]")
            name = string.lower(name or "")
            if string.find(name, query, 1, true) then alpha = 1 end
          end
        end
        frame:SetAlpha(alpha)
      end
    end
  end
end

local function BankToolbarEnsureSearch()
  if bankToolbarState.search then return bankToolbarState.search end

  local bank = pfUI.bag and pfUI.bag.left
  if not bank then return nil end

  local search = CreateFrame("Frame", nil, bank)
  search:EnableMouse(1)
  ToolbarCreateBackdrop(search, 1)

  search.edit = CreateFrame("EditBox", nil, search)
  search.edit:SetPoint("TOPLEFT", search, "TOPLEFT", 4, -1)
  search.edit:SetPoint("BOTTOMRIGHT", search, "BOTTOMRIGHT", -4, 1)
  search.edit:SetFont(pfUI.font_default or STANDARD_TEXT_FONT, ToolbarFontSize(), "OUTLINE")
  search.edit:SetTextColor(.9, .9, .9, 1)
  search.edit:SetAutoFocus(false)
  search.edit:SetText("")

  search.edit:SetScript("OnTextChanged", function()
    BankToolbarFilter(this:GetText())
  end)
  search.edit:SetScript("OnEscapePressed", function()
    bankToolbarState.searchOpen = false
    this:ClearFocus()
    BankToolbarFilter("")
    search:SetAlpha(0)
    search:EnableMouse(0)
    this:EnableMouse(0)
    ToolbarUpdateActiveVisuals()
  end)
  search.edit:SetScript("OnEnterPressed", function()
    this:ClearFocus()
  end)

  search:SetAlpha(0)
  search:EnableMouse(0)
  search.edit:EnableMouse(0)
  bankToolbarState.search = search
  return search
end

local function BankToolbarApplySearchState()
  local bank = pfUI.bag and pfUI.bag.left
  local search = BankToolbarEnsureSearch()
  if not bank or not search then return end

  local _, border = ToolbarMetrics(bank)
  local y = TOOLBAR_SEARCH_GAP
  if bank.bagslots and bank.bagslots:IsShown() then
    y = y + (bank.bagslots:GetHeight() or 0) + border * 2
  end

  search:ClearAllPoints()
  search:SetPoint("BOTTOMLEFT", bank, "TOPLEFT", border, y)
  search:SetPoint("BOTTOMRIGHT", bank, "TOPRIGHT", -border, y)
  search:SetHeight(bank.close and bank.close:GetHeight() or 12)

  if bankToolbarState.searchOpen then
    search:SetAlpha(1)
    search:EnableMouse(1)
    search.edit:EnableMouse(1)
  else
    search.edit:ClearFocus()
    search.edit:SetText("")
    search.edit:EnableMouse(0)
    search:EnableMouse(0)
    search:SetAlpha(0)
    BankToolbarFilter("")
  end

  ToolbarUpdateActiveVisuals()
end

local function BankToolbarToggleSearch()
  ToolbarHideMenu()
  bankToolbarState.searchOpen = not bankToolbarState.searchOpen
  BankToolbarApplySearchState()

  local search = bankToolbarState.search
  if bankToolbarState.searchOpen and search and search.edit then
    search.edit:SetFocus()
  end
end

local function BankToolbarToggleBagSlots()
  local bank = pfUI.bag and pfUI.bag.left
  local slots = bank and bank.bagslots
  if not slots then return end
  if slots:IsShown() then slots:Hide() else slots:Show() end
  BankToolbarApplySearchState()
end

local function BankToolbarShowViewMenu(owner)
  local bank = pfUI.bag and pfUI.bag.left
  local bagsOn = bank and bank.bagslots and bank.bagslots:IsShown()
  local emptyOn = true

  if pfUI.bagtweaks and pfUI.bagtweaks.ShowEmptyCategories then
    emptyOn = pfUI.bagtweaks.ShowEmptyCategories()
  end

  ToolbarShowMenu(owner, 145, {
    { text=(bagsOn and "[x] " or "[ ] ") .. L.BAGS, action=function()
        BankToolbarToggleBagSlots()
        ToolbarHideMenu()
      end },
    { text=(emptyOn and "[x] " or "[ ] ") .. L.EMPTY_CATEGORIES, action=function()
        ToolbarToggleEmptyCategories()
        ToolbarHideMenu()
      end },
  })
end

local function BankToolbarNativeClick(which)
  ToolbarHideMenu()
  local func = bankToolbarState.native[which]
  if func then func() end
end

local function BankToolbarMakeButton(key, textValue, onclick)
  local button = bankToolbarState.buttons[key]
  if button then
    ToolbarEnsureLabel(button, textValue)
    button:Show()
    return button
  end

  local bank = pfUI.bag and pfUI.bag.left
  if not bank then return nil end

  button = CreateFrame("Button", nil, bank)
  button.bagtweaks_toolbar_control = true
  button:EnableMouse(1)

  local _, border = ToolbarMetrics(bank)
  ToolbarCreateBackdrop(button, border)
  ToolbarEnsureLabel(button, textValue)
  ToolbarEnsureActiveOverlay(button)
  button:SetScript("OnClick", onclick)
  button:SetScript("OnEnter", function() ToolbarSetHover(this, true) end)
  button:SetScript("OnLeave", function() ToolbarSetHover(this, false) end)

  ToolbarSetHover(button, false)
  bankToolbarState.buttons[key] = button
  return button
end

local function BankToolbarSuppressNative(bank)
  if bank.sort and not bankToolbarState.native.sort then
    bankToolbarState.native.sort = bank.sort:GetScript("OnClick")
  end

  local natives = { bank.bags, bank.sort }
  for i = 1, table.getn(natives) do
    local button = natives[i]
    if button and not button.bagtweaks_toolbar_suppressed then
      button:SetAlpha(0)
      button:EnableMouse(0)
      ToolbarHideIcon(button)
      button.bagtweaks_toolbar_suppressed = true
    end
  end
end

local function BankToolbarClickSort()
  BankToolbarNativeClick("sort")
end

local function BankToolbarClickView()
  BankToolbarShowViewMenu(this)
end

local function BankToolbarLayout()
  local bank = pfUI.bag and pfUI.bag.left
  if not bank or not bank.close or not bank.GetWidth then return end

  local height, border, gap, topInset = ToolbarMetrics(bank)
  BankToolbarSuppressNative(bank)

  local add = BankToolbarMakeButton("add", "+", ToolbarAddCategory)
  local search = BankToolbarMakeButton("search", L.TOOLBAR_SEARCH, BankToolbarToggleSearch)
  local sort = BankToolbarMakeButton("sort", L.TOOLBAR_SORT, BankToolbarClickSort)
  local view = BankToolbarMakeButton("view", L.TOOLBAR_VIEW, BankToolbarClickView)
  local quest = BankToolbarMakeButton("quest", L.TOOLBAR_QUEST, ToolbarToggleQuest)
  local options = BankToolbarMakeButton("options", L.TOOLBAR_OPTIONS, ToolbarOpenOptions)

  local buttons = {}
  if search then table.insert(buttons, search) end

  if sort then
    if bankToolbarState.native.sort then
      sort:Show()
      table.insert(buttons, sort)
    else
      sort:Hide()
    end
  end

  if view then table.insert(buttons, view) end
  if quest then table.insert(buttons, quest) end
  if options then table.insert(buttons, options) end

  local closeWidth = bank.close:GetWidth() or height
  local addWidth = closeWidth

  if add then
    add:ClearAllPoints()
    add:SetHeight(height)
    add:SetWidth(addWidth)
    add:SetPoint("TOPLEFT", bank, "TOPLEFT", border, -topInset)

    if add.bagtweaks_toolbar_label then
      add.bagtweaks_toolbar_label:ClearAllPoints()
      add.bagtweaks_toolbar_label:SetPoint("CENTER", add, "CENTER", 0, 0)
    end
  end

  local count = table.getn(buttons)
  if count > 0 then
    local available = bank:GetWidth() - border - border - closeWidth - gap - addWidth - gap
    local gaps = (count - 1) * gap
    local usable = available - gaps

    if usable >= count then
      local base = math.floor(usable / count)
      local remainder = usable - base * count
      local previous = add

      for i = 1, count do
        local button = buttons[i]
        local width = base

        if remainder > 0 then
          width = width + 1
          remainder = remainder - 1
        end

        button:ClearAllPoints()
        button:SetHeight(height)
        button:SetWidth(width)
        button:SetPoint("TOPLEFT", previous, "TOPRIGHT", gap, 0)
        ToolbarHideIcon(button)
        previous = button
      end
    end
  end

  BankToolbarApplySearchState()
  ToolbarUpdateActiveVisuals()
end

local function BankToolbarSetup()
  local bank = pfUI.bag and pfUI.bag.left
  if not bank or not bank.close then return false end

  bank.bagtweaks_toolbar_managed = true
  if not bankToolbarState.initialized then bankToolbarState.initialized = true end
  return true
end

local function BankToolbarClose()
  bankToolbarState.searchOpen = false
  ToolbarHideMenu()
  if bankToolbarState.search then
    bankToolbarState.search.edit:ClearFocus()
    bankToolbarState.search.edit:SetText("")
    bankToolbarState.search.edit:EnableMouse(0)
    bankToolbarState.search:EnableMouse(0)
    bankToolbarState.search:SetAlpha(0)
  end
  BankToolbarFilter("")
  ToolbarUpdateActiveVisuals()
end

local function ToolbarLayout()
  local bag = pfUI.bag and pfUI.bag.right
  if not bag or not bag.close or not bag.GetWidth then return end

  local height, border, gap, topInset = ToolbarMetrics(bag)
  ToolbarSuppressNative(bag)

  local add = ToolbarMakeButton("add", "+", ToolbarAddCategory)
  local search = ToolbarMakeButton("search", L.TOOLBAR_SEARCH, ToolbarToggleSearch)
  local sort = ToolbarMakeButton("sort", L.TOOLBAR_SORT, ToolbarClickSort)
  local view = ToolbarMakeButton("view", L.TOOLBAR_VIEW, ToolbarClickView)
  local quest = ToolbarMakeButton("quest", L.TOOLBAR_QUEST, ToolbarToggleQuest)
  local disenchant = ToolbarMakeButton("disenchant", L.TOOLBAR_DISENCHANT, ToolbarToggleDisenchantMode)
  local picklock = ToolbarMakeButton("picklock", L.TOOLBAR_PICKLOCK, ToolbarTogglePickLockMode)
  local open = ToolbarMakeButton("open", L.TOOLBAR_OPEN, ToolbarClickOpen)
  local options = ToolbarMakeButton("options", L.TOOLBAR_OPTIONS, ToolbarOpenOptions)

  local buttons = {}

  if search then table.insert(buttons, search) end

  if sort then
    if toolbarState.native.sort then
      sort:Show()
      table.insert(buttons, sort)
    else
      sort:Hide()
    end
  end

  if view then table.insert(buttons, view) end
  if quest then table.insert(buttons, quest) end

  local deAvailable = bag.disenchant and (bag.disenchant:GetID() or 0) > 0
  if disenchant then
    if deAvailable then
      disenchant:Show()
      table.insert(buttons, disenchant)
    else
      disenchant:Hide()
      if toolbarState.activeMode == "disenchant" then ToolbarDisablePersistentMode() end
    end
  end

  local pickAvailable = bag.picklock and (bag.picklock:GetID() or 0) > 0
  if picklock then
    if pickAvailable then
      picklock:Show()
      table.insert(buttons, picklock)
    else
      picklock:Hide()
      if toolbarState.activeMode == "picklock" then ToolbarDisablePersistentMode() end
    end
  end

  if open then table.insert(buttons, open) end
  if options then table.insert(buttons, options) end

  local extras = ToolbarDiscoverExtras(bag, border)
  for i = 1, table.getn(extras) do table.insert(buttons, extras[i]) end

  local closeWidth = bag.close:GetWidth() or height
  local addWidth = closeWidth

  if add then
    add:ClearAllPoints()
    add:SetHeight(height)
    add:SetWidth(addWidth)
    add:SetPoint("TOPLEFT", bag, "TOPLEFT", border, -topInset)

    if add.bagtweaks_toolbar_label then
      add.bagtweaks_toolbar_label:ClearAllPoints()
      add.bagtweaks_toolbar_label:SetPoint("CENTER", add, "CENTER", 0, 0)
    end
  end

  local count = table.getn(buttons)
  if count == 0 then
    ToolbarApplySearchState()
    ToolbarUpdateActiveVisuals()
    return
  end

  local available = bag:GetWidth() - border - border - closeWidth - gap - addWidth - gap
  local gaps = (count - 1) * gap
  local usable = available - gaps
  if usable < count then return end

  local base = math.floor(usable / count)
  local remainder = usable - base * count
  local previous = add

  for i = 1, count do
    local button = buttons[i]
    local width = base

    if remainder > 0 then
      width = width + 1
      remainder = remainder - 1
    end

    button:ClearAllPoints()
    button:SetHeight(height)
    button:SetWidth(width)

    if previous then
      button:SetPoint("TOPLEFT", previous, "TOPRIGHT", gap, 0)
    else
      button:SetPoint("TOPLEFT", bag, "TOPLEFT", border, -topInset)
    end

    ToolbarHideIcon(button)
    previous = button
  end

  ToolbarApplySearchState()
  ToolbarUpdateActiveVisuals()
end

local function ToolbarEnsureBagHideHook(bag)
  local current = bag:GetScript("OnHide")
  if current == toolbarState.onHideWrapper then return end

  toolbarState.baseOnHide = current

  if not toolbarState.onHideWrapper then
    toolbarState.onHideWrapper = function()
      local old = toolbarState.baseOnHide
      if old and old ~= toolbarState.onHideWrapper then old() end
      toolbarState.searchOpen = false
      ToolbarHideMenu()
      if pfUI.bagtweaks and pfUI.bagtweaks.HideMenus then pfUI.bagtweaks.HideMenus() end
      ToolbarApplySearchState()
    end
  end

  bag:SetScript("OnHide", toolbarState.onHideWrapper)
end

local function ToolbarSetup()
  local bag = pfUI.bag and pfUI.bag.right
  if not bag or not bag.search or not bag.close then return false end

  bag.bagtweaks_toolbar_managed = true
  ToolbarEnsureBagHideHook(bag)

  if not toolbarState.initialized then toolbarState.initialized = true end
  return true
end

-- AutoPickLockbox-style bag click interception. Whichever addon loads second
-- wraps the previous global handler, so both behaviours can coexist.
local OriginalContainerFrameItemButton_OnClick_BagTweaks = ContainerFrameItemButton_OnClick
if type(OriginalContainerFrameItemButton_OnClick_BagTweaks) == "function" then
  function ContainerFrameItemButton_OnClick(button, ignoreShift)
    if ToolbarTryDisenchantClick(button) then return end
    return OriginalContainerFrameItemButton_OnClick_BagTweaks(button, ignoreShift)
  end
end

local toolbarWatcher = CreateFrame("Frame")
toolbarWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")
toolbarWatcher:RegisterEvent("BANKFRAME_OPENED")
toolbarWatcher:RegisterEvent("BANKFRAME_CLOSED")
toolbarWatcher:RegisterEvent("SPELLS_CHANGED")
toolbarWatcher:RegisterEvent("SPELLCAST_START")
toolbarWatcher:RegisterEvent("SPELLCAST_STOP")
toolbarWatcher:RegisterEvent("SPELLCAST_FAILED")
toolbarWatcher:RegisterEvent("SPELLCAST_INTERRUPTED")

toolbarWatcher:SetScript("OnEvent", function()
  if event == "SPELLCAST_START" then
    ToolbarOnSpellStarted()
    return
  elseif event == "SPELLCAST_STOP" or event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
    ToolbarOnSpellFinished()
    return
  elseif event == "BANKFRAME_CLOSED" then
    BankToolbarClose()
  end

  if ToolbarSetup() then ToolbarLayout() end
  if BankToolbarSetup() and pfUI.bag.left:IsShown() then BankToolbarLayout() end
end)

toolbarWatcher:SetScript("OnUpdate", function()
  local now = GetTime()
  ToolbarUpdatePickLock(now)

  if now - toolbarState.lastUpdate < TOOLBAR_UPDATE_INTERVAL then return end
  toolbarState.lastUpdate = now

  local bag = pfUI.bag and pfUI.bag.right
  if not toolbarState.initialized then
    ToolbarSetup()
  elseif bag and bag:IsShown() then
    ToolbarLayout()
  end

  local bank = pfUI.bag and pfUI.bag.left
  if not bankToolbarState.initialized then
    BankToolbarSetup()
  elseif bank and bank:IsShown() then
    BankToolbarLayout()
  end
end)

if ToolbarSetup() then ToolbarLayout() end
if BankToolbarSetup() then BankToolbarLayout() end
