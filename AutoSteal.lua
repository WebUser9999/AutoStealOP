-- FlyBase Cinematic
-- Voo com câmera, efeitos visuais e HUD

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- estado global
getgenv().FlyCinematic = getgenv().FlyCinematic or {
    savedCFrame = nil,
    isFlying = false,
    uiBuilt = false
}
local state = getgenv().FlyCinematic

-- utils
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

local function notify(msg)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "FlyBase",
            Text = msg,
            Duration = 3
        })
    end)
end

-- cria UI
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt = true

    local gui = Instance.new("ScreenGui")
    gui.Name = "FlyBaseUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(220, 180)
    frame.Position = UDim2.fromScale(0.8, 0.7)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    frame.Parent = gui
    Instance.new("UICorner", frame)

    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0, 12)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(200, 24)
    title.BackgroundTransparency = 1
    title.Text = "🚀 FlyBase Cinematic"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.new(1,1,1)
    title.Parent = frame

    local function makeBtn(txt)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(160, 40)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 16
        b.TextColor3 = Color3.new(1,1,1)
        b.BackgroundColor3 = Color3.fromRGB(50,50,70)
        Instance.new("UICorner", b)
        b.Parent = frame
        return b
    end

    local setBtn = makeBtn("➕ Set Position")
    local flyBtn = makeBtn("✈️ Fly to Base")

    -- HUD central
    local hud = Instance.new("TextLabel")
    hud.Size = UDim2.fromScale(1, 0.1)
    hud.Position = UDim2.fromScale(0, 0.45)
    hud.BackgroundTransparency = 1
    hud.Text = ""
    hud.Font = Enum.Font.GothamBlack
    hud.TextSize = 28
    hud.TextColor3 = Color3.fromRGB(200, 240, 255)
    hud.Parent = gui

    -- SET
    setBtn.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        state.savedCFrame = hrp.CFrame
        notify("📍 Posição salva!")
    end)

    -- FLY
    flyBtn.MouseButton1Click:Connect(function()
        if state.isFlying or not state.savedCFrame then
            notify("⚠️ Nenhuma posição salva.")
            return
        end
        state.isFlying = true

        local hrp, hum = getHRP()
        local startPos = hrp.Position
        local target = state.savedCFrame.Position

        local distance = (startPos - target).Magnitude
        local duration = math.clamp(distance/60, 0.5, 6)

        local startTime = tick()
        local startFOV = camera.FieldOfView
        hud.Text = "✈️ VOANDO PARA BASE..."

        -- partículas de rastro
        local attachment = Instance.new("Attachment", hrp)
        local trail = Instance.new("Trail")
        trail.Attachment0 = attachment
        trail.Attachment1 = attachment
        trail.Color = ColorSequence.new(Color3.fromRGB(90,120,255), Color3.fromRGB(200,220,255))
        trail.Lifetime = 0.3
        trail.Parent = hrp

        -- loop de voo
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then
                conn:Disconnect()
                state.isFlying = false
                return
            end
            local elapsed = tick() - startTime
            local alpha = math.clamp(elapsed/duration,0,1)

            local eased = 0.5 - 0.5*math.cos(math.pi*alpha)
            local newPos = startPos:Lerp(target, eased)
            hrp.CFrame = CFrame.new(newPos, target)

            -- câmera acompanha
            camera.CameraType = Enum.CameraType.Scriptable
            camera.CFrame = hrp.CFrame * CFrame.new(0, 5, -15)

            -- efeito de velocidade (FOV dinâmico)
            camera.FieldOfView = startFOV + (20 * math.sin(alpha*math.pi))

            if alpha >= 1 then
                conn:Disconnect()
                state.isFlying = false
                camera.CameraType = Enum.CameraType.Custom
                camera.FieldOfView = startFOV
                hud.Text = ""
                trail:Destroy()
                notify("✅ Chegou ao destino!")
            end
        end)
    end)

    -- reaplicar UI
    player.CharacterAdded:Connect(function()
        gui.Parent = player:WaitForChild("PlayerGui")
    end)
end

-- inicializa
buildUI()
