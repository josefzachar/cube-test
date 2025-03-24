-- water.lua - Water cell behavior and utilities

local CellTypes = require("src.cell_types")
local WATER = CellTypes.TYPES.WATER
local EMPTY = CellTypes.TYPES.EMPTY

local Water = {}

-- Add a pool of water at the specified position
function Water.createPool(level, x, y, width, height)
    -- Create a rectangular pool of water
    local startX = x - math.floor(width / 2)
    local endX = startX + width - 1
    local startY = y - math.floor(height / 2)
    local endY = startY + height - 1
    
    for py = startY, endY do
        for px = startX, endX do
            if px >= 0 and px < level.width and py >= 0 and py < level.height then
                level:setCellType(px, py, WATER)
            end
        end
    end
end

-- Create water physics for a cell
function Water.createPhysics(cell, world)
    -- Water cells are static but have special properties
    cell.body = love.physics.newBody(world, cell.x * cell.SIZE + cell.SIZE/2, cell.y * cell.SIZE + cell.SIZE/2, "static")
    cell.shape = love.physics.newRectangleShape(cell.SIZE, cell.SIZE)
    cell.fixture = love.physics.newFixture(cell.body, cell.shape)
    cell.fixture:setUserData("water")
    
    -- Make water very slippery with medium restitution
    cell.fixture:setFriction(0.05)
    cell.fixture:setRestitution(0.3)
    
    -- Set sensor to true so the ball can pass through but still detect collisions
    cell.fixture:setSensor(true)
end

-- Update water cell behavior
function Water.update(cell, dt, level)
    -- Cache level properties
    local levelHeight = level.height
    local levelWidth = level.width
    local x, y = cell.x, cell.y
    
    -- Early return if at bottom of level
    if y >= levelHeight - 1 then
        return false
    end
    
    -- Mark cells below as active
    if y < levelHeight - 2 then
        table.insert(level.activeCells, {x = x, y = y + 2})
    end
    
    -- Get cell types
    local belowType = level:getCellType(x, y + 1)
    
    -- Check if there's empty space below
    if belowType == EMPTY then
        -- Fall straight down
        level:setCellType(x, y, EMPTY)
        level:setCellType(x, y + 1, WATER)
        
        -- Mark cells as active for next frame
        local activeCells = level.activeCells
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x, y = y + 1})
        
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x, y = y + 2})
        end
        
        return true -- Cell changed
    end
    
    -- Check if we're at the edges
    local canCheckLeft = x > 0
    local canCheckRight = x < levelWidth - 1
    
    -- Get diagonal cell types
    local leftEmpty = canCheckLeft and level:getCellType(x - 1, y + 1) == EMPTY
    local rightEmpty = canCheckRight and level:getCellType(x + 1, y + 1) == EMPTY
    
    local activeCells = level.activeCells
    
    -- Water flows diagonally like sand
    if leftEmpty and rightEmpty then
        -- Both diagonal spaces are empty, choose randomly
        if math.random() < 0.5 then
            level:setCellType(x, y, EMPTY)
            level:setCellType(x - 1, y + 1, WATER)
            
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x - 1, y = y + 1})
            
            if y < levelHeight - 2 then
                table.insert(activeCells, {x = x - 1, y = y + 2})
            end
        else
            level:setCellType(x, y, EMPTY)
            level:setCellType(x + 1, y + 1, WATER)
            
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x + 1, y = y + 1})
            
            if y < levelHeight - 2 then
                table.insert(activeCells, {x = x + 1, y = y + 2})
            end
        end
        
        return true -- Cell changed
    elseif leftEmpty then
        level:setCellType(x, y, EMPTY)
        level:setCellType(x - 1, y + 1, WATER)
        
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x - 1, y = y + 1})
        
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x - 1, y = y + 2})
        end
        
        return true -- Cell changed
    elseif rightEmpty then
        level:setCellType(x, y, EMPTY)
        level:setCellType(x + 1, y + 1, WATER)
        
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x + 1, y = y + 1})
        
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x + 1, y = y + 2})
        end
        
        return true -- Cell changed
    end
    
    -- Water spreads horizontally more than sand
    -- Check left and right cells
    local leftType = canCheckLeft and level:getCellType(x - 1, y)
    local rightType = canCheckRight and level:getCellType(x + 1, y)
    
    -- Spread horizontally if possible
    if leftType == EMPTY and rightType == EMPTY then
        -- Both sides empty, choose randomly
        if math.random() < 0.5 then
            level:setCellType(x, y, EMPTY)
            level:setCellType(x - 1, y, WATER)
            
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x - 1, y = y})
        else
            level:setCellType(x, y, EMPTY)
            level:setCellType(x + 1, y, WATER)
            
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x + 1, y = y})
        end
        
        return true -- Cell changed
    elseif leftType == EMPTY then
        level:setCellType(x, y, EMPTY)
        level:setCellType(x - 1, y, WATER)
        
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x - 1, y = y})
        
        return true -- Cell changed
    elseif rightType == EMPTY then
        level:setCellType(x, y, EMPTY)
        level:setCellType(x + 1, y, WATER)
        
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x + 1, y = y})
        
        return true -- Cell changed
    end
    
    return false -- Water didn't move
end

return Water
