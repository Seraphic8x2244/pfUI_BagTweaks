-- pfUI_BagTweaks
-- 0.1.0-dev
--
-- First proof-of-concept:
--   * keeps pfUI's real bag slot buttons and normal item behaviour
--   * adds visual group headers to the backpack
--   * places Hearthstone (item 6948) in a separate test group
--   * leaves every other item and every empty slot in General
--
-- No item movement, sorting, classification UI, or automation is performed.

if not pfUI then return end

pfUI:RegisterModule("bagtweaks", "vanilla", function()
  if not pfUI.bag or not pfUI.bag.CreateBags then return end
  if pfUI.bag.bagtweaks_hooked then return end

  local TEST_ITEM_ID = 6948
  local HEADER_HEIGHT = 12

  local originalCreateBags = pfUI.bag.CreateBags
  local originalUpdateBag = pfUI.bag.UpdateBag

  local headers = {}

  local function GetContainerItemIDCompat(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return nil end

    local _, _, itemID = string.find(link, "item:(%d+)")
    return tonumber(itemID)
  end

  local function EnsureHeader(index, text)
    local parent = pfUI.bag.right
    if not parent then return nil end

    if not headers[index] then
      local header = CreateFrame("Frame", nil, parent)
      header:SetHeight(HEADER_HEIGHT)

      header.text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      header.text:SetFont(pfUI.font_default, C.global.font_size, "OUTLINE")
      header.text:SetJustifyH("LEFT")
      header.text:SetTextColor(1, 1, 1, 1)
      header.text:SetPoint("LEFT", header, "LEFT", 2, 0)

      header.line = header:CreateTexture(nil, "ARTWORK")
      header.line:SetTexture(1, 1, 1, 1)
      header.line:SetVertexColor(.25, .25, .25, 1)
      header.line:SetHeight(1)
      header.line:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
      header.line:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

      headers[index] = header
    end

    headers[index].text:SetText(text)
    headers[index]:Show()
    return headers[index]
  end

  local function CollectBackpackSlots()
    local general = {}
    local test = {}

    for i = 1, table.getn(pfUI.BACKPACK) do
      local bag = pfUI.BACKPACK[i]
      local bagsize = GetContainerNumSlots(bag)

      if bag == -2 and pfUI.bag.showKeyring == true then
        bagsize = GetKeyRingSize()
      end

      for slot = 1, bagsize do
        local slotData = pfUI.bags[bag] and pfUI.bags[bag].slots[slot]
        local button = slotData and slotData.frame

        if button then
          local entry = {
            bag = bag,
            slot = slot,
            frame = button,
          }

          if GetContainerItemIDCompat(bag, slot) == TEST_ITEM_ID then
            table.insert(test, entry)
          else
            table.insert(general, entry)
          end
        end
      end
    end

    return general, test
  end

  local function LayoutGroup(parent, group, rowlength, buttonSize, border, y)
    local spacing = border * 3
    local row = 0
    local column = 0

    for i = 1, table.getn(group) do
      local button = group[i].frame
      button:ClearAllPoints()
      button:SetPoint(
        "TOPLEFT",
        parent,
        "TOPLEFT",
        border + column * (buttonSize + spacing),
        -y - row * (buttonSize + spacing)
      )
      button:SetWidth(buttonSize)
      button:SetHeight(buttonSize)

      column = column + 1
      if column >= rowlength then
        column = 0
        row = row + 1
      end
    end

    if table.getn(group) == 0 then
      return y
    end

    if column > 0 then
      row = row + 1
    end

    return y + row * (buttonSize + spacing)
  end

  local function LayoutHeader(index, text, parent, border, y)
    local header = EnsureHeader(index, text)
    if not header then return y end

    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", border, -y)
    header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -border, -y)

    return y + HEADER_HEIGHT + border
  end

  local function RelayoutBackpack()
    local frame = pfUI.bag.right
    if not frame or not frame.button_size or not frame.close then return end
    if not pfUI.BACKPACK or not pfUI.bags then return end

    local _, border = GetBorderSize("bags")
    border = border or 1

    local rowlength = tonumber(C.appearance.bags.bagrowlength) or 10
    local buttonSize = frame.button_size
    local topSpace = frame.close:GetHeight() + border * 2
    local bottomSpace = pfUI.panel and pfUI.panel.right:IsShown()
      and pfUI.panel.right:GetHeight() + border
      or 16 + border

    local general, test = CollectBackpackSlots()
    local y = border * 2 + topSpace

    y = LayoutHeader(1, "General", frame, border, y)
    y = LayoutGroup(frame, general, rowlength, buttonSize, border, y)

    y = y + border
    y = LayoutHeader(2, "Test Group", frame, border, y)
    y = LayoutGroup(frame, test, rowlength, buttonSize, border, y)

    frame:SetHeight(y + bottomSpace + border)
  end

  pfUI.bag.CreateBags = function(self, object)
    originalCreateBags(self, object)

    if object ~= "bank" then
      RelayoutBackpack()
    end
  end

  if originalUpdateBag then
    pfUI.bag.UpdateBag = function(self, bag)
      originalUpdateBag(self, bag)

      if bag == -2 or (bag >= 0 and bag <= 4) then
        RelayoutBackpack()
      end
    end
  end

  pfUI.bag.bagtweaks_hooked = true

  -- pfUI has already built its modules by the time a dependent addon loads.
  -- Re-run the backpack layout once so the proof-of-concept appears immediately.
  if pfUI.bag.right then
    RelayoutBackpack()
  end
end)
