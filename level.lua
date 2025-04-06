-- level.lua - Level generation and management

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local LevelGenerator = require("src.level_generator")
local Renderer = require("src.renderer")
local Updater = require("src.updater")
local Boulder = require("src.boulder")

local Level = {}
Level.__index = Level

function Level.new(world, width, height)
    local self = setmetatable({}, Level)
    
    self.world = world
    self.width = width
    self.height = height
    self.cells = {}
    self.visualSandCells = {} -- Array to store visual sand cells
    self.boulders = {} -- Array to store boulders
    
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

-- Initialize grass flags for dirt cells
-- This should be called after the level is created and filled with content
function Level:initializeGrass()
    local EMPTY = Cell.TYPES.EMPTY
    local DIRT = Cell.TYPES.DIRT
    
    -- Loop through all cells
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            -- Check if this is a dirt cell
            if self.cells[y][x].type == DIRT then
                -- Check if there's empty space above
                if y > 0 and self.cells[y-1][x].type == EMPTY then
                    -- Mark this dirt cell as having grass
                    self.cells[y][x].hasGrass = true
                end
            end
        end
    end
end

function Level:update(dt, ball)
    -- Increment frame counter
    self.frameCount = self.frameCount + 1
    
    -- Update visual sand cells
    Updater.updateVisualSand(self, dt)
    
    -- Update active clusters
    Updater.updateActiveClusters(self, dt, ball)
    
    -- Update cells in active clusters
    Updater.updateCells(self, dt)
    
    -- Update boulders
    if self.boulders then
        for _, boulder in ipairs(self.boulders) do
            boulder:update(dt)
            
            -- Check for boulder interaction with cells
            local boulderX, boulderY = boulder:getPosition()
            local gridX, gridY = self:getGridCoordinates(boulderX, boulderY)
            
            -- Check surrounding cells for water and sand
            for y = gridY - 2, gridY + 2 do
                for x = gridX - 2, gridX + 2 do
                    if x >= 0 and x < self.width and y >= 0 and y < self.height then
                        local cellType = self:getCellType(x, y)
                        
                        -- Check if boulder is colliding with this cell
                        if boulder:isCollidingWithCell(x, y, Cell.SIZE) then
                            if cellType == CellTypes.TYPES.WATER then
                                boulder:enterWater(x, y)
                            elseif cellType == CellTypes.TYPES.SAND then
                                boulder:enterSand(x, y)
                            end
                        else
                            -- If not colliding, check if we need to exit water/sand
                            if cellType == CellTypes.TYPES.WATER then
                                boulder:exitWater(x, y)
                            elseif cellType == CellTypes.TYPES.SAND then
                                boulder:exitSand(x, y)
                            end
                        end
                    end
                end
            end
        end
    end
end

function Level:draw(debug)
    -- Delegate to the Renderer module
    Renderer.drawLevel(self, debug)
    
    -- Draw boulders
    if self.boulders then
        for _, boulder in ipairs(self.boulders) do
            boulder:draw(debug)
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
    -- Clear all existing cells first
    self:clearAllCells()
    
    -- Create a simple test level with various elements
    LevelGenerator.createTestLevel(self)
end

-- Add a pile of sand at the specified position
function Level:addSandPile(x, y, width, height)
    -- Delegate to the LevelGenerator
    local Sand = require("src.sand")
    Sand.createPile(self, x, y, width, height)
end

-- Add a pool of water at the specified position
function Level:addWaterPool(x, y, width, height)
    -- Delegate to the LevelGenerator
    local Water = require("src.water")
    Water.createPool(self, x, y, width, height)
end

-- Add a dirt block at the specified position
function Level:addDirtBlock(x, y, width, height)
    -- Delegate to the LevelGenerator
    local Dirt = require("dirt") -- Use dirt.lua from root directory
    Dirt.createBlock(self, x, y, width, height)
end

-- Add a win hole at the specified position
function Level:addWinHole(x, y, width, height)
    -- Delegate to the WinHole module
    local WinHole = require("src.win_hole")
    WinHole.createWinHoleArea(self, x, y, width, height)
end

-- Add a large amount of sand for performance testing
function Level:addLotsOfSand(amount)
    -- Clear all existing cells first
    self:clearAllCells()
    
    -- Delegate to the LevelGenerator
    LevelGenerator.createSandTestLevel(self, amount)
end

-- Create a level for testing dirt and water interaction
function Level:createDirtWaterTestLevel()
    -- Clear all existing cells first
    self:clearAllCells()
    
    -- Delegate to the LevelGenerator
    LevelGenerator.createDirtWaterTestLevel(self)
end

-- Create a level with water for testing fluid dynamics
function Level:createWaterTestLevel()
    -- Clear all existing cells first
    self:clearAllCells()
    
    -- Delegate to the LevelGenerator
    LevelGenerator.createWaterTestLevel(self)
end

-- Clear all cells in the level, completely destroying and recreating them
function Level:clearAllCells()
    -- First destroy all existing cells
    for y = 0, self.height - 1 do
        for x = 0, self.width - 1 do
            if self.cells[y] and self.cells[y][x] then
                -- Destroy the cell's physics body
                self.cells[y][x]:destroy(self.world)
            end
        end
    end
    
    -- Recreate all cells as empty
    for y = 0, self.height - 1 do
        self.cells[y] = {}
        self.lastUpdateTime[y] = {}
        for x = 0, self.width - 1 do
            self.cells[y][x] = Cell.new(self.world, x, y, Cell.TYPES.EMPTY)
            self.lastUpdateTime[y][x] = 0
        end
    end
    
    -- Clear visual sand cells
    self.visualSandCells = {}
    
    -- Clear boulders
    if self.boulders then
        for _, boulder in ipairs(self.boulders) do
            if boulder.body then
                boulder.body:destroy()
            end
        end
        self.boulders = {}
    end
    
    -- Reset active cells
    self.activeCells = {}
    
    -- Reset clusters
    local clusterRows = math.ceil(self.height / self.clusterSize)
    local clusterCols = math.ceil(self.width / self.clusterSize)
    for cy = 0, clusterRows - 1 do
        for cx = 0, clusterCols - 1 do
            if self.clusters[cy] and self.clusters[cy][cx] then
                self.clusters[cy][cx].active = false
                self.clusters[cy][cx].cells = {}
                self.clusters[cy][cx].lastUpdate = 0
            end
        end
    end
    
    -- Force a garbage collection to clean up any lingering references
    collectgarbage("collect")
end

-- Create a procedural level with tunnels, dirt, stone, water ponds, and sand traps
-- difficulty: 1 = easy, 2 = medium, 3 = hard, 4 = expert, 5 = insane
function Level:createProceduralLevel(difficulty)
    -- Clear all existing cells first
    self:clearAllCells()
    
    -- Delegate to the LevelGenerator with the specified difficulty
    LevelGenerator.createProceduralLevel(self, difficulty)
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
    
    -- Destroy all boulders
    if self.boulders then
        for _, boulder in ipairs(self.boulders) do
            if boulder.body then
                boulder.body:destroy()
            end
        end
        self.boulders = {}
    end
end

return Level
