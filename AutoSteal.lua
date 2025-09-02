-- FlyBase Anti-Reset Hardcore
-- usa BodyVelocity/BodyGyro em vez de Tween (não quebra no reset)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- memória global
getgenv().FlyBaseHardcore = getgenv().FlyBaseHardcore or {
    bases = {}, -- {["Base1"] = Vector3, ...}
    currentBase = nil
}

local bases = getgenv().FlyBaseHardcore.bases
local currentBase = getgenv().FlyBaseHardcore.currentBase
local isFlying = false

-- função utilitária
local function getHRP()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

-- notificação simples
local function notify(msg)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "FlyBase HC",
            Text = msg,
            Duration = 2
        })
    end)
end

-- criar UI simples
local gui = Instance.new("ScreenGui")
gui.Name = "FlyBaseHC_UI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(200, 120)
frame.Position = UDim2.fromScale(0.02, 0.7)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.Parent = gui
Instance.new("UICorner", frame)

local list = Instance.new("UIListLayout", frame)
list.Padding = UDim.new(0, 6)
list.VerticalAlignment = Enum.VerticalAlignment.Top
list.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function makeButton(txt)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(180, 32)
    b.Text = txt
    b.Font = Enum.Font.GothamBold
    b.TextColor3 = Color3.new(1,1,1)
    b.BackgroundColor3 = Color3.fromRGB(50,50,80)
    Instance.new("UICorner", b)
    b.Parent = frame
    return b
end

local setBtn = makeButton("➕ Set Base")
local flyBtn = makeButton("✈️ Fly to Base")
local switchBtn = makeButton("🔄 Switch Base")

-- eventos
setBtn.MouseButton1Click:Connect(function()
    local hrp = getHRP()
    if not hrp then return end
    local name = "Base"..tostring(#bases+1)
    bases[name] = hrp.Position
    getgenv().FlyBaseHardcore.currentBase = name
    currentBase = name
    notify("Base salva: "..name)
end)

switchBtn.MouseButton1Click:Connect(function()
    if next(bases) == nil then
        notify("Nenhuma base salva.")
        return
    end
    -- troca ciclicamente
    local keys = {}
    for k in pairs(bases) do table.insert(keys,k) end
    table.sort(keys)
    local idx = table.find(keys, currentBase) or 0
    idx = (idx % #keys) + 1
    currentBase = keys[idx]
    getgenv().FlyBaseHardcore.currentBase = currentBase
    notify("Base atual: "..currentBase)
end)

flyBtn.MouseButton1Click:Connect(function()
    if isFlying then return end
    if not currentBase or not bases[currentBase] then
        notify("Nenhuma base selecionada.")
        return
    end

    local hrp, humanoid = getHRP()
    local target = bases[currentBase]

    isFlying = true

    -- cria movers no HRP
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    bv.Velocity = Vector3.zero
    bv.Parent = hrp

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    bg.CFrame = hrp.CFrame
    bg.Parent = hrp

    -- loop até chegar
    local reached = false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then
            conn:Disconnect()
            return
        end

        local dir = (target - hrp.Position)
        local dist = dir.Magnitude

        if dist < 5 then
            bv.Velocity = Vector3.zero
            reached = true
            conn:Disconnect()
        else
            bv.Velocity = dir.Unit * 80 -- velocidade constante
            bg.CFrame = CFrame.new(hrp.Position, target)
        end
    end)

    repeat task.wait() until reached

    bv:Destroy()
    bg:Destroy()
    isFlying = false
    notify("Chegou em "..currentBase.."!")
end)

-- garantir UI após reset
player.CharacterAdded:Connect(function()
    gui.Parent = player:WaitForChild("PlayerGui")
end)
