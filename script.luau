local RunService = cloneref(game:GetService("RunService"))
local Players = cloneref(game:GetService("Players"))
local CoreGui = cloneref(game:GetService("CoreGui"))

local LocalPlayer = Players.LocalPlayer

local PlayerGui = LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
local HiddenGui = gethui and gethui() or CoreGui

local _connections = {}

local Soulfire = {}
local CommandIntake = { list = {} , nextId = 1, syncedCursor = 1 }
local RuntimeState = {
	gameState = "Unknown",
	currentWave = 0,
	currentCash = 0,
	started = false,
	stopped = false,
    paused = false,
	processorRunning = false,
    payload = nil,
	runStartedAt = 0
}

local executor = identifyexecutor and identifyexecutor() or "Unknown"

local LogConsoleHistory = {}
local RecordConsoleHistory = {}
local RecordedMacro = {}
local LogConsoleLabel, RecordConsoleLabel

local Flags = {
    AutoStrat = false,
    AutoSkip = false,
    AutoAbilities = false,
    BlockInput = false,
    Timescale = 1,
    Modifiers = {},
}

local SecurityFlags = {
    SafeMode = true,
    VirtualInput = true,
    WorldInput = true,
    StaticLoadout = true,
}

local function findPath(root: Instance?, parts: { string }): Instance?
    local current = root
    for _, part in ipairs(parts) do
        current = current and current:FindFirstChild(part) or nil
        if not current then return nil end
    end
    return current
end

local CustomUI = {}
local CustomTextFunctions = {}

CustomUI.PresetImages = {
    Logo = "rbxassetid://1369675507942242",
    Error = "rbxassetid://1369675507942242",
    Success = "rbxassetid://1369675507942242",
    Info = "rbxassetid://1369675507942242",
}

CustomUI.PresetColors = {
    darkred = Color3.fromRGB(139, 0, 0),
    red = Color3.fromRGB(255, 73, 73),
    softred = Color3.fromRGB(255, 128, 128),
    orange = Color3.fromRGB(255, 197, 73),
    gold = Color3.fromRGB(238, 216, 146),
    green = Color3.fromRGB(73, 230, 133),
    blue = Color3.fromRGB(73, 184, 255),
    purple = Color3.fromRGB(155, 73, 255),
    pink = Color3.fromRGB(255, 105, 180),
}

CustomTextFunctions.lerpColor = function(c1: Color3, c2: Color3, t: number): Color3
    return Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end

CustomTextFunctions.getGradientColor = function(colors: {Color3}, alpha: number): Color3
    if alpha <= 0 then return colors[1] end
    if alpha >= 1 then return colors[#colors] end
    
    local pos = alpha * (#colors - 1)
    local index = math.floor(pos) + 1
    local fraction = pos - math.floor(pos)
    
    return CustomTextFunctions.lerpColor(colors[index], colors[index + 1], fraction)
end

CustomTextFunctions.createRichTextGradient = function(text: string, colorList: {Color3}): string
    local result = ""
    local chars = {}
    
    for first, last in utf8.graphemes(text) do
        table.insert(chars, string.sub(text, first, last))
    end
    
    local numChars = #chars
    for i, char in ipairs(chars) do
        local alpha = (numChars > 1) and ((i - 1) / (numChars - 1)) or 0.5
        local color = CustomTextFunctions.getGradientColor(colorList, alpha)
        local hex = color:ToHex()
        
        result ..= string.format('<font color="#%s">%s</font>', hex, char)
    end
    
    return result
end

CustomTextFunctions.color3toRichtextString = function(color: Color3): string
    local r = math.floor(color.R * 255)
    local g = math.floor(color.G * 255)
    local b = math.floor(color.B * 255)
    return string.format("rgb(%d, %d, %d)", r, g, b)
end

CustomTextFunctions.color3toRichtext = function(text: string, color: Color3, bold: boolean?): string
    local r = math.floor(color.R * 255)
    local g = math.floor(color.G * 255)
    local b = math.floor(color.B * 255)
    local boldTag = bold and "<b>" or ""
    local closeBoldTag = bold and "</b>" or ""
    return string.format('<font color="rgb(%d, %d, %d)">%s%s%s</font>', r, g, b, boldTag, text, closeBoldTag)
end

local function printConsole(msg, console, status)
    local Timestamp = os.date("%X")
    local StatusTag = Timestamp or ""
    console = console or "log"

    if status == "success" then
        StatusTag = CustomTextFunctions.color3toRichtext(Timestamp, CustomUI.PresetColors.green)
    elseif status == "warning" then
        StatusTag = CustomTextFunctions.color3toRichtext(Timestamp, CustomUI.PresetColors.orange)
    elseif status == "error" then
        StatusTag = CustomTextFunctions.color3toRichtext(Timestamp, CustomUI.PresetColors.red)
    elseif status == "critical" then
        StatusTag = CustomTextFunctions.color3toRichtext(Timestamp, CustomUI.PresetColors.darkred, true)
    elseif status == "info" then
        StatusTag = CustomTextFunctions.color3toRichtext(Timestamp, CustomUI.PresetColors.blue)
    end

    local FinalMsg = "" .. StatusTag .. " -- " .. msg
    
    if console == "log" then
        table.insert(LogConsoleHistory, FinalMsg)
        if #LogConsoleHistory > 25 then table.remove(LogConsoleHistory, 1) end
        
        LogConsoleLabel:SetText(table.concat(LogConsoleHistory, "\n"))
    elseif console == "record" then
        table.insert(RecordConsoleHistory, FinalMsg)
        if #RecordConsoleHistory > 25 then table.remove(RecordConsoleHistory, 1) end

        RecordConsoleLabel:SetText(table.concat(RecordConsoleHistory, "\n"))
    end
end

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library: Library = (loadstring(game:HttpGet(repo .. "Library.lua")) :: () -> Library)()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ShowToggleFrameInKeybinds = true

local Game = "Universal"
local Version = "1.6.7 | Baka Build"

local Window = Library:CreateWindow({
    Title = "Soulfire",
	Footer = Game .. " | Version: " .. Version,
	Icon = 95816097006870,
    EnableSidebarResize = true,
    EnableCompacting = true,
})

-- The Tabs
local Tabs = {
    Home = Window:AddTab("Home", "user"),
    Agent = Window:AddTab("Agent", "sparkles"),
    Presets = Window:AddTab("Presets", "puzzle"),
    Main = Window:AddTab("Main", "zap"),
    Extra = Window:AddTab("Extra", "box"),
    Tools = Window:AddTab("Tools", "camera"),
    Settings = Window:AddTab("Settings", "settings"),
}

--Library:AddDraggableLabel("Soulfire")

-- ==========================================
-- HOME TAB
-- ==========================================

local AccountGroupBox = Tabs.Home:AddLeftGroupbox("Account", "user")
AccountGroupBox:AddImage("UserImage", {
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=420&h=420",
    Height = 200,
})

AccountGroupBox:AddLabel("Good afternoon, <b>" .. LocalPlayer.DisplayName .. "</b>!\nWelcome back to Soulfire!", true)
AccountGroupBox:AddLabel("Account Type: <b>" .. CustomTextFunctions.createRichTextGradient("Premium", {CustomUI.PresetColors.gold, CustomUI.PresetColors.orange}) .. "</b>")
AccountGroupBox:AddDivider("Environment")
AccountGroupBox:AddLabel("Executor: <b>" .. executor .. "</b>")
AccountGroupBox:AddLabel("Compatibility: <b>" .. "Fully Supported" .. "</b>")

local CreditsGroupBox = Tabs.Home:AddRightGroupbox('Developers', "circle-star")
CreditsGroupBox:AddLabel('[' .. CustomTextFunctions.color3toRichtext("BelowNatural", CustomUI.PresetColors.green) .. '] Owner', true)
CreditsGroupBox:AddLabel('[' .. CustomTextFunctions.color3toRichtext("Upio", CustomUI.PresetColors.green) .. '] Interface Designer', true)
CreditsGroupBox:AddLabel('[' .. CustomTextFunctions.color3toRichtext("Marlon", CustomUI.PresetColors.green) .. '] Aura Mogger', true)
CreditsGroupBox:AddLabel('[' .. CustomTextFunctions.color3toRichtext("L3monnn", CustomUI.PresetColors.green) .. '] *Random Kid*', true)

local InfoBox = Tabs.Home:AddRightGroupbox('Status', "info")
InfoBox:AddLabel('🤣 All systems offline')
InfoBox:AddLabel('Soulfire is a discontinued prototype. Will update in ... never 🤣', true)

InfoBox:AddButton('Join Discord', function()
    Library:Notify({
        Title = "Important",
        Description = "67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67",
        Duration = 5,
    })
end)

local UpdatesBox = Tabs.Home:AddRightGroupbox('Updates', 'megaphone')
UpdatesBox:AddLabel('[' .. CustomTextFunctions.color3toRichtext("ALPHA 1.0.0", CustomUI.PresetColors.green) .. '] - Initial Release\n [+] Added Mason67\n [!] Fixed your aura🤣\n [-] Removed Herobrine', true)

-- ==========================================
-- AGENT TAB
-- ==========================================

local function UpdateAgentStatus()
    local agentState = "Inactive"
    local color = CustomUI.PresetColors.green

    if RuntimeState.processorRunning and RuntimeState.payload then
        agentState = "Running"
        color = CustomUI.PresetColors.green
    elseif RuntimeState.processorRunning then
        agentState = "Active"
        color = CustomUI.PresetColors.green
    elseif RuntimeState.processorRunning and Toggles.PauseAgent.Value == true then
        agentState = "Paused"
        color = CustomUI.PresetColors.orange
    else
        agentState = "Inactive"
        color = CustomUI.PresetColors.red
    end
    
    Library.Labels.AgentStatus:SetText('Status: <b>' .. CustomTextFunctions.color3toRichtext(agentState, color) .. '</b>')
end

local MasterBox = Tabs.Agent:AddLeftGroupbox('Master Controls', "crown")
MasterBox:AddLabel('AgentStatus', { Text = 'Status: <b>' .. CustomTextFunctions.color3toRichtext("Inactive", CustomUI.PresetColors.red) .. '</b>' })
MasterBox:AddLabel('AgentPayload', { Text = 'Payload: <b>Empty</b>' })
MasterBox:AddToggle('PauseAgent', { Text = 'Pause Agent'})
MasterBox:AddButton({ Text = 'Terminate', DoubleClick = true, Func = function()
    RuntimeState.processorRunning = false
    UpdateAgentStatus()
    Library.Labels.AgentPayload:SetText('Payload: <b>Empty</b>')
end}):AddButton({ Text = 'Panic', DoubleClick = true, Func = function() 
    RuntimeState.processorRunning = false
    UpdateAgentStatus()
    Library.Labels.AgentPayload:SetText('Payload: <b>Empty</b>')
end})

Toggles.PauseAgent:OnChanged(function(state)
    RuntimeState.paused = state
    UpdateAgentStatus()
end)

local SecurityBox = Tabs.Agent:AddLeftGroupbox('Security', "shield")
SecurityBox:AddToggle('SafeMode', { 
    Text = 'Safe Mode', 
    Default = (newcclosure and cloneref and HiddenGui and getgenv) and true or false,
    Tooltip = "Enables various bypasses to avoid common anti-cheat detection methods.",
    DisabledTooltip = "Some bypasses may not be functioning properly",
    Disabled = not (newcclosure and cloneref and HiddenGui and getgenv) and true or false,
}) 

SecurityBox:AddToggle('VirtualInput', { 
    Text = 'Virtual Input', 
    Default = firesignal and true or false,
    Tooltip = "Simulates real user interaction with the game's interface.",
    DisabledTooltip = "Your executor does not support the necessary functions to enable this feature.",
    Disabled = not firesignal and true or false,
})

SecurityBox:AddToggle('WorldInput', { 
    Text = 'World Input',
    Default = (hookfunction and firesignal) and true or false,
    Tooltip = "Simulates real user interaction with towers, including placement and upgrades.",
    DisabledTooltip = "Your executor does not support the necessary functions to enable this feature.",
    Disabled = not (hookfunction and firesignal) and true or false,
})

SecurityBox:AddToggle('StaticLoadout', { 
    Text = 'Static Loadout', 
    Default = true,
    Tooltip = "Prevents Strategies from equipping or unequipping towers while in-game to avoid detection.",
})

local function SecuriyDialog(title, description, confirmCallback, cancelCallback)
    local Dialog
    Dialog = Window:AddDialog("DialogueIdx", {
        Title = title,
        Description = description,
        AutoDismiss = true,
        FooterButtons = {
            Cancel = {
                Title = "Cancel",
                Variant = "Ghost",
                Order = 1,
                Callback = function()
                    if cancelCallback then
                        cancelCallback()
                    end
                end
            },

            Disable = {
                Title = "Disable",
                Variant = "Destructive",
                Order = 2,
                Callback = function()
                    if confirmCallback then
                        confirmCallback()
                    end
                end
            },
        }
    })

    Dialog:SetButtonDisabled("Disable", true)
    
    Dialog:AddToggle("DisableSecondary", {
        Text = "I understand the risks",
        Callback = function(value) 
            Dialog:SetButtonDisabled("Disable", not value) 
        end
    })
end

Toggles.SafeMode:OnChanged(function(state)
    if state == false and not Toggles.SafeMode.Disabled then
        task.wait(0.1)
        Toggles.SafeMode:SetValue(true)
    end
end)

Toggles.VirtualInput:OnChanged(function(state)
    if state == false and SecurityFlags.VirtualInput == true then
        Toggles.VirtualInput:SetValue(true)
        SecuriyDialog("<font color='rgb(247, 199, 40)'>Warning</font>", "Disabling this feature may increase the risk of detection by anti-cheat systems. Are you sure you want to proceed?", function()
            SecurityFlags.VirtualInput = false
            Toggles.VirtualInput:SetValue(false)
        end)
    elseif state == true then
        SecurityFlags.VirtualInput = true
    end
end)

Toggles.WorldInput:OnChanged(function(state)
    if state == false and SecurityFlags.WorldInput == true then
        Toggles.WorldInput:SetValue(true)
        SecuriyDialog("<font color='rgb(247, 199, 40)'>Warning</font>", "Disabling this feature may increase the risk of detection by anti-cheat systems. Are you sure you want to proceed?", function()
            SecurityFlags.WorldInput = false
            Toggles.WorldInput:SetValue(false)
        end)
    elseif state == true then
        SecurityFlags.WorldInput = true
    end
end)

Toggles.StaticLoadout:OnChanged(function(state)
    if state == false and SecurityFlags.StaticLoadout == true then
        Toggles.StaticLoadout:SetValue(true)
        SecuriyDialog("<font color='rgb(247, 199, 40)'>Warning</font>", "Disabling this feature may increase the risk of detection by anti-cheat systems. Are you sure you want to proceed?", function()
            SecurityFlags.StaticLoadout = false
            Toggles.StaticLoadout:SetValue(false)
        end)
    elseif state == true then
        SecurityFlags.StaticLoadout = true
    end
end)

local AutoGatlingBox = Tabs.Agent:AddLeftGroupbox('Gatling Gun', "bot")
AutoGatlingBox:AddToggle('AutoFire', { Text = 'Auto Fire', Tooltip = "Automatically aims and fires at enemies within range"})
AutoGatlingBox:AddToggle('EndPriority', { Text = 'Smart Prioritize', Tooltip = "Prioritize Enemies about to enter base."})
AutoGatlingBox:AddDropdown('AimPriority', { Text = 'Target Priority', Default = 1, Values = {'Closest to Base', 'Farthest to Base', 'Strongest', 'Weakest', 'Closest to Gun'}})

local AgentFeaturesBox = Tabs.Agent:AddRightGroupbox('Agent Features', 'cpu')
AgentFeaturesBox:AddToggle('AutoSkip', { Text = 'Auto Skip', Tooltip = "Automatically skips every wave."})
AgentFeaturesBox:AddToggle('AutoRejoin', { Text = 'Auto Rejoin', Tooltip = "Automatically rejoins the game if disconnected or ended."})

AgentFeaturesBox:AddDropdown('Auto Abilties', { Text = 'Auto Abilities', AllowNull = true, Multi = true, Values = {'Call of Arms', 'Caravan', 'DJ Booth', 'Necromancer', 'Military Base', 'Mercenary Base'}})
AgentFeaturesBox:AddSlider('MilitaryPathDistance', { Text = 'Air Strike Path Distance', Default = 50, Min = 10, Max = 100, Compact = true, HideMax = true})
AgentFeaturesBox:AddSlider('MercenaryPathDistance', { Text = 'Airdrop Path Distance', Default = 50, Min = 10, Max = 100, Compact = true, HideMax = true})

local AgentSettingsBox = Tabs.Agent:AddRightGroupbox('Agent Settings', 'sliders-vertical')
AgentSettingsBox:AddToggle('AntiAFK', { Text = 'Anti AFK', Default = true, Tooltip = "Prevents you from being kicked when Idle for too long."})
AgentSettingsBox:AddToggle('BlockInput', { Text = 'Block Input', Tooltip = "Prevents user input while the auto-strategy is active to avoid interference."})

AgentSettingsBox:AddDropdown('Timescale', { Text = 'Timescale', Default = 2, Values = {0.5, 1, 1.5, 2}, DisabledValues = {0.5, 1.5, 2}})
AgentSettingsBox:AddDropdown('Modifiers', { Text = 'Enable Modifiers', AllowNull = true, Multi = true, Values = {'Double Health', 'Half Cash', 'Camo Bloons', 'Fortified Bloons'}})

AgentSettingsBox:AddToggle('AutoSellFarms', { Text = 'Auto-Sell Farms', Tooltip = "Automatically sells farms at the specified wave to maximize cash flow."})
AgentSettingsBox:AddSlider('SellFarmsWave', { Text = 'Wave', Default = 40, Min = 1, Max = 100, Compact = true, HideMax = true})

-- ==========================================
-- PRESETS TAB
-- ==========================================
local function ViewPreset(preset: { Name: string, Mode: string, Map: string, Towers: {string} })
    Library.Labels.SelectedPreset:SetText("Name: <b>" .. preset.Name .. "</b>")
    Library.Labels.SelectedMode:SetText("Mode: " .. preset.Mode)
    Library.Labels.SelectedMap:SetText("Map: " .. preset.Map)
    Library.Labels.SelectedTowers:SetText("Towers: " .. table.concat(preset.Towers, ", "))
end

local PresetSelectionBox = Tabs.Presets:AddLeftGroupbox("Current Selection", "notepad-text")
PresetSelectionBox:AddLabel("SelectedPreset", { Text = "Name: <b>None</b>", DoesWrap = true })
PresetSelectionBox:AddLabel("SelectedMode", { Text = "Mode: None" })
PresetSelectionBox:AddLabel("SelectedMap", { Text = "Map: None" })
PresetSelectionBox:AddLabel("SelectedTowers", { Text = "Towers: None" })
PresetSelectionBox:AddButton({ Text = "Run Strategy", Func = function() end })

local CustomStratBox = Tabs.Presets:AddLeftGroupbox('Saved Strategies', 'save')
CustomStratBox:AddDropdown('CustomStratDropdown', { Text = 'Select Strategy', AllowNull = true, Values = {'Example1', 'Example2', 'Example3'}})
CustomStratBox:AddButton({ Text = 'Load Strategy', Func = function() end })
CustomStratBox:AddButton({ Text = 'Export to Clipboard', Func = function() end })

Options.CustomStratDropdown:OnChanged(function(state)
    local fileName = state
    local macro = readfile("Soulfire/TowerDefenseSimulator/" .. fileName .. ".lua")

    local dataBlock = macro:match("data%s*=%s*(%b{})")
    if not dataBlock then
        error("No data table found in macro")
    end

    local chunk = "return " .. dataBlock

    local fn = loadstring(chunk)
    setfenv(fn, {}) -- optional sandbox
    local ok, data = pcall(fn)

    if not ok then
        error("Failed to parse data table: " .. tostring(data))
    end

    print("Author:", data.Author)
    print("Mode:", data.Mode)
    print("Map:", data.Map)
    print("Towers:", table.concat(data.Towers, ", "))
    print("Modifiers:", table.concat(data.Modifiers, ", ")) 
end)

local PresetLibraryBox = Tabs.Presets:AddRightGroupbox('Presets', 'library')
PresetLibraryBox:AddLabel('📚 <b>How to Use:</b> Select a preset from the list then press "Run Strategy" to get started!', true)
PresetLibraryBox:AddDivider()
PresetLibraryBox:AddButton({ Text = 'Easy Mode', Func = function() ViewPreset({ Name = "Easy Mode", Mode = "Easy", Map = "Inverted Temple", Towers = {"Dart Monkey", "Sniper Monkey", "Farm"} }) end })
PresetLibraryBox:AddButton({ Text = 'Casual Mode', Func = function() ViewPreset({ Name = "Casual Mode", Mode = "Casual", Map = "Inverted Temple", Towers = {"Dart Monkey", "Sniper Monkey", "Farm"} }) end })
PresetLibraryBox:AddButton({ Text = 'Intermediate Mode', Func = function() ViewPreset({ Name = "Intermediate Mode", Mode = "Intermediate", Map = "Inverted Temple", Towers = {"Dart Monkey", "Sniper Monkey", "Farm"} }) end })
PresetLibraryBox:AddButton({ Text = 'Molten Mode', Func = function() ViewPreset({ Name = "Molten Mode", Mode = "Molten", Map = "Inverted Temple", Towers = {"Dart Monkey", "Sniper Monkey", "Farm"} }) end })
PresetLibraryBox:AddButton({ Text = 'Fallen Mode', Func = function() ViewPreset({ Name = "Fallen Mode", Mode = "Fallen", Map = "Inverted Temple", Towers = {"Dart Monkey", "Sniper Monkey", "Farm"} }) end })
PresetLibraryBox:AddButton({ Text = 'Frost Mode', Func = function() ViewPreset({ Name = "Frost Mode", Mode = "Frost", Map = "Inverted Temple", Towers = {"Dart Monkey", "Sniper Monkey", "Farm"} }) end })

-- ==========================================
-- MAIN TAB
-- ==========================================
Tabs.Main:UpdateWarningBox({
    Title = "Warning",
    Text = "Interacting with features on this tab while the agent is active may cause unexpected behavior.",
    IsNormal = true,
    Visible = true,
    LockSize = true,
})

local HelpersBox = Tabs.Main:AddLeftGroupbox('Tower Helpers', "pencil")
HelpersBox:AddDropdown('SpecificTower', { Text = 'Select Tower Type', Default = 1, Values = {'Scout', 'Sniper', 'Farm', 'Accelerater'} })
HelpersBox:AddButton({ Text = 'Upgrade Selected Tower', Func = function() end })
HelpersBox:AddButton({ Text = 'Sell Selected Towers', Func = function() end })

HelpersBox:AddDivider("All Towers")
HelpersBox:AddButton({ Text = 'Upgrade All Towers', Func = function() end })
HelpersBox:AddButton({ Text = 'Sell All Towers', Func = function() end })

local TowerStackerBox = Tabs.Main:AddLeftGroupbox('Tower Stacker', "atom")
TowerStackerBox:AddLabel('📚 <b>Guide:</b> The first tower needs to be stacked before placing more on top of eachother', true)
TowerStackerBox:AddLabel('⚠️ <b>Warning:</b> Use at own risk!', true)
TowerStackerBox:AddToggle('StackTower', { Text = 'Stack Tower', Tooltip = "Allows placing multiple towers in the same position"})

local BasicInfoBox = Tabs.Main:AddRightGroupbox('Session Info', "chart-no-axes-column")
BasicInfoBox:AddLabel('Coins: 0')
BasicInfoBox:AddLabel('Gems: 0')
BasicInfoBox:AddLabel('Level: 67')
BasicInfoBox:AddLabel('Triumphs: 6')
BasicInfoBox:AddLabel('Loses: 7')
BasicInfoBox:AddDivider()
BasicInfoBox:AddLabel('Current Mode: Easy')
BasicInfoBox:AddLabel('Elapsed Time: 0')
BasicInfoBox:AddLabel('Current Wave: 0')
BasicInfoBox:AddLabel('Current Cash: $41')

-- ==========================================
-- EXTRA TAB
-- ==========================================
local RealName = LocalPlayer.Name
local RealDisplay = LocalPlayer.DisplayName
local CurrentSpoofedName = RealName
local SpoofEngineEnabled = false

local function SetupDynamicSpoof()
    if SpoofEngineEnabled then return end
    SpoofEngineEnabled = true
    
    if _connections["NameSpoofCleanup"] then 
        _connections["NameSpoofCleanup"]:Disconnect() 
        _connections["NameSpoofCleanup"] = nil
    end

    CurrentSpoofedName = CurrentSpoofedName or RealName

    local MainRoots = {
        findPath(CoreGui, {"RobloxGui"}), 
        findPath(CoreGui, {"PlayerList"}),
        findPath(CoreGui, {"ExperienceChat"}),
        PlayerGui, 
        workspace
    }

    local function update(obj)
        local text = obj.Text
        if text:find(RealName) or text:find(RealDisplay) then
            task.wait()
            obj.Text = text:gsub(RealName, CurrentSpoofedName):gsub(RealDisplay, CurrentSpoofedName)
        end
    end

    local function applySpoof(obj: Instance)
        if obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
            
            update(obj)
            local conn = obj:GetPropertyChangedSignal("Text"):Connect(function() update(obj) end)
            if not _connections["SpoofConns"] then _connections["SpoofConns"] = {} end
            table.insert(_connections["SpoofConns"], conn)
        end
    end

    for _, root in ipairs(MainRoots) do
        for _, desc in ipairs(root:GetDescendants()) do pcall(applySpoof, desc) end
        
        local conn = root.DescendantAdded:Connect(function(desc) pcall(applySpoof, desc) end)
        
        if not _connections["SpoofConns"] then _connections["SpoofConns"] = {} end
        table.insert(_connections["SpoofConns"], conn)
    end

    _connections["NameSpoofCleanup"] = {Disconnect = function() 
        for _, c in ipairs(_connections["SpoofConns"] or {}) do c:Disconnect() end 
        _connections["SpoofConns"] = {} 
    end}
end

local function spoofAvatar(targetUsername)
    local char = LocalPlayer.Character
    local humanoid: Humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return warn("Character/Humanoid not found") end

    local successId, targetId = pcall(function() 
        return Players:GetUserIdFromNameAsync(targetUsername) 
    end)
    if not successId then return warn("User not found.") end

    local successDesc, targetDesc = pcall(function() 
        return Players:GetHumanoidDescriptionFromUserIdAsync(targetId) 
    end)

    if successDesc and targetDesc then
        local current = humanoid:GetAppliedDescription()
        targetDesc.HeightScale = current.HeightScale
        targetDesc.WidthScale = current.WidthScale
        targetDesc.DepthScale = current.DepthScale
        targetDesc.HeadScale = current.HeadScale
        targetDesc.ProportionScale = current.ProportionScale
        targetDesc.BodyTypeScale = current.BodyTypeScale

        for _, item in ipairs(char:GetChildren()) do
            if item:IsA("Accessory") then
                item:Destroy()
            end

            if item:IsA("Shirt") or item:IsA("Pants") then
                item:Destroy()
            end
        end

        local successApply = pcall(function()
            humanoid:ApplyDescriptionClientServer(targetDesc)
        end)
        
        if not successApply then
            humanoid:ApplyDescriptionResetAsync(targetDesc)
        end
    end

    return
end

local function SendWebhook(data: { Event: string?, Mode: string?, Map: string?, Time: string?, Rewards: { [string]: number }?, Stats: { [string]: number }?, IsTest: boolean?, ErrorMessage: string? })
    data.IsTest = data.IsTest or false
    local eventText = data.Event or "Unknown"
    local modeText = data.Mode or "Unknown Mode"
    local mapText = data.Map or "Unknown Map"
    local timeText = data.Time or "Unknown Time"

    if type(request) ~= "function" then return end
    if not Options.WebhookUrl.Value or not string.match(Options.WebhookUrl.Value, "https://") then return end

    local colormapping = { ["Win"] = 3066993, ["Loss"] = 15158332, ["Error"] = 15105570, ["Test"] = 3447003 }
    local titlemapping = { ["Win"] = "🏆 Victory!", ["Loss"] = "❌ Defeat!", ["Error"] = "⚠️ An Error Occurred" }
    local rewardmapping = { ["Coins"] = "🪙", ["Gems"] = "💎", ["Experience"] = "⭐", ["Bonus"] = "🎁" }
    local statsmapping = { ["Level"] = "⭐", ["Triumphs"] = "🏆", ["Loses"] = "💀" }

    local currentColor = colormapping[eventText] or colormapping["Test"]

    local payload = {
        username = "Soulfire",
        avatar_url = "https://github.com/L3monnn/Soulfire/blob/main/Assets/Logo.png?raw=true",
        flags = 32768,
        content = "",
        components = {}
    }

    if Options.PingSettings.Value and table.find(Options.PingSettings.Value, "Ping on " .. eventText) then
        payload.content = (Options.DiscordUserId.Value ~= "") and ("<@" .. Options.DiscordUserId.Value .. ">") or "@everyone"
    end

    local mainContainer = {
        type = 17,
        accent_color = currentColor,
        components = {}
    }

    table.insert(mainContainer.components, {
        type = 13,
        title = "Soulfire Logger",
        icon_url = "https://githubusercontent.com"
    })

    if data.IsTest then
        table.insert(mainContainer.components, {
            type = 10,
            content = "## 🛰️ Test Webhook\nYour webhook is configured correctly! ✅"
        })
        table.insert(mainContainer.components, {
            type = 10,
            content = "> **Account:** `MasonBoi67`\n> **Executor:** `" .. (identifyexecutor() or "Unknown") .. "`"
        })
    elseif eventText == "Error" then
        table.insert(mainContainer.components, {
            type = 10,
            content = "### " .. titlemapping["Error"] .. "\nAn error occurred during your session."
        })
        table.insert(mainContainer.components, {
            type = 10,
            content = "```\n" .. (data.ErrorMessage or "No details provided") .. "\n```"
        })
    else
        table.insert(mainContainer.components, {
            type = 10,
            content = "### " .. (titlemapping[eventText] or "Match Result") .. "\n" ..
                      "> **Map:** `" .. mapText .. "`\n" ..
                      "> **Mode:** `" .. modeText .. "`\n" ..
                      "> **Time:** `" .. timeText .. "`"
        })

        local rewardsText = ""
        for reward, amount in pairs(data.Rewards or {}) do
            rewardsText = rewardsText .. (rewardmapping[reward] or "🔹") .. " " .. reward .. ": `" .. amount .. "`\n"
        end
        if rewardsText ~= "" then
            table.insert(mainContainer.components, { type = 10, content = "**✨ Rewards**\n" .. rewardsText })
        end

        local statsText = ""
        for stat, value in pairs(data.Stats or {}) do
            statsText = statsText .. (statsmapping[stat] or "📊") .. " " .. stat .. ": `" .. value .. "`\n"
        end
        if statsText ~= "" then
            table.insert(mainContainer.components, { type = 10, content = "**📊 Session Totals**\n" .. statsText })
        end
    end

    table.insert(mainContainer.components, {
        type = 10,
        content = "-# Join our server for strategies and updates!"
    })

    table.insert(mainContainer.components, {
        type = 1,
        components = {
            {
                type = 2,
                style = 5,
                label = "Join Server",
                emoji = { name = "🪐" },
                url = "67"
            }
        }
    })

    table.insert(payload.components, mainContainer)

    local success, response = pcall(function()
        return request({
            Url = Options.WebhookUrl.Value,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = game:GetService("HttpService"):JSONEncode(payload)
        })
    end)

    if not success then
        warn("❌ Webhook Error: " .. tostring(response))
    end
end

local MiscBox = Tabs.Extra:AddLeftGroupbox('Extra Features', 'sliders-horizontal')
MiscBox:AddToggle('AutoWalk', { Text = 'Auto Walk'})
MiscBox:AddToggle('AutoSticker', { Text = 'Auto Sticker'})
MiscBox:AddToggle('AutoLogbooks', { Text = 'Auto Pickup Log-books'})
MiscBox:AddToggle('AutoClaim', { Text = 'Auto Claim Rewards'})

local StreamerBox = Tabs.Extra:AddLeftGroupbox('Streamer Mode', 'drama')
StreamerBox:AddToggle('HideNotifications', { Text = 'Hide Notifications'})
StreamerBox:AddToggle('HideWatermark', { Text = 'Hide Watermark'})
StreamerBox:AddInput("SpoofName", { Text = "Spoof Name", Placeholder = LocalPlayer.DisplayName, Finished = true, AllowEmpty = false, MaxLength = 30})
StreamerBox:AddInput("SpoofAvatar", { Text = "Spoof Avatar", Placeholder = LocalPlayer.DisplayName, Finished = true, AllowEmpty = false, MaxLength = 30})

Options.SpoofName:OnChanged(function(state)
    if state ~= nil and state ~= "" then
        CurrentSpoofedName = state
        
        if not SpoofEngineEnabled then
            SetupDynamicSpoof()
        end
    end
end)

Options.SpoofAvatar:OnChanged(function(state)
    if state ~= nil and state ~= "" then
        spoofAvatar(state)
    end
end)

local OptimizationBox = Tabs.Extra:AddRightGroupbox('Optimization', 'gauge')
OptimizationBox:AddToggle('AntiLag', { Text = 'Anti-Lag', Disabled = true, Tooltip = "Soon boii" })
OptimizationBox:AddToggle('Disable3DRendering', { Text = 'Disable 3D Rendering'})

Toggles.Disable3DRendering:OnChanged(function(state)
    RunService:Set3dRenderingEnabled(state == false)
end)

local WebHookBox = Tabs.Extra:AddRightGroupbox('Webhook', 'webhook')

WebHookBox:AddInput("WebhookUrl", { 
    Text = "Discord Webhook URL", 
    Placeholder = "https://discord.com/api/webhooks/...",
})

WebHookBox:AddInput("DiscordUserId", { 
    Text = "User/Role ID to Ping", 
    Placeholder = "User ID", 
    Numeric = true,
})

WebHookBox:AddDropdown('PingSettings', { Text = 'Ping Settings', Default = {'Ping on Loss', 'Ping on Error'}, AllowNull = true, Multi = true, Values = {'Ping @everyone', 'Ping on Win', 'Ping on Loss', 'Ping on Error'}})
WebHookBox:AddDropdown('EventTriggers', { Text = 'Event Triggers', Default = {'Notify on Win', 'Notify on Loss', 'Notify on Error'}, AllowNull = true, Multi = true, Values = {'Notify on Win', 'Notify on Loss', 'Notify on Error'}})

WebHookBox:AddDivider("Controls")
WebHookBox:AddToggle('EnableWebhook', { Text = 'Enable Webhook', Tooltip = "Master toggle for all webhook notifications"})
WebHookBox:AddButton('Test Webhook', function() SendWebhook({IsTest = true}) end)

-- ==========================================
-- TOOLS TAB
-- ==========================================

local LoggerBox = Tabs.Tools:AddLeftGroupbox('Strategy Logger', 'square-pen')
LoggerBox:AddButton('File Save Current Strategy', "Saves", function() end)
LoggerBox:AddButton('Clear Console', function() 
    LogConsoleHistory = {}
    LogConsoleLabel:SetText('') 
end)

local LogConsole = Tabs.Tools:AddLeftGroupbox('Console', "radio")
LogConsoleLabel = LogConsole:AddLabel('LogConsoleLabel', {
    Text = "Empty",
    Size = 10,
    DoesWrap = true,
})

local RecorderBox = Tabs.Tools:AddRightGroupbox('Strategy Recorder', 'clapperboard')

RecorderBox:AddToggle('RecordToggle', {
    Text = 'Record Actions',
    Tooltip = "Records your actions in-game to create a strategy that can be shared with others.",
    DisabledTooltip = "Your executor does not support the necessary functions to enable this feature.",
    Disabled = not (hookfunction and hookmetamethod and getnamecallmethod and checkcaller) and true or false,
})

Toggles.RecordToggle:OnChanged(function(state)
    if state then
        RecordedMacro = {}
        RecordConsoleHistory = {}
        printConsole("Started Recording", "record", "info")
    else
        printConsole("Stopped Recording", "record", "info")
    end
end)

RecorderBox:AddButton('File Save Strategy', function()
    if true then
        return
    end

    if #RecordedMacro == 0 then 
        printConsole("Nothing to save!", "record", "warning") 
        return 
    end
    
    if not writefile then
        printConsole("File write function not available!", "record", "error")
        return
    end
    
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local filename = "Soulfire/TowerDefenseSimulator/Strategy_" .. timestamp .. ".lua"
    
    local FileContent = "-- Strategy Generated with Soulfire\n-- Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\nlocal data = " .. game:GetService("HttpService"):JSONEncode(RecordedMacro) .. "\n\nreturn data"
    
    pcall(function()
        writefile(filename, FileContent)
        printConsole("Strategy saved as: Strategy_" .. timestamp, "record", "success")
    end)
end)

RecorderBox:AddButton('Export Strategy', function()
    if #RecordedMacro == 0 then 
        printConsole("Nothing to export!", "record", "warning") 
        return 
    end
        
    local ExportString = "-- Strategy Generated with Soulfire\nreturn " .. game:GetService("HttpService"):JSONEncode(RecordedMacro)

    if #ExportString > 128 then
        printConsole("Strat too long to copy! Length: " .. #ExportString, "record", "error")
        return
    end

    if setclipboard then
        setclipboard(ExportString)
        printConsole("Strat copied to clipboard!", "record", "success")
    else
        printConsole("Clipboard function not available!", "record", "error")
    end
end)

local RecordConsole = Tabs.Tools:AddRightGroupbox('Recording Console', "cctv")
RecordConsoleLabel = RecordConsole:AddLabel('RecordConsoleLabel', {
    Text = "Empty",
    Size = 10,
    DoesWrap = true,
})

-- ==========================================
-- SETTINGS TAB
-- ==========================================

local MenuGroup = Tabs.Settings:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
	Default = Library.KeybindFrame and Library.KeybindFrame.Visible or false,
	Text = "Open Keybind Menu",
	Callback = function(value)
		if Library.KeybindFrame then
			Library.KeybindFrame.Visible = value
		end
	end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
	Text = "Custom Cursor",
	Default = true,
	Callback = function(Value)
		Library.ShowCustomCursor = Value
	end,
})
MenuGroup:AddDropdown("NotificationSide", {
	Values = { "Left", "Right" },
	Default = "Right",

	Text = "Notification Side",

	Callback = function(Value)
		Library:SetNotifySide(Value)
	end,
})
MenuGroup:AddDropdown("DPIDropdown", {
	Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",

	Text = "DPI Scale",

	Callback = function(Value)
		Value = Value:gsub("%%", "")
		local DPI = tonumber(Value)

		Library:SetDPIScale(DPI)
	end,
})

MenuGroup:AddSlider("UICornerSlider", {
	Text = "Corner Radius",
	Default = Library.CornerRadius,
	Min = 0,
	Max = 20,
	Rounding = 0,
	Callback = function(value)
		Window:SetCornerRadius(value)
	end
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind")
	:AddKeyPicker("MenuKeybind", { 
        Default = "RightShift", DefaultModifiers = {}, NoUI = true, Text = "Menu keybind" })

Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddButton("Unload", function()
    for _, conn in pairs(_connections) do
        if typeof(conn) == "table" and typeof(conn.Disconnect) == "function" then
            conn:Disconnect()
        elseif typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end

    getgenv().Soulfire = nil
    shared.Soulfire = nil

	Library:Unload()
end)

getgenv().Soulfire = Soulfire
shared.Soulfire = Soulfire

--[[

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("Soulfire")
SaveManager:SetFolder("Soulfire/Universal")

SaveManager:BuildConfigSection(Tabs["Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

]]--
