-- FlyBase Ultimate Stealth++
-- Movimento híbrido: WalkToPoint + Velocity, dividido em waypoints
-- Anti-reset/morte/drop ativo durante o voo
-- Smooth e replicado pro servidor (não é só client visual)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
local player = Players.LocalPlayer

-- Config
local HOLD_SECONDS = 5
local POST_SPAWN_PIN = 1.2
local WAYPOINT_DIST = 15   -- distância entre waypoints
local MAX_SPEED = 65       -- velocidade máxima
local MIN_SPEED = 25       -- velocidade mínima
local ACCEL_FACTOR = 0.15  -- suavização do velocity

getgenv().FlyBaseUltimate = getgenv().FlyBaseUltimate or {
    savedCFrame = nil,
    isFlying = false,
    uiBuilt = false,
    autoRespawn = true
}
local state = getgenv().FlyBaseUltimate

local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHRP(char) char = char or getChar(); return char:WaitForChild("HumanoidRootPart") end
local function getHumanoid(char) char = char or getChar(); return char:WaitForChild("Humanoid") end
local function notify(msg) pcall(function() StarterGui:SetCore("SendNotification",{Title="FlyBase++",Text=msg,Duration=2}) end) end

-- ===== Anti-Reset =====
local Anti = {active=false}
local function hookReset()
    StarterGui:SetCore("ResetButtonCallback", function()
        notify("⛔ Reset bloqueado em voo")
        return
    end)
end
local function unhookReset()
    StarterGui:SetCore("ResetButtonCallback", true)
end
local function enableAnti()
    if Anti.active then return end
    Anti.active = true
    hookReset()
    local hum = getHumanoid()
    hum.BreakJointsOnDeath = false
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
    for _,tool in ipairs(player.Backpack:GetChildren()) do if tool:IsA("Tool") then tool.CanBeDropped=false end end
end
local function disableAnti()
    if not Anti.active then return end
    Anti.active=false
    unhookReset()
    local hum = getHumanoid()
    hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
end

-- ===== Helpers =====
local function getGroundPosition(pos)
    local ray = RaycastParams.new()
    ray.FilterDescendantsInstances = {player.Character}
    ray.FilterType = Enum.RaycastFilterType.Blacklist
    local res = Workspace:Raycast(pos+Vector3.new(0,10,0), Vector3.new(0,-1000,0), ray)
    return res and Vector3.new(pos.X,res.Position.Y+2,pos.Z) or pos
end

local function hardLockTo(targetPos, seconds)
    local hrp = getHRP()
    if not hrp then return end
    local groundPos = getGroundPosition(targetPos)
    local t0 = tick()
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if not hrp.Parent then conn:Disconnect() return end
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(groundPos, groundPos+hrp.CFrame.LookVector)
        if tick()-t0 >= seconds then conn:Disconnect() end
    end)
end

-- ===== Fly Function =====
local function flyToBase()
    if state.isFlying or not state.savedCFrame then return end
    state.isFlying = true
    enableAnti()

    local hrp = getHRP()
    local hum = getHumanoid()
    local target = getGroundPosition(state.savedCFrame.Position)
    local start = hrp.Position

    local distTotal = (target-start).Magnitude
    local waypoints = math.ceil(distTotal / WAYPOINT_DIST)

    local conn
    local currentWp = 1
    local wpTarget = start:Lerp(target, currentWp/waypoints)

    conn = RunService.Heartbeat:Connect(function(dt)
        if not hrp.Parent then conn:Disconnect() state.isFlying=false disableAnti() return end

        local dist = (wpTarget-hrp.Position).Magnitude
        if dist < 3 then
            currentWp = currentWp+1
            if currentWp > waypoints then
                conn:Disconnect()
                state.isFlying=false
                notify("✅ Chegou na base!")
                hardLockTo(target,HOLD_SECONDS)
                disableAnti()
                return
            end
            wpTarget = start:Lerp(target, currentWp/waypoints)
            hum:MoveTo(wpTarget)
        end

        -- ajusta velocidade física
        local dir = (wpTarget-hrp.Position).Unit
        local desiredSpeed = math.random(MIN_SPEED,MAX_SPEED)
        local desiredVel = dir*desiredSpeed
        hrp.AssemblyLinearVelocity = hrp.AssemblyLinearVelocity:Lerp(desiredVel, ACCEL_FACTOR)
    end)
end

-- ===== UI =====
local function buildUI()
    if state.uiBuilt then return end
    state.uiBuilt=true
    local gui = Instance.new("ScreenGui")
    gui.Name="FlyBaseUI"
    gui.ResetOnSpawn=false
    gui.Parent=player:WaitForChild("PlayerGui")

    local frame=Instance.new("Frame")
    frame.Size=UDim2.fromOffset(260,250)
    frame.Position=UDim2.fromScale(0.75,0.6)
    frame.BackgroundColor3=Color3.fromRGB(30,30,40)
    frame.Parent=gui
    Instance.new("UICorner",frame)

    local title=Instance.new("TextLabel")
    title.Size=UDim2.fromOffset(200,30)
    title.BackgroundTransparency=1
    title.Text="🚀 FlyBase Stealth++"
    title.Font=Enum.Font.GothamBlack
    title.TextSize=18
    title.TextColor3=Color3.fromRGB(255,255,255)
    title.Parent=frame

    local function btn(txt,color,callback)
        local b=Instance.new("TextButton")
        b.Size=UDim2.fromOffset(200,44)
        b.Text=txt
        b.Font=Enum.Font.GothamBold
        b.TextSize=16
        b.TextColor3=Color3.new(1,1,1)
        b.BackgroundColor3=color
        Instance.new("UICorner",b)
        b.Parent=frame
        b.MouseButton1Click:Connect(callback)
    end

    btn("➕ Set Position",Color3.fromRGB(70,120,70),function()
        state.savedCFrame=getHRP().CFrame
        notify("📍 Base salva ✔")
    end)
    btn("✈️ Fly to Base",Color3.fromRGB(70,70,120),flyToBase)
end

buildUI()
notify("FlyBase Stealth++ carregado! ➕ Set / ✈️ Fly")
