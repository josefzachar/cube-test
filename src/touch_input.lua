-- touch_input.lua - Touch input handling for mobile devices

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local TouchInput = {}
TouchInput.__index = TouchInput

function TouchInput.new()
    local self = setmetatable({}, TouchInput)
    
    -- Touch state
    self.touchId = nil            -- Current active touch ID
    self.touchStartX = nil        -- Starting X position of touch
    self.touchStartY = nil        -- Starting Y position of touch
    self.touchCurrentX = nil      -- Current X position of touch
    self.touchCurrentY = nil      -- Current Y position of touch
    self.isAiming = false         -- Flag to track if user is currently aiming
    self.aimDirection = {x = 0, y = 0}  -- Direction vector for aiming
    self.aimPower = 0             -- Power of the shot
    self.maxPower = 2000          -- Maximum power (same as mouse input)
    self.minPower = 100           -- Minimum power (same as mouse input)
    
    -- Double tap detection
    self.lastTapTime = 0          -- Time of last tap
    self.lastTapX = 0             -- X position of last tap
    self.lastTapY = 0             -- Y position of last tap
    self.doubleTapThreshold = 0.3 -- Time threshold for double tap (in seconds)
    self.doubleTapDistance = 50   -- Distance threshold for double tap
    
    -- Shooting mode only
    self.mode = 1 -- Always in shooting mode
    
    return self
end

function TouchInput:update(ball, level, dt)
    -- Reset aiming if ball is moving or no active touch
    if ball:isMoving() or not self.touchId then
        self.isAiming = false
    end
    
    -- If aiming, update aim direction and power
    if self.isAiming and self.touchId and self.touchStartX and self.touchCurrentX then
        self:calculateAim()
    end
end

function TouchInput:calculateAim()
    -- Calculate direction vector from touch start to current touch position
    self.aimDirection.x = self.touchCurrentX - self.touchStartX
    self.aimDirection.y = self.touchCurrentY - self.touchStartY
    
    -- Calculate power based on distance (clamped between min and max)
    local distance = math.sqrt(self.aimDirection.x^2 + self.aimDirection.y^2)
    self.aimPower = math.min(self.maxPower, math.max(self.minPower, distance * 2))
    
    -- Normalize direction vector
    if distance > 0 then
        self.aimDirection.x = self.aimDirection.x / distance
        self.aimDirection.y = self.aimDirection.y / distance
    end
end

function TouchInput:handleTouchPressed(id, x, y, ball, level)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = self:screenToGameCoords(x, y)
    
    -- Check for double tap
    local currentTime = love.timer.getTime()
    local dx = gameX - self.lastTapX
    local dy = gameY - self.lastTapY
    local distance = math.sqrt(dx * dx + dy * dy)
    
    if currentTime - self.lastTapTime < self.doubleTapThreshold and distance < self.doubleTapDistance then
        -- Double tap detected - reset ball
        if ball.hasWon then
            -- Increase difficulty level for the next level
            if currentDifficulty < 5 then
                currentDifficulty = currentDifficulty + 1
                print("Difficulty increased to:", currentDifficulty)
            else
                print("Already at maximum difficulty!")
            end
        end
        
        -- Completely restart the game by calling love.load()
        love.load()
        return true
    end
    
    -- Store this tap for future double tap detection
    self.lastTapTime = currentTime
    self.lastTapX = gameX
    self.lastTapY = gameY
    
    -- If we already have an active touch, ignore this one
    if self.touchId then
        return false
    end
    
    -- Store the touch ID and position
    self.touchId = id
    
    -- Use the actual touch position as the start position for aiming
    self.touchStartX = gameX
    self.touchStartY = gameY
    
    self.touchCurrentX = gameX
    self.touchCurrentY = gameY
    
    if not ball:isMoving() then
        -- Start aiming
        self.isAiming = true
        return false -- No shot taken yet
    end
    
    return false
end

function TouchInput:handleTouchMoved(id, x, y)
    -- Only process if this is our active touch
    if id ~= self.touchId then
        return false
    end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = self:screenToGameCoords(x, y)
    
    -- Update current touch position
    self.touchCurrentX = gameX
    self.touchCurrentY = gameY
    
    return false
end

function TouchInput:handleTouchReleased(id, x, y, ball)
    -- Only process if this is our active touch
    if id ~= self.touchId then
        return false
    end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = self:screenToGameCoords(x, y)
    
    -- Clear touch state
    self.touchId = nil
    
    if self.isAiming and not ball:isMoving() then
        -- Stop aiming
        self.isAiming = false
        
        -- For slingshot, we want to fire in the direction from touch to ball
        -- The aimDirection already points from touch start to current touch position
        local slingDirection = {
            x = -self.aimDirection.x,
            y = -self.aimDirection.y
        }
        
        -- Shoot the ball using the slingshot direction
        ball:shoot(slingDirection, self.aimPower)
        return true -- Shot was taken
    end
    
    return false
end

function TouchInput:screenToGameCoords(screenX, screenY)
    -- Use our InputUtils module for coordinate conversion
    local InputUtils = require("src.input_utils")
    return InputUtils.screenToGameCoords(screenX, screenY)
end

function TouchInput:draw(ball, attempts)
    -- Draw aim line if ball is not moving and user is aiming
    if not ball:isMoving() and self.isAiming and self.touchId then
        local lineLength = self.aimPower / 5 -- Scale down for visual purposes
        local cellSize = 8  -- Size of each cell in pixels
        local cellSpacing = 6  -- Space between cells
        
        -- Get ball position for drawing the aim lines
        local ballX, ballY = ball:getPosition()
        
        -- Draw original aim line (dashed cells) from ball position
        love.graphics.setColor(0.4, 0.4, 0.4, 1) -- Light gray for original direction
        local endX = ballX + self.aimDirection.x * lineLength
        local endY = ballY + self.aimDirection.y * lineLength
        self:drawDashedCellLine(
            ballX, 
            ballY, 
            endX, 
            endY,
            cellSize,
            cellSpacing
        )
        
        -- Draw opposite aim line (actual shot direction) from ball position
        love.graphics.setColor(1, 1, 1, 1) -- White for shot direction
        local shotEndX = ballX - self.aimDirection.x * lineLength
        local shotEndY = ballY - self.aimDirection.y * lineLength
        self:drawDashedCellLine(
            ballX, 
            ballY, 
            shotEndX, 
            shotEndY,
            8,
            0
        )
        
        -- Draw pixelated arrow at the end of the white line
        self:drawPixelatedArrow(
            shotEndX, 
            shotEndY, 
            -self.aimDirection.x, 
            -self.aimDirection.y, 
            24 -- Arrow size
        )
        
        -- Reset color to white
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Function to draw a pixelated circle (copied from input.lua)
function TouchInput:drawPixelatedCircle(x, y, radius, pixelSize, mode)
    -- Calculate bounding box
    local minX = math.floor(x - radius - pixelSize)
    local minY = math.floor(y - radius - pixelSize)
    local maxX = math.ceil(x + radius + pixelSize)
    local maxY = math.ceil(y + radius + pixelSize)
    
    -- Determine which pixels to draw based on distance from center
    for px = minX, maxX, pixelSize do
        for py = minY, maxY, pixelSize do
            -- Calculate center of this pixel
            local centerX = px + pixelSize / 2
            local centerY = py + pixelSize / 2
            
            -- Calculate distance from circle center to pixel center
            local distX = centerX - x
            local distY = centerY - y
            local distance = math.sqrt(distX * distX + distY * distY)
            
            -- For filled circle, draw if inside radius
            if mode == "fill" and distance <= radius then
                love.graphics.rectangle("fill", px, py, pixelSize, pixelSize)
            -- For line circle, draw if close to the radius
            elseif mode == "line" and math.abs(distance - radius) <= pixelSize then
                love.graphics.rectangle("fill", px, py, pixelSize, pixelSize)
            end
        end
    end
end

-- Function to draw a dashed line made of cells (copied from input.lua)
function TouchInput:drawDashedCellLine(startX, startY, endX, endY, cellSize, spacing)
    local dirX = endX - startX
    local dirY = endY - startY
    local length = math.sqrt(dirX * dirX + dirY * dirY)
    
    if length > 0 then
        dirX = dirX / length
        dirY = dirY / length
    else
        return -- No line to draw
    end
    
    -- Draw cells along the line with spacing
    local distance = 0
    while distance < length do
        local posX = startX + dirX * distance
        local posY = startY + dirY * distance
        
        -- Draw a square "cell"
        love.graphics.rectangle("fill", posX - cellSize/2, posY - cellSize/2, cellSize, cellSize)
        
        -- Move along the line with spacing
        distance = distance + cellSize + spacing
    end
end

-- Function to draw a pixelated arrow (copied from input.lua)
function TouchInput:drawPixelatedArrow(x, y, dirX, dirY, size)
    -- Normalize direction
    local length = math.sqrt(dirX * dirX + dirY * dirY)
    if length > 0 then
        dirX = dirX / length
        dirY = dirY / length
    else
        return
    end
    
    -- Calculate perpendicular vector for arrow wings
    local perpX = -dirY
    local perpY = dirX
    
    -- Arrow pixel pattern (relative positions)
    local pixels = {
        {0, 0},                -- Tip
        {-1, -1}, {1, -1},     -- Second row
        {-2, -2}, {0, -2}, {2, -2},  -- Third row
        {-3, -3}, {-1, -3}, {1, -3}, {3, -3}  -- Fourth row
    }
    
    -- Size of each pixel
    local pixelSize = size / 4
    
    -- Draw each pixel of the arrow
    for _, pixel in ipairs(pixels) do
        local px = x + (pixel[1] * perpX + pixel[2] * dirX) * pixelSize
        local py = y + (pixel[1] * perpY + pixel[2] * dirY) * pixelSize
        
        love.graphics.rectangle("fill", px - pixelSize/2, py - pixelSize/2, pixelSize, pixelSize)
    end
end

return TouchInput
