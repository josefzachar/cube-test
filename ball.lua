-- ball.lua - Square ball implementation

local Ball = {}
Ball.__index = Ball

-- Colors
local WHITE = {1, 1, 1, 1}
local BLUE_TINT = {0.8, 0.8, 1, 1} -- Slight blue tint for when ball is in water
local SAND_TINT = {1, 0.9, 0.7, 1} -- Slight yellow/brown tint for when ball is in sand

function Ball.new(world, x, y)
    local self = setmetatable({}, Ball)
    
    -- Create the square ball
    self.body = love.physics.newBody(world, x, y, "dynamic")
    self.shape = love.physics.newRectangleShape(20, 20) -- 20x20 square
    self.fixture = love.physics.newFixture(self.body, self.shape, 2) -- Increased density for better physics
    self.fixture:setRestitution(0.3) -- Slightly less bouncy
    self.fixture:setFriction(0.5) -- Add friction for more natural movement
    self.fixture:setUserData("ball")
    
    self.isLaunched = false
    self.size = 20 -- Store the ball size for collision detection
    self.inWater = false -- Flag to track if the ball is in water
    self.waterCells = {} -- Table to track which water cells the ball is in
    self.inSand = false -- Flag to track if the ball is in sand
    self.sandCells = {} -- Table to track which sand cells the ball is in
    
    return self
end

function Ball:update(dt)
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
        local dragCoefficient = 0.01 -- Adjust this value to control water resistance
        local dragForceX = -vx * speed * dragCoefficient
        local dragForceY = -vy * speed * dragCoefficient
        
        -- Apply buoyancy (upward force)
        local buoyancyForce = 100 -- Adjust this value to control buoyancy
        
        -- Apply the forces
        self.body:applyForce(dragForceX, dragForceY + buoyancyForce)
    end
    
    -- Apply sand resistance if the ball is in sand
    if self.inSand and speed > 5 then
        -- Calculate drag force (proportional to velocity squared)
        local sandDragCoefficient = 0.05 -- Much higher drag coefficient for sand
        local dragForceX = -vx * speed * sandDragCoefficient
        local dragForceY = -vy * speed * sandDragCoefficient
        
        -- Apply the forces - no buoyancy in sand, just resistance
        self.body:applyForce(dragForceX, dragForceY)
        
        -- Also apply a damping effect to angular velocity
        local av = self.body:getAngularVelocity()
        self.body:setAngularVelocity(av * 0.95) -- Reduce angular velocity by 5% each frame
    end
    
    -- Check if ball has stopped
    if speed < 5 then
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

function Ball:draw(debug)
    love.graphics.push()
    
    -- Use appropriate tint based on what the ball is in
    if self.inWater then
        love.graphics.setColor(BLUE_TINT)
    elseif self.inSand then
        love.graphics.setColor(SAND_TINT)
    else
        love.graphics.setColor(WHITE)
    end
    
    love.graphics.translate(self.body:getX(), self.body:getY())
    love.graphics.rotate(self.body:getAngle())
    love.graphics.rectangle("fill", -10, -10, 20, 20) -- Draw a filled 20x20 square centered at the body position
    
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
        
        -- Show environment status
        if self.inWater then
            love.graphics.setColor(0, 0.5, 1, 1)
            love.graphics.print("In Water", x + 15, y - 20)
        elseif self.inSand then
            love.graphics.setColor(0.9, 0.7, 0.3, 1)
            love.graphics.print("In Sand", x + 15, y - 20)
        end
    end
end

function Ball:shoot(direction, power)
    -- Apply both linear impulse and angular impulse for more natural movement
    self.body:applyLinearImpulse(
        direction.x * power,
        direction.y * power
    )
    
    -- Apply angular impulse for rotation
    self.body:applyAngularImpulse(direction.x * 50)
    
    self.isLaunched = true
end

function Ball:reset(x, y)
    -- Reset the ball to the starting position
    self.body:setPosition(x, y)
    self.body:setLinearVelocity(0, 0)
    self.body:setAngularVelocity(0)
    self.body:setAngle(0) -- Reset rotation
    self.isLaunched = false
end

function Ball:getPosition()
    return self.body:getPosition()
end

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

return Ball
