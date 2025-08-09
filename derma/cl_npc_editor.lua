local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
	self:SetSize(500, 800)
	self:Center()
	self:SetTitle("Veritas NPC Editor")
	self:MakePopup()

	self.stats = {}
	self.grades = {}
	self.weaponTraits = {}
	self.armorTraits = {}

	-- Scrollable content area
	self.scroll = self:Add("DScrollPanel")
	self.scroll:Dock(FILL)
	self.scroll:DockMargin(5, 5, 5, 5)

	-- Model preview
	self.modelPreview = self.scroll:Add("DModelPanel")
	self.modelPreview:SetTall(200)
	self.modelPreview:SetModel("models/Humans/Group01/male_07.mdl")
	self.modelPreview:SetFOV(40)
	self.modelPreview.Dock = TOP
	function self.modelPreview:LayoutEntity(ent) return end

	-- Name field
	self.nameEntry = self.scroll:Add("DTextEntry")
	self.nameEntry:Dock(TOP)
	self.nameEntry:SetPlaceholderText("NPC Name")

	-- Model path field
	self.modelEntry = self.scroll:Add("DTextEntry")
	self.modelEntry:Dock(TOP)
	self.modelEntry:SetPlaceholderText("Model Path (e.g. models/Humans/Group01/male_07.mdl)")
	self.modelEntry.OnChange = function(entry)
		local mdl = entry:GetValue()
		if util.IsValidModel(mdl) then
			self.modelPreview:SetModel(mdl)
		end
	end

	-- Stats + Grades
	for _, stat in ipairs(PLUGIN.veritasStats) do
		local panel = self.scroll:Add("DPanel")
		panel:Dock(TOP)
		panel:SetTall(30)
		panel:SetPaintBackground(false)

		local label = panel:Add("DLabel")
		label:SetText(stat:upper())
		label:Dock(LEFT)
		label:SetWide(100)

		local statBox = panel:Add("DTextEntry")
		statBox:Dock(LEFT)
		statBox:SetWide(60)
		statBox:SetNumeric(true)
		statBox:SetValue("5")
		self.stats[stat] = statBox

		local gradeBox = panel:Add("DTextEntry")
		gradeBox:Dock(LEFT)
		gradeBox:SetWide(60)
		gradeBox:SetNumeric(true)
		gradeBox:SetValue("1")
		self.grades[stat] = gradeBox
	end

	-- Defense stat selection
	self.defenseBox = self.scroll:Add("DComboBox")
	self.defenseBox:Dock(TOP)
	self.defenseBox:SetTall(30)
	self.defenseBox:SetValue("Defense Stat")
	self.defenseBox:AddChoice("RFLX", "rflx")
	self.defenseBox:AddChoice("TGHN", "tghn")

	-- Weapon name
	self.weaponNameEntry = self.scroll:Add("DTextEntry")
	self.weaponNameEntry:Dock(TOP)
	self.weaponNameEntry:SetPlaceholderText("Weapon Name (e.g. Boltgun)")

	-- Weapon Traits Header
	local weaponHeader = self.scroll:Add("DLabel")
	weaponHeader:SetText("Weapon Traits")
	weaponHeader:SetFont("DermaDefaultBold")
	weaponHeader:Dock(TOP)
	weaponHeader:DockMargin(0, 10, 0, 5)

	local weaponTooltips = {
		["Wounds"] = "Wounds per hit. e.g. 2 or 1d5",
		["ArmorPiercing"] = "Subtracts from enemy SP. e.g. 3",
		["AntiArmor"] = "Extra mitigation shift. e.g. 2",
		["Shots"] = "How many shots per attack. e.g. 2",
		["Brutal"] = "Multiplier threshold if STRN. e.g. 30 => x2 @60",
		["Nimble"] = "Multiplier threshold if RFLX. e.g. 15 => x3 @45",
		["Ranged"] = "true/false",
		["Melee"] = "true/false",
		["CloseRanged"] = "true/false (45ft)",
		["FarMelee"] = "true/false (10ft)",
		["Energy"] = "true/false",
		["Kinetic"] = "true/false",
		["Plasma"] = "true/false",
		["Powered"] = "true/false",
		["Force"] = "true/false",
	}

	-- Common weapon traits
	for _, trait in ipairs({
		"Wounds", "ArmorPiercing", "AntiArmor", "Shots", "Brutal", "Nimble",
		"Ranged", "Melee", "CloseRanged", "FarMelee",
		"Energy", "Kinetic", "Plasma", "Powered", "Force"
	}) do
		local entry = self.scroll:Add("DTextEntry")
		entry:Dock(TOP)
		entry:SetTall(25)
		entry:SetPlaceholderText(trait)
		if weaponTooltips[trait] then
			entry:SetTooltip(weaponTooltips[trait])
		end
		self.weaponTraits[trait] = entry
	end

	-- Armor Traits Header
	local armorHeader = self.scroll:Add("DLabel")
	armorHeader:SetText("Armor Traits")
	armorHeader:SetFont("DermaDefaultBold")
	armorHeader:Dock(TOP)
	armorHeader:DockMargin(0, 10, 0, 5)

	local armorTooltips = {
		["StoppingPower"] = "Flat mitigation. e.g. 5",
		["Wounds"] = "Armor wound buffer. e.g. 3 or 1d4",
		["PowerArmor"] = "Boost STRN/TGHN grade by X. e.g. 1",
		["Field"] = "Format: 'Chance Uses'. e.g. 40 3",
		["ExtremeProtection"] = "true/false — absorb all damage",
		["Anti-Kinetic"] = "Bonus SP vs Kinetic. e.g. 2",
		["Anti-Plasma"] = "Bonus SP vs Plasma. e.g. 2",
		["Anti-Energy"] = "Bonus SP vs Energy. e.g. 2",
	}

	-- UI entries (we'll translate to engine format on save)
	for _, trait in ipairs({
		"StoppingPower", "Wounds", "PowerArmor", "Field", "ExtremeProtection",
		"Anti-Kinetic", "Anti-Plasma", "Anti-Energy"
	}) do
		local entry = self.scroll:Add("DTextEntry")
		entry:Dock(TOP)
		entry:SetTall(25)
		entry:SetPlaceholderText(trait)
		if armorTooltips[trait] then
			entry:SetTooltip(armorTooltips[trait])
		end
		self.armorTraits[trait] = entry
	end

	-- Save Button
	local saveButton = self:Add("DButton")
	saveButton:Dock(BOTTOM)
	saveButton:SetText("Apply Changes")
	saveButton:SetTall(40)
	saveButton:DockMargin(5, 5, 5, 5)

	saveButton.DoClick = function()
		if not IsValid(self.ent) then return end

		-- Stats
		local statData = {}
		for _, stat in ipairs(PLUGIN.veritasStats) do
			statData[stat] = {
				value = math.Clamp(tonumber(self.stats[stat]:GetValue()) or 5, 0, 100),
				grade = math.Clamp(tonumber(self.grades[stat]:GetValue()) or 1, 1, 10)
			}
		end

		-- Model
		local model = self.modelEntry:GetValue()
		if not util.IsValidModel(model) then
			Derma_Message("That model file doesn't exist.", "Error", "OK")
			return
		end

		-- Defense stat (string)
		local defenseStatValue = (self.defenseBox:GetValue() or "tghn"):lower()
		if defenseStatValue ~= "rflx" and defenseStatValue ~= "tghn" then
			defenseStatValue = "tghn"
		end

		-- Weapon traits parse
		local weaponTraits = {}
		for k, entry in pairs(self.weaponTraits) do
			local val = entry:GetValue()
			if val and val ~= "" then
				local lower = string.lower(val)
				if lower == "true" then
					weaponTraits[k] = true
				elseif lower == "false" then
					weaponTraits[k] = false
				else
					local num = tonumber(val)
					weaponTraits[k] = num or val
				end
			end
		end

		-- Armor traits parse -> convert UI fields into engine structure
		local armorTraits = {}
		-- Basic numeric/string
		local sp = tonumber(self.armorTraits["StoppingPower"]:GetValue() or "") or nil
		if sp then armorTraits.StoppingPower = sp end

		local woundsVal = self.armorTraits["Wounds"]:GetValue()
		if woundsVal and woundsVal ~= "" then
			local n = tonumber(woundsVal)
			armorTraits.Wounds = n or woundsVal -- allow dice strings
		end

		local pa = tonumber(self.armorTraits["PowerArmor"]:GetValue() or "") or nil
		if pa then armorTraits.PowerArmor = pa end

		local extreme = self.armorTraits["ExtremeProtection"]:GetValue()
		if extreme and extreme ~= "" then
			local l = string.lower(extreme)
			if l == "true" then armorTraits.ExtremeProtection = true
			elseif l == "false" then armorTraits.ExtremeProtection = false end
		end

		-- Field: "chance uses"
		do
			local fieldStr = self.armorTraits["Field"]:GetValue()
			if fieldStr and fieldStr ~= "" then
				local c, u = string.match(fieldStr, "^(%d+)%s+(%d+)$")
				if c and u then
					armorTraits.Field = { chance = tonumber(c) or 0, uses = tonumber(u) or 0 }
				else
					-- Support "chance" only
					local only = tonumber(fieldStr)
					if only then
						armorTraits.Field = { chance = only, uses = 0 }
					end
				end
			end
		end

		-- SpecializedProtection from Anti-*
		local spec = {}
		local ak = tonumber(self.armorTraits["Anti-Kinetic"]:GetValue() or "") or nil
		if ak then spec.Kinetic = ak end
		local ap = tonumber(self.armorTraits["Anti-Plasma"]:GetValue() or "") or nil
		if ap then spec.Plasma = ap end
		local ae = tonumber(self.armorTraits["Anti-Energy"]:GetValue() or "") or nil
		if ae then spec.Energy = ae end
		if next(spec) ~= nil then
			armorTraits.SpecializedProtection = spec
		end

		-- Weapon name sanitize/fallback
		local weaponName = (self.weaponNameEntry:GetValue() or ""):Trim()
		if weaponName == "" then
			local base = (self.nameEntry:GetValue() ~= "" and self.nameEntry:GetValue())
				or (IsValid(self.ent) and (self.ent:GetNetVar("veritas_name") or self.ent:GetClass()))
				or "NPC"
			weaponName = base .. "'s Weapon"
		end

		-- Send
		net.Start("ixVeritasSaveNpcData")
			net.WriteEntity(self.ent)
			net.WriteString(self.nameEntry:GetValue())
			net.WriteString(model)
			net.WriteTable(statData)
			net.WriteString(defenseStatValue)
			net.WriteTable(weaponTraits)
			net.WriteTable(armorTraits)
			net.WriteString(weaponName)
		net.SendToServer()

		self:Close()
	end
end

function PANEL:SetEntity(ent)
	self.ent = ent

	if not IsValid(ent) then return end

	-- Name
	self.nameEntry:SetText(ent:GetNetVar("veritas_name") or "")

	-- Model
	local modelPath = ent:GetModelPath() or ent:GetModel()
	self.modelEntry:SetText(modelPath or "")
	if util.IsValidModel(modelPath or "") then
		self.modelPreview:SetModel(modelPath)
	end

	-- Stats/grades
	for _, stat in ipairs(PLUGIN.veritasStats) do
		local value = ent:GetNetVar("veritas_stat_" .. stat, 5)
		local grade = ent:GetNetVar("veritas_grade_" .. stat, 1)
		self.stats[stat]:SetText(tostring(value))
		self.grades[stat]:SetText(tostring(grade))
	end

	-- Defense stat
	local def = ent:GetNetVar("veritas_defense_stat", "tghn")
	self.defenseBox:SetValue(string.upper(def))

	-- Weapon name
	self.weaponNameEntry:SetText(ent:GetNetVar("veritas_weapon_name") or "")

	-- Load existing traits
	local wTraits = ent:GetNetVar("veritas_weapon", {}) or {}
	local aTraits = ent:GetNetVar("veritas_armor", {}) or {}

	-- Weapon traits fill
	for k, entry in pairs(self.weaponTraits) do
		local v = wTraits[k]
		if v == nil then
			entry:SetText("")
		elseif isbool(v) then
			entry:SetText(v and "true" or "false")
		else
			entry:SetText(tostring(v))
		end
	end

	-- Armor traits fill (translate engine -> UI)
	-- Basic fields
	self.armorTraits["StoppingPower"]:SetText(aTraits.StoppingPower and tostring(aTraits.StoppingPower) or "")
	self.armorTraits["Wounds"]:SetText(aTraits.Wounds and tostring(aTraits.Wounds) or "")
	self.armorTraits["PowerArmor"]:SetText(aTraits.PowerArmor and tostring(aTraits.PowerArmor) or "")
	if aTraits.ExtremeProtection ~= nil then
		self.armorTraits["ExtremeProtection"]:SetText(aTraits.ExtremeProtection and "true" or "false")
	else
		self.armorTraits["ExtremeProtection"]:SetText("")
	end

	-- Field
	if istable(aTraits.Field) then
		local c = tonumber(aTraits.Field.chance) or 0
		local u = tonumber(aTraits.Field.uses) or 0
		self.armorTraits["Field"]:SetText(string.format("%d %d", c, u))
	else
		self.armorTraits["Field"]:SetText("")
	end

	-- SpecializedProtection -> Anti-*
	local spec = istable(aTraits.SpecializedProtection) and aTraits.SpecializedProtection or {}
	self.armorTraits["Anti-Kinetic"]:SetText(spec.Kinetic and tostring(spec.Kinetic) or "")
	self.armorTraits["Anti-Plasma"]:SetText(spec.Plasma and tostring(spec.Plasma) or "")
	self.armorTraits["Anti-Energy"]:SetText(spec.Energy and tostring(spec.Energy) or "")
end

vgui.Register("ixVeritasNpcEditor", PANEL, "DFrame")
