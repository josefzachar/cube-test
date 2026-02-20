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

-- Returns recommended (width, height) dimensions for a procedural level.
-- Rolls a shape preset first, then scales by difficulty.
function LevelGenerator.getProceduralDimensions(difficulty)
    difficulty = math.max(1, math.min(5, difficulty or 1))

    -- Weighted shape presets (cumulative probability out of 100)
    --   normal      55 %  – modestly varied rectangle
    --   long-narrow 25 %  – wide but short (scrolling corridor feel)
    --   tall-narrow 10 %  – tall but thin (vertical shaft feel)
    --   oversized   10 %  – extra large in both axes
    local roll = math.random(1, 100)
    local shape
    if     roll <= 55 then shape = "normal"
    elseif roll <= 80 then shape = "long"
    elseif roll <= 90 then shape = "tall"
    else                    shape = "big"
    end

    -- Difficulty scale nudges the base up slightly on harder levels
    local ds = difficulty * 0.06  -- 0.06 … 0.30 extra scaling factor

    local w, h
    if shape == "normal" then
        w = math.floor((150 + difficulty * 10) * (1 + ds * 0.5)) + math.random(-10, 10)
        h = math.floor(( 95 + difficulty *  6) * (1 + ds * 0.5)) + math.random(-6,   6)
    elseif shape == "long" then
        -- Wide and short – at least 2.5× aspect ratio
        w = math.floor((220 + difficulty * 14) * (1 + ds)) + math.random(-15, 15)
        h = math.floor(( 60 + difficulty *  4) * (1 + ds)) + math.random(-4,   4)
        h = math.max(h, 50)   -- never too thin to play
    elseif shape == "tall" then
        -- Tall and narrow – at least 2× aspect ratio the other way
        w = math.floor(( 65 + difficulty *  4) * (1 + ds)) + math.random(-5,   5)
        w = math.max(w, 55)
        h = math.floor((190 + difficulty * 12) * (1 + ds)) + math.random(-10, 10)
    else -- "big"
        w = math.floor((220 + difficulty * 18) * (1 + ds)) + math.random(-15, 15)
        h = math.floor((145 + difficulty * 12) * (1 + ds)) + math.random(-8,   8)
    end

    print("Level shape preset: " .. shape .. "  →  " .. w .. "x" .. h)
    return w, h
end

-- Create a procedural level with a randomly chosen archetype for variety.
-- difficulty: 1 = easy, 2 = medium, 3 = hard, 4 = expert, 5 = insane
function LevelGenerator.createProceduralLevel(level, difficulty, startX, startY)
    difficulty = math.max(1, math.min(5, difficulty or 1))

    -- Archetype selection is driven by the level's aspect ratio.
    -- Tall levels (height >> width) get dense archetypes so the ball has
    -- things to interact with while falling; wide/square levels stay open.
    local isTall = (level.height > level.width * 1.3)
    local roll = math.random(1, 100)
    local archetype
    if isTall then
        -- Dense archetypes only: underground 55%, cavern 45%
        if roll <= 55 then archetype = "underground"
        else               archetype = "cavern"
        end
    else
        -- Open archetypes dominate; cavy ones are rare
        if     roll <= 35 then archetype = "canyon"
        elseif roll <= 68 then archetype = "highlands"
        elseif roll <= 83 then archetype = "wetlands"
        elseif roll <= 92 then archetype = "cavern"
        else                   archetype = "underground"
        end
    end
    level.archetype = archetype
    print("Creating level | difficulty:", difficulty, "| archetype:", archetype, "| isTall:", isTall)

    -- Stone border walls
    Stone.createWalls(level)

    -- Start/goal reference points - use provided values or default corner
    startX = startX or 20
    startY = startY or 20
    -- Store on the level so game_init can read back the actual start used
    level._procStartX = startX
    level._procStartY = startY
    local goalX = level.width  - 20
    local goalY = level.height - 20

    -- Generate archetype-specific terrain
    if archetype == "canyon" then
        createCanyonTerrain(level, difficulty)
    elseif archetype == "cavern" then
        createCavernTerrain(level, difficulty)
    elseif archetype == "highlands" then
        createHighlandsTerrain(level, difficulty)
    elseif archetype == "underground" then
        createUndergroundTerrain(level, difficulty)
    elseif archetype == "wetlands" then
        createWetlandsTerrain(level, difficulty)
    else
        createHighlandsTerrain(level, difficulty)
    end

    -- Always carve a traversable main path (guarantees playability)
    createMainPath(level, startX, startY, goalX, goalY)

    -- Secondary exploration tunnels
    createFewerTunnels(level, difficulty)

    -- Stone obstacles (canyon already places its own)
    if archetype ~= "canyon" then
        addStoneStructures(level, difficulty)
    end

    -- Water (wetlands manages its own large water bodies)
    if archetype ~= "wetlands" then
        addWaterPonds(level, difficulty)
    end

    -- Sand traps
    addSandTraps(level, difficulty)

    -- Physics objects: boulders and explosive barrels
    addBoulders(level, difficulty)
    addBarrels(level, difficulty)

    -- Win-hole anchor point
    createGoalArea(level, goalX, goalY)

    -- Finalise terrain
    level:initializeGrass()
    level:activateFallingMaterialClusters()
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
    -- Ball starting position
    local ballStartX, ballStartY = 20, 20
    local minDistanceFromBall = 40 -- Minimum distance from ball starting position
    
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
    
    -- Remove any positions that are too close to the ball starting position
    local validLocations = {}
    for _, loc in ipairs(possibleLocations) do
        local distance = math.sqrt((loc.x - ballStartX)^2 + (loc.y - ballStartY)^2)
        if distance >= minDistanceFromBall then
            table.insert(validLocations, loc)
        end
    end
    
    -- If no valid locations, use the bottom right corner
    if #validLocations == 0 then
        validLocations = {{x = level.width - 20, y = level.height - 20}}
    end
    
    -- Pick a random location from valid locations
    local randomIndex = math.random(1, #validLocations)
    local holeX = math.floor(validLocations[randomIndex].x)
    local holeY = math.floor(validLocations[randomIndex].y)
    
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
                    WinHole.createWinHole(level, cellX, cellY)
                    table.insert(createdHoles, {x = cellX, y = cellY})
                end
            end
        end
    end
    
    -- Check for isolated win holes and remove them
    -- First, mark all holes that are part of a connected group
    local connected = {}
    local function markConnected(x, y)
        local key = x .. "," .. y
        if connected[key] then return end
        
        connected[key] = true
        
        -- Check adjacent cells (up, down, left, right)
        local directions = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
        for _, dir in ipairs(directions) do
            local nx = x + dir[1]
            local ny = y + dir[2]
            
            -- Check if this adjacent cell is also a win hole
            if nx >= 0 and nx < level.width and ny >= 0 and ny < level.height then
                if level:getCellType(nx, ny) == CellTypes.TYPES.WIN_HOLE then
                    markConnected(nx, ny)
                end
            end
        end
    end
    
    -- Start from the center hole and mark all connected holes
    markConnected(holeX, holeY)
    
    -- Remove any holes that aren't connected to the main group
    for i = #createdHoles, 1, -1 do
        local hole = createdHoles[i]
        local key = hole.x .. "," .. hole.y
        
        if not connected[key] then
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
    difficulty = difficulty or 1

    local minStructures = math.min(6, 2 + difficulty)
    local maxStructures = math.min(10, 4 + difficulty)
    local structureCount = math.random(minStructures, maxStructures)

    print("Creating", structureCount, "stone structures (difficulty:", difficulty, ")")

    for i = 1, structureCount do
        -- Placement
        local x, y
        if difficulty <= 2 or math.random() < 0.35 then
            x = math.random(10, level.width  - 20)
            y = math.random(20, level.height - 20)
        else
            x = math.random(math.floor(level.width  / 4), math.floor(3 * level.width  / 4))
            y = math.random(math.floor(level.height / 4), math.floor(3 * level.height / 4))
        end
        x = math.max(10, math.min(level.width  - 20, x))
        y = math.max(20, math.min(level.height - 20, y))

        local structureType = math.random(1, 4)

        if structureType == 1 then
            -- Rocky blob: an ellipse with per-column height jitter; fully solid interior
            local bw = math.random(4 + difficulty, 8 + difficulty)
            local bh = math.random(3 + difficulty, 6 + difficulty)
            for bx = -bw, bw do
                -- Jitter only the silhouette height of each column, interior is always filled
                local colJitter = math.random(-2, 2)
                local colH = math.max(0, math.floor(bh * math.sqrt(math.max(0, 1 - (bx / bw)^2)) + colJitter))
                for by = -colH, colH do
                    local px, py = x + bx, y + by
                    if px > 1 and px < level.width - 2 and py > 1 and py < level.height - 3 then
                        level:setCellType(px, py, CellTypes.TYPES.STONE)
                    end
                end
            end

        elseif structureType == 2 then
            -- Jagged ledge: a platform whose thickness varies column-by-column
            local width    = math.random(8 + difficulty * 2, 14 + difficulty * 3)
            local baseThick = math.random(2, 4)
            -- Generate a random-walk thickness profile
            local thick = {}
            thick[1] = baseThick
            for bx = 2, width do
                thick[bx] = math.max(1, math.min(6, thick[bx - 1] + math.random(-1, 1)))
            end
            for bx = 0, width - 1 do
                for by = 0, thick[bx + 1] - 1 do
                    local px, py = x + bx, y + by
                    if px > 1 and px < level.width - 2 and py > 1 and py < level.height - 3 then
                        level:setCellType(px, py, CellTypes.TYPES.STONE)
                    end
                end
            end

        elseif structureType == 3 then
            -- Craggy pillar: width oscillates as it rises
            local height   = math.random(5 + difficulty, 10 + difficulty * 2)
            local baseW    = math.random(2, 4)
            for by = 0, height - 1 do
                -- Width wiggles ±1 every few rows
                local w = math.max(1, baseW + math.floor(math.sin(by * 1.3) * 1.5) + math.random(-1, 1))
                local offset = math.random(0, 1)  -- slight horizontal drift
                for bx = offset, offset + w - 1 do
                    local px, py = x + bx, y - by
                    if px > 1 and px < level.width - 2 and py > 1 and py < level.height - 3 then
                        level:setCellType(px, py, CellTypes.TYPES.STONE)
                    end
                end
            end

        else
            -- Boulder cluster: 3-5 overlapping small blobs close together; solid circles
            local clusterR = math.random(3, 5 + difficulty)
            local blobCount = math.random(3, 5)
            for b = 1, blobCount do
                local bx = x + math.random(-clusterR, clusterR)
                local by = y + math.random(-clusterR, clusterR)
                local r  = math.random(2, 4)
                for dy = -r, r do
                    for dx = -r, r do
                        if dx * dx + dy * dy <= r * r then
                            local px, py = bx + dx, by + dy
                            if px > 1 and px < level.width - 2 and py > 1 and py < level.height - 3 then
                                level:setCellType(px, py, CellTypes.TYPES.STONE)
                            end
                        end
                    end
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
    
    -- Activate clusters with falling materials
    level:activateFallingMaterialClusters()
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
    
    -- Activate clusters with falling materials
    level:activateFallingMaterialClusters()
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
    
    -- Activate clusters with falling materials
    level:activateFallingMaterialClusters()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ARCHETYPE TERRAIN GENERATORS
-- Each function fills / carves the level differently to give distinct looks.
-- The main path is always carved afterwards, so playability is guaranteed.
-- ─────────────────────────────────────────────────────────────────────────────

-- Canyon: open upper air, uneven dirt floor with rocky outcroppings and
-- natural stone formations rising from the ground.
function createCanyonTerrain(level, difficulty)
    -- Base floor sits at ~80-88% height
    local baseFloor = math.floor(level.height * (0.80 + difficulty * 0.016))
    baseFloor = math.max(math.floor(level.height * 0.76), math.min(math.floor(level.height * 0.88), baseFloor))

    -- Generate a random-walk surface for the floor (bumpy, not flat)
    local surfaceY = {}
    surfaceY[1] = baseFloor
    for x = 2, level.width do
        local change = math.random(-2, 2)
        surfaceY[x] = math.max(baseFloor - 8, math.min(baseFloor + 6, surfaceY[x - 1] + change))
    end
    -- Smooth with a 3-wide box filter (3 passes)
    for pass = 1, 3 do
        for x = 2, level.width - 1 do
            surfaceY[x] = math.floor((surfaceY[x-1] + surfaceY[x] + surfaceY[x+1]) / 3)
        end
    end

    -- Fill from the surface down with dirt
    for x = 2, level.width - 3 do
        for y = surfaceY[x], level.height - 3 do
            if level:getCellType(x, y) ~= CellTypes.TYPES.STONE then
                level:setCellType(x, y, CellTypes.TYPES.DIRT)
            end
        end
    end

    -- Rocky outcroppings on the surface: small stone blobs sitting on top of the dirt
    local outcroppingCount = math.random(3, 5 + difficulty)
    for i = 1, outcroppingCount do
        local ox = math.random(12, level.width - 12)
        local oy = surfaceY[math.max(1, math.min(level.width, ox))]
        local bw = math.random(2, 5)
        local bh = math.random(2, 4)
        for bx = -bw, bw do
            -- Jitter per-column height for a natural silhouette; interior always solid
            local colJitter = math.random(-1, 1)
            local colH = math.max(0, math.floor(bh * math.sqrt(math.max(0, 1 - (bx / (bw + 0.01))^2)) + colJitter))
            for by = 0, colH do
                local px, py = ox + bx, oy - by
                if px > 1 and px < level.width - 2 and py > 1 and py < level.height - 3 then
                    level:setCellType(px, py, CellTypes.TYPES.STONE)
                end
            end
        end
    end

    -- Craggy stone formations rising from the floor (replace old rectangular pillars)
    local spacing = math.random(20, 32)
    local x = spacing
    while x < level.width - 15 do
        local formationType = math.random(1, 3)
        local groundY = surfaceY[math.max(1, math.min(level.width, x))]

        if formationType == 1 then
            -- Craggy pillar: width oscillates as it rises
            local height = math.random(
                math.floor(level.height * 0.06),
                math.floor(level.height * 0.20)
            )
            local baseW = math.random(2, 4)
            for by = 0, height do
                local w = math.max(1, baseW + math.floor(math.sin(by * 1.4) * 1.5) + math.random(-1, 1))
                local drift = math.floor(math.sin(by * 0.5) * 1.5)
                for bx = drift, drift + w - 1 do
                    local px, py = x + bx, groundY - by
                    if px > 1 and px < level.width - 2 and py > 1 and py < level.height - 3 then
                        level:setCellType(px, py, CellTypes.TYPES.STONE)
                    end
                end
            end

        elseif formationType == 2 then
            -- Boulder cluster on the floor; solid circles, no interior gaps
            local clusterR = math.random(3, 4)
            local blobCount = math.random(2, 4)
            for b = 1, blobCount do
                local bx = x + math.random(-clusterR, clusterR)
                local by_center = groundY - math.random(0, 2)
                local r = math.random(2, 3)
                for dy = -r, r do
                    for dx = -r, r do
                        if dx*dx + dy*dy <= r*r then
                            local px, py = bx + dx, by_center + dy
                            if px > 1 and px < level.width - 2 and py > 1 and py < level.height - 3 then
                                level:setCellType(px, py, CellTypes.TYPES.STONE)
                            end
                        end
                    end
                end
            end

        else
            -- Jagged ridge: a short ledge with varying thickness
            local width = math.random(5, 10)
            local baseThick = math.random(1, 3)
            local thick = {}
            thick[1] = baseThick
            for bx = 2, width do
                thick[bx] = math.max(1, math.min(5, thick[bx-1] + math.random(-1, 1)))
            end
            for bx = 0, width - 1 do
                for by = 0, thick[bx+1] - 1 do
                    local px, py = x + bx, groundY - by
                    if px > 1 and px < level.width - 2 and py > 1 and py < level.height - 3 then
                        level:setCellType(px, py, CellTypes.TYPES.STONE)
                    end
                end
            end
        end

        x = x + spacing + math.random(-6, 6)
    end

    -- A few floating stone platforms at varied heights
    local platformCount = math.min(5, 1 + difficulty)
    for i = 1, platformCount do
        local px = math.random(15, level.width - 25)
        local py = math.random(
            math.floor(level.height * 0.15),
            math.floor(level.height * 0.58)
        )
        -- Jagged floating ledge
        local width = math.random(5, 12)
        local thick = {}
        thick[1] = math.random(1, 2)
        for bx = 2, width do
            thick[bx] = math.max(1, math.min(3, thick[bx-1] + math.random(-1, 1)))
        end
        for bx = 0, width - 1 do
            for by = 0, thick[bx+1] - 1 do
                local fpx, fpy = px + bx, py + by
                if fpx > 1 and fpx < level.width - 2 and fpy > 1 and fpy < level.height - 3 then
                    level:setCellType(fpx, fpy, CellTypes.TYPES.STONE)
                end
            end
        end
    end
end

-- Cavern: entire level packed with dirt; large circular chambers are carved out
-- and connected by extra tunnels, creating an underground cave system.
function createCavernTerrain(level, difficulty)
    -- Fill with dirt
    for y = 2, level.height - 3 do
        for x = 2, level.width - 3 do
            if level:getCellType(x, y) ~= CellTypes.TYPES.STONE then
                level:setCellType(x, y, CellTypes.TYPES.DIRT)
            end
        end
    end

    -- Carve large chambers (generous radius ensures the ball can navigate)
    local chamberCount = math.random(6, 10)
    for i = 1, chamberCount do
        local cx = math.random(20, level.width  - 20)
        local cy = math.random(15, level.height - 15)
        createClearArea(level, cx, cy, math.random(10, 16))
    end

    -- Extra tunnel connections between arbitrary points
    for i = 1, math.random(4, 6) do
        connectPoints(level,
            math.random(15, level.width  - 15), math.random(15, level.height - 15),
            math.random(15, level.width  - 15), math.random(15, level.height - 15))
    end

    -- A few stone pillars inside open chambers for added challenge
    local pillarCount = math.max(0, difficulty - 1)
    for i = 1, pillarCount do
        local px = math.random(15, level.width  - 15)
        local py = math.random(15, level.height - 15)
        if level:getCellType(px, py) == CellTypes.TYPES.EMPTY then
            Stone.createBlock(level, px, py, math.random(2, 4), math.random(4, 8))
        end
    end
end

-- Highlands: noise-layered rolling terrain with exposed stone ridges on high
-- peaks. Uses two sine-wave octaves + a random-walk detail layer.
function createHighlandsTerrain(level, difficulty)
    -- Surface sits at ~78% of height – terrain covers only the bottom ~22%.
    local baseH = math.floor(level.height * 0.78)

    -- Random octave parameters – gentle amplitude keeps hills shallow
    local s1   = math.random(0, 628)
    local s2   = math.random(0, 628)
    local amp1 = math.floor(level.height * 0.07)  -- very gentle hills
    local amp2 = math.floor(level.height * 0.03)
    local f1   = 0.02 + math.random() * 0.02
    local f2   = 0.06 + math.random() * 0.04

    -- Random-walk detail (±3 cells for slight texture)
    local detail = {}
    detail[1] = 0
    for x = 2, level.width do
        detail[x] = math.max(-3, math.min(3, detail[x - 1] + math.random(-1, 1)))
    end

    local surfaceHeight = {}
    for x = 1, level.width do
        local h = baseH
            + math.floor(math.sin(x * f1 + s1 * 0.01) * amp1)
            + math.floor(math.sin(x * f2 + s2 * 0.01) * amp2)
            + detail[x]
        surfaceHeight[x] = math.max(
            math.floor(level.height * 0.58),  -- peaks never higher than 58% from top
            math.min(math.floor(level.height * 0.90), h)
        )
    end

    -- Smooth (3 passes of box filter)
    for pass = 1, 3 do
        for x = 2, level.width - 1 do
            surfaceHeight[x] = math.floor(
                (surfaceHeight[x - 1] + surfaceHeight[x] + surfaceHeight[x + 1]) / 3
            )
        end
    end

    -- Apply terrain
    for x = 2, level.width - 3 do
        local sh = surfaceHeight[x]
        for y = sh, level.height - 3 do
            if level:getCellType(x, y) ~= CellTypes.TYPES.STONE then
                level:setCellType(x, y, CellTypes.TYPES.DIRT)
            end
        end
        -- Exposed stone cap on very high peaks
        if sh < math.floor(level.height * 0.30) then
            for y = sh, math.min(sh + 4, level.height - 3) do
                if level:getCellType(x, y) == CellTypes.TYPES.DIRT then
                    level:setCellType(x, y, CellTypes.TYPES.STONE)
                end
            end
        end
    end
end

-- Underground: the entire level is solid dirt; wide horizontal corridors and
-- vertical shafts are carved to create a mine-like network. Always playable
-- because corridors are at least 7 cells tall.
function createUndergroundTerrain(level, difficulty)
    -- Fill with dirt
    for y = 2, level.height - 3 do
        for x = 2, level.width - 3 do
            if level:getCellType(x, y) ~= CellTypes.TYPES.STONE then
                level:setCellType(x, y, CellTypes.TYPES.DIRT)
            end
        end
    end

    -- Horizontal corridors spaced evenly.
    -- On tall levels add extra corridors so the ball has things to land on.
    local isTall = (level.height > level.width * 1.3)
    local corridorCount = isTall
        and math.min(12, 5 + math.floor(difficulty * 1.2))
        or  math.min(7,  3 + math.floor(difficulty * 0.8))
    for i = 1, corridorCount do
        local cy  = math.floor(level.height * (0.12 + (i / (corridorCount + 1)) * 0.76))
        cy = cy + math.random(-4, 4)
        cy = math.max(8, math.min(level.height - 8, cy))
        local halfH = 3  -- corridor is 7 cells tall (2*3+1)
        for y = cy - halfH, cy + halfH do
            for xc = 5, level.width - 5 do
                if y > 1 and y < level.height - 3 then
                    level:setCellType(xc, y, CellTypes.TYPES.EMPTY)
                end
            end
        end
    end

    -- Vertical shafts connecting corridors.
    -- Wider / more of them on tall levels so ball can pass through floors.
    local isTall2 = (level.height > level.width * 1.3)
    local shaftCount = isTall2
        and math.min(14, 7 + difficulty)
        or  math.min(10, 4 + difficulty)
    local shaftHalfW = isTall2 and math.random(3, 6) or math.random(2, 4)
    for i = 1, shaftCount do
        local sx = math.random(10, level.width - 10)
        for xc = sx, sx + shaftHalfW - 1 do
            for y = 5, level.height - 5 do
                if xc > 1 and xc < level.width - 2 then
                    level:setCellType(xc, y, CellTypes.TYPES.EMPTY)
                end
            end
        end
    end

    -- A few extra chambers at interesting intersections
    for i = 1, math.random(2, 4) do
        createClearArea(level,
            math.random(15, level.width  - 15),
            math.random(10, level.height - 10),
            math.random(6, 10))
    end
end

-- Wetlands: rolling upper terrain transitions into water-filled basins in the
-- lower half, with dirt islands bridging the basins.
function createWetlandsTerrain(level, difficulty)
    -- Surface sits at ~65% of height so the upper 65% is open air.
    local upperBaseH = math.floor(level.height * 0.60)
    local basinStart = math.floor(level.height * 0.68)

    -- Noise-based upper surface (gentle)
    local seed = math.random(0, 628)
    local amp  = math.floor(level.height * 0.07)
    local freq = 0.04 + math.random() * 0.03
    local surfaceHeight = {}
    for x = 1, level.width do
        local h = upperBaseH + math.floor(math.sin(x * freq + seed * 0.01) * amp) + math.random(-2, 2)
        surfaceHeight[x] = math.max(
            math.floor(level.height * 0.50),
            math.min(math.floor(level.height * 0.78), h)
        )
    end
    -- Smooth pass
    for pass = 1, 4 do
        for x = 2, level.width - 1 do
            surfaceHeight[x] = math.floor(
                (surfaceHeight[x - 1] + surfaceHeight[x] + surfaceHeight[x + 1]) / 3
            )
        end
    end

    -- Fill upper terrain with dirt below the surface line
    for x = 2, level.width - 3 do
        for y = surfaceHeight[x], level.height - 3 do
            if level:getCellType(x, y) ~= CellTypes.TYPES.STONE then
                level:setCellType(x, y, CellTypes.TYPES.DIRT)
            end
        end
    end

    -- Water basins in lower half
    local basinCount = math.min(8, 3 + difficulty)
    for i = 1, basinCount do
        local bx = math.random(8, level.width  - 25)
        local by = math.random(basinStart, level.height - 18)
        local bw = math.random(18, 38)
        local bh = math.random(7, 14)
        for y = by, by + bh do
            for xc = bx, bx + bw do
                if xc > 1 and xc < level.width - 2 and y > 1 and y < level.height - 3 then
                    level:setCellType(xc, y, CellTypes.TYPES.WATER)
                end
            end
        end
    end

    -- Dirt islands / ledges near the basin surface
    local islandCount = math.min(8, 3 + difficulty)
    for i = 1, islandCount do
        local ix = math.random(10, level.width  - 20)
        local iy = math.random(basinStart - 8, basinStart + 6)
        local iw = math.random(7, 15)
        local it = math.random(2, 4)
        for y = iy, iy + it do
            for xc = ix, ix + iw do
                if xc > 1 and xc < level.width - 2 and y > 1 and y < level.height - 3 then
                    level:setCellType(xc, y, CellTypes.TYPES.DIRT)
                end
            end
        end
    end

    -- A few tunnels in the upper portion for exploration
    createFewerTunnels(level, math.max(1, difficulty - 1))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PHYSICS-OBJECT SPAWNERS  (boulders & explosive barrels)
-- Both use level.world which is stored on the Level object by Level.new.
-- ─────────────────────────────────────────────────────────────────────────────

-- Spawn boulders into empty cells, scaling count with difficulty.
function addBoulders(level, difficulty)
    if not level.world then
        print("addBoulders: level.world is nil, skipping")
        return
    end
    if not level.boulders then level.boulders = {} end

    local Boulder   = require("src.boulder")
    local CELL_SIZE = 10

    -- Base: 1-2 at easy, 2-3 at medium, 3-4 at hard+
    local count = math.random(
        1 + math.floor(difficulty / 2),
        2 + math.floor(difficulty / 2)
    )
    -- Surge: 15% double, 5% triple
    local surge = math.random(1, 100)
    if     surge <= 5  then count = count * 3 ; print("Boulder TRIPLE surge!")
    elseif surge <= 20 then count = count * 2 ; print("Boulder DOUBLE surge!")
    end
    count = math.min(count, 10)  -- hard cap so the level doesn't get silly

    local placed, attempts = 0, 0
    while placed < count and attempts < 300 do
        attempts = attempts + 1
        local gx = math.random(10, level.width  - 10)
        local gy = math.random(8,  math.floor(level.height * 0.70))

        -- Only spawn in empty cells well away from the player start
        if level:getCellType(gx, gy) == CellTypes.TYPES.EMPTY then
            local distFromStart = math.sqrt((gx - 20)^2 + (gy - 20)^2)
            if distFromStart > 25 then
                local wx = gx * CELL_SIZE + CELL_SIZE / 2
                local wy = gy * CELL_SIZE + CELL_SIZE / 2
                local boulder = Boulder.new(level.world, wx, wy, 60)
                table.insert(level.boulders, boulder)
                placed = placed + 1
                print("Boulder placed at grid (" .. gx .. "," .. gy .. ")")
            end
        end
    end
    print("addBoulders: placed " .. placed .. " (tried " .. attempts .. ")")
end

-- Spawn explosive barrels into empty cells, scaling count with difficulty.
function addBarrels(level, difficulty)
    if not level.world then
        print("addBarrels: level.world is nil, skipping")
        return
    end
    if not level.barrels then level.barrels = {} end

    local Barrel    = require("src.barrel")
    local CELL_SIZE = 10

    -- Base: 1 at easy, up to 3 at hard+
    local count = math.random(1, 1 + math.floor(difficulty / 2))
    -- Surge: 15% double, 5% triple
    local surge = math.random(1, 100)
    if     surge <= 5  then count = count * 3 ; print("Barrel TRIPLE surge!")
    elseif surge <= 20 then count = count * 2 ; print("Barrel DOUBLE surge!")
    end
    count = math.min(count, 8)  -- hard cap

    local placed, attempts = 0, 0
    while placed < count and attempts < 300 do
        attempts = attempts + 1
        local gx = math.random(10, level.width  - 10)
        local gy = math.random(8,  math.floor(level.height * 0.80))

        if level:getCellType(gx, gy) == CellTypes.TYPES.EMPTY then
            local distFromStart = math.sqrt((gx - 20)^2 + (gy - 20)^2)
            if distFromStart > 30 then
                local wx = gx * CELL_SIZE + CELL_SIZE / 2
                local wy = gy * CELL_SIZE + CELL_SIZE / 2
                local barrel = Barrel.new(level.world, wx, wy)
                table.insert(level.barrels, barrel)
                placed = placed + 1
                print("Barrel placed at grid (" .. gx .. "," .. gy .. ")")
            end
        end
    end
    print("addBarrels: placed " .. placed .. " (tried " .. attempts .. ")")
end

return LevelGenerator
