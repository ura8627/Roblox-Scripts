--[[
    NPC / MONSTER DISGUISE — LOCAL ONLY (Video Recording ke liye)
    ---------------------------------------------------------------
    - Yeh sirf APKO nazar aayega, dusre players ko nahi (ban-free, kyunke
      server ko kuch bheja hi nahi jata — sirf aapke apne client par
      Transparency change hoti hai, jo LocalTransparencyModifier se
      hoti hai aur kabhi server tak replicate nahi hoti).
    - GUI khud workspace scan karke sare NPC/Monster dhoondh leta hai
      (kisi Model jis mein Humanoid YA AnimationController ho).
    - Button click karke us NPC ki "body" pehen lete hain (visual clone
      aapke character ke sath follow karta hai, feet floor ke barabar
      rehte hain chahe monster kitna bhi bada/chota ho).
    - ANIMATIONS (idle/walk/run/attack waghera) — chahe woh Humanoid-based
      rig ho ya CUSTOM non-Humanoid rig jiski AnimationId scripts ke
      andar HARDCODED/PRIVATE ho — hum unko "chura" nahi rahe, balke
      jab asal NPC (jo world mein waise hi chal raha hai) apni koi bhi
      animation play karta hai, uska AnimationTrack live capture karke
      wahi ID apne clone par use kar lete hain. Yeh kaam karta hai
      kyunke AnimationTrack.Animation.AnimationId hamesha kisi bhi
      script ko dikhta hai — chahe original ID kahin bhi (script ke
      andar hardcoded) se aayi ho.
    - "Next / Cycle" button se baar baar switch kar sakte ho.
    - Har captured animation ka apna manual button bhi ban jata hai
      (Idle/Walk ke ilawa Attack/Roar waghera bhi try kar sakte ho).

    KAHAN RAKHNA HAI:
    StarterPlayer -> StarterPlayerScripts -> yahan is LocalScript ko daal dein.
]]

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local currentDisguise    = nil
local renderConn         = nil
local monsterList        = {}
local currentIndex       = 0

local cloneAnimator      = nil   -- Animator jo hamare clone par lagi hai
local capturedAnimIds    = {}    -- name -> AnimationId  (jo bhi original NPC se milin)
local capturedAnimLooped = {}    -- name -> bool
local capturedAnimNames  = {}    -- set, duplicate button rokne ke liye
local liveTracks         = {}    -- name -> AnimationTrack (clone par loaded)
local currentAnimState   = nil   -- filhal konsa naam chal raha hai
local autoCategoryToName = {}    -- "idle"/"walk"/"run"/"jump"/"fall" -> captured name
local npcAnimListenConn  = nil   -- asal NPC ke Animator ko sunne wala connection

local ANIM_CATEGORIES = {"idle", "walk", "run", "jump", "fall", "climb", "swim", "attack", "roar", "death"}

local animListFrame = nil -- GUI: captured animations ka list (dynamic buttons)

------------------------------------------------------------
-- FIND ALL NPC / MONSTERS IN WORKSPACE
-- (Humanoid wale ya AnimationController wale, dono tarah ke rig)
------------------------------------------------------------
local function findMonsters()
	local list = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") then
			local hasHumanoid = obj:FindFirstChildOfClass("Humanoid") ~= nil
			local hasAnimController = obj:FindFirstChildOfClass("AnimationController") ~= nil
			if hasHumanoid or hasAnimController then
				if not Players:GetPlayerFromCharacter(obj) then
					table.insert(list, obj)
				end
			end
		end
	end
	return list
end

------------------------------------------------------------
-- Kisi bhi model ke andar se pehla Animator dhoondo
-- (Humanoid ke andar ho ya AnimationController ke andar)
------------------------------------------------------------
local function findAnimatorIn(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Animator") then
			return d
		end
	end
	return nil
end

------------------------------------------------------------
-- Apne clone ke liye Animator taiyar karo (Humanoid ho ya na ho)
------------------------------------------------------------
local function setupCloneAnimator(clone)
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end
		return animator
	end

	-- Non-Humanoid custom rig -> AnimationController use karo
	local ac = clone:FindFirstChildOfClass("AnimationController")
	if not ac then
		ac = Instance.new("AnimationController")
		ac.Parent = clone
	end
	local animator = ac:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = ac
	end
	return animator
end

------------------------------------------------------------
-- GUI mein ek captured-animation ka button add karo
------------------------------------------------------------
local function addCapturedAnimButton(name, id, looped)
	if not animListFrame then return end

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 24)
	btn.Text = "▶ " .. name
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 12
	btn.BackgroundColor3 = Color3.fromRGB(60, 45, 80)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Parent = animListFrame

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 5)
	c.Parent = btn

	btn.MouseButton1Click:Connect(function()
		if not cloneAnimator then return end

		if not liveTracks[name] then
			local animObj = Instance.new("Animation")
			animObj.AnimationId = id
			local ok, track = pcall(function()
				return cloneAnimator:LoadAnimation(animObj)
			end)
			if ok and track then
				track.Looped = looped
				liveTracks[name] = track
			end
		end

		local track = liveTracks[name]
		if track then
			if currentAnimState and liveTracks[currentAnimState] and liveTracks[currentAnimState] ~= track then
				liveTracks[currentAnimState]:Stop()
			end
			track:Play()
			currentAnimState = name
		end
	end)
end

------------------------------------------------------------
-- Jab bhi asal NPC koi animation play kare, usko capture karo
------------------------------------------------------------
local function handleCapturedTrack(track)
	if not track or not track.Animation then return end
	local id = track.Animation.AnimationId
	if not id or id == "" then return end

	local name = (track.Name ~= "" and track.Name) or track.Animation.Name
	if name == "" then name = "Animation" end
	if capturedAnimNames[name] then return end -- pehle se capture ho chuki

	capturedAnimNames[name]  = true
	capturedAnimIds[name]    = id
	capturedAnimLooped[name] = track.Looped

	addCapturedAnimButton(name, id, track.Looped)

	-- Naam se andaza lagao ke yeh idle/walk/run mein se konsi category hai,
	-- taake movement ke sath auto-sync ho sake
	local lname = name:lower()
	for _, cat in ipairs(ANIM_CATEGORIES) do
		if not autoCategoryToName[cat] and lname:find(cat, 1, true) then
			autoCategoryToName[cat] = name
		end
	end
end

------------------------------------------------------------
-- CLEAR / REMOVE DISGUISE (wapas apni asli body)
------------------------------------------------------------
local function clearDisguise()
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
	if npcAnimListenConn then
		npcAnimListenConn:Disconnect()
		npcAnimListenConn = nil
	end
	if currentDisguise then
		currentDisguise:Destroy()
		currentDisguise = nil
	end

	cloneAnimator      = nil
	capturedAnimIds    = {}
	capturedAnimLooped = {}
	capturedAnimNames  = {}
	liveTracks         = {}
	currentAnimState   = nil
	autoCategoryToName = {}

	if animListFrame then
		for _, child in ipairs(animListFrame:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
	end

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

	-- Scripts hata do taake NPC ka AI dubara chalna shuru na ho
	-- (animation IDs hum ab live-capture se lenge, script padhne ki zaroorat nahi)
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
		or clone:FindFirstChild("Root")
		or clone:FindFirstChild("Head")
		or clone:FindFirstChildWhichIsA("BasePart", true)

	if not clonePrimary then
		clone:Destroy()
		warn("Is NPC ka koi valid PrimaryPart/BasePart nahi mila")
		return
	end
	clone.PrimaryPart = clonePrimary
	clone.Parent = workspace
	currentDisguise = clone

	-- ===== FEET/GROUND ALIGNMENT FIX =====
	local function getBottomY(model)
		local cf, size = model:GetBoundingBox()
		return cf.Position.Y - (size.Y / 2)
	end

	local playerFootOffset = root.Position.Y - getBottomY(char)
	local cloneFootOffset  = clonePrimary.Position.Y - getBottomY(clone)
	local yAdjust = cloneFootOffset - playerFootOffset
	-- =======================================

	-- ===== ANIMATOR SETUP (Humanoid ho ya custom non-Humanoid rig) =====
	cloneAnimator = setupCloneAnimator(clone)

	-- Asal NPC (npcModel, jo world mein abhi bhi khud chal raha hai) ke
	-- Animator ko dhoondo aur uski animations "sunna" shuru kar do
	local npcAnimator = findAnimatorIn(npcModel)
	if npcAnimator then
		-- Jo already chal rahi hai (jaise Idle) usko turant capture karo
		for _, t in ipairs(npcAnimator:GetPlayingAnimationTracks()) do
			handleCapturedTrack(t)
		end
		-- Aage jo bhi nayi animation play hogi (Walk, Attack, Roar...) usko bhi capture karte raho
		npcAnimListenConn = npcAnimator.AnimationPlayed:Connect(handleCapturedTrack)
	else
		warn("Is NPC ka Animator nahi mila — shayad yeh sirf Motor6D se manually move hota hai (animation capture nahi ho sakegi, sirf pose milega)")
	end
	-- ======================================================================

	local playerHum = char:FindFirstChildOfClass("Humanoid")

	-- Har frame: clone ko follow karao, asli character chupao, aur
	-- (agar naam se pata chal jaye) movement ke hisaab se animation switch karo
	renderConn = RunService.RenderStepped:Connect(function()
		if root.Parent and clonePrimary.Parent then
			clone:SetPrimaryPartCFrame(root.CFrame + Vector3.new(0, yAdjust, 0))
		end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("Decal") then
				part.LocalTransparencyModifier = 1
			end
		end

		if playerHum and cloneAnimator then
			local desiredCat = nil
			local hState = playerHum:GetState()
			local speed = playerHum.MoveDirection.Magnitude

			if hState == Enum.HumanoidStateType.Jumping and autoCategoryToName.jump then
				desiredCat = "jump"
			elseif hState == Enum.HumanoidStateType.Freefall and autoCategoryToName.fall then
				desiredCat = "fall"
			elseif speed > 0.05 then
				if playerHum.WalkSpeed > 20 and autoCategoryToName.run then
					desiredCat = "run"
				elseif autoCategoryToName.walk then
					desiredCat = "walk"
				elseif autoCategoryToName.run then
					desiredCat = "run"
				end
			elseif autoCategoryToName.idle then
				desiredCat = "idle"
			end

			local desiredName = desiredCat and autoCategoryToName[desiredCat] or nil

			if desiredName and desiredName ~= currentAnimState then
				if not liveTracks[desiredName] then
					local animObj = Instance.new("Animation")
					animObj.AnimationId = capturedAnimIds[desiredName]
					local ok, track = pcall(function()
						return cloneAnimator:LoadAnimation(animObj)
					end)
					if ok and track then
						track.Looped = capturedAnimLooped[desiredName]
						liveTracks[desiredName] = track
					end
				end
				local newTrack = liveTracks[desiredName]
				if newTrack then
					if currentAnimState and liveTracks[currentAnimState] then
						liveTracks[currentAnimState]:Stop()
					end
					newTrack:Play()
					currentAnimState = desiredName
				end
			end
		end
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
mainFrame.Size = UDim2.new(0, 260, 0, 460)
mainFrame.Position = UDim2.new(0, 20, 0.5, -230)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Text = "Monster Disguise"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = mainFrame

-- Top buttons: Refresh + Next/Cycle + Remove
local refreshBtn = Instance.new("TextButton")
refreshBtn.Size = UDim2.new(0.33, -4, 0, 26)
refreshBtn.Position = UDim2.new(0, 4, 0, 28)
refreshBtn.Text = "Refresh"
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextSize = 12
refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
refreshBtn.TextColor3 = Color3.new(1, 1, 1)
refreshBtn.Parent = mainFrame

local nextBtn = Instance.new("TextButton")
nextBtn.Size = UDim2.new(0.33, -4, 0, 26)
nextBtn.Position = UDim2.new(0.335, 0, 0, 28)
nextBtn.Text = "Next ▶"
nextBtn.Font = Enum.Font.Gotham
nextBtn.TextSize = 12
nextBtn.BackgroundColor3 = Color3.fromRGB(50, 170, 90)
nextBtn.TextColor3 = Color3.new(1, 1, 1)
nextBtn.Parent = mainFrame

local removeBtn = Instance.new("TextButton")
removeBtn.Size = UDim2.new(0.33, -4, 0, 26)
removeBtn.Position = UDim2.new(0.67, 0, 0, 28)
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

-- Monster list label
local monsterLabel = Instance.new("TextLabel")
monsterLabel.Size = UDim2.new(1, 0, 0, 18)
monsterLabel.Position = UDim2.new(0, 4, 0, 58)
monsterLabel.BackgroundTransparency = 1
monsterLabel.Text = "NPCs / Monsters:"
monsterLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
monsterLabel.Font = Enum.Font.GothamBold
monsterLabel.TextSize = 12
monsterLabel.TextXAlignment = Enum.TextXAlignment.Left
monsterLabel.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -8, 0, 160)
scrollFrame.Position = UDim2.new(0, 4, 0, 78)
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

-- Captured animations label + list
local animLabel = Instance.new("TextLabel")
animLabel.Size = UDim2.new(1, 0, 0, 18)
animLabel.Position = UDim2.new(0, 4, 0, 244)
animLabel.BackgroundTransparency = 1
animLabel.Text = "Live-captured Animations:"
animLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
animLabel.Font = Enum.Font.GothamBold
animLabel.TextSize = 12
animLabel.TextXAlignment = Enum.TextXAlignment.Left
animLabel.Parent = mainFrame

animListFrame = Instance.new("ScrollingFrame")
animListFrame.Size = UDim2.new(1, -8, 1, -270)
animListFrame.Position = UDim2.new(0, 4, 0, 264)
animListFrame.BackgroundTransparency = 1
animListFrame.BorderSizePixel = 0
animListFrame.ScrollBarThickness = 6
animListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
animListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
animListFrame.Parent = mainFrame

local animListLayout = Instance.new("UIListLayout")
animListLayout.Padding = UDim.new(0, 4)
animListLayout.SortOrder = Enum.SortOrder.LayoutOrder
animListLayout.Parent = animListFrame

------------------------------------------------------------
-- Populate list of buttons (ek per NPC/monster)
------------------------------------------------------------
local function populateList()
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
