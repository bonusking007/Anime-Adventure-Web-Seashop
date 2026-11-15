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

local function shown(object, playerGui)
    while object and object ~= playerGui do
        if object:IsA("GuiObject") and not object.Visible then return false end
        if object:IsA("ScreenGui") and not object.Enabled then return false end
        object = object.Parent
    end
    return object == playerGui
end

local function readInventory()
    local gui = child(Player, "PlayerGui")
    if not gui then return nil end
    local inventoryLayer
    for _, object in ipairs(gui:GetDescendants()) do
        local text = textOf(object)
        if text and text:lower():match("^%s*inventory%s*$") and shown(object, gui) then
            inventoryLayer = object:FindFirstAncestorOfClass("ScreenGui")
            if inventoryLayer then break end
        end
    end
    if not inventoryLayer then return nil end
    local items, byName = {}, {}
    for _, card in ipairs(inventoryLayer:GetDescendants()) do
        if card:IsA("ImageButton") or card:IsA("Frame") then
            local main = child(card, "Main")
            local quantity = child(main, "Quantity")
            local quantityTag = child(main, "QuantityText")
            local rawName = textOf(child(card, "name")) or textOf(child(main, "Name"))
            local name = rawName and rawName:match("^%s*(.-)%s*$")
            local quantityText = textOf(quantity)
            if name and name ~= "" and not name:match("^%?+$") and quantityTag
                and child(main, "View") and quantityText and shown(card, gui) then
                local value = tonumber(quantityText:gsub(",", ""):match("^%s*(%d+)%s*$"))
                if not quantity.Visible then value = 1 end
                if value and value >= 1 then
                    local key = name:lower()
                    if byName[key] then
                        byName[key].amount = byName[key].amount + value
                    elseif #items < 160 then
                        local row = {name = name, amount = value}
                        byName[key] = row
                        table.insert(items, row)
                    end
                end
            end
        end
    end
    if #items == 0 then return nil end
    return items
end

local function itemRowsFromProfile(profile, catalog)
    if type(profile) ~= "table" then return nil end
    if type(profile.profile_data) == "table" then profile = profile.profile_data end
    local inventory = profile.inventory_profile_data or profile.inventory
    if type(inventory) ~= "table" then inventory = profile end
    if type(inventory.inventory_profile_data) == "table" then
        inventory = inventory.inventory_profile_data
    end
    local normal = inventory.normal_items
    local unique = inventory.unique_items
    if type(normal) ~= "table" and type(unique) ~= "table" then return nil end

    local quantities = {}
    local function add(id, quantity)
        if type(id) ~= "string" or type(catalog[id]) ~= "table" then return end
        if type(quantity) ~= "number" or quantity ~= math.floor(quantity) or quantity < 1 or quantity > 1e12 then return end
        quantities[id] = (quantities[id] or 0) + quantity
    end
    for key, value in pairs(type(normal) == "table" and normal or {}) do
        if type(value) == "table" then
            add(value.item_id or value.id or key, value.amount or value.quantity or value.count)
        else
            add(key, value)
        end
    end
    for key, value in pairs(type(unique) == "table" and unique or {}) do
        if type(value) == "table" then
            local id = value.item_id or value.id or (type(value.item) == "string" and value.item)
            if catalog[id] then
                add(id, 1)
            elseif type(key) == "string" and catalog[key] then
                local count = 0
                for _, instance in pairs(value) do
                    if type(instance) == "table" then count = count + 1 end
                end
                if count > 0 then add(key, count) end
            end
        elseif type(value) == "string" then
            add(value, 1)
        end
    end

    local rows, ids = {}, {}
    for id in pairs(quantities) do table.insert(ids, id) end
    table.sort(ids)
    for index = 1, math.min(#ids, 160) do
        local id = ids[index]
        local title = catalog[id].name
        table.insert(rows, {id = id, name = type(title) == "string" and title or id, amount = quantities[id]})
    end
    -- A nonempty input returning zero rows is an unknown format, not an empty bag.
    if #rows == 0 and (next(type(normal) == "table" and normal or {}) or next(type(unique) == "table" and unique or {})) then
        return nil
    end
    return rows
end

local function inventoryProviders()
    local storage = game:GetService("ReplicatedStorage")
    local endpoints = child(child(storage, "endpoints"), "client_to_server")
    local remote = child(endpoints, "get_player_session")
    local definitions = child(child(child(storage, "src"), "Data"), "Items")
    if not remote or not remote:IsA("RemoteFunction") or not definitions or not definitions:IsA("ModuleScript") then
        return nil
    end
    return remote, definitions
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
local sessionBag, inventoryMessage
local status = Tabs.Main:AddParagraph({Title = "Connection", Content = "Tracking is off"})
inventoryMessage = Tabs.Main:AddParagraph({Title = "Inventory", Content = "Waiting for game data"})
local url = BaseUrl:gsub("/+$", "") .. "/api/player?id=" .. tostring(Player.UserId)
local function send()
    if busy or not running then return end
    busy = true
    local success, r = pcall(function()
        lastRound = readRound() or lastRound
        local inventory = sessionBag or readInventory()
        local stats = child(Player, "_stats")
        return SendRequest({
            Url = url, Method = "POST",
            Headers = {["Content-Type"] = "application/json", ["X-API-Key"] = TrackerKey},
            Body = HttpService:JSONEncode({
                userId = Player.UserId, username = Player.Name, displayName = Player.DisplayName,
                gems = numberValue(stats, "gem_amount"), gold = numberValue(stats, "gold_amount"),
                wave = numberValue(workspace, "_wave_num"), round = lastRound,
                description = description, tracking = enabled, team = readTeam(), inventory = inventory
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
Tabs.Main:AddButton({Title = "Sync now", Description = "Tracking refreshes your inventory in the background", Callback = queueSend})
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
    local nextRead = 0
    local catalog
    local function showInventoryState(value)
        if running and not Fluent.Unloaded then inventoryMessage:SetDesc(value) end
    end
    while running and not Fluent.Unloaded do
        if not enabled then nextRead = 0 end
        if enabled and os.clock() >= nextRead then
            nextRead = os.clock() + 45
            local ok, rows = pcall(function()
                local remote, definitions = inventoryProviders()
                if not remote then return nil end
                catalog = catalog or require(definitions)
                if type(catalog) ~= "table" then return nil end
                return itemRowsFromProfile(remote:InvokeServer(), catalog)
            end)
            if ok and rows and running and enabled then
                sessionBag = rows
                showInventoryState(tostring(#rows) .. " item types from game data")
                queueSend()
            elseif running and enabled then
                sessionBag = nil
                showInventoryState("Game inventory format unavailable; watching Items UI automatically")
            end
        end
        task.wait(1)
    end
end)
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
