-- collision.lua - Collision handling for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")

local Collision = {}

-- Tables to track sand cells
Collision.sandToConvert = {} -- Table to store sand cells that need to be converted to flying sand

function Collision.beginContact(a, b, coll, level, ball)
    -- Don't clear the sandToConvert array here, it's cleared in main.lua
    
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
        
        -- Get the ball object
        local ballObject = ballBody:getUserData()
        
        -- Create a crater if the ball hits a material with appropriate speed thresholds
        local createCrater = false
        
        -- Get the cell type from the fixture user data
        local cellType = nil
        if otherData == "sand" then
            cellType = CellTypes.TYPES.SAND
        elseif otherData == "dirt" then
            cellType = CellTypes.TYPES.DIRT
        elseif otherData == "stone" then
            cellType = CellTypes.TYPES.STONE
        end
        
        -- Check if the material has properties
        if cellType and CellTypes.PROPERTIES[cellType] then
            local threshold = CellTypes.PROPERTIES[cellType].displacementThreshold
            
            -- Adjust threshold based on ball type
            if ballObject and ballObject.ballType then
                if ballObject.ballType == Balls.TYPES.HEAVY then
                    -- Heavy ball has lower threshold (easier to displace terrain)
                    threshold = threshold * 0.6
                elseif ballObject.ballType == Balls.TYPES.STICKY then
                    -- Sticky ball has higher threshold (harder to displace terrain)
                    threshold = threshold * 2.0
                end
            end
            
            -- Check if speed exceeds the adjusted threshold
            if speed > threshold then
                createCrater = true
            end
        end
        
        -- Handle sticky ball sticking
        if ballObject and ballObject.ballType == Balls.TYPES.STICKY and speed < 100 then
            -- Sticky ball sticks on impact if not moving too fast
            ballObject.stuck = true
        end
        
        -- Handle exploding ball explosion
        if ballObject and ballObject.ballType == Balls.TYPES.EXPLODING and speed > 100 then
            -- Exploding ball explodes on high-speed impact
            local result = ballObject:explode(level, Collision.sandToConvert)
            
            -- Check if we should switch to standard ball
            if result == "switch_to_standard" then
                -- We'll set a flag on the ball object to indicate it should be switched
                -- The actual switching will happen in the main update loop
                ballObject.shouldSwitchToStandard = true
            end
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
            
                -- Special case for direct hit: If the hit cell is sand or dirt and meets the direct hit threshold
                local directHitThreshold = CellTypes.PROPERTIES[cellType].directHitThreshold
                
                -- Adjust threshold based on ball type
                if ballObject and ballObject.ballType then
                if ballObject.ballType == Balls.TYPES.HEAVY then
                    -- Heavy ball has lower threshold (easier to displace terrain)
                    directHitThreshold = directHitThreshold * 0.6
                elseif ballObject.ballType == Balls.TYPES.STICKY then
                    -- Sticky ball has higher threshold (harder to displace terrain)
                    directHitThreshold = directHitThreshold * 2.0
                    end
                end
                
                if (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT) and 
                   CellTypes.PROPERTIES[cellType] and 
                   speed > directHitThreshold then
                
                local cellTypeName = cellType == CellTypes.TYPES.SAND and "sand" or "dirt"
                
                -- Clear the cell directly
                level:setCellType(gridX, gridY, CellTypes.TYPES.EMPTY)
                
                -- Only queue up for conversion if speed is above threshold
                if speed > CellTypes.PROPERTIES[cellType].displacementThreshold then
                    -- Queue up for conversion
                    table.insert(Collision.sandToConvert, {
                        x = gridX,
                        y = gridY,
                        vx = 0,
                        vy = 0, -- No upward boost
                        originalType = cellType, -- Store the original cell type
                        shouldConvert = true -- Flag to indicate this cell should be converted
                    })
                end
            end
            
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
            
            -- Calculate crater size based on material properties
            if cellType and CellTypes.PROPERTIES[cellType] then
                local props = CellTypes.PROPERTIES[cellType]
                directRadius = props.craterBaseRadius + 
                               math.min(props.craterMaxRadius, 
                                       speed / props.craterSpeedDivisor)
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
                            
                            -- Calculate distance for all cells
                            local distance = math.sqrt(dx*dx + dy*dy)
                            
                            if cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT then
                                
                                -- For direct hits, always convert the cell (dx=0, dy=0) regardless of radius
                                -- if it meets the direct hit threshold
                                local shouldConvert = distance <= directRadius
                                
                                -- Check for direct hit on a sand or dirt cell with properties
                                if dx == 0 and dy == 0 and 
                                   (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT) and
                                   CellTypes.PROPERTIES[cellType] and 
                                   speed > CellTypes.PROPERTIES[cellType].directHitThreshold then
                                    shouldConvert = true
                                end
                                
                                if shouldConvert then
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
                                    
                                    -- Only queue up sand and dirt cells for conversion if speed is above threshold
                                    if (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT) and
                                       CellTypes.PROPERTIES[cellType] and
                                       speed > CellTypes.PROPERTIES[cellType].displacementThreshold then
                                        
                                        -- Clear the cell
                                        level:setCellType(checkX, checkY, CellTypes.TYPES.EMPTY)
                                        
                                        -- Queue up for conversion
                                        table.insert(Collision.sandToConvert, {
                                            x = checkX,
                                            y = checkY,
                                            vx = flyVx,
                                            vy = flyVy,
                                            originalType = cellType, -- Store the original cell type
                                            shouldConvert = true -- Flag to indicate this cell should be converted
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
