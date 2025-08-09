local PLUGIN = PLUGIN

local PANEL = {}

function PANEL:Init()
    self:SetSize(400, 360)
    self:Center()
    self:SetTitle("Initiate Attack")
    self:MakePopup()

    self.targetBox = self:Add("DComboBox")
    self.targetBox:Dock(TOP)
    self.targetBox:SetTall(30)
    self.targetBox:SetValue("Select Target")

    self.weaponBox = self:Add("DComboBox")
    self.weaponBox:Dock(TOP)
    self.weaponBox:SetTall(30)
    self.weaponBox:SetValue("Select Weapon")

    self.statBox = self:Add("DComboBox")
    self.statBox:Dock(TOP)
    self.statBox:SetTall(30)
    self.statBox:SetValue("Choose Attack Stat (RFLX/STRN)")
    self.statBox:AddChoice("RFLX", "rflx")
    self.statBox:AddChoice("STRN", "strn")

    self.bonusEntry = self:Add("DNumberWang")
    self.bonusEntry:Dock(TOP)
    self.bonusEntry:SetTall(30)
    self.bonusEntry:SetMin(-100)
    self.bonusEntry:SetMax(100)
    self.bonusEntry:SetValue(0)
    self.bonusEntry:SetTooltip("Optional bonus to attack roll")

    self.attackCount = self:Add("DNumberWang")
    self.attackCount:Dock(TOP)
    self.attackCount:SetTall(30)
    self.attackCount:SetMin(1)
    self.attackCount:SetMax(1)
    self.attackCount:SetValue(1)
    self.attackCount:SetTooltip("Number of attacks (based on weapon's shots)")

    -- Update attack count when weapon is selected
    self.weaponBox.OnSelect = function(_, index, value, data)
        local selectedItem = data -- item object from AddChoice(..., item)
        if selectedItem and selectedItem.GetWeaponTraits then
            local traits = selectedItem:GetWeaponTraits()
            local maxShots = tonumber(traits.Shots) or 1
            self.attackCount:SetMax(maxShots)
            if self.attackCount:GetValue() > maxShots then
                self.attackCount:SetValue(maxShots)
            end
        else
            self.attackCount:SetMax(1)
            self.attackCount:SetValue(1)
        end
    end

    -- Submit button
    local submit = self:Add("DButton")
    submit:Dock(BOTTOM)
    submit:SetText("Attack!")
    submit:SetTall(40)
    submit.DoClick = function()
        local targetOpt = self.targetBox:GetSelected()
        local weaponOpt = self.weaponBox:GetSelected()
        local statOpt   = self.statBox:GetSelected()

        if not IsValid(targetOpt) or not IsValid(weaponOpt) or not IsValid(statOpt) then
            LocalPlayer():Notify("Please select a target, weapon, and stat.")
            return
        end

        local target = targetOpt:GetOptionData()   -- entity (player or NPC)
        local weapon = weaponOpt:GetOptionData()   -- item instance
        local stat   = statOpt:GetOptionData()     -- "rflx" or "strn"

        if not IsValid(target) or not weapon then
            LocalPlayer():Notify("Invalid target or weapon.")
            return
        end

        local slot = weapon:GetData("equipSlot") or weapon.weaponSlot or "primary"

        net.Start("ixVeritasSubmitAttack")
            net.WriteEntity(target)
            net.WriteString(stat)
            net.WriteUInt(self.attackCount:GetValue(), 8)
            net.WriteInt(self.bonusEntry:GetValue(), 16)
            net.WriteString(slot)
        net.SendToServer()

        LocalPlayer():Notify("Attack submitted.")
        self:Close()
    end

    self:PopulateTargetsAndWeapons()
end

function PANEL:PopulateTargetsAndWeapons()
    local char = LocalPlayer():GetCharacter()
    if not char then return end

    -- Targets
    local options = {}
    for _, ent in ipairs(ents.FindInSphere(LocalPlayer():GetPos(), 10000)) do
        if ent:IsPlayer() then
            local name = ent:Nick()
            table.insert(options, { text = string.format("%s [ent:%d]", name, ent:EntIndex()), data = ent })
        elseif ent:GetClass() == "ix_veritas_npc" then
            local name = ent:GetNetVar("veritas_name") or ent:GetClass()
            table.insert(options, { text = string.format("%s [ent:%d]", name, ent:EntIndex()), data = ent })
        end
    end
    table.SortByMember(options, "text", true)
    for _, opt in ipairs(options) do
        self.targetBox:AddChoice(opt.text, opt.data)
    end

    -- Weapons (equipped only)
    local inv = char:GetInventory()
    for _, item in pairs(inv:GetItems()) do
        if item.isWeapon and item:GetData("equipSlot") then
            local display = string.format("%s (%s)", item.name or "Weapon", item:GetData("equipSlot"))
            self.weaponBox:AddChoice(display, item)
        end
    end
end

vgui.Register("ixVeritasAttackMenu", PANEL, "DFrame")
