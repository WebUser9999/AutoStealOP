-- FlyBase Overdrive
-- Sistema intenso com múltiplas bases, UI dinâmica e voo suave

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

-- ==============================
-- GLOBAL STATE (anti-reset total)
-- ==============================
getgenv().FlyBaseOverdrive = getgenv().FlyBaseOverdrive or {
    bases = {},          -- {["Casa"] = Vector3, ["Torre"] = Vector3}
    currentBase = nil,
    flying = false
}

local state = getgenv().FlyBaseOverdrive

-- ==============================
-- UTIL
-- ==============================
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

local function notify(msg)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "FlyBase Overdrive",
            Text = msg,
            Duration = 3
        })
    end)
end

-- easing custom (ease in/out)
local function easeInOut(t)
    return 0.5 - 0.5 * math.cos(math.pi * t)
end

-- ==============================
-- UI BASE
-- ==============================
local gui = Instance.new("ScreenGui")
gui.Name = "FlyBaseOverdriveUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(260, 300)
frame.Position = UDim2.fromScale(0.02, 0.6)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Parent = gui

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 12)

local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(90, 120, 255)

-- título
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,30)
title.BackgroundTransparency = 1
title.Text = "🚀 FlyBase Overdrive"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255,255,255)

-- painel de status
local status = Instance.new("TextLabel", frame)
status.Size = UDim2.new(1,0,0,25)
status.Position = UDim2.new(0,0,0,32)
status.BackgroundTransparency = 1
status.Text = "Base: (nenhuma) | Dist: -"
status.Font = Enum.Font.Gotham
status.TextSize = 14
status.TextColor3 = Color3.fromRGB(200,220,255)

-- container scroll
local scroll = Instance.new("ScrollingFrame", frame)
scroll.Size = UDim2.new(1,0,1,-65)
scroll.Position = UDim2.new(0,0,0,65)
scroll.CanvasSize = UDim2.new(0,0,0,0)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 6

local listLayout = Instance.new("UIListLayout", scroll)
listLayout.Padding = UDim.new(0,4)

-- botão util
local function makeBtn(text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(240,30)
    b.Text = text
    b.Font = Enum.Font.GothamSemibold
    b.TextSize = 14
    b.TextColor3 = Color3.new(1,1,1)
    b.BackgroundColor3 = color or Color3.fromRGB(50,50,70)
    Instance.new("UICorner", b)
    return b
end

-- ==============================
-- UI CONTROLS
-- ==============================
local function refreshList()
    scroll:ClearAllChildren()
    local lay = Instance.new("UIListLayout", scroll)
    lay.Padding = UDim.new(0,4)

    for name,pos in pairs(state.bases) do
        local b = makeBtn("📍 "..name)
        b.Parent = scroll
        b.MouseButton1Click:Connect(function()
            state.currentBase = name
            notify("Selecionou base: "..name)
        end)
    end

    scroll.CanvasSize = UDim2.new(0,0,0,#state.bases*34)
end

-- botões principais
local saveBtn = makeBtn("➕ Salvar Base", Color3.fromRGB(70,120,70))
saveBtn.Parent = frame
saveBtn.Position = UDim2.new(0,10,1,-35)

local flyBtn = makeBtn("✈️ Voar", Color3.fromRGB(70,70,120))
flyBtn.Parent = frame
flyBtn.Position = UDim2.new(0,10,1,-70)

saveBtn.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    notify("Digite o nome da base no chat!")
    -- input via chat
    local conn
    conn = player.Chatted:Connect(function(msg)
        conn:Disconnect()
        local name = msg
        state.bases[name] = hrp.Position
        state.currentBase = name
        notify("Base salva: "..name)
        refreshList()
    end)
end)

flyBtn.MouseButton1Click:Connect(function()
    if state.flying then return end
    if not state.currentBase or not state.bases[state.currentBase] then
        notify("Nenhuma base selecionada.")
        return
    end

    local hrp, hum = getHRP()
    local target = state.bases[state.currentBase]
    state.flying = true

    hum.PlatformStand = true
    local startPos = hrp.Position
    local dist = (target - startPos).Magnitude
    local duration = math.clamp(dist/70,0.5,5)

    local startTime = tick()
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not hrp or not hrp.Parent then
            conn:Disconnect()
            state.flying = false
            return
        end
        local elapsed = tick()-startTime
        local alpha = math.clamp(elapsed/duration,0,1)
        local eased = easeInOut(alpha)
        local newPos = startPos:Lerp(target,eased)
        hrp.CFrame = CFrame.new(newPos, target)

        local remain = (target-hrp.Position).Magnitude
        status.Text = "Base: "..state.currentBase.." | Dist: "..math.floor(remain)

        if alpha>=1 then
            conn:Disconnect()
            hum.PlatformStand = false
            state.flying = false
            notify("Chegou em "..state.currentBase.."!")
        end
    end)
end)

-- animação borda
RunService.RenderStepped:Connect(function()
    stroke.Color = Color3.fromHSV((tick()%5)/5,0.6,1)
end)

-- manter UI após reset
player.CharacterAdded:Connect(function()
    gui.Parent = player:WaitForChild("PlayerGui")
    notify("Respawn detectado - bases ainda salvas")
end)

-- inicializar
refreshList()

