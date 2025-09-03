-- WalkBase Stealth+++ (complexo estilo FlyBase)
-- • 2 botões: Walk to Base / Set Position
-- • Hotkeys: F = andar, G = salvar
-- • UI com título + minimizar
-- • Status de distância
-- • Pathfinding seguro (anti-rollback)

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- Estado
getgenv().WalkBasePro = getgenv().WalkBasePro or {
    savedCFrame = nil,
    isWalking = false,
    uiBuilt = false
}
local state = getgenv().WalkBasePro
local uiStatus

local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="WalkBase",Text=msg,Duration=2})
    end)
end

-- Helpers
local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHRP(c) c=c or getChar(); return c:WaitForChild("HumanoidRootPart") end
local function getHumanoid(c) c=c or getChar(); return c:WaitForChild("Humanoid") end

-- Caminhar até a base
local function walkToBase()
    if state.isWalking or not state.savedCFrame then notify("⚠ Nenhuma base salva!"); return end
    state.isWalking = true
    local hum=getHumanoid(); hum.WalkSpeed = 22
    local hrp=getHRP()
    local target=state.savedCFrame.Position

    local path=PathfindingService:CreatePath({
        AgentRadius=2,AgentHeight=5,
        AgentCanJump=true,AgentJumpHeight=7,
        AgentMaxSlope=45
    })
    path:ComputeAsync(hrp.Position,target)

    if path.Status ~= Enum.PathStatus.Complete then
        notify("⚠ Caminho inválido!")
        state.isWalking=false
        return
    end

    local waypoints=path:GetWaypoints()
    for _,wp in ipairs(waypoints) do
        hum:MoveTo(wp.Position)
        repeat
            local dist=(wp.Position-hrp.Position).Magnitude
            if uiStatus then uiStatus.Text=string.format("Distância: %.1f", (target-hrp.Position).Magnitude) end
            task.wait(0.1)
        until (wp.Position-hrp.Position).Magnitude<3 or not state.isWalking
        if not state.isWalking then return end
    end

    notify("✅ Chegou à base andando!")
    if uiStatus then uiStatus.Text="Chegou ✔" end
    state.isWalking=false
end

-- Construir UI
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt=true

    local gui=Instance.new("ScreenGui")
    gui.Name="WalkBaseUI"; gui.ResetOnSpawn=false
    gui.Parent=player:WaitForChild("PlayerGui")

    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(280,180)
    frame.AnchorPoint=Vector2.new(0.5,0.5)
    frame.Position=UDim2.fromScale(0.5,0.5)
    frame.BackgroundColor3=Color3.fromRGB(26,28,36)
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)

    local stroke=Instance.new("UIStroke")
    stroke.Thickness=2
    stroke.Color=Color3.fromRGB(120,140,255)
    stroke.Parent=frame

    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,10)
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.VerticalAlignment=Enum.VerticalAlignment.Center
    layout.Parent=frame

    -- Título + Minimizar
    local titleBar=Instance.new("Frame")
    titleBar.Size=UDim2.fromOffset(260,26)
    titleBar.BackgroundTransparency=1
    titleBar.Parent=frame
    local title=Instance.new("TextLabel")
    title.Size=UDim2.fromScale(0.8,1)
    title.BackgroundTransparency=1
    title.Text="🚶 WalkBase Stealth+++"
    title.Font=Enum.Font.GothamBlack
    title.TextSize=18
    title.TextColor3=Color3.fromRGB(255,255,255)
    title.Parent=titleBar
    local minBtn=Instance.new("TextButton")
    minBtn.Size=UDim2.fromScale(0.2,1)
    minBtn.Position=UDim2.fromScale(0.8,0)
    minBtn.Text="—"
    minBtn.Font=Enum.Font.GothamBlack
    minBtn.TextSize=18
    minBtn.TextColor3=Color3.fromRGB(255,255,255)
    minBtn.BackgroundColor3=Color3.fromRGB(50,50,60)
    Instance.new("UICorner",minBtn).CornerRadius=UDim.new(0,6)
    minBtn.Parent=titleBar

    -- Botões
    local function makeBtn(txt,color,callback)
        local b=Instance.new("TextButton")
        b.Size=UDim2.fromOffset(240,44)
        b.Text=txt
        b.Font=Enum.Font.GothamBold
        b.TextSize=16
        b.TextColor3=Color3.new(1,1,1)
        b.BackgroundColor3=color
        Instance.new("UICorner",b).CornerRadius=UDim.new(0,10)
        b.Parent=frame
        b.MouseButton1Click:Connect(callback)
        return b
    end

    makeBtn("🚶 Walk to Base (F)", Color3.fromRGB(70,70,120), walkToBase)
    makeBtn("📍 Set Position (G)", Color3.fromRGB(70,120,70), function()
        state.savedCFrame=getHRP().CFrame
        notify("📍 Base salva!")
        if uiStatus then uiStatus.Text="Base salva ✔" end
    end)

    uiStatus=Instance.new("TextLabel")
    uiStatus.Size=UDim2.fromOffset(240,20)
    uiStatus.BackgroundTransparency=1
    uiStatus.Text="Aguardando base..."
    uiStatus.Font=Enum.Font.Gotham
    uiStatus.TextSize=14
    uiStatus.TextColor3=Color3.fromRGB(200,220,255)
    uiStatus.Parent=frame

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

-- Hotkeys
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.G then
        state.savedCFrame=getHRP().CFrame
        notify("📍 Base salva!")
        if uiStatus then uiStatus.Text="Base salva ✔" end
    elseif input.KeyCode==Enum.KeyCode.F then
        walkToBase()
    end
end)

notify("WalkBase Stealth+++ carregado — estilo FlyBase, só 2 botões 🚶")
