-- ball.lua - Square ball implementation with multiple ball types

local CellTypes = require("src.cell_types")

local Ball = {}
Ball.__index = Ball

-- Ball types
Ball.TYPES = {
    STANDARD = 1,
    HEAVY = 2,
    EXPLODING = 3,
    STICKY = 4
}

-- Colors
local WHITE = {1, 1, 1, 1}
local BLUE_TINT = {0.8, 0.8, 1, 1} -- Slight blue tint for when ball is in water
local SAND_TINT = {1, 0.9, 0.7, 1} -- Slight yellow/brown tint for when ball is in sand
local HEAVY_COLOR = {0.6, 0.6, 0.8, 1} -- Dark blue for heavy ball
local EXPLODING_COLOR = {1, 0.4, 0.2, 1} -- Orange-red for exploding ball
local STICKY_COLOR = {0.3, 0.8, 0.3, 1} -- Green for sticky ball

function Ball.new(world, x, y, ballType)
    local self = setmetatable({}, Ball)
    
    -- Set ball type (default to STANDARD if not specified)
    self.ballType = ballType or Ball.TYPES.STANDARD
    
    -- Create the square ball
    self.body = love.physics.newBody(world, x, y, "dynamic")
    self.shape = love.physics.newRectangleShape(20, 20) -- 20x20 square
    
    -- Set physics properties based on ball type
    if self.ballType == Ball.TYPES.HEAVY then
        -- Heavy ball has more density and less restitution
        self.fixture = love.physics.newFixture(self.body, self.shape, 5) -- Higher density
        self.fixture:setRestitution(0.2) -- Less bouncy
        self.fixture:setFriction(0.7) -- More friction
    elseif self.ballType == Ball.TYPES.EXPLODING then
        -- Exploding ball has standard physics
        self.fixture = love.physics.newFixture(self.body, self.shape, 2)
        self.fixture:setRestitution(0.3)
        self.fixture:setFriction(0.5)
        self.exploded = false -- Track if the ball has exploded
    elseif self.ballType == Ball.TYPES.STICKY then
        -- Sticky ball has no bounce and high friction
        self.fixture = love.physics.newFixture(self.body, self.shape, 1.5) -- Lower density
        self.fixture:setRestitution(0.0) -- No bounce
        self.fixture:setFriction(1.0) -- Maximum friction
        self.stuck = false -- Track if the ball is stuck
    else
        -- Standard ball
        self.fixture = love.physics.newFixture(self.body, self.shape, 2)
        self.fixture:setRestitution(0.3)
        self.fixture:setFriction(0.5)
    end
    
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

function Ball:update(dt)
    -- Get ball velocity
    local vx, vy = self.body:getLinearVelocity()
    local speed = math.sqrt(vx*vx + vy*vy)
    
    -- Handle sticky ball special case
    if self.ballType == Ball.TYPES.STICKY and self.stuck then
        -- If the sticky ball is stuck, force it to stop completely
        self.body:setLinearVelocity(0, 0)
        self.body:setAngularVelocity(0)
        return true -- Ball is stationary
    end
    
    -- Apply a small torque to make the square rotate more naturally when moving
    if speed > 50 then
        -- Apply torque proportional to speed and direction
        self.body:applyTorque(vx * 0.1)
    end
    
    -- Apply water resistance if the ball is in water
    if self.inWater and speed > 10 then
        -- Calculate drag force (proportional to velocity squared)
        local dragCoefficient = 0.01 -- Adjust this value to control water resistance
        
        -- Heavy ball has less water resistance
        if self.ballType == Ball.TYPES.HEAVY then
            dragCoefficient = 0.005
        end
        
        local dragForceX = -vx * speed * dragCoefficient
        local dragForceY = -vy * speed * dragCoefficient
        
        -- Apply buoyancy (upward force)
        local buoyancyForce = 100 -- Adjust this value to control buoyancy
        
        -- Heavy ball has less buoyancy
        if self.ballType == Ball.TYPES.HEAVY then
            buoyancyForce = 50
        end
        
        -- Apply the forces
        self.body:applyForce(dragForceX, dragForceY + buoyancyForce)
    end
    
    -- Apply sand resistance if the ball is in sand
    if self.inSand and speed > 5 then
        -- Calculate drag force (proportional to velocity squared)
        local sandDragCoefficient = 0.03 -- Reduced from 0.05 to 0.03 for less resistance
        
        -- Heavy ball has less sand resistance
        if self.ballType == Ball.TYPES.HEAVY then
            sandDragCoefficient = 0.015
        end
        
        local dragForceX = -vx * speed * sandDragCoefficient
        local dragForceY = -vy * speed * sandDragCoefficient
        
        -- Apply the forces - no buoyancy in sand, just resistance
        self.body:applyForce(dragForceX, dragForceY)
        
        -- Also apply a damping effect to angular velocity
        local av = self.body:getAngularVelocity()
        self.body:setAngularVelocity(av * 0.99) -- Reduced damping from 0.95 to 0.97
    end
    
    -- Check if ball has stopped
    local stoppedThreshold = 5
    
    -- Heavy ball needs more speed to be considered "moving"
    if self.ballType == Ball.TYPES.HEAVY then
        stoppedThreshold = 8
    end
    
    if speed < stoppedThreshold then
        self.isLaunched = false
        
        -- For sticky ball, if it's moving slowly, consider it stuck
        if self.ballType == Ball.TYPES.STICKY and speed < 20 then
            self.stuck = true
        end
        
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

function Ball:draw(debug)
    love.graphics.push()
    
    -- Get base color based on ball type
    local baseColor
    if self.ballType == Ball.TYPES.HEAVY then
        baseColor = HEAVY_COLOR
    elseif self.ballType == Ball.TYPES.EXPLODING then
        baseColor = EXPLODING_COLOR
    elseif self.ballType == Ball.TYPES.STICKY then
        baseColor = STICKY_COLOR
    else
        baseColor = WHITE
    end
    
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
    
    -- Draw the ball
    love.graphics.rectangle("fill", -10, -10, 20, 20) -- Draw a filled 20x20 square centered at the body position
    
    -- Draw special indicators based on ball type
    if self.ballType == Ball.TYPES.HEAVY then
        -- Draw a weight symbol (horizontal lines)
        love.graphics.setColor(0.2, 0.2, 0.4, 1)
        love.graphics.rectangle("fill", -7, -2, 14, 1)
        love.graphics.rectangle("fill", -7, 2, 14, 1)
    elseif self.ballType == Ball.TYPES.EXPLODING then
        -- Draw an X symbol
        love.graphics.setColor(0.9, 0.1, 0.1, 1)
        love.graphics.line(-5, -5, 5, 5)
        love.graphics.line(-5, 5, 5, -5)
    elseif self.ballType == Ball.TYPES.STICKY then
        -- Draw a dot pattern
        love.graphics.setColor(0.1, 0.5, 0.1, 1)
        love.graphics.circle("fill", -4, -4, 2)
        love.graphics.circle("fill", 4, -4, 2)
        love.graphics.circle("fill", -4, 4, 2)
        love.graphics.circle("fill", 4, 4, 2)
    end
    
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
        if self.ballType == Ball.TYPES.HEAVY then
            love.graphics.setColor(HEAVY_COLOR)
            love.graphics.print("Heavy Ball", x + 15, y + yOffset)
            yOffset = yOffset - 15
        elseif self.ballType == Ball.TYPES.EXPLODING then
            love.graphics.setColor(EXPLODING_COLOR)
            love.graphics.print("Exploding Ball", x + 15, y + yOffset)
            yOffset = yOffset - 15
        elseif self.ballType == Ball.TYPES.STICKY then
            love.graphics.setColor(STICKY_COLOR)
            love.graphics.print("Sticky Ball", x + 15, y + yOffset)
            yOffset = yOffset - 15
        else
            love.graphics.setColor(WHITE)
            love.graphics.print("Standard Ball", x + 15, y + yOffset)
            yOffset = yOffset - 15
        end
        
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

function Ball:shoot(direction, power)
    -- Reset any special states
    if self.ballType == Ball.TYPES.EXPLODING then
        self.exploded = false
    elseif self.ballType == Ball.TYPES.STICKY then
        self.stuck = false
    end
    
    -- Apply power multiplier based on ball type
    local powerMultiplier = 1.0
    if self.ballType == Ball.TYPES.HEAVY then
        powerMultiplier = 1.5 -- Heavy ball gets more power
    elseif self.ballType == Ball.TYPES.EXPLODING then
        powerMultiplier = 1.2 -- Exploding ball gets slightly more power
    elseif self.ballType == Ball.TYPES.STICKY then
        powerMultiplier = 0.8 -- Sticky ball gets less power
    end
    
    -- Apply both linear impulse and angular impulse for more natural movement
    self.body:applyLinearImpulse(
        direction.x * power * powerMultiplier,
        direction.y * power * powerMultiplier
    )
    
    -- Apply angular impulse for rotation
    local angularMultiplier = 50
    if self.ballType == Ball.TYPES.HEAVY then
        angularMultiplier = 80 -- Heavy ball gets more rotation
    elseif self.ballType == Ball.TYPES.STICKY then
        angularMultiplier = 30 -- Sticky ball gets less rotation
    end
    
    self.body:applyAngularImpulse(direction.x * angularMultiplier)
    
    self.isLaunched = true
end

function Ball:reset(x, y)
    -- Reset the ball to the starting position
    self.body:setPosition(x, y)
    self.body:setLinearVelocity(0, 0)
    self.body:setAngularVelocity(0)
    self.body:setAngle(0) -- Reset rotation
    self.isLaunched = false
    
    -- Reset special states
    if self.ballType == Ball.TYPES.EXPLODING then
        self.exploded = false
    elseif self.ballType == Ball.TYPES.STICKY then
        self.stuck = false
    end
end

function Ball:getPosition()
    return self.body:getPosition()
end

function Ball:isMoving()
    -- For sticky ball, if it's stuck, it's not considered moving
    if self.ballType == Ball.TYPES.STICKY and self.stuck then
        return false
    end
    return self.isLaunched
end

-- Change the ball type
function Ball:changeBallType(newType)
    -- Don't change if it's the same type
    if newType == self.ballType then
        return
    end
    
    -- Store current position and velocity
    local x, y = self.body:getPosition()
    local vx, vy = self.body:getLinearVelocity()
    local angle = self.body:getAngle()
    local av = self.body:getAngularVelocity()
    
    -- Remove old fixture
    self.fixture:destroy()
    
    -- Set new ball type
    self.ballType = newType
    
    -- Create new fixture with appropriate properties
    if self.ballType == Ball.TYPES.HEAVY then
        -- Heavy ball has more density and less restitution
        self.fixture = love.physics.newFixture(self.body, self.shape, 5) -- Higher density
        self.fixture:setRestitution(0.2) -- Less bouncy
        self.fixture:setFriction(0.7) -- More friction
    elseif self.ballType == Ball.TYPES.EXPLODING then
        -- Exploding ball has standard physics
        self.fixture = love.physics.newFixture(self.body, self.shape, 2)
        self.fixture:setRestitution(0.3)
        self.fixture:setFriction(0.5)
        self.exploded = false -- Reset explosion state
    elseif self.ballType == Ball.TYPES.STICKY then
        -- Sticky ball has no bounce and high friction
        self.fixture = love.physics.newFixture(self.body, self.shape, 1.5) -- Lower density
        self.fixture:setRestitution(0.0) -- No bounce
        self.fixture:setFriction(1.0) -- Maximum friction
        self.stuck = false -- Reset stuck state
    else
        -- Standard ball
        self.fixture = love.physics.newFixture(self.body, self.shape, 2)
        self.fixture:setRestitution(0.3)
        self.fixture:setFriction(0.5)
    end
    
    self.fixture:setUserData("ball")
    
    -- Maintain the same velocity and position
    self.body:setPosition(x, y)
    self.body:setLinearVelocity(vx, vy)
    self.body:setAngle(angle)
    self.body:setAngularVelocity(av)
end

-- Handle explosion for exploding ball
function Ball:explode(level, sandToConvert)
    if self.ballType ~= Ball.TYPES.EXPLODING or self.exploded then
        return false -- Not an exploding ball or already exploded
    end
    
    -- Mark as exploded
    self.exploded = true
    
    -- Get ball position
    local x, y = self.body:getPosition()
    local gridX, gridY = level:getGridCoordinates(x, y)
    
    -- Explosion radius
    local explosionRadius = 5
    
    -- Create explosion effect
    for dy = -explosionRadius, explosionRadius do
        for dx = -explosionRadius, explosionRadius do
            local checkX = gridX + dx
            local checkY = gridY + dy
            
            -- Calculate distance from center
            local distance = math.sqrt(dx*dx + dy*dy)
            
            -- Only affect cells within the explosion radius
            if distance <= explosionRadius and
               checkX >= 0 and checkX < level.width and 
               checkY >= 0 and checkY < level.height then
                
                -- Get the cell type
                local cellType = level:getCellType(checkX, checkY)
                
                -- Only affect certain cell types (not empty or water)
                if cellType ~= CellTypes.TYPES.EMPTY and 
                   cellType ~= CellTypes.TYPES.WATER then
                    
                    -- Direction away from explosion center
                    local dirX = dx
                    local dirY = dy
                    if dx == 0 and dy == 0 then
                        dirX, dirY = 0, -1 -- Default upward
                    else
                        local dirLen = math.sqrt(dirX*dirX + dirY*dirY)
                        dirX = dirX / dirLen
                        dirY = dirY / dirLen
                    end
                    
                    -- Calculate velocity based on distance from center
                    local impactFactor = (1 - distance/explosionRadius)
                    local flyVx = dirX * 500 * impactFactor
                    local flyVy = dirY * 500 * impactFactor - 200 -- Extra upward boost
                    
                    -- Add randomness
                    flyVx = flyVx + math.random(-50, 50)
                    flyVy = flyVy + math.random(-50, 50)
                    
                    -- Clear the cell
                    level:setCellType(checkX, checkY, CellTypes.TYPES.EMPTY)
                    
                    -- Queue up for conversion to visual particles
                    table.insert(sandToConvert, {
                        x = checkX,
                        y = checkY,
                        vx = flyVx,
                        vy = flyVy,
                        originalType = cellType,
                        shouldConvert = true
                    })
                end
            end
        end
    end
    
    return true -- Explosion successful
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

return Ball
