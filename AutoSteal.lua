-- FlyBase Ultimate (server-replicated fly)
-- Usa AssemblyLinearVelocity em vez de só mudar CFrame
-- Mantém UI + Auto Respawn + Fixação no chão + Anti-reset no voo

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

local HOLD_SECONDS = 7
local POST_SPAWN_PIN = 1.2
local DRIFT_EPS = 0.35
local MAX_SPEED = 100 -- velocidade máxima permitida
local ACCEL = 40      -- aceleração (quanto maior, mais rápido pega velocidade)

getgenv().FlyBaseUltimate = getgenv().FlyBaseUltimate or {
    savedCFrame = nil,
    isFlying = false,
    uiBuilt = false,
    autoRespawn = true
}
local state = getgenv().FlyBaseUltimate

local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHRP(char) char = char or getChar(); return char:WaitForChild("HumanoidRootPart") end
local function notify(msg) pcall(function() StarterGui:SetCore("SendNotification",{Title="FlyBase",Text=msg,Duration=2}) end) end

-- posição no chão abaixo do ponto alvo
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

-- fixa no chão após voo
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
        hrp.CFrame = CFrame.new(groundPos, groundPos + hrp.CFrame.LookVector)
        if tick() - t0 >= seconds then if conn then conn:Disconnect() end end
    end)
end

-- pós respawn: puxa de volta pra base
local function postSpawnPin(char)
    if not (state.autoRespawn and state.savedCFrame) then return end
    task.defer(function()
        local hrp = char:WaitForChild("HumanoidRootPart")
        local target = state.savedCFrame
        local groundPos = getGroundPosition(target.Position)
        hrp.CFrame = CFrame.new(groundPos)
        hardLockTo(groundPos, POST_SPAWN_PIN)
    end)
end

-- UI
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
        state.isFlying = true

        local hrp = getHRP()
        local target = getGroundPosition(state.savedCFrame.Position)
        local conn
        conn = RunService.Heartbeat:Connect(function(dt)
            if not hrp or not hrp.Parent then conn:Disconnect(); state.isFlying=false; return end

            local dir = (target - hrp.Position)
            local dist = dir.Magnitude
            if dist < 2 then
                conn:Disconnect()
                state.isFlying=false
                status.Text = "✅ Chegou ao destino!"
                hardLockTo(target,HOLD_SECONDS)
                return
            end

            local desiredVel = dir.Unit * math.clamp(dist, ACCEL, MAX_SPEED)
            -- suaviza aplicando aceleração
            hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(desiredVel, 0.25)
            status.Text = string.format("Distância: %.1f", dist)
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
    end)
end

buildUI()
notify("FlyBase Ultimate carregado! ➕ Set / ✈️ Fly")
