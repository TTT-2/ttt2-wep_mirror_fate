if SERVER then
    AddCSLuaFile()
end

DEFINE_BASECLASS("weapon_tttbase")

SWEP.HoldType = "slam"

if CLIENT then
    SWEP.PrintName = "weapon_mirrorfate_name"
    SWEP.Slot = 7

    SWEP.ViewModelFOV = 100
    SWEP.ViewModelFlip = false

    SWEP.EquipMenuData = {
        type = "item_weapon",
        name = "weapon_mirrorfate_name",
        desc = "weapon_mirrorfate_desc",
    }

    SWEP.Icon = "vgui/ttt/icon_mirror_fate"
end

SWEP.Base = "weapon_tttbase"

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = { ROLE_TRAITOR, ROLE_DETECTIVE }
SWEP.LimitedStock = true

SWEP.Spawnable = false
SWEP.AdminSpawnable = false

SWEP.ViewModel = "models/weapons/v_watch.mdl"
SWEP.WorldModel = "models/weapons/w_watch.mdl"

local mirrorFateModes = {
    {
        name = "explode",
        killFunction = function(victim, killer)
            print("killing with explosion")

            local dmginfo = DamageInfo()
            dmginfo:SetDamage(1000)
            dmginfo:SetAttacker(killer)
            dmginfo:SetInflictor(ents.Create("weapon_ttt_mirrorfate"))
            dmginfo:SetDamageType(DMG_BLAST)

            victim:EmitSound(Sound("ambient/explosions/explode_4.wav"))
            util.BlastDamageInfo(dmginfo, victim:GetPos(), 200)

            local effectdata = EffectData()
            effectdata:SetStart(victim:GetPos() + Vector(0, 0, 10))
            effectdata:SetOrigin(victim:GetPos() + Vector(0, 0, 10))
            effectdata:SetScale(1)
            util.Effect("HelicopterMegaBomb", effectdata)
        end,
    },
    {
        name = "holy",
        killFunction = function(victim, killer)
            print("killing with holy")
            local dmginfo = DamageInfo()
            dmginfo:SetDamage(1000)
            dmginfo:SetAttacker(killer)
            dmginfo:SetInflictor(ents.Create("weapon_ttt_mirrorfate"))
            dmginfo:SetDamageType(DMG_GENERIC)

            victim:EmitSound("mirrorfate/holy.wav")

            timer.Create("TTT2MirrorfateHoly" .. victim:EntIndex(), 1, 5, function()
                victim:SetGravity(0.01)
                victim:SetVelocity(Vector(0, 0, 250))

                if timer.RepsLeft("TTT2MirrorfateHoly" .. victim:EntIndex()) == 0 then
                    victim:SetGravity(1)
                    victim:TakeDamageInfo(dmginfo)
                end
            end)
        end,
    },
    {
        name = "burn",
        killFunction = function(victim, killer)
            print("killing with burn")
            local dmginfo = DamageInfo()
            dmginfo:SetDamage(5)
            dmginfo:SetAttacker(killer)
            dmginfo:SetInflictor(ents.Create("weapon_ttt_mirrorfate"))
            dmginfo:SetDamageType(DMG_BURN)

            victim:EmitSound("mirrorfate/evillaugh.mp3")

            timer.Create("TTT2MirrorfateBurnInHell" .. victim:EntIndex(), 0.25, 0, function()
                if victim:IsTerror() then
                    victim:TakeDamageInfo(dmginfo)
                    victim:Ignite(0.2)
                elseif not victim:IsTerror() then
                    timer.Remove("TTT2MirrorfateBurnInHell" .. victim:EntIndex())
                end
            end)
        end,
    },
    {
        name = "heart_attack",
        killFunction = function(victim, killer)
            print("killing with heart attack")
            local dmginfo = DamageInfo()
            dmginfo:SetDamage(1000)
            dmginfo:SetAttacker(killer)
            dmginfo:SetInflictor(ents.Create("weapon_ttt_mirrorfate"))
            dmginfo:SetDamageType(DMG_GENERIC)

            victim:TakeDamageInfo(dmginfo)
        end,
    },
}

function SWEP:OnDrop()
    self:Remove()
end

function SWEP:PrimaryAttack()
    if CLIENT then
        return
    end

    self.mode = (self.mode or 1) + 1

    if self.mode > #mirrorFateModes then
        self.mode = 1
    end
end

function SWEP:SecondaryAttack()
    if CLIENT then
        return
    end

    self.time = (self.time or 30) + 10

    if self.time > 60 then
        self.time = 30
    end
end

if SERVER then
    function SWEP:WasBought(buyer)
        self.mode = math.random(1, #mirrorFateModes)
        self.time = 30
    end

    hook.Add("DoPlayerDeath", "MirrorfateKillhim", function(victim, killer, damageinfo)
        if
            not IsValid(killer)
            or not IsValid(killer)
            or not killer:IsPlayer()
            or not victim:HasWeapon("weapon_ttt_mirrorfate")
        then
            return
        end

        local wepMirrorFate = victim:GetWeapon("weapon_ttt_mirrorfate")
        local time = wepMirrorFate.time or 30
        local mode = wepMirrorFate.mode or 1

        -- start the mirror fate timer
        timer.Create("TTT2Mirrorfate" .. killer:EntIndex(), time, 1, function()
            if not IsValid(killer) then
                return
            end

            -- note victim and killer are reversed here as it is a revenge kill
            mirrorFateModes[mode].killFunction(killer, victim)
        end)
    end)

    local function ResetMirrorFate(ply)
        timer.Remove("TTT2Mirrorfate" .. ply:EntIndex())
        timer.Remove("TTT2MirrorfateBurnInHell" .. ply:EntIndex())
        timer.Remove("TTT2MirrorfateHoly" .. ply:EntIndex())
    end

    hook.Add("PlayerSpawn", "ResetMirrorFate", ResetMirrorFate)

    hook.Add("TTTPrepareRound", "ResetMirrorFate", function()
        local plys = player.GetAll()

        for i = 1, #plys do
            ResetMirrorFate(plys[i])
        end
    end)
end

if CLIENT then
    function SWEP:Initialize()
        self:AddTTT2HUDHelp("mirrorfate_help_primary", "mirrorfate_help_secondary")

        self.BaseClass.Initialize(self)
    end
end
