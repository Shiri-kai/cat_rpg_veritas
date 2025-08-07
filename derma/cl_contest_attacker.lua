local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 250)
	self:Center()
	self:SetTitle("Initiate Contested Roll")
	self:MakePopup()

	self.stat = nil
	self.bonus = 0
	self.target = nil

	-- Stat selection
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

	-- Bonus entry
	self.bonusEntry = self:Add("DTextEntry")
	self.bonusEntry:Dock(TOP)
	self.bonusEntry:DockMargin(10, 5, 10, 5)
	self.bonusEntry:SetPlaceholderText("Enter bonus to stat (can be 0)")
	self.bonusEntry:SetNumeric(true)

	-- Target selection
	self.targetSelect = self:Add("DComboBox")
	self.targetSelect:Dock(TOP)
	self.targetSelect:DockMargin(10, 5, 10, 5)
	self.targetSelect:SetValue("Select Opponent")

	for _, v in ipairs(ents.GetAll()) do
		if v:IsPlayer() then
			self.targetSelect:AddChoice(v:Nick(), v)
		elseif IsValid(v) and v:GetClass() == "ix_veritas_npc" then
			local name = v:GetNpcName() or "Unnamed NPC"
			self.targetSelect:AddChoice("[NPC] " .. name, v)
		end
	end

	self.targetSelect.OnSelect = function(_, _, name, ent)
		self.target = ent
	end

	-- Submit
	local submit = self:Add("DButton")
	submit:SetText("Submit Contest Roll")
	submit:Dock(BOTTOM)
	submit:SetTall(40)
	submit.DoClick = function()
		self:Submit()
	end
end

function PANEL:Submit()
	local bonus = tonumber(self.bonusEntry:GetValue()) or 0
	if not self.stat or not self.target or not IsValid(self.target) then
		LocalPlayer():Notify("Invalid stat or target.")
		return
	end

	net.Start("ixVeritasContestSend")
		net.WriteString(self.stat)
		net.WriteInt(bonus, 16)
		net.WriteEntity(self.target)
	net.SendToServer()

	self:Remove()
end

vgui.Register("ixVeritasContestAttacker", PANEL, "DFrame")
