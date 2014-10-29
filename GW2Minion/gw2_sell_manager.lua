gw2_sell_manager = {}
gw2_sell_manager.mainWindow = { name = GetString("sellmanager"), x = 350, y = 50, w = 250, h = 350}
gw2minion.MainWindow.ChildWindows[gw2_sell_manager.mainWindow.name] = gw2_sell_manager.mainWindow.name
gw2_sell_manager.filterList = {}
gw2_sell_manager.currentFilter = nil

function gw2_sell_manager.ModuleInit()
	if (Settings.GW2Minion.SellManager_FilterList == nil) then
		Settings.GW2Minion.SellManager_FilterList = {
		{
			itemtype = "Weapon",
			name = "Weapons_Junk",
			rarity = "Junk",
			soulbound = "false",
			weapontype = "None",
		},
		
		{
			itemtype = "Weapon",
			name = "Weapons_Common",
			rarity = "Common",
			soulbound = "false",
			weapontype = "None",
		},
		
		{
			itemtype = "Weapon",
			name = "Weapons_Masterwork",
			rarity = "Masterwork",
			soulbound = "false",
			weapontype = "None",
		},
		
		{
			itemtype = "Weapon",
			name = "Weapons_Fine",
			rarity = "Fine",
			soulbound = "false",
			weapontype = "None",
		},
		
		{
			itemtype = "Armor",
			name = "Armor_Junk",
			rarity = "Junk",
			soulbound = "false",
			weapontype = "None",
		},
		
		{
			itemtype = "Armor",
			name = "Armor_Common",
			rarity = "Common",
			soulbound = "false",
			weapontype = "None",
		},
		
		{
			itemtype = "Armor",
			name = "Armor_Masterwork",
			rarity = "Masterwork",
			soulbound = "false",
			weapontype = "None",
		},
		
		{
			itemtype = "Armor",
			name = "Armor_Fine",
			rarity = "Fine",
			soulbound = "false",
			weapontype = "None",
		},
		
		}
	end
	
	if (Settings.GW2Minion.SellManager_Active == nil ) then
		Settings.GW2Minion.SellManager_Active = "1"
	end
	
	if (Settings.GW2Minion.SellManager_ItemIDInfo == nil ) then
		Settings.GW2Minion.SellManager_ItemIDInfo = {}
	end
	
	SellManager_Active = Settings.GW2Minion.SellManager_Active
	SellManager_ItemIDInfo = Settings.GW2Minion.SellManager_ItemIDInfo
	gw2_sell_manager.filterList = Settings.GW2Minion.SellManager_FilterList	
	gw2_sell_manager.refreshFilterlist()
	
	local mainWindow = WindowManager:NewWindow(gw2_sell_manager.mainWindow.name,gw2_sell_manager.mainWindow.x,gw2_sell_manager.mainWindow.y,gw2_sell_manager.mainWindow.w,gw2_sell_manager.mainWindow.h,false)
	if (mainWindow) then
		mainWindow:NewCheckBox(GetString("active"),"SellManager_Active",GetString("sellGroup"))
		mainWindow:NewButton(GetString("newfilter"),"SellManager_NewFilter",GetString("sellGroup"))
		RegisterEventHandler("SellManager_NewFilter",gw2_sell_manager.CreateDialog)	
		mainWindow:UnFold(GetString("sellGroup"))
		mainWindow:Hide()
		
		mainWindow:NewComboBox(GetString("sellByIDtems"),"SellManager_ItemToSell",GetString("sellByID"),"")
		mainWindow:NewButton(GetString("sellByIDAddItem"),"SellManager_AdditemID",GetString("sellByID"))
		RegisterEventHandler("SellManager_AdditemID",gw2_sell_manager.AddItemID)
		mainWindow:NewComboBox(GetString("sellItemList"),"SellManager_ItemIDList",GetString("sellByID"),"")
		SellManager_ItemIDList = "None"
		mainWindow:NewButton(GetString("sellByIDRemoveItem"),"SellManager_RemoveitemID",GetString("sellByID"))
		RegisterEventHandler("SellManager_RemoveitemID",gw2_sell_manager.RemoveItemID)
	end
	
	if (Player) then
		gw2_sell_manager.UpdateComboBox(Inventory(""),"SellManager_ItemToSell",SellManager_ItemIDInfo)
		gw2_sell_manager.UpdateComboBox(SellManager_ItemIDInfo,"SellManager_ItemIDList")
		gw2_sell_manager.refreshFilterlist()
	end
end

-- SINGLE ITEM STUFF HERE
-- Update singe-item drop-down list.
function gw2_sell_manager.UpdateComboBox(iTable,global,excludeTable,setToName)
	if (iTable and global) then
		local list = "None"
		for _,item in pairs(iTable) do
			if (ValidString(item.name) and StringContains(list, item.name) == false)then
				local name = item.name 
				if (ValidTable(excludeTable)) then
					for _,eItem in pairs(excludeTable) do
						if (eItem.name == item.name) then
							name = ""
						end
					end
				end
				list = (ValidString(name) == true and list .. "," .. name or list)
			end
		end
		_G[global] = (setToName == false and _G[global] or ValidString(setToName) and setToName or "None")
		_G[global .. "_listitems"] = list
	end
end

-- Add Single-Item to itemIDlist.
function gw2_sell_manager.AddItemID()
	if (ValidString(SellManager_ItemToSell) and SellManager_ItemToSell ~= "None") then
		-- Make sure this item is not already in our SellList
		for _,item in pairs(SellManager_ItemIDInfo) do
			if (SellManager_ItemToSell == item.name) then
				return
			end
		end
		-- Find Item by Name in Inventory
		for _,item in pairs(Inventory("")) do
			if (ValidString(item.name) and item.name == SellManager_ItemToSell)then
				table.insert(SellManager_ItemIDInfo, {name = item.name, itemID = item.itemID})
				gw2_sell_manager.UpdateComboBox(SellManager_ItemIDInfo,"SellManager_ItemIDList",nil,item.name)
				break
			end
		end
		Settings.GW2Minion.SellManager_ItemIDInfo = SellManager_ItemIDInfo
		gw2_sell_manager.UpdateComboBox(Inventory(""),"SellManager_ItemToSell",SellManager_ItemIDInfo)
	end
	return false
end

-- Remove Single-Item from itemIDlist.
function gw2_sell_manager.RemoveItemID()
	if ( ValidString(SellManager_ItemIDList) and SellManager_ItemIDList ~= "None") then
		for id,item in pairs(SellManager_ItemIDInfo) do
			if (item.name == SellManager_ItemIDList) then
				table.remove(SellManager_ItemIDInfo, id)
				break
			end
		end
		Settings.GW2Minion.SellManager_ItemIDInfo = SellManager_ItemIDInfo
		gw2_sell_manager.UpdateComboBox(SellManager_ItemIDInfo,"SellManager_ItemIDList")
		gw2_sell_manager.UpdateComboBox(Inventory(""),"SellManager_ItemToSell",SellManager_ItemIDInfo)
	end
end

-- FILTER STUFF HERE
--Refresh filters.
function gw2_sell_manager.refreshFilterlist()
	local mainWindow = WindowManager:GetWindow(gw2_sell_manager.mainWindow.name)
	if (mainWindow) then
		mainWindow:DeleteGroup(GetString("sellfilters"))
		for id,filter in pairs(gw2_sell_manager.filterList) do
			mainWindow:NewButton(gw2_sell_manager.filterList[id].name, "SellManager_Filter" .. id,GetString("sellfilters"))
			RegisterEventHandler("SellManager_Filter" .. id ,gw2_sell_manager.CreateDialog)
		end
		mainWindow:UnFold(GetString("sellfilters"))
	end
end

-- Create New Filter Dialog.
function gw2_sell_manager.CreateDialog(filterID)
	if (filterID:find("SellManager_Filter")) then
		filterID = string.gsub(filterID, "SellManager_Filter", "")
		filterID = tonumber(filterID)
		gw2_sell_manager.currentFilter = filterID
	end
	local dialog = WindowManager:GetWindow(GetString("newfilter"))
	local wSize = {w = 300, h = 170}
	if ( not dialog ) then
		dialog = WindowManager:NewWindow(GetString("newfilter"),nil,nil,nil,nil,true)
		dialog:NewField(GetString("name"),"SellManager_Name",GetString("filterdetails"))
		dialog:NewComboBox(GetString("soulbound"),"SellManager_Soulbound",GetString("filterdetails"),"true,false,either")
		local list = "None"
		for name,_ in pairs(GW2.ITEMTYPE) do list = list .. "," .. name end
		dialog:NewComboBox(GetString("itemtype"),"SellManager_Itemtype",GetString("filterdetails"),list)
		list = GetString("rarityNone")..","..GetString("rarityJunk")..","..GetString("rarityCommon")..","..GetString("rarityFine")..","..GetString("rarityMasterwork")..","..GetString("rarityRare")..","..GetString("rarityExotic")
		dialog:NewComboBox(GetString("rarity"),"SellManager_Rarity",GetString("filterdetails"),list)
		list = "None"
		for name,_ in pairs(GW2.WEAPONTYPE) do list = list .. "," .. name end
		dialog:NewComboBox(GetString("weapontype"),"SellManager_Weapontype",GetString("filterdetails"),list)
		dialog:UnFold(GetString("filterdetails"))

		local bSize = {w = 60, h = 20}
		-- Cancel Button
		local cancel = dialog:NewButton("Cancel","CancelDialog")
		cancel:Dock(0)
		cancel:SetSize(bSize.w,bSize.h)
		cancel:SetPos(((wSize.w - 12) - bSize.w),115)
		RegisterEventHandler("CancelDialog", function() dialog:SetModal(false) dialog:Hide() end)
		-- Save Button
		local save = dialog:NewButton("Save","SAVEDialog")
		save:Dock(0)
		save:SetSize(bSize.w,bSize.h)
		save:SetPos(((wSize.w - 12) - (bSize.w * 2 + 10)),115)
		local buttonFunction = function()
			local saveFilter = {
								name = SellManager_Name,
								itemtype = SellManager_Itemtype,
								rarity = SellManager_Rarity,
								weapontype = SellManager_Weapontype,
								soulbound = SellManager_Soulbound,
							}
			if (ValidString(saveFilter.name) == false) then
				ml_error("Please enter a filter name before saving.")
			elseif (gw2_sell_manager.validFilter(saveFilter)) then -- check if filter is valid.
				if (type(filterID) ~= "number") then -- new filter, making sure name is not in use.
					for _,filter in pairs(gw2_sell_manager.filterList) do
						if (saveFilter.name == filter.name) then
							return ml_error("Filter with this name already exists, please change the name.")
						end
					end
					table.insert(gw2_sell_manager.filterList, saveFilter)
				else
					gw2_sell_manager.filterList[filterID] = saveFilter
				end
				Settings.GW2Minion.SellManager_FilterList = gw2_sell_manager.filterList
				gw2_sell_manager.refreshFilterlist()
				dialog:SetModal(false)
				dialog:Hide()
			else
				ml_error("Filter Not Valid")
				ml_error("Filter needs to have both type and rarity set.")
				ml_error("Junk rarity can be set without any type.")
			end
		end
		RegisterEventHandler("SAVEDialog",buttonFunction)
		-- Delete Button
		local delete = dialog:NewButton("Delete","DELETEDialog")
		delete:Dock(0)
		delete:SetSize(bSize.w,bSize.h)
		delete:SetPos(0,115)
		local buttonFunction = function()
			table.remove(gw2_sell_manager.filterList, gw2_sell_manager.currentFilter)
			Settings.GW2Minion.SellManager_FilterList = gw2_sell_manager.filterList
			gw2_sell_manager.refreshFilterlist()
			dialog:SetModal(false)
			dialog:Hide()
		end
		RegisterEventHandler("DELETEDialog",buttonFunction)
	end
	
	if (type(filterID) == "number") then
		local delete = dialog:GetControl("Delete")
		delete:Show()
		SellManager_Name = gw2_sell_manager.filterList[filterID].name
		SellManager_Itemtype = gw2_sell_manager.filterList[filterID].itemtype
		SellManager_Rarity = gw2_sell_manager.filterList[filterID].rarity
		SellManager_Weapontype = gw2_sell_manager.filterList[filterID].weapontype
		SellManager_Soulbound = gw2_sell_manager.filterList[filterID].soulbound
	else
		local delete = dialog:GetControl("Delete")
		delete:Hide()
		SellManager_Name = ""
		SellManager_Itemtype = "None"
		SellManager_Rarity = GetString("rarityNone")
		SellManager_Weapontype = "None"
		SellManager_Soulbound = "either"
	end
	
	dialog:SetSize(wSize.w,wSize.h)
	dialog:Dock(GW2.DOCK.Center)
	dialog:Focus()
	dialog:SetModal(true)	
	dialog:Show()
end

-- Check if filter is valid:
function gw2_sell_manager.validFilter(filter)
	if (filter.itemtype ~= "None" and filter.itemtype ~= nil and
	filter.rarity ~= "None" and filter.rarity ~= nil) then
		return true
	elseif (filter.rarity == "Junk") then
		return true
	end
	return false
end

-- Working stuff here.
--Create filtered sell item list.
function gw2_sell_manager.createItemList()
	local items = Inventory("")
	local filteredItems = {}
	if (items) then
		for _,item in pairs(items) do
			if (item.salvagable and item.soulbound == false) then
				local addItem = false
				for _,filter in pairs(gw2_sell_manager.filterList) do
					if (mc_vendormanager.validFilter(filter)) then
						if ((filter.rarity == "None" or filter.rarity == nil or GW2.ITEMRARITY[filter.rarity] == item.rarity) and
						(filter.itemtype == "None" or filter.itemtype == nil or GW2.ITEMTYPE[filter.itemtype] == item.itemtype) and
						(filter.weapontype == "None" or filter.weapontype == nil or GW2.WEAPONTYPE[filter.weapontype] == item.weapontype) and					
						(filter.soulbound == "either" or (filter.soulbound == nil and item.soulbound == false) or filter.soulbound == tostring(item.soulbound))) then
							addItem = true
						end
					end
				end
				-- Check for single itemlist
				if (addItem == false) then
					for iID,lItem in pairs(SellManager_ItemIDInfo) do
						if (item.itemID == lItem.itemID) then
							addItem = true
							break
						end
					end
				end
				-- Add item if found in filters.
				if (addItem) then
					table.insert(filteredItems, item)
				end
			end
		end
		if (ValidTable(filteredItems)) then
			return filteredItems
		end
	end
	return false
end

--Have items to sell.
function gw2_sell_manager.haveItemToSell()
	if (ValidTable(gw2_sell_manager.createItemList())) then
		return true
	end
	return false
end

-- Toggle menu.
function gw2_sell_manager.ToggleMenu()
	local mainWindow = WindowManager:GetWindow(gw2_sell_manager.mainWindow.name)
	if (mainWindow) then
		if ( mainWindow.visible ) then
			mainWindow:Hide()
		else
			local wnd = WindowManager:GetWindow(gw2minion.MainWindow.Name)
			if ( wnd ) then
				mainWindow:SetPos(wnd.x+wnd.width,wnd.y)
				mainWindow:Show()
				gw2_sell_manager.UpdateComboBox(Inventory(""),"SellManager_ItemToSell",SellManager_ItemIDInfo)
			end
		end
	end
end

RegisterEventHandler("Module.Initalize",gw2_sell_manager.ModuleInit)