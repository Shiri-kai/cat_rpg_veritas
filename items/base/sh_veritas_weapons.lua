local PLUGIN = ix.plugin.Get("cat_rpg_veritas")

ITEM.name = "Base Weapon"
ITEM.description = "A base template for Veritas weapons."
ITEM.category = "Veritas Weapons"
ITEM.isWeapon = true

-- Custom slot info
ITEM.weaponSlot = "primary" -- Can be overridden in subclasses
ITEM.weaponTraits = {}

function ITEM:GetWeaponTraits()
	return self.weaponTraits or {}
end

function ITEM:GetDisplayTraits()
	local lines = {}

	if self.weaponTraits.Wounds then
		table.insert(lines, self.weaponTraits.Wounds .. " Wounds")
	end

	if self.weaponTraits.ArmorPiercing then
		table.insert(lines, self.weaponTraits.ArmorPiercing .. " AP")
	end

	if self.weaponTraits.AntiArmor then
		table.insert(lines, "Anti-Armor +" .. self.weaponTraits.AntiArmor)
	end

	if self.weaponTraits.Shots then
		table.insert(lines, self.weaponTraits.Shots .. " Shots")
	end

	if self.weaponTraits.Afterburn then
		table.insert(lines, "Afterburn: " .. self.weaponTraits.Afterburn)
	end

	if self.weaponTraits.Brutal then
		table.insert(lines, "Brutal: " .. self.weaponTraits.Brutal)
	end

	if self.weaponTraits.Nimble then
		table.insert(lines, "Nimble: " .. self.weaponTraits.Nimble)
	end

	for trait, label in pairs({
		Ranged = "Ranged",
		Melee = "Melee",
		CloseRanged = "Close-Ranged",
		FarMelee = "Far-Melee",
		Energy = "Energy",
		Kinetic = "Kinetic",
		Plasma = "Plasma",
		Powered = "Powered",
		Force = "Force (Psyker)",
		Cooldown = "Cooldown",
		CombiSlot = "Combi-Slot",
	}) do
		if self.weaponTraits[trait] then
			table.insert(lines, label)
		end
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
		local slot = self.weaponSlot or "primary"
		if not table.HasValue(PLUGIN.validWeaponSlots, slot) then
			self.player:Notify("Invalid weapon slot.")
			return false
		end

		return PLUGIN:EquipItem(self, slot)
	end

	return false
end

function ITEM:GetDescription()
	local desc = self.description or ""

	if self:GetData("equipSlot") then
		desc = desc .. "\n[Equipped as: " .. self:GetData("equipSlot") .. "]"
	end

	local traits = self:GetDisplayTraits()
	if traits and traits ~= "" then
		desc = desc .. "\n\nTraits:\n" .. traits
	end

	return desc
end
