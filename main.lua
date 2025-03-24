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
    level = Level.new(world, 160, 100)
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
    
    -- Check if the ball is involved in the collision
    local isBallCollision = (aData == "ball" or bData == "ball")
    
    -- Handle collisions between ball and any cells
    if isBallCollision then
        -- Ball hit stone or temporary stone - normal physics collision
        
        -- Get the ball's velocity
        local ballFixture = aData == "ball" and a or b
        local ballBody = ballFixture:getBody()
        local vx, vy = ballBody:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        
        -- Only create a crater if the ball is moving very fast
        -- We need to convert temp_stone back to sand for the crater effect
        if speed > 300 then
            -- Get the collision position
            local nx, ny = coll:getNormal()
            local x1, y1, x2, y2 = coll:getPositions()
            
            -- Use the collision position if available, otherwise use the fixture position
            local hitX, hitY
            if x1 and y1 then
                hitX, hitY = x1, y1
            else
                local hitFixture = aData == "temp_stone" and a or b
                local hitBody = hitFixture:getBody()
                hitX, hitY = hitBody:getPosition()
            end
            
            local gridX, gridY = level:getGridCoordinates(hitX, hitY)
            
            print("Ball hit solid at", gridX, gridY, "with speed", speed)
            
            -- First, convert temp_stone back to sand in the crater area
            local directRadius = 2 -- Ball is 20x20, each cell is 10x10, so radius 2 is about right
            for dy = -directRadius, directRadius do
                for dx = -directRadius, directRadius do
                    local checkX = gridX + dx
                    local checkY = gridY + dy
                    
                    -- Only affect temp_stone cells
                    if checkX >= 0 and checkX < level.width and checkY >= 0 and checkY < level.height then
                        if level:getCellType(checkX, checkY) == Cell.TYPES.TEMP_STONE then
                            -- Convert back to sand first
                            level:setCellType(checkX, checkY, Cell.TYPES.SAND)
                            
                            -- Also remove from the sandToStone list to prevent it from being converted back
                            for i = #sandToStone, 1, -1 do
                                if sandToStone[i].x == checkX and sandToStone[i].y == checkY then
                                    table.remove(sandToStone, i)
                                    break
                                end
                            end
                        end
                    end
                end
            end
            
            -- Now create the crater with visual sand
            
            -- Limit the crater to about twice the size of the ball
            local directRadius = 2 -- Ball is 20x20, each cell is 10x10, so radius 2 is about right
            for dy = -directRadius, directRadius do
                for dx = -directRadius, directRadius do
                    local checkX = gridX + dx
                    local checkY = gridY + dy
                    
                    -- Only affect sand cells
                    if checkX >= 0 and checkX < level.width and checkY >= 0 and checkY < level.height then
                        if level:getCellType(checkX, checkY) == Cell.TYPES.SAND then
                            -- Calculate velocity based on impact
                            local distance = math.sqrt(dx*dx + dy*dy)
                            if distance <= directRadius then
                                local impactFactor = (1 - distance/directRadius) * math.min(1.0, speed / 300)
                                
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
            
            -- We only need one loop to create the crater
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
    
-- Process sand cells that need to be converted to visual sand
-- This is done outside of collision callbacks to avoid Box2D errors
if #sandToConvert > 0 then
    print("Converting", #sandToConvert, "sand cells to visual sand")
    for _, sand in ipairs(sandToConvert) do
        print("  Converting sand at", sand.x, sand.y, "to visual sand with velocity", sand.vx, sand.vy)
        
        -- Get the cell at this position
        if level.cells[sand.y] and level.cells[sand.y][sand.x] then
            -- Create a crater by setting the cell to EMPTY
            level:setCellType(sand.x, sand.y, Cell.TYPES.EMPTY)
            
            -- Create a visual effect of flying sand
            -- We'll just create a new cell at the same position with type VISUAL_SAND
            local visualSand = Cell.new(world, sand.x, sand.y, Cell.TYPES.VISUAL_SAND)
            visualSand.velocityX = sand.vx
            visualSand.velocityY = sand.vy
            
            -- Add the visual sand to the level's cells array
            level.visualSandCells = level.visualSandCells or {}
            table.insert(level.visualSandCells, visualSand)
        end
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
        
        -- Only convert sand to temporary stone if the ball is moving
        if speed > 10 then
            -- Optimize: Use a smaller radius for slow-moving balls
            local radius = math.min(4, math.max(2, math.floor(speed / 100) + 2))
            
            -- Optimize: Only convert sand in the direction of movement
            local dirX = 0
            local dirY = 0
            
            if speed > 50 then
                dirX = vx / speed
                dirY = vy / speed
            end
            
            -- Calculate the distance from the ball to each cell
            for dy = -radius, radius do
                for dx = -radius, radius do
                    -- Skip cells that are not in the direction of movement (for fast balls)
                    if speed <= 50 or (dx * dirX + dy * dirY > -0.5) then
                        local checkX = gridX + dx
                        local checkY = gridY + dy
                        
                        -- Calculate distance from ball center to cell center
                        local distSq = dx*dx + dy*dy
                        
                        -- Only convert cells within the radius
                        if distSq <= radius*radius then
                            if checkX >= 0 and checkX < level.width and checkY >= 0 and checkY < level.height then
                                if level:getCellType(checkX, checkY) == Cell.TYPES.SAND then
                                    -- Convert sand to temporary stone
                                    level:setCellType(checkX, checkY, Cell.TYPES.TEMP_STONE)
                                    
                                    -- Add to the list of converted cells
                                    table.insert(sandToStone, {
                                        x = checkX,
                                        y = checkY,
                                        timer = 0.1 -- Convert back after 0.1 seconds (reduced from 0.2)
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Update the level (pass the ball for cluster activation)
    level:update(dt, ball)
    
    -- Update input
    input:update(ball, level)
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
    if debug then
        love.graphics.setColor(1, 0, 0, 1)
        
        -- FPS
        love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
        
        -- Cell counts (only update every 10 frames to improve performance)
        if not level.cellCounts or love.timer.getTime() - (level.lastCountTime or 0) > 0.5 then
            level.cellCounts = level.cellCounts or {}
            level.cellCounts.sandCount = 0
            level.cellCounts.stoneCount = 0
            level.cellCounts.tempStoneCount = 0
            level.cellCounts.emptyCount = 0
            level.cellCounts.visualSandCount = 0
            
            -- Only count cells in visible area
            local screenWidth, screenHeight = love.graphics.getDimensions()
            local margin = 10
            local minX = math.max(0, math.floor(0 / Cell.SIZE) - margin)
            local maxX = math.min(level.width - 1, math.ceil(screenWidth / Cell.SIZE) + margin)
            local minY = math.max(0, math.floor(0 / Cell.SIZE) - margin)
            local maxY = math.min(level.height - 1, math.ceil(screenHeight / Cell.SIZE) + margin)
            
            -- Count cells by type (only in visible area)
            for y = minY, maxY do
                for x = minX, maxX do
                    local cellType = level:getCellType(x, y)
                    if cellType == Cell.TYPES.SAND then
                        level.cellCounts.sandCount = level.cellCounts.sandCount + 1
                    elseif cellType == Cell.TYPES.STONE then
                        level.cellCounts.stoneCount = level.cellCounts.stoneCount + 1
                    elseif cellType == Cell.TYPES.TEMP_STONE then
                        level.cellCounts.tempStoneCount = level.cellCounts.tempStoneCount + 1
                    elseif cellType == Cell.TYPES.EMPTY then
                        level.cellCounts.emptyCount = level.cellCounts.emptyCount + 1
                    elseif cellType == Cell.TYPES.VISUAL_SAND then
                        level.cellCounts.visualSandCount = level.cellCounts.visualSandCount + 1
                    end
                end
            end
            
            -- Add visual sand particles count
            level.cellCounts.visualSandCount = level.cellCounts.visualSandCount + #(level.visualSandCells or {})
            level.lastCountTime = love.timer.getTime()
        end
        
        -- Use cached cell counts
        local sandCount = level.cellCounts.sandCount
        local stoneCount = level.cellCounts.stoneCount
        local tempStoneCount = level.cellCounts.tempStoneCount
        local emptyCount = level.cellCounts.emptyCount
        local visualSandCount = level.cellCounts.visualSandCount
        
        -- Display cell counts
        love.graphics.print("Sand: " .. sandCount, 10, 30)
        love.graphics.print("Stone: " .. stoneCount, 10, 50)
        love.graphics.print("Temp Stone: " .. tempStoneCount, 10, 70)
        love.graphics.print("Empty: " .. emptyCount, 10, 90)
        love.graphics.print("Visual Sand: " .. visualSandCount, 10, 110)
        
        -- Display ball info
        if ball.body then
            local x, y = ball.body:getPosition()
            local vx, vy = ball.body:getLinearVelocity()
            local speed = math.sqrt(vx*vx + vy*vy)
            love.graphics.print(string.format("Ball: x=%.1f, y=%.1f", x, y), 10, 130)
            love.graphics.print(string.format("Velocity: vx=%.1f, vy=%.1f", vx, vy), 10, 150)
            love.graphics.print(string.format("Speed: %.1f", speed), 10, 170)
        end
        
        -- Display optimization info
        love.graphics.print("Performance Optimization:", 10, 200)
        love.graphics.print("Cluster Size: " .. level.clusterSize .. "x" .. level.clusterSize, 10, 220)
        
        -- Count active clusters
        local clusterRows = math.ceil(level.height / level.clusterSize)
        local clusterCols = math.ceil(level.width / level.clusterSize)
        local activeClusterCount = 0
        local totalClusters = clusterRows * clusterCols
        
        for cy = 0, clusterRows - 1 do
            for cx = 0, clusterCols - 1 do
                if level.clusters[cy] and level.clusters[cy][cx] and level.clusters[cy][cx].active then
                    activeClusterCount = activeClusterCount + 1
                end
            end
        end
        
        love.graphics.print("Active Clusters: " .. activeClusterCount .. "/" .. totalClusters, 10, 240)
        love.graphics.print("Active Cells: " .. #level.activeCells, 10, 260)
        
        -- Draw active clusters
        love.graphics.setColor(0, 1, 0, 0.2)
        for cy = 0, clusterRows - 1 do
            for cx = 0, clusterCols - 1 do
                if level.clusters[cy] and level.clusters[cy][cx] and level.clusters[cy][cx].active then
                    love.graphics.rectangle(
                        "fill", 
                        cx * level.clusterSize * Cell.SIZE, 
                        cy * level.clusterSize * Cell.SIZE, 
                        level.clusterSize * Cell.SIZE, 
                        level.clusterSize * Cell.SIZE
                    )
                end
            end
        end
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
    elseif key == "s" then
        -- Add more sand for performance testing
        level:addLotsOfSand(1000)
        print("Added 1000 sand cells for performance testing")
    elseif key == "p" then
        -- Add a sand pile
        local x, y = ball.body:getPosition()
        local gridX, gridY = level:getGridCoordinates(x, y)
        level:addSandPile(gridX, gridY, 10, 20)
        print("Added a sand pile at ball position")
    end
end
