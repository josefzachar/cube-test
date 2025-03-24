-- Square Golf Game
-- A simple golf game where the ball is a square

-- Load the Love2D physics module
love.physics = require("love.physics")

-- Game variables
local world
local boundaries = {}
local ball
local ballBody
local ballShape
local ballFixture
local isLaunched = false
local attempts = 0
local debug = false -- Set to true to see physics bodies
local aimDirection = {x = 0, y = 0}
local aimPower = 0
local maxPower = 800
local minPower = 100
local aiming = false

-- Colors
local WHITE = {1, 1, 1, 1}

function love.load()
    -- Set up the physics world with gravity
    world = love.physics.newWorld(0, 9.81 * 64, true)
    
    -- Create boundaries (ground, ceiling, left wall, right wall)
    boundaries = {
        -- Ground
        {
            body = love.physics.newBody(world, 400, 590, "static"),
            shape = love.physics.newEdgeShape(-400, 0, 400, 0),
        },
        -- Left wall
        {
            body = love.physics.newBody(world, 0, 300, "static"),
            shape = love.physics.newEdgeShape(0, -300, 0, 290),
        },
        -- Right wall
        {
            body = love.physics.newBody(world, 800, 300, "static"),
            shape = love.physics.newEdgeShape(0, -300, 0, 290),
        },
        -- Ceiling
        {
            body = love.physics.newBody(world, 400, 0, "static"),
            shape = love.physics.newEdgeShape(-400, 0, 400, 0),
        },
        -- Some obstacles
        {
            body = love.physics.newBody(world, 400, 400, "static"),
            shape = love.physics.newEdgeShape(-100, 0, 100, 0),
        },
        {
            body = love.physics.newBody(world, 600, 300, "static"),
            shape = love.physics.newEdgeShape(-50, 50, 50, -50),
        }
    }
    
    -- Create fixtures for all boundaries
    for i, boundary in ipairs(boundaries) do
        boundary.fixture = love.physics.newFixture(boundary.body, boundary.shape)
        boundary.fixture:setRestitution(0.5) -- Bouncy boundaries
    end
    
    -- Create the square ball
    ballBody = love.physics.newBody(world, 100, 500, "dynamic")
    ballShape = love.physics.newRectangleShape(20, 20) -- 20x20 square
    ballFixture = love.physics.newFixture(ballBody, ballShape, 2) -- Increased density for better physics
    ballFixture:setRestitution(0.3) -- Slightly less bouncy
    ballFixture:setFriction(0.5) -- Add friction for more natural movement
end

-- Calculate aim direction and power based on mouse position
function calculateAim()
    local ballX, ballY = ballBody:getPosition()
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Calculate direction vector
    aimDirection.x = mouseX - ballX
    aimDirection.y = mouseY - ballY
    
    -- Calculate power based on distance (clamped between min and max)
    local distance = math.sqrt(aimDirection.x^2 + aimDirection.y^2)
    aimPower = math.min(maxPower, math.max(minPower, distance * 2))
    
    -- Normalize direction vector
    if distance > 0 then
        aimDirection.x = aimDirection.x / distance
        aimDirection.y = aimDirection.y / distance
    end
end

function love.update(dt)
    -- Update the physics world
    world:update(dt)
    
    -- Get ball velocity
    local vx, vy = ballBody:getLinearVelocity()
    local speed = math.sqrt(vx*vx + vy*vy)
    
    -- Update aim if ball is stationary (ready for next shot)
    if speed < 5 then
        isLaunched = false
        calculateAim()
    else
        -- Apply a small torque to make the square rotate more naturally when moving
        if speed > 50 then
            -- Apply torque proportional to speed and direction
            ballBody:applyTorque(vx * 0.1)
        end
    end
end

function love.draw()
    -- Draw all boundaries
    love.graphics.setColor(WHITE)
    for i, boundary in ipairs(boundaries) do
        love.graphics.push()
        love.graphics.translate(boundary.body:getX(), boundary.body:getY())
        love.graphics.rotate(boundary.body:getAngle())
        love.graphics.line(boundary.shape:getPoints())
        love.graphics.pop()
    end
    
    -- Draw aim line if not launched
    if not isLaunched then
        local ballX, ballY = ballBody:getPosition()
        local lineLength = aimPower / 10 -- Scale down for visual purposes
        love.graphics.setColor(WHITE)
        love.graphics.line(
            ballX, 
            ballY, 
            ballX + aimDirection.x * lineLength, 
            ballY + aimDirection.y * lineLength
        )
        
        -- Draw power indicator
        local powerPercentage = (aimPower - minPower) / (maxPower - minPower)
        love.graphics.print("Power: " .. math.floor(powerPercentage * 100) .. "%", 650, 30)
    end
    
    -- Draw the square ball
    love.graphics.push()
    love.graphics.setColor(WHITE)
    love.graphics.translate(ballBody:getX(), ballBody:getY())
    love.graphics.rotate(ballBody:getAngle())
    love.graphics.rectangle("line", -10, -10, 20, 20) -- Draw a 20x20 square centered at the body position
    love.graphics.pop()
    
    -- Display game status
    love.graphics.setColor(WHITE)
    love.graphics.print("Shots: " .. attempts .. " - Click to shoot, 'R' to reset to start", 250, 30)
end

function love.mousepressed(x, y, button)
    if button == 1 and not isLaunched then -- Left mouse button
        -- Launch the ball in the aimed direction
        ballBody:applyLinearImpulse(
            aimDirection.x * aimPower,
            aimDirection.y * aimPower
        )
        
        -- Apply angular impulse for rotation
        ballBody:applyAngularImpulse(aimDirection.x * 50)
        
        isLaunched = true
        attempts = attempts + 1
    end
end

function love.keypressed(key)
    if key == "r" then
        -- Reset the game
        resetBall()
    elseif key == "d" then
        -- Toggle debug mode
        debug = not debug
    end
end

function resetBall()
    -- Reset the ball to the starting position
    ballBody:setPosition(100, 500)
    ballBody:setLinearVelocity(0, 0)
    ballBody:setAngularVelocity(0)
    ballBody:setAngle(0) -- Reset rotation
    isLaunched = false
end
