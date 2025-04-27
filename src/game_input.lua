-- src/game_input.lua - Handles all game input processing

local Menu = require("src.menu")
local Editor = require("src.editor")
local Balls = require("src.balls")
local Debug = require("src.debug")
local Fire = require("src.fire")
local WinHole = require("src.win_hole")
local CellTypes = require("src.cell_types")
local Camera = require("src.camera")
local UI = require("src.ui")
local InputUtils = require("src.input_utils")
local Collision = require("src.collision") -- Needed for explode -> sandToConvert

local GameInput = {}

-- Function to convert screen coordinates to game coordinates
function GameInput.screenToGameCoords(screenX, screenY)
    return InputUtils.screenToGameCoords(screenX, screenY)
end

-- Handle key presses
function GameInput.handleKeyPressed(Game, key)
    -- If menu is active, handle menu key presses
    if Game.currentMode == Game.MODES.MENU then
        local result = Menu.handleKeyPressed(key)
        if result and type(result) == "table" then
            if result.action == "play" then
                Game.currentMode = Game.MODES.PLAY
                Game.init(Game.MODES.PLAY, result.level) -- Call wrapper correctly
            elseif result.action == "editor" then
                Game.currentMode = Game.MODES.EDITOR
                Game.init(Game.MODES.SANDBOX) -- Call wrapper correctly
                Editor.active = true
            elseif result.action == "sandbox" then
                Game.currentMode = Game.MODES.SANDBOX
                Game.init(Game.MODES.SANDBOX) -- Call wrapper correctly
            end
        end
        return
    end

    -- Return to menu with Escape key
    if key == "escape" and not Editor.active then
        if Game.testPlayMode then
            -- Return to editor
            Editor.returnFromTestPlay()
            Game.testPlayMode = false
        else
            Game.currentMode = Game.MODES.MENU
            Menu.active = true
            Menu.refreshLevelCount() -- Refresh level count in case new levels were created
        end
        return
    end

    -- Toggle editor mode with F12
    if key == "f12" then
        Editor.active = not Editor.active
        return
    end
    
    -- Zoom controls (available in all modes except menu)
    if key == "=" or key == "+" then
        -- Increase zoom level
        Game.increaseZoom()
        return
    elseif key == "-" then
        -- Decrease zoom level
        Game.decreaseZoom()
        return
    elseif key == "0" then
        -- Reset zoom level to default
        Game.resetZoom()
        return
    end

    -- If editor is active, handle editor key presses
    if Editor.active then
        Editor.handleKeyPressed(key)
        return
    end

    -- In PLAY mode, only allow standard ball and reset
    if Game.currentMode == Game.MODES.PLAY then
        if Game.input:handleKeyPressed(key, Game.ball) then
            -- Reset was performed
            Game.gameWon = false
            Game.winMessageTimer = 0
        end
        return
    end

    -- If in test play mode and 'r' key is pressed, return to editor
    if Game.testPlayMode and key == "r" then
        -- Return to editor
        Editor.returnFromTestPlay()
        Game.testPlayMode = false
        return
    end

    -- In SANDBOX or TEST_PLAY mode, allow all features
    -- Handle ball type switching
    if key == "1" then
        Game.currentBallType = Balls.TYPES.STANDARD
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        if Game.ball and Game.ball.body then Game.ball.body:destroy() end
        Game.ball = newBall
        if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end
        print("Switched to Standard Ball")
    elseif key == "2" then
        Game.currentBallType = Balls.TYPES.HEAVY
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        if Game.ball and Game.ball.body then Game.ball.body:destroy() end
        Game.ball = newBall
        if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end
        print("Switched to Heavy Ball")
    elseif key == "3" then
        Game.currentBallType = Balls.TYPES.EXPLODING
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        if Game.ball and Game.ball.body then Game.ball.body:destroy() end
        Game.ball = newBall
        if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end
        print("Switched to Exploding Ball")
    elseif key == "4" then
        Game.currentBallType = Balls.TYPES.STICKY
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        if Game.ball and Game.ball.body then Game.ball.body:destroy() end
        Game.ball = newBall
        if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end
        print("Switched to Sticky Ball")
    elseif key == "5" then
        Game.currentBallType = Balls.TYPES.SPRAYING
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        if Game.ball and Game.ball.body then Game.ball.body:destroy() end
        Game.ball = newBall
        if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end
        print("Switched to Spraying Ball")
    elseif key == "m" then
        -- Cycle through material types for the spraying ball
        if Game.ball.ballType == Balls.TYPES.SPRAYING and Game.ball.cycleMaterial then
            Game.ball:cycleMaterial()
        else
            print("Material cycling only works with the Spraying Ball")
        end
    elseif key == "e" then
        -- Always switch to exploding ball and trigger explosion immediately
        if Game.ball.ballType ~= Balls.TYPES.EXPLODING then
            -- Switch to exploding ball first
            Game.currentBallType = Balls.TYPES.EXPLODING
            local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
            if Game.ball and Game.ball.body then Game.ball.body:destroy() end
            Game.ball = newBall
            if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end
            print("Switched to Exploding Ball")
        end

        -- Trigger explosion
        if Game.ball and Game.ball.explode then
            local result = Game.ball:explode(Game.level, Collision.sandToConvert)
            if result then
                print("Exploded!")

                -- Check if we should switch to standard ball
                if result == "switch_to_standard" then
                    Game.currentBallType = Balls.TYPES.STANDARD
                    local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
                    if Game.ball and Game.ball.body then Game.ball.body:destroy() end
                    Game.ball = newBall
                    if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end
                    print("Switched to Standard Ball after explosion")
                end
            end
        end
    elseif Game.input:handleKeyPressed(key, Game.ball) then
        -- Reset was performed
        Game.gameWon = false
        Game.winMessageTimer = 0

        -- Reset camera to follow the ball at its new position
        if Game.ball then
            local ballX, ballY = Game.ball:getPosition()
            Camera.init(ballX, ballY)
        end
    else
        local result = Debug.handleKeyPressed(key, Game.level)
        if result == true then
            -- Toggle debug mode
            Game.debug = not Game.debug
        elseif result == "sand_pile" then
            -- Add a sand pile
            if Game.ball then
                local x, y = Game.ball.body:getPosition()
                local gridX, gridY = Game.level:getGridCoordinates(x, y)
                Game.level:addSandPile(gridX, gridY, 10, 20)
                print("Added a sand pile at ball position")
            end
        elseif result == "dirt_block" then
            -- Add a dirt block
            if Game.ball then
                local x, y = Game.ball.body:getPosition()
                local gridX, gridY = Game.level:getGridCoordinates(x, y)
                Game.level:addDirtBlock(gridX, gridY, 5, 5)
                print("Added a dirt block at ball position")
            end
        elseif result == "water_pool" then
            -- Add a water pool
            if Game.ball then
                local x, y = Game.ball.body:getPosition()
                local gridX, gridY = Game.level:getGridCoordinates(x, y)
                Game.level:addWaterPool(gridX, gridY, 10, 3)
                print("Added a water pool at ball position")
            end
        elseif key == "f" then
            -- Add fire at ball position
            if Game.ball then
                local x, y = Game.ball.body:getPosition()
                local gridX, gridY = Game.level:getGridCoordinates(x, y)

                -- Create a small cluster of fire for better visibility
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        local fireX = gridX + dx
                        local fireY = gridY + dy

                        -- Only place fire in empty cells
                        if fireX >= 0 and fireX < Game.level.width and
                           fireY >= 0 and fireY < Game.level.height and
                           Game.level:getCellType(fireX, fireY) == CellTypes.TYPES.EMPTY then
                            Fire.createFire(Game.level, fireX, fireY)
                        end
                    end
                end
                print("Added fire at ball position")
            end
        elseif key == "h" then
            -- Add a win hole at ball position
            if Game.ball then
                local x, y = Game.ball.body:getPosition()
                local gridX, gridY = Game.level:getGridCoordinates(x, y)
                WinHole.createWinHoleArea(Game.level, gridX, gridY, 3, 3)
                print("Added a win hole at ball position")
            end
        end
    end
end

-- Handle mouse press
function GameInput.handleMousePressed(Game, x, y, button)
    -- If menu is active, handle menu mouse presses
    if Game.currentMode == Game.MODES.MENU then
        local result = Menu.handleMousePressed(x, y, button)
        if result and type(result) == "table" then
            if result.action == "play" then
                Game.currentMode = Game.MODES.PLAY
                Game.init(Game.MODES.PLAY, result.level) -- Call wrapper correctly
            elseif result.action == "editor" then
                Game.currentMode = Game.MODES.EDITOR
                Game.init(Game.MODES.SANDBOX) -- Call wrapper correctly
                Editor.active = true
            elseif result.action == "sandbox" then
                Game.currentMode = Game.MODES.SANDBOX
                Game.init(Game.MODES.SANDBOX) -- Call wrapper correctly
            end
        end
        return
    end

    -- If editor is active, handle editor mouse presses
    if Editor.active then
        Editor.handleMousePressed(x, y, button)
        return
    end

    -- Check if we're in the win screen
    if Game.gameWon and Game.winMessageTimer > 0 then
        -- Get screen dimensions
        local screenWidth, screenHeight = love.graphics.getDimensions()

        -- Button dimensions (assuming these are defined or calculated elsewhere if needed)
        local windowWidth = 600
        local windowHeight = 400
        local windowX = (screenWidth - windowWidth) / 2
        local windowY = (screenHeight - windowHeight) / 2
        local buttonWidth = 200
        local buttonHeight = 50
        local buttonX = windowX + (windowWidth - buttonWidth) / 2
        local buttonY = windowY + windowHeight - buttonHeight - 40

        -- Check if click is on the continue button
        if x >= buttonX and x <= buttonX + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight then
            if Game.testPlayMode then
                -- Return to editor
                Editor.returnFromTestPlay()
                Game.testPlayMode = false
                return
            else
                -- Increase difficulty if not at max
                if currentDifficulty < 5 then
                    currentDifficulty = currentDifficulty + 1
                    print("Difficulty increased to:", currentDifficulty)
                end

                -- Reload the level with the next level number or current mode
                if Game.currentMode == Game.MODES.PLAY then
                    Game.init(Game, Game.currentMode, Menu.currentLevel) -- Pass Game object
                else
                    Game.init(Game, Game.currentMode) -- Pass Game object
                end
                return
            end
        end

        return -- Don't process other clicks when win screen is active
    end

    -- Check if mobile UI handled the mouse press
    if Game.mobileUI and Game.mobileUI.handleMousePressed(x, y, button, Game) then
        return -- Mobile UI handled the press, don't process further
    end
    
    -- Check if UI handled the mouse press
    if UI.handlePress(x, y) then
        return -- UI handled the press, don't process further
    end

    -- Convert screen coordinates to game coordinates
    local gameX, gameY = GameInput.screenToGameCoords(x, y)

    -- Otherwise, let the input system handle it with converted coordinates
    if Game.input and Game.input.handleMousePressed then
        if Game.input:handleMousePressed(button, Game.ball, gameX, gameY) then
            Game.attempts = Game.attempts + 1
        end
    end
end

-- Handle mouse release
function GameInput.handleMouseReleased(Game, x, y, button)
    -- If menu is active, don't handle game mouse releases
    if Game.currentMode == Game.MODES.MENU then
        return
    end

    -- If editor is active, handle editor mouse releases
    if Editor.active then
        Editor.handleMouseReleased(x, y, button)
        return
    end

    -- Convert screen coordinates to game coordinates
    local gameX, gameY = GameInput.screenToGameCoords(x, y)

    if Game.input and Game.input.handleMouseReleased then
        if Game.input:handleMouseReleased(button, Game.ball, gameX, gameY) then
            Game.attempts = Game.attempts + 1
        end
    end
end

-- Handle key releases
function GameInput.handleKeyReleased(Game, key)
    -- If menu is active, don't handle game key releases
    if Game.currentMode == Game.MODES.MENU then
        return
    end

    -- If editor is active, handle editor key releases
    if Editor.active then
        Editor.handleKeyReleased(key)
        return
    end

    -- In the future, we could add key release handling for the game itself
end

-- Handle mouse wheel
function GameInput.handleMouseWheel(Game, x, y)
    -- If menu is active, handle menu mouse wheel
    if Game.currentMode == Game.MODES.MENU then
        Menu.handleMouseWheel(x, y)
        return
    end

    -- If editor is active, handle editor mouse wheel
    if Editor.active then
        Editor.handleMouseWheel(x, y)
        return
    end

    -- Use mouse wheel for zooming
    if y > 0 then
        -- Scroll up - zoom in
        Game.increaseZoom()
    elseif y < 0 then
        -- Scroll down - zoom out
        Game.decreaseZoom()
    end
end


return GameInput
