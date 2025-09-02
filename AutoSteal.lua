--[[
  UI "Set Position" / "Fly to Base" para o personagem local
  - "Set Position": salva o CFrame atual do HumanoidRootPart
  - "Fly to Base": move (voa) suavemente até a posição salva (sem voltar)
  - Sem resets/retornos automáticos; a posição fica salva até você mudar
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Util: obtém o HRP com segurança
local function getHRP()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
end

-- Cria UI básica programaticamente
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FlyBaseUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "Container"
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
	btn.AutoButtonColor = true
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

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = btn

	return btn
end

local setBtn = makeButton("Set Position")
setBtn.Parent = container

local flyBtn = makeButton("Fly to Base")
flyBtn.Parent = container

-- Estado
local savedCFrame: CFrame? = nil
local isFlying = false

-- Feedback simples
local function notify(msg)
	if not game:GetService("StarterGui"):FindFirstChild("SetCore") then return end
	pcall(function()
		game.StarterGui:SetCore("SendNotification", {
			Title = "FlyBase",
			Text = msg,
			Duration = 2
		})
	end)
end

-- Lógica "Set Position"
setBtn.Activated:Connect(function()
	local hrp = getHRP()
	if not hrp then
		notify("Personagem não encontrado.")
		return
	end
	savedCFrame = hrp.CFrame
	notify("Posição salva!")
end)

-- Lógica "Fly to Base"
flyBtn.Activated:Connect(function()
	if isFlying then return end
	if not savedCFrame then
		notify("Nenhuma posição salva. Use 'Set Position' primeiro.")
		return
	end

	local hrp, humanoid = getHRP()
	if not hrp or not humanoid then
		notify("Personagem não encontrado.")
		return
	end

	isFlying = true

	-- Prepara voo: reduz interferência da física
	local originalPlatform = humanoid.PlatformStand
	local originalAutoRotate = humanoid.AutoRotate

	-- Velocidade zero
	if hrp:IsA("BasePart") then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end

	-- Desativa rotações e dá "hover"
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	-- Duração baseada na distância (suave e previsível)
	local distance = (hrp.Position - savedCFrame.Position).Magnitude
	local duration = math.clamp(distance / 60, 0.4, 3.0) -- 60 studs/s, min 0.4s, max 3s

	-- Tween direto do CFrame do HRP
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	local tween = TweenService:Create(hrp, tweenInfo, { CFrame = savedCFrame })

	-- Segurança: bloquear input de movimento (opcional)
	local ctxAction = game:GetService("ContextActionService")
	local actionName = "BlockMovementForFly"
	ctxAction:BindAction(actionName, function() return Enum.ContextActionResult.Sink end,
		false, Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump)

	tween:Play()
	tween.Completed:Wait()

	-- Restaura estados (sem voltar para a posição anterior!)
	ctxAction:UnbindAction(actionName)
	humanoid.PlatformStand = originalPlatform
	humanoid.AutoRotate = originalAutoRotate

	isFlying = false
	notify("Chegou à base!")
end)

-- Mantém a posição salva mesmo após respawn (sem reset)
player.CharacterAdded:Connect(function(char)
	-- Apenas garante que a UI continue viva e sem resetar a posição salva
	screenGui.Parent = player:WaitForChild("PlayerGui")
end)

-- DICA: se quiser que o "Fly to Base" gire o personagem para a mesma orientação salva,
-- já usamos CFrame completo (posição + rotação). Se preferir manter a rotação atual,
-- troque { CFrame = savedCFrame } por { CFrame = CFrame.new(savedCFrame.Position) }.
