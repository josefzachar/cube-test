-- collision.lua - Collision handling for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local Collision = {}

-- Tables to track sand cells
Collision.sandToStone = {} -- Table to track sand cells converted to stone
Collision.sandToConvert = {} -- Table to store sand cells that need to be converted to flying sand
Collision.tempStoneCells = {} -- Table to store temporary stone cells for ball collision

function Collision.beginContact(a, b, coll, level)
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
                        if level:getCellType(checkX, checkY) == CellTypes.TYPES.TEMP_STONE then
                            -- Convert back to sand first
                            level:setCellType(checkX, checkY, CellTypes.TYPES.SAND)
                            
                            -- Also remove from the sandToStone list to prevent it from being converted back
                            for i = #Collision.sandToStone, 1, -1 do
                                if Collision.sandToStone[i].x == checkX and Collision.sandToStone[i].y == checkY then
                                    table.remove(Collision.sandToStone, i)
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
                        if level:getCellType(checkX, checkY) == CellTypes.TYPES.SAND then
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
                                table.insert(Collision.sandToConvert, {
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

function Collision.endContact(a, b, coll)
    -- Not used but required by LÖVE
end

function Collision.preSolve(a, b, coll)
    -- Not used but required by LÖVE
end

function Collision.postSolve(a, b, coll, normalImpulse, tangentImpulse)
    -- Not used but required by LÖVE
end

function Collision.updateTempStone(dt)
    -- Convert temporary stone cells back to sand
    local i = 1
    while i <= #Collision.sandToStone do
        local cell = Collision.sandToStone[i]
        if cell.timer > 0 then
            cell.timer = cell.timer - dt
            i = i + 1
        else
            -- Remove from the list
            table.remove(Collision.sandToStone, i)
            -- Don't increment i since we removed an element
        end
    end
end

function Collision.clearTempStoneCells()
    -- Clear any temporary stone cells from the previous frame
    for _, cell in ipairs(Collision.tempStoneCells) do
        if cell.body then
            cell.body:destroy()
        end
    end
    Collision.tempStoneCells = {}
end

return Collision
