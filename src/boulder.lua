-- boulder.lua - Boulder implementation using Love2D physics

local CellTypes = require("src.cell_types")

local Boulder = {}
Boulder.__index = Boulder

-- Boulder colors
Boulder.COLORS = {
    MAIN = {0.5, 0.5, 0.5, 1}, -- Gray color for boulders
    HIGHLIGHT = {0.7, 0.7, 0.7, 1} -- Lighter gray for highlights
}

-- Constructor
function Boulder.new(world, x, y, size)
    local self = setmetatable({}, Boulder)
    
    -- Default size if not specified
    size = size or 60 -- Increased from 30 to 60 (2x larger)
    self.size = size
    
    -- Create the boulder physics body
    self.body = love.physics.newBody(world, x, y, "dynamic")
    
    -- Create a simple circular collision shape for smoother interaction with the ball
    local collisionRadius = size * 0.45 -- 45% of the visual size
    self.shape = love.physics.newCircleShape(collisionRadius)
    
    -- Physics properties
    self.fixture = love.physics.newFixture(self.body, self.shape, 8) -- Higher density than ball
    self.fixture:setRestitution(0.1) -- Less bouncy than ball
    self.fixture:setFriction(0.9) -- More friction than ball
    self.fixture:setUserData(self) -- Set the boulder object as user data for collision detection
    
    -- Environment state
    self.inWater = false
    self.waterCells = {}
    self.inSand = false
    self.sandCells = {}
    self.world = world
    
    return self
end

-- Update method - handles physics updates
function Boulder:update(dt)
    -- Get boulder velocity
    local vx, vy = self.body:getLinearVelocity()
    local speed = math.sqrt(vx*vx + vy*vy)
    
    -- Apply water resistance if the boulder is in water
    if self.inWater and speed > 10 then
        -- Calculate drag force (proportional to velocity squared)
        local dragCoefficient = self:getWaterDragCoefficient()
        
        local dragForceX = -vx * speed * dragCoefficient
        local dragForceY = -vy * speed * dragCoefficient
        
        -- Apply buoyancy (upward force) - less than ball due to higher density
        local buoyancyForce = self:getBuoyancyForce()
        
        -- Apply the forces
        self.body:applyForce(dragForceX, dragForceY + buoyancyForce)
    end
    
    -- Apply sand resistance if the boulder is in sand
    if self.inSand and speed > 5 then
        -- Calculate drag force (proportional to velocity squared)
        local sandDragCoefficient = self:getSandDragCoefficient()
        
        local dragForceX = -vx * speed * sandDragCoefficient
        local dragForceY = -vy * speed * sandDragCoefficient
        
        -- Apply the forces - no buoyancy in sand, just resistance
        self.body:applyForce(dragForceX, dragForceY)
        
        -- Also apply a damping effect to angular velocity
        local av = self.body:getAngularVelocity()
        self.body:setAngularVelocity(av * 0.97)
    end
    
    -- Check if boulder has stopped
    local stoppedThreshold = 5
    
    if speed < stoppedThreshold then
        return true -- Boulder is stationary
    else
        return false -- Boulder is still moving
    end
end

-- Draw the boulder
function Boulder:draw(debug)
    love.graphics.push()
    
    -- Get base color
    local baseColor = Boulder.COLORS.MAIN
    local highlightColor = Boulder.COLORS.HIGHLIGHT
    
    -- Apply environment tint
    if self.inWater then
        -- Mix with blue tint
        baseColor = {
            baseColor[1] * 0.8, 
            baseColor[2] * 0.8, 
            baseColor[3] * 1.2, 
            baseColor[4]
        }
        highlightColor = {
            highlightColor[1] * 0.8, 
            highlightColor[2] * 0.8, 
            highlightColor[3] * 1.2, 
            highlightColor[4]
        }
    elseif self.inSand then
        -- Mix with sand tint
        baseColor = {
            baseColor[1] * 1.1, 
            baseColor[2] * 0.9, 
            baseColor[3] * 0.7, 
            baseColor[4]
        }
        highlightColor = {
            highlightColor[1] * 1.1, 
            highlightColor[2] * 0.9, 
            highlightColor[3] * 0.7, 
            highlightColor[4]
        }
    end
    
    -- Get position and angle
    local x, y = self.body:getPosition()
    local angle = self.body:getAngle()
    
    love.graphics.translate(x, y)
    love.graphics.rotate(angle)
    
    -- Draw a boulder based on the SVG design
    local radius = self.size / 2
    local scale = self.size / 100 -- Scale factor based on boulder size (SVG is 100x110)
    
    -- Define the boulder layers (from top to bottom)
    local layers = {
        {width = 20, height = 10, y = -50, color = {0.53, 0.53, 0.53, 1}}, -- #888888
        {width = 40, height = 10, y = -40, color = {0.47, 0.47, 0.47, 1}}, -- #777777
        {width = 60, height = 10, y = -30, color = {0.40, 0.40, 0.40, 1}}, -- #666666
        {width = 60, height = 10, y = -20, color = {0.36, 0.36, 0.36, 1}}, -- #5c5c5c
        {width = 80, height = 10, y = -10, color = {0.30, 0.30, 0.30, 1}}, -- #4c4c4c
        {width = 80, height = 10, y = 0,   color = {0.27, 0.27, 0.27, 1}}, -- #444444
        {width = 80, height = 10, y = 10,  color = {0.23, 0.23, 0.23, 1}}, -- #3a3a3a
        {width = 60, height = 10, y = 20,  color = {0.20, 0.20, 0.20, 1}}, -- #333333
        {width = 40, height = 10, y = 30,  color = {0.16, 0.16, 0.16, 1}}  -- #2a2a2a
    }
    
    -- Add highlights
    local highlights = {
        {width = 20, height = 10, y = -20, color = {0.56, 0.56, 0.56, 1}}, -- #909090
        {width = 20, height = 10, y = -10, color = {0.48, 0.48, 0.48, 1}}  -- #7a7a7a
    }
    
    -- Apply environment tint to all colors
    if self.inWater then
        for i, layer in ipairs(layers) do
            layer.color[1] = layer.color[1] * 0.8
            layer.color[2] = layer.color[2] * 0.8
            layer.color[3] = layer.color[3] * 1.2
        end
        for i, highlight in ipairs(highlights) do
            highlight.color[1] = highlight.color[1] * 0.8
            highlight.color[2] = highlight.color[2] * 0.8
            highlight.color[3] = highlight.color[3] * 1.2
        end
    elseif self.inSand then
        for i, layer in ipairs(layers) do
            layer.color[1] = layer.color[1] * 1.1
            layer.color[2] = layer.color[2] * 0.9
            layer.color[3] = layer.color[3] * 0.7
        end
        for i, highlight in ipairs(highlights) do
            highlight.color[1] = highlight.color[1] * 1.1
            highlight.color[2] = highlight.color[2] * 0.9
            highlight.color[3] = highlight.color[3] * 0.7
        end
    end
    
    -- Draw the main layers
    for _, layer in ipairs(layers) do
        love.graphics.setColor(layer.color)
        love.graphics.rectangle(
            "fill",
            -layer.width * scale / 2,
            layer.y * scale + 5 * scale, -- Adjust vertical position to center
            layer.width * scale,
            layer.height * scale
        )
    end
    
    -- Draw the highlights
    for _, highlight in ipairs(highlights) do
        love.graphics.setColor(highlight.color)
        love.graphics.rectangle(
            "fill",
            -highlight.width * scale / 2,
            highlight.y * scale + 5 * scale, -- Adjust vertical position to center
            highlight.width * scale,
            highlight.height * scale
        )
    end
    
    -- Draw debug info
    if debug then
        -- Draw the collision area in red
        love.graphics.setColor(1, 0, 0, 0.5) -- Semi-transparent red
        
        -- Draw the circular collision shape
        love.graphics.circle("fill", 0, 0, self.shape:getRadius())
        
        -- Draw a red outline for the collision area
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.circle("line", 0, 0, self.shape:getRadius())
        
        -- We no longer need to draw the yellow outline for the visual area
        -- as it's confusing and not necessary for debugging
        
        -- Draw axes to show rotation
        love.graphics.setColor(1, 0, 0, 1) -- Red for X axis
        love.graphics.line(0, 0, self.size / 2, 0)
        love.graphics.setColor(0, 1, 0, 1) -- Green for Y axis
        love.graphics.line(0, 0, 0, self.size / 2)
    end
    
    love.graphics.pop()
    
    -- Draw additional debug info outside the transform
    if debug then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Boulder", x + self.size / 2 + 5, y - 15)
        
        -- Show environment status
        if self.inWater then
            love.graphics.setColor(0, 0.5, 1, 1)
            love.graphics.print("In Water", x + self.size / 2 + 5, y)
        elseif self.inSand then
            love.graphics.setColor(0.9, 0.7, 0.3, 1)
            love.graphics.print("In Sand", x + self.size / 2 + 5, y)
        end
    end
end

-- Check if the boulder is colliding with a cell at the given position
function Boulder:isCollidingWithCell(cellX, cellY, cellSize)
    local boulderX, boulderY = self.body:getPosition()
    
    -- Get the radius of the boulder's collision shape
    local radius = self.shape:getRadius()
    
    -- Simple circle-rectangle collision check
    local cellLeft = cellX * cellSize
    local cellRight = cellLeft + cellSize
    local cellTop = cellY * cellSize
    local cellBottom = cellTop + cellSize
    
    -- Find the closest point on the rectangle to the circle center
    local closestX = math.max(cellLeft, math.min(boulderX, cellRight))
    local closestY = math.max(cellTop, math.min(boulderY, cellBottom))
    
    -- Calculate the distance between the closest point and the circle center
    local distanceX = boulderX - closestX
    local distanceY = boulderY - closestY
    local distanceSquared = distanceX * distanceX + distanceY * distanceY
    
    -- Check if the distance is less than the radius squared
    return distanceSquared <= (radius * radius)
end

-- Add a water cell to the boulder's water cells
function Boulder:enterWater(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.waterCells[key] = true
    self.inWater = true
end

-- Remove a water cell from the boulder's water cells
function Boulder:exitWater(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.waterCells[key] = nil
    
    -- Check if the boulder is still in any water cells
    local stillInWater = false
    for _, _ in pairs(self.waterCells) do
        stillInWater = true
        break
    end
    
    self.inWater = stillInWater
end

-- Add a sand cell to the boulder's sand cells
function Boulder:enterSand(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.sandCells[key] = true
    self.inSand = true
end

-- Remove a sand cell from the boulder's sand cells
function Boulder:exitSand(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.sandCells[key] = nil
    
    -- Check if the boulder is still in any sand cells
    local stillInSand = false
    for _, _ in pairs(self.sandCells) do
        stillInSand = true
        break
    end
    
    self.inSand = stillInSand
end

-- Get the boulder's position
function Boulder:getPosition()
    return self.body:getPosition()
end

-- Physics property methods
function Boulder:getWaterDragCoefficient()
    return 0.02 -- Higher water drag than ball
end

function Boulder:getBuoyancyForce()
    return 50 -- Lower buoyancy than ball due to higher density
end

function Boulder:getSandDragCoefficient()
    return 0.05 -- Higher sand drag than ball
end

return Boulder
