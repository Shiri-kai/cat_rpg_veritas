local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 250)
	self:Center()
	self:SetTitle("Contested Roll Challenge")
	self:MakePopup()

	self.stat = "strn"
	self.bonus = 0

	self.attacker = nil
	self.attackerName = "Unknown"

	self.label = self:Add("DLabel")
	self.label:SetText("You have been challenged to a contested roll by: " .. self.attackerName)
	self.label:Dock(TOP)
	self.label:SetTall(40)
	self.label:SetWrap(true)

	self.statSelect = self:Add("DComboBox")
	self.statSelect:Dock(TOP)
	self.statSelect:DockMargin(10, 10, 10, 5)
	self.statSelect:SetValue("Select Stat")
	for _, stat in ipairs(PLUGIN.veritasStats) do
		self.statSelect:AddChoice(stat:upper(), stat)
	end
	self.statSelect.OnSelect = function(_, _, _, data)
		self.stat = data
	end

	self.bonusEntry = self:Add("DTextEntry")
	self.bonusEntry:Dock(TOP)
	self.bonusEntry:DockMargin(10, 5, 10, 5)
	self.bonusEntry:SetPlaceholderText("Enter bonus to stat")
	self.bonusEntry:SetNumeric(true)

	local accept = self:Add("DButton")
	accept:SetText("Accept Contest")
	accept:Dock(LEFT)
	accept:SetWide(self:GetWide() / 2)
	accept.DoClick = function()
		net.Start("ixVeritasContestResolve")
			net.WriteBool(true)
			net.WriteString(self.stat)
			net.WriteInt(tonumber(self.bonusEntry:GetValue()) or 0, 16)
			net.WriteEntity(self.attacker)
		net.SendToServer()
		self:Remove()
	end

	local deny = self:Add("DButton")
	deny:SetText("Deny")
	deny:Dock(RIGHT)
	deny:SetWide(self:GetWide() / 2)
	deny.DoClick = function()
		net.Start("ixVeritasContestResolve")
			net.WriteBool(false)
			net.WriteString("")
			net.WriteInt(0, 16)
			net.WriteEntity(self.attacker)
		net.SendToServer()
		self:Remove()
	end
end

vgui.Register("ixVeritasContestDefender", PANEL, "DFrame")
