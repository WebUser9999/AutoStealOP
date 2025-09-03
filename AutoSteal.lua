-- FlyBase Ultimate
-- Interface + Fly com easing + Auto Respawn + Fixação 7s NO CHÃO + Pós-respawn pin reforçado

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
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
local function notify(msg) pcall(function() game.StarterGui:SetCore("SendNotification",{Title="FlyBase",Text=msg,Duration=2}) end) end
local function easeInOut(t) return 0.5 - 0.5*math.cos(math.pi*t) end

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
        state.isFlying = true
        local hrp = getHRP()
        local startPos = hrp.Position
        local target = state.savedCFrame.Position
        local distance = (startPos - target).Magnitude
        local duration = math.clamp(distance/60,1,6)
        local startTime = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then conn:Disconnect(); state.isFlying=false; return end
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
    end)
end

buildUI()
notify("FlyBase Ultimate carregado! ➕ Set / ✈️ Fly")
