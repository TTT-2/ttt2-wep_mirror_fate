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

    SWEP.Icon = "vgui/ttt/icon_mirrorfate"
end

SWEP.Base = "weapon_tttbase"

SWEP.Kind = WEAPON_EQUIP2
SWEP.CanBuy = { ROLE_TRAITOR, ROLE_DETECTIVE }
SWEP.LimitedStock = true

SWEP.AllowDrop = false

SWEP.Spawnable = false
SWEP.AdminSpawnable = false

SWEP.ViewModel = "models/weapons/v_watch.mdl"
SWEP.WorldModel = "models/weapons/w_watch.mdl"

local mirrorFateModes = {
    {
        name = "explode",
        killFunction = function(victim, killer)
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
            local dmginfo = DamageInfo()
            dmginfo:SetDamage(1000)
            dmginfo:SetAttacker(killer)
            dmginfo:SetInflictor(ents.Create("weapon_ttt_mirrorfate"))
            dmginfo:SetDamageType(DMG_GENERIC)

            victim:TakeDamageInfo(dmginfo)
        end,
    },
}

function SWEP:PrimaryAttack()
    if CLIENT then
        return
    end

    local mode = self:GetNWInt("mode", 1)

    mode = mode + 1

    if mode > #mirrorFateModes then
        mode = 1
    end

    self:SetNWInt("mode", mode)

    STATUS:SetActiveIcon(self:GetOwner(), "ttt2_mirrorfate_status_owner", mode)
end

function SWEP:SecondaryAttack()
    if CLIENT then
        return
    end

    local time = self:GetNWInt("time", 30)

    time = time + 10

    if time > 60 then
        time = 30
    end

    self:SetNWInt("time", time)
end

function SWEP:Initialize()
    if SERVER then
        self:SetNWInt("mode", math.random(1, #mirrorFateModes))
        self:SetNWInt("time", 30)

        timer.Simple(0, function()
            if not IsValid(self) then
                return
            end

            STATUS:AddStatus(
                self:GetOwner(),
                "ttt2_mirrorfate_status_owner",
                self:GetNWInt("mode", 1)
            )
        end)
    else
        self:AddTTT2HUDHelp("mirrorfate_help_primary", "mirrorfate_help_secondary")
    end

    self.BaseClass.Initialize(self)
end

if SERVER then
    function SWEP:OnDrop()
        self:Remove()
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

        -- only continue if the killer doesn't own mirror fate as well
        if not killer:HasWeapon("weapon_ttt_mirrorfate") then
            local wepMirrorFate = victim:GetWeapon("weapon_ttt_mirrorfate")
            local time = wepMirrorFate:GetNWInt("time", 30)
            local mode = wepMirrorFate:GetNWInt("mode", 1)

            -- start the mirror fate timer
            timer.Create("TTT2Mirrorfate" .. killer:EntIndex(), time, 1, function()
                if not IsValid(killer) then
                    return
                end

                STATUS:RemoveStatus(killer, "ttt2_mirrorfate_status_victim")

                -- if the killer (the new victim) owns the mirror fate equipment, the kill won't happen
                if killer:HasWeapon("weapon_ttt_mirrorfate") then
                    EPOP:AddMessage(
                        victim,
                        "weapon_mirrorfate_failed_title",
                        "weapon_mirrorfate_failed_subtitle"
                    )

                    return
                end

                -- don't kill a dead player
                if not killer:IsTerror() then
                    return
                end

                -- note victim and killer are reversed here as it is a revenge kill
                mirrorFateModes[mode].killFunction(killer, victim)
            end)

            STATUS:AddStatus(killer, "ttt2_mirrorfate_status_victim")
        end
    end)

    hook.Add("TTT2OrderedEquipment", "TTT2MirrorFateBought", function(ply, equipmentName)
        if equipmentName ~= "weapon_ttt_mirrorfate" then
            return
        end

        STATUS:RemoveStatus(ply, "ttt2_mirrorfate_status_victim")
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
    function SWEP:OnRemove()
        STATUS:RemoveStatus("ttt2_mirrorfate_status_owner")
    end

    hook.Add("TTT2FinishedLoading", "TTT2InitMirrorfateStatus", function()
        STATUS:RegisterStatus("ttt2_mirrorfate_status_owner", {
            hud = {
                Material("vgui/ttt/perks/hud_mirrorfate_explode.png"),
                Material("vgui/ttt/perks/hud_mirrorfate_holy.png"),
                Material("vgui/ttt/perks/hud_mirrorfate_burn.png"),
                Material("vgui/ttt/perks/hud_mirrorfate_heart_attack.png"),
            },
            type = "good",
            name = {
                "weapon_mirrorfate_explode",
                "weapon_mirrorfate_holy",
                "weapon_mirrorfate_burn",
                "weapon_mirrorfate_heart_attack",
            },
            sidebarDescription = "weapon_mirrorfate_sidebar",
            DrawInfo = function()
                local wepMirrorFate = LocalPlayer():GetWeapon("weapon_ttt_mirrorfate")

                if not IsValid(wepMirrorFate) then
                    return
                end

                return tostring(wepMirrorFate:GetNWInt("time", 30)) .. "s"
            end,
        })

        STATUS:RegisterStatus("ttt2_mirrorfate_status_victim", {
            hud = {
                Material("vgui/ttt/perks/hud_mirrorfate.png"),
            },
            type = "bad",
            name = {
                "weapon_mirrorfate_victim",
            },
            sidebarDescription = "weapon_mirrorfate_sidebar_victim",
        })
    end)
end
