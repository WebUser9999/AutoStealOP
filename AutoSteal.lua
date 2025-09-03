-- FlyBase Ultimate
-- Interface + Fly inteligente + Respawn opcional + Fixação 7s no destino

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Estado global anti-reset
getgenv().FlyBaseUltimate = getgenv().FlyBaseUltimate or {
    savedCFrame = nil,
    isFlying = false,
    uiBuilt = false,
    autoRespawn = true
}
local state = getgenv().FlyBaseUltimate

-- Funções utilitárias
local function getHRP(char)
    char = char or player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function notify(msg)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "FlyBase",
            Text = msg,
            Duration = 2
        })
    end)
end

-- Easing para aceleração/desaceleração
local function easeInOut(t)
    return 0.5 - 0.5 * math.cos(math.pi * t)
end

-- Construção da UI
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt = true

    local gui = Instance.new("ScreenGui")
    gui.Name = "FlyBaseUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(260, 250)
    frame.Position = UDim2.fromScale(0.75, 0.6)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.Parent = gui
    Instance.new("UICorner", frame)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(120, 140, 255)

    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(200, 30)
    title.BackgroundTransparency = 1
    title.Text = "🚀 FlyBase Ultimate"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Parent = frame

    local function makeBtn(txt, baseColor, hoverColor)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(200, 44)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 16
        b.TextColor3 = Color3.fromRGB(255,255,255)
        b.BackgroundColor3 = baseColor
        Instance.new("UICorner", b)

        b.MouseEnter:Connect(function()
            b.BackgroundColor3 = hoverColor
        end)
        b.MouseLeave:Connect(function()
            b.BackgroundColor3 = baseColor
        end)

        b.Parent = frame
        return b
    end

    -- Botões principais
    local setBtn = makeBtn("➕ Set Position", Color3.fromRGB(70,120,70), Color3.fromRGB(90,160,90))
    local flyBtn = makeBtn("✈️ Fly to Base", Color3.fromRGB(70,70,120), Color3.fromRGB(100,100,160))
    local toggleBtn = makeBtn("🔄 Auto Respawn: ON", Color3.fromRGB(120,90,70), Color3.fromRGB(160,120,90))

    -- HUD status
    local status = Instance.new("TextLabel")
    status.Size = UDim2.fromOffset(220, 20)
    status.BackgroundTransparency = 1
    status.Text = "Base salva: nenhuma"
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.TextColor3 = Color3.fromRGB(200,220,255)
    status.Parent = frame

    -- Lógica Set
    setBtn.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        state.savedCFrame = hrp.CFrame
        status.Text = "📍 Base salva ✔"
    end)

    -- Lógica Fly
    flyBtn.MouseButton1Click:Connect(function()
        if state.isFlying or not state.savedCFrame then return end
        state.isFlying = true

        local hrp = getHRP()
        local startPos = hrp.Position
        local target = state.savedCFrame.Position
        local distance = (startPos - target).Magnitude
        local duration = math.clamp(distance/60, 1, 6)

        local startTime = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then
                conn:Disconnect()
                state.isFlying = false
                return
            end

            local elapsed = tick() - startTime
            local alpha = math.clamp(elapsed/duration, 0, 1)
            local eased = easeInOut(alpha)

            local newPos = startPos:Lerp(target, eased)
            hrp.CFrame = CFrame.new(newPos, target)

            local remain = (target - newPos).Magnitude
            local speed = (distance/duration) * math.sin(alpha*math.pi)
            status.Text = string.format("Distância: %.1f | Vel: %.1f", remain, speed)

            if alpha >= 1 then
                conn:Disconnect()
                state.isFlying = false
                status.Text = "✅ Chegou ao destino!"

                -- fixa no destino por 7 segundos
                hrp.CFrame = CFrame.new(target)
                local anchor = Instance.new("BodyPosition")
                anchor.Position = target
                anchor.MaxForce = Vector3.new(1e5,1e5,1e5)
                anchor.Parent = hrp

                task.delay(7, function()
                    if anchor and anchor.Parent then
                        anchor:Destroy()
                    end
                end)
            end
        end)
    end)

    -- Toggle Auto Respawn
    toggleBtn.MouseButton1Click:Connect(function()
        state.autoRespawn = not state.autoRespawn
        toggleBtn.Text = state.autoRespawn and "🔄 Auto Respawn: ON" or "🔄 Auto Respawn: OFF"
    end)

    -- Animação da borda
    RunService.RenderStepped:Connect(function()
        local t = tick()
        stroke.Color = Color3.fromHSV((t%6)/6, 0.6, 1)
    end)

    -- Respawn handler
    player.CharacterAdded:Connect(function(char)
        gui.Parent = player:WaitForChild("PlayerGui")
        if state.autoRespawn and state.savedCFrame then
            task.defer(function()
                local hrp = char:WaitForChild("HumanoidRootPart")
                hrp.CFrame = state.savedCFrame
            end)
        end
    end)
end

-- Iniciar
buildUI()
notify("FlyBase Ultimate carregado! ➕ Set / ✈️ Fly")
