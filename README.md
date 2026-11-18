# CKWritPlanner

Plan daily Craftsman's Writs for reputation in World of Warcraft: Forever. Compare estimated gold per 100 reputation, distance from your character or a selected flight point, and what you already have in your bags.

## Install with WowUp

1. Install [WaylaidCost](https://www.curseforge.com/wow/addons/waylaidcost) for Forever. It supplies the writ catalog and pricing engine. Version 1.0.2 is the tested version.
2. Install [Auctionator](https://www.curseforge.com/wow/addons/auctionator) for saved auction prices and the **Shop** button.
3. In WowUp, select **WoW Forever**, open **Get Addons → Install from URL**, and paste `https://github.com/eXhausted/CKWritPlanner`. [WowUp install guide](https://wowup.io/guide/get-addons/overview)
4. Restart the game, then open the planner with `/writguide` or the minimap scroll icon.

For manual installation, extract the Forever ZIP from [Releases](https://github.com/eXhausted/CKWritPlanner/releases) into `_forever_/Interface/AddOns`. The ZIP contains a single `CKWritPlanner` addon folder.

## Use

- Choose **Current location** or a flight point under **Rank from**. **Balanced** adds a travel weight of 10 silver per 1,000 yards before comparing cost per reputation. **Cheapest** and **Nearest** sort by price per reputation and straight-line distance, respectively.
- Open **Done today** to review completed writs. Click an available writ to pin its turn-in on the WoW map, or track its accepted quest when only quest tracking is available.
- Click **Shop** to search for the missing writ and delivery items in Auctionator. Away from the auction house, this saves a **Craftsman's Writs** shopping list for the selected writ.

## Prices and data

Keep **Use Auctionator's saved prices** enabled in WaylaidCost. The planner uses cached auction prices, and WaylaidCost can supply prices from its own saved writ scans. Refresh Auctionator's prices with a scan at the auction house. Items in your bags reduce the estimated spend. Optional CKProfessionPace integration can estimate crafting costs for known recipes.

Writ catalog and initial turn-in data come from WaylaidCost by shAkam_. The planner remembers additional locations when you turn in a writ.
