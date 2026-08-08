

SWEP = SWEP or {}
SWEP.Primary = SWEP.Primary or {}
SWEP.Secondary = SWEP.Secondary or {}


if SERVER then
    AddCSLuaFile('shared.lua');
    resource.AddFile('sound/epearl/teleport.wav')
    resource.AddFile('sound/epearl/throw.wav')

    sound.Add({name = 'epearl.teleport', channel = CHAN_AUTO, volume = 1, level = 45, sound = 'epearl/teleport.wav'})
    sound.Add({name = 'epearl.throw', channel = CHAN_AUTO, volume = 1, level = 80, sound = 'epearl/throw.wav'})

    util.AddNetworkString('epearl.collide.toClient')
    util.AddNetworkString('epearl.collide.toServer')
end

if CLIENT then
    SWEP.PrintName = 'Граната-Эндерперл';
    SWEP.Slot = 2;
    SWEP.SlotPos = 3;
    SWEP.DrawAmmo = false;
    SWEP.DrawCrosshair = false;
end

SWEP.Purpose = 'Граната-Эндерперл'
SWEP.Instructions = 'ЛКМ - Бросить пёрл'
SWEP.Author = 'Kuyash'

SWEP.ViewModelFOV = 62
SWEP.ViewModelFlip  = false

SWEP.Category = 'Портфолио'
SWEP.Spawnable = true
SWEP.AdminSpawnable = true

SWEP.NextStrike  = 0;

SWEP.ViewModel = 'models/items/grenadeammo.mdl'
SWEP.WorldModel = 'models/items/grenadeammo.mdl'


SWEP.Primary.Delay = 0.01
SWEP.Primary.Recoil = 0
SWEP.Primary.Damage = 0
SWEP.Primary.NumShots = 1
SWEP.Primary.Cone = 0
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = 'none'


SWEP.Secondary.Delay = 0.01
SWEP.Secondary.Recoil = 0
SWEP.Secondary.Damage = 0
SWEP.Secondary.NumShots = 1
SWEP.Secondary.Cone = 0
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = 'none'



function SWEP:Initialize()
    if CLIENT then self:SetWeaponHoldType('grenade') end 
end



function SWEP:PrimaryAttack()
    if CurTime() < self.NextStrike then return end
    self.NextStrike = CurTime() + 1

    if SERVER then
        local validSounds = {
            'player/pl_fallpain1.wav',
            'player/pl_fallpain3.wav'
        }

        local ply = self.Owner
        ply.lastepearl = ply.lastepearl or {}
        if IsValid(ply.lastepearl) then ply.lastepearl:Remove() end

        local epearl = ents.Create('prop_physics')
        ply.lastepearl = epearl

        local hitPos

        if not IsValid(epearl) then return end
            
        epearl:SetModel('models/Gibs/HGIBS.mdl')
        epearl:SetMaterial('phoenix_storms/metalset_1-2')
        epearl:Spawn()
        epearl:EmitSound('epearl.throw')
            
        local forward = ply:EyeAngles():Forward() 
        epearl:SetPos(ply:EyePos() + forward * 50)

        epearl:GetPhysicsObject():SetVelocity(forward*800)

        epearl:AddCallback('PhysicsCollide', function(ent, data)
            ent:Remove()
            hitPos = data.HitPos

            timer.Simple(0, function() -- перенос действия в следующий тик
                if not IsValid(ply) then return end
                
                ply:SetPos(hitPos)
                self:EmitSound(table.Random(validSounds), 75, 100, 1)
                self:EmitSound('epearl.teleport')
                    
                ply:TakeDamage(math.random(5, 15))
                    
                local hullMins, hullMaxs = ply:OBBMins() + Vector(0, 0, 20), ply:OBBMaxs()
                local tr = util.TraceHull({
                    start = hitPos,
                    endpos = hitPos,
                    mins = hullMins,
                    maxs = hullMaxs,
                    filter = ply
                })

                if (tr.Hit) then
                    if not IsValid(ply) then return end

                    local plyRagdoll = ply:CreateRagdoll()

                    net.Start('epearl.collide.toClient')
                    net.Send(ply)
                end
            end)
        end)
    end
end


if SERVER then
    net.Receive('epearl.collide.toServer', function()
        local newPos = net.ReadVector()
        local ply = net.ReadPlayer()

        local rdollEntity = ply:GetRagdollEntity()
        rdollEntity:Remove()
        
        timer.Simple(0, function()
            ply:SetPos(newPos)
        end)
    end)
end


if CLIENT then
    net.Receive('epearl.collide.toClient', function()
        local ply = LocalPlayer()
        
        hook.Add('CalcView', 'epearl.CalcView', function(_, _, angles, fov)
            local ragdoll = ply:GetRagdollEntity()
            local view = {
                origin = ragdoll:GetBonePosition(14) + Vector(0, 0, 10),
                angles = angles,
                fov = fov,
                drawviewer = false
            }
                
            ragdoll:ManipulateBoneScale(14, Vector(0, 0, 0)) 

            return view
        end)

        timer.Simple(2, function() 
            hook.Remove('CalcView', 'epearl.CalcView')
            net.Start('epearl.collide.toServer')
                local ragdoll = ply:GetRagdollEntity()
                local bone = ragdoll:LookupBone('ValveBiped.Bip01_Spine')
                net.WriteVector(ragdoll:GetBonePosition(bone))
                net.WritePlayer(ply)
            net.SendToServer()
        end)
    end)
end