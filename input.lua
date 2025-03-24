-- input.lua - Input handling (mouse, keyboard)

local Cell = require("cell")

local Input = {}
Input.__index = Input

-- Game modes
local MODES = {
    SHOOT = 1,
    SPRAY = 2
}

function Input.new()
    local self = setmetatable({}, Input)
    
    self.mouseX = 0
    self.mouseY = 0
    self.aimDirection = {x = 0, y = 0}
    self.aimPower = 0
    self.maxPower = 800
    self.minPower = 100
    
    -- Sand spraying properties
    self.mode = MODES.SHOOT -- Start in shooting mode
    self.sprayRadius = 2 -- Radius of sand spray
    self.sprayRate = 5 -- Number of sand particles per update
    
    return self
end

function Input:update(ball, level)
    -- Update mouse position
    self.mouseX, self.mouseY = love.mouse.getPosition()
    
    -- Handle mode switching
    if self.mode == MODES.SHOOT then
        -- Only calculate aim if ball is not moving
        if not ball:isMoving() then
            self:calculateAim(ball)
        end
    elseif self.mode == MODES.SPRAY then
        -- Handle sand spraying
        if love.mouse.isDown(1) then -- Left mouse button
            self:spraySand(level)
        end
    end
end

function Input:calculateAim(ball)
    local ballX, ballY = ball:getPosition()
    
    -- Calculate direction vector
    self.aimDirection.x = self.mouseX - ballX
    self.aimDirection.y = self.mouseY - ballY
    
    -- Calculate power based on distance (clamped between min and max)
    local distance = math.sqrt(self.aimDirection.x^2 + self.aimDirection.y^2)
    self.aimPower = math.min(self.maxPower, math.max(self.minPower, distance * 2))
    
    -- Normalize direction vector
    if distance > 0 then
        self.aimDirection.x = self.aimDirection.x / distance
        self.aimDirection.y = self.aimDirection.y / distance
    end
end

function Input:spraySand(level)
    -- Convert mouse position to grid coordinates
    local gridX, gridY = level:getGridCoordinates(self.mouseX, self.mouseY)
    
    -- Spray sand in a radius around the mouse position
    for i = 1, self.sprayRate do
        -- Random position within spray radius
        local offsetX = math.random(-self.sprayRadius, self.sprayRadius)
        local offsetY = math.random(-self.sprayRadius, self.sprayRadius)
        
        local sandX = gridX + offsetX
        local sandY = gridY + offsetY
        
        -- Check if the position is valid and empty
        if sandX >= 0 and sandX < level.width and sandY >= 0 and sandY < level.height then
            if level:getCellType(sandX, sandY) == Cell.TYPES.EMPTY then
                -- Create a new sand cell
                level:setCellType(sandX, sandY, Cell.TYPES.SAND)
            end
        end
    end
end

function Input:draw(ball)
    -- Draw mode indicator
    love.graphics.setColor(1, 1, 1, 1) -- White
    if self.mode == MODES.SHOOT then
        love.graphics.print("Mode: SHOOT (press SPACE to switch)", 10, 30)
        
        -- Draw aim line if ball is not moving
        if not ball:isMoving() then
            local ballX, ballY = ball:getPosition()
            local lineLength = self.aimPower / 10 -- Scale down for visual purposes
            
            love.graphics.line(
                ballX, 
                ballY, 
                ballX + self.aimDirection.x * lineLength, 
                ballY + self.aimDirection.y * lineLength
            )
            
            -- Draw power indicator
            local powerPercentage = (self.aimPower - self.minPower) / (self.maxPower - self.minPower)
            love.graphics.print("Power: " .. math.floor(powerPercentage * 100) .. "%", 650, 30)
        end
    else
        love.graphics.print("Mode: SPRAY (press SPACE to switch)", 10, 30)
        
        -- Draw spray indicator
        local gridX, gridY = math.floor(self.mouseX / Cell.SIZE), math.floor(self.mouseY / Cell.SIZE)
        love.graphics.circle("line", gridX * Cell.SIZE + Cell.SIZE/2, gridY * Cell.SIZE + Cell.SIZE/2, self.sprayRadius * Cell.SIZE)
    end
end

function Input:handleMousePressed(button, ball)
    if self.mode == MODES.SHOOT then
        if button == 1 and not ball:isMoving() then -- Left mouse button
            -- Shoot the ball in the aimed direction
            ball:shoot(self.aimDirection, self.aimPower)
            return true -- Shot was taken
        end
    end
    return false -- No shot taken
end

function Input:handleKeyPressed(key, ball)
    if key == "r" then
        -- Reset the ball to the starting position
        ball:reset(100, 500)
        return true -- Reset was performed
    elseif key == "space" then
        -- Switch between shooting and spraying modes
        if self.mode == MODES.SHOOT then
            self.mode = MODES.SPRAY
        else
            self.mode = MODES.SHOOT
        end
    end
    return false -- No action taken
end

return Input
