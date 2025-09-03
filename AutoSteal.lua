-- FlyBase Ultimate
-- Interface + Fly com easing + Auto Respawn + Fixação 7s NO CHÃO + Pós-respawn pin reforçado

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
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

-- ======================= AntiResetWhileFlying (simples e só durante o voo) =======================
local HAND_PART_NAMES = {"RightHand","LeftHand"} -- R6: {"Right Arm","Left Arm"}
local Anti = {
    active = false,
    hbConn = nil,
    diedConn = nil,
    resetHooked = false,
}

local function getHands(char)
    local t = {}
    for _,n in ipairs(HAND_PART_NAMES) do
        local h = char:FindFirstChild(n)
        if h and h:IsA("BasePart") then table.insert(t, h) end
    end
    return t
end

local function somethingInHand(char)
    -- Tool equipado?
    for _,child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then return true end
    end
    -- Qualquer solda/peça presa na mão que NÃO seja do próprio char
    for _,hand in ipairs(getHands(char)) do
        for _,d in ipairs(hand:GetDescendants()) do
            if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("Motor6D") then
                local other = nil
                if d:IsA("WeldConstraint") then
                    other = (d.Part0 == hand) and d.Part1 or ((d.Part1 == hand) and d.Part0 or nil)
                else
                    other = (d.Part0 == hand) and d.Part1 or ((d.Part1 == hand) and d.Part0 or nil)
                end
                if other and other:IsA("BasePart") and not other:IsDescendantOf(char) then
                    return true
                end
            end
        end
    end
    return false
end

local function hookResetButton()
    if Anti.resetHooked then return end
    Anti.resetHooked = true
    pcall(function()
        StarterGui:SetCore("ResetButtonCallback", function()
            notify("⛔ Reset bloqueado enquanto estiver voando")
            return -- ignora o reset
        end)
    end)
end

local function unhookResetButton()
    if not Anti.resetHooked then return end
    Anti.resetHooked = false
    pcall(function()
        StarterGui:SetCore("ResetButtonCallback", true) -- restaura comportamento padrão
    end)
end

local function enableAntiReset()
    if Anti.active then return end
    Anti.active = true
    hookResetButton()

    local hum = getHumanoid()
    hum.BreakJointsOnDeath = false
    -- “Deus” temporário só enquanto voa (não deixa zerar saúde)
    local targetMax = math.max(hum.MaxHealth, 1e9)
    hum.MaxHealth = targetMax
    hum.Health = targetMax

    -- mantém health alto durante o voo
    Anti.hbConn = RunService.Heartbeat:Connect(function()
        if not state.isFlying then return end
        if hum.Health < targetMax * 0.99 then
            hum.Health = targetMax
        end
        -- evita cair em Dead
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    end)

    -- se mesmo assim entrar em Died (kill function), cancela e revive instant
    Anti.diedConn = hum.Died:Connect(function()
        if state.isFlying then
            task.spawn(function()
                -- revive na marra
                player:LoadCharacter() -- evita tela de morte
            end)
        end
    end)

    notify("🛡️ Anti-reset ON (voando com item na mão)")
end

local function disableAntiReset()
    if not Anti.active then return end
    Anti.active = false

    if Anti.hbConn then Anti.hbConn:Disconnect(); Anti.hbConn = nil end
    if Anti.diedConn then Anti.diedConn:Disconnect(); Anti.diedConn = nil end

    -- restaura reset e estados
    unhookResetButton()
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
        -- não tento restaurar MaxHealth original pra evitar conflitos com jogos que mexem nisso.
        -- quem quiser pode setar manual depois.
    end
    notify("✅ Anti-reset OFF")
end

-- pega posição no chão abaixo do ponto alvo
local function getGroundPosition(pos: Vector3)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {player.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist

    local result = Workspace:Raycast(pos + Vector3.new(0,10,0), Vector3.new(0,-1000,0), rayParams)
    if result then
        return Vector3.new(pos.X, result.Position.Y + 2, pos.Z)
    else
        return pos
    end
end

-- lock pós-voo
local function hardLockTo(targetPos: Vector3, seconds: number)
    local hrp = getHRP()
    if not hrp or not hrp.Parent then return end

    -- ajusta para o chão
    local groundPos = getGroundPosition(targetPos)

    local t0 = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then if conn then conn:Disconnect() end return end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if (hrp.Position - groundPos).Magnitude > DRIFT_EPS then
            local look = hrp.CFrame - hrp.Position
            hrp.CFrame = CFrame.new(groundPos) * (look - look.Position)
        else
            local look = hrp.CFrame - hrp.Position
            hrp.CFrame = CFrame.new(groundPos) * (look - look.Position)
        end
        if tick() - t0 >= seconds then if conn then conn:Disconnect() end end
    end)
end

-- pós respawn
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

-- UI (mantida)
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

        -- >>> ANTI-RESET: só liga se estiver com algo na mão
        local char = getChar()
        if somethingInHand(char) then
            enableAntiReset()
        end

        state.isFlying = true
        local hrp = getHRP()
        local startPos = hrp.Position
        local target = state.savedCFrame.Position
        local distance = (startPos - target).Magnitude
        local duration = math.clamp(distance/60,1,6)
        local startTime = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then conn:Disconnect(); state.isFlying=false; disableAntiReset(); return end
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
                -- dá o lock no chão e depois solta o anti-reset
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
        -- no respawn, garante que o reset volte ao padrão se não estiver voando
        task.delay(0.2, function()
            if not state.isFlying then disableAntiReset() end
        end)
    end)
end

buildUI()
notify("FlyBase Ultimate carregado! ➕ Set / ✈️ Fly")
