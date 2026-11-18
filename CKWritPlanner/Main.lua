local addon, ns = ...

local pending
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:RegisterEvent("QUEST_LOG_UPDATE")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", function(self, event, arg)
    if event == "ADDON_LOADED" then
        if arg ~= addon then return end
        CKWritPlannerDB = CKWritPlannerDB or {}
        CKWritPlannerDB.spots = CKWritPlannerDB.spots or {}
        ns.BuildMinimapButton()
        self:UnregisterEvent(event)
        return
    end
    if event == "QUEST_TURNED_IN" and not ns.TurnedIn(arg) then return end
    if pending then return end
    pending = true
    C_Timer.After(0.15, function()
        pending = nil
        ns.RefreshPlanner()
    end)
end)

SLASH_CKWRITPLANNER1 = "/writguide"
SlashCmdList.CKWRITPLANNER = ns.OpenPlanner
