local PANEL = {}

function PANEL:Init()
	self:SetSize(360, 200)
	self:Center()
	self:SetTitle("Incoming Attack")
	self:MakePopup()

	self.callbackID = nil
	self.attacker = nil

	-- Description
	self.description = self:Add("DLabel")
	self.description:Dock(TOP)
	self.description:SetTall(30)
	self.description:SetText("You are being attacked!")
	self.description:SetContentAlignment(5)

	-- Defense Stat
	self.statBox = self:Add("DComboBox")
	self.statBox:Dock(TOP)
	self.statBox:SetTall(30)
	self.statBox:SetValue("Choose Defense Stat")
	self.statBox:AddChoice("RFLX")
	self.statBox:AddChoice("TGHN")

	-- Bonus Entry
	self.bonusEntry = self:Add("DNumberWang")
	self.bonusEntry:Dock(TOP)
	self.bonusEntry:SetTall(30)
	self.bonusEntry:SetMin(-100)
	self.bonusEntry:SetMax(100)
	self.bonusEntry:SetValue(0)
	self.bonusEntry:SetTooltip("Optional defense bonus")

	-- Submit
	local submit = self:Add("DButton")
	submit:Dock(BOTTOM)
	submit:SetTall(35)
	submit:SetText("Submit Defense")

	submit.DoClick = function()
		local stat = self.statBox:GetSelected()
		if not stat then
			LocalPlayer():Notify("Select a defense stat.")
			return
		end

		net.Start("ixVeritasDefenseResponse")
			net.WriteUInt(self.callbackID or 0, 8)
			net.WriteString(stat:lower())
			net.WriteInt(self.bonusEntry:GetValue(), 16)
		net.SendToServer()

		LocalPlayer():Notify("Defense submitted.")
		self:Close()
	end
end

function PANEL:SetCallbackID(id)
	self.callbackID = id
end

function PANEL:SetAttacker(ent)
    if IsValid(ent) then
        self.attacker = ent
        self:SetTitle("Defense vs " .. (ent:IsPlayer() and ent:Nick() or ent:GetClass()))
    else
        self:SetTitle("Incoming Attack")
    end
end


vgui.Register("ixVeritasDefenseMenu", PANEL, "DFrame")
