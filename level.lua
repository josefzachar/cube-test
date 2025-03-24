-- level.lua - Level generation and management

local Cell = require("cell")

local Level = {}
Level.__index = Level

function Level.new(world, width, height)
    local self = setmetatable({}, Level)
    
    self.world = world
    self.width = width
    self.height = height
    self.cells = {}
    self.visualSandCells = {} -- Array to store visual sand cells
    
    -- Initialize empty grid
    for y = 0, height - 1 do
        self.cells[y] = {}
        for x = 0, width - 1 do
            self.cells[y][x] = Cell.new(world, x, y, Cell.TYPES.EMPTY)
        end
    end
    
    return self
end

function Level:update(dt)
    
    -- Update all cells
    -- First update visual sand cells in the grid
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            if self.cells[y] and self.cells[y][x] and 
               self.cells[y][x].type == Cell.TYPES.VISUAL_SAND then
                self.cells[y][x]:update(dt, self)
            end
        end
    end
    
    -- Update visual sand cells in the visualSandCells array
    local i = 1
    while i <= #self.visualSandCells do
        local cell = self.visualSandCells[i]
        
        -- Update position based on velocity
        cell.visualX = cell.visualX + cell.velocityX * dt
        cell.visualY = cell.visualY + cell.velocityY * dt
        
        -- Apply gravity
        cell.velocityY = cell.velocityY + 500 * dt  -- Gravity
        
        -- Update lifetime and alpha
        cell.lifetime = (cell.lifetime or 0) + dt
        cell.alpha = math.max(0, 1 - (cell.lifetime / (cell.maxLifetime or 2.0)))
        
        -- Check if the visual sand should disappear
        if cell.lifetime >= (cell.maxLifetime or 2.0) or
           cell.visualX < 0 or cell.visualX >= self.width * Cell.SIZE or 
           cell.visualY < 0 or cell.visualY >= self.height * Cell.SIZE then
            -- Remove the visual sand
            table.remove(self.visualSandCells, i)
        else
            i = i + 1
        end
    end
    
    -- Then update cellular automata cells (regular sand)
    -- Process from bottom to top and right to left for more natural falling
    for y = self.height - 1, 0, -1 do
        -- Alternate direction each row for more natural movement
        if y % 2 == 0 then
            -- Process left to right
            for x = 0, self.width - 1 do
                if self.cells[y] and self.cells[y][x] and 
                   self.cells[y][x].type == Cell.TYPES.SAND then
                    self.cells[y][x]:update(dt, self)
                end
            end
        else
            -- Process right to left
            for x = self.width - 1, 0, -1 do
                if self.cells[y] and self.cells[y][x] and 
                   self.cells[y][x].type == Cell.TYPES.SAND then
                    self.cells[y][x]:update(dt, self)
                end
            end
        end
    end
end

function Level:draw()
    -- Draw all cells
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            if self.cells[y] and self.cells[y][x] then
                self.cells[y][x]:draw()
            end
        end
    end
    
    -- Draw visual sand cells
    for _, cell in ipairs(self.visualSandCells) do
        -- Draw visual sand at its actual position with alpha for fade out
        local color = {1.0, 0.9, 0.6, cell.alpha or 1.0} -- Brighter sand for visual effect
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", cell.visualX, cell.visualY, Cell.SIZE, Cell.SIZE)
    end
end

function Level:setCellType(x, y, type)
    -- Set cell type if within bounds
    if x >= 0 and x < self.width and y >= 0 and y < self.height then
        self.cells[y][x]:setType(self.world, type)
    end
end

-- This function is no longer needed since we're using visual sand
-- The conversion is done directly in main.lua

function Level:getCellType(x, y)
    -- Get cell type if within bounds
    if x >= 0 and x < self.width and y >= 0 and y < self.height then
        return self.cells[y][x].type
    end
    return nil
end

function Level:createTestLevel()
    -- Create a simple test level with only stone cells (no sand)
    
    -- Create ground
    for x = 0, self.width - 1 do
        self:setCellType(x, self.height - 1, Cell.TYPES.STONE)
        self:setCellType(x, self.height - 2, Cell.TYPES.STONE)
    end
    
    -- Create walls
    for y = 0, self.height - 1 do
        self:setCellType(0, y, Cell.TYPES.STONE)
        self:setCellType(self.width - 1, y, Cell.TYPES.STONE)
    end
    
    -- Create ceiling
    for x = 0, self.width - 1 do
        self:setCellType(x, 0, Cell.TYPES.STONE)
    end
    
    -- Create some stone obstacles
    for x = 30, 35 do
        for y = self.height - 10, self.height - 5 do
            self:setCellType(x, y, Cell.TYPES.STONE)
        end
    end
    
    -- Create a stone platform
    for x = 60, 70 do
        self:setCellType(x, self.height - 10, Cell.TYPES.STONE)
    end
end

function Level:getWorldCoordinates(gridX, gridY)
    return gridX * Cell.SIZE + Cell.SIZE/2, gridY * Cell.SIZE + Cell.SIZE/2
end

function Level:getGridCoordinates(worldX, worldY)
    return math.floor(worldX / Cell.SIZE), math.floor(worldY / Cell.SIZE)
end

function Level:destroy()
    -- Destroy all cells
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            if self.cells[y] and self.cells[y][x] then
                self.cells[y][x]:destroy(self.world)
            end
        end
    end
end

return Level
