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
function LevelGenerator.createProceduralLevel(level)
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
    createFewerTunnels(level)
    
    -- Add some stone structures
    addStoneStructures(level)
    
    -- Add occasional water ponds
    addWaterPonds(level)
    
    -- Add occasional sand traps
    addSandTraps(level)
    
    -- Create a goal area
    createGoalArea(level, goalX, goalY)
    
    -- Initialize grass on top of dirt cells
    level:initializeGrass()
    
    -- Final pass to remove any isolated dirt cells
    removeIsolatedDirtCells(level)
end

-- Create fewer tunnels and caves for a more dense terrain
function createFewerTunnels(level)
    -- Reduced number of tunnels
    local tunnelCount = math.random(2, 4) -- Reduced from 5-8
    
    for i = 1, tunnelCount do
        -- Start position for the tunnel
        local startX = math.random(5, level.width - 6)
        local startY = math.random(5, level.height - 6)
        
        -- Create a winding tunnel
        createWindingTunnel(level, startX, startY, 15, 30) -- Shorter tunnels
        
        -- Fewer branches
        local branchCount = math.random(1, 2) -- Reduced from 2-4
        for j = 1, branchCount do
            local branchX = math.random(5, level.width - 6)
            local branchY = math.random(5, level.height - 6)
            createWindingTunnel(level, branchX, branchY, 10, 20) -- Even shorter branches
        end
        
        -- Fewer caves
        local caveCount = math.random(1, 3) -- Reduced from 3-6
        for j = 1, caveCount do
            local caveX = math.random(10, level.width - 10)
            local caveY = math.random(10, level.height - 10)
            local caveRadius = math.random(4, 8) -- Slightly smaller caves
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
    -- Create a clear area around the goal
    createClearArea(level, goalX, goalY, 8)
    
    -- Add a win hole at the goal area
    local WinHole = require("src.win_hole")
    WinHole.createWinHoleArea(level, goalX - 3, goalY - 3, 7, 7) -- Create a diamond-shaped win hole
    
    -- Add a stone ring around the win hole for visibility
    for angle = 0, 360, 10 do
        local rad = math.rad(angle)
        local x = math.floor(goalX + math.cos(rad) * 6)
        local y = math.floor(goalY + math.sin(rad) * 6)
        
        if x > 1 and x < level.width - 2 and y > 1 and y < level.height - 3 then
            level:setCellType(x, y, CellTypes.TYPES.STONE)
        end
    end
end

-- Add some stone structures to the level
function addStoneStructures(level)
    local structureCount = math.random(3, 6)
    
    for i = 1, structureCount do
        local structureType = math.random(1, 3)
        local x = math.random(10, level.width - 20)
        local y = math.random(20, level.height - 20)
        
        if structureType == 1 then
            -- Stone block
            local width = math.random(3, 6)
            local height = math.random(3, 6)
            Stone.createBlock(level, x, y, width, height)
        elseif structureType == 2 then
            -- Stone platform
            local width = math.random(5, 12)
            Stone.createPlatform(level, x, y, width)
        else
            -- Stone pillar
            local height = math.random(4, 8)
            for py = y, y + height - 1 do
                if py >= 0 and py < level.height then
                    level:setCellType(x, py, CellTypes.TYPES.STONE)
                end
            end
        end
    end
end

-- Add occasional water ponds to the level
function addWaterPonds(level)
    local pondCount = math.random(2, 4)
    
    for i = 1, pondCount do
        local x = math.random(20, level.width - 30)
        local y = math.random(level.height - 30, level.height - 10)
        local width = math.random(10, 20)
        local height = math.random(3, 6)
        
        -- Create a water pond
        Water.createPool(level, x, y, width, height)
    end
end

-- Add occasional sand traps to the level
function addSandTraps(level)
    local trapCount = math.random(2, 5)
    
    for i = 1, trapCount do
        local x = math.random(20, level.width - 30)
        local y = math.random(level.height - 40, level.height - 10)
        local width = math.random(8, 15)
        local height = math.random(5, 15)
        
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
