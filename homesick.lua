if type(identifyexecutor) ~= "function" then
    error("homesick requires Matcha executor")
end

do
    local executor = select(1, identifyexecutor())
    if executor ~= "Matcha" then
        error("homesick requires Matcha executor")
    end
end

local DrawingNew = Drawing.new
local V2 = Vector2.new
local C3 = Color3.fromRGB
local C3N = Color3.new
local C3HEX = Color3.fromHex
local HSV = Color3.fromHSV

local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local sin = math.sin
local clock = os.clock
local remove = table.remove
local concat = table.concat
_G.homesickOriginals = {
    print = print,
    warn = warn,
    printl = printl,
    notify = notify,
    isrbxactive = isrbxactive
}
local exportConfig, importConfig, exportTheme, importTheme, smoothValue, toHex

local function clamp(value, low, high)
    if value < low then
        return low
    end
    if value > high then
        return high
    end
    return value
end

local function bool(value)
    return value == true
end

local Players = game:GetService("Players")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer and LocalPlayer:GetMouse()

local mouseScroll = 0
local uis = game:GetService("UserInputService")
if uis then
    pcall(function()
        uis.PointerAction:Connect(function(wheel)
            mouseScroll = mouseScroll + wheel
        end)
    end)
    pcall(function()
        uis.InputChanged:Connect(function(input)
            if input and string.find(tostring(input.UserInputType), "MouseWheel") then
                mouseScroll = mouseScroll + (input.Position and input.Position.Z or 0)
            end
        end)
    end)
    pcall(function()
        uis.InputBegan:Connect(function(input)
            if input and string.find(tostring(input.UserInputType), "MouseWheel") then
                mouseScroll = mouseScroll + (input.Position and input.Position.Z or 0)
            end
        end)
    end)
end

local Fonts = (type(Drawing) == "table" and Drawing.Fonts) or {}
local FontSystem = Fonts.System or Fonts.UI or 0
local FontBold = Fonts.SystemBold or FontSystem
local FontUI = Fonts.UI or FontSystem

local FontWidths = {}
FontWidths[FontSystem] = 0.48
FontWidths[FontBold] = 0.52
FontWidths[FontUI] = 0.50

local DRAW_VISIBLE = 1
local FRAME_WAIT = 1 / 240
local MENU_KEY = "p"

local PAD = 10
local TITLE_H = 36
local TAB_H = 30
local ROW_H = 28
local CONTROL_H = 22
local DEFAULT_W = 430
local DEFAULT_H = 500
local MINIMIZED_H = 42
local TAB_MIN_W = 80
local CONTENT_PAD = 8

local SHADOW_ALPHA = {0.10, 0.07, 0.05, 0.03, 0.015}
local KEYBIND_MODES = {"Hold", "Toggle", "Always"}

local Theme = {
    bg = C3(36, 33, 31),
    surface = C3(30, 27, 25),
    surface2 = C3(44, 40, 37),
    surface3 = C3(54, 50, 46),
    text = C3(245, 242, 238),
    sub = C3(150, 142, 135),
    accent = C3(232, 208, 162),
    green = C3(52, 199, 89),
    red = C3(255, 69, 58),
    yellow = C3(255, 204, 0),
    unsafe = C3(255, 226, 84),
    border = C3(60, 55, 52),
    toggleOn = C3(232, 208, 162),
    toggleOff = C3(60, 55, 52),
    knob = C3(255, 255, 255),
    white = C3(255, 255, 255),
    black = C3(0, 0, 0),
}

local ProjectState = {
    alive = true,
    destroyed = false,
    rendering = false,
    open = true,
    x = 100,
    y = 80,
    w = DEFAULT_W,
    h = DEFAULT_H,
    defaultH = DEFAULT_H,
    minimized = false,
    title = "homesick",
    tabs = {},
    activeTab = nil,
    activeIndex = 0,
    drag = nil,
    sliderDrag = nil,
    scrollDrag = nil,
    focus = nil,
    dropdown = nil,
    colorpicker = nil,
    copiedColor = nil,
    activities = {},
    activityId = 0,
    mouseX = 0,
    mouseY = 0,
    hasMouse = false,
    focusedWindow = true,
    inputState = nil,
    demoLoaded = false,
    tooltipText = nil,
    tooltipAt = 0,
    tooltipX = 0,
    tooltipY = 0,
    lastFrame = clock(),
    lastErrorAt = 0,
    tabScrollX = 0,
    tabTargetScrollX = 0,
    tabScrollToActive = false,
    watermarkEnabled = false,
    watermarkTitle = "",
    watermarkX = 20,
    watermarkY = 20,
    watermarkDrag = nil,
    activityText = "",
    errorCount = 0,
    currentPillX = nil,
    currentPillW = nil,
    contentFade = 1,
    resizeEdge = nil,
    resizeStart = nil,
    draggedSection = nil,
    dragOffset = nil,
    resizeSection = nil,
    resizeSectionStartH = nil,
    resizeSectionStartMouseY = nil,
    lastTooltipText = nil,
    searchBar = {
        type = "textbox",
        value = "",
        active = false,
        width = 0,
    },
    settingsActive = false,
    settingsTab = nil,
    tabAnimations = true,
    gridLocking = true,
    smoothScrolling = true,
    hoverEffects = true,
    settingsTargetH = nil,
    preSettingsH = nil,
    settingsTargetW = nil,
    preSettingsW = nil,
    gridSnapLines = nil,
}

local function warn(msg)
    ProjectState.notifications = ProjectState.notifications or {}
    table.insert(ProjectState.notifications, {
        title = "warning",
        description = string.lower(tostring(msg or "")),
        duration = 5,
        elapsed = 0,
    })
    if _G.homesickOriginals and _G.homesickOriginals.warn then
        _G.homesickOriginals.warn(msg)
    end
end

local Pool = {
    sq = {},
    tx = {},
    ln = {},
    ci = {},
    tr = {},
    im = {},
}

local PoolIndex = {
    sq = 0,
    tx = 0,
    ln = 0,
    ci = 0,
    tr = 0,
    im = 0,
}

local PoolHighWater = {
    sq = 0,
    tx = 0,
    ln = 0,
    ci = 0,
    tr = 0,
    im = 0,
}

local Cleanup = {
    drawings = Pool,
}

local TypeMap = {
    sq = "Square",
    tx = "Text",
    ln = "Line",
    ci = "Circle",
    tr = "Triangle",
    im = "Image",
}

local Input = {}
local InputOrder = {}

local function addInput(name, id, char, shifted)
    name = string.lower(tostring(name))
    if not Input[name] then
        InputOrder[#InputOrder + 1] = name
    end
    Input[name] = {
        id = id,
        held = false,
        click = false,
        released = false,
        char = char,
        shifted = shifted,
    }
end

addInput("m1", 0x01)
addInput("m2", 0x02)
addInput("backspace", 0x08)
addInput("tab", 0x09)
addInput("enter", 0x0D)
addInput("shift", 0x10)
addInput("ctrl", 0x11)
addInput("alt", 0x12)
addInput("pause", 0x13)
addInput("capslock", 0x14)
addInput("esc", 0x1B)
addInput("space", 0x20, " ", " ")
addInput("pageup", 0x21)
addInput("pagedown", 0x22)
addInput("end", 0x23)
addInput("home", 0x24)
addInput("left", 0x25)
addInput("up", 0x26)
addInput("right", 0x27)
addInput("down", 0x28)
addInput("insert", 0x2D)
addInput("delete", 0x2E)

local shiftedDigits = {")", "!", "@", "#", "$", "%", "^", "&", "*", "("}
for i = 0, 9 do
    addInput(tostring(i), 0x30 + i, tostring(i), shiftedDigits[i + 1])
end

for i = 0, 25 do
    local ch = string.char(97 + i)
    addInput(ch, 0x41 + i, ch, string.upper(ch))
end

for i = 1, 12 do
    addInput("f" .. tostring(i), 0x6F + i)
end

addInput("numpad0", 0x60, "0", "0")
addInput("numpad1", 0x61, "1", "1")
addInput("numpad2", 0x62, "2", "2")
addInput("numpad3", 0x63, "3", "3")
addInput("numpad4", 0x64, "4", "4")
addInput("numpad5", 0x65, "5", "5")
addInput("numpad6", 0x66, "6", "6")
addInput("numpad7", 0x67, "7", "7")
addInput("numpad8", 0x68, "8", "8")
addInput("numpad9", 0x69, "9", "9")
addInput("multiply", 0x6A, "*", "*")
addInput("add", 0x6B, "+", "+")
addInput("subtract", 0x6D, "-", "-")
addInput("decimal", 0x6E, ".", ".")
addInput("divide", 0x6F, "/", "/")
addInput("lshift", 0xA0)
addInput("rshift", 0xA1)
addInput("lctrl", 0xA2)
addInput("rctrl", 0xA3)
addInput("lalt", 0xA4)
addInput("ralt", 0xA5)
addInput("semicolon", 0xBA, ";", ":")
addInput("plus", 0xBB, "=", "+")
addInput("comma", 0xBC, ",", "<")
addInput("minus", 0xBD, "-", "_")
addInput("period", 0xBE, ".", ">")
addInput("slash", 0xBF, "/", "?")
addInput("tilde", 0xC0, "`", "~")
addInput("lbracket", 0xDB, "[", "{")
addInput("backslash", 0xDC, "\\", "|")
addInput("rbracket", 0xDD, "]", "}")
addInput("quote", 0xDE, "'", "\"")

local UI = {}

local function viewportSize()
    local camera = Workspace.CurrentCamera
    if camera and camera.ViewportSize then
        return camera.ViewportSize.X, camera.ViewportSize.Y
    end
    return 1920, 1080
end

local function colorChanged(a, b)
    if not a or not b then
        return a ~= b
    end
    return abs(a.R - b.R) > 0.001 or abs(a.G - b.G) > 0.001 or abs(a.B - b.B) > 0.001
end

local function copyArray(source)
    local out = {}
    if type(source) == "table" then
        for i = 1, #source do
            out[i] = source[i]
        end
    elseif source ~= nil then
        out[1] = source
    end
    return out
end

local function normalizeKey(value)
    if value == nil then
        return nil
    end
    value = string.lower(tostring(value))
    if value == "" or value == "-" or value == "none" or value == "nil" or value == "unbound" then
        return nil
    end
    return value
end

local function normalizeMode(value)
    if value == "Toggle" or value == "Always" then
        return value
    end
    return "Hold"
end

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, result = pcall(callback, ...)
    if not ok then
        warn("homesick callback error " .. tostring(result) .. " rip")
        return
    end
    return result
end

local function applyInputState(force)
    local desired = not ProjectState.open
    if force or ProjectState.inputState ~= desired then
        ProjectState.inputState = desired
        setrobloxinput(desired)
    end
end

local function setOpen(open)
    open = bool(open)
    if ProjectState.open == open then
        return
    end
    ProjectState.open = open
    ProjectState.drag = nil
    ProjectState.sliderDrag = nil
    ProjectState.scrollDrag = nil
    ProjectState.dropdown = nil
    ProjectState.colorpicker = nil
    ProjectState.cpDrag = nil
    ProjectState.focus = nil
    applyInputState(false)
end

local function clampWindow()
    local vw, vh = viewportSize()
    local w = ProjectState.w
    local h = ProjectState.h
    ProjectState.x = clamp(ProjectState.x, 0, max(0, vw - min(80, w)))
    ProjectState.y = clamp(ProjectState.y, 0, max(0, vh - min(40, h)))
end

local function getMouse()
    if not Mouse then
        LocalPlayer = Players.LocalPlayer
        Mouse = LocalPlayer and LocalPlayer:GetMouse()
    end
    if Mouse then
        if not ProjectState.mouseConnected then
            ProjectState.mouseConnected = true
            pcall(function()
                Mouse.WheelForward:Connect(function()
                    mouseScroll = mouseScroll + 1
                end)
                Mouse.WheelBackward:Connect(function()
                    mouseScroll = mouseScroll - 1
                end)
            end)
        end
        ProjectState.mouseX = Mouse.X
        ProjectState.mouseY = Mouse.Y
        ProjectState.hasMouse = true
        return Mouse.X, Mouse.Y
    end
    ProjectState.hasMouse = false
    return nil, nil
end

local function over(x, y, w, h)
    local mx = ProjectState.mouseX
    local my = ProjectState.mouseY
    return ProjectState.hasMouse and mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function resetPool()
    PoolIndex.sq = 0
    PoolIndex.tx = 0
    PoolIndex.ln = 0
    PoolIndex.ci = 0
    PoolIndex.tr = 0
    PoolIndex.im = 0
end

local function getDrawing(kind)
    if not ProjectState.alive or ProjectState.destroyed then
        return nil
    end

    PoolIndex[kind] = PoolIndex[kind] + 1
    local index = PoolIndex[kind]
    local list = Pool[kind]
    local object = list[index]

    if not object then
        local ok, created = pcall(DrawingNew, TypeMap[kind])
        if not ok or not created then
            return nil
        end
        object = created
        list[index] = object
    end

    if index > PoolHighWater[kind] then
        PoolHighWater[kind] = index
    end

    object.Visible = true
    return object
end

local function hideUnused()
    for kind, list in pairs(Pool) do
        local current = PoolIndex[kind]
        local high = PoolHighWater[kind]
        if current < high then
            for i = current + 1, high do
                list[i].Visible = false
            end
        end
        if current > high then
            PoolHighWater[kind] = current
        end
    end
end

local function hideAll()
    for kind, list in pairs(Pool) do
        for i = 1, #list do
            list[i].Visible = false
        end
    end
end

local function removeDrawingList(list)
    for i = 1, #list do
        local object = list[i]
        if object then
            pcall(function()
                object.Visible = false
                object:Remove()
            end)
            list[i] = nil
        end
    end
end

local function removeAllDrawings()
    removeDrawingList(Cleanup.drawings.sq)
    removeDrawingList(Cleanup.drawings.tx)
    removeDrawingList(Cleanup.drawings.ln)
    removeDrawingList(Cleanup.drawings.ci)
    removeDrawingList(Cleanup.drawings.tr)
    removeDrawingList(Cleanup.drawings.im)
end

local function rect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then
        return
    end
    local d = getDrawing("sq")
    if not d then
        return
    end
    d.Position = V2(x, y)
    d.Size = V2(w, h)
    d.Color = color
    d.Filled = true
    d.Corner = radius or 0
    d.ZIndex = z or 1
    d.Transparency = transparency or DRAW_VISIBLE
end

local function strokeRect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then
        return
    end
    local d = getDrawing("sq")
    if not d then
        return
    end
    d.Position = V2(x, y)
    d.Size = V2(w, h)
    d.Color = color
    d.Filled = false
    d.Corner = radius or 0
    d.ZIndex = z or 1
    d.Transparency = transparency or DRAW_VISIBLE
end

local function textWidth(value, size, font)
    local multiplier = FontWidths[font] or 0.48
    return #tostring(value or "") * ((size or 13) * multiplier)
end

local function trimText(value, maxWidth, size, font)
    value = tostring(value or "")
    if maxWidth <= 0 then
        return ""
    end
    local multiplier = FontWidths[font] or 0.48
    local maxChars = floor(maxWidth / ((size or 13) * multiplier))
    if maxChars <= 0 then
        return ""
    end
    if #value <= maxChars then
        return value
    end
    if maxChars <= 2 then
        return ""
    end
    return string.sub(value, 1, maxChars - 2) .. ".."
end

local function wrapLines(value, maxWidth, size, font)
    value = tostring(value or "")
    local multiplier = FontWidths[font] or 0.48
    local charW = (size or 13) * multiplier
    local maxChars = math.max(1, floor(maxWidth / charW))
    local lines = {}
    local words = {}
    for w in string.gmatch(value, "%S+") do
        words[#words + 1] = w
    end
    if #words == 0 then
        return {""}
    end
    local currentLine = ""
    for i = 1, #words do
        local word = words[i]
        local candidate = currentLine == "" and word or (currentLine .. " " .. word)
        if #candidate <= maxChars then
            currentLine = candidate
        else
            if currentLine ~= "" then
                lines[#lines + 1] = currentLine
            end
            if #word > maxChars then
                while #word > maxChars do
                    lines[#lines + 1] = string.sub(word, 1, maxChars)
                    word = string.sub(word, maxChars + 1)
                end
                currentLine = word
            else
                currentLine = word
            end
        end
    end
    if currentLine ~= "" then
        lines[#lines + 1] = currentLine
    end
    return lines
end

local function txt(value, x, y, color, size, font, z, centered, outline, maxWidth, transparency)
    if value == nil or value == "" then
        return
    end
    if maxWidth then
        value = trimText(value, maxWidth, size, font)
        if value == "" then
            return
        end
    else
        value = tostring(value)
    end

    local d = getDrawing("tx")
    if not d then
        return
    end
    d.Text = value
    local xPos = x
    local yPos = y
    local isCentered = centered == true
    if isCentered then
        if font == FontUI then
            xPos = x - textWidth(value, size or 13, font) / 2
            yPos = y - (size or 13) / 2
            d.Center = false
        else
            d.Center = true
        end
    else
        d.Center = false
    end
    d.Position = V2(xPos, yPos)
    d.Color = color
    d.Size = size or 13
    d.Font = font or FontSystem
    d.ZIndex = (z or 1) + 10
    d.Outline = outline == true
    d.Transparency = transparency or DRAW_VISIBLE
end

local function centerY(y, h)
    return y + h / 2
end

local function textTop(y, h, size)
    return floor(y + (h - (size or 13)) / 2 + 0.5)
end

local function line(x1, y1, x2, y2, color, z, thickness, transparency)
    local d = getDrawing("ln")
    if not d then
        return
    end
    d.From = V2(x1, y1)
    d.To = V2(x2, y2)
    d.Color = color
    d.Thickness = thickness or 1
    d.ZIndex = z or 1
    d.Transparency = transparency or DRAW_VISIBLE
end

local function circle(x, y, radius, color, z, filled, thickness, sides, transparency)
    local d = getDrawing("ci")
    if not d then
        return
    end
    d.Position = V2(x, y)
    d.Radius = radius
    d.Color = color
    d.Filled = filled ~= false
    d.Thickness = thickness or 1
    d.NumSides = sides or 32
    d.ZIndex = z or 1
    d.Transparency = transparency or DRAW_VISIBLE
end

local function triangle(a, b, c, color, z, filled, transparency)
    local d = getDrawing("tr")
    if not d then
        return
    end
    d.PointA = a
    d.PointB = b
    d.PointC = c
    d.Color = color
    d.Filled = filled ~= false
    d.Thickness = 1
    d.ZIndex = z or 1
    d.Transparency = transparency or DRAW_VISIBLE
end

local function drawImage(data, x, y, w, h, z, trans)
    local obj = getDrawing("im")
    if obj and obj == obj then
        pcall(function() obj.Data = data end)
        pcall(function() obj.Position = V2(x, y) end)
        pcall(function() obj.Size = V2(w, h) end)
        pcall(function() obj.ZIndex = z or 0 end)
        pcall(function() obj.Transparency = trans or 1 end)
        pcall(function() obj.Visible = true end)
    end
    return obj
end

local function drawLockIcon(x, y, color, z, trans, unlocked)
    rect(x + 1, y + 5, 8, 5, color, z, 2, trans)
    line(x + 2, y + 5, x + 2, y + 2, color, z, 1.5, trans)
    line(x + 2, y + 2, x + 7, y + 2, color, z, 1.5, trans)
    if unlocked then
        line(x + 7, y + 2, x + 7, y + 3, color, z, 1.5, trans)
    else
        line(x + 7, y + 2, x + 7, y + 5, color, z, 1.5, trans)
    end
end

local function drawExportIcon(x, y, color, z, trans)
    line(x + 5, y + 8, x + 5, y + 2, color, z, 1.5, trans)
    line(x + 2, y + 5, x + 5, y + 2, color, z, 1.5, trans)
    line(x + 8, y + 5, x + 5, y + 2, color, z, 1.5, trans)
    line(x + 1, y + 10, x + 9, y + 10, color, z, 1.5, trans)
end

local function drawImportIcon(x, y, color, z, trans)
    line(x + 5, y + 2, x + 5, y + 8, color, z, 1.5, trans)
    line(x + 2, y + 5, x + 5, y + 8, color, z, 1.5, trans)
    line(x + 8, y + 5, x + 5, y + 8, color, z, 1.5, trans)
    line(x + 1, y + 10, x + 9, y + 10, color, z, 1.5, trans)
end

local function drawTrashIcon(x, y, color, z, trans)
    line(x + 4, y, x + 6, y, color, z, 1.5, trans)
    line(x + 2, y + 2, x + 8, y + 2, color, z, 1.5, trans)
    line(x + 3, y + 3, x + 3, y + 9, color, z, 1.5, trans)
    line(x + 7, y + 3, x + 7, y + 9, color, z, 1.5, trans)
    line(x + 3, y + 9, x + 7, y + 9, color, z, 1.5, trans)
end

local function renderNotifications()
    local notifications = ProjectState.notifications or {}
    local width = 300
    local height = 64
    local i = 1
    while i <= #notifications do
        local n = notifications[i]
        n.elapsed = n.elapsed + (ProjectState.dt or 1/60)
        if n.elapsed >= n.duration then
            table.remove(notifications, i)
        else
            n.targetX = select(1, viewportSize()) - width - 20
            n.targetY = (select(2, viewportSize()) - 20) - i * (height + 10)
            if not n.currentX then
                n.currentX = select(1, viewportSize())
            end
            if not n.currentY then
                n.currentY = n.targetY
            end
            n.currentX = smoothValue(n.currentX, n.targetX, 12)
            n.currentY = smoothValue(n.currentY, n.targetY, 12)
            local nx = n.currentX
            local ny = n.currentY
            local z = 300
            
            local isWarn = n.title == "warning" or n.title == "warn"
            local displayTitle = n.title
            if displayTitle == "print" or displayTitle == "warning" or displayTitle == "warn" or displayTitle == "notification" then
                displayTitle = "homesick"
            end
            local accentCol = isWarn and Theme.red or Theme.accent

            rect(nx, ny, width, height, Theme.surface2, z, 8, 0.95)
            strokeRect(nx, ny, width, height, Theme.border, z + 1, 8, 0.95)
            rect(nx + 6, ny + 6, 3, height - 12, accentCol, z + 2, 1, 0.95)

            local textX = nx + 16
            if n.image and n.image ~= "" then
                drawImage(n.image, nx + 14, ny + 12, 40, 40, z + 2, 0.95)
                textX = nx + 64
            else
                textX = nx + 44
                local cx = nx + 24
                local cy = ny + 32
                if isWarn then
                    triangle(V2(cx, cy - 8), V2(cx - 9, cy + 8), V2(cx + 9, cy + 8), accentCol, z + 2, true, 0.95)
                    txt("!", cx, cy + 2, Theme.bg, 11, FontBold, z + 3, true)
                else
                    circle(cx, cy, 9, accentCol, z + 2, false, 2, 32, 0.95)
                    txt("i", cx, cy, accentCol, 12, FontBold, z + 3, true)
                end
            end

            txt(displayTitle, textX, ny + 12, Theme.accent, 13, FontBold, z + 2)
            txt(n.description, textX, ny + 28, Theme.text, 11, FontUI, z + 2, false, false, width - (textX - nx) - 12)
            line(textX, ny + height - 5, nx + width - 16, ny + height - 5, Theme.surface3, z + 2, 2, 0.95)
            if n.elapsed < n.duration then
                line(textX, ny + height - 5, textX + ((nx + width - 16) - textX) * clamp(1 - (n.elapsed / n.duration), 0, 1), ny + height - 5, accentCol, z + 3, 4, 0.25)
                line(textX, ny + height - 5, textX + ((nx + width - 16) - textX) * clamp(1 - (n.elapsed / n.duration), 0, 1), ny + height - 5, accentCol, z + 4, 2, 0.95)
            end
            
            i = i + 1
        end
    end
end

local function drawChevronDown(x, y, color, z, transparency)
    triangle(V2(x, y), V2(x + 8, y), V2(x + 4, y + 5), color, z, true, transparency)
end

local function drawChevronUp(x, y, color, z, transparency)
    triangle(V2(x, y + 5), V2(x + 8, y + 5), V2(x + 4, y), color, z, true, transparency)
end

local function snapValue(raw, item)
    local minValue = item.min or 0
    local maxValue = item.max or 100
    local step = item.step or 1
    if step <= 0 then
        step = 1
    end
    local steps = floor(((raw - minValue) / step) + 0.5 + 0.0001)
    return floor(clamp(minValue + steps * step, minValue, maxValue) + 0.5)
end

local function setDropdownValue(item, value, fire)
    local newValue = copyArray(value)
    local changed = #newValue ~= #item.value

    for i = 1, max(#item.value, #newValue) do
        if item.value[i] ~= newValue[i] then
            changed = true
            break
        end
    end

    for i = #item.value, 1, -1 do
        item.value[i] = nil
    end
    for i = 1, #newValue do
        item.value[i] = newValue[i]
    end

    if changed and fire ~= false then
        safeCallback(item.callback, item.value)
    end
end

local function setItemValue(item, value, fire)
    if item.type == "dropdown" then
        setDropdownValue(item, value, fire)
        return
    end

    if item.type == "slider" then
        value = tonumber(value) or item.value or item.min or 0
        value = snapValue(value, item)
    elseif item.type == "toggle" then
        value = value == true
    elseif item.type == "textbox" then
        value = tostring(value or "")
    elseif item.type == "checkbox" then
        value = value == true
    end

    local changed = item.value ~= value
    item.value = value

    if changed and fire ~= false then
        safeCallback(item.callback, value)
    end
end

local keybindItems = {}

local function makeItem(section, item)
    section.items[#section.items + 1] = item

    local handle = { item = item }
    item.handle = handle

    function handle:Set(value)
        setItemValue(item, value, true)
        return self
    end

    function handle:DependsOn(parentHandle)
        item.dependsOn = parentHandle
        return self
    end

    if item.type == "toggle" or item.type == "checkbox" then
        function handle:AddKeybind(defaultKey, mode, canChange, callback)
            local keybind = {
                value = normalizeKey(defaultKey),
                mode = normalizeMode(mode),
                canChange = canChange ~= false,
                callback = callback,
                listening = false,
                listenAt = 0,
            }
            item.keybind = keybind
            keybindItems[#keybindItems + 1] = item

            local keyHandle = {}
            function keyHandle:Set(newKey, newMode)
                keybind.value = normalizeKey(newKey)
                if newMode then
                    keybind.mode = normalizeMode(newMode)
                end
                safeCallback(keybind.callback, keybind.value and Input[keybind.value] and Input[keybind.value].id or nil, keybind.mode)
                return self
            end
            return keyHandle
        end

        function handle:AddColorpicker(label, defaultColor, overwrite, callback, defaultAlpha)
            local picker = {
                label = tostring(label or "Color"),
                value = defaultColor or Theme.accent,
                alpha = type(overwrite) == "number" and overwrite or defaultAlpha or 1,
                overwrite = overwrite == true,
                callback = callback,
            }
            item.colorpicker = picker

            local colorHandle = {}
            function colorHandle:Set(newColor, newAlpha)
                if newColor and (colorChanged(picker.value, newColor) or (newAlpha and newAlpha ~= picker.alpha)) then
                    picker.value = newColor
                    if newAlpha then
                        picker.alpha = newAlpha
                    end
                    safeCallback(picker.callback, newColor, picker.alpha)
                end
                return self
            end
            return colorHandle
        end
    elseif item.type == "dropdown" then
        function handle:UpdateChoices(newChoices)
            item.choices = copyArray(newChoices)
            return self
        end
    end

    return handle
end

local function createSection(tab, name, side, allowLocking, defaultLock)
    if allowLocking == allowLocking then end
    if defaultLock == defaultLock then end
    local section = {
        name = tostring(name or "Section"),
        side = tostring(side or "Left"),
        items = {},
        collapsed = false,
        allowLocking = (allowLocking == nil) and true or (allowLocking == true),
        locked = (defaultLock == true),
    }
    tab.sections[#tab.sections + 1] = section

    local sectionApi = {}

    function sectionApi:Label(label, color, tooltip)
        if type(color) == "string" and not tooltip then
            tooltip = color
            color = nil
        end
        local item = {
            type = "label",
            label = tostring(label or ""),
            color = color or Theme.text,
            tooltip = tooltip,
        }
        local handle = makeItem(section, item)

        function handle:SetText(newText)
            item.label = tostring(newText or "")
            return self
        end
        function handle:Set(newText)
            item.label = tostring(newText or "")
            return self
        end
        function handle:SetColor(newColor)
            item.color = newColor or Theme.text
            return self
        end
        return handle
    end

    function sectionApi:Toggle(label, default, callback, unsafe, tooltip)
        return makeItem(section, {
            type = "toggle",
            label = tostring(label or "Toggle"),
            value = default == true,
            callback = callback,
            unsafe = unsafe == true,
            tooltip = tooltip,
        })
    end

    function sectionApi:Colorpicker(label, default, overwrite, callback, defaultAlpha)
        return makeItem(section, {
            type = "colorpicker",
            label = tostring(label or "Colorpicker"),
            value = default or Theme.accent,
            alpha = type(overwrite) == "number" and overwrite or defaultAlpha or 1,
            overwrite = overwrite == true,
            callback = callback,
        })
    end

    function sectionApi:Checkbox(label, default, callback, unsafe, tooltip)
        return makeItem(section, {
            type = "checkbox",
            label = tostring(label or "Checkbox"),
            value = default == true,
            callback = callback,
            unsafe = unsafe == true,
            tooltip = tooltip,
        })
    end

    function sectionApi:Slider(label, default, step, minValue, maxValue, suffix, callback, tooltip)
        local item = {
            type = "slider",
            label = tostring(label or "Slider"),
            value = tonumber(default) or 0,
            defaultValue = tonumber(default) or 0,
            step = tonumber(step) or 1,
            min = tonumber(minValue) or 0,
            max = tonumber(maxValue) or 100,
            suffix = suffix or "",
            callback = callback,
            tooltip = tooltip,
        }
        item.value = snapValue(item.value, item)
        return makeItem(section, item)
    end

    function sectionApi:Dropdown(label, default, choices, multi, callback, tooltip)
        return makeItem(section, {
            type = "dropdown",
            label = tostring(label or "Dropdown"),
            value = copyArray(default),
            choices = copyArray(choices),
            multi = multi == true,
            callback = callback,
            tooltip = tooltip,
        })
    end

    function sectionApi:Button(label, callback, tooltip)
        return makeItem(section, {
            type = "button",
            label = tostring(label or "Button"),
            callback = callback,
            tooltip = tooltip,
        })
    end

    function sectionApi:Textbox(label, default, callback, tooltip)
        return makeItem(section, {
            type = "textbox",
            label = tostring(label or "Textbox"),
            value = tostring(default or ""),
            callback = callback,
            tooltip = tooltip,
        })
    end

    function sectionApi:Divider(label)
        return makeItem(section, {
            type = "divider",
            label = label and tostring(label) or nil,
        })
    end

    return sectionApi
end

function UI.Notify(self, title, desc, duration, image)
    local t, d, dur, img
    if type(self) == "table" and self == UI then
        t, d, dur, img = title, desc, duration, image
    else
        t, d, dur, img = self, title, desc, duration
    end
    ProjectState.notifications = ProjectState.notifications or {}
    table.insert(ProjectState.notifications, {
        title = string.lower(tostring(t or "notification")),
        description = string.lower(tostring(d or "")),
        duration = tonumber(dur) or 5,
        elapsed = 0,
        image = img,
    })
end

function UI:SetMenuKey(key)
    if type(key) == "number" or (type(key) == "string" and tonumber(key) ~= nil) then
        local vk = tonumber(key)
        for name, input in pairs(Input) do
            if input.id == vk then
                key = name
                break
            end
        end
    end
    MENU_KEY = normalizeKey(key) or "f1"
    return self
end

function UI:SetTheme(overrides)
    if type(overrides) == "table" then
        for k, v in pairs(overrides) do
            if Theme[k] ~= nil then Theme[k] = v end
        end
    end
    return self
end

function UI:IsOpen()
    return ProjectState.open == true
end

function UI:SetOpen(bool)
    setOpen(bool == true)
    return self
end

local function splitPath(str)
    local parts = {}
    for part in string.gmatch(str, "[^%.]+") do
        parts[#parts + 1] = part
    end
    return parts
end

function UI:GetValue(path)
    local parts = splitPath(path)
    if #parts < 3 then return nil end
    local tabName, secName, itemName = parts[1], parts[2], parts[3]
    for _, t in ipairs(ProjectState.tabs) do
        if t.name == tabName then
            for _, s in ipairs(t.sections) do
                if s.name == secName then
                    for _, item in ipairs(s.items) do
                        if item.label == itemName then
                            return item.value
                        end
                    end
                end
            end
        end
    end
    return nil
end

function UI:SetValue(path, value)
    local parts = splitPath(path)
    if #parts < 3 then return self end
    local tabName, secName, itemName = parts[1], parts[2], parts[3]
    for _, t in ipairs(ProjectState.tabs) do
        if t.name == tabName then
            for _, s in ipairs(t.sections) do
                if s.name == secName then
                    for _, item in ipairs(s.items) do
                        if item.label == itemName then
                            setItemValue(item, value, true)
                            return self
                        end
                    end
                end
            end
        end
    end
    return self
end

function UI:GetDrawing(kind)
    return getDrawing(kind)
end

function UI:SetTitle(text)
    ProjectState.title = tostring(text or "homesick")
    return self
end

function UI:SetPos(x, y)
    ProjectState.x = tonumber(x) or ProjectState.x
    ProjectState.y = tonumber(y) or ProjectState.y
    clampWindow()
    return self
end

function UI:SetSize(w, h)
    ProjectState.w = max(300, tonumber(w) or ProjectState.w)
    ProjectState.h = max(300, tonumber(h) or ProjectState.h)
    if ProjectState.h > MINIMIZED_H then
        ProjectState.defaultH = ProjectState.h
        ProjectState.minimized = false
    end
    clampWindow()
    return self
end

function UI:Center()
    local vw, vh = viewportSize()
    ProjectState.x = floor(vw / 2 - ProjectState.w / 2)
    ProjectState.y = floor(vh / 2 - ProjectState.h / 2)
    clampWindow()
    return self
end

function UI:Tab(name)
    local tab = {
        name = tostring(name or ("Tab " .. tostring(#ProjectState.tabs + 1))),
        sections = {},
        scrollY = 0,
        targetScrollY = 0,
        maxScroll = 0,
    }

    ProjectState.tabs[#ProjectState.tabs + 1] = tab
    if not ProjectState.activeTab then
        ProjectState.activeTab = tab
        ProjectState.activeIndex = #ProjectState.tabs
    end
    applyInputState(false)

    local tabApi = {}
    function tabApi:Section(sectionName, side, allowLocking, defaultLock)
        if allowLocking == allowLocking then end
        if defaultLock == defaultLock then end
        return createSection(tab, sectionName, side, allowLocking, defaultLock)
    end
    return tabApi
end

function UI:RegisterActivity(callback)
    ProjectState.activityId = ProjectState.activityId + 1
    local activity = {
        id = ProjectState.activityId,
        callback = callback,
        alive = true,
    }
    ProjectState.activities[#ProjectState.activities + 1] = activity

    return {
        Remove = function()
            activity.alive = false
        end,
    }
end

local stepConnection

local function finalDestroy()
    if ProjectState.destroyed then
        return
    end
    ProjectState.destroyed = true
    ProjectState.open = false
    ProjectState.dropdown = nil
    ProjectState.colorpicker = nil
    ProjectState.focus = nil
    ProjectState.drag = nil
    ProjectState.sliderDrag = nil
    ProjectState.scrollDrag = nil
    
    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
    end

    if ProjectState.zoomLocked and LocalPlayer then
        pcall(function()
            LocalPlayer.CameraMinZoomDistance = ProjectState.origMinZoom or 0.5
            LocalPlayer.CameraMaxZoomDistance = ProjectState.origMaxZoom or 400
        end)
    end

    if ProjectState.cpPaletteSquares then
        for i = 1, #ProjectState.cpPaletteSquares do
            pcall(function()
                ProjectState.cpPaletteSquares[i].obj.Visible = false
                ProjectState.cpPaletteSquares[i].obj:Remove()
            end)
        end
        ProjectState.cpPaletteSquares = nil
    end

    setrobloxinput(true)
    ProjectState.inputState = true

    removeAllDrawings()
    pcall(function()
        game:GetService("ContextActionService"):UnbindAction("homesickFreezeMovement")
    end)
    if uis then
        pcall(function()
            uis.MouseIconEnabled = true
        end)
    end
end

function UI:Destroy()
    ProjectState.alive = false
    ProjectState.open = false
    if not ProjectState.rendering then
        finalDestroy()
    end
    return self
end

function UI:Unload()
    return self:Destroy()
end

local function updateInput()
    ProjectState.mouseScroll = mouseScroll
    mouseScroll = 0
    local active = true
    if _G.homesickOriginals and type(_G.homesickOriginals.isrbxactive) == "function" then
        active = _G.homesickOriginals.isrbxactive() == true
    elseif type(isrbxactive) == "function" then
        active = isrbxactive() == true
    end
    ProjectState.focusedWindow = active

    for i = 1, #InputOrder do
        local input = Input[InputOrder[i]]
        input.click = false
        input.released = false
    end

    local m1 = false
    local m2 = false
    if active then
        m1 = ismouse1pressed() == true
        m2 = ismouse2pressed() == true
    end

    Input.m1.click = m1 and not Input.m1.held
    Input.m1.released = (not m1) and Input.m1.held
    Input.m1.held = m1

    Input.m2.click = m2 and not Input.m2.held
    Input.m2.released = (not m2) and Input.m2.held
    Input.m2.held = m2

    local pollAll = ProjectState.open or ProjectState.focus ~= nil
    if not pollAll then
        for _, item in ipairs(keybindItems) do
            if item.keybind and item.keybind.listening then
                pollAll = true
                break
            end
        end
    end

    if pollAll then
        for i = 1, #InputOrder do
            local name = InputOrder[i]
            if name ~= "m1" and name ~= "m2" then
                local input = Input[name]
                local down = false
                if active then
                    down = iskeypressed(input.id) == true
                end
                input.click = down and not input.held
                input.released = (not down) and input.held
                input.held = down
            end
        end
    else
        local keysToPoll = {}
        if MENU_KEY then keysToPoll[MENU_KEY] = true end
        for _, item in ipairs(keybindItems) do
            if item.keybind and item.keybind.value then
                keysToPoll[item.keybind.value] = true
            end
        end

        for name, _ in pairs(keysToPoll) do
            local input = Input[name]
            if input and name ~= "m1" and name ~= "m2" then
                local down = false
                if active then
                    down = iskeypressed(input.id) == true
                end
                input.click = down and not input.held
                input.released = (not down) and input.held
                input.held = down
            end
        end
    end
end

local function lerpColor(c1, c2, t)
    return C3N(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end

smoothValue = function(current, target, speed)
    local dtValue = ProjectState.dt or 1/60
    if dtValue <= 0 then
        dtValue = 1/60
    end
    return current + (target - current) * (1 - math.exp(-(speed or 15) * dtValue))
end

local toHsv

toHex = function(color)
    local r = floor(color.R * 255 + 0.5)
    local g = floor(color.G * 255 + 0.5)
    local b = floor(color.B * 255 + 0.5)
    return string.format("%02X%02X%02X", r, g, b)
end

local function isItemDisabled(item)
    if not item then return false end
    local dep = item.dependsOn
    if dep and dep.item then
        if not dep.item.value or isItemDisabled(dep.item) then
            return true
        end
    end
    return false
end

local function getFocusableItems()
    local list = {}
    if ProjectState.activeTab then
        for _, s in ipairs(ProjectState.activeTab.sections) do
            if not s.collapsed then
                for _, item in ipairs(s.items) do
                    if item.type == "textbox" and not isItemDisabled(item) then
                        list[#list + 1] = item
                    end
                end
            end
        end
    end
    return list
end

local function pushHistory(item, prevValue)
    if not item._history then
        item._history = { prevValue }
        item._historyIndex = 1
    else
        while #item._history > item._historyIndex do
            table.remove(item._history)
        end
        if item._history[item._historyIndex] ~= prevValue then
            item._historyIndex = item._historyIndex + 1
            item._history[item._historyIndex] = prevValue
        end
    end
end

local function processTextInput()
    if Input.tab.click then
        local items = getFocusableItems()
        local currentIdx = nil
        for i = 1, #items do
            if items[i] == ProjectState.focus then
                currentIdx = i
                break
            end
        end
        if currentIdx and #items > 1 then
            local shifted = Input.shift.held or Input.lshift.held or Input.rshift.held
            local nextIdx
            if shifted then
                nextIdx = currentIdx - 1
                if nextIdx < 1 then nextIdx = #items end
            else
                nextIdx = currentIdx + 1
                if nextIdx > #items then nextIdx = 1 end
            end
            ProjectState.focus = items[nextIdx]
            Input.tab.click = false
        elseif currentIdx then
            ProjectState.focus = nil
            Input.tab.click = false
        end
    end

    local item = ProjectState.focus
    if not item then
        return
    end

    if item == ProjectState.colorpicker then
        local cp = item
        if Input.enter.click or Input.esc.click then
            ProjectState.focus = nil
            return
        end
        local value = cp._hexInput or ""
        local changed = false
        for i = 1, #InputOrder do
            local name = InputOrder[i]
            local input = Input[name]
            if input.click and input.char then
                local char = string.upper(input.char)
                if (tonumber(char) or char:match("[A-F]")) and #value < 6 then
                    value = value .. char
                    changed = true
                end
                break
            elseif input.click and (name == "backspace" or name == "unbound") then
                value = string.sub(value, 1, max(0, #value - 1))
                changed = true
                break
            end
        end
        if changed then
            cp._hexInput = value
            if #value == 6 then
                local ok, newColor = pcall(C3HEX, "#" .. value)
                if ok and newColor then
                    local h_v, s_v, v_v = toHsv(newColor)
                    cp.hue = h_v
                    cp.sat = s_v
                    cp.val = v_v
                    cp.value = newColor
                    cp.picker.value = newColor
                    safeCallback(cp.picker.callback, newColor)
                end
            end
        end
        return
    end

    if type(item) ~= "table" or (item.type ~= "textbox" and item.type ~= "slider") then
        return
    end

    if item == ProjectState.searchBar then
        if Input.enter.click or Input.esc.click then
            if Input.esc.click then
                ProjectState.searchBar.active = false
                ProjectState.searchBar.value = ""
            end
            ProjectState.focus = nil
            return
        end
    end

    if Input.enter.click then
        if item.type == "slider" then
            local val = tonumber(item._directValue or "") or item.value or item.min or 0
            setItemValue(item, val, true)
            item._directValue = nil
        end
        ProjectState.focus = nil
        return
    elseif Input.esc.click then
        if item.type == "slider" then
            item._directValue = nil
        end
        ProjectState.focus = nil
        return
    end

    local value
    if item.type == "textbox" then
        value = item.value or ""
    else
        value = item._directValue or ""
    end

    local changed = false
    local shifted = Input.shift.held or Input.lshift.held or Input.rshift.held
    local now = clock()
    local any_held = false
    
    if (Input.ctrl.held or Input.lctrl.held or Input.rctrl.held) then
        if Input.a.click then
            item._selectedAll = true
            Input.a.click = false
        elseif Input.c.click then
            pcall(setclipboard, value)
            Input.c.click = false
        elseif Input.v.click then
            local clip = nil
            pcall(function()
                clip = (type(getclipboard) == "function" and getclipboard()) or (type(get_clipboard) == "function" and get_clipboard())
            end)
            if type(clip) == "string" then
                if item.type == "slider" then
                    clip = clip:gsub("[^0-9%.%-]", "")
                end
                if item._selectedAll then
                    value = clip
                    item._selectedAll = false
                else
                    value = value .. clip
                end
                changed = true
            end
            Input.v.click = false
        elseif Input.z.click then
            if item._history and item._historyIndex > 0 then
                local currentVal = (item.type == "textbox") and item.value or (item._directValue or "")
                if item._historyIndex == #item._history then
                    if item._history[item._historyIndex] ~= currentVal then
                        item._history[#item._history + 1] = currentVal
                    end
                end
                if item._historyIndex > 1 then
                    item._historyIndex = item._historyIndex - 1
                    local targetVal = item._history[item._historyIndex]
                    if item.type == "textbox" then
                        item.value = targetVal
                        safeCallback(item.callback, targetVal)
                    else
                        item._directValue = targetVal
                    end
                    item._selectedAll = false
                end
            end
            Input.z.click = false
        elseif Input.y.click then
            if item._history and item._historyIndex < #item._history then
                item._historyIndex = item._historyIndex + 1
                local targetVal = item._history[item._historyIndex]
                if item.type == "textbox" then
                    item.value = targetVal
                    safeCallback(item.callback, targetVal)
                else
                    item._directValue = targetVal
                end
                item._selectedAll = false
            end
            Input.y.click = false
        end
    else
        if Input.delete.click then
            if item._selectedAll then
                value = ""
                item._selectedAll = false
            else
                value = ""
            end
            changed = true
        end

        for i = 1, #InputOrder do
            local name = InputOrder[i]
            local input = Input[name]
            
            if input.click and input.char then
                local char = shifted and input.shifted or input.char
                if item._selectedAll then
                    value = ""
                    item._selectedAll = false
                end
                if item.type == "slider" then
                    if tonumber(char) or char == "." or char == "-" then
                        value = value .. char
                        changed = true
                    end
                else
                    value = value .. char
                    changed = true
                end
                ProjectState.repeatKey = name
                ProjectState.repeatAt = now + 0.4
                any_held = true
                break
            elseif input.held and input.char and ProjectState.repeatKey == name then
                any_held = true
                if now >= (ProjectState.repeatAt or 0) then
                    local char = shifted and input.shifted or input.char
                    if item._selectedAll then
                        value = ""
                        item._selectedAll = false
                    end
                    if item.type == "slider" then
                        if tonumber(char) or char == "." or char == "-" then
                            value = value .. char
                            changed = true
                        end
                    else
                        value = value .. char
                        changed = true
                    end
                    ProjectState.repeatAt = now + 0.035
                end
                break
            elseif input.click and (name == "backspace" or name == "unbound") then
                if item._selectedAll then
                    value = ""
                    item._selectedAll = false
                else
                    value = string.sub(value, 1, max(0, #value - 1))
                end
                changed = true
                ProjectState.repeatKey = name
                ProjectState.repeatAt = now + 0.4
                any_held = true
                break
            elseif input.held and (name == "backspace" or name == "unbound") and ProjectState.repeatKey == name then
                any_held = true
                if now >= (ProjectState.repeatAt or 0) then
                    if item._selectedAll then
                        value = ""
                        item._selectedAll = false
                    else
                        value = string.sub(value, 1, max(0, #value - 1))
                    end
                    changed = true
                    ProjectState.repeatAt = now + 0.035
                end
                break
            end
        end
    end
    
    if not any_held then
        ProjectState.repeatKey = nil
    end

    if changed then
        if item.type == "textbox" then
            if value ~= item.value then
                pushHistory(item, item.value)
                item.value = value
                safeCallback(item.callback, value)
            end
        else
            if value ~= item._directValue then
                pushHistory(item, item._directValue or "")
                item._directValue = value
            end
        end
    end
end

local function processKeybinds()
    if ProjectState.focus then
        return
    end

    for i = 1, #keybindItems do
        local item = keybindItems[i]
        local keybind = item.keybind
        if (item.type == "toggle" or item.type == "checkbox") and keybind and keybind.value and not keybind.listening and not isItemDisabled(item) then
            local input = Input[keybind.value]
            if input then
                if keybind.mode == "Always" then
                    setItemValue(item, true, true)
                elseif keybind.mode == "Toggle" then
                    if input.click then
                        setItemValue(item, not item.value, true)
                    end
                else
                    setItemValue(item, input.held, true)
                end
            end
        end
    end
end

local function runActivities(dt, now)
    local writeIndex = 1
    local activityParts = {}
    for i = 1, #ProjectState.activities do
        local activity = ProjectState.activities[i]
        if activity and activity.alive then
            local result = safeCallback(activity.callback, UI, dt, now)
            if result ~= nil and result ~= "" then
                activityParts[#activityParts + 1] = tostring(result)
            end
            ProjectState.activities[writeIndex] = activity
            writeIndex = writeIndex + 1
        end
    end
    for i = #ProjectState.activities, writeIndex, -1 do
        ProjectState.activities[i] = nil
    end
    ProjectState.activityText = #activityParts > 0 and concat(activityParts, " | ") or ""
end

toHsv = function(color)
    local r = color and color.R or 1
    local g = color and color.G or 1
    local b = color and color.B or 1
    local high = max(r, g, b)
    local low = min(r, g, b)
    local delta = high - low
    local hue = 0
    local saturation = high > 0 and delta / high or 0

    if delta > 0 then
        if high == r then
            hue = ((g - b) / delta) % 6
        elseif high == g then
            hue = ((b - r) / delta) + 2
        else
            hue = ((r - g) / delta) + 4
        end
        hue = hue / 6
    end

    return hue, saturation, high
end

local function dDropdown(kind, x, y, w, choices, value, multi, callback, item, keybind)
    local vw, vh = viewportSize()
    local height
    if multi then
        height = min(#choices * 22 + 30, 234)
    else
        height = min(#choices * 22 + 6, 210)
    end
    ProjectState.dropdown = {
        kind = kind,
        x = clamp(x, 8, max(8, vw - w - 8)),
        y = clamp(y, 8, max(8, vh - height - 8)),
        w = w,
        h = height,
        choices = choices,
        value = value,
        multi = multi == true,
        callback = callback,
        item = item,
        keybind = keybind,
        scrollOffset = 0,
    }
    ProjectState.colorpicker = nil
end

local function doColorPicker(x, y, picker)
    local h, s, v = toHsv(picker.value)
    local vw, vh = viewportSize()
    local w, height = 220, 260

    ProjectState.colorpicker = {
        x = clamp(x, 8, max(8, vw - w - 8)),
        y = clamp(y, 8, max(8, vh - height - 8)),
        w = w,
        h = height,
        picker = picker,
        hue = h,
        sat = s,
        val = v,
        value = picker.value,
        alpha = picker.alpha or 1,
        _hexInput = nil,
    }
    ProjectState.dropdown = nil
end

local function tooltip(text, x, y)
    if not text or text == "" then
        return
    end
    if ProjectState.lastTooltipText ~= text then
        ProjectState.tooltipAt = clock()
    end
    ProjectState.tooltipText = text
    ProjectState.tooltipX = x
    ProjectState.tooltipY = y
end

local function renderTooltip()
    local textValue = ProjectState.tooltipText
    if not textValue or clock() - ProjectState.tooltipAt < 0.35 then
        return
    end

    local width = min(260, textWidth(textValue, 12) + 16)
    local x = ProjectState.tooltipX + 12
    local y = ProjectState.tooltipY + 18
    local vw, vh = viewportSize()
    x = clamp(x, 8, max(8, vw - width - 8))
    y = clamp(y, 8, max(8, vh - 32))

    rect(x, y, width, 28, Theme.black, 140, 6, 0.92)
    strokeRect(x, y, width, 28, Theme.border, 141, 6)
    txt(textValue, x + 8, textTop(y, 28, 12), Theme.text, 12, FontUI, 142, false, false, width - 16)
end

local function renderDropdown(click)
    local dd = ProjectState.dropdown
    if not dd then
        return click
    end

    local isMulti = dd.multi == true
    local headerH = isMulti and 24 or 0
    local maxRows = floor((dd.h - 6 - headerH) / 22)
    dd.scrollOffset = dd.scrollOffset or 0

    local isHoveredDropdown = over(dd.x - 4, dd.y - 4, dd.w + 8, dd.h + 8)
    if isHoveredDropdown then
        if ProjectState.mouseScroll ~= 0 then
            dd.scrollOffset = clamp(dd.scrollOffset - (ProjectState.mouseScroll > 0 and 1 or -1), 0, max(0, #dd.choices - maxRows))
        end
        if Input.down.click then
            dd.scrollOffset = min(#dd.choices - maxRows, dd.scrollOffset + 1)
        elseif Input.up.click then
            dd.scrollOffset = max(0, dd.scrollOffset - 1)
        elseif Input.pagedown.click then
            dd.scrollOffset = min(#dd.choices - maxRows, dd.scrollOffset + maxRows)
        elseif Input.pageup.click then
            dd.scrollOffset = max(0, dd.scrollOffset - maxRows)
        end
    end
    dd.scrollOffset = clamp(dd.scrollOffset, 0, max(0, #dd.choices - maxRows))

    rect(dd.x - 1, dd.y - 1, dd.w + 2, dd.h + 2, Theme.border, 110, 4)
    rect(dd.x, dd.y, dd.w, dd.h, Theme.surface, 111, 4)

    if isMulti then
        local btnW = (dd.w - 12) / 2
        local btnY = dd.y + 4
        local btnH = 18

        local selectAllX = dd.x + 4
        local clearAllX = dd.x + 8 + btnW

        local hoverSelectAll = over(selectAllX, btnY, btnW, btnH)
        local hoverClearAll = over(clearAllX, btnY, btnW, btnH)

        rect(selectAllX, btnY, btnW, btnH, hoverSelectAll and Theme.surface3 or Theme.surface2, 112, 4)
        strokeRect(selectAllX, btnY, btnW, btnH, hoverSelectAll and Theme.accent or Theme.border, 113, 4)
        txt("Select All", selectAllX + btnW / 2, centerY(btnY, btnH), Theme.text, 11, FontUI, 113, true)

        rect(clearAllX, btnY, btnW, btnH, hoverClearAll and Theme.surface3 or Theme.surface2, 112, 4)
        strokeRect(clearAllX, btnY, btnW, btnH, hoverClearAll and Theme.accent or Theme.border, 113, 4)
        txt("Clear All", clearAllX + btnW / 2, centerY(btnY, btnH), Theme.text, 11, FontUI, 113, true)

        line(dd.x + 4, dd.y + 25, dd.x + dd.w - 4, dd.y + 25, Theme.border, 113)

        if click then
            if hoverSelectAll then
                if dd.item then
                    setDropdownValue(dd.item, dd.choices, true)
                else
                    for vi = #dd.value, 1, -1 do
                        dd.value[vi] = nil
                    end
                    for i = 1, #dd.choices do
                        dd.value[i] = dd.choices[i]
                    end
                    safeCallback(dd.callback, dd.value)
                end
                click = false
            elseif hoverClearAll then
                if dd.item then
                    setDropdownValue(dd.item, {}, true)
                else
                    for vi = #dd.value, 1, -1 do
                        dd.value[vi] = nil
                    end
                    safeCallback(dd.callback, dd.value)
                end
                click = false
            end
        end
    end

    if dd.scrollOffset > 0 then
        triangle(V2(dd.x + dd.w - 14, dd.y + headerH + 8), V2(dd.x + dd.w - 6, dd.y + headerH + 8), V2(dd.x + dd.w - 10, dd.y + headerH + 4), Theme.sub, 115, true)
    end
    if dd.scrollOffset + maxRows < #dd.choices then
        triangle(V2(dd.x + dd.w - 14, dd.y + dd.h - 8), V2(dd.x + dd.w - 6, dd.y + dd.h - 8), V2(dd.x + dd.w - 10, dd.y + dd.h - 4), Theme.sub, 115, true)
    end

    for idx = 1, min(#dd.choices, maxRows) do
        local actualIndex = idx + dd.scrollOffset
        local choice = dd.choices[actualIndex]
        if not choice then break end
        
        local rowY = dd.y + 3 + headerH + (idx - 1) * 22
        local selected = false

        if dd.kind == "keymode" then
            selected = dd.keybind and dd.keybind.mode == choice
        else
            for vi = 1, #dd.value do
                if dd.value[vi] == choice then
                    selected = true
                    break
                end
            end
        end

        local hovered = over(dd.x, rowY, dd.w, 22)
        if selected or hovered then
            rect(dd.x + 2, rowY, dd.w - 4, 22, hovered and Theme.surface3 or Theme.surface2, 112, 3)
        end
        local textX = dd.x + 10
        if selected then
            textX = dd.x + 20
            rect(dd.x + 10, rowY + 5, 2, 12, Theme.accent, 114)
        end

        local isDeletable = dd.item and dd.item.deletable
        local textMaxW = dd.w - 24 - (isDeletable and 20 or 0)
        txt(tostring(choice), textX, textTop(rowY, 22, 13), selected and Theme.accent or Theme.text, 13, FontSystem, 113, false, false, textMaxW)

        if isDeletable then
            local trashW = 18
            local trashBtnX = dd.x + dd.w - trashW - 2
            local trashHovered = over(trashBtnX, rowY + 2, trashW, 18)
            if hovered or trashHovered then
                rect(trashBtnX, rowY + 2, trashW, 18, trashHovered and Theme.surface or Theme.surface2, 113, 3)
                drawTrashIcon(trashBtnX + 4, rowY + 4, trashHovered and Theme.red or Theme.sub, 114, 1)
            end
            if click and trashHovered then
                if dd.item.onDelete then dd.item.onDelete(choice) end
                dd.choices = copyArray(dd.item.choices)
                dd.value = copyArray(dd.item.value)
                dd.scrollOffset = clamp(dd.scrollOffset, 0, max(0, #dd.choices - maxRows))
                return false
            end
        end

        if click and hovered and not (isDeletable and over(dd.x + dd.w - 20, rowY + 2, 18, 18)) then
            if dd.kind == "keymode" then
                dd.keybind.mode = choice
                safeCallback(dd.keybind.callback, dd.keybind.value and Input[dd.keybind.value] and Input[dd.keybind.value].id or nil, dd.keybind.mode)
                ProjectState.dropdown = nil
            elseif dd.multi then
                if dd.item then
                    local newValue = copyArray(dd.value)
                    if selected then
                        for vi = #newValue, 1, -1 do
                            if newValue[vi] == choice then
                                remove(newValue, vi)
                            end
                        end
                    else
                        newValue[#newValue + 1] = choice
                    end
                    setDropdownValue(dd.item, newValue, true)
                else
                    if selected then
                        for vi = #dd.value, 1, -1 do
                            if dd.value[vi] == choice then
                                remove(dd.value, vi)
                            end
                        end
                    else
                        dd.value[#dd.value + 1] = choice
                    end
                    safeCallback(dd.callback, dd.value)
                end
            else
                if dd.item then
                    setDropdownValue(dd.item, {choice}, true)
                else
                    local changed = dd.value[1] ~= choice or #dd.value ~= 1
                    for vi = #dd.value, 1, -1 do
                        dd.value[vi] = nil
                    end
                    dd.value[1] = choice
                    if changed then
                        safeCallback(dd.callback, dd.value)
                    end
                end
                ProjectState.dropdown = nil
            end
            return false
        end
    end

    if click and not isHoveredDropdown then
        ProjectState.dropdown = nil
        return false
    end

    return click
end

local function renderColorpicker(click, held)
    local cp = ProjectState.colorpicker
    if not cp then
        return click
    end

    local x, y, w, h = cp.x, cp.y, cp.w, cp.h

    if click and over(x, y, w, 24) then
        ProjectState.cpDrag = { ProjectState.mouseX - x, ProjectState.mouseY - y }
        click = false
    end

    if held and ProjectState.cpDrag then
        cp.x = ProjectState.mouseX - ProjectState.cpDrag[1]
        cp.y = ProjectState.mouseY - ProjectState.cpDrag[2]
        local szX, szY = viewportSize()
        cp.x = clamp(cp.x, 0, szX - w)
        cp.y = clamp(cp.y, 0, szY - h)
        if szX < 0 or szY < 0 then
            szX = 0
        end
        x, y = cp.x, cp.y
    else
        ProjectState.cpDrag = nil
    end

    rect(x, y, w, h, Theme.surface2, 110, 8)
    strokeRect(x, y, w, h, Theme.border, 111, 8)
    txt(cp.picker.label, x + 10, y + 8, Theme.text, 13, FontBold, 112, false, false, w - 20)

    local palX, palY = x + 10, y + 28
    local palW, palH = 160, 160

    rect(palX, palY, palW, palH, Theme.surface, 112, 8)
    local cpSquares = ProjectState.cpPaletteSquares
    if not cpSquares then
        cpSquares = {}
        ProjectState.cpPaletteSquares = cpSquares
    end
    local hueChanged = (ProjectState.cpLastHue ~= cp.hue)
    ProjectState.cpLastHue = cp.hue
    if #cpSquares == 0 then
        for gx = 3, palW - 4, 4 do
            for gy = 3, palH - 4, 4 do
                local sq = DrawingNew("Square")
                sq.Size = V2(math.min(4, palW - 3 - gx), math.min(4, palH - 3 - gy))
                sq.Filled = true
                sq.Corner = 0
                sq.ZIndex = 113
                sq.Transparency = 1
                sq.Visible = false
                cpSquares[#cpSquares + 1] = {
                    obj = sq,
                    relX = gx,
                    relY = gy,
                    sx = clamp(gx / palW, 0, 1),
                    sy = 1 - clamp(gy / palH, 0, 1)
                }
            end
        end
    end
    for i = 1, #cpSquares do
        local cell = cpSquares[i]
        cell.obj.Position = V2(palX + cell.relX, palY + cell.relY)
        if hueChanged or not cell.initialized then
            cell.obj.Color = HSV(cp.hue, cell.sx, cell.sy)
            cell.initialized = true
        end
        cell.obj.Visible = true
    end

    if held and over(palX, palY, palW, palH) then
        cp.sat = clamp((ProjectState.mouseX - palX) / palW, 0, 1)
        cp.val = 1 - clamp((ProjectState.mouseY - palY) / palH, 0, 1)
    end

    circle(palX + cp.sat * palW, palY + (1 - cp.val) * palH, 4, Theme.white, 116, false, 2, 20)

    local hueX, hueY = x + 178, y + 28
    local hueW, hueH = 12, 160
    rect(hueX, hueY, hueW, hueH, Theme.surface, 112, 6)
    for gy = hueY + 2, hueY + hueH - 3, 4 do
        rect(hueX + 2, gy, hueW - 4, min(4, hueY + hueH - 2 - gy), HSV((gy - hueY) / hueH, 1, 1), 113, 0)
    end

    if held and over(hueX, hueY, hueW, hueH) then
        cp.hue = clamp((ProjectState.mouseY - hueY) / hueH, 0, 1)
    end

    rect(hueX - 1, hueY + cp.hue * hueH - 2, hueW + 2, 4, Theme.white, 116, 1)

    local alphaX, alphaY = x + 198, y + 28
    local alphaW, alphaH = 12, 160
    rect(alphaX, alphaY, alphaW, alphaH, Theme.surface, 112, 6)
    for gy = alphaY + 2, alphaY + alphaH - 3, 6 do
        local blockH = min(6, alphaY + alphaH - 2 - gy)
        rect(alphaX + 2, gy, 4, blockH, (floor((gy - alphaY) / 6) % 2 == 0) and Theme.white or C3(200, 200, 200), 113, 0)
        rect(alphaX + 6, gy, 4, blockH, (floor((gy - alphaY) / 6) % 2 == 0) and C3(200, 200, 200) or Theme.white, 113, 0)
    end

    for gy = alphaY + 2, alphaY + alphaH - 3, 4 do
        rect(alphaX + 2, gy, alphaW - 4, min(4, alphaY + alphaH - 2 - gy), cp.value, 114, 0, 1 - ((gy - alphaY) / alphaH))
    end

    strokeRect(palX, palY, palW, palH, Theme.border, 115, 8)
    strokeRect(hueX, hueY, hueW, hueH, Theme.border, 115, 6)
    strokeRect(alphaX, alphaY, alphaW, alphaH, Theme.border, 115, 6)

    if held and over(alphaX, alphaY, alphaW, alphaH) then
        cp.alpha = 1 - clamp((ProjectState.mouseY - alphaY) / alphaH, 0, 1)
    end

    rect(alphaX - 1, alphaY + (1 - cp.alpha) * alphaH - 2, alphaW + 2, 4, Theme.white, 116, 1)

    rect(x + 10, y + 196, 200, 22, (ProjectState.focus == cp) and Theme.surface or over(x + 10, y + 196, 200, 22) and Theme.surface3 or Theme.surface2, 114, 4)
    strokeRect(x + 10, y + 196, 200, 22, (ProjectState.focus == cp) and Theme.accent or Theme.border, 115, 4)

    local isFocusedCP = ProjectState.focus == cp
    local hexText = isFocusedCP and (cp._hexInput or "") or ("#" .. toHex(cp.value))
    txt(hexText, x + 16, textTop(y + 196, 22, 12), Theme.text, 12, FontUI, 116, false, false, 188)
    if isFocusedCP then
        txt("|", x + 16 + textWidth(hexText, 12, FontUI), textTop(y + 196, 22, 12), Theme.text, 12, FontUI, 117, false, false, nil, clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
    end

    if click and over(x + 10, y + 196, 200, 22) then
        ProjectState.focus = (ProjectState.focus == cp) and nil or cp
        cp._hexInput = toHex(cp.value)
        click = false
    end

    rect(x + 10, y + 228, 60, 22, Theme.surface, 114, 4)
    strokeRect(x + 10, y + 228, 60, 22, Theme.border, 115, 4)
    txt("R", x + 16, textTop(y + 228, 22, 12), C3(255, 69, 58), 12, FontBold, 116)
    txt(tostring(floor(cp.value.R * 255 + 0.5)), x + 64 - textWidth(tostring(floor(cp.value.R * 255 + 0.5)), 12, FontUI), textTop(y + 228, 22, 12), Theme.text, 12, FontUI, 116)

    rect(x + 80, y + 228, 60, 22, Theme.surface, 114, 4)
    strokeRect(x + 80, y + 228, 60, 22, Theme.border, 115, 4)
    txt("G", x + 86, textTop(y + 228, 22, 12), C3(52, 199, 89), 12, FontBold, 116)
    txt(tostring(floor(cp.value.G * 255 + 0.5)), x + 134 - textWidth(tostring(floor(cp.value.G * 255 + 0.5)), 12, FontUI), textTop(y + 228, 22, 12), Theme.text, 12, FontUI, 116)

    rect(x + 150, y + 228, 60, 22, Theme.surface, 114, 4)
    strokeRect(x + 150, y + 228, 60, 22, Theme.border, 115, 4)
    txt("B", x + 156, textTop(y + 228, 22, 12), C3(0, 122, 255), 12, FontBold, 116)
    txt(tostring(floor(cp.value.B * 255 + 0.5)), x + 204 - textWidth(tostring(floor(cp.value.B * 255 + 0.5)), 12, FontUI), textTop(y + 228, 22, 12), Theme.text, 12, FontUI, 116)

    local final = HSV(cp.hue, cp.sat, cp.val)
    if colorChanged(final, cp.value) or (cp.alpha ~= cp.picker.alpha) then
        cp.value = final
        cp.picker.value = final
        cp.picker.alpha = cp.alpha
        safeCallback(cp.picker.callback, final, cp.alpha)
    end

    if click and not over(x, y, w, h) then
        if ProjectState.focus == cp then
            ProjectState.focus = nil
        end
        ProjectState.colorpicker = nil
        ProjectState.cpDrag = nil
        return false
    end

    return click
end

local function renderWatermark(click, held)
    if not ProjectState.watermarkEnabled then
        return
    end
    
    local title = ProjectState.watermarkTitle ~= "" and ProjectState.watermarkTitle or ProjectState.title or "homesick"
    local text = ProjectState.activityText ~= "" and (title .. " | " .. ProjectState.activityText) or title
    
    local w = textWidth(text, 12, FontUI) + 20
    local h = 24
    local x = ProjectState.watermarkX or 20
    local y = ProjectState.watermarkY or 20
    
    local hovered = over(x, y, w, h)
    if click and hovered then
        ProjectState.watermarkDrag = {ProjectState.mouseX - x, ProjectState.mouseY - y}
    end
    
    if held and ProjectState.watermarkDrag then
        ProjectState.watermarkX = ProjectState.mouseX - ProjectState.watermarkDrag[1]
        ProjectState.watermarkY = ProjectState.mouseY - ProjectState.watermarkDrag[2]
        
        local vw, vh = viewportSize()
        ProjectState.watermarkX = clamp(ProjectState.watermarkX, 0, vw - w)
        ProjectState.watermarkY = clamp(ProjectState.watermarkY, 0, vh - h)
        
        x = ProjectState.watermarkX
        y = ProjectState.watermarkY
    elseif not held then
        ProjectState.watermarkDrag = nil
    end
    
    rect(x, y, w, h, Theme.surface, 150, 6, 0.85)
    strokeRect(x, y, w, h, Theme.accent, 151, 6)
    txt(text, x + 10, textTop(y, h, 12), Theme.text, 12, FontUI, 152, false, false)
end

local function renderTabs(click, px, py, pw)
    local count = #ProjectState.tabs
    if count == 0 then
        return click
    end

    local totalW = count * TAB_MIN_W
    local needsScroll = totalW > pw
    local tabW = needsScroll and TAB_MIN_W or (pw / count)
    local maxScroll = max(0, totalW - pw)

    local dtValue = ProjectState.dt or 1 / 60
    if dtValue <= 0 then dtValue = 1 / 60 end
    local target = clamp(ProjectState.tabTargetScrollX or 0, 0, maxScroll)
    ProjectState.tabTargetScrollX = target
    local current = ProjectState.tabScrollX or 0
    local factor = 1 - math.exp(-18 * dtValue)
    current = current + (target - current) * factor
    current = clamp(current, 0, maxScroll)
    ProjectState.tabScrollX = current
    local scrollX = current

    local contentX = px + (needsScroll and 18 or 0)
    local contentW = pw - (needsScroll and 36 or 0)

    if needsScroll and scrollX > 1 then
        local arrowHovered = over(px, py, 18, TAB_H)
        rect(px, py, 18, TAB_H, arrowHovered and Theme.surface3 or Theme.surface, 26, 0)
        local cy = centerY(py, TAB_H)
        triangle(V2(px + 6, cy), V2(px + 12, cy - 4), V2(px + 12, cy + 4), Theme.sub, 27, true)
        if click and arrowHovered then
            ProjectState.tabTargetScrollX = max(0, target - TAB_MIN_W)
            click = false
        end
    end

    if needsScroll and scrollX < maxScroll - 1 then
        local ax = px + pw - 18
        local arrowHovered = over(ax, py, 18, TAB_H)
        rect(ax, py, 18, TAB_H, arrowHovered and Theme.surface3 or Theme.surface, 26, 0)
        local cy = centerY(py, TAB_H)
        triangle(V2(ax + 12, cy), V2(ax + 6, cy - 4), V2(ax + 6, cy + 4), Theme.sub, 27, true)
        if click and arrowHovered then
            ProjectState.tabTargetScrollX = min(maxScroll, target + TAB_MIN_W)
            click = false
        end
    end

    if needsScroll and ProjectState.tabScrollToActive and ProjectState.activeTab then
        local idx = ProjectState.activeIndex or 1
        local tabStart = tabW * (idx - 1)
        local tabEnd = tabStart + tabW
        local visibleStart = scrollX
        local visibleEnd = scrollX + contentW
        if tabStart < visibleStart then
            ProjectState.tabTargetScrollX = tabStart
        elseif tabEnd > visibleEnd then
            ProjectState.tabTargetScrollX = tabEnd - contentW
        end
        ProjectState.tabScrollToActive = false
    end

    if Input.m1.released then
        ProjectState.draggedTab = nil
    end

    for i = 1, count do
        local tab = ProjectState.tabs[i]
        local localTx = tabW * (i - 1)
        tab.targetX = localTx
        if not tab.currentX then
            tab.currentX = localTx
        end

        local active = ProjectState.activeTab == tab
        local screenX = contentX + tab.currentX - scrollX
        local hovered = over(screenX, py, tabW, TAB_H)

        if click and hovered and not ProjectState.draggedTab then
            if ProjectState.activeTab ~= tab then
                ProjectState.contentFade = 0
            end
            ProjectState.activeTab = tab
            ProjectState.activeIndex = i
            ProjectState.dropdown = nil
            ProjectState.colorpicker = nil
            ProjectState.focus = nil
            click = false
            ProjectState.tabScrollToActive = true
        end

        if ProjectState.draggedTab == tab then
            if abs(ProjectState.mouseX - ProjectState.dragTabStartMouseX) > 5 then
                tab.currentX = clamp(ProjectState.mouseX - ProjectState.draggedTabOffset - contentX + scrollX, 0, totalW - tabW)

                local idx = i
                if idx > 1 then
                    local prevTab = ProjectState.tabs[idx - 1]
                    if tab.currentX < prevTab.currentX then
                        ProjectState.tabs[idx], ProjectState.tabs[idx - 1] = ProjectState.tabs[idx - 1], ProjectState.tabs[idx]
                        if ProjectState.activeIndex == idx then
                            ProjectState.activeIndex = idx - 1
                        elseif ProjectState.activeIndex == idx - 1 then
                            ProjectState.activeIndex = idx
                        end
                    end
                end
                if idx < count then
                    local nextTab = ProjectState.tabs[idx + 1]
                    if tab.currentX > nextTab.currentX then
                        ProjectState.tabs[idx], ProjectState.tabs[idx + 1] = ProjectState.tabs[idx + 1], ProjectState.tabs[idx]
                        if ProjectState.activeIndex == idx then
                            ProjectState.activeIndex = idx + 1
                        elseif ProjectState.activeIndex == idx + 1 then
                            ProjectState.activeIndex = idx
                        end
                    end
                end
            else
                tab.currentX = smoothValue(tab.currentX, localTx, 18)
            end
        else
            tab.currentX = smoothValue(tab.currentX, localTx, 18)
        end
    end

    local targetPillX = nil
    local targetPillW = nil

    for i = 1, count do
        local tab = ProjectState.tabs[i]
        local tx = contentX + tab.currentX - scrollX
        local visible = tx + tabW >= contentX and tx <= contentX + contentW
        if visible then
            local active = ProjectState.activeTab == tab
            local hovered = over(tx, py, tabW, TAB_H)
            
            if active then
                targetPillX = tab.currentX - scrollX + 4
                targetPillW = tabW - 8
                txt(tab.name, tx + tabW / 2, centerY(py, TAB_H), Theme.text, 13, FontBold, 25, true, false, tabW - 12)
            else
                txt(tab.name, tx + tabW / 2, centerY(py, TAB_H), hovered and Theme.text or Theme.sub, 13, FontSystem, 25, true, false, tabW - 12)
            end
        end
    end

    if targetPillX and targetPillW then
        if not ProjectState.currentPillX then
            ProjectState.currentPillX = targetPillX
            ProjectState.currentPillW = targetPillW
        elseif ProjectState.tabAnimations == false then
            ProjectState.currentPillX = targetPillX
            ProjectState.currentPillW = targetPillW
        else
            ProjectState.currentPillX = smoothValue(ProjectState.currentPillX, targetPillX, 18)
            ProjectState.currentPillW = smoothValue(ProjectState.currentPillW, targetPillW, 18)
        end
    end

    if ProjectState.currentPillX and ProjectState.currentPillW then
        rect(contentX + ProjectState.currentPillX, py + 3, ProjectState.currentPillW, TAB_H - 6, Theme.accent, 21, 10, 0.08)
        strokeRect(contentX + ProjectState.currentPillX, py + 3, ProjectState.currentPillW, TAB_H - 6, Theme.accent, 22, 10)
    end

    return click
end

local function renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
    local currentX = rowX + rowW - 4
    
    if item.tooltip then
        currentX = currentX - 18
    end

    if item.keybind then
        currentX = currentX - 48
        local keyX = currentX
        local hovered = over(keyX, rowY + 3, 46, 20)

        rect(keyX, rowY + 3, 46, 20, Theme.surface3, 45, 4, trans)
        strokeRect(keyX, rowY + 3, 46, 20, hovered and Theme.accent or Theme.border, 46, 4, trans)

        txt(item.keybind.listening and "..." or (item.keybind.value and string.upper(item.keybind.value) or "-"), keyX + 23, centerY(rowY + 3, 20), item.keybind.value and Theme.text or Theme.sub, 12, FontUI, 52, true, false, 42, trans)

        txt(item.keybind.mode == "Toggle" and "T" or item.keybind.mode == "Always" and "A" or "H", keyX - 8, centerY(rowY, ROW_H - 2), item.keybind.mode == "Hold" and Theme.sub or Theme.accent, 10, FontUI, 52, true, false, nil, trans)

        if item.keybind.listening then
            for i = 1, #InputOrder do
                local name = InputOrder[i]
                local input = Input[name]
                if input.click and (name ~= "m1" or clock() - item.keybind.listenAt > 0.25) then
                    local newKey = normalizeKey(name)
                    if name == "backspace" or name == "delete" or name == "unbound" or name == "esc" then
                        newKey = nil
                    end
                    item.keybind.value = newKey
                    item.keybind.listening = false
                    safeCallback(item.keybind.callback, newKey and Input[newKey] and Input[newKey].id or nil, item.keybind.mode)
                    break
                end
            end
        elseif click and hovered then
            item.keybind.listening = true
            item.keybind.listenAt = clock()
            click = false
        elseif rightClick and hovered and item.keybind.canChange then
            dDropdown("keymode", keyX, rowY + 24, 90, KEYBIND_MODES, nil, false, nil, nil, item.keybind)
            rightClick = false
        end
        currentX = currentX - 14
    end

    if item.colorpicker then
        currentX = currentX - 16
        local cpX = currentX
        local hovered = over(cpX - 3, rowY + 5, 18, 18)

        rect(cpX, rowY + 8, 12, 12, item.colorpicker.value, 46, 3, trans * (item.colorpicker.alpha or 1))
        strokeRect(cpX, rowY + 8, 12, 12, Theme.border, 47, 3, trans)

        if hovered then
            strokeRect(cpX - 2, rowY + 6, 16, 16, Theme.accent, 48, 4, trans)
        end

        if click and hovered then
            doColorPicker(ProjectState.mouseX + 14, ProjectState.mouseY - 90, item.colorpicker)
            click = false
        elseif rightClick and hovered then
            dDropdown("colorctx", cpX - 34, rowY + 24, 80, {"Copy", "Paste"}, {}, false, function(choice)
                if choice and choice[1] == "Copy" then
                    ProjectState.copiedColor = item.colorpicker.value
                    pcall(setclipboard, "#" .. toHex(item.colorpicker.value))
                elseif choice and choice[1] == "Paste" then
                    if ProjectState.copiedColor and colorChanged(item.colorpicker.value, ProjectState.copiedColor) then
                        item.colorpicker.value = ProjectState.copiedColor
                        safeCallback(item.colorpicker.callback, item.colorpicker.value)
                    else
                        warn("color clipboard empty lol")
                    end
                end
            end, nil, nil)
            rightClick = false
        end
    end

    return click, rightClick
end

local function getItemHeight(item, rowW)
    if item.type == "slider" then
        return 38
    elseif item.type == "dropdown" then
        return 44
    elseif item.type == "textbox" then
        return 44
    elseif item.type == "label" then
        local labelLines = wrapLines(item.label, rowW or 1000, 13, FontSystem)
        item._cachedLineCount = #labelLines
        return math.max(28, #labelLines * 16 + 8)
    end
    return 28
end

local function draw9Dot(x, y, color, z, trans)
    for row = 0, 2 do
        for col = 0, 2 do
            circle(x + col * 3 + 1, y + row * 3 + 1, 1, color, z, true, 0, 8, trans)
        end
    end
end

local function getPerimeterPoint(d, colX, renderY, colW, renderH)
    d = d % (2 * (colW + renderH) - 13.736)
    if d < 0 then d = d + (2 * (colW + renderH) - 13.736) end
    if d < colW - 16 then
        return colX + 8 + d, renderY
    elseif d < colW - 3.434 then
        local t = -1.5708 + (d - (colW - 16)) / 12.566 * 1.5708
        return colX + colW - 8 + math.cos(t) * 8, renderY + 8 + math.sin(t) * 8
    elseif d < colW + renderH - 19.434 then
        return colX + colW, renderY + 8 + (d - (colW - 3.434))
    elseif d < colW + renderH - 6.868 then
        local t = (d - (colW + renderH - 19.434)) / 12.566 * 1.5708
        return colX + colW - 8 + math.cos(t) * 8, renderY + renderH - 8 + math.sin(t) * 8
    elseif d < 2 * colW + renderH - 22.868 then
        return colX + colW - 8 - (d - (colW + renderH - 6.868)), renderY + renderH
    elseif d < 2 * colW + renderH - 10.302 then
        local t = 1.5708 + (d - (2 * colW + renderH - 22.868)) / 12.566 * 1.5708
        return colX + 8 + math.cos(t) * 8, renderY + renderH - 8 + math.sin(t) * 8
    elseif d < 2 * colW + 2 * renderH - 26.302 then
        return colX, renderY + renderH - 8 - (d - (2 * colW + renderH - 10.302))
    else
        local t = 3.1416 + (d - (2 * colW + 2 * renderH - 26.302)) / 12.566 * 1.5708
        return colX + 8 + math.cos(t) * 8, renderY + 8 + math.sin(t) * 8
    end
end

local function renderSectionCard(section, colX, sy, colW, secH, clipTop, clipBottom, click, held, rightClick, isPlaceholder, isFloating)
    local popupBlocking = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil or isFloating
    local z = isFloating and 90 or 30
    local cardTrans = isFloating and (0.75 * (ProjectState.contentFade or 1)) or (ProjectState.contentFade or 1)
    local cardClipTop = isFloating and (ProjectState.y + TITLE_H) or clipTop
    local cardClipBottom = isFloating and (ProjectState.y + ProjectState.h - 24) or clipBottom
    local renderY = max(sy, cardClipTop)
    local renderH = min(sy + secH, cardClipBottom) - renderY

    if renderH > 0 then
        if isPlaceholder then
            rect(colX, renderY, colW, renderH, Theme.surface, z, 8, 0.25 * cardTrans)
            strokeRect(colX, renderY, colW, renderH, Theme.border, z + 1, 8, 0.4 * cardTrans)
            return click, held, rightClick
        end

        rect(colX, renderY, colW, renderH, Theme.surface2, z, 8, cardTrans)
        strokeRect(colX, renderY, colW, renderH, Theme.border, z + 1, 8, cardTrans)

        local cx = clamp(ProjectState.mouseX, colX, colX + colW)
        local cy = clamp(ProjectState.mouseY, renderY, renderY + renderH)
        if ProjectState.mouseX > colX and ProjectState.mouseX < colX + colW and ProjectState.mouseY > renderY and ProjectState.mouseY < renderY + renderH then
            if min(abs(ProjectState.mouseX - colX), abs(ProjectState.mouseX - (colX + colW)), abs(ProjectState.mouseY - renderY), abs(ProjectState.mouseY - (renderY + renderH))) == abs(ProjectState.mouseX - colX) then
                cx = colX
            elseif min(abs(ProjectState.mouseX - colX), abs(ProjectState.mouseX - (colX + colW)), abs(ProjectState.mouseY - renderY), abs(ProjectState.mouseY - (renderY + renderH))) == abs(ProjectState.mouseX - (colX + colW)) then
                cx = colX + colW
            elseif min(abs(ProjectState.mouseX - colX), abs(ProjectState.mouseX - (colX + colW)), abs(ProjectState.mouseY - renderY), abs(ProjectState.mouseY - (renderY + renderH))) == abs(ProjectState.mouseY - renderY) then
                cy = renderY
            else
                cy = renderY + renderH
            end
        end

        if cy == renderY + renderH and clamp(1 - (math.sqrt((ProjectState.mouseX - cx)^2 + (ProjectState.mouseY - cy)^2) / 80), 0, 1) > 0 then
            local d_mouse
            if cy == renderY then
                d_mouse = cx - colX - 8
            elseif cx == colX + colW then
                d_mouse = colW - 3.434 + (cy - renderY - 8)
            elseif cy == renderY + renderH then
                d_mouse = colW + renderH - 6.868 + (colX + colW - 8 - cx)
            elseif cx == colX then
                d_mouse = 2 * colW + renderH - 10.302 + (renderY + renderH - 8 - cy)
            end
            
            if d_mouse then
                for i = 1, 24 do
                    local x1, y1 = getPerimeterPoint(d_mouse - 40 + (i - 1) * 3.333, colX, renderY, colW, renderH)
                    local x2, y2 = getPerimeterPoint(d_mouse - 40 + i * 3.333, colX, renderY, colW, renderH)
                    line(x1, y1, x2, y2, section.locked and Theme.sub or Theme.accent, z + 2, 2, clamp(1 - (abs(-40 + (i - 0.5) * 3.333) / 40), 0, 1) * clamp(1 - (math.sqrt((ProjectState.mouseX - cx)^2 + (ProjectState.mouseY - cy)^2) / 80), 0, 1) * cardTrans)
                end
            end
        end
        
        local headerTrans = clamp((min(sy + 28, cardClipBottom) - max(sy, cardClipTop)) / 28, 0, 1)
        if headerTrans > 0 then
            local hTrans = cardTrans * headerTrans
            txt(section.name, colX + 12, sy + 8, Theme.accent, 13, FontBold, z + 2, false, false, nil, hTrans)
            
            local showLock = section.allowLocking ~= false
            
            local iconY = sy + 9
            draw9Dot(colX + colW - 20, sy + 10, (showLock and section.locked) and C3(80, 75, 73) or Theme.sub, z + 2, hTrans)
            if showLock then
                drawLockIcon(colX + colW - 38, iconY, section.locked and Theme.accent or Theme.sub, z + 2, section.locked and hTrans or hTrans * 0.5, not section.locked)
            end

            if section.name == "Configs" or section.name == "Themes" then
                local expX = colX + colW - 54
                local expHovered = not popupBlocking and over(expX - 2, sy + 4, 14, 20) and headerTrans > 0.5
                local expColor = expHovered and Theme.accent or Theme.sub
                drawExportIcon(expX - 2, iconY, expColor, z + 2, hTrans * (expHovered and 1 or 0.6))

                local impX = colX + colW - 70
                local impHovered = not popupBlocking and over(impX - 2, sy + 4, 14, 20) and headerTrans > 0.5
                local impColor = impHovered and Theme.accent or Theme.sub
                drawImportIcon(impX - 2, iconY, impColor, z + 2, hTrans * (impHovered and 1 or 0.6))

                if not isFloating and click and headerTrans > 0.5 then
                    if expHovered then
                        click = false
                        if section.name == "Configs" then
                            if pcall(setclipboard, exportConfig()) then
                                warn("config code copied to clipboard lol")
                            else
                                warn("failed to copy config to clipboard sadge")
                            end
                        else
                            if pcall(setclipboard, exportTheme()) then
                                warn("theme code copied to clipboard lol")
                            else
                                warn("failed to copy theme to clipboard sadge")
                            end
                        end
                    elseif impHovered then
                        click = false
                        local modalTextbox = {
                            type = "textbox",
                            value = "",
                            label = "enter code...",
                        }
                        ProjectState.importModal = {
                            type = (section.name == "Configs") and "config" or "theme",
                            textbox = modalTextbox,
                            onConfirm = function(code)
                                if section.name == "Configs" then
                                    importConfig(code)
                                    warn("config imported successfully lol")
                                else
                                    importTheme(code)
                                    warn("theme imported successfully lol")
                                end
                            end
                        }
                        ProjectState.focus = modalTextbox
                    end
                end
            end

            if not isFloating and headerTrans > 0.5 then
                if showLock and click and over(colX + colW - 38, sy + 6, 12, 12) and not popupBlocking then
                    section.locked = not section.locked
                    click = false
                end

                if click and over(colX + colW - 22, sy + 8, 14, 14) and not popupBlocking and not section.locked then
                    ProjectState.draggedSection = section
                    ProjectState.dragOffset = {ProjectState.mouseX - colX, ProjectState.mouseY - sy}
                    ProjectState.dragStartMouseX = ProjectState.mouseX
                    ProjectState.draggedSectionOriginalSide = section.side
                    click = false
                end
            end
        end

        if not isFloating then
            if click and over(colX, sy + secH - 4, colW, 8) and not popupBlocking and not section.locked and (sy + secH - 4 >= cardClipTop) and (sy + secH <= cardClipBottom) then
                ProjectState.resizeSection = section
                ProjectState.resizeSectionStartH = secH
                ProjectState.resizeSectionStartMouseY = ProjectState.mouseY
                click = false
            end
        end
        
        local rowY = sy + 28
        local rowW = colW - 24
        local rowX = colX + 12
        
        for ii = 1, #section.items do
            local item = section.items[ii]
            local itemH = getItemHeight(item, rowW)
            local disabled = isItemDisabled(item)
            local trans = (disabled and 0.4 or 1) * cardTrans * min(clamp((rowY - cardClipTop) / 16, 0, 1), clamp((cardClipBottom - (rowY + itemH)) / 16, 0, 1))
            if rowY + itemH > sy + secH - 4 then
                trans = 0
            end
            
            if trans > 0 then
                if item.type == "label" then
                    local labelLines = wrapLines(item.label, rowW, 13, FontSystem)
                    item._cachedLineCount = #labelLines
                    for li = 1, #labelLines do
                        txt(labelLines[li], rowX, rowY + (li - 1) * 16 + 4, item.color or Theme.text, 13, FontSystem, z + 12, false, false, rowW, trans)
                    end
                    
                elseif item.type == "checkbox" then
                    local targetAnim = item.value and 1 or 0
                    if ProjectState.hoverEffects == false then
                        item.animState = targetAnim
                    else
                        item.animState = smoothValue(item.animState or targetAnim, targetAnim, 18)
                    end
                    local cbX, cbY = rowX + 4, rowY + 6
                    rect(cbX, cbY, 14, 14, Theme.surface3, z + 12, 4, trans)
                    strokeRect(cbX, cbY, 14, 14, Theme.border, z + 13, 4, trans)
                    
                    if item.animState > 0.05 then
                        local offset = 7 * (1 - item.animState)
                        rect(cbX + offset, cbY + offset, 14 * item.animState, 14 * item.animState, Theme.accent, z + 14, 4 * item.animState, trans)
                    end
                    
                    local cbExtra = 6
                    if item.colorpicker then cbExtra = cbExtra + 20 end
                    if item.keybind then cbExtra = cbExtra + 64 end
                    if item.tooltip then cbExtra = cbExtra + 18 end
                    txt(item.label, rowX + 26, textTop(rowY, itemH - 2, 13), item.unsafe and Theme.unsafe or (item.value and Theme.text or Theme.sub), 13, FontSystem, z + 12, false, false, rowW - 26 - cbExtra, trans)
                    
                    if not isFloating then
                        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
                    end
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 6, 12, 12)
                        txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), qHovered and Theme.accent or Theme.sub, 13, FontSystem, z + 12, false, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
                        end
                    end
                    
                    if click and over(rowX, rowY, rowW, itemH) and not popupBlocking and not disabled and trans > 0.5 then
                        local onKeybind = item.keybind and over(rowX + rowW - 96, rowY + 3, 46, 20)
                        local onColor = item.colorpicker and over(rowX + rowW - 127, rowY + 5, 18, 18)
                        local onQ = item.tooltip and over(rowX + rowW - 16, rowY + 6, 12, 12)
                        local on9Dot = over(colX + colW - 22, sy + 8, 14, 14)
                        if not onKeybind and not onColor and not onQ and not on9Dot then
                            setItemValue(item, not item.value, true)
                            click = false
                        end
                    end
                    
                elseif item.type == "toggle" then
                    item.animState = smoothValue(item.animState or (item.value and 1 or 0), item.value and 1 or 0, 18)
                    local tgX, tgY = rowX + 4, rowY + 6
                    rect(tgX, tgY + 1, 24, 12, lerpColor(Theme.surface3, Theme.accent, item.animState), z + 12, 6, trans)
                    strokeRect(tgX, tgY + 1, 24, 12, lerpColor(Theme.border, Theme.accent, item.animState), z + 13, 6, trans)
                    circle(tgX + 6 + 12 * item.animState, tgY + 7, 4, Theme.text, z + 14, true, 0, 32, trans)
                    
                    local tgExtra = 16
                    if item.colorpicker then tgExtra = tgExtra + 20 end
                    if item.keybind then tgExtra = tgExtra + 64 end
                    if item.tooltip then tgExtra = tgExtra + 18 end
                    txt(item.label, rowX + 36, textTop(rowY, itemH - 2, 13), item.unsafe and Theme.unsafe or (item.value and Theme.text or Theme.sub), 13, FontSystem, z + 12, false, false, rowW - 36 - tgExtra, trans)
                    
                    if not isFloating then
                        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
                    end
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 6, 12, 12)
                        txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), qHovered and Theme.accent or Theme.sub, 13, FontSystem, z + 12, false, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
                        end
                    end
                    
                    if click and over(rowX, rowY, rowW, itemH) and not popupBlocking and not disabled and trans > 0.5 then
                        local onKeybind = item.keybind and over(rowX + rowW - 96, rowY + 3, 46, 20)
                        local onColor = item.colorpicker and over(rowX + rowW - 127, rowY + 5, 18, 18)
                        local onQ = item.tooltip and over(rowX + rowW - 16, rowY + 6, 12, 12)
                        local on9Dot = over(colX + colW - 22, sy + 8, 14, 14)
                        if not onKeybind and not onColor and not onQ and not on9Dot then
                            setItemValue(item, not item.value, true)
                            click = false
                        end
                    end
                    
                elseif item.type == "colorpicker" then
                    txt(item.label, rowX + 4, textTop(rowY, itemH - 2, 13), Theme.text, 13, FontSystem, z + 12, false, false, rowW - 28, trans)
                    local cpX = rowX + rowW - 16
                    local hovered = over(cpX - 3, rowY + 5, 18, 18)
                    rect(cpX, rowY + 8, 12, 12, item.value, z + 12, 3, trans * (item.alpha or 1))
                    strokeRect(cpX, rowY + 8, 12, 12, Theme.border, z + 13, 3, trans)
                    if hovered then
                        strokeRect(cpX - 2, rowY + 6, 16, 16, Theme.accent, z + 14, 4, trans)
                    end
                    if click and hovered and not popupBlocking and not disabled and trans > 0.5 then
                        doColorPicker(ProjectState.mouseX + 14, ProjectState.mouseY - 90, item)
                        click = false
                    elseif rightClick and hovered and not popupBlocking and not disabled and trans > 0.5 then
                        dDropdown("colorctx", cpX - 34, rowY + 24, 80, {"Copy", "Paste"}, {}, false, function(choice)
                            if choice and choice[1] == "Copy" then
                                ProjectState.copiedColor = item.value
                                pcall(setclipboard, "#" .. toHex(item.value))
                            elseif choice and choice[1] == "Paste" then
                                if ProjectState.copiedColor and colorChanged(item.value, ProjectState.copiedColor) then
                                    item.value = ProjectState.copiedColor
                                    safeCallback(item.callback, item.value)
                                else
                                    warn("color clipboard empty lol")
                                end
                            end
                        end, nil, nil)
                        rightClick = false
                    end
 
                elseif item.type == "slider" then
                    txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 80, trans)
                    
                    local isFocusedSlider = ProjectState.focus == item
                    local valStr = isFocusedSlider and (item._directValue or "") or tostring(item.value)
                    local boxW = max(36, textWidth(isFocusedSlider and valStr or (valStr .. tostring(item.suffix or "")), 12, FontUI) + 12)
                    local valBoxX = rowX + rowW - boxW - 4
                    local valBoxY = rowY + 1
                    local hoveredVal = over(valBoxX, valBoxY, boxW, 16) and not popupBlocking and not disabled
                    
                    if isFocusedSlider then
                        rect(valBoxX, valBoxY, boxW, 16, Theme.surface, z + 12, 4, trans)
                        strokeRect(valBoxX, valBoxY, boxW, 16, Theme.accent, z + 13, 4, trans)
                    end
                    txt(isFocusedSlider and valStr or (valStr .. tostring(item.suffix or "")), valBoxX + boxW / 2, rowY + 9, Theme.text, 12, FontUI, z + 14, true, false, boxW - 4, trans)
                    if isFocusedSlider then
                        txt("|", valBoxX + boxW / 2 + textWidth(valStr, 12, FontUI) / 2, rowY + 9, Theme.text, 12, FontUI, z + 15, true, false, nil, trans * clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
                    end
 
                    if click and hoveredVal and trans > 0.5 then
                        ProjectState.focus = item
                        item._directValue = tostring(item.value)
                        click = false
                    end
                    
                    local sx, sw = rowX + 4, rowW - 8
                    local sy_bar = rowY + 22
                    local denom = max(0.0001, (item.max or 100) - (item.min or 0))
                    local frac = clamp(((item.value or 0) - (item.min or 0)) / denom, 0, 1)
                    
                    rect(sx, sy_bar, sw, 4, Theme.surface3, z + 12, 2, trans)
                    if frac > 0 then
                        rect(sx, sy_bar, sw * frac, 4, Theme.accent, z + 13, 2, trans)
                    end
                    
                    item._animatedRadius = item._animatedRadius or 5
                    item._animatedRadius = smoothValue(item._animatedRadius, (hoveredVal or (over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled)) and 7 or 5, 18)
                    circle(sx + sw * frac, sy_bar + 2, item._animatedRadius, C3(190, 190, 190), z + 14, true, 0, 32, trans)
                    
                    if click and over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled and not hoveredVal and trans > 0.5 then
                        ProjectState.sliderDrag = item
                        click = false
                    end
                    if held and not popupBlocking and not disabled and (ProjectState.sliderDrag == item) then
                        local snapped = snapValue((item.min or 0) + denom * clamp((ProjectState.mouseX - sx) / sw, 0, 1), item)
                        if snapped ~= item.value then
                            item.value = snapped
                            safeCallback(item.callback, snapped)
                        end
                    end
                    
                elseif item.type == "dropdown" then
                    txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 20, trans)
                    
                    local dx, dw = rowX + 4, rowW - 8
                    local dy_box = rowY + 18
                    local boxH = 22
                    
                    rect(dx, dy_box, dw, boxH, over(dx, dy_box, dw, boxH) and Theme.surface3 or Theme.surface2, z + 12, 4, trans)
                    strokeRect(dx, dy_box, dw, boxH, Theme.border, z + 13, 4, trans)
                    
                    txt(item.multi and (#item.value > 0 and concat(item.value, ", ") or "-") or (item.value[1] or "-"), dx + 8, textTop(dy_box, boxH, 13), Theme.text, 13, FontSystem, z + 14, false, false, dw - 28, trans)
                    
                    if ProjectState.dropdown and ProjectState.dropdown.item == item then
                        drawChevronUp(dx + dw - 15, centerY(dy_box, boxH) - 2, Theme.sub, z + 15, trans)
                    else
                        drawChevronDown(dx + dw - 15, centerY(dy_box, boxH) - 2, Theme.sub, z + 15, trans)
                    end
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 2, 12, 12)
                        txt("?", rowX + rowW - 10, rowY + 2, qHovered and Theme.accent or Theme.sub, 13, FontSystem, z + 12, false, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
                        end
                    end
                    
                    if click and over(dx, dy_box, dw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
                        dDropdown("item", dx, dy_box + boxH, dw, item.choices, item.value, item.multi, item.callback, item, nil)
                        click = false
                    end
                    
                elseif item.type == "button" then
                    local controlY = rowY + 2
                    item._hoverFactor = smoothValue(item._hoverFactor or 0, (over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled) and 1 or 0, 18)
                    
                    rect(rowX + 4, controlY, rowW - 8, itemH - 4, Theme.accent, z + 12, 6, trans * (0.1 + 0.15 * item._hoverFactor))
                    strokeRect(rowX + 4, controlY, rowW - 8, itemH - 4, Theme.accent, z + 13, 6, trans * (0.4 + 0.6 * item._hoverFactor))
                    
                    txt(item.label, rowX + rowW / 2, centerY(controlY, itemH - 4), Theme.accent, 13, FontBold, z + 14, true, false, rowW - 24, trans)
                    
                    if click and over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled and trans > 0.5 then
                        safeCallback(item.callback)
                        click = false
                    end
                    
                elseif item.type == "textbox" then
                    txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 20, trans)
                    
                    local bx, bw = rowX + 4, rowW - 8
                    local dy_box = rowY + 18
                    local boxH = 22
                    local focused = ProjectState.focus == item
                    
                    rect(bx, dy_box, bw, boxH, focused and Theme.surface or over(bx, dy_box, bw, boxH) and Theme.surface3 or Theme.surface2, z + 12, 4, trans)
                    strokeRect(bx, dy_box, bw, boxH, focused and Theme.accent or Theme.border, z + 13, 4, trans)
                    
                    local is_empty = item.value == ""
                    local textTrans = (focused and is_empty) and trans * 0.2 or trans
                    txt(is_empty and item.label or item.value, bx + 8, textTop(dy_box, boxH, 13), is_empty and Theme.sub or Theme.text, 13, FontUI, z + 14, false, false, bw - 16, textTrans)
                    if focused then
                        if item._selectedAll and not is_empty then
                            rect(bx + 8, dy_box + 3, math.min(bw - 16, textWidth(item.value, 13, FontUI)), boxH - 6, Theme.accent, z + 13, 2, trans * 0.4)
                        end
                        local cursorX = bx + 8
                        if not is_empty then
                            cursorX = cursorX + textWidth(item.value, 13, FontUI)
                        end
                        txt("|", cursorX, textTop(dy_box, boxH, 13), Theme.text, 13, FontUI, z + 15, false, false, nil, trans * clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
                    end
                    
                    if click and over(bx, dy_box, bw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
                        ProjectState.focus = focused and nil or item
                        click = false
                    end
                    
                elseif item.type == "divider" then
                    if item.label and item.label ~= "" then
                        local textW = textWidth(item.label, 11, FontSystem)
                        local lineW = max(4, (rowW - textW - 16) / 2)
                        local lineY = centerY(rowY, itemH)
                        rect(rowX, lineY, lineW, 1, Theme.border, z + 12, 1, trans)
                        txt(item.label, rowX + lineW + 8, textTop(rowY, itemH, 11), Theme.sub, 11, FontSystem, z + 13, false, false, textW + 4, trans)
                        rect(rowX + lineW + textW + 16, lineY, lineW, 1, Theme.border, z + 12, 1, trans)
                    else
                        rect(rowX, centerY(rowY, itemH), rowW, 1, Theme.border, z + 12, 1, trans)
                    end
                end
            end
            
            rowY = rowY + itemH
        end
    end
    
    return click, held, rightClick
end

local function renderSections(tab, click, held, rightClick, px, contY, pw, contH)
    if not tab then
        return click, held, rightClick
    end

    local sectionsToRender = tab.sections

    local leftSecs = {}
    local rightSecs = {}
    for si = 1, #sectionsToRender do
        local section = sectionsToRender[si]
        if section.side == "Right" then
            rightSecs[#rightSecs + 1] = section
        else
            leftSecs[#leftSecs + 1] = section
        end
    end

    local leftTotal = 0
    for i = 1, #leftSecs do
        local sec = leftSecs[i]
        local colW = (sec.side == "Full") and pw or floor((pw - 10) / 2)
        local rowW = colW - 24
        local secH = sec.customHeight or 28
        if not sec.customHeight then
            for ii = 1, #sec.items do
                secH = secH + getItemHeight(sec.items[ii], rowW)
            end
            secH = secH + 6
        end
        sec.calculatedHeight = secH
        leftTotal = leftTotal + secH + 10
    end

    local rightTotal = 0
    for i = 1, #rightSecs do
        local sec = rightSecs[i]
        local colW = (sec.side == "Full") and pw or floor((pw - 10) / 2)
        local rowW = colW - 24
        local secH = sec.customHeight or 28
        if not sec.customHeight then
            for ii = 1, #sec.items do
                secH = secH + getItemHeight(sec.items[ii], rowW)
            end
            secH = secH + 6
        end
        sec.calculatedHeight = secH
        rightTotal = rightTotal + secH + 10
    end

    local contentH = max(leftTotal, rightTotal)
    local viewH = max(1, contH - CONTENT_PAD * 2)
    tab.maxScroll = max(0, contentH - viewH)
    tab.scrollY = tab.scrollY or 0
    tab.targetScrollY = clamp(tab.targetScrollY or tab.scrollY, 0, tab.maxScroll)
    local popupBlocking = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil

    if tab.maxScroll > 0 and not popupBlocking then
        if ProjectState.mouseScroll ~= 0 and over(ProjectState.x, ProjectState.y, ProjectState.w, ProjectState.h) then
            tab.targetScrollY = clamp(tab.targetScrollY - (ProjectState.mouseScroll > 0 and 1 or -1) * 28, 0, tab.maxScroll)
        end
        if not ProjectState.focus then
            if Input.up.held then
                tab.targetScrollY = max(0, tab.targetScrollY - 12)
            end
            if Input.down.held then
                tab.targetScrollY = min(tab.maxScroll, tab.targetScrollY + 12)
            end
            if Input.pageup.click then
                tab.targetScrollY = max(0, tab.targetScrollY - viewH)
            end
            if Input.pagedown.click then
                tab.targetScrollY = min(tab.maxScroll, tab.targetScrollY + viewH)
            end
            if Input.home.click then
                tab.targetScrollY = 0
            end
            if Input["end"].click then
                tab.targetScrollY = tab.maxScroll
            end
        end
    end

    local dtValue = ProjectState.dt or 1/60
    if dtValue <= 0 then dtValue = 1/60 end
    local factor = 1 - math.exp(-15 * dtValue)
    tab.scrollY = tab.scrollY + (tab.targetScrollY - tab.scrollY) * factor
    tab.scrollY = clamp(tab.scrollY, 0, tab.maxScroll)

    local sy = contY + CONTENT_PAD - tab.scrollY
    local clipTop = contY + 4
    local clipBottom = contY + contH - 4
    local colW = floor((pw - 10) / 2)
    local leftX = px
    local rightX = px + colW + 10

    local dragSec = ProjectState.draggedSection
    if held and dragSec then
        local dragIdx = nil
        for idx, sec in ipairs(tab.sections) do
            if sec == dragSec then
                dragIdx = idx
                break
            end
        end
        if dragIdx then
            if dragIdx > 1 then
                local prevSec = tab.sections[dragIdx - 1]
                if not prevSec.locked and not dragSec.locked and ProjectState.mouseY < (prevSec.lastRenderY or 0) + (prevSec.calculatedHeight or 0) / 2 then
                    tab.sections[dragIdx], tab.sections[dragIdx - 1] = tab.sections[dragIdx - 1], tab.sections[dragIdx]
                end
            end
            if dragIdx < #tab.sections then
                local nextSec = tab.sections[dragIdx + 1]
                if not nextSec.locked and not dragSec.locked and ProjectState.mouseY > (nextSec.lastRenderY or 0) + (nextSec.calculatedHeight or 0) / 2 then
                    tab.sections[dragIdx], tab.sections[dragIdx + 1] = tab.sections[dragIdx + 1], tab.sections[dragIdx]
                end
            end

            if abs(ProjectState.mouseX - ProjectState.dragStartMouseX) > 40 then
                local mouseFrac = (ProjectState.mouseX - px) / pw
                if mouseFrac < 0.35 then
                    dragSec.side = "Left"
                elseif mouseFrac > 0.65 then
                    dragSec.side = "Right"
                else
                    dragSec.side = "Full"
                end
            else
                dragSec.side = ProjectState.draggedSectionOriginalSide
            end
        end
    else
        ProjectState.draggedSection = nil
    end

    if held and ProjectState.resizeSection then
        local dy = ProjectState.mouseY - ProjectState.resizeSectionStartMouseY
        local newH = max(40, ProjectState.resizeSectionStartH + dy)
        
        if ProjectState.gridLocking ~= false then
            local resizeSec = ProjectState.resizeSection
            local resizeBottom = (resizeSec.lastRenderY or 0) + newH
            ProjectState.gridSnapLines = {}
            
            for i = 1, #sectionsToRender do
                local otherSec = sectionsToRender[i]
                if otherSec ~= resizeSec then
                    local otherBottom = (otherSec.lastRenderY or 0) + (otherSec.calculatedHeight or 0)
                    if abs(resizeBottom - otherBottom) < 10 then
                        newH = otherBottom - (resizeSec.lastRenderY or 0)
                        ProjectState.gridSnapLines[#ProjectState.gridSnapLines + 1] = otherBottom
                    end
                end
            end
        end
        
        ProjectState.resizeSection.customHeight = newH
    else
        ProjectState.resizeSection = nil
        ProjectState.gridSnapLines = nil
    end

    local leftY = sy
    local rightY = sy

    for i = 1, #sectionsToRender do
        local section = sectionsToRender[i]
        local secH = section.calculatedHeight

        local targetLocalX, targetLocalY, targetLocalW
        if section.side == "Full" then
            targetLocalX = 0
            targetLocalY = max(leftY, rightY) - sy
            targetLocalW = pw
            leftY = max(leftY, rightY) + secH + 10
            rightY = leftY
        elseif section.side == "Right" then
            targetLocalX = colW + 10
            targetLocalY = rightY - sy
            targetLocalW = colW
            rightY = rightY + secH + 10
        else
            targetLocalX = 0
            targetLocalY = leftY - sy
            targetLocalW = colW
            leftY = leftY + secH + 10
        end

        if not section.currentX then section.currentX = targetLocalX end
        if not section.currentY then section.currentY = targetLocalY end
        if not section.currentW then section.currentW = targetLocalW end

        section.currentX = smoothValue(section.currentX, targetLocalX, 16)
        section.currentY = smoothValue(section.currentY, targetLocalY, 16)
        section.currentW = smoothValue(section.currentW, targetLocalW, 16)

        section.lastRenderY = sy + section.currentY

        click, held, rightClick = renderSectionCard(section, px + section.currentX, sy + section.currentY, section.currentW, secH, clipTop, clipBottom, click, held, rightClick, dragSec == section, false)
    end

    if dragSec then
        renderSectionCard(
            dragSec,
            ProjectState.mouseX - ProjectState.dragOffset[1],
            ProjectState.mouseY - ProjectState.dragOffset[2],
            (dragSec.side == "Full") and pw or colW,
            dragSec.calculatedHeight,
            clipTop,
            clipBottom,
            false,
            false,
            false,
            false,
            true
        )
    end

    if ProjectState.gridSnapLines then
        for i = 1, #ProjectState.gridSnapLines do
            local snapY = ProjectState.gridSnapLines[i]
            if snapY > clipTop and snapY < clipBottom then
                line(px, snapY, px + pw, snapY, Theme.accent, 60, 1, 0.6)
            end
        end
    end

    if tab.maxScroll > 0 then
        local trackH = contH - CONTENT_PAD * 2 - 12
        local barH = max(22, (trackH / max(contentH, trackH)) * trackH)
        local barY = contY + CONTENT_PAD + 6 + (tab.scrollY / max(1, tab.maxScroll)) * (trackH - barH)
        local scrollBarX = ProjectState.x + ProjectState.w - 12
        rect(scrollBarX, contY + CONTENT_PAD + 6, 3, trackH, Theme.surface3, 50, 2, ProjectState.contentFade)
        rect(scrollBarX, barY, 3, barH, Theme.accent, 51, 2, ProjectState.contentFade)
        if click and over(scrollBarX - 5, contY + CONTENT_PAD + 6, 14, trackH) and not popupBlocking then
            local grab = barH / 2
            if over(scrollBarX - 5, barY, 14, barH) then
                grab = clamp(ProjectState.mouseY - barY, 0, barH)
            end
            ProjectState.scrollDrag = {
                tab = tab,
                grab = grab,
            }
            click = false
        end
        local drag = ProjectState.scrollDrag
        if held and type(drag) == "table" and drag.tab == tab then
            tab.targetScrollY = clamp((ProjectState.mouseY - (contY + CONTENT_PAD + 6) - drag.grab) / max(1, trackH - barH), 0, 1) * tab.maxScroll
        end
    elseif type(ProjectState.scrollDrag) == "table" and ProjectState.scrollDrag.tab == tab then
        ProjectState.scrollDrag = nil
    end

    return click, held, rightClick
end

local function serializeConfigData()
    local configData = {}
    for _, t in ipairs(ProjectState.tabs) do
        for _, s in ipairs(t.sections) do
            for _, item in ipairs(s.items) do
                if item.type ~= "divider" and item.type ~= "label" and item.type ~= "button" then
                    local key = t.name .. "." .. s.name .. "." .. item.label
                    local data
                    if item.type == "colorpicker" then
                        data = { value = toHex(item.value), alpha = item.alpha }
                    else
                        data = { value = item.value }
                    end
                    if item.keybind then
                        data.keybind = { value = item.keybind.value, mode = item.keybind.mode }
                    end
                    if item.colorpicker then
                        data.colorpicker = { value = toHex(item.colorpicker.value), alpha = item.colorpicker.alpha }
                    end
                    configData[key] = data
                end
            end
        end
    end
    return configData
end

local function saveConfig()
    pcall(makefolder, "homesick")
    local _, json = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), serializeConfigData())
    if json and json ~= "" then
        pcall(writefile, "homesick/config.json", json)
    end
end

local function loadConfig(json)
    if not json then
        local ok, raw = pcall(readfile, "homesick/config.json")
        if ok and raw then
            json = raw
        end
    end
    if not json or json == "" then return end
    local decodeOk, configData = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), json)
    if decodeOk and decodeOk == true and type(configData) == "table" then
        for _, t in ipairs(ProjectState.tabs) do
            for _, s in ipairs(t.sections) do
                for _, item in ipairs(s.items) do
                    local key = t.name .. "." .. s.name .. "." .. item.label
                    local data = configData[key]
                    if data then
                        if item.type == "colorpicker" then
                            pcall(function()
                                item.value = C3HEX("#" .. tostring(data.value or "FFFFFF"))
                                item.alpha = data.alpha or 1
                                safeCallback(item.callback, item.value, item.alpha)
                            end)
                        elseif item.type == "dropdown" then
                            local loadedVal = data.value
                            if type(loadedVal) ~= "table" then
                                loadedVal = loadedVal ~= nil and {loadedVal} or {}
                            end
                            setDropdownValue(item, loadedVal, true)
                        else
                            setItemValue(item, data.value, true)
                        end
                        if data.keybind and item.keybind then
                            item.keybind.value = normalizeKey(data.keybind.value)
                            item.keybind.mode = normalizeMode(data.keybind.mode)
                            safeCallback(item.keybind.callback, item.keybind.value and Input[item.keybind.value] and Input[item.keybind.value].id or nil, item.keybind.mode)
                        end
                        if data.colorpicker and item.colorpicker then
                            pcall(function()
                                item.colorpicker.value = C3HEX("#" .. tostring(data.colorpicker.value or "FFFFFF"))
                                item.colorpicker.alpha = data.colorpicker.alpha or 1
                                safeCallback(item.colorpicker.callback, item.colorpicker.value, item.colorpicker.alpha)
                            end)
                        end
                    end
                end
            end
        end
    end
end

exportConfig = function()
    local json = select(2, pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), serializeConfigData()))
    if json and json ~= "" then
        return "homesickCfg_" .. base64encode(json)
    end
    return ""
end

importConfig = function(str)
    if not str or string.sub(str, 1, 12) ~= "homesickCfg_" then return end
    local ok, json = pcall(base64decode, string.sub(str, 13))
    if ok and ok == ok and json and json ~= "" then
        loadConfig(json)
    end
end

local function saveTheme()
    pcall(makefolder, "homesick")
    local themeData = {}
    for k, v in pairs(Theme) do
        themeData[k] = toHex(v)
    end
    local _, json = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), themeData)
    if json and json ~= "" then
        pcall(writefile, "homesick/theme.json", json)
    end
end

local function loadTheme(json)
    if not json then
        local ok, raw = pcall(readfile, "homesick/theme.json")
        if ok and raw then
            json = raw
        end
    end
    if not json or json == "" then return end
    local decodeOk, themeData = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), json)
    if decodeOk and decodeOk == true and type(themeData) == "table" then
        for k, v in pairs(themeData) do
            if Theme[k] ~= nil then
                Theme[k] = C3HEX("#" .. v)
                if ProjectState.themeColorPickers and ProjectState.themeColorPickers[k] then
                    ProjectState.themeColorPickers[k]:Set(Theme[k])
                end
            end
        end
    end
end

exportTheme = function()
    local themeData = {}
    for k, v in pairs(Theme) do
        themeData[k] = toHex(v)
    end
    local json = select(2, pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), themeData))
    if json and json ~= "" then
        return "homesickTheme_" .. base64encode(json)
    end
    return ""
end

importTheme = function(str)
    if not str or string.sub(str, 1, 14) ~= "homesickTheme_" then return end
    local ok, json = pcall(base64decode, string.sub(str, 15))
    if ok and ok == ok and json and json ~= "" then
        loadTheme(json)
    end
end

local function getScriptsList()
    local list = {}
    if type(listfiles) == "function" then
        local files = listfiles(".")
        if files and #files > 0 then
            for i = 1, #files do
                local file = files[i]
                if file and file ~= "" and string.sub(file, -4) == ".lua" then
                    local name = file
                    if string.find(name, "[\\/]") then
                        name = string.match(name, "[^\\/]+$")
                    end
                    name = string.sub(name, 1, -5)
                    list[#list + 1] = name
                end
            end
        end
    end
    return list
end

local function getConfigsList()
    local list = {}
    pcall(makefolder, "homesick")
    if type(listfiles) == "function" then
        local files = listfiles("homesick")
        if files and #files > 0 then
            for i = 1, #files do
                local file = files[i]
                if file and file ~= "" and string.sub(file, -5) == ".json" then
                    local name = file
                    if string.find(name, "[\\/]") then
                        name = string.match(name, "[^\\/]+$")
                    end
                    name = string.sub(name, 1, -6)
                    if name ~= "theme" then
                        list[#list + 1] = name
                    end
                end
            end
        end
    end
    return list
end

local function getThemesList()
    local list = {}
    pcall(makefolder, "homesick/themes")
    if type(listfiles) == "function" then
        local files = listfiles("homesick/themes")
        if files and #files > 0 then
            for i = 1, #files do
                local file = files[i]
                if file and file ~= "" and string.sub(file, -5) == ".json" then
                    local name = file
                    if string.find(name, "[\\/]") then
                        name = string.match(name, "[^\\/]+$")
                    end
                    name = string.sub(name, 1, -6)
                    list[#list + 1] = name
                end
                local dummy = i or i
            end
        end
    end
    return list
end

local function initSettings()
    local settingsTab = {
        name = "Settings",
        sections = {},
        scrollY = 0,
        targetScrollY = 0,
        maxScroll = 0,
    }
    ProjectState.settingsTab = settingsTab
 
    local configSection = createSection(settingsTab, "Configs", "Left")
    local configDropdown = configSection:Dropdown("Config List", getConfigsList(), getConfigsList())
    configDropdown:Set("")
    
    configDropdown.item.deletable = true
    configDropdown.item.onDelete = function(name)
        if name and name ~= "" then
            pcall(delfile, "homesick/" .. name .. ".json")
            configDropdown:UpdateChoices(getConfigsList())
            configDropdown:Set({})
            if warn then warn("deleted config " .. name) end
        end
    end
    
    local configNameBox = configSection:Textbox("Config Name", "")
    configNameBox:Set("")

    configSection:Button("Load", function()
        local name = configNameBox.item.value
        if name == "" then
            name = configDropdown.item.value[1]
        end
        if name and name ~= "" then
            local ok, raw = pcall(readfile, "homesick/" .. name .. ".json")
            if ok and ok == ok and raw then
                loadConfig(raw)
            end
        end
    end)
    configSection:Button("Save", function()
        local name = configNameBox.item.value
        if name == "" then
            name = configDropdown.item.value[1]
        end
        if name and name ~= "" then
            local json = select(2, pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), serializeConfigData()))
            if json and json ~= "" then
                pcall(writefile, "homesick/" .. name .. ".json", json)
                configDropdown:UpdateChoices(getConfigsList())
            end
        end
    end)

    local themeSection = createSection(settingsTab, "Themes", "Right")
    local themeDropdown = themeSection:Dropdown("Theme List", getThemesList(), getThemesList())
    themeDropdown:Set("")
    
    themeDropdown.item.deletable = true
    themeDropdown.item.onDelete = function(name)
        if name and name ~= "" then
            pcall(delfile, "homesick/themes/" .. name .. ".json")
            themeDropdown:UpdateChoices(getThemesList())
            themeDropdown:Set({})
            if warn then warn("deleted theme " .. name) end
        end
    end
    
    local themeNameBox = themeSection:Textbox("Theme Name", "")
    themeNameBox:Set("")

    themeSection:Button("Load", function()
        local name = themeNameBox.item.value
        if name == "" then
            name = themeDropdown.item.value[1]
        end
        if name and name ~= "" then
            local ok, raw = pcall(readfile, "homesick/themes/" .. name .. ".json")
            if ok and ok == ok and raw then
                loadTheme(raw)
            end
        end
    end)
    themeSection:Button("Save", function()
        local name = themeNameBox.item.value
        if name == "" then
            name = themeDropdown.item.value[1]
        end
        if name and name ~= "" then
            local themeData = {}
            for k, v in pairs(Theme) do
                themeData[k] = toHex(v)
            end
            local json = select(2, pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), themeData))
            if json and json ~= "" then
                pcall(writefile, "homesick/themes/" .. name .. ".json", json)
                themeDropdown:UpdateChoices(getThemesList())
            end
        end
    end)

    local generalSec = createSection(settingsTab, "General Settings", "Full")
    generalSec:Checkbox("Spoof window focus", false, function(val)
        ProjectState.isrbxactiveOverride = val
    end)
    generalSec:Checkbox("Tab Animations", true, function(val)
        ProjectState.tabAnimations = val
    end)
    generalSec:Checkbox("Grid Locking", true, function(val)
        ProjectState.gridLocking = val
    end)
    generalSec:Checkbox("Checkbox Animations", true, function(val)
        ProjectState.hoverEffects = val
    end)

    local colorsSec = createSection(settingsTab, "Theme Colors", "Full")
    colorsSec:Label("Customize UI theme colors below:")
    ProjectState.themeColorPickers = {}
    local pickers = {"accent", "bg", "surface", "surface2", "surface3", "text", "sub", "border"}
    for idx = 1, #pickers do
        local name = pickers[idx]
        ProjectState.themeColorPickers[name] = colorsSec:Colorpicker(
            name == "accent" and "Accent" or
            name == "bg" and "Background" or
            name == "surface" and "Surface 1" or
            name == "surface2" and "Surface 2" or
            name == "surface3" and "Surface 3" or
            name == "text" and "Text" or
            name == "sub" and "Sub Text" or
            "Border",
            Theme[name],
            true,
            function(color)
                Theme[name] = color
            end
        )
        local dummy = idx or idx
    end
end

local function renderSearchFeature(item, rowX, rowY, rowW, click, held, rightClick, clipTop, clipBottom)
    local z = 40
    local disabled = isItemDisabled(item)
    local trans = (disabled and 0.4 or 1) * min(clamp((rowY - clipTop) / 16, 0, 1), clamp((clipBottom - (rowY + getItemHeight(item, rowW))) / 16, 0, 1))
    if trans <= 0 then
        return click, held, rightClick
    end
    
    local itemH = getItemHeight(item, rowW)
    local popupBlocking = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil
    
    if item.type == "checkbox" then
        local targetAnim = item.value and 1 or 0
        if ProjectState.hoverEffects == false then
            item.animState = targetAnim
        else
            item.animState = smoothValue(item.animState or targetAnim, targetAnim, 18)
        end
        rect(rowX + 4, rowY + 6, 14, 14, Theme.surface3, z + 12, 4, trans)
        strokeRect(rowX + 4, rowY + 6, 14, 14, Theme.border, z + 13, 4, trans)
        
        if item.animState > 0.05 then
            local offset = 7 * (1 - item.animState)
            rect(rowX + 4 + offset, rowY + 6 + offset, 14 * item.animState, 14 * item.animState, Theme.accent, z + 14, 4 * item.animState, trans)
        end
        
        txt(item.label, rowX + 26, textTop(rowY, itemH - 2, 13), item.unsafe and Theme.unsafe or (item.value and Theme.text or Theme.sub), 13, FontSystem, z + 12, false, false, rowW - 26 - (6 + (item.colorpicker and 20 or 0) + (item.keybind and 64 or 0) + (item.tooltip and 18 or 0)), trans)
        
        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
        
        if item.tooltip then
            txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), over(rowX + rowW - 16, rowY + 6, 12, 12) and Theme.accent or Theme.sub, 13, FontSystem, z + 12, false, false, nil, trans)
            if over(rowX + rowW - 16, rowY + 6, 12, 12) and not disabled then
                tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
            end
        end
        
        if click and over(rowX, rowY, rowW, itemH) and not popupBlocking and not disabled and trans > 0.5 then
            if not (item.keybind and over(rowX + rowW - 96, rowY + 3, 46, 20)) and not (item.colorpicker and over(rowX + rowW - 127, rowY + 5, 18, 18)) and not (item.tooltip and over(rowX + rowW - 16, rowY + 6, 12, 12)) then
                setItemValue(item, not item.value, true)
                click = false
            end
        end
        
    elseif item.type == "toggle" then
        item.animState = smoothValue(item.animState or (item.value and 1 or 0), item.value and 1 or 0, 18)
        rect(rowX + 4, rowY + 7, 24, 12, lerpColor(Theme.surface3, Theme.accent, item.animState), z + 12, 6, trans)
        strokeRect(rowX + 4, rowY + 7, 24, 12, lerpColor(Theme.border, Theme.accent, item.animState), z + 13, 6, trans)
        circle(rowX + 10 + 12 * item.animState, rowY + 13, 4, Theme.text, z + 14, true, 0, 32, trans)
        
        txt(item.label, rowX + 36, textTop(rowY, itemH - 2, 13), item.unsafe and Theme.unsafe or (item.value and Theme.text or Theme.sub), 13, FontSystem, z + 12, false, false, rowW - 36 - (6 + (item.colorpicker and 20 or 0) + (item.keybind and 64 or 0) + (item.tooltip and 18 or 0)), trans)
        
        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
        
        if item.tooltip then
            txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), over(rowX + rowW - 16, rowY + 6, 12, 12) and Theme.accent or Theme.sub, 13, FontSystem, z + 12, false, false, nil, trans)
            if over(rowX + rowW - 16, rowY + 6, 12, 12) and not disabled then
                tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
            end
        end
        
        if click and over(rowX, rowY, rowW, itemH) and not popupBlocking and not disabled and trans > 0.5 then
            if not (item.keybind and over(rowX + rowW - 96, rowY + 3, 46, 20)) and not (item.colorpicker and over(rowX + rowW - 127, rowY + 5, 18, 18)) and not (item.tooltip and over(rowX + rowW - 16, rowY + 6, 12, 12)) then
                setItemValue(item, not item.value, true)
                click = false
            end
        end
        
    elseif item.type == "colorpicker" then
        txt(item.label, rowX + 4, textTop(rowY, itemH - 2, 13), Theme.text, 13, FontSystem, z + 12, false, false, rowW - 28, trans)
        local cpX = rowX + rowW - 16
        local hovered = over(cpX - 3, rowY + 5, 18, 18)
        rect(cpX, rowY + 8, 12, 12, item.value, z + 12, 3, trans * (item.alpha or 1))
        strokeRect(cpX, rowY + 8, 12, 12, Theme.border, z + 13, 3, trans)
        if hovered then
            strokeRect(cpX - 2, rowY + 6, 16, 16, Theme.accent, z + 14, 4, trans)
        end
        if click and hovered and not popupBlocking and not disabled and trans > 0.5 then
            doColorPicker(ProjectState.mouseX + 14, ProjectState.mouseY - 90, item)
            click = false
        elseif rightClick and hovered and not popupBlocking and not disabled and trans > 0.5 then
            dDropdown("colorctx", cpX - 34, rowY + 24, 80, {"Copy", "Paste"}, {}, false, function(choice)
                if choice and choice[1] == "Copy" then
                    ProjectState.copiedColor = item.value
                    pcall(setclipboard, "#" .. toHex(item.value))
                elseif choice and choice[1] == "Paste" then
                    if ProjectState.copiedColor and colorChanged(item.value, ProjectState.copiedColor) then
                        item.value = ProjectState.copiedColor
                        safeCallback(item.callback, item.value)
                    else
                        warn("color clipboard empty lol")
                    end
                end
            end, nil, nil)
            rightClick = false
        end

    elseif item.type == "slider" then
        txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 80, trans)
        
        local isFocusedSlider = ProjectState.focus == item
        local valStr = isFocusedSlider and (item._directValue or "") or tostring(item.value)
        local boxW = max(36, textWidth(isFocusedSlider and valStr or (valStr .. tostring(item.suffix or "")), 12, FontUI) + 12)
        local valBoxX = rowX + rowW - boxW - 4
        local hoveredVal = over(valBoxX, rowY + 1, boxW, 16) and not popupBlocking and not disabled
        
        if isFocusedSlider then
            rect(valBoxX, rowY + 1, boxW, 16, Theme.surface, z + 12, 4, trans)
            strokeRect(valBoxX, rowY + 1, boxW, 16, Theme.accent, z + 13, 4, trans)
        end
        txt(isFocusedSlider and valStr or (valStr .. tostring(item.suffix or "")), valBoxX + boxW / 2, rowY + 9, Theme.text, 12, FontUI, z + 14, true, false, boxW - 4, trans)
        if isFocusedSlider then
            txt("|", valBoxX + boxW / 2 + textWidth(valStr, 12, FontUI) / 2, rowY + 9, Theme.text, 12, FontUI, z + 15, true, false, nil, trans * clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
        end

        if click and hoveredVal and trans > 0.5 then
            ProjectState.focus = item
            item._directValue = tostring(item.value)
            click = false
        end
        
        local sx, sw = rowX + 4, rowW - 8
        local sy_bar = rowY + 22
        local frac = clamp(((item.value or 0) - (item.min or 0)) / max(0.0001, (item.max or 100) - (item.min or 0)), 0, 1)
        
        rect(sx, sy_bar, sw, 4, Theme.surface3, z + 12, 2, trans)
        if frac > 0 then
            rect(sx, sy_bar, sw * frac, 4, Theme.accent, z + 13, 2, trans)
        end
        
        item._animatedRadius = item._animatedRadius or 5
        item._animatedRadius = smoothValue(item._animatedRadius, (hoveredVal or (over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled)) and 7 or 5, 18)
        circle(sx + sw * frac, sy_bar + 2, item._animatedRadius, C3(190, 190, 190), z + 14, true, 0, 32, trans)
        
        if click and over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled and not hoveredVal and trans > 0.5 then
            ProjectState.sliderDrag = item
            click = false
        end
        if held and not popupBlocking and not disabled and (ProjectState.sliderDrag == item) then
            local snapped = snapValue((item.min or 0) + max(0.0001, (item.max or 100) - (item.min or 0)) * clamp((ProjectState.mouseX - sx) / sw, 0, 1), item)
            if snapped ~= item.value then
                item.value = snapped
                safeCallback(item.callback, snapped)
            end
        end
        
    elseif item.type == "dropdown" then
        txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 20, trans)
        
        local dx, dw = rowX + 4, rowW - 8
        local dy_box = rowY + 18
        local boxH = 22
        
        rect(dx, dy_box, dw, boxH, over(dx, dy_box, dw, boxH) and Theme.surface3 or Theme.surface2, z + 12, 4, trans)
        strokeRect(dx, dy_box, dw, boxH, Theme.border, z + 13, 4, trans)
        
        txt(item.multi and (#item.value > 0 and concat(item.value, ", ") or "-") or (item.value[1] or "-"), dx + 8, textTop(dy_box, boxH, 13), Theme.text, 13, FontSystem, z + 14, false, false, dw - 28, trans)
        
        if ProjectState.dropdown and ProjectState.dropdown.item == item then
            drawChevronUp(dx + dw - 15, centerY(dy_box, boxH) - 2, Theme.sub, z + 15, trans)
        else
            drawChevronDown(dx + dw - 15, centerY(dy_box, boxH) - 2, Theme.sub, z + 15, trans)
        end
        
        if item.tooltip then
            txt("?", rowX + rowW - 10, rowY + 2, over(rowX + rowW - 16, rowY + 2, 12, 12) and Theme.accent or Theme.sub, 13, FontSystem, z + 12, false, false, nil, trans)
            if over(rowX + rowW - 16, rowY + 2, 12, 12) and not disabled then
                tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
            end
        end
        
        if click and over(dx, dy_box, dw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
            dDropdown("item", dx, dy_box + boxH, dw, item.choices, item.value, item.multi, item.callback, item, nil)
            click = false
        end
        
    elseif item.type == "button" then
        local controlY = rowY + 2
        item._hoverFactor = smoothValue(item._hoverFactor or 0, (over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled) and 1 or 0, 18)
        
        rect(rowX + 4, controlY, rowW - 8, itemH - 4, Theme.accent, z + 12, 6, trans * (0.1 + 0.15 * item._hoverFactor))
        strokeRect(rowX + 4, controlY, rowW - 8, itemH - 4, Theme.accent, z + 13, 6, trans * (0.4 + 0.6 * item._hoverFactor))
        
        txt(item.label, rowX + rowW / 2, centerY(controlY, itemH - 4), Theme.accent, 13, FontBold, z + 14, true, false, rowW - 24, trans)
        
        if click and over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled and trans > 0.5 then
            safeCallback(item.callback)
            click = false
        end
        
    elseif item.type == "textbox" then
        txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 20, trans)
        
        local bx, bw = rowX + 4, rowW - 8
        local dy_box = rowY + 18
        local boxH = 22
        local focused = ProjectState.focus == item
        
        rect(bx, dy_box, bw, boxH, focused and Theme.surface or over(bx, dy_box, bw, boxH) and Theme.surface3 or Theme.surface2, z + 12, 4, trans)
        strokeRect(bx, dy_box, bw, boxH, focused and Theme.accent or Theme.border, z + 13, 4, trans)
        
        txt((item.value == "") and item.label or item.value, bx + 8, textTop(dy_box, boxH, 13), (item.value == "") and Theme.sub or Theme.text, 13, FontUI, z + 14, false, false, bw - 16, trans)
        if focused then
            if item._selectedAll and not (item.value == "") then
                rect(bx + 8, dy_box + 3, math.min(bw - 16, textWidth(item.value, 13, FontUI)), boxH - 6, Theme.accent, z + 13, 2, trans * 0.4)
            end
            local cursorX = bx + 8
            if not (item.value == "") then
                cursorX = cursorX + textWidth(item.value, 13, FontUI)
            end
            txt("|", cursorX, textTop(dy_box, boxH, 13), Theme.text, 13, FontUI, z + 15, false, false, nil, trans * clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
        end
        
        if click and over(bx, dy_box, bw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
            ProjectState.focus = focused and nil or item
            click = false
        end
    end
    
    return click, held, rightClick
end

local function renderSearchResults(click, held, rightClick, px, py, pw, ph)
    local matches = {}
    for _, tab in ipairs(ProjectState.tabs) do
        for _, sec in ipairs(tab.sections) do
            for _, item in ipairs(sec.items) do
                if item.type ~= "divider" and item.type ~= "label" then
                    if string.find(string.lower(item.label or ""), string.lower(ProjectState.searchBar.value), 1, true) then
                        matches[#matches + 1] = {
                            tab = tab,
                            section = sec,
                            item = item
                        }
                    end
                end
            end
        end
    end

    local popupBlocking = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil
    
    local dummyY = py + CONTENT_PAD
    local lastTab = nil
    local lastSec = nil
    for i = 1, #matches do
        local match = matches[i]
        if match.tab ~= lastTab then
            dummyY = dummyY + 20
            lastTab = match.tab
            lastSec = nil
        end
        if match.section ~= lastSec then
            dummyY = dummyY + 18
            lastSec = match.section
        end
        dummyY = dummyY + getItemHeight(match.item, pw - 40) + 6
        if i < #matches then
            dummyY = dummyY + 6
        end
    end
    local searchContentH = dummyY - (py + CONTENT_PAD)
    
    ProjectState.searchMaxScroll = max(0, searchContentH - max(1, ph - CONTENT_PAD * 2))
    ProjectState.searchScrollY = ProjectState.searchScrollY or 0
    ProjectState.searchTargetScrollY = clamp(ProjectState.searchTargetScrollY or 0, 0, ProjectState.searchMaxScroll)
    
    if ProjectState.searchMaxScroll > 0 and not popupBlocking then
        if ProjectState.mouseScroll ~= 0 and over(ProjectState.x, ProjectState.y, ProjectState.w, ProjectState.h) then
            ProjectState.searchTargetScrollY = clamp(ProjectState.searchTargetScrollY - (ProjectState.mouseScroll > 0 and 1 or -1) * 28, 0, ProjectState.searchMaxScroll)
        end
    end
    
    local dtValue = ProjectState.dt or 1/60
    if dtValue <= 0 then dtValue = 1/60 end
    ProjectState.searchScrollY = ProjectState.searchScrollY + (ProjectState.searchTargetScrollY - ProjectState.searchScrollY) * (1 - math.exp(-15 * dtValue))
    ProjectState.searchScrollY = clamp(ProjectState.searchScrollY, 0, ProjectState.searchMaxScroll)
    
    local currentY = py + CONTENT_PAD - ProjectState.searchScrollY
    local clipTop = py + 4
    local clipBottom = py + ph - 4
    
    local lastTab = nil
    local lastSec = nil
    for i = 1, #matches do
        local match = matches[i]
        
        if match.tab ~= lastTab then
            local tabTrans = min(clamp((currentY - clipTop) / 16, 0, 1), clamp((clipBottom - (currentY + 20)) / 16, 0, 1))
            if tabTrans > 0 then
                txt(match.tab.name, px + 10, currentY, Theme.accent, 14, FontBold, 30, false, false, nil, tabTrans)
            end
            currentY = currentY + 20
            lastTab = match.tab
            lastSec = nil
        end
        
        if match.section ~= lastSec then
            local secTrans = min(clamp((currentY - clipTop) / 16, 0, 1), clamp((clipBottom - (currentY + 18)) / 16, 0, 1))
            if secTrans > 0 then
                txt(match.section.name, px + 10, currentY, Theme.sub, 12, FontBold, 30, false, false, nil, secTrans)
                
                if (px + pw - 20) > (px + 18 + textWidth(match.section.name, 12, FontBold)) then
                    for seg = 1, 20 do
                        line(
                            (px + 18 + textWidth(match.section.name, 12, FontBold)) + (seg - 1) * (((px + pw - 20) - (px + 18 + textWidth(match.section.name, 12, FontBold))) / 20),
                            currentY + 6,
                            (px + 18 + textWidth(match.section.name, 12, FontBold)) + seg * (((px + pw - 20) - (px + 18 + textWidth(match.section.name, 12, FontBold))) / 20),
                            currentY + 6,
                            Theme.border,
                            30,
                            1,
                            (1 - (seg / 20)) * secTrans
                        )
                    end
                end
            end
            currentY = currentY + 18
            lastSec = match.section
        end
        
        local itemH = getItemHeight(match.item, pw - 40)
        if min(currentY + itemH, clipBottom) - max(currentY, clipTop) > 0 then
            click, held, rightClick = renderSearchFeature(match.item, px + 10, currentY, pw - 20, click, held, rightClick, clipTop, clipBottom)
        end
        currentY = currentY + itemH + 6
        
        if i < #matches then
            local divTrans = min(clamp((currentY - clipTop) / 16, 0, 1), clamp((clipBottom - (currentY + 6)) / 16, 0, 1))
            if divTrans > 0 then
                rect(px + 10, currentY, pw - 20, 1, Theme.border, 30, 0, 0.5 * divTrans)
            end
            currentY = currentY + 6
        end
    end
    
    if ProjectState.searchMaxScroll > 0 then
        local trackH = ph - CONTENT_PAD * 2 - 12
        local barH = max(22, (trackH / max(searchContentH, trackH)) * trackH)
        local barY = py + CONTENT_PAD + 6 + (ProjectState.searchScrollY / max(1, ProjectState.searchMaxScroll)) * (trackH - barH)
        local scrollBarX = ProjectState.x + ProjectState.w - 12
        rect(scrollBarX, py + CONTENT_PAD + 6, 3, trackH, Theme.surface3, 50, 2, ProjectState.contentFade)
        rect(scrollBarX, barY, 3, barH, Theme.accent, 51, 2, ProjectState.contentFade)
        if click and over(scrollBarX - 5, py + CONTENT_PAD + 6, 14, trackH) and not popupBlocking then
            ProjectState.scrollDrag = {
                search = true,
                grab = over(scrollBarX - 5, barY, 14, barH) and clamp(ProjectState.mouseY - barY, 0, barH) or (barH / 2),
            }
            click = false
        end
        
        if held and type(ProjectState.scrollDrag) == "table" and ProjectState.scrollDrag.search then
            ProjectState.searchTargetScrollY = clamp((ProjectState.mouseY - (py + CONTENT_PAD + 6) - ProjectState.scrollDrag.grab) / max(1, trackH - barH), 0, 1) * ProjectState.searchMaxScroll
        end
    end
    
    return click, held, rightClick
end

local onlineCount = 7517 + math.random(-25, 25)
task.spawn(function()
    local ok, res = pcall(function()
        return game:HttpGet("https://api.counterapi.dev/v1/homesick/users/increment")
    end)
    if ok and res then
        local ok2, data = pcall(function()
            return game:GetService("HttpService"):JSONDecode(res)
        end)
        if ok2 and data and data.value then
            onlineCount = data.value
        end
    end
end)

local function renderWindow(click, held, rightClick)
    local x, y, w, h = ProjectState.x, ProjectState.y, ProjectState.w, ProjectState.h
    local popupOpen = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil or ProjectState.importModal ~= nil
    local baseClick = popupOpen and false or click
    local baseHeld = popupOpen and false or held
    local baseRightClick = popupOpen and false or rightClick

    for i = 1, #SHADOW_ALPHA do
        local offset = i * 2
        rect(x - offset, y - offset + 6, w + offset * 2, h + offset * 2, Theme.black, 0, 12, SHADOW_ALPHA[i])
    end

    rect(x, y, w, h, Theme.surface, 5, 12)
    strokeRect(x, y, w, h, Theme.border, 6, 12)
    rect(x + 2, y + 2, w - 4, TITLE_H - 2, Theme.surface2, 7, 10)
    rect(x + 2, y + 2 + (TITLE_H - 2) / 2, w - 4, (TITLE_H - 2) / 2, Theme.surface2, 7, 0)
    line(x + 2, y + TITLE_H, x + w - 2, y + TITLE_H, Theme.border, 8)

    local titleMidY = centerY(y, TITLE_H)

    local edgeSize = 6
    local mx, my = ProjectState.mouseX, ProjectState.mouseY
    local nearL = mx >= x - edgeSize and mx <= x + edgeSize and my >= y and my <= y + h
    local nearR = mx >= x + w - edgeSize and mx <= x + w + edgeSize and my >= y and my <= y + h
    local nearT = my >= y - edgeSize and my <= y + edgeSize and mx >= x and mx <= x + w
    local nearB = my >= y + h - edgeSize and my <= y + h + edgeSize and mx >= x and mx <= x + w

    if baseClick then
        local edge = nil
        if mx >= x + w - 15 and mx <= x + w and my >= y + h - 15 and my <= y + h then
            edge = "bottomright"
        elseif nearL and nearT then edge = "topleft"
        elseif nearR and nearT then edge = "topright"
        elseif nearL and nearB then edge = "bottomleft"
        elseif nearR and nearB then edge = "bottomright"
        elseif nearL then edge = "left"
        elseif nearR then edge = "right"
        elseif nearT then edge = "top"
        elseif nearB then edge = "bottom"
        end

        if edge then
            ProjectState.resizeEdge = edge
            ProjectState.resizeStart = {x = x, y = y, w = w, h = h, mouseX = mx, mouseY = my}
            baseClick = false
        elseif over(x, y, w, TITLE_H) then
            ProjectState.drag = {ProjectState.mouseX - x, ProjectState.mouseY - y}
            baseClick = false
        end
    end

    local drag = ProjectState.resizeEdge
    if held and drag and ProjectState.resizeStart then
        local start = ProjectState.resizeStart
        local dx = mx - start.mouseX
        local dy = my - start.mouseY
        local newX, newY, newW, newH = start.x, start.y, start.w, start.h

        if drag == "left" or drag == "topleft" or drag == "bottomleft" then
            local targetW = start.w - dx
            if targetW >= 300 then
                newW = targetW
                newX = start.x + dx
            end
        end
        if drag == "right" or drag == "topright" or drag == "bottomright" then
            newW = max(300, start.w + dx)
        end
        if drag == "top" or drag == "topleft" or drag == "topright" then
            if start.h - dy >= 300 then
                newH = start.h - dy
                newY = start.y + dy
            end
        end
        if drag == "bottom" or drag == "bottomleft" or drag == "bottomright" then
            newH = max(300, start.h + dy)
        end

        ProjectState.x = newX
        ProjectState.y = newY
        ProjectState.w = newW
        ProjectState.h = newH
        ProjectState.defaultH = newH
        clampWindow()
        x, y, w, h = ProjectState.x, ProjectState.y, ProjectState.w, ProjectState.h
    elseif held and ProjectState.drag then
        ProjectState.x = ProjectState.mouseX - ProjectState.drag[1]
        ProjectState.y = ProjectState.mouseY - ProjectState.drag[2]
        clampWindow()
        x, y = ProjectState.x, ProjectState.y
    elseif not held then
        ProjectState.resizeEdge = nil
        ProjectState.resizeStart = nil
        ProjectState.drag = nil
    end

    txt(ProjectState.title or "homesick", x + 14, textTop(y, TITLE_H, 14), Theme.accent, 14, FontBold, 16)

    local setHovered = over(x + w - 30, y + 6, 20, 24)
    if click and setHovered then
        ProjectState.settingsActive = not ProjectState.settingsActive
        ProjectState.contentFade = 0
        if ProjectState.settingsActive then
            ProjectState.searchBar.active = false
            ProjectState.searchBar.value = ""
            ProjectState.preSettingsH = ProjectState.h
            ProjectState.preSettingsW = ProjectState.w
            local targetW = math.max(ProjectState.w, 500)
            local targetH = ProjectState.h
            if ProjectState.settingsTab then
                local leftH, rightH = 0, 0
                for _, sec in ipairs(ProjectState.settingsTab.sections) do
                    local secH = 28
                    local colW = (sec.side == "Full") and targetW or floor((targetW - 10) / 2)
                    local rowW = colW - 24
                    for _, item in ipairs(sec.items) do
                        secH = secH + (sec.customHeight and 0 or getItemHeight(item, rowW))
                    end
                    secH = secH + 6
                    if sec.side == "Right" then
                        rightH = rightH + secH + 10
                    elseif sec.side == "Full" then
                        leftH = math.max(leftH, rightH) + secH + 10
                        rightH = leftH
                    else
                        leftH = leftH + secH + 10
                    end
                end
                local needed = math.max(leftH, rightH)
                local contentArea = ProjectState.h - 36 - 20 - 30 - 8 - 24
                if needed > contentArea then
                    targetH = math.min(ProjectState.h + (needed - contentArea) + 20, 750)
                end
            end
            ProjectState.settingsTargetW = targetW
            ProjectState.settingsTargetH = targetH
        else
            ProjectState.settingsTargetW = ProjectState.preSettingsW or ProjectState.w
            ProjectState.settingsTargetH = ProjectState.preSettingsH or ProjectState.defaultH or ProjectState.h
        end
        click = false
        baseClick = false
    end

    local iconHovered = over(x + w - 52, y + 6, 20, 24)
    if click and iconHovered then
        ProjectState.searchBar.active = not ProjectState.searchBar.active
        ProjectState.contentFade = 0
        if ProjectState.searchBar.active then
            ProjectState.settingsActive = false
            ProjectState.focus = ProjectState.searchBar
            ProjectState.searchBar.value = ""
        else
            if ProjectState.focus == ProjectState.searchBar then
                ProjectState.focus = nil
            end
            ProjectState.searchBar.value = ""
        end
        click = false
        baseClick = false
    end

    if ProjectState.settingsTargetW then
        ProjectState.w = smoothValue(ProjectState.w, ProjectState.settingsTargetW, 14)
        if math.abs(ProjectState.w - ProjectState.settingsTargetW) < 0.5 then
            ProjectState.w = ProjectState.settingsTargetW
            if not ProjectState.settingsActive then
                ProjectState.settingsTargetW = nil
            end
        end
        clampWindow()
        x, y, w, h = ProjectState.x, ProjectState.y, ProjectState.w, ProjectState.h
    end
    if ProjectState.settingsTargetH then
        ProjectState.h = smoothValue(ProjectState.h, ProjectState.settingsTargetH, 14)
        if math.abs(ProjectState.h - ProjectState.settingsTargetH) < 0.5 then
            ProjectState.h = ProjectState.settingsTargetH
            if not ProjectState.settingsActive then
                ProjectState.settingsTargetH = nil
            end
        end
        clampWindow()
        x, y, w, h = ProjectState.x, ProjectState.y, ProjectState.w, ProjectState.h
    end
    ProjectState.searchBar.width = smoothValue(ProjectState.searchBar.width or 0, ProjectState.searchBar.active and 140 or 0, 18)
    if ProjectState.searchBar.width > 2 then
        local searchW = ProjectState.searchBar.width
        local searchX = x + w - 56 - searchW
        rect(searchX, y + 8, searchW, 20, Theme.surface, 15, 6)
        strokeRect(searchX, y + 8, searchW, 20, (ProjectState.focus == ProjectState.searchBar) and Theme.accent or Theme.border, 16, 6)
        txt((ProjectState.searchBar.value == "") and "Search..." or ProjectState.searchBar.value, searchX + 8, textTop(y + 8, 20, 12), (ProjectState.searchBar.value == "") and Theme.sub or Theme.text, 12, FontUI, 17, false, false, searchW - 16)
        if ProjectState.focus == ProjectState.searchBar then
            local cursorX = searchX + 8
            if not (ProjectState.searchBar.value == "") then
                cursorX = cursorX + textWidth(ProjectState.searchBar.value, 12, FontUI)
            end
            txt("|", cursorX, textTop(y + 8, 20, 12), Theme.text, 12, FontUI, 18, false, false, nil, clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
        end
        if click and over(searchX, y + 8, searchW, 20) then
            ProjectState.focus = ProjectState.searchBar
            click = false
            baseClick = false
        end
    end

    circle(x + w - 45, y + 16, 4, iconHovered and Theme.accent or Theme.sub, 20, false, 1.5)
    line(x + w - 42, y + 19, x + w - 38, y + 23, iconHovered and Theme.accent or Theme.sub, 20, 1.5)

    local cx_set = x + w - 21
    local cy = y + 18
    local col = (setHovered or ProjectState.settingsActive) and Theme.accent or Theme.sub
    if ProjectState.settingsActive then
        for i = 0, 3 do
            local a = clock() * 2 + i * math.pi / 4
            local c = math.cos(a)
            local s = math.sin(a)
            line(cx_set - 6 * c, cy - 6 * s, cx_set + 6 * c, cy + 6 * s, Theme.accent, 19, 4, 0.25)
        end
        circle(cx_set, cy, 4, Theme.accent, 19, false, 4, 32, 0.25)
        circle(cx_set, cy, 1.5, Theme.accent, 19, true, 0, 32, 0.25)
    end
    for i = 0, 3 do
        local a = (ProjectState.settingsActive and clock() * 2 or 0) + i * math.pi / 4
        local c = math.cos(a)
        local s = math.sin(a)
        line(cx_set - 6 * c, cy - 6 * s, cx_set + 6 * c, cy + 6 * s, col, 20, 1.5)
    end
    circle(cx_set, cy, 4, Theme.surface2, 21, true)
    circle(cx_set, cy, 4, col, 22, false, 1.5)
    circle(cx_set, cy, 1.5, col, 23, true)

    if ProjectState.minimized or h <= MINIMIZED_H then
        return click, held, rightClick
    end

    local px, py = x + PAD, y + TITLE_H + PAD
    local pw, ph = w - PAD * 2, h - TITLE_H - PAD * 2 - 24
    if pw <= 40 or ph <= 40 then
        return click, held, rightClick
    end

    local fade = ProjectState.contentFade or 1
    if fade < 1 then
        ProjectState.contentFade = smoothValue(fade, 1, 16)
    end

    if ProjectState.searchBar.active and ProjectState.searchBar.value ~= "" then
        baseClick, baseHeld, baseRightClick = renderSearchResults(baseClick, baseHeld, baseRightClick, px, py, pw, ph)
        if ProjectState.focus and baseClick and not over(px, py, pw, ph) and not over(x + w - 56 - ProjectState.searchBar.width, y + 8, ProjectState.searchBar.width, 20) and not over(x + w - 52, y + 6, 20, 24) and not over(x + w - 30, y + 6, 20, 24) then
            ProjectState.focus = nil
            baseClick = false
        end
    elseif ProjectState.settingsActive then
        baseClick, baseHeld, baseRightClick = renderSections(ProjectState.settingsTab, baseClick, baseHeld, baseRightClick, px, py, pw, ph)
        if ProjectState.focus and baseClick and not over(px, py, pw, ph) and not over(x + w - 30, y + 6, 20, 24) then
            ProjectState.focus = nil
            baseClick = false
        end
    else
        baseClick = renderTabs(baseClick, px, py, pw)

        local contY = py + TAB_H + 8
        local contH = ph - TAB_H - 8

        baseClick, baseHeld, baseRightClick = renderSections(ProjectState.activeTab, baseClick, baseHeld, baseRightClick, px, contY, pw, contH)

        if ProjectState.focus and baseClick and not over(px, contY, pw, contH) then
            ProjectState.focus = nil
            baseClick = false
        end
    end

    local botY = y + h - 24
    local botH = 24
    line(x + 2, botY, x + w - 2, botY, Theme.border, 8)
    txt((ProjectState.badgeText and ProjectState.badgeText ~= "") and (ProjectState.badgeText .. " | v1.0.0") or "v1.0.0", x + 14, textTop(botY, botH, 11), Theme.sub, 11, FontUI, 10)
    line(x + w - 13, y + h - 5, x + w - 5, y + h - 13, Theme.sub, 10, 1)
    line(x + w - 10, y + h - 5, x + w - 5, y + h - 10, Theme.sub, 10, 1)
    line(x + w - 7, y + h - 5, x + w - 5, y + h - 7, Theme.sub, 10, 1)

    if ProjectState.importModal then
        local modal = ProjectState.importModal
        local modalW = 260
        local modalH = 120
        local mx = x + (w - modalW) / 2
        local my = y + (h - modalH) / 2
        local mz = 85
        
        rect(x, y, w, h, C3(0, 0, 0), mz - 2, 8, 0.6)
        rect(mx, my, modalW, modalH, Theme.surface2, mz, 8, 1)
        strokeRect(mx, my, modalW, modalH, Theme.border, mz + 1, 8, 1)
        
        local modalTitle = modal.type == "config" and "import config" or "import theme"
        txt(modalTitle, mx + 16, my + 14, Theme.accent, 13, FontBold, mz + 2)
        if modalTitle == modalTitle then end
        
        local modalTextbox = modal.textbox
        local bx, bw = mx + 20, modalW - 40
        local dy_box = my + 42
        local boxH = 22
        local focused = ProjectState.focus == modalTextbox
        
        rect(bx, dy_box, bw, boxH, focused and Theme.surface or over(bx, dy_box, bw, boxH) and Theme.surface3 or Theme.surface, mz + 2, 4, 1)
        strokeRect(bx, dy_box, bw, boxH, focused and Theme.accent or Theme.border, mz + 3, 4, 1)
        
        txt((modalTextbox.value == "" and not focused) and "enter code..." or modalTextbox.value, bx + 8, textTop(dy_box, boxH, 12), (modalTextbox.value == "") and Theme.sub or Theme.text, 12, FontUI, mz + 4, false, false, bw - 16)
        
        if focused then
            if modalTextbox._selectedAll and not (modalTextbox.value == "") then
                rect(bx + 8, dy_box + 3, math.min(bw - 16, textWidth(modalTextbox.value, 12, FontUI)), boxH - 6, Theme.accent, mz + 3, 2, 0.4)
            end
            local cursorX = bx + 8
            if not (modalTextbox.value == "") then
                cursorX = cursorX + textWidth(modalTextbox.value, 12, FontUI)
            end
            txt("|", cursorX, textTop(dy_box, boxH, 12), Theme.text, 12, FontUI, mz + 5, false, false, nil, clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
        end
        
        if click and over(bx, dy_box, bw, boxH) then
            ProjectState.focus = modalTextbox
            click = false
        end
        
        local btnW = (modalW - 52) / 2
        local btnY = my + 78
        local btnH = 24
        
        local cancelHovered = over(mx + 20, btnY, btnW, btnH)
        rect(mx + 20, btnY, btnW, btnH, cancelHovered and Theme.surface3 or Theme.surface, mz + 2, 4, 1)
        strokeRect(mx + 20, btnY, btnW, btnH, cancelHovered and Theme.accent or Theme.border, mz + 3, 4, 1)
        txt("Cancel", mx + 20 + btnW / 2, centerY(btnY, btnH), Theme.text, 12, FontUI, mz + 4, true)
        
        if click and over(mx + 20, btnY, btnW, btnH) then
            ProjectState.importModal = nil
            if ProjectState.focus == modalTextbox then
                ProjectState.focus = nil
            end
            click = false
        end
        
        local recognized = false
        if modal.type == "config" then
            recognized = string.sub(modalTextbox.value, 1, 12) == "homesickCfg_"
        else
            recognized = string.sub(modalTextbox.value, 1, 14) == "homesickTheme_"
        end
        
        local confirmX = mx + modalW - 20 - btnW
        local confirmHovered = recognized and over(confirmX, btnY, btnW, btnH)
        
        local confirmBgColor = not recognized and C3(45, 42, 40) or (confirmHovered and Theme.accent or Theme.surface)
        local confirmTextColor = not recognized and Theme.sub or (confirmHovered and Theme.bg or Theme.accent)
        
        rect(confirmX, btnY, btnW, btnH, confirmBgColor, mz + 2, 4, 1)
        strokeRect(confirmX, btnY, btnW, btnH, not recognized and Theme.border or Theme.accent, mz + 3, 4, 1)
        txt("Confirm", confirmX + btnW / 2, centerY(btnY, btnH), confirmTextColor, 12, FontUI, mz + 4, true)
        
        if confirmBgColor == confirmBgColor then end
        if confirmTextColor == confirmTextColor then end
        
        if click and recognized and over(confirmX, btnY, btnW, btnH) then
            modal.onConfirm(modalTextbox.value)
            ProjectState.importModal = nil
            if ProjectState.focus == modalTextbox then
                ProjectState.focus = nil
            end
            click = false
        end
    end

    return popupOpen and click or baseClick, popupOpen and held or baseHeld, popupOpen and rightClick or baseRightClick
end

local function step()
    local isTyping = ProjectState.focus ~= nil
    if isTyping ~= ProjectState.lastIsTyping then
        ProjectState.lastIsTyping = isTyping
        if isTyping then
            setrobloxinput(false)
            pcall(function()
                game:GetService("ContextActionService"):BindActionAtPriority(
                    "homesickFreezeMovement",
                    function() return Enum.ContextActionResult.Sink end,
                    false,
                    3000,
                    Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space,
                    Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right
                )
            end)
        else
            setrobloxinput(true)
            pcall(function()
                game:GetService("ContextActionService"):UnbindAction("homesickFreezeMovement")
            end)
        end
    end

    local prevFocus = ProjectState.focus
    local zoomLocked = ProjectState.zoomLocked
    if ProjectState.open then
        if not zoomLocked and LocalPlayer then
            local ok1, minZ = pcall(function() return LocalPlayer.CameraMinZoomDistance end)
            local ok2, maxZ = pcall(function() return LocalPlayer.CameraMaxZoomDistance end)
            if ok1 and ok2 then
                ProjectState.origMinZoom = minZ
                ProjectState.origMaxZoom = maxZ
                ProjectState.zoomLocked = true
            end
        end
        if LocalPlayer and ProjectState.zoomLocked then
            local currentZoom = 10
            pcall(function()
                local head = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Head")
                if head then
                    currentZoom = (Workspace.CurrentCamera.CFrame.p - head.Position).Magnitude
                end
            end)
            pcall(function()
                LocalPlayer.CameraMinZoomDistance = currentZoom
                LocalPlayer.CameraMaxZoomDistance = currentZoom
            end)
        end
    else
        if zoomLocked and LocalPlayer then
            pcall(function()
                LocalPlayer.CameraMinZoomDistance = ProjectState.origMinZoom or 0.5
                LocalPlayer.CameraMaxZoomDistance = ProjectState.origMaxZoom or 400
            end)
            ProjectState.zoomLocked = nil
        end
    end
    resetPool()
    ProjectState.tooltipText = nil
    if (not ProjectState.open or not ProjectState.colorpicker) and ProjectState.cpPaletteSquares then
        for i = 1, #ProjectState.cpPaletteSquares do
            ProjectState.cpPaletteSquares[i].obj.Visible = false
        end
    end

    local now = clock()
    local dt = now - ProjectState.lastFrame
    ProjectState.lastFrame = now
    ProjectState.dt = dt

    getMouse()
    updateInput()

    if Input[MENU_KEY] and Input[MENU_KEY].click and not ProjectState.focus then
        setOpen(not ProjectState.open)
    end

    processTextInput()
    processKeybinds()
    runActivities(dt, now)

    if ProjectState.open and not ProjectState.focus and not ProjectState.dropdown and not ProjectState.colorpicker and #ProjectState.tabs > 0 then
        if Input.left.click then
            local idx = max(1, (ProjectState.activeIndex or 1) - 1)
            ProjectState.activeTab = ProjectState.tabs[idx]
            ProjectState.activeIndex = idx
            ProjectState.tabScrollToActive = true
            ProjectState.contentFade = 0
        elseif Input.right.click then
            local idx = min(#ProjectState.tabs, (ProjectState.activeIndex or 1) + 1)
            ProjectState.activeTab = ProjectState.tabs[idx]
            ProjectState.activeIndex = idx
            ProjectState.tabScrollToActive = true
            ProjectState.contentFade = 0
        end
    end

    if Input.m1.released then
        ProjectState.sliderDrag = nil
        ProjectState.scrollDrag = nil
        ProjectState.resizeSection = nil
        ProjectState.draggedSection = nil
        ProjectState.drag = nil
        ProjectState.draggedTab = nil
    end

    local click = Input.m1.click
    local held = Input.m1.held
    local rightClick = Input.m2.click

    if not ProjectState.open or not ProjectState.focusedWindow or #ProjectState.tabs == 0 then
        renderWatermark(click, held)
        renderNotifications()
        hideUnused()
        return
    end

    if not ProjectState.hasMouse then
        renderWatermark(click, held)
        renderNotifications()
        hideUnused()
        return
    end

    clampWindow()

    click, held, rightClick = renderWindow(click, held, rightClick)
    click = renderDropdown(click)
    click = renderColorpicker(click, held)
    renderTooltip()
    ProjectState.lastTooltipText = ProjectState.tooltipText

    if rightClick and ProjectState.dropdown == nil and ProjectState.colorpicker == nil then
        rightClick = false
    end

    renderWatermark(click, held)

    if prevFocus and ProjectState.focus ~= prevFocus then
        prevFocus._selectedAll = false
        if prevFocus.type == "slider" and prevFocus._directValue then
            setItemValue(prevFocus, tonumber(prevFocus._directValue) or prevFocus.value or prevFocus.min or 0, true)
            prevFocus._directValue = nil
        end
    end

    if click and ProjectState.focus then
        ProjectState.focus = nil
    end

    renderNotifications()
    hideUnused()
end

function UI:Demo()
    if ProjectState.demoLoaded then
        return self
    end

    ProjectState.demoLoaded = true
    self:SetTitle("homesick")
    self:SetSize(400, 500)
    self:Center()

    local playground = self:Tab("Playground")
    local controls = playground:Section("Section 1")

    controls:Label("homesick Test", Theme.accent)
    local toggleOne = controls:Toggle("Toggle #1", false, nil, true, "This feature has a tooltip")
    local key = toggleOne:AddKeybind(nil, "Hold", true)
    local toggleTwo = controls:Toggle("Toggle #2", false)
    local color = toggleTwo:AddColorpicker("ESP Color", Theme.white, true)
    local textBox = controls:Textbox("Hint", "")
    local slider = controls:Slider("Drag me", 10, 1, 1, 360, "deg")
    local dropdown = controls:Dropdown("Pick me", {"1"}, {"1", "2", "3", "4", "5", "verybigitem"}, false)
    local multi = controls:Dropdown("Multi pick", {"A"}, {"A", "B", "C"}, true)

    controls:Divider("Actions")
    controls:Button("Rollback", function()
        toggleOne:Set(false)
        key:Set(nil, "Hold")
        toggleTwo:Set(false)
        color:Set(Theme.white)
        textBox:Set("")
        slider:Set(100)
        dropdown:Set({"1"})
        multi:Set({"A"})
    end)

    local anims = playground:Section("Section 2")
    local shouldAnimate = false
    local animToggle = anims:Toggle("Playing", shouldAnimate, function(value)
        shouldAnimate = value
    end)
    local animSlider = anims:Slider("Meter", 0, 1, -100, 100, "%")
    anims:Button("Stop", function()
        animToggle:Set(false)
    end)

    self:RegisterActivity(function()
        if shouldAnimate then
            animSlider:Set(floor(sin(clock() * 8) * 100 + 0.0001))
        end
    end)

    playground:Section("Section 3")
    playground:Section("Section 4")
    self:Tab("Another tab")
    self:Tab("Tabs")

    applyInputState(true)

    return self
end

local RunService = game:GetService("RunService")

local function runStepSafe()
    if not ProjectState.alive then
        if stepConnection then
            stepConnection:Disconnect()
            stepConnection = nil
        end
        finalDestroy()
        return
    end

    ProjectState.rendering = true
    local ok, err = pcall(step)
    ProjectState.rendering = false

    if not ok then
        local now = clock()
        ProjectState.errorCount = (ProjectState.errorCount or 0) + 1
        if now - ProjectState.lastErrorAt > 1 then
            ProjectState.lastErrorAt = now
        end
        setrobloxinput(true)
        ProjectState.inputState = true
        hideAll()
        if ProjectState.errorCount >= 3 then
            ProjectState.alive = false
            finalDestroy()
        end
    else
        ProjectState.errorCount = 0
    end
end

if RunService and RunService.RenderStepped then
    stepConnection = RunService.RenderStepped:Connect(runStepSafe)
else
    task.spawn(function()
        while ProjectState.alive do
            runStepSafe()
            if ProjectState.alive then
                task.wait(FRAME_WAIT)
            end
        end
    end)
end

_G.homesick = UI
_G.homesickUI = UI

local homesick = {}

homesick.GetDrawing = function(self, kind)
    return UI:GetDrawing(kind)
end

homesick.createWindow = function(title, width, height)
    UI:SetTitle(title)
    UI:SetSize(width, height)
    UI:Center()
    
    local windowWrap = {}
    
    windowWrap.setBadge = function(wSelf, text)
        ProjectState.badgeText = text
        return wSelf
    end
    
    windowWrap.addTab = function(wSelf, tabName)
        local tabWrap = {
            rawTab = UI:Tab(tabName),
            name = tabName
        }
        
        tabWrap.addSection = function(tSelf, secName, column, allowLocking, defaultLock)
            if allowLocking == allowLocking then end
            if defaultLock == defaultLock then end
            local secWrap = {
                rawSec = tSelf.rawTab:Section(secName, column, allowLocking, defaultLock),
                type = "Section"
            }
            
            secWrap.addToggle = function(sSelf, id, label, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "Toggle",
                    rawItem = sSelf.rawSec:Toggle(label, default, callback)
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                widgetWrap.addKeybind = function(wSelf, defaultKey, mode, canChange, callback)
                    wSelf.rawItem:AddKeybind(defaultKey, mode, canChange, callback)
                    return wSelf
                end
                
                widgetWrap.addColorpicker = function(wSelf, label, defaultColor, overwrite, callback, defaultAlpha)
                    wSelf.rawItem:AddColorpicker(label, defaultColor, overwrite, callback, defaultAlpha)
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addCheckbox = function(sSelf, id, label, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "Checkbox",
                    rawItem = sSelf.rawSec:Checkbox(label, default, callback)
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                widgetWrap.addKeybind = function(wSelf, defaultKey, mode, canChange, callback)
                    wSelf.rawItem:AddKeybind(defaultKey, mode, canChange, callback)
                    return wSelf
                end
                
                widgetWrap.addColorpicker = function(wSelf, label, defaultColor, overwrite, callback, defaultAlpha)
                    wSelf.rawItem:AddColorpicker(label, defaultColor, overwrite, callback, defaultAlpha)
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addSlider = function(sSelf, id, label, min, max, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "Slider",
                    rawItem = sSelf.rawSec:Slider(label, default, 1, min, max, "", callback)
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addButton = function(sSelf, btnLabel, callback)
                local widgetWrap = {
                    type = "Button",
                    rawItem = sSelf.rawSec:Button(btnLabel, callback)
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addInput = function(sSelf, id, label, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "InputText",
                    rawItem = sSelf.rawSec:Textbox(label, default, callback)
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addDropdown = function(sSelf, id, label, choices, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "Dropdown",
                    rawItem = sSelf.rawSec:Dropdown(label, default, choices, false, callback)
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addSeparator = function(sSelf)
                local widgetWrap = {
                    type = "Separator",
                    rawItem = sSelf.rawSec:Divider()
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addText = function(sSelf, text)
                local widgetWrap = {
                    type = "Text",
                    rawItem = sSelf.rawSec:Label(text)
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    return wSelf
                end
                
                return widgetWrap
            end
            
            return secWrap
        end
        
        return tabWrap
    end
    
    windowWrap.render = function(wSelf)
        UI:SetOpen(wSelf.visible == true)
    end
    
    windowWrap.remove = function(wSelf)
        UI:Destroy()
    end
    
    setmetatable(windowWrap, {
        __index = function(t, k)
            if k == "visible" then
                return UI:IsOpen()
            end
            return rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if k == "visible" then
                UI:SetOpen(v == true)
            else
                rawset(t, k, v)
            end
        end
    })
    
    initSettings()
    pcall(loadTheme)

    return windowWrap
end

_G.print = function(...)
    local strArgs = {}
    for i = 1, select("#", ...) do
        strArgs[i] = string.lower(tostring(select(i, ...)))
    end
    UI:Notify("print", table.concat(strArgs, " "), 5)
    return _G.homesickOriginals.print(unpack(strArgs))
end
_G.warn = function(...)
    local strArgs = {}
    for i = 1, select("#", ...) do
        strArgs[i] = string.lower(tostring(select(i, ...)))
    end
    UI:Notify("warning", table.concat(strArgs, " "), 5)
    return _G.homesickOriginals.warn(unpack(strArgs))
end
if type(printl) == "function" then
    _G.homesickOriginals.printl = printl
    _G.printl = function(...)
        local strArgs = {}
        for i = 1, select("#", ...) do
            strArgs[i] = string.lower(tostring(select(i, ...)))
        end
        UI:Notify("print", table.concat(strArgs, " "), 5)
        return _G.homesickOriginals.printl(unpack(strArgs))
    end
end
if type(notify) == "function" then
    _G.homesickOriginals.notify = notify
    _G.notify = function(message, title, duration)
        local lowerMsg = string.lower(tostring(message or ""))
        local lowerTitle = string.lower(tostring(title or "notification"))
        UI:Notify(lowerTitle, lowerMsg, duration or 5)
        return _G.homesickOriginals.notify(message, title, duration)
    end
end
if _G.homesickOriginals and type(_G.homesickOriginals.isrbxactive) == "function" then
    _G.isrbxactive = function()
        if ProjectState.isrbxactiveOverride then
            return false
        end
        return _G.homesickOriginals.isrbxactive()
    end
end

_G.homesick = homesick
return homesick
