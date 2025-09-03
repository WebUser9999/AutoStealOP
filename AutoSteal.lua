-- FlyBase Turbo
-- UI com vários botões e funções avançadas

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Estado global (anti-reset)
getgenv().FlyBaseTurbo = getgenv().FlyBaseTurbo or {
    bases = {},
    currentBase = nil,
    flying = false
}
local state = getgenv().FlyBaseTurbo
local flyConn

-- Funções utilitárias
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

local function notify(msg)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "FlyBase Turbo",
            Text = msg,
            Duration = 3
        })
    end)
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "FlyBaseTurboUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(240, 360)
frame.Position = UDim2.fromScale(0.02, 0.5)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
frame.Parent = gui
Instance.new("UICorner", frame)

local layout = Instance.new("UIListLayout", frame)
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Top

local function makeBtn(txt, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(220, 36)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.TextColor3 = Color3.new(1,1,1)
    b.BackgroundColor3 = color or Color3.fromRGB(50, 50, 70)
    Instance.new("UICorner", b)
    b.Parent = frame
    return b
end

-- Criando botões
local setBtn     = makeBtn("➕ Set Base", Color3.fromRGB(70,120,70))
local switchBtn  = makeBtn("🔄 Switch Base", Color3.fromRGB(90,90,140))
local flyBtn     = makeBtn("✈️ Fly to Base", Color3.fromRGB(70,70,120))
local deleteBtn  = makeBtn("❌ Delete Base", Color3.fromRGB(140,70,70))
local listBtn    = makeBtn("📜 List Bases", Color3.fromRGB(100,100,100))
local cancelBtn  = makeBtn("⏹ Cancel Fly", Color3.fromRGB(160,90,50))
local saveBtn    = makeBtn("💾 Save Session", Color3.fromRGB(90,140,90))
local clearBtn   = makeBtn("♻️ Clear All", Color3.fromRGB(140,90,140))

-- Lógica dos botões
setBtn.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    local name = "Base"..tostring(#state.bases+1)
    state.bases[name] = hrp.Position
    state.currentBase = name
    notify("Base salva: "..name)
end)

switchBtn.MouseButton1Click:Connect(function()
    local keys = {}
    for k in pairs(state.bases) do table.insert(keys, k) end
    table.sort(keys)
    if #keys == 0 then
        notify("Nenhuma base salva.")
        return
    end
    local idx = table.find(keys, state.currentBase) or 0
    idx = (idx % #keys) + 1
    state.currentBase = keys[idx]
    notify("Base atual: "..state.currentBase)
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
    local dist = (target-startPos).Magnitude
    local duration = math.clamp(dist/60, 0.5, 6)

    local startTime = tick()
    flyConn = RunService.RenderStepped:Connect(function()
        if not hrp or not hrp.Parent then
            flyConn:Disconnect()
            state.flying = false
            return
        end
        local alpha = math.clamp((tick()-startTime)/duration,0,1)
        local newPos = startPos:Lerp(target, alpha)
        hrp.CFrame = CFrame.new(newPos, target)
        if alpha>=1 then
            flyConn:Disconnect()
            hum.PlatformStand = false
            state.flying = false
            notify("Chegou em "..state.currentBase.."!")
        end
    end)
end)

deleteBtn.MouseButton1Click:Connect(function()
    if state.currentBase and state.bases[state.currentBase] then
        state.bases[state.currentBase] = nil
        notify("Base deletada.")
        state.currentBase = nil
    else
        notify("Nenhuma base para deletar.")
    end
end)

listBtn.MouseButton1Click:Connect(function()
    if next(state.bases) == nil then
        notify("Nenhuma base salva.")
        return
    end
    for name,pos in pairs(state.bases) do
        print("📍 "..name.." -> "..tostring(pos))
    end
    notify("Bases listadas no Output/Chat.")
end)

cancelBtn.MouseButton1Click:Connect(function()
    if flyConn then
        flyConn:Disconnect()
        state.flying = false
        local _, hum = getHRP()
        hum.PlatformStand = false
        notify("Voo cancelado!")
    end
end)

saveBtn.MouseButton1Click:Connect(function()
    getgenv().FlyBaseTurbo = state
    notify("Sessão salva no getgenv()")
end)

clearBtn.MouseButton1Click:Connect(function()
    state.bases = {}
    state.currentBase = nil
    notify("Todas as bases foram limpas!")
end)

-- UI sobrevive ao reset
player.CharacterAdded:Connect(function()
    gui.Parent = player:WaitForChild("PlayerGui")
end)
