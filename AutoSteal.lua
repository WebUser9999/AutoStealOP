-- FlyBase Ultimate (seu código) + AntiResetWhileFlying (hard)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

local HOLD_SECONDS = 7
local POST_SPAWN_PIN = 1.2
local DRIFT_EPS = 0.35
local MAX_NUDGE = 3

getgenv().FlyBaseUltimate = getgenv().FlyBaseUltimate or {
    savedCFrame = nil,
    isFlying = false,
    uiBuilt = false,
    autoRespawn = true
}
local state = getgenv().FlyBaseUltimate

local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHRP(char) char = char or getChar(); return char:WaitForChild("HumanoidRootPart") end
local function getHumanoid(char) char = char or getChar(); return char:WaitForChild("Humanoid") end
local function notify(msg) pcall(function() StarterGui:SetCore("SendNotification",{Title="FlyBase",Text=msg,Duration=2}) end) end
local function easeInOut(t) return 0.5 - 0.5*math.cos(math.pi*t) end

-- ======================= AntiResetWhileFlying (AGRESSIVO) =======================
local HAND_PART_NAMES = {"RightHand","LeftHand"} -- R6: {"Right Arm","Left Arm"}
local Anti = {
    active = false,
    hb = nil,
    healthConn = nil,
    diedConn = nil,
    reapplyResetHook = nil,
    lastMax = nil,
    resetHooked = false
}

local function hookResetButton()
    if Anti.resetHooked then return end
    Anti.resetHooked = true
    pcall(function()
        StarterGui:SetCore("ResetButtonCallback", function()
            notify("⛔ Reset bloqueado enquanto estiver voando")
            return -- ignora reset
        end)
    end)
end

local function unhookResetButton()
    if not Anti.resetHooked then return end
    Anti.resetHooked = false
    pcall(function()
        StarterGui:SetCore("ResetButtonCallback", true)
    end)
end

local function setToolsDrop(lock)
    -- não recria nada; só impede drop/acidentes enquanto voa
    local char = player.Character
    if not char then return end
    for _,obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then
            pcall(function() obj.CanBeDropped = not lock and true or false end)
        end
    end
    local bp = player:FindFirstChildOfClass("Backpack")
    if bp then
        for _,obj in ipairs(bp:GetChildren()) do
            if obj:IsA("Tool") then
                pcall(function() obj.CanBeDropped = not lock and true or false end)
            end
        end
    end
end

local function enableAntiReset()
    if Anti.active then return end
    Anti.active = true

    hookResetButton()
    -- alguns jogos tentam reativar o reset; re-aplica a cada 0.5s
    Anti.reapplyResetHook = RunService.Heartbeat:Connect(function()
        if not state.isFlying then return end
        hookResetButton()
    end)

    local hum = getHumanoid()
    hum.BreakJointsOnDeath = false
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
    hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)

    -- vida "infinita" durante o voo
    Anti.lastMax = hum.MaxHealth
    local big = 1e9
    hum.MaxHealth = math.max(big, hum.MaxHealth)
    hum.Health = hum.MaxHealth

    -- mantém vida alta continuamente
    Anti.hb = RunService.Heartbeat:Connect(function()
        if not state.isFlying then return end
        if hum.Health < hum.MaxHealth * 0.99 then
            hum.Health = hum.MaxHealth
        end
    end)

    -- se algum script zerar a vida, volta
    Anti.healthConn = hum:GetPropertyChangedSignal("Health"):Connect(function()
        if state.isFlying and hum.Health < hum.MaxHealth * 0.99 then
            hum.Health = hum.MaxHealth
        end
    end)

    -- se ainda assim entrar em Died, tenta “desmorrer” rápido
    Anti.diedConn = hum.Died:Connect(function()
        if state.isFlying then
            task.defer(function()
                -- força um "revive" local (melhor que LoadCharacter pra não perder nada)
                local hrp = getHRP()
                if hrp and hrp.Parent then
                    hum:ChangeState(Enum.HumanoidStateType.GettingUp)
                    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                    hum.Health = hum.MaxHealth
                end
            end)
        end
    end)

    -- evita drop involuntário
    setToolsDrop(true)
    notify("🛡️ Anti-reset (voo) ON")
end

local function disableAntiReset()
    if not Anti.active then return end
    Anti.active = false

    if Anti.hb then Anti.hb:Disconnect(); Anti.hb = nil end
    if Anti.healthConn then Anti.healthConn:Disconnect(); Anti.healthConn = nil end
    if Anti.diedConn then Anti.diedConn:Disconnect(); Anti.diedConn = nil end
    if Anti.reapplyResetHook then Anti.reapplyResetHook:Disconnect(); Anti.reapplyResetHook = nil end

    unhookResetButton()

    -- restaura drop
    setToolsDrop(false)

    -- reabilita estados; mantém MaxHealth grandão pra evitar conflito? vamos restaurar:
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, true)
        hum:SetStateEnabled(Enum.HumanoidStateType.Physics, true)
        if Anti.lastMax and Anti.lastMax >= 0 then
            pcall(function() hum.MaxHealth = Anti.lastMax end)
            if hum.Health > hum.MaxHealth then hum.Health = hum.MaxHealth end
        end
    end

    notify("✅ Anti-reset (voo) OFF")
end

-- ======================= (seu) helpers de chão/lock =======================
local function getGroundPosition(pos: Vector3)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {player.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(pos + Vector3.new(0,10,0), Vector3.new(0,-1000,0), rayParams)
    if result then
        return Vector3.new(pos.X, result.Position.Y + 2, pos.Z)
    else
        return pos
    end
end

local function hardLockTo(targetPos: Vector3, seconds: number)
    local hrp = getHRP()
    if not hrp or not hrp.Parent then return end
    local groundPos = getGroundPosition(targetPos)
    local t0 = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then if conn then conn:Disconnect() end return end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        local look = hrp.CFrame - hrp.Position
        hrp.CFrame = CFrame.new(groundPos) * (look - look.Position)
        if tick() - t0 >= seconds then if conn then conn:Disconnect() end end
    end)
end

local function postSpawnPin(char)
    if not (state.autoRespawn and state.savedCFrame) then return end
    task.defer(function()
        local hrp = char:WaitForChild("HumanoidRootPart")
        local target = state.savedCFrame
        local groundPos = getGroundPosition(target.Position)
        hrp.CFrame = CFrame.new(groundPos)
        local t0 = tick()
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not hrp or not hrp.Parent then if conn then conn:Disconnect() end return end
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            if (hrp.Position - groundPos).Magnitude > DRIFT_EPS then
                local look = hrp.CFrame - hrp.Position
                hrp.CFrame = CFrame.new(groundPos) * (look - look.Position)
            end
            if tick() - t0 >= POST_SPAWN_PIN then if conn then conn:Disconnect() end end
        end)
    end)
end

-- ======================= UI (seu código) =======================
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt = true
    local gui = Instance.new("ScreenGui")
    gui.Name = "FlyBaseUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(260,250)
    frame.Position = UDim2.fromScale(0.75,0.6)
    frame.BackgroundColor3 = Color3.fromRGB(30,30,40)
    frame.Parent = gui
    Instance.new("UICorner", frame)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(120,140,255)

    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0,10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(200,30)
    title.BackgroundTransparency = 1
    title.Text = "🚀 FlyBase Ultimate"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Parent = frame

    local function makeBtn(txt, baseColor, hoverColor)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(200,44)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 16
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.BackgroundColor3 = baseColor
        Instance.new("UICorner", b)
        b.MouseEnter:Connect(function() b.BackgroundColor3 = hoverColor end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = baseColor end)
        b.Parent = frame
        return b
    end

    local setBtn = makeBtn("➕ Set Position",Color3.fromRGB(70,120,70),Color3.fromRGB(90,160,90))
    local flyBtn = makeBtn("✈️ Fly to Base",Color3.fromRGB(70,70,120),Color3.fromRGB(100,100,160))
    local toggleBtn = makeBtn("🔄 Auto Respawn: ON",Color3.fromRGB(120,90,70),Color3.fromRGB(160,120,90))

    local status = Instance.new("TextLabel")
    status.Size = UDim2.fromOffset(220,20)
    status.BackgroundTransparency = 1
    status.Text = "Base salva: nenhuma"
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.TextColor3 = Color3.fromRGB(200,220,255)
    status.Parent = frame

    setBtn.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        state.savedCFrame = hrp.CFrame
        status.Text = "📍 Base salva ✔"
    end)

    flyBtn.MouseButton1Click:Connect(function()
        if state.isFlying or not state.savedCFrame then return end

        -- LIGA Anti-reset só durante o voo
        enableAntiReset()

        state.isFlying = true
        local hrp = getHRP()
        local startPos = hrp.Position
        local target = state.savedCFrame.Position
        local distance = (startPos - target).Magnitude
        local duration = math.clamp(distance/60,1,6)
        local startTime = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then
                conn:Disconnect(); state.isFlying=false; disableAntiReset(); return
            end
            local elapsed = tick()-startTime
            local alpha = math.clamp(elapsed/duration,0,1)
            local eased = easeInOut(alpha)
            local stepPos = startPos:Lerp(target,eased)
            local cur = hrp.Position
            local dir = (stepPos-cur)
            if dir.Magnitude > MAX_NUDGE then stepPos = cur + dir.Unit*MAX_NUDGE end
            hrp.CFrame = CFrame.new(stepPos,target)
            local remain = (target-stepPos).Magnitude
            local speed = (distance/duration)*math.sin(alpha*math.pi)
            status.Text = string.format("Distância: %.1f | Vel: %.1f",remain,speed)
            if alpha>=1 then
                conn:Disconnect(); state.isFlying=false; status.Text="✅ Chegou ao destino!"
                hardLockTo(target,HOLD_SECONDS)
                task.delay(HOLD_SECONDS, function()
                    disableAntiReset()
                end)
            end
        end)
    end)

    toggleBtn.MouseButton1Click:Connect(function()
        state.autoRespawn = not state.autoRespawn
        toggleBtn.Text = state.autoRespawn and "🔄 Auto Respawn: ON" or "🔄 Auto Respawn: OFF"
    end)

    RunService.RenderStepped:Connect(function()
        local t = tick()
        stroke.Color = Color3.fromHSV((t%6)/6,0.6,1)
    end)

    player.CharacterAdded:Connect(function(char)
        gui.Parent = player:WaitForChild("PlayerGui")
        postSpawnPin(char)
        -- se respawnou enquanto voava (edge), tenta desligar proteção pra evitar bug visual
        task.delay(0.2, function()
            if not state.isFlying then disableAntiReset() end
        end)
    end)
end

buildUI()
notify("FlyBase Ultimate carregado! ➕ Set / ✈️ Fly")
