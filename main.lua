-- Square Golf Game
-- A simple golf game where the ball is a square and the level is made of cells

-- Load modules
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

-- Game variables
local world
local ball
local level
local input
local attempts = 0
local debug = false -- Set to true to see physics bodies
local currentBallType = Balls.TYPES.STANDARD -- Start with standard ball
local gameWon = false -- Flag to track if the player has won
local winMessageTimer = 0 -- Timer for displaying the win message
currentDifficulty = 1 -- Current difficulty level (1-5) - global variable

-- Colors
local WHITE = {1, 1, 1, 1}
-- Background colors for gradient
BACKGROUND_COLOR = {0.2, 0.3, 0.6, 1.0} -- Dark blue (base color)
BACKGROUND_COLOR_TOP = {0.1, 0.2, 0.4, 1.0} -- Darker blue for top
BACKGROUND_COLOR_BOTTOM = {0.3, 0.4, 0.7, 1.0} -- Lighter blue for bottom

-- Function to create a diamond-shaped win hole
function createDiamondWinHole(level, holeX, holeY)
    -- Ball starting position
    local ballStartX, ballStartY = 20, 20
    local minDistanceFromBall = 40 -- Minimum distance from ball starting position
    
    -- If no position is provided, choose a random position
    if not holeX or not holeY then
        -- Choose a random position from several possible locations
        local possibleLocations = {
            {x = level.width - 20, y = level.height - 20}, -- Bottom right
            {x = 20, y = level.height - 20},               -- Bottom left
            {x = level.width - 20, y = 20},                -- Top right
            {x = level.width / 2, y = 20},                 -- Top middle
            {x = level.width / 2, y = level.height - 20},  -- Bottom middle
            {x = 20, y = level.height / 2},                -- Left middle
            {x = level.width - 20, y = level.height / 2}   -- Right middle
        }
        
        -- Remove the top-left position (20, 20) as it's too close to the ball starting position
        -- And filter out any positions that are too close to the ball starting position
        local validLocations = {}
        for _, loc in ipairs(possibleLocations) do
            local distance = math.sqrt((loc.x - ballStartX)^2 + (loc.y - ballStartY)^2)
            if distance >= minDistanceFromBall then
                table.insert(validLocations, loc)
            end
        end
        
        -- Pick a random location from valid locations
        local randomIndex = math.random(1, #validLocations)
        holeX = math.floor(validLocations[randomIndex].x)
        holeY = math.floor(validLocations[randomIndex].y)
    else
        -- If position is provided, check if it's too close to the ball starting position
        local distance = math.sqrt((holeX - ballStartX)^2 + (holeY - ballStartY)^2)
        if distance < minDistanceFromBall then
            -- If too close, move it to a valid position
            holeX = level.width - 20
            holeY = level.height - 20
        end
    end
    -- The pattern is:
    --   X
    --  XXX
    -- XXXXX
    --  XXX
    --   X
    
    -- Define the diamond pattern explicitly
    local pattern = {
        {0, 0, 1, 0, 0},
        {0, 1, 1, 1, 0},
        {1, 1, 1, 1, 1},
        {0, 1, 1, 1, 0},
        {0, 0, 1, 0, 0}
    }
    
    -- Create a clear area around the win hole
    for y = holeY - 5, holeY + 5 do
        for x = holeX - 5, holeX + 5 do
            if x >= 0 and x < level.width and y >= 0 and y < level.height then
                level:setCellType(x, y, CellTypes.TYPES.EMPTY)
            end
        end
    end
    
    -- Create win holes based on the pattern
    local createdHoles = {}
    
    for dy = 0, 4 do
        for dx = 0, 4 do
            -- Only create a win hole if the pattern has a 1 at this position
            if pattern[dy + 1][dx + 1] == 1 then
                local cellX = holeX - 2 + dx
                local cellY = holeY - 2 + dy
                
                -- Only create win holes within the level bounds
                if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
                    print("Creating win hole at", cellX, cellY)
                    WinHole.createWinHole(level, cellX, cellY)
                    table.insert(createdHoles, {x = cellX, y = cellY})
                end
            end
        end
    end
    
    -- Check for isolated win holes and remove them
    for i = #createdHoles, 1, -1 do
        local hole = createdHoles[i]
        local hasAdjacent = false
        
        -- Check adjacent cells (up, down, left, right)
        local directions = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
        for _, dir in ipairs(directions) do
            local nx = hole.x + dir[1]
            local ny = hole.y + dir[2]
            
            -- Check if this adjacent cell is also a win hole
            if nx >= 0 and nx < level.width and ny >= 0 and ny < level.height then
                if level:getCellType(nx, ny) == CellTypes.TYPES.WIN_HOLE then
                    hasAdjacent = true
                    break
                end
            end
        end
        
        -- If this hole has no adjacent win holes, remove it
        if not hasAdjacent then
            level:setCellType(hole.x, hole.y, CellTypes.TYPES.EMPTY)
            print("Removing isolated win hole at", hole.x, hole.y)
            table.remove(createdHoles, i)
        end
    end
end

function love.load()
    -- Initialize sound system
    Sound.load()
    
    -- Set up the physics world with gravity
    world = love.physics.newWorld(0, 9.81 * 64, true)
    
    -- Set up collision callbacks
    world:setCallbacks(
        function(a, b, coll) Collision.beginContact(a, b, coll, level, ball) end,
        function(a, b, coll) Collision.endContact(a, b, coll, level) end,
        Collision.preSolve,
        Collision.postSolve
    )
    
    -- Create the level (80x60 cells, each 10x10 pixels)
    level = Level.new(world, 160, 100)
    
    -- Create a procedural level with the current difficulty
    local LevelGenerator = require("src.level_generator")
    print("Creating level with difficulty:", currentDifficulty)
    level:createProceduralLevel(currentDifficulty)
    
    -- Create a diamond-shaped win hole at a random position
    createDiamondWinHole(level)
    
    -- Create the square ball at the starting position (matching the level generator)
    ball = Balls.createBall(world, 20 * Cell.SIZE, 20 * Cell.SIZE, currentBallType)
    
    -- Set the ball as the user data for the ball body
    ball.body:setUserData(ball)
    
    -- Create input handler
    input = Input.new()
    
    -- Reset game state
    gameWon = false
    winMessageTimer = 0
    attempts = 0
    
    -- Initialize UI
    if not UI.initialized then
        -- Set up UI callbacks
        UI.onBallTypeChange = function(ballTypeIndex)
            local ballTypes = {
                Balls.TYPES.STANDARD,
                Balls.TYPES.HEAVY,
                Balls.TYPES.EXPLODING,
                Balls.TYPES.STICKY
            }
            
            currentBallType = ballTypes[ballTypeIndex]
            local newBall = Balls.changeBallType(ball, world, currentBallType)
            ball.body:destroy() -- Destroy old ball's body
            ball = newBall
            ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
            
            local ballTypeNames = {"Standard", "Heavy", "Exploding", "Sticky"}
            print("Switched to " .. ballTypeNames[ballTypeIndex] .. " Ball")
        end
        
        UI.onAddWinHole = function()
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            WinHole.createWinHoleArea(level, gridX, gridY, 3, 3)
            print("Added a win hole at ball position")
        end
        
        UI.init()
        UI.initialized = true
    end
end

function love.update(dt)
    -- Process sand cells that need to be converted to visual sand
    Effects.processSandConversion(Collision.sandToConvert, level)
    Collision.sandToConvert = {} -- Clear the queue
    
    -- Update the physics world
    world:update(dt)
    
    -- Update sound system and camera shake effect
    Sound.update(dt)
    Sound.updateCameraShake(dt)
    
    -- Update the ball
    local ballStopped = ball:update(dt)
    
    -- Check if the exploding ball should switch to standard ball
    if ball.shouldSwitchToStandard then
        currentBallType = Balls.TYPES.STANDARD
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Standard Ball after explosion")
    end
    
    -- Check for win condition
    if ball.hasWon and not gameWon then
        gameWon = true
        winMessageTimer = 5.0 -- Display win message for 5 seconds
        print("GAME WON! Congratulations!")
    end
    
    -- Update win message timer
    if gameWon and winMessageTimer > 0 then
        winMessageTimer = winMessageTimer - dt
    end
    
    -- Update the level (pass the ball for cluster activation)
    level:update(dt, ball)
    
    -- Update fire and smoke
    Fire.update(dt, level)
    
    -- Update input
    input:update(ball, level)
    
    -- Update UI
    local mouseX, mouseY = love.mouse.getPosition()
    UI.update(mouseX, mouseY)
end

function love.keypressed(key)
    -- Handle ball type switching
    if key == "1" then
        currentBallType = Balls.TYPES.STANDARD
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Standard Ball")
    elseif key == "2" then
        currentBallType = Balls.TYPES.HEAVY
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Heavy Ball")
    elseif key == "3" then
        currentBallType = Balls.TYPES.EXPLODING
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Exploding Ball")
    elseif key == "4" then
        currentBallType = Balls.TYPES.STICKY
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Sticky Ball")
    elseif key == "e" and ball.ballType == Balls.TYPES.EXPLODING then
        -- Trigger explosion for exploding ball
        local result = ball:explode(level, Collision.sandToConvert)
        if result then
            print("Exploded!")
            
            -- Check if we should switch to standard ball
            if result == "switch_to_standard" then
                currentBallType = Balls.TYPES.STANDARD
                local newBall = Balls.changeBallType(ball, world, currentBallType)
                ball.body:destroy() -- Destroy old ball's body
                ball = newBall
                ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
                print("Switched to Standard Ball after explosion")
            end
        end
    elseif input:handleKeyPressed(key, ball) then
        -- Reset was performed
        -- Reset game state on reset
        gameWon = false
        winMessageTimer = 0
    else
        local result = Debug.handleKeyPressed(key, level)
        if result == true then
            -- Toggle debug mode
            debug = not debug
        elseif result == "sand_pile" then
            -- Add a sand pile
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            level:addSandPile(gridX, gridY, 10, 20)
            print("Added a sand pile at ball position")
        elseif result == "dirt_block" then
            -- Add a dirt block
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            level:addDirtBlock(gridX, gridY, 5, 5)
            print("Added a dirt block at ball position")
        elseif result == "water_pool" then
            -- Add a water pool
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            level:addWaterPool(gridX, gridY, 10, 3)
            print("Added a water pool at ball position")
        elseif key == "f" then
            -- Add fire at ball position
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            
            -- Create a small cluster of fire for better visibility
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local fireX = gridX + dx
                    local fireY = gridY + dy
                    
                    -- Only place fire in empty cells
                    if fireX >= 0 and fireX < level.width and 
                       fireY >= 0 and fireY < level.height and
                       level:getCellType(fireX, fireY) == CellTypes.TYPES.EMPTY then
                        Fire.createFire(level, fireX, fireY)
                    end
                end
            end
            print("Added fire at ball position")
        elseif key == "h" then
            -- Add a win hole at ball position
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            WinHole.createWinHoleArea(level, gridX, gridY, 3, 3)
            print("Added a win hole at ball position")
        end
    end
end

function love.draw()
    -- Draw gradient background
    love.graphics.clear(0, 0, 0, 1) -- Clear with black first
    
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Apply camera shake offset
    local shakeX, shakeY = 0, 0
    local cameraShakeActive = false
    if Sound.cameraShake and Sound.cameraShake.active then
        shakeX, shakeY = Sound.cameraShake.offsetX, Sound.cameraShake.offsetY
        love.graphics.push()
        love.graphics.translate(shakeX, shakeY)
        cameraShakeActive = true
    end
    
    -- Draw gradient rectangle covering the entire screen
    love.graphics.setColor(BACKGROUND_COLOR_TOP[1], BACKGROUND_COLOR_TOP[2], BACKGROUND_COLOR_TOP[3], BACKGROUND_COLOR_TOP[4])
    love.graphics.rectangle("fill", 0, 0, width, height)
    
    -- Create a subtle gradient mesh
    local gradient = love.graphics.newMesh({
        {0, 0, 0, 0, BACKGROUND_COLOR_TOP[1], BACKGROUND_COLOR_TOP[2], BACKGROUND_COLOR_TOP[3], BACKGROUND_COLOR_TOP[4]}, -- top-left
        {width, 0, 1, 0, BACKGROUND_COLOR_TOP[1], BACKGROUND_COLOR_TOP[2], BACKGROUND_COLOR_TOP[3], BACKGROUND_COLOR_TOP[4]}, -- top-right
        {width, height, 1, 1, BACKGROUND_COLOR_BOTTOM[1], BACKGROUND_COLOR_BOTTOM[2], BACKGROUND_COLOR_BOTTOM[3], BACKGROUND_COLOR_BOTTOM[4]}, -- bottom-right
        {0, height, 0, 1, BACKGROUND_COLOR_BOTTOM[1], BACKGROUND_COLOR_BOTTOM[2], BACKGROUND_COLOR_BOTTOM[3], BACKGROUND_COLOR_BOTTOM[4]} -- bottom-left
    }, "fan", "static")
    
    love.graphics.draw(gradient)
    
    -- Draw the level
    level:draw(debug) -- Pass debug flag to level:draw
    
    -- Draw the ball
    ball:draw(debug) -- Pass debug flag to ball:draw
    
    -- Draw input (aim line, power indicator)
    input:draw(ball)
    
    -- Display attempts counter and difficulty level
    love.graphics.setColor(WHITE)
    love.graphics.print("Shots: " .. attempts, 250, 30)
    
    -- Display difficulty level
    local difficultyText = "Difficulty: "
    if currentDifficulty == 1 then
        difficultyText = difficultyText .. "Easy"
    elseif currentDifficulty == 2 then
        difficultyText = difficultyText .. "Medium"
    elseif currentDifficulty == 3 then
        difficultyText = difficultyText .. "Hard"
    elseif currentDifficulty == 4 then
        difficultyText = difficultyText .. "Expert"
    elseif currentDifficulty == 5 then
        difficultyText = difficultyText .. "Insane"
    end
    love.graphics.print(difficultyText, 250, 50)
    
    -- Display current ball type
    local ballTypeText = "Ball: "
    if ball.ballType == Balls.TYPES.STANDARD then
        ballTypeText = ballTypeText .. "Standard (1)"
    elseif ball.ballType == Balls.TYPES.HEAVY then
        ballTypeText = ballTypeText .. "Heavy (2)"
    elseif ball.ballType == Balls.TYPES.EXPLODING then
        ballTypeText = ballTypeText .. "Exploding (3) - Press E to explode"
    elseif ball.ballType == Balls.TYPES.STICKY then
        ballTypeText = ballTypeText .. "Sticky (4)"
    end
    love.graphics.print(ballTypeText, 250, 70)
    
    -- Debug info
    Debug.drawDebugInfo(level, ball, attempts, debug)
    
    -- Draw active cells for debugging
    Debug.drawActiveCells(level)
    
    -- Reset camera shake before drawing UI
    if cameraShakeActive then
        love.graphics.pop()
    end
    
    -- Draw UI
    UI.draw()
    
    -- Draw win message if the game is won
    if gameWon and winMessageTimer > 0 then
        -- Draw a semi-transparent background
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        -- Draw the win message
        love.graphics.setColor(0, 1, 0, 1) -- Green text
        love.graphics.printf("YOU WIN!", 0, love.graphics.getHeight() / 2 - 70, love.graphics.getWidth(), "center")
        love.graphics.printf("Shots: " .. attempts, 0, love.graphics.getHeight() / 2 - 40, love.graphics.getWidth(), "center")
        
        -- Display current difficulty
        local difficultyName = "Easy"
        if currentDifficulty == 2 then
            difficultyName = "Medium"
        elseif currentDifficulty == 3 then
            difficultyName = "Hard"
        elseif currentDifficulty == 4 then
            difficultyName = "Expert"
        elseif currentDifficulty == 5 then
            difficultyName = "Insane"
        end
        
        love.graphics.printf("Current Difficulty: " .. difficultyName, 0, love.graphics.getHeight() / 2 - 10, love.graphics.getWidth(), "center")
        
        -- Display next difficulty message if not at max difficulty
        if currentDifficulty < 5 then
            local nextDifficultyName = "Medium"
            if currentDifficulty == 2 then
                nextDifficultyName = "Hard"
            elseif currentDifficulty == 3 then
                nextDifficultyName = "Expert"
            elseif currentDifficulty == 4 then
                nextDifficultyName = "Insane"
            end
            
            love.graphics.printf("Press R to restart with " .. nextDifficultyName .. " difficulty", 0, love.graphics.getHeight() / 2 + 20, love.graphics.getWidth(), "center")
        else
            love.graphics.printf("Press R to restart (Maximum difficulty reached)", 0, love.graphics.getHeight() / 2 + 20, love.graphics.getWidth(), "center")
        end
    end
end

function love.mousepressed(x, y, button)
    -- Check if UI handled the mouse press
    if UI.handlePress(x, y) then
        return -- UI handled the press, don't process further
    end
    
    -- Otherwise, let the input system handle it
    if input:handleMousePressed(button, ball) then
        attempts = attempts + 1
    end
end

function love.mousereleased(x, y, button)
    if input:handleMouseReleased(button, ball) then
        attempts = attempts + 1
    end
end

-- Store the original pop function
local originalPop = love.graphics.pop

-- Override the pop function
love.graphics.pop = function(...)
    -- Call the original pop function
    originalPop(...)
end
