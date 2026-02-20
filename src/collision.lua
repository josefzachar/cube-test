-- collision.lua - Collision handling for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")
local Sound = require("src.sound")

local Collision = {}

-- Tables to track sand cells
Collision.sandToConvert = {} -- Table to store sand cells that need to be converted to flying sand
Collision.iceToMelt = {}    -- Table to store ICE cells that need to convert to WATER (deferred, outside physics lock)

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
        -- Prefer body user-data (set in game_init), fall back to the passed-in ball parameter
        local ball = ballBody:getUserData() or ball
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
            
            -- Set the win flag on the ball (only once)
            if ball and not ball.hasWon then
                ball.hasWon = true

                -- Store the entry speed so the fall-animation can react to it
                ball.winEntrySpeed = speed

                -- Play win sound
                Sound.playWin()

                -- Find centroid of all win-hole cells so the ball has an exact target to fall into
                local holeSumX, holeSumY, holeCount = 0, 0, 0
                for gy = 0, level.height - 1 do
                    for gx = 0, level.width - 1 do
                        if level.cells[gy] and level.cells[gy][gx] and
                           level.cells[gy][gx].type == CellTypes.TYPES.WIN_HOLE then
                            holeSumX  = holeSumX  + gx
                            holeSumY  = holeSumY  + gy
                            holeCount = holeCount + 1
                        end
                    end
                end
                if holeCount > 0 then
                    ball.winHoleCenterX = (holeSumX / holeCount + 0.5) * Cell.SIZE
                    ball.winHoleCenterY = (holeSumY / holeCount + 0.5) * Cell.SIZE
                end

                print("Ball entered win hole! Player wins!")
            end
        -- Handle water collisions
        elseif otherData == "water" then
            -- Get the water cell position
            local waterBody = otherFixture:getBody()
            local waterX, waterY = waterBody:getPosition()
            local gridX, gridY = level:getGridCoordinates(waterX, waterY)
            
            -- Tell the ball it's in water
            -- Special case for water ball - it manages its own water detection via grid scan
            if ball and ball.enterWater then
                if not (ball.ballType == Balls.TYPES.WATER_BALL) then
                    ball:enterWater(gridX, gridY)
                end
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
        elseif otherData == "ice" then
            cellType = CellTypes.TYPES.ICE
        end
        
        -- Check if the material has properties
        if cellType and CellTypes.PROPERTIES[cellType] then
            local threshold = CellTypes.PROPERTIES[cellType].displacementThreshold
            
            -- Adjust threshold based on ball type
            if ballObject and ballObject.ballType then
                if ballObject.ballType == Balls.TYPES.HEAVY then
                    -- Heavy ball has a lower threshold for sand/dirt (easier to displace)
                    -- but not as absurdly low as before — sand still needs a real hit
                    if cellType ~= CellTypes.TYPES.STONE then
                        threshold = threshold * 0.35
                    end
                    -- Stone is NOT easier to displace for heavy ball
                elseif ballObject.ballType == Balls.TYPES.STICKY then
                    -- Sticky ball has higher threshold (harder to displace terrain)
                    threshold = threshold * 2.0
                elseif ballObject.ballType == Balls.TYPES.BULLET then
                    -- Bullet ball skips the standard crater system entirely;
                    -- penetration is handled in bullet_ball:update()
                    threshold = math.huge
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
            
            -- Use the collision position if available, otherwise use the fixture position.
            -- For ICE we always use the body center: the contact point lands on the cell's
            -- top edge and floor() maps it to the empty row above, causing water to spawn
            -- in the wrong cell instead of replacing the ice.
            local hitX, hitY
            if cellType == CellTypes.TYPES.ICE then
                local iceBody = otherFixture:getBody()
                hitX, hitY = iceBody:getPosition()
            elseif x1 and y1 then
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
                    -- Heavy ball hits sand/dirt more easily, but doesn't affect stone
                    if cellType ~= CellTypes.TYPES.STONE then
                        directHitThreshold = directHitThreshold * 0.35
                    end
                elseif ballObject.ballType == Balls.TYPES.STICKY then
                    -- Sticky ball has higher threshold (harder to displace terrain)
                    directHitThreshold = directHitThreshold * 2.0
                    end
                end
                
                -- Only sand, dirt and ice can be displaced on direct hit (stone is never affected)
                -- ICE can only be broken by the heavy ball
                local isHeavyBall = ballObject and ballObject.ballType == Balls.TYPES.HEAVY
                local canDirectHit = (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT
                                      or (cellType == CellTypes.TYPES.ICE and isHeavyBall))
                
                if canDirectHit and CellTypes.PROPERTIES[cellType] and speed > directHitThreshold then
                
                local cellTypeName = cellType == CellTypes.TYPES.SAND and "sand" or "dirt"
                
                -- Ice shatters back to water instead of becoming a particle
                if cellType == CellTypes.TYPES.ICE then
                    table.insert(Collision.iceToMelt, {x = gridX, y = gridY})
                else
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
            end
            
            -- Slow down the ball more when it hits sand
            if otherData == "sand" then
                -- Special case for spraying/bullet balls - don't slow down
                if not (ballObject and (ballObject.ballType == Balls.TYPES.SPRAYING or
                                        ballObject.ballType == Balls.TYPES.BULLET)) then
                    -- Damping amount is ball-type specific (heavy ball carries more momentum)
                    local dampingFactor = (ballObject and ballObject.getSandCollisionDamping)
                                         and ballObject:getSandCollisionDamping() or 0.35
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
                
                -- Heavy ball creates noticeably bigger craters, but not an explosion
                if ballObject and ballObject.ballType == Balls.TYPES.HEAVY then
                    directRadius = directRadius * 2
                end
            end

            -- For sand: cap the crater radius to the actual sand density in the area.
            -- This prevents a single grain of sand on dirt from producing a huge blast.
            if cellType == CellTypes.TYPES.SAND then
                local sandCount = 0
                local scanR = math.ceil(directRadius)
                for sy = -scanR, scanR do
                    for sx = -scanR, scanR do
                        local cx2, cy2 = gridX + sx, gridY + sy
                        if cx2 >= 0 and cx2 < level.width and cy2 >= 0 and cy2 < level.height then
                            if level.cells[cy2] and level.cells[cy2][cx2] and
                               level:getCellType(cx2, cy2) == CellTypes.TYPES.SAND then
                                sandCount = sandCount + 1
                            end
                        end
                    end
                end
                -- Radius grows with sqrt of sand volume; minimum 1 so single cells
                -- still get a small displacement effect.
                local densityRadius = math.sqrt(sandCount) * 0.8
                directRadius = math.min(directRadius, math.max(densityRadius, 1))
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
                            
                            -- Only sand and dirt are displaced by crater physics (stone is never blasted)
                            -- Ice in crater radius also shatters to water, but only for heavy ball
                            local isHeavyBall = ballObject and ballObject.ballType == Balls.TYPES.HEAVY
                            local canAffectCell = (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT
                                                   or (cellType == CellTypes.TYPES.ICE and isHeavyBall))
                            
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
                                    
                                    -- Heavy ball sends sand flying with more force, but not chaotically
                                    if ballObject and ballObject.ballType == Balls.TYPES.HEAVY then
                                        flyVx = flyVx * 2.0
                                        flyVy = flyVy * 2.0
                                    end
                                    
                                    -- Add randomness
                                    if ballObject and ballObject.ballType == Balls.TYPES.HEAVY then
                                        flyVx = flyVx + math.random(-100, 100)
                                        flyVy = flyVy + math.random(-100, 100)
                                    else
                                        flyVx = flyVx + math.random(-50, 50)
                                        flyVy = flyVy + math.random(-50, 50)
                                    end
                                    
                                    -- Queue up sand/dirt cells for conversion (stone is never converted)
                                    local canConvert = (cellType == CellTypes.TYPES.SAND or cellType == CellTypes.TYPES.DIRT) and
                                                      CellTypes.PROPERTIES[cellType] and
                                                      speed > CellTypes.PROPERTIES[cellType].displacementThreshold

                                    -- Ice shatters to water inside the crater radius
                                    if cellType == CellTypes.TYPES.ICE and
                                       CellTypes.PROPERTIES[cellType] and
                                       speed > CellTypes.PROPERTIES[cellType].displacementThreshold then
                                        table.insert(Collision.iceToMelt, {x = checkX, y = checkY})
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

    -- ── Barrel collision detection ─────────────────────────────────────────
    -- Determine if a barrel is involved in this contact
    local barrelFixture, otherFixtureB
    if type(aData) == "table" and aData.isBarrel then
        barrelFixture  = a
        otherFixtureB  = b
    elseif type(bData) == "table" and bData.isBarrel then
        barrelFixture  = b
        otherFixtureB  = a
    end

    if barrelFixture then
        local barrel    = barrelFixture:getUserData()
        local otherData = otherFixtureB:getUserData()

        -- Sand, water, fire, smoke, and win-hole do NOT trigger the barrel.
        -- Only hard collisions (ball, boulder, another barrel, or solid cells) do.
        local isSoft = (otherData == "sand"     or otherData == "water" or
                        otherData == "fire"     or otherData == "smoke" or
                        otherData == "win_hole")

        if not isSoft and barrel and not barrel.exploded and barrel.armed then
            -- Use relative velocity so a gently-resting barrel is not triggered
            local barrelBody = barrelFixture:getBody()
            local otherBody  = otherFixtureB:getBody()
            local bvx, bvy   = barrelBody:getLinearVelocity()
            local ovx, ovy   = otherBody:getLinearVelocity()
            local relVx, relVy = bvx - ovx, bvy - ovy
            local relSpeed     = math.sqrt(relVx * relVx + relVy * relVy)

            if relSpeed > 200 then
                barrel.pendingExplosion = true
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
            -- Special case for water ball - it manages its own water detection via grid scan
            if ball and ball.exitWater then
                if not (ball.ballType == Balls.TYPES.WATER_BALL) then
                    ball:exitWater(gridX, gridY)
                end
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
        
        -- If it's a bullet ball that has been launched, disable collisions with
        -- sand, dirt and water so it physically passes through them.
        -- When NOT launched (ball resting on terrain) collisions are kept enabled.
        if ballObject and ballObject.ballType == Balls.TYPES.BULLET
                and ballObject.isLaunched and (ballObject.penetrationEnergy or 0) > 0 then
            if otherData == "sand" or otherData == "dirt" or otherData == "water" or otherData == "ice" then
                coll:setEnabled(false)
                return
            end
        end

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
