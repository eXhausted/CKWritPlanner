local _, ns = ...
local planner
local pageSize = 8
local rows, page = {}, 1
local mode, ownedOnly, doneOnly = "Balanced", false, false
local origin, resetTimer

local function money(copper)
    if copper == nil then return "Unknown" end
    if copper == 0 then return "0c" end
    copper = math.ceil(copper)
    if copper >= 10000 then return ("%dg %02ds"):format(math.floor(copper / 10000), math.floor(copper / 100) % 100) end
    if copper >= 100 then return ("%ds %02dc"):format(math.floor(copper / 100), copper % 100) end
    return ("%dc"):format(copper)
end

local function distance(row)
    if row.distance then
        if row.distance < 1000 then return ("%d yd"):format(math.floor(row.distance + 0.5)) end
        return ("%.1fk yd"):format(row.distance / 1000)
    end
    if row.overseas then return "Other continent" end
    return "Unknown"
end

local function label(parent, font, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font)
    text:SetPoint("TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local function button(parent, title, width, x, y, callback, point)
    local control = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    control:SetSize(width, 24)
    control:SetPoint(point or "TOPLEFT", x, y)
    control:SetText(title)
    control:SetScript("OnClick", callback)
    return control
end

local function itemText(order)
    local bundle = order.bundles[1]
    return ns.ItemName(order.requiredItemID, bundle[2])
end

local function showTooltip(control)
    local row = control.row
    if not row then return end
    local order = row.order
    GameTooltip:SetOwner(control, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ns.ItemName(order.itemID, order.name), 1, 0.82, 0)
    GameTooltip:AddLine(("%d reputation with %s"):format(row.rep, row.faction), 1, 1, 1)
    GameTooltip:AddLine(ns.PlaceName(order, row.spot), 1, 1, 1)
    GameTooltip:AddLine(("Deliver %d x %s"):format(order.bundles[1][1], itemText(order)), 1, 1, 1)
    if row.doneToday then
        GameTooltip:AddLine("Done today. Available again after the daily reset.", 0.65, 0.8, 1)
        GameTooltip:Show()
        return
    end
    local writ = row.active and "Quest accepted" or (row.owned and "In bags" or money(row.writCost))
    GameTooltip:AddDoubleLine("Writ", writ)
    local goods = row.missing == 0 and "In bags" or (money(row.goodsCost) .. (row.craft and " to craft" or ""))
    GameTooltip:AddDoubleLine(("Missing items (%d)"):format(row.missing), goods)
    if row.cost then GameTooltip:AddDoubleLine("Per 100 reputation", money(row.perRep * 100)) end
    if origin then GameTooltip:AddDoubleLine("From " .. origin.name, distance(row)) end
    if row.spot and not row.spot.questWaypoint then
        GameTooltip:AddLine("Click to pin the turn-in on your map.", 0.65, 0.8, 1)
    elseif row.active then
        GameTooltip:AddLine("Click to track the quest.", 0.65, 0.8, 1)
    else
        GameTooltip:AddLine("Accept the writ to track its turn-in.", 0.65, 0.8, 1)
    end
    GameTooltip:Show()
end

local function render()
    local last = math.max(1, math.ceil(#rows / pageSize))
    page = math.min(page, last)
    planner.previous:SetEnabled(page > 1)
    planner.next:SetEnabled(page < last)
    planner.page:SetText(("%d / %d  (%d writs)"):format(page, last, #rows))
    planner.empty:SetShown(#rows == 0)
    for i, control in ipairs(planner.entries) do
        local row = rows[(page - 1) * pageSize + i]
        control.row = row
        control:SetShown(row ~= nil)
        if row then
            local order = row.order
            local place = ns.PlaceName(order, row.spot)
            control.item:SetText(("%d x %s"):format(order.bundles[1][1], itemText(order)))
            if row.doneToday then
                control.destination:SetText("|cff88c697Done today|r  /  " .. place)
                control.cost:SetText("")
                control.perRep:SetText("")
            else
                local status = row.active and "Accepted" or (row.owned and "In bags" or "Buy writ")
                if row.owned then
                    status = row.missing == 0 and "Ready to turn in" or ("%s, %d needed"):format(status, row.missing)
                end
                control.destination:SetText(place .. "  |cff808080/|r  " .. status)
                control.cost:SetText(money(row.cost))
                control.perRep:SetText(row.cost and (money(row.perRep * 100) .. " / 100 rep") or "Price missing")
            end
            control.shop:SetShown(not row.doneToday)
            control.distance:SetText(distance(row))
            control.rep:SetText(tostring(row.rep))
        end
    end
end

function ns.RefreshPlanner()
    if not planner or not planner:IsShown() then return end
    local available, completed = ns.Rank(mode, ownedOnly, origin)
    rows = doneOnly and completed or available
    if not doneOnly and not ownedOnly then
        for _, row in ipairs(completed) do rows[#rows + 1] = row end
    end
    planner.done:SetText(doneOnly and "Back to writs" or ("Done today (%d)"):format(#completed))
    planner.scope:SetEnabled(not doneOnly)
    planner.empty:SetText(doneOnly and "No writs turned in today." or "No available writs match this filter.")
    if not resetTimer and #completed > 0 then
        local seconds = ns.SecondsUntilDailyReset()
        if seconds then
            resetTimer = C_Timer.NewTimer(seconds + 1, function()
                resetTimer = nil
                ns.RefreshPlanner()
            end)
        end
    end
    for name, control in pairs(planner.sorts) do
        if name == mode then control:Disable() else control:Enable() end
    end
    planner.scope:SetText(ownedOnly and "In bags / accepted" or "All writs")
    render()
end

local function createPlanner()
    planner = CreateFrame("Frame", "CKWritPlannerFrame", UIParent, "BasicFrameTemplateWithInset")
    planner:Hide()
    planner:SetSize(720, 546)
    planner:SetPoint("CENTER")
    planner:SetFrameStrata("DIALOG")
    planner:SetMovable(true)
    planner:SetClampedToScreen(true)
    planner:EnableMouse(true)
    planner:RegisterForDrag("LeftButton")
    planner:SetScript("OnDragStart", planner.StartMoving)
    planner:SetScript("OnDragStop", planner.StopMovingOrSizing)
    planner:SetScript("OnShow", ns.RefreshPlanner)
    planner.TitleText:SetText("Craftsman's Writs")
    tinsert(UISpecialFrames, planner:GetName())

    label(planner, "GameFontNormalSmall", 21, -43, 72):SetText("Rank from")
    local picker = CreateFrame("DropdownButton", nil, planner, "WowStyle1DropdownTemplate")
    picker:SetPoint("TOPLEFT", 92, -36)
    picker:SetSize(370, 24)
    picker:SetSelectionText(function() return origin and origin.name or "Current location" end)
    local function isSelected(spot)
        return (origin and origin.key) == (spot and spot.key)
    end
    local function selectOrigin(spot)
        origin, page = spot, 1
        ns.RefreshPlanner()
    end
    picker:SetupMenu(function(_, root)
        root:SetScrollMode(340)
        root:CreateRadio("Current location", isSelected, selectOrigin)
        local groups = ns.FlightPaths()
        if #groups == 0 then root:CreateTitle("No flight paths available") end
        for _, group in ipairs(groups) do
            root:CreateTitle(group.name)
            for _, spot in ipairs(group.paths) do
                root:CreateRadio(spot.name, isSelected, selectOrigin, spot)
            end
        end
    end)

    planner.sorts = {}
    for index, name in ipairs({"Balanced", "Cheapest", "Nearest"}) do
        local sortMode = name
        planner.sorts[sortMode] = button(planner, name, 88, 16 + (index - 1) * 92, -70, function()
            mode, page = sortMode, 1
            ns.RefreshPlanner()
        end)
    end
    planner.scope = button(planner, "All writs", 125, 298, -70, function()
        ownedOnly, page = not ownedOnly, 1
        ns.RefreshPlanner()
    end)
    planner.done = button(planner, "Done today (0)", 135, 429, -70, function()
        doneOnly, page = not doneOnly, 1
        ns.RefreshPlanner()
    end)
    button(planner, "Refresh", 86, 617, -36, function()
        page = 1
        ns.RefreshPlanner()
    end)

    label(planner, "GameFontNormalSmall", 21, -112, 334):SetText("Required item and turn-in")
    label(planner, "GameFontNormalSmall", 373, -112, 126):SetText("Estimated spend")
    label(planner, "GameFontNormalSmall", 512, -112, 92):SetText("Distance")
    label(planner, "GameFontNormalSmall", 610, -112, 34):SetText("Rep")

    planner.entries = {}
    for i = 1, pageSize do
        local entry = CreateFrame("Button", nil, planner)
        entry:SetSize(688, 42)
        entry:SetPoint("TOPLEFT", 16, -129 - (i - 1) * 42)
        entry:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        entry.item = label(entry, "GameFontHighlight", 5, -5, 341)
        entry.destination = label(entry, "GameFontDisableSmall", 5, -23, 341)
        entry.cost = label(entry, "GameFontHighlight", 357, -5, 125)
        entry.perRep = label(entry, "GameFontDisableSmall", 357, -23, 125)
        entry.distance = label(entry, "GameFontHighlightSmall", 496, -13, 92)
        entry.rep = label(entry, "GameFontHighlight", 594, -13, 34)
        entry.shop = button(entry, "Shop", 53, 629, -8, function(self)
            local row = self:GetParent().row
            if not row or row.doneToday then return end
            ns.ShopForWrit(row.order, function()
                GameTooltip:Hide()
                planner:Hide()
            end)
        end)
        entry.shop:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Auctionator Shopping", 1, 0.82, 0)
            GameTooltip:AddLine("Shop for the missing writ and turn-in items.", 1, 1, 1)
            GameTooltip:Show()
        end)
        entry.shop:SetScript("OnLeave", function() GameTooltip:Hide() end)
        entry:SetScript("OnEnter", showTooltip)
        entry:SetScript("OnLeave", function() GameTooltip:Hide() end)
        entry:SetScript("OnClick", function(self)
            if self.row and not self.row.doneToday and ns.PinTurnIn(self.row) then
                GameTooltip:Hide()
                planner:Hide()
            end
        end)
        planner.entries[i] = entry
    end

    planner.empty = label(planner, "GameFontHighlight", 21, -145, 665)
    label(planner, "GameFontDisableSmall", 21, -470, 680):SetText(
        "Distance is straight-line from the selected location. Balanced values travel at 10s per 1,000 yards.")
    label(planner, "GameFontDisableSmall", 21, -485, 680):SetText(
        "Prices are cached. Scan with Auctionator or WaylaidCost's Writs view, then refresh.")

    planner.page = label(planner, "GameFontHighlightSmall", 21, -514, 235)
    planner.previous = button(planner, "Previous", 83, -108, 18, function()
        page = page - 1
        render()
    end, "BOTTOMRIGHT")
    planner.next = button(planner, "Next", 83, -16, 18, function()
        page = page + 1
        render()
    end, "BOTTOMRIGHT")
end

function ns.OpenPlanner()
    if not planner then createPlanner() end
    if planner:IsShown() then
        ns.RefreshPlanner()
    else
        planner:Show()
    end
end

function ns.BuildMinimapButton()
    if not Minimap or CKWritPlannerMinimapButton then return end
    local db = CKWritPlannerDB
    local control = CreateFrame("Button", "CKWritPlannerMinimapButton", Minimap)
    control:SetSize(32, 32)
    control:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    control:RegisterForClicks("LeftButtonUp")
    control:RegisterForDrag("LeftButton")
    control:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

    local icon = control:CreateTexture(nil, "ARTWORK")
    icon:SetSize(19, 19)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Note_01")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local border = control:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local function position()
        local angle = math.rad(tonumber(db.minimapAngle) or 150)
        local x, y = math.cos(angle), math.sin(angle)
        if GetMinimapShape and GetMinimapShape() == "SQUARE" then
            local edge = math.max(math.abs(x), math.abs(y))
            x, y = x / edge, y / edge
        end
        control:ClearAllPoints()
        control:SetPoint("CENTER", Minimap, "CENTER",
            x * (Minimap:GetWidth() / 2 + 6), y * (Minimap:GetHeight() / 2 + 6))
    end

    control:SetScript("OnClick", function()
        GameTooltip:Hide()
        ns.OpenPlanner()
    end)
    control:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Craftsman's Writs", 1, 0.82, 0)
        GameTooltip:AddLine("Click to open the planner. Drag to move this button.", 1, 1, 1)
        GameTooltip:Show()
    end)
    control:SetScript("OnLeave", function() GameTooltip:Hide() end)
    control:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            if not cx or not cy then return end
            local x, y = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            db.minimapAngle = math.deg(math.atan2(y / scale - cy, x / scale - cx))
            position()
        end)
    end)
    local function stopDragging(self)
        self:SetScript("OnUpdate", nil)
    end
    control:SetScript("OnDragStop", stopDragging)
    control:SetScript("OnHide", stopDragging)
    Minimap:HookScript("OnSizeChanged", position)
    position()
end
