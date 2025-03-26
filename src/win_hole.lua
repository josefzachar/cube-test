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
    
    print("Created win hole physics at", cell.x, cell.y, "with sensor =", cell.fixture:isSensor())
end

-- Create a diamond-shaped win hole
function WinHole.createWinHoleArea(level, x, y, _, _)
    -- Create a diamond shape using a 5x5 grid with corners removed
    -- The pattern is:
    --   X
    --  XXX
    -- XXXXX
    --  XXX
    --   X
    
    -- Define the diamond pattern explicitly
    local pattern = {
        {0, 0, 1, 0, 0},
        {0, 1, 1, 1, 0},
        {1, 1, 1, 1, 1},
        {0, 1, 1, 1, 0},
        {0, 0, 1, 0, 0}
    }
    
    -- Create win holes based on the pattern
    for dy = 0, 4 do
        for dx = 0, 4 do
            -- Only create a win hole if the pattern has a 1 at this position
            if pattern[dy + 1][dx + 1] == 1 then
                local cellX = x + dx
                local cellY = y + dy
                
                -- Only create win holes within the level bounds
                if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
                    print("Creating win hole at", cellX, cellY)
                    WinHole.createWinHole(level, cellX, cellY)
                end
            end
        end
    end
end

return WinHole
