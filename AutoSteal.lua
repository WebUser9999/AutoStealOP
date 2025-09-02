-- Fly to Base UI - versão corrigida (não mata ao voar)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- função utilitária para pegar HRP e Humanoid
local function getHRP()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

-- Criar UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyBaseUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.AnchorPoint = Vector2.new(1, 1)
container.Position = UDim2.fromScale(0.98, 0.95)
container.Size = UDim2.fromOffset(250, 90)
container.BackgroundTransparency = 1
container.Parent = screenGui

local uiList = Instance.new("UIListLayout")
uiList.Padding = UDim.new(0, 8)
uiList.FillDirection = Enum.FillDirection.Horizontal
uiList.HorizontalAlignment = Enum.HorizontalAlignment.Right
uiList.VerticalAlignment = Enum.VerticalAlignment.Center
uiList.Parent = container

local function makeButton(text)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(120, 44)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(240, 240, 255)
	btn.Font = Enum.Font.GothamSemibold
	btn.TextSize = 14

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.4
	stroke.Color = Color3.fromRGB(90, 100, 255)
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn

	return btn
end

local setBtn = makeButton("Set Position")
setBtn.Parent = container

local flyBtn = makeButton("Fly to Base")
flyBtn.Parent = container

-- Estado
local savedCFrame: CFrame? = nil
local isFlying = false

-- Notificação simples
local function notify(msg)
	pcall(function()
		game.StarterGui:SetCore("SendNotification", {
			Title = "FlyBase",
			Text = msg,
			Duration = 2
		})
	end)
end

-- Botão "Set Position"
setBtn.Activated:Connect(function()
	local hrp = getHRP()
	if not hrp then
		notify("Personagem não encontrado.")
		return
	end
	savedCFrame = hrp.CFrame
	notify("Posição salva!")
end)

-- Botão "Fly to Base"
flyBtn.Activated:Connect(function()
	if isFlying then return end
	if not savedCFrame then
		notify("Nenhuma posição salva.")
		return
	end

	local hrp, humanoid = getHRP()
	if not hrp or not humanoid then
		notify("Personagem não encontrado.")
		return
	end

	isFlying = true

	-- zerar velocidade (não deixa cair)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	-- calcular tempo de voo
	local distance = (hrp.Position - savedCFrame.Position).Magnitude
	local duration = math.clamp(distance / 60, 0.4, 3.0)

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(hrp, tweenInfo, { CFrame = savedCFrame })

	tween:Play()
	tween.Completed:Wait()

	isFlying = false
	notify("Chegou na base!")
end)

-- Garantir UI depois de respawn
player.CharacterAdded:Connect(function()
	screenGui.Parent = player:WaitForChild("PlayerGui")
end)
