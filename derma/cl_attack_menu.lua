local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 360)
	self:Center()
	self:SetTitle("Initiate Attack")
	self:MakePopup()

	self.targets = {}
	self.weapons = {}

	self.targetBox = self:Add("DComboBox")
	self.targetBox:Dock(TOP)
	self.targetBox:SetTall(30)
	self.targetBox:SetValue("Select Target")

	self.weaponBox = self:Add("DComboBox")
	self.weaponBox:Dock(TOP)
	self.weaponBox:SetTall(30)
	self.weaponBox:SetValue("Select Weapon")

	self.statBox = self:Add("DComboBox")
	self.statBox:Dock(TOP)
	self.statBox:SetTall(30)
	self.statBox:SetValue("Choose Attack Stat (RFLX/STRN)")
	self.statBox:AddChoice("RFLX")
	self.statBox:AddChoice("STRN")

	self.bonusEntry = self:Add("DNumberWang")
	self.bonusEntry:Dock(TOP)
	self.bonusEntry:SetTall(30)
	self.bonusEntry:SetMin(-100)
	self.bonusEntry:SetMax(100)
	self.bonusEntry:SetValue(0)
	self.bonusEntry:SetTooltip("Optional bonus to attack roll")

	self.attackCount = self:Add("DNumberWang")
	self.attackCount:Dock(TOP)
	self.attackCount:SetTall(30)
	self.attackCount:SetMin(1)
	self.attackCount:SetMax(1)
	self.attackCount:SetValue(1)
	self.attackCount:SetTooltip("Number of attacks (based on weapon's shots)")

	-- Update attack count when weapon is selected
	self.weaponBox.OnSelect = function(_, index, value)
		local selectedItem = self.weapons[value]
		if selectedItem and selectedItem.GetWeaponTraits then
			local traits = selectedItem:GetWeaponTraits()
			local maxShots = traits.Shots or 1
			self.attackCount:SetMax(maxShots)
			if self.attackCount:GetValue() > maxShots then
				self.attackCount:SetValue(maxShots)
			end
		end
	end

	-- Submit button
	local submit = self:Add("DButton")
	submit:Dock(BOTTOM)
	submit:SetText("Attack!")
	submit:SetTall(40)
	submit.DoClick = function()
		local targetName = self.targetBox:GetSelected()
		local weaponName = self.weaponBox:GetSelected()
		local stat = self.statBox:GetSelected()

		if not targetName or not weaponName or not stat then
			LocalPlayer():Notify("Please select a target, weapon, and stat.")
			return
		end

		local target = self.targets[targetName]
		local weapon = self.weapons[weaponName]

		if not IsValid(target) or not weapon then
			LocalPlayer():Notify("Invalid target or weapon.")
			return
		end

		net.Start("ixVeritasSubmitAttack")
			net.WriteEntity(target)
			net.WriteString(stat:lower())
			net.WriteUInt(self.attackCount:GetValue(), 8)
			net.WriteInt(self.bonusEntry:GetValue(), 16)
			net.WriteString(weapon:GetData("equipSlot") or "primary")
		net.SendToServer()

		LocalPlayer():Notify("Attack submitted.")

		self:Close()
	end

	-- Populate targets and weapons after UI is built
	self:PopulateTargetsAndWeapons()
end

function PANEL:PopulateTargetsAndWeapons()
	local char = LocalPlayer():GetCharacter()
	if not char then return end

	-- Target collection
	local playerKeys = {}

	for _, ent in ipairs(ents.FindInSphere(LocalPlayer():GetPos(), 10000)) do
		if ent:IsPlayer() then
			local name = ent:Nick()
			local key = string.format("%s [ent:%d]", name, ent:EntIndex())
			self.targets[key] = ent
			table.insert(playerKeys, key)
		elseif ent:GetClass() == "ix_veritas_npc" then
			local name = ent:GetNetVar("veritas_name") or ent:GetClass()
			local key = string.format("%s [ent:%d]", name, ent:EntIndex())
			self.targets[key] = ent
			table.insert(playerKeys, key)
		end
	end

	table.sort(playerKeys)
	for _, key in ipairs(playerKeys) do
		self.targetBox:AddChoice(key)
	end

	-- Weapon collection
	local inv = char:GetInventory()
	for _, item in pairs(inv:GetItems()) do
		if item.isWeapon and item:GetData("equipSlot") then
			local display = string.format("%s (%s)", item.name, item:GetData("equipSlot"))
			self.weapons[display] = item
			self.weaponBox:AddChoice(display)
		end
	end
end

vgui.Register("ixVeritasAttackMenu", PANEL, "DFrame")
