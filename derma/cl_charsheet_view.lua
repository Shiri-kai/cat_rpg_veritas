local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 500)
	self:Center()
	self:SetTitle("Viewing Character Sheet")
	self:MakePopup()

	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)
end

function PANEL:SetSheetData(target, statData, woundCount, equippedText)
	for _, stat in ipairs(ix.plugin.Get("cat_rpg_veritas").veritasStats) do
		local statEntry = statData[stat]
		local value = statEntry and statEntry.value or 5
		local grade = statEntry and statEntry.grade or 1

		local row = self.scroll:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(40)
		row:DockMargin(0, 0, 0, 5)
		row.Paint = function(s, w, h)
			surface.SetDrawColor(30, 30, 30, 200)
			surface.DrawRect(0, 0, w, h)
		end

		local label = row:Add("DLabel")
		label:SetText(stat:upper() .. ": " .. value .. " (Grade " .. grade .. ")")
		label:Dock(LEFT)
		label:SetWide(300)
		label:SetFont("DermaDefaultBold")
		label:DockMargin(10, 0, 0, 0)
	end

	if woundCount then
		local woundLabel = self:Add("DLabel")
		woundLabel:SetText("Max Wounds: " .. woundCount)
		woundLabel:Dock(TOP)
		woundLabel:SetFont("DermaDefaultBold")
		woundLabel:SetContentAlignment(5)
		woundLabel:SetTall(25)
	end

	if equippedText then
		local equippedLabel = self:Add("DLabel")
		equippedLabel:SetText(equippedText)
		equippedLabel:Dock(TOP)
		equippedLabel:SetFont("DermaDefaultBold")
		equippedLabel:SetWrap(true)
		equippedLabel:SetContentAlignment(7)
		equippedLabel:SetTall(120)
		equippedLabel:DockMargin(10, 5, 10, 5)
	end
end

vgui.Register("ixVeritasCharSheetViewer", PANEL, "DFrame")
