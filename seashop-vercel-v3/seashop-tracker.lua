local BaseUrl = "https://animeadventurewebseashop.vercel.app"
local TrackerKey = "YOUR_TRACKER_API_KEY"
local Interval = 20

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer
local SendRequest = request
if not Player or type(SendRequest) ~= "function" then
    warn("Seashop Tracker: LocalPlayer or HTTP request is unavailable")
    return
end
local function child(parent, name)
    return parent and parent:FindFirstChild(name)
end

local function textOf(object)
    return object and object:IsA("TextLabel") and object.Text or nil
end

local function readTeam()
    local hud = child(child(Player, "PlayerGui"), "spawn_units")
    local lives = child(hud, "Lives")
    local container = child(child(lives, "Frame"), "Units")
    if not container then return nil end
    local team = {}
    for slot = 1, 6 do
        local card = child(container, tostring(slot))
        local main = child(card, "Main")
        local label = textOf(child(card, "name")) or textOf(child(main, "Name"))
        local name = label and label:match("^%s*(.-)%s*$")
        if name and name ~= "" and not name:match("^%?+$") then
            local levelText = textOf(child(main, "Level"))
            local traits, seen = {}, {}
            local tray = child(main, "TraitIcons")
            if tray then
                for _, icon in ipairs(tray:GetChildren()) do
                    local key = icon.Name:lower()
                    if (icon:IsA("ImageLabel") or icon:IsA("ImageButton")) and icon.Visible
                        and icon.Image ~= "" and not seen[key] then
                        seen[key] = true
                        table.insert(traits, key)
                    end
                end
            end
            table.insert(team, {
                slot = slot, name = name, level = levelText and tonumber(levelText:match("%d+")),
                traits = traits,
            })
        end
    end
    return team
end

local function numberValue(parent, name)
    local value = child(parent, name)
    if value and value:IsA("ValueBase") then
        return tonumber(value.Value)
    end
end

local function reward(entry)
    if not entry or not entry:IsA("GuiObject") or not entry.Visible then
        return
    end
    local label = child(child(entry, "Main"), "Amount")
    if label and label:IsA("TextLabel") then
        local cleaned = label.Text:gsub(",", ""):match("%d+")
        return tonumber(cleaned)
    end
end

local function itemImage(entry)
    for _, object in ipairs(entry:GetDescendants()) do
        if object:IsA("ImageLabel") or object:IsA("ImageButton") then
            local n = object.Name:lower()
            if n == "icon" or n == "image" or n == "itemimage" or n == "itemicon" then
                local id = object.Image:match("rbxassetid://(%d+)") or object.Image:match("[?&]id=(%d+)")
                if id then return id end
            end
        end
    end
end
local function readRound()
    local results = child(child(Player, "PlayerGui"), "ResultsUI")
    if not results or not results:IsA("ScreenGui") or not results.Enabled then
        return
    end
    local holder = child(results, "Holder")
    local stage = child(holder, "LevelName")
    local list = child(child(holder, "LevelRewards"), "ScrollingFrame")
    local items = {}
    if list then
        for _, entry in ipairs(list:GetChildren()) do
            if entry.Name ~= "GemReward" and entry.Name ~= "GoldReward" then
                local count = reward(entry)
                if count and #items < 50 then
                    local title = child(child(entry, "Main"), "Name")
                    local label = title and title:IsA("TextLabel") and title.Text or entry.Name
                    table.insert(items, {name = label, amount = count, imageId = itemImage(entry)})
                end
            end
        end
    end
    return {
        items = items,
        stage = stage and stage:IsA("TextLabel") and stage.Text or "",
        gems = reward(child(list, "GemReward")),
        gold = reward(child(list, "GoldReward")),
    }
end

local env = getgenv and getgenv() or _G
if env.SEASHOP_AA_STOP then env.SEASHOP_AA_STOP() end
local function loadModule(url)
    local r = SendRequest({Url = url, Method = "GET"})
    assert(r and r.StatusCode == 200, "Seashop UI download failed")
    return assert(loadstring(r.Body))()
end
local ok, Fluent = pcall(loadModule, "https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua")
if not ok then warn("Seashop: Fluent download failed") return end
local Window = Fluent:CreateWindow({
    Title = "Seashop | Anime Adventures", SubTitle = "Tracker",
    TabWidth = 150, Size = UDim2.fromOffset(580, 460),
    Acrylic = false, Theme = "Dark", MinimizeKey = Enum.KeyCode.LeftControl
})
local Tabs = {
    Main = Window:AddTab({Title = "Tracker", Icon = "radio"}),
    Settings = Window:AddTab({Title = "Settings", Icon = "settings"})
}
local running, enabled, busy = true, false, false
local description, draft = "", ""
local lastRound
local status = Tabs.Main:AddParagraph({Title = "Connection", Content = "Tracking is off"})
local url = BaseUrl:gsub("/+$", "") .. "/api/player?id=" .. tostring(Player.UserId)
local function send()
    if busy or not running then return end
    busy = true
    local success, r = pcall(function()
        lastRound = readRound() or lastRound
        local stats = child(Player, "_stats")
        return SendRequest({
            Url = url, Method = "POST",
            Headers = {["Content-Type"] = "application/json", ["X-API-Key"] = TrackerKey},
            Body = HttpService:JSONEncode({
                userId = Player.UserId, username = Player.Name, displayName = Player.DisplayName,
                gems = numberValue(stats, "gem_amount"), gold = numberValue(stats, "gold_amount"),
                wave = numberValue(workspace, "_wave_num"), round = lastRound,
                description = description, tracking = enabled, team = readTeam()
            })
        })
    end)
    busy = false
    if not running then return end
    local code = success and type(r) == "table" and r.StatusCode
    status:SetDesc(code == 200 and (enabled and "Synced at " .. os.date("%H:%M:%S") or "Tracking paused")
        or ("Sync failed: " .. tostring(code or "request error")))
end
local function queueSend()
    task.spawn(function()
        while busy and running do task.wait(0.1) end
        if running then send() end
    end)
end
local toggle = Tabs.Main:AddToggle("AutoTrack", {Title = "Auto Track", Default = false})
toggle:OnChanged(function(value)
    enabled = value == true
    queueSend()
end)
Tabs.Main:AddInput("FarmDescription", {
    Title = "Farm description", Default = "", Placeholder = "Farming gems / Summer Hunt",
    Numeric = false, Finished = false,
    Callback = function(value) draft = tostring(value) end
})
local function applyDescription()
    local boundary = utf8.offset(draft, 81)
    description = boundary and draft:sub(1, boundary - 1) or draft
end
Tabs.Main:AddButton({
    Title = "Set status", Description = "Apply the description to your website",
    Callback = function() applyDescription() queueSend() end
})
Tabs.Main:AddButton({Title = "Sync now", Callback = queueSend})
local restore = Instance.new("TextButton")
restore.Name = "SeashopRestore"
restore.Size = UDim2.fromOffset(90, 40)
restore.Position = UDim2.new(1, -105, 0, 20)
restore.Text = "Seashop"
restore.TextColor3 = Color3.fromRGB(92, 230, 203)
restore.BackgroundColor3 = Color3.fromRGB(18, 30, 40)
restore.Visible = false
restore.Parent = Fluent.GUI
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = restore
local originalMinimize = Window.Minimize
function Window:Minimize()
    originalMinimize(self)
    restore.Visible = Window.Minimized == true
end
restore.Activated:Connect(function() Window:Minimize() end)
env.SEASHOP_AA_STOP = function()
    running = false
    restore:Destroy()
    if not Fluent.Unloaded then Fluent:Destroy() end
end
local loaded = pcall(function()
    local SaveManager = loadModule("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua")
    local InterfaceManager = loadModule("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua")
    SaveManager:SetLibrary(Fluent)
    InterfaceManager:SetLibrary(Fluent)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({})
    InterfaceManager:SetFolder("SeashopTracker")
    SaveManager:SetFolder("SeashopTracker/AnimeAdventures/" .. tostring(Player.UserId))
    InterfaceManager:BuildInterfaceSection(Tabs.Settings)
    SaveManager:BuildConfigSection(Tabs.Settings)
    SaveManager:LoadAutoloadConfig()
    draft = Fluent.Options.FarmDescription.Value or draft
    applyDescription()
end)
if not loaded then
    Fluent:Notify({Title = "Settings", Content = "Config unavailable. Tracker still works.", Duration = 5})
end
Window:SelectTab(1)
task.spawn(function()
    local nextSend = 0
    while running and not Fluent.Unloaded do
        if enabled and os.clock() >= nextSend then
            send()
            nextSend = os.clock() + Interval
        end
        task.wait(0.5)
    end
    if running then env.SEASHOP_AA_STOP() end
end)
