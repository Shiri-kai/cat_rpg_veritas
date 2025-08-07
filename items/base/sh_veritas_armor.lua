local PLUGIN = ix.plugin.Get("cat_rpg_veritas")

ITEM.name = "Base Veritas Armor"
ITEM.description = "A template for RPG armor with defensive traits."
ITEM.category = "Veritas Armor"
ITEM.base = "base_armor"
ITEM.isArmor = true

ITEM.armorTraits = {
    -- Example default traits
    StoppingPower = 2,
    Wounds = "1d4",
    SpecializedProtection = {
        Plasma = 2,
        Kinetic = 1,
    },
    PowerArmor = 1,
    Field = {
        chance = 25,
        uses = 3,
    }
}

-- Returns raw trait data
function ITEM:GetArmorData()
    return self.armorTraits or {}
end

-- Builds description lines for Veritas traits
function ITEM:GetVeritasTraitsDisplay()
    local lines = {}

    if self.armorTraits.StoppingPower then
        table.insert(lines, self.armorTraits.StoppingPower .. " Stopping Power")
    end

    if self.armorTraits.Wounds then
        table.insert(lines, self.armorTraits.Wounds .. " Wounds")
    end

    if self.armorTraits.SpecializedProtection then
        for dmgType, value in pairs(self.armorTraits.SpecializedProtection) do
            table.insert(lines, "Anti-" .. dmgType .. ": " .. value)
        end
    end

    if self.armorTraits.PowerArmor then
        table.insert(lines, "Power-Armor: +" .. self.armorTraits.PowerArmor)
    end

    if self.armorTraits.Field then
        local field = self.armorTraits.Field
        table.insert(lines, "Field: " .. field.chance .. "%, " .. field.uses .. " use(s)")
    end

    return table.concat(lines, "\n")
end

-- Override base description to include Veritas traits
function ITEM:GetDescription()
    local desc = self.description or ""

    if self:GetData("equip") then
        desc = desc .. "\n[Equipped]"
    end

    -- Append RPG armor traits
    local traitDesc = self:GetVeritasTraitsDisplay()
    if traitDesc and traitDesc ~= "" then
        desc = desc .. "\n\nTraits:\n" .. traitDesc
    end

    return desc
end

-- Optional: Override paint overlay to match equip status
if CLIENT then
    function ITEM:PaintOver(item, w, h)
        if item:GetData("equip") then
            surface.SetDrawColor(0, 255, 0, 100)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end
