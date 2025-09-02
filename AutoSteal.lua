-- FlyBase Ultra Anti-Reset
-- Multi-bases, interface avançada, memória global

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ==============================
-- GLOBAL (não some no reset/reexecução)
-- ==============================
getgenv().FlyBaseData = getgenv().FlyBaseData or {
    savedBases = {}, -- { ["Base1"] = CFrame, ... }
    currentBase = nil,
}

local savedBases = getgenv().FlyBaseData.savedBases
local currentBase = getgenv().FlyBaseData.currentBase
local isFlying = false

-- Função utilitária
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

-- ==============================
-- INTERFACE
-- ==============================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyBaseUltraUI"
screenGui.ResetOnSpawn = false -- anti-reset
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.AnchorPoint = Vector2.new(0, 0)
mainFrame.Position = UDim2.fromScale(0.02, 0.7)
mainFrame.Size = UDim2.fromOffset(280, 220)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(90, 120, 255)
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Text = "🚀 FlyBase ULTRA"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 30)
title.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = mainFrame

-- botão utilitário
local function makeButton(text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.fromOffset(240, 36)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(240, 240, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn

    local s = Instance.new("UIStroke")
    s.Thickness = 1.4
    s.Color = Color3.fromRGB(90, 100, 255)
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = btn

    return btn
end

-- botões
local setBtn = makeButton("➕ Salvar Base")
setBtn.Parent = mainFrame

local flyBtn = makeButton("✈️ Voar até Base Selecionada")
flyBtn.Parent = mainFrame

-- dropdown
local dropdown = Instance.new("TextLabel")
dropdown.Text = currentBase and ("Base atual: " .. currentBase) or "Base atual: (nenhuma)"
dropdown.Font = Enum.Font.Gotham
dropdown.TextSize = 14
dropdown.TextColor3 = Color3.fromRGB(200, 220, 255)
dropdown.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
dropdown.Size = UDim2.fromOffset(240, 36)
dropdown.Parent = mainFrame

local cornerDrop = Instance.new("UICorner")
cornerDrop.CornerRadius = UDim.new(0, 8)
cornerDrop.Parent = dropdown

-- lista suspensa
local baseListFrame = Instance.new("Frame")
baseListFrame.Size = UDim2.fromOffset(240, 100)
baseListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
baseListFrame.Visible = false
baseListFrame.Parent = mainFrame

local cornerList = Instance.new("UICorner")
cornerList.CornerRadius = UDim.new(0, 8)
cornerList.Parent = baseListFrame

local listLayout2 = Instance.new("UIListLayout")
listLayout2.Padding = UDim.new(0, 4)
listLayout2.Parent = baseListFrame

-- ==============================
-- FUNÇÕES
-- ==============================
local function notify(msg)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "FlyBase ULTRA",
            Text = msg,
            Duration = 2
        })
    end)
end

local function updateDropdown()
    baseListFrame:ClearAllChildren()
    local l = Instance.new("UIListLayout")
    l.Padding = UDim.new(0, 4)
    l.Parent = baseListFrame

    for name, cf in pairs(savedBases) do
        local b = makeButton("📍 " .. name)
        b.Size = UDim2.fromOffset(220, 30)
        b.Parent = baseListFrame

        b.Activated:Connect(function()
            currentBase = name
            getgenv().FlyBaseData.currentBase = name
            dropdown.Text = "Base atual: " .. name
            baseListFrame.Visible = false
            notify("Base selecionada: " .. name)
        end)
    end
end

-- ==============================
-- EVENTOS
-- ==============================
setBtn.Activated:Connect(function()
    local hrp = getHRP()
    if not hrp then return end

    local baseName = "Base" .. tostring(#savedBases + 1)
    savedBases[baseName] = hrp.CFrame
    currentBase = baseName
    getgenv().FlyBaseData.currentBase = baseName
    dropdown.Text = "Base atual: " .. baseName
    updateDropdown()
    notify("Base salva como " .. baseName)
end)

flyBtn.Activated:Connect(function()
    if isFlying then return end
    if not currentBase or not savedBases[currentBase] then
        notify("Nenhuma base selecionada.")
        return
    end

    local hrp = getHRP()
    if not hrp then return end

    local target = savedBases[currentBase]
    isFlying = true

    -- zera movimento
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    -- tween
    local distance = (hrp.Position - target.Position).Magnitude
    local duration = math.clamp(distance / 70, 0.5, 4)

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(hrp, tweenInfo, { CFrame = target })

    tween:Play()
    tween.Completed:Wait()

    isFlying = false
    notify("Chegou em " .. currentBase .. "!")
end)

dropdown.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        baseListFrame.Visible = not baseListFrame.Visible
    end
end)

-- manter UI viva após respawn
player.CharacterAdded:Connect(function()
    screenGui.Parent = player:WaitForChild("PlayerGui")
    notify("Respawn detectado. Bases continuam salvas.")
end)

-- animação da borda
RunService.RenderStepped:Connect(function()
    local t = tick()
    stroke.Color = Color3.fromHSV((t % 5) / 5, 0.6, 1)
end)

-- inicializar lista
updateDropdown()
