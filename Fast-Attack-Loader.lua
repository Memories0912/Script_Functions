local Module = {
  Distance = 50,
  attackMobs = true,
  attackPlayers = true,
  Equipped = nil,
  Debounce = 0,
  
  ComboDebounce = 0,
  M1Combo = 0,
  ShootsPerTarget = {
    ["Dual Flintlock"] = 2
  },
  SpecialShoots = {
    ["Skull Guitar"] = "TAP",
    ["Bazooka"] = "Position",
    ["Cannon"] = "Position"
  }
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Net = ReplicatedStorage.Modules.Net
local RE_RegisterAttack = Net["RE/RegisterAttack"]
local RE_RegisterHit = Net["RE/RegisterHit"]
local RE_ShootGunEvent = Net["RE/ShootGunEvent"]

local Characters = workspace.Characters
local Enemies = workspace.Enemies

local Player = Players.LocalPlayer

local CombatController = ReplicatedStorage.Controllers.CombatController
local GunValidator = ReplicatedStorage.Remotes.Validator2

local old_shoot = getupvalue(require(CombatController).Attack, 9)

local function CheckPlayerAlly(__Player: Player): boolean
  if tostring(__Player.Team) == "Marines" and __Player.Team == Player.Team then
    return false
  elseif __Player:HasTag(`Ally{Player.Name}`) or Player:HasTag(`Ally{__Player.Name}`) then
    return false
  end
  
  return true
end

local function IsAlive(Character)
  local Humanoid = Character:FindFirstChildOfClass("Humanoid")
  return Humanoid and Humanoid.Health > 0
end

function Module:CheckStun(ToolTip: string, Character: Character, Humanoid: Humanoid): boolean
  local Stun = Character:FindFirstChild("Stun")
  local Busy = Character:FindFirstChild("Busy")
  
  if Humanoid.Sit and (ToolTip == "Sword" or ToolTip == "Melee" or ToolTip == "Gun") then
    return false
  elseif Stun and Stun.Value > 0 then -- {{ or Busy and Busy.Value }}
    return false
  end
  
  return true
end

function Module:Process(assert: boolean, Enemies: Folder, BladeHits: table, Position: Vector3, Distance: number): (nil)
  if not assert then return end
  
  local Mobs = Enemies:GetChildren()
  
  for i = 1, #Mobs do
    local Enemy = Mobs[i]
    local RootPart = Enemy.PrimaryPart
    local CanAttack = Enemy.Parent == Characters and CheckPlayerAlly(Players:GetPlayerFromCharacter(Enemy))
    
    if Enemy ~= Player.Character and RootPart and (Enemy.Parent ~= Characters or CanAttack) then
      if (Position - RootPart.Position).Magnitude <= Distance then
        if not self.EnemyRootPart then
          self.EnemyRootPart = RootPart
        else
          table.insert(BladeHits, { Enemy, RootPart })
        end
      end
    end
  end
end

function Module:GetAllBladeHits(Character: Character, Distance: number?): (nil)
  local Position = Character:GetPivot().Position
  local BladeHits = {}
  Distance = Distance or self.Distance
  
  self:Process(self.attackMobs, Enemies, BladeHits, Position, Distance)
  self:Process(self.attackPlayers, Characters, BladeHits, Position, Distance)
  
  return BladeHits
end

function Module:GetClosestEnemyPosition(Character: Character, Distance: number?): (nil)
  local BladeHits = self:GetAllBladeHits(Character, Distance)
  
  local Distance, Closest = math.huge
  
  for i = 1, #BladeHits do
    local Magnitude = if Closest then (Closest.Position - BladeHits[i][2].Position).Magnitude else Distance
    
    if Magnitude <= Distance then
      Distance, Closest = Magnitude, BladeHits[i][2]
    end
  end
  
  return if Closest then Closest.Position else nil
end

function Module:GetGunHits(Character: Character, Distance: number?)
  local BladeHits = self:GetAllBladeHits(Character, Distance)
  local GunHits = {}
  
  for i = 1, #BladeHits do
    if not GunHits[1] or (BladeHits[i][2].Position - GunHits[1].Position).Magnitude <= 10 then
      table.insert(GunHits, BladeHits[i][2])
    end
  end
  
  return GunHits
end

function Module:GetCombo(): number
  local Combo = if tick() - self.ComboDebounce <= 0.4 then self.M1Combo else 0
  Combo = if Combo >= 4 then 1 else Combo + 1
  
  self.ComboDebounce = tick()
  self.M1Combo = Combo
  
  return Combo
end

function Module:UseFruitM1(Character: Character, Equipped: Tool, Combo: number): (nil)
  local Position = Character:GetPivot().Position
  local EnemyList = Enemies:GetChildren()
  
  for i = 1, #EnemyList do
    local Enemy = EnemyList[i]
    local PrimaryPart = Enemy.PrimaryPart
    if IsAlive(Enemy) and PrimaryPart and (PrimaryPart.Position - Position).Magnitude <= 50 then
      local Direction = (PrimaryPart.Position - Position).Unit
      return Equipped.LeftClickRemote:FireServer(Direction, Combo)
    end
  end
end

function Module:UseNormalClick(Humanoid: Humanoid, Character: Character, Cooldown: number): (nil)
  self.EnemyRootPart = nil
  local BladeHits = self:GetAllBladeHits(Character)
  
  if self.EnemyRootPart then
    RE_RegisterAttack:FireServer(Cooldown)
    RE_RegisterHit:FireServer(self.EnemyRootPart, BladeHits)
  end
end

function Module:GetValidator2()
  local v1 = getupvalue(old_shoot, 15) -- v40, 15
  local v2 = getupvalue(old_shoot, 13) -- v41, 13
  local v3 = getupvalue(old_shoot, 16) -- v42, 16
  local v4 = getupvalue(old_shoot, 17) -- v43, 17
  local v5 = getupvalue(old_shoot, 14) -- v44, 14
  local v6 = getupvalue(old_shoot, 12) -- v45, 12
  local v7 = getupvalue(old_shoot, 18) -- v46, 18
  
  local v8 = v6 * v2                  -- v133
  local v9 = (v5 * v2 + v6 * v1) % v3 -- v134
  
  v9 = (v9 * v3 + v8) % v4
  v5 = math.floor(v9 / v3)
  v6 = v9 - v5 * v3
  v7 = v7 + 1
  
  setupvalue(old_shoot, 15, v1) -- v40, 15
  setupvalue(old_shoot, 13, v2) -- v41, 13
  setupvalue(old_shoot, 16, v3) -- v42, 16
  setupvalue(old_shoot, 17, v4) -- v43, 17
  setupvalue(old_shoot, 14, v5) -- v44, 14
  setupvalue(old_shoot, 12, v6) -- v45, 12
  setupvalue(old_shoot, 18, v7) -- v46, 18
  
  return math.floor(v9 / v4 * 16777215), v7
end

function Module:UseGunShoot(Character, Equipped)
  local ShootType = self.SpecialShoots[Equipped.Name] or "Normal"
  
  if ShootType == "Normal" then
    local Hits = self:GetGunHits(Character, 120)
    
    if #Hits > 0 then
      local Target = Hits[1].Position
      
      Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
      GunValidator:FireServer(self:GetValidator2())
      
      for i = 1, (self.ShootsPerTarget[Equipped.Name] or 1) do
        RE_ShootGunEvent:FireServer(Target, Hits)
      end
    end
  elseif ShootType == "Position" or (ShootType == "TAP" and Equipped:FindFirstChild("RemoteEvent")) then
    local Target = self:GetClosestEnemyPosition(Character, 200)
    
    if Target then
      Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
      GunValidator:FireServer(self:GetValidator2())
      
      if ShootType == "TAP" then
        Equipped.RemoteEvent:FireServer("TAP", Target)
      else
        RE_ShootGunEvent:FireServer(Target)
      end
    end
  end
end

function Module.attack()
  if not IsAlive(Player.Character) then return end
  
  local self = Module
  local Character = Player.Character
  local Humanoid = Character.Humanoid
  
  local Equipped = Character:FindFirstChildOfClass("Tool")
  local ToolTip = Equipped and Equipped.ToolTip
  local ToolName = Equipped and Equipped.Name
  
  if not Equipped or (ToolTip ~= "Gun" and ToolTip ~= "Melee" and ToolTip ~= "Blox Fruit" and ToolTip ~= "Sword") then
    return nil
  end
  
  local Cooldown = Equipped:FindFirstChild("Cooldown") and Equipped.Cooldown.Value or 0.25
  local Nickname = Equipped:FindFirstChild("Nickname") and Equipped.Nickname.Value or "Null"
  
  if (tick() - self.Debounce) >= Cooldown and self:CheckStun(ToolTip, Character, Humanoid) then
    local Combo = self:GetCombo()
    Cooldown += if Combo >= 4 then 0.05 else 0
    
    self.Equipped = Equipped
    self.Debounce = if Combo >= 4 and ToolTip ~= "Gun" then (tick() + 0.05) else tick()

    if ToolTip == "Blox Fruit" then
      if ToolName == "Ice-Ice" or ToolName == "Light-Light" then
        return self:UseNormalClick(Humanoid, Character, Cooldown)
      elseif Equipped:FindFirstChild("LeftClickRemote") then
        return self:UseFruitM1(Character, Equipped, Combo)
      end
    elseif ToolTip == "Gun" then
      return self:UseGunShoot(Character, Equipped)
    else
      return self:UseNormalClick(Humanoid, Character, Cooldown)
    end
  end
end

if getgenv().fast_attack then
  getgenv().fast_attack:Disconnect()
end

getgenv().fast_attack = RunService.Stepped:Connect(Module.attack)
