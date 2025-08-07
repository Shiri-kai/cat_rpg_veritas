local PLUGIN = PLUGIN

net.Receive("ixVeritasOpenCharSheet", function()
	if IsValid(ix.gui.charSheet) then
		ix.gui.charSheet:Remove()
	end

	vgui.Create("ixVeritasCharSheet")
end)

net.Receive("ixVeritasOpenStatSetup", function()
	if IsValid(ix.gui.setupStats) then
		ix.gui.setupStats:Remove()
	end

	vgui.Create("ixVeritasSetupStats")
end)

net.Receive("ixVeritasSendCharSheet", function()
	local target = net.ReadEntity()
	local statTable = net.ReadTable()
	local woundCount = net.ReadUInt(8)
	local equippedText = net.ReadString()

	local frame = vgui.Create("ixVeritasCharSheetViewer")
	if IsValid(frame) then
		frame:SetTitle("Viewing: " .. target:Nick())
		frame:SetSheetData(target, statTable, woundCount, equippedText)
	end
end)


-- Open the attacker selection panel
net.Receive("ixVeritasOpenContestAttacker", function()
	if IsValid(ix.gui.contestAttacker) then
		ix.gui.contestAttacker:Remove()
	end
	vgui.Create("ixVeritasContestAttacker")
end)

-- Open the defender response panel
net.Receive("ixVeritasOpenContestDefender", function()
	local attackerName = net.ReadString()
	local attackerID = net.ReadEntity()

	if IsValid(ix.gui.contestDefender) then
		ix.gui.contestDefender:Remove()
	end

	local panel = vgui.Create("ixVeritasContestDefender")
	panel.attacker = attackerID
	panel.attackerName = attackerName
end)


net.Receive("ixVeritasEditNpc", function()
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end

	local panel = vgui.Create("ixVeritasNpcEditor")
	panel:SetEntity(ent)
end)

net.Receive("ixVeritasOpenNpcEditor", function()
	local ent = net.ReadEntity()
	if not IsValid(ent) then return end

	if IsValid(LocalPlayer()._veritasNpcEditor) then
		LocalPlayer()._veritasNpcEditor:MakePopup()
		return
	end

	local panel = vgui.Create("ixVeritasNpcEditor")
	panel:SetEntity(ent)
	LocalPlayer()._veritasNpcEditor = panel

	panel.OnClose = function()
		if IsValid(LocalPlayer()) then
			LocalPlayer()._veritasNpcEditor = nil
		end
	end
end)

net.Receive("ixVeritasSyncInitiative", function()
	initiativeQueue = net.ReadTable()
	currentTurn = net.ReadUInt(8)
end)

net.Receive("ixVeritasToggleInitiativeHud", function()
	showInitiativeHud = net.ReadBool()
end)

hook.Add("HUDPaint", "ixVeritasDrawInitiative", function()
	if not showInitiativeHud or not initiativeQueue or #initiativeQueue == 0 then return end

	local x = 30
	local y = ScrH() * 0.3
	local spacing = 25

	draw.SimpleText("Initiative Order", "Trebuchet24", x, y - spacing, color_white, 0, 0)

	for i, entry in ipairs(initiativeQueue) do
		local name = entry.name or "Unknown"
		local roll = entry.roll or 0
		local text = string.format("[%d] %s - %d", i, name, roll)

		local isTurn = (i == currentTurn)
		local color = isTurn and Color(0, 255, 0) or color_white

		draw.SimpleText(text, "Trebuchet18", x, y + (i * spacing), color, 0, 0)
	end
end)

net.Receive("ixVeritasOpenAttackMenu", function()
	vgui.Create("ixVeritasAttackMenu")
end)

net.Receive("ixVeritasDefensePrompt", function()
	local attacker = net.ReadEntity()
	local callbackID = net.ReadUInt(8)

	if IsValid(ix.gui.contestDefender) then
		ix.gui.contestDefender:Remove()
	end

	local frame = vgui.Create("ixVeritasDefenseMenu")
	frame:SetCallbackID(callbackID)
	frame:SetAttacker(attacker)
end)

net.Receive("ixVeritasCombatLog", function()
	local raw = net.ReadString()
	local lines = util.JSONToTable(raw) or {}

	for _, line in ipairs(lines) do
		local colorized = {}

		-- Header
		if string.StartWith(line, "[COMBAT]") or string.StartWith(line, "[CONTEST]") or string.StartWith(line, "[SKILL]") then
			table.insert(colorized, Color(255, 255, 0)) -- Yellow
			table.insert(colorized, line)

		-- Hit landed
		elseif string.find(line, "→ Hit landed") then
			table.insert(colorized, Color(0, 255, 0))
			table.insert(colorized, line)

		-- Missed
		elseif string.find(line, "→ Miss") then
			table.insert(colorized, Color(255, 100, 100))
			table.insert(colorized, line)

		-- Blocked by Field
		elseif string.find(line, "blocked by Field") then
			table.insert(colorized, Color(100, 255, 255))
			table.insert(colorized, line)

		-- Summary
		elseif string.StartWith(line, "Summary") then
			table.insert(colorized, Color(255, 255, 0))
			table.insert(colorized, line)

		-- Damage totals
		elseif string.StartWith(line, "Total Wounds Dealt") then
			local wounds, mit, over = line:match("(%d+).-(%d+).-(%d+)")
			table.insert(colorized, Color(255, 255, 255))
			table.insert(colorized, "Total Wounds Dealt: ")

			table.insert(colorized, Color(255, 150, 150)) table.insert(colorized, wounds)
			table.insert(colorized, Color(255, 255, 255)) table.insert(colorized, " | Mitigated: ")
			table.insert(colorized, Color(150, 150, 255)) table.insert(colorized, mit)
			table.insert(colorized, Color(255, 255, 255)) table.insert(colorized, " | Overflow: ")
			table.insert(colorized, Color(255, 255, 100)) table.insert(colorized, over)

		-- Breakdown lines
		elseif string.find(line, "Wound") then
			table.insert(colorized, Color(200, 200, 255))
			table.insert(colorized, line)

		-- Everything else
		else
			table.insert(colorized, Color(200, 200, 200))
			table.insert(colorized, line)
		end

		chat.AddText(unpack(colorized))
	end
end)