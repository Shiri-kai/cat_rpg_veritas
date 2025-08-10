local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 360)
	self:Center()
	self:SetTitle("Initiate Attack")
	self:MakePopup()

	-- current selections
	self.selTargetEnt  = nil
	self.selWeaponItem = nil
	self.selStat       = nil

	self.targetBox = self:Add("DComboBox")
	self.targetBox:Dock(TOP)
	self.targetBox:SetTall(30)
	self.targetBox:SetValue("Select Target")
	self.targetBox.OnSelect = function(_, _, _, data)
		self.selTargetEnt = data
	end

	self.weaponBox = self:Add("DComboBox")
	self.weaponBox:Dock(TOP)
	self.weaponBox:SetTall(30)
	self.weaponBox:SetValue("Select Weapon")
	self.weaponBox.OnSelect = function(_, _, _, item)
		self.selWeaponItem = item

		-- Update attack count limit based on weapon traits
		local maxShots = 1
		if item and item.GetWeaponTraits then
			local traits = item:GetWeaponTraits()
			maxShots = tonumber(traits.Shots) or 1
		end
		self.attackCount:SetMax(maxShots)
		if self.attackCount:GetValue() > maxShots then
			self.attackCount:SetValue(maxShots)
		end
	end

	self.statBox = self:Add("DComboBox")
	self.statBox:Dock(TOP)
	self.statBox:SetTall(30)
	self.statBox:SetValue("Choose Attack Stat (RFLX/STRN)")
	self.statBox:AddChoice("RFLX", "rflx")
	self.statBox:AddChoice("STRN", "strn")
	self.statBox.OnSelect = function(_, _, _, data)
		self.selStat = data -- "rflx" or "strn"
	end

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

	-- Submit button
	local submit = self:Add("DButton")
	submit:Dock(BOTTOM)
	submit:SetText("Attack!")
	submit:SetTall(40)
	submit.DoClick = function()
		if not IsValid(self.selTargetEnt) or not self.selWeaponItem or not self.selStat then
			LocalPlayer():Notify("Please select a target, weapon, and stat.")
			return
		end

		local slot = self.selWeaponItem:GetData("equipSlot") or self.selWeaponItem.weaponSlot or "primary"

		net.Start("ixVeritasSubmitAttack")
			net.WriteEntity(self.selTargetEnt)
			net.WriteString(self.selStat) -- "rflx"/"strn"
			net.WriteUInt(self.attackCount:GetValue(), 8)
			net.WriteInt(self.bonusEntry:GetValue(), 16)
			net.WriteString(slot)
		net.SendToServer()

		LocalPlayer():Notify("Attack submitted.")
		self:Close()
	end

	self:PopulateTargetsAndWeapons()
end

function PANEL:PopulateTargetsAndWeapons()
	local ply = LocalPlayer()
	local char = ply and ply:GetCharacter()
	if not char then return end

	-- Targets
	local options = {}
	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 10000)) do
		if ent:IsPlayer() then
			local key = string.format("%s [ent:%d]", ent:Nick(), ent:EntIndex())
			table.insert(options, { text = key, data = ent })
		elseif ent:GetClass() == "ix_veritas_npc" then
			local name = ent:GetNetVar("veritas_name") or ent:GetClass()
			local key = string.format("%s [ent:%d]", name, ent:EntIndex())
			table.insert(options, { text = key, data = ent })
		end
	end
	table.SortByMember(options, "text", true)
	for _, opt in ipairs(options) do
		self.targetBox:AddChoice(opt.text, opt.data)
	end

	-- Weapons (equipped only)
	local inv = char:GetInventory()
	if not inv then return end

	for _, item in pairs(inv:GetItems()) do
		if item.isWeapon and item:GetData("equipSlot") then
			local display = string.format("%s (%s)", item.name or "Weapon", item:GetData("equipSlot"))
			self.weaponBox:AddChoice(display, item)
		end
	end
end

vgui.Register("ixVeritasAttackMenu", PANEL, "DFrame")
