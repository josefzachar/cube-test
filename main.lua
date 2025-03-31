-- Square Golf Game
-- A simple golf game where the ball is a square and the level is made of cells

-- Load core modules
local Game = require("src.game")
local Menu = require("src.menu")
local Draw = require("src.draw")
local Editor = require("src.editor")
local TouchInput = require("src.touch_input")
local MobileUI = require("src.mobile_ui")
local MobileOptimizations = require("src.mobile_optimizations")

-- Enable mobile features by default on all platforms
local isMobile = true

-- Option to disable mobile features with 'D' key
if love.keyboard.isDown("d") then
    isMobile = false
    print("Desktop mode forced (mobile features disabled)")
else
    print("Mobile features enabled by default")
end

-- FPS counter for performance monitoring
local fpsCounter = {
    value = 0,
    timer = 0,
    frames = 0
}

function love.load()
    -- Initialize the menu
    Menu.init()
    Menu.active = true
    Game.currentMode = Game.MODES.MENU
    
    -- Initialize the game in sandbox mode (default)
    Game.init(Game.MODES.SANDBOX)
    
    -- Initialize mobile features if on mobile
    if isMobile then
        Game.touchInput = TouchInput.new()
        print("Mobile device detected, touch input enabled")
        
        -- Initialize mobile UI
        MobileUI.init()
        Game.mobileUI = MobileUI
        
        -- Initialize mobile optimizations
        MobileOptimizations.enabled = true
        MobileOptimizations.init()
        Game.mobileOptimizations = MobileOptimizations
        
        -- Apply mobile-specific physics optimizations
        if Game.world then
            MobileOptimizations.optimizePhysics(Game.world)
        end
    end
end

function love.update(dt)
    -- Update FPS counter
    fpsCounter.frames = fpsCounter.frames + 1
    fpsCounter.timer = fpsCounter.timer + dt
    if fpsCounter.timer >= 1 then
        fpsCounter.value = fpsCounter.frames
        fpsCounter.frames = 0
        fpsCounter.timer = fpsCounter.timer - 1
    end
    
    -- Update the game
    Game.update(dt)
    
    -- Update mobile features if on mobile
    if isMobile then
        -- Update touch input
        if Game.touchInput then
            Game.touchInput:update(Game.ball, Game.level, dt)
        end
        
        -- Update mobile UI
        if Game.mobileUI and not Menu.active and not Editor.active then
            Game.mobileUI.update(Game, dt)
        end
        
        -- Apply dynamic performance adjustments based on FPS
        if Game.mobileOptimizations then
            -- Get update frequency based on current FPS
            local updateFrequency = Game.mobileOptimizations.getUpdateFrequency(fpsCounter.value)
            
            -- Store update frequency for use in other modules
            Game.updateFrequency = updateFrequency
        end
    end
end

function love.keypressed(key)
    -- Handle key presses
    Game.handleKeyPressed(key)
end

function love.textinput(text)
    -- If editor is active, handle editor text input
    if Editor.active then
        Editor.handleTextInput(text)
    end
end

function love.draw()
    -- Apply mobile rendering optimizations
    if isMobile and Game.mobileOptimizations then
        Game.mobileOptimizations.optimizeRendering()
    end
    
    -- Draw the game
    Draw.draw(Game)
    
    -- Draw mobile features if on mobile
    if isMobile and not Menu.active and not Editor.active then
        -- Draw touch input overlay
        if Game.touchInput then
            Game.touchInput:draw(Game.ball, Game.attempts)
        end
        
        -- Draw mobile UI
        if Game.mobileUI then
            Game.mobileUI.draw(Game)
        end
        
        -- Draw FPS counter in debug mode
        if Game.debug then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("FPS: " .. fpsCounter.value, 10, love.graphics.getHeight() - 20)
        end
    end
end

function love.mousepressed(x, y, button)
    -- Handle mouse presses
    Game.handleMousePressed(x, y, button)
end

function love.mousereleased(x, y, button)
    -- Handle mouse releases
    Game.handleMouseReleased(x, y, button)
end

function love.wheelmoved(x, y)
    -- Handle mouse wheel movement
    Game.handleMouseWheel(x, y)
end

function love.resize(width, height)
    -- Handle window resize
    -- This is important to refresh UI and cursor position after resizing
    if Editor.active then
        -- Recreate UI elements to adjust to new window size
        local EditorUI = require("src.editor.ui")
        EditorUI.createUI()
    end
    
    -- Update UI scaling for mobile
    if isMobile then
        -- Recalculate UI scaling factors
        GAME_SCALE = math.min(width / Game.ORIGINAL_WIDTH, height / Game.ORIGINAL_HEIGHT)
        GAME_OFFSET_X = (width / GAME_SCALE - Game.ORIGINAL_WIDTH) / 2
        GAME_OFFSET_Y = (height / GAME_SCALE - Game.ORIGINAL_HEIGHT) / 2
    end
end

-- Touch event callbacks for mobile devices
function love.touchpressed(id, x, y, dx, dy, pressure)
    if isMobile then
        -- If menu is active, handle menu touch presses
        if Game.currentMode == Game.MODES.MENU then
            local result = Menu.handleMousePressed(x, y, 1) -- Treat as left mouse button
            if result and type(result) == "table" then
                if result.action == "play" then
                    Game.currentMode = Game.MODES.PLAY
                    Game.init(Game.MODES.PLAY, result.level)
                elseif result.action == "editor" then
                    Game.currentMode = Game.MODES.EDITOR
                    Game.init(Game.MODES.SANDBOX)
                    Editor.active = true
                elseif result.action == "sandbox" then
                    Game.currentMode = Game.MODES.SANDBOX
                    Game.init(Game.MODES.SANDBOX)
                end
            end
            return
        end
        
        -- If editor is active, handle editor touch presses
        if Editor.active then
            Editor.handleMousePressed(x, y, 1) -- Treat as left mouse button
            return
        end
        
        -- Check if we're in the win screen
        if Game.gameWon and Game.winMessageTimer > 0 then
            -- Get screen dimensions
            local screenWidth, screenHeight = love.graphics.getDimensions()
            
            -- Button dimensions
            local windowWidth = 600
            local windowHeight = 400
            local windowX = (screenWidth - windowWidth) / 2
            local windowY = (screenHeight - windowHeight) / 2
            local buttonWidth = 200
            local buttonHeight = 50
            local buttonX = windowX + (windowWidth - buttonWidth) / 2
            local buttonY = windowY + windowHeight - buttonHeight - 40
            
            -- Check if touch is on the continue button
            if x >= buttonX and x <= buttonX + buttonWidth and
               y >= buttonY and y <= buttonY + buttonHeight then
                if Game.testPlayMode then
                    -- Return to editor
                    local Editor = require("src.editor")
                    Editor.returnFromTestPlay()
                    Game.testPlayMode = false
                    return
                else
                    -- Increase difficulty if not at max
                    if currentDifficulty < 5 then
                        currentDifficulty = currentDifficulty + 1
                        print("Difficulty increased to:", currentDifficulty)
                    end
                    
                    -- Reload the level with the next level number
                    if Game.currentMode == Game.MODES.PLAY then
                        Game.init(Game.currentMode, Menu.currentLevel)
                    else
                        Game.init(Game.currentMode)
                    end
                    return
                end
            end
            
            return -- Don't process other touches when win screen is active
        end
        
        -- Check if mobile UI handled the touch
        if Game.mobileUI and Game.mobileUI.handleTouchPressed(id, x, y, Game) then
            return -- Mobile UI handled the press
        end
        
        -- Get UI module
        local UI = require("src.ui")
        
        -- Check if UI handled the touch
        if UI.handlePress(x, y) then
            return -- UI handled the press, don't process further
        end
        
        -- Otherwise, let the touch input system handle it
        if Game.touchInput and Game.touchInput:handleTouchPressed(id, x, y, Game.ball, Game.level) then
            Game.attempts = Game.attempts + 1
        end
    end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    if isMobile and Game.touchInput then
        Game.touchInput:handleTouchMoved(id, x, y)
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    if isMobile then
        -- Check if mobile UI handled the touch release
        if Game.mobileUI and Game.mobileUI.handleTouchReleased(id, x, y, Game) then
            return -- Mobile UI handled the release
        end
        
        -- Otherwise, let the touch input system handle it
        if Game.touchInput and Game.touchInput:handleTouchReleased(id, x, y, Game.ball) then
            Game.attempts = Game.attempts + 1
        end
    end
end

-- Global function to create a diamond-shaped win hole (used by debug.lua)
_G.createDiamondWinHole = function(level)
    local WinHoleGenerator = require("src.win_hole_generator")
    WinHoleGenerator.createDiamondWinHole(level, nil, nil, 20, 20)
end

-- Function to convert screen coordinates to game coordinates
function screenToGameCoords(screenX, screenY)
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Calculate scale factors
    local scaleX = width / Game.ORIGINAL_WIDTH
    local scaleY = height / Game.ORIGINAL_HEIGHT
    local scale = math.min(scaleX, scaleY)
    
    -- Ensure minimum scale to prevent rendering issues
    scale = math.max(scale, 0.5) -- Minimum scale factor of 0.5
    
    -- Calculate offsets for centering
    local scaledWidth = width / scale
    local scaledHeight = height / scale
    local offsetX = (scaledWidth - Game.ORIGINAL_WIDTH) / 2
    local offsetY = (scaledHeight - Game.ORIGINAL_HEIGHT) / 2
    
    -- Convert screen coordinates to game coordinates
    local gameX = (screenX / scale) - offsetX
    local gameY = (screenY / scale) - offsetY
    
    return gameX, gameY
end
