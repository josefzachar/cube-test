-- Square Golf Game
-- A simple golf game where the ball is a square and the level is made of cells

-- Load modules
local Ball = require("ball")
local Cell = require("cell")
local Level = require("level")
local Input = require("input")

-- Game variables
local world
local ball
local level
local input
local attempts = 0
local debug = false -- Set to true to see physics bodies
local sandToStone = {} -- Table to track sand cells converted to stone
local sandToConvert = {} -- Table to store sand cells that need to be converted to flying sand
local tempStoneCells = {} -- Table to store temporary stone cells for ball collision

-- Colors
local WHITE = {1, 1, 1, 1}

function love.load()
    -- Set up the physics world with gravity
    world = love.physics.newWorld(0, 9.81 * 64, true)
    
    -- Set up collision callbacks
    world:setCallbacks(beginContact, endContact, preSolve, postSolve)
    
    -- Create the level (80x60 cells, each 10x10 pixels)
    level = Level.new(world, 80, 60)
    level:createTestLevel()
    
    -- Create the square ball
    ball = Ball.new(world, 100, 500)
    
    -- Create input handler
    input = Input.new()
end

-- Collision callbacks
function beginContact(a, b, coll)
    local aData = a:getUserData()
    local bData = b:getUserData()
    
    -- Handle collisions between ball and stone/temp_stone cells
    if (aData == "ball" and (bData == "stone" or bData == "temp_stone")) or 
       ((aData == "stone" or aData == "temp_stone") and bData == "ball") then
        -- Ball hit stone or temporary stone - normal physics collision
        
        -- Get the ball's velocity
        local ballFixture = aData == "ball" and a or b
        local ballBody = ballFixture:getBody()
        local vx, vy = ballBody:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        
        -- If the ball is moving fast enough and hit a temporary stone (sand), create a crater
        if speed > 50 and (aData == "temp_stone" or bData == "temp_stone") then
            -- Get the stone cell position
            local stoneFixture = aData == "temp_stone" and a or b
            local stoneBody = stoneFixture:getBody()
            local stoneX, stoneY = stoneBody:getPosition()
            local gridX, gridY = level:getGridCoordinates(stoneX, stoneY)
            
            print("Ball hit temp_stone at", gridX, gridY, "with speed", speed)
            
            -- Queue up nearby cells for conversion to flying sand
            local craterRadius = math.min(3, math.floor(speed / 100) + 1)
            for dy = -craterRadius, craterRadius do
                for dx = -craterRadius, craterRadius do
                    local distance = math.sqrt(dx*dx + dy*dy)
                    if distance <= craterRadius then
                        local checkX = gridX + dx
                        local checkY = gridY + dy
                        
                        -- Only affect sand cells
                        if checkX >= 0 and checkX < level.width and checkY >= 0 and checkY < level.height then
                            if level:getCellType(checkX, checkY) == Cell.TYPES.SAND then
                                -- Calculate velocity based on impact
                                local impactFactor = (1 - distance/craterRadius) * math.min(1.0, speed / 300)
                                
                                -- Direction away from impact
                                local dirX = dx
                                local dirY = dy
                                if dx == 0 and dy == 0 then
                                    dirX, dirY = 0, -1 -- Default upward
                                else
                                    local dirLen = math.sqrt(dirX*dirX + dirY*dirY)
                                    dirX = dirX / dirLen
                                    dirY = dirY / dirLen
                                end
                                
                                -- Calculate velocity with much stronger effect
                                local flyVx = dirX * speed * 1.0 * impactFactor
                                local flyVy = dirY * speed * 1.0 * impactFactor - 200 -- Extra upward boost
                                
                                -- Add randomness
                                flyVx = flyVx + math.random(-50, 50)
                                flyVy = flyVy + math.random(-50, 50)
                                
                                -- Queue up for conversion
                                table.insert(sandToConvert, {
                                    x = checkX,
                                    y = checkY,
                                    vx = flyVx,
                                    vy = flyVy
                                })
                            end
                        end
                    end
                end
            end
        end
    end
end

function endContact(a, b, coll)
    -- Not used but required by LÖVE
end

function preSolve(a, b, coll)
    -- Not used but required by LÖVE
end

function postSolve(a, b, coll, normalImpulse, tangentImpulse)
    -- Not used but required by LÖVE
end

function love.update(dt)
    -- Clear any temporary stone cells from the previous frame
    for _, cell in ipairs(tempStoneCells) do
        if cell.body then
            cell.body:destroy()
        end
    end
    tempStoneCells = {}
    
    -- Process sand cells that need to be converted to flying sand
    -- This is done outside of collision callbacks to avoid Box2D errors
    if #sandToConvert > 0 then
        print("Converting", #sandToConvert, "sand cells to flying sand")
        for _, sand in ipairs(sandToConvert) do
            print("  Converting sand at", sand.x, sand.y, "to flying sand with velocity", sand.vx, sand.vy)
            level:convertSandToFlying(sand.x, sand.y, sand.vx, sand.vy)
        end
        sandToConvert = {} -- Clear the queue
    end
    
    -- Convert temporary stone cells back to sand
    local i = 1
    while i <= #sandToStone do
        local cell = sandToStone[i]
        if cell.timer > 0 then
            cell.timer = cell.timer - dt
            i = i + 1
        else
            -- Convert back to sand if it's still temporary stone
            if level:getCellType(cell.x, cell.y) == Cell.TYPES.TEMP_STONE then
                level:setCellType(cell.x, cell.y, Cell.TYPES.SAND)
            end
            -- Remove from the list
            table.remove(sandToStone, i)
            -- Don't increment i since we removed an element
        end
    end
    
    -- Update the physics world
    world:update(dt)
    
    -- Update the ball
    local ballStopped = ball:update(dt)
    
    -- Check for ball collisions with sand
    if ball.body then
        local vx, vy = ball.body:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        local ballX, ballY = ball.body:getPosition()
        local gridX, gridY = level:getGridCoordinates(ballX, ballY)
        
        -- Convert sand to temporary stone when the ball is about to hit it
        -- Use a larger radius to catch more sand cells in the ball's path
        local radius = 4
        for dy = -radius, radius do
            for dx = -radius, radius do
                local checkX = gridX + dx
                local checkY = gridY + dy
                
                if checkX >= 0 and checkX < level.width and checkY >= 0 and checkY < level.height then
                    if level:getCellType(checkX, checkY) == Cell.TYPES.SAND then
                        -- Always convert all sand cells within the radius to temporary stone
                        -- This ensures the ball always has something to collide with
                        level:setCellType(checkX, checkY, Cell.TYPES.TEMP_STONE)
                        
                        -- Add to the list of converted cells
                        table.insert(sandToStone, {
                            x = checkX,
                            y = checkY,
                            timer = 0.5 -- Convert back after 0.5 seconds
                        })
                    end
                end
            end
        end
    end
    
    -- Update the level
    level:update(dt)
    
    -- Update input
    input:update(ball, level)
end

function love.draw()
    -- Draw the level
    level:draw()
    
    -- Draw the ball
    ball:draw()
    
    -- Draw input (aim line, power indicator)
    input:draw(ball)
    
    -- Display attempts counter
    love.graphics.setColor(WHITE)
    love.graphics.print("Shots: " .. attempts, 250, 30)
    
    -- Debug info
    if debug then
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    end
end

function love.mousepressed(x, y, button)
    if input:handleMousePressed(button, ball) then
        attempts = attempts + 1
    end
end

function love.keypressed(key)
    if input:handleKeyPressed(key, ball) then
        -- Reset was performed
    elseif key == "d" then
        -- Toggle debug mode
        debug = not debug
    end
end
