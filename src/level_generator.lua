-- level_generator.lua - Level generation utilities

local CellTypes = require("src.cell_types")
local Sand = require("src.sand")
local Water = require("src.water")
local Stone = require("src.stone")
-- Try loading Dirt module from root directory
print("About to require dirt module from root")
local status, result = pcall(function()
    local module = require("dirt")
    print("Module type:", type(module))
    return module
end)

if not status then
    print("Error loading dirt module:", result)
    Dirt = {}
else
    Dirt = result
end
print("Dirt module loaded:", Dirt, "type:", type(Dirt))

local LevelGenerator = {}

-- Create a procedural level with tunnels, dirt, stone, water ponds, and sand traps
-- difficulty: 1 = easy, 2 = medium, 3 = hard, 4 = expert, 5 = insane
function LevelGenerator.createProceduralLevel(level, difficulty)
    -- Default to difficulty 1 (easy) if not specified
    difficulty = difficulty or 1
    
    -- Clamp difficulty between 1 and 5
    difficulty = math.max(1, math.min(5, difficulty))
    
    -- Print the current difficulty level
    print("Creating level with difficulty:", difficulty)
    -- Create stone walls around the level
    Stone.createWalls(level)
    
    -- Define start and goal positions
    local startX, startY = 20, 20
    local goalX, goalY = level.width - 20, level.height - 20
    
    -- Create a dense dirt terrain that looks like a landscape
    createDirtPatches(level)
    
    -- Create a main path from start to goal (essential for gameplay)
    createMainPath(level, startX, startY, goalX, goalY)
    
    -- Create just a few additional tunnels (reduced for more dense terrain)
    createFewerTunnels(level, difficulty)
    
    -- Add some stone structures
    addStoneStructures(level, difficulty)
    
    -- Add occasional water ponds
    addWaterPonds(level, difficulty)
    
    -- Add occasional sand traps
    addSandTraps(level, difficulty)
    
    -- Create a goal area
    createGoalArea(level, goalX, goalY)
    
    -- Initialize grass on top of dirt cells
    level:initializeGrass()
    
    -- Final pass to remove any isolated dirt cells
    removeIsolatedDirtCells(level)
end

-- Create tunnels and caves with density based on difficulty
function createFewerTunnels(level, difficulty)
    -- Default to difficulty 1 if not provided
    difficulty = difficulty or 1
    
    -- Adjust tunnel count based on difficulty (fewer tunnels = harder)
    local minTunnels = math.max(1, 5 - difficulty) -- 4, 3, 2, 1, 1
    local maxTunnels = math.max(2, 7 - difficulty) -- 6, 5, 4, 3, 2
    local tunnelCount = math.random(minTunnels, maxTunnels)
    
    print("Creating", tunnelCount, "tunnels (difficulty:", difficulty, ")")
    
    for i = 1, tunnelCount do
        -- Start position for the tunnel
        local startX = math.random(5, level.width - 6)
        local startY = math.random(5, level.height - 6)
        
        -- Adjust tunnel length based on difficulty (shorter tunnels = harder)
        local minLength = math.max(10, 25 - (difficulty * 3)) -- 22, 19, 16, 13, 10
        local maxLength = math.max(15, 40 - (difficulty * 5)) -- 35, 30, 25, 20, 15
        
        -- Create a winding tunnel
        createWindingTunnel(level, startX, startY, minLength, maxLength)
        
        -- Adjust branch count based on difficulty (fewer branches = harder)
        local minBranches = math.max(0, 3 - difficulty) -- 2, 1, 0, 0, 0
        local maxBranches = math.max(1, 4 - difficulty) -- 3, 2, 1, 1, 1
        local branchCount = math.random(minBranches, maxBranches)
        
        for j = 1, branchCount do
            local branchX = math.random(5, level.width - 6)
            local branchY = math.random(5, level.height - 6)
            
            -- Shorter branches
            local branchMinLength = math.max(5, 15 - (difficulty * 2))
            local branchMaxLength = math.max(10, 25 - (difficulty * 3))
            
            createWindingTunnel(level, branchX, branchY, branchMinLength, branchMaxLength)
        end
        
        -- Adjust cave count based on difficulty (fewer caves = harder)
        local minCaves = math.max(0, 3 - difficulty) -- 2, 1, 0, 0, 0
        local maxCaves = math.max(1, 5 - difficulty) -- 4, 3, 2, 1, 1
        local caveCount = math.random(minCaves, maxCaves)
        
        for j = 1, caveCount do
            local caveX = math.random(10, level.width - 10)
            local caveY = math.random(10, level.height - 10)
            
            -- Adjust cave size based on difficulty (smaller caves = harder)
            local minRadius = math.max(2, 6 - difficulty) -- 5, 4, 3, 2, 2
            local maxRadius = math.max(4, 10 - difficulty) -- 9, 8, 7, 6, 5
            local caveRadius = math.random(minRadius, maxRadius)
            
            createClearArea(level, caveX, caveY, caveRadius)
        end
    end
end

-- Create a dense dirt terrain that looks like a landscape with grass
function createDirtPatches(level)
    -- First, create a base terrain layer that covers most of the level
    createBaseTerrain(level)
    
    -- Then add some terrain variations (hills and valleys)
    addTerrainVariations(level)
    
    -- Finally, remove any isolated single dirt cells
    removeIsolatedDirtCells(level)
end

-- Create a base terrain layer that covers most of the level
function createBaseTerrain(level)
    -- Create a continuous ground layer
    local groundHeight = math.floor(level.height * 0.7) -- Start ground at 70% of level height
    
    -- Fill everything below groundHeight with dirt
    for y = groundHeight, level.height - 3 do
        for x = 1, level.width - 2 do
            -- Skip if it's already a stone wall
            if level:getCellType(x, y) ~= CellTypes.TYPES.STONE then
                level:setCellType(x, y, CellTypes.TYPES.DIRT)
            end
        end
    end
    
    -- Create a more natural-looking top surface with some variations
    local surfaceVariation = 5 -- How much the surface can vary up and down
    
    -- Generate a smooth surface height array
    local surfaceHeight = {}
    surfaceHeight[1] = groundHeight
    
    -- Generate a smooth, continuous surface
    for x = 2, level.width - 2 do
        -- Gradually change the height for a smoother surface
        local change = math.random(-1, 1)
        surfaceHeight[x] = math.max(groundHeight - surfaceVariation, 
                           math.min(groundHeight + surfaceVariation, 
                           surfaceHeight[x-1] + change))
    end
    
    -- Apply the surface heights
    for x = 1, level.width - 2 do
        -- Fill everything from the surface height to the bottom with dirt
        for y = surfaceHeight[x], level.height - 3 do
            if level:getCellType(x, y) ~= CellTypes.TYPES.STONE then
                level:setCellType(x, y, CellTypes.TYPES.DIRT)
            end
        end
    end
end

-- Add terrain variations like hills and valleys
function addTerrainVariations(level)
    -- Add some hills (larger mounds of dirt)
    local hillCount = math.random(3, 6)
    for i = 1, hillCount do
        local hillX = math.random(20, level.width - 30)
        local hillY = math.random(level.height * 0.5, level.height * 0.7)
        local hillWidth = math.random(15, 30)
        local hillHeight = math.random(10, 20)
        
        -- Create a hill with a rounded top
        for y = hillY, hillY + hillHeight do
            local rowWidth = hillWidth * (1 - ((y - hillY) / hillHeight)^0.7)
            local startX = hillX - math.floor(rowWidth / 2)
            local endX = startX + rowWidth
            
            for x = startX, endX do
                if x > 1 and x < level.width - 2 and y > 1 and y < level.height - 3 then
                    level:setCellType(x, y, CellTypes.TYPES.DIRT)
                end
            end
        end
    end
    
    -- Add some plateaus (flat areas at different heights)
    local plateauCount = math.random(2, 4)
    for i = 1, plateauCount do
        local plateauX = math.random(20, level.width - 30)
        local plateauY = math.random(level.height * 0.5, level.height * 0.7)
        local plateauWidth = math.random(20, 40)
        local plateauHeight = math.random(5, 10)
        
        -- Create a plateau with steep sides
        for y = plateauY, plateauY + plateauHeight do
            for x = plateauX, plateauX + plateauWidth do
                if x > 1 and x < level.width - 2 and y > 1 and y < level.height - 3 then
                    level:setCellType(x, y, CellTypes.TYPES.DIRT)
                end
            end
        end
    end
end

-- Remove any isolated single dirt cells
function removeIsolatedDirtCells(level)
    for y = 1, level.height - 3 do
        for x = 1, level.width - 2 do
            if level:getCellType(x, y) == CellTypes.TYPES.DIRT then
                -- Count adjacent dirt cells
                local adjacentDirt = 0
                
                -- Check the 8 surrounding cells
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if not (dx == 0 and dy == 0) then -- Skip the center cell
                            local nx, ny = x + dx, y + dy
                            if nx >= 1 and nx < level.width - 1 and ny >= 1 and ny < level.height - 2 then
                                if level:getCellType(nx, ny) == CellTypes.TYPES.DIRT then
                                    adjacentDirt = adjacentDirt + 1
                                end
                            end
                        end
                    end
                end
                
                -- If this is an isolated dirt cell (no adjacent dirt cells), remove it
                if adjacentDirt == 0 then
                    level:setCellType(x, y, CellTypes.TYPES.EMPTY)
                end
            end
        end
    end
end

-- Create a main path from start to goal
function createMainPath(level, startX, startY, goalX, goalY)
    -- Create a path with several control points
    local points = {}
    table.insert(points, {x = startX, y = startY})
    
    -- Add 3-5 control points
    local controlPoints = math.random(3, 5)
    for i = 1, controlPoints do
        local x = math.random(20, level.width - 20)
        local y = math.random(20, level.height - 20)
        table.insert(points, {x = x, y = y})
    end
    
    table.insert(points, {x = goalX, y = goalY})
    
    -- Connect the points with tunnels
    for i = 1, #points - 1 do
        connectPoints(level, points[i].x, points[i].y, points[i+1].x, points[i+1].y)
    end
    
    -- Create a clear area around the start point
    createClearArea(level, startX, startY, 8)
end

-- Connect two points with a tunnel
function connectPoints(level, x1, y1, x2, y2)
    local steps = math.max(math.abs(x2 - x1), math.abs(y2 - y1)) * 2
    local tunnelWidth = math.random(3, 5)
    
    for i = 0, steps do
        local t = i / steps
        local x = math.floor(x1 + (x2 - x1) * t)
        local y = math.floor(y1 + (y2 - y1) * t)
        
        -- Add some randomness to the path
        if math.random() < 0.3 then
            x = x + math.random(-3, 3)
            y = y + math.random(-3, 3)
        end
        
        -- Carve out the tunnel (make cells empty)
        for w = -math.floor(tunnelWidth/2), math.floor(tunnelWidth/2) do
            for h = -math.floor(tunnelWidth/2), math.floor(tunnelWidth/2) do
                local tx = x + w
                local ty = y + h
                
                -- Make sure we're within bounds and not touching the walls
                if tx > 1 and tx < level.width - 2 and ty > 1 and ty < level.height - 3 then
                    level:setCellType(tx, ty, CellTypes.TYPES.EMPTY)
                end
            end
        end
    end
end

-- Create a clear area (empty cells) around a point
function createClearArea(level, centerX, centerY, radius)
    for y = centerY - radius, centerY + radius do
        for x = centerX - radius, centerX + radius do
            if x > 1 and x < level.width - 2 and y > 1 and y < level.height - 3 then
                -- Calculate distance from center
                local distance = math.sqrt((x - centerX)^2 + (y - centerY)^2)
                if distance <= radius then
                    level:setCellType(x, y, CellTypes.TYPES.EMPTY)
                end
            end
        end
    end
end

-- Create additional tunnels and caves
function createAdditionalTunnels(level)
    local tunnelCount = math.random(5, 8)
    
    for i = 1, tunnelCount do
        -- Start position for the tunnel
        local startX = math.random(5, level.width - 6)
        local startY = math.random(5, level.height - 6)
        
        -- Create a winding tunnel
        createWindingTunnel(level, startX, startY)
        
        -- Add some branches to the main tunnel
        local branchCount = math.random(2, 4)
        for j = 1, branchCount do
            local branchX = math.random(5, level.width - 6)
            local branchY = math.random(5, level.height - 6)
            createWindingTunnel(level, branchX, branchY, 15, 30) -- Shorter branches
        end
        
        -- Create some caves (larger open areas)
        local caveCount = math.random(3, 6)
        for j = 1, caveCount do
            local caveX = math.random(10, level.width - 10)
            local caveY = math.random(10, level.height - 10)
            local caveRadius = math.random(5, 10)
            createClearArea(level, caveX, caveY, caveRadius)
        end
    end
end

-- Create a winding tunnel starting from the given position
function createWindingTunnel(level, startX, startY, minLength, maxLength)
    -- Default values if not provided
    minLength = minLength or 30
    maxLength = maxLength or 60
    
    local length = math.random(minLength, maxLength)
    local x, y = startX, startY
    local tunnelWidth = math.random(3, 5) -- Width of the tunnel
    
    for i = 1, length do
        -- Carve out the tunnel (make cells empty)
        for w = -math.floor(tunnelWidth/2), math.floor(tunnelWidth/2) do
            for h = -math.floor(tunnelWidth/2), math.floor(tunnelWidth/2) do
                local tx = x + w
                local ty = y + h
                
                -- Make sure we're within bounds and not touching the walls
                if tx > 1 and tx < level.width - 2 and ty > 1 and ty < level.height - 3 then
                    level:setCellType(tx, ty, CellTypes.TYPES.EMPTY)
                end
            end
        end
        
        -- Randomly change direction
        if math.random() < 0.3 then
            local direction = math.random(1, 4)
            if direction == 1 and x > 10 then -- Left
                x = x - 1
            elseif direction == 2 and x < level.width - 10 then -- Right
                x = x + 1
            elseif direction == 3 and y > 10 then -- Up
                y = y - 1
            elseif direction == 4 and y < level.height - 10 then -- Down
                y = y + 1
            end
        else
            -- Continue in the current direction with a slight variation
            local dx = math.random(-1, 1)
            local dy = math.random(-1, 1)
            
            x = math.max(5, math.min(level.width - 6, x + dx))
            y = math.max(5, math.min(level.height - 6, y + dy))
        end
    end
end

-- Create a goal area (could be a hole or target)
function createGoalArea(level, goalX, goalY)
    -- Choose a random position for the win hole
    -- We'll pick from several possible locations to ensure variety
    local possibleLocations = {
        {x = goalX, y = goalY},                      -- Original goal position (bottom right)
        {x = 20, y = level.height - 20},             -- Bottom left
        {x = level.width - 20, y = 20},              -- Top right
        {x = level.width / 2, y = 20},               -- Top middle
        {x = 20, y = level.height / 2},              -- Left middle
        {x = level.width - 20, y = level.height / 2} -- Right middle
    }
    
    -- Pick a random location
    local randomIndex = math.random(1, #possibleLocations)
    local holeX = math.floor(possibleLocations[randomIndex].x)
    local holeY = math.floor(possibleLocations[randomIndex].y)
    
    -- Create a clear area around the win hole
    createClearArea(level, holeX, holeY, 10)
    
    -- Create a diamond-shaped win hole directly
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
    
    -- First, check if we can create a complete pattern
    local canCreateComplete = true
    for dy = 0, 4 do
        for dx = 0, 4 do
            if pattern[dy + 1][dx + 1] == 1 then
                local cellX = holeX - 2 + dx
                local cellY = holeY - 2 + dy
                
                if cellX < 0 or cellX >= level.width or cellY < 0 or cellY >= level.height then
                    canCreateComplete = false
                    break
                end
            end
        end
        if not canCreateComplete then
            break
        end
    end
    
    -- If we can't create a complete pattern, adjust the position
    if not canCreateComplete then
        holeX = math.max(5, math.min(level.width - 5, holeX))
        holeY = math.max(5, math.min(level.height - 5, holeY))
    end
    
    -- Create win holes based on the pattern
    local WinHole = require("src.win_hole")
    local createdHoles = {}
    
    for dy = 0, 4 do
        for dx = 0, 4 do
            -- Only create a win hole if the pattern has a 1 at this position
            if pattern[dy + 1][dx + 1] == 1 then
                local cellX = holeX - 2 + dx
                local cellY = holeY - 2 + dy
                
                -- Only create win holes within the level bounds
                if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
                    print("Creating win hole at", cellX, cellY)
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
            print("Removing isolated win hole at", hole.x, hole.y)
            table.remove(createdHoles, i)
        end
    end
    
    -- Add some visual indicators around the win hole (not stone)
    -- Create a pattern of empty cells around the win hole
    local radius = 12
    for angle = 0, 360, 30 do
        local rad = math.rad(angle)
        local x = math.floor(holeX + math.cos(rad) * radius)
        local y = math.floor(holeY + math.sin(rad) * radius)
        
        if x > 1 and x < level.width - 2 and y > 1 and y < level.height - 3 then
            -- Create a small empty area at each point
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local tx = x + dx
                    local ty = y + dy
                    if tx > 1 and tx < level.width - 2 and ty > 1 and ty < level.height - 3 then
                        level:setCellType(tx, ty, CellTypes.TYPES.EMPTY)
                    end
                end
            end
        end
    end
    
    -- Ensure there's a path from the start to the win hole
    connectPoints(level, 20, 20, holeX, holeY)
end

-- Add stone structures to the level based on difficulty
function addStoneStructures(level, difficulty)
    -- Default to difficulty 1 if not provided
    difficulty = difficulty or 1
    
    -- Adjust structure count based on difficulty (more structures = harder)
    local minStructures = math.min(6, 2 + difficulty) -- 3, 4, 5, 6, 7
    local maxStructures = math.min(10, 4 + difficulty) -- 5, 6, 7, 8, 9
    local structureCount = math.random(minStructures, maxStructures)
    
    print("Creating", structureCount, "stone structures (difficulty:", difficulty, ")")
    
    for i = 1, structureCount do
        local structureType = math.random(1, 3)
        
        -- Place structures more strategically at higher difficulties
        local x, y
        if difficulty <= 2 then
            -- Random placement for easy/medium
            x = math.random(10, level.width - 20)
            y = math.random(20, level.height - 20)
        else
            -- More strategic placement for harder difficulties
            -- Place structures along common paths
            if math.random() < 0.7 then
                -- Place near the middle of the level
                x = math.random(math.floor(level.width / 4), math.floor(3 * level.width / 4))
                y = math.random(math.floor(level.height / 4), math.floor(3 * level.height / 4))
            else
                -- Random placement
                x = math.random(10, level.width - 20)
                y = math.random(20, level.height - 20)
            end
        end
        
        -- Ensure x and y are within valid bounds
        x = math.max(10, math.min(level.width - 20, x))
        y = math.max(20, math.min(level.height - 20, y))
        
        if structureType == 1 then
            -- Stone block
            -- Adjust size based on difficulty (larger blocks = harder)
            local minWidth = math.min(8, 2 + difficulty) -- 3, 4, 5, 6, 7
            local maxWidth = math.min(12, 4 + difficulty) -- 5, 6, 7, 8, 9
            local width = math.random(minWidth, maxWidth)
            
            local minHeight = math.min(8, 2 + difficulty) -- 3, 4, 5, 6, 7
            local maxHeight = math.min(12, 4 + difficulty) -- 5, 6, 7, 8, 9
            local height = math.random(minHeight, maxHeight)
            
            Stone.createBlock(level, x, y, width, height)
        elseif structureType == 2 then
            -- Stone platform
            -- Adjust width based on difficulty (wider platforms = harder)
            local minWidth = math.min(15, 5 + difficulty * 2) -- 7, 9, 11, 13, 15
            local maxWidth = math.min(25, 10 + difficulty * 3) -- 13, 16, 19, 22, 25
            local width = math.random(minWidth, maxWidth)
            
            Stone.createPlatform(level, x, y, width)
        else
            -- Stone pillar
            -- Adjust height based on difficulty (taller pillars = harder)
            local minHeight = math.min(10, 3 + difficulty) -- 4, 5, 6, 7, 8
            local maxHeight = math.min(15, 6 + difficulty * 2) -- 8, 10, 12, 14, 16
            local height = math.random(minHeight, maxHeight)
            
            for py = y, y + height - 1 do
                if py >= 0 and py < level.height then
                    level:setCellType(x, py, CellTypes.TYPES.STONE)
                end
            end
        end
    end
end

-- Add water ponds to the level based on difficulty
function addWaterPonds(level, difficulty)
    -- Default to difficulty 1 if not provided
    difficulty = difficulty or 1
    
    -- Adjust pond count based on difficulty (more ponds = harder)
    local minPonds = math.min(5, 1 + difficulty) -- 2, 3, 4, 5, 6
    local maxPonds = math.min(8, 3 + difficulty) -- 4, 5, 6, 7, 8
    local pondCount = math.random(minPonds, maxPonds)
    
    print("Creating", pondCount, "water ponds (difficulty:", difficulty, ")")
    
    for i = 1, pondCount do
        -- Place ponds more strategically at higher difficulties
        local x, y
        if difficulty <= 2 then
            -- Random placement for easy/medium
            x = math.random(20, level.width - 30)
            y = math.random(level.height - 30, level.height - 10)
        else
            -- More strategic placement for harder difficulties
            if math.random() < 0.7 then
                -- Place along common paths
                x = math.random(math.floor(level.width / 4), math.floor(3 * level.width / 4))
                y = math.random(math.floor(level.height / 3), math.floor(2 * level.height / 3))
            else
                -- Random placement
                x = math.random(20, level.width - 30)
                y = math.random(level.height - 30, level.height - 10)
            end
        end
        
        -- Ensure x and y are within valid bounds
        x = math.max(20, math.min(level.width - 30, x))
        y = math.max(20, math.min(level.height - 10, y))
        
        -- Adjust size based on difficulty (larger ponds = harder)
        local minWidth = math.min(25, 10 + difficulty * 3) -- 13, 16, 19, 22, 25
        local maxWidth = math.min(35, 15 + difficulty * 4) -- 19, 23, 27, 31, 35
        local width = math.random(minWidth, maxWidth)
        
        -- Make sure width isn't too large for the level
        width = math.min(width, level.width - 40)
        
        local minHeight = math.min(10, 3 + difficulty) -- 4, 5, 6, 7, 8
        local maxHeight = math.min(15, 5 + difficulty * 2) -- 7, 9, 11, 13, 15
        local height = math.random(minHeight, maxHeight)
        
        -- Make sure height isn't too large for the level
        height = math.min(height, level.height - 20)
        
        -- Create a water pond
        Water.createPool(level, x, y, width, height)
    end
end

-- Add sand traps to the level based on difficulty
function addSandTraps(level, difficulty)
    -- Default to difficulty 1 if not provided
    difficulty = difficulty or 1
    
    -- Adjust trap count based on difficulty (more traps = harder)
    local minTraps = math.min(6, 2 + difficulty) -- 3, 4, 5, 6, 7
    local maxTraps = math.min(10, 4 + difficulty) -- 5, 6, 7, 8, 9
    local trapCount = math.random(minTraps, maxTraps)
    
    print("Creating", trapCount, "sand traps (difficulty:", difficulty, ")")
    
    for i = 1, trapCount do
        -- Place traps more strategically at higher difficulties
        local x, y
        if difficulty <= 2 then
            -- Random placement for easy/medium
            x = math.random(20, level.width - 30)
            y = math.random(level.height - 40, level.height - 10)
        else
            -- More strategic placement for harder difficulties
            if math.random() < 0.6 then
                -- Place along common paths
                x = math.random(math.floor(level.width / 4), math.floor(3 * level.width / 4))
                y = math.random(math.floor(level.height / 3), math.floor(2 * level.height / 3))
            else
                -- Random placement
                x = math.random(20, level.width - 30)
                y = math.random(level.height - 40, level.height - 10)
            end
        end
        
        -- Ensure x and y are within valid bounds
        x = math.max(20, math.min(level.width - 30, x))
        y = math.max(20, math.min(level.height - 10, y))
        
        -- Adjust size based on difficulty (larger traps = harder)
        local minWidth = math.min(20, 8 + difficulty * 2) -- 10, 12, 14, 16, 18
        local maxWidth = math.min(30, 15 + difficulty * 3) -- 18, 21, 24, 27, 30
        local width = math.random(minWidth, maxWidth)
        
        -- Make sure width isn't too large for the level
        width = math.min(width, level.width - 40)
        
        local minHeight = math.min(20, 5 + difficulty * 3) -- 8, 11, 14, 17, 20
        local maxHeight = math.min(30, 10 + difficulty * 4) -- 14, 18, 22, 26, 30
        local height = math.random(minHeight, maxHeight)
        
        -- Make sure height isn't too large for the level
        height = math.min(height, level.height - 20)
        
        -- Create a sand trap
        Sand.createPile(level, x, y, width, height)
    end
end

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
    
    -- Add dirt blocks
    print("Dirt type:", type(Dirt))
    if type(Dirt) == "table" then
        Dirt.createBlock(level, 100, level.height - 15, 8, 5)
        Dirt.createPlatform(level, 40, level.height - 40, 15)
    end
    
    -- Initialize grass on top of dirt cells
    level:initializeGrass()
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
    
    -- Initialize grass on top of dirt cells
    level:initializeGrass()
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
    
    -- Initialize grass on top of dirt cells
    level:initializeGrass()
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
    
    -- Add dirt blocks
    Dirt.createBlock(level, 110, level.height - 25, 10, 8)
    Dirt.createPlatform(level, 60, level.height - 50, 20)
    
    -- Initialize grass on top of dirt cells
    level:initializeGrass()
end

-- Create a level for testing dirt and water interaction
function LevelGenerator.createDirtWaterTestLevel(level)
    -- Create stone walls around the level
    Stone.createWalls(level)
    
    -- Create some stone platforms
    Stone.createPlatform(level, 30, level.height - 30, 20)
    Stone.createPlatform(level, 80, level.height - 40, 30)
    
    -- Add water pools
    Water.createPool(level, 40, level.height - 5, 80, 10)  -- Large pool at bottom
    Water.createPool(level, 60, level.height - 50, 40, 15) -- Pool at top
    
    -- Add dirt blocks above water to demonstrate sinking
    Dirt.createBlock(level, 50, level.height - 20, 10, 5)
    Dirt.createBlock(level, 70, level.height - 60, 15, 5)
    
    -- Add some dirt platforms
    Dirt.createPlatform(level, 100, level.height - 20, 25)
    Dirt.createPlatform(level, 20, level.height - 50, 15)
    
    -- Initialize grass on top of dirt cells
    level:initializeGrass()
end

return LevelGenerator
