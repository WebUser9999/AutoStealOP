-- FlyBase UI Simples e Estável
-- 2 botões: Set / Fly, sem mexer na câmera (sem tela preta)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- estado global
getgenv().FlyBaseSafe = getgenv().FlyBaseSafe or {
    savedCFrame = nil,
    isFlying = false,
    uiBuilt = false
}
local state = getgenv().FlyBaseSafe

-- pegar HRP
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

-- criar UI
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt = true

    local gui = Instance.new("ScreenGui")
    gui.Name = "FlyBaseUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(220, 160)
    frame.Position = UDim2.fromScale(0.75, 0.65)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.Parent = gui
    Instance.new("UICorner", frame)

    local layout = Instance.new("UIListLayout", frame)
    layout.Padding = UDim.new(0, 12)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center

    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(200, 30)
    title.BackgroundTransparency = 1
    title.Text = "🚀 FlyBase"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255,255,255)
    title.Parent = frame

    local function makeBtn(txt, baseColor, hoverColor)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(180, 44)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 16
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
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

    local setBtn = makeBtn("➕ Set Position", Color3.fromRGB(70,120,70), Color3.fromRGB(90,160,90))
    local flyBtn = makeBtn("✈️ Fly to Base", Color3.fromRGB(70,70,120), Color3.fromRGB(100,100,160))

    local status = Instance.new("TextLabel")
    status.Size = UDim2.fromOffset(200, 20)
    status.BackgroundTransparency = 1
    status.Text = "Base salva: nenhuma"
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.TextColor3 = Color3.fromRGB(200,220,255)
    status.Parent = frame

    -- salvar posição
    setBtn.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        state.savedCFrame = hrp.CFrame
        status.Text = "📍 Base salva!"
    end)

    -- voar até posição salva
    flyBtn.MouseButton1Click:Connect(function()
        if state.isFlying or not state.savedCFrame then return end
        state.isFlying = true

        local hrp = getHRP()
        local target = state.savedCFrame.Position

        local conn
        conn = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then
                conn:Disconnect()
                state.isFlying = false
                return
            end

            local pos = hrp.Position
            local dir = (target - pos)
            local dist = dir.Magnitude

            if dist < 2 then
                hrp.CFrame = CFrame.new(target)
                conn:Disconnect()
                state.isFlying = false
                status.Text = "✅ Chegou ao destino!"
            else
                hrp.CFrame = CFrame.new(pos + dir.Unit * math.min(3, dist), target)
                status.Text = string.format("Distância: %.1f", dist)
            end
        end)
    end)

    -- reaplicar GUI após reset
    player.CharacterAdded:Connect(function()
        gui.Parent = player:WaitForChild("PlayerGui")
    end)
end

buildUI()
