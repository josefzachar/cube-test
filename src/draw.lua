-- draw.lua - Drawing and rendering functions

local Debug = require("src.debug")
local Sound = require("src.sound")
local Editor = require("src.editor")
local Menu = require("src.menu")
local UI = require("src.ui")
local Camera = require("src.camera")
local Cell = require("cell")

local Draw = {}

-- Draw the game
function Draw.draw(Game)
    -- Draw gradient background
    love.graphics.clear(0, 0, 0, 1) -- Clear with black first
    
    -- If menu is active, draw menu with standard transformation
    if Game.currentMode == Game.MODES.MENU then
        -- Get screen dimensions
        local width, height = love.graphics.getDimensions()
        
        -- Calculate scale based on screen dimensions
        -- No reference size needed - just use the screen dimensions
        local scale = 1.0 -- Default scale
        
        -- Store the scale for other modules to use
        GAME_SCALE = scale
        
        -- Ensure minimum scale to prevent rendering issues
        scale = math.max(scale, 0.5) -- Minimum scale factor of 0.5
        
        -- Store the scale for other modules to use
        GAME_SCALE = scale
        
        -- Apply scaling transformation
        love.graphics.push()
        love.graphics.scale(scale, scale)
        
        -- Adjust width and height for scaled coordinates
        local scaledWidth = width / scale
        local scaledHeight = height / scale
        
        -- Center the game in the window
        -- No need for offsets since we're using the actual level dimensions
        local offsetX = 0
        local offsetY = 0
        
        -- Store the offsets for other modules to use
        GAME_OFFSET_X = offsetX
        GAME_OFFSET_Y = offsetY
        
        love.graphics.translate(offsetX, offsetY)
        
        Menu.draw()
        -- Pop the transformation stack before returning
        love.graphics.pop()
        return
    end
    
    -- Update camera position if we have a ball
    if Game.ball then
        local ballX, ballY = Game.ball:getPosition()
        Camera.update(ballX, ballY, love.timer.getDelta())
    end
    
    -- Apply camera transformation (includes scaling, centering, and camera position)
    Camera.apply(Game)
    
    -- Get screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Get level dimensions
    local levelWidth = Game.level.width * Cell.SIZE
    local levelHeight = Game.level.height * Cell.SIZE
    
    -- Draw gradient rectangle covering the entire screen
    love.graphics.setColor(Game.BACKGROUND_COLOR_TOP[1], Game.BACKGROUND_COLOR_TOP[2], Game.BACKGROUND_COLOR_TOP[3], Game.BACKGROUND_COLOR_TOP[4])
    love.graphics.rectangle("fill", 0, 0, levelWidth, levelHeight)
    
    -- Create a subtle gradient mesh
    local gradient = love.graphics.newMesh({
        {0, 0, 0, 0, Game.BACKGROUND_COLOR_TOP[1], Game.BACKGROUND_COLOR_TOP[2], Game.BACKGROUND_COLOR_TOP[3], Game.BACKGROUND_COLOR_TOP[4]}, -- top-left
        {levelWidth, 0, 1, 0, Game.BACKGROUND_COLOR_TOP[1], Game.BACKGROUND_COLOR_TOP[2], Game.BACKGROUND_COLOR_TOP[3], Game.BACKGROUND_COLOR_TOP[4]}, -- top-right
        {levelWidth, levelHeight, 1, 1, Game.BACKGROUND_COLOR_BOTTOM[1], Game.BACKGROUND_COLOR_BOTTOM[2], Game.BACKGROUND_COLOR_BOTTOM[3], Game.BACKGROUND_COLOR_BOTTOM[4]}, -- bottom-right
        {0, levelHeight, 0, 1, Game.BACKGROUND_COLOR_BOTTOM[1], Game.BACKGROUND_COLOR_BOTTOM[2], Game.BACKGROUND_COLOR_BOTTOM[3], Game.BACKGROUND_COLOR_BOTTOM[4]} -- bottom-left
    }, "fan", "static")
    
    love.graphics.draw(gradient)
    
    
    -- If editor is active, draw editor
    if Editor.active then
        Editor.draw()
        -- Pop the transformation stack before returning
        love.graphics.pop()
        return
    end
    
    -- Draw the level (only if editor is not active)
    Game.level:draw(Game.debug) -- Pass debug flag to level:draw
    
    -- Draw input (aim line, power indicator) BEFORE the ball so ball appears on top
    Game.input:draw(Game.ball, Game.attempts)
    
    -- Draw the ball on top of everything
    Game.ball:draw(Game.debug) -- Pass debug flag to ball:draw
    
    -- Debug info
    Debug.drawDebugInfo(Game.level, Game.ball, Game.attempts, Game.debug)
    
    -- Draw active cells for debugging
    Debug.drawActiveCells(Game.level)
    
    -- Reset camera transformation before drawing UI
    love.graphics.pop()
    
    -- Apply scaling transformation for UI elements (without camera offset)
    love.graphics.push()
    love.graphics.scale(GAME_SCALE, GAME_SCALE)
    love.graphics.translate(GAME_OFFSET_X, GAME_OFFSET_Y)
    
    -- Display FPS counter
    love.graphics.setColor(Game.WHITE)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Display game mode
    local modeText = "MODE: "
    if Game.currentMode == Game.MODES.PLAY then
        modeText = modeText .. "PLAY (Level " .. Menu.currentLevel .. ")"
    elseif Game.currentMode == Game.MODES.EDITOR then
        modeText = modeText .. "EDITOR"
    elseif Game.currentMode == Game.MODES.SANDBOX then
        modeText = modeText .. "SANDBOX"
    end
    
    -- Add test play indicator if in test play mode
    if Game.testPlayMode then
        modeText = modeText .. " (TEST PLAY)"
    end
    
    love.graphics.print(modeText, 10, 50)
    
    -- Reset transformation
    love.graphics.pop()
    
    
    -- Draw UI (UI is drawn at screen coordinates, not scaled)
    if not Editor.active then
        -- Draw UI based on game mode
        UI.draw()
    end
    
    -- Draw win message if the game is won
    if Game.gameWon and Game.winMessageTimer > 0 then
        Draw.drawWinScreen(Game)
    end
end

-- Draw the win screen
function Draw.drawWinScreen(Game)
    -- Load the win screen font if not already loaded
    if not Game.winFont then
        Game.winFont = love.graphics.newFont("fonts/pixel_font.ttf", 32)
    end
    if not Game.winFontSmall then
        Game.winFontSmall = love.graphics.newFont("fonts/pixel_font.ttf", 24)
    end
    
    -- Get screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Draw a retro-styled background panel
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9) -- Dark blue background
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
    
    -- Draw grid pattern for retro computer look
    love.graphics.setColor(0, 0, 0, 0.05)
    for i = 0, screenWidth, 16 do
        love.graphics.line(i, 0, i, screenHeight)
    end
    for i = 0, screenHeight, 16 do
        love.graphics.line(0, i, screenWidth, i)
    end
    
    -- Draw scanlines for CRT effect
    love.graphics.setColor(0, 0, 0, 0.1)
    for i = 0, screenHeight, 2 do
        love.graphics.line(0, i, screenWidth, i)
    end
    
    -- Draw a centered terminal-like window
    local windowWidth = 600
    local windowHeight = 400
    local windowX = (screenWidth - windowWidth) / 2
    local windowY = (screenHeight - windowHeight) / 2
    
    -- Window background
    love.graphics.setColor(0.05, 0.05, 0.15, 0.95)
    love.graphics.rectangle("fill", windowX, windowY, windowWidth, windowHeight, 0, 0) -- No rounded corners
    
    -- Window border
    love.graphics.setColor(0, 0.8, 0.8, 1) -- Cyan border
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", windowX, windowY, windowWidth, windowHeight, 0, 0)
    love.graphics.setLineWidth(1)
    
    -- Window header
    love.graphics.setColor(0.2, 0.2, 0.4, 1)
    love.graphics.rectangle("fill", windowX, windowY, windowWidth, 40, 0, 0)
    
    -- Header text
    love.graphics.setFont(Game.winFont)
    love.graphics.setColor(0, 1, 1, 1) -- Cyan text
    local headerText = "MISSION COMPLETE"
    local headerWidth = Game.winFont:getWidth(headerText)
    love.graphics.print(headerText, windowX + (windowWidth - headerWidth) / 2, windowY + 5)
    
    -- Content
    love.graphics.setFont(Game.winFontSmall)
    
    -- Display current difficulty
    local difficultyName = "EASY"
    if currentDifficulty == 2 then
        difficultyName = "MEDIUM"
    elseif currentDifficulty == 3 then
        difficultyName = "HARD"
    elseif currentDifficulty == 4 then
        difficultyName = "EXPERT"
    elseif currentDifficulty == 5 then
        difficultyName = "INSANE"
    end
    
    -- Stats section
    local textY = windowY + 70
    local textX = windowX + 50
    local lineHeight = 35
    
    love.graphics.setColor(1, 0.5, 0, 1) -- Orange for headers
    love.graphics.print("MISSION STATS:", textX, textY)
    textY = textY + lineHeight
    
    love.graphics.setColor(0, 1, 1, 1) -- Cyan for text
    love.graphics.print("SHOTS FIRED: " .. Game.attempts, textX, textY)
    textY = textY + lineHeight
    
    love.graphics.print("DIFFICULTY: " .. difficultyName, textX, textY)
    textY = textY + lineHeight * 1.5
    
    -- Next difficulty message
    if currentDifficulty < 5 then
        local nextDifficultyName = "MEDIUM"
        if currentDifficulty == 2 then
            nextDifficultyName = "HARD"
        elseif currentDifficulty == 3 then
            nextDifficultyName = "EXPERT"
        elseif currentDifficulty == 4 then
            nextDifficultyName = "INSANE"
        end
        
        love.graphics.setColor(1, 0.5, 0, 1) -- Orange for headers
        love.graphics.print("NEXT MISSION:", textX, textY)
        textY = textY + lineHeight
        
        love.graphics.setColor(0, 1, 1, 1) -- Cyan for text
        love.graphics.print("DIFFICULTY: " .. nextDifficultyName, textX, textY)
    else
        love.graphics.setColor(1, 0.5, 0, 1) -- Orange for headers
        love.graphics.print("MAXIMUM DIFFICULTY REACHED", textX, textY)
    end
    
    -- Draw buttons
    local buttonWidth = 200
    local buttonHeight = 50
    local buttonX = windowX + (windowWidth - buttonWidth) / 2
    local buttonY = windowY + windowHeight - buttonHeight - 40
    
    -- If in test play mode, show "Return to Editor" button
    if Game.testPlayMode then
        -- Draw "RETURN TO EDITOR" button
        love.graphics.setColor(0.2, 0.2, 0.4, 1) -- Button background
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 0, 0)
        
        -- Button border
        love.graphics.setColor(0, 0.8, 0.8, 1) -- Cyan border
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 0, 0)
        love.graphics.setLineWidth(1)
        
        -- Button highlight
        love.graphics.setColor(0, 1, 1, 0.3) -- Cyan highlight
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, 2)
        love.graphics.rectangle("fill", buttonX, buttonY, 2, buttonHeight)
        
        -- Button text
        love.graphics.setColor(0, 1, 1, 1) -- Cyan text
        local buttonText = "TO EDITOR"
        local buttonTextWidth = Game.winFontSmall:getWidth(buttonText)
        love.graphics.print(buttonText, buttonX + (buttonWidth - buttonTextWidth) / 2, buttonY + (buttonHeight - Game.winFontSmall:getHeight()) / 2)
    else
        -- Draw "CONTINUE" button
        love.graphics.setColor(0.2, 0.2, 0.4, 1) -- Button background
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 0, 0)
        
        -- Button border
        love.graphics.setColor(0, 0.8, 0.8, 1) -- Cyan border
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 0, 0)
        love.graphics.setLineWidth(1)
        
        -- Button highlight
        love.graphics.setColor(0, 1, 1, 0.3) -- Cyan highlight
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, 2)
        love.graphics.rectangle("fill", buttonX, buttonY, 2, buttonHeight)
        
        -- Button text
        love.graphics.setColor(0, 1, 1, 1) -- Cyan text
        local buttonText = "CONTINUE [R]"
        local buttonTextWidth = Game.winFontSmall:getWidth(buttonText)
        love.graphics.print(buttonText, buttonX + (buttonWidth - buttonTextWidth) / 2, buttonY + (buttonHeight - Game.winFontSmall:getHeight()) / 2)
    end
end

return Draw
