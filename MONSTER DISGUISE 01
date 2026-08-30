--[[
    NPC / MONSTER DISGUISE — LOCAL ONLY (Video Recording ke liye)
    ---------------------------------------------------------------
    - Yeh sirf APKO nazar aayega, dusre players ko nahi (ban-free, kyunke
      server ko kuch bheja hi nahi jata — sirf aapke apne client par
      Transparency change hoti hai, jo LocalTransparencyModifier se
      hoti hai aur kabhi server tak replicate nahi hoti).
    - GUI khud workspace scan karke sare NPC/Monster dhoondh leta hai
      (kisi Model jis mein Humanoid ho, aur woh koi Player na ho).
    - Button click karke us NPC ki "body" pehen lete hain (visual clone
      aapke character ke sath follow karta hai).
    - "Next / Cycle" button se baar baar switch kar sakte ho.

    KAHAN RAKHNA HAI:
    StarterPlayer -> StarterPlayerScripts -> yahan is LocalScript ko daal dein.
]]

local Players       = game:GetService("Players")
local RunService     = game:GetService("RunService")

local player = Players.LocalPlayer

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local currentDisguise   = nil
local renderConn        = nil
local monsterList        = {}
local currentIndex       = 0
local animTracks        = {}   -- category (idle/walk/run/jump/fall) -> AnimationTrack
local currentAnimState  = nil

------------------------------------------------------------
-- FIND ALL NPC / MONSTERS IN WORKSPACE
------------------------------------------------------------
local function findMonsters()
	local list = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
			-- Player ka apna character skip karo, baaki sab NPC/monster maano
			if not Players:GetPlayerFromCharacter(obj) then
				table.insert(list, obj)
			end
		end
	end
	return list
end

------------------------------------------------------------
-- NPC KI ANIMATIONS (idle/walk/run/jump/fall) NIKALO
------------------------------------------------------------
-- Zyada tar Roblox rigs mein ek "Animate" Script/Folder hota hai jiske
-- andar "idle", "walk", "run" waghera naam ke sub-folders hote hain,
-- jinke andar Animation objects (AnimationId ke sath) hote hain.
-- Yeh function unko dhoond kar table mein return karta hai.
local ANIM_CATEGORIES = {"idle", "walk", "run", "jump", "fall", "climb", "swim"}

local function extractAnimations(model)
	local anims = {}

	local function scanContainer(container)
		for _, cat in ipairs(ANIM_CATEGORIES) do
			if not anims[cat] then
				local sub = container:FindFirstChild(cat)
				if sub then
					for _, child in ipairs(sub:GetChildren()) do
						if child:IsA("Animation") and child.AnimationId ~= "" then
							anims[cat] = child.AnimationId
							break
						end
					end
				end
			end
		end
	end

	-- Pehle "Animate" naam ki Script/Folder dhoondo (default Roblox pattern)
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "Animate" and (d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Folder")) then
			scanContainer(d)
		end
	end

	-- Kuch na mile to, poore model mein har Animation object ko uske
	-- parent ke naam se category match karke le lo (fallback)
	if next(anims) == nil then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Animation") and d.AnimationId ~= "" and d.Parent then
				local pname = d.Parent.Name:lower()
				for _, cat in ipairs(ANIM_CATEGORIES) do
					if not anims[cat] and pname:find(cat, 1, true) then
						anims[cat] = d.AnimationId
					end
				end
			end
		end
	end

	return anims
end

------------------------------------------------------------
-- CLEAR / REMOVE DISGUISE (wapas apni asli body)
------------------------------------------------------------
local function clearDisguise()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if currentDisguise then
		currentDisguise:Destroy()
		currentDisguise = nil
	end
	animTracks = {}
	currentAnimState = nil

	local char = player.Character
	if char then
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				part.LocalTransparencyModifier = 0
			end
		end
	end
end

------------------------------------------------------------
-- DISGUISE AS A GIVEN NPC MODEL (sirf local view)
------------------------------------------------------------
local function disguiseAs(npcModel)
	if not npcModel or not npcModel.Parent then
		warn("Yeh NPC ab maujood nahi hai (destroyed ho chuka hai)")
		return
	end

	clearDisguise()

	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- NPC ka clone banao (visual copy)
	local clone = npcModel:Clone()
	clone.Name = "Disguise_" .. npcModel.Name

	-- Scripts delete karne se PEHLE animation IDs nikaal lo, warna
	-- Animate script ke saath woh bhi chali jaayengi
	local animIds = extractAnimations(clone)

	-- Scripts hata do taake NPC ka AI dubara chalna shuru na ho
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end

	-- Physics off, taake yeh sirf ek "costume" ki tarah follow kare
	for _, p in ipairs(clone:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.Anchored = false
			p.Massless = true
		end
	end

	local clonePrimary = clone.PrimaryPart
		or clone:FindFirstChild("HumanoidRootPart")
		or clone:FindFirstChild("Torso")
		or clone:FindFirstChild("Head")

	if not clonePrimary then
		clone:Destroy()
		warn("Is NPC ka koi valid PrimaryPart nahi mila")
		return
	end
	clone.PrimaryPart = clonePrimary
	clone.Parent = workspace
	currentDisguise = clone

	-- ===== FEET/GROUND ALIGNMENT FIX =====
	-- Har model ka size alag hota hai, isliye sirf root.CFrame copy karne se
	-- bade/chote monster floor mein dhans jate ya hawa mein tairte hain.
	-- Yahan hum root se "feet" tak ki doori nikaal kar, dono (player aur
	-- clone) ke feet ko hamesha floor par barabar rakhte hain.
	local function getBottomY(model)
		local cf, size = model:GetBoundingBox()
		return cf.Position.Y - (size.Y / 2)
	end

	local playerFootOffset = root.Position.Y - getBottomY(char)
	local cloneFootOffset  = clonePrimary.Position.Y - getBottomY(clone)
	local yAdjust = cloneFootOffset - playerFootOffset
	-- =======================================

	-- ===== ANIMATIONS SETUP (idle/walk/run/jump/fall) =====
	local cloneHum = clone:FindFirstChildOfClass("Humanoid")
	local animator = nil
	if cloneHum then
		animator = cloneHum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = cloneHum
		end
	end

	animTracks = {}
	if animator then
		for cat, id in pairs(animIds) do
			local animObj = Instance.new("Animation")
			animObj.AnimationId = id
			local ok, track = pcall(function()
				return animator:LoadAnimation(animObj)
			end)
			if ok and track then
				track.Looped = true
				animTracks[cat] = track
			end
		end
	end
	currentAnimState = nil
	-- =========================================================

	local playerHum = char:FindFirstChildOfClass("Humanoid")

	-- Har frame: clone ko apne asli character ke root ke sath move karo,
	-- asli character ko sirf apni screen par invisible rakho, aur apne
	-- real movement ke hisaab se sahi animation play karo
	renderConn = RunService.RenderStepped:Connect(function()
		if root.Parent and clonePrimary.Parent then
			clone:SetPrimaryPartCFrame(root.CFrame + Vector3.new(0, yAdjust, 0))
		end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				part.LocalTransparencyModifier = 1
			end
		end

		-- ===== APNE MOVEMENT KE HISAAB SE ANIMATION CHUNO =====
		if playerHum then
			local desired = nil
			local hState = playerHum:GetState()
			local speed = playerHum.MoveDirection.Magnitude

			if hState == Enum.HumanoidStateType.Jumping and animTracks.jump then
				desired = "jump"
			elseif hState == Enum.HumanoidStateType.Freefall and animTracks.fall then
				desired = "fall"
			elseif speed > 0.05 then
				if playerHum.WalkSpeed > 20 and animTracks.run then
					desired = "run"
				elseif animTracks.walk then
					desired = "walk"
				elseif animTracks.run then
					desired = "run"
				end
			elseif animTracks.idle then
				desired = "idle"
			end

			if desired ~= currentAnimState then
				if currentAnimState and animTracks[currentAnimState] then
					animTracks[currentAnimState]:Stop()
				end
				if desired and animTracks[desired] then
					animTracks[desired]:Play()
				end
				currentAnimState = desired
			end
		end
		-- ========================================================
	end)
end

------------------------------------------------------------
-- Character respawn hone par disguise reset kar do
------------------------------------------------------------
player.CharacterAdded:Connect(function()
	clearDisguise()
end)

------------------------------------------------------------
-- ================= GUI ================= 
------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonsterDisguiseGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 320)
mainFrame.Position = UDim2.new(0, 20, 0.5, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Monster Disguise"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = mainFrame

-- Top buttons: Refresh + Next/Cycle + Remove
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0.33, -4, 0, 28)
refreshBtn.Position = UDim2.new(0, 4, 0, 32)
refreshBtn.Text = "Refresh"
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextSize = 12
refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
refreshBtn.TextColor3 = Color3.new(1, 1, 1)
refreshBtn.Parent = mainFrame

local nextBtn = Instance.new("TextButton")
nextBtn.Size = UDim2.new(0.33, -4, 0, 28)
nextBtn.Position = UDim2.new(0.335, 0, 0, 32)
nextBtn.Text = "Next ▶"
nextBtn.Font = Enum.Font.Gotham
nextBtn.TextSize = 12
nextBtn.BackgroundColor3 = Color3.fromRGB(50, 170, 90)
nextBtn.TextColor3 = Color3.new(1, 1, 1)
nextBtn.Parent = mainFrame

local removeBtn = Instance.new("TextButton")
removeBtn.Size = UDim2.new(0.33, -4, 0, 28)
removeBtn.Position = UDim2.new(0.67, 0, 0, 32)
removeBtn.Text = "Reset Me"
removeBtn.Font = Enum.Font.Gotham
removeBtn.TextSize = 12
removeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
removeBtn.TextColor3 = Color3.new(1, 1, 1)
removeBtn.Parent = mainFrame

for _, b in ipairs({refreshBtn, nextBtn, removeBtn}) do
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = b
end

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -8, 1, -70)
scrollFrame.Position = UDim2.new(0, 4, 0, 66)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

------------------------------------------------------------
-- Populate list of buttons (ek per NPC/monster)
------------------------------------------------------------
local function populateList()
	-- purane buttons hatao
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	monsterList = findMonsters()
	currentIndex = 0

	if #monsterList == 0 then
		local noneLabel = Instance.new("TextLabel")
		noneLabel.Size = UDim2.new(1, 0, 0, 26)
		noneLabel.BackgroundTransparency = 1
		noneLabel.Text = "Koi NPC/Monster nahi mila"
		noneLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		noneLabel.Font = Enum.Font.Gotham
		noneLabel.TextSize = 12
		noneLabel.Parent = scrollFrame
		return
	end

	for i, npc in ipairs(monsterList) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 26)
		btn.LayoutOrder = i
		btn.Text = npc.Name
		btn.Font = Enum.Font.Gotham
		btn.TextSize = 13
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Parent = scrollFrame

		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 5)
		c.Parent = btn

		btn.MouseButton1Click:Connect(function()
			currentIndex = i
			disguiseAs(npc)
		end)
	end
end

------------------------------------------------------------
-- Button events
------------------------------------------------------------
refreshBtn.MouseButton1Click:Connect(populateList)

removeBtn.MouseButton1Click:Connect(clearDisguise)

nextBtn.MouseButton1Click:Connect(function()
	if #monsterList == 0 then
		populateList()
		if #monsterList == 0 then return end
	end
	currentIndex = currentIndex + 1
	if currentIndex > #monsterList then
		currentIndex = 1
	end
	local npc = monsterList[currentIndex]
	if npc then
		disguiseAs(npc)
	end
end)

-- pehli baar list bana do
populateList()
