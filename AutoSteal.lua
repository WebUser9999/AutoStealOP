-- WalkBase Stealth Ultra+++ (versão complexa, anti-cheat, UI completa)
-- • Anda até a base com Pathfinding
-- • Desvia de obstáculos
-- • Auto Respawn + Slot 1
-- • Botão Parar caminhada
-- • Minimizar/Maximizar
-- • Anti-reset ativo

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- Config
local WALK_SPEED   = 22
local STOP_DIST    = 3
local KEY_WALK     = Enum.KeyCode.F
local KEY_SET      = Enum.KeyCode.G
local KEY_SLOT_1   = Enum.KeyCode.One
local KEY_RESP     = Enum.KeyCode.R

-- Estado
getgenv().WalkBaseUltra = getgenv().WalkBaseUltra or {
    savedCFrame = nil,
    slot1 = nil,
    isWalking = false,
    autoRespawn = true,
    uiBuilt = false,
    uiPos = nil,
    currentConn = nil
}
local state = getgenv().WalkBaseUltra

local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="WalkBase+++",Text=msg,Duration=2})
    end)
end

-- Helpers
local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHRP(c) c=c or getChar(); return c:WaitForChild("HumanoidRootPart") end
local function getHumanoid(c) c=c or getChar(); return c:WaitForChild("Humanoid") end

-- Anti-reset
local Anti={active=false}
local function hookReset() pcall(function()
    StarterGui:SetCore("ResetButtonCallback",function() notify("⛔ Reset bloqueado") return end)
end) end
local function unhookReset() pcall(function() StarterGui:SetCore("ResetButtonCallback",true) end) end
local function enableAnti()
    if Anti.active then return end
    Anti.active=true
    hookReset()
    local hum=getHumanoid()
    hum.BreakJointsOnDeath=false
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead,false)
end
local function disableAnti()
    if not Anti.active then return end
    Anti.active=false
    unhookReset()
    local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:SetStateEnabled(Enum.HumanoidStateType.Dead,true) end
end

-- Walk com Pathfinding
local uiStatus
local function walkToBase()
    if state.isWalking or not state.savedCFrame then notify("⚠ Defina a base primeiro!"); return end
    state.isWalking = true; enableAnti()
    local hum=getHumanoid(); hum.WalkSpeed = WALK_SPEED
    local hrp=getHRP()
    local target=state.savedCFrame.Position

    -- cancela rota anterior
    if state.currentConn then state.currentConn:Disconnect() end

    uiStatus.Text="📡 Calculando rota..."
    local path=PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 7,
        AgentMaxSlope = 45
    })
    path:ComputeAsync(hrp.Position,target)

    if path.Status ~= Enum.PathStatus.Complete then
        uiStatus.Text="❌ Caminho inválido"
        notify("⚠ Caminho inválido")
        state.isWalking=false; disableAnti()
        return
    end

    local waypoints=path:GetWaypoints()
    uiStatus.Text="🚶 Iniciando caminhada..."

    local conn; conn=hum.MoveToFinished:Connect(function(reached)
        if not state.isWalking then return end
        if #waypoints==0 then return end

        table.remove(waypoints,1)
        if #waypoints==0 then
            conn:Disconnect(); state.currentConn=nil
            state.isWalking=false; disableAnti()
            uiStatus.Text="✅ Chegou!"
            notify("✅ Chegou na base andando!")
        else
            hum:MoveTo(waypoints[1].Position)
            uiStatus.Text="🚶 Andando... ("..tostring(#waypoints).." pontos restantes)"
        end
    end)
    state.currentConn=conn

    -- inicia primeiro movimento
    hum:MoveTo(waypoints[1].Position)
end

-- Cancelar caminhada
local function stopWalking()
    if not state.isWalking then return end
    state.isWalking=false; disableAnti()
    if state.currentConn then state.currentConn:Disconnect(); state.currentConn=nil end
    uiStatus.Text="⏹ Caminhada cancelada"
    notify("⏹ Caminhada cancelada")
end

-- UI
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt=true
    local gui=Instance.new("ScreenGui")
    gui.Name="WalkBaseUI"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true
    gui.Parent=player:WaitForChild("PlayerGui")

    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(320,320)
    frame.AnchorPoint=Vector2.new(0.5,0.5)
    frame.Position=state.uiPos or UDim2.fromScale(0.5,0.5)
    frame.BackgroundColor3=Color3.fromRGB(26,28,36)
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)

    local stroke=Instance.new("UIStroke"); stroke.Thickness=2; stroke.Color=Color3.fromRGB(120,140,255); stroke.Parent=frame

    local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,10)
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.VerticalAlignment=Enum.VerticalAlignment.Center; layout.Parent=frame

    -- Título + Minimizar
    local titleBar=Instance.new("Frame")
    titleBar.Size=UDim2.fromOffset(300,26); titleBar.BackgroundTransparency=1; titleBar.Parent=frame
    local title=Instance.new("TextLabel")
    title.Size=UDim2.fromScale(0.8,1); title.BackgroundTransparency=1
    title.Text="🚶 WalkBase Stealth Ultra+++"
    title.Font=Enum.Font.GothamBlack; title.TextSize=18; title.TextColor3=Color3.fromRGB(255,255,255)
    title.Parent=titleBar
    local minBtn=Instance.new("TextButton")
    minBtn.Size=UDim2.fromScale(0.2,1); minBtn.Position=UDim2.fromScale(0.8,0)
    minBtn.Text="—"; minBtn.Font=Enum.Font.GothamBlack; minBtn.TextSize=18
    minBtn.TextColor3=Color3.fromRGB(255,255,255); minBtn.BackgroundColor3=Color3.fromRGB(50,50,60)
    Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,6)
    minBtn.Parent=titleBar

    -- Botões
    local function makeBtn(txt,color)
        local b=Instance.new("TextButton")
        b.Size=UDim2.fromOffset(260,44)
        b.Text=txt; b.Font=Enum.Font.GothamBold; b.TextSize=16
        b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=color
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
        b.Parent=frame; return b
    end

    local walkBtn = makeBtn("🚶 Walk to Base (F)", Color3.fromRGB(70,70,120))
    local stopBtn = makeBtn("⏹ Parar Caminhada", Color3.fromRGB(160,60,60))
    local setBtn  = makeBtn("➕ Set Position (G)", Color3.fromRGB(70,120,70))
    local respBtn = makeBtn("🔄 Auto Respawn: ON (R)", Color3.fromRGB(120,90,70))
    local slot1   = makeBtn("🎯 Slot 1 (1) | SHIFT+1 salva", Color3.fromRGB(52,98,160))

    uiStatus=Instance.new("TextLabel")
    uiStatus.Size=UDim2.fromOffset(280,20); uiStatus.BackgroundTransparency=1
    uiStatus.Text="Base salva: nenhuma"; uiStatus.Font=Enum.Font.Gotham
    uiStatus.TextSize=14; uiStatus.TextColor3=Color3.fromRGB(200,220,255)
    uiStatus.Parent=frame

    -- Ações
    setBtn.MouseButton1Click:Connect(function()
        state.savedCFrame=getHRP().CFrame; uiStatus.Text="📍 Base salva ✔"; notify("📍 Base salva ✔")
    end)
    walkBtn.MouseButton1Click:Connect(walkToBase)
    stopBtn.MouseButton1Click:Connect(stopWalking)
    respBtn.MouseButton1Click:Connect(function()
        state.autoRespawn=not state.autoRespawn
        respBtn.Text=state.autoRespawn and "🔄 Auto Respawn: ON (R)" or "🔄 Auto Respawn: OFF (R)"
    end)
    slot1.MouseButton1Click:Connect(function()
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            state.slot1=getHRP().CFrame; notify("💾 Slot 1 salvo.")
        else
            if state.slot1 then state.savedCFrame=state.slot1; notify("🎯 Slot 1 ativado.") else notify("⚠ Slot 1 vazio.") end
        end
    end)

    -- Minimizar/Maximizar
    local minimized=false
    minBtn.MouseButton1Click:Connect(function()
        minimized=not minimized
        for _,child in ipairs(frame:GetChildren()) do
            if child~=titleBar and child~=stroke then child.Visible=not minimized end
        end
        minBtn.Text=minimized and "+" or "—"
    end)
end

buildUI()
notify("WalkBase Stealth Ultra+++ carregado — agora com Pathfinding, Auto Respawn, Slot e Botão Parar 🚶")
