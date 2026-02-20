-- ball_base.lua - Base class for all ball types

local CellTypes = require("src.cell_types")

local Ball = {}
Ball.__index = Ball

-- Ball types enum
Ball.TYPES = {
    STANDARD = 1,
    HEAVY = 2,
    EXPLODING = 3,
    STICKY = 4,
    SPRAYING = 5
}

-- Colors
Ball.COLORS = {
    WHITE = {1, 1, 1, 1},
    BLUE_TINT = {0.8, 0.8, 1, 1}, -- Slight blue tint for when ball is in water
    SAND_TINT = {1, 0.9, 0.7, 1}, -- Slight yellow/brown tint for when ball is in sand
    HEAVY_COLOR = {0.6, 0.6, 0.8, 1}, -- Dark blue for heavy ball
    EXPLODING_COLOR = {1, 0.4, 0.2, 1}, -- Orange-red for exploding ball
    STICKY_COLOR = {0.3, 0.8, 0.3, 1}, -- Green for sticky ball
    SPRAYING_COLOR = {0.9, 0.8, 0.3, 1} -- Yellow-orange for spraying ball
}

-- Base constructor for all ball types
function Ball.new(world, x, y, ballType)
    local self = setmetatable({}, Ball)
    
    -- Set ball type (default to STANDARD if not specified)
    self.ballType = ballType or Ball.TYPES.STANDARD
    
    -- Create the square ball
    self.body = love.physics.newBody(world, x, y, "dynamic")
    self.shape = love.physics.newRectangleShape(20, 20) -- 20x20 square
    
    -- Ensure the ball doesn't float by setting a higher density
    self.body:setMassData(0, 0, 2, 0) -- Increase the mass to prevent floating
    
    -- Default physics properties (will be overridden by specific ball types)
    self.fixture = love.physics.newFixture(self.body, self.shape, 2)
    self.fixture:setRestitution(0.3)
    self.fixture:setFriction(0.5)
    self.fixture:setUserData("ball")
    
    self.isLaunched = false
    self.size = 20 -- Store the ball size for collision detection
    self.inWater = false -- Flag to track if the ball is in water
    self.waterCells = {} -- Table to track which water cells the ball is in
    self.inSand = false -- Flag to track if the ball is in sand
    self.sandCells = {} -- Table to track which sand cells the ball is in
    self.world = world -- Store the world for later use
    
    return self
end

-- Update method - handles physics updates
function Ball:update(dt)
    -- Handle ball winning condition: play a satisfying fall-into-hole animation
    if self.hasWon then
        -- Initialise animation state on the very first frame
        if not self.winAnimTimer then
            self.winAnimTimer = 0
            self.scale        = 1.0
            self.body:setGravityScale(0)
            self.body:setLinearVelocity(0, 0)
            self.body:setLinearDamping(20)
            self.body:setAngularDamping(2)

            -- Determine initial orbit position relative to hole centre
            local bx, by = self.body:getPosition()
            local cx = self.winHoleCenterX or bx
            local cy = self.winHoleCenterY or by
            local odx = bx - cx
            local ody = by - cy
            self.winOrbitStartRadius = math.max(math.sqrt(odx*odx + ody*ody), 18)
            self.winOrbitAngle       = math.atan2(ody, odx)
            self.winOrbitDir         = 1  -- counter-clockwise (matches majority of orbit particles)

            -- Spawn burst particles that shoot outward from ball position
            self.winBurst = {}
            local burstColors = {
                {0.80, 0.20, 1.00}, {0.90, 0.40, 1.00},
                {0.55, 0.05, 0.90}, {1.00, 0.60, 1.00},
                {1.00, 1.00, 1.00},
            }
            local es = self.winEntrySpeed or 0
            local numParticles = es > 280 and 28 or (es > 80 and 20 or 12)
            for i = 1, numParticles do
                local angle = (i / numParticles) * math.pi * 2 + math.random() * 0.6
                local spd   = 100 + math.random() * (100 + es * 0.6)
                local col   = burstColors[math.random(#burstColors)]
                local sz    = (math.random(2) == 1) and 2 or 4
                table.insert(self.winBurst, {
                    x = bx, y = by,
                    vx = math.cos(angle) * spd,
                    vy = math.sin(angle) * spd - 30,  -- slight upward bias
                    life = 0,
                    maxLife = 0.25 + math.random() * 0.35,
                    col = col,
                    sz  = sz,
                })
            end

            -- Animation duration and base orbit speed from entry speed
            if es > 280 then
                self.winAnimDuration = 1.0
                self.winBaseAngSpeed = 2.8
            elseif es > 80 then
                self.winAnimDuration = 1.6
                self.winBaseAngSpeed = 1.8
            else
                self.winAnimDuration = 2.2
                self.winBaseAngSpeed = 1.1
            end
        end

        -- Update burst particles
        if self.winBurst then
            local i = 1
            while i <= #self.winBurst do
                local p = self.winBurst[i]
                p.x    = p.x + p.vx * dt
                p.y    = p.y + p.vy * dt
                p.vy   = p.vy + 400 * dt  -- gravity pulls them back down
                p.life = p.life + dt
                if p.life >= p.maxLife then
                    table.remove(self.winBurst, i)
                else
                    i = i + 1
                end
            end
        end

        self.winAnimTimer = self.winAnimTimer + dt
        local progress    = math.min(self.winAnimTimer / self.winAnimDuration, 1.0)

        -- Spiral orbit: radius shrinks, angular speed grows (conservation of angular momentum)
        local radFrac       = math.max(0.0, 1.0 - progress ^ 0.75)
        local currentRadius = self.winOrbitStartRadius * radFrac

        -- ω ∝ 1/r  (faster spin as it tightens toward the singularity)
        local angSpeed = self.winBaseAngSpeed
            * self.winOrbitStartRadius / math.max(currentRadius, 3)
        self.winOrbitAngle = self.winOrbitAngle + angSpeed * self.winOrbitDir * dt

        -- Teleport ball to its spiral position (physics body, no velocity fighting)
        if self.winHoleCenterX and self.winHoleCenterY then
            local tx = self.winHoleCenterX + math.cos(self.winOrbitAngle) * currentRadius
            local ty = self.winHoleCenterY + math.sin(self.winOrbitAngle) * currentRadius
            self.body:setPosition(tx, ty)
            self.body:setLinearVelocity(0, 0)
        end

        -- Visual rotation matches orbital spin
        self.body:setAngularVelocity(angSpeed * self.winOrbitDir * 3)

        -- Scale shrinks only in the final 40% (ball "absorbs" into singularity)
        local scaleProg = math.max(0.0, (progress - 0.60) / 0.40)
        self.scale      = math.max(0, 1.0 - scaleProg * scaleProg * (3 - 2 * scaleProg))

        if progress >= 1.0 then
            self.scale = 0
            return true  -- animation finished
        end
        return false  -- still animating
    end
    
    -- Get ball velocity
    local vx, vy = self.body:getLinearVelocity()
    local speed = math.sqrt(vx*vx + vy*vy)
    
    -- Apply a small torque to make the square rotate more naturally when moving
    if speed > 50 then
        -- Apply torque proportional to speed and direction
        self.body:applyTorque(vx * 0.1)
    end
    
    -- Apply water resistance if the ball is in water
    if self.inWater and speed > 10 then
        -- Calculate drag force (proportional to velocity squared)
        local dragCoefficient = self:getWaterDragCoefficient()
        
        local dragForceX = -vx * speed * dragCoefficient
        local dragForceY = -vy * speed * dragCoefficient
        
        -- Apply buoyancy (upward force)
        local buoyancyForce = self:getBuoyancyForce()
        
        -- Apply the forces
        self.body:applyForce(dragForceX, dragForceY + buoyancyForce)
    end
    
    -- Apply sand resistance if the ball is in sand
    if self.inSand and speed > 5 then
        -- Calculate drag force (proportional to velocity squared)
        local sandDragCoefficient = self:getSandDragCoefficient()
        
        local dragForceX = -vx * speed * sandDragCoefficient
        local dragForceY = -vy * speed * sandDragCoefficient
        
        -- Apply the forces - no buoyancy in sand, just resistance
        self.body:applyForce(dragForceX, dragForceY)
        
        -- Also apply a damping effect to angular velocity
        local av = self.body:getAngularVelocity()
        self.body:setAngularVelocity(av * 0.99) -- Reduced damping from 0.95 to 0.97
    end
    
    -- Check if ball has stopped
    local stoppedThreshold = self:getStoppedThreshold()
    
    if speed < stoppedThreshold then
        self.isLaunched = false
        return true -- Ball is stationary
    else
        return false -- Ball is still moving
    end
end

-- Check if the ball is colliding with a cell at the given position
function Ball:isCollidingWithCell(cellX, cellY, cellSize)
    local ballX, ballY = self.body:getPosition()
    local ballHalfWidth = self.size / 2
    
    -- Get ball velocity for predictive collision
    local vx, vy = self.body:getLinearVelocity()
    local speed = math.sqrt(vx*vx + vy*vy)
    
    -- For fast-moving balls, use velocity to predict collision
    local predictiveDistance = 0
    if speed > 100 then
        -- Normalize velocity
        local nvx = vx / speed
        local nvy = vy / speed
        
        -- Add a predictive factor based on speed
        predictiveDistance = math.min(speed * 0.05, cellSize * 2)
        
        -- Adjust ball position based on velocity
        ballX = ballX + nvx * predictiveDistance
        ballY = ballY + nvy * predictiveDistance
    end
    
    -- Simple AABB collision check with the predicted position
    local ballLeft = ballX - ballHalfWidth
    local ballRight = ballX + ballHalfWidth
    local ballTop = ballY - ballHalfWidth
    local ballBottom = ballY + ballHalfWidth
    
    local cellLeft = cellX * cellSize
    local cellRight = cellLeft + cellSize
    local cellTop = cellY * cellSize
    local cellBottom = cellTop + cellSize
    
    -- Check for overlap
    return ballRight > cellLeft and
           ballLeft < cellRight and
           ballBottom > cellTop and
           ballTop < cellBottom
end

-- Draw the ball
function Ball:draw(debug)
    -- Skip drawing if the ball has won (disappeared)
    if self.scale and self.scale <= 0 then
        return
    end
    
    love.graphics.push()
    
    -- Get base color based on ball type
    local baseColor = self:getColor()
    
    -- Apply environment tint
    if self.inWater then
        -- Mix with blue tint
        love.graphics.setColor(
            baseColor[1] * 0.8, 
            baseColor[2] * 0.8, 
            baseColor[3] * 1.2, 
            baseColor[4]
        )
    elseif self.inSand then
        -- Mix with sand tint
        love.graphics.setColor(
            baseColor[1] * 1.1, 
            baseColor[2] * 0.9, 
            baseColor[3] * 0.7, 
            baseColor[4]
        )
    else
        love.graphics.setColor(baseColor)
    end
    
    love.graphics.translate(self.body:getX(), self.body:getY())
    love.graphics.rotate(self.body:getAngle())

    -- Shrink visually during win animation
    if self.scale and self.scale < 1.0 and self.scale > 0 then
        love.graphics.scale(self.scale, self.scale)
    end

    -- Draw the ball
    love.graphics.rectangle("fill", -10, -10, 20, 20) -- Draw a filled 20x20 square centered at the body position
    
    -- Draw special indicators based on ball type
    self:drawSpecialIndicator()
    
    -- Draw debug info
    if debug then
        -- Draw a red outline
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.rectangle("line", -10, -10, 20, 20)
        
        -- Draw axes to show rotation
        love.graphics.setColor(1, 0, 0, 1) -- Red for X axis
        love.graphics.line(0, 0, 15, 0)
        love.graphics.setColor(0, 1, 0, 1) -- Green for Y axis
        love.graphics.line(0, 0, 0, 15)
    end
    
    love.graphics.pop()

    -- Draw win burst particles (world-space, outside the ball transform)
    if self.winBurst and #self.winBurst > 0 then
        for _, p in ipairs(self.winBurst) do
            local frac  = p.life / p.maxLife
            local alpha = 1.0 - frac * frac  -- fast fade
            love.graphics.setColor(p.col[1], p.col[2], p.col[3], alpha)
            local sx = math.floor(p.x / p.sz) * p.sz
            local sy = math.floor(p.y / p.sz) * p.sz
            love.graphics.rectangle("fill", sx, sy, p.sz, p.sz)
        end
    end

    -- Draw additional debug info outside the transform
    if debug then
        local x, y = self.body:getPosition()
        local vx, vy = self.body:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        local angle = self.body:getAngle() * 180 / math.pi -- Convert to degrees
        
        -- Draw velocity vector
        love.graphics.setColor(1, 1, 0, 1) -- Yellow
        love.graphics.line(x, y, x + vx * 0.1, y + vy * 0.1)
        
        -- Draw bounding box
        love.graphics.setColor(0, 1, 1, 0.5) -- Cyan
        love.graphics.rectangle("line", x - 10, y - 10, 20, 20)
        
        -- Show environment and ball type status
        local yOffset = -20
        
        -- Show ball type
        self:drawDebugInfo(x, y, yOffset)
        yOffset = yOffset - 15
        
        -- Show environment status
        if self.inWater then
            love.graphics.setColor(0, 0.5, 1, 1)
            love.graphics.print("In Water", x + 15, y + yOffset)
        elseif self.inSand then
            love.graphics.setColor(0.9, 0.7, 0.3, 1)
            love.graphics.print("In Sand", x + 15, y + yOffset)
        end
    end
end

-- Shoot the ball
function Ball:shoot(direction, power)
    -- Apply power multiplier based on ball type
    local powerMultiplier = self:getPowerMultiplier()
    
    -- Apply both linear impulse and angular impulse for more natural movement
    self.body:applyLinearImpulse(
        direction.x * power * powerMultiplier,
        direction.y * power * powerMultiplier
    )
    
    -- Apply angular impulse for rotation
    local angularMultiplier = self:getAngularMultiplier()
    
    self.body:applyAngularImpulse(direction.x * angularMultiplier)
    
    self.isLaunched = true
end

-- Reset the ball to the starting position
function Ball:reset(x, y)
    -- Reset the ball to the starting position
    self.body:setPosition(x, y)
    self.body:setLinearVelocity(0, 0)
    self.body:setAngularVelocity(0)
    self.body:setAngle(0) -- Reset rotation
    self.isLaunched = false
end

-- Get the ball's position
function Ball:getPosition()
    return self.body:getPosition()
end

-- Check if the ball is moving
function Ball:isMoving()
    return self.isLaunched
end

-- Add a water cell to the ball's water cells
function Ball:enterWater(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.waterCells[key] = true
    self.inWater = true
end

-- Remove a water cell from the ball's water cells
function Ball:exitWater(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.waterCells[key] = nil
    
    -- Check if the ball is still in any water cells
    local stillInWater = false
    for _, _ in pairs(self.waterCells) do
        stillInWater = true
        break
    end
    
    self.inWater = stillInWater
end

-- Add a sand cell to the ball's sand cells
function Ball:enterSand(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.sandCells[key] = true
    self.inSand = true
end

-- Remove a sand cell from the ball's sand cells
function Ball:exitSand(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.sandCells[key] = nil
    
    -- Check if the ball is still in any sand cells
    local stillInSand = false
    for _, _ in pairs(self.sandCells) do
        stillInSand = true
        break
    end
    
    self.inSand = stillInSand
end

-- Methods to be overridden by specific ball types
function Ball:getColor()
    return Ball.COLORS.WHITE
end

function Ball:drawSpecialIndicator()
    -- No special indicator for base ball
end

function Ball:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(Ball.COLORS.WHITE)
    love.graphics.print("Ball", x + 15, y + yOffset)
end

function Ball:getWaterDragCoefficient()
    return 0.01 -- Default water drag coefficient
end

function Ball:getBuoyancyForce()
    return 100 -- Default buoyancy force
end

function Ball:getSandDragCoefficient()
    return 0.03 -- Default sand drag coefficient
end

function Ball:getSandCollisionDamping()
    return 0.35 -- Default: ball keeps 65% of speed on each sand contact
end

function Ball:getStoppedThreshold()
    return 5 -- Default stopped threshold
end

function Ball:getPowerMultiplier()
    return 1.0 -- Default power multiplier
end

function Ball:getAngularMultiplier()
    return 50 -- Default angular multiplier
end

return Ball
