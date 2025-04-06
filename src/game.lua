-- game.lua - Core game initialization and state management

local Balls = require("src.balls")
local Cell = require("cell")
local Level = require("level")
local Input = require("input")
local Collision = require("src.collision")
local Effects = require("src.effects")
local Debug = require("src.debug")
local CellTypes = require("src.cell_types")
local Fire = require("src.fire")
local WinHole = require("src.win_hole")
local UI = require("src.ui")
local Sound = require("src.sound")
local Editor = require("src.editor")
local Menu = require("src.menu")
local WinHoleGenerator = require("src.win_hole_generator")
local Camera = require("src.camera")

-- Game state
local Game = {
    -- Game variables
    world = nil,
    ball = nil,
    level = nil,
    input = nil,
    attempts = 0,
    debug = false, -- Set to true to see physics bodies
    currentBallType = Balls.TYPES.STANDARD, -- Start with standard ball
    gameWon = false, -- Flag to track if the player has won
    winMessageTimer = 0, -- Timer for displaying the win message
    testPlayMode = false, -- Flag to track if we're in test play mode
    
    -- Game modes
    MODES = {
        MENU = "menu",
        PLAY = "play",
        EDITOR = "editor",
        SANDBOX = "sandbox",
        TEST_PLAY = "test_play"
    },
    currentMode = nil,
    
    -- Colors
    WHITE = {1, 1, 1, 1},
    
    -- Background colors for gradient
    BACKGROUND_COLOR = {0.2, 0.3, 0.6, 1.0}, -- Dark blue (base color)
    BACKGROUND_COLOR_TOP = {0.1, 0.2, 0.4, 1.0}, -- Darker blue for top
    BACKGROUND_COLOR_BOTTOM = {0.3, 0.4, 0.7, 1.0} -- Lighter blue for bottom
}

-- Global difficulty level (1-5)
currentDifficulty = 1

-- Make these global so they can be accessed from other modules
GAME_SCALE = 1
GAME_OFFSET_X = 0
GAME_OFFSET_Y = 0

    -- Initialize the game
function Game.init(mode, levelNumber)
    -- Initialize sound system
    Sound.load()
    
    -- Reset camera
    Camera.reset()
    
    -- Set up the physics world with gravity
    Game.world = love.physics.newWorld(0, 9.81 * 64, true)
    
    -- Set up collision callbacks
    Game.world:setCallbacks(
        function(a, b, coll) Collision.beginContact(a, b, coll, Game.level, Game.ball) end,
        function(a, b, coll) Collision.endContact(a, b, coll, Game.level) end,
        Collision.preSolve,
        Collision.postSolve
    )
    
    -- If we're in test play mode, we should already have a level set by the editor
    -- So we don't need to create a new one or modify the existing one
    if Game.testPlayMode then
        print("Test play mode - using editor level with dimensions: " .. Game.level.width .. "x" .. Game.level.height)
        
        -- Create the square ball at the starting position
        local Editor = require("src.editor")
        Game.ball = Balls.createBall(Game.world, Editor.startX * Cell.SIZE, Editor.startY * Cell.SIZE, Game.currentBallType)
        
        -- Set the ball as the user data for the ball body
        Game.ball.body:setUserData(Game.ball)
        
        -- In test play mode, all balls are available
        UI.availableBalls = {
            [Balls.TYPES.STANDARD] = true,
            [Balls.TYPES.HEAVY] = true,
            [Balls.TYPES.EXPLODING] = true,
            [Balls.TYPES.STICKY] = true,
            [Balls.TYPES.SPRAYING] = true
        }
        
        -- Initialize camera with ball position
        local ballX, ballY = Game.ball:getPosition()
        Camera.init(ballX, ballY)
        
        -- Note: Camera scaling is now completely disabled in camera.lua
        -- to ensure cells are always displayed at their original size (10px)
        
        -- Create input handler
        Game.input = Input.new()
        
        -- Reset game state
        Game.gameWon = false
        Game.winMessageTimer = 0
        Game.attempts = 0
        
        -- Initialize editor
        Editor.init(Game.level, Game.world)
        
        -- Initialize UI
        if not UI.initialized then
            -- Set up UI callbacks
            UI.onBallTypeChange = function(ballTypeIndex)
                local ballTypes = {
                    Balls.TYPES.STANDARD,
                    Balls.TYPES.HEAVY,
                    Balls.TYPES.EXPLODING,
                    Balls.TYPES.STICKY,
                    Balls.TYPES.SPRAYING
                }
                
                Game.currentBallType = ballTypes[ballTypeIndex]
                local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
                Game.ball.body:destroy() -- Destroy old ball's body
                Game.ball = newBall
                Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
                
                local ballTypeNames = {"Standard", "Heavy", "Exploding", "Sticky", "Spraying"}
                print("Switched to " .. ballTypeNames[ballTypeIndex] .. " Ball")
            end
            
            UI.onAddWinHole = function()
                local x, y = Game.ball.body:getPosition()
                local gridX, gridY = Game.level:getGridCoordinates(x, y)
                WinHole.createWinHoleArea(Game.level, gridX, gridY, 3, 3)
                print("Added a win hole at ball position")
            end
            
            UI.init()
            UI.initialized = true
        end
        
        return
    end
    
    if mode == Game.MODES.PLAY then
        -- Load the specified level
        local levelData = Menu.loadLevel(levelNumber)
        if levelData then
            -- Always use the dimensions from the level file, no fallbacks
            local levelWidth = tonumber(levelData.width)
            local levelHeight = tonumber(levelData.height)
            
            if not levelWidth or not levelHeight then
                print("ERROR: Invalid level dimensions in level file: width=" .. tostring(levelData.width) .. ", height=" .. tostring(levelData.height))
                -- Use reasonable defaults if dimensions are invalid
                levelWidth = 160
                levelHeight = 100
            end
            
            print("Using level file dimensions: " .. levelWidth .. "x" .. levelHeight)
            Game.level = Level.new(Game.world, levelWidth, levelHeight)
            
            -- Set level properties
            local cellCount = 0
            local height = tonumber(levelData.height) or 100
            local width = tonumber(levelData.width) or 160
            
            for y = 0, height - 1 do
                for x = 0, width - 1 do
                    local cellType = 0
                    
                    -- Check if cells is an array or an object
                    if type(levelData.cells) == "table" then
                        if type(levelData.cells[0]) == "table" then
                            -- Array of arrays format
                            if levelData.cells[y] and levelData.cells[y][x] then
                                cellType = levelData.cells[y][x]
                            end
                        else
                            -- Object format with y-coordinates as keys
                            if levelData.cells[tostring(y)] and levelData.cells[tostring(y)][tostring(x)] then
                                cellType = levelData.cells[tostring(y)][tostring(x)]
                            end
                        end
                    end
                    
                    if cellType > 0 then -- Only count non-empty cells
                        cellCount = cellCount + 1
                        print("Loading cell at", x, y, "with type", cellType)
                    end
                    
                    Game.level:setCellType(x, y, cellType)
                end
            end
            print("Loaded", cellCount, "non-empty cells from level file")
            
            -- Initialize grass on top of dirt cells
            Game.level:initializeGrass()
            
        -- Create the ball at the specified starting position
        Game.ball = Balls.createBall(Game.world, levelData.startX * Cell.SIZE, levelData.startY * Cell.SIZE, Balls.TYPES.STANDARD)
        
        -- Create the win hole using the exact position from the level data
        local WinHoleGenerator = require("src.win_hole_generator")
        WinHoleGenerator.createDiamondWinHole(Game.level, levelData.winHoleX, levelData.winHoleY, levelData.startX, levelData.startY)
        
        -- Only allow balls specified in the level
        UI.availableBalls = levelData.availableBalls
        else
            -- Fallback to procedural level if level file not found
            Game.level:createProceduralLevel(currentDifficulty)
            WinHoleGenerator.createDiamondWinHole(Game.level, nil, nil, 20, 20)
            Game.ball = Balls.createBall(Game.world, 20 * Cell.SIZE, 20 * Cell.SIZE, Balls.TYPES.STANDARD)
            UI.availableBalls = {
                [Balls.TYPES.STANDARD] = true,
                [Balls.TYPES.HEAVY] = false,
                [Balls.TYPES.EXPLODING] = false,
                [Balls.TYPES.STICKY] = false
            }
        end
    else
        -- Check if we're in test play mode
        if Game.testPlayMode then
            -- In test play mode, the level is already created by the editor
            -- We don't need to create a new level here
            print("Test play mode - using editor level with dimensions: " .. Game.level.width .. "x" .. Game.level.height)
            
            -- Don't create a new win hole in test play mode, as the editor level already has one
            -- or the user will place one manually during testing
        else
            -- Always use the editor's level dimensions
            local Editor = require("src.editor")
            
            -- If editor has a level, use its dimensions
            if Editor.level and Editor.level.width and Editor.level.height then
                print("Using editor's level dimensions: " .. Editor.level.width .. "x" .. Editor.level.height)
                Game.level = Level.new(Game.world, Editor.level.width, Editor.level.height)
            else
                -- This should never happen in normal operation, but just in case
                print("WARNING: No editor level dimensions available, using minimal dimensions")
                Game.level = Level.new(Game.world, 20, 20) -- Minimum allowed dimensions
            end
            
            -- Create a procedural level with the current difficulty
            local LevelGenerator = require("src.level_generator")
            print("Creating level with difficulty:", currentDifficulty)
            Game.level:createProceduralLevel(currentDifficulty)
            
            -- Create a diamond-shaped win hole at a random position
            WinHoleGenerator.createDiamondWinHole(Game.level, nil, nil, 20, 20)
        end
        
        -- Create the square ball at the starting position (matching the level generator)
        Game.ball = Balls.createBall(Game.world, 20 * Cell.SIZE, 20 * Cell.SIZE, Game.currentBallType)
        
        -- In sandbox mode, all balls are available
        UI.availableBalls = {
            [Balls.TYPES.STANDARD] = true,
            [Balls.TYPES.HEAVY] = true,
            [Balls.TYPES.EXPLODING] = true,
            [Balls.TYPES.STICKY] = true,
            [Balls.TYPES.SPRAYING] = true
        }
    end
    
    -- Set the ball as the user data for the ball body
    Game.ball.body:setUserData(Game.ball)
    
    -- Initialize camera with ball position
    local ballX, ballY = Game.ball:getPosition()
    Camera.init(ballX, ballY)
    
    -- Note: Camera scaling is now completely disabled in camera.lua
    -- to ensure cells are always displayed at their original size (10px)
    
    -- Create input handler
    Game.input = Input.new()
    
    -- Reset game state
    Game.gameWon = false
    Game.winMessageTimer = 0
    Game.attempts = 0
    
    -- Initialize editor
    Editor.init(Game.level, Game.world)
    
    -- Initialize UI
    if not UI.initialized then
        -- Set up UI callbacks
        UI.onBallTypeChange = function(ballTypeIndex)
            local ballTypes = {
                Balls.TYPES.STANDARD,
                Balls.TYPES.HEAVY,
                Balls.TYPES.EXPLODING,
                Balls.TYPES.STICKY,
                Balls.TYPES.SPRAYING
            }
            
            Game.currentBallType = ballTypes[ballTypeIndex]
            local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
            Game.ball.body:destroy() -- Destroy old ball's body
            Game.ball = newBall
            Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
            
            local ballTypeNames = {"Standard", "Heavy", "Exploding", "Sticky", "Spraying"}
            print("Switched to " .. ballTypeNames[ballTypeIndex] .. " Ball")
        end
        
        UI.onAddWinHole = function()
            local x, y = Game.ball.body:getPosition()
            local gridX, gridY = Game.level:getGridCoordinates(x, y)
            WinHole.createWinHoleArea(Game.level, gridX, gridY, 3, 3)
            print("Added a win hole at ball position")
        end
        
        UI.init()
        UI.initialized = true
    end
end

-- Update the game
function Game.update(dt)
    -- If menu is active, update menu
    if Game.currentMode == Game.MODES.MENU then
        Menu.update(dt)
        return
    end
    
    -- If editor is active, update editor instead of game
    if Editor.active then
        Editor.update(dt)
        return
    end
    
    -- Process sand cells that need to be converted to visual sand
    Effects.processSandConversion(Collision.sandToConvert, Game.level)
    Collision.sandToConvert = {} -- Clear the queue
    
    -- Update the physics world
    Game.world:update(dt)
    
    -- Update sound system and camera shake effect
    Sound.update(dt)
    Sound.updateCameraShake(dt)
    
    -- Update the ball
    local ballStopped = Game.ball:update(dt)
    
    -- Update boulders if they exist
    if Game.level.boulders then
        for _, boulder in ipairs(Game.level.boulders) do
            boulder:update(dt)
        end
    end
    
    -- Check if the exploding ball should switch to standard ball
    if Game.ball.shouldSwitchToStandard then
        Game.currentBallType = Balls.TYPES.STANDARD
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        Game.ball.body:destroy() -- Destroy old ball's body
        Game.ball = newBall
        Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
        print("Switched to Standard Ball after explosion")
    end
    
    -- Check for win condition
    if Game.ball.hasWon and not Game.gameWon then
        Game.gameWon = true
        Game.winMessageTimer = 999999.0 -- Display win message until user dismisses it
        print("GAME WON! Congratulations!")
        
        -- If in PLAY mode, advance to next level
        if Game.currentMode == Game.MODES.PLAY and Menu.currentLevel < Menu.totalLevels then
            Menu.currentLevel = Menu.currentLevel + 1
        end
    end
    
    -- Win message timer is no longer decremented automatically
    -- It will only be reset when the user clicks the continue button or presses R
    
    -- Update the level (always update all clusters)
    Game.level:update(dt, Game.ball)
    
    -- Update fire and smoke
    Fire.update(dt, Game.level)
    
    -- Update input
    Game.input:update(Game.ball, Game.level)
    
    -- Update UI
    local mouseX, mouseY = love.mouse.getPosition()
    UI.update(mouseX, mouseY)
end

-- Handle key presses
function Game.handleKeyPressed(key)
    -- If menu is active, handle menu key presses
    if Game.currentMode == Game.MODES.MENU then
        local result = Menu.handleKeyPressed(key)
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
    
    -- If editor is active, handle editor key presses
    if Editor.active then
        Editor.handleKeyPressed(key)
        return
    end
    
    -- In PLAY mode, only allow standard ball
    if Game.currentMode == Game.MODES.PLAY then
        -- Handle ball reset and other input
        if Game.input:handleKeyPressed(key, Game.ball) then
            -- Reset was performed
            -- Reset game state on reset
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
    
    -- In SANDBOX mode, allow all features
    -- Handle ball type switching
    if key == "1" then
        Game.currentBallType = Balls.TYPES.STANDARD
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        Game.ball.body:destroy() -- Destroy old ball's body
        Game.ball = newBall
        Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
        print("Switched to Standard Ball")
    elseif key == "2" then
        Game.currentBallType = Balls.TYPES.HEAVY
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        Game.ball.body:destroy() -- Destroy old ball's body
        Game.ball = newBall
        Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
        print("Switched to Heavy Ball")
    elseif key == "3" then
        Game.currentBallType = Balls.TYPES.EXPLODING
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        Game.ball.body:destroy() -- Destroy old ball's body
        Game.ball = newBall
        Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
        print("Switched to Exploding Ball")
    elseif key == "4" then
        Game.currentBallType = Balls.TYPES.STICKY
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        Game.ball.body:destroy() -- Destroy old ball's body
        Game.ball = newBall
        Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
        print("Switched to Sticky Ball")
    elseif key == "5" then
        Game.currentBallType = Balls.TYPES.SPRAYING
        local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
        Game.ball.body:destroy() -- Destroy old ball's body
        Game.ball = newBall
        Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
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
            Game.ball.body:destroy() -- Destroy old ball's body
            Game.ball = newBall
            Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
            print("Switched to Exploding Ball")
        end
        
        -- Trigger explosion
        local result = Game.ball:explode(Game.level, Collision.sandToConvert)
        if result then
            print("Exploded!")
            
            -- Check if we should switch to standard ball
            if result == "switch_to_standard" then
                Game.currentBallType = Balls.TYPES.STANDARD
                local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
                Game.ball.body:destroy() -- Destroy old ball's body
                Game.ball = newBall
                Game.ball.body:setUserData(Game.ball) -- Set the ball as the user data for the ball body
                print("Switched to Standard Ball after explosion")
            end
        end
    elseif Game.input:handleKeyPressed(key, Game.ball) then
        -- Reset was performed
        -- Reset game state on reset
        Game.gameWon = false
        Game.winMessageTimer = 0
        
        -- Reset camera to follow the ball at its new position
        local ballX, ballY = Game.ball:getPosition()
        Camera.init(ballX, ballY)
    else
        local result = Debug.handleKeyPressed(key, Game.level)
        if result == true then
            -- Toggle debug mode
            Game.debug = not Game.debug
        elseif result == "sand_pile" then
            -- Add a sand pile
            local x, y = Game.ball.body:getPosition()
            local gridX, gridY = Game.level:getGridCoordinates(x, y)
            Game.level:addSandPile(gridX, gridY, 10, 20)
            print("Added a sand pile at ball position")
        elseif result == "dirt_block" then
            -- Add a dirt block
            local x, y = Game.ball.body:getPosition()
            local gridX, gridY = Game.level:getGridCoordinates(x, y)
            Game.level:addDirtBlock(gridX, gridY, 5, 5)
            print("Added a dirt block at ball position")
        elseif result == "water_pool" then
            -- Add a water pool
            local x, y = Game.ball.body:getPosition()
            local gridX, gridY = Game.level:getGridCoordinates(x, y)
            Game.level:addWaterPool(gridX, gridY, 10, 3)
            print("Added a water pool at ball position")
        elseif key == "f" then
            -- Add fire at ball position
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
        elseif key == "h" then
            -- Add a win hole at ball position
            local x, y = Game.ball.body:getPosition()
            local gridX, gridY = Game.level:getGridCoordinates(x, y)
            WinHole.createWinHoleArea(Game.level, gridX, gridY, 3, 3)
            print("Added a win hole at ball position")
        end
    end
end

-- Handle mouse press
function Game.handleMousePressed(x, y, button)
    -- If menu is active, handle menu mouse presses
    if Game.currentMode == Game.MODES.MENU then
        local result = Menu.handleMousePressed(x, y, button)
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
    
    -- If editor is active, handle editor mouse presses
    if Editor.active then
        Editor.handleMousePressed(x, y, button)
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
        
        -- Check if click is on the continue button
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
        
        return -- Don't process other clicks when win screen is active
    end
    
    -- Check if UI handled the mouse press
    if UI.handlePress(x, y) then
        return -- UI handled the press, don't process further
    end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = screenToGameCoords(x, y)
    
    -- Otherwise, let the input system handle it with converted coordinates
    if Game.input:handleMousePressed(button, Game.ball, gameX, gameY) then
        Game.attempts = Game.attempts + 1
    end
end

-- Handle mouse release
function Game.handleMouseReleased(x, y, button)
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
    local gameX, gameY = screenToGameCoords(x, y)
    
    if Game.input:handleMouseReleased(button, Game.ball, gameX, gameY) then
        Game.attempts = Game.attempts + 1
    end
end

-- Handle key releases
function Game.handleKeyReleased(key)
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
function Game.handleMouseWheel(x, y)
    -- If menu is active, don't handle game mouse wheel
    if Game.currentMode == Game.MODES.MENU then
        return
    end
    
    -- If editor is active, handle editor mouse wheel
    if Editor.active then
        Editor.handleMouseWheel(x, y)
        return
    end
    
    -- In the future, we could add mouse wheel handling for the game itself
    -- For example, zooming in/out, scrolling through inventory, etc.
end

-- Function to convert screen coordinates to game coordinates
function screenToGameCoords(screenX, screenY)
    -- Use our InputUtils module
    local InputUtils = require("src.input_utils")
    return InputUtils.screenToGameCoords(screenX, screenY)
end

return Game
