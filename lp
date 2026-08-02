-- ============================================================
-- 自动升级脚本（UI模板基于矿石透视脚本）
-- 功能：自动接取任务 → 传送到NPC上方 → 自动攻击 → 循环
-- ============================================================

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local starterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local Camera = workspace.CurrentCamera

local function createUI()
    local success, err = pcall(function()

        -- 清理旧UI
        local old = playerGui:FindFirstChild("AutoLevelBG")
        if old then old:Destroy() end
        old = playerGui:FindFirstChild("AutoLevelUI")
        if old then old:Destroy() end
        old = playerGui:FindFirstChild("AutoLevelCtrl")
        if old then old:Destroy() end

        -- ============================================================
        -- 所有变量提前声明（避免Lua闭包作用域问题）
        -- ============================================================
        local autoLevelActive = false
        local levelHeight = 10
        local currentTarget = nil
        local attackHeartbeat = nil
        local questRemote = nil
        local questFrameRef = nil
        local currentNPCName = ""
        local sliderDragging = false
        local questVisConnection = nil
        local toggleBtnRef = nil
        local statusLabelRef = nil
        local tpPart = nil  -- 传送用Part
        local selectedWeaponName = "无"  -- 选中的武器名（提前声明，startAttack能访问）
        local equipWeapon  -- 装备武器函数（提前声明）
        local autoBossActive = false
        local bossAttackHeartbeat = nil
        local selectedBossKey = ""
        local bossDropdownOpen = false
        local bossDropdownRef = nil
        local bossStatusLabelRef = nil
        local autoSummonedActive = false
        local summonedAttackHeartbeat = nil
        local selectedSummonedKey = ""
        local summonedDropdownOpen = false
        local summonedDropdownRef = nil
        local summonedStatusLabelRef = nil
        local autoSummonAttackActive = false
        local summonAttackHeartbeat = nil
        local selectedSummonAttackKey = ""
        local summonAttackDropdownOpen = false
        local summonAttackDropdownRef = nil
        local autoFarmActive = false
        local farmAttackHeartbeat = nil
        local selectedFarmKey = ""
        local farmDropdownOpen = false
        local farmDropdownRef = nil
        local autoSmallBossActive = false
        local smallBossAttackHeartbeat = nil
        local selectedSmallBossKey = ""
        local smallBossDropdownOpen = false
        local smallBossDropdownRef = nil
                local transparencyElements = {}
                local autoStatLabels = {}

        -- ============================================================
        -- 背景样式判定：10% 动画（特殊），90% 图片（正常）
        -- ============================================================
        local isSpecialUI = (math.random(1, 100) <= 10)
        local hs = isSpecialUI and "♡" or ""

        -- ============================================================
        -- 第一层：独立的背景 ScreenGui（DisplayOrder 低 = 渲染在后面）
        -- ============================================================
        local animGui = Instance.new("ScreenGui")
        animGui.Name = "AutoLevelBG"
        animGui.DisplayOrder = 1
        animGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        animGui.IgnoreGuiInset = true
        animGui.ResetOnSpawn = false
        animGui.Parent = playerGui

        if not isSpecialUI then
            -- 正常 UI（90%）：图片背景 + 淡蓝色填充
            local normalBg = Instance.new("Frame")
            normalBg.Size = UDim2.new(0, 600, 0, 300)
            normalBg.Position = UDim2.new(0.5, -300, 0.5, -150)
            normalBg.BackgroundColor3 = Color3.fromRGB(173, 216, 230)
            normalBg.BackgroundTransparency = 1
            normalBg.ZIndex = 0
            normalBg.Parent = animGui

            local normalImg = Instance.new("ImageLabel")
            normalImg.Size = UDim2.new(0, 600, 0, 300)
            normalImg.Position = UDim2.new(0.5, -300, 0.5, -150)
            normalImg.BackgroundTransparency = 1
            normalImg.ImageTransparency = 1
            normalImg.ZIndex = 1
            normalImg.ScaleType = Enum.ScaleType.Stretch
            normalImg.Parent = animGui

            task.spawn(function()
                local NORMAL_URL = "https://ghfast.top/https://raw.githubusercontent.com/sssbbb3ryf/h-h-h/main/bg.jpg"
                local NORMAL_FILE = "autolevel_bg_v2.jpg"
                -- 优先用缓存（getcustomasset）
                local loaded = false
                if isfile(NORMAL_FILE) then
                    local assetUrl = getcustomasset(NORMAL_FILE)
                    if assetUrl and assetUrl ~= "" then
                        normalImg.Image = assetUrl
                        normalImg.ImageTransparency = 0
                        loaded = true
                        print("[自动升级] 图片背景已从缓存加载")
                    end
                end
                -- 缓存失败或没有缓存，直接用URL
                if not loaded then
                    normalImg.Image = NORMAL_URL
                    normalImg.ImageTransparency = 0
                    print("[自动升级] 图片背景使用在线URL")
                end
                -- 后台下载更新缓存（不影响显示）
                pcall(function()
                    local data = game:HttpGet(NORMAL_URL)
                    if data and #data > 1000 then
                        writefile(NORMAL_FILE, data)
                        print("[自动升级] 图片缓存已更新，大小:", #data)
                    end
                end)
            end)
        end

        -- ============================================================
        -- 动画：多Label方案（每帧独立Label，Image只设一次，绝不闪烁）
        -- ============================================================
        local GITEE_BASE = "https://gitee.com/xsadad_0/roxy/raw/main/"
        local ANIM_TOTAL = 152
        local CACHE_FOLDER = "anim_bg_cache"
        if makefolder then makefolder(CACHE_FOLDER) end

        if isSpecialUI then
            -- 创建152个独立ImageLabel
            local bgFrames = {}
            for i = 1, ANIM_TOTAL do
                local lbl = Instance.new("ImageLabel")
                lbl.Name = "BgF" .. i
                lbl.Size = UDim2.new(0, 600, 0, 300)
                lbl.Position = UDim2.new(0.5, -300, 0.5, -150)
                lbl.BackgroundTransparency = 1
                lbl.ImageTransparency = 1
                lbl.ZIndex = 1
                lbl.ScaleType = Enum.ScaleType.Stretch
                lbl.Parent = animGui
                bgFrames[i] = lbl
            end

            -- 构建帧URL列表 + 设置Image
            for i = 1, ANIM_TOTAL do
                local fname = string.format("frame_%04d.jpg", i)
                local fpath = CACHE_FOLDER .. "/" .. fname
                if isfile and isfile(fpath) and readfile and getcustomasset then
                    bgFrames[i].Image = getcustomasset(fpath)
                else
                    bgFrames[i].Image = GITEE_BASE .. fname
                    task.spawn(function()
                        local ok, data = pcall(function()
                            return game:HttpGet(GITEE_BASE .. fname)
                        end)
                        if ok and data and #data > 100 then
                            pcall(function() writefile(fpath, data) end)
                        end
                    end)
                end
            end

            bgFrames[1].ImageTransparency = 0
            print("[自动升级] 第一帧已显示")

            -- 后台预加载
            task.spawn(function()
                print("[自动升级] 后台预加载 " .. ANIM_TOTAL .. " 帧...")
                local ContentProvider = game:GetService("ContentProvider")
                local PRELOAD_BATCH = 10
                for batchStart = 1, ANIM_TOTAL, PRELOAD_BATCH do
                    local batchEnd = math.min(batchStart + PRELOAD_BATCH - 1, ANIM_TOTAL)
                    local batch = {}
                    for i = batchStart, batchEnd do
                        batch[#batch + 1] = bgFrames[i]
                    end
                    pcall(function()
                        ContentProvider:PreloadAsync(batch)
                    end)
                    task.wait(0.01)
                end
                print("[自动升级] 后台预加载完成")
            end)

            -- 播放循环
            task.spawn(function()
                local cur = 1
                local FPS = 30
                local interval = 1 / FPS
                while true do
                    if not animGui or not animGui.Parent then break end
                    local frameStart = tick()
                    local nextIdx = cur + 1
                    if nextIdx > ANIM_TOTAL then nextIdx = 1 end
                    bgFrames[nextIdx].ImageTransparency = 0
                    bgFrames[cur].ImageTransparency = 1
                    cur = nextIdx
                    local elapsed = tick() - frameStart
                    if elapsed < interval then
                        task.wait(interval - elapsed)
                    end
                end
            end)
        end -- if isSpecialUI

        -- ============================================================
        -- 第二层：UI 面板 ScreenGui（DisplayOrder 高 = 渲染在前面）
        -- ============================================================
        local gui = Instance.new("ScreenGui")
        gui.Name = "AutoLevelUI"
        gui.DisplayOrder = 10
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.IgnoreGuiInset = true
        gui.ResetOnSpawn = false
        gui.Parent = playerGui

        local mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, 600, 0, 300)
        mainFrame.Position = UDim2.new(0.5, -300, 0.5, -150)
        mainFrame.BackgroundTransparency = 1
        mainFrame.ZIndex = 100
        mainFrame.Parent = gui

        -- 左侧面板
        local leftPanel = Instance.new("Frame")
        leftPanel.Size = UDim2.new(0, 150, 1, 0)
        leftPanel.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        leftPanel.BackgroundTransparency = 1
        leftPanel.ZIndex = 10
        leftPanel.Parent = mainFrame

        -- 右侧面板
        local rightPanel = Instance.new("Frame")
        rightPanel.Size = UDim2.new(1, -160, 1, -10)
        rightPanel.Position = UDim2.new(0, 160, 0, 5)
        rightPanel.BackgroundTransparency = 1
        rightPanel.ZIndex = 10
        rightPanel.Parent = mainFrame

        -- 左侧按钮
        local btn1 = Instance.new("TextButton")
        btn1.Size = UDim2.new(1, -10, 0, 40)
        btn1.Position = UDim2.new(0, 5, 0, 10)
        btn1.Text = "自动" .. hs
        btn1.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn1.TextColor3 = Color3.fromRGB(255, 182, 193)
        btn1.BackgroundTransparency = 0.65
        btn1.TextTransparency = 0.65
        btn1.ZIndex = 11
        btn1.Parent = leftPanel

        -- 左侧按钮2：自动加点
        local btn2 = Instance.new("TextButton")
        btn2.Size = UDim2.new(1, -10, 0, 40)
        btn2.Position = UDim2.new(0, 5, 0, 55)
        btn2.Text = "加点" .. hs
        btn2.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        btn2.TextColor3 = Color3.fromRGB(255, 182, 193)
        btn2.BackgroundTransparency = 0.65
        btn2.TextTransparency = 0.65
        btn2.ZIndex = 11
        btn2.Parent = leftPanel

        -- 选项卡：自动
        local tab1 = Instance.new("Frame")
        tab1.Size = UDim2.new(1, 0, 1, 0)
        tab1.BackgroundTransparency = 1
        tab1.ZIndex = 10
        tab1.Parent = rightPanel

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.ZIndex = 10
        scroll.Parent = tab1
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.ScrollBarThickness = 4
        scroll.ScrollBarImageColor3 = Color3.fromHSV(0, 1, 1)
        scroll.ScrollBarImageTransparency = 0.3

        -- 选项卡：自动加点
        local tab2 = Instance.new("Frame")
        tab2.Size = UDim2.new(1, 0, 1, 0)
        tab2.BackgroundTransparency = 1
        tab2.ZIndex = 10
        tab2.Visible = false
        tab2.Parent = rightPanel

        local scroll2 = Instance.new("ScrollingFrame")
        scroll2.Size = UDim2.new(1, 0, 1, 0)
        scroll2.BackgroundTransparency = 1
        scroll2.ZIndex = 10
        scroll2.Parent = tab2
        scroll2.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll2.ScrollBarThickness = 4
        scroll2.ScrollBarImageColor3 = Color3.fromHSV(0, 1, 1)
        scroll2.ScrollBarImageTransparency = 0.3

        -- 选项卡切换
        btn1.MouseButton1Click:Connect(function()
            tab1.Visible = true
            tab2.Visible = false
        end)
        btn2.MouseButton1Click:Connect(function()
            tab1.Visible = false
            tab2.Visible = true
        end)

        -- ============================================================
        -- 辅助函数
        -- ============================================================

        local lastKnownLevel = 0  -- 记住上次成功读取的等级

        local function getLevel()
            local ok, result = pcall(function()
                local sg = playerGui:WaitForChild("ScreenGui", 2)
                local hud = sg:WaitForChild("HUD", 2)
                local lv = hud:FindFirstChild("Level")
                if lv and lv.Text then
                    return tonumber(lv.Text:match("%d+")) or 0
                end
                return 0
            end)
            if ok and result and result > 0 then
                lastKnownLevel = result
                return result
            end
            return lastKnownLevel
        end

        local function getQuestRemote()
            if questRemote and questRemote.Parent then return questRemote end
            pcall(function()
                questRemote = ReplicatedStorage:WaitForChild("Packages", 9e9)
                    :WaitForChild("_Index", 9e9)
                    :WaitForChild("sleitnick_net@0.2.0", 9e9)
                    :WaitForChild("net", 9e9)
                    :WaitForChild("RE/QuestEvent", 9e9)
            end)
            return questRemote
        end

        local function getQuestFrame()
            if questFrameRef and questFrameRef.Parent then return questFrameRef end
            pcall(function()
                questFrameRef = playerGui:WaitForChild("ScreenGui", 5)
                    :WaitForChild("Quest", 5)
                    :WaitForChild("Container", 5)
                    :WaitForChild("QuestFrame", 5)
            end)
            return questFrameRef
        end

        local function fireQuest(id)
            local remote = getQuestRemote()
            if not remote then
                print("[自动升级] 未找到 QuestEvent")
                return false
            end
            local args = {
                [1] = "Request";
                [2] = { ["Id"] = id; };
            }
            local ok, e = pcall(function()
                remote:FireServer(unpack(args))
            end)
            if ok then
                print("[自动升级] 已接取任务 Id=" .. id)
            else
                warn("[自动升级] 任务请求失败:", e)
            end
            return ok
        end

        -- 安全获取目标位置（兼容Model和BasePart）
        local function getTargetPos(target)
            if not target then return nil end
            -- 方法1: GetPivot（Model通用，最可靠）
            local ok, p = pcall(function() return target:GetPivot().Position end)
            if ok and p then return p end
            -- 方法2: PrimaryPart
            ok, p = pcall(function()
                if target.PrimaryPart then return target.PrimaryPart.Position end
                return nil
            end)
            if ok and p then return p end
            -- 方法3: .Position（BasePart直接可用）
            ok, p = pcall(function() return target.Position end)
            if ok and p then return p end
            -- 方法4: 找HumanoidRootPart
            ok, p = pcall(function()
                local hrp = target:FindFirstChild("HumanoidRootPart")
                if hrp then return hrp.Position end
                return nil
            end)
            return ok and p or nil
        end

        -- 直接从用户给的路径获取NPC目标，必须确保是Model
        local function getTarget(npcName)
            local target = nil
            -- 精确路径（最快）
            pcall(function() target = workspace.Enemies[npcName] end)
            if target and target.Parent then
                local h = target:FindFirstChildWhichIsA("Humanoid")
                if h and h.Health > 0 then return target end
            end
            -- 精确路径失败，递归找存活的（只匹配Model）
            target = nil
            pcall(function()
                for _, c in workspace.Enemies:GetDescendants() do
                    if c:IsA("Model") and c.Name == npcName then
                        local h = c:FindFirstChildWhichIsA("Humanoid")
                        if h and h.Health > 0 then
                            target = c
                            break
                        end
                    end
                end
            end)
            return target
        end

        local function isAlive(npc)
            if not npc or not npc.Parent then return false end
            local hum = npc:FindFirstChildWhichIsA("Humanoid")
            return hum and hum.Health > 0
        end

        -- ============================================================
        -- 攻击逻辑：每帧直接传送到NPC头顶 + 点击攻击
        -- ============================================================

        local function stopAttack()
            currentTarget = nil
            if attackHeartbeat then
                attackHeartbeat:Disconnect()
                attackHeartbeat = nil
            end
            -- 清理传送Part
            if tpPart then
                pcall(function() tpPart:Destroy() end)
                tpPart = nil
            end
            -- 不传送回原位，玩家留在怪物的原地
        end

        local function startAttack(npcName)
            stopAttack()
            currentNPCName = npcName
            local lastClick = 0
            local lastDbg = 0
            local lastLockedCF = nil  -- 记录最后锁定的CFrame
            local lastReequip = 0      -- 上次重新装备武器的时间

            attackHeartbeat = RunService.Heartbeat:Connect(function()
                if not autoLevelActive then stopAttack() return end
                local char = player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                if currentTarget and not isAlive(currentTarget) then
                    currentTarget = nil
                end
                if not currentTarget then
                    currentTarget = getTarget(npcName)
                    if not currentTarget then
                        -- 没找到目标：锁在原位不掉落，不清速度防飞
                        pcall(function()
                            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            if lastLockedCF then
                                hrp.CFrame = lastLockedCF
                            end
                        end)
                        if statusLabelRef then statusLabelRef.Text = "等待 [" .. npcName .. "]" end
                        return
                    end
                    print("[自动升级] 锁定: " .. currentTarget.Name)
                else
                    -- 已锁定但每60帧才重新搜索（避免每帧GetDescendants卡顿）
                    if not isAlive(currentTarget) then
                        currentTarget = nil
                    end
                end

                local tp = getTargetPos(currentTarget)
                if not tp then
                    currentTarget = nil
                    -- 位置获取失败也锁在原位
                    pcall(function()
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        if lastLockedCF then
                            hrp.CFrame = lastLockedCF
                        end
                    end)
                    return
                end
                local now = tick()

                -- 每帧将角色固定在NPC头顶（对抗重力）
                local targetCF = CFrame.lookAt(
                    Vector3.new(tp.X, tp.Y + levelHeight, tp.Z), tp
                )
                pcall(function()
                    hrp.CFrame = targetCF
                    -- 清除物理速度，防止NPC死亡瞬间残留速度导致飞出
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end)
                lastLockedCF = targetCF  -- 记录，切换目标时用

                -- 每0.5秒点击攻击（不用CaptureController减负荷）
                if now - lastClick >= 0.5 then
                    lastClick = now
                    pcall(function()
                        VirtualUser:ClickButton1(Vector2.new(
                            Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
                        ))
                    end)
                end

                -- 每隔2秒检查武器是否还在手上，不在就重新装备（放最后，pcall防报错）
                if now - lastReequip >= 2 then
                    lastReequip = now
                    pcall(function()
                        if selectedWeaponName and selectedWeaponName ~= "无" then
                            local hasWeapon = false
                            for _, t in ipairs(char:GetChildren()) do
                                if t:IsA("Tool") and t.Name == selectedWeaponName then
                                    hasWeapon = true
                                    break
                                end
                            end
                            if not hasWeapon then
                                equipWeapon(selectedWeaponName)
                            end
                        end
                    end)
                end

                -- 每5秒显示距离
                if now - lastDbg >= 5 then
                    lastDbg = now
                    local d = (hrp.Position - tp).Magnitude
                    if statusLabelRef then
                        statusLabelRef.Text = currentTarget.Name .. " " .. string.format("%.0f", d) .. "m"
                    end
                end
            end)
        end

        -- ============================================================
        -- BOSS 攻击逻辑（与自动升级共享传送攻击模式）
        -- ============================================================

        local function stopBossAttack()
            if bossAttackHeartbeat then
                bossAttackHeartbeat:Disconnect()
                bossAttackHeartbeat = nil
            end
        end

        local function getBossModel(bossKey)
            if bossKey == "Sung Jinwoo" then
                local ok, m = pcall(function() return workspace.Boss.ServerTimeBossSpawner["Sung Jinwoo"] end)
                if ok and m then
                    local h = m:FindFirstChildWhichIsA("Humanoid")
                    if h and h.Health > 0 then return m end
                end
            elseif bossKey == "Aizen" then
                local ok, m = pcall(function()
                    local a = workspace.Boss:FindFirstChild("Aizen")
                    return a and a:FindFirstChild("Aizen") or nil
                end)
                if ok and m then
                    local h = m:FindFirstChildWhichIsA("Humanoid")
                    if h and h.Health > 0 then return m end
                end
            end
            return nil
        end

        local function getAliveBosses()
            local bosses = {}
            pcall(function()
                local sjw = workspace.Boss.ServerTimeBossSpawner:FindFirstChild("Sung Jinwoo")
                if sjw then
                    local h = sjw:FindFirstChildWhichIsA("Humanoid")
                    if h and h.Health > 0 then
                        table.insert(bosses, {key = "Sung Jinwoo", display = "程肖宇"})
                    end
                end
                local aizen = workspace.Boss:FindFirstChild("Aizen")
                if aizen then
                    aizen = aizen:FindFirstChild("Aizen")
                end
                if aizen then
                    local h = aizen:FindFirstChildWhichIsA("Humanoid")
                    if h and h.Health > 0 then
                        table.insert(bosses, {key = "Aizen", display = "蓝染"})
                    end
                end
            end)
            return bosses
        end

        local function startBossAttack()
            stopBossAttack()
            local lastClick = 0
            local lastLockedCF = nil
            local lastReequip = 0

            bossAttackHeartbeat = RunService.Heartbeat:Connect(function()
                if not autoBossActive then stopBossAttack() return end
                local char = player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local boss = getBossModel(selectedBossKey)
                if not boss then
                    pcall(function()
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        if lastLockedCF then hrp.CFrame = lastLockedCF end
                    end)
                    if bossStatusLabelRef then bossStatusLabelRef.Text = "等待BOSS刷新..." end
                    return
                end

                local tp = getTargetPos(boss)
                if not tp then return end
                local now = tick()

                local targetCF = CFrame.lookAt(
                    Vector3.new(tp.X, tp.Y + levelHeight, tp.Z), tp
                )
                pcall(function()
                    hrp.CFrame = targetCF
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end)
                lastLockedCF = targetCF

                if now - lastClick >= 0.5 then
                    lastClick = now
                    pcall(function()
                        VirtualUser:ClickButton1(Vector2.new(
                            Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
                        ))
                    end)
                end

                if now - lastReequip >= 2 then
                    lastReequip = now
                    pcall(function()
                        if selectedWeaponName and selectedWeaponName ~= "无" then
                            local hasWeapon = false
                            for _, t in ipairs(char:GetChildren()) do
                                if t:IsA("Tool") and t.Name == selectedWeaponName then
                                    hasWeapon = true
                                    break
                                end
                            end
                            if not hasWeapon then equipWeapon(selectedWeaponName) end
                        end
                    end)
                end

                if bossStatusLabelRef then
                    local hum = boss:FindFirstChildWhichIsA("Humanoid")
                    local hp = hum and math.floor(hum.Health) or 0
                    local maxHp = hum and math.floor(hum.MaxHealth) or 0
                    bossStatusLabelRef.Text = "攻击中 HP " .. hp .. "/" .. maxHp
                end
            end)
        end

        -- ============================================================
        -- 任务触发（QuestFrame不可见时执行）
        -- ============================================================

        local function triggerAutoLevel()
            if not autoLevelActive then return end
            local ok, err = pcall(function()
                local level = getLevel()
                if level <= 0 then
                    print("[自动升级] 等级读取失败，跳过本次")
                    if statusLabelRef then statusLabelRef.Text = "读取等级中..." end
                    return
                end
                print("[自动升级] Lv." .. level)
                local questId, npcName
                if level < 101 then
                    questId, npcName = 1, "bandit"
                elseif level <= 250 then
                    questId, npcName = 2, "Bandit Leader"
                elseif level <= 400 then
                    questId, npcName = 3, "Monkey"
                elseif level <= 600 then
                    questId, npcName = 4, "Shank"
                elseif level <= 800 then
                    questId, npcName = 8, "Snow Bandit"
                elseif level <= 1000 then
                    questId, npcName = 7, "Mihawk"
                elseif level <= 1300 then
                    questId, npcName = 9, "National Level Hunter"
                elseif level <= 1600 then
                    questId, npcName = 5, "Sorcerer Student"
                elseif level <= 2000 then
                    questId, npcName = 6, "Miwa"
                elseif level <= 2500 then
                    questId, npcName = 10, "Hollow"
                elseif level <= 3500 then
                    questId, npcName = 11, "Arrancar"
                else
                    autoLevelActive = false
                    if toggleBtnRef then toggleBtnRef.Text = "关闭" end
                    if statusLabelRef then statusLabelRef.Text = "等级超出" end
                    stopAttack()
                    return
                end
                if statusLabelRef then statusLabelRef.Text = "接任务 Id=" .. questId end
                fireQuest(questId)
                if statusLabelRef then statusLabelRef.Text = "启动攻击 [" .. npcName .. "]" end
                startAttack(npcName)
            end)
            if not ok then
                warn("[自动升级] 错误:", err)
                if statusLabelRef then statusLabelRef.Text = "错误" end
            end
        end

        -- ============================================================
        -- UI：自动升级功能块
        -- ============================================================

        local BLOCK_PAD = 5
        local ROW_H = 40
        local ROW_GAP = 3
        local HEADER_H = 20

        -- 功能块容器
        local autoBlock = Instance.new("Frame")
        autoBlock.Size = UDim2.new(1, -10, 0, 197)
        autoBlock.Position = UDim2.new(0, 5, 0, 5)
        autoBlock.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        autoBlock.BackgroundTransparency = 0.5
        autoBlock.ZIndex = 10
        local blockCorner = Instance.new("UICorner")
        blockCorner.CornerRadius = UDim.new(0, 6)
        blockCorner.Parent = autoBlock
        autoBlock.Parent = scroll
        table.insert(transparencyElements, autoBlock)

        -- 功能块标题
        local blockHeader = Instance.new("TextLabel")
        blockHeader.Size = UDim2.new(1, -10, 0, HEADER_H)
        blockHeader.Position = UDim2.new(0, 5, 0, BLOCK_PAD)
        blockHeader.Text = "自动升级"
        blockHeader.TextColor3 = Color3.fromRGB(255, 182, 193)
        blockHeader.TextTransparency = 0.65
        blockHeader.BackgroundTransparency = 1
        blockHeader.TextXAlignment = Enum.TextXAlignment.Left
        blockHeader.Font = Enum.Font.GothamBold
        blockHeader.TextSize = 14
        blockHeader.ZIndex = 12
        blockHeader.Parent = autoBlock
        table.insert(autoStatLabels, blockHeader)

        -- ============================================================
        -- UI：选择武器行
        -- ============================================================

        local WEAPON_ROW_H = ROW_H
        local DROPDOWN_MAX = 200  -- 下拉最大高度
        local weaponDropdownOpen = false
        local weaponDropdownRef = nil
        selectedWeaponName = "无"  -- 赋值（已在顶部声明）

        -- 获取玩家所有工具（背包+已装备）
        local function getToolNames()
            local names = {}
            local seen = {}
            -- 背包里的工具
            pcall(function()
                for _, tool in ipairs(player.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name and not seen[tool.Name] then
                        seen[tool.Name] = true
                        table.insert(names, tool.Name)
                    end
                end
            end)
            -- 已装备的工具
            pcall(function()
                if player.Character then
                    for _, tool in ipairs(player.Character:GetChildren()) do
                        if tool:IsA("Tool") and tool.Name and not seen[tool.Name] then
                            seen[tool.Name] = true
                            table.insert(names, tool.Name)
                        end
                    end
                end
            end)
            return names
        end

        -- 装备指定武器（赋值给顶部预声明的变量）
        equipWeapon = function(name)
            if not name or name == "无" then return end
            if not player.Character then return end
            -- 先从背包装备
            pcall(function()
                for _, tool in ipairs(player.Backpack:GetChildren()) do
                    if tool:IsA("Tool") and tool.Name == name then
                        tool.Parent = player.Character
                        print("[自动升级] 已装备: " .. name)
                        return
                    end
                end
            end)
        end

        -- 玩家重生后自动装备武器
        player.CharacterAdded:Connect(function(newChar)
            task.wait(1)  -- 等角色加载完
            if selectedWeaponName and selectedWeaponName ~= "无" then
                -- 等背包刷新
                local ok, _ = pcall(function()
                    for _, tool in ipairs(player.Backpack:GetChildren()) do
                        if tool:IsA("Tool") and tool.Name == selectedWeaponName then
                            tool.Parent = newChar
                            print("[自动升级] 重生后装备: " .. selectedWeaponName)
                            return
                        end
                    end
                end)
                if not ok then
                    -- 背包没找到，延迟再试一次
                    task.delay(2, function()
                        pcall(function()
                            for _, tool in ipairs(player.Backpack:GetChildren()) do
                                if tool:IsA("Tool") and tool.Name == selectedWeaponName then
                                    tool.Parent = player.Character
                                    print("[自动升级] 延迟装备: " .. selectedWeaponName)
                                    return
                                end
                            end
                        end)
                    end)
                end
            end
        end)

        local weaponRow = Instance.new("Frame")
        weaponRow.Size = UDim2.new(1, -10, 0, WEAPON_ROW_H)
        weaponRow.Position = UDim2.new(0, 5, 0, BLOCK_PAD + HEADER_H + ROW_GAP)
        weaponRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        weaponRow.BackgroundTransparency = 0.65
        weaponRow.ZIndex = 11
        weaponRow.Parent = autoBlock

        local weaponLabel = Instance.new("TextLabel")
        weaponLabel.Size = UDim2.new(0.5, 0, 1, 0)
        weaponLabel.Position = UDim2.new(0, 5, 0, 0)
        weaponLabel.Text = "选择武器"
        weaponLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
        weaponLabel.TextTransparency = 0.65
        weaponLabel.BackgroundTransparency = 1
        weaponLabel.TextXAlignment = Enum.TextXAlignment.Left
        weaponLabel.ZIndex = 12
        weaponLabel.Parent = weaponRow

        local weaponBtn = Instance.new("TextButton")
        weaponBtn.Size = UDim2.new(0.45, 0, 0.8, 0)
        weaponBtn.Position = UDim2.new(0.53, 0, 0.1, 0)
        weaponBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        weaponBtn.BackgroundTransparency = 0.65
        weaponBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
        weaponBtn.TextTransparency = 0.65
        weaponBtn.Text = selectedWeaponName
        weaponBtn.ZIndex = 12
        weaponBtn.Parent = weaponRow
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = weaponBtn

        -- 下拉列表容器
        local function closeDropdown()
            if weaponDropdownRef then
                weaponDropdownRef:Destroy()
                weaponDropdownRef = nil
            end
            weaponDropdownOpen = false
        end

        local function toggleDropdown()
            if weaponDropdownOpen then
                closeDropdown()
                return
            end
            -- 每次展开刷新数据
            local names = getToolNames()
            if #names == 0 then
                selectedWeaponName = "无"
                weaponBtn.Text = selectedWeaponName
                return
            end

            weaponDropdownOpen = true
            local dropFrame = Instance.new("ScrollingFrame")
            dropFrame.Name = "WeaponDropdown"
            dropFrame.Size = UDim2.new(0.45, 0, 0, math.min(#names * 28 + 4, DROPDOWN_MAX))
            local btnAbs = weaponBtn.AbsolutePosition
            local btnSz = weaponBtn.AbsoluteSize
            local mainAbs = mainFrame.AbsolutePosition
            dropFrame.Position = UDim2.new(0, btnAbs.X - mainAbs.X, 0, btnAbs.Y - mainAbs.Y + btnSz.Y + 2)
            dropFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            dropFrame.BackgroundTransparency = 0.2
            dropFrame.BorderSizePixel = 0
            dropFrame.ZIndex = 999
            dropFrame.ScrollBarThickness = 3
            dropFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 182, 193)
            dropFrame.CanvasSize = UDim2.new(0, 0, 0, #names * 28)
            dropFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
            dropFrame.Active = true
            local dropCorner = Instance.new("UICorner")
            dropCorner.CornerRadius = UDim.new(0, 4)
            dropCorner.Parent = dropFrame
            dropFrame.Parent = mainFrame
            weaponDropdownRef = dropFrame

            -- 点击外部关闭
            local closeConn
            closeConn = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    -- 检查是否点在下拉框外面
                    local pos = input.Position
                    local dropAbs = dropFrame.AbsolutePosition
                    local dropSize = dropFrame.AbsoluteSize
                    if pos.X < dropAbs.X or pos.X > dropAbs.X + dropSize.X
                        or pos.Y < dropAbs.Y or pos.Y > dropAbs.Y + dropSize.Y then
                        -- 也排除按钮本身
                        local btnAbs = weaponBtn.AbsolutePosition
                        local btnSize = weaponBtn.AbsoluteSize
                        if pos.X < btnAbs.X or pos.X > btnAbs.X + btnSize.X
                            or pos.Y < btnAbs.Y or pos.Y > btnAbs.Y + btnSize.Y then
                            closeDropdown()
                            if closeConn then closeConn:Disconnect() end
                        end
                    end
                end
            end)

            for i, name in ipairs(names) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -8, 0, 26)
                btn.Position = UDim2.new(0, 4, 0, (i - 1) * 28 + 2)
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.BackgroundTransparency = 0.4
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.TextTransparency = 0.2
                btn.Text = name
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 13
                btn.ZIndex = 1000
                btn.Parent = dropFrame
                local itemCorner = Instance.new("UICorner")
                itemCorner.CornerRadius = UDim.new(0, 3)
                itemCorner.Parent = btn

                -- 高亮已选中的
                if name == selectedWeaponName then
                    btn.BackgroundColor3 = Color3.fromRGB(255, 100, 130)
                    btn.BackgroundTransparency = 0.3
                end

                btn.MouseEnter:Connect(function()
                    if name ~= selectedWeaponName then
                        btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    end
                end)
                btn.MouseLeave:Connect(function()
                    if name ~= selectedWeaponName then
                        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    end
                end)

                btn.MouseButton1Click:Connect(function()
                    selectedWeaponName = name
                    weaponBtn.Text = name
                    equipWeapon(name)
                    closeDropdown()
                    if closeConn then closeConn:Disconnect() end
                end)
            end
        end

        weaponBtn.MouseButton1Click:Connect(toggleDropdown)

        -- ============================================================
        -- UI：自动升级开关行
        -- ============================================================

        local TOGGLE_Y = BLOCK_PAD + HEADER_H + ROW_GAP + WEAPON_ROW_H + ROW_GAP
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -10, 0, ROW_H)
        row.Position = UDim2.new(0, 5, 0, TOGGLE_Y)
        row.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        row.BackgroundTransparency = 0.65
        row.ZIndex = 11
        row.Parent = autoBlock

        local rowLabel = Instance.new("TextLabel")
        rowLabel.Size = UDim2.new(0.5, 0, 1, 0)
        rowLabel.Position = UDim2.new(0, 5, 0, 0)
        rowLabel.Text = "自动升级"
        rowLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
        rowLabel.TextTransparency = 0.65
        rowLabel.BackgroundTransparency = 1
        rowLabel.TextXAlignment = Enum.TextXAlignment.Left
        rowLabel.ZIndex = 12
        rowLabel.Parent = row

        toggleBtnRef = Instance.new("TextButton")
        toggleBtnRef.Size = UDim2.new(0.45, 0, 0.8, 0)
        toggleBtnRef.Position = UDim2.new(0.53, 0, 0.1, 0)
        toggleBtnRef.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        toggleBtnRef.BackgroundTransparency = 0.65
        toggleBtnRef.TextColor3 = Color3.fromRGB(255, 182, 193)
        toggleBtnRef.TextTransparency = 0.65
        toggleBtnRef.Text = "关闭"
        toggleBtnRef.ZIndex = 12
        toggleBtnRef.Parent = row
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 4)
        toggleCorner.Parent = toggleBtnRef

        -- ============================================================
        -- UI：高度滑条（夜视风格）
        -- ============================================================

        local SLIDER_Y = TOGGLE_Y + ROW_H + ROW_GAP
        local sliderContainer = Instance.new("Frame")
        sliderContainer.Size = UDim2.new(1, -10, 0, 55)
        sliderContainer.Position = UDim2.new(0, 5, 0, SLIDER_Y)
        sliderContainer.BackgroundTransparency = 1
        sliderContainer.ZIndex = 11
        sliderContainer.Parent = autoBlock

        local sliderLabel = Instance.new("TextLabel")
        sliderLabel.Size = UDim2.new(1, 0, 0, 20)
        sliderLabel.Position = UDim2.new(0, 0, 0, 0)
        sliderLabel.Text = "NPC上方高度: 10"
        sliderLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
        sliderLabel.TextTransparency = 0.65
        sliderLabel.BackgroundTransparency = 1
        sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
        sliderLabel.ZIndex = 12
        sliderLabel.Parent = sliderContainer

        local sliderTrack = Instance.new("Frame")
        sliderTrack.Size = UDim2.new(1, 0, 0, 8)
        sliderTrack.Position = UDim2.new(0, 0, 0, 28)
        sliderTrack.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        sliderTrack.BackgroundTransparency = 0.3
        sliderTrack.ZIndex = 12
        sliderTrack.Parent = sliderContainer
        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(0, 4)
        trackCorner.Parent = sliderTrack

        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new(0.111, 0, 1, 0)
        sliderFill.BackgroundColor3 = Color3.fromRGB(255, 182, 193)
        sliderFill.BackgroundTransparency = 0.3
        sliderFill.ZIndex = 13
        sliderFill.Parent = sliderTrack
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 4)
        fillCorner.Parent = sliderFill

        local sliderThumb = Instance.new("TextButton")
        sliderThumb.Size = UDim2.new(0, 18, 0, 18)
        sliderThumb.Position = UDim2.new(0.111, -9, 0.5, -9)
        sliderThumb.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        sliderThumb.Text = ""
        sliderThumb.ZIndex = 14
        sliderThumb.Parent = sliderTrack
        local thumbCorner = Instance.new("UICorner")
        thumbCorner.CornerRadius = UDim.new(1, 0)
        thumbCorner.Parent = sliderThumb

        -- 滑条逻辑
        local SLIDER_MIN = 1
        local SLIDER_MAX = 50

        local function updateSlider(val)
            levelHeight = math.clamp(math.floor(val + 0.5), SLIDER_MIN, SLIDER_MAX)
            local ratio = (levelHeight - SLIDER_MIN) / (SLIDER_MAX - SLIDER_MIN)
            sliderFill.Size = UDim2.new(ratio, 0, 1, 0)
            sliderThumb.Position = UDim2.new(ratio, -9, 0.5, -9)
            sliderLabel.Text = "NPC上方高度: " .. levelHeight
        end

        local function getValueFromX(x)
            if not sliderTrack or not sliderTrack.Parent then return SLIDER_MIN end
            local absX = sliderTrack.AbsolutePosition.X
            local absW = sliderTrack.AbsoluteSize.X
            if absW <= 0 then return SLIDER_MIN end
            local relX = math.clamp((x - absX) / absW, 0, 1)
            return SLIDER_MIN + relX * (SLIDER_MAX - SLIDER_MIN)
        end

        sliderThumb.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = true
            end
        end)

        sliderTrack.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = true
                updateSlider(getValueFromX(input.Position.X))
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                sliderDragging = false
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if not sliderDragging then return end
            if not sliderTrack or not sliderTrack.Parent then
                sliderDragging = false
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch then
                updateSlider(getValueFromX(input.Position.X))
            end
        end)

        -- ============================================================
        -- UI：状态标签
        -- ============================================================

        local STATUS_Y = SLIDER_Y + 55 + ROW_GAP
        statusLabelRef = Instance.new("TextLabel")
        statusLabelRef.Size = UDim2.new(1, -10, 0, 20)
        statusLabelRef.Position = UDim2.new(0, 5, 0, STATUS_Y)
        statusLabelRef.Text = "就绪"
        statusLabelRef.TextColor3 = Color3.fromRGB(200, 200, 200)
        statusLabelRef.TextTransparency = 0.65
        statusLabelRef.BackgroundTransparency = 1
        statusLabelRef.TextXAlignment = Enum.TextXAlignment.Left
        statusLabelRef.TextWrapped = true
        statusLabelRef.ZIndex = 12
        statusLabelRef.Parent = autoBlock

        -- ============================================================
        -- UI：自动BOSS功能块
        -- ============================================================

        local BOSS_BLOCK_Y = 5 + 197 + 20  -- autoBlock底部 + 半行间距
        local BOSS_ROW_H = ROW_H * 2  -- 2倍高 = 80
        local SUMMONED_ROW_H = ROW_H * 2  -- 2倍高 = 80
        local SUMMON_ATTACK_ROW_H = ROW_H * 2  -- 2倍高 = 80
        local BOSS_BLOCK_H = BLOCK_PAD + HEADER_H + ROW_GAP + BOSS_ROW_H + ROW_GAP + SUMMONED_ROW_H + ROW_GAP + SUMMON_ATTACK_ROW_H + ROW_GAP + 20 + BLOCK_PAD  -- 302

        local bossBlock = Instance.new("Frame")
        bossBlock.Size = UDim2.new(1, -10, 0, BOSS_BLOCK_H)
        bossBlock.Position = UDim2.new(0, 5, 0, BOSS_BLOCK_Y)
        bossBlock.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        bossBlock.BackgroundTransparency = 0.5
        bossBlock.ZIndex = 10
        local bossBlockCorner = Instance.new("UICorner")
        bossBlockCorner.CornerRadius = UDim.new(0, 6)
        bossBlockCorner.Parent = bossBlock
        bossBlock.Parent = scroll
        table.insert(transparencyElements, bossBlock)

        -- BOSS功能块标题
        local bossBlockHeader = Instance.new("TextLabel")
        bossBlockHeader.Size = UDim2.new(1, -10, 0, HEADER_H)
        bossBlockHeader.Position = UDim2.new(0, 5, 0, BLOCK_PAD)
        bossBlockHeader.Text = "自动BOSS"
        bossBlockHeader.TextColor3 = Color3.fromRGB(255, 182, 193)
        bossBlockHeader.TextTransparency = 0.65
        bossBlockHeader.BackgroundTransparency = 1
        bossBlockHeader.TextXAlignment = Enum.TextXAlignment.Left
        bossBlockHeader.Font = Enum.Font.GothamBold
        bossBlockHeader.TextSize = 14
        bossBlockHeader.ZIndex = 12
        bossBlockHeader.Parent = bossBlock
        table.insert(autoStatLabels, bossBlockHeader)

        -- BOSS行（2倍高）
        local bossRowY = BLOCK_PAD + HEADER_H + ROW_GAP
        local bossRow = Instance.new("Frame")
        bossRow.Size = UDim2.new(1, -10, 0, BOSS_ROW_H)
        bossRow.Position = UDim2.new(0, 5, 0, bossRowY)
        bossRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        bossRow.BackgroundTransparency = 0.65
        bossRow.ZIndex = 11
        bossRow.Parent = bossBlock
        table.insert(transparencyElements, bossRow)

        -- 左侧标签
        local bossLabel = Instance.new("TextLabel")
        bossLabel.Size = UDim2.new(0.3, 0, 1, 0)
        bossLabel.Position = UDim2.new(0, 5, 0, 0)
        bossLabel.Text = "世界BOSS"
        bossLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
        bossLabel.TextTransparency = 0.65
        bossLabel.BackgroundTransparency = 1
        bossLabel.TextXAlignment = Enum.TextXAlignment.Left
        bossLabel.ZIndex = 12
        bossLabel.Parent = bossRow
        table.insert(autoStatLabels, bossLabel)

        -- 右上：BOSS选择按钮
        local bossSelectBtn = Instance.new("TextButton")
        bossSelectBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
        bossSelectBtn.Position = UDim2.new(0.33, 0, 0.05, 0)
        bossSelectBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        bossSelectBtn.BackgroundTransparency = 0.65
        bossSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        bossSelectBtn.TextTransparency = 0.65
        bossSelectBtn.Text = "选择BOSS"
        bossSelectBtn.ZIndex = 12
        bossSelectBtn.Parent = bossRow
        local bossSelCorner = Instance.new("UICorner")
        bossSelCorner.CornerRadius = UDim.new(0, 4)
        bossSelCorner.Parent = bossSelectBtn
        table.insert(transparencyElements, bossSelectBtn)

        -- 右下：BOSS开关按钮
        local bossToggleBtn = Instance.new("TextButton")
        bossToggleBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
        bossToggleBtn.Position = UDim2.new(0.33, 0, 0.5, 0)
        bossToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        bossToggleBtn.BackgroundTransparency = 0.65
        bossToggleBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
        bossToggleBtn.TextTransparency = 0.65
        bossToggleBtn.Text = "关闭"
        bossToggleBtn.ZIndex = 12
        bossToggleBtn.Parent = bossRow
        local bossTogCorner = Instance.new("UICorner")
        bossTogCorner.CornerRadius = UDim.new(0, 4)
        bossTogCorner.Parent = bossToggleBtn
        table.insert(transparencyElements, bossToggleBtn)

        -- ============================================================
        -- 被召唤者行（2倍高）
        -- ============================================================

        local summonedRowY = bossRowY + BOSS_ROW_H + ROW_GAP
        local summonedRow = Instance.new("Frame")
        summonedRow.Size = UDim2.new(1, -10, 0, SUMMONED_ROW_H)
        summonedRow.Position = UDim2.new(0, 5, 0, summonedRowY)
        summonedRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        summonedRow.BackgroundTransparency = 0.65
        summonedRow.ZIndex = 11
        summonedRow.Parent = bossBlock
        table.insert(transparencyElements, summonedRow)

        -- 左侧标签
        local summonedLabel = Instance.new("TextLabel")
        summonedLabel.Size = UDim2.new(0.3, 0, 1, 0)
        summonedLabel.Position = UDim2.new(0, 5, 0, 0)
        summonedLabel.Text = "被召唤者"
        summonedLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
        summonedLabel.TextTransparency = 0.65
        summonedLabel.BackgroundTransparency = 1
        summonedLabel.TextXAlignment = Enum.TextXAlignment.Left
        summonedLabel.ZIndex = 12
        summonedLabel.Parent = summonedRow
        table.insert(autoStatLabels, summonedLabel)

        -- 右上：被召唤者选择按钮
        local summonedSelectBtn = Instance.new("TextButton")
        summonedSelectBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
        summonedSelectBtn.Position = UDim2.new(0.33, 0, 0.05, 0)
        summonedSelectBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        summonedSelectBtn.BackgroundTransparency = 0.65
        summonedSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        summonedSelectBtn.TextTransparency = 0.65
        summonedSelectBtn.Text = "选择BOSS"
        summonedSelectBtn.ZIndex = 12
        summonedSelectBtn.Parent = summonedRow
        local summonedSelCorner = Instance.new("UICorner")
        summonedSelCorner.CornerRadius = UDim.new(0, 4)
        summonedSelCorner.Parent = summonedSelectBtn
        table.insert(transparencyElements, summonedSelectBtn)

        -- 右下：被召唤者开关按钮
        local summonedToggleBtn = Instance.new("TextButton")
        summonedToggleBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
        summonedToggleBtn.Position = UDim2.new(0.33, 0, 0.5, 0)
        summonedToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        summonedToggleBtn.BackgroundTransparency = 0.65
        summonedToggleBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
        summonedToggleBtn.TextTransparency = 0.65
        summonedToggleBtn.Text = "关闭"
        summonedToggleBtn.ZIndex = 12
        summonedToggleBtn.Parent = summonedRow
        local summonedTogCorner = Instance.new("UICorner")
        summonedTogCorner.CornerRadius = UDim.new(0, 4)
        summonedTogCorner.Parent = summonedToggleBtn
        table.insert(transparencyElements, summonedToggleBtn)

        -- ============================================================
        -- 召唤攻击行（2倍高）
        -- ============================================================

        local summonAttackRowY = summonedRowY + SUMMONED_ROW_H + ROW_GAP
        local summonAttackRow = Instance.new("Frame")
        summonAttackRow.Size = UDim2.new(1, -10, 0, SUMMON_ATTACK_ROW_H)
        summonAttackRow.Position = UDim2.new(0, 5, 0, summonAttackRowY)
        summonAttackRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        summonAttackRow.BackgroundTransparency = 0.65
        summonAttackRow.ZIndex = 11
        summonAttackRow.Parent = bossBlock
        table.insert(transparencyElements, summonAttackRow)

        -- 左侧标签
        local summonAttackLabel = Instance.new("TextLabel")
        summonAttackLabel.Size = UDim2.new(0.3, 0, 1, 0)
        summonAttackLabel.Position = UDim2.new(0, 5, 0, 0)
        summonAttackLabel.Text = "召唤攻击"
        summonAttackLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
        summonAttackLabel.TextTransparency = 0.65
        summonAttackLabel.BackgroundTransparency = 1
        summonAttackLabel.TextXAlignment = Enum.TextXAlignment.Left
        summonAttackLabel.ZIndex = 12
        summonAttackLabel.Parent = summonAttackRow
        table.insert(autoStatLabels, summonAttackLabel)

        -- 右上：选择按钮
        local summonAttackSelectBtn = Instance.new("TextButton")
        summonAttackSelectBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
        summonAttackSelectBtn.Position = UDim2.new(0.33, 0, 0.05, 0)
        summonAttackSelectBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        summonAttackSelectBtn.BackgroundTransparency = 0.65
        summonAttackSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        summonAttackSelectBtn.TextTransparency = 0.65
        summonAttackSelectBtn.Text = "选择目标"
        summonAttackSelectBtn.ZIndex = 12
        summonAttackSelectBtn.Parent = summonAttackRow
        local saSelCorner = Instance.new("UICorner")
        saSelCorner.CornerRadius = UDim.new(0, 4)
        saSelCorner.Parent = summonAttackSelectBtn
        table.insert(transparencyElements, summonAttackSelectBtn)

        -- 右下：开关按钮
        local summonAttackToggleBtn = Instance.new("TextButton")
        summonAttackToggleBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
        summonAttackToggleBtn.Position = UDim2.new(0.33, 0, 0.5, 0)
        summonAttackToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        summonAttackToggleBtn.BackgroundTransparency = 0.65
        summonAttackToggleBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
        summonAttackToggleBtn.TextTransparency = 0.65
        summonAttackToggleBtn.Text = "关闭"
        summonAttackToggleBtn.ZIndex = 12
        summonAttackToggleBtn.Parent = summonAttackRow
        local saTogCorner = Instance.new("UICorner")
        saTogCorner.CornerRadius = UDim.new(0, 4)
        saTogCorner.Parent = summonAttackToggleBtn
        table.insert(transparencyElements, summonAttackToggleBtn)

        -- BOSS状态标签
        local BOSS_STATUS_Y = summonAttackRowY + SUMMON_ATTACK_ROW_H + ROW_GAP
        bossStatusLabelRef = Instance.new("TextLabel")
        bossStatusLabelRef.Size = UDim2.new(1, -10, 0, 20)
        bossStatusLabelRef.Position = UDim2.new(0, 5, 0, BOSS_STATUS_Y)
        bossStatusLabelRef.Text = "就绪"
        bossStatusLabelRef.TextColor3 = Color3.fromRGB(200, 200, 200)
        bossStatusLabelRef.TextTransparency = 0.65
        bossStatusLabelRef.BackgroundTransparency = 1
        bossStatusLabelRef.TextXAlignment = Enum.TextXAlignment.Left
        bossStatusLabelRef.TextWrapped = true
        bossStatusLabelRef.ZIndex = 12
        bossStatusLabelRef.Parent = bossBlock

        -- BOSS下拉框
        local function closeBossDropdown()
            if bossDropdownRef then
                bossDropdownRef:Destroy()
                bossDropdownRef = nil
            end
            bossDropdownOpen = false
        end

        local function toggleBossDropdown()
            if bossDropdownOpen then
                closeBossDropdown()
                return
            end
            local alive = getAliveBosses()
            if #alive == 0 then
                bossSelectBtn.Text = "无存活BOSS"
                return
            end
            bossDropdownOpen = true
            local dropFrame = Instance.new("ScrollingFrame")
            dropFrame.Name = "BossDropdown"
            dropFrame.Size = UDim2.new(0.65, 0, 0, math.min(#alive * 28 + 4, DROPDOWN_MAX))
            local btnAbs = bossSelectBtn.AbsolutePosition
            local btnSz = bossSelectBtn.AbsoluteSize
            local mainAbs = mainFrame.AbsolutePosition
            dropFrame.Position = UDim2.new(0, btnAbs.X - mainAbs.X, 0, btnAbs.Y - mainAbs.Y + btnSz.Y + 2)
            dropFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            dropFrame.BackgroundTransparency = 0.2
            dropFrame.BorderSizePixel = 0
            dropFrame.ZIndex = 999
            dropFrame.ScrollBarThickness = 3
            dropFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 182, 193)
            dropFrame.CanvasSize = UDim2.new(0, 0, 0, #alive * 28)
            dropFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
            dropFrame.Active = true
            local dc = Instance.new("UICorner")
            dc.CornerRadius = UDim.new(0, 4)
            dc.Parent = dropFrame
            dropFrame.Parent = mainFrame
            bossDropdownRef = dropFrame
            local closeConn
            closeConn = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    local pos = input.Position
                    local dAbs = dropFrame.AbsolutePosition
                    local dSz = dropFrame.AbsoluteSize
                    local bAbs = bossSelectBtn.AbsolutePosition
                    local bSz = bossSelectBtn.AbsoluteSize
                    if (pos.X < dAbs.X or pos.X > dAbs.X + dSz.X or pos.Y < dAbs.Y or pos.Y > dAbs.Y + dSz.Y)
                        and (pos.X < bAbs.X or pos.X > bAbs.X + bSz.X or pos.Y < bAbs.Y or pos.Y > bAbs.Y + bSz.Y) then
                        closeBossDropdown()
                        if closeConn then closeConn:Disconnect() end
                    end
                end
            end)
            for i, boss in ipairs(alive) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -8, 0, 26)
                btn.Position = UDim2.new(0, 4, 0, (i - 1) * 28 + 2)
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.BackgroundTransparency = 0.4
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.TextTransparency = 0.2
                btn.Text = boss.display
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 13
                btn.ZIndex = 1000
                btn.Parent = dropFrame
                local ic = Instance.new("UICorner")
                ic.CornerRadius = UDim.new(0, 3)
                ic.Parent = btn
                if boss.key == selectedBossKey then
                    btn.BackgroundColor3 = Color3.fromRGB(255, 100, 130)
                    btn.BackgroundTransparency = 0.3
                end
                btn.MouseEnter:Connect(function()
                    if boss.key ~= selectedBossKey then btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80) end
                end)
                btn.MouseLeave:Connect(function()
                    if boss.key ~= selectedBossKey then btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end
                end)
                btn.MouseButton1Click:Connect(function()
                    selectedBossKey = boss.key
                    bossSelectBtn.Text = boss.display
                    closeBossDropdown()
                    if closeConn then closeConn:Disconnect() end
                end)
            end
        end

        bossSelectBtn.MouseButton1Click:Connect(toggleBossDropdown)

        -- BOSS开关事件
        bossToggleBtn.MouseButton1Click:Connect(function()
            autoBossActive = not autoBossActive
            bossToggleBtn.Text = autoBossActive and "开启" or "关闭"
            if autoBossActive then
                if selectedBossKey == "" then
                    if bossStatusLabelRef then bossStatusLabelRef.Text = "请先选择BOSS" end
                    autoBossActive = false
                    bossToggleBtn.Text = "关闭"
                    return
                end
                if bossStatusLabelRef then bossStatusLabelRef.Text = "启动中..." end
                startBossAttack()
            else
                stopBossAttack()
                if bossStatusLabelRef then bossStatusLabelRef.Text = "已关闭" end
            end
        end)

        -- ============================================================
        -- 被召唤者逻辑函数
        -- ============================================================

        local function stopSummonedAttack()
            if summonedAttackHeartbeat then
                summonedAttackHeartbeat:Disconnect()
                summonedAttackHeartbeat = nil
            end
        end

        local function getSummonedBossModel(bossKey)
            if bossKey == "Rimuru" then
                local ok1, m1 = pcall(function()
                    return workspace.Boss.ServerTimeBossSpawner:FindFirstChild("Rimuru")
                end)
                if ok1 and m1 then
                    local h = m1:FindFirstChildWhichIsA("Humanoid")
                    if h and h.Health > 0 then return m1 end
                end
                return nil
            end
            local ok2, m2 = pcall(function()
                return workspace.Boss.BossSummoner:FindFirstChild(bossKey)
            end)
            if ok2 and m2 then
                local h = m2:FindFirstChildWhichIsA("Humanoid")
                if h and h.Health > 0 then return m2 end
            end
            return nil
        end

        local function getAliveSummonedBosses()
            local bosses = {}
            local summonMap = {
                ["Verdant Hero"] = "柜子",
                ["Saber"] = "Saber",
                ["Gilgamesh"] = "金闪闪",
                ["Kokushibo"] = "黑死牟",
            }
            pcall(function()
                local spawner = workspace.Boss:FindFirstChild("BossSummoner")
                if not spawner then return end
                for key, display in pairs(summonMap) do
                    local m = spawner:FindFirstChild(key)
                    if m then
                        local h = m:FindFirstChildWhichIsA("Humanoid")
                        if h and h.Health > 0 then
                            table.insert(bosses, {key = key, display = display})
                        end
                    end
                end
            end)
            pcall(function()
                local rimuru = workspace.Boss.ServerTimeBossSpawner:FindFirstChild("Rimuru")
                if rimuru then
                    local h = rimuru:FindFirstChildWhichIsA("Humanoid")
                    if h and h.Health > 0 then
                        table.insert(bosses, {key = "Rimuru", display = "利姆鲁"})
                    end
                end
            end)
            return bosses
        end

        local function startSummonedAttack()
            stopSummonedAttack()
            local lastClick = 0
            local lastLockedCF = nil
            local lastReequip = 0

            summonedAttackHeartbeat = RunService.Heartbeat:Connect(function()
                if not autoSummonedActive then stopSummonedAttack() return end
                local char = player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local boss = getSummonedBossModel(selectedSummonedKey)
                if not boss then
                    pcall(function()
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        if lastLockedCF then hrp.CFrame = lastLockedCF end
                    end)
                    if summonedStatusLabelRef then summonedStatusLabelRef.Text = "等待BOSS刷新..." end
                    return
                end

                local tp = getTargetPos(boss)
                if not tp then return end
                local now = tick()

                local targetCF = CFrame.lookAt(
                    Vector3.new(tp.X, tp.Y + levelHeight, tp.Z), tp
                )
                pcall(function()
                    hrp.CFrame = targetCF
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end)
                lastLockedCF = targetCF

                if now - lastClick >= 0.5 then
                    lastClick = now
                    pcall(function()
                        VirtualUser:ClickButton1(Vector2.new(
                            Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
                        ))
                    end)
                end

                if now - lastReequip >= 2 then
                    lastReequip = now
                    pcall(function()
                        if selectedWeaponName and selectedWeaponName ~= "无" then
                            local hasWeapon = false
                            for _, t in ipairs(char:GetChildren()) do
                                if t:IsA("Tool") and t.Name == selectedWeaponName then
                                    hasWeapon = true
                                    break
                                end
                            end
                            if not hasWeapon then equipWeapon(selectedWeaponName) end
                        end
                    end)
                end

                if summonedStatusLabelRef then
                    local hum = boss:FindFirstChildWhichIsA("Humanoid")
                    local hp = hum and math.floor(hum.Health) or 0
                    local maxHp = hum and math.floor(hum.MaxHealth) or 0
                    summonedStatusLabelRef.Text = "攻击中 HP " .. hp .. "/" .. maxHp
                end
            end)
        end

        -- 被召唤者下拉框
        local function closeSummonedDropdown()
            if summonedDropdownRef then
                summonedDropdownRef:Destroy()
                summonedDropdownRef = nil
            end
            summonedDropdownOpen = false
        end

        local function toggleSummonedDropdown()
            if summonedDropdownOpen then
                closeSummonedDropdown()
                return
            end
            local alive = getAliveSummonedBosses()
            if #alive == 0 then
                summonedSelectBtn.Text = "无存活BOSS"
                return
            end
            summonedDropdownOpen = true
            local dropFrame = Instance.new("ScrollingFrame")
            dropFrame.Name = "SummonedDropdown"
            dropFrame.Size = UDim2.new(0.65, 0, 0, math.min(#alive * 28 + 4, DROPDOWN_MAX))
            local btnAbs = summonedSelectBtn.AbsolutePosition
            local btnSz = summonedSelectBtn.AbsoluteSize
            local mainAbs = mainFrame.AbsolutePosition
            dropFrame.Position = UDim2.new(0, btnAbs.X - mainAbs.X, 0, btnAbs.Y - mainAbs.Y + btnSz.Y + 2)
            dropFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            dropFrame.BackgroundTransparency = 0.2
            dropFrame.BorderSizePixel = 0
            dropFrame.ZIndex = 999
            dropFrame.ScrollBarThickness = 3
            dropFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 182, 193)
            dropFrame.CanvasSize = UDim2.new(0, 0, 0, #alive * 28)
            dropFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
            dropFrame.Active = true
            local dc = Instance.new("UICorner")
            dc.CornerRadius = UDim.new(0, 4)
            dc.Parent = dropFrame
            dropFrame.Parent = mainFrame
            summonedDropdownRef = dropFrame
            local closeConn
            closeConn = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    local pos = input.Position
                    local dAbs = dropFrame.AbsolutePosition
                    local dSz = dropFrame.AbsoluteSize
                    local bAbs = summonedSelectBtn.AbsolutePosition
                    local bSz = summonedSelectBtn.AbsoluteSize
                    if (pos.X < dAbs.X or pos.X > dAbs.X + dSz.X or pos.Y < dAbs.Y or pos.Y > dAbs.Y + dSz.Y)
                        and (pos.X < bAbs.X or pos.X > bAbs.X + bSz.X or pos.Y < bAbs.Y or pos.Y > bAbs.Y + bSz.Y) then
                        closeSummonedDropdown()
                        if closeConn then closeConn:Disconnect() end
                    end
                end
            end)
            for i, boss in ipairs(alive) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -8, 0, 26)
                btn.Position = UDim2.new(0, 4, 0, (i - 1) * 28 + 2)
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.BackgroundTransparency = 0.4
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.TextTransparency = 0.2
                btn.Text = boss.display
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 13
                btn.ZIndex = 1000
                btn.Parent = dropFrame
                local ic = Instance.new("UICorner")
                ic.CornerRadius = UDim.new(0, 3)
                ic.Parent = btn
                if boss.key == selectedSummonedKey then
                    btn.BackgroundColor3 = Color3.fromRGB(255, 100, 130)
                    btn.BackgroundTransparency = 0.3
                end
                btn.MouseEnter:Connect(function()
                    if boss.key ~= selectedSummonedKey then btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80) end
                end)
                btn.MouseLeave:Connect(function()
                    if boss.key ~= selectedSummonedKey then btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end
                end)
                btn.MouseButton1Click:Connect(function()
                    selectedSummonedKey = boss.key
                    summonedSelectBtn.Text = boss.display
                    closeSummonedDropdown()
                    if closeConn then closeConn:Disconnect() end
                end)
            end
        end

        summonedSelectBtn.MouseButton1Click:Connect(toggleSummonedDropdown)

        -- 被召唤者开关事件
        summonedToggleBtn.MouseButton1Click:Connect(function()
            autoSummonedActive = not autoSummonedActive
            summonedToggleBtn.Text = autoSummonedActive and "开启" or "关闭"
            if autoSummonedActive then
                if selectedSummonedKey == "" then
                    if summonedStatusLabelRef then summonedStatusLabelRef.Text = "请先选择BOSS" end
                    autoSummonedActive = false
                    summonedToggleBtn.Text = "关闭"
                    return
                end
                if summonedStatusLabelRef then summonedStatusLabelRef.Text = "启动中..." end
                startSummonedAttack()
            else
                stopSummonedAttack()
                if summonedStatusLabelRef then summonedStatusLabelRef.Text = "已关闭" end
            end
        end)

        -- ============================================================
        -- 召唤攻击逻辑
        -- ============================================================

        local function stopSummonAttack()
            if summonAttackHeartbeat then
                summonAttackHeartbeat:Disconnect()
                summonAttackHeartbeat = nil
            end
        end

        -- 检测蓝染是否存活
        local function checkAizenAlive()
            local ok1, parent = pcall(function()
                return workspace.Boss:FindFirstChild("Aizen")
            end)
            if not ok1 or not parent then return nil end
            local ok2, m = pcall(function()
                return parent:FindFirstChild("Aizen")
            end)
            if not ok2 or not m then return nil end
            local h = m:FindFirstChildWhichIsA("Humanoid")
            if h and h.Health > 0 then return m end
            return nil
        end

        -- 检测Rimuru或Sung Jinwoo是否存活
        local function checkRimuruAlive()
            local ok1, m = pcall(function()
                return workspace.Boss.ServerTimeBossSpawner:FindFirstChild("Rimuru")
            end)
            if ok1 and m then
                local h = m:FindFirstChildWhichIsA("Humanoid")
                if h and h.Health > 0 then return m end
            end
            local ok2, sjw = pcall(function()
                return workspace.Boss.ServerTimeBossSpawner:FindFirstChild("Sung Jinwoo")
            end)
            if ok2 and sjw then
                local h = sjw:FindFirstChildWhichIsA("Humanoid")
                if h and h.Health > 0 then return sjw end
            end
            return nil
        end

        -- 检测Slime Orb数量
        local function checkSlimeOrbCount()
            local count = 0
            pcall(function()
                local orb = playerGui.ScreenGui.HUD.StorageFrame.Main.MaterialFrame:FindFirstChild("Slime Orb")
                if orb then
                    local default = orb:FindFirstChild("Default")
                    if default then
                        local itemCount = default:FindFirstChild("ItemCount")
                        if itemCount then
                            local txt = itemCount.Text or ""
                            local num = txt:match("(%d+)")
                            count = tonumber(num) or 0
                        end
                    end
                end
            end)
            return count
        end

        -- 发射SlimeRE召唤
        local function fireSlimeRE()
            pcall(function()
                local args = {
                    [1] = "SummonSlime";
                    [2] = { ["Amount"] = 1 };
                }
                local r = ReplicatedStorage:FindFirstChild("Packages")
                if r then r = r:FindFirstChild("_Index") end
                if r then r = r:FindFirstChild("sleitnick_net@0.2.0") end
                if r then r = r:FindFirstChild("net") end
                if r then r = r:FindFirstChild("RE/SlimeRE") end
                if r then
                    r:FireServer(unpack(args))
                    print("[召唤攻击] 已使用Slime Orb")
                end
            end)
        end

        local function startSummonAttack()
            stopSummonAttack()
            local lastClick = 0
            local lastLockedCF = nil
            local lastReequip = 0
            local slimeFireCount = 0
            local wasBossAlive = false

            summonAttackHeartbeat = RunService.Heartbeat:Connect(function()
                if not autoSummonAttackActive then stopSummonAttack() return end
                local char = player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local now = tick()
                local boss = nil

                -- 检测目标BOSS是否存活
                if selectedSummonAttackKey == "Aizen" then
                    boss = checkAizenAlive()
                elseif selectedSummonAttackKey == "Rimuru" then
                    boss = checkRimuruAlive()
                end

                if boss then
                    -- BOSS存活，直接攻击
                    wasBossAlive = true
                    local tp = getTargetPos(boss)
                    if not tp then return end
                    local targetCF = CFrame.lookAt(
                        Vector3.new(tp.X, tp.Y + levelHeight, tp.Z), tp
                    )
                    pcall(function()
                        hrp.CFrame = targetCF
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                    lastLockedCF = targetCF

                    if now - lastClick >= 0.5 then
                        lastClick = now
                        pcall(function()
                            VirtualUser:ClickButton1(Vector2.new(
                                Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
                            ))
                        end)
                    end

                    if now - lastReequip >= 2 then
                        lastReequip = now
                        pcall(function()
                            if selectedWeaponName and selectedWeaponName ~= "无" then
                                local hasWeapon = false
                                for _, t in ipairs(char:GetChildren()) do
                                    if t:IsA("Tool") and t.Name == selectedWeaponName then
                                        hasWeapon = true; break
                                    end
                                end
                                if not hasWeapon then equipWeapon(selectedWeaponName) end
                            end
                        end)
                    end

                    if bossStatusLabelRef then
                        local hum = boss:FindFirstChildWhichIsA("Humanoid")
                        local hp = hum and math.floor(hum.Health) or 0
                        local maxHp = hum and math.floor(hum.MaxHealth) or 0
                        bossStatusLabelRef.Text = "攻击BOSS HP " .. hp .. "/" .. maxHp
                    end
                else
                    -- BOSS未存活，执行召唤/刷怪逻辑
                    -- 检测BOSS刚死（从存活变不存活），重置发射计数
                    if wasBossAlive then
                        wasBossAlive = false
                        slimeFireCount = 0
                    end

                    if selectedSummonAttackKey == "Rimuru" and slimeFireCount == 0 then
                        local orbCount = checkSlimeOrbCount()
                        if orbCount >= 3 then
                            for fi = 1, 3 do
                                fireSlimeRE()
                            end
                            slimeFireCount = 3
                        end
                    end

                    -- 刷Hollow
                    local target = getTarget("Hollow")
                    if not target then
                        pcall(function()
                            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            if lastLockedCF then hrp.CFrame = lastLockedCF end
                        end)
                        if bossStatusLabelRef then
                            if selectedSummonAttackKey == "Rimuru" then
                                bossStatusLabelRef.Text = "已召唤,等待BOSS..."
                            else
                                bossStatusLabelRef.Text = "等待Hollow刷新..."
                            end
                        end
                        return
                    end

                    local tp = getTargetPos(target)
                    if not tp then return end
                    local targetCF = CFrame.lookAt(
                        Vector3.new(tp.X, tp.Y + levelHeight, tp.Z), tp
                    )
                    pcall(function()
                        hrp.CFrame = targetCF
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                    lastLockedCF = targetCF

                    if now - lastClick >= 0.5 then
                        lastClick = now
                        pcall(function()
                            VirtualUser:ClickButton1(Vector2.new(
                                Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
                            ))
                        end)
                    end

                    if now - lastReequip >= 2 then
                        lastReequip = now
                        pcall(function()
                            if selectedWeaponName and selectedWeaponName ~= "无" then
                                local hasWeapon = false
                                for _, t in ipairs(char:GetChildren()) do
                                    if t:IsA("Tool") and t.Name == selectedWeaponName then
                                        hasWeapon = true; break
                                    end
                                end
                                if not hasWeapon then equipWeapon(selectedWeaponName) end
                            end
                        end)
                    end

                    if bossStatusLabelRef then
                        if selectedSummonAttackKey == "Rimuru" then
                            if slimeFireCount >= 3 then
                                bossStatusLabelRef.Text = "刷Hollow(已召唤,等BOSS)"
                            else
                                bossStatusLabelRef.Text = "刷Hollow(Orb" .. checkSlimeOrbCount() .. "/3)"
                            end
                        else
                            bossStatusLabelRef.Text = "刷Hollow(等" .. summonAttackSelectBtn.Text .. ")"
                        end
                    end
                end
            end)
        end

        -- 召唤攻击下拉框
        local summonAttackOptions = {
            {key = "Aizen", display = "蓝染"},
            {key = "Rimuru", display = "利姆鲁"},
        }

        local function closeSummonAttackDropdown()
            if summonAttackDropdownRef then
                summonAttackDropdownRef:Destroy()
                summonAttackDropdownRef = nil
            end
            summonAttackDropdownOpen = false
        end

        local function toggleSummonAttackDropdown()
            if summonAttackDropdownOpen then
                closeSummonAttackDropdown()
                return
            end
            summonAttackDropdownOpen = true
            local dropFrame = Instance.new("ScrollingFrame")
            dropFrame.Name = "SummonAttackDropdown"
            local optCount = #summonAttackOptions
            dropFrame.Size = UDim2.new(0.65, 0, 0, math.min(optCount * 28 + 4, DROPDOWN_MAX))
            local btnAbs = summonAttackSelectBtn.AbsolutePosition
            local btnSz = summonAttackSelectBtn.AbsoluteSize
            local mainAbs = mainFrame.AbsolutePosition
            dropFrame.Position = UDim2.new(0, btnAbs.X - mainAbs.X, 0, btnAbs.Y - mainAbs.Y + btnSz.Y + 2)
            dropFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            dropFrame.BackgroundTransparency = 0.2
            dropFrame.BorderSizePixel = 0
            dropFrame.ZIndex = 999
            dropFrame.ScrollBarThickness = 3
            dropFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 182, 193)
            dropFrame.CanvasSize = UDim2.new(0, 0, 0, optCount * 28)
            dropFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
            dropFrame.Active = true
            local dc = Instance.new("UICorner")
            dc.CornerRadius = UDim.new(0, 4)
            dc.Parent = dropFrame
            dropFrame.Parent = mainFrame
            summonAttackDropdownRef = dropFrame
            local closeConn
            closeConn = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    local pos = input.Position
                    local dAbs = dropFrame.AbsolutePosition
                    local dSz = dropFrame.AbsoluteSize
                    local bAbs = summonAttackSelectBtn.AbsolutePosition
                    local bSz = summonAttackSelectBtn.AbsoluteSize
                    if (pos.X < dAbs.X or pos.X > dAbs.X + dSz.X or pos.Y < dAbs.Y or pos.Y > dAbs.Y + dSz.Y)
                        and (pos.X < bAbs.X or pos.X > bAbs.X + bSz.X or pos.Y < bAbs.Y or pos.Y > bAbs.Y + bSz.Y) then
                        closeSummonAttackDropdown()
                        if closeConn then closeConn:Disconnect() end
                    end
                end
            end)
            for i, opt in ipairs(summonAttackOptions) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -8, 0, 26)
                btn.Position = UDim2.new(0, 4, 0, (i - 1) * 28 + 2)
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.BackgroundTransparency = 0.4
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.TextTransparency = 0.2
                btn.Text = opt.display
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 13
                btn.ZIndex = 1000
                btn.Parent = dropFrame
                local ic = Instance.new("UICorner")
                ic.CornerRadius = UDim.new(0, 3)
                ic.Parent = btn
                if opt.key == selectedSummonAttackKey then
                    btn.BackgroundColor3 = Color3.fromRGB(255, 100, 130)
                    btn.BackgroundTransparency = 0.3
                end
                btn.MouseEnter:Connect(function()
                    if opt.key ~= selectedSummonAttackKey then btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80) end
                end)
                btn.MouseLeave:Connect(function()
                    if opt.key ~= selectedSummonAttackKey then btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end
                end)
                btn.MouseButton1Click:Connect(function()
                    selectedSummonAttackKey = opt.key
                    summonAttackSelectBtn.Text = opt.display
                    closeSummonAttackDropdown()
                    if closeConn then closeConn:Disconnect() end
                end)
            end
        end

        summonAttackSelectBtn.MouseButton1Click:Connect(toggleSummonAttackDropdown)

        -- 召唤攻击开关事件
        summonAttackToggleBtn.MouseButton1Click:Connect(function()
            autoSummonAttackActive = not autoSummonAttackActive
            summonAttackToggleBtn.Text = autoSummonAttackActive and "开启" or "关闭"
            if autoSummonAttackActive then
                if selectedSummonAttackKey == "" then
                    if bossStatusLabelRef then bossStatusLabelRef.Text = "请先选择目标" end
                    autoSummonAttackActive = false
                    summonAttackToggleBtn.Text = "关闭"
                    return
                end
                if bossStatusLabelRef then bossStatusLabelRef.Text = "启动中..." end
                startSummonAttack()
            else
                stopSummonAttack()
                if bossStatusLabelRef then bossStatusLabelRef.Text = "已关闭" end
            end
        end)

        -- ============================================================
        -- UI：自动加点类别（4个开关：近战/健康/武器/力量）
        -- ============================================================

        local statsRemote = nil

        local function getStatsRemote()
            if statsRemote and statsRemote.Parent then return statsRemote end
            local ok, _ = pcall(function()
                local p1 = ReplicatedStorage:FindFirstChild("Packages")
                if not p1 then return end
                local p2 = p1:FindFirstChild("_Index")
                if not p2 then return end
                local p3 = p2:FindFirstChild("sleitnick_net@0.2.0")
                if not p3 then return end
                local p4 = p3:FindFirstChild("net")
                if not p4 then return end
                local p5 = p4:FindFirstChild("RE/StatsAllocateEvent")
                if p5 then statsRemote = p5 end
            end)
            if not statsRemote then
                print("[自动加点] Remote未找到，下次循环重试")
            end
            return statsRemote
        end

        -- 读取当前技能点数
        local function getSkillPoints()
            local ok, spObj = pcall(function()
                return playerGui.ScreenGui.HUD.StatsFrame.Main.StatsUP.statspoingot
            end)
            if not ok or not spObj then return 0 end
            local text = spObj.Text or ""
            local num = text:match(":%s*(%d+)")
            return tonumber(num) or 0
        end

        local statPointsPerClick = 1  -- 每次加点数量（输入栏控制）

        local statConfigs = {
            {name = "近战", key = "Strength"},
            {name = "健康", key = "Defense"},
            {name = "武器", key = "Weapon"},
            {name = "力量", key = "Power"},
        }
        local statStates = {}  -- {active=false, thread=nil}

        local STATS_HEADER_Y = 5
        local STATS_START_Y = 28
        local STATS_ROW_H = 40
        local STATS_GAP = 3

        -- 类别标题
        local statsHeader = Instance.new("TextLabel")
        statsHeader.Size = UDim2.new(1, -10, 0, 18)
        statsHeader.Position = UDim2.new(0, 5, 0, STATS_HEADER_Y)
        statsHeader.Text = "自动加点"
        statsHeader.TextColor3 = Color3.fromRGB(255, 182, 193)
        statsHeader.TextTransparency = 0.65
        statsHeader.BackgroundTransparency = 1
        statsHeader.TextXAlignment = Enum.TextXAlignment.Left
        statsHeader.Font = Enum.Font.GothamBold
        statsHeader.TextSize = 14
        statsHeader.ZIndex = 12
        statsHeader.Parent = scroll2
        table.insert(autoStatLabels, statsHeader)

        for i, cfg in ipairs(statConfigs) do
            local statKey = cfg.key  -- 闭包捕获，避免循环变量引用问题
            local yPos = STATS_START_Y + (i - 1) * (STATS_ROW_H + STATS_GAP)
            statStates[i] = {active = false, thread = nil}

            local statRow = Instance.new("Frame")
            statRow.Size = UDim2.new(1, -10, 0, STATS_ROW_H)
            statRow.Position = UDim2.new(0, 5, 0, yPos)
            statRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            statRow.BackgroundTransparency = 0.65
            statRow.ZIndex = 11
            statRow.Parent = scroll2
            table.insert(transparencyElements, statRow)

            local statLabel = Instance.new("TextLabel")
            statLabel.Size = UDim2.new(0.5, 0, 1, 0)
            statLabel.Position = UDim2.new(0, 5, 0, 0)
            statLabel.Text = cfg.name
            statLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
            statLabel.TextTransparency = 0.65
            statLabel.BackgroundTransparency = 1
            statLabel.TextXAlignment = Enum.TextXAlignment.Left
            statLabel.ZIndex = 12
            statLabel.Parent = statRow
            table.insert(autoStatLabels, statLabel)

            local statBtn = Instance.new("TextButton")
            statBtn.Size = UDim2.new(0.45, 0, 0.8, 0)
            statBtn.Position = UDim2.new(0.53, 0, 0.1, 0)
            statBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            statBtn.BackgroundTransparency = 0.65
            statBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
            statBtn.TextTransparency = 0.65
            statBtn.Text = "关闭"
            statBtn.ZIndex = 12
            statBtn.Parent = statRow
            local statBtnCorner = Instance.new("UICorner")
            statBtnCorner.CornerRadius = UDim.new(0, 4)
            statBtnCorner.Parent = statBtn
            table.insert(transparencyElements, statBtn)

            -- 关闭时记录：点击开/关
            local idx = i  -- 闭包捕获
            statBtn.MouseButton1Click:Connect(function()
                local state = statStates[idx]
                state.active = not state.active
                statBtn.Text = state.active and "开启" or "关闭"

                if state.active then
                    -- 取消旧线程
                    if state.thread then
                        pcall(task.cancel, state.thread)
                        state.thread = nil
                    end
                    state.thread = task.spawn(function()
                        while state.active do
                            local sp = getSkillPoints()
                            if sp and sp > 0 then
                                local remote = getStatsRemote()
                                if remote then
                                    pcall(function()
                                        local pts = statPointsPerClick
                                        print("[自动加点] " .. statKey .. " +" .. pts)
                                        remote:FireServer(statKey, pts)
                                    end)
                                else
                                    print("[自动加点] 未找到 StatsAllocateEvent")
                                end
                                task.wait(0.5)
                            else
                                task.wait(1)
                            end
                        end
                    end)
                else
                    if state.thread then
                        pcall(task.cancel, state.thread)
                        state.thread = nil
                    end
                end
            end)
        end

        -- ============================================================
        -- UI：自动刷怪功能块
        -- ============================================================

        local FARM_BLOCK_Y = BOSS_BLOCK_Y + BOSS_BLOCK_H + 20
        local FARM_ROW_H = ROW_H * 2
        local SMALL_BOSS_ROW_H = ROW_H * 2
        local FARM_BLOCK_H = BLOCK_PAD + HEADER_H + ROW_GAP + FARM_ROW_H + ROW_GAP + SMALL_BOSS_ROW_H + ROW_GAP + ROW_H + ROW_GAP + 20 + BLOCK_PAD

        local farmBlock = Instance.new("Frame")
        farmBlock.Size = UDim2.new(1, -10, 0, FARM_BLOCK_H)
        farmBlock.Position = UDim2.new(0, 5, 0, FARM_BLOCK_Y)
        farmBlock.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        farmBlock.BackgroundTransparency = 0.5
        farmBlock.ZIndex = 10
        local farmBlockCorner = Instance.new("UICorner")
        farmBlockCorner.CornerRadius = UDim.new(0, 6)
        farmBlockCorner.Parent = farmBlock
        farmBlock.Parent = scroll
        table.insert(transparencyElements, farmBlock)

        local farmBlockHeader = Instance.new("TextLabel")
        farmBlockHeader.Size = UDim2.new(1, -10, 0, HEADER_H)
        farmBlockHeader.Position = UDim2.new(0, 5, 0, BLOCK_PAD)
        farmBlockHeader.Text = "自动刷怪"
        farmBlockHeader.TextColor3 = Color3.fromRGB(255, 182, 193)
        farmBlockHeader.TextTransparency = 0.65
        farmBlockHeader.BackgroundTransparency = 1
        farmBlockHeader.TextXAlignment = Enum.TextXAlignment.Left
        farmBlockHeader.Font = Enum.Font.GothamBold
        farmBlockHeader.TextSize = 14
        farmBlockHeader.ZIndex = 12
        farmBlockHeader.Parent = farmBlock
        table.insert(autoStatLabels, farmBlockHeader)

        local farmRowY = BLOCK_PAD + HEADER_H + ROW_GAP
        local farmRow = Instance.new("Frame")
        farmRow.Size = UDim2.new(1, -10, 0, FARM_ROW_H)
        farmRow.Position = UDim2.new(0, 5, 0, farmRowY)
        farmRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        farmRow.BackgroundTransparency = 0.65
        farmRow.ZIndex = 11
        farmRow.Parent = farmBlock
        table.insert(transparencyElements, farmRow)

        local farmLabel = Instance.new("TextLabel")
        farmLabel.Size = UDim2.new(0.3, 0, 1, 0)
        farmLabel.Position = UDim2.new(0, 5, 0, 0)
        farmLabel.Text = "刷小怪"
        farmLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
        farmLabel.TextTransparency = 0.65
        farmLabel.BackgroundTransparency = 1
        farmLabel.TextXAlignment = Enum.TextXAlignment.Left
        farmLabel.ZIndex = 12
        farmLabel.Parent = farmRow
        table.insert(autoStatLabels, farmLabel)

        local farmSelectBtn = Instance.new("TextButton")
        farmSelectBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
        farmSelectBtn.Position = UDim2.new(0.33, 0, 0.05, 0)
        farmSelectBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        farmSelectBtn.BackgroundTransparency = 0.65
        farmSelectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        farmSelectBtn.TextTransparency = 0.65
        farmSelectBtn.Text = "选择怪物"
        farmSelectBtn.ZIndex = 12
        farmSelectBtn.Parent = farmRow
        local fmSelCorner = Instance.new("UICorner")
        fmSelCorner.CornerRadius = UDim.new(0, 4)
        fmSelCorner.Parent = farmSelectBtn
        table.insert(transparencyElements, farmSelectBtn)

        local farmToggleBtn = Instance.new("TextButton")
        farmToggleBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
        farmToggleBtn.Position = UDim2.new(0.33, 0, 0.5, 0)
        farmToggleBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
        farmToggleBtn.BackgroundTransparency = 0.65
        farmToggleBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
        farmToggleBtn.TextTransparency = 0.65
        farmToggleBtn.Text = "关闭"
        farmToggleBtn.ZIndex = 12
        farmToggleBtn.Parent = farmRow
        local fmTogCorner = Instance.new("UICorner")
        fmTogCorner.CornerRadius = UDim.new(0, 4)
        fmTogCorner.Parent = farmToggleBtn
        table.insert(transparencyElements, farmToggleBtn)

        local farmStatusLabelRef = Instance.new("TextLabel")
        farmStatusLabelRef.Size = UDim2.new(1, -10, 0, 20)
        farmStatusLabelRef.Position = UDim2.new(0, 5, 0, farmRowY + FARM_ROW_H + ROW_GAP)
        farmStatusLabelRef.Text = "就绪"
        farmStatusLabelRef.TextColor3 = Color3.fromRGB(200, 200, 200)
        farmStatusLabelRef.TextTransparency = 0.65
        farmStatusLabelRef.BackgroundTransparency = 1
        farmStatusLabelRef.TextXAlignment = Enum.TextXAlignment.Left
        farmStatusLabelRef.TextWrapped = true
        farmStatusLabelRef.ZIndex = 12
        farmStatusLabelRef.Parent = farmBlock

        -- 小boss（独立函数，字节码分离避免外层超限）
        local function initSmallBoss()
            local sbActive = false
            local sbHeartbeat = nil
            local sbSelectedKey = ""
            local sbDropOpen = false
            local sbDropRef = nil

            local sbRowY = farmRowY + FARM_ROW_H + ROW_GAP + 20 + ROW_GAP
            local sbRow = Instance.new("Frame")
            sbRow.Size = UDim2.new(1, -10, 0, SMALL_BOSS_ROW_H)
            sbRow.Position = UDim2.new(0, 5, 0, sbRowY)
            sbRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            sbRow.BackgroundTransparency = 0.65
            sbRow.ZIndex = 11
            sbRow.Parent = farmBlock
            table.insert(transparencyElements, sbRow)

            local sbLabel = Instance.new("TextLabel")
            sbLabel.Size = UDim2.new(0.3, 0, 1, 0)
            sbLabel.Position = UDim2.new(0, 5, 0, 0)
            sbLabel.Text = "小boss"
            sbLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
            sbLabel.TextTransparency = 0.65
            sbLabel.BackgroundTransparency = 1
            sbLabel.TextXAlignment = Enum.TextXAlignment.Left
            sbLabel.ZIndex = 12
            sbLabel.Parent = sbRow
            table.insert(autoStatLabels, sbLabel)

            local sbSelBtn = Instance.new("TextButton")
            sbSelBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
            sbSelBtn.Position = UDim2.new(0.33, 0, 0.05, 0)
            sbSelBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            sbSelBtn.BackgroundTransparency = 0.65
            sbSelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            sbSelBtn.TextTransparency = 0.65
            sbSelBtn.Text = "选择boss"
            sbSelBtn.ZIndex = 12
            sbSelBtn.Parent = sbRow
            local c1 = Instance.new("UICorner") c1.CornerRadius = UDim.new(0, 4) c1.Parent = sbSelBtn
            table.insert(transparencyElements, sbSelBtn)

            local sbTogBtn = Instance.new("TextButton")
            sbTogBtn.Size = UDim2.new(0.65, 0, 0.4, 0)
            sbTogBtn.Position = UDim2.new(0.33, 0, 0.5, 0)
            sbTogBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            sbTogBtn.BackgroundTransparency = 0.65
            sbTogBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
            sbTogBtn.TextTransparency = 0.65
            sbTogBtn.Text = "关闭"
            sbTogBtn.ZIndex = 12
            sbTogBtn.Parent = sbRow
            local c2 = Instance.new("UICorner") c2.CornerRadius = UDim.new(0, 4) c2.Parent = sbTogBtn
            table.insert(transparencyElements, sbTogBtn)

            local allRowY = sbRowY + SMALL_BOSS_ROW_H + ROW_GAP
            local allRow = Instance.new("Frame")
            allRow.Size = UDim2.new(1, -10, 0, ROW_H)
            allRow.Position = UDim2.new(0, 5, 0, allRowY)
            allRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            allRow.BackgroundTransparency = 0.65
            allRow.ZIndex = 11
            allRow.Parent = farmBlock
            table.insert(transparencyElements, allRow)

            local allLabel = Instance.new("TextLabel")
            allLabel.Size = UDim2.new(0.3, 0, 1, 0)
            allLabel.Position = UDim2.new(0, 5, 0, 0)
            allLabel.Text = "刷全部"
            allLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
            allLabel.TextTransparency = 0.65
            allLabel.BackgroundTransparency = 1
            allLabel.TextXAlignment = Enum.TextXAlignment.Left
            allLabel.ZIndex = 12
            allLabel.Parent = allRow
            table.insert(autoStatLabels, allLabel)

            local allTogBtn = Instance.new("TextButton")
            allTogBtn.Size = UDim2.new(0.65, 0, 1, 0)
            allTogBtn.Position = UDim2.new(0.33, 0, 0, 0)
            allTogBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
            allTogBtn.BackgroundTransparency = 0.65
            allTogBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
            allTogBtn.TextTransparency = 0.65
            allTogBtn.Text = "关闭"
            allTogBtn.ZIndex = 12
            allTogBtn.Parent = allRow
            local c3 = Instance.new("UICorner") c3.CornerRadius = UDim.new(0, 4) c3.Parent = allTogBtn
            table.insert(transparencyElements, allTogBtn)

            local sbStatusLbl = Instance.new("TextLabel")
            sbStatusLbl.Size = UDim2.new(1, -10, 0, 20)
            sbStatusLbl.Position = UDim2.new(0, 5, 0, allRowY + ROW_H + ROW_GAP)
            sbStatusLbl.Text = "就绪"
            sbStatusLbl.TextColor3 = Color3.fromRGB(200, 200, 200)
            sbStatusLbl.TextTransparency = 0.65
            sbStatusLbl.BackgroundTransparency = 1
            sbStatusLbl.TextXAlignment = Enum.TextXAlignment.Left
            sbStatusLbl.TextWrapped = true
            sbStatusLbl.ZIndex = 12
            sbStatusLbl.Parent = farmBlock

            local function stopSBAttack()
                if sbHeartbeat then sbHeartbeat:Disconnect() sbHeartbeat = nil end
            end
            local function startSBAttack()
                stopSBAttack()
                local lastClick = 0
                local lastCF = nil
                sbHeartbeat = RunService.Heartbeat:Connect(function()
                    if not sbActive then stopSBAttack() return end
                    local char = player.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local target = getTarget(sbSelectedKey)
                    if not target then
                        pcall(function()
                            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                            if lastCF then hrp.CFrame = lastCF end
                        end)
                        if sbStatusLbl then sbStatusLbl.Text = "等待刷新..." end
                        return
                    end
                    local tp = getTargetPos(target)
                    if not tp then return end
                    local now = tick()
                    local tCF = CFrame.lookAt(Vector3.new(tp.X, tp.Y + levelHeight, tp.Z), tp)
                    pcall(function()
                        hrp.CFrame = tCF
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                    lastCF = tCF
                    if now - lastClick >= 0.5 then
                        lastClick = now
                        pcall(function()
                            VirtualUser:ClickButton1(Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2))
                        end)
                    end
                    if sbStatusLbl then sbStatusLbl.Text = "攻击中 " .. sbSelectedKey end
                end)
            end

            local sbOpts = {
                {key = "Bandit Leader", display = "Bandit Leader"},
                {key = "Shank", display = "Shank"},
                {key = "Mihawk", display = "Mihawk"},
                {key = "National Level Hunter", display = "National Level Hunter"},
                {key = "Miwa", display = "Miwa"},
                {key = "Arrancar", display = "Arrancar"},
                {key = "Ichigo (Bankai)", display = "Ichigo (Bankai)"},
                {key = "Mahito", display = "Mahito"},
            }
            local function closeSBDD()
                if sbDropRef then sbDropRef:Destroy() sbDropRef = nil end
                sbDropOpen = false
            end
            local function toggleSBDD()
                if sbDropOpen then closeSBDD() return end
                sbDropOpen = true
                local df = Instance.new("ScrollingFrame")
                df.Name = "SBDrop"
                local oc = #sbOpts
                df.Size = UDim2.new(0.65, 0, 0, math.min(oc * 28 + 4, DROPDOWN_MAX))
                local ba = sbSelBtn.AbsolutePosition
                local bs = sbSelBtn.AbsoluteSize
                local ma = mainFrame.AbsolutePosition
                df.Position = UDim2.new(0, ba.X - ma.X, 0, ba.Y - ma.Y + bs.Y + 2)
                df.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
                df.BackgroundTransparency = 0.2
                df.BorderSizePixel = 0
                df.ZIndex = 999
                df.ScrollBarThickness = 3
                df.ScrollBarImageColor3 = Color3.fromRGB(255, 182, 193)
                df.CanvasSize = UDim2.new(0, 0, 0, oc * 28)
                df.AutomaticCanvasSize = Enum.AutomaticSize.None
                df.Active = true
                local dc = Instance.new("UICorner") dc.CornerRadius = UDim.new(0, 4) dc.Parent = df
                df.Parent = mainFrame
                sbDropRef = df
                local cc
                cc = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        local p = input.Position
                        local da = df.AbsolutePosition
                        local ds = df.AbsoluteSize
                        local ea = sbSelBtn.AbsolutePosition
                        local es = sbSelBtn.AbsoluteSize
                        if (p.X < da.X or p.X > da.X + ds.X or p.Y < da.Y or p.Y > da.Y + ds.Y) and (p.X < ea.X or p.X > ea.X + es.X or p.Y < ea.Y or p.Y > ea.Y + es.Y) then
                            closeSBDD()
                            if cc then cc:Disconnect() end
                        end
                    end
                end)
                for i, opt in ipairs(sbOpts) do
                    local b = Instance.new("TextButton")
                    b.Size = UDim2.new(1, -8, 0, 26)
                    b.Position = UDim2.new(0, 4, 0, (i - 1) * 28 + 2)
                    b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                    b.BackgroundTransparency = 0.4
                    b.TextColor3 = Color3.fromRGB(255, 255, 255)
                    b.TextTransparency = 0.2
                    b.Text = opt.display
                    b.TextXAlignment = Enum.TextXAlignment.Left
                    b.Font = Enum.Font.GothamBold
                    b.TextSize = 13
                    b.ZIndex = 1000
                    b.Parent = df
                    local ic = Instance.new("UICorner") ic.CornerRadius = UDim.new(0, 3) ic.Parent = b
                    if opt.key == sbSelectedKey then
                        b.BackgroundColor3 = Color3.fromRGB(255, 100, 130)
                        b.BackgroundTransparency = 0.3
                    end
                    b.MouseEnter:Connect(function()
                        if opt.key ~= sbSelectedKey then b.BackgroundColor3 = Color3.fromRGB(80, 80, 80) end
                    end)
                    b.MouseLeave:Connect(function()
                        if opt.key ~= sbSelectedKey then b.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end
                    end)
                    b.MouseButton1Click:Connect(function()
                        sbSelectedKey = opt.key
                        sbSelBtn.Text = opt.display
                        closeSBDD()
                        if cc then cc:Disconnect() end
                    end)
                end
            end
            sbSelBtn.MouseButton1Click:Connect(toggleSBDD)
            sbTogBtn.MouseButton1Click:Connect(function()
                sbActive = not sbActive
                sbTogBtn.Text = sbActive and "开启" or "关闭"
                if sbActive then
                    if sbSelectedKey == "" then
                        if sbStatusLbl then sbStatusLbl.Text = "请先选择boss" end
                        sbActive = false
                        sbTogBtn.Text = "关闭"
                        return
                    end
                    if sbStatusLbl then sbStatusLbl.Text = "启动中..." end
                    startSBAttack()
                else
                    stopSBAttack()
                    if sbStatusLbl then sbStatusLbl.Text = "已关闭" end
                end
            end)
        end
            local allActive = false
            local allHB = nil
            local allIdx = 1
            local allKeys = {"Bandit Leader", "Shank", "Mihawk", "National Level Hunter", "Miwa", "Arrancar", "Ichigo (Bankai)", "Mahito"}
            local function stopAll()
                if allHB then allHB:Disconnect() allHB = nil end
            end
            local function startAll()
                stopAll()
                local lastClick = 0
                local lastCF = nil
                allHB = RunService.Heartbeat:Connect(function()
                    if not allActive then stopAll() return end
                    local char = player.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    local target = getTarget(allKeys[allIdx])
                    if not target then
                        local triedAll = true
                        local savedIdx = allIdx
                        for t = 1, #allKeys do
                            allIdx = allIdx % #allKeys + 1
                            target = getTarget(allKeys[allIdx])
                            if target then triedAll = false break end
                        end
                        if triedAll then
                            pcall(function()
                                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                                if lastCF then hrp.CFrame = lastCF end
                            end)
                            if sbStatusLbl then sbStatusLbl.Text = "等待刷新..." end
                            return
                        end
                    end
                    local tp = getTargetPos(target)
                    if not tp then return end
                    local now = tick()
                    local tCF = CFrame.lookAt(Vector3.new(tp.X, tp.Y + levelHeight, tp.Z), tp)
                    pcall(function()
                        hrp.CFrame = tCF
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end)
                    lastCF = tCF
                    if now - lastClick >= 0.5 then
                        lastClick = now
                        pcall(function()
                            VirtualUser:ClickButton1(Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2))
                        end)
                    end
                    if sbStatusLbl then sbStatusLbl.Text = "刷全部: " .. allKeys[allIdx] end
                end)
            end
            allTogBtn.MouseButton1Click:Connect(function()
                allActive = not allActive
                allTogBtn.Text = allActive and "开启" or "关闭"
                if allActive then
                    if sbStatusLbl then sbStatusLbl.Text = "启动中..." end
                    startAll()
                else
                    stopAll()
                    if sbStatusLbl then sbStatusLbl.Text = "已关闭" end
                end
            end)
        initSmallBoss()

        -- 刷怪攻击逻辑
        local function stopFarmAttack()
            if farmAttackHeartbeat then
                farmAttackHeartbeat:Disconnect()
                farmAttackHeartbeat = nil
            end
        end

        local function startFarmAttack()
            stopFarmAttack()
            local lastClick = 0
            local lastLockedCF = nil
            local lastReequip = 0

            farmAttackHeartbeat = RunService.Heartbeat:Connect(function()
                if not autoFarmActive then stopFarmAttack() return end
                local char = player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end

                local target = getTarget(selectedFarmKey)
                if not target then
                    pcall(function()
                        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        if lastLockedCF then hrp.CFrame = lastLockedCF end
                    end)
                    if farmStatusLabelRef then farmStatusLabelRef.Text = "等待刷新..." end
                    return
                end

                local tp = getTargetPos(target)
                if not tp then return end
                local now = tick()
                local targetCF = CFrame.lookAt(
                    Vector3.new(tp.X, tp.Y + levelHeight, tp.Z), tp
                )
                pcall(function()
                    hrp.CFrame = targetCF
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                end)
                lastLockedCF = targetCF

                if now - lastClick >= 0.5 then
                    lastClick = now
                    pcall(function()
                        VirtualUser:ClickButton1(Vector2.new(
                            Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2
                        ))
                    end)
                end

                if now - lastReequip >= 2 then
                    lastReequip = now
                    pcall(function()
                        if selectedWeaponName and selectedWeaponName ~= "无" then
                            local hasWeapon = false
                            for _, t in ipairs(char:GetChildren()) do
                                if t:IsA("Tool") and t.Name == selectedWeaponName then
                                    hasWeapon = true; break
                                end
                            end
                            if not hasWeapon then equipWeapon(selectedWeaponName) end
                        end
                    end)
                end

                if farmStatusLabelRef then
                    farmStatusLabelRef.Text = "攻击中 " .. selectedFarmKey
                end
            end)
        end

        -- 刷怪下拉框
        local farmOptions = {
            {key = "Bandit", display = "Bandit"},
            {key = "Monkey", display = "Monkey"},
            {key = "Snow Bandit", display = "Snow Bandit"},
            {key = "Sorcerer Student", display = "Sorcerer Student"},
            {key = "Hollow", display = "Hollow"},
        }

        local function closeFarmDropdown()
            if farmDropdownRef then
                farmDropdownRef:Destroy()
                farmDropdownRef = nil
            end
            farmDropdownOpen = false
        end

        local function toggleFarmDropdown()
            if farmDropdownOpen then
                closeFarmDropdown()
                return
            end
            farmDropdownOpen = true
            local dropFrame = Instance.new("ScrollingFrame")
            dropFrame.Name = "FarmDropdown"
            local optCount = #farmOptions
            dropFrame.Size = UDim2.new(0.65, 0, 0, math.min(optCount * 28 + 4, DROPDOWN_MAX))
            local btnAbs = farmSelectBtn.AbsolutePosition
            local btnSz = farmSelectBtn.AbsoluteSize
            local mainAbs = mainFrame.AbsolutePosition
            dropFrame.Position = UDim2.new(0, btnAbs.X - mainAbs.X, 0, btnAbs.Y - mainAbs.Y + btnSz.Y + 2)
            dropFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            dropFrame.BackgroundTransparency = 0.2
            dropFrame.BorderSizePixel = 0
            dropFrame.ZIndex = 999
            dropFrame.ScrollBarThickness = 3
            dropFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 182, 193)
            dropFrame.CanvasSize = UDim2.new(0, 0, 0, optCount * 28)
            dropFrame.AutomaticCanvasSize = Enum.AutomaticSize.None
            dropFrame.Active = true
            local dc = Instance.new("UICorner")
            dc.CornerRadius = UDim.new(0, 4)
            dc.Parent = dropFrame
            dropFrame.Parent = mainFrame
            farmDropdownRef = dropFrame
            local closeConn
            closeConn = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch then
                    local pos = input.Position
                    local dAbs = dropFrame.AbsolutePosition
                    local dSz = dropFrame.AbsoluteSize
                    local bAbs = farmSelectBtn.AbsolutePosition
                    local bSz = farmSelectBtn.AbsoluteSize
                    if (pos.X < dAbs.X or pos.X > dAbs.X + dSz.X or pos.Y < dAbs.Y or pos.Y > dAbs.Y + dSz.Y)
                        and (pos.X < bAbs.X or pos.X > bAbs.X + bSz.X or pos.Y < bAbs.Y or pos.Y > bAbs.Y + bSz.Y) then
                        closeFarmDropdown()
                        if closeConn then closeConn:Disconnect() end
                    end
                end
            end)
            for i, opt in ipairs(farmOptions) do
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, -8, 0, 26)
                btn.Position = UDim2.new(0, 4, 0, (i - 1) * 28 + 2)
                btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                btn.BackgroundTransparency = 0.4
                btn.TextColor3 = Color3.fromRGB(255, 255, 255)
                btn.TextTransparency = 0.2
                btn.Text = opt.display
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.Font = Enum.Font.GothamBold
                btn.TextSize = 13
                btn.ZIndex = 1000
                btn.Parent = dropFrame
                local ic = Instance.new("UICorner")
                ic.CornerRadius = UDim.new(0, 3)
                ic.Parent = btn
                if opt.key == selectedFarmKey then
                    btn.BackgroundColor3 = Color3.fromRGB(255, 100, 130)
                    btn.BackgroundTransparency = 0.3
                end
                btn.MouseEnter:Connect(function()
                    if opt.key ~= selectedFarmKey then btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80) end
                end)
                btn.MouseLeave:Connect(function()
                    if opt.key ~= selectedFarmKey then btn.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end
                end)
                btn.MouseButton1Click:Connect(function()
                    selectedFarmKey = opt.key
                    farmSelectBtn.Text = opt.display
                    closeFarmDropdown()
                    if closeConn then closeConn:Disconnect() end
                end)
            end
        end

        farmSelectBtn.MouseButton1Click:Connect(toggleFarmDropdown)

        farmToggleBtn.MouseButton1Click:Connect(function()
            autoFarmActive = not autoFarmActive
            farmToggleBtn.Text = autoFarmActive and "开启" or "关闭"
            if autoFarmActive then
                if selectedFarmKey == "" then
                    if farmStatusLabelRef then farmStatusLabelRef.Text = "请先选择怪物" end
                    autoFarmActive = false
                    farmToggleBtn.Text = "关闭"
                    return
                end
                if farmStatusLabelRef then farmStatusLabelRef.Text = "启动中..." end
                startFarmAttack()
            else
                stopFarmAttack()
                if farmStatusLabelRef then farmStatusLabelRef.Text = "已关闭" end
            end
        end)

        scroll.CanvasSize = UDim2.new(0, 0, 0, FARM_BLOCK_Y + FARM_BLOCK_H + 5)
        -- 输入栏：每次加点数量（在4个按钮下方）
        local INPUT_Y = STATS_START_Y + 4 * (STATS_ROW_H + STATS_GAP) + 5
        local inputRow = Instance.new("Frame")
        inputRow.Size = UDim2.new(1, -10, 0, 32)
        inputRow.Position = UDim2.new(0, 5, 0, INPUT_Y)
        inputRow.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        inputRow.BackgroundTransparency = 0.65
        inputRow.ZIndex = 11
        inputRow.Parent = scroll2
        table.insert(transparencyElements, inputRow)

        local inputLabel = Instance.new("TextLabel")
        inputLabel.Size = UDim2.new(0.45, 0, 1, 0)
        inputLabel.Position = UDim2.new(0, 5, 0, 0)
        inputLabel.Text = "每次加点数量"
        inputLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
        inputLabel.TextTransparency = 0.65
        inputLabel.BackgroundTransparency = 1
        inputLabel.TextXAlignment = Enum.TextXAlignment.Left
        inputLabel.TextSize = 13
        inputLabel.ZIndex = 12
        inputLabel.Parent = inputRow
        table.insert(autoStatLabels, inputLabel)

        local statInputBox = Instance.new("TextBox")
        statInputBox.Size = UDim2.new(0.25, 0, 0.7, 0)
        statInputBox.Position = UDim2.new(0.5, 0, 0.15, 0)
        statInputBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        statInputBox.BackgroundTransparency = 0.3
        statInputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        statInputBox.Text = "1"
        statInputBox.PlaceholderText = "1"
        statInputBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
        statInputBox.TextSize = 14
        statInputBox.Font = Enum.Font.GothamBold
        statInputBox.ZIndex = 13
        statInputBox.ClearTextOnFocus = false
        statInputBox.Parent = inputRow
        local inputCorner = Instance.new("UICorner")
        inputCorner.CornerRadius = UDim.new(0, 4)
        inputCorner.Parent = statInputBox
        table.insert(transparencyElements, statInputBox)

        statInputBox:GetPropertyChangedSignal("Text"):Connect(function()
            local val = tonumber(statInputBox.Text)
            if val and val > 0 then
                statPointsPerClick = math.floor(val)
            else
                statPointsPerClick = 1
            end
        end)
        statInputBox.FocusLost:Connect(function()
            local val = tonumber(statInputBox.Text)
            if not val or val <= 0 then
                statInputBox.Text = "1"
                statPointsPerClick = 1
            end
        end)

        scroll2.CanvasSize = UDim2.new(0, 0, 0, INPUT_Y + 40)

        -- ============================================================
        -- 统一 UI 能见度控制
        -- ============================================================
        table.insert(transparencyElements, weaponRow)
        table.insert(transparencyElements, weaponBtn)
        table.insert(transparencyElements, row)
        table.insert(transparencyElements, sliderTrack)
        table.insert(transparencyElements, toggleBtnRef)

        local function applyReducedTransparency()
            local normalMode = not isSpecialUI
            local bgT = normalMode and 0.60 or 0.65
            local btnBgT = normalMode and 0.60 or 0.65
            local txtT = normalMode and 0.60 or 0.65
            leftPanel.BackgroundTransparency = 1
            rightPanel.BackgroundTransparency = 1
            for _, elem in ipairs(transparencyElements) do
                if elem:IsA("TextButton") or elem:IsA("ImageButton") then
                    elem.BackgroundTransparency = btnBgT
                    elem.TextTransparency = txtT
                elseif elem:IsA("Frame") then
                    elem.BackgroundTransparency = bgT
                end
            end
            if btn1 then
                btn1.BackgroundTransparency = btnBgT
                btn1.TextTransparency = txtT
            end
            if btn2 then
                btn2.BackgroundTransparency = btnBgT
                btn2.TextTransparency = txtT
            end
            if rowLabel then rowLabel.TextTransparency = txtT end
            if sliderLabel then sliderLabel.TextTransparency = txtT end
            if statusLabelRef then statusLabelRef.TextTransparency = txtT end
            for _, lbl in ipairs(autoStatLabels) do
                lbl.TextTransparency = txtT
            end
        end

        applyReducedTransparency()

        -- ============================================================
        -- 自动升级开关事件
        -- ============================================================

        toggleBtnRef.MouseButton1Click:Connect(function()
            autoLevelActive = not autoLevelActive
            toggleBtnRef.Text = autoLevelActive and "开启" or "关闭"

            if autoLevelActive then
                local qf = getQuestFrame()
                if qf then
                    -- 不管QuestFrame是否可见，直接启动
                    statusLabelRef.Text = "启动中..."
                    task.spawn(triggerAutoLevel)
                    -- 同时监听QuestFrame可见性变化（任务完成时自动接下一个）
                    if questVisConnection then questVisConnection:Disconnect() end
                    questVisConnection = qf:GetPropertyChangedSignal("Visible"):Connect(function()
                        if not qf.Visible and autoLevelActive then
                            task.spawn(triggerAutoLevel)
                        end
                    end)
                else
                    statusLabelRef.Text = "未找到任务界面"
                    print("[自动升级] 未找到 QuestFrame")
                end
            else
                stopAttack()
                if questVisConnection then
                    questVisConnection:Disconnect()
                    questVisConnection = nil
                end
                statusLabelRef.Text = "已关闭"
            end
        end)

        -- ============================================================
        -- 控制层（折叠/刷新）
        -- ============================================================

        local ctrlGui = Instance.new("ScreenGui")
        ctrlGui.Name = "AutoLevelCtrl"
        ctrlGui.DisplayOrder = 9999
        ctrlGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ctrlGui.IgnoreGuiInset = true
        ctrlGui.ResetOnSpawn = false
        ctrlGui.Parent = playerGui

        local toggleUIBtn = Instance.new("ImageButton")
        toggleUIBtn.Size = UDim2.new(0, 50, 0, 50)
        toggleUIBtn.Position = UDim2.new(1, -65, 0.5, -25)
        toggleUIBtn.BackgroundTransparency = 1
        toggleUIBtn.ZIndex = 1
        toggleUIBtn.Image = "rbxassetid://74595430581428"
        toggleUIBtn.Parent = ctrlGui

        local refreshBtn = Instance.new("TextButton")
        refreshBtn.Size = UDim2.new(0, 50, 0, 40)
        refreshBtn.Position = UDim2.new(1, -65, 0.5, -130)
        refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        refreshBtn.BackgroundTransparency = 0.65
        refreshBtn.TextColor3 = Color3.fromRGB(255, 182, 193)
        refreshBtn.TextTransparency = 0.65
        refreshBtn.Text = "刷新"
        refreshBtn.TextSize = 14
        refreshBtn.Font = Enum.Font.SourceSansBold
        refreshBtn.ZIndex = 1
        refreshBtn.Parent = ctrlGui

        local uiVisible = true

        toggleUIBtn.MouseButton1Click:Connect(function()
            uiVisible = not uiVisible
            mainFrame.Visible = uiVisible
            animGui.Enabled = uiVisible
            toggleUIBtn.Image = uiVisible
                and "rbxassetid://74595430581428"
                or "rbxassetid://124965942250140"
        end)

        refreshBtn.MouseButton1Click:Connect(function()
            stopAttack()
            autoLevelActive = false
            if questVisConnection then
                questVisConnection:Disconnect()
                questVisConnection = nil
            end
            local o1 = playerGui:FindFirstChild("AutoLevelBG")
            if o1 then o1:Destroy() end
            local o2 = playerGui:FindFirstChild("AutoLevelUI")
            if o2 then o2:Destroy() end
            local o3 = playerGui:FindFirstChild("AutoLevelCtrl")
            if o3 then o3:Destroy() end
            print("[自动升级] 刷新UI...")
            createUI()
        end)

        print("[自动升级] UI创建完成")
    end)

    if not success then
        warn("[自动升级] 创建失败:", err)
    end
end

-- ============================================================
-- 加载动画：自动检测帧数 + BGM（只播放一次，最顶层遮挡一切）
-- ============================================================
local function playLoadingAnimation()
    local LOADING_BASE = "https://ghfast.top/https://raw.githubusercontent.com/sssbbb3ryf/loading/main/"
    local LOADING_CACHE = "loading_anim_cache"
    local BGM_FILE = "loading_bgm.mp3"
    if makefolder then makefolder(LOADING_CACHE) end

    local hasFileSystem = (isfile and readfile and writefile and getcustomasset)

    local function checkLocalCache()
        if not hasFileSystem then return 0 end
        local count = 0
        for i = 1, 1000 do
            local fname = string.format("loading_%04d.jpg", i)
            if isfile(LOADING_CACHE .. "/" .. fname) then
                count = i
            else
                break
            end
        end
        return count
    end

    local skipPressed = false
    local bgmSound = nil

    local function httpGetSafe(url, timeoutSec)
        timeoutSec = timeoutSec or 10
        local result = nil
        local done = false
        task.spawn(function()
            local ok, data = pcall(function()
                return game:HttpGet(url)
            end)
            if ok then result = data end
            done = true
        end)
        local start = tick()
        while not done do
            task.wait(0.1)
            if (tick() - start) > timeoutSec then
                done = true
                break
            end
        end
        return result
    end

    task.spawn(function()
        local LOADING_TOTAL = 0

        -- 有缓存就用缓存数量
        if hasFileSystem then
            local cached = checkLocalCache()
            if cached > 0 then
                LOADING_TOTAL = cached
                print("[加载] 使用本地缓存 " .. LOADING_TOTAL .. " 帧")
            end
        end

        -- 没有缓存就先下载（全屏黑底+进度提示）
        if LOADING_TOTAL == 0 then
            if not hasFileSystem then
                print("[加载] 不支持文件系统，跳过动画")
                createUI()
                return
            end

            -- 创建下载提示界面
            starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
            pcall(function() starterGui:SetCore("TopbarEnabled", false) end)
            local dlGui = Instance.new("ScreenGui")
            dlGui.Name = "LoadingAnimation"
            dlGui.ResetOnSpawn = false
            dlGui.IgnoreGuiInset = true
            dlGui.DisplayOrder = 99999
            dlGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            local okGui, _ = pcall(function() dlGui.Parent = game:GetService("CoreGui") end)
            if not okGui then dlGui.Parent = playerGui end

            local dlBg = Instance.new("Frame")
            dlBg.Size = UDim2.new(1, 0, 1, 0)
            dlBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            dlBg.BackgroundTransparency = 0
            dlBg.ZIndex = 0
            dlBg.Parent = dlGui

            local dlLabel = Instance.new("TextLabel")
            dlLabel.Size = UDim2.new(1, 0, 0, 40)
            dlLabel.Position = UDim2.new(0, 0, 0.45, 0)
            dlLabel.BackgroundTransparency = 1
            dlLabel.TextColor3 = Color3.fromRGB(255, 182, 193)
            dlLabel.Text = "正在下载加载动画..."
            dlLabel.Font = Enum.Font.GothamBold
            dlLabel.TextSize = 18
            dlLabel.ZIndex = 1
            dlLabel.Parent = dlGui

            local dlBar = Instance.new("Frame")
            dlBar.Size = UDim2.new(0.6, 0, 0, 6)
            dlBar.Position = UDim2.new(0.2, 0, 0.52, 0)
            dlBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
            dlBar.BackgroundTransparency = 0.3
            dlBar.ZIndex = 1
            dlBar.Parent = dlGui
            local dlBarCorner = Instance.new("UICorner")
            dlBarCorner.CornerRadius = UDim.new(0, 3)
            dlBarCorner.Parent = dlBar

            local dlFill = Instance.new("Frame")
            dlFill.Size = UDim2.new(0, 0, 1, 0)
            dlFill.BackgroundColor3 = Color3.fromRGB(255, 182, 193)
            dlFill.BackgroundTransparency = 0.3
            dlFill.ZIndex = 2
            dlFill.Parent = dlBar
            local dlFillCorner = Instance.new("UICorner")
            dlFillCorner.CornerRadius = UDim.new(0, 3)
            dlFillCorner.Parent = dlFill

            -- 下载逻辑：从第1帧开始逐个探测，快速确定总数
            print("[加载] 探测帧数...")
            local lastFound = 0
            for i = 1, 1000 do
                local fname = string.format("loading_%04d.jpg", i)
                local data = httpGetSafe(LOADING_BASE .. fname, 3)
                if data and #data > 500 then
                    lastFound = i
                    -- 探测到就顺便存下来
                    local fpath = LOADING_CACHE .. "/" .. fname
                    if not isfile(fpath) then
                        pcall(function() writefile(fpath, data) end)
                    end
                    -- 每帧更新进度
                    dlLabel.Text = "正在探测帧数... " .. i
                else
                    break
                end
            end
            LOADING_TOTAL = lastFound
            print("[加载] 检测到 " .. LOADING_TOTAL .. " 帧")

            if LOADING_TOTAL == 0 then
                dlLabel.Text = "下载失败，跳过动画"
                task.wait(1.5)
                dlGui:Destroy()
                starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
                pcall(function() starterGui:SetCore("TopbarEnabled", true) end)
                createUI()
                return
            end

            -- 前面的帧探测时已保存，无需重复下载
            -- 下载BGM
            if not isfile(BGM_FILE) then
                dlLabel.Text = "正在下载BGM..."
                local bgmData = httpGetSafe(LOADING_BASE .. "loading_bgm.mp3", 30)
                if bgmData and #bgmData > 1000 then
                    pcall(function() writefile(BGM_FILE, bgmData) end)
                    print("[加载] BGM已下载，大小:", #bgmData)
                else
                    print("[加载] BGM下载失败")
                end
            end

            dlLabel.Text = "下载完成！"
            task.wait(0.5)
            dlGui:Destroy()
            starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
            pcall(function() starterGui:SetCore("TopbarEnabled", true) end)
        end

        if LOADING_TOTAL == 0 then
            createUI()
            return
        end

        -- 构建帧URL列表（刚下载完的直接用GitHub URL，避免getcustomasset对新文件不生效）
        local frameUrls = {}
        local usedCache = false
        if hasFileSystem then
            -- 检查是否是已有缓存（非本次下载）
            local allCached = true
            for i = 1, LOADING_TOTAL do
                local fname = string.format("loading_%04d.jpg", i)
                if not isfile(LOADING_CACHE .. "/" .. fname) then
                    allCached = false
                    break
                end
            end
            if allCached then
                usedCache = true
                for i = 1, LOADING_TOTAL do
                    local fname = string.format("loading_%04d.jpg", i)
                    frameUrls[i] = getcustomasset(LOADING_CACHE .. "/" .. fname)
                end
            end
        end
        if not usedCache then
            for i = 1, LOADING_TOTAL do
                local fname = string.format("loading_%04d.jpg", i)
                frameUrls[i] = LOADING_BASE .. fname
            end
        end

        local readyCount = #frameUrls
        print("[加载] 就绪: " .. readyCount .. "/" .. LOADING_TOTAL .. (usedCache and " (缓存)" or " (在线)"))

        if readyCount == 0 then
            print("[加载] 没有任何可用帧，跳过动画")
            createUI()
            return
        end

        print("[加载] 全部就绪，创建UI并播放动画")

        starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        pcall(function() starterGui:SetCore("TopbarEnabled", false) end)

        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "LoadingAnimation"
        screenGui.ResetOnSpawn = false
        screenGui.IgnoreGuiInset = true
        screenGui.DisplayOrder = 99999
        screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local ok, err = pcall(function()
            screenGui.Parent = game:GetService("CoreGui")
        end)
        if not ok then
            screenGui.Parent = playerGui
        end

        local bgFrame = Instance.new("Frame")
        bgFrame.Name = "BlackBG"
        bgFrame.Size = UDim2.new(1, 0, 1, 0)
        bgFrame.Position = UDim2.new(0, 0, 0, 0)
        bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bgFrame.BackgroundTransparency = 0
        bgFrame.ZIndex = 0
        bgFrame.Parent = screenGui

        local frames = {}
        for i = 1, readyCount do
            local lbl = Instance.new("ImageLabel")
            lbl.Name = "LoadF" .. i
            lbl.Size = UDim2.new(1, 0, 1, 0)
            lbl.Position = UDim2.new(0, 0, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.ImageTransparency = 1
            lbl.ZIndex = 5
            lbl.ScaleType = Enum.ScaleType.Stretch
            lbl.Image = frameUrls[i]
            lbl.Parent = screenGui
            frames[i] = lbl
        end

        frames[1].ImageTransparency = 0

        task.spawn(function()
            print("[加载] 后台预加载 " .. readyCount .. " 帧...")
            local ContentProvider = game:GetService("ContentProvider")
            local PRELOAD_BATCH = 10
            for batchStart = 1, readyCount, PRELOAD_BATCH do
                if skipPressed then break end
                local batchEnd = math.min(batchStart + PRELOAD_BATCH - 1, readyCount)
                local batch = {}
                for i = batchStart, batchEnd do
                    batch[#batch + 1] = frames[i]
                end
                pcall(function()
                    ContentProvider:PreloadAsync(batch)
                end)
                task.wait(0.01)
            end
            print("[加载] 后台预加载完成")
        end)

        local skipBtn = Instance.new("TextButton")
        skipBtn.Size = UDim2.new(0, 100, 0, 40)
        skipBtn.Position = UDim2.new(1, -120, 1, -60)
        skipBtn.AnchorPoint = Vector2.new(1, 1)
        skipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        skipBtn.BackgroundTransparency = 0.5
        skipBtn.Text = "跳过"
        skipBtn.TextColor3 = Color3.new(1, 1, 1)
        skipBtn.TextSize = 20
        skipBtn.Font = Enum.Font.SourceSansBold
        skipBtn.ZIndex = 100
        skipBtn.Parent = screenGui

        local function finishLoading()
            if skipPressed then return end
            skipPressed = true
            if bgmSound then
                bgmSound:Stop()
                bgmSound:Destroy()
                bgmSound = nil
            end
            starterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
            pcall(function() starterGui:SetCore("TopbarEnabled", true) end)
            if screenGui then
                screenGui:Destroy()
            end
            print("加载动画完毕，开始创建自动升级 UI")
            createUI()
        end

        skipBtn.MouseButton1Click:Connect(function()
            if skipPressed then return end
            finishLoading()
        end)

        print("[加载] 开始播放动画（" .. readyCount .. " 帧，30fps）...")

        local cur = 1
        local FPS = 30
        local interval = 1 / FPS
        local bgmStarted = false

        local bgmStartFrame = 1
        pcall(function()
            local bgmObj = Instance.new("Sound")
            if isfile(BGM_FILE) then
                bgmObj.SoundId = getcustomasset(BGM_FILE)
            else
                bgmObj.SoundId = LOADING_BASE .. "loading_bgm.mp3"
            end
            bgmObj.Volume = 0.5
            bgmObj.Looped = false
            bgmObj.Parent = workspace
            local bgmWait = 0
            while bgmObj.TimeLength <= 0 and not skipPressed and bgmWait < 5 do
                task.wait(0.1)
                bgmWait = bgmWait + 0.1
            end
            if bgmObj.TimeLength > 0 then
                local bgmLength = bgmObj.TimeLength
                local animTotalTime = readyCount / FPS
                print("[加载] BGM时长: " .. string.format("%.2f", bgmLength) .. "s, 动画时长: " .. string.format("%.2f", animTotalTime) .. "s")
                if bgmLength > 0 and bgmLength <= animTotalTime then
                    local bgmFrames = math.floor(bgmLength * FPS)
                    bgmStartFrame = math.max(1, readyCount - bgmFrames + 1)
                    print("[加载] BGM将在第 " .. bgmStartFrame .. " 帧开始播放")
                end
            else
                print("[加载] BGM加载超时，跳过BGM")
                pcall(function() bgmObj:Destroy() end)
            end
        end)

        task.spawn(function()
            while cur < readyCount and not skipPressed do
                local frameStart = tick()

                local nextIdx = cur + 1

                if frames[nextIdx] then
                    frames[nextIdx].ImageTransparency = 0
                end

                if frames[cur] then
                    frames[cur].ImageTransparency = 1
                end

                cur = nextIdx

                if not bgmStarted and cur >= bgmStartFrame then
                    bgmStarted = true
                    pcall(function()
                        bgmSound = Instance.new("Sound")
                        if isfile(BGM_FILE) then
                            bgmSound.SoundId = getcustomasset(BGM_FILE)
                        else
                            bgmSound.SoundId = LOADING_BASE .. "loading_bgm.mp3"
                        end
                        bgmSound.Volume = 0.5
                        bgmSound.Looped = false
                        bgmSound.Parent = workspace
                        bgmSound:Play()
                        print("[加载] BGM 已开始播放（第 " .. bgmStartFrame .. " 帧）")
                    end)
                end

                local elapsed = tick() - frameStart
                if elapsed < interval then
                    task.wait(interval - elapsed)
                end
            end

            if not skipPressed then
                local fadeInfo = TweenInfo.new(1.5, Enum.EasingStyle.Linear)
                for _, lbl in ipairs(frames) do
                    pcall(function()
                        TweenService:Create(lbl, fadeInfo, {ImageTransparency = 1}):Play()
                    end)
                end
                task.wait(1.5)
                if not skipPressed then finishLoading() end
            end
        end)
    end)
end

-- 启动加载动画
playLoadingAnimation()
