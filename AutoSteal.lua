-- FlyBase Ultimate
-- Interface + Fly inteligente + Respawn opcional + Fixação 7s resistente a empurrões

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Estado global anti-reset (mantido)
getgenv().FlyBaseUltimate = getgenv().FlyBaseUltimate or {
    savedCFrame = nil,
    isFlying = false,
    uiBuilt = false,
    autoRespawn = true
}
local state = getgenv().FlyBaseUltimate

-- Utils (mantido)
local function getHRP(char)
    char = char or player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function getHum()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("Humanoid")
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

-- Curva (mantido)
local function easeInOut(t)
    return 0.5 - 0.5 * math.cos(math.pi * t)
end

-- NOVO: fixação robusta por N segundos usando AlignPosition/AlignOrientation
local function holdAtPosition(targetPos: Vector3, seconds: number)
    local hrp = getHRP()
    local hum = getHum()
    if not hrp or not hum then return end

    -- Congelar controles sem matar personagem
    local oldWS, oldJP, oldAR = hum.WalkSpeed, hum.JumpPower, hum.AutoRotate
    hum.WalkSpeed = 0
    hum.JumpPower = 0
    hum.AutoRotate = false

    -- Cria attachments/constraints fortes
    local att = Instance.new("Attachment")
    att.Name = "FlyBase_Att"
    att.Parent = hrp

    local ap = Instance.new("AlignPosition")
    ap.Name = "FlyBase_AlignPos"
    ap.Attachment0 = att
    ap.ApplyAtCenterOfMass = true
    ap.RigidityEnabled = true
    ap.MaxForce = 1e9
    ap.Responsiveness = 200
    ap.Parent = hrp
    ap.Position = targetPos

    local ao = Instance.new("AlignOrientation")
    ao.Name = "FlyBase_AlignOri"
    ao.Attachment0 = att
    ao.RigidityEnabled = true
    ao.MaxTorque = 1e9
    ao.Responsiveness = 200
    ao.Parent = hrp
    -- Mantém a orientação atual olhando para frente (opcional: olhar pro destino)
    ao.CFrame = hrp.CFrame - hrp.CFrame.Position

    -- Loop por 'seconds' segurando posição e anulando empurrões
    local done = false
    local t0 = tick()
    local hbConn
    hbConn = RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then
            done = true
            return
        end
        ap.Position = targetPos
        -- anula velocidades que o item tentar aplicar
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if tick() - t0 >= seconds then
            done = true
        end
    end)

    -- Espera terminar
    repeat task.wait() until done

    -- Cleanup e restaura controles
    if hbConn then hbConn:Disconnect() end
    if ao then ao:Destroy() end
    if ap then ap:Destroy() end
    if att then att:Destroy() end

    hum.WalkSpeed = oldWS
    hum.JumpPower = oldJP
    hum.AutoRotate = oldAR
end

-- Construção da UI (mantida)
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

        b.MouseEnter:Connect(function() b.BackgroundColor3 = hoverColor end)
        b.MouseLeave:Connect(function() b.BackgroundColor3 = baseColor end)

        b.Parent = frame
        return b
    end

    -- Botões principais (mantidos)
    local setBtn = makeBtn("➕ Set Position", Color3.fromRGB(70,120,70), Color3.fromRGB(90,160,90))
    local flyBtn = makeBtn("✈️ Fly to Base", Color3.fromRGB(70,70,120), Color3.fromRGB(100,100,160))
    local toggleBtn = makeBtn("🔄 Auto Respawn: ON", Color3.fromRGB(120,90,70), Color3.fromRGB(160,120,90))

    -- HUD (mantido)
    local status = Instance.new("TextLabel")
    status.Size = UDim2.fromOffset(220, 20)
    status.BackgroundTransparency = 1
    status.Text = "Base salva: nenhuma"
    status.Font = Enum.Font.Gotham
    status.TextSize = 14
    status.TextColor3 = Color3.fromRGB(200,220,255)
    status.Parent = frame

    -- Set (mantido)
    setBtn.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        state.savedCFrame = hrp.CFrame
        status.Text = "📍 Base salva ✔"
    end)

    -- Fly (mantido, só alterado o FINAL para usar holdAtPosition)
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

                -- >>> FIXAÇÃO ROBUSTA POR 7s (segura mesmo com brainrot)
                holdAtPosition(target, 7)
            end
        end)
    end)

    -- Toggle Auto Respawn (mantido)
    toggleBtn.MouseButton1Click:Connect(function()
        state.autoRespawn = not state.autoRespawn
        toggleBtn.Text = state.autoRespawn and "🔄 Auto Respawn: ON" or "🔄 Auto Respawn: OFF"
    end)

    -- Borda animada (mantido)
    RunService.RenderStepped:Connect(function()
        local t = tick()
        stroke.Color = Color3.fromHSV((t%6)/6, 0.6, 1)
    end)

    -- Anti-reset/respawn (mantido)
    player.CharacterAdded:Connect(function(char)
        gui.Parent = player:WaitForChild("PlayerGui")
        if state.autoRespawn and state.savedCFrame then
            task.defer(function()
                local hrp2 = char:WaitForChild("HumanoidRootPart")
                hrp2.CFrame = state.savedCFrame
            end)
        end
    end)
end

-- Início (mantido)
local function ensureUI() buildUI() end
ensureUI()
notify("FlyBase Ultimate carregado! ➕ Set / ✈️ Fly")
