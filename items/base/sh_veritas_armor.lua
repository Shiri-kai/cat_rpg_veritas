local PLUGIN = ix.plugin.Get("cat_rpg_veritas")

ITEM.name = "Base Veritas Armor"
ITEM.description = "A template for RPG armor with defensive traits."
ITEM.category = "Veritas Armor"
ITEM.base = "base_armor"
ITEM.isArmor = true

ITEM.armorSlot = "armor"

ITEM.armorTraits = {
    StoppingPower = 2,
    Wounds = "1d4",
    SpecializedProtection = {
        Plasma = 2,
        Kinetic = 1,
    },
    PowerArmor = 1,

    -- Example "Field" (chance to block entire attack); "uses" is decremented on hit.
    Field = {
        chance = 25,  -- %
        uses = 3,
    }
}

-- Deep copy helper (covers nested tables we actually use)
local function DeepCopyArmorTraits(t)
    local out = {}
    for k, v in pairs(t or {}) do
        if istable(v) then
            local sub = {}
            for sk, sv in pairs(v) do
                sub[sk] = sv
            end
            out[k] = sub
        else
            out[k] = v
        end
    end
    return out
end

-- Ensure each item instance has its own traits table (so Field.uses etc. are per-instance).
function ITEM:OnInstanced()
    self.armorTraits = DeepCopyArmorTraits(self.armorTraits or {})
    -- Normalize expected subtables
    self.armorTraits.SpecializedProtection = self.armorTraits.SpecializedProtection or {}
    if self.armorTraits.Field and not istable(self.armorTraits.Field) then
        self.armorTraits.Field = { chance = tonumber(self.armorTraits.Field) or 0, uses = 0 }
    end

    -- ensure Field table shape + remember maxUses
    local f = self.armorTraits.Field
    if istable(f) then
        f.chance = tonumber(f.chance) or 0
        f.uses = tonumber(f.uses) or 0
        f.maxUses = tonumber(f.maxUses) or f.uses -- <- store the baseline for later refills
    end
end

-- Returns the per-instance trait data
function ITEM:GetArmorData()
    return self.armorTraits or {}
end

-- Builds description lines for Veritas traits
function ITEM:GetVeritasTraitsDisplay()
    local lines = {}
    local t = self:GetArmorData()

    if t.StoppingPower then
        table.insert(lines, t.StoppingPower .. " Stopping Power")
    end

    if t.Wounds then
        table.insert(lines, tostring(t.Wounds) .. " Wounds")
    end

    if t.SpecializedProtection then
        for dmgType, value in pairs(t.SpecializedProtection) do
            table.insert(lines, "Anti-" .. dmgType .. ": " .. value)
        end
    end

    if t.PowerArmor then
        table.insert(lines, "Power-Armor: +" .. t.PowerArmor)
    end

    if t.Field then
        local field = t.Field
        table.insert(lines, "Field: " .. (field.chance or 0) .. "%, " .. (field.uses or 0) .. " use(s)")
    end

    return table.concat(lines, "\n")
end

-- Override base description to include Veritas traits
function ITEM:GetDescription()
    local desc = self.description or ""

    if self:GetData("equip") then
        desc = desc .. "\n[Equipped]"
    end

    local traitDesc = self:GetVeritasTraitsDisplay()
    if traitDesc ~= "" then
        desc = desc .. "\n\nTraits:\n" .. traitDesc
    end

    return desc
end

-- Only mark equipSlot for the RPG system.
function ITEM:OnEquipped(client, itemEntity)
    self:SetData("equipSlot", self.armorSlot)
end

function ITEM:OnUnequipped(client, itemEntity)
    self:SetData("equipSlot", nil)
end

-- Optional: paint overlay
if CLIENT then
    function ITEM:PaintOver(item, w, h)
        if item:GetData("equip") then
            surface.SetDrawColor(0, 255, 0, 100)
            surface.DrawRect(w - 14, h - 14, 8, 8)
        end
    end
end
