-- input.lua - Input handling (mouse, keyboard)

local Cell = require("cell")
local CellTypes = require("src.cell_types")

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
    CellTypes.TYPES.DIRT
}

-- Material names for display
local MATERIAL_NAMES = {
    [CellTypes.TYPES.SAND] = "SAND",
    [CellTypes.TYPES.STONE] = "STONE",
    [CellTypes.TYPES.WATER] = "WATER",
    [CellTypes.TYPES.DIRT] = "DIRT"
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
    self.mouseX, self.mouseY = love.mouse.getPosition()
    
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
                -- Create a new cell of the current material type
                level:setCellType(cellX, cellY, materialType)
            end
        end
    end
end

function Input:draw(ball)
    -- Draw mode indicator
    love.graphics.setColor(1, 1, 1, 1) -- White
    if self.mode == MODES.SHOOT then
        love.graphics.print("Mode: SHOOT (press SPACE to switch)", 10, 30)
        
        -- Draw aim line if ball is not moving and user is aiming
        if not ball:isMoving() and self.isAiming and self.clickPosition.x ~= nil then
            local lineLength = self.aimPower / 10 -- Scale down for visual purposes
            
            -- Draw original aim line
            love.graphics.setColor(0.8, 0.8, 0.8, 1) -- Light gray for original direction
            love.graphics.line(
                self.clickPosition.x, 
                self.clickPosition.y, 
                self.clickPosition.x + self.aimDirection.x * lineLength, 
                self.clickPosition.y + self.aimDirection.y * lineLength
            )
            
            -- Draw opposite aim line (actual shot direction)
            love.graphics.setColor(1, 0, 0, 1) -- Red for shot direction
            love.graphics.line(
                self.clickPosition.x, 
                self.clickPosition.y, 
                self.clickPosition.x - self.aimDirection.x * lineLength, 
                self.clickPosition.y - self.aimDirection.y * lineLength
            )
            
            -- Draw a small indicator at the clicked position
            love.graphics.setColor(1, 0.5, 0, 1) -- Orange
            love.graphics.circle("fill", self.clickPosition.x, self.clickPosition.y, 5)
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
        
        -- Display current mode and material
        love.graphics.print("Mode: SPRAY - Material: " .. materialName .. " (press SPACE to switch, RIGHT-CLICK to change material)", 10, 30)
        
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

function Input:handleMousePressed(button, ball)
    if self.mode == MODES.SHOOT then
        if button == 1 and not ball:isMoving() then -- Left mouse button
            -- Start aiming
            self.isAiming = true
            
            -- Store the clicked position
            self.clickPosition.x = self.mouseX
            self.clickPosition.y = self.mouseY
            
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
function Input:handleMouseReleased(button, ball)
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
        -- Reset the ball to the starting position (matching the level generator)
        ball:reset(20 * Cell.SIZE, 20 * Cell.SIZE)
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
