local _, ns = ...
local engine = WaylaidCostEngine
local questLog = C_QuestLog

-- Faction flags from the Forever client quest list (ForeverChanges /quests/crafting).
local factionOnly = {
    [94004] = "Alliance",
    [94215] = "Alliance", [94224] = "Alliance", [94225] = "Alliance",
    [94227] = "Alliance", [94230] = "Alliance", [94233] = "Alliance",
    [94254] = "Alliance",
    [94213] = "Horde", [94216] = "Horde", [94220] = "Horde",
    [94228] = "Horde", [94229] = "Horde", [94231] = "Horde",
    [94239] = "Horde", [94243] = "Horde", [94244] = "Horde",
    [94247] = "Horde", [94250] = "Horde", [94255] = "Horde",
}

local catalog, byQuest, recentTurnIns = {}, {}, {}
for _, order in ipairs(WaylaidCostWrits) do
    catalog[#catalog + 1] = order
    byQuest[order.questID] = order
end
table.sort(catalog, function(a, b) return a.questID < b.questID end)

-- English zone keys from the WaylaidCost catalog mapped to Forever UI map IDs.
local mapByZone = {
    ["Alterac Mountains"] = 1416, ["Arathi Highlands"] = 1417, Ashenvale = 1440,
    Badlands = 1418, ["Deadwind Pass"] = 1430, Desolace = 1443, Duskwood = 1431,
    ["Dustwallow Marsh"] = 1445, Felwood = 1448, Feralas = 1444,
    ["Hillsbrad Foothills"] = 1424, Moonglade = 1450, ["Mount Hyjal"] = 2482,
    Riverglades = 2548, ["Searing Gorge"] = 1427, ["Stonetalon Mountains"] = 1442,
    ["Stranglethorn Vale"] = 1434, ["Swamp of Sorrows"] = 1435, Tanaris = 1446,
    ["The Hinterlands"] = 1425, ["Thousand Needles"] = 1441,
    ["Un'Goro Crater"] = 1449, Wetlands = 1437,
}

local function plainNumber(value)
    if type(value) == "number" and not (issecretvalue and issecretvalue(value)) then
        return value
    end
end

local function position(map, x, y)
    if plainNumber(map) and map > 0 and plainNumber(x) and plainNumber(y)
        and x >= 0 and x <= 1 and y >= 0 and y <= 1 and (x > 0 or y > 0) then
        return { map = map, x = x, y = y }
    end
end

local function faction()
    return (UnitFactionGroup("player"))
end

local function worldPosition(spot)
    local instance, coords = C_Map.GetWorldPosFromMapPos(spot.map, CreateVector2D(spot.x, spot.y))
    if coords and plainNumber(instance) and plainNumber(coords.x) and plainNumber(coords.y) then
        return coords.x, coords.y, instance
    end
end

local function addFlightPath(paths, key, name, map, x, y)
    local spot = position(map, x, y)
    if not spot then return end
    local px, py, instance = worldPosition(spot)
    if plainNumber(px) and plainNumber(py) and plainNumber(instance) then
        spot.key, spot.name = key, name
        paths[#paths + 1] = spot
        return true
    end
end

local flightContinents = {
    { map = 1414, name = "Kalimdor" },
    { map = 1415, name = "Eastern Kingdoms" },
}

function ns.FlightPaths()
    local side = faction()
    if side ~= "Alliance" and side ~= "Horde" then return {} end
    local taxiFaction = Enum.FlightPathFaction
    local getNodes = C_TaxiMap and C_TaxiMap.GetTaxiNodesForMap
    local groups = {}

    for _, continent in ipairs(flightContinents) do
        local map = continent.map
        local paths, seen = {}, {}
        for _, node in ipairs(getNodes and getNodes(map) or {}) do
            local nodeFaction = plainNumber(node.faction)
            local id = plainNumber(node.nodeID)
            if id and not seen[id] and node.position and node.name and taxiFaction
                and (nodeFaction == taxiFaction[side] or nodeFaction == taxiFaction.Neutral) then
                seen[id] = addFlightPath(paths, id, node.name, map, node.position.x, node.position.y)
            end
        end
        if #paths > 0 then
            table.sort(paths, function(a, b) return a.name < b.name end)
            local info = C_Map.GetMapInfo(map)
            groups[#groups + 1] = { name = info and info.name or continent.name, paths = paths }
        end
    end
    return groups
end

local function learnedSpots()
    local db = CKWritPlannerDB
    local side = faction()
    if not db or not side then return end
    db.spots[side] = db.spots[side] or {}
    return db.spots[side]
end

function ns.TurnedIn(questID)
    questID = plainNumber(questID)
    if not questID or not byQuest[questID] then return end
    local reset = engine.WritResetSeconds()
    if reset then recentTurnIns[questID] = GetTime() + reset end
    local map = C_Map.GetBestMapForUnit("player")
    local coords = map and C_Map.GetPlayerMapPosition(map, "player")
    local spots = learnedSpots()
    local spot = coords and position(map, coords.x, coords.y)
    if spots and spot then spots[questID] = spot end
    return true
end

local function staticSpots(order)
    local result = {}
    for _, place in ipairs(order.turnIns or {}) do
        local coord = place.coord
        local spot = coord and position(mapByZone[place.zone], coord[1] / 100, coord[2] / 100)
        if spot then
            spot.npc, spot.zone = place.npc, place.zone
            result[#result + 1] = spot
        end
    end
    return result
end

local function liveWaypoint(questID)
    if not questLog.IsOnQuest(questID) or not questLog.IsComplete(questID) then return end
    local map, x, y = questLog.GetNextWaypoint(questID)
    local spot = position(map, x, y)
    if spot then
        spot.questWaypoint = true
        return spot
    end
    map = C_Map.GetBestMapForUnit("player")
    for _, marker in ipairs(map and questLog.GetQuestsOnMap(map) or {}) do
        if marker.questID == questID then
            spot = position(map, marker.x, marker.y)
            if spot then return spot end
        end
    end
end

local function distanceFrom(spot, px, py, instance)
    if not px then return end
    local x, y, continent = worldPosition(spot)
    if not x then return end
    if instance == continent then return math.sqrt((px - x)^2 + (py - y)^2) end
    -- Only label an ocean crossing when both points are on Azeroth's outdoor continents.
    if (instance == 0 or instance == 1) and (continent == 0 or continent == 1) then
        return nil, true
    end
end

local function playerPosition()
    local map = plainNumber(C_Map.GetBestMapForUnit("player"))
    local coords = map and C_Map.GetPlayerMapPosition(map, "player")
    local spot = coords and position(map, coords.x, coords.y)
    if spot then return worldPosition(spot) end
end

local function destination(order, px, py, instance)
    local spots = learnedSpots()
    local saved = spots and spots[order.questID]
    local choices = staticSpots(order)
    if saved then
        local known = choices[1]
        local spot = position(saved.map, saved.x, saved.y)
        if spot then
            spot.npc = known and known.map == spot.map and known.npc
            choices = { spot }
        end
    end
    if #choices == 0 then
        local pace = CKProfessionPace and CKProfessionPace.Crates
        local prior = pace and pace.WritSpot(order.itemID)
        local spot = prior and not prior.live and position(prior.m, prior.x, prior.y)
        if spot then choices[1] = spot end
    end
    local best, distance, overseas
    for _, spot in ipairs(choices) do
        local yards, other = distanceFrom(spot, px, py, instance)
        if not best or (yards and (not distance or yards < distance)) then
            best, distance, overseas = spot, yards, other
        end
    end
    -- A game waypoint can be a boat or other intermediate stop. Use it for
    -- navigation when the destination is unknown, but exclude it from distance ranking.
    return best or liveWaypoint(order.questID), distance, overseas
end

function ns.PlaceName(order, spot)
    local known = order.turnIns and order.turnIns[1]
    if not spot then return known and (known.npc .. " - " .. known.zone) or "Destination unknown" end
    local info = C_Map.GetMapInfo(spot.map)
    local zone = info and info.name or spot.zone
    if spot.questWaypoint then return zone and ("Quest waypoint - " .. zone) or "Quest waypoint" end
    return spot.npc and zone and (spot.npc .. " - " .. zone) or zone or spot.npc or "Known turn-in"
end

local function matchesFaction(order)
    local side = factionOnly[order.questID]
    return not side or side == faction()
end

local function doneToday(order)
    local expires = recentTurnIns[order.questID]
    return (expires and GetTime() < expires) or engine.WritIsDoneToday(order)
end

function ns.PinTurnIn(row)
    local order, spot = row.order, row.spot
    if doneToday(order) then return false end
    if spot and not spot.questWaypoint and C_Map.CanSetUserWaypointOnMap(spot.map) then
        local pin = UiMapPoint.CreateFromCoordinates(spot.map, spot.x, spot.y)
        if C_Map.SetUserWaypoint(pin) then
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            return true
        end
    end
    if questLog.IsOnQuest(order.questID) then
        C_SuperTrack.SetSuperTrackedQuestID(order.questID)
        return true
    end
    print("Craftsman's Writs: No waypoint available. Accept the writ to track the quest.")
    return false
end

function ns.SecondsUntilDailyReset()
    return engine.WritResetSeconds()
end

function ns.ItemName(id, fallback)
    return C_Item.GetItemNameByID(id) or fallback
end

local function inBags(id)
    return plainNumber(C_Item.GetItemCount(id, false, false, false)) or 0
end

local shoppingRequest
local shoppingListName = "Craftsman's Writs"

function ns.ShopForWrit(order, onOpen)
    local request = {}
    shoppingRequest = request
    if doneToday(order) then
        print("Craftsman's Writs: This writ is done today.")
        return
    end
    local api = engine.AuctionatorAPI()
    if not api or not api.MultiSearchAdvanced or not api.CreateShoppingList or not api.ConvertToSearchString then
        print("Craftsman's Writs: Enable Auctionator to use the shopping list.")
        return
    end

    local items = {}
    if not engine.WritIsActive(order) and inBags(order.itemID) == 0 then
        items[#items + 1] = { id = order.itemID, name = order.name, quantity = 1 }
    end
    local bundle = order.bundles[1]
    local missing = bundle[1] - inBags(order.requiredItemID)
    if missing > 0 then
        items[#items + 1] = { id = order.requiredItemID, name = bundle[2], quantity = missing }
    end
    if #items == 0 then
        print("Craftsman's Writs: You have everything needed for this writ.")
        return
    end

    local terms, pending = {}, #items
    local function addTerm(index, item, name)
        if shoppingRequest ~= request then return end
        if not name or name == "" then
            shoppingRequest = nil
            print("Craftsman's Writs: Auctionator could not load the item name. Try again in a moment.")
            return
        end
        terms[index] = { searchString = name, quantity = item.quantity, isExact = true }
        pending = pending - 1
        if pending > 0 then return end
        shoppingRequest = nil
        if doneToday(order) then return end

        local atAuctionHouse = (AuctionHouseFrame and AuctionHouseFrame:IsShown())
            or (AuctionFrame and AuctionFrame:IsShown())
        local ok
        if atAuctionHouse then
            engine.CancelScan("Scan stopped: opened Craftsman's Writs shopping")
            ok = pcall(api.MultiSearchAdvanced, shoppingListName, terms)
            if ok and onOpen then onOpen() end
        else
            ok = pcall(function()
                local searches = {}
                for i, term in ipairs(terms) do
                    searches[i] = api.ConvertToSearchString(shoppingListName, term)
                end
                api.CreateShoppingList(shoppingListName, shoppingListName, searches)
            end)
            if ok then print("Craftsman's Writs: Shopping list saved in Auctionator.") end
        end
        if not ok then print("Craftsman's Writs: Auctionator could not open or save the shopping list.") end
    end

    for index, item in ipairs(items) do
        local name = engine.LocalItemName(item.name)
        if name then
            addTerm(index, item, name)
        else
            local slot, needed = index, item
            local data = Item:CreateFromItemID(needed.id)
            data:ContinueOnItemLoad(function()
                addTerm(slot, needed, engine.LocalItemName(needed.name))
            end)
        end
    end
end

local function craftPrice(pace, item, count)
    if not pace or not pace.Crates or count == 0 then return end
    local status = pace.Crates.WritStatus(item)
    if not status or status.kind ~= "craft" then return end
    local recipe = pace.Data.recipes[status.spellID]
    if not recipe or recipe.cooldown or not recipe.reagents or #recipe.reagents == 0 then return end
    local yield = recipe.count
    if type(yield) == "table" then yield = yield[1] end
    yield = tonumber(yield) or 1
    if yield <= 0 then return end
    local crafts, cost = math.ceil(count / yield), 0
    for _, reagent in ipairs(recipe.reagents) do
        local missing = crafts * (reagent[2] or 1) - inBags(reagent[1])
        if missing > 0 then
            local unit = pace.Prices.Buy(reagent[1])
            if not unit then return end
            cost = cost + missing * unit
        end
    end
    return cost
end

local function makeQuote()
    local scan = engine.GetSnapshot("writs")
    local source = engine.ResolveAuctionatorPrices(scan, catalog) or scan
    local books = source and source.books or {}
    local cache = {}
    return function(name, count)
        if count == 0 then return 0 end
        cache[name] = cache[name] or {}
        local counts = cache[name]
        if counts[count] == nil then
            counts[count] = engine.Quote(books[name], count, source ~= nil,
                source and source.incomplete, source and source.targeted and books[name] == nil).cost or false
        end
        return counts[count] or nil
    end
end

local function compare(a, b)
    if a.group ~= b.group then return a.group < b.group end
    if a.score ~= b.score then return a.score < b.score end
    if a.perRep ~= b.perRep then return a.perRep < b.perRep end
    if a.distance ~= b.distance then return (a.distance or math.huge) < (b.distance or math.huge) end
    if a.owned ~= b.owned then return a.owned end
    return a.order.questID < b.order.questID
end

function ns.Rank(mode, ownedOnly, origin)
    local rows, completed, quote = {}, {}, makeQuote()
    local px, py, instance
    if origin then
        px, py, instance = worldPosition(origin)
    else
        px, py, instance = playerPosition()
    end
    local pace = CKProfessionPace
    for _, order in ipairs(catalog) do
        local active = engine.WritIsActive(order) == true
        local owned = active or inBags(order.itemID) > 0
        local rep, factionName = engine.Reputation(order)
        local eligible = rep and rep > 0 and matchesFaction(order)
        local done = eligible and doneToday(order)
        if done then
            local spot, distance, overseas = destination(order, px, py, instance)
            completed[#completed + 1] = {
                order = order, rep = rep, faction = factionName, spot = spot,
                distance = distance, overseas = overseas, doneToday = true,
            }
        elseif eligible and (owned or not ownedOnly) then
            local bundle = order.bundles[1]
            local missing = math.max(0, bundle[1] - inBags(order.requiredItemID))
            local goodsCost = quote(bundle[2], missing)
            local craftCost = craftPrice(pace, order.requiredItemID, missing)
            local useCraft = craftCost and (not goodsCost or craftCost < goodsCost)
            if useCraft then goodsCost = craftCost end
            local writCost = quote(order.name, owned and 0 or 1)
            local cost = writCost and goodsCost and (writCost + goodsCost)
            local spot, distance, overseas = destination(order, px, py, instance)
            local perRep = cost and cost / rep or math.huge
            local group, score = 0, perRep
            if mode == "Nearest" then
                group = distance and 0 or (overseas and 1 or 2)
                score = distance or math.huge
            elseif mode == "Balanced" then
                group = distance and (cost and 0 or 1) or (overseas and 2 or 3)
                -- 10 silver per 1,000 yards, converted to copper on the same scale as the price.
                if distance and cost then score = (cost + distance) / rep end
            end
            rows[#rows + 1] = {
                order = order, rep = rep, faction = factionName, spot = spot, distance = distance,
                overseas = overseas, cost = cost, writCost = writCost, goodsCost = goodsCost,
                craft = useCraft == true, perRep = perRep, missing = missing, owned = owned,
                active = active, group = group, score = score,
            }
        end
    end
    table.sort(rows, compare)
    table.sort(completed, function(a, b) return a.order.name < b.order.name end)
    return rows, completed
end
