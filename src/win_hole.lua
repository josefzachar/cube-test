-- win_hole.lua - Win hole implementation for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local WinHole = {}

-- Create a win hole at the specified position
function WinHole.createWinHole(level, x, y)
    -- Set the cell type to WIN_HOLE
    level:setCellType(x, y, CellTypes.TYPES.WIN_HOLE)
    
    -- Create physics for the win hole
    local cell = level.cells[y][x]
    WinHole.createPhysics(cell, level.world)
    
    -- Return the created cell
    return cell
end

-- Create a win hole physics body
function WinHole.createPhysics(cell, world)
    -- Create a static body for the win hole
    cell.body = love.physics.newBody(world, cell.x * Cell.SIZE + Cell.SIZE/2, cell.y * Cell.SIZE + Cell.SIZE/2, "static")
    
    -- Create a rectangle shape for the win hole
    cell.shape = love.physics.newRectangleShape(Cell.SIZE, Cell.SIZE)
    
    -- Create a fixture for the win hole
    cell.fixture = love.physics.newFixture(cell.body, cell.shape)
    
    -- Set the user data to identify this as a win hole
    cell.fixture:setUserData("win_hole")
    
    -- Set the category and mask for collision filtering
    cell.fixture:setCategory(2) -- Category 2 for cells
    cell.fixture:setMask(2)     -- Don't collide with other cells
    
    -- Make the win hole a sensor so it doesn't physically block the ball
    cell.fixture:setSensor(true)
end

-- Create a win hole area in a diamond shape
function WinHole.createWinHoleArea(level, x, y, size, _)
    -- Size should be odd to have a center point
    if size % 2 == 0 then
        size = size + 1
    end
    
    local radius = math.floor(size / 2)
    local centerX = x + radius
    local centerY = y + radius
    
    -- Create a diamond-shaped area of win holes
    for dy = -radius, radius do
        for dx = -radius, radius do
            -- Calculate Manhattan distance from center
            local distance = math.abs(dx) + math.abs(dy)
            
            -- If within the diamond radius, create a win hole
            if distance <= radius then
                local cellX = centerX + dx
                local cellY = centerY + dy
                
                -- Only create win holes within the level bounds
                if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
                    WinHole.createWinHole(level, cellX, cellY)
                end
            end
        end
    end
end

return WinHole
