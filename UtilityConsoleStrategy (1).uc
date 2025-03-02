class UtilityConsoleStrategy extends X2DownloadableContentInfo;

exec function EquipUtility(name TemplateName, optional bool bReplaceUnique = false)
{
	local array<XComGameState_Item> UnitInventory;
	local XComGameState_Item UtilityState;
	local XComGameState_Unit UnitState;
	local XComGameState_HeadquartersXCom HQState;
	local XComGameState NewGameState;
	local X2ItemTemplateManager TemplateManager;
	local X2ItemTemplate EquippedItemTemplate;
	local X2EquipmentTemplate EquipmentTemplate;
	local EInventorySlot InventorySlot;
	local int i, equippedUtil, maxUtil;
	local bool isUnique;
	local UIArmory Armory;
	local StateObjectReference UnitRef;
	local XComGameStateHistory History;
	Armory = UIArmory(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory'));
	if (Armory == none)
	{
		class'Helpers'.static.OutputMsg("Not on Armory.");
		return;
	}

	History = `XCOMHISTORY;
	UnitRef = Armory.GetUnitRef();
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));

	if (UnitState == none)
		return;

	TemplateManager = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	EquipmentTemplate = X2EquipmentTemplate(TemplateManager.FindItemTemplate(TemplateName));

	if (EquipmentTemplate == none)
	{
		class'Helpers'.static.OutputMsg("Error: No template found for the provided name. Please provide a valid item template name.");
		return;
	}
	
	InventorySlot = EquipmentTemplate.InventorySlot;
	if (InventorySlot != eInvSlot_Utility)
	{
		class'Helpers'.static.OutputMsg("Error: Equipment template was found, but is not a utility item. (slot is \"" $ InventorySlot $ "\")");
		return;
	}
	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Equip Utility Item");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));
	HQState = XComGameState_HeadquartersXCom(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	
	if (!HQState.hasItem(EquipmentTemplate, 1)) 
	{
		class'Helpers'.static.OutputMsg("You do not have any of that item.");
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		return;
	}

	UnitInventory = UnitState.GetAllInventoryItems();
	// check if unique
	isUnique = TemplateManager.ItemCategoryIsUniqueEquip(EquipmentTemplate.ItemCat);

	for (i = UnitInventory.Length - 1; i >= 0; i--)
	{
		// Check all utility item slots for conflicting utility items
		if (UnitInventory[i].InventorySlot == InventorySlot)
		{
			equippedUtil++;
			EquippedItemTemplate = UnitInventory[i].GetMyTemplate();
			if (isUnique && EquippedItemTemplate.ItemCat == EquipmentTemplate.ItemCat)
			{
				if (!bReplaceUnique)
				{
					class'Helpers'.static.OutputMsg("Unit already has unique item equipped. Set bReplaceUnique to 1 if you want to replace it.");
					`XCOMHISTORY.CleanupPendingGameState(NewGameState);
					return;
				}	
				// remove 1 of what we are equipping from HQ inventory, if not infinite
				if (!EquipmentTemplate.bInfiniteItem)
					HQState.RemoveItemFromInventory(NewGameState, HQState.GetItemByName(TemplateName).GetReference(), 1);
				// add 1 back of our currently equipped item to HQ inventory, if not infinite
				if (!EquippedItemTemplate.bInfiniteItem)
				{
					if (HQState.hasItem(EquippedItemTemplate, 1))
					{
						// if it is already in HQ Inventory, add 1 to quantity
						HQState.AddResource(NewGameState, UnitInventory[i].GetMyTemplateName(), 1);
					}
					else
					{
						// if it is not in HQ inventory, add 1
						UtilityState = EquippedItemTemplate.CreateInstanceFromTemplate(NewGameState);
						UtilityState.Quantity = 1;
						HQState.PutItemInInventory(NewGameState, UtilityState);
					}
				}
				// remove equipped utility item
				UnitState.RemoveItemFromInventory(UnitInventory[i], NewGameState);
				// add selected utility item
				UtilityState = EquipmentTemplate.CreateInstanceFromTemplate(NewGameState);
				UtilityState.InventorySlot = InventorySlot;
				UnitState.InventoryItems.AddItem(UtilityState.GetReference());
				`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
				return;			
			}
		}
	}
	maxUtil = UnitState.GetMaxStat(eStat_UtilityItems);
	// check if unit already has full utility slots
	// strictly greater than because the xpad is a utility item
	if (equippedUtil > maxUtil) 
	{
		class'Helpers'.static.OutputMsg("You have the max number of utility items equipped already.");
		`XCOMHISTORY.CleanupPendingGameState(NewGameState);
		return;
	}
	if (!EquipmentTemplate.bInfiniteItem)
		HQState.RemoveItemFromInventory(NewGameState, HQState.GetItemByName(TemplateName).GetReference(), 1);
	// add selected utility item
	UtilityState = EquipmentTemplate.CreateInstanceFromTemplate(NewGameState);
	UtilityState.InventorySlot = InventorySlot;
	UnitState.InventoryItems.AddItem(UtilityState.GetReference());
	`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
}

