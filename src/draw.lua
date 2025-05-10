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
    -- If menu is active, use the level background color for clearing
    if Game.currentMode == Game.MODES.MENU then
        love.graphics.clear(Game.LEVEL_BACKGROUND_COLOR[1], Game.LEVEL_BACKGROUND_COLOR[2], 
                           Game.LEVEL_BACKGROUND_COLOR[3], Game.LEVEL_BACKGROUND_COLOR[4])
    else
        -- Draw gradient background
        love.graphics.clear(0, 0, 0, 1) -- Clear with black first
    end
    
    -- If menu is active, draw menu (Menu.draw handles its own transformations)
    if Game.currentMode == Game.MODES.MENU then
        -- Get screen dimensions
        local width, height = love.graphics.getDimensions()
        
        -- Store the scale for other modules to use
        GAME_SCALE = ZOOM_LEVEL
        
        -- Store the offsets for other modules to use
        GAME_OFFSET_X = 0
        GAME_OFFSET_Y = 0
        
        -- Draw menu (handles its own transformations for background and UI)
        Menu.draw()
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
    
    -- Draw solid level background color
    love.graphics.setColor(Game.LEVEL_BACKGROUND_COLOR[1], Game.LEVEL_BACKGROUND_COLOR[2], 
                          Game.LEVEL_BACKGROUND_COLOR[3], Game.LEVEL_BACKGROUND_COLOR[4])
    love.graphics.rectangle("fill", 0, 0, levelWidth, levelHeight)
    
    
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
    
    -- Draw FPS counter in absolute screen coordinates (sticky to top left corner)
    love.graphics.push()
    love.graphics.origin() -- Reset all transformations to ensure absolute positioning
    love.graphics.setColor(Game.WHITE)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 0, 0)
    love.graphics.pop()
    
    -- Apply transformation for UI elements (without scaling or camera offset)
    love.graphics.push()
    -- No scaling for UI elements
    love.graphics.translate(GAME_OFFSET_X, GAME_OFFSET_Y)
    
    -- Only display game mode in EDITOR mode
    if Game.currentMode == Game.MODES.EDITOR then
        local modeText = "MODE: EDITOR"
        
        -- Add test play indicator if in test play mode
        if Game.testPlayMode then
            modeText = modeText .. " (TEST PLAY)"
        end
        
        love.graphics.print(modeText, 10, 50)
    end
    
    -- Display zoom level in the top center with game font
    local zoomText = string.format("%.1f", ZOOM_LEVEL) .. "x"
    
    -- Load the pixel font for zoom display if not already loaded
    if not Game.zoomFont then
        Game.zoomFont = love.graphics.newFont("fonts/pixel_font.ttf", 24)
    end
    
    -- Save current font
    local currentFont = love.graphics.getFont()
    
    -- Set font to game font
    love.graphics.setFont(Game.zoomFont)
    
    -- Calculate width with the game font
    local zoomTextWidth = Game.zoomFont:getWidth(zoomText)
    local screenWidth = love.graphics.getWidth()
    
    -- Draw zoom text
    love.graphics.print(zoomText, (screenWidth - zoomTextWidth) / 2, 10)
    
    -- Restore original font
    love.graphics.setFont(currentFont)
    
    -- Reset transformation
    love.graphics.pop()
    
    
    -- Draw UI (UI is drawn at screen coordinates, not scaled)
    if not Editor.active then
        -- Draw UI based on game mode
        UI.draw()
        
        -- Draw mobile UI if available
        if Game.mobileUI then
            Game.mobileUI.draw(Game)
        end
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
