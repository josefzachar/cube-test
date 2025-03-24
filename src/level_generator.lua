-- level_generator.lua - Level generation utilities

local CellTypes = require("src.cell_types")
local Sand = require("src.sand")
local Water = require("src.water")
local Stone = require("src.stone")

local LevelGenerator = {}

-- Create a test level with various elements
function LevelGenerator.createTestLevel(level)
    -- Create stone walls around the level
    Stone.createWalls(level)
    
    -- Create some stone obstacles
    Stone.createBlock(level, 30, level.height - 10, 6, 6)
    
    -- Create a stone platform
    Stone.createPlatform(level, 60, level.height - 10, 11)
    
    -- Add some sand piles
    Sand.createPile(level, 40, level.height - 3, 10, 20)
    Sand.createPile(level, 80, level.height - 3, 15, 30)
    Sand.createPile(level, 120, level.height - 3, 20, 40)
    
    -- Add water pools
    Water.createPool(level, 20, level.height - 5, 20, 3)  -- Ground level pool
    Water.createPool(level, 50, level.height - 30, 30, 10) -- Larger pool higher up
end

-- Create a level with lots of sand for performance testing
function LevelGenerator.createSandTestLevel(level, amount)
    -- Create stone walls around the level
    Stone.createWalls(level)
    
    -- Add random sand cells
    for i = 1, amount do
        local x = math.random(1, level.width - 2)
        local y = math.random(1, level.height - 3)
        
        if level:getCellType(x, y) == CellTypes.TYPES.EMPTY then
            level:setCellType(x, y, CellTypes.TYPES.SAND)
        end
    end
end

-- Create a level with water for testing fluid dynamics
function LevelGenerator.createWaterTestLevel(level)
    -- Create stone walls around the level
    Stone.createWalls(level)
    
    -- Create some stone obstacles
    Stone.createBlock(level, 30, level.height - 20, 10, 5)
    Stone.createBlock(level, 60, level.height - 30, 5, 15)
    Stone.createBlock(level, 90, level.height - 15, 15, 5)
    
    -- Add water pools
    Water.createPool(level, 20, level.height - 40, 40, 20)  -- Large pool at top
    Water.createPool(level, 80, level.height - 5, 30, 3)   -- Small pool at bottom
end

-- Create a level with mixed elements
function LevelGenerator.createMixedLevel(level)
    -- Create stone walls around the level
    Stone.createWalls(level)
    
    -- Create some stone platforms
    Stone.createPlatform(level, 20, level.height - 20, 30)
    Stone.createPlatform(level, 70, level.height - 30, 40)
    Stone.createPlatform(level, 40, level.height - 40, 20)
    
    -- Add sand piles
    Sand.createPile(level, 30, level.height - 21, 10, 10)
    Sand.createPile(level, 80, level.height - 31, 15, 15)
    
    -- Add water pools
    Water.createPool(level, 50, level.height - 5, 40, 4)
    Water.createPool(level, 90, level.height - 40, 20, 8)
end

return LevelGenerator
