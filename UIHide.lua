local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Players = game:GetService("Players")

local uiHidden = false
local savedGuis = {} -- Un GUIs ka record rakhne ke liye jo pehle se ON thin

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    -- Check if Ctrl + H is pressed
    if input.KeyCode == Enum.KeyCode.H and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
        uiHidden = not uiHidden
        
        -- Roblox Default UI ko toggle karna
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not uiHidden)
        end)
        
        local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            if uiHidden then
                -- Hide karne ki baari
                table.clear(savedGuis) -- Puraana record clear karein
                for _, gui in pairs(playerGui:GetChildren()) do
                    -- Sirf unko hide aur save karein jo pehle se Enabled (ON) hain
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        table.insert(savedGuis, gui)
                        gui.Enabled = false
                    end
                end
            else
                -- Wapas Show karne ki baari
                for _, gui in pairs(savedGuis) do
                    -- Sirf unhi ko wapas ON karein jo save kiye the
                    if gui and gui.Parent then 
                        gui.Enabled = true
                    end
                end
                table.clear(savedGuis) -- Kaam hone ke baad memory clear kar dein
            end
        end
    end
end)
