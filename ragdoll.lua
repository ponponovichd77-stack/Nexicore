--[[
   NexiCore | RAGDOLL BEASTS
   UI: Rayfield (бесплатный, open source) — https://sirius.menu/rayfield
   Запуск: экзекутор с HttpGet + loadstring (Delta / Solara / Wave / Swift / Xeno)
]]

if not game:IsLoaded() then game.Loaded:Wait() end

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local VIM              = game:GetService("VirtualInputManager")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local LocalPlayer      = Players.LocalPlayer
local Camera           = workspace.CurrentCamera

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
   Camera = workspace.CurrentCamera
end)

local Rayfield
for _, url in ipairs({
   "https://sirius.menu/rayfield",
   "https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/main/source.lua",
}) do
   local ok, result = pcall(function() return loadstring(game:HttpGet(url))() end)
   if ok and result then Rayfield = result break end
end
if not Rayfield then
   warn("[NexiCore] Rayfield не загрузился — проверь HttpGet в экзекуторе")
   return
end

-- ============================ state ============================

local S = {
   -- legit
   legitPunch   = false,
   legitDelay   = 0.115,
   aimAssist    = false,
   assisSmooth  = 5,
   antiStun     = false,
   walkSpeed    = 16,
   autoClimb    = false,
   -- rage
   ragePunch    = false,
   rageDelay    = 0.030,
   autoGrab     = false,
   grabRange    = 13,
   tpBehind     = false,
   autoTp       = false,
   tpRange      = 40,
   ignoreTeam   = true,
   flingMode    = "Velocity",
   -- aim
   aimRange     = 90,
   aimPart      = "Head",
   -- visuals
   espMode      = "Box",
   espColor     = Color3.fromRGB(140, 100, 255),
   espRange     = 500,
   espNames     = true,
   espHealth    = true,
   skyPreset    = "Default",
   charMaterial = "Default",
   charAlpha    = 0,
   charColor    = nil,
   fullbright   = false,
   -- misc
   antiAfk      = true,
}

local function mDown(btn)
   if btn == "L" then
      if type(mouse1down) == "function" then pcall(mouse1down) else VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1) end
   else
      if type(mouse2down) == "function" then pcall(mouse2down) else VIM:SendMouseButtonEvent(0, 0, 1, true, game, 1) end
   end
end

local function mUp(btn)
   if btn == "L" then
      if type(mouse1release) == "function" then pcall(mouse1release) else VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1) end
   else
      if type(mouse2release) == "function" then pcall(mouse2release) else VIM:SendMouseButtonEvent(0, 0, 1, false, game, 1) end
   end
end

local function click(btn, hold)
   mDown(btn)
   task.wait(hold or 0.03)
   mUp(btn)
end

local function spaceTap()
   VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
   task.wait(0.04)
   VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
end

-- ============================ targets ============================

local function isEnemy(plr)
   if plr == LocalPlayer then return false end
   local char = plr.Character
   if not char then return false end
   local hum = char:FindFirstChildOfClass("Humanoid")
   if not hum or hum.Health <= 0 then return false end
   if S.ignoreTeam and LocalPlayer.Team ~= nil and plr.Team ~= nil and plr.Team == LocalPlayer.Team then
      return false
   end
   return true
end

local function aimPartOf(char)
   local part = char:FindFirstChild(S.aimPart)
   if not part or not part:IsA("BasePart") then
      part = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
   end
   return part
end

local function pickTarget(range)
   local origin = Camera.CFrame.Position
   local best, bestDist
   for _, plr in ipairs(Players:GetPlayers()) do
      if isEnemy(plr) then
         local part = aimPartOf(plr.Character)
         if part then
            local dist = (part.Position - origin).Magnitude
            if dist <= range and (not bestDist or dist < bestDist) then
               best, bestDist = plr, dist
            end
         end
      end
   end
   return best, bestDist
end

-- ============================ movement ============================

local function teleportBehind(plr)
   local char = LocalPlayer.Character
   local root = char and char:FindFirstChild("HumanoidRootPart")
   local tchar = plr and plr.Character
   local troot = tchar and tchar:FindFirstChild("HumanoidRootPart")
   if not (root and troot) then return false end

   local behind = troot.Position - troot.CFrame.LookVector * 2.8 + Vector3.new(0, 1, 0)
   pcall(function()
      char:PivotTo(CFrame.lookAt(behind, troot.Position))
   end)
   return true
end

local function flingTarget(plr)
   local char = LocalPlayer.Character
   local root = char and char:FindFirstChild("HumanoidRootPart")
   local tchar = plr and plr.Character
   local troot = tchar and tchar:FindFirstChild("HumanoidRootPart")
   local thead = tchar and tchar:FindFirstChild("Head")
   if not (root and troot) then return end

   if S.flingMode == "Head-on" and thead then
      root.CFrame = thead.CFrame
   elseif S.flingMode == "Spin" then
      root.CFrame = troot.CFrame * CFrame.new(0, 1.5, 0)
   else
      root.CFrame = troot.CFrame * CFrame.new(0, 1.5, 1.2)
   end
   task.wait()

   pcall(function()
      root.AssemblyAngularVelocity = Vector3.new(9e5, 9e5, 9e5)
      root.AssemblyLinearVelocity = Vector3.new(0, 4e4, 0)
   end)
   task.delay(0.3, function()
      if root and root.Parent then
         pcall(function()
            root.AssemblyAngularVelocity = Vector3.zero
            root.AssemblyLinearVelocity = Vector3.zero
         end)
      end
   end)
end

-- ============================ combat loops ============================

local lastPunch = 0
task.spawn(function()
   while task.wait(0.008) do
      local now = os.clock()
      if S.ragePunch and now - lastPunch >= S.rageDelay then
         lastPunch = now
         if S.autoGrab then
            local plr = pickTarget(S.grabRange)
            if plr then click("L", 0.06) end
         else
            click("L", 0.02)
         end
      elseif S.legitPunch and now - lastPunch >= S.legitDelay then
         lastPunch = now
         click("L", 0.03)
      end
   end
end)

-- стабильное удержание захвата в rage
local grabHeld = false
RunService.Heartbeat:Connect(function()
   if not S.autoGrab then
      if grabHeld then mUp("L"); grabHeld = false end
      return
   end
   local plr = pickTarget(S.grabRange)
   if plr then
      if not grabHeld then mDown("L"); grabHeld = true end
   elseif grabHeld then
      mUp("L"); grabHeld = false
   end
end)

-- авто-климб
local climbSide = false
task.spawn(function()
   while task.wait(0.09) do
      if S.autoClimb then
         spaceTap()
         climbSide = not climbSide
         click(climbSide and "L" or "R", 0.02)
      end
   end
end)

-- выход из стана / кулдауна
task.spawn(function()
   while task.wait(0.1) do
      if S.antiStun then
         local char = LocalPlayer.Character
         local hum = char and char:FindFirstChildOfClass("Humanoid")
         if hum then
            local state = hum:GetState()
            if hum.PlatformStand
               or state == Enum.HumanoidStateType.Physics
               or state == Enum.HumanoidStateType.FallingDown
               or state == Enum.HumanoidStateType.Ragdoll then
               spaceTap()
               click("L", 0.02)
            end
         end
      end
   end
end)

-- авто TP за спину
task.spawn(function()
   while task.wait(0.25) do
      if S.autoTp then
         local plr = pickTarget(S.tpRange)
         if plr then teleportBehind(plr) end
      end
   end
end)

-- ============================ speed ============================

task.spawn(function()
   while task.wait(0.3) do
      local char = LocalPlayer.Character
      local hum = char and char:FindFirstChildOfClass("Humanoid")
      if hum then hum.WalkSpeed = S.walkSpeed end
   end
end)

-- ============================ aim ============================

local rageAim = false
RunService.RenderStepped:Connect(function(dt)
   if not (rageAim or S.aimAssist) then return end
   local plr = pickTarget(S.aimRange)
   if not plr then return end
   local part = aimPartOf(plr.Character)
   if not part then return end
   local desired = CFrame.lookAt(Camera.CFrame.Position, part.Position)
   local speed = rageAim and 55 or S.assisSmooth
   Camera.CFrame = Camera.CFrame:Lerp(desired, math.clamp(dt * speed, 0.02, 1))
end)

-- ============================ ESP ============================

local hasDrawing = pcall(function()
   local sq = Drawing.new("Square")
   sq:Remove()
   return true
end)

local boxes = {}

local function newBox()
   local b = {}
   b.square = Drawing.new("Square")
   b.square.Thickness = 1
   b.square.Filled = false
   b.square.Transparency = 1
   b.fill = Drawing.new("Square")
   b.fill.Filled = true
   b.fill.Transparency = 0.15
   b.name = Drawing.new("Text")
   b.name.Size = 14
   b.name.Center = true
   b.name.Outline = true
   b.name.Font = 2
   b.hp = Drawing.new("Square")
   b.hp.Filled = true
   b.hp.Thickness = 0
   return b
end

local function hideBox(b)
   b.square.Visible = false
   b.fill.Visible = false
   b.name.Visible = false
   b.hp.Visible = false
end

local function destroyBox(b)
   for _, v in pairs(b) do pcall(function() v:Remove() end) end
end

local function drawBox(plr, b)
   local char = plr.Character
   local head = char and char:FindFirstChild("Head")
   local root = char and char:FindFirstChild("HumanoidRootPart")
   local hum = char and char:FindFirstChildOfClass("Humanoid")
   if not (head and root and hum and hum.Health > 0) then hideBox(b) return end

   local hp, onScreen = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0))
   if not onScreen then hideBox(b) return end

   local fp = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.8, 0))
   local height = math.abs(fp.Y - hp.Y)
   if height < 6 then hideBox(b) return end
   local width = height * 0.52
   local x, y = hp.X - width / 2, hp.Y

   b.square.Position = Vector2.new(x, y)
   b.square.Size = Vector2.new(width, height)
   b.square.Color = S.espColor
   b.square.Visible = true

   b.fill.Position = Vector2.new(x, y)
   b.fill.Size = Vector2.new(width, height)
   b.fill.Color = S.espColor
   b.fill.Visible = true

   if S.espNames then
      local dist = math.floor((root.Position - Camera.CFrame.Position).Magnitude)
      b.name.Text = plr.DisplayName .. " [" .. dist .. "m]"
      b.name.Position = Vector2.new(x + width / 2, y - 18)
      b.name.Color = Color3.fromRGB(255, 255, 255)
      b.name.Visible = true
   else
      b.name.Visible = false
   end

   if S.espHealth then
      local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
      b.hp.Position = Vector2.new(x - 5, y + height * (1 - frac))
      b.hp.Size = Vector2.new(2, height * frac)
      b.hp.Color = Color3.fromRGB(80, 255, 120):Lerp(Color3.fromRGB(255, 60, 60), 1 - frac)
      b.hp.Visible = true
   else
      b.hp.Visible = false
   end
end

local ghosts = {}

local function updateGhosts()
   local want = S.espMode == "Ghost" or S.espMode == "Box+Ghost"
   for _, plr in ipairs(Players:GetPlayers()) do
      if plr ~= LocalPlayer then
         local char = plr.Character
         local hum = char and char:FindFirstChildOfClass("Humanoid")
         local root = char and char:FindFirstChild("HumanoidRootPart")
         local hl = char and char:FindFirstChild("NexiCoreGhost")
         local inRange = root and (root.Position - Camera.CFrame.Position).Magnitude <= S.espRange
         if want and char and hum and hum.Health > 0 and inRange then
            if not hl then
               hl = Instance.new("Highlight")
               hl.Name = "NexiCoreGhost"
               hl.Parent = char
               hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
               hl.OutlineTransparency = 1
               hl.FillTransparency = 0.82
               hl.Adornee = char
            end
            hl.FillColor = S.espColor
         elseif hl then
            hl:Destroy()
         end
      end
   end
end

RunService.RenderStepped:Connect(function()
   updateGhosts()

   local boxMode = (S.espMode == "Box" or S.espMode == "Box+Ghost") and hasDrawing
   if not boxMode then
      for _, b in pairs(boxes) do hideBox(b) end
      return
   end

   for _, plr in ipairs(Players:GetPlayers()) do
      if plr ~= LocalPlayer then
         local b = boxes[plr]
         if not b then b = newBox(); boxes[plr] = b end
         local char = plr.Character
         local root = char and char:FindFirstChild("HumanoidRootPart")
         if not root or (root.Position - Camera.CFrame.Position).Magnitude > S.espRange then
            hideBox(b)
         else
            drawBox(plr, b)
         end
      end
   end
end)

Players.PlayerRemoving:Connect(function(plr)
   local b = boxes[plr]
   if b then destroyBox(b); boxes[plr] = nil end
end)

-- ============================ sky / lighting ============================

local SKY = {
   Default = { clock = 14, brightness = 2, ambient = Color3.fromRGB(70, 70, 70), outdoor = Color3.fromRGB(128, 128, 128),
               fog = Color3.fromRGB(192, 192, 192), fogEnd = 100000, shadows = true, density = 0.3, haze = 1.5,
               atmColor = Color3.fromRGB(199, 199, 199), decay = Color3.fromRGB(106, 112, 125) },
   Night   = { clock = 0, brightness = 0.5, ambient = Color3.fromRGB(20, 24, 45), outdoor = Color3.fromRGB(40, 46, 80),
               fog = Color3.fromRGB(15, 18, 35), fogEnd = 600, shadows = true, density = 0.35, haze = 2,
               atmColor = Color3.fromRGB(30, 40, 90), decay = Color3.fromRGB(20, 20, 40) },
   Neon    = { clock = 14, brightness = 3.5, ambient = Color3.fromRGB(120, 40, 200), outdoor = Color3.fromRGB(90, 30, 160),
               fog = Color3.fromRGB(60, 10, 110), fogEnd = 400, shadows = false, density = 0.45, haze = 4,
               atmColor = Color3.fromRGB(180, 60, 255), decay = Color3.fromRGB(90, 20, 140) },
   Hell    = { clock = 0.4, brightness = 2.5, ambient = Color3.fromRGB(120, 20, 10), outdoor = Color3.fromRGB(160, 40, 20),
               fog = Color3.fromRGB(90, 10, 5), fogEnd = 250, shadows = true, density = 0.6, haze = 6,
               atmColor = Color3.fromRGB(255, 80, 30), decay = Color3.fromRGB(120, 20, 10) },
   Void    = { clock = 0, brightness = 0.2, ambient = Color3.fromRGB(5, 5, 8), outdoor = Color3.fromRGB(8, 8, 12),
               fog = Color3.fromRGB(0, 0, 0), fogEnd = 300, shadows = false, density = 0.5, haze = 1,
               atmColor = Color3.fromRGB(10, 10, 15), decay = Color3.fromRGB(5, 5, 8), emptySky = true },
}

local function applySky(name)
   local p = SKY[name] or SKY.Default
   for _, v in ipairs(Lighting:GetChildren()) do
      if v:IsA("Sky") or v:IsA("Atmosphere") then v:Destroy() end
   end
   Lighting.ClockTime = p.clock
   Lighting.Brightness = p.brightness
   Lighting.Ambient = p.ambient
   Lighting.OutdoorAmbient = p.outdoor
   Lighting.FogColor = p.fog
   Lighting.FogEnd = p.fogEnd
   Lighting.GlobalShadows = p.shadows
   Lighting.FogStart = 0

   local sky = Instance.new("Sky")
   sky.Name = "NexiCoreSky"
   sky.Parent = Lighting

   local atm = Instance.new("Atmosphere")
   atm.Name = "NexiCoreAtmosphere"
   atm.Density = p.density
   atm.Haze = p.haze
   atm.Color = p.atmColor
   atm.Decay = p.decay
   atm.Parent = Lighting

   if name == "Void" then
      -- пустой Sky без текстур = чёрное небо
      Lighting.FogEnd = 350
   end
end

local function applyFullbright(on)
   if on then
      Lighting.Brightness = 4
      Lighting.ClockTime = 14
      Lighting.GlobalShadows = false
      Lighting.FogEnd = 1e6
      Lighting.Ambient = Color3.new(1, 1, 1)
      Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
   else
      applySky(S.skyPreset)
   end
end

-- ============================ character material ============================

local function applyCharLook()
   local char = LocalPlayer.Character
   if not char then return end
   for _, d in ipairs(char:GetDescendants()) do
      if d:IsA("BasePart") then
         if S.charMaterial ~= "Default" then
            local ok = pcall(function() d.Material = Enum.Material[S.charMaterial] end)
            if not ok then d.Material = Enum.Material.SmoothPlastic end
         end
         d.Transparency = S.charAlpha
         if S.charColor then d.Color = S.charColor end
      end
   end
end

LocalPlayer.CharacterAdded:Connect(function()
   task.wait(0.5)
   applyCharLook()
end)

-- ============================ anti-afk ============================

LocalPlayer.Idled:Connect(function()
   if S.antiAfk then spaceTap() end
end)

-- ============================ UI ============================

local Window = Rayfield:CreateWindow({
   Name = "NexiCore | Ragdoll Beasts",
   LoadingTitle = "NexiCore",
   LoadingSubtitle = "ragdoll beasts",
   ConfigurationSaving = { Enabled = false },
   KeySystem = false,
})

local function safe(fn)
   local ok, err = pcall(fn)
   if not ok then warn("[NexiCore] UI: " .. tostring(err)) end
end

-- ---------- LEGIT ----------
local Legit = Window:CreateTab("Legit", 0)
Legit:CreateSection("Удары")
Legit:CreateToggle({
   Name = "Авто-удар (легит)",
   CurrentValue = false,
   Flag = "LegitPunch",
   Callback = function(v) S.legitPunch = v end,
})
Legit:CreateSlider({
   Name = "Задержка удара",
   Range = { 80, 300 },
   Increment = 5,
   Suffix = " мс",
   CurrentValue = 115,
   Flag = "LegitDelay",
   Callback = function(v) S.legitDelay = v / 1000 end,
})
Legit:CreateToggle({
   Name = "Выход из стана / КД",
   CurrentValue = false,
   Flag = "AntiStun",
   Callback = function(v) S.antiStun = v end,
})
Legit:CreateSection("Наведение")
Legit:CreateToggle({
   Name = "Помощь в наведении",
   CurrentValue = false,
   Flag = "AimAssist",
   Callback = function(v) S.aimAssist = v end,
})
Legit:CreateSlider({
   Name = "Плавность ведения",
   Range = { 1, 20 },
   Increment = 1,
   CurrentValue = 5,
   Flag = "AssistSmooth",
   Callback = function(v) S.assisSmooth = v end,
})
Legit:CreateSection("Движение")
Legit:CreateToggle({
   Name = "Авто-климб",
   CurrentValue = false,
   Flag = "AutoClimb",
   Callback = function(v) S.autoClimb = v end,
})
Legit:CreateSlider({
   Name = "WalkSpeed",
   Range = { 16, 32 },
   Increment = 1,
   CurrentValue = 16,
   Flag = "WalkSpeed",
   Callback = function(v) S.walkSpeed = v end,
})

-- ---------- RAGE ----------
local Rage = Window:CreateTab("Rage", 0)
Rage:CreateSection("Удары")
Rage:CreateToggle({
   Name = "Быстрые удары (rage)",
   CurrentValue = false,
   Flag = "RagePunch",
   Callback = function(v) S.ragePunch = v end,
})
Rage:CreateSlider({
   Name = "Задержка удара",
   Range = { 10, 200 },
   Increment = 5,
   Suffix = " мс",
   CurrentValue = 30,
   Flag = "RageDelay",
   Callback = function(v) S.rageDelay = v / 1000 end,
})
Rage:CreateToggle({
   Name = "Авто-захват",
   CurrentValue = false,
   Flag = "AutoGrab",
   Callback = function(v) S.autoGrab = v end,
})
Rage:CreateSlider({
   Name = "Дистанция захвата",
   Range = { 4, 40 },
   Increment = 1,
   Suffix = " м",
   CurrentValue = 13,
   Flag = "GrabRange",
   Callback = function(v) S.grabRange = v end,
})
Rage:CreateSection("Позиция")
Rage:CreateToggle({
   Name = "TP за спину (при нажатии Z)",
   CurrentValue = false,
   Flag = "TpBehind",
   Callback = function(v) S.tpBehind = v end,
})
Rage:CreateToggle({
   Name = "Авто TP за спину",
   CurrentValue = false,
   Flag = "AutoTp",
   Callback = function(v) S.autoTp = v end,
})
Rage:CreateSlider({
   Name = "Дистанция TP",
   Range = { 5, 120 },
   Increment = 5,
   Suffix = " м",
   CurrentValue = 40,
   Flag = "TpRange",
   Callback = function(v) S.tpRange = v end,
})
Rage:CreateToggle({
   Name = "Игнорировать союзников",
   CurrentValue = true,
   Flag = "IgnoreTeam",
   Callback = function(v) S.ignoreTeam = v end,
})
Rage:CreateSection("Флинг")
Rage:CreateDropdown({
   Name = "Режим флинга",
   Options = { "Velocity", "Spin", "Head-on" },
   CurrentOption = { "Velocity" },
   Flag = "FlingMode",
   Callback = function(opt)
      S.flingMode = type(opt) == "table" and opt[1] or opt
   end,
})
Rage:CreateButton({
   Name = "Флинг цели (X)",
   Callback = function()
      local plr = pickTarget(S.tpRange)
      if plr then flingTarget(plr) end
   end,
})
Rage:CreateButton({
   Name = "One-Click: TP + флинг",
   Callback = function()
      local plr = pickTarget(S.tpRange)
      if plr then
         teleportBehind(plr)
         task.wait(0.05)
         flingTarget(plr)
      end
   end,
})
Rage:CreateSection("Наведение")
Rage:CreateToggle({
   Name = "Жёсткий aim",
   CurrentValue = false,
   Flag = "RageAim",
   Callback = function(v) rageAim = v end,
})
Rage:CreateSlider({
   Name = "Дистанция aim",
   Range = { 10, 250 },
   Increment = 5,
   Suffix = " м",
   CurrentValue = 90,
   Flag = "AimRange",
   Callback = function(v) S.aimRange = v end,
})
Rage:CreateDropdown({
   Name = "Часть цели",
   Options = { "Head", "HumanoidRootPart" },
   CurrentOption = { "Head" },
   Flag = "AimPart",
   Callback = function(opt)
      S.aimPart = type(opt) == "table" and opt[1] or opt
   end,
})

-- ---------- VISUALS ----------
local Visual = Window:CreateTab("Визуал", 0)
Visual:CreateSection("ESP")
if hasDrawing then
   Visual:CreateDropdown({
      Name = "Режим ESP",
      Options = { "Off", "Box", "Ghost", "Box+Ghost" },
      CurrentOption = { "Box" },
      Flag = "EspMode",
      Callback = function(opt) S.espMode = type(opt) == "table" and opt[1] or opt end,
   })
else
   Visual:CreateDropdown({
      Name = "Режим ESP (только Ghost)",
      Options = { "Off", "Ghost" },
      CurrentOption = { "Ghost" },
      Flag = "EspMode",
      Callback = function(opt) S.espMode = type(opt) == "table" and opt[1] or opt end,
   })
end
safe(function()
   Visual:CreateColorPicker({
      Name = "Цвет ESP",
      Color = Color3.fromRGB(140, 100, 255),
      Flag = "EspColor",
      Callback = function(c) S.espColor = c end,
   })
end)
Visual:CreateSlider({
   Name = "Дистанция ESP",
   Range = { 50, 2000 },
   Increment = 50,
   Suffix = " м",
   CurrentValue = 500,
   Flag = "EspRange",
   Callback = function(v) S.espRange = v end,
})
Visual:CreateToggle({
   Name = "Имена и дистанция",
   CurrentValue = true,
   Flag = "EspNames",
   Callback = function(v) S.espNames = v end,
})
Visual:CreateToggle({
   Name = "Полоска HP",
   CurrentValue = true,
   Flag = "EspHealth",
   Callback = function(v) S.espHealth = v end,
})

Visual:CreateSection("Небо и свет")
Visual:CreateDropdown({
   Name = "Небо",
   Options = { "Default", "Night", "Neon", "Hell", "Void" },
   CurrentOption = { "Default" },
   Flag = "SkyPreset",
   Callback = function(opt)
      S.skyPreset = type(opt) == "table" and opt[1] or opt
      applySky(S.skyPreset)
   end,
})
Visual:CreateToggle({
   Name = "Fullbright",
   CurrentValue = false,
   Flag = "Fullbright",
   Callback = function(v)
      S.fullbright = v
      applyFullbright(v)
   end,
})

Visual:CreateSection("Кукла")
Visual:CreateDropdown({
   Name = "Материал",
   Options = { "Default", "Neon", "Glass", "ForceField", "SmoothPlastic", "Metal", "Marble", "Fabric", "Slate" },
   CurrentOption = { "Default" },
   Flag = "CharMaterial",
   Callback = function(opt)
      S.charMaterial = type(opt) == "table" and opt[1] or opt
      applyCharLook()
   end,
})
Visual:CreateSlider({
   Name = "Прозрачность",
   Range = { 0, 1 },
   Increment = 0.05,
   CurrentValue = 0,
   Flag = "CharAlpha",
   Callback = function(v) S.charAlpha = v; applyCharLook() end,
})
safe(function()
   Visual:CreateColorPicker({
      Name = "Цвет куклы",
      Color = Color3.fromRGB(160, 120, 255),
      Flag = "CharColor",
      Callback = function(c) S.charColor = c; applyCharLook() end,
   })
end)
Visual:CreateButton({
   Name = "Сбросить вид куклы",
   Callback = function()
      S.charMaterial = "Default"
      S.charAlpha = 0
      S.charColor = nil
      local char = LocalPlayer.Character
      if char then
         for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") then d.Transparency = 0 end
         end
      end
   end,
})

-- ---------- UTILITY ----------
local Util = Window:CreateTab("Утилиты", 0)
Util:CreateToggle({
   Name = "Anti-AFK",
   CurrentValue = true,
   Flag = "AntiAfk",
   Callback = function(v) S.antiAfk = v end,
})
Util:CreateButton({
   Name = "Перезайти",
   Callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end,
})
Util:CreateButton({
   Name = "Сбросить свет и небо",
   Callback = function()
      S.skyPreset = "Default"
      S.fullbright = false
      applySky("Default")
   end,
})

-- хоткеи
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
   if processed then return end
   if input.KeyCode == Enum.KeyCode.Z and S.tpBehind then
      local plr = pickTarget(S.tpRange)
      if plr then teleportBehind(plr) end
   elseif input.KeyCode == Enum.KeyCode.X then
      local plr = pickTarget(S.tpRange)
      if plr then flingTarget(plr) end
   end
end)

pcall(function()
   Rayfield:Notify({
      Title = "NexiCore",
      Content = "Загружено: Legit / Rage / Визуал / Утилиты",
      Duration = 5,
      Image = 0,
   })
end)
