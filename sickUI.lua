local sickUi = {}

local function keyCodeToChar(keyCode, isShiftDown)
    local name = (type(keyCode) == "table" and keyCode.Name) or (type(keyCode) == "string" and keyCode)
    if type(name) ~= "string" then
        return nil
    end
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
    print("making window " .. tostring(title))
    
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

    local function isPointInRect(px, py, rx, ry, rw, rh)
        return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
    end

    local function handleMouseClick(mouseX, mouseY)
        if mouseX >= self.x + self.width - 20 and mouseX <= self.x + self.width - 5 and mouseY >= self.y + 4 and mouseY <= self.y + 18 then
            self.visible = false
            self:render()
            return
        end

        if mouseX >= self.x and mouseX <= self.x + self.width and mouseY >= self.y and mouseY <= self.y + 25 then
            self.dragging = true
            self.dragOffset = Vector2.new(mouseX - self.x, mouseY - self.y)
            return
        end

        local tabOffset = 0
        for i, tab in ipairs(self.tabs) do
            if isPointInRect(mouseX, mouseY, self.x + 10 + tabOffset - 5, self.y + 28, tab.drawings.button.TextBounds.X + 20, 18) then
                self.activeTab = i
                self:render()
                return
            end
            tabOffset = tabOffset + tab.drawings.button.TextBounds.X + 20
        end

        if self.tabs[self.activeTab] and self.tabs[self.activeTab].sections then
            for _, sec in ipairs(self.tabs[self.activeTab].sections) do
                for _, widget in ipairs(sec.widgets) do
                    if widget.type == "Toggle" then
                        if mouseX >= math.min(widget.drawings.bg.Position.X - 5, widget.drawings.label.Position.X) and mouseX <= math.max(widget.drawings.bg.Position.X + widget.drawings.bg.Size.X + 5, widget.drawings.label.Position.X + widget.drawings.label.TextBounds.X) and mouseY >= widget.drawings.label.Position.Y - 2 and mouseY <= widget.drawings.label.Position.Y + 16 then
                            widget:click()
                            self:render()
                            return
                        end
                    elseif widget.type == "Slider" then
                        if isPointInRect(mouseX, mouseY, widget.lastTrackX - 5, widget.drawings.track.From.Y - 10, 90, 20) then
                            self.activeSlider = widget
                            widget:click(mouseX)
                            self:render()
                            return
                        end
                    elseif widget.type == "Button" then
                        if isPointInRect(mouseX, mouseY, widget.drawings.box.Position.X - 2, widget.drawings.box.Position.Y - 2, widget.drawings.box.Size.X + 4, widget.drawings.box.Size.Y + 4) then
                            widget:click()
                            self:render()
                            return
                        end
                    elseif widget.type == "InputText" then
                        if isPointInRect(mouseX, mouseY, widget.drawings.box.Position.X - 2, widget.drawings.box.Position.Y - 2, widget.drawings.box.Size.X + 4, widget.drawings.box.Size.Y + 4) then
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
    end

    self.drawings.bg = Drawing.new("Square")
    self.drawings.bg.Visible = false
    self.drawings.bg.Filled = true
    self.drawings.bg.Color = Color3.fromRGB(12, 17, 14)
    self.drawings.bg.ZIndex = 100

    self.drawings.border = Drawing.new("Square")
    self.drawings.border.Visible = false
    self.drawings.border.Filled = false
    self.drawings.border.Color = Color3.fromRGB(56, 94, 71)
    self.drawings.border.Thickness = 1.5
    self.drawings.border.ZIndex = 101

    self.drawings.header = Drawing.new("Square")
    self.drawings.header.Visible = false
    self.drawings.header.Filled = true
    self.drawings.header.Color = Color3.fromRGB(8, 12, 10)
    self.drawings.header.ZIndex = 101

    self.drawings.titleText = Drawing.new("Text")
    self.drawings.titleText.Visible = false
    self.drawings.titleText.Font = Drawing.Fonts.UI
    self.drawings.titleText.Size = 13
    self.drawings.titleText.Color = Color3.fromRGB(230, 240, 232)
    self.drawings.titleText.Text = title
    self.drawings.titleText.ZIndex = 102

    self.drawings.logoText = Drawing.new("Text")
    self.drawings.logoText.Visible = false
    self.drawings.logoText.Font = Drawing.Fonts.UI
    self.drawings.logoText.Size = 13
    self.drawings.logoText.Color = Color3.fromRGB(88, 196, 120)
    self.drawings.logoText.Text = "matcha"
    self.drawings.logoText.ZIndex = 102

    self.drawings.closeText = Drawing.new("Text")
    self.drawings.closeText.Visible = false
    self.drawings.closeText.Font = Drawing.Fonts.UI
    self.drawings.closeText.Size = 13
    self.drawings.closeText.Color = Color3.fromRGB(140, 160, 145)
    self.drawings.closeText.Text = "x"
    self.drawings.closeText.ZIndex = 102

    self.drawings.footer = Drawing.new("Square")
    self.drawings.footer.Visible = false
    self.drawings.footer.Filled = true
    self.drawings.footer.Color = Color3.fromRGB(8, 12, 10)
    self.drawings.footer.ZIndex = 101

    self.drawings.footerText = Drawing.new("Text")
    self.drawings.footerText.Visible = false
    self.drawings.footerText.Font = Drawing.Fonts.UI
    self.drawings.footerText.Size = 11
    self.drawings.footerText.Color = Color3.fromRGB(88, 150, 108)
    self.drawings.footerText.Text = "matcha.pink/discord"
    self.drawings.footerText.Center = true
    self.drawings.footerText.ZIndex = 102

    self.drawings.tooltipBg = Drawing.new("Square")
    self.drawings.tooltipBg.Visible = false
    self.drawings.tooltipBg.Filled = true
    self.drawings.tooltipBg.Color = Color3.fromRGB(8, 12, 10)
    self.drawings.tooltipBg.ZIndex = 1000

    self.drawings.tooltipBorder = Drawing.new("Square")
    self.drawings.tooltipBorder.Visible = false
    self.drawings.tooltipBorder.Filled = false
    self.drawings.tooltipBorder.Color = Color3.fromRGB(56, 94, 71)
    self.drawings.tooltipBorder.Thickness = 1
    self.drawings.tooltipBorder.ZIndex = 1001

    self.drawings.tooltipText = Drawing.new("Text")
    self.drawings.tooltipText.Visible = false
    self.drawings.tooltipText.Font = Drawing.Fonts.UI
    self.drawings.tooltipText.Size = 11
    self.drawings.tooltipText.Color = Color3.fromRGB(230, 240, 232)
    self.drawings.tooltipText.ZIndex = 1002

    self.addTab = function(wSelf, name)
        local tab = {
            name = name,
            sections = {}
        }
        
        tab.drawings = {}
        tab.drawings.button = Drawing.new("Text")
        tab.drawings.button.Visible = false
        tab.drawings.button.Font = Drawing.Fonts.UI
        tab.drawings.button.Size = 12
        tab.drawings.button.Center = true
        tab.drawings.button.Text = name
        tab.drawings.button.ZIndex = 103

        tab.drawings.underline = Drawing.new("Line")
        tab.drawings.underline.Visible = false
        tab.drawings.underline.Thickness = 2
        tab.drawings.underline.Color = Color3.fromRGB(88, 196, 120)
        tab.drawings.underline.ZIndex = 103

        tab.addSection = function(tSelf, secName, column)
            local section = {
                name = secName,
                column = column,
                widgets = {},
                drawings = {}
            }
            
            section.drawings.bg = Drawing.new("Square")
            section.drawings.bg.Visible = false
            section.drawings.bg.Filled = true
            section.drawings.bg.Color = Color3.fromRGB(16, 23, 19)
            section.drawings.bg.ZIndex = 101

            section.drawings.border = Drawing.new("Square")
            section.drawings.border.Visible = false
            section.drawings.border.Filled = false
            section.drawings.border.Color = Color3.fromRGB(36, 51, 41)
            section.drawings.border.Thickness = 1
            section.drawings.border.ZIndex = 102
            
            section.drawings.titleBg = Drawing.new("Square")
            section.drawings.titleBg.Visible = false
            section.drawings.titleBg.Filled = true
            section.drawings.titleBg.Color = Color3.fromRGB(12, 17, 14)
            section.drawings.titleBg.ZIndex = 103
            
            section.drawings.titleText = Drawing.new("Text")
            section.drawings.titleText.Visible = false
            section.drawings.titleText.Font = Drawing.Fonts.UI
            section.drawings.titleText.Size = 12
            section.drawings.titleText.Color = Color3.fromRGB(88, 196, 120)
            section.drawings.titleText.Text = secName
            section.drawings.titleText.ZIndex = 104
            
            table.insert(tSelf.sections, section)
            
            section.addToggle = function(sSelf, id, label, default, callback)
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
                widget.drawings.label.Color = Color3.fromRGB(230, 240, 232)
                widget.drawings.label.Text = label
                widget.drawings.label.ZIndex = 103
                
                widget.drawings.bg = Drawing.new("Square")
                widget.drawings.bg.Visible = false
                widget.drawings.bg.Filled = true
                widget.drawings.bg.Size = Vector2.new(18, 8)
                widget.drawings.bg.ZIndex = 103
                
                widget.drawings.knob = Drawing.new("Circle")
                widget.drawings.knob.Visible = false
                widget.drawings.knob.Filled = true
                widget.drawings.knob.Radius = 5
                widget.drawings.knob.Color = Color3.fromRGB(255, 255, 255)
                widget.drawings.knob.NumSides = 12
                widget.drawings.knob.ZIndex = 104

                widget.position = function(wSelf, wx, wy, ww)
                    wSelf.drawings.label.Position = Vector2.new(wx, wy)
                    wSelf.drawings.bg.Position = Vector2.new(wx + ww - 20, wy + 3)
                    if wSelf.value then
                        wSelf.drawings.knob.Position = Vector2.new(wx + ww - 20 + 13, wy + 7)
                    else
                        wSelf.drawings.knob.Position = Vector2.new(wx + ww - 20 + 5, wy + 7)
                    end
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.label.Visible = visible
                    wSelf.drawings.bg.Visible = visible
                    wSelf.drawings.knob.Visible = visible
                    if wSelf.value then
                        wSelf.drawings.bg.Color = Color3.fromRGB(88, 196, 120)
                    else
                        wSelf.drawings.bg.Color = Color3.fromRGB(40, 56, 46)
                    end
                end
                
                widget.click = function(wSelf)
                    wSelf.value = not wSelf.value
                    if wSelf.callback then
                        pcall(wSelf.callback, wSelf.value)
                    end
                end

                widget.addTooltip = function(wSelf, text)
                    wSelf.desc = text
                    return wSelf
                end
                
                table.insert(sSelf.widgets, widget)
                return widget
            end

            section.addSlider = function(sSelf, id, label, min, max, default, callback)
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
                widget.drawings.label.Color = Color3.fromRGB(230, 240, 232)
                widget.drawings.label.ZIndex = 103
                
                widget.drawings.track = Drawing.new("Line")
                widget.drawings.track.Visible = false
                widget.drawings.track.Thickness = 3
                widget.drawings.track.Color = Color3.fromRGB(40, 56, 46)
                widget.drawings.track.ZIndex = 103
                
                widget.drawings.fill = Drawing.new("Line")
                widget.drawings.fill.Visible = false
                widget.drawings.fill.Thickness = 3
                widget.drawings.fill.Color = Color3.fromRGB(88, 196, 120)
                widget.drawings.fill.ZIndex = 104
                
                widget.drawings.knob = Drawing.new("Circle")
                widget.drawings.knob.Visible = false
                widget.drawings.knob.Filled = true
                widget.drawings.knob.Radius = 4
                widget.drawings.knob.Color = Color3.fromRGB(255, 255, 255)
                widget.drawings.knob.NumSides = 12
                widget.drawings.knob.ZIndex = 105
                
                widget.position = function(wSelf, wx, wy, ww)
                    wSelf.drawings.label.Position = Vector2.new(wx, wy)
                    wSelf.lastTrackX = wx + ww - 80
                    wSelf.drawings.track.From = Vector2.new(wx + ww - 80, wy + 6)
                    wSelf.drawings.track.To = Vector2.new(wx + ww, wy + 6)
                    wSelf.drawings.fill.From = Vector2.new(wx + ww - 80, wy + 6)
                    wSelf.drawings.fill.To = Vector2.new(wx + ww - 80 + 80 * ((wSelf.value - wSelf.min) / (wSelf.max - wSelf.min)), wy + 6)
                    wSelf.drawings.knob.Position = Vector2.new(wx + ww - 80 + 80 * ((wSelf.value - wSelf.min) / (wSelf.max - wSelf.min)), wy + 6)
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.label.Visible = visible
                    wSelf.drawings.track.Visible = visible
                    wSelf.drawings.fill.Visible = visible
                    wSelf.drawings.knob.Visible = visible
                    wSelf.drawings.label.Text = wSelf.label .. " (" .. string.format("%.2f", wSelf.value) .. ")"
                end
                
                widget.click = function(wSelf, mouseX)
                    wSelf.value = wSelf.min + math.clamp((mouseX - wSelf.lastTrackX) / 80, 0, 1) * (wSelf.max - wSelf.min)
                    if wSelf.callback then
                        pcall(wSelf.callback, wSelf.value)
                    end
                end

                widget.addTooltip = function(wSelf, text)
                    wSelf.desc = text
                    return wSelf
                end
                
                table.insert(sSelf.widgets, widget)
                return widget
            end

            section.addButton = function(sSelf, btnLabel, callback)
                local widget = {
                    type = "Button",
                    label = btnLabel,
                    callback = callback,
                    drawings = {}
                }
                
                widget.drawings.box = Drawing.new("Square")
                widget.drawings.box.Visible = false
                widget.drawings.box.Filled = true
                widget.drawings.box.Color = Color3.fromRGB(36, 51, 41)
                widget.drawings.box.ZIndex = 103
                
                widget.drawings.border = Drawing.new("Square")
                widget.drawings.border.Visible = false
                widget.drawings.border.Filled = false
                widget.drawings.border.Color = Color3.fromRGB(56, 94, 71)
                widget.drawings.border.Thickness = 1
                widget.drawings.border.ZIndex = 104
                
                widget.drawings.label = Drawing.new("Text")
                widget.drawings.label.Visible = false
                widget.drawings.label.Font = Drawing.Fonts.UI
                widget.drawings.label.Size = 12
                widget.drawings.label.Color = Color3.fromRGB(230, 240, 232)
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
                    if wSelf.callback then
                        pcall(wSelf.callback)
                    end
                end

                widget.addTooltip = function(wSelf, text)
                    wSelf.desc = text
                    return wSelf
                end
                
                table.insert(sSelf.widgets, widget)
                return widget
            end

            section.addSeparator = function(sSelf)
                local widget = {
                    type = "Separator",
                    drawings = {}
                }
                
                widget.drawings.line = Drawing.new("Line")
                widget.drawings.line.Visible = false
                widget.drawings.line.Thickness = 1
                widget.drawings.line.Color = Color3.fromRGB(28, 40, 32)
                widget.drawings.line.ZIndex = 103
                
                widget.position = function(wSelf, wx, wy, ww)
                    wSelf.drawings.line.From = Vector2.new(wx, wy + 8)
                    wSelf.drawings.line.To = Vector2.new(wx + ww, wy + 8)
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.line.Visible = visible
                end
                
                widget.click = function() end
                
                table.insert(sSelf.widgets, widget)
                return widget
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
                widget.drawings.label.Color = Color3.fromRGB(140, 160, 145)
                widget.drawings.label.Text = text
                widget.drawings.label.ZIndex = 103
                
                widget.position = function(wSelf, wx, wy, ww)
                    wSelf.drawings.label.Position = Vector2.new(wx, wy)
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.label.Visible = visible
                end
                
                widget.click = function() end
                
                table.insert(sSelf.widgets, widget)
                return widget
            end

            section.addInput = function(sSelf, id, label, default, callback)
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
                widget.drawings.label.Color = Color3.fromRGB(230, 240, 232)
                widget.drawings.label.Text = label
                widget.drawings.label.ZIndex = 103
                
                widget.drawings.box = Drawing.new("Square")
                widget.drawings.box.Visible = false
                widget.drawings.box.Filled = true
                widget.drawings.box.Color = Color3.fromRGB(20, 28, 23)
                widget.drawings.box.ZIndex = 103
                
                widget.drawings.border = Drawing.new("Square")
                widget.drawings.border.Visible = false
                widget.drawings.border.Filled = false
                widget.drawings.border.Color = Color3.fromRGB(36, 51, 41)
                widget.drawings.border.Thickness = 1
                widget.drawings.border.ZIndex = 104
                
                widget.drawings.valueText = Drawing.new("Text")
                widget.drawings.valueText.Visible = false
                widget.drawings.valueText.Font = Drawing.Fonts.UI
                widget.drawings.valueText.Size = 12
                widget.drawings.valueText.Color = Color3.fromRGB(230, 240, 232)
                widget.drawings.valueText.ZIndex = 105
                
                widget.position = function(wSelf, wx, wy, ww)
                    wSelf.drawings.label.Position = Vector2.new(wx, wy)
                    wSelf.drawings.box.Position = Vector2.new(wx + ww - 80, wy)
                    wSelf.drawings.box.Size = Vector2.new(80, 16)
                    wSelf.drawings.border.Position = Vector2.new(wx + ww - 80, wy)
                    wSelf.drawings.border.Size = Vector2.new(80, 16)
                    wSelf.drawings.valueText.Position = Vector2.new(wx + ww - 75, wy + 1)
                end
                
                widget.show = function(wSelf, visible)
                    wSelf.drawings.label.Visible = visible
                    wSelf.drawings.box.Visible = visible
                    wSelf.drawings.border.Visible = visible
                    wSelf.drawings.valueText.Visible = visible
                    if wSelf.focused then
                        if tick() % 1 < 0.5 then
                            wSelf.drawings.valueText.Text = wSelf.value .. "|"
                        else
                            wSelf.drawings.valueText.Text = wSelf.value
                        end
                        wSelf.drawings.border.Color = Color3.fromRGB(88, 196, 120)
                    else
                        wSelf.drawings.valueText.Text = wSelf.value
                        wSelf.drawings.border.Color = Color3.fromRGB(36, 51, 41)
                    end
                end
                
                widget.click = function(wSelf)
                    wSelf.focused = true
                end
                
                widget.key = function(wSelf, keyName, isShiftDown)
                    if type(keyName) ~= "string" then
                        return
                    end
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
                        local nameChar = keyCodeToChar(keyName, isShiftDown)
                        if nameChar then
                            wSelf.value = wSelf.value .. nameChar
                        end
                    end
                end

                widget.addTooltip = function(wSelf, text)
                    wSelf.desc = text
                    return wSelf
                end
                
                table.insert(sSelf.widgets, widget)
                return widget
            end

            return section
        end

        table.insert(wSelf.tabs, tab)
        return tab
    end

    self.render = function()
        self.drawings.bg.Position = Vector2.new(self.x, self.y)
        self.drawings.bg.Size = Vector2.new(self.width, self.height)
        self.drawings.bg.Visible = self.visible
        
        self.drawings.border.Position = Vector2.new(self.x, self.y)
        self.drawings.border.Size = Vector2.new(self.width, self.height)
        self.drawings.border.Visible = self.visible
        
        self.drawings.header.Position = Vector2.new(self.x, self.y)
        self.drawings.header.Size = Vector2.new(self.width, 25)
        self.drawings.header.Visible = self.visible
        
        self.drawings.logoText.Position = Vector2.new(self.x + 10, self.y + 6)
        self.drawings.logoText.Visible = self.visible
        
        self.drawings.titleText.Position = Vector2.new(self.x + 60, self.y + 6)
        self.drawings.titleText.Visible = self.visible

        self.drawings.closeText.Position = Vector2.new(self.x + self.width - 16, self.y + 6)
        self.drawings.closeText.Visible = self.visible
        
        self.drawings.footer.Position = Vector2.new(self.x, self.y + self.height - 18)
        self.drawings.footer.Size = Vector2.new(self.width, 18)
        self.drawings.footer.Visible = self.visible
        
        self.drawings.footerText.Position = Vector2.new(self.x + self.width / 2, self.y + self.height - 15)
        self.drawings.footerText.Visible = self.visible
        
        local tabX = self.x + 10
        local tabOffset = 0
        for i, tab in ipairs(self.tabs) do
            local tabWidth = tab.drawings.button.TextBounds.X + 20
            local isActive = (i == self.activeTab)
            tab.drawings.underline.Visible = self.visible and isActive
            if isActive then
                tab.drawings.underline.From = Vector2.new(tabX + tabOffset, self.y + 46)
                tab.drawings.underline.To = Vector2.new(tabX + tabOffset + tabWidth - 10, self.y + 46)
                tab.drawings.button.Color = Color3.fromRGB(88, 196, 120)
            else
                tab.drawings.button.Color = Color3.fromRGB(120, 140, 125)
            end
            tab.drawings.button.Position = Vector2.new(tabX + tabOffset + tabWidth / 2 - 5, self.y + 30)
            tab.drawings.button.Visible = self.visible
            tabOffset = tabOffset + tabWidth
        end
        
        local leftY = self.y + 55
        local rightY = self.y + 55
        local columnWidth = self.width / 2 - 15
        
        if self.tabs[self.activeTab] and self.tabs[self.activeTab].sections then
            for _, sec in ipairs(self.tabs[self.activeTab].sections) do
                local secX = sec.column == "Left" and (self.x + 10) or (self.x + self.width / 2 + 5)
                local secY = sec.column == "Left" and leftY or rightY
                local secHeight = 25 + #sec.widgets * 25
                
                sec.drawings.bg.Position = Vector2.new(secX, secY)
                sec.drawings.bg.Size = Vector2.new(columnWidth, secHeight)
                sec.drawings.bg.Visible = self.visible
                
                sec.drawings.border.Position = Vector2.new(secX, secY)
                sec.drawings.border.Size = Vector2.new(columnWidth, secHeight)
                sec.drawings.border.Visible = self.visible
                
                sec.drawings.titleBg.Position = Vector2.new(secX + 8, secY - 6)
                sec.drawings.titleBg.Size = Vector2.new(sec.drawings.titleText.TextBounds.X + 8, 12)
                sec.drawings.titleBg.Visible = self.visible
                
                sec.drawings.titleText.Position = Vector2.new(secX + 12, secY - 6)
                sec.drawings.titleText.Visible = self.visible
                
                local widgetY = secY + 15
                for _, widget in ipairs(sec.widgets) do
                    widget:position(secX + 10, widgetY, columnWidth - 20)
                    widget:show(self.visible)
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
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.P then
                self.visible = not self.visible
                self:render()
                return
            end
            if self.visible then
                if self.tabs[self.activeTab] and self.tabs[self.activeTab].sections then
                    for _, sec in ipairs(self.tabs[self.activeTab].sections) do
                        for _, widget in ipairs(sec.widgets) do
                            if widget.type == "InputText" and widget.focused then
                                widget:key(input.KeyCode.Name, game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift) or game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.RightShift))
                                self:render()
                            end
                        end
                    end
                end
            end
        elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
            if self.visible then
                local mouse = game:GetService("Players").LocalPlayer:GetMouse()
                handleMouseClick(mouse.X, mouse.Y)
            end
        end
    end)

    self.inputEndedConnection = game:GetService("UserInputService").InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self.dragging = false
            self.activeSlider = nil
        end
    end)

    task.spawn(function()
        while self.visible ~= nil do
            task.wait()
            if self.visible then
                if not ismouse1pressed() then
                    self.dragging = false
                    self.activeSlider = nil
                end
                local mouse = game:GetService("Players").LocalPlayer:GetMouse()
                if self.dragging then
                    self.x = mouse.X - self.dragOffset.X
                    self.y = mouse.Y - self.dragOffset.Y
                    self:render()
                elseif self.activeSlider then
                    local val = self.activeSlider.min + math.clamp((mouse.X - self.activeSlider.lastTrackX) / 80, 0, 1) * (self.activeSlider.max - self.activeSlider.min)
                    self.activeSlider.value = val
                    pcall(self.activeSlider.callback, val)
                    self:render()
                end
                
                local hovered = false
                if self.tabs[self.activeTab] and self.tabs[self.activeTab].sections then
                    for _, sec in ipairs(self.tabs[self.activeTab].sections) do
                        for _, widget in ipairs(sec.widgets) do
                            if widget.desc and widget.drawings.label and widget.drawings.label.Visible then
                                if mouse.X >= widget.drawings.label.Position.X and mouse.X <= widget.drawings.label.Position.X + 120 and mouse.Y >= widget.drawings.label.Position.Y and mouse.Y <= widget.drawings.label.Position.Y + 14 then
                                    self.drawings.tooltipText.Text = widget.desc
                                    self.drawings.tooltipText.Position = Vector2.new(mouse.X + 12, mouse.Y + 12)
                                    self.drawings.tooltipBg.Position = Vector2.new(mouse.X + 8, mouse.Y + 8)
                                    self.drawings.tooltipBg.Size = Vector2.new(self.drawings.tooltipText.TextBounds.X + 8, 16)
                                    self.drawings.tooltipBorder.Position = Vector2.new(mouse.X + 8, mouse.Y + 8)
                                    self.drawings.tooltipBorder.Size = Vector2.new(self.drawings.tooltipText.TextBounds.X + 8, 16)
                                    self.drawings.tooltipText.Visible = true
                                    self.drawings.tooltipBg.Visible = true
                                    self.drawings.tooltipBorder.Visible = true
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
                    self.drawings.tooltipBorder.Visible = false
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

    return self
end

_G.sickUi = sickUi
return sickUi
