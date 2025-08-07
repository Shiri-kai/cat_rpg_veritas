local PLUGIN = ix.plugin.Get("cat_rpg_veritas")

ITEM.name = "Base Armor"
ITEM.description = "A base template for Veritas armor."
ITEM.category = "Veritas Armor"
ITEM.isArmor = true

ITEM.armorSlot = "armor"
ITEM.armorTraits = {}

function ITEM:GetArmorData()
	return self.armorTraits or {}
end

function ITEM:GetDisplayTraits()
	local lines = {}

	if self.armorTraits.StoppingPower then
		table.insert(lines, self.armorTraits.StoppingPower .. " Stopping Power")
	end
	if self.armorTraits.Wounds then
		table.insert(lines, self.armorTraits.Wounds .. " Wounds")
	end

	for dmgType, value in pairs(self.armorTraits.SpecializedProtection or {}) do
		table.insert(lines, "Anti-" .. dmgType .. ": " .. value)
	end

	if self.armorTraits.PowerArmor then
		table.insert(lines, "Power-Armor: +" .. self.armorTraits.PowerArmor)
	end

	if self.armorTraits.Field then
		local field = self.armorTraits.Field
		table.insert(lines, "Field: " .. field.chance .. "%, " .. field.uses .. " use(s)")
	end

	return table.concat(lines, "\n")
end

ITEM.functions.Equip = {
	name = "Equip",
	tip = "Equip this item.",
	icon = "icon16/accept.png",

	OnRun = function(item)
		local client = item.player or item:GetOwner()
		local char = client and client:GetCharacter()
		if not char then return false end

		local slot = item.weaponSlot or item.armorSlot
		if not slot then
			client:Notify("This item has no valid equip slot.")
			return false
		end

		-- Prevent equipping if something is already in that slot
		local inv = char:GetInventory()
		for _, invItem in pairs(inv:GetItems()) do
			if invItem ~= item and invItem:GetData("equipSlot") == slot then
				client:Notify("You already have an item equipped in slot: " .. slot)
				return false
			end
		end

		item:SetData("equipSlot", slot)
		client:Notify("You equipped " .. item:GetName() .. " to " .. slot .. ".")
		return false
	end,

	OnCanRun = function(item)
		return not item:GetData("equipSlot")
	end
}

ITEM.functions.Unequip = {
	name = "Unequip",
	tip = "Unequip this item.",
	icon = "icon16/cancel.png",

	OnRun = function(item)
		local client = item.player or item:GetOwner()
		if not client then return false end

		item:SetData("equipSlot", nil)
		client:Notify("You unequipped " .. item:GetName() .. ".")
		return false
	end,

	OnCanRun = function(item)
		return item:GetData("equipSlot") ~= nil
	end
}

if CLIENT then
	function ITEM:PaintOver(item, w, h)
		if item:GetData("equipSlot") then
			surface.SetDrawColor(0, 255, 0, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end


function ITEM:OnUse()
	if self:GetData("equipSlot") then
		PLUGIN:UnequipItem(self)
	else
		return PLUGIN:EquipItem(self, "armor")
	end

	return false
end

function ITEM:GetDescription()
	local desc = self.description or ""

	if self:GetData("equipSlot") then
		desc = desc .. "\n[Equipped]"
	end

	local traits = self:GetDisplayTraits()
	if traits and traits ~= "" then
		desc = desc .. "\n\nTraits:\n" .. traits
	end

	return desc
end
