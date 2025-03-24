-- level.lua - Level generation and management

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local Level = {}
Level.__index = Level

function Level.new(world, width, height)
    local self = setmetatable({}, Level)
    
    self.world = world
    self.width = width
    self.height = height
    self.cells = {}
    self.visualSandCells = {} -- Array to store visual sand cells
    
    -- Performance optimization variables
    self.activeCells = {} -- Table to track cells that need updating
    self.clusterSize = 8 -- Size of each cluster (8x8 cells)
    self.clusters = {} -- Table to track active clusters
    self.lastUpdateTime = {} -- Track when each cluster was last updated
    self.updateInterval = 1/60 -- Update interval for inactive clusters (once per frame)
    self.frameCount = 0 -- Frame counter for staggered updates
    
    -- Initialize empty grid
    for y = 0, height - 1 do
        self.cells[y] = {}
        self.lastUpdateTime[y] = {}
        for x = 0, width - 1 do
            self.cells[y][x] = Cell.new(world, x, y, Cell.TYPES.EMPTY)
            self.lastUpdateTime[y][x] = 0
        end
    end
    
    -- Initialize clusters
    local clusterRows = math.ceil(height / self.clusterSize)
    local clusterCols = math.ceil(width / self.clusterSize)
    for cy = 0, clusterRows - 1 do
        self.clusters[cy] = {}
        for cx = 0, clusterCols - 1 do
            self.clusters[cy][cx] = {
                active = false,
                cells = {},
                lastUpdate = 0
            }
        end
    end
    
    return self
end

function Level:update(dt, ball)
    -- Increment frame counter
    self.frameCount = self.frameCount + 1
    
    -- Update visual sand cells in the visualSandCells array
    -- These are always updated regardless of clustering
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
    
    -- Update active clusters
    self:updateActiveClusters(dt, ball)
    
    -- Update cells in active clusters
    self:updateCellsInActiveClusters(dt)
end

-- Mark clusters as active based on ball position and recent changes
function Level:updateActiveClusters(dt, ball)
    -- Reset all clusters to inactive
    local clusterRows = math.ceil(self.height / self.clusterSize)
    local clusterCols = math.ceil(self.width / self.clusterSize)
    
    for cy = 0, clusterRows - 1 do
        for cx = 0, clusterCols - 1 do
            self.clusters[cy][cx].active = false
        end
    end
    
    -- Mark clusters as active based on ball position
    if ball and ball.body then
        local ballX, ballY = ball.body:getPosition()
        local gridX, gridY = self:getGridCoordinates(ballX, ballY)
        
        -- Mark a 3x3 grid of clusters around the ball as active
        local clusterX = math.floor(gridX / self.clusterSize)
        local clusterY = math.floor(gridY / self.clusterSize)
        
        for cy = clusterY - 1, clusterY + 1 do
            for cx = clusterX - 1, clusterX + 1 do
                if cy >= 0 and cy < clusterRows and cx >= 0 and cx < clusterCols then
                    self.clusters[cy][cx].active = true
                end
            end
        end
    end
    
    -- Mark clusters as active based on recent changes
    for _, cell in ipairs(self.activeCells) do
        local clusterX = math.floor(cell.x / self.clusterSize)
        local clusterY = math.floor(cell.y / self.clusterSize)
        
        if clusterY >= 0 and clusterY < clusterRows and clusterX >= 0 and clusterX < clusterCols then
            self.clusters[clusterY][clusterX].active = true
            
            -- Also mark clusters below as active (for falling sand)
            if clusterY + 1 < clusterRows then
                self.clusters[clusterY + 1][clusterX].active = true
            end
        end
    end
    
    -- Store active cells for debug visualization
    self.debugActiveCells = {}
    for _, cell in ipairs(self.activeCells) do
        table.insert(self.debugActiveCells, {x = cell.x, y = cell.y, time = love.timer.getTime()})
    end
    
    -- Clear active cells list for next frame
    self.activeCells = {}
end

-- Update cells in active clusters
function Level:updateCellsInActiveClusters(dt)
    -- IMPORTANT: Disable cluster-based optimization for sand cells
    -- Update all sand cells every frame to eliminate horizontal lines
    
    -- Process from bottom to top for natural falling
    for y = self.height - 1, 0, -1 do
        -- Alternate direction each row for more natural movement
        if y % 2 == 0 then
            -- Process left to right
            for x = 0, self.width - 1 do
                if self.cells[y] and self.cells[y][x] then
                    -- Update visual sand cells
                    if self.cells[y][x].type == Cell.TYPES.VISUAL_SAND then
                        self.cells[y][x]:update(dt, self)
                    end
                    
                    -- Update sand cells - ALWAYS update ALL sand cells
                    if self.cells[y][x].type == Cell.TYPES.SAND then
                        local changed = self.cells[y][x]:update(dt, self)
                        
                        -- If the cell changed, mark it as active for next frame
                        if changed then
                            table.insert(self.activeCells, {x = x, y = y})
                        end
                    end
                end
            end
        else
            -- Process right to left
            for x = self.width - 1, 0, -1 do
                if self.cells[y] and self.cells[y][x] then
                    -- Update visual sand cells
                    if self.cells[y][x].type == Cell.TYPES.VISUAL_SAND then
                        self.cells[y][x]:update(dt, self)
                    end
                    
                    -- Update sand cells - ALWAYS update ALL sand cells
                    if self.cells[y][x].type == Cell.TYPES.SAND then
                        local changed = self.cells[y][x]:update(dt, self)
                        
                        -- If the cell changed, mark it as active for next frame
                        if changed then
                            table.insert(self.activeCells, {x = x, y = y})
                        end
                    end
                end
            end
        end
    end
    
    -- Keep track of active cells for debug visualization
    self.debugActiveCells = {}
    for _, cell in ipairs(self.activeCells) do
        table.insert(self.debugActiveCells, {x = cell.x, y = cell.y, time = love.timer.getTime()})
    end
end

function Level:draw(debug)
    -- Get visible area (camera view)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Calculate visible cell range with some margin
    local margin = 5 -- Extra cells to draw outside the visible area
    local minX = math.max(0, math.floor(0 / CellTypes.SIZE) - margin)
    local maxX = math.min(self.width - 1, math.ceil(screenWidth / CellTypes.SIZE) + margin)
    local minY = math.max(0, math.floor(0 / CellTypes.SIZE) - margin)
    local maxY = math.min(self.height - 1, math.ceil(screenHeight / CellTypes.SIZE) + margin)
    
    -- Batch drawing for better performance
    local sandBatch = {}
    local stoneBatch = {}
    local tempStoneBatch = {}
    
    -- Collect cells for batch drawing
    for y = minY, maxY do
        for x = minX, maxX do
            if self.cells[y] and self.cells[y][x] then
                local cell = self.cells[y][x]
                local cellType = cell.type
                
                if cellType == Cell.TYPES.SAND then
                    table.insert(sandBatch, {x = x, y = y})
                elseif cellType == Cell.TYPES.STONE then
                    table.insert(stoneBatch, {x = x, y = y})
                elseif cellType == Cell.TYPES.TEMP_STONE then
                    table.insert(tempStoneBatch, {x = x, y = y})
                elseif debug and cellType == Cell.TYPES.EMPTY then
                    -- Draw empty cells only in debug mode
                    love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
                    love.graphics.rectangle("line", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
                end
            end
        end
    end
    
    -- Draw sand cells
    love.graphics.setColor(0.9, 0.8, 0.5, 1) -- Sand color
    for _, cell in ipairs(sandBatch) do
        love.graphics.rectangle("fill", cell.x * Cell.SIZE, cell.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(0, 0, 1, 1) -- Blue
            love.graphics.circle("fill", cell.x * Cell.SIZE + Cell.SIZE/2, cell.y * Cell.SIZE + Cell.SIZE/2, 2)
            love.graphics.setColor(0.9, 0.8, 0.5, 1) -- Reset to sand color
        end
    end
    
    -- Draw stone cells
    love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Stone color
    for _, cell in ipairs(stoneBatch) do
        love.graphics.rectangle("fill", cell.x * Cell.SIZE, cell.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(1, 0, 0, 1) -- Red
            love.graphics.circle("fill", cell.x * Cell.SIZE + Cell.SIZE/2, cell.y * Cell.SIZE + Cell.SIZE/2, 2)
            love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Reset to stone color
        end
    end
    
    -- Draw temp stone cells
    love.graphics.setColor(0.9, 0.8, 0.5, 1) -- Same as sand color
    for _, cell in ipairs(tempStoneBatch) do
        love.graphics.rectangle("fill", cell.x * Cell.SIZE, cell.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(1, 0, 1, 1) -- Magenta
            love.graphics.circle("fill", cell.x * Cell.SIZE + Cell.SIZE/2, cell.y * Cell.SIZE + Cell.SIZE/2, 2)
            love.graphics.setColor(0.9, 0.8, 0.5, 1) -- Reset to sand color
        end
    end
    
    -- Draw visual sand cells
    if #self.visualSandCells > 0 then
        for _, cell in ipairs(self.visualSandCells) do
            -- Only draw if within visible area
            if cell.visualX >= minX * Cell.SIZE - Cell.SIZE and 
               cell.visualX <= maxX * Cell.SIZE + Cell.SIZE and
               cell.visualY >= minY * Cell.SIZE - Cell.SIZE and
               cell.visualY <= maxY * Cell.SIZE + Cell.SIZE then
                
                -- Draw visual sand at its actual position with alpha for fade out
                local color = {1.0, 0.9, 0.6, cell.alpha or 1.0} -- Brighter sand for visual effect
                love.graphics.setColor(color)
                love.graphics.rectangle("fill", cell.visualX, cell.visualY, Cell.SIZE, Cell.SIZE)
                
                -- Draw debug info for visual sand
                if debug then
                    love.graphics.setColor(1, 0, 0, cell.alpha or 1.0)
                    love.graphics.rectangle("line", cell.visualX, cell.visualY, Cell.SIZE, Cell.SIZE)
                end
            end
        end
    end
    
    -- Draw grid lines in debug mode
    if debug then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
        for x = minX, maxX + 1 do
            love.graphics.line(x * Cell.SIZE, minY * Cell.SIZE, x * Cell.SIZE, (maxY + 1) * Cell.SIZE)
        end
        for y = minY, maxY + 1 do
            love.graphics.line(minX * Cell.SIZE, y * Cell.SIZE, (maxX + 1) * Cell.SIZE, y * Cell.SIZE)
        end
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
    
    -- Add some sand piles
    self:addSandPile(40, self.height - 3, 10, 20)
    self:addSandPile(80, self.height - 3, 15, 30)
    self:addSandPile(120, self.height - 3, 20, 40)
end

-- Add a pile of sand at the specified position
function Level:addSandPile(x, y, width, height)
    -- Create a triangular pile of sand
    for py = 0, height - 1 do
        local rowWidth = math.floor(width * (1 - py / height))
        local startX = x - math.floor(rowWidth / 2)
        local endX = startX + rowWidth - 1
        
        for px = startX, endX do
            if px >= 0 and px < self.width and y - py >= 0 and y - py < self.height then
                self:setCellType(px, y - py, Cell.TYPES.SAND)
            end
        end
    end
end

-- Add a large amount of sand for performance testing
function Level:addLotsOfSand(amount)
    -- Add random sand cells
    for i = 1, amount do
        local x = math.random(1, self.width - 2)
        local y = math.random(1, self.height - 3)
        
        if self:getCellType(x, y) == Cell.TYPES.EMPTY then
            self:setCellType(x, y, Cell.TYPES.SAND)
        end
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
