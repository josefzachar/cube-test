-- stone.lua - Stone cell behavior and utilities

local CellTypes = require("src.cell_types")
local STONE = CellTypes.TYPES.STONE

local Stone = {}

-- Create stone physics for a cell
function Stone.createPhysics(cell, world)
    -- Stone cells are static (immovable)
    cell.body = love.physics.newBody(world, cell.x * cell.SIZE + cell.SIZE/2, cell.y * cell.SIZE + cell.SIZE/2, "static")
    cell.shape = love.physics.newRectangleShape(cell.SIZE, cell.SIZE)
    cell.fixture = love.physics.newFixture(cell.body, cell.shape)
    
    -- Set user data
    cell.fixture:setUserData("stone")
end

-- Create a stone platform at the specified position
function Stone.createPlatform(level, x, y, width)
    for px = x, x + width - 1 do
        if px >= 0 and px < level.width and y >= 0 and y < level.height then
            level:setCellType(px, y, STONE)
        end
    end
end

-- Create a stone block at the specified position
function Stone.createBlock(level, x, y, width, height)
    for py = y, y + height - 1 do
        for px = x, x + width - 1 do
            if px >= 0 and px < level.width and py >= 0 and py < level.height then
                level:setCellType(px, py, STONE)
            end
        end
    end
end

-- Create stone walls around the level
function Stone.createWalls(level)
    -- Create ground
    for x = 0, level.width - 1 do
        level:setCellType(x, level.height - 1, STONE)
        level:setCellType(x, level.height - 2, STONE)
    end
    
    -- Create walls
    for y = 0, level.height - 1 do
        level:setCellType(0, y, STONE)
        level:setCellType(level.width - 1, y, STONE)
    end
    
    -- Create ceiling
    for x = 0, level.width - 1 do
        level:setCellType(x, 0, STONE)
    end
end

return Stone
