-- collision.lua - Collision handling for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local Collision = {}

-- Tables to track sand cells
Collision.sandToConvert = {} -- Table to store sand cells that need to be converted to flying sand

function Collision.beginContact(a, b, coll, level)
    local aData = a:getUserData()
    local bData = b:getUserData()
    
    -- Check if the ball is involved in the collision
    local isBallCollision = (aData == "ball" or bData == "ball")
    
    -- Handle collisions between ball and any cells
    if isBallCollision then
        -- Get the ball fixture and the other fixture
        local ballFixture, otherFixture
        if aData == "ball" then
            ballFixture = a
            otherFixture = b
        else
            ballFixture = b
            otherFixture = a
        end
        
        local ballBody = ballFixture:getBody()
        local ball = ballBody:getUserData() -- Get the ball object
        local otherData = otherFixture:getUserData()
        
        -- Get the ball's velocity
        local vx, vy = ballBody:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        
        -- Handle water collisions
        if otherData == "water" then
            -- Get the water cell position
            local waterBody = otherFixture:getBody()
            local waterX, waterY = waterBody:getPosition()
            local gridX, gridY = level:getGridCoordinates(waterX, waterY)
            
            -- Tell the ball it's in water
            if ball and ball.enterWater then
                ball:enterWater(gridX, gridY)
            end
        -- Handle sand collisions
        elseif otherData == "sand" then
            -- Get the sand cell position
            local sandBody = otherFixture:getBody()
            local sandX, sandY = sandBody:getPosition()
            local gridX, gridY = level:getGridCoordinates(sandX, sandY)
            
            -- Tell the ball it's in sand
            if ball and ball.enterSand then
                ball:enterSand(gridX, gridY)
            end
        end
        
        -- Create a crater if the ball hits sand, stone, or dirt with appropriate speed thresholds
        -- Lower threshold for sand, higher for dirt
        local createCrater = false
        if (otherData == "sand" and speed > 50) or  -- Much lower threshold for sand (was 100)
           (otherData == "dirt" and speed > 300) or  -- Keep dirt threshold the same
           (otherData == "stone" and speed > 300) then -- Keep stone threshold the same
            createCrater = true
        end
        
        if createCrater then
            -- Get the collision position
            local nx, ny = coll:getNormal()
            local x1, y1, x2, y2 = coll:getPositions()
            
            -- Use the collision position if available, otherwise use the fixture position
            local hitX, hitY
            if x1 and y1 then
                hitX, hitY = x1, y1
            else
                local hitBody = otherFixture:getBody()
                hitX, hitY = hitBody:getPosition()
            end
            
            local gridX, gridY = level:getGridCoordinates(hitX, hitY)
            
            print("Ball hit solid at", gridX, gridY, "with speed", speed)
            
            -- Slow down the ball more when it hits sand
            if otherData == "sand" then
                -- Apply a stronger damping force to the ball when it hits sand
                local dampingFactor = 0.7  -- Higher value means more damping
                local vx, vy = ballBody:getLinearVelocity()
                ballBody:setLinearVelocity(vx * (1 - dampingFactor), vy * (1 - dampingFactor))
                
                -- Also reduce angular velocity
                local av = ballBody:getAngularVelocity()
                ballBody:setAngularVelocity(av * (1 - dampingFactor))
            end
            
            -- Create the crater with visual particles
            -- Make the crater size appropriate for the material
            local directRadius = 2 -- Default radius
            if otherData == "sand" then
                -- Even more sensitive crater size for sand based on speed
                directRadius = 0.5 + math.min(3.5, speed / 150)  -- Changed from speed/200 to speed/150
            elseif otherData == "dirt" then
                -- Keep dirt calculation the same
                directRadius = 0.5 + math.min(2.0, (speed - 200) / 300)
            end
            for dy = -directRadius, directRadius do
                for dx = -directRadius, directRadius do
                    local checkX = gridX + dx
                    local checkY = gridY + dy
                    
                    -- Only affect sand and dirt cells within bounds
                    if checkX >= 0 and checkX < level.width and checkY >= 0 and checkY < level.height then
                        -- Make sure the cell exists
                        if level.cells[checkY] and level.cells[checkY][checkX] then
                            local cellType = level:getCellType(checkX, checkY)
                            if cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT then
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
            end
        end
    end
end

function Collision.endContact(a, b, coll, level)
    local aData = a:getUserData()
    local bData = b:getUserData()
    
    -- Check if the ball is involved in the collision
    local isBallCollision = (aData == "ball" or bData == "ball")
    
    -- Handle collisions between ball and any cells
    if isBallCollision then
        -- Get the ball fixture and the other fixture
        local ballFixture, otherFixture
        if aData == "ball" then
            ballFixture = a
            otherFixture = b
        else
            ballFixture = b
            otherFixture = a
        end
        
        local ballBody = ballFixture:getBody()
        local ball = ballBody:getUserData() -- Get the ball object
        local otherData = otherFixture:getUserData()
        
        -- Handle water collisions
        if otherData == "water" then
            -- Get the water cell position
            local waterBody = otherFixture:getBody()
            local waterX, waterY = waterBody:getPosition()
            local gridX, gridY = level:getGridCoordinates(waterX, waterY)
            
            -- Tell the ball it's exiting water
            if ball and ball.exitWater then
                ball:exitWater(gridX, gridY)
            end
        -- Handle sand collisions
        elseif otherData == "sand" then
            -- Get the sand cell position
            local sandBody = otherFixture:getBody()
            local sandX, sandY = sandBody:getPosition()
            local gridX, gridY = level:getGridCoordinates(sandX, sandY)
            
            -- Tell the ball it's exiting sand
            if ball and ball.exitSand then
                ball:exitSand(gridX, gridY)
            end
        end
    end
end

function Collision.preSolve(a, b, coll)
    -- Not used but required by LÖVE
end

function Collision.postSolve(a, b, coll, normalImpulse, tangentImpulse)
    -- Not used but required by LÖVE
end


return Collision
