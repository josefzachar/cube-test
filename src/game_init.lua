-- src/game_init.lua - Handles game initialization logic

local Balls = require("src.balls")
local Cell = require("cell")
local Level = require("level")
local Input = require("input")
local Collision = require("src.collision")
local Sound = require("src.sound")
local Editor = require("src.editor")
local Menu = require("src.menu")
local WinHoleGenerator = require("src.win_hole_generator")
local Camera = require("src.camera")
local UI = require("src.ui")
local WinHole = require("src.win_hole")
local GameState = require("src.game_state") -- Add require for GameState

local GameInit = {}

-- Initialize the game
function GameInit.init(Game, mode, levelNumber)
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
        local Editor = require("src.editor") -- Re-require locally if needed
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

    if mode == GameState.MODES.PLAY then -- Use GameState.MODES for comparison
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
                        -- print("Loading cell at", x, y, "with type", cellType) -- Removed for brevity
                    end

                    Game.level:setCellType(x, y, cellType)
                end
            end
            print("Loaded", cellCount, "non-empty cells from level file")

            -- Initialize grass on top of dirt cells
            Game.level:initializeGrass()

            -- Load boulders if they exist in the level data
            if levelData.boulders and type(levelData.boulders) == "table" then
                Game.level.boulders = {}
                for i, boulderData in ipairs(levelData.boulders) do
                    if boulderData.x and boulderData.y then
                        local Boulder = require("src.boulder")
                        local boulder = Boulder.new(Game.world, boulderData.x, boulderData.y, boulderData.size or 60)
                        table.insert(Game.level.boulders, boulder)
                        print("Loaded boulder at", boulderData.x, boulderData.y)
                    end
                end
                print("Loaded", #Game.level.boulders, "boulders from level file")
            end

        -- Create the ball at the specified starting position
        Game.ball = Balls.createBall(Game.world, levelData.startX * Cell.SIZE, levelData.startY * Cell.SIZE, Balls.TYPES.STANDARD)

        -- Create the win hole using the exact position from the level data
        local WinHoleGenerator = require("src.win_hole_generator") -- Re-require locally
        WinHoleGenerator.createDiamondWinHole(Game.level, levelData.winHoleX, levelData.winHoleY, levelData.startX, levelData.startY)

        -- Only allow balls specified in the level
        UI.availableBalls = levelData.availableBalls
        else
            -- Fallback to procedural level if level file not found
            Game.level = Level.new(Game.world, 160, 100) -- Default dimensions
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
        -- Check if we're in test play mode (already handled above, but keep structure)
        if Game.testPlayMode then
             -- This block is technically unreachable due to the check at the start,
             -- but kept for structural consistency with the original code.
             print("Test play mode - using editor level with dimensions: " .. Game.level.width .. "x" .. Game.level.height)
        else
            -- Always use the editor's level dimensions if available
            local Editor = require("src.editor") -- Re-require locally

            -- If editor has a level, use its dimensions
            if Editor.level and Editor.level.width and Editor.level.height then
                print("Using editor's level dimensions: " .. Editor.level.width .. "x" .. Editor.level.height)
                Game.level = Level.new(Game.world, Editor.level.width, Editor.level.height)
            else
                -- Fallback dimensions
                print("WARNING: No editor level dimensions available, using default dimensions")
                if Game.currentMode == GameState.MODES.SANDBOX then -- Use GameState.MODES for comparison
                    print("Using 160x100 cells for SANDBOX mode")
                    Game.level = Level.new(Game.world, 160, 100)
                else
                    Game.level = Level.new(Game.world, 160, 100) -- Default dimensions for other modes
                end
            end

            -- Create a procedural level with the current difficulty
            -- local LevelGenerator = require("src.level_generator") -- Not used directly here
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
    if Game.ball and Game.ball.body then
        Game.ball.body:setUserData(Game.ball)
    else
        print("ERROR: Ball or ball body not created during initialization!")
    end


    -- Initialize camera with ball position
    if Game.ball then
        local ballX, ballY = Game.ball:getPosition()
        Camera.init(ballX, ballY)
    else
        Camera.init(0, 0) -- Fallback camera init
    end


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
            if Game.ball and Game.ball.body then Game.ball.body:destroy() end -- Destroy old ball's body
            Game.ball = newBall
            if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end -- Set the ball as the user data for the ball body

            local ballTypeNames = {"Standard", "Heavy", "Exploding", "Sticky", "Spraying"}
            print("Switched to " .. ballTypeNames[ballTypeIndex] .. " Ball")
        end

        UI.onAddWinHole = function()
            if Game.ball then
                local x, y = Game.ball.body:getPosition()
                local gridX, gridY = Game.level:getGridCoordinates(x, y)
                WinHole.createWinHoleArea(Game.level, gridX, gridY, 3, 3)
                print("Added a win hole at ball position")
            end
        end

        UI.init()
        UI.initialized = true
    end
end

return GameInit
