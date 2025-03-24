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
    -- First update physics-based cells (flying sand)
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            if self.cells[y] and self.cells[y][x] and 
               self.cells[y][x].type == Cell.TYPES.FLYING_SAND then
                self.cells[y][x]:update(dt, self)
            end
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
                   self.cells[y][x].type == Cell.TYPES.SAND and
                   self.cells[y][x].state == Cell.STATES.STATIC then
                    self.cells[y][x]:update(dt, self)
                end
            end
        else
            -- Process right to left
            for x = self.width - 1, 0, -1 do
                if self.cells[y] and self.cells[y][x] and 
                   self.cells[y][x].type == Cell.TYPES.SAND and
                   self.cells[y][x].state == Cell.STATES.STATIC then
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
end

function Level:setCellType(x, y, type)
    -- Set cell type if within bounds
    if x >= 0 and x < self.width and y >= 0 and y < self.height then
        self.cells[y][x]:setType(self.world, type)
    end
end

-- Convert a sand cell to flying sand when hit by the ball
function Level:convertSandToFlying(x, y, velocityX, velocityY)
    -- Check if the coordinates are valid
    if x < 0 or x >= self.width or y < 0 or y >= self.height then
        print("  ERROR: Invalid coordinates", x, y)
        return false
    end
    
    -- Check if the cell exists and is sand
    if not self.cells[y] or not self.cells[y][x] then
        print("  ERROR: Cell does not exist at", x, y)
        return false
    end
    
    -- Only convert sand cells
    if self.cells[y][x].type ~= Cell.TYPES.SAND then
        print("  ERROR: Cell at", x, y, "is not sand, it's", self.cells[y][x].type)
        return false
    end
    
    -- Convert to flying sand
    print("  SUCCESS: Converting sand at", x, y, "to flying sand")
    self.cells[y][x]:convertToFlyingSand(self.world, velocityX, velocityY)
    return true
end

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
