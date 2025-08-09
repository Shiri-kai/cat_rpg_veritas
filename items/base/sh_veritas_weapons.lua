local PLUGIN = ix.plugin.Get("cat_rpg_veritas")

ITEM.name = "Base Veritas Weapon"
ITEM.description = "A base template for Veritas weapons."
ITEM.category = "Veritas Weapons"
ITEM.base = "base_weapons" -- inherit from Helix weapon base
ITEM.isWeapon = true

-- Default slot (can be overridden in individual weapons)
ITEM.weaponSlot = "primary"
ITEM.weaponCategory = ITEM.weaponSlot -- sync for Helix
ITEM.weaponTraits = {} -- Veritas-specific traits

-- Ensure slot is synced for Helix when the item loads
function ITEM:OnInstanced()
	if self.weaponSlot then
		self.weaponCategory = self.weaponSlot
	end
end

function ITEM:GetWeaponTraits()
	return self.weaponTraits or {}
end

function ITEM:GetDisplayTraits()
	local lines = {}
	local wt = self:GetWeaponTraits()

	-- Numeric traits
	if wt.Wounds then
		table.insert(lines, wt.Wounds .. " Wounds")
	end
	if wt.ArmorPiercing then
		table.insert(lines, wt.ArmorPiercing .. " AP")
	end
	if wt.AntiArmor then
		table.insert(lines, "Anti-Armor +" .. wt.AntiArmor)
	end
	if wt.Shots then
		table.insert(lines, wt.Shots .. " Shots")
	end
	if wt.Afterburn then
		table.insert(lines, "Afterburn: " .. wt.Afterburn)
	end
	if wt.Brutal then
		table.insert(lines, "Brutal: " .. wt.Brutal)
	end
	if wt.Nimble then
		table.insert(lines, "Nimble: " .. wt.Nimble)
	end
	if wt.Blast then
		table.insert(lines, "Blast " .. wt.Blast)
	end

	-- Boolean traits
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
		if wt[trait] then
			table.insert(lines, label)
		end
	end

	return table.concat(lines, "\n")
end

function ITEM:GetDescription()
	local desc = self.description or ""

	if self:GetData("equip") then
		desc = desc .. "\n[Equipped as: " .. (self.weaponSlot or "unknown") .. "]"
	end

	local traits = self:GetDisplayTraits()
	if traits ~= "" then
		desc = desc .. "\n\nTraits:\n" .. traits
	end

	return desc
end

function ITEM:OnEquipWeapon(client, weapon)
    local char = client:GetCharacter()
    if char then
        self:SetData("equipSlot", self.weaponSlot) -- match RPG system
    end
end

function ITEM:OnUnequipWeapon(client, weapon)
    self:SetData("equipSlot", nil)
end

if CLIENT then
	function ITEM:PaintOver(item, w, h)
		if item:GetData("equip") then
			surface.SetDrawColor(0, 255, 0, 100)
			surface.DrawRect(w - 14, h - 14, 8, 8)
		end
	end
end
