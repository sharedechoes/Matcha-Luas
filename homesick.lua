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
    local function onInput(input, processed)
        if input and string.find(tostring(input.UserInputType), "MouseWheel") then
            mouseScroll = mouseScroll + (input.Position and input.Position.Z or 0)
        end
    end
    if uis.InputChanged then
        uis.InputChanged:Connect(onInput)
    elseif uis.InputBegan then
        uis.InputBegan:Connect(onInput)
    end
end
if Mouse then
    pcall(function()
        Mouse.WheelForward:Connect(function()
            mouseScroll = mouseScroll + 1
        end)
        Mouse.WheelBackward:Connect(function()
            mouseScroll = mouseScroll - 1
        end)
    end)
end

local Fonts = (type(Drawing) == "table" and Drawing.Fonts) or {}
local FontSystem = Fonts.System or Fonts.UI or 0
local FontBold = Fonts.SystemBold or FontSystem
local FontUI = Fonts.UI or FontSystem

local FontWidths = {}
FontWidths[FontSystem] = 0.52
FontWidths[FontBold] = 0.56
FontWidths[FontUI] = 0.48

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
    bg = C3(30, 27, 26),
    surface = C3(24, 21, 20),
    surface2 = C3(38, 34, 32),
    surface3 = C3(46, 42, 39),
    text = C3(240, 240, 240),
    sub = C3(130, 120, 115),
    accent = C3(222, 196, 151),
    green = C3(52, 199, 89),
    red = C3(255, 69, 58),
    yellow = C3(255, 204, 0),
    unsafe = C3(255, 226, 84),
    border = C3(54, 49, 47),
    toggleOn = C3(222, 196, 151),
    toggleOff = C3(54, 49, 47),
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
}

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
        warn("homesick callback error " .. tostring(result))
        return
    end
    return result
end

local function applyInputState(force)
    local desired = not ProjectState.open
    if force or ProjectState.inputState ~= desired then
        ProjectState.inputState = desired
        setrobloxinput(true)
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
    ProjectState.focus = nil
    applyInputState(false)
    if Mouse then
        pcall(function()
            Mouse.Icon = open and "http://www.roblox.com/asset/?id=12556702945" or ""
        end)
    end
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
    local multiplier = FontWidths[font] or 0.52
    return #tostring(value or "") * ((size or 13) * multiplier)
end

local function trimText(value, maxWidth, size, font)
    value = tostring(value or "")
    if maxWidth <= 0 then
        return ""
    end
    local multiplier = FontWidths[font] or 0.52
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
    d.Position = V2(x, y)
    d.Color = color
    d.Size = size or 13
    d.Font = font or FontSystem
    d.ZIndex = (z or 1) + 10
    d.Center = centered == true
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

local function drawChevronDown(x, y, color, z)
    triangle(V2(x, y), V2(x + 8, y), V2(x + 4, y + 5), color, z, true)
end

local function snapValue(raw, item)
    local minValue = item.min or 0
    local maxValue = item.max or 100
    local step = item.step or 1
    if step <= 0 then
        step = 1
    end
    local steps = floor(((raw - minValue) / step) + 0.5 + 0.0001)
    return clamp(minValue + steps * step, minValue, maxValue)
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

    if item.type == "toggle" then
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

        function handle:AddColorpicker(label, defaultColor, overwrite, callback)
            local picker = {
                label = tostring(label or "Color"),
                value = defaultColor or Theme.accent,
                overwrite = overwrite == true,
                callback = callback,
            }
            item.colorpicker = picker

            local colorHandle = {}
            function colorHandle:Set(newColor)
                if newColor and colorChanged(picker.value, newColor) then
                    picker.value = newColor
                    safeCallback(picker.callback, newColor)
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

local function createSection(tab, name, side)
    local section = {
        name = tostring(name or "Section"),
        side = tostring(side or "Left"),
        items = {},
        collapsed = false,
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
    ProjectState.h = max(120, tonumber(h) or ProjectState.h)
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
    function tabApi:Section(sectionName, side)
        return createSection(tab, sectionName, side)
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

    setrobloxinput(true)
    ProjectState.inputState = true

    removeAllDrawings()
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
    if type(isrbxactive) == "function" then
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

local function smoothValue(current, target, speed)
    local dtValue = ProjectState.dt or 1/60
    if dtValue <= 0 then
        dtValue = 1/60
    end
    return current + (target - current) * (1 - math.exp(-(speed or 15) * dtValue))
end

local toHsv

local function toHex(color)
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
                    if (item.type == "textbox" or item.type == "slider") and not isItemDisabled(item) then
                        list[#list + 1] = item
                    end
                end
            end
        end
    end
    return list
end

local function processTextInput()
    if Input.tab.click then
        local items = getFocusableItems()
        if #items > 0 then
            local currentIdx = nil
            for i = 1, #items do
                if items[i] == ProjectState.focus then
                    currentIdx = i
                    break
                end
            end

            local nextIdx
            local shifted = Input.shift.held or Input.lshift.held or Input.rshift.held
            if currentIdx then
                if shifted then
                    nextIdx = currentIdx - 1
                    if nextIdx < 1 then
                        nextIdx = #items
                    end
                else
                    nextIdx = currentIdx + 1
                    if nextIdx > #items then
                        nextIdx = 1
                    end
                end
            else
                nextIdx = shifted and #items or 1
            end

            local nextItem = items[nextIdx]
            ProjectState.focus = nextItem
            if type(nextItem) == "table" and nextItem.type == "slider" then
                nextItem._directValue = tostring(nextItem.value)
            end
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
    
    if Input.delete.click then
        value = ""
        changed = true
    end

    for i = 1, #InputOrder do
        local name = InputOrder[i]
        local input = Input[name]
        
        if input.click and input.char then
            local char = shifted and input.shifted or input.char
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
            value = string.sub(value, 1, max(0, #value - 1))
            changed = true
            ProjectState.repeatKey = name
            ProjectState.repeatAt = now + 0.4
            any_held = true
            break
        elseif input.held and (name == "backspace" or name == "unbound") and ProjectState.repeatKey == name then
            any_held = true
            if now >= (ProjectState.repeatAt or 0) then
                value = string.sub(value, 1, max(0, #value - 1))
                changed = true
                ProjectState.repeatAt = now + 0.035
            end
            break
        end
    end
    
    if not any_held then
        ProjectState.repeatKey = nil
    end

    if changed then
        if item.type == "textbox" then
            if value ~= item.value then
                item.value = value
                safeCallback(item.callback, value)
            end
        else
            item._directValue = value
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
        if item.type == "toggle" and keybind and keybind.value and not keybind.listening and not isItemDisabled(item) then
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

local function spawnDropdown(kind, x, y, w, choices, value, multi, callback, item, keybind)
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

local PRESET_SWATCHES = {
    C3(0, 122, 255),
    C3(114, 178, 21),
    C3(255, 69, 58),
    C3(255, 204, 0),
    C3(255, 105, 180),
    C3(160, 32, 240),
    C3(255, 255, 255),
    C3(0, 0, 0)
}

local function spawnColorpicker(x, y, picker)
    local h, s, v = toHsv(picker.value)
    local vw, vh = viewportSize()
    local w, height = 200, 220

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
        _hexInput = nil,
    }
    ProjectState.dropdown = nil
end

local function tooltip(text, x, y)
    if not text or text == "" then
        return
    end
    if ProjectState.tooltipText ~= text then
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
            dd.scrollOffset = clamp(dd.scrollOffset - ProjectState.mouseScroll, 0, max(0, #dd.choices - maxRows))
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

    rect(dd.x - 1, dd.y - 1, dd.w + 2, dd.h + 2, Theme.border, 110, 6)
    rect(dd.x, dd.y, dd.w, dd.h, C3(35, 35, 40), 111, 6)

    if isMulti then
        local btnW = (dd.w - 12) / 2
        local btnY = dd.y + 4
        local btnH = 18

        local selectAllX = dd.x + 4
        local clearAllX = dd.x + 8 + btnW

        local hoverSelectAll = over(selectAllX, btnY, btnW, btnH)
        local hoverClearAll = over(clearAllX, btnY, btnW, btnH)

        rect(selectAllX, btnY, btnW, btnH, hoverSelectAll and C3(55, 55, 62) or C3(42, 42, 48), 112, 4)
        strokeRect(selectAllX, btnY, btnW, btnH, hoverSelectAll and Theme.accent or Theme.border, 113, 4)
        txt("Select All", selectAllX + btnW / 2, centerY(btnY, btnH), Theme.text, 11, FontUI, 113, true)

        rect(clearAllX, btnY, btnW, btnH, hoverClearAll and C3(55, 55, 62) or C3(42, 42, 48), 112, 4)
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
        if hovered then
            rect(dd.x + 2, rowY, dd.w - 4, 22, C3(50, 50, 56), 112, 3)
        end
        txt(tostring(choice), dd.x + 8, textTop(rowY, 22, 13), selected and Theme.accent or Theme.text, 13, FontUI, 113, false, false, dd.w - 24)

        if click and hovered then
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
    rect(x, y, w, h, C3(35, 35, 40), 110, 8)
    strokeRect(x, y, w, h, Theme.border, 111, 8)
    txt(cp.picker.label, x + 10, y + 8, Theme.text, 13, FontBold, 112, false, false, w - 20)

    local palX, palY = x + 10, y + 28
    local palW, palH = w - 20, 82
    local cell = 18

    for gx = palX, palX + palW - 1, cell do
        local sx = clamp((gx - palX) / palW, 0, 1)
        for gy = palY, palY + palH - 1, cell do
            local sy = 1 - clamp((gy - palY) / palH, 0, 1)
            rect(gx, gy, cell, cell, HSV(cp.hue, sx, sy), 113, 0)
        end
    end

    if held and over(palX, palY, palW, palH) then
        cp.sat = clamp((ProjectState.mouseX - palX) / palW, 0, 1)
        cp.val = 1 - clamp((ProjectState.mouseY - palY) / palH, 0, 1)
    end

    local markerX = palX + cp.sat * palW
    local markerY = palY + (1 - cp.val) * palH
    circle(markerX, markerY, 4, Theme.white, 116, false, 2, 20)

    local hueX, hueY = x + 10, y + 118
    local hueW, hueH = w - 20, 10
    for gx = hueX, hueX + hueW - 1, 12 do
        rect(gx, hueY, 12, hueH, HSV((gx - hueX) / hueW, 1, 1), 113, 0)
    end

    if held and over(hueX, hueY, hueW, hueH) then
        cp.hue = clamp((ProjectState.mouseX - hueX) / hueW, 0, 1)
    end

    rect(hueX + cp.hue * hueW - 2, hueY - 1, 4, hueH + 2, Theme.white, 116, 1)

    local swY = y + 136
    local swW = 14
    local swSpacing = (w - 20 - (swW * #PRESET_SWATCHES)) / (#PRESET_SWATCHES - 1)
    for i = 1, #PRESET_SWATCHES do
        local swColor = PRESET_SWATCHES[i]
        local swX = x + 10 + (i - 1) * (swW + swSpacing)
        local hovered = over(swX, swY, swW, swW)
        rect(swX, swY, swW, swW, swColor, 114, 2)
        strokeRect(swX, swY, swW, swW, hovered and Theme.accent or Theme.border, 115, 2)

        if click and hovered then
            local h_s, s_s, v_s = toHsv(swColor)
            cp.hue = h_s
            cp.sat = s_s
            cp.val = v_s
            cp.value = swColor
            click = false
        end
    end

    local hexY = y + 158
    local hexW = w - 20
    local hexH = 22
    local hexFocused = ProjectState.focus == cp
    local hexHovered = over(x + 10, hexY, hexW, hexH)

    rect(x + 10, hexY, hexW, hexH, hexFocused and C3(25, 25, 30) or hexHovered and C3(45, 45, 52) or C3(35, 35, 40), 114, 4)
    strokeRect(x + 10, hexY, hexW, hexH, hexFocused and Theme.accent or Theme.border, 115, 4)

    local hexText = hexFocused and (cp._hexInput or "") or ("#" .. toHex(cp.value))
    if hexFocused and floor(clock() * 2) % 2 == 0 then
        hexText = hexText .. "|"
    end
    txt(hexText, x + 16, textTop(hexY, hexH, 12), Theme.text, 12, FontUI, 116, false, false, hexW - 12)

    if click and hexHovered then
        ProjectState.focus = hexFocused and nil or cp
        cp._hexInput = toHex(cp.value)
        click = false
    end

    local r = floor(cp.value.R * 255 + 0.5)
    local g = floor(cp.value.G * 255 + 0.5)
    local b = floor(cp.value.B * 255 + 0.5)
    local rgbText = string.format("R: %d  G: %d  B: %d", r, g, b)
    txt(rgbText, x + 10, y + 188, Theme.sub, 11, FontUI, 114, false, false, w - 20)

    rect(x + w - 30, y + 186, 20, 14, cp.value, 114, 3)
    strokeRect(x + w - 30, y + 186, 20, 14, Theme.border, 115, 3)

    local final = HSV(cp.hue, cp.sat, cp.val)
    if colorChanged(final, cp.value) then
        cp.value = final
        cp.picker.value = final
        safeCallback(cp.picker.callback, final)
    end

    if click and not over(x, y, w, h) then
        if ProjectState.focus == cp then
            ProjectState.focus = nil
        end
        ProjectState.colorpicker = nil
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
            ProjectState.activeTab = tab
            ProjectState.activeIndex = i
            ProjectState.dropdown = nil
            ProjectState.colorpicker = nil
            ProjectState.focus = nil
            ProjectState.draggedTab = tab
            ProjectState.draggedTabOffset = ProjectState.mouseX - screenX
            ProjectState.dragTabStartMouseX = ProjectState.mouseX
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
                targetPillX = tx + 4
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
        else
            ProjectState.currentPillX = smoothValue(ProjectState.currentPillX, targetPillX, 18)
            ProjectState.currentPillW = smoothValue(ProjectState.currentPillW, targetPillW, 18)
        end
    end

    if ProjectState.currentPillX and ProjectState.currentPillW then
        rect(ProjectState.currentPillX, py + 3, ProjectState.currentPillW, TAB_H - 6, Theme.accent, 21, 10, 0.08)
        strokeRect(ProjectState.currentPillX, py + 3, ProjectState.currentPillW, TAB_H - 6, Theme.accent, 22, 10)
    end

    return click
end

local function renderToggleExtras(item, rowX, rowY, rowW, click, rightClick)
    if item.keybind then
        local keybind = item.keybind
        local keyText = keybind.listening and "..." or (keybind.value and string.upper(keybind.value) or "-")
        local keyW = 46
        local keyX = rowX + rowW - 96
        local keyY = rowY + 3
        local keyH = 20
        local hovered = over(keyX, keyY, keyW, keyH)

        rect(keyX, keyY, keyW, keyH, Theme.surface3, 45, 4)
        strokeRect(keyX, keyY, keyW, keyH, hovered and Theme.accent or Theme.border, 46, 4)

        txt(keyText, keyX + keyW / 2, centerY(keyY, keyH), keybind.value and Theme.text or Theme.sub, 12, FontUI, 52, true, false, keyW - 4)

        local modeTag = keybind.mode == "Toggle" and "T" or keybind.mode == "Always" and "A" or "H"
        local modeColor = keybind.mode == "Hold" and Theme.sub or Theme.accent
        txt(modeTag, rowX + rowW - 108, centerY(rowY, ROW_H - 2), modeColor, 10, FontUI, 52, true)

        if keybind.listening then
            for i = 1, #InputOrder do
                local name = InputOrder[i]
                local input = Input[name]
                if input.click and (name ~= "m1" or clock() - keybind.listenAt > 0.25) then
                    local newKey = normalizeKey(name)
                    if name == "backspace" or name == "delete" or name == "unbound" then
                        newKey = nil
                    end
                    keybind.value = newKey
                    keybind.listening = false
                    safeCallback(keybind.callback, newKey and Input[newKey] and Input[newKey].id or nil, keybind.mode)
                    break
                end
            end
        elseif click and hovered then
            keybind.listening = true
            keybind.listenAt = clock()
            click = false
        elseif rightClick and hovered and keybind.canChange then
            spawnDropdown("keymode", keyX, rowY + 24, 90, KEYBIND_MODES, nil, false, nil, nil, keybind)
            rightClick = false
        end
    end

    if item.colorpicker then
        local picker = item.colorpicker
        local cpX = rowX + rowW - 124
        local cpW = 12
        local cpH = 12
        local cpY = rowY + 8
        local hovered = over(cpX - 3, cpY - 3, cpW + 6, cpH + 6)

        rect(cpX, cpY, cpW, cpH, picker.value, 46, 3)
        strokeRect(cpX, cpY, cpW, cpH, Theme.border, 47, 3)

        if hovered then
            strokeRect(cpX - 2, cpY - 2, cpW + 4, cpH + 4, Theme.accent, 48, 4)
        end

        if click and hovered then
            spawnColorpicker(ProjectState.mouseX + 14, ProjectState.mouseY - 90, picker)
            click = false
        elseif rightClick and hovered then
            spawnDropdown("colorctx", cpX - 34, rowY + 24, 80, {"Copy", "Paste"}, {}, false, function(choice)
                local selected = choice and choice[1]
                if selected == "Copy" then
                    ProjectState.copiedColor = picker.value
                    pcall(setclipboard, "#" .. toHex(picker.value))
                elseif selected == "Paste" then
                    if ProjectState.copiedColor and colorChanged(picker.value, ProjectState.copiedColor) then
                        picker.value = ProjectState.copiedColor
                        safeCallback(picker.callback, picker.value)
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

local function getItemHeight(item)
    if item.type == "slider" then
        return 38
    elseif item.type == "dropdown" then
        return 44
    elseif item.type == "textbox" then
        return 44
    end
    return 28
end

local function draw9Dot(x, y, color, z, trans)
    for row = 0, 2 do
        for col = 0, 2 do
            circle(x + col * 3, y + row * 3, 1, color, z, true, 0, 8, trans)
        end
    end
end

local function renderSectionCard(section, colX, sy, colW, secH, clipTop, clipBottom, click, held, rightClick, isPlaceholder, isFloating)
    local popupBlocking = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil or isFloating
    local z = isFloating and 90 or 30
    
    local fade = ProjectState.contentFade or 1
    local cardTrans = isFloating and (0.75 * fade) or fade
    
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
        
        if sy + 8 >= cardClipTop and sy + 22 <= cardClipBottom then
            txt(section.name, colX + 12, sy + 8, Theme.accent, 13, FontBold, z + 2, false, false, nil, cardTrans)
        end
        
        if sy + 10 >= cardClipTop and sy + 19 <= cardClipBottom then
            draw9Dot(colX + colW - 20, sy + 10, Theme.sub, z + 2, cardTrans)
        end
        
        if not isFloating then
            local handleHovered = over(colX + colW - 22, sy + 8, 14, 14)
            if click and handleHovered and not popupBlocking then
                ProjectState.draggedSection = section
                ProjectState.dragOffset = {ProjectState.mouseX - colX, ProjectState.mouseY - sy}
                ProjectState.dragStartMouseX = ProjectState.mouseX
                ProjectState.draggedSectionOriginalSide = section.side
                click = false
            end
            
            local bottomHovered = over(colX, sy + secH - 4, colW, 8)
            if click and bottomHovered and not popupBlocking then
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
            local itemH = getItemHeight(item)
            
            if rowY >= max(cardClipTop, sy + 26) and rowY + itemH <= min(cardClipBottom, sy + secH - 4) then
                local disabled = isItemDisabled(item)
                local trans = (disabled and 0.4 or 1) * cardTrans
                
                if item.type == "label" then
                    txt(item.label, rowX, textTop(rowY, itemH - 2, 13), item.color or Theme.text, 13, FontSystem, z + 12, false, false, rowW, trans)
                    
                elseif item.type == "toggle" then
                    rect(rowX + 4, rowY + 6, 14, 14, item.value and Theme.accent or Theme.surface3, z + 12, 4, trans)
                    strokeRect(rowX + 4, rowY + 6, 14, 14, item.value and Theme.accent or Theme.border, z + 13, 4, trans)
                    
                    txt(item.label, rowX + 26, textTop(rowY, itemH - 2, 13), item.unsafe and Theme.unsafe or (item.value and Theme.text or Theme.sub), 13, FontSystem, z + 12, false, false, rowW - 120, trans)
                    
                    if not isFloating then
                        click, rightClick = renderToggleExtras(item, rowX, rowY, rowW, click, rightClick)
                    end
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 6, 12, 12)
                        txt("?", rowX + rowW - 10, textTop(rowY, itemH - 2, 13), qHovered and Theme.accent or Theme.sub, 13, FontSystem, z + 12, true, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
                        end
                    end
                    
                    if click and over(rowX, rowY, rowW, itemH) and not popupBlocking and not disabled then
                        local onKeybind = item.keybind and over(rowX + rowW - 96, rowY + 3, 46, 20)
                        local onColor = item.colorpicker and over(rowX + rowW - 127, rowY + 5, 18, 18)
                        local onQ = item.tooltip and over(rowX + rowW - 16, rowY + 6, 12, 12)
                        local on9Dot = over(colX + colW - 22, sy + 8, 14, 14)
                        if not onKeybind and not onColor and not onQ and not on9Dot then
                            setItemValue(item, not item.value, true)
                            click = false
                        end
                    end
                    
                elseif item.type == "slider" then
                    txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 80, trans)
                    
                    txt(tostring(item.value) .. tostring(item.suffix or ""), rowX + rowW - 4 - textWidth(tostring(item.value) .. tostring(item.suffix or ""), 13, FontSystem), rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, 60, trans)
                    
                    local sx, sw = rowX + 4, rowW - 8
                    local sy_bar = rowY + 22
                    local denom = max(0.0001, (item.max or 100) - (item.min or 0))
                    local frac = clamp(((item.value or 0) - (item.min or 0)) / denom, 0, 1)
                    
                    rect(sx, sy_bar, sw, 4, C3(58, 58, 64), z + 12, 2, trans)
                    if frac > 0 then
                        rect(sx, sy_bar, sw * frac, 4, Theme.accent, z + 13, 2, trans)
                    end
                    
                    circle(sx + sw * frac, sy_bar + 2, 5, Theme.knob, z + 14, true, 0, 32, trans)
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 2, 12, 12)
                        txt("?", rowX + rowW - 10, rowY + 2, qHovered and Theme.accent or Theme.sub, 13, FontSystem, z + 12, true, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
                        end
                    end
                    
                    if click and over(sx - 4, sy_bar - 8, sw + 8, 16) and not popupBlocking and not disabled then
                        ProjectState.sliderDrag = item
                        click = false
                    end
                    if held and not popupBlocking and not disabled and (ProjectState.sliderDrag == item) then
                        local raw = (item.min or 0) + denom * clamp((ProjectState.mouseX - sx) / sw, 0, 1)
                        local snapped = snapValue(raw, item)
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
                    
                    rect(dx, dy_box, dw, boxH, over(dx, dy_box, dw, boxH) and C3(55, 55, 62) or C3(42, 42, 48), z + 12, 4, trans)
                    strokeRect(dx, dy_box, dw, boxH, Theme.border, z + 13, 4, trans)
                    
                    txt(item.multi and (#item.value > 0 and concat(item.value, ", ") or "-") or (item.value[1] or "-"), dx + 8, textTop(dy_box, boxH, 13), Theme.text, 13, FontUI, z + 14, false, false, dw - 28, trans)
                    drawChevronDown(dx + dw - 15, centerY(dy_box, boxH) - 2, Theme.sub, z + 15)
                    
                    if item.tooltip and not isFloating then
                        local qHovered = over(rowX + rowW - 16, rowY + 2, 12, 12)
                        txt("?", rowX + rowW - 10, rowY + 2, qHovered and Theme.accent or Theme.sub, 13, FontSystem, z + 12, true, false, nil, trans)
                        if qHovered and not disabled then
                            tooltip(item.tooltip, ProjectState.mouseX, ProjectState.mouseY)
                        end
                    end
                    
                    if click and over(dx, dy_box, dw, boxH) and not popupBlocking and not disabled then
                        spawnDropdown("item", dx, dy_box + boxH + 4, dw, item.choices, item.value, item.multi, item.callback, item, nil)
                        click = false
                    end
                    
                elseif item.type == "button" then
                    local controlY = rowY + 2
                    rect(rowX + 4, controlY, rowW - 8, itemH - 4, over(rowX + 4, controlY, rowW - 8, itemH - 4) and Theme.accent or C3(42, 42, 48), z + 12, 6, trans)
                    strokeRect(rowX + 4, controlY, rowW - 8, itemH - 4, over(rowX + 4, controlY, rowW - 8, itemH - 4) and Theme.accent or Theme.border, z + 13, 6, trans)
                    txt(item.label, rowX + rowW / 2, centerY(controlY, itemH - 4), over(rowX + 4, controlY, rowW - 8, itemH - 4) and Theme.bg or Theme.text, 13, FontBold, z + 14, true, false, rowW - 24, trans)
                    
                    if click and over(rowX + 4, controlY, rowW - 8, itemH - 4) and not popupBlocking and not disabled then
                        safeCallback(item.callback)
                        click = false
                    end
                    
                elseif item.type == "textbox" then
                    txt(item.label, rowX + 4, rowY + 2, Theme.text, 13, FontSystem, z + 12, false, false, rowW - 20, trans)
                    
                    local bx, bw = rowX + 4, rowW - 8
                    local dy_box = rowY + 18
                    local boxH = 22
                    local focused = ProjectState.focus == item
                    
                    rect(bx, dy_box, bw, boxH, focused and C3(35, 35, 42) or over(bx, dy_box, bw, boxH) and C3(55, 55, 62) or C3(42, 42, 48), z + 12, 4, trans)
                    strokeRect(bx, dy_box, bw, boxH, focused and Theme.accent or Theme.border, z + 13, 4, trans)
                    
                    local shown = item.value ~= "" and item.value or item.label
                    if focused and floor(clock() * 2) % 2 == 0 then
                        shown = tostring(item.value or "") .. "|"
                    end
                    txt(shown, bx + 8, textTop(dy_box, boxH, 13), (item.value ~= "" or focused) and Theme.text or Theme.sub, 13, FontUI, z + 14, false, false, bw - 16, trans)
                    
                    if click and over(bx, dy_box, bw, boxH) and not popupBlocking and not disabled then
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
        local secH = sec.customHeight or 28
        if not sec.customHeight then
            for ii = 1, #sec.items do
                secH = secH + getItemHeight(sec.items[ii])
            end
            secH = secH + 6
        end
        sec.calculatedHeight = secH
        leftTotal = leftTotal + secH + 10
    end

    local rightTotal = 0
    for i = 1, #rightSecs do
        local sec = rightSecs[i]
        local secH = sec.customHeight or 28
        if not sec.customHeight then
            for ii = 1, #sec.items do
                secH = secH + getItemHeight(sec.items[ii])
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

    if tab.maxScroll > 0 and not popupBlocking and not ProjectState.focus then
        if ProjectState.mouseScroll ~= 0 and over(px, contY, pw, contH) then
            tab.targetScrollY = clamp(tab.targetScrollY - ProjectState.mouseScroll * 28, 0, tab.maxScroll)
        end
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
                if ProjectState.mouseY < (prevSec.lastRenderY or 0) + (prevSec.calculatedHeight or 0) / 2 then
                    tab.sections[dragIdx], tab.sections[dragIdx - 1] = tab.sections[dragIdx - 1], tab.sections[dragIdx]
                end
            end
            if dragIdx < #tab.sections then
                local nextSec = tab.sections[dragIdx + 1]
                if ProjectState.mouseY > (nextSec.lastRenderY or 0) + (nextSec.calculatedHeight or 0) / 2 then
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
        ProjectState.resizeSection.customHeight = max(40, ProjectState.resizeSectionStartH + dy)
    else
        ProjectState.resizeSection = nil
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

    if tab.maxScroll > 0 then
        local trackH = contH - CONTENT_PAD * 2
        local barH = max(22, (trackH / max(contentH, trackH)) * trackH)
        local barY = contY + CONTENT_PAD + (tab.scrollY / max(1, tab.maxScroll)) * (trackH - barH)
        rect(px + pw - 6, contY + CONTENT_PAD, 3, trackH, C3(45, 45, 52), 50, 2)
        rect(px + pw - 6, barY, 3, barH, Theme.sub, 51, 2)
        if click and over(px + pw - 11, contY + CONTENT_PAD, 12, trackH) and not popupBlocking then
            local grab = barH / 2
            if over(px + pw - 11, barY, 12, barH) then
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
            tab.targetScrollY = clamp((ProjectState.mouseY - (contY + CONTENT_PAD) - drag.grab) / max(1, trackH - barH), 0, 1) * tab.maxScroll
        end
    elseif type(ProjectState.scrollDrag) == "table" and ProjectState.scrollDrag.tab == tab then
        ProjectState.scrollDrag = nil
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
    local popupOpen = ProjectState.dropdown ~= nil or ProjectState.colorpicker ~= nil
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
        if nearL and nearT then edge = "topleft"
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
            local targetH = start.h - dy
            if targetH >= 120 then
                newH = targetH
                newY = start.y + dy
            end
        end
        if drag == "bottom" or drag == "bottomleft" or drag == "bottomright" then
            newH = max(120, start.h + dy)
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

    txt("homesick", x + 14, textTop(y, TITLE_H, 14), Theme.accent, 14, FontBold, 16)
    txt("Interface", x + 85, textTop(y, TITLE_H, 14), Theme.text, 14, FontSystem, 16)
    rect(x + 158, textTop(y, TITLE_H, 14) - 1, 30, 16, C3(38, 34, 32), 15, 6)
    strokeRect(x + 158, textTop(y, TITLE_H, 14) - 1, 30, 16, Theme.accent, 16, 6)
    txt("Pro", x + 173, textTop(y, TITLE_H, 14) + 7, Theme.accent, 10, FontBold, 17, true)

    local userStr = LocalPlayer and LocalPlayer.Name or "kiyomi"
    txt(userStr, x + w - 14 - textWidth(userStr, 13, FontUI), textTop(y, TITLE_H, 13), Theme.text, 13, FontUI, 16)

    if ProjectState.minimized or h <= MINIMIZED_H then
        return click, held, rightClick
    end

    local px, py = x + PAD, y + TITLE_H + PAD
    local pw, ph = w - PAD * 2, h - TITLE_H - PAD * 2 - 24
    if pw <= 40 or ph <= 40 then
        return click, held, rightClick
    end

    baseClick = renderTabs(baseClick, px, py, pw)

    local contY = py + TAB_H + 8
    local contH = ph - TAB_H - 8

    local fade = ProjectState.contentFade or 1
    if fade < 1 then
        fade = smoothValue(fade, 1, 16)
        ProjectState.contentFade = fade
    end

    baseClick, baseHeld, baseRightClick = renderSections(ProjectState.activeTab, baseClick, baseHeld, baseRightClick, px, contY, pw, contH)

    if ProjectState.focus and baseClick and not over(px, contY, pw, contH) then
        ProjectState.focus = nil
        baseClick = false
    end

    local botY = y + h - 24
    local botH = 24
    line(x + 2, botY, x + w - 2, botY, Theme.border, 8)
    circle(x + 14, botY + 12, 3, C3(52, 199, 89), 10)
    txt(tostring(onlineCount) .. " online", x + 24, textTop(botY, botH, 11), Theme.text, 11, FontUI, 10)
    txt("Build: May 19 2026", x + w - 14 - textWidth("Build: May 19 2026", 11, FontUI), textTop(botY, botH, 11), Theme.sub, 11, FontUI, 10)

    return popupOpen and click or baseClick, popupOpen and held or baseHeld, popupOpen and rightClick or baseRightClick
end

local function step()
    resetPool()
    ProjectState.tooltipText = nil

    local now = clock()
    local dt = now - ProjectState.lastFrame
    ProjectState.lastFrame = now
    ProjectState.dt = dt

    getMouse()
    updateInput()

    if Input[MENU_KEY] and Input[MENU_KEY].click then
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
        hideUnused()
        return
    end

    if not ProjectState.hasMouse then
        renderWatermark(click, held)
        hideUnused()
        return
    end

    clampWindow()

    click, held, rightClick = renderWindow(click, held, rightClick)
    click = renderDropdown(click)
    click = renderColorpicker(click, held)
    renderTooltip()

    if rightClick and ProjectState.dropdown == nil and ProjectState.colorpicker == nil then
        rightClick = false
    end

    renderWatermark(click, held)

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
            warn("homesick step error " .. tostring(err))
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

homesick.createWindow = function(title, width, height)
    UI:SetTitle(title)
    UI:SetSize(width, height)
    UI:Center()
    
    local windowWrap = {}
    
    windowWrap.addTab = function(wSelf, tabName)
        local tabWrap = {
            rawTab = UI:Tab(tabName),
            name = tabName
        }
        
        tabWrap.addSection = function(tSelf, secName, column)
            local secWrap = {
                rawSec = tSelf.rawTab:Section(secName, column),
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
                
                return widgetWrap
            end
            
            secWrap.addSlider = function(sSelf, id, label, min, max, default, callback)
                local widgetWrap = {
                    id = id,
                    type = "Slider",
                    rawItem = sSelf.rawSec:Slider(label, default, (max - min) / 100, min, max, "", callback)
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
    
    return windowWrap
end

_G.homesick = homesick
return homesick
