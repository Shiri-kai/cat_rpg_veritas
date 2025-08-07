local PLUGIN = PLUGIN

-- Utility stuff for combat
PLUGIN.validWeaponSlots = {
	"primary",
	"secondary",
	"tertiary",
	"melee"
}

PLUGIN.validArmorSlot = "armor"

PLUGIN.pendingDefenses = PLUGIN.pendingDefenses or {}

function PLUGIN:CanEquipItem(char, slot)
	local inv = char:GetInventory()
	for _, item in pairs(inv:GetItems()) do
		if item:GetData("equipSlot") == slot then
			return false, item
		end
	end
	return true
end

function PLUGIN:GetEquippedItem(char, slot)
	local inv = char:GetInventory()
	for _, item in pairs(inv:GetItems()) do
		if item:GetData("equipSlot") == slot then
			return item
		end
	end
end

function PLUGIN:EquipItem(item, slot)
	local char = item.player:GetCharacter()
	local canEquip, conflictItem = self:CanEquipItem(char, slot)

	if not canEquip then
		item.player:Notify("Unequip " .. conflictItem.name .. " from slot '" .. slot .. "' first.")
		return false
	end

	item:SetData("equipSlot", slot)
	item.player:Notify("Equipped " .. item.name .. " to " .. slot .. ".")
	return true
end

function PLUGIN:UnequipItem(item)
	item:SetData("equipSlot", nil)
	if item.player and IsValid(item.player) then
		item.player:Notify("Unequipped " .. item.name .. ".")
	end
end


function PLUGIN:RollDamage(expression)
	if not expression or type(expression) ~= "string" then return 0 end

	expression = expression:lower():gsub("%s", "") -- remove whitespace

	local diceCount, diceSides, op, mod
	local total = 0
	local rolls = {}

	-- Match: XdY+Z or XdYxZ
	diceCount, diceSides, op, mod = expression:match("^(%d+)d(%d+)([+x])(%d+)$")
	if diceCount and diceSides then
		diceCount = tonumber(diceCount)
		diceSides = tonumber(diceSides)
		mod = tonumber(mod)

		for i = 1, diceCount do
			local roll = math.random(1, diceSides)
			total = total + roll
			table.insert(rolls, roll)
		end

		if op == "+" then
			total = total + mod
		elseif op == "x" then
			total = total * mod
		end

		return total, { rolls = rolls, formula = expression, op = op, mod = mod }
	end

	-- Match: Just XdY
	diceCount, diceSides = expression:match("^(%d+)d(%d+)$")
	if diceCount and diceSides then
		diceCount = tonumber(diceCount)
		diceSides = tonumber(diceSides)

		for i = 1, diceCount do
			local roll = math.random(1, diceSides)
			total = total + roll
			table.insert(rolls, roll)
		end

		return total, { rolls = rolls, formula = expression, op = nil, mod = 0 }
	end

	-- Match: static number
	local static = tonumber(expression)
	if static then
		return static, { rolls = { static }, formula = expression, op = nil, mod = 0 }
	end

	return 0, { rolls = {}, formula = expression, op = nil, mod = 0 }
end

function PLUGIN:GetCharacterStat(ent, stat)
	if not IsValid(ent) then return 0 end

	if ent:IsPlayer() then
		local char = ent:GetCharacter()
		return char and char:GetData("veritas_" .. stat, 5) or 5
	elseif ent:GetClass() == "ix_veritas_npc" then
		return ent:GetNetVar("veritas_stat_" .. stat, 5)
	end

	return 5
end

function PLUGIN:GetCharacterGrade(ent, stat)
	if not IsValid(ent) then return 1 end

	local baseGrade = 1

	if ent:IsPlayer() then
		local char = ent:GetCharacter()
		baseGrade = char and char:GetData("veritas_grade_" .. stat, 1) or 1
	elseif ent:GetClass() == "ix_veritas_npc" then
		baseGrade = ent:GetNetVar("veritas_grade_" .. stat, 1)
	end

	local boost = self:GetPowerArmorBoost(ent, stat)
	return math.min(baseGrade + boost, 10)
end

function PLUGIN:GetEquippedWeapon(ent)
	if ent:IsPlayer() then
		local inv = ent:GetCharacter():GetInventory()
		for _, item in pairs(inv:GetItems()) do
			if item:GetData("equipSlot") and item.isWeapon then
				return item
			end
		end
	elseif IsValid(ent) and ent:GetClass() == "ix_veritas_npc" then
		local traits = ent:GetNetVar("veritas_weapon", nil)
		if traits then
			-- Fake "item" object with GetWeaponTraits() support
			return {
				GetWeaponTraits = function()
					return traits
				end,
				name = ent:GetNetVar("veritas_weapon_name") or (ent:GetNpcName() .. "'s Weapon")
			}
		end
	end
end

function PLUGIN:GetEquippedArmor(ent)
	if ent:IsPlayer() then
		local inv = ent:GetCharacter():GetInventory()
		for _, item in pairs(inv:GetItems()) do
			if item:GetData("equipSlot") == "armor" and item.isArmor then
				return item
			end
		end
	elseif IsValid(ent) and ent:GetClass() == "ix_veritas_npc" then
		local traits = ent:GetNetVar("veritas_armor", nil)
		if traits then
			return {
				GetArmorData = function()
					return traits
				end,
				name = ent:GetNpcName() .. "'s Armor"
			}
		end
	end
end

function PLUGIN:DoCombatRoll(ent, stat, bonus)
	local base = self:GetCharacterStat(ent, stat)
	local grade = self:GetCharacterGrade(ent, stat)
	local rawRoll = math.random(1, 100)
	local total = rawRoll + base + bonus

	return {
		raw = rawRoll,
		stat = base,
		bonus = bonus,
		grade = grade,
		total = total
	}
end

function PLUGIN:MitigateTotalDamage(totalWounds, weaponTraits, armorTraits)
	local ap = weaponTraits.ArmorPiercing or 0
	local aa = weaponTraits.AntiArmor or 0

	local sp = armorTraits.StoppingPower or 0
	local specialized = armorTraits.SpecializedProtection or {}
	local damageType = nil

	-- Detect damage type
	for k in pairs(weaponTraits) do
		if k == "Kinetic" or k == "Energy" or k == "Plasma" then
			damageType = k
			break
		end
	end

	if damageType and specialized[damageType] then
		sp = sp + specialized[damageType]
	end

	local effectiveSP = math.max(0, sp - ap)

	-- Extreme Protection: all mitigated
	if armorTraits.ExtremeProtection then
		return {
			total = totalWounds,
			mitigated = totalWounds,
			overflow = 0,
			fieldBlocked = false
		}
	end

	-- Field block check (this blocks *everything* if it procs)
	if armorTraits.Field then
		local chance = armorTraits.Field.chance or 0
		local uses = armorTraits.Field.uses or 0

		if uses > 0 and math.random(1, 100) <= chance then
			armorTraits.Field.uses = uses - 1
			return {
				total = totalWounds,
				mitigated = totalWounds,
				overflow = 0,
				fieldBlocked = true
			}
		end
	end

	-- Final calculation
	local overflow = math.max(0, totalWounds - effectiveSP)
	local mitigated = totalWounds - overflow

	-- Apply Anti-Armor bonus (adds to mitigated side)
	if aa > 0 then
		mitigated = math.min(totalWounds, mitigated + aa)
		overflow = totalWounds - mitigated
	end

	return {
		total = totalWounds,
		mitigated = mitigated,
		overflow = overflow,
		fieldBlocked = false
	}
end



function PLUGIN:ResolveCombat(attacker, defender, atkStat, defStat, atkBonus, shotCount, defBonus)
	atkBonus = atkBonus or 0
	shotCount = shotCount or 1
	defBonus = defBonus or 0

	print("[Veritas] ResolveCombat called: attacker =", attacker, "defender =", defender)
	
	-- If defender is a player and no defense stat/bonus is provided, prompt them
	if defender:IsPlayer() and not defStat then
		local callbackID = math.random(1, 254)

		self.pendingDefenses = self.pendingDefenses or {}
		self.pendingDefenses[callbackID] = {
			attacker = attacker,
			defender = defender,
			attackStat = atkStat,
			attackBonus = atkBonus,
			shotCount = shotCount
		}

		net.Start("ixVeritasDefensePrompt")
			net.WriteEntity(attacker)
			net.WriteUInt(callbackID, 8)
		net.Send(defender)

		return -- Wait for response
	end

	local weapon = self:GetEquippedWeapon(attacker)
	local armor = self:GetEquippedArmor(defender)

	if not weapon then
		if attacker:IsPlayer() then
			attacker:Notify("You have no weapon equipped.")
		elseif IsValid(attacker) then
			for _, ply in ipairs(player.GetAll()) do
				if ply:IsAdmin() and ply:GetPos():Distance(attacker:GetPos()) <= 10000 then
					ply:Notify("[Veritas] NPC '" .. (attacker.GetNpcName and attacker:GetNpcName() or attacker:GetClass()) .. "' has no weapon assigned.")
				end
			end
		end
		return
	end

	local weaponTraits = weapon:GetWeaponTraits() or {}
	local armorTraits = armor and armor:GetArmorData() or {}

	-- Default defense stat fallback
	if not defStat then
		if defender:IsPlayer() then
			defStat = "rflx"
		else
			defStat = defender:GetNetVar("veritas_defense_stat", "tghn")
		end
	end

	local allRolls = {}
	local hitCount = 0
	local totalWounds = 0
	local rawHitWounds = {}

	for i = 1, shotCount do
		local atkRoll = self:DoCombatRoll(attacker, atkStat, atkBonus)
		local defRoll = self:DoCombatRoll(defender, defStat, defBonus)

		-- Grade difference penalties
		local atkGrade = atkRoll.grade or 1
		local defGrade = defRoll.grade or 1
		local gradeDiff = atkGrade - defGrade

		if gradeDiff < 0 then
			local penalty = math.abs(gradeDiff) * 0.10
			atkRoll.gradePenalty = penalty
			atkRoll.total = math.floor((atkRoll.raw + atkRoll.stat + atkRoll.bonus) * (1 - penalty))
		elseif gradeDiff > 0 then
			local penalty = math.abs(gradeDiff) * 0.10
			defRoll.gradePenalty = penalty
			defRoll.total = math.floor((defRoll.raw + defRoll.stat + defRoll.bonus) * (1 - penalty))
		end

		local hit = atkRoll.total > defRoll.total
		local multiplier = 1

		-- Trait-based wound multiplier
		if weaponTraits.Brutal and atkStat == "strn" then
			multiplier = math.max(1, math.floor(atkRoll.total / weaponTraits.Brutal))
		elseif weaponTraits.Nimble and atkStat == "rflx" then
			multiplier = math.max(1, math.floor(atkRoll.total / weaponTraits.Nimble))
		end

		local hitWoundBreakdown = {}

		if hit then
			hitCount = hitCount + 1

			for j = 1, multiplier do
				local rawWound = weaponTraits.Wounds or 1

				if type(rawWound) == "string" then
					local rolled = self:RollDamage(rawWound)
					rawWound = rolled or 0
				end

				rawWound = math.max(0, rawWound)

				-- Collect wound breakdown
				table.insert(rawHitWounds, {
					damage = rawWound,
					ap = weaponTraits.ArmorPiercing or 0,
					aa = weaponTraits.AntiArmor or 0,
					sp = armorTraits.StoppingPower or 0
				})

				totalWounds = totalWounds + rawWound

				table.insert(hitWoundBreakdown, {
					rolled = rawWound,
					ap = weaponTraits.ArmorPiercing or 0,
					sp = armorTraits.StoppingPower or 0,
					aa = weaponTraits.AntiArmor or 0
				})
			end
		end

		table.insert(allRolls, {
			atkRoll = atkRoll,
			defRoll = defRoll,
			hit = hit,
			multiplier = multiplier,
			fieldBlocked = false, -- global block handled later
			hitWoundBreakdown = hitWoundBreakdown
		})
	end

	-- Apply armor mitigation
	local mitigation = self:MitigateTotalDamage(totalWounds, weaponTraits, armorTraits)

	local resultData = {
		attackerEntity = attacker,
		defenderEntity = defender,
		weapon = weapon,
		shotCount = shotCount,
		allRolls = allRolls,
		hitCount = hitCount,
		totalWounds = mitigation.total,
		totalMitigated = mitigation.mitigated,
		totalOverflow = mitigation.overflow,
		fieldBlockedCount = mitigation.fieldBlocked and 1 or 0
	}

	self:AnnounceCombatResults(resultData)
end





function PLUGIN:AnnounceCombatResults(data)
	local attacker = data.attackerEntity
	local defender = data.defenderEntity

	local attackerName = IsValid(attacker) and (
		attacker:IsPlayer() and attacker:Nick() or (attacker.GetNpcName and attacker:GetNpcName()) or attacker:GetClass()
	) or "Unknown Attacker"

	local defenderName = IsValid(defender) and (
		defender:IsPlayer() and defender:Nick() or (defender.GetNpcName and defender:GetNpcName()) or defender:GetClass()
	) or "Unknown Defender"

	local weaponName = (data.weapon and data.weapon.name) or "Weapon"

	local lines = {}
	table.insert(lines, string.format("[COMBAT] %s attacks %s with %s (%d attack%s)",
		attackerName,
		defenderName,
		weaponName,
		data.shotCount,
		data.shotCount > 1 and "s" or ""
	))

	for i, roll in ipairs(data.allRolls) do
		local atk = roll.atkRoll or {}
		local def = roll.defRoll or {}
		

		-- Calculate original (pre-penalty) totals
		local atkOriginalTotal = (tonumber(atk.raw) or 0) + (tonumber(atk.stat) or 0) + (tonumber(atk.bonus) or 0)
		local defOriginalTotal = (tonumber(def.raw) or 0) + (tonumber(def.stat) or 0) + (tonumber(def.bonus) or 0)

		-- Build the combat line
		local line = string.format(
			"Attack %d: ATT d100(%d)+%d+%d = %d",
			i,
			atk.raw or 0,
			atk.stat or 0,
			atk.bonus or 0,
			atkOriginalTotal
		)

		if atkOriginalTotal ~= atk.total then
			line = line .. string.format(" -> %d", atk.total or 0)
		end

		line = line .. string.format(" | DEF d100(%d)+%d+%d = %d",
			def.raw or 0,
			def.stat or 0,
			def.bonus or 0,
			def.total or 0
		)

		table.insert(lines, line)

		-- Grade penalties
		if atk.gradePenalty then
			table.insert(lines, string.format("    Attacker roll penalized by %.0f%% due to grade difference.", atk.gradePenalty * 100))
		end
		if def.gradePenalty then
			table.insert(lines, string.format("    Defender roll penalized by %.0f%% due to grade difference.", def.gradePenalty * 100))
		end

		if roll.hit then
			if roll.fieldBlocked then
				table.insert(lines, "→ Hit blocked by Field.")
			else
				table.insert(lines, string.format("→ Hit landed! (x%d multiplier)", roll.multiplier))

				if roll.multiplier > 1 then
					local traitName = "Trait"
					local traits = data.weapon and data.weapon.GetWeaponTraits and data.weapon:GetWeaponTraits()
					if traits then
						if traits.Brutal then
							traitName = "Brutal"
						elseif traits.Nimble then
							traitName = "Nimble"
						end
					end

					table.insert(lines, string.format(
						"    Triggered %s: %dx hits total from roll of %d",
						traitName,
						roll.multiplier,
						tonumber(atk.total) or 0
					))
				end

				if roll.hitWoundBreakdown then
					for _, part in ipairs(roll.hitWoundBreakdown) do
						local line = string.format(
							"    Wound: Rolled %d | AP = %d",
							part.rolled or 0,
							part.ap or 0
							)

							if part.aa and part.aa > 0 then
							line = line .. string.format(" | AA = %d", part.aa)
						end

						table.insert(lines, line)
					end
				end
			end
		else
			table.insert(lines, "→ Miss.")
		end
	end

	-- Summary
	table.insert(lines, string.format("Summary: %d/%d attacks hit.", data.hitCount, data.shotCount))

	if data.fieldBlockedCount > 0 then
		table.insert(lines, string.format("%d hits were blocked by Field.", data.fieldBlockedCount))
	end

	if data.hitCount > 0 and data.fieldBlockedCount < data.hitCount then
		table.insert(lines, string.format("Total Wounds Dealt: %d | Mitigated: %d | Overflow: %d",
			data.totalWounds,
			data.totalMitigated,
			data.totalOverflow
		))
	end

	-- Send to nearby players
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply) and (
			(IsValid(attacker) and ply:GetPos():Distance(attacker:GetPos()) <= 600) or
			(IsValid(defender) and ply:GetPos():Distance(defender:GetPos()) <= 600)
		) then
			net.Start("ixVeritasCombatLog")
				net.WriteString(util.TableToJSON(lines))
			net.Send(ply)
		end
	end
end



function PLUGIN:GetPowerArmorBoost(ply, stat)
	local armor = self:GetEquippedArmor(ply)
	if not armor or not armor.GetArmorData then return 0 end

	local data = armor:GetArmorData()
	if not data or not data.PowerArmor then return 0 end

	if stat ~= "strn" and stat ~= "tghn" then return 0 end

	return tonumber(data.PowerArmor) or 0
end

