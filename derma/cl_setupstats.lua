local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
	self:SetSize(500, 500)
	self:Center()
	self:SetTitle("Initial Stat Setup")
	self:MakePopup()

	self.remainingPoints = 40
	self.statValues = {}
	self.labels = {}

	local char = LocalPlayer():GetCharacter()

	for _, stat in ipairs(PLUGIN.veritasStats) do
		self.statValues[stat] = 5

		local row = self:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(40)
		row:DockMargin(5, 5, 5, 0)

		local name = row:Add("DLabel")
		name:SetText(stat:upper())
		name:Dock(LEFT)
		name:SetWide(100)

		local subBtn = row:Add("DButton")
		subBtn:SetText("-")
		subBtn:SetWide(30)
		subBtn:Dock(LEFT)
		subBtn.DoClick = function()
			if self.statValues[stat] > 5 then
				self.statValues[stat] = self.statValues[stat] - 1
				self.remainingPoints = self.remainingPoints + 1
				self.labels[stat]:SetText(self.statValues[stat])
			end
		end

		self.labels[stat] = row:Add("DLabel")
		self.labels[stat]:SetText("5")
		self.labels[stat]:Dock(LEFT)
		self.labels[stat]:SetWide(40)
		self.labels[stat]:SetContentAlignment(5)

		local addBtn = row:Add("DButton")
		addBtn:SetText("+")
		addBtn:SetWide(30)
		addBtn:Dock(LEFT)
		addBtn.DoClick = function()
			if self.remainingPoints > 0 and self.statValues[stat] < 20 then
				self.statValues[stat] = self.statValues[stat] + 1
				self.remainingPoints = self.remainingPoints - 1
				self.labels[stat]:SetText(self.statValues[stat])
			end
		end
	end

	-- Remaining points
	self.pointsLabel = self:Add("DLabel")
	self.pointsLabel:SetText("Remaining Points: 40")
	self.pointsLabel:SetFont("DermaDefaultBold")
	self.pointsLabel:SetTall(25)
	self.pointsLabel:Dock(TOP)
	self.pointsLabel:DockMargin(5, 10, 5, 5)
	self.Think = function(s)
		s.pointsLabel:SetText("Remaining Points: " .. s.remainingPoints)
	end

	-- Submit
	local submit = self:Add("DButton")
	submit:SetText("Confirm Allocation")
	submit:Dock(BOTTOM)
	submit:SetTall(40)
	submit.DoClick = function()
		if self.remainingPoints > 0 then
			LocalPlayer():Notify("You must spend all 40 points.")
			return
		end

		net.Start("ixVeritasSubmitStats")
			net.WriteTable(self.statValues)
		net.SendToServer()

		self:Remove()
	end
end

vgui.Register("ixVeritasSetupStats", PANEL, "DFrame")
