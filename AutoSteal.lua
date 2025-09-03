-- Scanner de Tools
local player = game:GetService("Players").LocalPlayer

local function listTools()
    print("=== TOOLS NO CHARACTER ===")
    if player.Character then
        for _,v in ipairs(player.Character:GetChildren()) do
            if v:IsA("Tool") then
                print("Name:", v.Name)
            end
        end
    end
    print("=== TOOLS NA BACKPACK ===")
    local bp = player:FindFirstChildOfClass("Backpack")
    if bp then
        for _,v in ipairs(bp:GetChildren()) do
            if v:IsA("Tool") then
                print("Name:", v.Name)
            end
        end
    end
end

listTools()
