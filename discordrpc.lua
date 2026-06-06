local cfg = {
    bridgePort = 4444,

    showGame = false,
    showGameId = true,
    showExecutor = false,
    showTime = true,
    showPing = true,

    details = "",
    statePrefix = "game: ",
    pingPrefix = "ping: ",
    menuState = "in main menu",

    largeImageKey = "matcha",
    largeImageText = "matcha lua",
    smallImageKey = "roblox",
    smallImageText = "roblox",

    updateInterval = 2,
}

local startTime = tick()
local bridgeUrl = "http://localhost:" .. cfg.bridgePort .. "/rpc"

local function jsonStr(s)
    return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\length', '\\length') .. '"'
end

local function toJson(t)
    local parts = {}
    for row, v in pairs(t) do
        local data
        if type(v) == "table" then
            data = toJson(v)
        elseif type(v) == "number" then
            data = tostring(v)
        elseif type(v) == "boolean" then
            data = tostring(v)
        elseif type(v) == "string" then
            data = jsonStr(v)
        else
            data = "null"
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function inMenu()
    local ok, pid = pcall(function() return game.PlaceId end)
    if not ok or not pid or pid == 0 then return true end
    return false
end

local function safeGetGameName()
    local ok, output = pcall(getgetname)
    if ok and output and output ~= "" then return output end
    local ok2, res2 = pcall(function() return game.Name end)
    if ok2 and res2 and res2 ~= "" and res2 ~= "Game" then return res2 end
    local ok3, res3 = pcall(function() return tostring(game.GameId) end)
    if ok3 and res3 and res3 ~= "0" then return "id:" .. res3 end
    return nil
end

local function buildPayload()
    if inMenu() then
        local payload = {
            details = cfg.menuState,
            assets  = {
                large_image = cfg.largeImageKey,
                large_text  = cfg.largeImageText,
            },
        }
        if cfg.showTime then
            payload.timestamps = { start = math.floor(startTime) }
        end
        return toJson(payload)
    end

    local gameName = cfg.showGame and safeGetGameName() or nil
    local gameId   = cfg.showGameId and (pcall(function() return tostring(game.GameId) end) and tostring(game.GameId) or nil) or nil
    local ping     = cfg.showPing and GetPingValue() or nil

    local stateStr
    if gameName then
        stateStr = cfg.statePrefix .. gameName
        if gameId then stateStr = stateStr .. " (" .. gameId .. ")" end
    elseif gameId then
        stateStr = cfg.statePrefix .. gameId
    end

    local detailStr = cfg.details
    if ping and cfg.showPing then
        detailStr = detailStr .. cfg.pingPrefix .. tostring(ping) .. "ms"
    end

    local payload = {
        details = detailStr,
        state   = stateStr,
        assets  = {
            large_image = cfg.largeImageKey,
            large_text  = cfg.largeImageText,
            small_image = cfg.smallImageKey,
            small_text  = cfg.smallImageText,
        },
    }

    if cfg.showTime then
        payload.timestamps = { start = math.floor(startTime) }
    end

    return toJson(payload)
end

local function pushRPC()
    local ok, err = pcall(function()
        game:HttpPost(bridgeUrl, buildPayload(), "application/json")
    end)
    if not ok then
        warn("rpc push failed: " .. tostring(err))
    end
end

pushRPC()

spawn(function()
    while true do
        wait(cfg.updateInterval)
        pushRPC()
    end
end)

print("discord rpc running, updating every " .. cfg.updateInterval .. "s")