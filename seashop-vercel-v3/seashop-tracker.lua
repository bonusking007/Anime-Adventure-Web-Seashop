local BaseUrl = "https://YOUR-PROJECT.vercel.app"
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
if BaseUrl:find("YOUR%-PROJECT") or TrackerKey == "YOUR_TRACKER_API_KEY" then
    warn("Seashop Tracker: set BaseUrl and TrackerKey first")
    return
end

local function child(parent, name)
    return parent and parent:FindFirstChild(name)
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
                    table.insert(items, {name = label, amount = count})
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
local running = true
env.SEASHOP_AA_STOP = function() running = false end

local url = BaseUrl:gsub("/+$", "") .. "/api/player?id=" .. tostring(Player.UserId)
local lastRound
task.spawn(function()
    while running do
        lastRound = readRound() or lastRound
        local stats = child(Player, "_stats")
        local payload = {
            userId = Player.UserId,
            username = Player.Name,
            displayName = Player.DisplayName,
            gems = numberValue(stats, "gem_amount"),
            gold = numberValue(stats, "gold_amount"),
            wave = numberValue(workspace, "_wave_num"),
            round = lastRound,
        }
        local ok, result = pcall(SendRequest, {
            Url = url,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-API-Key"] = TrackerKey,
            },
            Body = HttpService:JSONEncode(payload),
        })
        if not ok or type(result) ~= "table" then
            warn("Seashop Tracker: request failed")
        elseif result.StatusCode ~= 200 then
            warn("Seashop Tracker: HTTP " .. tostring(result.StatusCode))
        end
        task.wait(Interval)
    end
end)
