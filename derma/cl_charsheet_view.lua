local PLUGIN = PLUGIN

-- Helper: get PA boost for a given target+stat
local function GetPABoostForStat(target, stat)
	if not IsValid(target) then return 0 end
	if not PLUGIN or not PLUGIN.GetPowerArmorBoost then return 0 end

	local ok, boost = pcall(PLUGIN.GetPowerArmorBoost, PLUGIN, target, stat)
	if ok and tonumber(boost) then
		boost = math.floor(boost)
		if (stat == "strn" or stat == "tghn") and boost > 0 then
			return boost
		end
	end
	return 0
end

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
	local statsList = PLUGIN and PLUGIN.veritasStats or { "strn","rflx","tghn","intl","tech","prsn","wyrd" }

	for _, stat in ipairs(statsList) do
		local entry = statData and statData[stat] or {}
		local value = tonumber(entry.value) or 5

		local grade = tonumber(entry.grade) or 1

		local paBoost = tonumber(entry.boost) or GetPABoostForStat(target, stat)
		local paNote = (paBoost > 0) and (" (+%d PA)"):format(paBoost) or ""

		local row = self.scroll:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(40)
		row:DockMargin(0, 0, 0, 5)
		row.Paint = function(s, w, h)
			surface.SetDrawColor(30, 30, 30, 200)
			surface.DrawRect(0, 0, w, h)
		end

		local label = row:Add("DLabel")
		label:Dock(LEFT)
		label:SetWide(320)
		label:SetFont("DermaDefaultBold")
		label:DockMargin(10, 0, 0, 0)
		label:SetText(("%s: %d (Grade %d%s)"):format(stat:upper(), value, grade, paNote))
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
