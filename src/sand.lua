-- sand.lua - Sand cell behavior and utilities

local CellTypes = require("src.cell_types")
local SAND = CellTypes.TYPES.SAND
local EMPTY = CellTypes.TYPES.EMPTY
local WATER = CellTypes.TYPES.WATER
local VISUAL_SAND = CellTypes.TYPES.VISUAL_SAND

local Sand = {}

-- Add a pile of sand at the specified position
function Sand.createPile(level, x, y, width, height)
    -- Create a triangular pile of sand
    for py = 0, height - 1 do
        local rowWidth = math.floor(width * (1 - py / height))
        local startX = x - math.floor(rowWidth / 2)
        local endX = startX + rowWidth - 1
        
        for px = startX, endX do
            if px >= 0 and px < level.width and y - py >= 0 and py < level.height then
                level:setCellType(px, y - py, SAND)
            end
        end
    end
end

-- Create sand physics for a cell
function Sand.createPhysics(cell, world)
    -- Sand cells are static but can be displaced
    cell.body = love.physics.newBody(world, cell.x * cell.SIZE + cell.SIZE/2, cell.y * cell.SIZE + cell.SIZE/2, "static")
    cell.shape = love.physics.newRectangleShape(cell.SIZE, cell.SIZE)
    cell.fixture = love.physics.newFixture(cell.body, cell.shape)
    cell.fixture:setUserData("sand")
    
    -- Make sand less solid than stone
    cell.fixture:setFriction(0.3)
    cell.fixture:setRestitution(0.2)
end

-- Update sand cell behavior
function Sand.update(cell, dt, level)
    -- Cache level properties
    local levelHeight = level.height
    local levelWidth = level.width
    local x, y = cell.x, cell.y
    
    -- Early return if at bottom of level
    if y >= levelHeight - 1 then
        return false
    end
    
    -- Mark cells below as active to ensure continuous falling
    if y < levelHeight - 2 then
        table.insert(level.activeCells, {x = x, y = y + 2})
    end
    
    -- Get cell types
    local belowType = level:getCellType(x, y + 1)
    
    -- Check if there's empty space below
    if belowType == EMPTY then
        -- Fall straight down
        level:setCellType(x, y, EMPTY)
        level:setCellType(x, y + 1, SAND)
        
        -- Mark cells as active for next frame
        local activeCells = level.activeCells
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x, y = y + 1})
        
        -- Mark cells below as active to ensure continuous falling
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x, y = y + 2})
        end
        
        return true -- Cell changed
    -- Check if there's water below - sand should sink in water
    elseif belowType == WATER then
        -- Swap positions - sand sinks, water rises
        level:setCellType(x, y, WATER)
        level:setCellType(x, y + 1, SAND)
        
        -- Mark cells as active for next frame
        local activeCells = level.activeCells
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x, y = y + 1})
        
        -- Mark cells below as active to ensure continuous falling
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x, y = y + 2})
        end
        
        return true -- Cell changed
    end
    
    -- Check if we're at the edges
    local canCheckLeft = x > 0
    local canCheckRight = x < levelWidth - 1
    
    -- Get diagonal cell types
    local leftType = canCheckLeft and level:getCellType(x - 1, y + 1)
    local rightType = canCheckRight and level:getCellType(x + 1, y + 1)
    
    local leftEmpty = leftType == EMPTY
    local rightEmpty = rightType == EMPTY
    
    local leftWater = leftType == WATER
    local rightWater = rightType == WATER
    
    local activeCells = level.activeCells
    
    -- Handle empty spaces diagonally
    if (leftEmpty and rightEmpty) or (leftEmpty and rightWater) or (leftWater and rightEmpty) or (leftWater and rightWater) then
        -- Both diagonal spaces are empty or water, choose randomly
        if math.random() < 0.5 then
            -- Fall diagonally left
            if leftEmpty then
                level:setCellType(x, y, EMPTY)
                level:setCellType(x - 1, y + 1, SAND)
            else -- leftWater
                level:setCellType(x, y, WATER)
                level:setCellType(x - 1, y + 1, SAND)
            end
            
            -- Mark cells as active for next frame
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x - 1, y = y + 1})
            
            -- Mark cells below as active to ensure continuous falling
            if y < levelHeight - 2 then
                table.insert(activeCells, {x = x - 1, y = y + 2})
            end
        else
            -- Fall diagonally right
            if rightEmpty then
                level:setCellType(x, y, EMPTY)
                level:setCellType(x + 1, y + 1, SAND)
            else -- rightWater
                level:setCellType(x, y, WATER)
                level:setCellType(x + 1, y + 1, SAND)
            end
            
            -- Mark cells as active for next frame
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x + 1, y = y + 1})
            
            -- Mark cells below as active to ensure continuous falling
            if y < levelHeight - 2 then
                table.insert(activeCells, {x = x + 1, y = y + 2})
            end
        end
        
        return true -- Cell changed
    elseif leftEmpty then
        -- Fall diagonally left
        level:setCellType(x, y, EMPTY)
        level:setCellType(x - 1, y + 1, SAND)
        
        -- Mark cells as active for next frame
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x - 1, y = y + 1})
        
        -- Mark cells below as active to ensure continuous falling
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x - 1, y = y + 2})
        end
        
        return true -- Cell changed
    elseif rightEmpty then
        -- Fall diagonally right
        level:setCellType(x, y, EMPTY)
        level:setCellType(x + 1, y + 1, SAND)
        
        -- Mark cells as active for next frame
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x + 1, y = y + 1})
        
        -- Mark cells below as active to ensure continuous falling
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x + 1, y = y + 2})
        end
        
        return true -- Cell changed
    elseif leftWater then
        -- Fall diagonally left through water
        level:setCellType(x, y, WATER)
        level:setCellType(x - 1, y + 1, SAND)
        
        -- Mark cells as active for next frame
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x - 1, y = y + 1})
        
        -- Mark cells below as active to ensure continuous falling
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x - 1, y = y + 2})
        end
        
        return true -- Cell changed
    elseif rightWater then
        -- Fall diagonally right through water
        level:setCellType(x, y, WATER)
        level:setCellType(x + 1, y + 1, SAND)
        
        -- Mark cells as active for next frame
        table.insert(activeCells, {x = x, y = y})
        table.insert(activeCells, {x = x + 1, y = y + 1})
        
        -- Mark cells below as active to ensure continuous falling
        if y < levelHeight - 2 then
            table.insert(activeCells, {x = x + 1, y = y + 2})
        end
        
        return true -- Cell changed
    end
    
    return false -- Sand didn't move
end

-- Convert a sand cell to visual flying sand with initial velocity
function Sand.convertToVisual(cell, velocityX, velocityY)
    -- Change type to VISUAL_SAND
    cell.type = VISUAL_SAND
    
    -- Set initial velocity
    cell.velocityX = velocityX
    cell.velocityY = velocityY
    
    -- Initialize visual position
    cell.visualX = cell.x * cell.SIZE
    cell.visualY = cell.y * cell.SIZE
    
    -- Reset lifetime
    cell.lifetime = 0
    cell.alpha = 1.0
end

-- Update visual sand behavior
function Sand.updateVisual(cell, dt, level)
    -- Update position based on velocity
    cell.visualX = cell.visualX + cell.velocityX * dt
    cell.visualY = cell.visualY + cell.velocityY * dt
    cell.velocityY = cell.velocityY + 500 * dt  -- Gravity
    
    -- Update lifetime and alpha
    cell.lifetime = cell.lifetime + dt
    cell.alpha = math.max(0, 1 - (cell.lifetime / cell.maxLifetime))
    
    -- Check if the visual sand should disappear
    if cell.lifetime >= cell.maxLifetime or
       cell.visualX < 0 or cell.visualX >= level.width * cell.SIZE or 
       cell.visualY < 0 or cell.visualY >= level.height * cell.SIZE then
        -- Remove the visual sand
        level:setCellType(cell.x, cell.y, EMPTY)
        return true -- Cell changed
    end
    
    return true -- Visual sand always changes (moves)
end

return Sand
