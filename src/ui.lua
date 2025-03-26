-- ui.lua - User interface elements for the game

local UI = {}

-- Button class
local Button = {}
Button.__index = Button

-- Create a new button
function Button.new(x, y, width, height, text, action, color)
    local self = setmetatable({}, Button)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.text = text
    self.action = action
    self.color = color or {0.3, 0.3, 0.8, 0.8} -- Default blue color
    self.hoverColor = {self.color[1] * 1.2, self.color[2] * 1.2, self.color[3] * 1.2, self.color[4]}
    self.isHovered = false
    return self
end

-- Check if a point is inside the button
function Button:isPointInside(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
end

-- Draw the button
function Button:draw()
    -- Draw button background
    if self.isHovered then
        love.graphics.setColor(self.hoverColor)
    else
        love.graphics.setColor(self.color)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 5, 5) -- Rounded corners
    
    -- Draw button border
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 5, 5)
    
    -- Draw button text
    love.graphics.setColor(1, 1, 1, 1)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(self.text)
    local textHeight = font:getHeight()
    love.graphics.print(self.text, 
        self.x + (self.width - textWidth) / 2, 
        self.y + (self.height - textHeight) / 2)
end

-- Update button state (check for hover)
function Button:update(mouseX, mouseY)
    self.isHovered = self:isPointInside(mouseX, mouseY)
end

-- Handle mouse press
function Button:handlePress(x, y)
    if self:isPointInside(x, y) then
        self.action()
        return true
    end
    return false
end

-- UI Manager
local buttons = {}
local isUIVisible = false
local toggleUIButton = nil

-- Initialize the UI
function UI.init(ballTypes)
    -- Create toggle UI button (always visible)
    toggleUIButton = Button.new(10, 10, 100, 30, "Toggle UI", function()
        isUIVisible = not isUIVisible
    end, {0.5, 0.5, 0.5, 0.8})
    
    -- Create difficulty buttons
    local difficultyColors = {
        {0.0, 0.8, 0.0, 0.8}, -- Easy (Green)
        {0.8, 0.8, 0.0, 0.8}, -- Medium (Yellow)
        {0.8, 0.4, 0.0, 0.8}, -- Hard (Orange)
        {0.8, 0.0, 0.0, 0.8}, -- Expert (Red)
        {0.5, 0.0, 0.5, 0.8}  -- Insane (Purple)
    }
    
    local difficultyNames = {"Easy", "Medium", "Hard", "Expert", "Insane"}
    
    -- Create difficulty buttons
    for i = 1, 5 do
        local button = Button.new(120 + (i-1) * 110, 10, 100, 30, 
            difficultyNames[i], 
            function() 
                currentDifficulty = i
                print("Difficulty set to:", difficultyNames[i])
                love.load() -- Reload the level with new difficulty
            end,
            difficultyColors[i])
        table.insert(buttons, button)
    end
    
    -- Create ball type buttons
    local ballTypeNames = {"Standard", "Heavy", "Exploding", "Sticky"}
    local ballTypeColors = {
        {0.8, 0.8, 0.8, 0.8}, -- Standard (White)
        {0.5, 0.5, 0.5, 0.8}, -- Heavy (Gray)
        {0.8, 0.0, 0.0, 0.8}, -- Exploding (Red)
        {0.0, 0.8, 0.0, 0.8}  -- Sticky (Green)
    }
    
    for i = 1, 4 do
        local button = Button.new(120 + (i-1) * 140, 50, 130, 30, 
            ballTypeNames[i], 
            function() 
                -- This function will be called when the button is pressed
                -- It will be defined in main.lua to change the ball type
                if UI.onBallTypeChange then
                    UI.onBallTypeChange(i)
                end
            end,
            ballTypeColors[i])
        table.insert(buttons, button)
    end
    
    -- Create regenerate level button
    local regenButton = Button.new(680, 10, 100, 30, "New Level", function()
        love.load() -- Reload the level
    end, {0.0, 0.6, 0.8, 0.8})
    table.insert(buttons, regenButton)
    
    -- Create win hole button
    local winHoleButton = Button.new(680, 50, 100, 30, "Win Hole", function()
        -- This function will be called when the button is pressed
        -- It will be defined in main.lua to add a win hole at the ball position
        if UI.onAddWinHole then
            UI.onAddWinHole()
        end
    end, {0.8, 0.8, 0.0, 0.8})
    table.insert(buttons, winHoleButton)
end

-- Update the UI
function UI.update(mouseX, mouseY)
    toggleUIButton:update(mouseX, mouseY)
    
    if isUIVisible then
        for _, button in ipairs(buttons) do
            button:update(mouseX, mouseY)
        end
    end
end

-- Draw the UI
function UI.draw()
    -- Always draw the toggle button
    toggleUIButton:draw()
    
    -- Draw other buttons only if UI is visible
    if isUIVisible then
        for _, button in ipairs(buttons) do
            button:draw()
        end
    end
end

-- Handle mouse press
function UI.handlePress(x, y)
    -- Check toggle button first
    if toggleUIButton:handlePress(x, y) then
        return true
    end
    
    -- Check other buttons only if UI is visible
    if isUIVisible then
        for _, button in ipairs(buttons) do
            if button:handlePress(x, y) then
                return true
            end
        end
    end
    
    return false
end

return UI
