-- === Model Conveyor Keeper (pega Model da esteira, salva e re-anexa no respawn) ===
-- Não precisa saber o nome. Detecta pelo contato com a mão (Right/LeftHand).
-- Se o jogo já soldar, a gente detecta e clona. Se não, a gente cria a solda.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Ajustes
local HAND_PART_NAMES = {"RightHand","LeftHand"} -- R6 use "Right Arm","Left Arm" se precisar
local ONLY_ON_TOUCH = true          -- TRUE: só captura quando tocar na mão; FALSE: também tenta pegar Model muito perto
local NEARBY_RADIUS = 4.5           -- usado se ONLY_ON_TOUCH = false
local IGNORE_CHARACTER_MODELS = true -- não pega Models que são personagens

-- Estado global (reusa se já existir)
getgenv().FlyBaseUltimate = getgenv().FlyBaseUltimate or {}
local state = getgenv().FlyBaseUltimate
state.modelKeeper = state.modelKeeper or {
  savedModelClone = nil,
  savedModelName = nil,
  savedRelCF = nil,
  savedHandName = nil,
  conns = {}
}
local MK = state.modelKeeper

-- Utilidades
local function getChar() return player.Character or player.CharacterAdded:Wait() end
local function getHumanoid(char) char = char or getChar(); return char:WaitForChild("Humanoid") end

local function firstBasePart(model)
  if not model or not model:IsA("Model") then return nil end
  if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
    return model.PrimaryPart
  end
  for _,d in ipairs(model:GetDescendants()) do
    if d:IsA("BasePart") then
      return d
    end
  end
  return nil
end

local function setPrimaryIfNeeded(model)
  if not model.PrimaryPart then
    local p = firstBasePart(model)
    if p then model.PrimaryPart = p end
  end
end

local function isCharacterModel(model)
  if not model or not model:IsA("Model") then return false end
  return model:FindFirstChildOfClass("Humanoid") ~= nil
end

local function weldToHand(model, handPart)
  setPrimaryIfNeeded(model)
  local pp = model.PrimaryPart or firstBasePart(model)
  if not (pp and handPart and handPart:IsA("BasePart")) then return nil end

  -- tira colisão pra não te arrastar
  for _,bp in ipairs(model:GetDescendants()) do
    if bp:IsA("BasePart") then
      bp.CanCollide = false
      bp.Massless = true
    end
  end

  -- move o modelo pra mão mantendo offset
  local rel = handPart.CFrame:ToObjectSpace(pp.CFrame)

  -- cria a solda
  local weld = Instance.new("WeldConstraint")
  weld.Part0 = handPart
  weld.Part1 = pp
  weld.Parent = handPart

  -- aplica o offset (reposiciona o modelo preso à mão)
  model:SetPrimaryPartCFrame(handPart.CFrame * rel)

  return rel -- guardamos o offset pra reaplicar no respawn
end

local function saveClone(model)
  if not model or not model:IsA("Model") then return end
  -- destrói clone antigo
  if MK.savedModelClone and MK.savedModelClone.Parent then
    MK.savedModelClone:Destroy()
  end
  local clone = model:Clone()
  -- guardamos fora da workspace pra não interferir (nil parenting)
  clone.Parent = nil
  MK.savedModelClone = clone
  MK.savedModelName = model.Name
end

local function attachSavedToNewChar(handPart)
  if not (MK.savedModelClone and handPart) then return end
  local clone = MK.savedModelClone:Clone()
  clone.Parent = workspace -- precisa existir pra soldar e posicionar
  setPrimaryIfNeeded(clone)
  local rel = MK.savedRelCF or CFrame.new(0,0,0)
  local pp = clone.PrimaryPart or firstBasePart(clone)
  if not pp then return end

  -- posiciona próximo da mão antes de soldar
  clone:SetPrimaryPartCFrame(handPart.CFrame * rel)
  -- solda novamente
  local weld = Instance.new("WeldConstraint")
  weld.Part0 = handPart
  weld.Part1 = pp
  weld.Parent = handPart

  -- segurança: sem colisão e massless
  for _,bp in ipairs(clone:GetDescendants()) do
    if bp:IsA("BasePart") then
      bp.CanCollide = false
      bp.Massless = true
    end
  end
end

local function captureModelFromPart(hitPart, handPart)
  if not (hitPart and hitPart:IsA("BasePart")) then return end
  local model = hitPart:FindFirstAncestorOfClass("Model")
  if not model then return end
  if IGNORE_CHARACTER_MODELS and isCharacterModel(model) then return end

  -- se já está com um guardado e o nome bater, ignora
  if MK.savedModelName and model.Name == MK.savedModelName then
    -- ainda assim garante a solda e offset
  end

  -- garante que o modelo está no mundo
  if not model.Parent then return end

  -- solda na mão e salva offset
  local rel = weldToHand(model, handPart)
  if rel then
    MK.savedRelCF = rel
    MK.savedHandName = handPart.Name
    saveClone(model)
    -- opcional: feedback
    pcall(function() game.StarterGui:SetCore("SendNotification",{Title="Model Keeper",Text="Modelo capturado: "..(model.Name or "sem nome"),Duration=2}) end)
  end
end

local function hookHand(handPart)
  if not handPart or MK.conns[handPart] then return end

  local conns = {}

  -- captura por toque
  conns[#conns+1] = handPart.Touched:Connect(function(hit)
    captureModelFromPart(hit, handPart)
  end)

  -- captura por proximidade (opcional)
  if not ONLY_ON_TOUCH then
    conns[#conns+1] = RunService.Heartbeat:Connect(function()
      -- varre partes próximas
      local origin = handPart.Position
      for _,desc in ipairs(workspace:GetDescendants()) do
        if desc:IsA("BasePart") and (desc.Position - origin).Magnitude <= NEARBY_RADIUS then
          local model = desc:FindFirstAncestorOfClass("Model")
          if model and (not IGNORE_CHARACTER_MODELS or not isCharacterModel(model)) then
            captureModelFromPart(desc, handPart)
            break
          end
        end
      end
    end)
  end

  MK.conns[handPart] = conns
end

local function unhookAll()
  for hand, conns in pairs(MK.conns) do
    for _,c in ipairs(conns) do pcall(function() c:Disconnect() end) end
  end
  MK.conns = {}
end

local function onCharacter(char)
  unhookAll()

  -- acha mãos
  local hands = {}
  for _,name in ipairs(HAND_PART_NAMES) do
    local h = char:FindFirstChild(name) or char:WaitForChild(name, 3)
    if h and h:IsA("BasePart") then
      table.insert(hands, h)
    end
  end

  -- reconecta listeners de captura
  for _,h in ipairs(hands) do
    hookHand(h)
  end

  -- reanexa modelo salvo no respawn (na mesma mão, se existir)
  if MK.savedModelClone and MK.savedRelCF then
    local targetHand = nil
    for _,h in ipairs(hands) do
      if not MK.savedHandName or h.Name == MK.savedHandName then
        targetHand = h
        break
      end
    end
    if targetHand then
      -- espera o Humanoid ficar pronto pra não brigar com animações iniciais
      task.delay(0.2, function()
        attachSavedToNewChar(targetHand)
      end)
    end
  end
end

-- Liga ciclo
player.CharacterAdded:Connect(onCharacter)
if player.Character then onCharacter(player.Character) end
