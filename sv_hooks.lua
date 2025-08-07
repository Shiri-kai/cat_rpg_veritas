local PLUGIN = PLUGIN

util.AddNetworkString("ixVeritasOpenCharSheet")
util.AddNetworkString("ixVeritasRollStat")
util.AddNetworkString("ixVeritasOpenStatSetup")
util.AddNetworkString("ixVeritasSubmitStats")
util.AddNetworkString("ixVeritasSendCharSheet")
util.AddNetworkString("ixVeritasRequestCharSheet")

util.AddNetworkString("ixVeritasOpenContestAttacker")
util.AddNetworkString("ixVeritasContestSend")
util.AddNetworkString("ixVeritasOpenContestDefender")
util.AddNetworkString("ixVeritasContestResolve")

util.AddNetworkString("ixVeritasEditNpc")
util.AddNetworkString("ixVeritasSaveNpcData")
util.AddNetworkString("ixVeritasOpenNpcEditor")

util.AddNetworkString("ixVeritasSyncInitiative")
util.AddNetworkString("ixVeritasToggleInitiativeHud")

util.AddNetworkString("ixVeritasOpenAttackMenu")
util.AddNetworkString("ixVeritasSubmitAttack")
util.AddNetworkString("ixVeritasDefensePrompt")
util.AddNetworkString("ixVeritasDefenseResponse")
util.AddNetworkString("ixVeritasNpcAttack")
util.AddNetworkString("ixVeritasOpenNpcAttackMenu")
util.AddNetworkString("ixVeritasCombatLog")


function PLUGIN:CharacterCreated(client, character)
	for _, stat in ipairs(PLUGIN.veritasStats) do
		character:SetData("veritas_" .. stat, 5)
		character:SetData("veritas_grade_" .. stat, 1)
	end
end

net.Receive("ixVeritasRequestCharSheet", function(_, ply)
	local target = net.ReadEntity()

	if not IsValid(target) or not target:IsPlayer() then return end

	local char = target:GetCharacter()
	if not char then return end

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
end)

net.Receive("ixVeritasRollStat", function(_, ply)
	local stat = net.ReadString()
	local char = ply:GetCharacter()

	if not table.HasValue(PLUGIN.veritasStats, stat) then return end

	local value = char:GetData("veritas_" .. stat, 5)
	local roll = math.random(1, 100)
	local total = value + roll
	local grade = char:GetData("veritas_grade_" .. stat, 1)

	local output = {
		string.format("[SKILL] %s rolls %s → d100(%d) + Stat(%d) = %d [Grade: %d]", ply:Nick(), stat:upper(), roll, value, total, grade)
	}

	for _, v in ipairs(player.GetAll()) do
		if v:GetPos():Distance(ply:GetPos()) <= 600 then
			net.Start("ixVeritasCombatLog")
				net.WriteString(util.TableToJSON(output))
			net.Send(v)
		end
	end
end)

net.Receive("ixVeritasSubmitStats", function(len, ply)
	local char = ply:GetCharacter()

	if not char or char:GetData("veritas_setup_complete", false) then
		ply:Notify("Stat setup already completed.")
		return
	end

	local statTable = net.ReadTable()
	local total = 0

	for stat, value in pairs(statTable) do
		if not table.HasValue(PLUGIN.veritasStats, stat) then return end
		value = math.Clamp(value, 5, 20)
		total = total + (value - 5)
	end

	if total ~= 40 then
		ply:Notify("You must allocate exactly 40 points.")
		return
	end

	for stat, value in pairs(statTable) do
		char:SetData("veritas_" .. stat, value)
	end

	char:SetData("veritas_setup_complete", true)
	ply:Notify("Stat setup complete.")
end)

-- After attacker picks stat/bonus/target
net.Receive("ixVeritasContestSend", function(len, ply)
	local stat = net.ReadString()
	local bonus = net.ReadInt(16)
	local target = net.ReadEntity()

	if not IsValid(target) then return end

	local isNPC = IsValid(target) and target:GetClass() == "ix_veritas_npc"

	-- Save attacker data
	ply.contestPending = {
		stat = stat,
		bonus = bonus,
		defender = target
	}

	-- If it's a player, send the defender UI
	if target:IsPlayer() then
		net.Start("ixVeritasOpenContestDefender")
			net.WriteString(ply:Nick())
			net.WriteEntity(ply)
			
		net.Send(target)
		return
	end

	-- If target is an NPC, auto-resolve
	if isNPC then
		local defenderStat = stat
		local defenderBonus = 0
		local attacker = ply
		local defender = target
		local attackerChar = attacker:GetCharacter()
		if not attackerChar then return end

		local aStat = stat
		local aBonus = bonus or 0
		local aRaw = math.random(1, 100)
		local aBase = attackerChar:GetData("veritas_" .. aStat, 5)
		local aGrade = attackerChar:GetData("veritas_grade_" .. aStat, 1)
		local aInitial = aRaw + aBase + aBonus

		local dStat = defenderStat
		local dBonus = defenderBonus
		local dRaw = math.random(1, 100)
		local dBase = defender:GetNetVar("veritas_stat_" .. dStat, 5)
		local dGrade = defender:GetNetVar("veritas_grade_" .. dStat, 1)
		local dInitial = dRaw + dBase + dBonus

		local aFinal, dFinal = aInitial, dInitial
		local gradeText = ""

		if aGrade < dGrade then
			local diff = dGrade - aGrade
			local penalty = diff * 0.1
			aFinal = math.floor(aInitial * (1 - penalty))
			gradeText = string.format("Grade difference: %s is %d grade(s) lower. %d%% penalty applied.", attacker:Nick(), diff, penalty * 100)
		elseif dGrade < aGrade then
			local diff = aGrade - dGrade
			local penalty = diff * 0.1
			dFinal = math.floor(dInitial * (1 - penalty))
			local dName = defender:GetNpcName() or "NPC"
			gradeText = string.format("Grade difference: %s is %d grade(s) lower. %d%% penalty applied.", dName, diff, penalty * 100)
		else
			gradeText = "No grade difference. No penalties applied."
		end

		local winnerText = ""
		local dName = defender:GetNpcName() or "NPC"
		if aFinal > dFinal then
			winnerText = attacker:Nick() .. " wins the contest!"
		elseif dFinal > aFinal then
			winnerText = dName .. " wins the contest!"
		else
			winnerText = "The contest ends in a tie!"
		end

		local output = {
			string.format("[CONTEST] %s vs %s", attacker:Nick(), dName),
			string.format("%s rolled d100(%d) + Stat(%d) + Bonus(%d) = %d [Grade: %d]", attacker:Nick(), aRaw, aBase, aBonus, aInitial, aGrade),
			string.format("%s rolled d100(%d) + Stat(%d) + Bonus(%d) = %d [Grade: %d]", dName, dRaw, dBase, dBonus, dInitial, dGrade),
			string.format("%s vs %s → %d vs %d", attacker:Nick(), dName, aFinal, dFinal),
			gradeText,
			winnerText
		}

		for _, v in ipairs(player.GetAll()) do
			local nearAttacker = IsValid(attacker) and v:GetPos():Distance(attacker:GetPos()) <= 600
			local nearDefender = IsValid(defender) and v:GetPos():Distance(defender:GetPos()) <= 600

			if nearAttacker or nearDefender then
				net.Start("ixVeritasCombatLog")
					net.WriteString(util.TableToJSON(output))
				net.Send(v)
			end
		end

		attacker.contestPending = nil
	end
end)



-- Defender accepts/denies and picks stat
net.Receive("ixVeritasContestResolve", function(_, ply)
	local accepted = net.ReadBool()
	local defenderStat = net.ReadString()
	local defenderBonus = net.ReadInt(16)
	local attacker = net.ReadEntity()

	-- GM-initiated contest
	if ply.gmContest then
		local info = ply.gmContest
		local gmName = "GM"
		local aValue = info.value
		local aBonus = info.bonus or 0
		local aRaw = math.random(1, 100)
		local aInitial = aRaw + aValue + aBonus
		local aGrade = info.grade or 1

		local dStat = defenderStat
		local dBonus = defenderBonus or 0
		local dRaw = math.random(1, 100)
		local dBase = ply:GetCharacter():GetData("veritas_" .. dStat, 5)
		local dGrade = ply:GetCharacter():GetData("veritas_grade_" .. dStat, 1)
		local dInitial = dRaw + dBase + dBonus

		local aFinal, dFinal = aInitial, dInitial
		local gradeText = ""

		if aGrade < dGrade then
			local diff = dGrade - aGrade
			local penalty = diff * 0.1
			aFinal = math.floor(aInitial * (1 - penalty))
			gradeText = string.format("Grade difference: %s is %d grade(s) lower. %d%% penalty applied.", gmName, diff, penalty * 100)
		elseif dGrade < aGrade then
			local diff = aGrade - dGrade
			local penalty = diff * 0.1
			dFinal = math.floor(dInitial * (1 - penalty))
			gradeText = string.format("Grade difference: %s is %d grade(s) lower. %d%% penalty applied.", ply:Nick(), diff, penalty * 100)
		else
			gradeText = "No grade difference. No penalties applied."
		end

		local winnerText = ""
		if aFinal > dFinal then
			winnerText = gmName .. " wins the contest!"
		elseif dFinal > aFinal then
			winnerText = ply:Nick() .. " wins the contest!"
		else
			winnerText = "The contest ends in a tie!"
		end

		local output = {
			string.format("[CONTEST] GM vs %s", ply:Nick()),
			string.format("GM rolled d100(%d) + Stat(%d) + Bonus(%d) = %d [Grade: %d]", aRaw, aValue, aBonus, aInitial, aGrade),
			string.format("%s rolled d100(%d) + Stat(%d) + Bonus(%d) = %d [Grade: %d]", ply:Nick(), dRaw, dBase, dBonus, dInitial, dGrade),
			string.format("GM vs %s → %d vs %d", ply:Nick(), aFinal, dFinal),
			gradeText,
			winnerText
		}

		for _, v in ipairs(player.GetAll()) do
			local nearDefender = IsValid(ply) and v:GetPos():Distance(ply:GetPos()) <= 600
	
			if nearDefender then
				net.Start("ixVeritasCombatLog")
					net.WriteString(util.TableToJSON(output))
				net.Send(v)
			end
		end

		ply.gmContest = nil
		return
	end

	-- Player-initiated contest (player or NPC target)
	if not IsValid(attacker) or not attacker.contestPending then return end

	local defender = attacker.contestPending.defender
	if not IsValid(defender) then return end

	local isNPC = defender:GetClass() == "ix_veritas_npc"

	-- NPCs auto-accept contests
	if not accepted and not isNPC then
		attacker:Notify(ply:Nick() .. " declined the contest.")
		ply:Notify("You declined the contest.")
		attacker.contestPending = nil
		return
	end

	local attackerChar = attacker:GetCharacter()
	if not attackerChar then return end

	local aStat = attacker.contestPending.stat
	local aBonus = attacker.contestPending.bonus or 0
	local aRaw = math.random(1, 100)
	local aBase = attackerChar:GetData("veritas_" .. aStat, 5)
	local aGrade = attackerChar:GetData("veritas_grade_" .. aStat, 1)
	local aInitial = aRaw + aBase + aBonus

	local dStat = defenderStat
	local dBonus = defenderBonus or 0
	local dRaw = math.random(1, 100)
	local dBase, dGrade

	if isNPC then
		dBase = defender:GetNetVar("veritas_stat_" .. dStat, 5)
		dGrade = defender:GetNetVar("veritas_grade_" .. dStat, 1)
	else
		local defenderChar = defender:GetCharacter()
		if not defenderChar then return end
		dBase = defenderChar:GetData("veritas_" .. dStat, 5)
		dGrade = defenderChar:GetData("veritas_grade_" .. dStat, 1)
	end

	local dInitial = dRaw + dBase + dBonus

	local aFinal, dFinal = aInitial, dInitial
	local gradeText = ""

	if aGrade < dGrade then
		local diff = dGrade - aGrade
		local penalty = diff * 0.1
		aFinal = math.floor(aInitial * (1 - penalty))
		gradeText = string.format("Grade difference: %s is %d grade(s) lower. %d%% penalty applied.", attacker:Nick(), diff, penalty * 100)
	elseif dGrade < aGrade then
		local diff = aGrade - dGrade
		local penalty = diff * 0.1
		dFinal = math.floor(dInitial * (1 - penalty))
		local dName = isNPC and (defender:GetNpcName() or "NPC") or defender:Nick()
		gradeText = string.format("Grade difference: %s is %d grade(s) lower. %d%% penalty applied.", dName, diff, penalty * 100)
	else
		gradeText = "No grade difference. No penalties applied."
	end

	local winnerText = ""
	if aFinal > dFinal then
		winnerText = attacker:Nick() .. " wins the contest!"
	elseif dFinal > aFinal then
		local dName = isNPC and (defender:GetNpcName() or "NPC") or defender:Nick()
		winnerText = dName .. " wins the contest!"
	else
		winnerText = "The contest ends in a tie!"
	end

	local dName = isNPC and (defender:GetNpcName() or "NPC") or defender:Nick()

	local output = {
		string.format("[CONTEST] %s vs %s", attacker:Nick(), dName),
		string.format("%s rolled d100(%d) + Stat(%d) + Bonus(%d) = %d [Grade: %d]", attacker:Nick(), aRaw, aBase, aBonus, aInitial, aGrade),
		string.format("%s rolled d100(%d) + Stat(%d) + Bonus(%d) = %d [Grade: %d]", dName, dRaw, dBase, dBonus, dInitial, dGrade),
		string.format("%s vs %s → %d vs %d", attacker:Nick(), dName, aFinal, dFinal),
		gradeText,
		winnerText
	}

	for _, v in ipairs(player.GetAll()) do
		local nearAttacker = IsValid(attacker) and v:GetPos():Distance(attacker:GetPos()) <= 600
		local nearDefender = IsValid(defender) and v:GetPos():Distance(defender:GetPos()) <= 600

		if nearAttacker or nearDefender then
			net.Start("ixVeritasCombatLog")
				net.WriteString(util.TableToJSON(output))
			net.Send(v)
		end
	end

	attacker.contestPending = nil
end)



net.Receive("ixVeritasSaveNpcData", function(len, client)
	local ent = net.ReadEntity()
	local name = net.ReadString()
	local model = net.ReadString()
	local statTable = net.ReadTable()
	local defenseStat = net.ReadString()
	local weaponTraits = net.ReadTable()
	local armorTraits = net.ReadTable()
	local weaponName = net.ReadString()

	if not IsValid(ent) or ent:GetClass() ~= "ix_veritas_npc" then
		client:Notify("Invalid NPC.")
		return
	end

	-- Apply to entity
	ent:SetModel(model)
	ent:SetNetVar("veritas_name", name)
	ent:SetNetVar("veritas_model", model)

	for stat, values in pairs(statTable) do
		ent:SetNetVar("veritas_stat_" .. stat, values.value)
		ent:SetNetVar("veritas_grade_" .. stat, values.grade)
	end

	ent:SetNetVar("veritas_defense_stat", defenseStat)

	-- Store traits
	ent:SetNetVar("veritas_weapon", weaponTraits)
	ent:SetNetVar("veritas_weapon_name", weaponName)
	ent:SetNetVar("veritas_armor", armorTraits)

	client:Notify("NPC data saved successfully.")
end)



function PLUGIN:SyncInitiative()
	net.Start("ixVeritasSyncInitiative")
		net.WriteTable(self.initiativeQueue or {})
		net.WriteUInt(self.initiativeTurnIndex or 1, 8)
	net.Broadcast()
end


net.Receive("ixVeritasSubmitAttack", function(len, ply)
	local target = net.ReadEntity()
	local stat = net.ReadString()
	local shotCount = net.ReadUInt(8)
	local bonus = net.ReadInt(16)
	local slot = net.ReadString()

	local char = ply:GetCharacter()
	if not char or not IsValid(target) then return end

	local plugin = ix.plugin.Get("cat_rpg_veritas")
	if not plugin then return end

	local inv = char:GetInventory()
	local weaponItem

	-- Look for the weapon in the requested equipSlot
	for _, item in pairs(inv:GetItems()) do
		if item.isWeapon and item:GetData("equipSlot") == slot then
			weaponItem = item
			break
		end
	end

	if not weaponItem then
		ply:Notify("No valid weapon equipped in slot: " .. slot)
		return
	end

	-- Finally, resolve combat with correct shotCount
	plugin:ResolveCombat(ply, target, stat, nil, bonus, shotCount)
end)

local pendingDefenses = {} -- key = callback ID, value = data for pending attack

net.Receive("ixVeritasDefenseResponse", function(len, ply)
	local callbackID = net.ReadUInt(8)
	local stat = net.ReadString()
	local bonus = net.ReadInt(16)

	-- Had to explicitely call plugin here, or it would break for some reason
	local plugin = ix.plugin.Get("cat_rpg_veritas")
	if not plugin then
		return
	end

	local pending = plugin.pendingDefenses and plugin.pendingDefenses[callbackID]
	if not pending then
		return
	end

	-- Clean up stored pending defense
	plugin.pendingDefenses[callbackID] = nil

	-- Call ResolveCombat with full context
	plugin:ResolveCombat(
		pending.attacker,
		pending.defender,
		pending.attackStat,
		stat, -- defender stat from UI
		pending.attackBonus,
		pending.shotCount,
		bonus  -- defender bonus from UI
	)
end)

net.Receive("ixVeritasNpcAttack", function(len, ply)
	if not ply:IsAdmin() then return end

	local attacker = net.ReadEntity()
	local defender = net.ReadEntity()
	local atkStat = net.ReadString()
	local atkBonus = net.ReadInt(16)
	local shotCount = net.ReadUInt(8)

	if not IsValid(attacker) or not IsValid(defender) then
		ply:Notify("Invalid attacker or target.")
		return
	end

	if attacker:GetClass() ~= "ix_veritas_npc" then
		ply:Notify("Attacker must be a valid Veritas NPC.")
		return
	end

	PLUGIN:ResolveCombat(attacker, defender, atkStat, nil, atkBonus, shotCount)
end)