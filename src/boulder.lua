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
    size = size or 30
    self.size = size
    
    -- Create the boulder physics body
    self.body = love.physics.newBody(world, x, y, "dynamic")
    self.shape = love.physics.newCircleShape(size / 2) -- Circular shape
    
    -- Physics properties
    self.fixture = love.physics.newFixture(self.body, self.shape, 5) -- Higher density than ball
    self.fixture:setRestitution(0.2) -- Less bouncy than ball
    self.fixture:setFriction(0.7) -- More friction than ball
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
    
    -- Draw a pixelated boulder
    local radius = self.size / 2
    local pixelSize = 2 -- Size of each "pixel"
    
    -- Define the boulder shape as a 2D grid
    -- 0 = empty, 1 = edge, 2 = fill, 3 = highlight
    local boulderGrid = {
        {0,0,0,0,1,1,1,1,1,0,0,0,0},
        {0,0,1,1,2,2,2,2,2,1,1,0,0},
        {0,1,2,2,2,2,2,2,2,2,2,1,0},
        {0,1,2,2,2,2,2,2,2,2,2,1,0},
        {1,2,2,2,2,2,2,2,2,2,2,2,1},
        {1,2,2,2,2,2,2,2,2,2,2,2,1},
        {1,2,2,2,2,2,2,2,2,2,2,2,1},
        {1,2,2,2,2,2,2,2,2,2,2,2,1},
        {1,2,2,2,2,2,2,2,2,2,2,2,1},
        {0,1,2,2,2,2,2,2,2,2,2,1,0},
        {0,1,2,2,2,2,2,2,2,2,2,1,0},
        {0,0,1,1,2,2,2,2,2,1,1,0,0},
        {0,0,0,0,1,1,1,1,1,0,0,0,0}
    }
    
    -- Add highlight to top-left quadrant
    for y = 1, 6 do
        for x = 1, 6 do
            if boulderGrid[y] and boulderGrid[y][x] == 2 then
                boulderGrid[y][x] = 3
            end
        end
    end
    
    -- Calculate the offset to center the grid
    local gridSize = #boulderGrid
    local offset = (gridSize * pixelSize) / 2
    
    -- Draw the boulder pixels
    for y = 1, gridSize do
        for x = 1, gridSize do
            local value = boulderGrid[y][x]
            if value > 0 then
                -- Set color based on pixel type
                if value == 1 then
                    -- Edge color (darker)
                    love.graphics.setColor(
                        baseColor[1] * 0.7,
                        baseColor[2] * 0.7,
                        baseColor[3] * 0.7,
                        baseColor[4]
                    )
                elseif value == 2 then
                    -- Fill color
                    love.graphics.setColor(baseColor)
                elseif value == 3 then
                    -- Highlight color
                    love.graphics.setColor(highlightColor)
                end
                
                -- Draw the pixel
                love.graphics.rectangle(
                    "fill",
                    (x - 1) * pixelSize - offset,
                    (y - 1) * pixelSize - offset,
                    pixelSize,
                    pixelSize
                )
            end
        end
    end
    
    -- Draw debug info
    if debug then
        -- Draw a red outline
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.circle("line", 0, 0, self.size / 2)
        
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
    local radius = self.size / 2
    
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
