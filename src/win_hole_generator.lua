-- win_hole_generator.lua - Functions for creating win holes

local CellTypes = require("src.cell_types")
local WinHole = require("src.win_hole")

local WinHoleGenerator = {}

-- Function to create a diamond-shaped win hole
function WinHoleGenerator.createDiamondWinHole(level, holeX, holeY, startX, startY)
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
    
    -- If no position is provided, choose a random position
    if not holeX or not holeY then
        -- Choose a random position from several possible locations
        local possibleLocations = {
            {x = level.width - 20, y = level.height - 20}, -- Bottom right
            {x = 20, y = level.height - 20},               -- Bottom left
            {x = level.width - 20, y = 20},                -- Top right
            {x = level.width / 2, y = 20},                 -- Top middle
            {x = level.width / 2, y = level.height - 20},  -- Bottom middle
            {x = 20, y = level.height / 2},                -- Left middle
            {x = level.width - 20, y = level.height / 2}   -- Right middle
        }
        
        -- Remove the top-left position (20, 20) as it's too close to the ball starting position
        -- And filter out any positions that are too close to the ball starting position
        local validLocations = {}
        for _, loc in ipairs(possibleLocations) do
            local distance = math.sqrt((loc.x - ballStartX)^2 + (loc.y - ballStartY)^2)
            if distance >= minDistanceFromBall then
                table.insert(validLocations, loc)
            end
        end
        
        -- Pick a random location from valid locations
        local randomIndex = math.random(1, #validLocations)
        holeX = math.floor(validLocations[randomIndex].x)
        holeY = math.floor(validLocations[randomIndex].y)
    else
        -- If position is provided, use it exactly as specified
        -- Log the position for debugging
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
    for y = holeY - 5, holeY + 5 do
        for x = holeX - 5, holeX + 5 do
            if x >= 0 and x < level.width and y >= 0 and y < level.height then
                level:setCellType(x, y, CellTypes.TYPES.EMPTY)
            end
        end
    end
    
    -- Create win holes based on the pattern
    local createdHoles = {}
    
    for dy = 0, 4 do
        for dx = 0, 4 do
            -- Only create a win hole if the pattern has a 1 at this position
            if pattern[dy + 1][dx + 1] == 1 then
                local cellX = holeX - 2 + dx
                local cellY = holeY - 2 + dy
                
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

return WinHoleGenerator
