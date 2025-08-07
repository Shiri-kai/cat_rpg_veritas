local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
	self:SetSize(400, 500)
	self:Center()
	self:SetTitle("Character Sheet")
	self:MakePopup()

	local char = LocalPlayer():GetCharacter()

	-- Scroll panel for stats
	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)

	for _, stat in ipairs(PLUGIN.veritasStats) do
		local statValue = char:GetData("veritas_" .. stat, 5)
		local grade = char:GetData("veritas_grade_" .. stat, 1)

		local row = self.scroll:Add("DPanel")
		row:Dock(TOP)
		row:SetTall(40)
		row:DockMargin(0, 0, 0, 5)
		row.Paint = function(s, w, h)
			surface.SetDrawColor(30, 30, 30, 200)
			surface.DrawRect(0, 0, w, h)
		end

		local label = row:Add("DLabel")
		label:SetText(stat:upper() .. ": " .. statValue .. " (Grade " .. grade .. ")")
		label:Dock(LEFT)
		label:SetWide(220)
		label:SetFont("DermaDefaultBold")
		label:DockMargin(10, 0, 0, 0)

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
	local wounds = char:GetData("wounds", 3 + math.floor(char:GetData("veritas_tghn", 5) / 10))

	local woundLabel = self:Add("DLabel")
	woundLabel:SetText("Max Wounds: " .. wounds)
	woundLabel:Dock(TOP)
	woundLabel:SetFont("DermaDefaultBold")
	woundLabel:SetContentAlignment(5)
	woundLabel:SetTall(25)

	-- Equipped items display
	local inv = char:GetInventory()

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

	for slot, label in pairs(slotMap) do
		local itemName = equippedBySlot[slot] or "None"
		equippedText = equippedText .. label .. ": " .. itemName .. "\n"
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
