-- input.lua - Input handling (mouse, keyboard)
-- Note: This module now works alongside touch_input.lua for a unified input experience

local Cell = require("cell")
local CellTypes = require("src.cell_types")

-- Original design dimensions (must match the values in main.lua)
local ORIGINAL_WIDTH = 1600
local ORIGINAL_HEIGHT = 1000

-- Background color (must match the value in main.lua)
local BACKGROUND_COLOR = {0.2, 0.3, 0.6, 1.0} -- Dark blue (base color)

local Input = {}
Input.__index = Input

-- Shooting mode only
local SHOOT_MODE = 1

function Input.new()
    local self = setmetatable({}, Input)
    
    self.mouseX = 0
    self.mouseY = 0
    self.aimDirection = {x = 0, y = 0}
    self.aimPower = 0
    self.maxPower = 2000  -- Increased from 800 to 1500 for higher force
    self.minPower = 100
    self.clickPosition = {x = nil, y = nil}  -- Store the position where the user clicked
    self.isAiming = false  -- Flag to track if the user is currently aiming
    
    -- Shooting mode only
    self.mode = SHOOT_MODE -- Always in shooting mode
    
    return self
end

function Input:update(ball, level)
    -- Update mouse position
    local screenX, screenY = love.mouse.getPosition()
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY
    if love.window then
        -- Get screen dimensions
        local width, height = love.graphics.getDimensions()
        
        -- Calculate scale factors
        local scaleX = width / ORIGINAL_WIDTH
        local scaleY = height / ORIGINAL_HEIGHT
        local scale = math.min(scaleX, scaleY)
        
        -- Calculate offsets for centering
        local scaledWidth = width / scale
        local scaledHeight = height / scale
        local offsetX = (scaledWidth - ORIGINAL_WIDTH) / 2
        local offsetY = (scaledHeight - ORIGINAL_HEIGHT) / 2
        
        -- Get camera position
        local Camera = require("src.camera")
        local cameraOffsetX = ORIGINAL_WIDTH / 2 - Camera.x
        local cameraOffsetY = ORIGINAL_HEIGHT / 2 - Camera.y
        
        -- Convert screen coordinates to game coordinates with camera offset
        gameX = (screenX / scale) - offsetX - cameraOffsetX
        gameY = (screenY / scale) - offsetY - cameraOffsetY
        
        -- Update mouse position with game coordinates
        self.mouseX = gameX
        self.mouseY = gameY
    else
        -- Fallback if love.window is not available
        self.mouseX, self.mouseY = screenX, screenY
    end
    
    -- Only calculate aim if ball is not moving and user is aiming
    if not ball:isMoving() and self.isAiming then
        self:calculateAim(ball)
    end
end

function Input:calculateAim(ball)
    -- Calculate direction vector from click position to mouse
    self.aimDirection.x = self.mouseX - self.clickPosition.x
    self.aimDirection.y = self.mouseY - self.clickPosition.y
    
    -- Calculate power based on distance (clamped between min and max)
    local distance = math.sqrt(self.aimDirection.x^2 + self.aimDirection.y^2)
    self.aimPower = math.min(self.maxPower, math.max(self.minPower, distance * 2))
    
    -- Normalize direction vector
    if distance > 0 then
        self.aimDirection.x = self.aimDirection.x / distance
        self.aimDirection.y = self.aimDirection.y / distance
    end

    -- Shift camera slightly in the shot direction (opposite of drag) so the player
    -- can see more of where the ball is going while aiming.
    local Camera = require("src.camera")
    local AIM_LOOK = 60  -- max camera shift in game pixels
    local powerFraction = (self.aimPower - self.minPower) / (self.maxPower - self.minPower)
    Camera.aimTargetX = -self.aimDirection.x * AIM_LOOK * powerFraction
    Camera.aimTargetY = -self.aimDirection.y * AIM_LOOK * powerFraction
    
    -- Note: We no longer update the click position here
    -- The click position stays at the original click location
end

-- Function to draw a dashed line made of cells
function Input:drawDashedCellLine(startX, startY, endX, endY, cellSize, spacing)
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

-- Function to draw a pixelated arrow
function Input:drawPixelatedArrow(x, y, dirX, dirY, size)
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

-- Function to draw a pixelated circle
function Input:drawPixelatedCircle(x, y, radius, pixelSize, mode)
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

function Input:draw(ball, attempts)
    -- Draw shots counter in screen space (not affected by camera transform)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1) -- White
    love.graphics.print("Shots: " .. attempts, 0, 16)
    love.graphics.pop()
    
    -- Draw aim line if ball is not moving and user is aiming
    if not ball:isMoving() and self.isAiming and self.clickPosition.x ~= nil then
        -- Only draw when there is meaningful drag distance
        if self.aimPower <= 0 then return end

        local lineLength = self.aimPower / 5 -- Scale down for visual purposes
        local cellSize = 8  -- Size of each cell in pixels
        local cellSpacing = 6  -- Space between cells

        -- Gray dashed line: from press position toward finger (shows the pull/slingshot)
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        local dragEndX = self.clickPosition.x + self.aimDirection.x * lineLength
        local dragEndY = self.clickPosition.y + self.aimDirection.y * lineLength
        self:drawDashedCellLine(
            self.clickPosition.x,
            self.clickPosition.y,
            dragEndX,
            dragEndY,
            cellSize,
            cellSpacing
        )

        -- White arrow: FROM same click origin, going in the shot direction (opposite of drag)
        local shotEndX = self.clickPosition.x - self.aimDirection.x * lineLength
        local shotEndY = self.clickPosition.y - self.aimDirection.y * lineLength
        love.graphics.setColor(1, 1, 1, 1)
        self:drawDashedCellLine(
            self.clickPosition.x,
            self.clickPosition.y,
            shotEndX,
            shotEndY,
            8,
            0
        )
        self:drawPixelatedArrow(
            shotEndX,
            shotEndY,
            -self.aimDirection.x,
            -self.aimDirection.y,
            24
        )

        -- Reset color to white
        love.graphics.setColor(1, 1, 1, 1)

        -- Draw power indicator
        local powerPercentage = (self.aimPower - self.minPower) / (self.maxPower - self.minPower)
        love.graphics.print("Power: " .. math.floor(powerPercentage * 100) .. "%", 650, 30)
    end
end

function Input:handleMousePressed(button, ball, gameX, gameY)
    -- Use provided game coordinates if available, otherwise use stored mouse position
    local clickX = gameX or self.mouseX
    local clickY = gameY or self.mouseY
    
    if button == 1 and not ball:isMoving() then -- Left mouse button
        -- Start aiming
        self.isAiming = true
        
        -- Reset direction so no stale arrow is shown from the previous shot
        self.aimDirection = {x = 0, y = 0}
        self.aimPower = 0

        -- Store the actual clicked position instead of the ball's position
        self.clickPosition.x = clickX
        self.clickPosition.y = clickY
        
        -- Update mouse position to match game coordinates
        if gameX and gameY then
            self.mouseX = gameX
            self.mouseY = gameY
        end
        
        -- Calculate initial aim
        self:calculateAim(ball)
        
        return false -- No shot taken yet
    end
    
    return false -- No shot taken
end

-- Handle mouse release events
function Input:handleMouseReleased(button, ball, gameX, gameY)
    -- Use provided game coordinates if available, otherwise use stored mouse position
    if gameX and gameY then
        self.mouseX = gameX
        self.mouseY = gameY
    end
    
    if button == 1 and self.isAiming and not ball:isMoving() then -- Left mouse button
        -- Stop aiming
        self.isAiming = false

        -- Return camera to ball-centered position
        local Camera = require("src.camera")
        Camera.aimTargetX = 0
        Camera.aimTargetY = 0
        
        -- For slingshot, we want to fire in the direction from mouse to ball
        -- The aimDirection already points from ball to mouse, so we use the negative
        local slingDirection = {
            x = -self.aimDirection.x,
            y = -self.aimDirection.y
        }
        
        -- Shoot the ball using the slingshot direction
        ball:shoot(slingDirection, self.aimPower)
        return true -- Shot was taken
    end
    
    return false -- No shot taken
end

function Input:handleKeyPressed(key, ball)
    if key == "r" then
        -- Check if the player has won
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
        -- This will regenerate the level and reset everything
        love.load()
        
        -- Reset the click position and aiming state
        self.clickPosition.x = nil
        self.clickPosition.y = nil
        self.isAiming = false
        return true -- Reset was performed
    end
    return false -- No action taken
end

return Input
