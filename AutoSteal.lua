-- WalkBase Stealth++ (apenas Set Position + Walk)
-- • Botão Set Position = marca ponto atual
-- • Botão Walk to Position = anda até o ponto marcado
-- • Hotkeys: G = set, F = andar
-- • Sem salvar nada fixo, sem "base salva"

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- Estado
getgenv().WalkBaseNow = getgenv().WalkBaseNow or {
    targetCFrame = nil,
    isWalking = false,
    uiBuilt = false
}
local state = getgenv().WalkBaseNow

local function notify(msg)
    pcall(function()
        StarterGui:SetCore("SendNotification",{Title="WalkBase",Text=msg,Duration=2})
    end)
end

-- Helpers
local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHRP(c) c=c or getChar(); return c:WaitForChild("HumanoidRootPart") end
local function getHumanoid(c) c=c or getChar(); return c:WaitForChild("Humanoid") end

-- Caminhar até posição marcada
local function walkToPosition()
    if state.isWalking or not state.targetCFrame then return end
    state.isWalking = true
    local hum=getHumanoid(); hum.WalkSpeed = 22
    local hrp=getHRP()
    local target=state.targetCFrame.Position

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

    for _,wp in ipairs(path:GetWaypoints()) do
        hum:MoveTo(wp.Position)
        hum.MoveToFinished:Wait()
        if not state.isWalking then return end
    end

    notify("✅ Chegou ao ponto marcado!")
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
    frame.Size=UDim2.fromOffset(260,140)
    frame.AnchorPoint=Vector2.new(0.5,0.5)
    frame.Position=UDim2.fromScale(0.5,0.5)
    frame.BackgroundColor3=Color3.fromRGB(26,28,36)
    frame.Parent=gui
    Instance.new("UICorner",frame).CornerRadius=UDim.new(0,12)

    local layout=Instance.new("UIListLayout")
    layout.Padding=UDim.new(0,10)
    layout.HorizontalAlignment=Enum.HorizontalAlignment.Center
    layout.VerticalAlignment=Enum.VerticalAlignment.Center
    layout.Parent=frame

    local function makeBtn(txt,color,callback)
        local b=Instance.new("TextButton")
        b.Size=UDim2.fromOffset(220,44)
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

    makeBtn("🚶 Walk to Position (F)", Color3.fromRGB(70,70,120), walkToPosition)
    makeBtn("📍 Set Position (G)", Color3.fromRGB(70,120,70), function()
        state.targetCFrame=getHRP().CFrame
        notify("📍 Posição marcada!")
    end)
end

buildUI()

-- Hotkeys também
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.G then
        state.targetCFrame=getHRP().CFrame
        notify("📍 Posição marcada!")
    elseif input.KeyCode == Enum.KeyCode.F then
        walkToPosition()
    end
end)

notify("WalkBase Stealth++ carregado — Set Position + Walk to Position 🚶")
alkBase Stealth+++ carregado — estilo FlyBase, só 2 botões 🚶")
