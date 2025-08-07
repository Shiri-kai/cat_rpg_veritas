local PLUGIN = PLUGIN

ix.command.Add("CharSheet", {
	description = "Open your character sheet.",
	OnRun = function(self, client)
		if SERVER then
			net.Start("ixVeritasOpenCharSheet")
			net.Send(client)
		end
	end
})

ix.command.Add("ViewCharSheet", {
	description = "View another player's character sheet.",
	arguments = {ix.type.character},
	adminOnly = true,
	OnRun = function(self, ply, targetChar)
		local target = targetChar:GetPlayer()
		if not IsValid(target) then return "Player not found." end

		local char = target:GetCharacter()
		if not char then return "Character not loaded." end

		local data = {}
		for _, stat in ipairs(PLUGIN.veritasStats) do
			data[stat] = {
				value = char:GetData("veritas_" .. stat, 5),
				grade = char:GetData("veritas_grade_" .. stat, 1)
			}
		end

		local wounds = char:GetData("wounds", 3 + math.floor(char:GetData("veritas_tghn", 5) / 10))

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

		net.Start("ixVeritasSendCharSheet")
			net.WriteEntity(target)
			net.WriteTable(data)
			net.WriteUInt(wounds, 8)
			net.WriteString(equippedText)
		net.Send(ply)
	end
})

ix.command.Add("SetupStats", {
	description = "Distribute your initial 40 stat points. One-time use.",
	OnRun = function(self, client)
		if SERVER then
			local char = client:GetCharacter()
			if char:GetData("veritas_setup_complete", false) then
				client:Notify("You have already set up your stats.")
				return
			end

			net.Start("ixVeritasOpenStatSetup")
			net.Send(client)
		end
	end
})

ix.command.Add("ResetStatsSetup", {
	description = "Allows a player to redo their stat setup.",
	arguments = {ix.type.character},
	adminOnly = true,
	OnRun = function(self, ply, targetChar)
		local target = targetChar:GetPlayer()
		if not IsValid(target) then return "Invalid player." end

		local char = targetChar
		if not char then return "Invalid character." end

		char:SetData("veritas_setup_complete", false)

		-- Reset all stats and grades to default
		local plugin = ix.plugin.Get("cat_rpg_veritas")
		if plugin and plugin.veritasStats then
			for _, stat in ipairs(plugin.veritasStats) do
				char:SetData("veritas_" .. stat, 5)
				char:SetData("veritas_grade_" .. stat, 1)
			end
		end

		target:Notify("Your Veritas stats have been reset. Please reopen the stat setup menu.")
		ply:Notify("Reset stat setup for " .. target:Nick() .. ".")

		return true
	end
})

ix.command.Add("StatSet", {
	description = "Set a specific stat to a value.",
	arguments = {ix.type.character, ix.type.string, ix.type.number},
	adminOnly = true,
	OnRun = function(self, client, targetChar, stat, value)
		stat = stat:lower()
		if not table.HasValue(PLUGIN.veritasStats, stat) then
			return "Invalid stat."
		end

		value = math.Clamp(value, 0, 100)
		targetChar:SetData("veritas_" .. stat, value)
		client:Notify("Set " .. stat:upper() .. " to " .. value .. " for " .. targetChar:GetName())
	end
})

ix.command.Add("StatAdd", {
	description = "Add a value to a stat.",
	arguments = {ix.type.character, ix.type.string, ix.type.number},
	adminOnly = true,
	OnRun = function(self, client, targetChar, stat, amount)
		stat = stat:lower()
		if not table.HasValue(PLUGIN.veritasStats, stat) then
			return "Invalid stat."
		end

		local current = targetChar:GetData("veritas_" .. stat, 5)
		local new = math.Clamp(current + amount, 0, 100)
		targetChar:SetData("veritas_" .. stat, new)

		client:Notify("Set " .. stat:upper() .. " to " .. new .. " for " .. targetChar:GetName())
	end
})

ix.command.Add("GradeSet", {
	description = "Set a stat grade.",
	arguments = {ix.type.character, ix.type.string, ix.type.number},
	adminOnly = true,
	OnRun = function(self, client, targetChar, stat, value)
		stat = stat:lower()
		if not table.HasValue(PLUGIN.veritasStats, stat) then
			return "Invalid stat."
		end

		value = math.Clamp(value, 1, 10)
		targetChar:SetData("veritas_grade_" .. stat, value)
		client:Notify("Set grade of " .. stat:upper() .. " to " .. value .. " for " .. targetChar:GetName())
	end
})

ix.command.Add("GradeAdd", {
	description = "Add to a stat grade.",
	arguments = {ix.type.character, ix.type.string, ix.type.number},
	adminOnly = true,
	OnRun = function(self, client, targetChar, stat, amount)
		stat = stat:lower()
		if not table.HasValue(PLUGIN.veritasStats, stat) then
			return "Invalid stat."
		end

		local current = targetChar:GetData("veritas_grade_" .. stat, PLUGIN:GetStatGrade(targetChar:GetData("veritas_" .. stat, 5)))
		local new = math.Clamp(current + amount, 1, 10)
		targetChar:SetData("veritas_grade_" .. stat, new)

		client:Notify("Grade of " .. stat:upper() .. " set to " .. new .. " for " .. targetChar:GetName())
	end
})

ix.command.Add("RollStat", {
	description = "Roll a stat with optional bonus. Format: /rollstat stat [bonus]",
	arguments = {
		ix.type.string,
		ix.type.number, -- optional
	},
	OnRun = function(self, client, stat, bonus)
		bonus = bonus or 0
		stat = stat:lower()

		if not table.HasValue(PLUGIN.veritasStats, stat) then
			client:Notify("Invalid stat.")
			return
		end

		local char = client:GetCharacter()
		local base = char:GetData("veritas_" .. stat, 5)
		local roll = math.random(1, 100)
		local total = roll + base + bonus

		local msg = string.format(
			"%s rolls [%s]: d100(%d) + %d (stat) + %d (bonus) = %d",
			client:Nick(),
			stat:upper(),
			roll, base, bonus, total
		)

		for _, v in ipairs(player.GetAll()) do
			if v:GetPos():Distance(client:GetPos()) <= 600 then
				v:ChatPrint(msg)
			end
		end
	end
})


ix.command.Add("ContestRoll", {
	description = "Initiate a contested roll.",
	OnRun = function(self, client)
		net.Start("ixVeritasOpenContestAttacker")
		net.Send(client)
	end
})

ix.command.Add("GMContestedRoll", {
	description = "GM: Perform a contested roll against a player using custom attacker stats.",
	arguments = {
		ix.type.character,      -- target player
		ix.type.string,         -- stat name
		ix.type.number,         -- stat value
		ix.type.number,         -- bonus
		ix.type.number          -- grade
	},
	adminOnly = true,
	OnRun = function(self, client, targetChar, stat, statValue, bonus, grade)
		local targetPly = targetChar:GetPlayer()
		if not IsValid(targetPly) then
			client:Notify("Target player not found.")
			return
		end

		-- Ensure valid stat
		stat = stat:lower()
		if not table.HasValue(PLUGIN.veritasStats, stat) then
			client:Notify("Invalid stat.")
			return
		end

		-- Save GM contest data
		targetPly.gmContest = {
			value = statValue,
			bonus = bonus,
			grade = grade,
		}

		net.Start("ixVeritasOpenContestDefender")
			net.WriteString("GM")
			net.WriteEntity(client) -- not used for logic
		net.Send(targetPly)

		client:Notify("Sent GM contested roll to " .. targetPly:Nick())
	end
})

ix.command.Add("RollInitiative", {
	description = "Roll 1d100 + bonus to enter initiative.",
	arguments = { ix.type.number }, -- optional bonus
	OnRun = function(self, client, bonus)
		bonus = bonus or 0
		local roll = math.random(1, 100)
		local total = roll + bonus

		-- Prevent double-adding
		for _, entry in ipairs(PLUGIN.initiativeQueue) do
			if entry.ply == client then
				return client:Notify("You already rolled initiative.")
			end
		end

		table.insert(PLUGIN.initiativeQueue, {
			name = client:Nick(),
			ply = client,
			roll = total
		})

		-- Re-sort
		table.sort(PLUGIN.initiativeQueue, function(a, b)
			return a.roll > b.roll
		end)
		PLUGIN:SyncInitiative()

		client:Notify("You rolled " .. roll .. " + " .. bonus .. " = " .. total .. " initiative.")
	end
})

ix.command.Add("NpcInitiative", {
	description = "GM: Add an NPC to the initiative queue.",
	adminOnly = true,
	arguments = { ix.type.string, ix.type.number }, -- name, bonus
	OnRun = function(self, client, name, bonus)
		bonus = bonus or 0
		local roll = math.random(1, 100)
		local total = roll + bonus

		table.insert(PLUGIN.initiativeQueue, {
			name = name .. " (NPC)",
			npc = true,
			roll = total
		})


		table.sort(PLUGIN.initiativeQueue, function(a, b)
			return a.roll > b.roll
		end)
		PLUGIN:SyncInitiative()
		client:Notify("NPC '" .. name .. "' rolled " .. roll .. " + " .. bonus .. " = " .. total .. " initiative.")
	end
})

ix.command.Add("ShowInitiative", {
	description = "Toggle the on-screen initiative HUD display.",
	OnRun = function(self, client)
		net.Start("ixVeritasToggleInitiativeHud")
			net.WriteBool(true) -- true = show
		net.Send(client)
		
		PLUGIN:SyncInitiative()
		client:Notify("Initiative HUD enabled. Use /hideinitiative to disable it.")
	end
})

ix.command.Add("HideInitiative", {
	description = "Hide the on-screen initiative HUD.",
	OnRun = function(self, client)
		net.Start("ixVeritasToggleInitiativeHud")
			net.WriteBool(false)
		net.Send(client)

		PLUGIN:SyncInitiative()
		client:Notify("Initiative HUD disabled.")
	end
})

ix.command.Add("PassTurn", {
	description = "Pass your turn to the next character.",
	OnRun = function(self, client)
		local current = PLUGIN.initiativeQueue[PLUGIN.initiativeTurnIndex]
		if not current or current.ply ~= client then
			client:Notify("It is not your turn.")
			return
		end

		PLUGIN.initiativeTurnIndex = PLUGIN.initiativeTurnIndex + 1
		if PLUGIN.initiativeTurnIndex > #PLUGIN.initiativeQueue then
			PLUGIN.initiativeTurnIndex = 1
		end
		
		PLUGIN:SyncInitiative()
	end
})

ix.command.Add("ForceNextTurn", {
	description = "Force the next initiative turn.",
	adminOnly = true,
	OnRun = function(self, client)
		if #PLUGIN.initiativeQueue == 0 then
			client:Notify("Initiative queue is empty.")
			return
		end

		local current = PLUGIN.initiativeQueue[PLUGIN.initiativeTurnIndex]
		PLUGIN.initiativeTurnIndex = PLUGIN.initiativeTurnIndex + 1

		if PLUGIN.initiativeTurnIndex > #PLUGIN.initiativeQueue then
			PLUGIN.initiativeTurnIndex = 1
		end
		PLUGIN:SyncInitiative()

		local next = PLUGIN.initiativeQueue[PLUGIN.initiativeTurnIndex]
		client:Notify("Forced next turn. It's now " .. next.name .. "'s turn.")
	end
})

ix.command.Add("ClearInitiative", {
	description = "Clear the initiative queue.",
	adminOnly = true,
	OnRun = function(self, client)
		PLUGIN.initiativeQueue = {}
		PLUGIN.initiativeTurnIndex = 1
		PLUGIN:SyncInitiative()
		client:Notify("Initiative queue cleared.")
	end
})

ix.command.Add("LeaveInitiative", {
	description = "Remove yourself from the initiative order.",
	OnRun = function(self, client)
		for i, entry in ipairs(PLUGIN.initiativeQueue) do
			if entry.ply == client then
				table.remove(PLUGIN.initiativeQueue, i)

				-- Adjust turn index if needed
				if i <= PLUGIN.initiativeTurnIndex then
					PLUGIN.initiativeTurnIndex = math.max(1, PLUGIN.initiativeTurnIndex - 1)
				end
				
				PLUGIN:SyncInitiative()
				client:Notify("You have been removed from the initiative.")
				return
			end
		end

		client:Notify("You are not in the initiative order.")
	end
})

ix.command.Add("RemoveInitiative", {
	description = "Remove an NPC or player from initiative by name.",
	adminOnly = true,
	arguments = { ix.type.string },
	OnRun = function(self, client, name)
		local removed = false

		for i = #PLUGIN.initiativeQueue, 1, -1 do
			local entry = PLUGIN.initiativeQueue[i]

			if string.lower(entry.name) == string.lower(name) then
				table.remove(PLUGIN.initiativeQueue, i)

				if i <= PLUGIN.initiativeTurnIndex then
					PLUGIN.initiativeTurnIndex = math.max(1, PLUGIN.initiativeTurnIndex - 1)
				end
				
				PLUGIN:SyncInitiative()
				client:Notify("Removed '" .. entry.name .. "' from initiative.")
				removed = true
				break
			end
		end

		if not removed then
			client:Notify("No one by that name found in the initiative order.")
		end
	end
})


ix.command.Add("Attack", {
	description = "Open the attack menu.",
	OnRun = function(self, client)
		net.Start("ixVeritasOpenAttackMenu")
		net.Send(client)
	end
})

ix.command.Add("NpcAttack", {
	description = "Open the NPC attack menu for GM-controlled NPC combat.",
	adminOnly = true,
	OnRun = function(self, client)
		net.Start("ixVeritasOpenNpcAttackMenu")
		net.Send(client)
	end
})