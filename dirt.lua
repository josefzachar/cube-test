-- dirt.lua - Dirt cell behavior and utilities
print("Loading dirt.lua module from root directory")

local CellTypes = require("src.cell_types")
local DIRT = CellTypes.TYPES.DIRT
local EMPTY = CellTypes.TYPES.EMPTY
local WATER = CellTypes.TYPES.WATER

local Dirt = {}

-- Create a dirt block at the specified position
function Dirt.createBlock(level, x, y, width, height)
    for py = y, y + height - 1 do
        for px = x, x + width - 1 do
            if px >= 0 and px < level.width and py >= 0 and py < level.height then
                level:setCellType(px, py, DIRT)
            end
        end
    end
end

-- Create a dirt platform at the specified position
function Dirt.createPlatform(level, x, y, width)
    for px = x, x + width - 1 do
        if px >= 0 and px < level.width and y >= 0 and y < level.height then
            level:setCellType(px, y, DIRT)
        end
    end
end

-- Create dirt physics for a cell
function Dirt.createPhysics(cell, world)
    -- Dirt cells are static (immovable) like stone
    cell.body = love.physics.newBody(world, cell.x * cell.SIZE + cell.SIZE/2, cell.y * cell.SIZE + cell.SIZE/2, "static")
    cell.shape = love.physics.newRectangleShape(cell.SIZE, cell.SIZE)
    cell.fixture = love.physics.newFixture(cell.body, cell.shape)
    
    -- Set user data
    cell.fixture:setUserData("dirt")
    
    -- Make dirt less solid than stone but similar to sand
    cell.fixture:setFriction(0.3)
    cell.fixture:setRestitution(0.2)
end

-- Update dirt cell behavior
function Dirt.update(cell, dt, level)
    -- Cache level properties
    local levelHeight = level.height
    local levelWidth = level.width
    local x, y = cell.x, cell.y
    
    -- Early return if at bottom of level
    if y >= levelHeight - 1 then
        return false
    end
    
    -- Get cell types
    local belowType = level:getCellType(x, y + 1)
    
    -- Check if there's water below - dirt should displace water like sand
    if belowType == WATER then
        -- Swap positions - dirt sinks, water rises
        level:setCellType(x, y, WATER)
        level:setCellType(x, y + 1, DIRT)
        
        -- Mark cells as active for next frame
        local activeCells = level.activeCells
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x, y = y + 1})
        
        return true -- Cell changed
    end
    
    return false -- Dirt didn't move
end

print("About to return Dirt table:", Dirt)
return Dirt
