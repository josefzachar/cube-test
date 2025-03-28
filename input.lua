-- input.lua - Input handling (mouse, keyboard)

local Cell = require("cell")
local CellTypes = require("src.cell_types")

-- Original design dimensions (must match the values in main.lua)
local ORIGINAL_WIDTH = 1600
local ORIGINAL_HEIGHT = 1000

-- Background color (must match the value in main.lua)
local BACKGROUND_COLOR = {0.2, 0.3, 0.6, 1.0} -- Dark blue (base color)

local Input = {}
Input.__index = Input

-- Game modes
local MODES = {
    SHOOT = 1,
    SPRAY = 2
}

-- Available material types for spraying (excluding visual effects)
local MATERIALS = {
    CellTypes.TYPES.SAND,
    CellTypes.TYPES.STONE,
    CellTypes.TYPES.WATER,
    CellTypes.TYPES.DIRT,
    CellTypes.TYPES.FIRE
}

-- Material names for display
local MATERIAL_NAMES = {
    [CellTypes.TYPES.SAND] = "SAND",
    [CellTypes.TYPES.STONE] = "STONE",
    [CellTypes.TYPES.WATER] = "WATER",
    [CellTypes.TYPES.DIRT] = "DIRT",
    [CellTypes.TYPES.FIRE] = "FIRE"
}

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
    
    -- Material spraying properties
    self.mode = MODES.SHOOT -- Start in shooting mode
    self.sprayRadius = 2 -- Radius of spray
    self.sprayRate = 5 -- Number of particles per update
    self.currentMaterialIndex = 1 -- Start with first material (SAND)
    
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
        
        -- Convert screen coordinates to game coordinates
        gameX = (screenX / scale) - offsetX
        gameY = (screenY / scale) - offsetY
        
        -- Update mouse position with game coordinates
        self.mouseX = gameX
        self.mouseY = gameY
    else
        -- Fallback if love.window is not available
        self.mouseX, self.mouseY = screenX, screenY
    end
    
    -- Handle mode switching
    if self.mode == MODES.SHOOT then
        -- Only calculate aim if ball is not moving and user is aiming
        if not ball:isMoving() and self.isAiming then
            self:calculateAim(ball)
        end
    elseif self.mode == MODES.SPRAY then
        -- Handle material spraying
        if love.mouse.isDown(1) then -- Left mouse button
            self:sprayMaterial(level)
        end
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
    
    -- Note: We no longer update the click position here
    -- The click position stays at the original click location
end

function Input:sprayMaterial(level)
    -- Convert mouse position to grid coordinates
    local gridX, gridY = level:getGridCoordinates(self.mouseX, self.mouseY)
    
    -- Get current material type
    local materialType = MATERIALS[self.currentMaterialIndex]
    
    -- Spray material in a radius around the mouse position
    for i = 1, self.sprayRate do
        -- Random position within spray radius
        local offsetX = math.random(-self.sprayRadius, self.sprayRadius)
        local offsetY = math.random(-self.sprayRadius, self.sprayRadius)
        
        local cellX = gridX + offsetX
        local cellY = gridY + offsetY
        
        -- Check if the position is valid and empty
        if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
            if level:getCellType(cellX, cellY) == CellTypes.TYPES.EMPTY then
                -- Special handling for fire
                if materialType == CellTypes.TYPES.FIRE then
                    -- Use the Fire module to create fire properly
                    local Fire = require("src.fire")
                    Fire.createFire(level, cellX, cellY)
                else
                    -- Create a new cell of the current material type
                    level:setCellType(cellX, cellY, materialType)
                end
            end
        end
    end
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
    -- Draw mode indicator
    love.graphics.setColor(1, 1, 1, 1) -- White
    if self.mode == MODES.SHOOT then
        love.graphics.print("Mode: SHOOT (press SPACE to switch)", 10, 30)
        love.graphics.print("Shots: " .. attempts, 10, 50)
        
        -- Draw aim line if ball is not moving and user is aiming
        if not ball:isMoving() and self.isAiming and self.clickPosition.x ~= nil then
            local lineLength = self.aimPower / 5 -- Scale down for visual purposes
            local cellSize = 8  -- Size of each cell in pixels
            local cellSpacing = 6  -- Space between cells
            
            -- Draw original aim line (dashed cells)
            love.graphics.setColor(0.4, 0.4, 0.4, 1) -- Light gray for original direction
            local endX = self.clickPosition.x + self.aimDirection.x * lineLength
            local endY = self.clickPosition.y + self.aimDirection.y * lineLength
            self:drawDashedCellLine(
                self.clickPosition.x, 
                self.clickPosition.y, 
                endX, 
                endY,
                cellSize,
                cellSpacing
            )
            
            -- Draw opposite aim line (actual shot direction)
            love.graphics.setColor(1, 1, 1, 1) -- Red for shot direction
            local shotEndX = self.clickPosition.x - self.aimDirection.x * lineLength
            local shotEndY = self.clickPosition.y - self.aimDirection.y * lineLength
            self:drawDashedCellLine(
                self.clickPosition.x, 
                self.clickPosition.y, 
                shotEndX, 
                shotEndY,
                8,
                0
            )
            
            -- Draw pixelated arrow at the end of the red line
            self:drawPixelatedArrow(
                shotEndX, 
                shotEndY, 
                -self.aimDirection.x, 
                -self.aimDirection.y, 
                24 -- Arrow size
            )
            
            -- Draw a small indicator at the clicked position
            -- First draw the filled circle with background color
            love.graphics.setColor(BACKGROUND_COLOR[1], BACKGROUND_COLOR[2], BACKGROUND_COLOR[3], BACKGROUND_COLOR[4])
            self:drawPixelatedCircle(self.clickPosition.x, self.clickPosition.y, 12, 2, "fill")
            -- Then draw the white border over it
            love.graphics.setColor(1, 1, 1, 1) -- White
            self:drawPixelatedCircle(self.clickPosition.x, self.clickPosition.y, 12, 2, "line")
            love.graphics.setColor(1, 1, 1, 1) -- Reset to white
            
            -- Draw power indicator
            local powerPercentage = (self.aimPower - self.minPower) / (self.maxPower - self.minPower)
            love.graphics.print("Power: " .. math.floor(powerPercentage * 100) .. "%", 650, 30)
        end
    else
        -- Get the current material type and name
        local materialType = MATERIALS[self.currentMaterialIndex]
        local materialName = MATERIAL_NAMES[materialType]
        
        -- Get the color for the current material
        local materialColor = CellTypes.COLORS[materialType]
        
        -- Display mode and shots
        love.graphics.print("Mode: SPRAY - Material: " .. materialName .. " (press SPACE to switch, RIGHT-CLICK to change material)", 10, 30)
        love.graphics.print("Shots: " .. attempts, 10, 50)
        
        -- Draw spray indicator with current material color
        local gridX, gridY = math.floor(self.mouseX / CellTypes.SIZE), math.floor(self.mouseY / CellTypes.SIZE)
        
        -- Draw filled circle with semi-transparency
        love.graphics.setColor(materialColor[1], materialColor[2], materialColor[3], 0.5)
        love.graphics.circle("fill", gridX * CellTypes.SIZE + CellTypes.SIZE/2, gridY * CellTypes.SIZE + CellTypes.SIZE/2, self.sprayRadius * CellTypes.SIZE)
        
        -- Draw outline with full opacity
        love.graphics.setColor(materialColor[1], materialColor[2], materialColor[3], 1)
        love.graphics.circle("line", gridX * CellTypes.SIZE + CellTypes.SIZE/2, gridY * CellTypes.SIZE + CellTypes.SIZE/2, self.sprayRadius * CellTypes.SIZE)
        
        -- Reset color
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function Input:handleMousePressed(button, ball, gameX, gameY)
    -- Use provided game coordinates if available, otherwise use stored mouse position
    local clickX = gameX or self.mouseX
    local clickY = gameY or self.mouseY
    
    if self.mode == MODES.SHOOT then
        if button == 1 and not ball:isMoving() then -- Left mouse button
            -- Start aiming
            self.isAiming = true
            
            -- Store the clicked position
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
    elseif self.mode == MODES.SPRAY then
        if button == 2 then -- Right mouse button
            -- Cycle to next material
            self:cycleMaterial()
            return false
        end
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
    
    if self.mode == MODES.SHOOT then
        if button == 1 and self.isAiming and not ball:isMoving() then -- Left mouse button
            -- Stop aiming
            self.isAiming = false
            
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
    elseif key == "space" then
        -- Switch between shooting and spraying modes
        if self.mode == MODES.SHOOT then
            self.mode = MODES.SPRAY
        else
            self.mode = MODES.SHOOT
        end
        -- Reset aiming state when switching modes
        self.isAiming = false
    elseif key == "1" or key == "2" or key == "3" or key == "4" then
        -- Number keys 1-4 for quick material selection
        if self.mode == MODES.SPRAY then
            local index = tonumber(key)
            if index <= #MATERIALS then
                self.currentMaterialIndex = index
            end
        end
    end
    return false -- No action taken
end

function Input:cycleMaterial()
    -- Cycle to the next material
    self.currentMaterialIndex = self.currentMaterialIndex % #MATERIALS + 1
end

return Input
