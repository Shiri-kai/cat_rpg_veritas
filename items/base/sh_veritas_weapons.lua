local PLUGIN = ix.plugin.Get("cat_rpg_veritas")

ITEM.name = "Base Veritas Weapon"
ITEM.description = "A base template for Veritas weapons."
ITEM.category = "Veritas Weapons"
ITEM.base = "base_weapons" -- inherit from Helix weapon base
ITEM.isWeapon = true
ITEM.weaponCategory = "primary" -- Uses default equip system
ITEM.weaponTraits = {} -- Veritas-specific traits

ITEM.veritasEquipSlot = "primary"

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

function ITEM:GetDescription()
	local desc = self.description or ""

	if self:GetData("equip") then
		desc = desc .. "\n[Equipped]"
	end

	local traits = self:GetDisplayTraits()
	if traits ~= "" then
		desc = desc .. "\n\nTraits:\n" .. traits
	end

	return desc
end

if CLIENT then
	function ITEM:PaintOver(item, w, h)
		if item:GetData("equip") then
			surface.SetDrawColor(0, 255, 0, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end
