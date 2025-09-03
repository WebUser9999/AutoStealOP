-- WalkBase Stealth++ (simples)
-- • G = Set Position
-- • F = Walk to Base
-- • Usa Pathfinding (seguro contra anticheat)
-- • Sem botões extras

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- Estado
getgenv().WalkBaseSimple = getgenv().WalkBaseSimple or {
    savedCFrame = nil,
    isWalking = false
}
local state = getgenv().WalkBaseSimple

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

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentJumpHeight = 7,
        AgentMaxSlope = 45
    })
    path:ComputeAsync(hrp.Position, target)

    if path.Status ~= Enum.PathStatus.Complete then
        notify("⚠ Caminho inválido!")
        state.isWalking=false
        return
    end

    for _, waypoint in ipairs(path:GetWaypoints()) do
        hum:MoveTo(waypoint.Position)
        hum.MoveToFinished:Wait()
        if not state.isWalking then return end
    end

    notify("✅ Chegou à base andando!")
    state.isWalking=false
end

-- Hotkeys
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.G then
        state.savedCFrame = getHRP().CFrame
        notify("📍 Base salva!")
    elseif input.KeyCode == Enum.KeyCode.F then
        walkToBase()
    end
end)

notify("WalkBase carregado — G salva posição, F anda até a base 🚶")
