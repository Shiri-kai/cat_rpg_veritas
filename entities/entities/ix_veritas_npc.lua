AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Veritas NPC"
ENT.Category = "Helix: Veritas"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
	self:NetworkVar("String", 0, "NpcName")
	self:NetworkVar("String", 1, "ModelPath")
end

-- SERVER SIDE
if SERVER then
	util.AddNetworkString("ixVeritasOpenNpcEditor")

	function ENT:Initialize()
		local mdl = self:GetModelPath()

		if not mdl or mdl == "" or mdl == "Error" or not file.Exists(mdl, "GAME") then
			mdl = "models/Humans/Group01/male_07.mdl"
			self:SetModelPath(mdl)
		end

		self:SetModel(mdl)
		self:SetNpcName(self:GetNpcName() or "Veritas NPC")

		self:SetSolid(SOLID_VPHYSICS)
		self:SetMoveType(MOVETYPE_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)

		local phys = self:GetPhysicsObject()
		if IsValid(phys) then
			phys:Wake()
		end

		self:SetIdleAnim()
	end

	function ENT:SetIdleAnim()
		-- Try ACT_IDLE
		local ok = self:ResetSequence(ACT_IDLE)

		if not ok or self:GetSequence() <= 0 then
			local fallbackSeqs = { "idle_subtle", "idle_all_01", "idle" }

			for _, seq in ipairs(fallbackSeqs) do
				local id = self:LookupSequence(seq)
				if id and id > 0 then
					self:ResetSequence(id)
					return
				end
			end

			-- Default to sequence 0 if nothing else
			self:SetSequence(0)
			self:SetPlaybackRate(0)
		end
	end

	function ENT:Think()
		self:SetIdleAnim()
		self:NextThink(CurTime() + 5)
		return true
	end

	function ENT:Use(activator, caller)
		if not IsValid(activator) or not activator:IsPlayer() then return end
		if self._nextUse and self._nextUse > CurTime() then return end
		self._nextUse = CurTime() + 0.5

		net.Start("ixVeritasOpenNpcEditor")
			net.WriteEntity(self)
		net.Send(activator)
	end

	-- Allow admins to pick up with physgun
	function ENT:PhysgunPickup(ply)
		return ply:IsAdmin()
	end
	
	function ENT:GetNpcName()
		return self:GetNetVar("veritas_name") or self:GetNW2String("veritas_name", "Unnamed NPC")
	end

end

-- CLIENT SIDE
if CLIENT then
	function ENT:Draw()
		self:DrawModel()

		local pos = self:GetPos() + Vector(0, 0, 80)
		local ang = LocalPlayer():EyeAngles()
		ang:RotateAroundAxis(ang:Right(), 90)
		ang:RotateAroundAxis(ang:Up(), 90)

		cam.Start3D2D(pos, Angle(0, ang.y, 90), 0.2)
			draw.SimpleTextOutlined(
				self:GetNpcName() or "Veritas NPC",
				"DermaLarge",
				0, 0,
				color_white,
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER,
				1,
				color_black
			)
		cam.End3D2D()
	end
end
