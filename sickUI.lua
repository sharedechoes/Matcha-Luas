local sickUi = {}

local function keyCodeToChar(keyCode, isShiftDown)
    local name = keyCode.Name
    if #name == 1 then
        if isShiftDown then
            return name:upper()
        else
            return name:lower()
        end
    elseif name == "Space" then
        return " "
    elseif name == "Period" then
        return "."
    elseif name == "Minus" then
        return "-"
    elseif name == "Underscore" then
        return "_"
    elseif name == "Zero" then return isShiftDown and ")" or "0"
    elseif name == "One" then return isShiftDown and "!" or "1"
    elseif name == "Two" then return isShiftDown and "@" or "2"
    elseif name == "Three" then return isShiftDown and "#" or "3"
    elseif name == "Four" then return isShiftDown and "$" or "4"
    elseif name == "Five" then return isShiftDown and "%" or "5"
    elseif name == "Six" then return isShiftDown and "^" or "6"
    elseif name == "Seven" then return isShiftDown and "&" or "7"
    elseif name == "Eight" then return isShiftDown and "*" or "8"
    elseif name == "Nine" then return isShiftDown and "(" or "9"
    end
    return nil
end

sickUi.createWindow = function(title, width, height)
    print("creating window " .. tostring(title) .. " size " .. tostring(title))
    print("window width " .. tostring(width) .. " height " .. tostring(height))
    
    local self = {
        title = title,
        width = width,
        height = height,
        visible = false,
        dragging = false,
        tabs = {},
        activeTab = 1,
        x = workspace.CurrentCamera.ViewportSize.X / 2 - width / 2,
        y = workspace.CurrentCamera.ViewportSize.Y / 2 - height / 2,
        drawings = {},
        dragOffset = Vector2.new(0, 0)
    }

    self.drawings.bg = Drawing.new("Square")
    self.drawings.bg.Visible = false
    self.drawings.bg.Filled = true
    self.drawings.bg.Color = Color3.fromRGB(24, 22, 21)
    self.drawings.bg.Transparency = 1.0
    self.drawings.bg.ZIndex = 100

    self.drawings.border = Drawing.new("Square")
    self.drawings.border.Visible = false
    self.drawings.border.Filled = false
    self.drawings.border.Color = Color3.fromRGB(45, 41, 38)
    self.drawings.border.Thickness = 1.5
    self.drawings.border.Transparency = 1.0
    self.drawings.border.ZIndex = 101

    self.drawings.header = Drawing.new("Square")
    self.drawings.header.Visible = false
    self.drawings.header.Filled = true
    self.drawings.header.Color = Color3.fromRGB(20, 18, 17)
    self.drawings.header.Transparency = 1.0
    self.drawings.header.ZIndex = 101

    self.drawings.titleText = Drawing.new("Text")
    self.drawings.titleText.Visible = false
    self.drawings.titleText.Font = Drawing.Fonts.UI
    self.drawings.titleText.Size = 13
    self.drawings.titleText.Color = Color3.fromRGB(240, 230, 220)
    self.drawings.titleText.Text = title
    self.drawings.titleText.ZIndex = 102

    self.drawings.logoText = Drawing.new("Text")
    self.drawings.logoText.Visible = false
    self.drawings.logoText.Font = Drawing.Fonts.UI
    self.drawings.logoText.Size = 13
    self.drawings.logoText.Color = Color3.fromRGB(191, 155, 95)
    self.drawings.logoText.Text = "matcha"
    self.drawings.logoText.ZIndex = 102

    self.drawings.footer = Drawing.new("Square")
    self.drawings.footer.Visible = false
    self.drawings.footer.Filled = true
    self.drawings.footer.Color = Color3.fromRGB(20, 18, 17)
    self.drawings.footer.Transparency = 1.0
    self.drawings.footer.ZIndex = 101

    self.drawings.footerText = Drawing.new("Text")
    self.drawings.footerText.Visible = false
    self.drawings.footerText.Font = Drawing.Fonts.UI
    self.drawings.footerText.Size = 11
    self.drawings.footerText.Color = Color3.fromRGB(191, 155, 95)
    self.drawings.footerText.Text = "matcha.pink/discord"
    self.drawings.footerText.Center = true
    self.drawings.footerText.ZIndex = 102

    self.drawings.tooltipBg = Drawing.new("Square")
    self.drawings.tooltipBg.Visible = false
    self.drawings.tooltipBg.Filled = true
    self.drawings.tooltipBg.Color = Color3.fromRGB(24, 22, 21)
    self.drawings.tooltipBg.Transparency = 1.0
    self.drawings.tooltipBg.ZIndex = 1000

    self.drawings.tooltipText = Drawing.new("Text")
    self.drawings.tooltipText.Visible = false
    self.drawings.tooltipText.Font = Drawing.Fonts.UI
    self.drawings.tooltipText.Size = 11
    self.drawings.tooltipText.Color = Color3.fromRGB(240, 230, 220)
    self.drawings.tooltipText.ZIndex = 1001

    self.addTab = function(wSelf, name)
        print("adding tab " .. tostring(name) .. " to window " .. tostring(wSelf.title))
        local tab = {
            name = name,
            sections = {}
        }
        
        tab.drawings = {}
        tab.drawings.bg = Drawing.new("Square")
        tab.drawings.bg.Visible = false
        tab.drawings.bg.Filled = true
        tab.drawings.bg.Color = Color3.fromRGB(40, 36, 33)
        tab.drawings.bg.ZIndex = 102
        
        tab.drawings.button = Drawing.new("Text")
        tab.drawings.button.Visible = false
        tab.drawings.button.Font = Drawing.Fonts.UI
        tab.drawings.button.Size = 12
        tab.drawings.button.Center = true
        tab.drawings.button.Text = name
        tab.drawings.button.ZIndex = 103

        tab.addSection = function(tSelf, secName, column)
            print("adding section " .. tostring(secName) .. " to tab " .. tostring(tSelf.name))
            print("column is " .. tostring(column) .. " column " .. tostring(column))
            
            local section = {
                name = secName,
                column = column,
                widgets = {},
                drawings = {}
            }
            
            section.drawings.border = Drawing.new("Square")
            section.drawings.border.Visible = false
            section.drawings.border.Filled = false
            section.drawings.border.Color = Color3.fromRGB(45, 41, 38)
            section.drawings.border.Thickness = 1
            section.drawings.border.ZIndex = 102
            
            section.drawings.titleBg = Drawing.new("Square")
            section.drawings.titleBg.Visible = false
            section.drawings.titleBg.Filled = true
            section.drawings.titleBg.Color = Color3.fromRGB(24, 22, 21)
            section.drawings.titleBg.ZIndex = 103
            
            section.drawings.titleText = Drawing.new("Text")
            section.drawings.titleText.Visible = false
            section.drawings.titleText.Font = Drawing.Fonts.UI
            section.drawings.titleText.Size = 12
            section.drawings.titleText.Color = Color3.fromRGB(191, 155, 95)
            section.drawings.titleText.Text = secName
            section.drawings.titleText.ZIndex = 104
            
            table.insert(tSelf.sections, section)
            
            section.addWidget = function(widget)
                table.insert(section.widgets, widget)
                if widget.type then
                    return widget
                end
            end

            section.addToggle = function(sSelf, id, label, default, callback)
                print("adding toggle " .. tostring(id) .. " to section " .. tostring(sSelf.name))
                print("default is " .. tostring(default) .. " default " .. tostring(default))
                
                local widget = {
                    id = id,
                    type = "Toggle",
                    label = label,
                    value = default or false,
                    callback = callback,
                    drawings = {}
                }
                
                widget.drawings.label = Drawing.new("Text")
                widget.drawings.label.Visible = false
                widget.drawings.label.Font = Drawing.Fonts.UI
                widget.drawings.label.Size = 12
                widget.drawings.label.Color = Color3.fromRGB(240, 230, 220)
                widget.drawings.label.Text = label
                widget.drawings.label.ZIndex = 103
                
                widget.drawings.box = Drawing.new("Square")
                widget.drawings.box.Visible = false
                widget.drawings.box.Filled = true
                widget.drawings.box.Size = Vector2.new(10, 10)
                widget.drawings.box.ZIndex = 103
                
                widget.position = function(wSelf, wx, wy, ww)
                    if wSelf then
                        wSelf.drawings.label.Position = Vector2.new(wx, wy)
                        wSelf.drawings.box.Position = Vector2.new(wx + ww - 12, wy + 2)
                    end
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.label.Visible = visible
                    wSelf.drawings.box.Visible = visible
                    wSelf.drawings.box.Color = wSelf.value and Color3.fromRGB(191, 155, 95) or Color3.fromRGB(40, 36, 33)
                end
                
                widget.click = function(wSelf)
                    wSelf.value = not wSelf.value
                    if wSelf.callback then
                        pcall(wSelf.callback, wSelf.value)
                    end
                end

                widget.addTooltip = function(wSelf, text)
                    wSelf.desc = text
                    print("adding tooltip " .. tostring(text) .. " to " .. tostring(wSelf.id))
                    return wSelf
                end
                
                if sSelf and sSelf.widgets then
                    return sSelf.addWidget(widget)
                end
            end

            section.addSlider = function(sSelf, id, label, min, max, default, callback)
                print("adding slider " .. tostring(id) .. " to section " .. tostring(sSelf.name))
                print("min is " .. tostring(min) .. " max " .. tostring(max))
                print("default is " .. tostring(default) .. " default " .. tostring(default))
                
                local widget = {
                    id = id,
                    type = "Slider",
                    label = label,
                    min = min,
                    max = max,
                    value = default or min,
                    callback = callback,
                    drawings = {}
                }
                
                widget.drawings.label = Drawing.new("Text")
                widget.drawings.label.Visible = false
                widget.drawings.label.Font = Drawing.Fonts.UI
                widget.drawings.label.Size = 12
                widget.drawings.label.Color = Color3.fromRGB(240, 230, 220)
                widget.drawings.label.Text = label
                widget.drawings.label.ZIndex = 103
                
                widget.drawings.track = Drawing.new("Line")
                widget.drawings.track.Visible = false
                widget.drawings.track.Thickness = 3
                widget.drawings.track.Color = Color3.fromRGB(40, 36, 33)
                widget.drawings.track.ZIndex = 103
                
                widget.drawings.fill = Drawing.new("Line")
                widget.drawings.fill.Visible = false
                widget.drawings.fill.Thickness = 3
                widget.drawings.fill.Color = Color3.fromRGB(191, 155, 95)
                widget.drawings.fill.ZIndex = 104
                
                widget.drawings.knob = Drawing.new("Square")
                widget.drawings.knob.Visible = false
                widget.drawings.knob.Filled = true
                widget.drawings.knob.Size = Vector2.new(6, 10)
                widget.drawings.knob.Color = Color3.fromRGB(240, 230, 220)
                widget.drawings.knob.ZIndex = 105
                
                widget.position = function(wSelf, wx, wy, ww)
                    wSelf.drawings.label.Position = Vector2.new(wx, wy)
                    local trackWidth = 80
                    local trackX = wx + ww - trackWidth
                    local pct = (wSelf.value - wSelf.min) / (wSelf.max - wSelf.min)
                    wSelf.drawings.track.From = Vector2.new(trackX, wy + 6)
                    wSelf.drawings.track.To = Vector2.new(trackX + trackWidth, wy + 6)
                    wSelf.drawings.fill.From = Vector2.new(trackX, wy + 6)
                    wSelf.drawings.fill.To = Vector2.new(trackX + trackWidth * pct, wy + 6)
                    wSelf.drawings.knob.Position = Vector2.new(trackX + trackWidth * pct - 3, wy + 1)
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.label.Visible = visible
                    wSelf.drawings.track.Visible = visible
                    wSelf.drawings.fill.Visible = visible
                    wSelf.drawings.knob.Visible = visible
                    wSelf.drawings.label.Text = wSelf.label .. " (" .. string.format("%.2f", wSelf.value) .. ")"
                end
                
                widget.click = function(wSelf, mouseX, ww, wx)
                    local trackWidth = 80
                    if ww and wx and ww == ww and wx == wx then
                        local pct = math.clamp((mouseX - (wx + ww - trackWidth)) / trackWidth, 0, 1)
                        wSelf.value = wSelf.min + pct * (wSelf.max - wSelf.min)
                        if wSelf.callback then
                            pcall(wSelf.callback, wSelf.value)
                        end
                    end
                end

                widget.addTooltip = function(wSelf, text)
                    wSelf.desc = text
                    print("adding tooltip " .. tostring(text) .. " to " .. tostring(wSelf.id))
                    return wSelf
                end
                
                if sSelf and sSelf.widgets then
                    return sSelf.addWidget(widget)
                end
            end

            section.addButton = function(sSelf, btnLabel, callback)
                print("adding button " .. tostring(btnLabel) .. " to section " .. tostring(sSelf.name))
                
                local widget = {
                    type = "Button",
                    label = btnLabel,
                    callback = callback,
                    drawings = {}
                }
                
                widget.drawings.box = Drawing.new("Square")
                widget.drawings.box.Visible = false
                widget.drawings.box.Filled = true
                widget.drawings.box.Color = Color3.fromRGB(40, 36, 33)
                widget.drawings.box.ZIndex = 103
                
                widget.drawings.border = Drawing.new("Square")
                widget.drawings.border.Visible = false
                widget.drawings.border.Filled = false
                widget.drawings.border.Color = Color3.fromRGB(45, 41, 38)
                widget.drawings.border.Thickness = 1
                widget.drawings.border.ZIndex = 104
                
                widget.drawings.label = Drawing.new("Text")
                widget.drawings.label.Visible = false
                widget.drawings.label.Font = Drawing.Fonts.UI
                widget.drawings.label.Size = 12
                widget.drawings.label.Color = Color3.fromRGB(240, 230, 220)
                widget.drawings.label.Text = btnLabel
                widget.drawings.label.Center = true
                widget.drawings.label.ZIndex = 105
                
                widget.position = function(wSelf, wx, wy, ww)
                    wSelf.drawings.box.Position = Vector2.new(wx, wy)
                    wSelf.drawings.box.Size = Vector2.new(ww, 18)
                    wSelf.drawings.border.Position = Vector2.new(wx, wy)
                    wSelf.drawings.border.Size = Vector2.new(ww, 18)
                    wSelf.drawings.label.Position = Vector2.new(wx + ww / 2, wy + 2)
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.box.Visible = visible
                    wSelf.drawings.border.Visible = visible
                    wSelf.drawings.label.Visible = visible
                end
                
                widget.click = function(wSelf)
                    if wSelf and wSelf.callback then
                        pcall(wSelf.callback)
                    end
                end

                widget.addTooltip = function(wSelf, text)
                    wSelf.desc = text
                    print("adding tooltip " .. tostring(text) .. " to button " .. tostring(wSelf.label))
                    return wSelf
                end
                
                if sSelf and sSelf.widgets then
                    return sSelf.addWidget(widget)
                end
            end

            section.addSeparator = function(sSelf)
                local widget = {
                    type = "Separator",
                    drawings = {}
                }
                
                widget.drawings.line = Drawing.new("Line")
                widget.drawings.line.Visible = false
                widget.drawings.line.Thickness = 1
                widget.drawings.line.Color = Color3.fromRGB(35, 43, 51)
                widget.drawings.line.ZIndex = 103
                
                widget.position = function(wSelf, wx, wy, ww)
                    if wSelf then
                        wSelf.drawings.line.From = Vector2.new(wx, wy + 8)
                        wSelf.drawings.line.To = Vector2.new(wx + ww, wy + 8)
                    end
                end
                
                widget.show = function(wSelf, visible)
                    if wSelf and wSelf.drawings then
                        wSelf.drawings.line.Visible = visible
                    end
                end
                
                widget.click = function(wSelf)
                    if wSelf and wSelf.type then
                        local _ = wSelf.type
                    end
                end
                
                print("adding separator to section " .. tostring(sSelf.name))
                if sSelf and sSelf.widgets then
                    return sSelf.addWidget(widget)
                end
            end

            section.addText = function(sSelf, text)
                local widget = {
                    type = "Text",
                    text = text,
                    drawings = {}
                }
                
                widget.drawings.label = Drawing.new("Text")
                widget.drawings.label.Visible = false
                widget.drawings.label.Font = Drawing.Fonts.UI
                widget.drawings.label.Size = 12
                widget.drawings.label.Color = Color3.fromRGB(140, 130, 120)
                widget.drawings.label.Text = text
                widget.drawings.label.ZIndex = 103
                
                widget.position = function(wSelf, wx, wy, ww)
                    if wSelf and wSelf.drawings then
                        wSelf.drawings.label.Position = Vector2.new(wx, wy)
                    end
                end
                
                widget.show = function(wSelf, visible)
                    if wSelf and wSelf.drawings then
                        wSelf.drawings.label.Visible = visible
                    end
                end
                
                widget.click = function(wSelf)
                    if wSelf and wSelf.type then
                        local _ = wSelf.type
                    end
                end
                
                print("adding text " .. tostring(text) .. " to section " .. tostring(sSelf.name))
                if sSelf and sSelf.widgets then
                    return sSelf.addWidget(widget)
                end
            end

            section.addInput = function(sSelf, id, label, default, callback)
                print("adding input " .. tostring(id) .. " to section " .. tostring(sSelf.name))
                
                local widget = {
                    id = id,
                    type = "InputText",
                    label = label,
                    value = default or "",
                    callback = callback,
                    focused = false,
                    drawings = {}
                }
                
                widget.drawings.label = Drawing.new("Text")
                widget.drawings.label.Visible = false
                widget.drawings.label.Font = Drawing.Fonts.UI
                widget.drawings.label.Size = 12
                widget.drawings.label.Color = Color3.fromRGB(240, 230, 220)
                widget.drawings.label.Text = label
                widget.drawings.label.ZIndex = 103
                
                widget.drawings.box = Drawing.new("Square")
                widget.drawings.box.Visible = false
                widget.drawings.box.Filled = true
                widget.drawings.box.Color = Color3.fromRGB(40, 36, 33)
                widget.drawings.box.ZIndex = 103
                
                widget.drawings.border = Drawing.new("Square")
                widget.drawings.border.Visible = false
                widget.drawings.border.Filled = false
                widget.drawings.border.Color = Color3.fromRGB(45, 41, 38)
                widget.drawings.border.Thickness = 1
                widget.drawings.border.ZIndex = 104
                
                widget.drawings.valueText = Drawing.new("Text")
                widget.drawings.valueText.Visible = false
                widget.drawings.valueText.Font = Drawing.Fonts.UI
                widget.drawings.valueText.Size = 12
                widget.drawings.valueText.Color = Color3.fromRGB(240, 230, 220)
                widget.drawings.valueText.ZIndex = 105
                
                widget.position = function(wSelf, wx, wy, ww)
                    wSelf.drawings.label.Position = Vector2.new(wx, wy)
                    local boxWidth = 80
                    local boxX = wx + ww - boxWidth
                    wSelf.drawings.box.Position = Vector2.new(boxX, wy)
                    wSelf.drawings.box.Size = Vector2.new(boxWidth, 16)
                    wSelf.drawings.border.Position = Vector2.new(boxX, wy)
                    wSelf.drawings.border.Size = Vector2.new(boxWidth, 16)
                    wSelf.drawings.valueText.Position = Vector2.new(boxX + 5, wy + 1)
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.label.Visible = visible
                    wSelf.drawings.box.Visible = visible
                    wSelf.drawings.border.Visible = visible
                    wSelf.drawings.valueText.Visible = visible
                    wSelf.drawings.valueText.Text = wSelf.value .. (wSelf.focused and "|" or "")
                    wSelf.drawings.border.Color = wSelf.focused and Color3.fromRGB(191, 155, 95) or Color3.fromRGB(45, 41, 38)
                end
                
                widget.click = function(wSelf)
                    if wSelf then
                        wSelf.focused = true
                        local _ = wSelf.type
                    end
                end
                
                widget.key = function(wSelf, keyName, isShiftDown)
                    if keyName == "BackSpace" or keyName == "Backspace" then
                        wSelf.value = wSelf.value:sub(1, #wSelf.value - 1)
                    elseif keyName == "Return" or keyName == "Enter" then
                        wSelf.focused = false
                        if wSelf.callback then
                            pcall(wSelf.callback, wSelf.value)
                        end
                    elseif keyName == "Escape" then
                        wSelf.focused = false
                    else
                        local nameChar = keyCodeToChar({Name = keyName}, isShiftDown)
                        if nameChar then
                            wSelf.value = wSelf.value .. nameChar
                        end
                    end
                end

                widget.addTooltip = function(wSelf, text)
                    wSelf.desc = text
                    print("adding tooltip " .. tostring(text) .. " to input " .. tostring(wSelf.label))
                    return wSelf
                end
                
                if sSelf and sSelf.widgets then
                    return sSelf.addWidget(widget)
                end
            end

            if section.name then
                return section
            end
        end

        table.insert(wSelf.tabs, tab)
        if tab.name then
            return tab
        end
    end

    self.render = function()
        local x = self.x
        local y = self.y
        local w = self.width
        local h = self.height
        local visible = self.visible
        
        self.drawings.bg.Position = Vector2.new(x, y)
        self.drawings.bg.Size = Vector2.new(w, h)
        self.drawings.bg.Visible = visible
        
        self.drawings.border.Position = Vector2.new(x, y)
        self.drawings.border.Size = Vector2.new(w, h)
        self.drawings.border.Visible = visible
        
        self.drawings.header.Position = Vector2.new(x, y)
        self.drawings.header.Size = Vector2.new(w, 25)
        self.drawings.header.Visible = visible
        
        self.drawings.logoText.Position = Vector2.new(x + 10, y + 6)
        self.drawings.logoText.Visible = visible
        
        self.drawings.titleText.Position = Vector2.new(x + 60, y + 6)
        self.drawings.titleText.Visible = visible
        
        self.drawings.footer.Position = Vector2.new(x, y + h - 20)
        self.drawings.footer.Size = Vector2.new(w, 20)
        self.drawings.footer.Visible = visible
        
        self.drawings.footerText.Position = Vector2.new(x + w / 2, y + h - 16)
        self.drawings.footerText.Visible = visible
        
        local tabX = x + 10
        local tabY = y + 30
        for i, tab in ipairs(self.tabs) do
            local isActive = (i == self.activeTab)
            tab.drawings.bg.Visible = visible and isActive
            if isActive and isActive == true then
                tab.drawings.bg.Position = Vector2.new(tabX + (i-1) * 60 - 5, tabY - 2)
                tab.drawings.bg.Size = Vector2.new(50, 18)
                tab.drawings.button.Color = Color3.fromRGB(191, 155, 95)
            else
                tab.drawings.button.Color = Color3.fromRGB(140, 130, 120)
            end
            tab.drawings.button.Position = Vector2.new(tabX + (i-1) * 60 + 20, tabY)
            tab.drawings.button.Visible = visible
        end
        
        local contentY = y + 55
        local leftY = contentY
        local rightY = contentY
        local columnWidth = w / 2 - 15
        
        local activeTabObj = self.tabs[self.activeTab]
        if activeTabObj and activeTabObj.sections then
            for _, sec in ipairs(activeTabObj.sections) do
                local secX = sec.column == "Left" and (x + 10) or (x + w / 2 + 5)
                local secY = sec.column == "Left" and leftY or rightY
                local secHeight = 25 + #sec.widgets * 25
                
                sec.drawings.border.Position = Vector2.new(secX, secY)
                sec.drawings.border.Size = Vector2.new(columnWidth, secHeight)
                sec.drawings.border.Visible = visible
                
                sec.drawings.titleBg.Position = Vector2.new(secX + 8, secY - 6)
                sec.drawings.titleBg.Size = Vector2.new(sec.drawings.titleText.TextBounds.X + 8, 12)
                sec.drawings.titleBg.Visible = visible
                
                sec.drawings.titleText.Position = Vector2.new(secX + 12, secY - 6)
                sec.drawings.titleText.Visible = visible
                
                local widgetY = secY + 15
                for _, widget in ipairs(sec.widgets) do
                    widget:position(secX + 10, widgetY, columnWidth - 20)
                    widget:show(visible)
                    widgetY = widgetY + 25
                end
                
                if sec.column == "Left" then
                    leftY = leftY + secHeight + 15
                else
                    rightY = rightY + secHeight + 15
                end
            end
        end
    end

    self.inputBeganConnection = game:GetService("UserInputService").InputBegan:Connect(function(input)
        if input.KeyCode then
            if tostring(input.KeyCode):find("%.P$") then
                self.visible = not self.visible
                self:render()
                return
            end
        end

        if not self.visible then return end
        
        local mouseX = game:GetService("Players").LocalPlayer:GetMouse().X
        local mouseY = game:GetService("Players").LocalPlayer:GetMouse().Y
        
        if tostring(input.UserInputType):find("MouseButton1") then
            if mouseX >= self.x and mouseX <= self.x + self.width and mouseY >= self.y and mouseY <= self.y + 25 then
                self.dragging = true
                self.dragOffset = Vector2.new(mouseX - self.x, mouseY - self.y)
            end
            
            local tabX = self.x + 10
            local tabY = self.y + 30
            for i, tab in ipairs(self.tabs) do
                if mouseX >= tabX + (i-1)*60 - 5 and mouseX <= tabX + (i-1)*60 + 45 and mouseY >= tabY - 2 and mouseY <= tabY + 16 then
                    self.activeTab = i
                    self:render()
                end
            end
            
            local activeTabObj = self.tabs[self.activeTab]
            if activeTabObj and activeTabObj.sections then
                for _, sec in ipairs(activeTabObj.sections) do
                    for _, widget in ipairs(sec.widgets) do
                        if widget.type == "Toggle" then
                            local box = widget.drawings.box
                            if mouseX >= box.Position.X - 5 and mouseX <= box.Position.X + box.Size.X + 5 and mouseY >= box.Position.Y - 5 and mouseY <= box.Position.Y + box.Size.Y + 5 then
                                widget:click()
                                self:render()
                            end
                        elseif widget.type == "Slider" then
                            local track = widget.drawings.track
                            local trackWidth = 80
                            local trackX = track.From.X
                            if mouseX >= trackX - 5 and mouseX <= trackX + trackWidth + 5 and mouseY >= track.From.Y - 10 and mouseY <= track.From.Y + 10 then
                                widget:click(mouseX, trackWidth, trackX)
                                self:render()
                            end
                        elseif widget.type == "Button" then
                            local box = widget.drawings.box
                            if mouseX >= box.Position.X and mouseX <= box.Position.X + box.Size.X and mouseY >= box.Position.Y and mouseY <= box.Position.Y + box.Size.Y then
                                widget:click()
                                self:render()
                            end
                        elseif widget.type == "InputText" then
                            local box = widget.drawings.box
                            if mouseX >= box.Position.X and mouseX <= box.Position.X + box.Size.X and mouseY >= box.Position.Y and mouseY <= box.Position.Y + box.Size.Y then
                                widget:click()
                                self:render()
                            else
                                widget.focused = false
                                self:render()
                            end
                        end
                    end
                end
            end
        elseif input.KeyCode then
            local activeTabObj = self.tabs[self.activeTab]
            if activeTabObj and activeTabObj.sections then
                for _, sec in ipairs(activeTabObj.sections) do
                    for _, widget in ipairs(sec.widgets) do
                        if widget.type == "InputText" and widget.focused then
                            local shift = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) or game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.RightShift)
                            if shift or not shift then
                                widget:key(input.KeyCode.Name, shift)
                                self:render()
                            end
                        end
                    end
                end
            end
        end
    end)

    self.inputEndedConnection = game:GetService("UserInputService").InputEnded:Connect(function(input)
        if tostring(input.UserInputType):find("MouseButton1") then
            self.dragging = false
        end
    end)

    task.spawn(function()
        while self.visible ~= nil do
            task.wait()
            if self.visible and self.dragging then
                self.x = game:GetService("Players").LocalPlayer:GetMouse().X - self.dragOffset.X
                self.y = game:GetService("Players").LocalPlayer:GetMouse().Y - self.dragOffset.Y
                self:render()
            end
            
            if self.visible then
                local mouseX = game:GetService("Players").LocalPlayer:GetMouse().X
                local mouseY = game:GetService("Players").LocalPlayer:GetMouse().Y
                local hovered = false
                local activeTabObj = self.tabs[self.activeTab]
                if activeTabObj and activeTabObj.sections then
                    for _, sec in ipairs(activeTabObj.sections) do
                        for _, widget in ipairs(sec.widgets) do
                            if widget.desc then
                                local label = widget.drawings.label
                                if label and mouseX >= label.Position.X and mouseX <= label.Position.X + 120 and mouseY >= label.Position.Y and mouseY <= label.Position.Y + 12 then
                                    self.drawings.tooltipText.Text = widget.desc
                                    self.drawings.tooltipText.Position = Vector2.new(mouseX + 12, mouseY + 12)
                                    self.drawings.tooltipBg.Position = Vector2.new(mouseX + 8, mouseY + 8)
                                    self.drawings.tooltipBg.Size = Vector2.new(self.drawings.tooltipText.TextBounds.X + 8, 16)
                                    self.drawings.tooltipText.Visible = true
                                    self.drawings.tooltipBg.Visible = true
                                    hovered = true
                                    break
                                end
                            end
                        end
                        if hovered then break end
                    end
                end
                if not hovered then
                    self.drawings.tooltipText.Visible = false
                    self.drawings.tooltipBg.Visible = false
                end
            end
        end
    end)

    self.remove = function(wSelf)
        pcall(function()
            if wSelf.inputBeganConnection then wSelf.inputBeganConnection:Disconnect() end
            if wSelf.inputEndedConnection then wSelf.inputEndedConnection:Disconnect() end
            for _, drawing in pairs(wSelf.drawings) do
                if drawing then
                    drawing:Remove()
                end
            end
            for _, tab in ipairs(wSelf.tabs) do
                for _, drawing in pairs(tab.drawings) do
                    if drawing then
                        drawing:Remove()
                    end
                end
                for _, sec in ipairs(tab.sections) do
                    for _, widget in ipairs(sec.widgets) do
                        for _, drawing in pairs(widget.drawings) do
                            if drawing then
                                drawing:Remove()
                            end
                        end
                    end
                    for _, drawing in pairs(sec.drawings) do
                        if drawing then
                            drawing:Remove()
                        end
                    end
                end
            end
        end)
    end

    if self.title then
        return self
    end
end

_G.sickUi = sickUi
return sickUi
