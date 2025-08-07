local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 320)
	self:Center()
	self:SetTitle("NPC Attack Panel")
	self:MakePopup()

	self.npcs = {}
	self.targets = {}

	-- Attacker selection
	self.attackerBox = self:Add("DComboBox")
	self.attackerBox:Dock(TOP)
	self.attackerBox:SetTall(30)
	self.attackerBox:SetValue("Select NPC Attacker")

	-- Target selection
	self.targetBox = self:Add("DComboBox")
	self.targetBox:Dock(TOP)
	self.targetBox:SetTall(30)
	self.targetBox:SetValue("Select Target")

	-- Stat selection
	self.statBox = self:Add("DComboBox")
	self.statBox:Dock(TOP)
	self.statBox:SetTall(30)
	self.statBox:SetValue("Choose Attack Stat (RFLX/STRN)")
	self.statBox:AddChoice("RFLX")
	self.statBox:AddChoice("STRN")

	-- Bonus
	self.bonusEntry = self:Add("DNumberWang")
	self.bonusEntry:Dock(TOP)
	self.bonusEntry:SetTall(30)
	self.bonusEntry:SetValue(0)
	self.bonusEntry:SetMin(-100)
	self.bonusEntry:SetMax(100)
	self.bonusEntry:SetTooltip("Optional Bonus")
	
	-- Number of Shots
	self.shotCount = self:Add("DNumberWang")
	self.shotCount:Dock(TOP)
	self.shotCount:SetTall(30)
	self.shotCount:SetMin(1)
	self.shotCount:SetMax(1) -- default, will update dynamically
	self.shotCount:SetValue(1)
	self.shotCount:SetTooltip("Number of shots to fire (max from weapon traits)")

	-- Submit
	local submit = self:Add("DButton")
	submit:Dock(BOTTOM)
	submit:SetText("Perform Attack")
	submit:SetTall(40)

	submit.DoClick = function()
		local attackerName = self.attackerBox:GetValue()
		local targetName = self.targetBox:GetValue()
		local stat = self.statBox:GetValue():lower()

		local attacker = self.npcs[attackerName]
		local target = self.targets[targetName]

		if not IsValid(attacker) or not IsValid(target) or stat == "" then
			LocalPlayer():Notify("Select attacker, target, and stat.")
			return
		end

		net.Start("ixVeritasNpcAttack")
			net.WriteEntity(attacker)
			net.WriteEntity(target)
			net.WriteString(stat)
			net.WriteInt(self.bonusEntry:GetValue(), 16)
			net.WriteUInt(self.shotCount:GetValue(), 8)
		net.SendToServer()

		self:Close()
	end
end

function PANEL:PopulateTargets()
	for _, ent in ipairs(ents.FindInSphere(LocalPlayer():GetPos(), 10000)) do
		if ent:GetClass() == "ix_veritas_npc" then
			local name = ent:GetNetVar("veritas_name") or "Unnamed NPC"
			local key = name .. " [" .. ent:EntIndex() .. "]"

			self.npcs[key] = ent
			self.attackerBox:AddChoice(key)
		elseif ent:IsPlayer() then
			local name = ent:Nick()
			self.targets[name] = ent
			self.targetBox:AddChoice(name)
		end
	end

	-- Dynamically adjust max shots when attacker is selected
	self.attackerBox.OnSelect = function(_, _, value)
		local npc = self.npcs[value]
		if not IsValid(npc) then return end

		local traits = npc:GetNetVar("veritas_weapon", {})
		local maxShots = tonumber(traits.Shots) or 1
		self.shotCount:SetMax(math.Clamp(maxShots, 1, 30))
	end
end

vgui.Register("ixVeritasNpcAttackMenu", PANEL, "DFrame")

-- Show the attack menu
net.Receive("ixVeritasOpenNpcAttackMenu", function()
	local panel = vgui.Create("ixVeritasNpcAttackMenu")
	panel:PopulateTargets()
end)
