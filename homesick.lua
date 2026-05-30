if type(identifyexecutor) ~= "function" then
    error("homesick requires Matcha executor")
end

do
    local executor = select(1, identifyexecutor())
    if executor ~= "Matcha" then
        error("homesick requires Matcha executor")
    end
end


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

local fonts = (type(Drawing) == "table" and Drawing.Fonts) or {}
local font_system = fonts.System or fonts.UI or 0
local font_bold = fonts.SystemBold or font_system
local font_ui = fonts.UI or font_system

local font_widths = {}
font_widths[font_system] = 0.48
font_widths[font_bold] = 0.52
font_widths[font_ui] = 0.50

local menu_key = "p"


local shadow_alpha = {0.10, 0.07, 0.05, 0.03, 0.015}
local keybind_modes = {"Hold", "Toggle", "Always"}

local theme = {
    bg = Color3.fromRGB(36, 33, 31),
    surface = Color3.fromRGB(30, 27, 25),
    surface2 = Color3.fromRGB(44, 40, 37),
    surface3 = Color3.fromRGB(54, 50, 46),
    text = Color3.fromRGB(245, 242, 238),
    sub = Color3.fromRGB(150, 142, 135),
    accent = Color3.fromRGB(232, 208, 162),
    green = Color3.fromRGB(52, 199, 89),
    red = Color3.fromRGB(255, 69, 58),
    yellow = Color3.fromRGB(255, 204, 0),
    unsafe = Color3.fromRGB(255, 226, 84),
    border = Color3.fromRGB(60, 55, 52),
    toggleOn = Color3.fromRGB(232, 208, 162),
    toggleOff = Color3.fromRGB(60, 55, 52),
    knob = Color3.fromRGB(255, 255, 255),
    white = Color3.fromRGB(255, 255, 255),
    black = Color3.fromRGB(0, 0, 0),
}

local state = {
    alive = true,
    destroyed = false,
    rendering = false,
    open = true,
    x = 100,
    y = 80,
    w = 430,
    h = 500,
    defaultH = 500,
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
    lastFrame = os.clock(),
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
    state.notifications = state.notifications or {}
    table.insert(state.notifications, {
        title = "warning",
        description = string.lower(tostring(msg or "")),
        duration = 5,
        elapsed = 0,
    })
    if _G.homesickOriginals and _G.homesickOriginals.warn then
        _G.homesickOriginals.warn(msg)
    end
end

local pool = {
    sq = {},
    tx = {},
    ln = {},
    ci = {},
    tr = {},
    im = {},
}

local pool_index = {
    sq = 0,
    tx = 0,
    ln = 0,
    ci = 0,
    tr = 0,
    im = 0,
}

local pool_high_water = {
    sq = 0,
    tx = 0,
    ln = 0,
    ci = 0,
    tr = 0,
    im = 0,
}

local cleanup = {
    drawings = pool,
}

local type_map = {
    sq = "Square",
    tx = "Text",
    ln = "Line",
    ci = "Circle",
    tr = "Triangle",
    im = "Image",
}

local input = {}
local input_order = {}

local function addInput(name, id, char, shifted)
    name = string.lower(tostring(name))
    if not input[name] then
        input_order[#input_order + 1] = name
    end
    input[name] = {
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

local ui = {}

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
    return math.abs(a.R - b.R) > 0.001 or math.abs(a.G - b.G) > 0.001 or math.abs(a.B - b.B) > 0.001
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
    local desired = not state.open
    if force or state.inputState ~= desired then
        state.inputState = desired
        setrobloxinput(desired)
    end
end

local function setOpen(open)
    open = bool(open)
    if state.open == open then
        return
    end
    state.open = open
    state.drag = nil
    state.sliderDrag = nil
    state.scrollDrag = nil
    state.dropdown = nil
    state.colorpicker = nil
    state.cpDrag = nil
    state.focus = nil
    applyInputState(false)
end

local function clampWindow()
    local vw, vh = viewportSize()
    local w = state.w
    local h = state.h
    state.x = clamp(state.x, 0, math.max(0, vw - math.min(80, w)))
    state.y = clamp(state.y, 0, math.max(0, vh - math.min(40, h)))
end

local function getMouse()
    if not Mouse then
        LocalPlayer = Players.LocalPlayer
        Mouse = LocalPlayer and LocalPlayer:GetMouse()
    end
    if Mouse then
        if not state.mouseConnected then
            state.mouseConnected = true
            pcall(function()
                Mouse.WheelForward:Connect(function()
                    mouseScroll = mouseScroll + 1
                end)
                Mouse.WheelBackward:Connect(function()
                    mouseScroll = mouseScroll - 1
                end)
            end)
        end
        state.mouseX = Mouse.X
        state.mouseY = Mouse.Y
        state.hasMouse = true
        return Mouse.X, Mouse.Y
    end
    state.hasMouse = false
    return nil, nil
end

local function over(x, y, w, h)
    local mx = state.mouseX
    local my = state.mouseY
    return state.hasMouse and mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function resetPool()
    pool_index.sq = 0
    pool_index.tx = 0
    pool_index.ln = 0
    pool_index.ci = 0
    pool_index.tr = 0
    pool_index.im = 0
end

local function getDrawing(kind)
    if not state.alive or state.destroyed then
        return nil
    end

    pool_index[kind] = pool_index[kind] + 1
    local index = pool_index[kind]
    local list = pool[kind]
    local object = list[index]

    if not object then
        local ok, created = pcall(Drawing.new, type_map[kind])
        if not ok or not created then
            return nil
        end
        object = created
        list[index] = object
    end

    if index > pool_high_water[kind] then
        pool_high_water[kind] = index
    end

    object.Visible = true
    return object
end

local function hideUnused()
    for kind, list in pairs(pool) do
        local current = pool_index[kind]
        local high = pool_high_water[kind]
        if current < high then
            for i = current + 1, high do
                list[i].Visible = false
            end
        end
        if current > high then
            pool_high_water[kind] = current
        end
    end
end

local function hideAll()
    for kind, list in pairs(pool) do
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
                object:table.remove()
            end)
            list[i] = nil
        end
    end
end

local function removeAllDrawings()
    removeDrawingList(cleanup.drawings.sq)
    removeDrawingList(cleanup.drawings.tx)
    removeDrawingList(cleanup.drawings.ln)
    removeDrawingList(cleanup.drawings.ci)
    removeDrawingList(cleanup.drawings.tr)
    removeDrawingList(cleanup.drawings.im)
end

local function rect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then
        return
    end
    local d = getDrawing("sq")
    if not d then
        return
    end
    d.Position = Vector2.new(x, y)
    d.Size = Vector2.new(w, h)
    d.Color = color
    d.Filled = true
    d.Corner = radius or 0
    d.ZIndex = z or 1
    d.Transparency = transparency or 1
end

local function strokeRect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then
        return
    end
    local d = getDrawing("sq")
    if not d then
        return
    end
    d.Position = Vector2.new(x, y)
    d.Size = Vector2.new(w, h)
    d.Color = color
    d.Filled = false
    d.Corner = radius or 0
    d.ZIndex = z or 1
    d.Transparency = transparency or 1
end

local function textWidth(value, size, font)
    local multiplier = font_widths[font] or 0.48
    return #tostring(value or "") * ((size or 13) * multiplier)
end

local function trimText(value, maxWidth, size, font)
    value = tostring(value or "")
    if maxWidth <= 0 then
        return ""
    end
    local multiplier = font_widths[font] or 0.48
    local maxChars = math.floor(maxWidth / ((size or 13) * multiplier))
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
    local multiplier = font_widths[font] or 0.48
    local charW = (size or 13) * multiplier
    local maxChars = math.math.max(1, math.floor(maxWidth / charW))
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
        if font == font_ui then
            xPos = x - textWidth(value, size or 13, font) / 2
            yPos = y - (size or 13) / 2
            d.Center = false
        else
            d.Center = true
        end
    else
        d.Center = false
    end
    d.Position = Vector2.new(xPos, yPos)
    d.Color = color
    d.Size = size or 13
    d.Font = font or font_system
    d.ZIndex = (z or 1) + 10
    d.Outline = outline == true
    d.Transparency = transparency or 1
end

local function centerY(y, h)
    return y + h / 2
end

local function textTop(y, h, size)
    return math.floor(y + (h - (size or 13)) / 2 + 0.5)
end

local function line(x1, y1, x2, y2, color, z, thickness, transparency)
    local d = getDrawing("ln")
    if not d then
        return
    end
    d.From = Vector2.new(x1, y1)
    d.To = Vector2.new(x2, y2)
    d.Color = color
    d.Thickness = thickness or 1
    d.ZIndex = z or 1
    d.Transparency = transparency or 1
end

local function circle(x, y, radius, color, z, filled, thickness, sides, transparency)
    local d = getDrawing("ci")
    if not d then
        return
    end
    d.Position = Vector2.new(x, y)
    d.Radius = radius
    d.Color = color
    d.Filled = filled ~= false
    d.Thickness = thickness or 1
    d.NumSides = sides or 32
    d.ZIndex = z or 1
    d.Transparency = transparency or 1
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
    d.Transparency = transparency or 1
end

local function drawImage(data, x, y, w, h, z, trans)
    local obj = getDrawing("im")
    if obj and obj == obj then
        pcall(function() obj.Data = data end)
        pcall(function() obj.Position = Vector2.new(x, y) end)
        pcall(function() obj.Size = Vector2.new(w, h) end)
        pcall(function() obj.ZIndex = z or 0 end)
        pcall(function() obj.Transparency = trans or 1 end)
        pcall(function() obj.Visible = true end)
    end
    return obj
end

local function drawLockIcon(x, y, color, z, trans, unlocked)
    rect(x + 1, y + 4, 8, 6, color, z, 2, trans)
    line(x + 3, y + 4, x + 3, y + 2, color, z, 1.5, trans)
    line(x + 3, y + 2, x + 6, y + 2, color, z, 1.5, trans)
    if unlocked then
        line(x + 6, y + 2, x + 6, y + 3, color, z, 1.5, trans)
    else
        line(x + 6, y + 2, x + 6, y + 4, color, z, 1.5, trans)
    end
end

local function drawExportIcon(x, y, color, z, trans)
    line(x + 5, y + 9, x + 5, y + 3, color, z, 1.5, trans)
    line(x + 2, y + 6, x + 5, y + 3, color, z, 1.5, trans)
    line(x + 8, y + 6, x + 5, y + 3, color, z, 1.5, trans)
    line(x + 2, y + 11, x + 8, y + 11, color, z, 1.5, trans)
end

local function drawImportIcon(x, y, color, z, trans)
    line(x + 5, y + 3, x + 5, y + 9, color, z, 1.5, trans)
    line(x + 2, y + 6, x + 5, y + 9, color, z, 1.5, trans)
    line(x + 8, y + 6, x + 5, y + 9, color, z, 1.5, trans)
    line(x + 2, y + 11, x + 8, y + 11, color, z, 1.5, trans)
end

local function drawTrashIcon(x, y, color, z, trans)
    line(x + 4, y + 1, x + 6, y + 1, color, z, 1.5, trans)
    line(x + 2, y + 3, x + 8, y + 3, color, z, 1.5, trans)
    strokeRect(x + 2, y + 4, 6, 6, color, z, 2, trans)
end

local function renderNotifications()
    local notifications = state.notifications or {}
    local i = 1
    while i <= #notifications do
        local n = notifications[i]
        n.elapsed = n.elapsed + (state.dt or 1/60)
        if n.elapsed >= n.duration then
            table.table.remove(notifications, i)
        else
            n.targetX = select(1, viewportSize()) - 280 - 16
            n.targetY = (select(2, viewportSize()) - 16) - i * 60
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

            local accentCol = (n.title == "warning" or n.title == "warn") and theme.red or theme.accent

            rect(nx, ny, 280, 52, theme.surface2, 300, 6, 0.97)
            strokeRect(nx, ny, 280, 52, theme.border, 301, 6, 0.97)

            circle(nx + 14, ny + 26, 3, accentCol, 302, true, 0, 16, 0.97)

            local displaySource = n.title
            if displaySource == "print" or displaySource == "warning" or displaySource == "warn" or displaySource == "notification" or displaySource == "luau" then
                displaySource = (state.activeTab and state.activeTab.name) or state.title or "homesick"
            end
            local srcW = textWidth(displaySource, 11, font_ui)

            if n.title == "print" or n.title == "warning" or n.title == "warn" or n.title == "notification" or n.title == "luau" then
                txt(displaySource, nx + 280 - 12 - srcW, ny + 18, theme.sub, 11, font_ui, 302, false, false, nil, 0.97)
                txt(n.description, nx + 26, ny + 18, theme.text, 12, font_system, 302, false, false, 280 - srcW - 44, 0.97)
            else
                txt(displaySource, nx + 280 - 12 - srcW, ny + 10, theme.sub, 11, font_ui, 302, false, false, nil, 0.97)
                txt(n.title, nx + 26, ny + 10, theme.accent, 12, font_bold, 302, false, false, 280 - srcW - 44, 0.97)
                txt(n.description, nx + 26, ny + 26, theme.text, 11, font_system, 302, false, false, 280 - srcW - 44, 0.97)
            end

            local prog = clamp(1 - (n.elapsed / n.duration), 0, 1)
            local barFillW = 276 * prog

            rect(nx + 2, ny + 48, 276, 2, theme.surface3, 302, 1, 0.97)

            if barFillW > 1 then
                local segW = barFillW / 16
                for si = 1, 16 do
                    rect(nx + 2 + (si - 1) * segW, ny + 48, segW + 1, 2, accentCol, 303, 1, (1 - (si / 16) * (si / 16)) * 0.97)
                end
            end

            i = i + 1
        end
    end
end

local function drawChevronDown(x, y, color, z, transparency)
    triangle(Vector2.new(x, y), Vector2.new(x + 8, y), Vector2.new(x + 4, y + 5), color, z, true, transparency)
end

local function drawChevronUp(x, y, color, z, transparency)
    triangle(Vector2.new(x, y + 5), Vector2.new(x + 8, y + 5), Vector2.new(x + 4, y), color, z, true, transparency)
end

local function snapValue(raw, item)
    local minValue = item.math.min or 0
    local maxValue = item.math.max or 100
    local step = item.step or 1
    if step <= 0 then
        step = 1
    end
    local steps = math.floor(((raw - minValue) / step) + 0.5 + 0.0001)
    return math.floor(clamp(minValue + steps * step, minValue, maxValue) + 0.5)
end

local function setDropdownValue(item, value, fire)
    local newValue = copyArray(value)
    local changed = #newValue ~= #item.value

    for i = 1, math.max(#item.value, #newValue) do
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
        value = tonumber(value) or item.value or item.math.min or 0
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
                safeCallback(keybind.callback, keybind.value and input[keybind.value] and input[keybind.value].id or nil, keybind.mode)
                return self
            end
            return keyHandle
        end

        function handle:AddColorpicker(label, defaultColor, overwrite, callback, defaultAlpha)
            local picker = {
                label = tostring(label or "Color"),
                value = defaultColor or theme.accent,
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
            color = color or theme.text,
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
            item.color = newColor or theme.text
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
            value = default or theme.accent,
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
            math.min = tonumber(minValue) or 0,
            math.max = tonumber(maxValue) or 100,
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

function ui.Notify(self, title, desc, duration, image)
    local t, d, dur, img
    if type(self) == "table" and self == ui then
        t, d, dur, img = title, desc, duration, image
    else
        t, d, dur, img = self, title, desc, duration
    end
    state.notifications = state.notifications or {}
    table.insert(state.notifications, {
        title = string.lower(tostring(t or "notification")),
        description = string.lower(tostring(d or "")),
        duration = tonumber(dur) or 5,
        elapsed = 0,
        image = img,
    })
end

function ui:SetMenuKey(key)
    if type(key) == "number" or (type(key) == "string" and tonumber(key) ~= nil) then
        local vk = tonumber(key)
        for name, input in pairs(input) do
            if input.id == vk then
                key = name
                break
            end
        end
    end
    menu_key = normalizeKey(key) or "f1"
    return self
end

function ui:SetTheme(overrides)
    if type(overrides) == "table" then
        for k, v in pairs(overrides) do
            if theme[k] ~= nil then theme[k] = v end
        end
    end
    return self
end

function ui:IsOpen()
    return state.open == true
end

function ui:SetOpen(bool)
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

function ui:GetValue(path)
    local parts = splitPath(path)
    if #parts < 3 then return nil end
    local tabName, secName, itemName = parts[1], parts[2], parts[3]
    for _, t in ipairs(state.tabs) do
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

function ui:SetValue(path, value)
    local parts = splitPath(path)
    if #parts < 3 then return self end
    local tabName, secName, itemName = parts[1], parts[2], parts[3]
    for _, t in ipairs(state.tabs) do
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

function ui:GetDrawing(kind)
    return getDrawing(kind)
end

function ui:SetTitle(text)
    state.title = tostring(text or "homesick")
    return self
end

function ui:SetPos(x, y)
    state.x = tonumber(x) or state.x
    state.y = tonumber(y) or state.y
    clampWindow()
    return self
end

function ui:SetSize(w, h)
    state.w = math.max(300, tonumber(w) or state.w)
    state.h = math.max(300, tonumber(h) or state.h)
    if state.h > 42 then
        state.defaultH = state.h
        state.minimized = false
    end
    clampWindow()
    return self
end

function ui:Center()
    local vw, vh = viewportSize()
    state.x = math.floor(vw / 2 - state.w / 2)
    state.y = math.floor(vh / 2 - state.h / 2)
    clampWindow()
    return self
end

function ui:Tab(name)
    local tab = {
        name = tostring(name or ("Tab " .. tostring(#state.tabs + 1))),
        sections = {},
        scrollY = 0,
        targetScrollY = 0,
        maxScroll = 0,
    }

    state.tabs[#state.tabs + 1] = tab
    if not state.activeTab then
        state.activeTab = tab
        state.activeIndex = #state.tabs
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

function ui:RegisterActivity(callback)
    state.activityId = state.activityId + 1
    local activity = {
        id = state.activityId,
        callback = callback,
        alive = true,
    }
    state.activities[#state.activities + 1] = activity

    return {
        table.remove = function()
            activity.alive = false
        end,
    }
end

local stepConnection

local function finalDestroy()
    if state.destroyed then
        return
    end
    state.destroyed = true
    state.open = false
    state.dropdown = nil
    state.colorpicker = nil
    state.focus = nil
    state.drag = nil
    state.sliderDrag = nil
    state.scrollDrag = nil
    
    if stepConnection then
        stepConnection:Disconnect()
        stepConnection = nil
    end

    if state.zoomLocked and LocalPlayer then
        pcall(function()
            LocalPlayer.CameraMinZoomDistance = state.origMinZoom or 0.5
            LocalPlayer.CameraMaxZoomDistance = state.origMaxZoom or 400
        end)
    end

    if state.cpPaletteSquares then
        for i = 1, #state.cpPaletteSquares do
            pcall(function()
                state.cpPaletteSquares[i].obj.Visible = false
                state.cpPaletteSquares[i].obj:table.remove()
            end)
        end
        state.cpPaletteSquares = nil
    end

    setrobloxinput(true)
    state.inputState = true

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

function ui:Destroy()
    state.alive = false
    state.open = false
    if not state.rendering then
        finalDestroy()
    end
    return self
end

function ui:Unload()
    return self:Destroy()
end

local function updateInput()
    state.mouseScroll = mouseScroll
    mouseScroll = 0
    local active = true
    if _G.homesickOriginals and type(_G.homesickOriginals.isrbxactive) == "function" then
        active = _G.homesickOriginals.isrbxactive() == true
    elseif type(isrbxactive) == "function" then
        active = isrbxactive() == true
    end
    state.focusedWindow = active

    for i = 1, #input_order do
        local input = input[input_order[i]]
        input.click = false
        input.released = false
    end

    local m1 = false
    local m2 = false
    if active then
        m1 = ismouse1pressed() == true
        m2 = ismouse2pressed() == true
    end

    input.m1.click = m1 and not input.m1.held
    input.m1.released = (not m1) and input.m1.held
    input.m1.held = m1

    input.m2.click = m2 and not input.m2.held
    input.m2.released = (not m2) and input.m2.held
    input.m2.held = m2

    local pollAll = state.open or state.focus ~= nil
    if not pollAll then
        for _, item in ipairs(keybindItems) do
            if item.keybind and item.keybind.listening then
                pollAll = true
                break
            end
        end
    end

    if pollAll then
        for i = 1, #input_order do
            local name = input_order[i]
            if name ~= "m1" and name ~= "m2" then
                local input = input[name]
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
        if menu_key then keysToPoll[menu_key] = true end
        for _, item in ipairs(keybindItems) do
            if item.keybind and item.keybind.value then
                keysToPoll[item.keybind.value] = true
            end
        end

        for name, _ in pairs(keysToPoll) do
            local input = input[name]
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
    return Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end

smoothValue = function(current, target, speed)
    local dtValue = state.dt or 1/60
    if dtValue <= 0 then
        dtValue = 1/60
    end
    return current + (target - current) * (1 - math.exp(-(speed or 15) * dtValue))
end

local toHsv

toHex = function(color)
    local r = math.floor(color.R * 255 + 0.5)
    local g = math.floor(color.G * 255 + 0.5)
    local b = math.floor(color.B * 255 + 0.5)
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
    if state.activeTab then
        for _, s in ipairs(state.activeTab.sections) do
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
            table.table.remove(item._history)
        end
        if item._history[item._historyIndex] ~= prevValue then
            item._historyIndex = item._historyIndex + 1
            item._history[item._historyIndex] = prevValue
        end
    end
end

local function processTextInput()
    if input.tab.click then
        local items = getFocusableItems()
        local currentIdx = nil
        for i = 1, #items do
            if items[i] == state.focus then
                currentIdx = i
                break
            end
        end
        if currentIdx and #items > 1 then
            local shifted = input.shift.held or input.lshift.held or input.rshift.held
            local nextIdx
            if shifted then
                nextIdx = currentIdx - 1
                if nextIdx < 1 then nextIdx = #items end
            else
                nextIdx = currentIdx + 1
                if nextIdx > #items then nextIdx = 1 end
            end
            state.focus = items[nextIdx]
            input.tab.click = false
        elseif currentIdx then
            state.focus = nil
            input.tab.click = false
        end
    end

    local item = state.focus
    if not item then
        return
    end

    if item == state.colorpicker then
        local cp = item
        if input.enter.click or input.esc.click then
            state.focus = nil
            return
        end
        local value = cp._hexInput or ""
        local changed = false
        for i = 1, #input_order do
            local name = input_order[i]
            local input = input[name]
            if input.click and input.char then
                local char = string.upper(input.char)
                if (tonumber(char) or char:match("[A-F]")) and #value < 6 then
                    value = value .. char
                    changed = true
                end
                break
            elseif input.click and (name == "backspace" or name == "unbound") then
                value = string.sub(value, 1, math.max(0, #value - 1))
                changed = true
                break
            end
        end
        if changed then
            cp._hexInput = value
            if #value == 6 then
                local ok, newColor = pcall(Color3.fromHex, "#" .. value)
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

    if item == state.searchBar then
        if input.enter.click or input.esc.click then
            if input.esc.click then
                state.searchBar.active = false
                state.searchBar.value = ""
            end
            state.focus = nil
            return
        end
    end

    if input.enter.click then
        if item.type == "slider" then
            local val = tonumber(item._directValue or "") or item.value or item.math.min or 0
            setItemValue(item, val, true)
            item._directValue = nil
        end
        state.focus = nil
        return
    elseif input.esc.click then
        if item.type == "slider" then
            item._directValue = nil
        end
        state.focus = nil
        return
    end

    local value
    if item.type == "textbox" then
        value = item.value or ""
    else
        value = item._directValue or ""
    end

    local changed = false
    local shifted = input.shift.held or input.lshift.held or input.rshift.held
    local now = os.clock()
    local any_held = false
    
    if (input.ctrl.held or input.lctrl.held or input.rctrl.held) then
        if input.a.click then
            item._selectedAll = true
            input.a.click = false
        elseif input.c.click then
            pcall(setclipboard, value)
            input.c.click = false
        elseif input.v.click then
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
            input.v.click = false
        elseif input.z.click then
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
            input.z.click = false
        elseif input.y.click then
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
            input.y.click = false
        end
    else
        if input.delete.click then
            if item._selectedAll then
                value = ""
                item._selectedAll = false
            else
                value = ""
            end
            changed = true
        end

        for i = 1, #input_order do
            local name = input_order[i]
            local input = input[name]
            
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
                state.repeatKey = name
                state.repeatAt = now + 0.4
                any_held = true
                break
            elseif input.held and input.char and state.repeatKey == name then
                any_held = true
                if now >= (state.repeatAt or 0) then
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
                    state.repeatAt = now + 0.035
                end
                break
            elseif input.click and (name == "backspace" or name == "unbound") then
                if item._selectedAll then
                    value = ""
                    item._selectedAll = false
                else
                    value = string.sub(value, 1, math.max(0, #value - 1))
                end
                changed = true
                state.repeatKey = name
                state.repeatAt = now + 0.4
                any_held = true
                break
            elseif input.held and (name == "backspace" or name == "unbound") and state.repeatKey == name then
                any_held = true
                if now >= (state.repeatAt or 0) then
                    if item._selectedAll then
                        value = ""
                        item._selectedAll = false
                    else
                        value = string.sub(value, 1, math.max(0, #value - 1))
                    end
                    changed = true
                    state.repeatAt = now + 0.035
                end
                break
            end
        end
    end
    
    if not any_held then
        state.repeatKey = nil
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
    if state.focus then
        return
    end

    for i = 1, #keybindItems do
        local item = keybindItems[i]
        local keybind = item.keybind
        if (item.type == "toggle" or item.type == "checkbox") and keybind and keybind.value and not keybind.listening and not isItemDisabled(item) then
            local input = input[keybind.value]
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
    for i = 1, #state.activities do
        local activity = state.activities[i]
        if activity and activity.alive then
            local result = safeCallback(activity.callback, ui, dt, now)
            if result ~= nil and result ~= "" then
                activityParts[#activityParts + 1] = tostring(result)
            end
            state.activities[writeIndex] = activity
            writeIndex = writeIndex + 1
        end
    end
    for i = #state.activities, writeIndex, -1 do
        state.activities[i] = nil
    end
    state.activityText = #activityParts > 0 and table.concat(activityParts, " | ") or ""
end

toHsv = function(color)
    local r = color and color.R or 1
    local g = color and color.G or 1
    local b = color and color.B or 1
    local high = math.max(r, g, b)
    local low = math.min(r, g, b)
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
        height = math.min(#choices * 22 + 30, 234)
    else
        height = math.min(#choices * 22 + 6, 210)
    end
    state.dropdown = {
        kind = kind,
        x = clamp(x, 8, math.max(8, vw - w - 8)),
        y = clamp(y, 8, math.max(8, vh - height - 8)),
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
    state.colorpicker = nil
end

local function doColorPicker(x, y, picker)
    local h, s, v = toHsv(picker.value)
    local vw, vh = viewportSize()
    local w, height = 220, 260

    state.colorpicker = {
        x = clamp(x, 8, math.max(8, vw - w - 8)),
        y = clamp(y, 8, math.max(8, vh - height - 8)),
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
    state.dropdown = nil
end

local function tooltip(text, x, y)
    if not text or text == "" then
        return
    end
    if state.lastTooltipText ~= text then
        state.tooltipAt = os.clock()
    end
    state.tooltipText = text
    state.tooltipX = x
    state.tooltipY = y
end

local function renderTooltip()
    local textValue = state.tooltipText
    if not textValue or os.clock() - state.tooltipAt < 0.35 then
        return
    end

    local width = math.min(260, textWidth(textValue, 12) + 16)
    local x = state.tooltipX + 12
    local y = state.tooltipY + 18
    local vw, vh = viewportSize()
    x = clamp(x, 8, math.max(8, vw - width - 8))
    y = clamp(y, 8, math.max(8, vh - 32))

    rect(x, y, width, 28, theme.black, 140, 6, 0.92)
    strokeRect(x, y, width, 28, theme.border, 141, 6)
    txt(textValue, x + 8, textTop(y, 28, 12), theme.text, 12, font_ui, 142, false, false, width - 16)
end

local function renderDropdown(click, rightClick)
    local dd = state.dropdown
    if not dd then
        return click, rightClick
    end

    local isMulti = dd.multi == true
    local headerH = 0
    local maxRows = math.floor((dd.h - 6 - headerH) / 22)
    dd.scrollOffset = dd.scrollOffset or 0

    local isHoveredDropdown = over(dd.x - 4, dd.y - 4, dd.w + 8, dd.h + 8)
    if isHoveredDropdown then
        if state.mouseScroll ~= 0 then
            dd.scrollOffset = clamp(dd.scrollOffset - (state.mouseScroll > 0 and 1 or -1), 0, math.max(0, #dd.choices - maxRows))
        end
        if input.down.click then
            dd.scrollOffset = math.min(#dd.choices - maxRows, dd.scrollOffset + 1)
        elseif input.up.click then
            dd.scrollOffset = math.max(0, dd.scrollOffset - 1)
        elseif input.pagedown.click then
            dd.scrollOffset = math.min(#dd.choices - maxRows, dd.scrollOffset + maxRows)
        elseif input.pageup.click then
            dd.scrollOffset = math.max(0, dd.scrollOffset - maxRows)
        end
    end
    dd.scrollOffset = clamp(dd.scrollOffset, 0, math.max(0, #dd.choices - maxRows))

    rect(dd.x - 1, dd.y - 1, dd.w + 2, dd.h + 2, theme.border, 110, 4)
    rect(dd.x, dd.y, dd.w, dd.h, theme.surface, 111, 4)

    if dd.scrollOffset > 0 then
        triangle(Vector2.new(dd.x + dd.w - 14, dd.y + headerH + 8), Vector2.new(dd.x + dd.w - 6, dd.y + headerH + 8), Vector2.new(dd.x + dd.w - 10, dd.y + headerH + 4), theme.sub, 115, true)
    end
    if dd.scrollOffset + maxRows < #dd.choices then
        triangle(Vector2.new(dd.x + dd.w - 14, dd.y + dd.h - 8), Vector2.new(dd.x + dd.w - 6, dd.y + dd.h - 8), Vector2.new(dd.x + dd.w - 10, dd.y + dd.h - 4), theme.sub, 115, true)
    end

    for idx = 1, math.min(#dd.choices, maxRows) do
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
            rect(dd.x + 2, rowY, dd.w - 4, 22, hovered and theme.surface3 or theme.surface2, 112, 3)
        end
        local textX = dd.x + 10
        if selected then
            textX = dd.x + 20
            rect(dd.x + 10, rowY + 5, 2, 12, theme.accent, 114)
        end

        local isDeletable = dd.item and dd.item.deletable
        local textMaxW = dd.w - 24 - (isDeletable and 20 or 0)
        txt(tostring(choice), textX, textTop(rowY, 22, 13), selected and theme.accent or theme.text, 13, font_system, 113, false, false, textMaxW)

        if isDeletable then
            local trashW = 18
            local trashBtnX = dd.x + dd.w - trashW - 2
            local trashHovered = over(trashBtnX, rowY + 2, trashW, 18)
            if hovered or trashHovered then
                rect(trashBtnX, rowY + 2, trashW, 18, trashHovered and theme.surface or theme.surface2, 113, 3)
                drawTrashIcon(trashBtnX + 4, rowY + 4, trashHovered and theme.red or theme.sub, 114, 1)
            end
            if click and trashHovered then
                if dd.item.onDelete then dd.item.onDelete(choice) end
                dd.choices = copyArray(dd.item.choices)
                dd.value = copyArray(dd.item.value)
                dd.scrollOffset = clamp(dd.scrollOffset, 0, math.max(0, #dd.choices - maxRows))
                return false
            end
        end

        if click and hovered and not (isDeletable and over(dd.x + dd.w - 20, rowY + 2, 18, 18)) then
            if dd.kind == "keymode" then
                dd.keybind.mode = choice
                safeCallback(dd.keybind.callback, dd.keybind.value and input[dd.keybind.value] and input[dd.keybind.value].id or nil, dd.keybind.mode)
                state.dropdown = nil
            elseif dd.multi then
                if dd.item then
                    local newValue = copyArray(dd.value)
                    if selected then
                        for vi = #newValue, 1, -1 do
                            if newValue[vi] == choice then
                                table.remove(newValue, vi)
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
                                table.remove(dd.value, vi)
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
                state.dropdown = nil
            end
            return false, rightClick
        end
    end

    if isMulti and rightClick and isHoveredDropdown then
        if not dd._ctxMenu then
            dd._ctxMenu = true
            dd._ctxY = clamp(state.mouseY, dd.y, dd.y + dd.h - 44)
        end
        rightClick = false
    end

    if dd._ctxMenu then
        local ctxX = dd.x
        local ctxY = dd._ctxY or dd.y
        local ctxW = dd.w
        rect(ctxX, ctxY, ctxW, 44, theme.surface2, 116, 4)
        strokeRect(ctxX, ctxY, ctxW, 44, theme.border, 117, 4)

        local hoverAll = over(ctxX + 2, ctxY + 2, ctxW - 4, 18)
        local hoverClear = over(ctxX + 2, ctxY + 24, ctxW - 4, 18)

        rect(ctxX + 2, ctxY + 2, ctxW - 4, 18, hoverAll and theme.surface3 or theme.surface, 117, 3)
        txt("Select All", ctxX + 10, ctxY + 4, hoverAll and theme.accent or theme.text, 12, font_ui, 118)
        rect(ctxX + 2, ctxY + 24, ctxW - 4, 18, hoverClear and theme.surface3 or theme.surface, 117, 3)
        txt("Clear All", ctxX + 10, ctxY + 26, hoverClear and theme.accent or theme.text, 12, font_ui, 118)

        if click then
            if hoverAll then
                if dd.item then
                    setDropdownValue(dd.item, dd.choices, true)
                else
                    for vi = #dd.value, 1, -1 do dd.value[vi] = nil end
                    for ci = 1, #dd.choices do dd.value[ci] = dd.choices[ci] end
                    safeCallback(dd.callback, dd.value)
                end
                dd._ctxMenu = nil
                click = false
            elseif hoverClear then
                if dd.item then
                    setDropdownValue(dd.item, {}, true)
                else
                    for vi = #dd.value, 1, -1 do dd.value[vi] = nil end
                    safeCallback(dd.callback, dd.value)
                end
                dd._ctxMenu = nil
                click = false
            else
                dd._ctxMenu = nil
            end
        end
    end

    if click and not isHoveredDropdown then
        state.dropdown = nil
        return false, rightClick
    end

    return click, rightClick
end

local function renderColorpicker(click, held)
    local cp = state.colorpicker
    if not cp then
        return click
    end

    local x, y, w, h = cp.x, cp.y, cp.w, cp.h

    if click and over(x, y, w, 24) then
        state.cpDrag = { state.mouseX - x, state.mouseY - y }
        click = false
    end

    if held and state.cpDrag then
        cp.x = state.mouseX - state.cpDrag[1]
        cp.y = state.mouseY - state.cpDrag[2]
        local szX, szY = viewportSize()
        cp.x = clamp(cp.x, 0, szX - w)
        cp.y = clamp(cp.y, 0, szY - h)
        if szX < 0 or szY < 0 then
            szX = 0
        end
        x, y = cp.x, cp.y
    else
        state.cpDrag = nil
    end

    rect(x, y, w, h, theme.surface2, 110, 8)
    strokeRect(x, y, w, h, theme.border, 111, 8)
    txt(cp.picker.label, x + 10, y + 8, theme.text, 13, font_bold, 112, false, false, w - 20)

    local palX, palY = x + 10, y + 28
    local palW, palH = 160, 160

    rect(palX, palY, palW, palH, theme.surface, 112, 8)
    local cpSquares = state.cpPaletteSquares
    if not cpSquares then
        cpSquares = {}
        state.cpPaletteSquares = cpSquares
    end
    local hueChanged = (state.cpLastHue ~= cp.hue)
    state.cpLastHue = cp.hue
    if #cpSquares == 0 then
        for gx = 3, palW - 4, 4 do
            for gy = 3, palH - 4, 4 do
                local sq = Drawing.new("Square")
                sq.Size = Vector2.new(math.math.min(4, palW - 3 - gx), math.math.min(4, palH - 3 - gy))
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
        cell.obj.Position = Vector2.new(palX + cell.relX, palY + cell.relY)
        if hueChanged or not cell.initialized then
            cell.obj.Color = Color3.fromHSV(cp.hue, cell.sx, cell.sy)
            cell.initialized = true
        end
        cell.obj.Visible = true
    end

    if held and over(palX, palY, palW, palH) then
        cp.sat = clamp((state.mouseX - palX) / palW, 0, 1)
        cp.val = 1 - clamp((state.mouseY - palY) / palH, 0, 1)
    end

    circle(palX + cp.sat * palW, palY + (1 - cp.val) * palH, 4, theme.white, 116, false, 2, 20)

    local hueX, hueY = x + 178, y + 28
    local hueW, hueH = 12, 160
    rect(hueX, hueY, hueW, hueH, theme.surface, 112, 6)
    for gy = hueY + 2, hueY + hueH - 3, 4 do
        rect(hueX + 2, gy, hueW - 4, math.min(4, hueY + hueH - 2 - gy), Color3.fromHSV((gy - hueY) / hueH, 1, 1), 113, 0)
    end

    if held and over(hueX, hueY, hueW, hueH) then
        cp.hue = clamp((state.mouseY - hueY) / hueH, 0, 1)
    end

    rect(hueX - 1, hueY + cp.hue * hueH - 2, hueW + 2, 4, theme.white, 116, 1)

    local alphaX, alphaY = x + 198, y + 28
    local alphaW, alphaH = 12, 160
    rect(alphaX, alphaY, alphaW, alphaH, theme.surface, 112, 6)
    for gy = alphaY + 2, alphaY + alphaH - 3, 6 do
        local blockH = math.min(6, alphaY + alphaH - 2 - gy)
        rect(alphaX + 2, gy, 4, blockH, (math.floor((gy - alphaY) / 6) % 2 == 0) and theme.white or Color3.fromRGB(200, 200, 200), 113, 0)
        rect(alphaX + 6, gy, 4, blockH, (math.floor((gy - alphaY) / 6) % 2 == 0) and Color3.fromRGB(200, 200, 200) or theme.white, 113, 0)
    end

    for gy = alphaY + 2, alphaY + alphaH - 3, 4 do
        rect(alphaX + 2, gy, alphaW - 4, math.min(4, alphaY + alphaH - 2 - gy), cp.value, 114, 0, 1 - ((gy - alphaY) / alphaH))
    end

    strokeRect(palX, palY, palW, palH, theme.border, 115, 8)
    strokeRect(hueX, hueY, hueW, hueH, theme.border, 115, 6)
    strokeRect(alphaX, alphaY, alphaW, alphaH, theme.border, 115, 6)

    if held and over(alphaX, alphaY, alphaW, alphaH) then
        cp.alpha = 1 - clamp((state.mouseY - alphaY) / alphaH, 0, 1)
    end

    rect(alphaX - 1, alphaY + (1 - cp.alpha) * alphaH - 2, alphaW + 2, 4, theme.white, 116, 1)

    rect(x + 10, y + 196, 200, 22, (state.focus == cp) and theme.surface or over(x + 10, y + 196, 200, 22) and theme.surface3 or theme.surface2, 114, 4)
    strokeRect(x + 10, y + 196, 200, 22, (state.focus == cp) and theme.accent or theme.border, 115, 4)

    local isFocusedCP = state.focus == cp
    local hexText = isFocusedCP and (cp._hexInput or "") or ("#" .. toHex(cp.value))
    txt(hexText, x + 16, textTop(y + 196, 22, 12), theme.text, 12, font_ui, 116, false, false, 188)
    if isFocusedCP then
        txt("|", x + 16 + textWidth(hexText, 12, font_ui), textTop(y + 196, 22, 12), theme.text, 12, font_ui, 117, false, false, nil, clamp(0.5 + 0.5 * math.math.sin(os.clock() * 8), 0, 1))
    end

    if click and over(x + 10, y + 196, 200, 22) then
        state.focus = (state.focus == cp) and nil or cp
        cp._hexInput = toHex(cp.value)
        click = false
    end

    rect(x + 10, y + 228, 60, 22, theme.surface, 114, 4)
    strokeRect(x + 10, y + 228, 60, 22, theme.border, 115, 4)
    txt("R", x + 16, textTop(y + 228, 22, 12), Color3.fromRGB(255, 69, 58), 12, font_bold, 116)
    txt(tostring(math.floor(cp.value.R * 255 + 0.5)), x + 64 - textWidth(tostring(math.floor(cp.value.R * 255 + 0.5)), 12, font_ui), textTop(y + 228, 22, 12), theme.text, 12, font_ui, 116)

    rect(x + 80, y + 228, 60, 22, theme.surface, 114, 4)
    strokeRect(x + 80, y + 228, 60, 22, theme.border, 115, 4)
    txt("G", x + 86, textTop(y + 228, 22, 12), Color3.fromRGB(52, 199, 89), 12, font_bold, 116)
    txt(tostring(math.floor(cp.value.G * 255 + 0.5)), x + 134 - textWidth(tostring(math.floor(cp.value.G * 255 + 0.5)), 12, font_ui), textTop(y + 228, 22, 12), theme.text, 12, font_ui, 116)

    rect(x + 150, y + 228, 60, 22, theme.surface, 114, 4)
    strokeRect(x + 150, y + 228, 60, 22, theme.border, 115, 4)
    txt("B", x + 156, textTop(y + 228, 22, 12), Color3.fromRGB(0, 122, 255), 12, font_bold, 116)
    txt(tostring(math.floor(cp.value.B * 255 + 0.5)), x + 204 - textWidth(tostring(math.floor(cp.value.B * 255 + 0.5)), 12, font_ui), textTop(y + 228, 22, 12), theme.text, 12, font_ui, 116)

    local final = Color3.fromHSV(cp.hue, cp.sat, cp.val)
    if colorChanged(final, cp.value) or (cp.alpha ~= cp.picker.alpha) then
        cp.value = final
        cp.picker.value = final
        cp.picker.alpha = cp.alpha
        safeCallback(cp.picker.callback, final, cp.alpha)
    end

    if click and not over(x, y, w, h) then
        if state.focus == cp then
            state.focus = nil
        end
        state.colorpicker = nil
        state.cpDrag = nil
        return false
    end

    return click
end

local function renderWatermark(click, held)
    if not state.watermarkEnabled then
        return
    end
    
    local title = state.watermarkTitle ~= "" and state.watermarkTitle or state.title or "homesick"
    local text = state.activityText ~= "" and (title .. " | " .. state.activityText) or title
    
    local w = textWidth(text, 12, font_ui) + 20
    local h = 24
    local x = state.watermarkX or 20
    local y = state.watermarkY or 20
    
    local hovered = over(x, y, w, h)
    if click and hovered then
        state.watermarkDrag = {state.mouseX - x, state.mouseY - y}
    end
    
    if held and state.watermarkDrag then
        state.watermarkX = state.mouseX - state.watermarkDrag[1]
        state.watermarkY = state.mouseY - state.watermarkDrag[2]
        
        local vw, vh = viewportSize()
        state.watermarkX = clamp(state.watermarkX, 0, vw - w)
        state.watermarkY = clamp(state.watermarkY, 0, vh - h)
        
        x = state.watermarkX
        y = state.watermarkY
    elseif not held then
        state.watermarkDrag = nil
    end
    
    rect(x, y, w, h, theme.surface, 150, 6, 0.85)
    strokeRect(x, y, w, h, theme.accent, 151, 6)
    txt(text, x + 10, textTop(y, h, 12), theme.text, 12, font_ui, 152, false, false)
end

local function renderTabs(click, px, py, pw)
    local count = #state.tabs
    if count == 0 then
        return click
    end

    local totalW = count * 80
    local needsScroll = totalW > pw
    local tabW = needsScroll and 80 or (pw / count)
    local maxScroll = math.max(0, totalW - pw)

    local dtValue = state.dt or 1 / 60
    if dtValue <= 0 then dtValue = 1 / 60 end
    local target = clamp(state.tabTargetScrollX or 0, 0, maxScroll)
    state.tabTargetScrollX = target
    local current = state.tabScrollX or 0
    local factor = 1 - math.exp(-18 * dtValue)
    current = current + (target - current) * factor
    current = clamp(current, 0, maxScroll)
    state.tabScrollX = current
    local scrollX = current

    local contentX = px + (needsScroll and 18 or 0)
    local contentW = pw - (needsScroll and 36 or 0)

    if needsScroll and scrollX > 1 then
        local arrowHovered = over(px, py, 18, 30)
        rect(px, py, 18, 30, arrowHovered and theme.surface3 or theme.surface, 26, 0)
        local cy = centerY(py, 30)
        triangle(Vector2.new(px + 6, cy), Vector2.new(px + 12, cy - 4), Vector2.new(px + 12, cy + 4), theme.sub, 27, true)
        if click and arrowHovered then
            state.tabTargetScrollX = math.max(0, target - 80)
            click = false
        end
    end

    if needsScroll and scrollX < maxScroll - 1 then
        local ax = px + pw - 18
        local arrowHovered = over(ax, py, 18, 30)
        rect(ax, py, 18, 30, arrowHovered and theme.surface3 or theme.surface, 26, 0)
        local cy = centerY(py, 30)
        triangle(Vector2.new(ax + 12, cy), Vector2.new(ax + 6, cy - 4), Vector2.new(ax + 6, cy + 4), theme.sub, 27, true)
        if click and arrowHovered then
            state.tabTargetScrollX = math.min(maxScroll, target + 80)
            click = false
        end
    end

    if needsScroll and state.tabScrollToActive and state.activeTab then
        local idx = state.activeIndex or 1
        local tabStart = tabW * (idx - 1)
        local tabEnd = tabStart + tabW
        local visibleStart = scrollX
        local visibleEnd = scrollX + contentW
        if tabStart < visibleStart then
            state.tabTargetScrollX = tabStart
        elseif tabEnd > visibleEnd then
            state.tabTargetScrollX = tabEnd - contentW
        end
        state.tabScrollToActive = false
    end

    if input.m1.released then
        state.draggedTab = nil
    end

    for i = 1, count do
        local tab = state.tabs[i]
        local localTx = tabW * (i - 1)
        tab.targetX = localTx
        if not tab.currentX then
            tab.currentX = localTx
        end

        local active = state.activeTab == tab
        local screenX = contentX + tab.currentX - scrollX
        local hovered = over(screenX, py, tabW, 30)

        if click and hovered and not state.draggedTab then
            if state.activeTab ~= tab then
                state.contentFade = 0
            end
            state.activeTab = tab
            state.activeIndex = i
            state.dropdown = nil
            state.colorpicker = nil
            state.focus = nil
            click = false
            state.tabScrollToActive = true
        end

        if state.draggedTab == tab then
            if math.abs(state.mouseX - state.dragTabStartMouseX) > 5 then
                tab.currentX = clamp(state.mouseX - state.draggedTabOffset - contentX + scrollX, 0, totalW - tabW)

                local idx = i
                if idx > 1 then
                    local prevTab = state.tabs[idx - 1]
                    if tab.currentX < prevTab.currentX then
                        state.tabs[idx], state.tabs[idx - 1] = state.tabs[idx - 1], state.tabs[idx]
                        if state.activeIndex == idx then
                            state.activeIndex = idx - 1
                        elseif state.activeIndex == idx - 1 then
                            state.activeIndex = idx
                        end
                    end
                end
                if idx < count then
                    local nextTab = state.tabs[idx + 1]
                    if tab.currentX > nextTab.currentX then
                        state.tabs[idx], state.tabs[idx + 1] = state.tabs[idx + 1], state.tabs[idx]
                        if state.activeIndex == idx then
                            state.activeIndex = idx + 1
                        elseif state.activeIndex == idx + 1 then
                            state.activeIndex = idx
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
        local tab = state.tabs[i]
        local tx = contentX + tab.currentX - scrollX
        local visible = tx + tabW >= contentX and tx <= contentX + contentW
        if visible then
            local active = state.activeTab == tab
            local hovered = over(tx, py, tabW, 30)
            
            if active then
                targetPillX = tab.currentX - scrollX + 4
                targetPillW = tabW - 8
                txt(tab.name, tx + tabW / 2, centerY(py, 30), theme.text, 13, font_bold, 25, true, false, tabW - 12)
            else
                txt(tab.name, tx + tabW / 2, centerY(py, 30), hovered and theme.text or theme.sub, 13, font_system, 25, true, false, tabW - 12)
            end
        end
    end

    if targetPillX and targetPillW then
        if not state.currentPillX then
            state.currentPillX = targetPillX
            state.currentPillW = targetPillW
        elseif state.tabAnimations == false then
            state.currentPillX = targetPillX
            state.currentPillW = targetPillW
        else
            state.currentPillX = smoothValue(state.currentPillX, targetPillX, 18)
            state.currentPillW = smoothValue(state.currentPillW, targetPillW, 18)
        end
    end

    if state.currentPillX and state.currentPillW then
        rect(contentX + state.currentPillX, py + 3, state.currentPillW, 30 - 6, theme.accent, 21, 10, 0.08)
        strokeRect(contentX + state.currentPillX, py + 3, state.currentPillW, 30 - 6, theme.accent, 22, 10)
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

        rect(keyX, rowY + 3, 46, 20, theme.surface3, 45, 4, trans)
        strokeRect(keyX, rowY + 3, 46, 20, hovered and theme.accent or theme.border, 46, 4, trans)

        txt(item.keybind.listening and "..." or (item.keybind.value and string.upper(item.keybind.value) or "-"), keyX + 23, centerY(rowY + 3, 20), item.keybind.value and theme.text or theme.sub, 12, font_ui, 52, true, false, 42, trans)

        txt(item.keybind.mode == "Toggle" and "T" or item.keybind.mode == "Always" and "A" or "H", keyX - 8, centerY(rowY, 28 - 2), item.keybind.mode == "Hold" and theme.sub or theme.accent, 10, font_ui, 52, true, false, nil, trans)

        if item.keybind.listening then
            for i = 1, #input_order do
                local name = input_order[i]
                local input = input[name]
                if input.click and (name ~= "m1" or os.clock() - item.keybind.listenAt > 0.25) then
                    local newKey = normalizeKey(name)
                    if name == "backspace" or name == "delete" or name == "unbound" or name == "esc" then
                        newKey = nil
                    end
                    item.keybind.value = newKey
                    item.keybind.listening = false
                    safeCallback(item.keybind.callback, newKey and input[newKey] and input[newKey].id or nil, item.keybind.mode)
                    break
                end
            end
        elseif click and hovered then
            item.keybind.listening = true
            item.keybind.listenAt = os.clock()
            click = false
        elseif rightClick and hovered and item.keybind.canChange then
            dDropdown("keymode", keyX, rowY + 24, 90, keybind_modes, nil, false, nil, nil, item.keybind)
            rightClick = false
        end
        currentX = currentX - 14
    end

    if item.colorpicker then
        currentX = currentX - 16
        local cpX = currentX
        local hovered = over(cpX - 3, rowY + 5, 18, 18)

        rect(cpX, rowY + 8, 12, 12, item.colorpicker.value, 46, 3, trans * (item.colorpicker.alpha or 1))
        strokeRect(cpX, rowY + 8, 12, 12, theme.border, 47, 3, trans)

        if hovered then
            strokeRect(cpX - 2, rowY + 6, 16, 16, theme.accent, 48, 4, trans)
        end

        if click and hovered then
            doColorPicker(state.mouseX + 14, state.mouseY - 90, item.colorpicker)
            click = false
        elseif rightClick and hovered then
            dDropdown("colorctx", cpX - 34, rowY + 24, 80, {"Copy", "Paste"}, {}, false, function(choice)
                if choice and choice[1] == "Copy" then
                    state.copiedColor = item.colorpicker.value
                    pcall(setclipboard, "#" .. toHex(item.colorpicker.value))
                elseif choice and choice[1] == "Paste" then
                    if state.copiedColor and colorChanged(item.colorpicker.value, state.copiedColor) then
                        item.colorpicker.value = state.copiedColor
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
        local labelLines = wrapLines(item.label, rowW or 1000, 13, font_system)
        item._cachedLineCount = #labelLines
        return math.math.max(28, #labelLines * 16 + 8)
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
        return colX + colW - 8 + math.cos(t) * 8, renderY + 8 + math.math.sin(t) * 8
    elseif d < colW + renderH - 19.434 then
        return colX + colW, renderY + 8 + (d - (colW - 3.434))
    elseif d < colW + renderH - 6.868 then
        local t = (d - (colW + renderH - 19.434)) / 12.566 * 1.5708
        return colX + colW - 8 + math.cos(t) * 8, renderY + renderH - 8 + math.math.sin(t) * 8
    elseif d < 2 * colW + renderH - 22.868 then
        return colX + colW - 8 - (d - (colW + renderH - 6.868)), renderY + renderH
    elseif d < 2 * colW + renderH - 10.302 then
        local t = 1.5708 + (d - (2 * colW + renderH - 22.868)) / 12.566 * 1.5708
        return colX + 8 + math.cos(t) * 8, renderY + renderH - 8 + math.math.sin(t) * 8
    elseif d < 2 * colW + 2 * renderH - 26.302 then
        return colX, renderY + renderH - 8 - (d - (2 * colW + renderH - 10.302))
    else
        local t = 3.1416 + (d - (2 * colW + 2 * renderH - 26.302)) / 12.566 * 1.5708
        return colX + 8 + math.cos(t) * 8, renderY + 8 + math.math.sin(t) * 8
    end
end

local function renderSectionCard(section, colX, sy, colW, secH, clipTop, clipBottom, click, held, rightClick, isPlaceholder, isFloating)
    local popupBlocking = state.dropdown ~= nil or state.colorpicker ~= nil or isFloating
    local z = isFloating and 90 or 30
    local cardTrans = isFloating and (0.75 * (state.contentFade or 1)) or (state.contentFade or 1)
    local cardClipTop = isFloating and (state.y + 36) or clipTop
    local cardClipBottom = isFloating and (state.y + state.h - 24) or clipBottom
    local renderY = math.max(sy, cardClipTop)
    local renderH = math.min(sy + secH, cardClipBottom) - renderY

    if renderH > 0 then
        if isPlaceholder then
            rect(colX, renderY, colW, renderH, theme.surface, z, 8, 0.25 * cardTrans)
            strokeRect(colX, renderY, colW, renderH, theme.border, z + 1, 8, 0.4 * cardTrans)
            return click, held, rightClick
        end

        rect(colX, renderY, colW, renderH, theme.surface2, z, 8, cardTrans)
        strokeRect(colX, renderY, colW, renderH, theme.border, z + 1, 8, cardTrans)

        local cx = clamp(state.mouseX, colX, colX + colW)
        local cy = clamp(state.mouseY, renderY, renderY + renderH)
        if state.mouseX > colX and state.mouseX < colX + colW and state.mouseY > renderY and state.mouseY < renderY + renderH then
            if math.min(math.abs(state.mouseX - colX), math.abs(state.mouseX - (colX + colW)), math.abs(state.mouseY - renderY), math.abs(state.mouseY - (renderY + renderH))) == math.abs(state.mouseX - colX) then
                cx = colX
            elseif math.min(math.abs(state.mouseX - colX), math.abs(state.mouseX - (colX + colW)), math.abs(state.mouseY - renderY), math.abs(state.mouseY - (renderY + renderH))) == math.abs(state.mouseX - (colX + colW)) then
                cx = colX + colW
            elseif math.min(math.abs(state.mouseX - colX), math.abs(state.mouseX - (colX + colW)), math.abs(state.mouseY - renderY), math.abs(state.mouseY - (renderY + renderH))) == math.abs(state.mouseY - renderY) then
                cy = renderY
            else
                cy = renderY + renderH
            end
        end

        if cy == renderY + renderH and clamp(1 - (math.sqrt((state.mouseX - cx)^2 + (state.mouseY - cy)^2) / 80), 0, 1) > 0 then
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
                    line(x1, y1, x2, y2, section.locked and theme.sub or theme.accent, z + 2, 2, clamp(1 - (math.abs(-40 + (i - 0.5) * 3.333) / 40), 0, 1) * clamp(1 - (math.sqrt((state.mouseX - cx)^2 + (state.mouseY - cy)^2) / 80), 0, 1) * cardTrans)
                end
            end
        end
        
        local headerTrans = clamp((math.min(sy + 28, cardClipBottom) - math.max(sy, cardClipTop)) / 28, 0, 1)
        if headerTrans > 0 then
            local hTrans = cardTrans * headerTrans
            txt(section.name, colX + 12, sy + 8, theme.accent, 13, font_bold, z + 2, false, false, nil, hTrans)
            
            local showLock = section.allowLocking ~= false
            
            local iconY = sy + 9
            draw9Dot(colX + colW - 20, sy + 10, (showLock and section.locked) and Color3.fromRGB(80, 75, 73) or theme.sub, z + 2, hTrans)
            if showLock then
                drawLockIcon(colX + colW - 38, iconY, section.locked and theme.accent or theme.sub, z + 2, section.locked and hTrans or hTrans * 0.5, not section.locked)
            end

            if section.name == "Configs" or section.name == "Themes" then
                local expX = colX + colW - 54
                local expHovered = not popupBlocking and over(expX - 2, sy + 4, 14, 20) and headerTrans > 0.5
                local expColor = expHovered and theme.accent or theme.sub
                drawExportIcon(expX - 2, iconY, expColor, z + 2, hTrans * (expHovered and 1 or 0.6))

                local impX = colX + colW - 70
                local impHovered = not popupBlocking and over(impX - 2, sy + 4, 14, 20) and headerTrans > 0.5
                local impColor = impHovered and theme.accent or theme.sub
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
                        state.importModal = {
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
                        state.focus = modalTextbox
                    end
                end
            end

            if not isFloating and headerTrans > 0.5 then
                if showLock and click and over(colX + colW - 38, sy + 6, 12, 12) and not popupBlocking then
                    section.locked = not section.locked
                    click = false
                end

                if click and over(colX + colW - 22, sy + 8, 14, 14) and not popupBlocking and not section.locked then
                    state.draggedSection = section
                    state.dragOffset = {state.mouseX - colX, state.mouseY - sy}
                    state.dragStartMouseX = state.mouseX
                    state.draggedSectionOriginalSide = section.side
                    click = false
                end
            end
        end

        if not isFloating then
            if click and over(colX, sy + secH - 4, colW, 8) and not popupBlocking and not section.locked and (sy + secH - 4 >= cardClipTop) and (sy + secH <= cardClipBottom) then
                state.resizeSection = section
                state.resizeSectionStartH = secH
                state.resizeSectionStartMouseY = state.mouseY
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
            local trans = (disabled and 0.4 or 1) * cardTrans * math.min(clamp((rowY - cardClipTop) / 16, 0, 1), clamp((cardClipBottom - (rowY + itemH)) / 16, 0, 1))
            if rowY + itemH > sy + secH - 4 then
                trans = 0
            end
            
            if trans > 0 then
                if item.type == "label" then
                    local labelLines = wrapLines(item.label, rowW, 13, font_system)
                    item._cachedLineCount = #labelLines
                    for li = 1, #labelLines do
                        txt(labelLines[li], rowX, rowY + (li - 1) * 16 + 4, item.color or theme.text, 13, font_system, z + 12, false, false, rowW, trans)
                    end
                    
                elseif item.type == "checkbox" then
                    local targetAnim = item.value and 1 or 0
                    if state.hoverEffects == false then
                        item.animState = targetAnim
                    else
                        item.animState = smoothValue(item.animState or targetAnim, targetAnim, 18)
                    end
                    local cbX, cbY = rowX + 4, rowY + 6
                    rect(cbX, cbY, 14, 14, theme.surface3, z + 12, 4, trans)
                    strokeRect(cbX, cbY, 14, 14, theme.border, z + 13, 4, trans)
                    
                    if item.animState > 0.05 then
                        local offset = 7 * (1 - item.animState)
                        rect(cbX + offset, cbY + offset, 14 * item.animState, 14 * item.animState, theme.accent, z + 14, 4 * item.animState, trans)
                    end
                    
                    local cbExtra = 6
                    if item.colorpicker then cbExtra = cbExtra + 20 end
                    if item.keybind then cbExtra = cbExtra + 64 end
                    if item.tooltip then cbExtra = cbExtra + 18 end
                    txt(item.label, rowX + 26, textTop(rowY, itemH - 2, 13), item.unsafe and theme.unsafe or (item.value and theme.text or theme.sub), 13, font_system, z + 12, false, false, rowW - 26 - cbExtra, trans)
                    
                    if not isFloating then
                        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
                    end
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 6, 12, 12)
                        txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), qHovered and theme.accent or theme.sub, 13, font_system, z + 12, false, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, state.mouseX, state.mouseY)
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
                    rect(tgX, tgY + 1, 24, 12, lerpColor(theme.surface3, theme.accent, item.animState), z + 12, 6, trans)
                    strokeRect(tgX, tgY + 1, 24, 12, lerpColor(theme.border, theme.accent, item.animState), z + 13, 6, trans)
                    circle(tgX + 6 + 12 * item.animState, tgY + 7, 4, theme.text, z + 14, true, 0, 32, trans)
                    
                    local tgExtra = 16
                    if item.colorpicker then tgExtra = tgExtra + 20 end
                    if item.keybind then tgExtra = tgExtra + 64 end
                    if item.tooltip then tgExtra = tgExtra + 18 end
                    txt(item.label, rowX + 36, textTop(rowY, itemH - 2, 13), item.unsafe and theme.unsafe or (item.value and theme.text or theme.sub), 13, font_system, z + 12, false, false, rowW - 36 - tgExtra, trans)
                    
                    if not isFloating then
                        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
                    end
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 6, 12, 12)
                        txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), qHovered and theme.accent or theme.sub, 13, font_system, z + 12, false, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, state.mouseX, state.mouseY)
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
                    txt(item.label, rowX + 4, textTop(rowY, itemH - 2, 13), theme.text, 13, font_system, z + 12, false, false, rowW - 28, trans)
                    local cpX = rowX + rowW - 16
                    local hovered = over(cpX - 3, rowY + 5, 18, 18)
                    rect(cpX, rowY + 8, 12, 12, item.value, z + 12, 3, trans * (item.alpha or 1))
                    strokeRect(cpX, rowY + 8, 12, 12, theme.border, z + 13, 3, trans)
                    if hovered then
                        strokeRect(cpX - 2, rowY + 6, 16, 16, theme.accent, z + 14, 4, trans)
                    end
                    if click and hovered and not popupBlocking and not disabled and trans > 0.5 then
                        doColorPicker(state.mouseX + 14, state.mouseY - 90, item)
                        click = false
                    elseif rightClick and hovered and not popupBlocking and not disabled and trans > 0.5 then
                        dDropdown("colorctx", cpX - 34, rowY + 24, 80, {"Copy", "Paste"}, {}, false, function(choice)
                            if choice and choice[1] == "Copy" then
                                state.copiedColor = item.value
                                pcall(setclipboard, "#" .. toHex(item.value))
                            elseif choice and choice[1] == "Paste" then
                                if state.copiedColor and colorChanged(item.value, state.copiedColor) then
                                    item.value = state.copiedColor
                                    safeCallback(item.callback, item.value)
                                else
                                    warn("color clipboard empty lol")
                                end
                            end
                        end, nil, nil)
                        rightClick = false
                    end
 
                elseif item.type == "slider" then
                    txt(item.label, rowX + 4, rowY + 2, theme.text, 13, font_system, z + 12, false, false, rowW - 80, trans)
                    
                    local isFocusedSlider = state.focus == item
                    local valStr = isFocusedSlider and (item._directValue or "") or tostring(item.value)
                    local boxW = math.max(36, textWidth(isFocusedSlider and valStr or (valStr .. tostring(item.suffix or "")), 12, font_ui) + 12)
                    local valBoxX = rowX + rowW - boxW - 4
                    local valBoxY = rowY + 1
                    local hoveredVal = over(valBoxX, valBoxY, boxW, 16) and not popupBlocking and not disabled
                    
                    if isFocusedSlider then
                        rect(valBoxX, valBoxY, boxW, 16, theme.surface, z + 12, 4, trans)
                        strokeRect(valBoxX, valBoxY, boxW, 16, theme.accent, z + 13, 4, trans)
                    end
                    txt(isFocusedSlider and valStr or (valStr .. tostring(item.suffix or "")), valBoxX + boxW / 2, rowY + 9, theme.text, 12, font_ui, z + 14, true, false, boxW - 4, trans)
                    if isFocusedSlider then
                        txt("|", valBoxX + boxW / 2 + textWidth(valStr, 12, font_ui) / 2, rowY + 9, theme.text, 12, font_ui, z + 15, true, false, nil, trans * clamp(0.5 + 0.5 * math.math.sin(os.clock() * 8), 0, 1))
                    end
 
                    if click and hoveredVal and trans > 0.5 then
                        state.focus = item
                        item._directValue = tostring(item.value)
                        click = false
                    end
                    
                    local sx, sw = rowX + 4, rowW - 8
                    local sy_bar = rowY + 22
                    local denom = math.max(0.0001, (item.math.max or 100) - (item.math.min or 0))
                    local frac = clamp(((item.value or 0) - (item.math.min or 0)) / denom, 0, 1)
                    
                    rect(sx, sy_bar, sw, 4, theme.surface3, z + 12, 2, trans)
                    if frac > 0 then
                        rect(sx, sy_bar, sw * frac, 4, theme.accent, z + 13, 2, trans)
                    end
                    
                    item._animatedRadius = item._animatedRadius or 5
                    item._animatedRadius = smoothValue(item._animatedRadius, (hoveredVal or (over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled)) and 7 or 5, 18)
                    circle(sx + sw * frac, sy_bar + 2, item._animatedRadius, Color3.fromRGB(190, 190, 190), z + 14, true, 0, 32, trans)
                    
                    if click and over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled and not hoveredVal and trans > 0.5 then
                        state.sliderDrag = item
                        click = false
                    end
                    if held and not popupBlocking and not disabled and (state.sliderDrag == item) then
                        local snapped = snapValue((item.math.min or 0) + denom * clamp((state.mouseX - sx) / sw, 0, 1), item)
                        if snapped ~= item.value then
                            item.value = snapped
                            safeCallback(item.callback, snapped)
                        end
                    end
                    
                elseif item.type == "dropdown" then
                    txt(item.label, rowX + 4, rowY + 2, theme.text, 13, font_system, z + 12, false, false, rowW - 20, trans)
                    
                    local dx, dw = rowX + 4, rowW - 8
                    local dy_box = rowY + 18
                    local boxH = 22
                    
                    rect(dx, dy_box, dw, boxH, over(dx, dy_box, dw, boxH) and theme.surface3 or theme.surface2, z + 12, 4, trans)
                    strokeRect(dx, dy_box, dw, boxH, theme.border, z + 13, 4, trans)
                    
                    txt(item.multi and (#item.value > 0 and table.concat(item.value, ", ") or "-") or (item.value[1] or "-"), dx + 8, textTop(dy_box, boxH, 13), theme.text, 13, font_system, z + 14, false, false, dw - 28, trans)
                    
                    if state.dropdown and state.dropdown.item == item then
                        drawChevronUp(dx + dw - 15, centerY(dy_box, boxH) - 2, theme.sub, z + 15, trans)
                    else
                        drawChevronDown(dx + dw - 15, centerY(dy_box, boxH) - 2, theme.sub, z + 15, trans)
                    end
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 2, 12, 12)
                        txt("?", rowX + rowW - 10, rowY + 2, qHovered and theme.accent or theme.sub, 13, font_system, z + 12, false, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, state.mouseX, state.mouseY)
                        end
                    end
                    
                    if click and over(dx, dy_box, dw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
                        dDropdown("item", dx, dy_box + boxH, dw, item.choices, item.value, item.multi, item.callback, item, nil)
                        click = false
                    end
                    
                elseif item.type == "button" then
                    local controlY = rowY + 2
                    item._hoverFactor = smoothValue(item._hoverFactor or 0, (over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled) and 1 or 0, 18)
                    
                    rect(rowX + 4, controlY, rowW - 8, itemH - 4, theme.accent, z + 12, 6, trans * (0.1 + 0.15 * item._hoverFactor))
                    strokeRect(rowX + 4, controlY, rowW - 8, itemH - 4, theme.accent, z + 13, 6, trans * (0.4 + 0.6 * item._hoverFactor))
                    
                    txt(item.label, rowX + rowW / 2, centerY(controlY, itemH - 4), theme.accent, 13, font_bold, z + 14, true, false, rowW - 24, trans)
                    
                    if click and over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled and trans > 0.5 then
                        safeCallback(item.callback)
                        click = false
                    end
                    
                elseif item.type == "textbox" then
                    txt(item.label, rowX + 4, rowY + 2, theme.text, 13, font_system, z + 12, false, false, rowW - 20, trans)
                    
                    local bx, bw = rowX + 4, rowW - 8
                    local dy_box = rowY + 18
                    local boxH = 22
                    local focused = state.focus == item
                    
                    rect(bx, dy_box, bw, boxH, focused and theme.surface or over(bx, dy_box, bw, boxH) and theme.surface3 or theme.surface2, z + 12, 4, trans)
                    strokeRect(bx, dy_box, bw, boxH, focused and theme.accent or theme.border, z + 13, 4, trans)
                    
                    local is_empty = item.value == ""
                    local textTrans = (focused and is_empty) and trans * 0.2 or trans
                    txt(is_empty and item.label or item.value, bx + 8, textTop(dy_box, boxH, 13), is_empty and theme.sub or theme.text, 13, font_ui, z + 14, false, false, bw - 16, textTrans)
                    if focused then
                        if item._selectedAll and not is_empty then
                            rect(bx + 8, dy_box + 3, math.math.min(bw - 16, textWidth(item.value, 13, font_ui)), boxH - 6, theme.accent, z + 13, 2, trans * 0.4)
                        end
                        local cursorX = bx + 8
                        if not is_empty then
                            cursorX = cursorX + textWidth(item.value, 13, font_ui)
                        end
                        txt("|", cursorX, textTop(dy_box, boxH, 13), theme.text, 13, font_ui, z + 15, false, false, nil, trans * clamp(0.5 + 0.5 * math.math.sin(os.clock() * 8), 0, 1))
                    end
                    
                    if click and over(bx, dy_box, bw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
                        state.focus = focused and nil or item
                        click = false
                    end
                    
                elseif item.type == "divider" then
                    if item.label and item.label ~= "" then
                        local textW = textWidth(item.label, 11, font_system)
                        local lineW = math.max(4, (rowW - textW - 16) / 2)
                        local lineY = centerY(rowY, itemH)
                        rect(rowX, lineY, lineW, 1, theme.border, z + 12, 1, trans)
                        txt(item.label, rowX + lineW + 8, textTop(rowY, itemH, 11), theme.sub, 11, font_system, z + 13, false, false, textW + 4, trans)
                        rect(rowX + lineW + textW + 16, lineY, lineW, 1, theme.border, z + 12, 1, trans)
                    else
                        rect(rowX, centerY(rowY, itemH), rowW, 1, theme.border, z + 12, 1, trans)
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
        local colW = (sec.side == "Full") and pw or math.floor((pw - 10) / 2)
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
        local colW = (sec.side == "Full") and pw or math.floor((pw - 10) / 2)
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

    local contentH = math.max(leftTotal, rightTotal)
    local viewH = math.max(1, contH - 8 * 2)
    tab.maxScroll = math.max(0, contentH - viewH)
    tab.scrollY = tab.scrollY or 0
    tab.targetScrollY = clamp(tab.targetScrollY or tab.scrollY, 0, tab.maxScroll)
    local popupBlocking = state.dropdown ~= nil or state.colorpicker ~= nil

    if tab.maxScroll > 0 and not popupBlocking then
        if state.mouseScroll ~= 0 and over(state.x, state.y, state.w, state.h) then
            tab.targetScrollY = clamp(tab.targetScrollY - (state.mouseScroll > 0 and 1 or -1) * 28, 0, tab.maxScroll)
        end
        if not state.focus then
            if input.up.held then
                tab.targetScrollY = math.max(0, tab.targetScrollY - 12)
            end
            if input.down.held then
                tab.targetScrollY = math.min(tab.maxScroll, tab.targetScrollY + 12)
            end
            if input.pageup.click then
                tab.targetScrollY = math.max(0, tab.targetScrollY - viewH)
            end
            if input.pagedown.click then
                tab.targetScrollY = math.min(tab.maxScroll, tab.targetScrollY + viewH)
            end
            if input.home.click then
                tab.targetScrollY = 0
            end
            if input["end"].click then
                tab.targetScrollY = tab.maxScroll
            end
        end
    end

    local dtValue = state.dt or 1/60
    if dtValue <= 0 then dtValue = 1/60 end
    local factor = 1 - math.exp(-15 * dtValue)
    tab.scrollY = tab.scrollY + (tab.targetScrollY - tab.scrollY) * factor
    tab.scrollY = clamp(tab.scrollY, 0, tab.maxScroll)

    local sy = contY + 8 - tab.scrollY
    local clipTop = contY + 4
    local clipBottom = contY + contH - 4
    local colW = math.floor((pw - 10) / 2)
    local leftX = px
    local rightX = px + colW + 10

    local dragSec = state.draggedSection
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
                if not prevSec.locked and not dragSec.locked and state.mouseY < (prevSec.lastRenderY or 0) + (prevSec.calculatedHeight or 0) / 2 then
                    tab.sections[dragIdx], tab.sections[dragIdx - 1] = tab.sections[dragIdx - 1], tab.sections[dragIdx]
                end
            end
            if dragIdx < #tab.sections then
                local nextSec = tab.sections[dragIdx + 1]
                if not nextSec.locked and not dragSec.locked and state.mouseY > (nextSec.lastRenderY or 0) + (nextSec.calculatedHeight or 0) / 2 then
                    tab.sections[dragIdx], tab.sections[dragIdx + 1] = tab.sections[dragIdx + 1], tab.sections[dragIdx]
                end
            end

            if math.abs(state.mouseX - state.dragStartMouseX) > 40 then
                local mouseFrac = (state.mouseX - px) / pw
                if mouseFrac < 0.35 then
                    dragSec.side = "Left"
                elseif mouseFrac > 0.65 then
                    dragSec.side = "Right"
                else
                    dragSec.side = "Full"
                end
            else
                dragSec.side = state.draggedSectionOriginalSide
            end
        end
    else
        state.draggedSection = nil
    end

    if held and state.resizeSection then
        local dy = state.mouseY - state.resizeSectionStartMouseY
        local newH = math.max(40, state.resizeSectionStartH + dy)
        
        if state.gridLocking ~= false then
            local resizeSec = state.resizeSection
            local resizeBottom = (resizeSec.lastRenderY or 0) + newH
            state.gridSnapLines = {}
            
            for i = 1, #sectionsToRender do
                local otherSec = sectionsToRender[i]
                if otherSec ~= resizeSec then
                    local otherBottom = (otherSec.lastRenderY or 0) + (otherSec.calculatedHeight or 0)
                    if math.abs(resizeBottom - otherBottom) < 10 then
                        newH = otherBottom - (resizeSec.lastRenderY or 0)
                        state.gridSnapLines[#state.gridSnapLines + 1] = otherBottom
                    end
                end
            end
        end
        
        state.resizeSection.customHeight = newH
    else
        state.resizeSection = nil
        state.gridSnapLines = nil
    end

    local leftY = sy
    local rightY = sy

    for i = 1, #sectionsToRender do
        local section = sectionsToRender[i]
        local secH = section.calculatedHeight

        local targetLocalX, targetLocalY, targetLocalW
        if section.side == "Full" then
            targetLocalX = 0
            targetLocalY = math.max(leftY, rightY) - sy
            targetLocalW = pw
            leftY = math.max(leftY, rightY) + secH + 10
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
            state.mouseX - state.dragOffset[1],
            state.mouseY - state.dragOffset[2],
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

    if state.gridSnapLines then
        for i = 1, #state.gridSnapLines do
            local snapY = state.gridSnapLines[i]
            if snapY > clipTop and snapY < clipBottom then
                line(px, snapY, px + pw, snapY, theme.accent, 60, 1, 0.6)
            end
        end
    end

    if tab.maxScroll > 0 then
        local trackH = contH - 8 * 2 - 12
        local barH = math.max(22, (trackH / math.max(contentH, trackH)) * trackH)
        local barY = contY + 8 + 6 + (tab.scrollY / math.max(1, tab.maxScroll)) * (trackH - barH)
        local scrollBarX = state.x + state.w - 12
        rect(scrollBarX, contY + 8 + 6, 3, trackH, theme.surface3, 50, 2, state.contentFade)
        rect(scrollBarX, barY, 3, barH, theme.accent, 51, 2, state.contentFade)
        if click and over(scrollBarX - 5, contY + 8 + 6, 14, trackH) and not popupBlocking then
            local grab = barH / 2
            if over(scrollBarX - 5, barY, 14, barH) then
                grab = clamp(state.mouseY - barY, 0, barH)
            end
            state.scrollDrag = {
                tab = tab,
                grab = grab,
            }
            click = false
        end
        local drag = state.scrollDrag
        if held and type(drag) == "table" and drag.tab == tab then
            tab.targetScrollY = clamp((state.mouseY - (contY + 8 + 6) - drag.grab) / math.max(1, trackH - barH), 0, 1) * tab.maxScroll
        end
    elseif type(state.scrollDrag) == "table" and state.scrollDrag.tab == tab then
        state.scrollDrag = nil
    end

    return click, held, rightClick
end

local function serializeConfigData()
    local configData = {}
    for _, t in ipairs(state.tabs) do
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
        for _, t in ipairs(state.tabs) do
            for _, s in ipairs(t.sections) do
                for _, item in ipairs(s.items) do
                    local key = t.name .. "." .. s.name .. "." .. item.label
                    local data = configData[key]
                    if data then
                        if item.type == "colorpicker" then
                            pcall(function()
                                item.value = Color3.fromHex("#" .. tostring(data.value or "FFFFFF"))
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
                            safeCallback(item.keybind.callback, item.keybind.value and input[item.keybind.value] and input[item.keybind.value].id or nil, item.keybind.mode)
                        end
                        if data.colorpicker and item.colorpicker then
                            pcall(function()
                                item.colorpicker.value = Color3.fromHex("#" .. tostring(data.colorpicker.value or "FFFFFF"))
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
    for k, v in pairs(theme) do
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
            if theme[k] ~= nil then
                theme[k] = Color3.fromHex("#" .. v)
                if state.themeColorPickers and state.themeColorPickers[k] then
                    state.themeColorPickers[k]:Set(theme[k])
                end
            end
        end
    end
end

exportTheme = function()
    local themeData = {}
    for k, v in pairs(theme) do
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
    state.settingsTab = settingsTab
 
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
    local themeDropdown = themeSection:Dropdown("theme List", getThemesList(), getThemesList())
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
    
    local themeNameBox = themeSection:Textbox("theme Name", "")
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
            for k, v in pairs(theme) do
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
        state.isrbxactiveOverride = val
    end)
    generalSec:Checkbox("Tab Animations", true, function(val)
        state.tabAnimations = val
    end)
    generalSec:Checkbox("Grid Locking", true, function(val)
        state.gridLocking = val
    end)
    generalSec:Checkbox("Checkbox Animations", true, function(val)
        state.hoverEffects = val
    end)

    local colorsSec = createSection(settingsTab, "theme Colors", "Full")
    colorsSec:Label("Customize ui theme colors below:")
    state.themeColorPickers = {}
    local pickers = {"accent", "bg", "surface", "surface2", "surface3", "text", "sub", "border"}
    for idx = 1, #pickers do
        local name = pickers[idx]
        state.themeColorPickers[name] = colorsSec:Colorpicker(
            name == "accent" and "Accent" or
            name == "bg" and "Background" or
            name == "surface" and "Surface 1" or
            name == "surface2" and "Surface 2" or
            name == "surface3" and "Surface 3" or
            name == "text" and "Text" or
            name == "sub" and "Sub Text" or
            "Border",
            theme[name],
            true,
            function(color)
                theme[name] = color
            end
        )
        local dummy = idx or idx
    end
end

local function renderSearchFeature(item, rowX, rowY, rowW, click, held, rightClick, clipTop, clipBottom)
    local z = 40
    local disabled = isItemDisabled(item)
    local trans = (disabled and 0.4 or 1) * math.min(clamp((rowY - clipTop) / 16, 0, 1), clamp((clipBottom - (rowY + getItemHeight(item, rowW))) / 16, 0, 1))
    if trans <= 0 then
        return click, held, rightClick
    end
    
    local itemH = getItemHeight(item, rowW)
    local popupBlocking = state.dropdown ~= nil or state.colorpicker ~= nil
    
    if item.type == "checkbox" then
        local targetAnim = item.value and 1 or 0
        if state.hoverEffects == false then
            item.animState = targetAnim
        else
            item.animState = smoothValue(item.animState or targetAnim, targetAnim, 18)
        end
        rect(rowX + 4, rowY + 6, 14, 14, theme.surface3, z + 12, 4, trans)
        strokeRect(rowX + 4, rowY + 6, 14, 14, theme.border, z + 13, 4, trans)
        
        if item.animState > 0.05 then
            local offset = 7 * (1 - item.animState)
            rect(rowX + 4 + offset, rowY + 6 + offset, 14 * item.animState, 14 * item.animState, theme.accent, z + 14, 4 * item.animState, trans)
        end
        
        txt(item.label, rowX + 26, textTop(rowY, itemH - 2, 13), item.unsafe and theme.unsafe or (item.value and theme.text or theme.sub), 13, font_system, z + 12, false, false, rowW - 26 - (6 + (item.colorpicker and 20 or 0) + (item.keybind and 64 or 0) + (item.tooltip and 18 or 0)), trans)
        
        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
        
        if item.tooltip then
            txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), over(rowX + rowW - 16, rowY + 6, 12, 12) and theme.accent or theme.sub, 13, font_system, z + 12, false, false, nil, trans)
            if over(rowX + rowW - 16, rowY + 6, 12, 12) and not disabled then
                tooltip(item.tooltip, state.mouseX, state.mouseY)
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
        rect(rowX + 4, rowY + 7, 24, 12, lerpColor(theme.surface3, theme.accent, item.animState), z + 12, 6, trans)
        strokeRect(rowX + 4, rowY + 7, 24, 12, lerpColor(theme.border, theme.accent, item.animState), z + 13, 6, trans)
        circle(rowX + 10 + 12 * item.animState, rowY + 13, 4, theme.text, z + 14, true, 0, 32, trans)
        
        txt(item.label, rowX + 36, textTop(rowY, itemH - 2, 13), item.unsafe and theme.unsafe or (item.value and theme.text or theme.sub), 13, font_system, z + 12, false, false, rowW - 36 - (6 + (item.colorpicker and 20 or 0) + (item.keybind and 64 or 0) + (item.tooltip and 18 or 0)), trans)
        
        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
        
        if item.tooltip then
            txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), over(rowX + rowW - 16, rowY + 6, 12, 12) and theme.accent or theme.sub, 13, font_system, z + 12, false, false, nil, trans)
            if over(rowX + rowW - 16, rowY + 6, 12, 12) and not disabled then
                tooltip(item.tooltip, state.mouseX, state.mouseY)
            end
        end
        
        if click and over(rowX, rowY, rowW, itemH) and not popupBlocking and not disabled and trans > 0.5 then
            if not (item.keybind and over(rowX + rowW - 96, rowY + 3, 46, 20)) and not (item.colorpicker and over(rowX + rowW - 127, rowY + 5, 18, 18)) and not (item.tooltip and over(rowX + rowW - 16, rowY + 6, 12, 12)) then
                setItemValue(item, not item.value, true)
                click = false
            end
        end
        
    elseif item.type == "colorpicker" then
        txt(item.label, rowX + 4, textTop(rowY, itemH - 2, 13), theme.text, 13, font_system, z + 12, false, false, rowW - 28, trans)
        local cpX = rowX + rowW - 16
        local hovered = over(cpX - 3, rowY + 5, 18, 18)
        rect(cpX, rowY + 8, 12, 12, item.value, z + 12, 3, trans * (item.alpha or 1))
        strokeRect(cpX, rowY + 8, 12, 12, theme.border, z + 13, 3, trans)
        if hovered then
            strokeRect(cpX - 2, rowY + 6, 16, 16, theme.accent, z + 14, 4, trans)
        end
        if click and hovered and not popupBlocking and not disabled and trans > 0.5 then
            doColorPicker(state.mouseX + 14, state.mouseY - 90, item)
            click = false
        elseif rightClick and hovered and not popupBlocking and not disabled and trans > 0.5 then
            dDropdown("colorctx", cpX - 34, rowY + 24, 80, {"Copy", "Paste"}, {}, false, function(choice)
                if choice and choice[1] == "Copy" then
                    state.copiedColor = item.value
                    pcall(setclipboard, "#" .. toHex(item.value))
                elseif choice and choice[1] == "Paste" then
                    if state.copiedColor and colorChanged(item.value, state.copiedColor) then
                        item.value = state.copiedColor
                        safeCallback(item.callback, item.value)
                    else
                        warn("color clipboard empty lol")
                    end
                end
            end, nil, nil)
            rightClick = false
        end

    elseif item.type == "slider" then
        txt(item.label, rowX + 4, rowY + 2, theme.text, 13, font_system, z + 12, false, false, rowW - 80, trans)
        
        local isFocusedSlider = state.focus == item
        local valStr = isFocusedSlider and (item._directValue or "") or tostring(item.value)
        local boxW = math.max(36, textWidth(isFocusedSlider and valStr or (valStr .. tostring(item.suffix or "")), 12, font_ui) + 12)
        local valBoxX = rowX + rowW - boxW - 4
        local hoveredVal = over(valBoxX, rowY + 1, boxW, 16) and not popupBlocking and not disabled
        
        if isFocusedSlider then
            rect(valBoxX, rowY + 1, boxW, 16, theme.surface, z + 12, 4, trans)
            strokeRect(valBoxX, rowY + 1, boxW, 16, theme.accent, z + 13, 4, trans)
        end
        txt(isFocusedSlider and valStr or (valStr .. tostring(item.suffix or "")), valBoxX + boxW / 2, rowY + 9, theme.text, 12, font_ui, z + 14, true, false, boxW - 4, trans)
        if isFocusedSlider then
            txt("|", valBoxX + boxW / 2 + textWidth(valStr, 12, font_ui) / 2, rowY + 9, theme.text, 12, font_ui, z + 15, true, false, nil, trans * clamp(0.5 + 0.5 * math.math.sin(os.clock() * 8), 0, 1))
        end

        if click and hoveredVal and trans > 0.5 then
            state.focus = item
            item._directValue = tostring(item.value)
            click = false
        end
        
        local sx, sw = rowX + 4, rowW - 8
        local sy_bar = rowY + 22
        local frac = clamp(((item.value or 0) - (item.math.min or 0)) / math.max(0.0001, (item.math.max or 100) - (item.math.min or 0)), 0, 1)
        
        rect(sx, sy_bar, sw, 4, theme.surface3, z + 12, 2, trans)
        if frac > 0 then
            rect(sx, sy_bar, sw * frac, 4, theme.accent, z + 13, 2, trans)
        end
        
        item._animatedRadius = item._animatedRadius or 5
        item._animatedRadius = smoothValue(item._animatedRadius, (hoveredVal or (over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled)) and 7 or 5, 18)
        circle(sx + sw * frac, sy_bar + 2, item._animatedRadius, Color3.fromRGB(190, 190, 190), z + 14, true, 0, 32, trans)
        
        if click and over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled and not hoveredVal and trans > 0.5 then
            state.sliderDrag = item
            click = false
        end
        if held and not popupBlocking and not disabled and (state.sliderDrag == item) then
            local snapped = snapValue((item.math.min or 0) + math.max(0.0001, (item.math.max or 100) - (item.math.min or 0)) * clamp((state.mouseX - sx) / sw, 0, 1), item)
            if snapped ~= item.value then
                item.value = snapped
                safeCallback(item.callback, snapped)
            end
        end
        
    elseif item.type == "dropdown" then
        txt(item.label, rowX + 4, rowY + 2, theme.text, 13, font_system, z + 12, false, false, rowW - 20, trans)
        
        local dx, dw = rowX + 4, rowW - 8
        local dy_box = rowY + 18
        local boxH = 22
        
        rect(dx, dy_box, dw, boxH, over(dx, dy_box, dw, boxH) and theme.surface3 or theme.surface2, z + 12, 4, trans)
        strokeRect(dx, dy_box, dw, boxH, theme.border, z + 13, 4, trans)
        
        txt(item.multi and (#item.value > 0 and table.concat(item.value, ", ") or "-") or (item.value[1] or "-"), dx + 8, textTop(dy_box, boxH, 13), theme.text, 13, font_system, z + 14, false, false, dw - 28, trans)
        
        if state.dropdown and state.dropdown.item == item then
            drawChevronUp(dx + dw - 15, centerY(dy_box, boxH) - 2, theme.sub, z + 15, trans)
        else
            drawChevronDown(dx + dw - 15, centerY(dy_box, boxH) - 2, theme.sub, z + 15, trans)
        end
        
        if item.tooltip then
            txt("?", rowX + rowW - 10, rowY + 2, over(rowX + rowW - 16, rowY + 2, 12, 12) and theme.accent or theme.sub, 13, font_system, z + 12, false, false, nil, trans)
            if over(rowX + rowW - 16, rowY + 2, 12, 12) and not disabled then
                tooltip(item.tooltip, state.mouseX, state.mouseY)
            end
        end
        
        if click and over(dx, dy_box, dw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
            dDropdown("item", dx, dy_box + boxH, dw, item.choices, item.value, item.multi, item.callback, item, nil)
            click = false
        end
        
    elseif item.type == "button" then
        local controlY = rowY + 2
        item._hoverFactor = smoothValue(item._hoverFactor or 0, (over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled) and 1 or 0, 18)
        
        rect(rowX + 4, controlY, rowW - 8, itemH - 4, theme.accent, z + 12, 6, trans * (0.1 + 0.15 * item._hoverFactor))
        strokeRect(rowX + 4, controlY, rowW - 8, itemH - 4, theme.accent, z + 13, 6, trans * (0.4 + 0.6 * item._hoverFactor))
        
        txt(item.label, rowX + rowW / 2, centerY(controlY, itemH - 4), theme.accent, 13, font_bold, z + 14, true, false, rowW - 24, trans)
        
        if click and over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled and trans > 0.5 then
            safeCallback(item.callback)
            click = false
        end
        
    elseif item.type == "textbox" then
        txt(item.label, rowX + 4, rowY + 2, theme.text, 13, font_system, z + 12, false, false, rowW - 20, trans)
        
        local bx, bw = rowX + 4, rowW - 8
        local dy_box = rowY + 18
        local boxH = 22
        local focused = state.focus == item
        
        rect(bx, dy_box, bw, boxH, focused and theme.surface or over(bx, dy_box, bw, boxH) and theme.surface3 or theme.surface2, z + 12, 4, trans)
        strokeRect(bx, dy_box, bw, boxH, focused and theme.accent or theme.border, z + 13, 4, trans)
        
        txt((item.value == "") and item.label or item.value, bx + 8, textTop(dy_box, boxH, 13), (item.value == "") and theme.sub or theme.text, 13, font_ui, z + 14, false, false, bw - 16, trans)
        if focused then
            if item._selectedAll and not (item.value == "") then
                rect(bx + 8, dy_box + 3, math.math.min(bw - 16, textWidth(item.value, 13, font_ui)), boxH - 6, theme.accent, z + 13, 2, trans * 0.4)
            end
            local cursorX = bx + 8
            if not (item.value == "") then
                cursorX = cursorX + textWidth(item.value, 13, font_ui)
            end
            txt("|", cursorX, textTop(dy_box, boxH, 13), theme.text, 13, font_ui, z + 15, false, false, nil, trans * clamp(0.5 + 0.5 * math.math.sin(os.clock() * 8), 0, 1))
        end
        
        if click and over(bx, dy_box, bw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
            state.focus = focused and nil or item
            click = false
        end
    end
    
    return click, held, rightClick
end

local function renderSearchResults(click, held, rightClick, px, py, pw, ph)
    local matches = {}
    for _, tab in ipairs(state.tabs) do
        for _, sec in ipairs(tab.sections) do
            for _, item in ipairs(sec.items) do
                if item.type ~= "divider" and item.type ~= "label" then
                    if string.find(string.lower(item.label or ""), string.lower(state.searchBar.value), 1, true) then
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

    local popupBlocking = state.dropdown ~= nil or state.colorpicker ~= nil
    
    local dummyY = py + 8
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
    local searchContentH = dummyY - (py + 8)
    
    state.searchMaxScroll = math.max(0, searchContentH - math.max(1, ph - 8 * 2))
    state.searchScrollY = state.searchScrollY or 0
    state.searchTargetScrollY = clamp(state.searchTargetScrollY or 0, 0, state.searchMaxScroll)
    
    if state.searchMaxScroll > 0 and not popupBlocking then
        if state.mouseScroll ~= 0 and over(state.x, state.y, state.w, state.h) then
            state.searchTargetScrollY = clamp(state.searchTargetScrollY - (state.mouseScroll > 0 and 1 or -1) * 28, 0, state.searchMaxScroll)
        end
    end
    
    local dtValue = state.dt or 1/60
    if dtValue <= 0 then dtValue = 1/60 end
    state.searchScrollY = state.searchScrollY + (state.searchTargetScrollY - state.searchScrollY) * (1 - math.exp(-15 * dtValue))
    state.searchScrollY = clamp(state.searchScrollY, 0, state.searchMaxScroll)
    
    local currentY = py + 8 - state.searchScrollY
    local clipTop = py + 4
    local clipBottom = py + ph - 4
    
    local lastTab = nil
    local lastSec = nil
    for i = 1, #matches do
        local match = matches[i]
        
        if match.tab ~= lastTab then
            local tabTrans = math.min(clamp((currentY - clipTop) / 16, 0, 1), clamp((clipBottom - (currentY + 20)) / 16, 0, 1))
            if tabTrans > 0 then
                txt(match.tab.name, px + 10, currentY, theme.accent, 14, font_bold, 30, false, false, nil, tabTrans)
            end
            currentY = currentY + 20
            lastTab = match.tab
            lastSec = nil
        end
        
        if match.section ~= lastSec then
            local secTrans = math.min(clamp((currentY - clipTop) / 16, 0, 1), clamp((clipBottom - (currentY + 18)) / 16, 0, 1))
            if secTrans > 0 then
                txt(match.section.name, px + 10, currentY, theme.sub, 12, font_bold, 30, false, false, nil, secTrans)
                
                if (px + pw - 20) > (px + 18 + textWidth(match.section.name, 12, font_bold)) then
                    for seg = 1, 20 do
                        line(
                            (px + 18 + textWidth(match.section.name, 12, font_bold)) + (seg - 1) * (((px + pw - 20) - (px + 18 + textWidth(match.section.name, 12, font_bold))) / 20),
                            currentY + 6,
                            (px + 18 + textWidth(match.section.name, 12, font_bold)) + seg * (((px + pw - 20) - (px + 18 + textWidth(match.section.name, 12, font_bold))) / 20),
                            currentY + 6,
                            theme.border,
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
        if math.min(currentY + itemH, clipBottom) - math.max(currentY, clipTop) > 0 then
            click, held, rightClick = renderSearchFeature(match.item, px + 10, currentY, pw - 20, click, held, rightClick, clipTop, clipBottom)
        end
        currentY = currentY + itemH + 6
        
        if i < #matches then
            local divTrans = math.min(clamp((currentY - clipTop) / 16, 0, 1), clamp((clipBottom - (currentY + 6)) / 16, 0, 1))
            if divTrans > 0 then
                rect(px + 10, currentY, pw - 20, 1, theme.border, 30, 0, 0.5 * divTrans)
            end
            currentY = currentY + 6
        end
    end
    
    if state.searchMaxScroll > 0 then
        local trackH = ph - 8 * 2 - 12
        local barH = math.max(22, (trackH / math.max(searchContentH, trackH)) * trackH)
        local barY = py + 8 + 6 + (state.searchScrollY / math.max(1, state.searchMaxScroll)) * (trackH - barH)
        local scrollBarX = state.x + state.w - 12
        rect(scrollBarX, py + 8 + 6, 3, trackH, theme.surface3, 50, 2, state.contentFade)
        rect(scrollBarX, barY, 3, barH, theme.accent, 51, 2, state.contentFade)
        if click and over(scrollBarX - 5, py + 8 + 6, 14, trackH) and not popupBlocking then
            state.scrollDrag = {
                search = true,
                grab = over(scrollBarX - 5, barY, 14, barH) and clamp(state.mouseY - barY, 0, barH) or (barH / 2),
            }
            click = false
        end
        
        if held and type(state.scrollDrag) == "table" and state.scrollDrag.search then
            state.searchTargetScrollY = clamp((state.mouseY - (py + 8 + 6) - state.scrollDrag.grab) / math.max(1, trackH - barH), 0, 1) * state.searchMaxScroll
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

local function drawSideGlow(x1, y1, x2, y2, mx, my, color, z)
    local cx = (x1 == x2) and x1 or clamp(mx, math.min(x1, x2), math.max(x1, x2))
    local cy = (x1 == x2) and clamp(my, math.min(y1, y2), math.max(y1, y2)) or y1
    local factor = clamp(1 - math.sqrt((mx - cx) * (mx - cx) + (my - cy) * (my - cy)) / 100, 0, 1)
    if factor > 0 then
        if x1 == x2 then
            local startY = math.max(math.min(y1, y2), cy - 40)
            local endY = math.min(math.max(y1, y2), cy + 40)
            if endY > startY then
                local segH = (endY - startY) / 16
                for si = 1, 16 do
                    local sy1 = startY + (si - 1) * segH
                    local sy2 = startY + si * segH
                    line(x1, sy1, x1, sy2, color, z, 2, factor * clamp(1 - math.abs(((sy1 + sy2) / 2) - cy) / 40, 0, 1))
                end
            end
        else
            local startX = math.max(math.min(x1, x2), cx - 40)
            local endX = math.min(math.max(x1, x2), cx + 40)
            if endX > startX then
                local segW = (endX - startX) / 16
                for si = 1, 16 do
                    local sx1 = startX + (si - 1) * segW
                    local sx2 = startX + si * segW
                    line(sx1, y1, sx2, y1, color, z, 2, factor * clamp(1 - math.abs(((sx1 + sx2) / 2) - cx) / 40, 0, 1))
                end
            end
        end
    end
end

local function renderWindow(click, held, rightClick)
    local x, y, w, h = state.x, state.y, state.w, state.h
    local popupOpen = state.dropdown ~= nil or state.colorpicker ~= nil or state.importModal ~= nil
    local baseClick = popupOpen and false or click
    local baseHeld = popupOpen and false or held
    local baseRightClick = popupOpen and false or rightClick

    for i = 1, #shadow_alpha do
        local offset = i * 2
        rect(x - offset, y - offset + 6, w + offset * 2, h + offset * 2, theme.black, 0, 12, shadow_alpha[i])
    end

    rect(x, y, w, h, theme.surface, 5, 12)
    strokeRect(x, y, w, h, theme.border, 6, 12)

    local dragEdge = state.resizeEdge
    if held and dragEdge then
        if string.find(dragEdge, "left") then
            drawSideGlow(x, y + 8, x, y + h - 8, state.mouseX, state.mouseY, theme.accent, 7)
        end
        if string.find(dragEdge, "right") then
            drawSideGlow(x + w, y + 8, x + w, y + h - 8, state.mouseX, state.mouseY, theme.accent, 7)
        end
        if string.find(dragEdge, "top") then
            drawSideGlow(x + 8, y, x + w - 8, y, state.mouseX, state.mouseY, theme.accent, 7)
        end
        if string.find(dragEdge, "bottom") then
            drawSideGlow(x + 8, y + h, x + w - 8, y + h, state.mouseX, state.mouseY, theme.accent, 7)
        end
    end

    rect(x + 2, y + 2, w - 4, 36 - 2, theme.surface2, 7, 10)
    rect(x + 2, y + 2 + (36 - 2) / 2, w - 4, (36 - 2) / 2, theme.surface2, 7, 0)
    line(x + 2, y + 36, x + w - 2, y + 36, theme.border, 8)

    local titleMidY = centerY(y, 36)

    local edgeSize = 6
    local mx, my = state.mouseX, state.mouseY
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
            state.resizeEdge = edge
            state.resizeStart = {x = x, y = y, w = w, h = h, mouseX = mx, mouseY = my}
            baseClick = false
        elseif over(x, y, w, 36) then
            state.drag = {state.mouseX - x, state.mouseY - y}
            baseClick = false
        end
    end

    local drag = state.resizeEdge
    if held and drag and state.resizeStart then
        local start = state.resizeStart
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
            newW = math.max(300, start.w + dx)
        end
        if drag == "top" or drag == "topleft" or drag == "topright" then
            if start.h - dy >= 300 then
                newH = start.h - dy
                newY = start.y + dy
            end
        end
        if drag == "bottom" or drag == "bottomleft" or drag == "bottomright" then
            newH = math.max(300, start.h + dy)
        end

        state.x = newX
        state.y = newY
        state.w = newW
        state.h = newH
        state.defaultH = newH
        clampWindow()
        x, y, w, h = state.x, state.y, state.w, state.h
    elseif held and state.drag then
        state.x = state.mouseX - state.drag[1]
        state.y = state.mouseY - state.drag[2]
        clampWindow()
        x, y = state.x, state.y
    elseif not held then
        state.resizeEdge = nil
        state.resizeStart = nil
        state.drag = nil
    end

    txt(state.title or "homesick", x + 14, textTop(y, 36, 14), theme.accent, 14, font_bold, 16)

    local setHovered = over(x + w - 30, y + 6, 20, 24)
    if click and setHovered then
        state.settingsActive = not state.settingsActive
        state.contentFade = 0
        if state.settingsActive then
            state.searchBar.active = false
            state.searchBar.value = ""
            state.preSettingsH = state.h
            state.preSettingsW = state.w
            local targetW = math.math.max(state.w, 500)
            local targetH = state.h
            if state.settingsTab then
                local leftH, rightH = 0, 0
                for _, sec in ipairs(state.settingsTab.sections) do
                    local secH = 28
                    local colW = (sec.side == "Full") and targetW or math.floor((targetW - 10) / 2)
                    local rowW = colW - 24
                    for _, item in ipairs(sec.items) do
                        secH = secH + (sec.customHeight and 0 or getItemHeight(item, rowW))
                    end
                    secH = secH + 6
                    if sec.side == "Right" then
                        rightH = rightH + secH + 10
                    elseif sec.side == "Full" then
                        leftH = math.math.max(leftH, rightH) + secH + 10
                        rightH = leftH
                    else
                        leftH = leftH + secH + 10
                    end
                end
                local needed = math.math.max(leftH, rightH)
                local contentArea = state.h - 36 - 20 - 30 - 8 - 24
                if needed > contentArea then
                    targetH = math.math.min(state.h + (needed - contentArea) + 20, 750)
                end
            end
            state.settingsTargetW = targetW
            state.settingsTargetH = targetH
        else
            state.settingsTargetW = state.preSettingsW or state.w
            state.settingsTargetH = state.preSettingsH or state.defaultH or state.h
        end
        click = false
        baseClick = false
    end

    local iconHovered = over(x + w - 52, y + 6, 20, 24)
    if click and iconHovered then
        state.searchBar.active = not state.searchBar.active
        state.contentFade = 0
        if state.searchBar.active then
            state.settingsActive = false
            state.focus = state.searchBar
            state.searchBar.value = ""
        else
            if state.focus == state.searchBar then
                state.focus = nil
            end
            state.searchBar.value = ""
        end
        click = false
        baseClick = false
    end

    if state.settingsTargetW then
        state.w = smoothValue(state.w, state.settingsTargetW, 14)
        if math.math.abs(state.w - state.settingsTargetW) < 0.5 then
            state.w = state.settingsTargetW
            if not state.settingsActive then
                state.settingsTargetW = nil
            end
        end
        clampWindow()
        x, y, w, h = state.x, state.y, state.w, state.h
    end
    if state.settingsTargetH then
        state.h = smoothValue(state.h, state.settingsTargetH, 14)
        if math.math.abs(state.h - state.settingsTargetH) < 0.5 then
            state.h = state.settingsTargetH
            if not state.settingsActive then
                state.settingsTargetH = nil
            end
        end
        clampWindow()
        x, y, w, h = state.x, state.y, state.w, state.h
    end
    state.searchBar.width = smoothValue(state.searchBar.width or 0, state.searchBar.active and 140 or 0, 18)
    if state.searchBar.width > 2 then
        local searchW = state.searchBar.width
        local searchX = x + w - 56 - searchW
        rect(searchX, y + 8, searchW, 20, theme.surface, 15, 6)
        strokeRect(searchX, y + 8, searchW, 20, (state.focus == state.searchBar) and theme.accent or theme.border, 16, 6)
        txt((state.searchBar.value == "") and "Search..." or state.searchBar.value, searchX + 8, textTop(y + 8, 20, 12), (state.searchBar.value == "") and theme.sub or theme.text, 12, font_ui, 17, false, false, searchW - 16)
        if state.focus == state.searchBar then
            local cursorX = searchX + 8
            if not (state.searchBar.value == "") then
                cursorX = cursorX + textWidth(state.searchBar.value, 12, font_ui)
            end
            txt("|", cursorX, textTop(y + 8, 20, 12), theme.text, 12, font_ui, 18, false, false, nil, clamp(0.5 + 0.5 * math.math.sin(os.clock() * 8), 0, 1))
        end
        if click and over(searchX, y + 8, searchW, 20) then
            state.focus = state.searchBar
            click = false
            baseClick = false
        end
    end

    circle(x + w - 45, y + 16, 4, iconHovered and theme.accent or theme.sub, 20, false, 1.5)
    line(x + w - 42, y + 19, x + w - 38, y + 23, iconHovered and theme.accent or theme.sub, 20, 1.5)

    local cx_set = x + w - 21
    local cy = y + 18
    local col = (setHovered or state.settingsActive) and theme.accent or theme.sub
    if state.settingsActive then
        for i = 0, 3 do
            local a = os.clock() * 2 + i * math.pi / 4
            local c = math.cos(a)
            local s = math.math.sin(a)
            line(cx_set - 6 * c, cy - 6 * s, cx_set + 6 * c, cy + 6 * s, theme.accent, 19, 4, 0.25)
        end
        circle(cx_set, cy, 4, theme.accent, 19, false, 4, 32, 0.25)
        circle(cx_set, cy, 1.5, theme.accent, 19, true, 0, 32, 0.25)
    end
    for i = 0, 3 do
        local a = (state.settingsActive and os.clock() * 2 or 0) + i * math.pi / 4
        local c = math.cos(a)
        local s = math.math.sin(a)
        line(cx_set - 6 * c, cy - 6 * s, cx_set + 6 * c, cy + 6 * s, col, 20, 1.5)
    end
    circle(cx_set, cy, 4, theme.surface2, 21, true)
    circle(cx_set, cy, 4, col, 22, false, 1.5)
    circle(cx_set, cy, 1.5, col, 23, true)

    if state.minimized or h <= 42 then
        return click, held, rightClick
    end

    local px, py = x + 10, y + 36 + 10
    local pw, ph = w - 10 * 2, h - 36 - 10 * 2 - 24
    if pw <= 40 or ph <= 40 then
        return click, held, rightClick
    end

    local fade = state.contentFade or 1
    if fade < 1 then
        state.contentFade = smoothValue(fade, 1, 16)
    end

    if state.searchBar.active and state.searchBar.value ~= "" then
        baseClick, baseHeld, baseRightClick = renderSearchResults(baseClick, baseHeld, baseRightClick, px, py, pw, ph)
        if state.focus and baseClick and not over(px, py, pw, ph) and not over(x + w - 56 - state.searchBar.width, y + 8, state.searchBar.width, 20) and not over(x + w - 52, y + 6, 20, 24) and not over(x + w - 30, y + 6, 20, 24) then
            state.focus = nil
            baseClick = false
        end
    elseif state.settingsActive then
        baseClick, baseHeld, baseRightClick = renderSections(state.settingsTab, baseClick, baseHeld, baseRightClick, px, py, pw, ph)
        if state.focus and baseClick and not over(px, py, pw, ph) and not over(x + w - 30, y + 6, 20, 24) then
            state.focus = nil
            baseClick = false
        end
    else
        baseClick = renderTabs(baseClick, px, py, pw)

        local contY = py + 30 + 8
        local contH = ph - 30 - 8

        baseClick, baseHeld, baseRightClick = renderSections(state.activeTab, baseClick, baseHeld, baseRightClick, px, contY, pw, contH)

        if state.focus and baseClick and not over(px, contY, pw, contH) then
            state.focus = nil
            baseClick = false
        end
    end

    local botY = y + h - 24
    local botH = 24
    line(x + 2, botY, x + w - 2, botY, theme.border, 8)
    txt((state.badgeText and state.badgeText ~= "") and (state.badgeText .. " | v1.0.0") or "v1.0.0", x + 14, textTop(botY, botH, 11), theme.sub, 11, font_ui, 10)
    line(x + w - 13, y + h - 5, x + w - 5, y + h - 13, theme.sub, 10, 1)
    line(x + w - 10, y + h - 5, x + w - 5, y + h - 10, theme.sub, 10, 1)
    line(x + w - 7, y + h - 5, x + w - 5, y + h - 7, theme.sub, 10, 1)

    if state.importModal then
        local modal = state.importModal
        local modalW = 260
        local modalH = 120
        local mx = x + (w - modalW) / 2
        local my = y + (h - modalH) / 2
        local mz = 85
        
        rect(x, y, w, h, Color3.fromRGB(0, 0, 0), mz - 2, 8, 0.6)
        rect(mx, my, modalW, modalH, theme.surface2, mz, 8, 1)
        strokeRect(mx, my, modalW, modalH, theme.border, mz + 1, 8, 1)
        
        local modalTitle = modal.type == "config" and "import config" or "import theme"
        txt(modalTitle, mx + 16, my + 14, theme.accent, 13, font_bold, mz + 2)
        if modalTitle == modalTitle then end
        
        local modalTextbox = modal.textbox
        local bx, bw = mx + 20, modalW - 40
        local dy_box = my + 42
        local boxH = 22
        local focused = state.focus == modalTextbox
        
        rect(bx, dy_box, bw, boxH, focused and theme.surface or over(bx, dy_box, bw, boxH) and theme.surface3 or theme.surface, mz + 2, 4, 1)
        strokeRect(bx, dy_box, bw, boxH, focused and theme.accent or theme.border, mz + 3, 4, 1)
        
        txt((modalTextbox.value == "" and not focused) and "enter code..." or modalTextbox.value, bx + 8, textTop(dy_box, boxH, 12), (modalTextbox.value == "") and theme.sub or theme.text, 12, font_ui, mz + 4, false, false, bw - 16)
        
        if focused then
            if modalTextbox._selectedAll and not (modalTextbox.value == "") then
                rect(bx + 8, dy_box + 3, math.math.min(bw - 16, textWidth(modalTextbox.value, 12, font_ui)), boxH - 6, theme.accent, mz + 3, 2, 0.4)
            end
            local cursorX = bx + 8
            if not (modalTextbox.value == "") then
                cursorX = cursorX + textWidth(modalTextbox.value, 12, font_ui)
            end
            txt("|", cursorX, textTop(dy_box, boxH, 12), theme.text, 12, font_ui, mz + 5, false, false, nil, clamp(0.5 + 0.5 * math.math.sin(os.clock() * 8), 0, 1))
        end
        
        if click and over(bx, dy_box, bw, boxH) then
            state.focus = modalTextbox
            click = false
        end
        
        local btnW = (modalW - 52) / 2
        local btnY = my + 78
        local btnH = 24
        
        local cancelHovered = over(mx + 20, btnY, btnW, btnH)
        rect(mx + 20, btnY, btnW, btnH, cancelHovered and theme.surface3 or theme.surface, mz + 2, 4, 1)
        strokeRect(mx + 20, btnY, btnW, btnH, cancelHovered and theme.accent or theme.border, mz + 3, 4, 1)
        txt("Cancel", mx + 20 + btnW / 2, centerY(btnY, btnH), theme.text, 12, font_ui, mz + 4, true)
        
        if click and over(mx + 20, btnY, btnW, btnH) then
            state.importModal = nil
            if state.focus == modalTextbox then
                state.focus = nil
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
        
        local confirmBgColor = not recognized and Color3.fromRGB(45, 42, 40) or (confirmHovered and theme.accent or theme.surface)
        local confirmTextColor = not recognized and theme.sub or (confirmHovered and theme.bg or theme.accent)
        
        rect(confirmX, btnY, btnW, btnH, confirmBgColor, mz + 2, 4, 1)
        strokeRect(confirmX, btnY, btnW, btnH, not recognized and theme.border or theme.accent, mz + 3, 4, 1)
        txt("Confirm", confirmX + btnW / 2, centerY(btnY, btnH), confirmTextColor, 12, font_ui, mz + 4, true)
        
        if confirmBgColor == confirmBgColor then end
        if confirmTextColor == confirmTextColor then end
        
        if click and recognized and over(confirmX, btnY, btnW, btnH) then
            modal.onConfirm(modalTextbox.value)
            state.importModal = nil
            if state.focus == modalTextbox then
                state.focus = nil
            end
            click = false
        end
    end

    return popupOpen and click or baseClick, popupOpen and held or baseHeld, popupOpen and rightClick or baseRightClick
end

local function step()
    local isTyping = state.focus ~= nil
    if isTyping ~= state.lastIsTyping then
        state.lastIsTyping = isTyping
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

    local prevFocus = state.focus
    local zoomLocked = state.zoomLocked
    if state.open then
        if not zoomLocked and LocalPlayer then
            local ok1, minZ = pcall(function() return LocalPlayer.CameraMinZoomDistance end)
            local ok2, maxZ = pcall(function() return LocalPlayer.CameraMaxZoomDistance end)
            if ok1 and ok2 then
                state.origMinZoom = minZ
                state.origMaxZoom = maxZ
                state.zoomLocked = true
            end
        end
        if LocalPlayer and state.zoomLocked then
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
                LocalPlayer.CameraMinZoomDistance = state.origMinZoom or 0.5
                LocalPlayer.CameraMaxZoomDistance = state.origMaxZoom or 400
            end)
            state.zoomLocked = nil
        end
    end
    resetPool()
    state.tooltipText = nil
    if (not state.open or not state.colorpicker) and state.cpPaletteSquares then
        for i = 1, #state.cpPaletteSquares do
            state.cpPaletteSquares[i].obj.Visible = false
        end
    end

    local now = os.clock()
    local dt = now - state.lastFrame
    state.lastFrame = now
    state.dt = dt

    getMouse()
    updateInput()

    if input[menu_key] and input[menu_key].click and not state.focus then
        setOpen(not state.open)
    end

    processTextInput()
    processKeybinds()
    runActivities(dt, now)

    if state.open and not state.focus and not state.dropdown and not state.colorpicker and #state.tabs > 0 then
        if input.left.click then
            local idx = math.max(1, (state.activeIndex or 1) - 1)
            state.activeTab = state.tabs[idx]
            state.activeIndex = idx
            state.tabScrollToActive = true
            state.contentFade = 0
        elseif input.right.click then
            local idx = math.min(#state.tabs, (state.activeIndex or 1) + 1)
            state.activeTab = state.tabs[idx]
            state.activeIndex = idx
            state.tabScrollToActive = true
            state.contentFade = 0
        end
    end

    if input.m1.released then
        state.sliderDrag = nil
        state.scrollDrag = nil
        state.resizeSection = nil
        state.draggedSection = nil
        state.drag = nil
        state.draggedTab = nil
    end

    local click = input.m1.click
    local held = input.m1.held
    local rightClick = input.m2.click

    if not state.open or not state.focusedWindow or #state.tabs == 0 then
        renderWatermark(click, held)
        renderNotifications()
        hideUnused()
        return
    end

    if not state.hasMouse then
        renderWatermark(click, held)
        renderNotifications()
        hideUnused()
        return
    end

    clampWindow()

    click, held, rightClick = renderWindow(click, held, rightClick)
    click, rightClick = renderDropdown(click, rightClick)
    click = renderColorpicker(click, held)
    renderTooltip()
    state.lastTooltipText = state.tooltipText

    if rightClick and state.dropdown == nil and state.colorpicker == nil then
        rightClick = false
    end

    renderWatermark(click, held)

    if prevFocus and state.focus ~= prevFocus then
        prevFocus._selectedAll = false
        if prevFocus.type == "slider" and prevFocus._directValue then
            setItemValue(prevFocus, tonumber(prevFocus._directValue) or prevFocus.value or prevFocus.math.min or 0, true)
            prevFocus._directValue = nil
        end
    end

    if click and state.focus then
        state.focus = nil
    end

    renderNotifications()
    hideUnused()
end

function ui:Demo()
    if state.demoLoaded then
        return self
    end

    state.demoLoaded = true
    self:SetTitle("homesick")
    self:SetSize(400, 500)
    self:Center()

    local playground = self:Tab("Playground")
    local controls = playground:Section("Section 1")

    controls:Label("homesick Test", theme.accent)
    local toggleOne = controls:Toggle("Toggle #1", false, nil, true, "This feature has a tooltip")
    local key = toggleOne:AddKeybind(nil, "Hold", true)
    local toggleTwo = controls:Toggle("Toggle #2", false)
    local color = toggleTwo:AddColorpicker("ESP Color", theme.white, true)
    local textBox = controls:Textbox("Hint", "")
    local slider = controls:Slider("Drag me", 10, 1, 1, 360, "deg")
    local dropdown = controls:Dropdown("Pick me", {"1"}, {"1", "2", "3", "4", "5", "verybigitem"}, false)
    local multi = controls:Dropdown("Multi pick", {"A"}, {"A", "B", "C"}, true)

    controls:Divider("Actions")
    controls:Button("Rollback", function()
        toggleOne:Set(false)
        key:Set(nil, "Hold")
        toggleTwo:Set(false)
        color:Set(theme.white)
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
            animSlider:Set(math.floor(math.sin(os.clock() * 8) * 100 + 0.0001))
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
    if not state.alive then
        if stepConnection then
            stepConnection:Disconnect()
            stepConnection = nil
        end
        finalDestroy()
        return
    end

    state.rendering = true
    local ok, err = pcall(step)
    state.rendering = false

    if not ok then
        local now = os.clock()
        state.errorCount = (state.errorCount or 0) + 1
        if now - state.lastErrorAt > 1 then
            state.lastErrorAt = now
        end
        setrobloxinput(true)
        state.inputState = true
        hideAll()
        if state.errorCount >= 3 then
            state.alive = false
            finalDestroy()
        end
    else
        state.errorCount = 0
    end
end

if RunService and RunService.RenderStepped then
    stepConnection = RunService.RenderStepped:Connect(runStepSafe)
else
    task.spawn(function()
        while state.alive do
            runStepSafe()
            if state.alive then
                task.wait((1 / 240))
            end
        end
    end)
end

_G.homesick = ui
_G.homesickUI = ui

local homesick = {}

homesick.GetDrawing = function(self, kind)
    return ui:GetDrawing(kind)
end

homesick.createWindow = function(title, width, height)
    ui:SetTitle(title)
    ui:SetSize(width, height)
    ui:Center()
    
    local windowWrap = {}
    
    windowWrap.setBadge = function(wSelf, text)
        state.badgeText = text
        return wSelf
    end
    
    windowWrap.addTab = function(wSelf, tabName)
        local tabWrap = {
            rawTab = ui:Tab(tabName),
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
            
            secWrap.addSlider = function(sSelf, id, label, math.min, math.max, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "Slider",
                    rawItem = sSelf.rawSec:Slider(label, default, 1, math.min, math.max, "", callback)
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
            
            secWrap.addMultiDropdown = function(sSelf, id, label, choices, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "MultiDropdown",
                    rawItem = sSelf.rawSec:Dropdown(label, default, choices, true, callback)
                }
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                widgetWrap.updateChoices = function(wSelf, newChoices)
                    wSelf.rawItem:UpdateChoices(newChoices)
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
        ui:SetOpen(wSelf.visible == true)
    end
    
    windowWrap.table.remove = function(wSelf)
        ui:Destroy()
    end
    
    setmetatable(windowWrap, {
        __index = function(t, k)
            if k == "visible" then
                return ui:IsOpen()
            end
            return rawget(t, k)
        end,
        __newindex = function(t, k, v)
            if k == "visible" then
                ui:SetOpen(v == true)
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
    ui:Notify("print", table.table.concat(strArgs, " "), 5)
    return _G.homesickOriginals.print(unpack(strArgs))
end
_G.warn = function(...)
    local strArgs = {}
    for i = 1, select("#", ...) do
        strArgs[i] = string.lower(tostring(select(i, ...)))
    end
    ui:Notify("warning", table.table.concat(strArgs, " "), 5)
    return _G.homesickOriginals.warn(unpack(strArgs))
end
if type(printl) == "function" then
    _G.homesickOriginals.printl = printl
    _G.printl = function(...)
        local strArgs = {}
        for i = 1, select("#", ...) do
            strArgs[i] = string.lower(tostring(select(i, ...)))
        end
        ui:Notify("print", table.table.concat(strArgs, " "), 5)
        return _G.homesickOriginals.printl(unpack(strArgs))
    end
end
if type(notify) == "function" then
    _G.homesickOriginals.notify = notify
    _G.notify = function(message, title, duration)
        local lowerMsg = string.lower(tostring(message or ""))
        local lowerTitle = string.lower(tostring(title or "notification"))
        ui:Notify(lowerTitle, lowerMsg, duration or 5)
        return _G.homesickOriginals.notify(message, title, duration)
    end
end
if _G.homesickOriginals and type(_G.homesickOriginals.isrbxactive) == "function" then
    _G.isrbxactive = function()
        if state.isrbxactiveOverride then
            return false
        end
        return _G.homesickOriginals.isrbxactive()
    end
end

_G.homesick = homesick
return homesick
