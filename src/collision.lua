-- collision.lua - Collision handling for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")
local Sound = require("src.sound")

local Collision = {}

-- Tables to track sand cells
Collision.sandToConvert = {} -- Table to store sand cells that need to be converted to flying sand

function Collision.beginContact(a, b, coll, level, ball)
    -- Don't clear the sandToConvert array here, it's cleared in main.lua
    
    local aData = a:getUserData()
    local bData = b:getUserData()
    
    -- Check if the ball is involved in the collision
    local isBallCollision = (aData == "ball" or bData == "ball" or 
                            (type(aData) == "table" and aData.ballType) or 
                            (type(bData) == "table" and bData.ballType))
    
    -- Handle collisions between ball and any cells
    if isBallCollision then
        -- Get the ball fixture and the other fixture
        local ballFixture, otherFixture
        if aData == "ball" or (type(aData) == "table" and aData.ballType) then
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
        
        -- Get the ball object to check if it's in water
        local ballObject = ballBody:getUserData()
        local inWater = ballObject and ballObject.inWater
        
        -- Play sound based on the cell type, but only if not in water
        if otherData == "water" and not inWater then
            -- Play water sound only when entering water
            -- For water entry, use a slightly enhanced speed value to make splash more pronounced
            local splashSpeed = math.max(speed, 100) -- Minimum splash volume threshold
            Sound.playCollisionSound(CellTypes.TYPES.WATER, splashSpeed)
        elseif not inWater then
            -- Play other sounds only if not in water
            if otherData == "sand" then
                Sound.playCollisionSound(CellTypes.TYPES.SAND, speed)
            elseif otherData == "dirt" then
                Sound.playCollisionSound(CellTypes.TYPES.DIRT, speed)
            elseif otherData == "stone" then
                Sound.playCollisionSound(CellTypes.TYPES.STONE, speed)
            else
                -- Default to grass sound for empty cells or other types
                Sound.playCollisionSound(nil, speed)
            end
        end
        
        -- Handle win hole collisions
        if otherData == "win_hole" then
            -- Get the win hole cell position
            local winHoleBody = otherFixture:getBody()
            local winHoleX, winHoleY = winHoleBody:getPosition()
            local gridX, gridY = level:getGridCoordinates(winHoleX, winHoleY)
            
            -- Set the win flag on the ball
            if ball then
                ball.hasWon = true
                
                -- Play win sound
                Sound.playWin()
                
                print("Ball entered win hole! Player wins!")
                print("Ball position:", ballBody:getX(), ballBody:getY())
                print("Win hole position:", winHoleX, winHoleY)
                print("Win hole grid coordinates:", gridX, gridY)
                print("Ball hasWon flag:", ball.hasWon)
            end
        -- Handle water collisions
        elseif otherData == "water" then
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
                -- Special case for spraying ball - don't enter sand if it's a spraying ball
                if not (ball.ballType == Balls.TYPES.SPRAYING) then
                    ball:enterSand(gridX, gridY)
                end
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
                    -- Heavy ball has ridiculously low threshold (ridiculously easy to displace terrain)
                    threshold = threshold * 0.1 -- Changed from 0.2 to 0.1 (10x more effective than standard)
                    
                    -- Special case for stone - allow heavy ball to affect stone
                    if cellType == CellTypes.TYPES.STONE then
                        -- Still hard to break stone, but possible with heavy ball
                        threshold = threshold * 0.5 -- 50% of the already reduced threshold
                    end
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
        
        -- Handle sticky ball sticking - only stick to material cells if it doesn't have attached sand
        if ballObject and ballObject.ballType == Balls.TYPES.STICKY and 
           (otherData == "sand" or otherData == "dirt" or otherData == "stone") then
            
            -- Special case for sand cells - attach them to the sticky ball
            if otherData == "sand" then
                -- Get the sand cell position
                local sandBody = otherFixture:getBody()
                local sandX, sandY = sandBody:getPosition()
                local gridX, gridY = level:getGridCoordinates(sandX, sandY)
                
                -- Attach the sand cell to the sticky ball
                if ballObject.attachSandCell then
                    -- Pass the level directly to the attachSandCell method
                    ballObject:attachSandCell(gridX, gridY, level)
                end
            end
            
            -- Only stick if the ball doesn't have attached sand cells
            if #ballObject.attachedSandCells == 0 then
                -- Sticky ball sticks on impact with material cells
                ballObject.stuck = true
                
                -- Immediately stop the ball to simulate sticking
                ballBody:setLinearVelocity(0, 0)
                ballBody:setAngularVelocity(0)
            end
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
                    -- Heavy ball has ridiculously low threshold (ridiculously easy to displace terrain)
                    directHitThreshold = directHitThreshold * 0.1 -- Changed from 0.2 to 0.1 (10x more effective than standard)
                    
                    -- Special case for stone - allow heavy ball to affect stone
                    if cellType == CellTypes.TYPES.STONE then
                        -- Still hard to break stone, but possible with heavy ball
                        directHitThreshold = directHitThreshold * 0.5 -- 50% of the already reduced threshold
                    end
                elseif ballObject.ballType == Balls.TYPES.STICKY then
                    -- Sticky ball has higher threshold (harder to displace terrain)
                    directHitThreshold = directHitThreshold * 2.0
                    end
                end
                
                -- Allow heavy ball to affect stone on direct hit too
                local canDirectHit = (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT)
                
                -- Special case for heavy ball - can also affect stone on direct hit
                if ballObject and ballObject.ballType == Balls.TYPES.HEAVY and cellType == CellTypes.TYPES.STONE then
                    canDirectHit = true
                end
                
                if canDirectHit and CellTypes.PROPERTIES[cellType] and speed > directHitThreshold then
                
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
                -- Special case for spraying ball - don't slow down if it's a spraying ball
                if not (ballObject and ballObject.ballType == Balls.TYPES.SPRAYING) then
                    -- Apply a stronger damping force to the ball when it hits sand
                    local dampingFactor = 0.7  -- Higher value means more damping
                    local vx, vy = ballBody:getLinearVelocity()
                    ballBody:setLinearVelocity(vx * (1 - dampingFactor), vy * (1 - dampingFactor))
                    
                    -- Also reduce angular velocity
                    local av = ballBody:getAngularVelocity()
                    ballBody:setAngularVelocity(av * (1 - dampingFactor))
                end
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
                
                -- Heavy ball creates MASSIVE craters
                if ballObject and ballObject.ballType == Balls.TYPES.HEAVY then
                    -- Triple the crater size for heavy ball
                    directRadius = directRadius * 3
                end
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
                            
                            -- Allow heavy ball to affect stone cells too
                            local canAffectCell = (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT)
                            
                            -- Special case for heavy ball - can also affect stone
                            if ballObject and ballObject.ballType == Balls.TYPES.HEAVY and cellType == CellTypes.TYPES.STONE then
                                -- Heavy ball can affect stone cells with a much higher chance
                                -- Use a fixed threshold for stone since we don't have the original threshold here
                                local stoneThreshold = 200 -- Lower threshold for stone (was 300)
                                if speed > stoneThreshold and distance <= directRadius * 0.8 then -- Larger area (was 0.5)
                                    canAffectCell = true
                                end
                            end
                            
                            if canAffectCell then
                                
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
                                    
                                    -- Heavy ball sends cells flying with INSANE force
                                    if ballObject and ballObject.ballType == Balls.TYPES.HEAVY then
                                        flyVx = flyVx * 4.0 -- Quadruple the horizontal velocity
                                        flyVy = flyVy * 4.0 -- Quadruple the vertical velocity
                                    end
                                    
                                    -- Add randomness
                                    if ballObject and ballObject.ballType == Balls.TYPES.HEAVY then
                                        -- MUCH more randomness for heavy ball - creates chaotic explosions
                                        flyVx = flyVx + math.random(-200, 200)
                                        flyVy = flyVy + math.random(-200, 200)
                                    else
                                        -- Normal randomness for other balls
                                        flyVx = flyVx + math.random(-50, 50)
                                        flyVy = flyVy + math.random(-50, 50)
                                    end
                                    
                                    -- Queue up cells for conversion if speed is above threshold
                                    -- Allow heavy ball to convert stone cells to flying particles too
                                    local canConvert = (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT) and
                                                      CellTypes.PROPERTIES[cellType] and
                                                      speed > CellTypes.PROPERTIES[cellType].displacementThreshold
                                    
                                    -- Special case for heavy ball - can convert stone to flying particles
                                    if ballObject and ballObject.ballType == Balls.TYPES.HEAVY and 
                                       cellType == CellTypes.TYPES.STONE and
                                       CellTypes.PROPERTIES[cellType] and
                                       speed > 200 then -- Much lower threshold for stone (was 400)
                                        canConvert = true
                                    end
                                    
                                    if canConvert then
                                        
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
    local isBallCollision = (aData == "ball" or bData == "ball" or 
                            (type(aData) == "table" and aData.ballType) or 
                            (type(bData) == "table" and bData.ballType))
    
    -- Handle collisions between ball and any cells
    if isBallCollision then
        -- Get the ball fixture and the other fixture
        local ballFixture, otherFixture
        if aData == "ball" or (type(aData) == "table" and aData.ballType) then
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
    local aData = a:getUserData()
    local bData = b:getUserData()
    
    -- Check if the ball is involved in the collision
    local isBallCollision = (aData == "ball" or bData == "ball" or 
                            (type(aData) == "table" and aData.ballType) or 
                            (type(bData) == "table" and bData.ballType))
    
    if isBallCollision then
        -- Get the ball fixture and the other fixture
        local ballFixture, otherFixture
        if aData == "ball" or (type(aData) == "table" and aData.ballType) then
            ballFixture = a
            otherFixture = b
        else
            ballFixture = b
            otherFixture = a
        end
        
        local ballBody = ballFixture:getBody()
        local ballObject = ballBody:getUserData() -- Get the ball object
        local otherData = otherFixture:getUserData()
        
        -- If it's a spraying ball, only disable collisions with the material it's currently spraying
        if ballObject and ballObject.ballType == Balls.TYPES.SPRAYING then
            -- Get the current material the ball is spraying
            local currentMaterial = ballObject.currentMaterial
            local materialMode = ballObject.materialMode
            
            -- If in random mode, we need to check the current material
            if materialMode == require("src.balls.spraying_ball").RANDOM_MODE then
                -- In random mode, we still need to collide with the ground
                -- Only disable collisions if we're sure it's a material the ball just sprayed
                -- This is a simplification - we'll only disable sand collisions in random mode
                if otherData == "sand" then
                    coll:setEnabled(false)
                end
            else
                -- Check if the collision is with the material the ball is currently spraying
                local shouldDisable = false
                
                if currentMaterial == CellTypes.TYPES.SAND and otherData == "sand" then
                    shouldDisable = true
                elseif currentMaterial == CellTypes.TYPES.DIRT and otherData == "dirt" then
                    shouldDisable = true
                elseif currentMaterial == CellTypes.TYPES.STONE and otherData == "stone" then
                    shouldDisable = true
                elseif currentMaterial == CellTypes.TYPES.WATER and otherData == "water" then
                    shouldDisable = true
                end
                
                if shouldDisable then
                    coll:setEnabled(false) -- Disable the collision
                end
            end
        end
    end
end

function Collision.postSolve(a, b, coll, normalImpulse, tangentImpulse)
    -- Not used but required by LÖVE
end


return Collision
