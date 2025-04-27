-- mobile_ui.lua - Mobile-friendly UI components and scaling

local UI = require("src.ui")
local Balls = require("src.balls")

local MobileUI = {}

-- UI scaling factors
MobileUI.buttonScale = 1.5 -- Make buttons larger for touch
MobileUI.fontScale = 1.2   -- Make text larger for readability
MobileUI.spacing = 20      -- Spacing between UI elements

-- Initialize mobile UI
function MobileUI.init()
    -- Make sure the base UI is initialized
    if not UI.initialized then
        UI.init()
        UI.initialized = true
    end
    
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
    
    -- Reset button (visible when ball is not moving)
    MobileUI.resetButton = {
        x = love.graphics.getWidth() - 120,
        y = love.graphics.getHeight() - 120,
        width = 100,
        height = 100,
        text = "RESET",
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
    local buttonSize = 80 -- Square buttons for touch
    local buttonSpacing = 10
    local leftMargin = 20
    local bottomMargin = 20
    
    -- Ball type names and colors
    local ballTypes = {
        { name = "STD", type = Balls.TYPES.STANDARD, color = {1, 1, 1, 1} },
        { name = "HVY", type = Balls.TYPES.HEAVY, color = {0.6, 0.6, 0.8, 1} },
        { name = "EXP", type = Balls.TYPES.EXPLODING, color = {1, 0.4, 0.2, 1} },
        { name = "STK", type = Balls.TYPES.STICKY, color = {0.3, 0.8, 0.3, 1} },
        { name = "SPR", type = Balls.TYPES.SPRAYING, color = {0.9, 0.8, 0.3, 1} }
    }
    
    MobileUI.ballButtons = {}
    
    for i, ballInfo in ipairs(ballTypes) do
        local button = {
            x = leftMargin,
            y = love.graphics.getHeight() - bottomMargin - (buttonSize + buttonSpacing) * i,
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
                    print("Switched to " .. ballInfo.name .. " Ball")
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
    -- Update button position on window resize
    MobileUI.resetButton.x = love.graphics.getWidth() - 120
    MobileUI.resetButton.y = love.graphics.getHeight() - 120
    
    -- Update button visibility
    MobileUI.resetButton.visible = game.ball and not game.ball:isMoving()
    
    -- Update ball button positions
    local buttonSize = 80
    local buttonSpacing = 10
    local leftMargin = 20
    local bottomMargin = 20
    
    for i, button in ipairs(MobileUI.ballButtons) do
        button.x = leftMargin
        button.y = love.graphics.getHeight() - bottomMargin - (buttonSize + buttonSpacing) * i
        
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
    
    -- Draw pinch-to-zoom hint
    love.graphics.setColor(1, 1, 1, 0.7)
    local zoomHint = "Pinch to zoom"
    local zoomHintWidth = love.graphics.getFont():getWidth(zoomHint)
    love.graphics.print(zoomHint, love.graphics.getWidth() - zoomHintWidth - 20, 20)
    
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
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 10, 10)
    
    -- Draw button border (thicker for selected button)
    if isSelected then
        love.graphics.setLineWidth(3)
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 0.8)
    end
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 10, 10)
    love.graphics.setLineWidth(1)
    
    -- Draw ball representation (colored square)
    love.graphics.setColor(color)
    local ballSize = button.width * 0.4
    love.graphics.rectangle("fill", 
        button.x + (button.width - ballSize) / 2, 
        button.y + (button.height - ballSize) / 2 - 10, 
        ballSize, ballSize)
    
    -- Draw button text below the ball
    love.graphics.setColor(1, 1, 1, 1)
    local textWidth = love.graphics.getFont():getWidth(button.text)
    local textHeight = love.graphics.getFont():getHeight()
    love.graphics.print(
        button.text,
        button.x + (button.width - textWidth) / 2,
        button.y + button.height - textHeight - 5
    )
    
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
    love.graphics.rectangle("fill", button.x, button.y, button.width, button.height, 10, 10)
    
    -- Draw button border
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.rectangle("line", button.x, button.y, button.width, button.height, 10, 10)
    
    -- Draw button text
    love.graphics.setColor(1, 1, 1, 1)
    local textWidth = love.graphics.getFont():getWidth(button.text)
    local textHeight = love.graphics.getFont():getHeight()
    love.graphics.print(
        button.text,
        button.x + (button.width - textWidth) / 2,
        button.y + (button.height - textHeight) / 2
    )
    
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
                print("Switched to " .. btn.text .. " Ball in PLAY mode")
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
                print("Switched to " .. btn.text .. " Ball in PLAY mode (touch)")
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
