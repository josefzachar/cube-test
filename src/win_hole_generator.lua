-- win_hole_generator.lua - Functions for creating win holes

local CellTypes = require("src.cell_types")
local WinHole = require("src.win_hole")

local WinHoleGenerator = {}

-- Function to create a diamond-shaped win hole
function WinHoleGenerator.createDiamondWinHole(level, holeX, holeY, startX, startY)
    -- Check if we're loading from a level file or creating a new level
    local loadingFromFile = false
    
    -- If holeX and holeY are provided and there's already a win hole at that position,
    -- we're likely loading from a level file and should skip clearing the area
    if holeX and holeY then
        -- Check if there's already a win hole at the specified position
        for dy = 0, 4 do
            for dx = 0, 4 do
                local pattern = {
                    {0, 0, 1, 0, 0},
                    {0, 1, 1, 1, 0},
                    {1, 1, 1, 1, 1},
                    {0, 1, 1, 1, 0},
                    {0, 0, 1, 0, 0}
                }
                
                if pattern[dy + 1][dx + 1] == 1 then
                    local cellX = holeX - 2 + dx
                    local cellY = holeY - 2 + dy
                    
                    if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
                        if level:getCellType(cellX, cellY) == CellTypes.TYPES.WIN_HOLE then
                            loadingFromFile = true
                            print("Win hole already exists at position, ensuring physics are created")
                            break
                        end
                    end
                end
            end
            if loadingFromFile then break end
        end
    end
    
    -- If we're loading from a file, ensure physics are created for existing win holes
    if loadingFromFile then
        -- Define the diamond pattern explicitly
        local pattern = {
            {0, 0, 1, 0, 0},
            {0, 1, 1, 1, 0},
            {1, 1, 1, 1, 1},
            {0, 1, 1, 1, 0},
            {0, 0, 1, 0, 0}
        }
        
        -- Create physics for existing win holes
        for dy = 0, 4 do
            for dx = 0, 4 do
                if pattern[dy + 1][dx + 1] == 1 then
                    local cellX = holeX - 2 + dx
                    local cellY = holeY - 2 + dy
                    
                    if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
                        if level:getCellType(cellX, cellY) == CellTypes.TYPES.WIN_HOLE then
                            -- Create physics for this win hole cell
                            local cell = level.cells[cellY][cellX]
                            if not cell.fixture then  -- Only create physics if not already created
                                WinHole.createPhysics(cell, level.world)
                                print("Created physics for existing win hole at", cellX, cellY)
                            end
                        end
                    end
                end
            end
        end
    else
        -- If we're not loading from a file, proceed with normal win hole creation
        -- First, scan the entire level and clear any existing win holes
        -- This ensures no win holes remain from previous level generations
        for y = 0, level.height - 1 do
            for x = 0, level.width - 1 do
                if level:getCellType(x, y) == CellTypes.TYPES.WIN_HOLE then
                    level:setCellType(x, y, CellTypes.TYPES.EMPTY)
                end
            end
        end
        
        -- Ball starting position (use provided values or default to 20, 20)
        local ballStartX = startX or 20
        local ballStartY = startY or 20
        local minDistanceFromBall = 10 -- Minimum distance from ball starting position
        
        -- If no position is provided, pick a random candidate far from the ball start
        if not holeX or not holeY then
            local margin = 18
            local all = {
                {x = margin,                  y = margin},
                {x = level.width  - margin,   y = margin},
                {x = margin,                  y = level.height - margin},
                {x = level.width  - margin,   y = level.height - margin},
                {x = math.floor(level.width  / 2), y = margin},
                {x = math.floor(level.width  / 2), y = level.height - margin},
                {x = margin,                  y = math.floor(level.height / 2)},
                {x = level.width  - margin,   y = math.floor(level.height / 2)},
            }
            -- Keep only candidates that are far enough from the ball start
            -- AND not directly below/above it (within 30 cells horizontally),
            -- to prevent the ball from falling straight in on spawn.
            local valid = {}
            for _, c in ipairs(all) do
                local dx = math.abs(c.x - ballStartX)
                local dy = math.abs(c.y - ballStartY)
                local d  = math.sqrt(dx * dx + dy * dy)
                local directlyAligned = (dx < 30)  -- same vertical column ± 30 cells
                if d >= 40 and not directlyAligned then
                    table.insert(valid, c)
                end
            end
            -- Relax the alignment constraint if nothing qualifies
            if #valid == 0 then
                for _, c in ipairs(all) do
                    local d = math.sqrt((c.x - ballStartX)^2 + (c.y - ballStartY)^2)
                    if d >= 40 then table.insert(valid, c) end
                end
            end
            if #valid == 0 then valid = all end  -- last-resort fallback
            local chosen = valid[math.random(1, #valid)]
            holeX = chosen.x
            holeY = chosen.y

            print("Win hole position: Random candidate (" .. holeX .. "," .. holeY .. ")")
            print("(ball start was " .. ballStartX .. "," .. ballStartY .. ")")
        else
            -- holeX/holeY were provided explicitly (loading from level file)
            print("Win hole position: Using exact position from level file (" .. holeX .. "," .. holeY .. ")")
        end
        
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
        
        -- Create a clear area around the win hole
        -- Make sure we're using the exact position from the level file
        local exactHoleX = holeX
        local exactHoleY = holeY
        
        for y = exactHoleY - 5, exactHoleY + 5 do
            for x = exactHoleX - 5, exactHoleX + 5 do
                if x >= 0 and x < level.width and y >= 0 and y < level.height then
                    level:setCellType(x, y, CellTypes.TYPES.EMPTY)
                end
            end
        end
        
        -- Create win holes based on the pattern
        local createdHoles = {}
        
        -- Use the exact position from the level file
        -- without any modifications or inversions
        for dy = 0, 4 do
            for dx = 0, 4 do
                -- Only create a win hole if the pattern has a 1 at this position
                if pattern[dy + 1][dx + 1] == 1 then
                    local cellX = exactHoleX - 2 + dx
                    local cellY = exactHoleY - 2 + dy
                    
                    -- Only create win holes within the level bounds
                    if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
                        WinHole.createWinHole(level, cellX, cellY)
                        table.insert(createdHoles, {x = cellX, y = cellY})
                    end
                end
            end
        end
    
        -- Check for isolated win holes and remove them
        for i = #createdHoles, 1, -1 do
            local hole = createdHoles[i]
            local hasAdjacent = false
            
            -- Check adjacent cells (up, down, left, right)
            local directions = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
            for _, dir in ipairs(directions) do
                local nx = hole.x + dir[1]
                local ny = hole.y + dir[2]
                
                -- Check if this adjacent cell is also a win hole
                if nx >= 0 and nx < level.width and ny >= 0 and ny < level.height then
                    if level:getCellType(nx, ny) == CellTypes.TYPES.WIN_HOLE then
                        hasAdjacent = true
                        break
                    end
                end
            end
            
            -- If this hole has no adjacent win holes, remove it
            if not hasAdjacent then
                level:setCellType(hole.x, hole.y, CellTypes.TYPES.EMPTY)
                table.remove(createdHoles, i)
            end
        end
    end
end

return WinHoleGenerator
