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

-- Game variables
local world
local ball
local level
local input
local attempts = 0
local debug = false -- Set to true to see physics bodies
local currentBallType = Balls.TYPES.STANDARD -- Start with standard ball

-- Colors
local WHITE = {1, 1, 1, 1}

function love.load()
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
    level:createProceduralLevel()
    
    -- Create the square ball at the starting position (matching the level generator)
    ball = Balls.createBall(world, 20 * Cell.SIZE, 20 * Cell.SIZE, currentBallType)
    
    -- Set the ball as the user data for the ball body
    ball.body:setUserData(ball)
    
    -- Create input handler
    input = Input.new()
end

function love.update(dt)
    -- Process sand cells that need to be converted to visual sand
    Effects.processSandConversion(Collision.sandToConvert, level)
    Collision.sandToConvert = {} -- Clear the queue
    
    -- Update the physics world
    world:update(dt)
    
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
    
    -- Update the level (pass the ball for cluster activation)
    level:update(dt, ball)
    
    -- Update fire and smoke
    Fire.update(dt, level)
    
    -- Update input
    input:update(ball, level)
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
        end
    end
end

function love.draw()
    -- Draw the level
    level:draw(debug) -- Pass debug flag to level:draw
    
    -- Draw the ball
    ball:draw(debug) -- Pass debug flag to ball:draw
    
    -- Draw input (aim line, power indicator)
    input:draw(ball)
    
    -- Display attempts counter
    love.graphics.setColor(WHITE)
    love.graphics.print("Shots: " .. attempts, 250, 30)
    
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
    love.graphics.print(ballTypeText, 250, 50)
    
    -- Debug info
    Debug.drawDebugInfo(level, ball, attempts, debug)
    
    -- Draw active cells for debugging
    Debug.drawActiveCells(level)
end

function love.mousepressed(x, y, button)
    if input:handleMousePressed(button, ball) then
        attempts = attempts + 1
    end
end

function love.mousereleased(x, y, button)
    if input:handleMouseReleased(button, ball) then
        attempts = attempts + 1
    end
end
