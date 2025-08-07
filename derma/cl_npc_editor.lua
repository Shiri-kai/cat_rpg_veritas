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
	self.defenseBox:AddChoice("RFLX")
	self.defenseBox:AddChoice("TGHN")
	
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
		["AntiArmor"] = "Extra damage vs armor. e.g. 2",
		["Shots"] = "How many shots per attack. e.g. 2",
		["Brutal"] = "Multiplier if STRN. e.g. 30 = x2 @60",
		["Nimble"] = "Multiplier if RFLX. e.g. 15 = x3 @45",
		["Ranged"] = "Set to true for ranged weapon",
		["Melee"] = "Set to true for melee weapon",
		["CloseRanged"] = "Set to true (45ft range)",
		["FarMelee"] = "Set to true (10ft range)",
		["Energy"] = "Set to true for energy weapon",
		["Kinetic"] = "Set to true for bullet/slug",
		["Plasma"] = "Set to true for plasma weapon",
		["Powered"] = "Set to true for power weapons",
		["Force"] = "True if usable by psykers",
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
		["StoppingPower"] = "Absorbs X damage before spillover. e.g. 5",
		["Wounds"] = "Wounds armor can take before breaking. e.g. 3",
		["PowerArmor"] = "Boosts STRN/TGHN grade by X. e.g. 1",
		["Field"] = "Format: 'Chance Uses'. e.g. 40 3",
		["ExtremeProtection"] = "Set to true to absorb all damage",
		["Anti-Kinetic"] = "Bonus SP vs kinetic damage. e.g. 2",
		["Anti-Plasma"] = "Bonus SP vs plasma damage. e.g. 2",
		["Anti-Energy"] = "Bonus SP vs energy damage. e.g. 2",
	}

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
		local statData = {}
		for _, stat in ipairs(PLUGIN.veritasStats) do
			statData[stat] = {
				value = math.Clamp(tonumber(self.stats[stat]:GetValue()) or 5, 0, 100),
				grade = math.Clamp(tonumber(self.grades[stat]:GetValue()) or 1, 1, 10)
			}
		end

		local model = self.modelEntry:GetValue()
		if not file.Exists(model, "GAME") then
			Derma_Message("That model file doesn't exist.", "Error", "OK")
			return
		end

		-- Parse traits
		local weaponTraits = {}
		for k, entry in pairs(self.weaponTraits) do
			local val = entry:GetValue()
			if val and val ~= "" then
				local num = tonumber(val)
				weaponTraits[k] = num or (val == "true" and true) or (val == "false" and false) or val
			end
		end

		local armorTraits = {}
		for k, entry in pairs(self.armorTraits) do
			local val = entry:GetValue()
			if val and val ~= "" then
				local num = tonumber(val)
				armorTraits[k] = num or (val == "true" and true) or (val == "false" and false) or val
			end
		end
		
		local weaponName = self.weaponNameEntry:GetValue() or "Unnamed Weapon"

		net.Start("ixVeritasSaveNpcData")
			net.WriteEntity(self.ent)
			net.WriteString(self.nameEntry:GetValue())
			net.WriteString(model)
			net.WriteTable(statData)
			net.WriteString(self.defenseBox:GetSelected() or "tghn")
			net.WriteTable(weaponTraits)
			net.WriteTable(armorTraits)
			net.WriteString(weaponName)
		net.SendToServer()

		self:Close()
	end
end

function PANEL:SetEntity(ent)
	self.ent = ent

	if IsValid(ent) then
		self.nameEntry:SetText(ent:GetNetVar("veritas_name") or "")

		local modelPath = ent:GetModelPath() or ent:GetModel()
		self.modelEntry:SetText(modelPath or "")
		if util.IsValidModel(modelPath) then
			self.modelPreview:SetModel(modelPath)
		end

		for _, stat in ipairs(PLUGIN.veritasStats) do
			local value = ent:GetNetVar("veritas_stat_" .. stat, 5)
			local grade = ent:GetNetVar("veritas_grade_" .. stat, 1)
			self.stats[stat]:SetText(tostring(value))
			self.grades[stat]:SetText(tostring(grade))
		end

		self.defenseBox:SetValue(ent:GetNetVar("veritas_defense_stat", "tghn"):upper())

		-- Load existing traits
		local wTraits = ent:GetNetVar("veritas_weapon", {})
		local aTraits = ent:GetNetVar("veritas_armor", {})

		for k, entry in pairs(self.weaponTraits) do
			entry:SetText(tostring(wTraits[k] or ""))
		end
		for k, entry in pairs(self.armorTraits) do
			entry:SetText(tostring(aTraits[k] or ""))
		end
	end
end

vgui.Register("ixVeritasNpcEditor", PANEL, "DFrame")
