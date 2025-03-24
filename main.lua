-- Square Golf Game
-- A simple golf game where the ball is a square and the level is made of cells

-- Load modules
local Ball = require("ball")
local Cell = require("cell")
local Level = require("level")
local Input = require("input")
local Collision = require("src.collision")
local Effects = require("src.effects")
local Debug = require("src.debug")

-- Game variables
local world
local ball
local level
local input
local attempts = 0
local debug = false -- Set to true to see physics bodies

-- Colors
local WHITE = {1, 1, 1, 1}

function love.load()
    -- Set up the physics world with gravity
    world = love.physics.newWorld(0, 9.81 * 64, true)
    
    -- Set up collision callbacks
    world:setCallbacks(
        function(a, b, coll) Collision.beginContact(a, b, coll, level) end,
        function(a, b, coll) Collision.endContact(a, b, coll, level) end,
        Collision.preSolve,
        Collision.postSolve
    )
    
    -- Create the level (80x60 cells, each 10x10 pixels)
    level = Level.new(world, 160, 100)
    level:createTestLevel()
    
    -- Create the square ball
    ball = Ball.new(world, 100, 500)
    
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
    
    -- Update the level (pass the ball for cluster activation)
    level:update(dt, ball)
    
    -- Update input
    input:update(ball, level)
end

function love.keypressed(key)
    if input:handleKeyPressed(key, ball) then
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
