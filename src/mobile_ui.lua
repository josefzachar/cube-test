-- mobile_ui.lua - Mobile-friendly UI components and scaling

local UI = require("src.ui")
local Balls = require("src.balls")

local MobileUI = {}

-- UI scaling factors
MobileUI.buttonScale = 2 -- Make buttons larger for touch
MobileUI.fontScale = 1   -- Make text larger for readability
MobileUI.spacing = 0      -- Spacing between UI elements

-- Images
MobileUI.resetIcon = nil -- Will be loaded in init

-- Initialize mobile UI
function MobileUI.init()
    -- Make sure the base UI is initialized
    if not UI.initialized then
        UI.init()
        UI.initialized = true
    end
    
    -- Load images
    MobileUI.resetIcon = love.graphics.newImage("img/reset.png")
    
    -- Apply mobile-specific UI adjustments
    MobileUI.createMobileButtons()
    
    -- Set up long press detection for material switching
    MobileUI.longPressTimer = 0
    MobileUI.longPressThreshold = 0.5 -- seconds
    MobileUI.isLongPressing = false
    
    -- Triple tap detection for reset
    MobileUI.tapCount = 0
    MobileUI.lastTapTime = 0
    MobileUI.tapTimeThreshold = 0.5 -- seconds
    
    print("Mobile UI initialized")
end

-- Create mobile-friendly buttons
function MobileUI.createMobileButtons()
    -- We'll create larger, touch-friendly buttons
    -- These will be used in addition to the gesture controls
    
    -- Ball type buttons (horizontally aligned on the bottom left)
    local buttonSize = 50 -- Square buttons for touch
    local buttonSpacing = 10
    local leftMargin = 20
    local bottomMargin = 20
    
    -- Ball type buttons (horizontally aligned on the bottom left)
    local buttonSize = 50 -- Square buttons for touch
    local buttonSpacing = 10
    local leftMargin = 20
    local bottomMargin = 20
    
    -- Reset button (visible when ball is not moving)
    MobileUI.resetButton = {
        x = love.graphics.getWidth() - leftMargin - buttonSize,
        y = love.graphics.getHeight() - bottomMargin - buttonSize,
        width = buttonSize,
        height = buttonSize,
        text = "", -- No text, will draw an icon instead
        visible = true,
        action = function(game)
            -- Reset the ball
            if game.ball then
                -- Instead of calling love.load() which goes back to the menu,
                -- reinitialize the current game mode to reset the level
                local currentMode = game.currentMode
                local Menu = require("src.menu")
                
                if currentMode == game.MODES.PLAY then
                    -- In PLAY mode, reinitialize with the current level
                    game.init(currentMode, Menu.currentLevel)
                else
                    -- In SANDBOX or TEST_PLAY mode, just reinitialize the current mode
                    game.init(currentMode)
                end
                
                game.gameWon = false
                game.winMessageTimer = 0
                return true -- Reset was performed
            end
            return false
        end
    }
    
    -- Ball type buttons (vertically stacked on the bottom left)
    local buttonSize = 50 -- Square buttons for touch
    local buttonSpacing = 0
    local leftMargin = 20
    local bottomMargin = 20
    
    -- Ball types and colors (no text labels)
    local ballTypes = {
        { name = "", type = Balls.TYPES.STANDARD,   color = {1, 1, 1, 1} },
        { name = "", type = Balls.TYPES.HEAVY,        color = {0.6, 0.6, 0.8, 1} },
        { name = "", type = Balls.TYPES.EXPLODING,    color = {1, 0.4, 0.2, 1} },
        { name = "", type = Balls.TYPES.STICKY,       color = {0.3, 0.8, 0.3, 1} },
        { name = "", type = Balls.TYPES.SPRAYING,     color = {0.9, 0.8, 0.3, 1} },
        { name = "", type = Balls.TYPES.BULLET,       color = {0.25, 0.25, 0.28, 1} },
        { name = "", type = Balls.TYPES.ICE_BALL,     color = {0.5, 0.85, 1.0, 1} },
        { name = "", type = Balls.TYPES.WATER_BALL,   color = {0.1, 0.55, 1.0, 1} },
        { name = "", type = Balls.TYPES.GROWING_BALL,  color = {0.5, 1.0, 0.1, 1} }
    }
    
    MobileUI.ballButtons = {}
    
    for i, ballInfo in ipairs(ballTypes) do
        local button = {
            x = leftMargin + (i-1) * (buttonSize + buttonSpacing),
            y = love.graphics.getHeight() - bottomMargin - buttonSize,
            width = buttonSize,
            height = buttonSize,
            text = ballInfo.name,
            ballType = ballInfo.type,
            color = ballInfo.color,
            visible = true,
            action = function(game)
                -- Only allow ball switching in SANDBOX mode or when testing in EDITOR
                if game.currentMode == game.MODES.SANDBOX or game.testPlayMode then
                    -- Change the ball type
                    game.currentBallType = ballInfo.type
                    local newBall = Balls.changeBallType(game.ball, game.world, game.currentBallType)
                    if game.ball and game.ball.body then game.ball.body:destroy() end
                    game.ball = newBall
                    if game.ball and game.ball.body then game.ball.body:setUserData(game.ball) end
                    -- Get the ball type name for logging
                    local ballTypeToName = {
                        [Balls.TYPES.STANDARD]   = "Standard",
                        [Balls.TYPES.HEAVY]      = "Heavy",
                        [Balls.TYPES.EXPLODING]  = "Exploding",
                        [Balls.TYPES.STICKY]     = "Sticky",
                        [Balls.TYPES.SPRAYING]   = "Spraying",
                        [Balls.TYPES.BULLET]     = "Bullet",
                        [Balls.TYPES.ICE_BALL]   = "Ice",
                        [Balls.TYPES.WATER_BALL]   = "Water",
                        [Balls.TYPES.GROWING_BALL] = "Growing"
                    }
                    local ballName = ballTypeToName[ballInfo.type] or "Unknown"
                    print("Switched to " .. ballName .. " Ball")
                    return true -- Ball type was changed
                end
                return false
            end
        }
        table.insert(MobileUI.ballButtons, button)
    end
end

-- Update mobile UI
function MobileUI.update(game, dt)
    -- Update button positions on window resize
    local buttonSize = 50
    local buttonSpacing = 10
    local leftMargin = 20
    local bottomMargin = 20
    
    -- Update reset button position
    MobileUI.resetButton.x = love.graphics.getWidth() - leftMargin - buttonSize
    MobileUI.resetButton.y = love.graphics.getHeight() - bottomMargin - buttonSize
    
    -- Update button visibility
    MobileUI.resetButton.visible = game.ball and not game.ball:isMoving()
    
    -- Update ball button positions
    local buttonSize = 50
    local buttonSpacing = 10
    local leftMargin = 20
    local bottomMargin = 20
    
    for i, button in ipairs(MobileUI.ballButtons) do
        button.x = leftMargin + (i-1) * (buttonSize + buttonSpacing)
        button.y = love.graphics.getHeight() - bottomMargin - buttonSize
        
        -- Show ball type buttons in SANDBOX mode, when testing in EDITOR, or in PLAY mode if the ball type is available
        if game.currentMode == game.MODES.SANDBOX or game.testPlayMode then
            button.visible = true
        elseif game.currentMode == game.MODES.PLAY and UI.availableBalls and UI.availableBalls[button.ballType] then
            button.visible = true
        else
            button.visible = false
        end
    end
    
    -- No long press detection needed anymore
end

-- Draw mobile UI
function MobileUI.draw(game)
    -- Set font size for mobile
    local originalFont = love.graphics.getFont()
    local fontSize = 24 * MobileUI.fontScale
    local font = love.graphics.newFont(fontSize)
    love.graphics.setFont(font)
    
    -- Draw reset button
    MobileUI.drawButton(MobileUI.resetButton, game.ball and not game.ball:isMoving())
    
    -- Draw ball type buttons
    for _, button in ipairs(MobileUI.ballButtons) do
        -- Highlight the current ball type
        local isSelected = game.currentBallType == button.ballType
        MobileUI.drawBallButton(button, button.visible, isSelected, button.color)
    end
    
    -- Draw zoom level in the top center with game font
    love.graphics.setColor(1, 1, 1, 0.7)
    local zoomText = string.format("%.1f", ZOOM_LEVEL) .. "x"
    
    -- Load the pixel font for zoom display if not already loaded
    if not MobileUI.zoomFont then
        MobileUI.zoomFont = love.graphics.newFont("fonts/pixel_font.ttf", 24)
    end
    
    -- Save current font
    local currentFont = love.graphics.getFont()
    
    -- Set font to game font
    love.graphics.setFont(MobileUI.zoomFont)
    
    -- Calculate width with the game font
    local zoomTextWidth = MobileUI.zoomFont:getWidth(zoomText)
    local screenWidth = love.graphics.getWidth()
    
    -- Draw zoom text
    love.graphics.print(zoomText, (screenWidth - zoomTextWidth) / 2, 10)
    
    -- Restore original font
    love.graphics.setFont(currentFont)
    
    -- Restore original font
    love.graphics.setFont(originalFont)
end

-- Draw a ball button with color
function MobileUI.drawBallButton(button, visible, isSelected, color)
    if not visible or not button.visible then
        return
    end
    
    -- Draw button background
    if isSelected then
        -- Selected button has brighter background
        love.graphics.setColor(0.4, 0.4, 0.4, 0.9)
    else
        love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    end
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
    
    -- Draw button border (thicker for selected button)
    if isSelected then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 0.8)
    end
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
    love.graphics.setLineWidth(1)
    
    -- Draw ball representation (colored square)
    love.graphics.setColor(color)
    local ballSize = button.width * 0.6 -- Make the colored square larger since we don't have text
    love.graphics.rectangle("fill", 
        button.x + (button.width - ballSize) / 2, 
        button.y + (button.height - ballSize) / 2, 
        ballSize, ballSize)
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw a button
function MobileUI.drawButton(button, visible)
    if not visible or not button.visible then
        return
    end
    
    -- Draw button background
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
    
    -- Draw button border
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
    
    -- Check if this is the reset button (no text)
    if button == MobileUI.resetButton then
        -- Draw reset icon from the PNG image
        love.graphics.setColor(1, 1, 1, 1)
        
        -- Calculate icon dimensions and position
        local iconSize = button.width * 0.7
        local centerX = button.x + button.width / 2
        local centerY = button.y + button.height / 2
        
        -- Draw the reset icon image
        if MobileUI.resetIcon then
            local imgWidth = MobileUI.resetIcon:getWidth()
            local imgHeight = MobileUI.resetIcon:getHeight()
            local scale = iconSize / math.max(imgWidth, imgHeight)
            
            love.graphics.draw(
                MobileUI.resetIcon,
                centerX,
                centerY,
                0,  -- rotation (0 = no rotation)
                scale,
                scale,
                imgWidth / 2,  -- origin X (center of image)
                imgHeight / 2   -- origin Y (center of image)
            )
        end
    else
        -- Draw button text (for other buttons)
        love.graphics.setColor(1, 1, 1, 1)
        local textWidth = love.graphics.getFont():getWidth(button.text)
        local textHeight = love.graphics.getFont():getHeight()
        love.graphics.print(
            button.text,
            button.x + (button.width - textWidth) / 2,
            button.y + (button.height - textHeight) / 2
        )
    end
    
    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Handle mouse press
function MobileUI.handleMousePressed(x, y, button, game)
    -- Only handle left mouse button
    if button ~= 1 then
        return false
    end
    
    -- Check if click is on reset button
    if MobileUI.isPointInButton(x, y, MobileUI.resetButton) and MobileUI.resetButton.visible then
        return MobileUI.resetButton.action(game)
    end
    
    -- Check if click is on any ball button
    for _, btn in ipairs(MobileUI.ballButtons) do
        if MobileUI.isPointInButton(x, y, btn) and btn.visible then
            -- Allow ball switching in PLAY mode if the ball type is available
            if game.currentMode == game.MODES.PLAY and UI.availableBalls and UI.availableBalls[btn.ballType] then
                -- Change the ball type
                game.currentBallType = btn.ballType
                local newBall = Balls.changeBallType(game.ball, game.world, game.currentBallType)
                if game.ball and game.ball.body then game.ball.body:destroy() end
                game.ball = newBall
                if game.ball and game.ball.body then game.ball.body:setUserData(game.ball) end
                -- Get the ball type name for logging
                local ballTypeToName = {
                    [Balls.TYPES.STANDARD] = "Standard",
                    [Balls.TYPES.HEAVY] = "Heavy",
                    [Balls.TYPES.EXPLODING] = "Exploding",
                    [Balls.TYPES.STICKY] = "Sticky",
                    [Balls.TYPES.SPRAYING] = "Spraying"
                }
                local ballName = ballTypeToName[btn.ballType] or "Unknown"
                print("Switched to " .. ballName .. " Ball in PLAY mode")
                return true -- Ball type was changed
            elseif game.currentMode == game.MODES.SANDBOX or game.testPlayMode then
                return btn.action(game)
            end
        end
    end
    
    return false
end

-- Handle touch press
function MobileUI.handleTouchPressed(id, x, y, game)
    -- Check if touch is on reset button
    if MobileUI.isPointInButton(x, y, MobileUI.resetButton) and MobileUI.resetButton.visible then
        return MobileUI.resetButton.action(game)
    end
    
    -- Check if touch is on any ball button
    for _, btn in ipairs(MobileUI.ballButtons) do
        if MobileUI.isPointInButton(x, y, btn) and btn.visible then
            -- Allow ball switching in PLAY mode if the ball type is available
            if game.currentMode == game.MODES.PLAY and UI.availableBalls and UI.availableBalls[btn.ballType] then
                -- Change the ball type
                game.currentBallType = btn.ballType
                local newBall = Balls.changeBallType(game.ball, game.world, game.currentBallType)
                if game.ball and game.ball.body then game.ball.body:destroy() end
                game.ball = newBall
                if game.ball and game.ball.body then game.ball.body:setUserData(game.ball) end
                -- Get the ball type name for logging
                local ballTypeToName = {
                    [Balls.TYPES.STANDARD] = "Standard",
                    [Balls.TYPES.HEAVY] = "Heavy",
                    [Balls.TYPES.EXPLODING] = "Exploding",
                    [Balls.TYPES.STICKY] = "Sticky",
                    [Balls.TYPES.SPRAYING] = "Spraying"
                }
                local ballName = ballTypeToName[btn.ballType] or "Unknown"
                print("Switched to " .. ballName .. " Ball in PLAY mode (touch)")
                return true -- Ball type was changed
            elseif game.currentMode == game.MODES.SANDBOX or game.testPlayMode then
                return btn.action(game)
            end
        end
    end
    
    -- Check for triple tap (for reset)
    local currentTime = love.timer.getTime()
    if currentTime - MobileUI.lastTapTime < MobileUI.tapTimeThreshold then
        MobileUI.tapCount = MobileUI.tapCount + 1
        if MobileUI.tapCount >= 3 then
            -- Triple tap detected - reset
            if game.ball then
                -- Instead of calling love.load() which goes back to the menu,
                -- reinitialize the current game mode to reset the level
                local currentMode = game.currentMode
                local Menu = require("src.menu")
                
                if currentMode == game.MODES.PLAY then
                    -- In PLAY mode, reinitialize with the current level
                    game.init(currentMode, Menu.currentLevel)
                else
                    -- In SANDBOX or TEST_PLAY mode, just reinitialize the current mode
                    game.init(currentMode)
                end
                
                game.gameWon = false
                game.winMessageTimer = 0
                MobileUI.tapCount = 0
                return true -- Reset was performed
            end
        end
    else
        -- Too much time has passed, reset tap count
        MobileUI.tapCount = 1
    end
    MobileUI.lastTapTime = currentTime
    
    return false
end

-- Handle touch release
function MobileUI.handleTouchReleased(id, x, y, game)
    return false
end

-- Check if a point is inside a button
function MobileUI.isPointInButton(x, y, button)
    return x >= button.x and x <= button.x + button.width and
           y >= button.y and y <= button.y + button.height
end

return MobileUI
