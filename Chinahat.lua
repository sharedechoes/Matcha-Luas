local myId = tick()
_G.chinahatActive = myId

local cfg = {
    enabled = true,
    size = 2.0,
    tipHeight = 1.1,
    segments = 30,
    rainbowSpeed = 0.35,
    thickness = 1.8,
    showSegments = false,
    filled = true,
    fillOpacity = 0.35,
}

local function hsvToColor(h, s, v)
    h = h % 1
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then return Color3.new(v, t, p) end
    if i == 1 then return Color3.new(q, v, p) end
    if i == 2 then return Color3.new(p, v, t) end
    if i == 3 then return Color3.new(p, q, v) end
    if i == 4 then return Color3.new(t, p, v) end
    return Color3.new(v, p, q)
end

if _G.chinahatLines then
    pcall(function()
        for _, l in ipairs(_G.chinahatLines) do
            l.Visible = false
        end
    end)
    _G.chinahatLines = nil
end

local segs = cfg.segments
local allLines = {}

local function makeLine(th, zi)
    local ok, l = pcall(Drawing.new, "Line")
    if ok and l then
        l.Visible = false
        l.ZIndex = zi or 10
        l.Thickness = th or cfg.thickness
        table.insert(allLines, l)
        return l
    end
    return nil
end

local rimLines = {}
local spokeLines = {}
local midLines = {}
local fillLines = {}

for i = 1, segs do
    rimLines[i]   = makeLine(cfg.thickness, 10)
    spokeLines[i] = makeLine(cfg.thickness * 0.7, 9)
    midLines[i]   = makeLine(cfg.thickness * 0.5, 9)
end

for i = 1, 60 do
    fillLines[i] = makeLine(1, 7)
end

_G.chinahatLines = allLines

task.spawn(function()
    local rs = game:GetService("RunService")
    local players = game:GetService("Players")

    rs.RenderStepped:Connect(function()
        if _G.chinahatActive ~= myId then
            for _, l in ipairs(allLines) do pcall(function() l.Visible = false end) end
            return
        end

        for _, l in ipairs(allLines) do
            l.Visible = false
        end

        if not cfg.enabled then return end

        local lp = players.LocalPlayer
        if not lp then return end
        local char = lp.Character
        if not char then return end
        local head = char:FindFirstChild("Head")
        if not head then return end

        local headPos = head.Position
        local headTopY = headPos.Y + head.Size.Y * 0.5
        local now = tick()

        local tipWorld = Vector3.new(headPos.X, headTopY + cfg.tipHeight, headPos.Z)
        local tipScreen, tipOnScreen = WorldToScreen(tipWorld)

        if cfg.filled and tipOnScreen then
            for i = 1, 60 do
                local a0 = (i - 1) / 60 * math.pi * 2
                local a1 = i / 60 * math.pi * 2
                local hue = ((i - 1) / 60 + now * cfg.rainbowSpeed) % 1
                local col = hsvToColor(hue, 1, 1)

                local fw0 = Vector3.new(headPos.X + math.cos(a0)*cfg.size, headTopY, headPos.Z + math.sin(a0)*cfg.size)
                local fw1 = Vector3.new(headPos.X + math.cos(a1)*cfg.size, headTopY, headPos.Z + math.sin(a1)*cfg.size)
                local fws0, fwo0 = WorldToScreen(fw0)
                local fws1, fwo1 = WorldToScreen(fw1)

                if fwo0 and fwo1 then
                    local dx = fws1.X - fws0.X
                    local dy = fws1.Y - fws0.Y
                    local arcLen = math.sqrt(dx*dx + dy*dy)
                    local midX = (fws0.X + fws1.X) * 0.5
                    local midY = (fws0.Y + fws1.Y) * 0.5

                    local fl = fillLines[i]
                    if fl then
                        fl.From = Vector2.new(tipScreen.X, tipScreen.Y)
                        fl.To   = Vector2.new(midX, midY)
                        fl.Color = col
                        fl.Thickness = math.max(1, arcLen)
                        fl.Transparency = cfg.fillOpacity
                        fl.Visible = true
                    end
                end
            end
        end

        for i = 1, segs do
            local a0 = (i - 1) / segs * math.pi * 2
            local a1 = i / segs * math.pi * 2
            local hue = ((i - 1) / segs + now * cfg.rainbowSpeed) % 1
            local col = hsvToColor(hue, 1, 1)

            local rw0 = Vector3.new(headPos.X + math.cos(a0)*cfg.size, headTopY, headPos.Z + math.sin(a0)*cfg.size)
            local rw1 = Vector3.new(headPos.X + math.cos(a1)*cfg.size, headTopY, headPos.Z + math.sin(a1)*cfg.size)
            local rs0, ro0 = WorldToScreen(rw0)
            local rs1, ro1 = WorldToScreen(rw1)

            if rimLines[i] and ro0 and ro1 then
                rimLines[i].From  = Vector2.new(rs0.X, rs0.Y)
                rimLines[i].To    = Vector2.new(rs1.X, rs1.Y)
                rimLines[i].Color = col
                rimLines[i].Visible = true
            end

            if cfg.showSegments then
                if spokeLines[i] and tipOnScreen and ro0 then
                    spokeLines[i].From  = Vector2.new(tipScreen.X, tipScreen.Y)
                    spokeLines[i].To    = Vector2.new(rs0.X, rs0.Y)
                    spokeLines[i].Color = col
                    spokeLines[i].Visible = true
                end

                local mw0 = Vector3.new(headPos.X + math.cos(a0)*cfg.size*0.5, headTopY + cfg.tipHeight*0.55, headPos.Z + math.sin(a0)*cfg.size*0.5)
                local mw1 = Vector3.new(headPos.X + math.cos(a1)*cfg.size*0.5, headTopY + cfg.tipHeight*0.55, headPos.Z + math.sin(a1)*cfg.size*0.5)
                local ms0, mo0 = WorldToScreen(mw0)
                local ms1, mo1 = WorldToScreen(mw1)
                if midLines[i] and mo0 and mo1 then
                    midLines[i].From  = Vector2.new(ms0.X, ms0.Y)
                    midLines[i].To    = Vector2.new(ms1.X, ms1.Y)
                    midLines[i].Color = col
                    midLines[i].Visible = true
                end
            end
        end
    end)
end)