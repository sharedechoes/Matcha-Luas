local env = nil
pcall(function() env = getfenv and getfenv() or _G end)
if type(env) ~= "table" then env = {} end

local shared = type(shared) == "table" and shared or {}
local function safeWriteGlobal(key, value)
    pcall(function()
        _G[key] = value
    end)
    pcall(function()
        shared[key] = value
    end)
end

local function safeReadGlobal(key)
    local val = nil
    pcall(function() val = _G[key] end)
    if val ~= nil then return val end
    pcall(function() val = shared[key] end)
    return val
end

local v2 = Vector2.new
local c3 = Color3.fromRGB

local c3Hex = nil
pcall(function() c3Hex = Color3.fromHex end)
if type(c3Hex) ~= "function" then c3Hex = function(...) return nil end end

local hsv = nil
pcall(function() hsv = Color3.fromHSV end)
if type(hsv) ~= "function" then hsv = function(...) return nil end end

local abs = math.abs
local floor = math.floor
local max = math.max
local min = math.min
local sin = math.sin

local clock = nil
pcall(function() clock = os.clock end)
if type(clock) ~= "function" then
    local rawTick = env.tick
    if type(rawTick) ~= "function" then
        pcall(function() rawTick = tick end)
    end
    if type(rawTick) == "function" then
        clock = rawTick
    else
        clock = function() return 0 end
    end
end

local remove = table.remove
local concat = table.concat

local setrobloxinput = (type(env.setrobloxinput) == "function" and env.setrobloxinput) or function(...) end
local isrbxactive = (type(env.isrbxactive) == "function" and env.isrbxactive) or function() return true end

local homesickFunctions = safeReadGlobal("homesickFunctions")
if type(homesickFunctions) ~= "table" then
    homesickFunctions = {}
    safeWriteGlobal("homesickFunctions", homesickFunctions)
end

local homesickOriginals = safeReadGlobal("homesickOriginals")
if type(homesickOriginals) ~= "table" then
    homesickOriginals = {
        print = env.print or print,
        warn = env.warn or warn,
        printl = env.printl,
        notify = env.notify,
        isrbxactive = (type(env.isrbxactive) == "function" and env.isrbxactive) or isrbxactive
    }
    safeWriteGlobal("homesickOriginals", homesickOriginals)
end
local exportConfig, importConfig, exportTheme, importTheme, smoothValue, toHex, doColorPicker, dDropdown, drawChevronDown, drawChevronUp

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

local function parseColor(c)
    if type(c) == "string" then
        return c3Hex(string.sub(c, 1, 1) == "#" and c or "#" .. c)
    elseif type(c) == "table" then
        return c3(c[1] or 255, c[2] or 255, c[3] or 255)
    end
    return c
end

local Players = game:GetService("Players")
local Workspace = workspace
local LocalPlayer = Players.LocalPlayer
local Mouse = select(1, pcall(function() return LocalPlayer:GetMouse() end)) and LocalPlayer:GetMouse() or nil
local rawTick = env.tick
if type(rawTick) ~= "function" then
    pcall(function() rawTick = tick end)
end
local homesickInstanceId = (type(rawTick) == "function" and rawTick() or clock())
safeWriteGlobal("homesickInstanceId", homesickInstanceId)

local clipboardBox = nil
local clipboardGui = nil
local clipboardPending = false
local clipboardResult = nil

local function initClipboardBox()
    if clipboardBox then return end
    pcall(function()
        local sg = Instance.new("ScreenGui")
        sg.Name = "homesickClipboard"
        sg.ResetOnSpawn = false
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local tb = Instance.new("TextBox", sg)
        tb.Size = UDim2.new(0, 1, 0, 1)
        tb.Position = UDim2.new(0, -10, 0, -10)
        tb.BackgroundTransparency = 1
        tb.TextTransparency = 1
        tb.Text = ""
        tb.ClearTextOnFocus = false
        sg.Parent = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui") or game:GetService("CoreGui")
        clipboardGui = sg
        clipboardBox = tb
        tb.FocusLost:Connect(function()
            if clipboardPending then
                clipboardResult = tb.Text
                tb.Text = ""
                clipboardPending = false
            end
        end)
    end)
end

local function readClipboard(callback)
    initClipboardBox()
    if not clipboardBox then callback(nil) return end
    clipboardBox.Text = ""
    clipboardPending = true
    clipboardResult = nil
    pcall(function() clipboardBox:CaptureFocus() end)
    pcall(function()
        keypress(0x11)
        keypress(0x56)
        keyrelease(0x56)
        keyrelease(0x11)
    end)
    task.delay(0.05, function()
        pcall(function() clipboardBox:ReleaseFocus() end)
        task.delay(0.02, function()
            local result = clipboardResult
            clipboardPending = false
            clipboardResult = nil
            callback(type(result) == "string" and result or nil)
        end)
    end)
end

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
FontWidths[Fonts.System or 0] = 0.48
FontWidths[Fonts.SystemBold or 0] = 0.52
FontWidths[Fonts.UI or 0] = 0.50
FontWidths[Fonts.Minecraft or 0] = 0.55
FontWidths[Fonts.Monospace or 0] = 0.60
FontWidths[Fonts.Pixel or 0] = 0.50
FontWidths[Fonts.Fortnite or 0] = 0.55

local drawVisible = 1
local menuKey = "p"

local tabH = 30
local minimizedH = 42
local tabMinW = 80
local contentPad = 8

local shadowAlpha = {0.10, 0.07, 0.05, 0.03, 0.015}

local changelogs = {
    "added searchable dropdowns",
    "added autoload themes and configs separate option",
    "added hover tooltips and global settings toggle",
    "added limit max selections for multi dropdowns",
    "saved theme color and alpha transparency levels together",
    "added user settings checkboxes for autoload config and theme",
    "added global spotlight search palette via ctrl + space",
    "added loading spinner and mod combos for keybinds",
    "fixed tooltips cutting off with auto-wrapping and dynamic box sizing",
    "added auto-adapting keybind button sizes",
    "redesigned waiting for keybind loader to a YouTube-style dotted spinner",
    "fixed spotlight search and key combos not polling when GUI is closed",
    "added smooth fade transitions and premium styling to spotlight search",
    "removed pinning feature altogether"
}

local Theme = {
    bg = c3(36, 33, 31),
    surface = c3(30, 27, 25),
    surface2 = c3(44, 40, 37),
    surface3 = c3(54, 50, 46),
    text = c3(245, 242, 238),
    sub = c3(150, 142, 135),
    accent = c3(232, 208, 162),
    green = c3(52, 199, 89),
    red = c3(255, 69, 58),
    yellow = c3(255, 204, 0),
    unsafe = c3(255, 226, 84),
    border = c3(60, 55, 52),
    white = c3(255, 255, 255),
    black = c3(0, 0, 0),
}

local ThemeAlpha = {
    bg = 1.0,
    surface = 1.0,
    surface2 = 1.0,
    surface3 = 1.0,
    text = 1.0,
    sub = 1.0,
    accent = 1.0,
    green = 1.0,
    red = 1.0,
    yellow = 1.0,
    unsafe = 1.0,
    border = 1.0,
    white = 1.0,
    black = 1.0,
}

local function getThemeAlpha(color)
    for name, val in pairs(Theme) do
        if val == color then
            return ThemeAlpha[name] or 1.0
        end
    end
    return 1.0
end

local ProjectState = {
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
    tooltipsEnabled = true,
    caretEnabled = true,
    settingsTargetH = nil,
    preSettingsH = nil,
    settingsTargetW = nil,
    preSettingsW = nil,
    gridSnapLines = nil,
    tabsPosition = "top",
    layoutEditing = false,
    hotkeyEnabled = false,
    hotkeyPos = v2(100, 200),
    hotkeyDrag = nil,
    spotlightEnabled = true,
    spotlightKeybind = "ctrl+space",
    spotlightActive = false,
    spotlightSearch = {
        type = "textbox",
        value = "",
        active = false,
        selected = 1,
    },
}

local function warn(msg)
    ProjectState.notifications = ProjectState.notifications or {}
    table.insert(ProjectState.notifications, {
        title = "warning",
        description = string.lower(tostring(msg or "")),
        duration = 5,
        elapsed = 0,
    })
    if homesickOriginals and homesickOriginals.warn then
        homesickOriginals.warn(msg)
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

local ExternalPool = { sq = {}, tx = {}, ln = {}, ci = {}, tr = {}, im = {} }
local ExternalPoolIndex = { sq = 0, tx = 0, ln = 0, ci = 0, tr = 0, im = 0 }
local ExternalPoolHighWater = { sq = 0, tx = 0, ln = 0, ci = 0, tr = 0, im = 0 }

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

local ui = {}

local function viewportSize()
    local camera = nil
    pcall(function() camera = Workspace and Workspace.CurrentCamera end)
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
        warn("homesick callback error " .. tostring(result))
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
    ProjectState.spotlightActive = false
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
    local pos = ProjectState.tabsPosition or "top"
    ProjectState.x = clamp(
        ProjectState.x,
        pos == "left" and (85 + 8) or 0,
        pos == "right" and max(0, select(1, viewportSize()) - ProjectState.w - 85 - 8) or max(0, select(1, viewportSize()) - min(80, ProjectState.w))
    )
    ProjectState.y = clamp(
        ProjectState.y,
        0,
        max(0, select(2, viewportSize()) - min(40, ProjectState.h))
    )
end

local function getMouse()
    if not Mouse then
        LocalPlayer = Players.LocalPlayer
        Mouse = select(1, pcall(function() return LocalPlayer:GetMouse() end)) and LocalPlayer:GetMouse() or nil
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
        local ok, created = pcall(function() return Drawing.new(TypeMap[kind]) end)
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

local function getExternalDrawing(kind)
    if not ProjectState.alive or ProjectState.destroyed then
        return nil
    end

    ExternalPoolIndex[kind] = ExternalPoolIndex[kind] + 1
    local index = ExternalPoolIndex[kind]
    local list = ExternalPool[kind]
    local object = list[index]

    if not object then
        local ok, created = pcall(function() return Drawing.new(TypeMap[kind]) end)
        if not ok or not created then
            return nil
        end
        object = created
        list[index] = object
    end

    if index > ExternalPoolHighWater[kind] then
        ExternalPoolHighWater[kind] = index
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
    removeDrawingList(ExternalPool.sq)
    removeDrawingList(ExternalPool.tx)
    removeDrawingList(ExternalPool.ln)
    removeDrawingList(ExternalPool.ci)
    removeDrawingList(ExternalPool.tr)
    removeDrawingList(ExternalPool.im)
end

local function rect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then
        return
    end
    local d = getDrawing("sq")
    if not d then
        return
    end
    d.Position = v2(x, y)
    d.Size = v2(w, h)
    d.Color = color
    d.Filled = true
    d.Corner = radius or 0
    d.ZIndex = z or 1
    d.Transparency = (transparency or drawVisible) * getThemeAlpha(color)
end

local function strokeRect(x, y, w, h, color, z, radius, transparency)
    if w <= 0 or h <= 0 then
        return
    end
    local d = getDrawing("sq")
    if not d then
        return
    end
    d.Position = v2(x, y)
    d.Size = v2(w, h)
    d.Color = color
    d.Filled = false
    d.Corner = radius or 0
    d.ZIndex = z or 1
    d.Transparency = (transparency or drawVisible) * getThemeAlpha(color)
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
    if value == nil or value == "" or (value == "|" and ProjectState.caretEnabled == false) then
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
    d.Position = v2(xPos, yPos)
    d.Color = color
    d.Size = size or 13
    d.Font = font or FontSystem
    d.ZIndex = (z or 1) + 10
    d.Outline = outline == true
    d.Transparency = (transparency or drawVisible) * getThemeAlpha(color)
end

local function drawVerticalText(text, tx, ty, color, size, font, z)
    for i = 1, #text do
        txt(string.sub(text, i, i), tx, ty + (i - 1) * (size + 2), color, size, font, z, true)
    end
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
    d.From = v2(x1, y1)
    d.To = v2(x2, y2)
    d.Color = color
    d.Thickness = thickness or 1
    d.ZIndex = z or 1
    d.Transparency = (transparency or drawVisible) * getThemeAlpha(color)
end

local function circle(x, y, radius, color, z, filled, thickness, sides, transparency)
    local d = getDrawing("ci")
    if not d then
        return
    end
    d.Position = v2(x, y)
    d.Radius = radius
    d.Color = color
    d.Filled = filled ~= false
    d.Thickness = thickness or 1
    d.NumSides = sides or 32
    d.ZIndex = z or 1
    d.Transparency = (transparency or drawVisible) * getThemeAlpha(color)
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
    d.Transparency = (transparency or drawVisible) * getThemeAlpha(color)
end

local function drawImage(data, x, y, w, h, z, trans)
    local obj = getDrawing("im")
    if obj and obj == obj then
        pcall(function() obj.Data = data end)
        pcall(function() obj.Position = v2(x, y) end)
        pcall(function() obj.Size = v2(w, h) end)
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

local function drawSideGlow(x1, y1, x2, y2, mx, my, color, z)
    local isHoriz = abs(y1 - y2) < 1
    local px = isHoriz and clamp(mx, min(x1, x2), max(x1, x2)) or x1
    local py = isHoriz and y1 or clamp(my, min(y1, y2), max(y1, y2))
    local dist = math.sqrt((mx - px)^2 + (my - py)^2)
    if dist < 80 then
        for si = 1, 24 do
            local alpha = (1 - abs(-40 + (si - 0.5) * 3.333) / 40) * (1 - dist / 80)
            if alpha > 0 then
                if isHoriz then
                    line(clamp(px - 40 + (si - 1) * 3.333, min(x1, x2), max(x1, x2)), y1, clamp(px - 40 + si * 3.333, min(x1, x2), max(x1, x2)), y1, color, z, 2, alpha)
                else
                    line(x1, clamp(py - 40 + (si - 1) * 3.333, min(y1, y2), max(y1, y2)), x1, clamp(py - 40 + si * 3.333, min(y1, y2), max(y1, y2)), color, z, 2, alpha)
                end
            end
        end
    end
end

local function renderCustomBoxes(click, held)
    local popupBlocking = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil
    local boxes = ProjectState.customBoxes or {}
    
    if held and ProjectState.boxDrag then
        ProjectState.boxDrag.box.position = v2(ProjectState.mouseX - ProjectState.boxDrag.offset.X, ProjectState.mouseY - ProjectState.boxDrag.offset.Y)
    end
    if held and ProjectState.boxResize then
        ProjectState.boxResize.box.size = v2(max(100, ProjectState.boxResize.startSize.X + (ProjectState.mouseX - ProjectState.boxResize.startMouse.X)), max(40, ProjectState.boxResize.startSize.Y + (ProjectState.mouseY - ProjectState.boxResize.startMouse.Y)))
    end

    for i = 1, #boxes do
        local box = boxes[i]
        if box.visible then
            local bx = box.position.X
            local by = box.position.Y
            local bw = box.size.X
            local bh = box.size.Y
            
            if click and not popupBlocking then
                if over(bx + bw - 15, by + bh - 15, 15, 15) then
                    ProjectState.boxResize = { box = box, startSize = box.size, startMouse = v2(ProjectState.mouseX, ProjectState.mouseY) }
                    click = false
                elseif box.showTopbar and box.title and over(bx, by, bw, 22) then
                    ProjectState.boxDrag = { box = box, offset = v2(ProjectState.mouseX - bx, ProjectState.mouseY - by) }
                    click = false
                elseif not box.showTopbar and over(bx, by, bw, 15) then
                    ProjectState.boxDrag = { box = box, offset = v2(ProjectState.mouseX - bx, ProjectState.mouseY - by) }
                    click = false
                end
            end

            rect(bx, by, bw, bh, box.bgColor, 100, 6, 0.95)
            strokeRect(bx, by, bw, bh, box.borderColor, 101, 6, 0.95)
            
            line(bx + bw - 13, by + bh - 5, bx + bw - 5, by + bh - 13, Theme.sub, 102, 1)
            line(bx + bw - 10, by + bh - 5, bx + bw - 5, by + bh - 10, Theme.sub, 102, 1)
            line(bx + bw - 7, by + bh - 5, bx + bw - 5, by + bh - 7, Theme.sub, 102, 1)

            local currentY = by + 8
            if box.showTopbar and box.title then
                txt(box.title, bx + bw / 2, currentY, box.titleColor, 12, FontUI, 102, true)
                line(bx + 8, currentY + 16, bx + bw - 8, currentY + 16, Theme.border, 101, 1)
                currentY = currentY + 22
            end
            for j = 1, #box.elementOrder do
                local el = box.elements[box.elementOrder[j]]
                if el then
                    if el.type == "text" then
                        if currentY + el.size + 4 <= by + bh - 6 then
                            txt(el.text, bx + bw / 2, currentY, el.color, el.size, el.font, 102, el.alignment == "center")
                            currentY = currentY + el.size + 4
                        end
                    elseif el.type == "timer" then
                        if currentY + 8 <= by + bh - 6 then
                            rect(bx + 10, currentY + 4, bw - 20, 2, Theme.surface3, 102, 1, 0.95)
                            rect(bx + 10, currentY + 4, (bw - 20) * clamp(el.value / max(0.0001, el.maxValue), 0, 1), 2, el.color, 103, 1, 0.95)
                            currentY = currentY + 8
                        end
                    elseif el.type == "button" then
                        if currentY + 24 <= by + bh - 6 then
                            local hovered = over(bx + 10, currentY, bw - 20, 20) and not popupBlocking
                            rect(bx + 10, currentY, bw - 20, 20, hovered and Theme.surface3 or Theme.surface2, 102, 4, 0.95)
                            strokeRect(bx + 10, currentY, bw - 20, 20, hovered and Theme.accent or Theme.border, 103, 4, 0.95)
                            txt(el.label, bx + bw / 2, currentY + 10, Theme.text, 11, FontSystem, 104, true)
                            if click and hovered then
                                safeCallback(el.callback)
                                click = false
                            end
                            currentY = currentY + 24
                        end
                    elseif el.type == "checkbox" then
                        if currentY + 20 <= by + bh - 6 then
                            local cbX, cbY = bx + 10, currentY + 3
                            rect(cbX, cbY, 14, 14, Theme.surface3, 102, 4, 0.95)
                            strokeRect(cbX, cbY, 14, 14, Theme.border, 103, 4, 0.95)
                            local targetAnim = el.value and 1 or 0
                            el.animState = smoothValue(el.animState or targetAnim, targetAnim, 18)
                            if el.animState > 0.05 then
                                local offset = 7 * (1 - el.animState)
                                rect(cbX + offset, cbY + offset, 14 * el.animState, 14 * el.animState, Theme.accent, 104, 4 * el.animState, 0.95)
                            end
                            txt(el.label, bx + 30, currentY, el.value and Theme.text or Theme.sub, 11, FontSystem, 102, false)
                            local hovered = over(bx + 10, currentY, bw - 20, 20) and not popupBlocking
                            if click and hovered then
                                el.value = not el.value
                                safeCallback(el.callback, el.value)
                                click = false
                            end
                            currentY = currentY + 20
                        end
                    elseif el.type == "slider" then
                        if currentY + 24 <= by + bh - 6 then
                            txt(el.label, bx + 10, currentY, Theme.text, 11, FontSystem, 102, false)
                            local valStr = tostring(el.value)
                            txt(valStr, bx + bw - 10 - textWidth(valStr, 11, FontUI), currentY, Theme.text, 11, FontUI, 102, false)
                            local barY = currentY + 14
                            local barW = bw - 20
                            rect(bx + 10, barY, barW, 4, Theme.surface3, 102, 2, 0.95)
                            rect(bx + 10, barY, barW * clamp((el.value - el.min) / max(0.0001, el.max - el.min), 0, 1), 4, Theme.accent, 103, 2, 0.95)
                            circle(bx + 10 + barW * clamp((el.value - el.min) / max(0.0001, el.max - el.min), 0, 1), barY + 2, 4, Theme.text, 104, true, 0, 16, 0.95)
                            local hovered = over(bx + 10, barY - 4, barW, 12) and not popupBlocking
                            if held and (hovered or ProjectState.sliderDrag == el) then
                                ProjectState.sliderDrag = el
                                local newVal = el.min + clamp((ProjectState.mouseX - (bx + 10)) / barW, 0, 1) * (el.max - el.min)
                                if el.step then
                                    newVal = math.floor(newVal / el.step + 0.5) * el.step
                                end
                                if el.value ~= newVal then
                                    el.value = newVal
                                    safeCallback(el.callback, newVal)
                                end
                            end
                            currentY = currentY + 24
                        end
                    elseif el.type == "separator" then
                        if currentY + 10 <= by + bh - 6 then
                            if el.label and el.label ~= "" then
                                local textW = textWidth(el.label, 11, FontSystem)
                                local lineW = max(4, (bw - 20 - textW - 16) / 2)
                                local lineY = currentY + 5
                                rect(bx + 10, lineY, lineW, 1, Theme.border, 102, 1, 0.95)
                                txt(el.label, bx + 10 + lineW + 8, currentY, Theme.sub, 11, FontSystem, 103, false, false, textW + 4)
                                rect(bx + 10 + lineW + textW + 16, lineY, lineW, 1, Theme.border, 102, 1, 0.95)
                            else
                                rect(bx + 10, currentY + 5, bw - 20, 1, Theme.border, 102, 1, 0.95)
                            end
                            currentY = currentY + 10
                        end
                    elseif el.type == "colorpicker" then
                        if currentY + 20 <= by + bh - 6 then
                            txt(el.label, bx + 10, currentY + 3, Theme.text, 11, FontSystem, 102, false)
                            local cpX = bx + bw - 22
                            local hovered = over(cpX - 3, currentY + 1, 18, 18)
                            rect(cpX, currentY + 4, 12, 12, el.value, 102, 3, 0.95)
                            strokeRect(cpX, currentY + 4, 12, 12, Theme.border, 103, 3, 0.95)
                            if hovered then
                                strokeRect(cpX - 2, currentY + 2, 16, 16, Theme.accent, 104, 4, 0.95)
                            end
                            if click and hovered and not popupBlocking then
                                doColorPicker(ProjectState.mouseX + 14, ProjectState.mouseY - 90, el)
                                click = false
                            end
                            currentY = currentY + 20
                        end
                    elseif el.type == "dropdown" then
                        if currentY + 36 <= by + bh - 6 then
                            txt(el.label, bx + 10, currentY, Theme.text, 11, FontSystem, 102, false)
                            local dx = bx + 10
                            local dw = bw - 20
                            local dyBox = currentY + 14
                            local boxH = 18
                            local hovered = over(dx, dyBox, dw, boxH)
                            rect(dx, dyBox, dw, boxH, hovered and Theme.surface3 or Theme.surface2, 102, 4, 0.95)
                            strokeRect(dx, dyBox, dw, boxH, Theme.border, 103, 4, 0.95)
                            txt(el.value[1] or "-", dx + 6, centerY(dyBox, boxH), Theme.text, 11, FontSystem, 104, false)
                            drawChevronDown(dx + dw - 12, centerY(dyBox, boxH) - 2, Theme.sub, 105)
                            if click and hovered and not popupBlocking then
                                dDropdown("item", dx, dyBox + boxH, dw, el.choices, el.value, false, el.callback, el, nil)
                                click = false
                            end
                            currentY = currentY + 36
                        end
                    end
                end
            end
        end
    end
    return click
end

local function renderNotifications()
    local notifications = ProjectState.notifications or {}
    while #notifications > 10 do
        table.remove(notifications, 1)
    end
    local width = 280
    local height = 52
    local i = 1
    while i <= #notifications do
        local n = notifications[i]
        n.elapsed = n.elapsed + (ProjectState.dt or 1/60)
        if n.elapsed >= n.duration then
            table.remove(notifications, i)
        else
            n.targetX = select(1, viewportSize()) - width - 16
            n.targetY = (select(2, viewportSize()) - 16) - i * (height + 8)
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
            local displaySource = n.title
            if displaySource == "print" or displaySource == "warning" or displaySource == "warn" or displaySource == "notification" then
                displaySource = ProjectState.activeTab and ProjectState.activeTab.name or ProjectState.title or "homesick"
            end
            local fadeAlpha = 1
            if n.elapsed < 0.25 then
                fadeAlpha = n.elapsed / 0.25
            elseif n.duration - n.elapsed < 0.35 then
                fadeAlpha = (n.duration - n.elapsed) / 0.35
            end
            fadeAlpha = clamp(fadeAlpha, 0, 1)
            rect(nx, ny, width, height, Theme.surface2, z, 6, 0.85 * fadeAlpha)
            strokeRect(nx, ny, width, height, Theme.border, z + 1, 6, 0.85 * fadeAlpha)
            txt(displaySource, nx + 14, ny + 10, n.title == "warning" and Theme.red or Theme.accent, 11, FontUI, z + 2, false, false, width - 28, 0.95 * fadeAlpha)
            txt(n.description, nx + 14, ny + 26, Theme.text, 11, FontSystem, z + 2, false, false, width - 28, 0.95 * fadeAlpha)
            local barY = ny + height - 4
            local barX = nx + 6
            local barW = width - 12
            local barFillW = barW * clamp(1 - (n.elapsed / n.duration), 0, 1)
            rect(barX, barY, barW, 2, Theme.surface3, z + 2, 1, 0.95 * fadeAlpha)
            if barFillW > 1 then
                rect(barX, barY, barFillW, 2, n.title == "warning" and Theme.red or Theme.accent, z + 3, 1, 0.95 * fadeAlpha)
            end
            i = i + 1
        end
    end
end

drawChevronDown = function(x, y, color, z, transparency)
    triangle(v2(x, y), v2(x + 8, y), v2(x + 4, y + 5), color, z, true, transparency)
end

drawChevronUp = function(x, y, color, z, transparency)
    triangle(v2(x, y + 5), v2(x + 8, y + 5), v2(x + 4, y), color, z, true, transparency)
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

    if item.type == "checkbox" then
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
            function keyHandle:AddToHotkey(label, toggleId)
                keybind.hotkeyLabel = label
                keybind.hotkeyToggleId = toggleId
                return self
            end
            function keyHandle:RemoveFromHotkey()
                keybind.hotkeyLabel = nil
                keybind.hotkeyToggleId = nil
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
            if ProjectState.dropdown and ProjectState.dropdown.item == item then
                ProjectState.dropdown.choices = copyArray(newChoices)
                ProjectState.dropdown.h = min(#newChoices * 22 + (ProjectState.dropdown.multi and 30 or 6), ProjectState.dropdown.multi and 234 or 210)
                ProjectState.dropdown.y = clamp(ProjectState.dropdown.y, 8, max(8, select(2, viewportSize()) - ProjectState.dropdown.h - 8))
                ProjectState.dropdown.scrollOffset = clamp(ProjectState.dropdown.scrollOffset or 0, 0, max(0, #newChoices - floor((ProjectState.dropdown.h - 6) / 22)))
            end
            return self
        end
        function handle:AddChoice(choice)
            for i = 1, #item.choices do
                if item.choices[i] == choice then return self end
            end
            table.insert(item.choices, choice)
            self:UpdateChoices(item.choices)
            return self
        end
        function handle:RemoveChoice(choice)
            for i = #item.choices, 1, -1 do
                if item.choices[i] == choice then
                    table.remove(item.choices, i)
                end
            end
            for i = #item.value, 1, -1 do
                if item.value[i] == choice then
                    table.remove(item.value, i)
                end
            end
            self:UpdateChoices(item.choices)
            return self
        end
        function handle:ClearChoices()
            for i = #item.choices, 1, -1 do
                item.choices[i] = nil
            end
            for i = #item.value, 1, -1 do
                item.value[i] = nil
            end
            self:UpdateChoices(item.choices)
            return self
        end
        function handle:SetSearchable(boolVal)
            item.searchable = boolVal == true
            return self
        end
        function handle:SetMaxSelections(limit)
            item.maxSelections = tonumber(limit)
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
            type = "checkbox",
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

    function sectionApi:Dropdown(label, default, choices, multi, callback, tooltip, searchable, maxSelections)
        return makeItem(section, {
            type = "dropdown",
            label = tostring(label or "Dropdown"),
            value = copyArray(default),
            choices = copyArray(choices),
            multi = multi == true,
            callback = callback,
            tooltip = tooltip,
            searchable = searchable == true,
            maxSelections = tonumber(maxSelections),
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

    function sectionApi:SetSize(w, h)
        if w then
            section.customWidth = w
        end
        if h then
            section.customHeight = h
        end
        return self
    end

    function sectionApi:overrideSize(w, h)
        return self:SetSize(w, h)
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
    ProjectState.notifications = ProjectState.notifications or {}
    table.insert(ProjectState.notifications, {
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
        for name, input in pairs(Input) do
            if input.id == vk then
                key = name
                break
            end
        end
    end
    menuKey = normalizeKey(key) or "f1"
    return self
end

function ui:SetTheme(overrides)
    if type(overrides) == "table" then
        for k, v in pairs(overrides) do
            if Theme[k] ~= nil then Theme[k] = v end
        end
    end
    return self
end

function ui:IsOpen()
    return ProjectState.open == true
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

function ui:SetValue(path, value)
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

function ui:GetDrawing(kind)
    return getExternalDrawing(kind)
end

function ui:SetTitle(text)
    ProjectState.title = tostring(text or "homesick")
    return self
end

function ui:SetPos(x, y)
    ProjectState.x = tonumber(x) or ProjectState.x
    ProjectState.y = tonumber(y) or ProjectState.y
    clampWindow()
    return self
end

function ui:SetSize(w, h)
    ProjectState.w = max(300, tonumber(w) or ProjectState.w)
    ProjectState.h = max(300, tonumber(h) or ProjectState.h)
    if ProjectState.h > minimizedH then
        ProjectState.defaultH = ProjectState.h
        ProjectState.minimized = false
    end
    clampWindow()
    return self
end

function ui:Center()
    local vw, vh = viewportSize()
    ProjectState.x = floor(vw / 2 - ProjectState.w / 2)
    ProjectState.y = floor(vh / 2 - ProjectState.h / 2)
    clampWindow()
    return self
end

function ui:Tab(name)
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

function ui:RegisterActivity(callback)
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

    if clipboardGui then
        pcall(function() clipboardGui:Destroy() end)
        clipboardGui = nil
        clipboardBox = nil
    end

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
    ProjectState.alive = false
    ProjectState.open = false
    if not ProjectState.rendering then
        finalDestroy()
    end
    return self
end

function ui:Unload()
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
        if menuKey then keysToPoll[menuKey] = true end
        if ProjectState.spotlightEnabled ~= false then
            local sk = ProjectState.spotlightKeybind or "ctrl+space"
            local plus = string.find(sk, "+", 1, true)
            if plus then
                keysToPoll[string.sub(sk, 1, plus - 1)] = true
                keysToPoll[string.sub(sk, plus + 1)] = true
            else
                keysToPoll[sk] = true
            end
        end
        for _, item in ipairs(keybindItems) do
            if item.keybind and item.keybind.value then
                local val = item.keybind.value
                local plus = string.find(val, "+", 1, true)
                if plus then
                    keysToPoll[string.sub(val, 1, plus - 1)] = true
                    keysToPoll[string.sub(val, plus + 1)] = true
                else
                    keysToPoll[val] = true
                end
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
    return Color3.new(
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

toHex = function(color, alpha)
    if alpha then
        return string.format("%02X%02X%02X%02X", floor(color.R * 255 + 0.5), floor(color.G * 255 + 0.5), floor(color.B * 255 + 0.5), floor(alpha * 255 + 0.5))
    end
    return string.format("%02X%02X%02X", floor(color.R * 255 + 0.5), floor(color.G * 255 + 0.5), floor(color.B * 255 + 0.5))
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
    if not item.history then
        item.history = { prevValue }
        item.historyIndex = 1
    else
        while #item.history > item.historyIndex do
            table.remove(item.history)
        end
        if item.history[item.historyIndex] ~= prevValue then
            item.historyIndex = item.historyIndex + 1
            item.history[item.historyIndex] = prevValue
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

    if item == ProjectState.spotlightSearch then
        local ss = item
        if Input.esc.click then
            ProjectState.spotlightActive = false
            ProjectState.focus = nil
            Input.esc.click = false
            return
        end
        
        local matches = {}
        local query = string.lower(ss.value or "")
        for _, t in ipairs(ProjectState.tabs) do
            for _, s in ipairs(t.sections) do
                for _, mi in ipairs(s.items) do
                    if mi.type ~= "divider" and mi.type ~= "label" then
                        if query == "" or string.find(string.lower(mi.label), query, 1, true) then
                            matches[#matches + 1] = mi
                        end
                    end
                end
            end
        end
        
        local matchCount = math.min(#matches, 5)
        
        if Input.down.click then
            ss.selected = (ss.selected or 1) + 1
            if ss.selected > matchCount then ss.selected = 1 end
            Input.down.click = false
        elseif Input.up.click then
            ss.selected = (ss.selected or 1) - 1
            if ss.selected < 1 then ss.selected = matchCount end
            Input.up.click = false
        end
        
        if Input.enter.click then
            local mi = matches[ss.selected or 1]
            if mi then
                if mi.type == "checkbox" or mi.type == "toggle" then
                    setItemValue(mi, not mi.value, true)
                elseif mi.type == "button" then
                    safeCallback(mi.callback)
                end
            end
            ProjectState.spotlightActive = false
            ProjectState.focus = nil
            Input.enter.click = false
            return
        end

        local value = ss.value or ""
        local changed = false
        for i = 1, #InputOrder do
            local name = InputOrder[i]
            local input = Input[name]
            if input.click and input.char then
                value = value .. input.char
                changed = true
                break
            elseif input.click and (name == "backspace" or name == "unbound") then
                value = string.sub(value, 1, max(0, #value - 1))
                changed = true
                break
            end
        end
        if changed then
            ss.value = value
            ss.selected = 1
        end
        return
    end

    if item == ProjectState.dropdown then
        local dd = item
        if Input.enter.click or Input.esc.click then
            ProjectState.focus = nil
            return
        end
        local value = dd.searchQuery or ""
        local changed = false
        for i = 1, #InputOrder do
            local name = InputOrder[i]
            local input = Input[name]
            if input.click and input.char then
                value = value .. input.char
                changed = true
                break
            elseif input.click and (name == "backspace" or name == "unbound") then
                value = string.sub(value, 1, max(0, #value - 1))
                changed = true
                break
            end
        end
        if changed then
            dd.searchQuery = value
            local filtered = {}
            for idx = 1, #dd.item.choices do
                local choice = dd.item.choices[idx]
                if string.find(string.lower(tostring(choice)), string.lower(value), 1, true) then
                    table.insert(filtered, choice)
                end
            end
            dd.choices = filtered
            dd.scrollOffset = 0
            dd.h = min(#filtered * 22 + (dd.multi and 30 or 6) + 24, dd.multi and 234 or 210)
        end
        return
    end

    if item == ProjectState.colorpicker then
        local cp = item
        if Input.enter.click or Input.esc.click then
            ProjectState.focus = nil
            return
        end
        local value = cp.hexInput or ""
        local changed = false
        for i = 1, #InputOrder do
            local name = InputOrder[i]
            local input = Input[name]
            if input.click and input.char then
                local char = string.upper(input.char)
                if (tonumber(char) or char:match("[A-F]")) and #value < 8 then
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
            cp.hexInput = value
            if #value == 8 then
                local ok, newColor = pcall(c3Hex, "#" .. string.sub(value, 1, 6))
                if ok and newColor and tonumber(string.sub(value, 7, 8), 16) then
                    cp.hue, cp.sat, cp.val = toHsv(newColor)
                    cp.value = newColor
                    cp.alpha = tonumber(string.sub(value, 7, 8), 16) / 255
                    cp.picker.value = newColor
                    cp.picker.alpha = cp.alpha
                    safeCallback(cp.picker.callback, newColor, cp.alpha)
                end
            elseif #value == 6 then
                local ok, newColor = pcall(c3Hex, "#" .. value)
                if ok and newColor then
                    cp.hue, cp.sat, cp.val = toHsv(newColor)
                    cp.value = newColor
                    cp.picker.value = newColor
                    safeCallback(cp.picker.callback, newColor, cp.alpha)
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
            local val = tonumber(item.directValue or "") or item.value or item.min or 0
            setItemValue(item, val, true)
            item.directValue = nil
        end
        ProjectState.focus = nil
        return
    elseif Input.esc.click then
        if item.type == "slider" then
            item.directValue = nil
        end
        ProjectState.focus = nil
        return
    end

    local value
    if item.type == "textbox" then
        value = item.value or ""
    else
        value = item.directValue or ""
    end

    local changed = false
    local shifted = Input.shift.held or Input.lshift.held or Input.rshift.held
    local now = clock()
    local anyHeld = false
    
    if (Input.ctrl.held or Input.lctrl.held or Input.rctrl.held) then
        if Input.a.click then
            item.selectedAll = true
            Input.a.click = false
        elseif Input.c.click then
            pcall(setclipboard, value)
            Input.c.click = false
        elseif Input.v.click then
            local captureItem = item
            local captureSelectedAll = item.selectedAll
            local captureValue = value
            readClipboard(function(clip)
                if type(clip) == "string" and clip ~= "" and ProjectState.focus == captureItem then
                    if captureItem.type == "slider" then
                        clip = clip:gsub("[^0-9%.%-]", "")
                    end
                    local newVal
                    if captureSelectedAll then
                        newVal = clip
                        captureItem.selectedAll = false
                    else
                        newVal = captureValue .. clip
                    end
                    if captureItem.type == "textbox" then
                        if newVal ~= captureItem.value then
                            pushHistory(captureItem, captureItem.value)
                            captureItem.value = newVal
                            safeCallback(captureItem.callback, newVal)
                        end
                    else
                        if newVal ~= captureItem.directValue then
                            pushHistory(captureItem, captureItem.directValue or "")
                            captureItem.directValue = newVal
                        end
                    end
                end
            end)
            Input.v.click = false
        elseif Input.z.click then
            if item.history and item.historyIndex > 0 then
                local currentVal = (item.type == "textbox") and item.value or (item.directValue or "")
                if item.historyIndex == #item.history then
                    if item.history[item.historyIndex] ~= currentVal then
                        item.history[#item.history + 1] = currentVal
                    end
                end
                if item.historyIndex > 1 then
                    item.historyIndex = item.historyIndex - 1
                    local targetVal = item.history[item.historyIndex]
                    if item.type == "textbox" then
                        item.value = targetVal
                        safeCallback(item.callback, targetVal)
                    else
                        item.directValue = targetVal
                    end
                    item.selectedAll = false
                end
            end
            Input.z.click = false
        elseif Input.y.click then
            if item.history and item.historyIndex < #item.history then
                item.historyIndex = item.historyIndex + 1
                local targetVal = item.history[item.historyIndex]
                if item.type == "textbox" then
                    item.value = targetVal
                    safeCallback(item.callback, targetVal)
                else
                    item.directValue = targetVal
                end
                item.selectedAll = false
            end
            Input.y.click = false
        end
    else
        if Input.delete.click then
            if item.selectedAll then
                value = ""
                item.selectedAll = false
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
                if item.selectedAll then
                    value = ""
                    item.selectedAll = false
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
                anyHeld = true
                break
            elseif input.held and input.char and ProjectState.repeatKey == name then
                anyHeld = true
                if now >= (ProjectState.repeatAt or 0) then
                    local char = shifted and input.shifted or input.char
                    if item.selectedAll then
                        value = ""
                        item.selectedAll = false
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
                if item.selectedAll then
                    value = ""
                    item.selectedAll = false
                else
                    value = string.sub(value, 1, max(0, #value - 1))
                end
                changed = true
                ProjectState.repeatKey = name
                ProjectState.repeatAt = now + 0.4
                anyHeld = true
                break
            elseif input.held and (name == "backspace" or name == "unbound") and ProjectState.repeatKey == name then
                anyHeld = true
                if now >= (ProjectState.repeatAt or 0) then
                    if item.selectedAll then
                        value = ""
                        item.selectedAll = false
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
    
    if not anyHeld then
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
            if value ~= item.directValue then
                pushHistory(item, item.directValue or "")
                item.directValue = value
            end
        end
    end
end

local function processKeybinds()
    if ProjectState.focus and ProjectState.focus ~= ProjectState.spotlightSearch then
        return
    end

    if ProjectState.spotlightEnabled ~= false and not ProjectState.open then
        local key = ProjectState.spotlightKeybind or "ctrl+space"
        local isCombo = string.find(key, "+", 1, true)
        local pressed = false
        if isCombo then
            local mod = string.sub(key, 1, isCombo - 1)
            local k = string.sub(key, isCombo + 1)
            if Input[mod] and Input[mod].held and Input[k] and Input[k].click then
                pressed = true
            end
        else
            if Input[key] and Input[key].click then
                pressed = true
            end
        end
        if pressed then
            ProjectState.spotlightActive = not ProjectState.spotlightActive
            if ProjectState.spotlightActive then
                ProjectState.focus = ProjectState.spotlightSearch
                ProjectState.spotlightSearch.value = ""
                ProjectState.spotlightSearch.selected = 1
            else
                if ProjectState.focus == ProjectState.spotlightSearch then
                    ProjectState.focus = nil
                end
            end
            return
        end
    end

    if ProjectState.focus then
        return
    end

    for i = 1, #keybindItems do
        local item = keybindItems[i]
        local keybind = item.keybind
        if item.label ~= "Spotlight Search" and item.type == "checkbox" and keybind and keybind.value and not keybind.listening and not isItemDisabled(item) then
            local val = keybind.value
            local isCombo = string.find(val, "+", 1, true)
            if isCombo then
                local mod = string.sub(val, 1, isCombo - 1)
                local k = string.sub(val, isCombo + 1)
                local modInput = Input[mod]
                local keyInput = Input[k]
                if modInput and keyInput then
                    if keybind.mode == "Always" then
                        setItemValue(item, modInput.held and keyInput.held, true)
                    elseif keybind.mode == "Toggle" then
                        if modInput.held and keyInput.click then
                            setItemValue(item, not item.value, true)
                        end
                    else
                        setItemValue(item, modInput.held and keyInput.held, true)
                    end
                end
            else
                local input = Input[val]
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
end

local function runActivities(dt, now)
    local writeIndex = 1
    local activityParts = {}
    for i = 1, #ProjectState.activities do
        local activity = ProjectState.activities[i]
        if activity and activity.alive then
            local result = safeCallback(activity.callback, ui, dt, now)
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

dDropdown = function(kind, x, y, w, choices, value, multi, callback, item, keybind)
    local vw, vh = viewportSize()
    local height = min(#choices * 22 + (multi and 30 or 6) + ((item and item.searchable) and 24 or 0), multi and 234 or 210)
    ProjectState.dropdown = {
        kind = kind,
        x = clamp(x, 8, max(8, vw - w - 8)),
        y = clamp(y, 8, max(8, vh - height - 8)),
        w = w,
        h = height,
        choices = copyArray(choices),
        value = value,
        multi = multi == true,
        callback = callback,
        item = item,
        keybind = keybind,
        scrollOffset = 0,
        searchQuery = "",
    }
    if item and item.searchable then
        ProjectState.focus = ProjectState.dropdown
    end
    ProjectState.colorpicker = nil
end

doColorPicker = function(x, y, picker)
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
        hexInput = nil,
    }
    ProjectState.dropdown = nil
end
local function findItemValue(idOrLabel)
    if string.find(tostring(idOrLabel or ""), "%.") then
        local val = ui:GetValue(idOrLabel)
        if val ~= nil then return val end
    end
    for _, t in ipairs(ProjectState.tabs) do
        for _, s in ipairs(t.sections) do
            for _, item in ipairs(s.items) do
                if item.id == idOrLabel then
                    return item.value
                elseif item.label == idOrLabel then
                    return item.value
                end
            end
        end
    end
    return nil
end

local function renderHotkeyOverlay(click, held)
    if not ProjectState.hotkeyEnabled then
        return click
    end
    
    local dtValue = ProjectState.dt or 1/60
    if dtValue <= 0 then dtValue = 1/60 end
    
    ProjectState.hotkeyFades = ProjectState.hotkeyFades or {}
    local displayHotkeys = {}
    
    for _, item in ipairs(keybindItems) do
        if item.keybind and item.keybind.value then
            local active = false
            if (item.keybind.hotkeyToggleId and findItemValue(item.keybind.hotkeyToggleId) == true) or
               (not item.keybind.hotkeyToggleId and (
                   item.keybind.mode == "Always" or
                   (item.keybind.mode == "Toggle" and item.value == true) or
                   (item.keybind.mode == "Hold" and Input[item.keybind.value] and Input[item.keybind.value].held == true)
               )) then
                active = true
            end
            
            local currentFade = ProjectState.hotkeyFades[item] or 0
            if active then
                currentFade = currentFade + (1 - currentFade) * (1 - math.exp(-15 * dtValue))
                if currentFade > 0.99 then currentFade = 1 end
            else
                currentFade = currentFade - currentFade * (1 - math.exp(-15 * dtValue))
                if currentFade < 0.01 then currentFade = 0 end
            end
            ProjectState.hotkeyFades[item] = currentFade
            
            if currentFade > 0 then
                displayHotkeys[#displayHotkeys + 1] = {
                    label = item.keybind.hotkeyLabel or item.label,
                    value = item.keybind.value,
                    mode = item.keybind.mode,
                    listening = item.keybind.listening,
                    fade = currentFade
                }
            end
        end
    end
    
    local hx, hy = ProjectState.hotkeyPos.X, ProjectState.hotkeyPos.Y
    local hw = 220
    
    local totalHeight = 26
    for i = 1, #displayHotkeys do
        totalHeight = totalHeight + 20 * displayHotkeys[i].fade
    end
    totalHeight = max(46, totalHeight)
    
    ProjectState.hotkeyHeight = smoothValue(ProjectState.hotkeyHeight or 46, totalHeight, 18)
    local hh = ProjectState.hotkeyHeight
    
    if click and over(hx, hy, hw, 22) and not (ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil) then
        ProjectState.hotkeyDrag = { ProjectState.mouseX - hx, ProjectState.mouseY - hy }
        click = false
    end
    if held and ProjectState.hotkeyDrag then
        ProjectState.hotkeyPos = v2(ProjectState.mouseX - ProjectState.hotkeyDrag[1], ProjectState.mouseY - ProjectState.hotkeyDrag[2])
        hx, hy = ProjectState.hotkeyPos.X, ProjectState.hotkeyPos.Y
    elseif not held then
        ProjectState.hotkeyDrag = nil
    end
    
    rect(hx, hy, hw, hh, Theme.surface, 150, 6, 0.85)
    strokeRect(hx, hy, hw, hh, Theme.border, 151, 6)
    
    rect(hx + 2, hy + 2, hw - 4, 18, Theme.surface2, 152, 4)
    txt("keybinds", hx + 10, textTop(hy + 2, 18, 11), Theme.accent, 11, FontBold, 153)
    
    if #displayHotkeys == 0 then
        txt("-", hx + hw / 2, centerY(hy + 22, 20), Theme.sub, 11, FontSystem, 153, true)
    else
        local currentY = hy + 22
        for i = 1, #displayHotkeys do
            local kb = displayHotkeys[i]
            local itemHeight = 20 * kb.fade
            if itemHeight > 2 then
                txt(kb.label, hx + 10, textTop(currentY, itemHeight, 11), Theme.text, 11, FontSystem, 153, false, false, nil, kb.fade)
                txt(
                    string.format("[%s] [%s]", kb.listening and "..." or string.upper(kb.value or "-"), kb.mode == "Toggle" and "Toggle" or kb.mode == "Always" and "Always" or "Hold"),
                    hx + hw - 10 - textWidth(string.format("[%s] [%s]", kb.listening and "..." or string.upper(kb.value or "-"), kb.mode == "Toggle" and "Toggle" or kb.mode == "Always" and "Always" or "Hold"), 10, FontUI),
                    textTop(currentY, itemHeight, 10),
                    Theme.sub,
                    10,
                    FontUI,
                    153,
                    false,
                    false,
                    nil,
                    kb.fade
                )
            end
            currentY = currentY + itemHeight
        end
    end
    
    return click
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
    if ProjectState.tooltipsEnabled == false then
        return
    end
    if not ProjectState.tooltipText or clock() - ProjectState.tooltipAt < 0.35 then
        return
    end

    local lines = wrapLines(ProjectState.tooltipText, 260, 12, FontUI)
    local maxW = 0
    for i = 1, #lines do
        if textWidth(lines[i], 12, FontUI) > maxW then
            maxW = textWidth(lines[i], 12, FontUI)
        end
    end
    local width = maxW + 16
    local h = 12 + 16 * #lines
    local x = clamp(ProjectState.tooltipX + 12, 8, max(8, select(1, viewportSize()) - width - 8))
    local y = clamp(ProjectState.tooltipY + 18, 8, max(8, select(2, viewportSize()) - h - 4))

    rect(x, y, width, h, Theme.black, 140, 6, 0.92)
    strokeRect(x, y, width, h, Theme.border, 141, 6)
    for i = 1, #lines do
        txt(lines[i], x + 8, y + 8 + (i - 1) * 16, Theme.text, 12, FontUI, 142)
    end
end

local function renderDropdown(click, rightClick)
    local dd = ProjectState.dropdown
    if not dd then
        return click, rightClick
    end

    local isMulti = dd.multi == true
    local headerH = (dd.item and dd.item.searchable) and 24 or 0
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

    if headerH > 0 then
        rect(dd.x + 2, dd.y + 2, dd.w - 4, 20, Theme.surface2, 112, 3)
        strokeRect(dd.x + 2, dd.y + 2, dd.w - 4, 20, (ProjectState.focus == dd) and Theme.accent or Theme.border, 113, 3)
        txt((dd.searchQuery == "" and ProjectState.focus ~= dd) and "search..." or dd.searchQuery, dd.x + 8, textTop(dd.y + 2, 20, 11), (dd.searchQuery == "") and Theme.sub or Theme.text, 11, FontUI, 114, false, false, dd.w - 16)
        if ProjectState.focus == dd then
            local cursorX = dd.x + 8
            if dd.searchQuery ~= "" then
                cursorX = cursorX + textWidth(dd.searchQuery, 11, FontUI)
            end
            txt("|", cursorX, textTop(dd.y + 2, 20, 11), Theme.text, 11, FontUI, 115, false, false, nil, clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
        end
        if click and over(dd.x + 2, dd.y + 2, dd.w - 4, 20) then
            ProjectState.focus = dd
            click = false
        end
    end

    if dd.scrollOffset > 0 then
        triangle(v2(dd.x + dd.w - 14, dd.y + headerH + 8), v2(dd.x + dd.w - 6, dd.y + headerH + 8), v2(dd.x + dd.w - 10, dd.y + headerH + 4), Theme.sub, 115, true)
    end
    if dd.scrollOffset + maxRows < #dd.choices then
        triangle(v2(dd.x + dd.w - 14, dd.y + dd.h - 8), v2(dd.x + dd.w - 6, dd.y + dd.h - 8), v2(dd.x + dd.w - 10, dd.y + dd.h - 4), Theme.sub, 115, true)
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
                        if dd.item.maxSelections and #newValue >= dd.item.maxSelections then
                            warn("max selections of " .. tostring(dd.item.maxSelections) .. " reached")
                        else
                            newValue[#newValue + 1] = choice
                        end
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
                        if dd.maxSelections and #dd.value >= dd.maxSelections then
                            warn("max selections of " .. tostring(dd.maxSelections) .. " reached")
                        else
                            dd.value[#dd.value + 1] = choice
                        end
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
            return false, rightClick
        end
    end

    if isMulti and rightClick and isHoveredDropdown then
        if not dd.ctxMenu then
            dd.ctxMenu = true
            dd.ctxY = clamp(ProjectState.mouseY, dd.y, dd.y + dd.h - 44)
        end
        rightClick = false
    end

    if dd.ctxMenu then
        local ctxX = dd.x
        local ctxY = dd.ctxY or dd.y
        local ctxW = dd.w
        rect(ctxX, ctxY, ctxW, 44, Theme.surface2, 116, 4)
        strokeRect(ctxX, ctxY, ctxW, 44, Theme.border, 117, 4)

        local hoverAll = over(ctxX + 2, ctxY + 2, ctxW - 4, 18)
        local hoverClear = over(ctxX + 2, ctxY + 24, ctxW - 4, 18)

        rect(ctxX + 2, ctxY + 2, ctxW - 4, 18, hoverAll and Theme.surface3 or Theme.surface, 117, 3)
        txt("Select All", ctxX + 10, ctxY + 4, hoverAll and Theme.accent or Theme.text, 12, FontUI, 118)
        rect(ctxX + 2, ctxY + 24, ctxW - 4, 18, hoverClear and Theme.surface3 or Theme.surface, 117, 3)
        txt("Clear All", ctxX + 10, ctxY + 26, hoverClear and Theme.accent or Theme.text, 12, FontUI, 118)

        if click then
            if hoverAll then
                local limit = dd.item and dd.item.maxSelections or dd.maxSelections
                if limit and #dd.choices > limit then
                    warn("max selections of " .. tostring(limit) .. " reached")
                    local clampedChoices = {}
                    for ci = 1, limit do
                        clampedChoices[ci] = dd.choices[ci]
                    end
                    if dd.item then
                        setDropdownValue(dd.item, clampedChoices, true)
                    else
                        for vi = #dd.value, 1, -1 do dd.value[vi] = nil end
                        for ci = 1, limit do dd.value[ci] = clampedChoices[ci] end
                        safeCallback(dd.callback, dd.value)
                    end
                else
                    if dd.item then
                        setDropdownValue(dd.item, dd.choices, true)
                    else
                        for vi = #dd.value, 1, -1 do dd.value[vi] = nil end
                        for ci = 1, #dd.choices do dd.value[ci] = dd.choices[ci] end
                        safeCallback(dd.callback, dd.value)
                    end
                end
                dd.ctxMenu = nil
                click = false
            elseif hoverClear then
                if dd.item then
                    setDropdownValue(dd.item, {}, true)
                else
                    for vi = #dd.value, 1, -1 do dd.value[vi] = nil end
                    safeCallback(dd.callback, dd.value)
                end
                dd.ctxMenu = nil
                click = false
            else
                dd.ctxMenu = nil
            end
        end
    end

    if click and not isHoveredDropdown then
        ProjectState.dropdown = nil
        return false, rightClick
    end

    return click, rightClick
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
                local sq = Drawing.new("Square")
                sq.Size = v2(math.min(4, palW - 3 - gx), math.min(4, palH - 3 - gy))
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
        cell.obj.Position = v2(palX + cell.relX, palY + cell.relY)
        if hueChanged or not cell.initialized then
            cell.obj.Color = hsv(cp.hue, cell.sx, cell.sy)
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
        rect(hueX + 2, gy, hueW - 4, min(4, hueY + hueH - 2 - gy), hsv((gy - hueY) / hueH, 1, 1), 113, 0)
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
        rect(alphaX + 2, gy, 4, blockH, (floor((gy - alphaY) / 6) % 2 == 0) and Theme.white or c3(200, 200, 200), 113, 0)
        rect(alphaX + 6, gy, 4, blockH, (floor((gy - alphaY) / 6) % 2 == 0) and c3(200, 200, 200) or Theme.white, 113, 0)
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
    local hexText = isFocusedCP and (cp.hexInput or "") or ("#" .. toHex(cp.value, cp.alpha))
    txt(hexText, x + 16, textTop(y + 196, 22, 12), Theme.text, 12, FontUI, 116, false, false, 188)
    if isFocusedCP then
        txt("|", x + 16 + textWidth(hexText, 12, FontUI), textTop(y + 196, 22, 12), Theme.text, 12, FontUI, 117, false, false, nil, clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
    end

    if click and over(x + 10, y + 196, 200, 22) then
        ProjectState.focus = (ProjectState.focus == cp) and nil or cp
        cp.hexInput = toHex(cp.value, cp.alpha)
        click = false
    end

    rect(x + 10, y + 228, 60, 22, Theme.surface, 114, 4)
    strokeRect(x + 10, y + 228, 60, 22, Theme.border, 115, 4)
    txt("R", x + 16, textTop(y + 228, 22, 12), c3(255, 69, 58), 12, FontBold, 116)
    txt(tostring(floor(cp.value.R * 255 + 0.5)), x + 64 - textWidth(tostring(floor(cp.value.R * 255 + 0.5)), 12, FontUI), textTop(y + 228, 22, 12), Theme.text, 12, FontUI, 116)

    rect(x + 80, y + 228, 60, 22, Theme.surface, 114, 4)
    strokeRect(x + 80, y + 228, 60, 22, Theme.border, 115, 4)
    txt("G", x + 86, textTop(y + 228, 22, 12), c3(52, 199, 89), 12, FontBold, 116)
    txt(tostring(floor(cp.value.G * 255 + 0.5)), x + 134 - textWidth(tostring(floor(cp.value.G * 255 + 0.5)), 12, FontUI), textTop(y + 228, 22, 12), Theme.text, 12, FontUI, 116)

    rect(x + 150, y + 228, 60, 22, Theme.surface, 114, 4)
    strokeRect(x + 150, y + 228, 60, 22, Theme.border, 115, 4)
    txt("B", x + 156, textTop(y + 228, 22, 12), c3(0, 122, 255), 12, FontBold, 116)
    txt(tostring(floor(cp.value.B * 255 + 0.5)), x + 204 - textWidth(tostring(floor(cp.value.B * 255 + 0.5)), 12, FontUI), textTop(y + 228, 22, 12), Theme.text, 12, FontUI, 116)

    local final = hsv(cp.hue, cp.sat, cp.val)
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

local function renderTabs(click, px, py, pw, ph)
    local count = #ProjectState.tabs
    if count == 0 then
        return click
    end

    local pos = ProjectState.tabsPosition or "top"
    local isVertical = pos == "left" or pos == "right"
    
    if isVertical then
        ProjectState.currentPillX = nil
        ProjectState.currentPillW = nil
        local tabH = 30
        local totalH = count * tabH
        local needsScroll = totalH > ph
        local tabW = 85
        local maxScroll = max(0, totalH - ph)
        
        local dtValue = ProjectState.dt or 1 / 60
        if dtValue <= 0 then dtValue = 1 / 60 end
        local target = clamp(ProjectState.tabTargetScrollX or 0, 0, maxScroll)
        ProjectState.tabTargetScrollX = target
        local current = ProjectState.tabScrollX or 0
        local factor = 1 - math.exp(-18 * dtValue)
        current = current + (target - current) * factor
        current = clamp(current, 0, maxScroll)
        ProjectState.tabScrollX = current
        local scrollY = current
        
        local contentY = py + (needsScroll and 18 or 0)
        local contentH = ph - (needsScroll and 36 or 0)
        local tabX = pos == "left" and px or (px + pw - tabW)
        
        if needsScroll and scrollY > 1 then
            local arrowHovered = over(tabX, py, tabW, 18)
            rect(tabX, py, tabW, 18, arrowHovered and Theme.surface3 or Theme.surface, 26, 4)
            local cx = centerY(tabX, tabW)
            triangle(v2(cx, py + 6), v2(cx - 4, py + 12), v2(cx + 4, py + 12), Theme.sub, 27, true)
            if click and arrowHovered then
                ProjectState.tabTargetScrollX = max(0, target - tabH)
                click = false
            end
        end
        
        if needsScroll and scrollY < maxScroll - 1 then
            local ay = py + ph - 18
            local arrowHovered = over(tabX, ay, tabW, 18)
            rect(tabX, ay, tabW, 18, arrowHovered and Theme.surface3 or Theme.surface, 26, 4)
            local cx = centerY(tabX, tabW)
            triangle(v2(cx, ay + 12), v2(cx - 4, ay + 6), v2(cx + 4, ay + 6), Theme.sub, 27, true)
            if click and arrowHovered then
                ProjectState.tabTargetScrollX = min(maxScroll, target + tabH)
                click = false
            end
        end
        
        if needsScroll and ProjectState.tabScrollToActive and ProjectState.activeTab then
            local idx = ProjectState.activeIndex or 1
            local tabStart = tabH * (idx - 1)
            local tabEnd = tabStart + tabH
            local visibleStart = scrollY
            local visibleEnd = scrollY + contentH
            if tabStart < visibleStart then
                ProjectState.tabTargetScrollX = tabStart
            elseif tabEnd > visibleEnd then
                ProjectState.tabTargetScrollX = tabEnd - contentH
            end
            ProjectState.tabScrollToActive = false
        end
        
        if Input.m1.released then
            ProjectState.draggedTab = nil
        end
        
        for i = 1, count do
            local tab = ProjectState.tabs[i]
            local localTy = tabH * (i - 1)
            tab.targetY = localTy
            if not tab.currentY then
                tab.currentY = localTy
            end
            
            local screenY = contentY + tab.currentY - scrollY
            local hovered = over(tabX, screenY, tabW, tabH)
            
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
                if abs(ProjectState.mouseY - ProjectState.dragTabStartMouseY) > 5 then
                    tab.currentY = clamp(ProjectState.mouseY - ProjectState.draggedTabOffset - contentY + scrollY, 0, totalH - tabH)
                    
                    local idx = i
                    if idx > 1 then
                        local prevTab = ProjectState.tabs[idx - 1]
                        if tab.currentY < prevTab.currentY then
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
                        if tab.currentY > nextTab.currentY then
                            ProjectState.tabs[idx], ProjectState.tabs[idx + 1] = ProjectState.tabs[idx + 1], ProjectState.tabs[idx]
                            if ProjectState.activeIndex == idx then
                                ProjectState.activeIndex = idx + 1
                            elseif ProjectState.activeIndex == idx + 1 then
                                ProjectState.activeIndex = idx
                            end
                        end
                    end
                else
                    tab.currentY = smoothValue(tab.currentY, localTy, 18)
                end
            else
                tab.currentY = smoothValue(tab.currentY, localTy, 18)
            end
        end
        
        local targetPillY = nil
        local targetPillH = nil
        
        for i = 1, count do
            local tab = ProjectState.tabs[i]
            local ty = contentY + tab.currentY - scrollY
            local visible = ty + tabH >= contentY and ty <= contentY + contentH
            if visible then
                local active = ProjectState.activeTab == tab
                local hovered = over(tabX, ty, tabW, tabH)
                if active then
                    targetPillY = tab.currentY - scrollY + 3
                    targetPillH = tabH - 6
                    txt(tab.name, tabX + tabW / 2, centerY(ty, tabH), Theme.accent, 12, FontBold, 25, true, false, tabW - 8)
                else
                    txt(tab.name, tabX + tabW / 2, centerY(ty, tabH), hovered and Theme.text or Theme.sub, 12, FontSystem, 25, true, false, tabW - 8)
                end
            end
        end
        
        if targetPillY and targetPillH then
            if not ProjectState.currentPillY then
                ProjectState.currentPillY = targetPillY
                ProjectState.currentPillH = targetPillH
            elseif ProjectState.tabAnimations == false then
                ProjectState.currentPillY = targetPillY
                ProjectState.currentPillH = targetPillH
            else
                ProjectState.currentPillY = smoothValue(ProjectState.currentPillY, targetPillY, 18)
                ProjectState.currentPillH = smoothValue(ProjectState.currentPillH, targetPillH, 18)
            end
        end
        
        if ProjectState.currentPillY and ProjectState.currentPillH then
            rect(tabX + 4, contentY + ProjectState.currentPillY, tabW - 8, ProjectState.currentPillH, Theme.accent, 21, 6, 0.08)
            strokeRect(tabX + 4, contentY + ProjectState.currentPillY, tabW - 8, ProjectState.currentPillH, Theme.accent, 22, 6)
        end
        
        return click
    end

    ProjectState.currentPillY = nil
    ProjectState.currentPillH = nil
    local totalW = count * tabMinW
    local needsScroll = totalW > pw
    local tabW = needsScroll and tabMinW or (pw / count)
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
        local arrowHovered = over(px, py, 18, tabH)
        rect(px, py, 18, tabH, arrowHovered and Theme.surface3 or Theme.surface, 26, 0)
        local cy = centerY(py, tabH)
        triangle(v2(px + 6, cy), v2(px + 12, cy - 4), v2(px + 12, cy + 4), Theme.sub, 27, true)
        if click and arrowHovered then
            ProjectState.tabTargetScrollX = max(0, target - tabMinW)
            click = false
        end
    end

    if needsScroll and scrollX < maxScroll - 1 then
        local ax = px + pw - 18
        local arrowHovered = over(ax, py, 18, tabH)
        rect(ax, py, 18, tabH, arrowHovered and Theme.surface3 or Theme.surface, 26, 0)
        local cy = centerY(py, tabH)
        triangle(v2(ax + 12, cy), v2(ax + 6, cy - 4), v2(ax + 6, cy + 4), Theme.sub, 27, true)
        if click and arrowHovered then
            ProjectState.tabTargetScrollX = min(maxScroll, target + tabMinW)
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
        local hovered = over(screenX, py, tabW, tabH)

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
            local hovered = over(tx, py, tabW, tabH)
            if active then
                targetPillX = tab.currentX - scrollX + 4
                targetPillW = tabW - 8
                txt(tab.name, tx + tabW / 2, centerY(py, tabH), Theme.text, 13, FontBold, 25, true, false, tabW - 12)
            else
                txt(tab.name, tx + tabW / 2, centerY(py, tabH), hovered and Theme.text or Theme.sub, 13, FontSystem, 25, true, false, tabW - 12)
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
        rect(contentX + ProjectState.currentPillX, py + 3, ProjectState.currentPillW, tabH - 6, Theme.accent, 21, 10, 0.08)
        strokeRect(contentX + ProjectState.currentPillX, py + 3, ProjectState.currentPillW, tabH - 6, Theme.accent, 22, 10)
    end

    return click
end

local function renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
    local currentX = rowX + rowW - 4

    if item.keybind then
        local keyText = "-"
        if item.keybind.listening then
            if item.keybind.modifierPressed then
                keyText = item.keybind.modifierPressed .. " + ?"
            else
                keyText = "?"
            end
        elseif item.keybind.value then
            keyText = item.keybind.value
        end
        local textToDraw = string.upper(keyText):gsub("%+", " + ")
        if not item.keybind.listening then
            textToDraw = textToDraw .. " [" .. string.sub(item.keybind.mode or "Hold", 1, 1):upper() .. "]"
        end
        local neededW = math.max(46, textWidth(textToDraw, 12, FontUI) + 12)
        currentX = currentX - neededW - 2
        local keyX = currentX
        local hovered = over(keyX, rowY + 3, neededW, 20)

        rect(keyX, rowY + 3, neededW, 20, Theme.surface3, 45, 4, trans)
        strokeRect(keyX, rowY + 3, neededW, 20, hovered and Theme.accent or Theme.border, 46, 4, trans)

        txt(textToDraw, keyX + neededW / 2, centerY(rowY + 3, 20), (item.keybind.listening or item.keybind.value) and Theme.text or Theme.sub, 12, FontUI, 52, true, false, neededW - 4, trans)

        if item.keybind.listening then
            for j = 1, 8 do
                circle(
                    (keyX - 10) + 5 * math.cos((j - 1) * 0.785398 + clock() * 8),
                    (centerY(rowY + 3, 20)) + 5 * math.sin((j - 1) * 0.785398 + clock() * 8),
                    1.2,
                    Theme.accent,
                    50,
                    true,
                    nil,
                    8,
                    trans * (j / 8)
                )
            end

            for i = 1, #InputOrder do
                local name = InputOrder[i]
                local input = Input[name]
                if input.click and (name ~= "m1" or clock() - item.keybind.listenAt > 0.25) then
                    local newKey = normalizeKey(name)
                    if name == "backspace" or name == "delete" or name == "unbound" or name == "esc" then
                        item.keybind.value = nil
                        item.keybind.modifierPressed = nil
                        item.keybind.listening = false
                        safeCallback(item.keybind.callback, nil, item.keybind.mode)
                        break
                    end
                    
                    local isMod = (name == "ctrl" or name == "alt" or name == "shift" or name == "lctrl" or name == "rctrl" or name == "lalt" or name == "ralt" or name == "lshift" or name == "rshift")
                    if isMod then
                        if item.keybind.modifierPressed then
                            if item.keybind.modifierPressed ~= name then
                                item.keybind.modifierPressed = name
                            end
                        else
                            item.keybind.modifierPressed = name
                        end
                    else
                        local keyVal = newKey
                        if item.keybind.modifierPressed then
                            keyVal = item.keybind.modifierPressed .. "+" .. newKey
                        end
                        item.keybind.value = keyVal
                        item.keybind.modifierPressed = nil
                        item.keybind.listening = false
                        safeCallback(item.keybind.callback, keyVal, item.keybind.mode)
                        break
                    end
                end
            end
        elseif click and hovered then
            item.keybind.listening = true
            item.keybind.modifierPressed = nil
            item.keybind.listenAt = clock()
            click = false
        elseif rightClick and hovered and item.keybind.canChange then
            dDropdown("keymode", keyX, rowY + 24, 90, {"Hold", "Toggle", "Always"}, nil, false, nil, nil, item.keybind)
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
                    ProjectState.copiedAlpha = item.colorpicker.alpha or 1
                    pcall(setclipboard, "#" .. toHex(item.colorpicker.value, item.colorpicker.alpha))
                elseif choice and choice[1] == "Paste" then
                    if ProjectState.copiedColor then
                        item.colorpicker.value = ProjectState.copiedColor
                        item.colorpicker.alpha = ProjectState.copiedAlpha or 1
                        safeCallback(item.colorpicker.callback, item.colorpicker.value, item.colorpicker.alpha)
                    else
                        warn("color clipboard empty")
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
        item.cachedLineCount = #labelLines
        return math.max(28, #labelLines * 16 + 8)
    elseif item.type == "checkbox" and item.keybind then
        return 36
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
    local cardClipTop = isFloating and (ProjectState.y + 36) or clipTop
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
            local dMouse
            if cy == renderY then
                dMouse = cx - colX - 8
            elseif cx == colX + colW then
                dMouse = colW - 3.434 + (cy - renderY - 8)
            elseif cy == renderY + renderH then
                dMouse = colW + renderH - 6.868 + (colX + colW - 8 - cx)
            elseif cx == colX then
                dMouse = 2 * colW + renderH - 10.302 + (renderY + renderH - 8 - cy)
            end
            
            if dMouse then
                for i = 1, 24 do
                    local x1, y1 = getPerimeterPoint(dMouse - 40 + (i - 1) * 3.333, colX, renderY, colW, renderH)
                    local x2, y2 = getPerimeterPoint(dMouse - 40 + i * 3.333, colX, renderY, colW, renderH)
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
            draw9Dot(colX + colW - 20, sy + 10, (showLock and section.locked) and c3(80, 75, 73) or Theme.sub, z + 2, hTrans)
            if showLock then
                drawLockIcon(colX + colW - 38, iconY, section.locked and Theme.accent or Theme.sub, z + 2, section.locked and hTrans or hTrans * 0.5, not section.locked)
            end

            if section.name == "Configs" or section.name == "Themes" then
                local expX = colX + colW - 54
                local expHovered = not popupBlocking and over(expX - 2, sy + 4, 14, 20) and headerTrans > 0.5
                local expColor = expHovered and Theme.accent or Theme.sub
                drawExportIcon(expX - 2, iconY - 2, expColor, z + 2, hTrans * (expHovered and 1 or 0.6))

                local impX = colX + colW - 70
                local impHovered = not popupBlocking and over(impX - 2, sy + 4, 14, 20) and headerTrans > 0.5
                local impColor = impHovered and Theme.accent or Theme.sub
                drawImportIcon(impX - 2, iconY - 2, impColor, z + 2, hTrans * (impHovered and 1 or 0.6))

                if not isFloating and click and headerTrans > 0.5 then
                    if expHovered then
                        click = false
                        if section.name == "Configs" then
                            if pcall(setclipboard, exportConfig()) then
                                warn("config code copied to clipboard")
                            else
                                warn("failed to copy config to clipboard")
                            end
                        else
                            if pcall(setclipboard, exportTheme()) then
                                warn("theme code copied to clipboard")
                            else
                                warn("failed to copy theme to clipboard")
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
                                    warn("config imported successfully")
                                else
                                    importTheme(code)
                                    warn("theme imported successfully")
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
        
        local rowW = colW - 24
        local rowX = colX + 12
        local rowY = sy + 28
        
        local totalItemsH = 0
        for k = 1, #section.items do
            totalItemsH = totalItemsH + getItemHeight(section.items[k], rowW)
        end
        local isClipped = section.customHeight and (secH - 34 < totalItemsH)
        
        for ii = 1, #section.items do
            local item = section.items[ii]
            local itemH = getItemHeight(item, rowW)
            local disabled = isItemDisabled(item)
            local trans = (disabled and 0.4 or 1) * cardTrans * min(clamp((rowY - cardClipTop) / 16, 0, 1), clamp((cardClipBottom - (rowY + itemH)) / 16, 0, 1))
            if isClipped then
                trans = trans * clamp(((sy + secH - 4) - (rowY + itemH)) / 16, 0, 1)
            end
            
            if trans > 0 then
                if item.type == "label" then
                    local labelLines = wrapLines(item.label, rowW, 13, FontSystem)
                    item.cachedLineCount = #labelLines
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
                    txt(item.label, rowX + 26, textTop(rowY, (item.keybind and 28 or itemH) - 2, 13), item.unsafe and Theme.unsafe or (item.value and Theme.text or Theme.sub), 13, FontSystem, z + 12, false, false, rowW - 26 - cbExtra, trans)
                    
                    if not isFloating then
                        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
                    end
                    
                    if item.tooltip and over(rowX, rowY, rowW, itemH) and not disabled and trans > 0.5 then
                        tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
                    end
                    
                    if click and over(rowX, rowY, rowW, itemH) and not popupBlocking and not disabled and trans > 0.5 then
                        local onKeybind = item.keybind and over(rowX + rowW - 96, rowY + 3, 46, 20)
                        local onColor = item.colorpicker and over(rowX + rowW - 127, rowY + 5, 18, 18)
                        local on9Dot = over(colX + colW - 22, sy + 8, 14, 14)
                        if not onKeybind and not onColor and not on9Dot then
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
                                ProjectState.copiedAlpha = item.alpha or 1
                                pcall(setclipboard, "#" .. toHex(item.value, item.alpha))
                            elseif choice and choice[1] == "Paste" then
                                if ProjectState.copiedColor then
                                    item.value = ProjectState.copiedColor
                                    item.alpha = ProjectState.copiedAlpha or 1
                                    safeCallback(item.callback, item.value, item.alpha)
                                else
                                    warn("color clipboard empty")
                                end
                            end
                        end, nil, nil)
                        rightClick = false
                    end
 
                elseif item.type == "slider" then
                    txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 80, trans)
                    
                    local isFocusedSlider = ProjectState.focus == item
                    local valStr = isFocusedSlider and (item.directValue or "") or tostring(item.value)
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
                        item.directValue = tostring(item.value)
                        click = false
                    end
                    
                    local sx, sw = rowX + 4, rowW - 8
                    local syBar = rowY + 22
                    local denom = max(0.0001, (item.max or 100) - (item.min or 0))
                    local frac = clamp(((item.value or 0) - (item.min or 0)) / denom, 0, 1)
                    
                    rect(sx, syBar, sw, 4, Theme.surface3, z + 12, 2, trans)
                    if frac > 0 then
                        rect(sx, syBar, sw * frac, 4, Theme.accent, z + 13, 2, trans)
                    end
                    
                    item.animatedRadius = item.animatedRadius or 5
                    item.animatedRadius = smoothValue(item.animatedRadius, (hoveredVal or (over(sx - 4, syBar - 8, sw + 8, 16) and not popupBlocking and not disabled)) and 7 or 5, 18)
                    circle(sx + sw * frac, syBar + 2, item.animatedRadius, c3(190, 190, 190), z + 14, true, 0, 32, trans)
                    
                    if click and over(sx - 4, syBar - 8, sw + 8, 16) and not popupBlocking and not disabled and not hoveredVal and trans > 0.5 then
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
                    local dyBox = rowY + 18
                    local boxH = 22
                    
                    rect(dx, dyBox, dw, boxH, over(dx, dyBox, dw, boxH) and Theme.surface3 or Theme.surface2, z + 12, 4, trans)
                    strokeRect(dx, dyBox, dw, boxH, Theme.border, z + 13, 4, trans)
                    
                    txt(item.multi and (#item.value > 0 and concat(item.value, ", ") or "-") or (item.value[1] or "-"), dx + 8, textTop(dyBox, boxH, 13), Theme.text, 13, FontSystem, z + 14, false, false, dw - 28, trans)
                    
                    if ProjectState.dropdown and ProjectState.dropdown.item == item then
                        drawChevronUp(dx + dw - 15, centerY(dyBox, boxH) - 2, Theme.sub, z + 15, trans)
                    else
                        drawChevronDown(dx + dw - 15, centerY(dyBox, boxH) - 2, Theme.sub, z + 15, trans)
                    end
                    
                    if item.tooltip and over(rowX, rowY, rowW, itemH) and not disabled and trans > 0.5 then
                        tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
                    end
                    
                    if click and over(dx, dyBox, dw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
                        dDropdown("item", dx, dyBox + boxH, dw, item.choices, item.value, item.multi, item.callback, item, nil)
                        click = false
                    end
                    
                elseif item.type == "button" then
                    local controlY = rowY + 2
                    item.hoverFactor = smoothValue(item.hoverFactor or 0, (over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled) and 1 or 0, 18)
                    
                    rect(rowX + 4, controlY, rowW - 8, itemH - 4, Theme.accent, z + 12, 6, trans * (0.1 + 0.15 * item.hoverFactor))
                    strokeRect(rowX + 4, controlY, rowW - 8, itemH - 4, Theme.accent, z + 13, 6, trans * (0.4 + 0.6 * item.hoverFactor))
                    
                    txt(item.label, rowX + rowW / 2, centerY(controlY, itemH - 4), Theme.accent, 13, FontBold, z + 14, true, false, rowW - 24, trans)
                    
                    if click and over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled and trans > 0.5 then
                        safeCallback(item.callback)
                        click = false
                    end
                    
                elseif item.type == "textbox" then
                    txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 20, trans)
                    
                    local bx, bw = rowX + 4, rowW - 8
                    local dyBox = rowY + 18
                    local boxH = 22
                    local focused = ProjectState.focus == item
                    
                    rect(bx, dyBox, bw, boxH, focused and Theme.surface or over(bx, dyBox, bw, boxH) and Theme.surface3 or Theme.surface2, z + 12, 4, trans)
                    strokeRect(bx, dyBox, bw, boxH, focused and Theme.accent or Theme.border, z + 13, 4, trans)
                    
                    local isEmpty = item.value == ""
                    local textTrans = (focused and isEmpty) and trans * 0.2 or trans
                    txt(isEmpty and item.label or item.value, bx + 8, textTop(dyBox, boxH, 13), isEmpty and Theme.sub or Theme.text, 13, FontUI, z + 14, false, false, bw - 16, textTrans)
                    if focused then
                        if item.selectedAll and not isEmpty then
                            rect(bx + 8, dyBox + 3, math.min(bw - 16, textWidth(item.value, 13, FontUI)), boxH - 6, Theme.accent, z + 13, 2, trans * 0.4)
                        end
                        local cursorX = bx + 8
                        if not isEmpty then
                            cursorX = cursorX + textWidth(item.value, 13, FontUI)
                        end
                        txt("|", cursorX, textTop(dyBox, boxH, 13), Theme.text, 13, FontUI, z + 15, false, false, nil, trans * clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
                    end
                    
                    if click and over(bx, dyBox, bw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
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
        local colW = sec.customWidth or ((sec.side == "Full") and pw or floor((pw - 10) / 2))
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
        local colW = sec.customWidth or ((sec.side == "Full") and pw or floor((pw - 10) / 2))
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
    local viewH = max(1, contH - contentPad * 2)
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

    local sy = contY + contentPad - tab.scrollY
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
            targetLocalW = section.customWidth or pw
            leftY = max(leftY, rightY) + secH + 10
            rightY = leftY
        elseif section.side == "Right" then
            targetLocalW = section.customWidth or colW
            targetLocalX = (section.customWidth and (pw - section.customWidth)) or (colW + 10)
            targetLocalY = rightY - sy
            rightY = rightY + secH + 10
        else
            targetLocalW = section.customWidth or colW
            targetLocalX = 0
            targetLocalY = leftY - sy
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
            dragSec.customWidth or ((dragSec.side == "Full") and pw or colW),
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
        local trackH = contH - contentPad * 2 - 12
        local barH = max(22, (trackH / max(contentH, trackH)) * trackH)
        local barY = contY + contentPad + 6 + (tab.scrollY / max(1, tab.maxScroll)) * (trackH - barH)
        local scrollBarX = ProjectState.x + ProjectState.w - 12
        rect(scrollBarX, contY + contentPad + 6, 3, trackH, Theme.surface3, 50, 2, ProjectState.contentFade)
        rect(scrollBarX, barY, 3, barH, Theme.accent, 51, 2, ProjectState.contentFade)
        if click and over(scrollBarX - 5, contY + contentPad + 6, 14, trackH) and not popupBlocking then
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
            tab.targetScrollY = clamp((ProjectState.mouseY - (contY + contentPad + 6) - drag.grab) / max(1, trackH - barH), 0, 1) * tab.maxScroll
        end
    elseif type(ProjectState.scrollDrag) == "table" and ProjectState.scrollDrag.tab == tab then
        ProjectState.scrollDrag = nil
    end

    return click, held, rightClick
end

local function serializeConfigData()
    local configData = {}
    configData.system = {
        tabsPosition = ProjectState.tabsPosition,
        titlePosition = ProjectState.titlePosition,
        hotkeyEnabled = ProjectState.hotkeyEnabled,
        autoloadConfig = ProjectState.autoloadConfig,
        autoloadTheme = ProjectState.autoloadTheme,
        tabAnimations = ProjectState.tabAnimations,
        gridLocking = ProjectState.gridLocking,
        tooltipsEnabled = ProjectState.tooltipsEnabled,
        hoverEffects = ProjectState.hoverEffects,
        isrbxactiveOverride = ProjectState.isrbxactiveOverride,
        spotlightEnabled = ProjectState.spotlightEnabled,
        spotlightKeybind = ProjectState.spotlightKeybind,
        caretEnabled = ProjectState.caretEnabled ~= false,
    }
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

local function loadConfig(json, force)
    if not json then
        local ok, raw = pcall(readfile, "homesick/config.json")
        if ok and raw then
            json = raw
        end
    end
    if not json or json == "" then return end
    local decodeOk, configData = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), json)
    if decodeOk and decodeOk == true and type(configData) == "table" then
        if configData.system then
            ProjectState.tabsPosition = configData.system.tabsPosition or "top"
            ProjectState.titlePosition = configData.system.titlePosition or "top"
            ProjectState.hotkeyEnabled = configData.system.hotkeyEnabled == true
            ProjectState.autoloadConfig = configData.system.autoloadConfig == true
            ProjectState.autoloadTheme = configData.system.autoloadTheme == true
            if configData.system.tabAnimations ~= nil then
                ProjectState.tabAnimations = configData.system.tabAnimations == true
            end
            if configData.system.gridLocking ~= nil then
                ProjectState.gridLocking = configData.system.gridLocking == true
            end
            if configData.system.tooltipsEnabled ~= nil then
                ProjectState.tooltipsEnabled = configData.system.tooltipsEnabled == true
            end
            if configData.system.hoverEffects ~= nil then
                ProjectState.hoverEffects = configData.system.hoverEffects == true
            end
            ProjectState.isrbxactiveOverride = configData.system.isrbxactiveOverride == true
            ProjectState.spotlightEnabled = configData.system.spotlightEnabled ~= false
            ProjectState.spotlightKeybind = configData.system.spotlightKeybind or "ctrl+space"
            if configData.system.caretEnabled ~= nil then
                ProjectState.caretEnabled = configData.system.caretEnabled == true
            else
                ProjectState.caretEnabled = true
            end
        end
        if force or ProjectState.autoloadConfig then
            for _, t in ipairs(ProjectState.tabs) do
                for _, s in ipairs(t.sections) do
                    for _, item in ipairs(s.items) do
                        local key = t.name .. "." .. s.name .. "." .. item.label
                        local data = configData[key]
                        if data then
                            if item.type == "colorpicker" then
                                pcall(function()
                                    item.value = c3Hex("#" .. tostring(data.value or "FFFFFF"))
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
                                    item.colorpicker.value = c3Hex("#" .. tostring(data.colorpicker.value or "FFFFFF"))
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
        themeData[k] = { color = toHex(v), alpha = ThemeAlpha[k] or 1.0 }
    end
    local _, json = pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), themeData)
    if json and json ~= "" then
        pcall(writefile, "homesick/theme.json", json)
    end
end

local function loadTheme(jsonOrTable)
    local themeData = nil
    if type(jsonOrTable) == "table" then
        themeData = jsonOrTable
    else
        local json = jsonOrTable or select(2, pcall(readfile, "homesick/theme.json"))
        if json and json ~= "" then
            local ok, decoded = pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), json)
            if ok then themeData = decoded end
        end
    end
    if type(themeData) == "table" then
        for k, v in pairs(themeData) do
            if Theme[k] ~= nil then
                local alphaVal = 1.0
                local colorVal = nil
                if type(v) == "table" then
                    if v.color then
                        colorVal = c3Hex(string.sub(v.color, 1, 1) == "#" and v.color or "#" .. v.color)
                        alphaVal = tonumber(v.alpha) or 1.0
                    else
                        colorVal = c3(v[1] or 255, v[2] or 255, v[3] or 255)
                    end
                elseif type(v) == "userdata" then
                    colorVal = v
                else
                    colorVal = c3Hex(string.sub(tostring(v), 1, 1) == "#" and tostring(v) or "#" .. tostring(v))
                end
                if colorVal then
                    Theme[k] = colorVal
                    ThemeAlpha[k] = alphaVal
                    if ProjectState.themeColorPickers and ProjectState.themeColorPickers[k] then
                        ProjectState.themeColorPickers[k]:Set(colorVal, alphaVal)
                    end
                end
            end
        end
    end
end

exportTheme = function()
    local themeData = {}
    for k, v in pairs(Theme) do
        themeData[k] = { color = toHex(v), alpha = ThemeAlpha[k] or 1.0 }
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
                themeData[k] = { color = toHex(v), alpha = ThemeAlpha[k] or 1.0 }
            end
            local json = select(2, pcall(game:GetService("HttpService").JSONEncode, game:GetService("HttpService"), themeData))
            if json and json ~= "" then
                pcall(writefile, "homesick/themes/" .. name .. ".json", json)
                themeDropdown:UpdateChoices(getThemesList())
            end
        end
    end)
    themeSection:Button("Reset to Default", function()
        for k, v in pairs({
            bg = c3(36, 33, 31),
            surface = c3(30, 27, 25),
            surface2 = c3(44, 40, 37),
            surface3 = c3(54, 50, 46),
            text = c3(245, 242, 238),
            sub = c3(150, 142, 135),
            accent = c3(232, 208, 162),
            green = c3(52, 199, 89),
            red = c3(255, 69, 58),
            yellow = c3(255, 204, 0),
            unsafe = c3(255, 226, 84),
            border = c3(60, 55, 52),
            white = c3(255, 255, 255),
            black = c3(0, 0, 0),
        }) do
            Theme[k] = v
            ThemeAlpha[k] = 1.0
            if ProjectState.themeColorPickers and ProjectState.themeColorPickers[k] then
                ProjectState.themeColorPickers[k]:Set(v)
            end
        end
        saveTheme()
    end)

    local generalSec = createSection(settingsTab, "General Settings", "Full")
    generalSec:Checkbox("isrbxactive()", ProjectState.isrbxactiveOverride == true, function(val)
        ProjectState.isrbxactiveOverride = val
        pcall(saveConfig)
    end)
    generalSec:Checkbox("Tab Animations", ProjectState.tabAnimations ~= false, function(val)
        ProjectState.tabAnimations = val
        pcall(saveConfig)
    end)
    generalSec:Checkbox("Grid Locking", ProjectState.gridLocking ~= false, function(val)
        ProjectState.gridLocking = val
        pcall(saveConfig)
    end)
    generalSec:Checkbox("show tooltips", ProjectState.tooltipsEnabled ~= false, function(val)
        ProjectState.tooltipsEnabled = val
        pcall(saveConfig)
    end)
    generalSec:Checkbox("Checkbox Animations", ProjectState.hoverEffects ~= false, function(val)
        ProjectState.hoverEffects = val
        pcall(saveConfig)
    end)
    generalSec:Checkbox("Hotkey Overlay", ProjectState.hotkeyEnabled == true, function(val)
        ProjectState.hotkeyEnabled = val
        pcall(saveConfig)
    end)
    generalSec:Checkbox("autoload config", ProjectState.autoloadConfig == true, function(val)
        ProjectState.autoloadConfig = val
        pcall(saveConfig)
    end)
    generalSec:Checkbox("autoload theme", ProjectState.autoloadTheme == true, function(val)
        ProjectState.autoloadTheme = val
        pcall(saveConfig)
    end)
    generalSec:Checkbox("writing caret", ProjectState.caretEnabled ~= false, function(val)
        ProjectState.caretEnabled = val
        pcall(saveConfig)
    end)
    local spotlightCheckbox = generalSec:Checkbox("Spotlight Search", ProjectState.spotlightEnabled ~= false, function(val)
        ProjectState.spotlightEnabled = val
        pcall(saveConfig)
    end)
    spotlightCheckbox:AddKeybind(ProjectState.spotlightKeybind or "ctrl+space", "Toggle", true, function(key, mode)
        ProjectState.spotlightKeybind = key
        pcall(saveConfig)
    end)
    generalSec:Button("Toggle Layout Editor", function()
        ProjectState.layoutEditing = true
        ProjectState.settingsActive = false
        ProjectState.contentFade = 0
    end)

    local colorsSec = createSection(settingsTab, "Theming", "Full")
    local fontNames = {"System", "ui", "SystemBold", "Minecraft", "Monospace", "Pixel", "Fortnite"}
    local fontMap = {
        System = Fonts.System or 0,
        ui = Fonts.UI or 0,
        SystemBold = Fonts.SystemBold or 0,
        Minecraft = Fonts.Minecraft or 0,
        Monospace = Fonts.Monospace or 0,
        Pixel = Fonts.Pixel or 0,
        Fortnite = Fonts.Fortnite or 0,
    }
    colorsSec:Dropdown("Font", {"System"}, fontNames, false, function(picked)
        if picked and #picked > 0 then
            local f = fontMap[picked[1]]
            if f then
                FontSystem = f
                FontUI = f
                FontBold = fontMap.SystemBold or f
            end
        end
    end)
    ProjectState.themeColorPickers = {}
    local pickers = {"accent", "bg", "surface", "surface2", "surface3", "text", "sub", "border", "green", "red", "yellow", "unsafe"}
    for idx = 1, #pickers do
        local name = pickers[idx]
        ProjectState.themeColorPickers[name] = colorsSec:Colorpicker(
            name == "accent" and "Accent Color" or
            name == "bg" and "Window Background" or
            name == "surface" and "Section Background" or
            name == "surface2" and "Widget Background (Inactive)" or
            name == "surface3" and "Widget Background (Hovered/Active)" or
            name == "text" and "Primary Text" or
            name == "sub" and "Subtext" or
            name == "border" and "Border Color" or
            name == "green" and "Success/Green Accent" or
            name == "red" and "Error/Red Accent" or
            name == "yellow" and "Warning/Yellow Accent" or
            "Unsafe/Caution Accent",
            Theme[name],
            true,
            function(color, alpha)
                Theme[name] = color
                ThemeAlpha[name] = alpha or 1.0
            end
        )
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
        
        txt(item.label, rowX + 26, textTop(rowY, (item.keybind and 28 or itemH) - 2, 13), item.unsafe and Theme.unsafe or (item.value and Theme.text or Theme.sub), 13, FontSystem, z + 12, false, false, rowW - 26 - (6 + (item.colorpicker and 20 or 0) + (item.keybind and 64 or 0)), trans)
        
        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick, trans)
        
        if item.tooltip and over(rowX, rowY, rowW, itemH) and not disabled and trans > 0.5 then
            tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
        end
        
        if click and over(rowX, rowY, rowW, itemH) and not popupBlocking and not disabled and trans > 0.5 then
            if not (item.keybind and over(rowX + rowW - 96, rowY + 3, 46, 20)) and not (item.colorpicker and over(rowX + rowW - 127, rowY + 5, 18, 18)) then
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
                    ProjectState.copiedAlpha = item.alpha or 1
                    pcall(setclipboard, "#" .. toHex(item.value, item.alpha))
                elseif choice and choice[1] == "Paste" then
                    if ProjectState.copiedColor then
                        item.value = ProjectState.copiedColor
                        item.alpha = ProjectState.copiedAlpha or 1
                        safeCallback(item.callback, item.value, item.alpha)
                    else
                        warn("color clipboard is empty")
                    end
                end
            end, nil, nil)
            rightClick = false
        end

    elseif item.type == "slider" then
        txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 80, trans)
        
        local isFocusedSlider = ProjectState.focus == item
        local valStr = isFocusedSlider and (item.directValue or "") or tostring(item.value)
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
            item.directValue = tostring(item.value)
            click = false
        end
        
        local sx, sw = rowX + 4, rowW - 8
        local syBar = rowY + 22
        local frac = clamp(((item.value or 0) - (item.min or 0)) / max(0.0001, (item.max or 100) - (item.min or 0)), 0, 1)
        
        rect(sx, syBar, sw, 4, Theme.surface3, z + 12, 2, trans)
        if frac > 0 then
            rect(sx, syBar, sw * frac, 4, Theme.accent, z + 13, 2, trans)
        end
        
        item.animatedRadius = item.animatedRadius or 5
        item.animatedRadius = smoothValue(item.animatedRadius, (hoveredVal or (over(sx - 4, syBar - 8, sw + 8, 16) and not popupBlocking and not disabled)) and 7 or 5, 18)
        circle(sx + sw * frac, syBar + 2, item.animatedRadius, c3(190, 190, 190), z + 14, true, 0, 32, trans)
        
        if click and over(sx - 4, syBar - 8, sw + 8, 16) and not popupBlocking and not disabled and not hoveredVal and trans > 0.5 then
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
        local dyBox = rowY + 18
        local boxH = 22
        
        rect(dx, dyBox, dw, boxH, over(dx, dyBox, dw, boxH) and Theme.surface3 or Theme.surface2, z + 12, 4, trans)
        strokeRect(dx, dyBox, dw, boxH, Theme.border, z + 13, 4, trans)
        
        txt(item.multi and (#item.value > 0 and concat(item.value, ", ") or "-") or (item.value[1] or "-"), dx + 8, textTop(dyBox, boxH, 13), Theme.text, 13, FontSystem, z + 14, false, false, dw - 28, trans)
        
        if ProjectState.dropdown and ProjectState.dropdown.item == item then
            drawChevronUp(dx + dw - 15, centerY(dyBox, boxH) - 2, Theme.sub, z + 15, trans)
        else
            drawChevronDown(dx + dw - 15, centerY(dyBox, boxH) - 2, Theme.sub, z + 15, trans)
        end
        
        if item.tooltip and over(rowX, rowY, rowW, itemH) and not disabled and trans > 0.5 then
            tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
        end
        
        if click and over(dx, dyBox, dw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
            dDropdown("item", dx, dyBox + boxH, dw, item.choices, item.value, item.multi, item.callback, item, nil)
            click = false
        end
        
    elseif item.type == "button" then
        local controlY = rowY + 2
        item.hoverFactor = smoothValue(item.hoverFactor or 0, (over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled) and 1 or 0, 18)
        
        rect(rowX + 4, controlY, rowW - 8, itemH - 4, Theme.accent, z + 12, 6, trans * (0.1 + 0.15 * item.hoverFactor))
        strokeRect(rowX + 4, controlY, rowW - 8, itemH - 4, Theme.accent, z + 13, 6, trans * (0.4 + 0.6 * item.hoverFactor))
        
        txt(item.label, rowX + rowW / 2, centerY(controlY, itemH - 4), Theme.accent, 13, FontBold, z + 14, true, false, rowW - 24, trans)
        
        if click and over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled and trans > 0.5 then
            safeCallback(item.callback)
            click = false
        end
        
    elseif item.type == "textbox" then
        txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 20, trans)
        
        local bx, bw = rowX + 4, rowW - 8
        local dyBox = rowY + 18
        local boxH = 22
        local focused = ProjectState.focus == item
        
        rect(bx, dyBox, bw, boxH, focused and Theme.surface or over(bx, dyBox, bw, boxH) and Theme.surface3 or Theme.surface2, z + 12, 4, trans)
        strokeRect(bx, dyBox, bw, boxH, focused and Theme.accent or Theme.border, z + 13, 4, trans)
        
        txt((item.value == "") and item.label or item.value, bx + 8, textTop(dyBox, boxH, 13), (item.value == "") and Theme.sub or Theme.text, 13, FontUI, z + 14, false, false, bw - 16, trans)
        if focused then
            if item.selectedAll and not (item.value == "") then
                rect(bx + 8, dyBox + 3, math.min(bw - 16, textWidth(item.value, 13, FontUI)), boxH - 6, Theme.accent, z + 13, 2, trans * 0.4)
            end
            local cursorX = bx + 8
            if not (item.value == "") then
                cursorX = cursorX + textWidth(item.value, 13, FontUI)
            end
            txt("|", cursorX, textTop(dyBox, boxH, 13), Theme.text, 13, FontUI, z + 15, false, false, nil, trans * clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
        end
        
        if click and over(bx, dyBox, bw, boxH) and not popupBlocking and not disabled and trans > 0.5 then
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
    
    local dummyY = py + contentPad
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
    local searchContentH = dummyY - (py + contentPad)
    
    ProjectState.searchMaxScroll = max(0, searchContentH - max(1, ph - contentPad * 2))
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
    
    local currentY = py + contentPad - ProjectState.searchScrollY
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
        local trackH = ph - contentPad * 2 - 12
        local barH = max(22, (trackH / max(searchContentH, trackH)) * trackH)
        local barY = py + contentPad + 6 + (ProjectState.searchScrollY / max(1, ProjectState.searchMaxScroll)) * (trackH - barH)
        local scrollBarX = ProjectState.x + ProjectState.w - 12
        rect(scrollBarX, py + contentPad + 6, 3, trackH, Theme.surface3, 50, 2, ProjectState.contentFade)
        rect(scrollBarX, barY, 3, barH, Theme.accent, 51, 2, ProjectState.contentFade)
        if click and over(scrollBarX - 5, py + contentPad + 6, 14, trackH) and not popupBlocking then
            ProjectState.scrollDrag = {
                search = true,
                grab = over(scrollBarX - 5, barY, 14, barH) and clamp(ProjectState.mouseY - barY, 0, barH) or (barH / 2),
            }
            click = false
        end
        
        if held and type(ProjectState.scrollDrag) == "table" and ProjectState.scrollDrag.search then
            ProjectState.searchTargetScrollY = clamp((ProjectState.mouseY - (py + contentPad + 6) - ProjectState.scrollDrag.grab) / max(1, trackH - barH), 0, 1) * ProjectState.searchMaxScroll
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

    local popupOpen = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil or ProjectState.importModal ~= nil or ProjectState.changelogOpen
    local orgClick = click

    local baseClick = popupOpen and false or click
    local baseHeld = popupOpen and false or held
    local baseRightClick = popupOpen and false or rightClick

    local titlePos = ProjectState.titlePosition or "top"
    local isVertTitle = titlePos == "left" or titlePos == "right"
    
    local titleBarX, titleBarY, titleBarW, titleBarH
    local px, py = x + 10, y + 10
    local pw, ph = w - 20, h - 20 - 24
    
    if titlePos == "left" then
        titleBarX, titleBarY, titleBarW, titleBarH = x + 2, y + 2, 36 - 2, h - 28
        px = px + 36
        pw = pw - 36
    elseif titlePos == "right" then
        titleBarX, titleBarY, titleBarW, titleBarH = x + w - 36, y + 2, 36 - 2, h - 28
        pw = pw - 36
    elseif titlePos == "bottom" then
        titleBarX, titleBarY, titleBarW, titleBarH = x + 2, y + h - 36 - 24, w - 4, 36 - 2
        ph = ph - 36
    else
        titleBarX, titleBarY, titleBarW, titleBarH = x + 2, y + 2, w - 4, 36 - 2
        py = py + 36
        ph = ph - 36
    end

    for i = 1, #shadowAlpha do
        local offset = i * 2
        rect(x - offset, y - offset + 6, w + offset * 2, h + offset * 2, Theme.black, 0, 12, shadowAlpha[i])
    end

    local glowIntensity = 0.35 + 0.2 * math.cos(clock() * 2.5)
    for i = 1, 3 do
        local offset = i * 3
        rect(x - offset, y - offset, w + offset * 2, h + offset * 2, Theme.accent, 0, 12, glowIntensity * (0.12 / i))
    end

    rect(x, y, w, h, Theme.surface, 5, (titlePos == "bottom") and 0 or 12)
    if titlePos == "left" or titlePos == "right" then
        rect(x, y + h - 12, w, 12, Theme.surface, 5, 0)
    end
    strokeRect(x, y, w, h, Theme.border, 6, (titlePos == "bottom") and 0 or 12)
    if titlePos == "left" or titlePos == "right" then
        rect(x + 1, y + h - 12, w - 2, 13, Theme.surface, 6, 0)
        line(x, y + h - 12, x, y + h, Theme.border, 6)
        line(x, y + h, x + w, y + h, Theme.border, 6)
        line(x + w, y + h - 12, x + w, y + h, Theme.border, 6)
    end

    local dragEdge = ProjectState.resizeEdge
    if held and dragEdge then
        if string.find(dragEdge, "left") then
            drawSideGlow(x, y + 8, x, y + h - 8, ProjectState.mouseX, ProjectState.mouseY, Theme.accent, 7)
        end
        if string.find(dragEdge, "right") then
            drawSideGlow(x + w, y + 8, x + w, y + h - 8, ProjectState.mouseX, ProjectState.mouseY, Theme.accent, 7)
        end
        if string.find(dragEdge, "top") then
            drawSideGlow(x + 8, y, x + w - 8, y, ProjectState.mouseX, ProjectState.mouseY, Theme.accent, 7)
        end
        if string.find(dragEdge, "bottom") then
            drawSideGlow(x + 8, y + h, x + w - 8, y + h, ProjectState.mouseX, ProjectState.mouseY, Theme.accent, 7)
        end
    end

    if titlePos == "top" then
        rect(titleBarX, titleBarY, titleBarW, titleBarH, Theme.surface2, 7, 10)
        rect(titleBarX, titleBarY + titleBarH / 2, titleBarW, titleBarH / 2, Theme.surface2, 7, 0)
        line(titleBarX, titleBarY + titleBarH, titleBarX + titleBarW, titleBarY + titleBarH, Theme.border, 8)
    elseif titlePos == "bottom" then
        rect(titleBarX, titleBarY, titleBarW, titleBarH, Theme.surface2, 7, 10)
        rect(titleBarX, titleBarY, titleBarW, titleBarH / 2, Theme.surface2, 7, 0)
        line(titleBarX, titleBarY, titleBarX + titleBarW, titleBarY, Theme.border, 8)
    elseif titlePos == "left" then
        rect(titleBarX, titleBarY, titleBarW, titleBarH, Theme.surface2, 7, 10)
        rect(titleBarX + titleBarW / 2, titleBarY, titleBarW / 2, titleBarH, Theme.surface2, 7, 0)
        line(titleBarX + titleBarW, titleBarY, titleBarX + titleBarW, titleBarY + titleBarH, Theme.border, 8)
    else
        rect(titleBarX, titleBarY, titleBarW, titleBarH, Theme.surface2, 7, 10)
        rect(titleBarX, titleBarY, titleBarW / 2, titleBarH, Theme.surface2, 7, 0)
        line(titleBarX, titleBarY, titleBarX, titleBarY + titleBarH, Theme.border, 8)
    end

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
        elseif over(titleBarX, titleBarY, titleBarW, titleBarH) then
            if ProjectState.layoutEditing then
                ProjectState.titleDrag = {ProjectState.mouseX - titleBarX, ProjectState.mouseY - titleBarY}
            else
                ProjectState.drag = {ProjectState.mouseX - x, ProjectState.mouseY - y}
            end
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
    elseif held and ProjectState.titleDrag then
        local snapTarget = "top"
        local previewX, previewY, previewW, previewH = x + 2, y + 2, w - 4, 36 - 2
        
        if mx < x + w * 0.25 then
            snapTarget = "left"
            previewX, previewY, previewW, previewH = x + 2, y + 2, 36 - 2, h - 28
        elseif mx > x + w * 0.75 then
            snapTarget = "right"
            previewX, previewY, previewW, previewH = x + w - 36, y + 2, 36 - 2, h - 28
        elseif my > y + h * 0.75 then
            snapTarget = "bottom"
            previewX, previewY, previewW, previewH = x + 2, y + h - 36 - 24, w - 4, 36 - 2
        end
        
        rect(previewX, previewY, previewW, previewH, Theme.accent, 200, 6, 0.3)
        strokeRect(previewX, previewY, previewW, previewH, Theme.accent, 201, 6)
        
        ProjectState.lastTitleSnapTarget = snapTarget
    elseif not held then
        ProjectState.resizeEdge = nil
        ProjectState.resizeStart = nil
        ProjectState.drag = nil
        if ProjectState.titleDrag then
            if ProjectState.lastTitleSnapTarget then
                ProjectState.titlePosition = ProjectState.lastTitleSnapTarget
                pcall(saveConfig)
                ProjectState.lastTitleSnapTarget = nil
            end
            ProjectState.titleDrag = nil
        end
    end

    local setHovered, cxSet, cy
    local iconHovered, circleX, circleY, lineX1, lineY1, lineX2, lineY2
    local searchX, searchY
    
    if isVertTitle then
        local cogCY = titleBarY + titleBarH - 18
        local searchIY = cogCY - 26
        setHovered = over(titleBarX + 8, cogCY - 10, 20, 20)
        cxSet = titleBarX + 18
        cy = cogCY
        
        iconHovered = over(titleBarX + 8, searchIY - 10, 20, 20)
        circleX = titleBarX + 18
        circleY = searchIY
        lineX1 = titleBarX + 21
        lineY1 = searchIY + 3
        lineX2 = titleBarX + 25
        lineY2 = searchIY + 7
        
        searchX = (titlePos == "left") and (titleBarX + titleBarW + 4) or (titleBarX - ProjectState.searchBar.width - 4)
        searchY = searchIY - 10
    else
        setHovered = over(titleBarX + titleBarW - 30, titleBarY + 6, 20, 24)
        cxSet = titleBarX + titleBarW - 21
        cy = titleBarY + 18
        
        iconHovered = over(titleBarX + titleBarW - 52, titleBarY + 6, 20, 24)
        circleX = titleBarX + titleBarW - 45
        circleY = titleBarY + 16
        lineX1 = titleBarX + titleBarW - 42
        lineY1 = titleBarY + 19
        lineX2 = titleBarX + titleBarW - 38
        lineY2 = titleBarY + 23
        
        searchX = titleBarX + titleBarW - 56 - ProjectState.searchBar.width
        searchY = titleBarY + 8
    end

    if isVertTitle then
        drawVerticalText(ProjectState.title or "homesick", titleBarX + titleBarW / 2, titleBarY + 14, Theme.accent, 14, FontBold, 16)
    else
        txt(ProjectState.title or "homesick", titleBarX + 14, textTop(titleBarY, 36, 14), Theme.accent, 14, FontBold, 16)
    end

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
        rect(searchX, searchY, ProjectState.searchBar.width, 20, Theme.surface, 15, 6)
        strokeRect(searchX, searchY, ProjectState.searchBar.width, 20, (ProjectState.focus == ProjectState.searchBar) and Theme.accent or Theme.border, 16, 6)
        txt((ProjectState.searchBar.value == "") and "Search..." or ProjectState.searchBar.value, searchX + 8, textTop(searchY, 20, 12), (ProjectState.searchBar.value == "") and Theme.sub or Theme.text, 12, FontUI, 17, false, false, ProjectState.searchBar.width - 16)
        if ProjectState.focus == ProjectState.searchBar then
            local cursorX = searchX + 8
            if not (ProjectState.searchBar.value == "") then
                cursorX = cursorX + textWidth(ProjectState.searchBar.value, 12, FontUI)
            end
            txt("|", cursorX, textTop(searchY, 20, 12), Theme.text, 12, FontUI, 18, false, false, nil, clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
        end
        if click and over(searchX, searchY, ProjectState.searchBar.width, 20) then
            ProjectState.focus = ProjectState.searchBar
            click = false
            baseClick = false
        end
    end

    circle(circleX, circleY, 4, iconHovered and Theme.accent or Theme.sub, 20, false, 1.5)
    line(lineX1, lineY1, lineX2, lineY2, iconHovered and Theme.accent or Theme.sub, 20, 1.5)

    local col = (setHovered or ProjectState.settingsActive) and Theme.accent or Theme.sub
    if ProjectState.settingsActive then
        for i = 0, 3 do
            local a = clock() * 2 + i * math.pi / 4
            local c = math.cos(a)
            local s = math.sin(a)
            line(cxSet - 6 * c, cy - 6 * s, cxSet + 6 * c, cy + 6 * s, Theme.accent, 19, 4, 0.25)
        end
        circle(cxSet, cy, 4, Theme.accent, 19, false, 4, 32, 0.25)
        circle(cxSet, cy, 1.5, Theme.accent, 19, true, 0, 32, 0.25)
    end
    for i = 0, 3 do
        local a = (ProjectState.settingsActive and clock() * 2 or 0) + i * math.pi / 4
        local c = math.cos(a)
        local s = math.sin(a)
        line(cxSet - 6 * c, cy - 6 * s, cxSet + 6 * c, cy + 6 * s, col, 20, 1.5)
    end
    circle(cxSet, cy, 4, Theme.surface2, 21, true)
    circle(cxSet, cy, 4, col, 22, false, 1.5)
    circle(cxSet, cy, 1.5, col, 23, true)

    if ProjectState.minimized or h <= minimizedH then
        return click, held, rightClick
    end

    if pw <= 40 or ph <= 40 then
        return click, held, rightClick
    end

    if ProjectState.layoutEditing then
        local bannerY = py
        local bannerH = 22
        local bannerHovered = over(px, bannerY, pw, bannerH)
        rect(px, bannerY, pw, bannerH, bannerHovered and Theme.surface3 or Theme.surface2, 100, 4)
        strokeRect(px, bannerY, pw, bannerH, bannerHovered and Theme.accent or Theme.border, 101, 4)
        txt("layout editor - drag tabs to snap. click here to exit", px + pw / 2, centerY(bannerY, bannerH), Theme.accent, 11, FontSystem, 102, true)
        
        if click and bannerHovered then
            ProjectState.layoutEditing = false
            click = false
        end
        
        py = py + bannerH + 4
        ph = ph - bannerH - 4
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
        local pos = ProjectState.tabsPosition or "top"
        local tabW = 85
        local tabH = tabH
        
        local tabsX, tabsY, tabsWidth, tabsHeight
        local contX, contY, contW, contH = px, py, pw, ph
        
        if pos == "left" then
            tabsX, tabsY, tabsWidth, tabsHeight = x - tabW - 8, y, tabW, h
        elseif pos == "right" then
            tabsX, tabsY, tabsWidth, tabsHeight = x + w + 8, y, tabW, h
        elseif pos == "bottom" then
            tabsX, tabsY, tabsWidth, tabsHeight = px, py + ph - tabH, pw, tabH
            contH = ph - tabH - 6
        else
            tabsX, tabsY, tabsWidth, tabsHeight = px, py, pw, tabH
            contY = py + tabH + 6
            contH = ph - tabH - 6
        end
        
        if pos == "left" or pos == "right" then
            for i = 1, #shadowAlpha do
                local offset = i * 2
                rect(tabsX - offset, tabsY - offset + 6, tabsWidth + offset * 2, tabsHeight + offset * 2, Theme.black, 0, 12, shadowAlpha[i])
            end
        end
        
        rect(tabsX, tabsY, tabsWidth, tabsHeight, Theme.surface, 5, 8)
        strokeRect(tabsX, tabsY, tabsWidth, tabsHeight, Theme.border, 6, 8)
        
        if ProjectState.layoutEditing then
            local isHoveredTabs = over(tabsX, tabsY, tabsWidth, tabsHeight)
            if click and isHoveredTabs and not popupOpen then
                ProjectState.tabsDrag = { ProjectState.mouseX - tabsX, ProjectState.mouseY - tabsY }
                click = false
            end
            
            if ProjectState.tabsDrag then
                if held then
                    local mx, my = ProjectState.mouseX, ProjectState.mouseY
                    local snapTarget = "top"
                    local previewX, previewY, previewW, previewH = px, py, pw, tabH
                    
                    if mx < x + w * 0.25 then
                        snapTarget = "left"
                        previewX, previewY, previewW, previewH = x - tabW - 8, y, tabW, h
                    elseif mx > x + w * 0.75 then
                        snapTarget = "right"
                        previewX, previewY, previewW, previewH = x + w + 8, y, tabW, h
                    elseif my > y + h * 0.75 then
                        snapTarget = "bottom"
                        previewX, previewY, previewW, previewH = px, py + ph - tabH, pw, tabH
                    end
                    
                    rect(previewX, previewY, previewW, previewH, Theme.accent, 200, 6, 0.3)
                    strokeRect(previewX, previewY, previewW, previewH, Theme.accent, 201, 6)
                    
                    ProjectState.lastSnapTarget = snapTarget
                else
                    if ProjectState.lastSnapTarget then
                        ProjectState.tabsPosition = ProjectState.lastSnapTarget
                        pcall(saveConfig)
                        ProjectState.lastSnapTarget = nil
                    end
                    ProjectState.tabsDrag = nil
                end
            end
            
            strokeRect(tabsX, tabsY, tabsWidth, tabsHeight, Theme.accent, 199, 8)
        end
        
        baseClick = renderTabs(baseClick, tabsX, tabsY, tabsWidth, tabsHeight)
        baseClick, baseHeld, baseRightClick = renderSections(ProjectState.activeTab, baseClick, baseHeld, baseRightClick, contX, contY, contW, contH)
        
        if ProjectState.focus and baseClick and not over(contX, contY, contW, contH) then
            ProjectState.focus = nil
            baseClick = false
        end
    end

    local botY = y + h - 24
    local botH = 24
    line(x + 2, botY, x + w - 2, botY, Theme.border, 8)
    txt((ProjectState.badgeText and ProjectState.badgeText ~= "") and (ProjectState.badgeText .. " | v1.4.0") or "v1.4.0", x + 14, textTop(botY, botH, 11), Theme.sub, 11, FontUI, 10)
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
        
        rect(x, y, w, h, c3(0, 0, 0), mz - 2, 8, 0.6)
        rect(mx, my, modalW, modalH, Theme.surface2, mz, 8, 1)
        strokeRect(mx, my, modalW, modalH, Theme.border, mz + 1, 8, 1)
        
        local modalTitle = modal.type == "config" and "import config" or "import theme"
        txt(modalTitle, mx + 16, my + 14, Theme.accent, 13, FontBold, mz + 2)
        if modalTitle == modalTitle then end
        
        local modalTextbox = modal.textbox
        local bx, bw = mx + 20, modalW - 40
        local dyBox = my + 42
        local boxH = 22
        local focused = ProjectState.focus == modalTextbox
        
        rect(bx, dyBox, bw, boxH, focused and Theme.surface or over(bx, dyBox, bw, boxH) and Theme.surface3 or Theme.surface, mz + 2, 4, 1)
        strokeRect(bx, dyBox, bw, boxH, focused and Theme.accent or Theme.border, mz + 3, 4, 1)
        
        txt((modalTextbox.value == "" and not focused) and "enter code..." or modalTextbox.value, bx + 8, textTop(dyBox, boxH, 12), (modalTextbox.value == "") and Theme.sub or Theme.text, 12, FontUI, mz + 4, false, false, bw - 16)
        
        if focused then
            if modalTextbox.selectedAll and not (modalTextbox.value == "") then
                rect(bx + 8, dyBox + 3, math.min(bw - 16, textWidth(modalTextbox.value, 12, FontUI)), boxH - 6, Theme.accent, mz + 3, 2, 0.4)
            end
            local cursorX = bx + 8
            if not (modalTextbox.value == "") then
                cursorX = cursorX + textWidth(modalTextbox.value, 12, FontUI)
            end
            txt("|", cursorX, textTop(dyBox, boxH, 12), Theme.text, 12, FontUI, mz + 5, false, false, nil, clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
        end
        
        if click and over(bx, dyBox, bw, boxH) then
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
        
        local confirmBgColor = not recognized and c3(45, 42, 40) or (confirmHovered and Theme.accent or Theme.surface)
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

    if ProjectState.changelogOpen then
        local modalW = 300
        local modalH = 260
        local mx = x + (w - modalW) / 2
        local my = y + (h - modalH) / 2
        local mz = 85
        
        rect(x, y, w, h, c3(0, 0, 0), mz - 2, 8, 0.6)
        rect(mx, my, modalW, modalH, Theme.surface2, mz, 8, 1)
        strokeRect(mx, my, modalW, modalH, Theme.border, mz + 1, 8, 1)
        
        txt("homesick changelog - " .. "v1.3.6", mx + 16, my + 14, Theme.accent, 13, FontBold, mz + 2)
        
        for i = 1, #changelogs do
            local text = changelogs[i]
            local isAdd = true
            if string.find(text, "^fixed") or string.find(text, "^removed") or string.find(text, "^deleted") or string.find(text, "^cleared") then
                isAdd = false
            end
            local yOffset = my + 40 + (i - 1) * 18
            local bulletColor = isAdd and c3(150, 220, 150) or c3(220, 150, 150)
            local bulletChar = isAdd and "+" or "-"
            local bx = mx + 16
            txt("[" .. bulletChar .. "] " .. text, bx, yOffset, Theme.text, 11, FontSystem, mz + 2)
            txt(bulletChar, bx + textWidth("[", 11, FontSystem), yOffset, bulletColor, 11, FontSystem, mz + 3)
        end
        
        local btnHovered = over(mx + 100, my + 220, 100, 24)
        rect(mx + 100, my + 220, 100, 24, btnHovered and Theme.surface3 or Theme.surface, mz + 2, 4, 1)
        strokeRect(mx + 100, my + 220, 100, 24, btnHovered and Theme.accent or Theme.border, mz + 3, 4, 1)
        txt("continue", mx + 150, centerY(my + 220, 24), Theme.accent, 12, FontBold, mz + 4, true)
        
        if click and btnHovered then
            ProjectState.changelogOpen = false
            click = false
        end
    end

    return popupOpen and click or baseClick, popupOpen and held or baseHeld, popupOpen and rightClick or baseRightClick
end

local function renderSpotlightSearch(click)
    local fade = ProjectState.spotlightFade or 0
    local dt = ProjectState.dt or 0.016
    if ProjectState.spotlightActive == true then
        fade = math.min(1, fade + dt * 6)
    else
        fade = math.max(0, fade - dt * 6)
    end
    ProjectState.spotlightFade = fade

    if fade <= 0 then
        return click
    end

    local vw, vh = viewportSize()
    local sx = (vw - 400) / 2
    local sy = vh * 0.3
    rect(0, 0, vw, vh, Theme.black, 299, 0, 0.25 * fade)

    rect(sx - 4, sy - 4, 408, 48, Theme.black, 298, 10, 0.2 * fade)
    rect(sx, sy, 400, 40, Theme.surface, 300, 8, 0.85 * fade)
    strokeRect(sx, sy, 400, 40, Theme.accent, 301, 8, fade * 0.4)

    circle(sx + 20, centerY(sy, 40) - 2, 4, Theme.accent, 302, false, 1.5, 12, fade)
    line(sx + 23, centerY(sy, 40) + 1, sx + 27, centerY(sy, 40) + 5, Theme.accent, 302, 1.5, fade)

    local displayVal = ProjectState.spotlightSearch.value
    if displayVal == "" and ProjectState.focus ~= ProjectState.spotlightSearch then
        txt("type to search...", sx + 36, centerY(sy, 40), Theme.sub, 13, FontUI, 302, false, false, nil, fade)
    else
        txt(displayVal, sx + 36, centerY(sy, 40), Theme.text, 13, FontUI, 302, false, false, nil, fade)
    end
    if ProjectState.focus == ProjectState.spotlightSearch then
        txt("|", sx + 36 + textWidth(displayVal, 13, FontUI), centerY(sy, 40), Theme.text, 13, FontUI, 303, false, false, nil, fade * clamp(0.5 + 0.5 * math.sin(clock() * 8), 0, 1))
    end
    local matches = {}
    local query = string.lower(displayVal)
    for _, t in ipairs(ProjectState.tabs) do
        for _, s in ipairs(t.sections) do
            for _, item in ipairs(s.items) do
                if item.type ~= "divider" and item.type ~= "label" then
                    if query == "" or string.find(string.lower(item.label), query, 1, true) then
                        matches[#matches + 1] = { tab = t, section = s, item = item }
                    end
                end
            end
        end
    end
    if #matches > 0 and query ~= "" then
        local matchCount = math.min(#matches, 5)
        local resultsH = matchCount * 30 + 10
        rect(sx - 4, sy + 42, 408, resultsH + 8, Theme.black, 298, 10, 0.2 * fade)
        rect(sx, sy + 46, 400, resultsH, Theme.surface, 300, 8, 0.85 * fade)
        strokeRect(sx, sy + 46, 400, resultsH, Theme.border, 301, 8, fade * 0.8)
        ProjectState.spotlightSearch.selected = clamp(ProjectState.spotlightSearch.selected or 1, 1, matchCount)
        for i = 1, matchCount do
            local match = matches[i]
            local rowY = sy + 51 + (i - 1) * 30
            local isSelected = ProjectState.spotlightSearch.selected == i
            local hovered = over(sx + 6, rowY, 388, 26)
            if isSelected or hovered then
                rect(sx + 6, rowY, 388, 26, hovered and Theme.surface3 or Theme.surface2, 302, 4, fade * (hovered and 0.9 or 0.6))
                if hovered then
                    ProjectState.spotlightSearch.selected = i
                end
                if isSelected then
                    rect(sx + 6, rowY, 4, 26, Theme.accent, 303, 2, fade)
                end
            end
            txt(match.tab.name .. " > " .. match.item.label, sx + 14, centerY(rowY, 26), isSelected and Theme.accent or Theme.text, 12, FontUI, 303, false, false, nil, fade)
            local valText = ""
            local mi = match.item
            if mi.type == "checkbox" or mi.type == "toggle" then
                valText = mi.value and "on" or "off"
            elseif mi.type == "slider" then
                valText = tostring(mi.value)
            elseif mi.type == "dropdown" then
                valText = mi.value[1] or "-"
            elseif mi.type == "textbox" then
                valText = mi.value ~= "" and mi.value or "-"
            end
            txt(valText, sx + 386 - textWidth(valText, 11, FontSystem), centerY(rowY, 26), Theme.sub, 11, FontSystem, 303, false, false, nil, fade)
        end
    end
    if click and not over(sx, sy, 400, 40) and not (#matches > 0 and query ~= "" and over(sx, sy + 46, 400, math.min(#matches, 5) * 30 + 10)) then
        ProjectState.spotlightActive = false
        ProjectState.focus = nil
        click = false
    end
    return click
end

local function step()
    local isTyping = ProjectState.focus ~= nil
    if isTyping ~= ProjectState.lastIsTyping then
        ProjectState.lastIsTyping = isTyping
        if isTyping then
            setrobloxinput(false)
            pcall(function()
                if game then
                    game:GetService("ContextActionService"):BindActionAtPriority(
                        "homesickFreezeMovement",
                        function() return Enum.ContextActionResult.Sink end,
                        false,
                        3000,
                        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Space,
                        Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right
                    )
                end
            end)
        else
            setrobloxinput(true)
            pcall(function()
                if game then
                    game:GetService("ContextActionService"):UnbindAction("homesickFreezeMovement")
                end
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

    if Input[menuKey] and Input[menuKey].click and not ProjectState.focus then
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
        ProjectState.boxDrag = nil
        ProjectState.boxResize = nil
    end

    local click = Input.m1.click
    local held = Input.m1.held
    local rightClick = Input.m2.click

    if not ProjectState.open or #ProjectState.tabs == 0 then
        click = renderHotkeyOverlay(click, held)
        renderWatermark(click, held)
        click = renderCustomBoxes(click, held)
        renderNotifications()
        click = renderSpotlightSearch(click)
        hideUnused()
        return
    end

    if not ProjectState.hasMouse then
        renderWatermark(click, held)
        click = renderCustomBoxes(click, held)
        renderNotifications()
        hideUnused()
        return
    end

    clampWindow()

    click, held, rightClick = renderWindow(click, held, rightClick)
    click, rightClick = renderDropdown(click, rightClick)
    click = renderColorpicker(click, held)
    renderTooltip()
    ProjectState.lastTooltipText = ProjectState.tooltipText

    if rightClick and ProjectState.dropdown == nil and ProjectState.colorpicker == nil then
        rightClick = false
    end

    renderWatermark(click, held)

    if prevFocus and ProjectState.focus ~= prevFocus then
        prevFocus.selectedAll = false
        if prevFocus.type == "slider" and prevFocus.directValue then
            setItemValue(prevFocus, tonumber(prevFocus.directValue) or prevFocus.value or prevFocus.min or 0, true)
            prevFocus.directValue = nil
        end
    end

    if click and ProjectState.focus then
        ProjectState.focus = nil
    end

    renderNotifications()
    click = renderHotkeyOverlay(click, held)
    click = renderCustomBoxes(click, held)
    click = renderSpotlightSearch(click)
    hideUnused()
end

local RunService = game:GetService("RunService")

local function runStepSafe()
    if _G.homesickInstanceId ~= homesickInstanceId then
        ProjectState.alive = false
    end
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
        warn("step failed " .. tostring(err))
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
                task.wait((1 / 240))
            end
        end
    end)
end

safeWriteGlobal("homesick", ui)
safeWriteGlobal("homesickUI", ui)

local settingNames = {
    tabanimations = "tabAnimations",
    gridlocking = "gridLocking",
    tooltips = "tooltipsEnabled",
    tooltipsenabled = "tooltipsEnabled",
    hovereffects = "hoverEffects",
    hotkey = "hotkeyEnabled",
    hotkeyenabled = "hotkeyEnabled",
    autoloadconfig = "autoloadConfig",
    autoloadtheme = "autoloadTheme",
    spotlight = "spotlightEnabled",
    spotlightenabled = "spotlightEnabled",
    caret = "caretEnabled",
    caretenabled = "caretEnabled",
    isrbxactiveoverride = "isrbxactiveOverride"
}

local function syncSettingsUI()
    if not ProjectState.settingsTab then return end
    for _, s in ipairs(ProjectState.settingsTab.sections) do
        for _, item in ipairs(s.items) do
            if item.label == "isrbxactive()" then
                item.value = ProjectState.isrbxactiveOverride == true
            elseif item.label == "Tab Animations" then
                item.value = ProjectState.tabAnimations ~= false
            elseif item.label == "Grid Locking" then
                item.value = ProjectState.gridLocking ~= false
            elseif item.label == "show tooltips" then
                item.value = ProjectState.tooltipsEnabled ~= false
            elseif item.label == "Checkbox Animations" then
                item.value = ProjectState.hoverEffects ~= false
            elseif item.label == "Hotkey Overlay" then
                item.value = ProjectState.hotkeyEnabled == true
            elseif item.label == "autoload config" then
                item.value = ProjectState.autoloadConfig == true
            elseif item.label == "autoload theme" then
                item.value = ProjectState.autoloadTheme == true
            elseif item.label == "Spotlight Search" then
                item.value = ProjectState.spotlightEnabled ~= false
            elseif item.label == "writing caret" then
                item.value = ProjectState.caretEnabled ~= false
            end
        end
    end
end

local homesick = { changelogEnabled = true }

homesick.setSetting = function(self, name, value)
    if type(self) ~= "table" or self.createWindow == nil then
        value = name
        name = self
    end
    local key = settingNames[tostring(name):lower()] or name
    if ProjectState[key] ~= nil then
        ProjectState[key] = (value == true)
        pcall(saveConfig)
        syncSettingsUI()
    end
end

homesick.getSetting = function(self, name)
    if type(self) ~= "table" or self.createWindow == nil then
        name = self
    end
    return ProjectState[settingNames[tostring(name):lower()] or name]
end

homesick.toggleSetting = function(self, name)
    if type(self) ~= "table" or self.createWindow == nil then
        name = self
    end
    local key = settingNames[tostring(name):lower()] or name
    if ProjectState[key] ~= nil then
        ProjectState[key] = not ProjectState[key]
        pcall(saveConfig)
        syncSettingsUI()
        return ProjectState[key]
    end
end

homesick.setTheme = function(self, themeData)
    if type(self) ~= "table" or self.createWindow == nil then
        themeData = self
    end
    loadTheme(themeData)
end

homesick.GetDrawing = function(self, kind)
    return ui:GetDrawing(kind)
end

homesick.CreateBox = function(self, config)
    config = config or {}
    local box = {
        title = config.title,
        showTopbar = config.showTopbar ~= false,
        position = config.position or v2(100, 100),
        size = config.size or v2(220, 75),
        bgColor = parseColor(config.bgColor or Theme.surface),
        borderColor = parseColor(config.borderColor or Theme.accent),
        titleColor = parseColor(config.titleColor or Theme.text),
        visible = config.visible == true,
        elements = {},
        elementOrder = {},
    }
    
    function box:SetVisible(v)
        self.visible = v == true
        return self
    end
    
    function box:SetPosition(pos)
        self.position = pos
        return self
    end

    function box:SetSize(sz)
        self.size = sz
        return self
    end

    function box:SetColor(bg, border)
        if bg then
            self.bgColor = parseColor(bg)
        end
        if border then
            self.borderColor = parseColor(border)
        end
        return self
    end
    
    function box:AddText(id, text, color, size, font, alignment)
        if not self.elements[id] then
            table.insert(self.elementOrder, id)
        end
        self.elements[id] = {
            type = "text",
            text = text or "",
            color = parseColor(color or Theme.text),
            size = size or 13,
            font = font or FontSystem,
            alignment = alignment or "center",
        }
        return self
    end
    
    function box:SetText(id, text, color)
        local el = self.elements[id]
        if el then
            el.text = text or el.text
            if color then
                el.color = parseColor(color)
            end
        end
        return self
    end
    
    function box:AddTimer(id, value, maxValue, color)
        if not self.elements[id] then
            table.insert(self.elementOrder, id)
        end
        self.elements[id] = {
            type = "timer",
            value = value or 0,
            maxValue = maxValue or 1,
            color = parseColor(color or Theme.accent),
        }
        return self
    end
    
    function box:SetTimer(id, value, maxValue)
        local el = self.elements[id]
        if el then
            el.value = value or el.value
            el.maxValue = maxValue or el.maxValue
        end
        return self
    end

    function box:AddButton(id, label, callback)
        if not self.elements[id] then
            table.insert(self.elementOrder, id)
        end
        self.elements[id] = {
            type = "button",
            label = tostring(label or "Button"),
            callback = callback,
        }
        return self
    end

    function box:AddCheckbox(id, label, default, callback)
        if not self.elements[id] then
            table.insert(self.elementOrder, id)
        end
        self.elements[id] = {
            type = "checkbox",
            label = tostring(label or "Checkbox"),
            value = default == true,
            callback = callback,
            animState = default == true and 1 or 0,
        }
        return self
    end

    function box:AddSlider(id, label, default, minValue, maxValue, step, callback)
        if not self.elements[id] then
            table.insert(self.elementOrder, id)
        end
        self.elements[id] = {
            type = "slider",
            label = tostring(label or "Slider"),
            value = tonumber(default) or tonumber(minValue) or 0,
            min = tonumber(minValue) or 0,
            max = tonumber(maxValue) or 100,
            step = tonumber(step),
            callback = callback,
        }
        return self
    end
    
    function box:SetCheckbox(id, value)
        local el = self.elements[id]
        if el and el.type == "checkbox" then
            el.value = value == true
        end
        return self
    end
    
    function box:SetSlider(id, value)
        local el = self.elements[id]
        if el and el.type == "slider" then
            el.value = clamp(tonumber(value) or el.value, el.min, el.max)
        end
        return self
    end

    function box:AddSeparator(id, label)
        if not self.elements[id] then
            table.insert(self.elementOrder, id)
        end
        self.elements[id] = {
            type = "separator",
            label = label or "",
        }
        return self
    end

    function box:AddColorpicker(id, label, defaultColor, callback)
        if not self.elements[id] then
            table.insert(self.elementOrder, id)
        end
        self.elements[id] = {
            type = "colorpicker",
            label = label or "color",
            value = parseColor(defaultColor or Theme.white),
            callback = callback,
        }
        return self
    end
    
    function box:SetColorpicker(id, value)
        if self.elements[id] and self.elements[id].type == "colorpicker" then
            self.elements[id].value = parseColor(value)
        end
        return self
    end

    function box:AddDropdown(id, label, choices, default, callback)
        if not self.elements[id] then
            table.insert(self.elementOrder, id)
        end
        self.elements[id] = {
            type = "dropdown",
            label = label or "dropdown",
            choices = choices or {},
            value = copyArray(default),
            callback = callback,
            multi = false,
        }
        return self
    end

    function box:SetDropdown(id, value)
        if self.elements[id] and self.elements[id].type == "dropdown" then
            setDropdownValue(self.elements[id], value, true)
        end
        return self
    end

    function box:UpdateChoices(id, choices)
        if self.elements[id] and self.elements[id].type == "dropdown" then
            self.elements[id].choices = copyArray(choices)
            if ProjectState.dropdown and ProjectState.dropdown.item == self.elements[id] then
                ProjectState.dropdown.choices = copyArray(choices)
                ProjectState.dropdown.h = min(#choices * 22 + (ProjectState.dropdown.multi and 30 or 6), ProjectState.dropdown.multi and 234 or 210)
                ProjectState.dropdown.y = clamp(ProjectState.dropdown.y, 8, max(8, select(2, viewportSize()) - ProjectState.dropdown.h - 8))
                ProjectState.dropdown.scrollOffset = clamp(ProjectState.dropdown.scrollOffset or 0, 0, max(0, #choices - floor((ProjectState.dropdown.h - 6) / 22)))
            end
        end
        return self
    end

    ProjectState.customBoxes = ProjectState.customBoxes or {}
    table.insert(ProjectState.customBoxes, box)
    return box
end
homesick.CreateElement = homesick.CreateBox

homesick.createWindow = function(title, width, height)
    ui:SetTitle(title)
    ui:SetSize(width, height)
    ui:Center()
    
    if homesick.changelogEnabled then
        ProjectState.changelogOpen = true
    end
    
    local windowWrap = {}
    
    windowWrap.setBadge = function(wSelf, text)
        ProjectState.badgeText = text
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
            
            secWrap.setSize = function(sSelf, w, h)
                sSelf.rawSec:SetSize(w, h)
                return sSelf
            end
            secWrap.overrideSize = function(sSelf, w, h)
                sSelf.rawSec:overrideSize(w, h)
                return sSelf
            end
            
            secWrap.addToggle = function(sSelf, id, label, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "Toggle",
                    rawItem = sSelf.rawSec:Toggle(label, default, callback)
                }
                widgetWrap.rawItem.item.id = id
                
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
                
                widgetWrap.getValue = function(wSelf)
                    return wSelf.rawItem.item.value
                end
                
                widgetWrap.setValue = function(wSelf, val)
                    wSelf.rawItem:Set(val)
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
                widgetWrap.rawItem.item.id = id
                
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
                
                widgetWrap.getValue = function(wSelf)
                    return wSelf.rawItem.item.value
                end
                
                widgetWrap.setValue = function(wSelf, val)
                    wSelf.rawItem:Set(val)
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
                widgetWrap.rawItem.item.id = id
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                widgetWrap.getValue = function(wSelf)
                    return wSelf.rawItem.item.value
                end
                
                widgetWrap.setValue = function(wSelf, val)
                    wSelf.rawItem:Set(val)
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
                widgetWrap.rawItem.item.id = id
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                widgetWrap.getValue = function(wSelf)
                    return wSelf.rawItem.item.value
                end
                
                widgetWrap.setValue = function(wSelf, val)
                    wSelf.rawItem:Set(val)
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addDropdown = function(sSelf, id, label, choices, default, callback, searchable, maxSelections)
                local widgetWrap = {
                    id = id,
                    type = "Dropdown",
                    rawItem = sSelf.rawSec:Dropdown(label, default, choices, false, callback, nil, searchable, maxSelections)
                }
                widgetWrap.rawItem.item.id = id
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                widgetWrap.setSearchable = function(wSelf, boolVal)
                    wSelf.rawItem:SetSearchable(boolVal)
                    return wSelf
                end
                
                widgetWrap.setMaxSelections = function(wSelf, limit)
                    wSelf.rawItem:SetMaxSelections(limit)
                    return wSelf
                end
                
                widgetWrap.updateChoices = function(wSelf, newChoices)
                    wSelf.rawItem:UpdateChoices(newChoices)
                    return wSelf
                end
                
                widgetWrap.addChoice = function(wSelf, choice)
                    wSelf.rawItem:AddChoice(choice)
                    return wSelf
                end
                
                widgetWrap.removeChoice = function(wSelf, choice)
                    wSelf.rawItem:RemoveChoice(choice)
                    return wSelf
                end
                
                widgetWrap.clearChoices = function(wSelf)
                    wSelf.rawItem:ClearChoices()
                    return wSelf
                end
                
                widgetWrap.getValue = function(wSelf)
                    return wSelf.rawItem.item.value
                end
                
                widgetWrap.setValue = function(wSelf, val)
                    wSelf.rawItem:Set(val)
                    return wSelf
                end
                
                return widgetWrap
            end
            
            secWrap.addMultiDropdown = function(sSelf, id, label, choices, default, callback, searchable, maxSelections)
                local widgetWrap = {
                    id = id,
                    type = "MultiDropdown",
                    rawItem = sSelf.rawSec:Dropdown(label, default, choices, true, callback, nil, searchable, maxSelections)
                }
                widgetWrap.rawItem.item.id = id
                
                widgetWrap.addTooltip = function(wSelf, text)
                    wSelf.rawItem.item.tooltip = text
                    return wSelf
                end
                
                widgetWrap.setSearchable = function(wSelf, boolVal)
                    wSelf.rawItem:SetSearchable(boolVal)
                    return wSelf
                end
                
                widgetWrap.setMaxSelections = function(wSelf, limit)
                    wSelf.rawItem:SetMaxSelections(limit)
                    return wSelf
                end
                
                widgetWrap.updateChoices = function(wSelf, newChoices)
                    wSelf.rawItem:UpdateChoices(newChoices)
                    return wSelf
                end
                
                widgetWrap.addChoice = function(wSelf, choice)
                    wSelf.rawItem:AddChoice(choice)
                    return wSelf
                end
                
                widgetWrap.removeChoice = function(wSelf, choice)
                    wSelf.rawItem:RemoveChoice(choice)
                    return wSelf
                end
                
                widgetWrap.clearChoices = function(wSelf)
                    wSelf.rawItem:ClearChoices()
                    return wSelf
                end
                
                widgetWrap.getValue = function(wSelf)
                    return wSelf.rawItem.item.value
                end
                
                widgetWrap.setValue = function(wSelf, val)
                    wSelf.rawItem:Set(val)
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
                
                widgetWrap.getValue = function(wSelf)
                    return wSelf.rawItem.item.label
                end
                
                widgetWrap.setValue = function(wSelf, val)
                    wSelf.rawItem:Set(val)
                    return wSelf
                end
                
                return widgetWrap
            end
            
            return secWrap
        end
        
        return tabWrap
    end
    
    windowWrap.autoloadConfig = function(wSelf, name)
        wSelf.configName = name
        return wSelf
    end
    
    windowWrap.autoloadTheme = function(wSelf, name)
        wSelf.themeName = name
        return wSelf
    end
    
    windowWrap.render = function(wSelf)
        if wSelf.configName and not wSelf.configLoaded then
            wSelf.configLoaded = true
            pcall(function()
                local raw = readfile("homesick/" .. wSelf.configName .. ".json")
                if raw and raw ~= "" then
                    loadConfig(raw)
                end
            end)
        end
        if wSelf.themeName and not wSelf.themeLoaded then
            wSelf.themeLoaded = true
            if type(wSelf.themeName) == "table" then
                loadTheme(wSelf.themeName)
            else
                pcall(function()
                    local raw = readfile("homesick/themes/" .. wSelf.themeName .. ".json")
                    if raw and raw ~= "" then
                        loadTheme(raw)
                    end
                end)
            end
        end
        ui:SetOpen(wSelf.visible == true)
    end
    
    windowWrap.remove = function(wSelf)
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
    
    pcall(loadConfig)
    initSettings()
    if ProjectState.autoloadTheme then
        pcall(loadTheme)
    end

    return windowWrap
end

local newPrint
newPrint = function(...)
    local strArgs = {}
    for i = 1, select("#", ...) do
        strArgs[i] = string.lower(tostring(select(i, ...)))
    end
    ui:Notify("print", table.concat(strArgs, " "), 5)
    local orig = homesickOriginals.print
    if orig and orig ~= newPrint and not homesickFunctions[orig] then
        return orig(unpack(strArgs))
    end
end
homesickFunctions[newPrint] = true
pcall(function()
    env.print = newPrint
end)
safeWriteGlobal("print", newPrint)

local newWarn
newWarn = function(...)
    local strArgs = {}
    for i = 1, select("#", ...) do
        strArgs[i] = string.lower(tostring(select(i, ...)))
    end
    ui:Notify("warning", table.concat(strArgs, " "), 5)
    local orig = homesickOriginals.warn
    if orig and orig ~= newWarn and not homesickFunctions[orig] then
        return orig(unpack(strArgs))
    end
end
homesickFunctions[newWarn] = true
pcall(function()
    env.warn = newWarn
end)
safeWriteGlobal("warn", newWarn)

if type(env.printl) == "function" then
    local newPrintl
    newPrintl = function(...)
        local strArgs = {}
        for i = 1, select("#", ...) do
            strArgs[i] = string.lower(tostring(select(i, ...)))
        end
        ui:Notify("print", table.concat(strArgs, " "), 5)
        local orig = homesickOriginals.printl
        if orig and orig ~= newPrintl and not homesickFunctions[orig] then
            return orig(unpack(strArgs))
        end
    end
    homesickFunctions[newPrintl] = true
    pcall(function()
        env.printl = newPrintl
    end)
    safeWriteGlobal("printl", newPrintl)
end

if type(env.notify) == "function" then
    local newNotify
    newNotify = function(message, title, duration)
        local lowerMsg = string.lower(tostring(message or ""))
        local lowerTitle = string.lower(tostring(title or "notification"))
        ui:Notify(lowerTitle, lowerMsg, duration or 5)
        local orig = homesickOriginals.notify
        if orig and orig ~= newNotify and not homesickFunctions[orig] then
            return orig(message, title, duration)
        end
    end
    homesickFunctions[newNotify] = true
    pcall(function()
        env.notify = newNotify
    end)
    safeWriteGlobal("notify", newNotify)
end

if type(homesickOriginals.isrbxactive) == "function" then
    local newIsRbxActive
    newIsRbxActive = function()
        if ProjectState.isrbxactiveOverride then
            return true
        end
        local orig = homesickOriginals.isrbxactive
        if orig and orig ~= newIsRbxActive and not homesickFunctions[orig] then
            return orig()
        end
        return true
    end
    homesickFunctions[newIsRbxActive] = true
    pcall(function()
        env.isrbxactive = newIsRbxActive
    end)
    safeWriteGlobal("isrbxactive", newIsRbxActive)
end

safeWriteGlobal("homesick", homesick)
return homesick
