local cache = {}

task.spawn(function()
    for _, name in ipairs({
        "awake.png", "yawn1.png", "yawn2.png", "wash1.png", "wash2.png",
        "scratch1.png", "scratch2.png", "sleep1.png", "sleep2.png",
        "up1.png", "up2.png", "down1.png", "down2.png",
        "left1.png", "left2.png", "right1.png", "right2.png",
        "upleft1.png", "upleft2.png", "upright1.png", "upright2.png",
        "downleft1.png", "downleft2.png", "downright1.png", "downright2.png"
    }) do
        if not cache[name] then
            pcall(function()
                cache[name] = game:HttpGet("https://raw.githubusercontent.com/crgimenes/neko/master/assets/" .. name)
            end)
        end
    end
end)

local nekoImage = Drawing.new("Image")
nekoImage.Size = Vector2.new(32, 32)
nekoImage.Visible = true

local neko_pos = Vector2.new(200, 200)
local mouse = game:GetService("Players").LocalPlayer:GetMouse()
local state = "awake"
local idleTime = 0
local lastAnimTime = 0
local anim_frame = 1
local wakeTime = 0
local lastSprite = ""

local connection
connection = game:GetService("RunService").RenderStepped:Connect(function(dt)
    local diff = Vector2.new(mouse.X, mouse.Y) - neko_pos
    local mag = math.sqrt(diff.X * diff.X + diff.Y * diff.Y)

    if mag > 16 then
        if state == "sleeping" then
            state = "awake"
            wakeTime = 0.5
            idleTime = 0
        elseif state == "awake" then
            wakeTime = wakeTime - dt
            if wakeTime <= 0 then
                state = "chasing"
            end
        elseif state ~= "chasing" then
            state = "chasing"
        end
    else
        if state == "chasing" then
            state = "awake"
            idleTime = 0
            wakeTime = 0.5
        elseif state == "awake" then
            idleTime = idleTime + dt
            if idleTime >= 2 then
                state = "idle"
            end
        end
    end

    local spriteName = "awake.png"

    if state == "chasing" then
        neko_pos = neko_pos + Vector2.new(diff.X / mag, diff.Y / mag) * (150 * dt)

        local deg = math.deg(math.atan2(diff.Y, diff.X))
        if deg < 0 then deg = deg + 360 end

        local dir_name = "right"
        if deg >= 22.5 and deg < 67.5 then
            dir_name = "downright"
        elseif deg >= 67.5 and deg < 112.5 then
            dir_name = "down"
        elseif deg >= 112.5 and deg < 157.5 then
            dir_name = "downleft"
        elseif deg >= 157.5 and deg < 202.5 then
            dir_name = "left"
        elseif deg >= 202.5 and deg < 247.5 then
            dir_name = "upleft"
        elseif deg >= 247.5 and deg < 292.5 then
            dir_name = "up"
        elseif deg >= 292.5 and deg < 337.5 then
            dir_name = "upright"
        end

        if tick() - lastAnimTime > 0.15 then
            anim_frame = anim_frame == 1 and 2 or 1
            lastAnimTime = tick()
        end
        spriteName = dir_name .. anim_frame .. ".png"
    elseif state == "awake" then
        spriteName = "awake.png"
    else
        idleTime = idleTime + dt
        if idleTime < 2 then
            spriteName = "awake.png"
        elseif idleTime < 4 then
            if tick() - lastAnimTime > 0.15 then
                anim_frame = anim_frame == 1 and 2 or 1
                lastAnimTime = tick()
            end
            spriteName = "scratch" .. anim_frame .. ".png"
        elseif idleTime < 6 then
            if tick() - lastAnimTime > 0.15 then
                anim_frame = anim_frame == 1 and 2 or 1
                lastAnimTime = tick()
            end
            spriteName = "wash" .. anim_frame .. ".png"
        elseif idleTime < 8 then
            if tick() - lastAnimTime > 0.25 then
                anim_frame = anim_frame == 1 and 2 or 1
                lastAnimTime = tick()
            end
            spriteName = "yawn" .. anim_frame .. ".png"
        else
            state = "sleeping"
            if tick() - lastAnimTime > 0.5 then
                anim_frame = anim_frame == 1 and 2 or 1
                lastAnimTime = tick()
            end
            spriteName = "sleep" .. anim_frame .. ".png"
        end
    end

    if spriteName ~= lastSprite then
        local data = cache[spriteName]
        if data then
            nekoImage.Data = data
            lastSprite = spriteName
        end
    end

    nekoImage.Position = neko_pos - Vector2.new(16, 16)
end)