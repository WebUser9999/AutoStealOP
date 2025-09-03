-- FlyBase Stealth+++ (by chatgpt)
-- • Voo híbrido: Humanoid:MoveTo() + AssemblyLinearVelocity (replicado) com waypoints adaptativos
-- • Anti-reset/anti-morte/anti-drop só durante o voo
-- • UI centralizada, draggable, lembra posição; "➕ Set Position" no MEIO
-- • Slots de base (1..3), ETA/Distância/Velocidade na UI, teclas de atalho
-- • Sobe automaticamente se encontrar obstáculo (raycast frontal)

-- =========================== SERVICES / SETUP ===========================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- =========================== CONFIG ===========================
local HOLD_SECONDS      = 5     -- tempo fixado no chão ao chegar
local POST_SPAWN_PIN    = 1.2
local BASE_SLOTS        = 3     -- número de slots de base (1..3)
local WAYPOINT_DIST     = 16    -- alvo médio entre waypoints
local MAX_SPEED         = 70    -- velocidade máx. (tuning anti-AC)
local MIN_SPEED         = 28    -- velocidade mín.
local ACCEL_FACTOR      = 0.18  -- suavização de velocidade
local OBST_CHECK_DIST   = 8     -- checagem frontal
local OBST_UP_STEP      = 6     -- sobe esse tanto quando tem obstáculo
local RIG_HANDS         = {"RightHand","LeftHand"} -- troque p/ R6: {"Right Arm","Left Arm"}

-- atalhos (mude se quiser)
local KEY_FLY           = Enum.KeyCode.F
local KEY_SET           = Enum.KeyCode.G
local KEY_TOGGLE_RESP   = Enum.KeyCode.R
local KEY_SLOT_1        = Enum.KeyCode.One
local KEY_SLOT_2        = Enum.KeyCode.Two
local KEY_SLOT_3        = Enum.KeyCode.Three

-- =========================== STATE ===========================
getgenv().FlyBaseUltimate = getgenv().FlyBaseUltimate or {
    savedCFrame = nil,     -- base ativa
    slots = {},            -- slots[1..3] = CFrame
    isFlying = false,
    uiBuilt = false,
    autoRespawn = true,
    uiPos = nil            -- lembra posição do frame
}
local state = getgenv().FlyBaseUltimate

local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title="FlyBase+++", Text=msg, Duration=2})
    end)
end

-- =========================== HELPERS ===========================
local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHRP(char) char = char or getChar(); return char:WaitForChild("HumanoidRootPart") end
local function getHumanoid(char) char = char or getChar(); return char:WaitForChild("Humanoid") end

local function groundAt(pos: Vector3)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {player.Character}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local hit = Workspace:Raycast(pos + Vector3.new(0,12,0), Vector3.new(0,-1000,0), rp)
    return hit and Vector3.new(pos.X, hit.Position.Y + 2, pos.Z) or pos
end

local function hardLockTo(targetPos: Vector3, seconds: number)
    local hrp = getHRP()
    if not hrp then return end
    local g = groundAt(targetPos)
    local t0 = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not hrp.Parent then if conn then conn:Disconnect() end return end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(g, g + hrp.CFrame.LookVector)
        if tick()-t0 >= seconds then if conn then conn:Disconnect() end end
    end)
end

local function dirTo(a: Vector3, b: Vector3)
    local v = (b - a)
    if v.Magnitude < 1e-3 then return Vector3.zero end
    return v.Unit
end

local function forwardObstacle(hrp: BasePart)
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {player.Character}
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    local origin = hrp.Position + Vector3.new(0, 2, 0)
    local dir = hrp.CFrame.LookVector * OBST_CHECK_DIST
    local hit = Workspace:Raycast(origin, dir, rp)
    return hit ~= nil
end

-- =========================== ANTI-RESET (voo) ===========================
local Anti = {active=false, conns={}}

local function hookReset()
    pcall(function()
        StarterGui:SetCore("ResetButtonCallback", function()
            notify("⛔ Reset bloqueado durante o voo")
            return
        end)
    end)
end
local function unhookReset() pcall(function() StarterGui:SetCore("ResetButtonCallback", true) end) end

local function setDrop(lock)
    local bp = player:FindFirstChildOfClass("Backpack")
    if bp then
        for _,obj in ipairs(bp:GetChildren()) do
            if obj:IsA("Tool") then pcall(function() obj.CanBeDropped = not lock and true or false end) end
        end
    end
    local char = player.Character
    if char then
        for _,obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then pcall(function() obj.CanBeDropped = not lock and true or false end) end
        end
    end
end

local function enableAnti()
    if Anti.active then return end
    Anti.active = true
    hookReset()
    setDrop(true)
    local hum = getHumanoid()
    hum.BreakJointsOnDeath = false
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
end

local function disableAnti()
    if not Anti.active then return end
    Anti.active = false
    unhookReset()
    setDrop(false)
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end
end

-- =========================== FLY (STEALTH+++) ===========================
local uiStatus -- forward decl. (label)
local function flyToBase()
    if state.isFlying or not state.savedCFrame then notify("⚠️ Define a base com ➕ Set Position"); return end
    state.isFlying = true
    enableAnti()

    local hrp = getHRP()
    local hum = getHumanoid()
    local target = groundAt(state.savedCFrame.Position)
    local start  = hrp.Position

    local totalDist = (target - start).Magnitude
    local wpCount   = math.max(1, math.ceil(totalDist / WAYPOINT_DIST))
    local iWp       = 1
    local wpTarget  = start:Lerp(target, iWp / wpCount)

    local lastPos   = hrp.Position
    local speedSmoothed = 0

    hum:MoveTo(wpTarget)

    local conn
    conn = RunService.Heartbeat:Connect(function(dt)
        if not hrp.Parent then conn:Disconnect() state.isFlying=false disableAnti() return end

        -- Se houver obstáculo à frente, sobe um pouco:
        if forwardObstacle(hrp) then
            wpTarget = wpTarget + Vector3.new(0, OBST_UP_STEP, 0)
            hum:MoveTo(wpTarget)
        end

        local toWp = (wpTarget - hrp.Position)
        local dist = toWp.Magnitude

        -- Indicadores (velocidade e ETA)
        local deltaDist = (hrp.Position - lastPos).Magnitude
        lastPos = hrp.Position
        local instSpeed = deltaDist / math.max(dt, 1e-3)
        speedSmoothed = speedSmoothed == 0 and instSpeed or (speedSmoothed*0.85 + instSpeed*0.15)

        local distRemain = (target - hrp.Position).Magnitude
        local eta = (speedSmoothed > 1) and (distRemain / speedSmoothed) or 0
        if uiStatus then
            uiStatus.Text = string.format("Dist: %.1f | Vel: %.1f | ETA: %.1fs", distRemain, speedSmoothed, eta)
        end

        if dist < 3 then
            iWp += 1
            if iWp > wpCount then
                conn:Disconnect()
                state.isFlying=false
                notify("✅ Chegou na base!")
                hardLockTo(target, HOLD_SECONDS)
                disableAnti()
                return
            end
            wpTarget = start:Lerp(target, iWp / wpCount)
            hum:MoveTo(wpTarget)
        end

        -- Velocity “natural”
        if dist > 1 then
            local dir = toWp.Unit
            local desiredSpeed = MIN_SPEED + (MAX_SPEED - MIN_SPEED) * (0.6 + 0.4*math.sin(tick()*2)) -- varia um pouco
            local desiredVel = dir * desiredSpeed
            hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(desiredVel, ACCEL_FACTOR)
        end
    end)
end

-- =========================== RESPawn PIN opcional ===========================
local function postSpawnPin(char)
    if not (state.autoRespawn and state.savedCFrame) then return end
    task.defer(function()
        local hrp = char:WaitForChild("HumanoidRootPart")
        local target = state.savedCFrame
        local g = groundAt(target.Position)
        hrp.CFrame = CFrame.new(g)
        hardLockTo(g, POST_SPAWN_PIN)
    end)
end

-- =========================== UI (CENTRAL, DRAGGABLE, REMEMBER) ===========================
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt = true

    local gui = Instance.new("ScreenGui")
    gui.Name = "FlyBaseUI"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromOffset(300, 320)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = state.uiPos or UDim2.fromScale(0.5, 0.5) -- lembra posição
    frame.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(120, 140, 255)
    stroke.Parent = frame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Parent = frame

    -- Título (draggable area)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.fromOffset(260, 26)
    title.BackgroundTransparency = 1
    title.Text = "🚀 FlyBase Stealth+++"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Parent = frame

    -- Dragging
    do
        local dragging = false
        local dragStart, startPos
        title.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = i.Position
                startPos = frame.Position
                i.Changed:Connect(function()
                    if i.UserInputState == Enum.UserInputState.End then dragging = false end
                end)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = i.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                state.uiPos = frame.Position
            end
        end)
    end

    -- Botões: Fly (cima) | Set Position (MEIO) | Auto Respawn (baixo)
    local function makeBtn(txt, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(240, 44)
        b.Text = txt
        b.Font = Enum.Font.GothamBold
        b.TextSize = 16
        b.TextColor3 = Color3.new(1,1,1)
        b.BackgroundColor3 = color
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
        b.Parent = frame
        return b
    end

    local flyBtn    = makeBtn("✈️ Fly to Base  (F)", Color3.fromRGB(70, 70, 120))
    local setBtn    = makeBtn("➕ Set Position (G)", Color3.fromRGB(70, 120, 70))  -- <<< NO MEIO
    local respBtn   = makeBtn("🔄 Auto Respawn: ON (R)", Color3.fromRGB(120, 90, 70))

    -- Linha de status
    uiStatus = Instance.new("TextLabel")
    uiStatus.Size = UDim2.fromOffset(260, 20)
    uiStatus.BackgroundTransparency = 1
    uiStatus.Text = "Base salva: nenhuma"
    uiStatus.Font = Enum.Font.Gotham
    uiStatus.TextSize = 14
    uiStatus.TextColor3 = Color3.fromRGB(200, 220, 255)
    uiStatus.Parent = frame

    -- Slots de base
    local slotRow = Instance.new("Frame")
    slotRow.Size = UDim2.fromOffset(260, 34)
    slotRow.BackgroundTransparency = 1
    slotRow.Parent = frame
    local hlist = Instance.new("UIListLayout", slotRow)
    hlist.FillDirection = Enum.FillDirection.Horizontal
    hlist.Padding = UDim.new(0, 8)
    hlist.HorizontalAlignment = Enum.HorizontalAlignment.Center
    hlist.VerticalAlignment = Enum.VerticalAlignment.Center

    local function slotButton(index, color)
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(72, 32)
        b.Text = "Slot "..index
        b.Font = Enum.Font.GothamBold
        b.TextSize = 14
        b.TextColor3 = Color3.new(1,1,1)
        b.BackgroundColor3 = color
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        b.Parent = slotRow
        return b
    end
    local slot1 = slotButton(1, Color3.fromRGB(52, 98, 160))
    local slot2 = slotButton(2, Color3.fromRGB(160, 98, 52))
    local slot3 = slotButton(3, Color3.fromRGB(98, 160, 52))

    -- Ações
    setBtn.MouseButton1Click:Connect(function()
        local hrp = getHRP()
        state.savedCFrame = hrp.CFrame
        uiStatus.Text = "📍 Base salva ✔"
        notify("📍 Base salva ✔")
    end)

    flyBtn.MouseButton1Click:Connect(function()
        if state.isFlying then return end
        if not state.savedCFrame then notify("⚠️ Define a base com ➕ Set Position."); return end
        flyToBase()
    end)

    respBtn.MouseButton1Click:Connect(function()
        state.autoRespawn = not state.autoRespawn
        respBtn.Text = state.autoRespawn and "🔄 Auto Respawn: ON (R)" or "🔄 Auto Respawn: OFF (R)"
        notify(state.autoRespawn and "Auto Respawn ON" or "Auto Respawn OFF")
    end)

    -- Slots: clique curto = setar base ativa; SHIFT+clique = salvar slot
    local function useSlot(i)
        if state.slots[i] then
            state.savedCFrame = state.slots[i]
            uiStatus.Text = ("🎯 Base ativa: Slot %d"):format(i)
            notify(("🎯 Base ativa: Slot %d"):format(i))
        else
            notify(("⚠️ Slot %d vazio. SHIFT+Clique para salvar."):format(i))
        end
    end
    local function saveSlot(i)
        local hrp = getHRP()
        state.slots[i] = hrp.CFrame
        notify(("💾 Slot %d salvo."):format(i))
    end

    local function wireSlot(btn, idx)
        btn.MouseButton1Click:Connect(function()
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                saveSlot(idx)
            else
                useSlot(idx)
            end
        end)
    end
    wireSlot(slot1,1); wireSlot(slot2,2); wireSlot(slot3,3)

    -- atalhos
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == KEY_SET then
            setBtn:Activate()
        elseif input.KeyCode == KEY_FLY then
            flyBtn:Activate()
        elseif input.KeyCode == KEY_TOGGLE_RESP then
            respBtn:Activate()
        elseif input.KeyCode == KEY_SLOT_1 then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                saveSlot(1) else useSlot(1) end
        elseif input.KeyCode == KEY_SLOT_2 then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                saveSlot(2) else useSlot(2) end
        elseif input.KeyCode == KEY_SLOT_3 then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                saveSlot(3) else useSlot(3) end
        end
    end)

    -- efeito visual
    RunService.RenderStepped:Connect(function()
        local t = tick()
        stroke.Color = Color3.fromHSV((t%6)/6, 0.6, 1)
    end)

    -- respawn pin
    player.CharacterAdded:Connect(function(char)
        gui.Parent = player:WaitForChild("PlayerGui")
        if state.autoRespawn then postSpawnPin(char) end
    end)
end

-- =========================== BOOT ===========================
buildUI()
notify("FlyBase Stealth+++ pronto — UI central, Set Position no meio (G), Fly (F), Slots (1-2-3)")
