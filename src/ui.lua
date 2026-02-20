-- ui.lua - User interface elements for the game

local UI = {}

-- Load the pixel font for buttons
local buttonFont = nil
local function loadButtonFont()
    -- Load the font with larger size for retro look
    buttonFont = love.graphics.newFont("fonts/pixel_font.ttf", 24)
end

-- Retro color palette for 80s cassette futurism aesthetic
local retroColors = {
    background = {0.05, 0.05, 0.15, 0.9},  -- Dark blue background
    panel = {0.1, 0.1, 0.2, 0.9},          -- Slightly lighter panel
    panelBorder = {0, 0.8, 0.8, 1},        -- Cyan border
    buttonNormal = {0.2, 0.2, 0.4, 1},     -- Dark purple button
    buttonHover = {0.3, 0.3, 0.6, 1},      -- Lighter purple on hover
    buttonBorder = {0, 0.8, 0.8, 1},       -- Cyan border
    buttonHighlight = {0, 1, 1, 0.3},      -- Cyan highlight
    textShadow = {0, 0, 0, 0.7},           -- Dark text shadow
    text = {0, 1, 1, 1}                    -- Cyan text
}

-- Draw scanlines effect for retro CRT look
local function drawScanlines(x, y, width, height, alpha)
    love.graphics.setColor(0, 0, 0, alpha or 0.1)
    for i = 0, height, 2 do
        love.graphics.line(x, y + i, x + width, y + i)
    end
end

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
    -- Draw button with retro 80s computer aesthetic (squared, pixelated)
    
    -- Button shadow (offset slightly)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", self.x + 3, self.y + 3, self.width, self.height, 0, 0) -- No rounded corners
    
    -- Main button fill with retro colors
    if self.isHovered then
        -- For colored buttons (like ball buttons), brighten the custom color
        if self.color and self.color ~= retroColors.buttonNormal then
            love.graphics.setColor(self.hoverColor)
        else
            love.graphics.setColor(retroColors.buttonHover)
        end
    else
        -- For colored buttons, use the custom color
        if self.color and self.color ~= retroColors.buttonNormal then
            love.graphics.setColor(self.color)
        else
            love.graphics.setColor(retroColors.buttonNormal)
        end
    end
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 0, 0) -- No rounded corners
    
    -- Add a grid pattern for retro computer look
    love.graphics.setColor(0, 0, 0, 0.1)
    for i = 0, self.width, 4 do
        love.graphics.line(self.x + i, self.y, self.x + i, self.y + self.height)
    end
    for i = 0, self.height, 4 do
        love.graphics.line(self.x, self.y + i, self.x + self.width, self.y + i)
    end
    
    -- Add a highlight at the top for retro 3D effect
    love.graphics.setColor(retroColors.buttonHighlight)
    love.graphics.rectangle("fill", self.x, self.y, self.width, 2)
    love.graphics.rectangle("fill", self.x, self.y, 2, self.height)
    
    -- Draw button border with thicker line
    love.graphics.setColor(retroColors.buttonBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
    love.graphics.setLineWidth(1) -- Reset line width
    
    -- Check if this is the reset button (no text)
    if self == UI.resetButton then
        -- Draw reset icon (circular arrow)
        love.graphics.setColor(retroColors.text)
        love.graphics.setLineWidth(2)
        
        -- Calculate icon dimensions
        local iconSize = self.width * 0.6
        local centerX = self.x + self.width / 2
        local centerY = self.y + self.height / 2
        local radius = iconSize / 2
        
        -- Draw circular arrow (270 degrees)
        love.graphics.arc("line", centerX, centerY, radius, math.rad(0), math.rad(270))
        
        -- Draw arrowhead
        local arrowX = centerX
        local arrowY = centerY - radius
        local arrowSize = radius / 3
        love.graphics.line(arrowX, arrowY, arrowX + arrowSize, arrowY + arrowSize)
        love.graphics.line(arrowX, arrowY, arrowX - arrowSize, arrowY + arrowSize)
        
        -- Reset line width
        love.graphics.setLineWidth(1)
    -- Only draw text if there is any
    elseif self.text and self.text ~= "" then
        -- Set the pixel font for button text
        love.graphics.setFont(buttonFont)
        
        -- Text shadow
        love.graphics.setColor(retroColors.textShadow)
        local textWidth = buttonFont:getWidth(self.text)
        local textHeight = buttonFont:getHeight()
        love.graphics.print(self.text, 
            self.x + (self.width - textWidth) / 2 + 1, 
            self.y + (self.height - textHeight) / 2 + 1)
        
        -- Actual text with retro cyan color
        love.graphics.setColor(retroColors.text)
        love.graphics.print(self.text, 
            self.x + (self.width - textWidth) / 2, 
            self.y + (self.height - textHeight) / 2)
        
        -- Reset to default font
        love.graphics.setFont(love.graphics.getFont())
    end
    
    -- Add scanlines for CRT effect
    drawScanlines(self.x, self.y, self.width, self.height, 0.05)
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
local ballButtons = {} -- Separate array for ball buttons
local isUIVisible = false
local toggleUIButton = nil
local isPlayMode = false -- Flag to track if we're in PLAY mode

-- Game dimensions for positioning
local GAME_WIDTH = 1600
local GAME_HEIGHT = 1000

-- Initialize the UI
function UI.init(ballTypes)
    -- Load the button font
    loadButtonFont()
    
    -- Get screen dimensions for positioning
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Button dimensions for retro look
    local buttonWidth = 160
    local buttonHeight = 40
    local buttonMargin = 10
    local panelWidth = buttonWidth + buttonMargin * 2
    
    -- Position the toggle button in the top right corner of the game area
    local rightEdge = GAME_WIDTH - buttonMargin
    local buttonX = rightEdge - buttonWidth
    
    -- Create toggle UI button in the top right corner (only visible in EDITOR mode)
    toggleUIButton = Button.new(rightEdge - buttonWidth, buttonMargin, buttonWidth, buttonHeight, "TERMINAL", function()
        isUIVisible = not isUIVisible
    end)
    
    -- Check if we're in PLAY mode by looking at the GameState
    local GameState = require("src.game_state")
    local Game = require("src.game")
    isPlayMode = Game.currentMode == GameState.MODES.PLAY
    
    -- Create difficulty buttons
    local difficultyNames = {"EASY", "MEDIUM", "HARD", "EXPERT", "INSANE"}
    
    -- Create difficulty buttons vertically stacked on the right
    for i = 1, 5 do
        local button = Button.new(
            buttonX, 
            buttonMargin + i * (buttonHeight + buttonMargin) + 50, 
            buttonWidth, 
            buttonHeight, 
            difficultyNames[i], 
            function() 
                currentDifficulty = i
                print("Difficulty set to:", difficultyNames[i])
                love.load() -- Reload the level with new difficulty
            end
        )
        table.insert(buttons, button)
    end
    
    -- Create ball type buttons
    local ballTypeNames = {"STANDARD", "HEAVY", "EXPLODE", "STICKY", "SPRAY", "BULLET", "ICE"}
    
    -- Create ball type buttons vertically stacked on the right
    local ballButtonY = buttonMargin + 6 * (buttonHeight + buttonMargin) + 70
    for i = 1, 7 do
        local button = Button.new(
            buttonX, 
            ballButtonY + (i-1) * (buttonHeight + buttonMargin), 
            buttonWidth, 
            buttonHeight, 
            ballTypeNames[i], 
            function() 
                -- This function will be called when the button is pressed
                -- It will be defined in main.lua to change the ball type
                if UI.onBallTypeChange then
                    UI.onBallTypeChange(i)
                end
            end
        )
        table.insert(buttons, button)
        
        -- Also create separate ball buttons for PLAY mode that will be always visible
        -- These will be positioned in a horizontal row in the bottom left corner
        if isPlayMode then
            -- Make smaller square buttons without text
            local buttonSize = 40 -- Square buttons
            local ballColors = {
                {1, 1, 1, 1},         -- STANDARD: white
                {0.6, 0.6, 0.8, 1},   -- HEAVY: blue-gray
                {1, 0.4, 0.2, 1},     -- EXPLODE: orange-red
                {0.3, 0.8, 0.3, 1},   -- STICKY: green
                {0.9, 0.8, 0.3, 1},   -- SPRAY: yellow
                {0.25, 0.25, 0.28, 1},-- BULLET: dark gray
                {0.5, 0.85, 1.0, 1}   -- ICE: light cyan
            }
            
            local playModeBallButton = Button.new(
                buttonMargin + (i-1) * (buttonSize + buttonMargin),
                GAME_HEIGHT - buttonMargin - buttonSize,
                buttonSize,
                buttonSize,
                "", -- No text
                function()
                    if UI.onBallTypeChange then
                        UI.onBallTypeChange(i)
                    end
                end,
                ballColors[i] -- Use the appropriate color for this ball type
            )
            table.insert(ballButtons, playModeBallButton)
        end
    end
    
    -- Create reset button for PLAY mode (same size as ball buttons)
    if isPlayMode then
        local buttonSize = 40 -- Square buttons
        local buttonMargin = 10
        
        -- Create reset button in the bottom right corner
        UI.resetButton = Button.new(
            GAME_WIDTH - buttonMargin - buttonSize,
            GAME_HEIGHT - buttonMargin - buttonSize,
            buttonSize,
            buttonSize,
            "", -- No text, will draw an icon instead
            function()
                -- Reset the current level
                local Game = require("src.game")
                local Menu = require("src.menu")
                
                if Game.currentMode == Game.MODES.PLAY then
                    -- In PLAY mode, reinitialize with the current level
                    Game.init(Game.currentMode, Menu.currentLevel)
                else
                    -- In SANDBOX or TEST_PLAY mode, just reinitialize the current mode
                    Game.init(Game.currentMode)
                end
                
                Game.gameWon = false
                Game.winMessageTimer = 0
            end
        )
        table.insert(ballButtons, UI.resetButton)
    end
    
    -- Create regenerate level button
    local regenButton = Button.new(
        buttonX, 
        ballButtonY + 4 * (buttonHeight + buttonMargin) + 20, 
        buttonWidth, 
        buttonHeight, 
        "NEW LEVEL", 
        function()
            love.load() -- Reload the level
        end
    )
    table.insert(buttons, regenButton)
    
    -- Create win hole button
    local winHoleButton = Button.new(
        buttonX, 
        ballButtonY + 5 * (buttonHeight + buttonMargin) + 20, 
        buttonWidth, 
        buttonHeight, 
        "WIN HOLE", 
        function()
            -- This function will be called when the button is pressed
            -- It will be defined in main.lua to add a win hole at the ball position
            if UI.onAddWinHole then
                UI.onAddWinHole()
            end
        end
    )
    table.insert(buttons, winHoleButton)
    
    -- Get Game module
    local Game = require("src.game")
    
    -- Create return to editor button (only visible in test play mode)
    UI.returnToEditorButton = Button.new(
        buttonX, 
        ballButtonY + 6 * (buttonHeight + buttonMargin) + 20, 
        buttonWidth, 
        buttonHeight, 
        "TO EDITOR", 
        function()
            -- Return to editor
            local Editor = require("src.editor")
            Editor.returnFromTestPlay()
            Game.testPlayMode = false
        end
    )
    table.insert(buttons, UI.returnToEditorButton)
end

-- Update the UI
function UI.update(mouseX, mouseY)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = UI.convertCoordinates(mouseX, mouseY)
    
    -- Only update the toggle button in EDITOR mode
    local Game = require("src.game")
    local GameState = require("src.game_state")
    if Game.currentMode == GameState.MODES.EDITOR then
        toggleUIButton:update(gameX, gameY)
    end
    
    -- Update the separate ball buttons in PLAY mode
    if isPlayMode and #ballButtons > 0 then
        local Balls = require("src.balls")
        local ballTypeNames = {"STANDARD", "HEAVY", "EXPLODE", "STICKY", "SPRAY", "BULLET", "ICE"}
        
        for i, button in ipairs(ballButtons) do
            local ballName = ballTypeNames[i]
            local ballType = Balls.TYPES[string.upper(ballName == "EXPLODE" and "EXPLODING" or ballName == "SPRAY" and "SPRAYING" or ballName == "ICE" and "ICE_BALL" or ballName)]
            
            -- Only update the ball button if it's available
            if UI.availableBalls and UI.availableBalls[ballType] then
                button:update(gameX, gameY)
            end
        end
    end
    
    if isUIVisible then
        local Balls = require("src.balls")
        local ballTypeNames = {"STANDARD", "HEAVY", "EXPLODE", "STICKY", "SPRAY"}
        
        for _, button in ipairs(buttons) do
            -- Skip the "Return to Editor" button if not in test play mode
            if button == UI.returnToEditorButton then
                -- Get Game module
                local Game = require("src.game")
                if not Game.testPlayMode then
                    goto continue
                end
            end
            
            -- Check if this is a ball button and if it's available
            local isBallButton = false
            for j, ballName in ipairs(ballTypeNames) do
                if button.text == ballName then
                    isBallButton = true
                    local ballType = Balls.TYPES[string.upper(ballName == "EXPLODE" and "EXPLODING" or ballName == "SPRAY" and "SPRAYING" or ballName)]
                    
                    -- Only update the ball button if it's available
                    if UI.availableBalls and UI.availableBalls[ballType] then
                        button:update(gameX, gameY)
                    end
                    
                    goto continue
                end
            end
            
            -- If it's not a ball button, update it normally
            if not isBallButton then
                button:update(gameX, gameY)
            end
            
            ::continue::
        end
    end
end

-- Draw the UI
function UI.draw()
    -- Get screen dimensions for positioning
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Calculate scale factors
    local scaleX = screenWidth / GAME_WIDTH
    local scaleY = screenHeight / GAME_HEIGHT
    local scale = math.min(scaleX, scaleY) -- Use the smaller scale to ensure everything fits
    
    -- Ensure minimum scale to prevent rendering issues
    scale = math.max(scale, 0.5) -- Minimum scale factor of 0.5
    
    -- Apply scaling transformation for UI elements (without camera offset)
    love.graphics.push()
    love.graphics.scale(scale, scale)
    
    -- Center the game in the window
    local scaledWidth = screenWidth / scale
    local scaledHeight = screenHeight / scale
    local offsetX = (scaledWidth - GAME_WIDTH) / 2
    local offsetY = (scaledHeight - GAME_HEIGHT) / 2
    
    -- Apply translation for UI elements (without camera offset)
    love.graphics.translate(offsetX, offsetY)
    
    -- Button dimensions for calculating panel size
    local buttonWidth = 160
    local buttonMargin = 10
    local panelWidth = buttonWidth + buttonMargin * 2
    
    -- Only draw the toggle button in EDITOR mode
    local Game = require("src.game")
    local GameState = require("src.game_state")
    if Game.currentMode == GameState.MODES.EDITOR then
        toggleUIButton:draw()
    end
    
    -- Draw the ball buttons in PLAY mode
    if isPlayMode and #ballButtons > 0 then
        local Balls = require("src.balls")
        local ballTypeNames = {"STANDARD", "HEAVY", "EXPLODE", "STICKY", "SPRAY", "BULLET", "ICE"}
        
        -- Use smaller dimensions for the ball buttons panel
        local buttonSize = 40 -- Square buttons
        local panelWidth = (#ballButtons * (buttonSize + buttonMargin)) + buttonMargin
        local panelHeight = buttonSize + buttonMargin * 2
        local panelX = buttonMargin
        local panelY = GAME_HEIGHT - buttonMargin - buttonSize - buttonMargin * 2
        
        -- Draw a small panel for the ball buttons
        love.graphics.setColor(retroColors.panel)
        love.graphics.rectangle("fill", panelX - buttonMargin, panelY - buttonMargin, 
                               panelWidth, panelHeight, 0, 0)
        
        -- Draw grid pattern for retro computer look
        love.graphics.setColor(0, 0, 0, 0.05)
        for i = 0, panelWidth, 8 do
            love.graphics.line(panelX - buttonMargin + i, panelY - buttonMargin, 
                              panelX - buttonMargin + i, panelY - buttonMargin + panelHeight)
        end
        for i = 0, panelHeight, 8 do
            love.graphics.line(panelX - buttonMargin, panelY - buttonMargin + i, 
                              panelX - buttonMargin + panelWidth, panelY - buttonMargin + i)
        end
        
        -- Draw panel border
        love.graphics.setColor(retroColors.panelBorder)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", panelX - buttonMargin, panelY - buttonMargin, 
                               panelWidth, panelHeight)
        love.graphics.setLineWidth(1)
        
        -- Draw scanlines for CRT effect
        drawScanlines(panelX - buttonMargin, panelY - buttonMargin, panelWidth, panelHeight, 0.05)
        
        -- Draw the ball buttons
        for i, button in ipairs(ballButtons) do
            local ballName = ballTypeNames[i]
            local ballType = Balls.TYPES[string.upper(ballName == "EXPLODE" and "EXPLODING" or ballName == "SPRAY" and "SPRAYING" or ballName == "ICE" and "ICE_BALL" or ballName)]
            
            -- Only draw the ball button if it's available
            if UI.availableBalls and UI.availableBalls[ballType] then
                button:draw()
            end
        end
    end
    
    -- Draw other buttons only if UI is visible
    if isUIVisible then
        -- Draw a retro terminal panel on the right side
        local panelX = GAME_WIDTH - panelWidth
        local panelHeight = GAME_HEIGHT
        
        -- Draw panel background
        love.graphics.setColor(retroColors.panel)
        love.graphics.rectangle("fill", panelX, 0, panelWidth, panelHeight, 0, 0) -- No rounded corners for retro look
        
        -- Draw grid pattern for retro computer look
        love.graphics.setColor(0, 0, 0, 0.05)
        for i = 0, panelWidth, 8 do
            love.graphics.line(panelX + i, 0, panelX + i, panelHeight)
        end
        for i = 0, panelHeight, 8 do
            love.graphics.line(panelX, i, panelX + panelWidth, i)
        end
        
        -- Draw panel border
        love.graphics.setColor(retroColors.panelBorder)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", panelX, 0, panelWidth, panelHeight)
        love.graphics.line(panelX, 0, panelX, panelHeight) -- Left edge line
        love.graphics.setLineWidth(1)
        
        -- Draw scanlines for CRT effect
        drawScanlines(panelX, 0, panelWidth, panelHeight, 0.05)
        
        -- Draw "TERMINAL" header
        love.graphics.setFont(buttonFont)
        love.graphics.setColor(retroColors.text)
        local headerText = "CONTROLS"
        local headerWidth = buttonFont:getWidth(headerText)
        love.graphics.print(headerText, panelX + (panelWidth - headerWidth) / 2, buttonMargin * 3 + 40)
        
        -- Draw all buttons
        local Balls = require("src.balls")
        local ballTypeNames = {"STANDARD", "HEAVY", "EXPLODE", "STICKY", "SPRAY", "BULLET", "ICE"}
        
        for i, button in ipairs(buttons) do
            -- Skip the "Return to Editor" button if not in test play mode
            if button == UI.returnToEditorButton then
                -- Get Game module
                local Game = require("src.game")
                if not Game.testPlayMode then
                    goto continue
                end
            end
            
            -- Check if this is a ball button and if it's available
            local isBallButton = false
            for j, ballName in ipairs(ballTypeNames) do
                if button.text == ballName then
                    isBallButton = true
                    local ballType = Balls.TYPES[string.upper(ballName == "EXPLODE" and "EXPLODING" or ballName == "SPRAY" and "SPRAYING" or ballName == "ICE" and "ICE_BALL" or ballName)]
                    
                    -- Only draw the ball button if it's available
                    if UI.availableBalls and UI.availableBalls[ballType] then
                        button:draw()
                    end
                    
                    goto continue
                end
            end
            
            -- If it's not a ball button, draw it normally
            if not isBallButton then
                button:draw()
            end
            
            ::continue::
        end
    end
    
    -- Reset the transformation
    love.graphics.pop()
end

-- Convert screen coordinates to game coordinates
function UI.convertCoordinates(screenX, screenY)
    -- Calculate scale factors
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local scaleX = screenWidth / GAME_WIDTH
    local scaleY = screenHeight / GAME_HEIGHT
    local scale = math.min(scaleX, scaleY)
    scale = math.max(scale, 0.5) -- Minimum scale factor of 0.5
    
    -- Calculate offsets for centering
    local scaledWidth = screenWidth / scale
    local scaledHeight = screenHeight / scale
    local offsetX = (scaledWidth - GAME_WIDTH) / 2
    local offsetY = (scaledHeight - GAME_HEIGHT) / 2
    
    -- Convert screen coordinates to game coordinates
    local gameX = (screenX / scale) - offsetX
    local gameY = (screenY / scale) - offsetY
    
    return gameX, gameY
end

-- Handle mouse press
function UI.handlePress(x, y)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = UI.convertCoordinates(x, y)
    
    -- Check toggle button only in EDITOR mode
    local Game = require("src.game")
    local GameState = require("src.game_state")
    if Game.currentMode == GameState.MODES.EDITOR and toggleUIButton:handlePress(gameX, gameY) then
        return true
    end
    
    -- Check the ball buttons in PLAY mode
    if isPlayMode and #ballButtons > 0 then
        local Balls = require("src.balls")
        local ballTypeNames = {"STANDARD", "HEAVY", "EXPLODE", "STICKY", "SPRAY"}
        
        for i, button in ipairs(ballButtons) do
            local ballName = ballTypeNames[i]
            local ballType = Balls.TYPES[string.upper(ballName == "EXPLODE" and "EXPLODING" or ballName == "SPRAY" and "SPRAYING" or ballName)]
            
            -- Only handle press for the ball button if it's available
            if UI.availableBalls and UI.availableBalls[ballType] and button:handlePress(gameX, gameY) then
                return true
            end
        end
    end
    
    -- Check other buttons only if UI is visible
    if isUIVisible then
        local Balls = require("src.balls")
        local ballTypeNames = {"STANDARD", "HEAVY", "EXPLODE", "STICKY", "SPRAY"}
        
        for _, button in ipairs(buttons) do
            -- Skip the "Return to Editor" button if not in test play mode
            if button == UI.returnToEditorButton then
                -- Get Game module
                local Game = require("src.game")
                if not Game.testPlayMode then
                    goto continue
                end
            end
            
            -- Check if this is a ball button and if it's available
            local isBallButton = false
            for j, ballName in ipairs(ballTypeNames) do
                if button.text == ballName then
                    isBallButton = true
                    local ballType = Balls.TYPES[string.upper(ballName == "EXPLODE" and "EXPLODING" or ballName == "SPRAY" and "SPRAYING" or ballName)]
                    
                    -- Only handle press for the ball button if it's available
                    if UI.availableBalls and UI.availableBalls[ballType] and button:handlePress(gameX, gameY) then
                        return true
                    end
                    
                    goto continue
                end
            end
            
            -- If it's not a ball button, handle press normally
            if not isBallButton and button:handlePress(gameX, gameY) then
                return true
            end
            
            ::continue::
        end
    end
    
    return false
end

return UI
