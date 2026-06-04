local myId = tick()
_G.breadcrumbsActive = myId

local cfg = {
    enabled = true,
    trailType = "neon", -- options are: solid, gradient, pulse, rainbow, flicker, neon
    colors = {
        Color3.fromHex("ff0040"),
        Color3.fromHex("70001a"),
    },
    maxPoints = 500,
    fadeTime = 3,
    thickness = 3.5,
    minDist = 0.05,
}

local points = {}
local drawings = {}
local lastWorldPos = nil

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpColor(c1, c2, t)
    return Color3.new(
        lerp(c1.R, c2.R, t),
        lerp(c1.G, c2.G, t),
        lerp(c1.B, c2.B, t)
    )
end

local function sampleColors(t)
    local cols = cfg.colors
    local n = #cols
    if n == 1 then return cols[1] end
    if t <= 0 then return cols[1] end
    if t >= 1 then return cols[n] end
    local scaled = t * (n - 1)
    local idx = math.floor(scaled)
    return lerpColor(cols[idx + 1], cols[idx + 2], scaled - idx)
end

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

local function gOC(idx)
    if not drawings[idx] then
        local ok, d = pcall(Drawing.new, "Line")
        if ok and d then
            drawings[idx] = d
        else
            return nil
        end
    end
    return drawings[idx]
end

local function renderTrail()
    local now = os.clock()
    local n = #points

    for i = 1, #drawings do
        local d = drawings[i]
        if d then d.Visible = false end
    end

    if n < 2 then return end

    local screenPts = {}
    for i = 1, n do
        local sp, onScreen = WorldToScreen(points[i].world)
        screenPts[i] = onScreen and Vector2.new(sp.X, sp.Y) or false
    end

    local tt = cfg.trailType
    local drawIdx = 0

    for i = 1, n - 1 do
        local sp1 = screenPts[i]
        local sp2 = screenPts[i + 1]
        if not sp1 or not sp2 then continue end

        local sp0 = screenPts[math.max(1, i - 1)] or sp1
        local sp3 = screenPts[math.min(n, i + 2)] or sp2

        local age = now - points[i].t
        local alpha = math.max(0, 1 - age / cfg.fadeTime)
        if alpha <= 0.01 then continue end

        local gradT = n <= 2 and 0 or (i - 1) / (n - 2)

        local col = sampleColors(gradT)
        local thickness = cfg.thickness
        local isNeon = tt == "neon"
        local neonA

        if tt == "solid" then
            col = sampleColors(0)
        elseif tt == "gradient" then
            col = sampleColors(gradT)
        elseif tt == "pulse" then
            thickness = cfg.thickness * (1 + 0.7 * math.sin(now * 6 + i * 0.28))
        elseif tt == "rainbow" then
            col = hsvToColor((now * 0.18 + gradT * 0.6) % 1, 0.85, 1)
        elseif tt == "flicker" then
            local aT = math.sin(now * 0.9 + gradT * math.pi * 2) * 0.5 + 0.5
            col = sampleColors(aT)
        elseif tt == "neon" then
            col = sampleColors(gradT)
            neonA = alpha * (0.85 + 0.15 * math.sin(now * 4 + i * 0.15))
        end

        local prevSP = sp1
        for sub = 1, 3 do
            local t = sub / 3
            local t2 = t * t
            local t3 = t2 * t
            local x = 0.5 * (2*sp1.X + (-sp0.X+sp2.X)*t + (2*sp0.X-5*sp1.X+4*sp2.X-sp3.X)*t2 + (-sp0.X+3*sp1.X-3*sp2.X+sp3.X)*t3)
            local y = 0.5 * (2*sp1.Y + (-sp0.Y+sp2.Y)*t + (2*sp0.Y-5*sp1.Y+4*sp2.Y-sp3.Y)*t2 + (-sp0.Y+3*sp1.Y-3*sp2.Y+sp3.Y)*t3)
            local curSP = Vector2.new(x, y)

            if isNeon then
                local neonLayers = {
                    { cfg.thickness * 9,   neonA * 0.08 },
                    { cfg.thickness * 4.5, neonA * 0.2  },
                    { cfg.thickness * 1.8, neonA * 0.7  },
                    { cfg.thickness * 0.7, neonA        },
                }
                for _, layer in ipairs(neonLayers) do
                    drawIdx = drawIdx + 1
                    local d = gOC(drawIdx)
                    if d then
                        d.From = prevSP
                        d.To = curSP
                        d.Color = col
                        d.Thickness = layer[1]
                        d.Transparency = layer[2]
                        d.ZIndex = 5
                        d.Visible = true
                    end
                end
            else
                drawIdx = drawIdx + 1
                local d = gOC(drawIdx)
                if d then
                    d.From = prevSP
                    d.To = curSP
                    d.Color = col
                    d.Thickness = thickness
                    d.Transparency = alpha
                    d.ZIndex = 5
                    d.Visible = true
                end
            end

            prevSP = curSP
        end
    end
end

local function killOld()
    local now = os.clock()
    local cutoff = now - cfg.fadeTime - 0.5
    local keep = 1
    for i = 1, #points do
        if points[i].t >= cutoff then
            keep = i
            break
        end
    end
    if keep > 1 then
        for i = 1, keep - 1 do
            table.remove(points, 1)
        end
    end
    if #points > cfg.maxPoints then
        while #points > cfg.maxPoints do
            table.remove(points, 1)
        end
    end
end

task.spawn(function()
    local rs = game:GetService("RunService")
    local players = game:GetService("Players")

    rs.RenderStepped:Connect(function()
        if _G.breadcrumbsActive ~= myId then return end
        if not cfg.enabled then return end

        local lp = players.LocalPlayer
        if not lp then return end
        local char = lp.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local hum = char:FindFirstChildOfClass("Humanoid")

        local worldPos = root.Position
        local hipH = hum and hum.HipHeight or 2
        local footWorld = worldPos - Vector3.new(0, hipH, 0)

        local now = os.clock()
        if lastWorldPos then
            local moved = (worldPos - lastWorldPos).Magnitude
            if moved > cfg.minDist then
                table.insert(points, { world = footWorld, t = now })
                lastWorldPos = worldPos
            end
        else
            lastWorldPos = worldPos
        end

        killOld()
        renderTrail()
    end)
end)