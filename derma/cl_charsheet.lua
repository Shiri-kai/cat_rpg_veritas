local PLUGIN = PLUGIN

-- Helper: get PA boost for a given player+stat (safe clientside)
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
	self:SetTitle("Character Sheet")
	self:MakePopup()

	local ply = LocalPlayer()
	local char = IsValid(ply) and ply:GetCharacter()

	-- Scroll panel for stats
	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)

	for _, stat in ipairs(PLUGIN.veritasStats) do
		local baseValue = char and char:GetData("veritas_" .. stat, 5) or 5
		local baseGrade = char and char:GetData("veritas_grade_" .. stat, 1) or 1

		-- PA boost + effective grade
		local paBoost = GetPABoostForStat(ply, stat)
		local effectiveGrade = math.min(baseGrade + paBoost, 10)
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
		label:SetWide(260)
		label:SetFont("DermaDefaultBold")
		label:DockMargin(10, 0, 0, 0)
		label:SetText(("%s: %d (Grade %d%s)"):format(stat:upper(), baseValue, effectiveGrade, paNote))

		local rollButton = row:Add("DButton")
		rollButton:Dock(RIGHT)
		rollButton:SetWide(100)
		rollButton:SetText("Roll")
		rollButton.DoClick = function()
			net.Start("ixVeritasRollStat")
				net.WriteString(stat)
			net.SendToServer()
		end
	end

	-- Wound display
	local wounds = 3 + math.floor((char and char:GetData("veritas_tghn", 5) or 5) / 10)

	local woundLabel = self:Add("DLabel")
	woundLabel:SetText("Max Wounds: " .. wounds)
	woundLabel:Dock(TOP)
	woundLabel:SetFont("DermaDefaultBold")
	woundLabel:SetContentAlignment(5)
	woundLabel:SetTall(25)

	-- Equipped items display
	local inv = char and char:GetInventory()
	local slotMap = {
		["primary"] = "Primary Weapon",
		["secondary"] = "Secondary Weapon",
		["tertiary"] = "Tertiary Weapon",
		["melee"] = "Melee Weapon",
		["armor"] = "Armor"
	}

	local equippedBySlot = {}
	if inv then
		for _, item in pairs(inv:GetItems()) do
			local slot = item:GetData("equipSlot")
			if slot then
				equippedBySlot[slot] = item.name
			end
		end
	end

	local equippedText = ""
	for slot, nice in pairs(slotMap) do
		local itemName = equippedBySlot[slot] or "None"
		equippedText = equippedText .. nice .. ": " .. itemName .. "\n"
	end

	local equippedList = self:Add("DLabel")
	equippedList:SetText(equippedText)
	equippedList:Dock(TOP)
	equippedList:SetWrap(true)
	equippedList:SetTall(120)
	equippedList:SetFont("DermaDefaultBold")
	equippedList:SetContentAlignment(7) -- Top left
	equippedList:DockMargin(10, 5, 10, 5)
end

vgui.Register("ixVeritasCharSheet", PANEL, "DFrame")
