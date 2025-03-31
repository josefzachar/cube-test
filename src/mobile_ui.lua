-- mobile_ui.lua - Mobile-friendly UI components and scaling

local UI = require("src.ui")

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
                game.ball:reset()
                game.gameWon = false
                game.winMessageTimer = 0
                return true -- Reset was performed
            end
            return false
        end
    }
    
    -- Reset button is the only button we need now
end

-- Update mobile UI
function MobileUI.update(game, dt)
    -- Update button position on window resize
    MobileUI.resetButton.x = love.graphics.getWidth() - 120
    MobileUI.resetButton.y = love.graphics.getHeight() - 120
    
    -- Update button visibility
    MobileUI.resetButton.visible = game.ball and not game.ball:isMoving()
    
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
    
    -- Restore original font
    love.graphics.setFont(originalFont)
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

-- Handle touch press
function MobileUI.handleTouchPressed(id, x, y, game)
    -- Check if touch is on reset button
    if MobileUI.isPointInButton(x, y, MobileUI.resetButton) and MobileUI.resetButton.visible then
        return MobileUI.resetButton.action(game)
    end
    
    -- Check for triple tap (for reset)
    local currentTime = love.timer.getTime()
    if currentTime - MobileUI.lastTapTime < MobileUI.tapTimeThreshold then
        MobileUI.tapCount = MobileUI.tapCount + 1
        if MobileUI.tapCount >= 3 then
            -- Triple tap detected - reset
            if game.ball then
                game.ball:reset()
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
