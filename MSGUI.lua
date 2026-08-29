-- Advanced Auto-Detect NPC / Monster Spectate GUI (Fixed)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Existing GUI Remove Karein (Agar pehle se load ho)
if game:GetService("CoreGui"):FindFirstChild("NPCSpectatorGUI") then
    game:GetService("CoreGui").NPCSpectatorGUI:Destroy()
end

-- Screen GUI setup
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NPCSpectatorGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui")

local Frame = Instance.new("Frame", ScreenGui)
Frame.Size = UDim2.new(0, 240, 0, 350)
Frame.Position = UDim2.new(0.05, 0, 0.3, 0)
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Frame.Active = true
Frame.Draggable = true

local Title = Instance.new("TextLabel", Frame)
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Text = "NPC Spectator System"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16

-- Refresh Button (Title ki jagah, kyunke TextLabel click support nahi karta)
local RefreshBtn = Instance.new("TextButton", Frame)
RefreshBtn.Size = UDim2.new(1, -20, 0, 25)
RefreshBtn.Position = UDim2.new(0, 10, 0, 35)
RefreshBtn.Text = "🔄 Refresh List"
RefreshBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshBtn.Font = Enum.Font.SourceSansBold
RefreshBtn.TextSize = 14

-- Scroll Container NPC List ke liye
local Scroll = Instance.new("ScrollingFrame", Frame)
Scroll.Size = UDim2.new(1, -20, 1, -115)
Scroll.Position = UDim2.new(0, 10, 0, 65)
Scroll.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.ScrollBarThickness = 6

local UIListLayout = Instance.new("UIListLayout", Scroll)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 5)

-- Reset Cam Button
local ResetBtn = Instance.new("TextButton", Frame)
ResetBtn.Size = UDim2.new(1, -20, 0, 30)
ResetBtn.Position = UDim2.new(0, 10, 1, -35)
ResetBtn.Text = "Reset to My Player"
ResetBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
ResetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ResetBtn.Font = Enum.Font.SourceSansBold

-- Functions
local function scanNPCs()
    -- List saaf karein
    for _, child in pairs(Scroll:GetChildren()) do
        if child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local count = 0
    -- Workspace ke andar tamam Models scan karna
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            -- Check karein ke yeh real player na ho
            if not Players:GetPlayerFromCharacter(obj) then
                count = count + 1
                local Button = Instance.new("TextButton", Scroll)
                Button.Size = UDim2.new(1, -10, 0, 30)
                Button.LayoutOrder = count
                Button.Text = obj.Name
                Button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
                Button.TextColor3 = Color3.fromRGB(255, 255, 255)

                Button.MouseButton1Click:Connect(function()
                    local humanoid = obj:FindFirstChildOfClass("Humanoid")
                    if humanoid and humanoid.Health > 0 then
                        Camera.CameraSubject = humanoid
                        Camera.CameraType = Enum.CameraType.Custom
                    end
                end)
            end
        end
    end
    Scroll.CanvasSize = UDim2.new(0, 0, 0, count * 35)
end

-- Initial Scan
scanNPCs()

-- Refresh on click (Agar naye monsters spawn ho)
RefreshBtn.MouseButton1Click:Connect(scanNPCs)

-- Reset Camera
ResetBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    if char then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            Camera.CameraSubject = humanoid
            Camera.CameraType = Enum.CameraType.Custom
        end
    end
end)

-- Show/Hide Shortcut (Right Shift)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        Frame.Visible = not Frame.Visible
    end
end)
