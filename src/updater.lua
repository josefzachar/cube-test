-- updater.lua - Cell update utilities

local CellTypes = require("src.cell_types")
local Cell = require("cell")

local Updater = {}

-- Helper function to update a single cell and track changes
function Updater.updateCell(level, x, y, dt)
    local cell = level.cells[y][x]
    if cell.type ~= CellTypes.TYPES.EMPTY and cell.type ~= CellTypes.TYPES.STONE then
        local changed = cell:update(dt, level)
        if changed then
            table.insert(level.activeCells, {x = x, y = y})
        end
        return changed
    end
    return false
end

-- Update all cells in the level
function Updater.updateCells(level, dt)
    -- Track performance
    local sandWaterStart = love.timer.getTime()
    local sandWaterCellCount = 0
    
    -- Initialize movingSandWater if not present
    if not level.movingSandWater then
        level.movingSandWater = {}
    end
    
    local newMovingSandWater = {}
    
    -- Build set of sand/water cells to check
    local Cell = require("cell")
    local SAND = Cell.TYPES.SAND
    local WATER = Cell.TYPES.WATER
    local SPRAY_WATER = Cell.TYPES.SPRAY_WATER
    local EMPTY = Cell.TYPES.EMPTY
    
    local cellsToCheck = {}
    
    -- Add previously moving cells and their neighbors
    for key, _ in pairs(level.movingSandWater) do
        local x, y = key:match("(%d+),(%d+)")
        x, y = tonumber(x), tonumber(y)
        
        if x and y then
            -- Add this cell and neighbors (3x3 area)
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local nx, ny = x + dx, y + dy
                    if nx >= 0 and nx < level.width and ny >= 0 and ny < level.height then
                        local cellKey = nx .. "," .. ny
                        if not cellsToCheck[cellKey] then
                            if level.cells[ny] and level.cells[ny][nx] then
                                local cellType = level.cells[ny][nx].type
                                if cellType == SAND or cellType == WATER or cellType == SPRAY_WATER then
                                    cellsToCheck[cellKey] = {x = nx, y = ny}
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Also check sand/water near the ball (to wake up settled cells)
    if level.ball and level.ball.body then
        local ballX, ballY = level.ball.body:getPosition()
        local gridX, gridY = level:getGridCoordinates(ballX, ballY)
        local radius = 16  -- Check 16 cells around ball
        
        for dy = -radius, radius do
            for dx = -radius, radius do
                local nx, ny = gridX + dx, gridY + dy
                if nx >= 0 and nx < level.width and ny >= 0 and ny < level.height then
                    local cellKey = nx .. "," .. ny
                    if not cellsToCheck[cellKey] then
                        if level.cells[ny] and level.cells[ny][nx] then
                            local cellType = level.cells[ny][nx].type
                            if cellType == SAND or cellType == WATER or cellType == SPRAY_WATER then
                                cellsToCheck[cellKey] = {x = nx, y = ny}
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- CRITICAL: Always check sand/water that has empty space below (unsettled cells)
    -- This ensures materials fall even when ball is far away
    -- Only scan every 5 frames to reduce overhead
    if not level.unsettledScanFrame then
        level.unsettledScanFrame = 0
    end
    level.unsettledScanFrame = level.unsettledScanFrame + 1
    
    if level.unsettledScanFrame % 5 == 0 then
        for y = 0, level.height - 2 do  -- -2 because we check y+1
            for x = 0, level.width - 1 do
                if level.cells[y] and level.cells[y][x] and level.cells[y+1] and level.cells[y+1][x] then
                    local cellType = level.cells[y][x].type
                    if cellType == SAND or cellType == WATER or cellType == SPRAY_WATER then
                        local belowType = level.cells[y+1][x].type
                        -- If there's empty space or water below sand, cell needs to update
                        if belowType == EMPTY or (cellType == SAND and (belowType == WATER or belowType == SPRAY_WATER)) then
                            local cellKey = x .. "," .. y
                            if not cellsToCheck[cellKey] then
                                cellsToCheck[cellKey] = {x = x, y = y}
                                -- Also mark as moving so it continues next frame
                                newMovingSandWater[cellKey] = true
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Update only the cells we need to check (bottom to top for natural falling)
    local sortedCells = {}
    for key, cell in pairs(cellsToCheck) do
        table.insert(sortedCells, cell)
    end
    table.sort(sortedCells, function(a, b) return a.y > b.y end)
    
    for _, cell in ipairs(sortedCells) do
        local x, y = cell.x, cell.y
        if level.cells[y] and level.cells[y][x] then
            local changed = Updater.updateCell(level, x, y, dt)
            sandWaterCellCount = sandWaterCellCount + 1
            if changed then
                local key = x .. "," .. y
                newMovingSandWater[key] = true
            end
        end
    end
    
    -- Update movingSandWater for next frame
    level.movingSandWater = newMovingSandWater
    
    local sandWaterTime = love.timer.getTime() - sandWaterStart
    level.perfStats.sandWaterCellsCount = sandWaterCellCount
    
    -- Track other cells performance
    local otherCellsStart = love.timer.getTime()
    
    -- Then update other cell types only in active clusters
    -- Get active clusters
    local activeClusters = {}
    local clusterRows = math.ceil(level.height / level.clusterSize)
    local clusterCols = math.ceil(level.width / level.clusterSize)
    
    for cy = 0, clusterRows - 1 do
        for cx = 0, clusterCols - 1 do
            if level.clusters[cy] and level.clusters[cy][cx] and level.clusters[cy][cx].active then
                table.insert(activeClusters, {cx = cx, cy = cy})
            end
        end
    end
    
    -- If there are no active clusters, use the traditional update method
    if #activeClusters == 0 then
        -- Process from bottom to top for natural falling
        for y = level.height - 1, 0, -1 do
            -- Alternate direction each row for more natural movement
            if y % 2 == 0 then
                -- Process left to right
                Updater.updateRowLeftToRight(level, y, dt)
            else
                -- Process right to left
                Updater.updateRowRightToLeft(level, y, dt)
            end
        end
    else
        -- Use sparse matrix technique - only update cells in active clusters
        for _, cluster in ipairs(activeClusters) do
            local startX = cluster.cx * level.clusterSize
            local startY = cluster.cy * level.clusterSize
            local endX = math.min(startX + level.clusterSize - 1, level.width - 1)
            local endY = math.min(startY + level.clusterSize - 1, level.height - 1)
            
            -- Process from bottom to top for natural falling
            for y = endY, startY, -1 do
                -- Alternate direction for more natural movement
                if y % 2 == 0 then
                    -- Process left to right
                    for x = startX, endX do
                        if level.cells[y] and level.cells[y][x] then
                            local cellType = level.cells[y][x].type
                            -- Skip sand and water - already updated
                            if cellType ~= Cell.TYPES.SAND and cellType ~= Cell.TYPES.WATER then
                                Updater.updateCell(level, x, y, dt)
                            end
                        end
                    end
                else
                    -- Process right to left
                    for x = endX, startX, -1 do
                        if level.cells[y] and level.cells[y][x] then
                            local cellType = level.cells[y][x].type
                            -- Skip sand and water - already updated
                            if cellType ~= Cell.TYPES.SAND and cellType ~= Cell.TYPES.WATER then
                                Updater.updateCell(level, x, y, dt)
                            end
                        end
                    end
                end
            end
        end
    end
    
    local otherCellsTime = love.timer.getTime() - otherCellsStart
    
    -- Keep track of active cells for debug visualization
    level.debugActiveCells = {}
    for _, cell in ipairs(level.activeCells) do
        table.insert(level.debugActiveCells, {x = cell.x, y = cell.y, time = love.timer.getTime()})
    end
    
    -- Return timing info
    return sandWaterTime, otherCellsTime
end

-- Update a row of cells from left to right (only used when no active clusters)
function Updater.updateRowLeftToRight(level, y, dt)
    for x = 0, level.width - 1 do
        if level.cells[y] and level.cells[y][x] then
            Updater.updateCell(level, x, y, dt)
        end
    end
end

-- Update a row of cells from right to left (only used when no active clusters)
function Updater.updateRowRightToLeft(level, y, dt)
    for x = level.width - 1, 0, -1 do
        if level.cells[y] and level.cells[y][x] then
            Updater.updateCell(level, x, y, dt)
        end
    end
end

-- Try to place a sand grain back into the grid exactly at (gx, gy).
-- Only places if that cell is currently empty (no upward stacking that causes towers).
local function settleSandGrain(level, gx, gy, cellType)
    local CellTypes = require("src.cell_types")
    local realType = CellTypes.TYPES.SAND
    if cellType == CellTypes.TYPES.VISUAL_DIRT then
        realType = CellTypes.TYPES.DIRT
    end

    if gx < 0 or gx >= level.width or gy < 0 or gy >= level.height then
        return false
    end

    if level.cells[gy] and level.cells[gy][gx] then
        if level:getCellType(gx, gy) == CellTypes.TYPES.EMPTY then
            level:setCellType(gx, gy, realType)
            if level.movingSandWater then
                level.movingSandWater[gx .. "," .. gy] = true
            end
            return true
        end
    end
    return false
end

-- Update visual sand cells with optimized boundary checks
function Updater.updateVisualSand(level, dt)
    local levelWidth = level.width * Cell.SIZE
    local levelHeight = level.height * Cell.SIZE
    local gravity = 500
    local CellTypes = require("src.cell_types")

    local i = 1
    while i <= #level.visualSandCells do
        local cell = level.visualSandCells[i]
        local maxLifetime = cell.maxLifetime or 6.0

        -- Update position
        cell.visualX = cell.visualX + cell.velocityX * dt
        cell.visualY = cell.visualY + cell.velocityY * dt

        -- Apply gravity
        cell.velocityY = cell.velocityY + gravity * dt

        -- Fade alpha over lifetime
        cell.lifetime = (cell.lifetime or 0) + dt
        cell.alpha = math.max(0, 1 - (cell.lifetime / maxLifetime))

        -- Current grid position
        local gx = math.floor(cell.visualX / Cell.SIZE)
        local gy = math.floor(cell.visualY / Cell.SIZE)

        local outOfBounds = cell.visualX < 0 or cell.visualX >= levelWidth or
                            cell.visualY >= levelHeight

        local shouldSettle = false

        if not outOfBounds and cell.velocityY > 50 and cell.willSettle then
            -- Only settle when the grain is mostly falling vertically.
            -- Grains still flying sideways (freshly launched) will skip this
            -- and only get another chance once gravity has curved them downward.
            local spd = math.sqrt(cell.velocityX * cell.velocityX + cell.velocityY * cell.velocityY)
            local verticalFraction = (spd > 0) and (cell.velocityY / spd) or 0
            if verticalFraction < 0.7 then
                i = i + 1
                goto continueVisualSand
            end

            -- Determine type of the grain's current grid cell
            local ct = nil
            if gy >= 0 and gy < level.height and gx >= 0 and gx < level.width then
                local cur = level.cells[gy] and level.cells[gy][gx]
                ct = cur and level:getCellType(gx, gy)
            end

            local isSolid = ct ~= nil and
                            ct ~= CellTypes.TYPES.EMPTY and
                            ct ~= CellTypes.TYPES.WATER and
                            ct ~= CellTypes.TYPES.VISUAL_SAND and
                            ct ~= CellTypes.TYPES.VISUAL_DIRT

            if isSolid then
                -- Grain tunnelled into solid (fast movement) — back up one row
                local aboveY = gy - 1
                if aboveY >= 0 and aboveY < level.height then
                    local aboveCell = level.cells[aboveY] and level.cells[aboveY][gx]
                    local at = aboveCell and level:getCellType(gx, aboveY)
                    if at == CellTypes.TYPES.EMPTY then
                        shouldSettle = true
                        gy = aboveY -- settle one row above the solid
                    end
                end
            elseif ct == CellTypes.TYPES.EMPTY then
                -- Normal case: grain is in empty air, check one row below
                local belowY = gy + 1
                local belowSolid = false
                if belowY >= level.height then
                    belowSolid = true
                elseif belowY >= 0 and gx >= 0 and gx < level.width then
                    local belowCell = level.cells[belowY] and level.cells[belowY][gx]
                    local bt = belowCell and level:getCellType(gx, belowY)
                    belowSolid = bt ~= nil and
                                 bt ~= CellTypes.TYPES.EMPTY and
                                 bt ~= CellTypes.TYPES.WATER and
                                 bt ~= CellTypes.TYPES.VISUAL_SAND and
                                 bt ~= CellTypes.TYPES.VISUAL_DIRT
                end
                if belowSolid then
                    shouldSettle = true
                end
            end
        end

        -- Safety fallback: discard when lifetime expires (grain never found a surface)
        local shouldRemove = outOfBounds or (cell.lifetime >= maxLifetime)

        if shouldSettle then
            settleSandGrain(level, gx, gy, cell.type)
            shouldRemove = true
        end

        if shouldRemove then
            local lastIndex = #level.visualSandCells
            if i < lastIndex then
                level.visualSandCells[i] = level.visualSandCells[lastIndex]
                level.visualSandCells[lastIndex] = nil
            else
                level.visualSandCells[i] = nil
            end
        else
            i = i + 1
        end
        ::continueVisualSand::
    end
end

-- Update active clusters with adaptive runtime optimization
function Updater.updateActiveClusters(level, dt, ball)
    local Cell = require("cell")
    -- Reset all clusters to inactive
    local clusterRows = math.ceil(level.height / level.clusterSize)
    local clusterCols = math.ceil(level.width / level.clusterSize)
    
    -- Initialize cluster activity counts if not present
    if not level.clusterActivityCounts then
        level.clusterActivityCounts = {}
        for cy = 0, clusterRows - 1 do
            level.clusterActivityCounts[cy] = {}
            for cx = 0, clusterCols - 1 do
                level.clusterActivityCounts[cy][cx] = 0
            end
        end
    end
    
    -- Decay activity counts for all clusters (slower decay to keep them active longer)
    for cy = 0, clusterRows - 1 do
        for cx = 0, clusterCols - 1 do
            if level.clusterActivityCounts[cy] and level.clusterActivityCounts[cy][cx] then
                level.clusterActivityCounts[cy][cx] = level.clusterActivityCounts[cy][cx] * 0.95 -- Slower decay
            end
            
            -- Don't reset active state - we'll set it based on activity count
            if level.clusters[cy] and level.clusters[cy][cx] then
                level.clusters[cy][cx].active = false
            end
        end
    end
    
    -- Mark clusters as active based on ball position
    if ball and ball.body then
        local ballX, ballY = ball.body:getPosition()
        local gridX, gridY = level:getGridCoordinates(ballX, ballY)
        
        -- Mark clusters around the ball as active
        local clusterX = math.floor(gridX / level.clusterSize)
        local clusterY = math.floor(gridY / level.clusterSize)
        
        -- Determine the radius of active clusters
        local radius = 1 -- 3x3 grid
        
        for cy = clusterY - radius, clusterY + radius do
            for cx = clusterX - radius, clusterX + radius do
                if cy >= 0 and cy < clusterRows and cx >= 0 and cx < clusterCols then
                    -- Always activate clusters near the ball
                    if level.clusters[cy] and level.clusters[cy][cx] then
                        level.clusters[cy][cx].active = true
                    end
                    
                    -- Increase activity count for this cluster
                    if level.clusterActivityCounts[cy] and level.clusterActivityCounts[cy][cx] then
                        level.clusterActivityCounts[cy][cx] = level.clusterActivityCounts[cy][cx] + 5 -- Higher weight for ball proximity
                    end
                    
                    -- Store distance to ball for prioritization
                    if level.clusters[cy] and level.clusters[cy][cx] then
                        local distX = cx - clusterX
                        local distY = cy - clusterY
                        level.clusters[cy][cx].distanceToBall = math.sqrt(distX * distX + distY * distY)
                    end
                end
            end
        end
    end
    
    -- Mark clusters as active based on recent changes (only for dirt and non-sand/water materials)
    for _, cell in ipairs(level.activeCells) do
        local clusterX = math.floor(cell.x / level.clusterSize)
        local clusterY = math.floor(cell.y / level.clusterSize)
        
        if clusterY >= 0 and clusterY < clusterRows and clusterX >= 0 and clusterX < clusterCols then
            -- Activate this cluster
            if level.clusters[clusterY] and level.clusters[clusterY][clusterX] then
                level.clusters[clusterY][clusterX].active = true
            end
            
            -- Increase activity count for this cluster
            if level.clusterActivityCounts[clusterY] and level.clusterActivityCounts[clusterY][clusterX] then
                level.clusterActivityCounts[clusterY][clusterX] = level.clusterActivityCounts[clusterY][clusterX] + 1
            end
            
            -- Note: No longer activating clusters below since sand/water always update
        end
    end
    
    -- Activate clusters with any recent activity (very low threshold)
    local activityThreshold = 0.1 -- Very low threshold - activate on any recent activity
    for cy = 0, clusterRows - 1 do
        for cx = 0, clusterCols - 1 do
            if level.clusterActivityCounts[cy] and level.clusterActivityCounts[cy][cx] and 
               level.clusterActivityCounts[cy][cx] > activityThreshold then
                if level.clusters[cy] and level.clusters[cy][cx] then
                    level.clusters[cy][cx].active = true
                end
            end
        end
    end
    
    -- CRITICAL: Keep clusters active if they contain falling materials (checked AFTER activity-based activation)
    -- Only check clusters that aren't already active to avoid redundant work
    -- OPTIMIZATION: Don't scan ALL clusters every frame - only scan a batch per frame
    local SAND = Cell.TYPES.SAND
    local WATER = Cell.TYPES.WATER
    local EMPTY = Cell.TYPES.EMPTY
    
    -- Initialize scan position if not present
    if not level.clusterScanPosition then
        level.clusterScanPosition = 0
    end
    
    -- Only scan a small batch of clusters per frame (spread work across frames)
    local clustersPerFrame = 20  -- Scan 20 clusters per frame instead of all clusters
    local scannedCount = 0
    local startPos = level.clusterScanPosition
    
    for i = 0, clusterRows * clusterCols - 1 do
        if scannedCount >= clustersPerFrame then
            break
        end
        
        local idx = (startPos + i) % (clusterRows * clusterCols)
        local cy = math.floor(idx / clusterCols)
        local cx = idx % clusterCols
        
        -- Only scan if cluster is not already active
        if level.clusters[cy] and level.clusters[cy][cx] and not level.clusters[cy][cx].active then
            scannedCount = scannedCount + 1
            
            local startX = cx * level.clusterSize
            local startY = cy * level.clusterSize
            local endX = math.min(startX + level.clusterSize - 1, level.width - 1)
            local endY = math.min(startY + level.clusterSize - 1, level.height - 1)
            
            -- Quick scan for falling materials in this cluster
            local hasFallingMaterial = false
            for y = startY, endY do
                for x = startX, endX do
                    if level.cells[y] and level.cells[y][x] then
                        local cellType = level.cells[y][x].type
                        
                        if (cellType == SAND or cellType == WATER) and y < level.height - 1 then
                            local belowType = level.cells[y+1][x].type
                            -- Check if material can fall
                            if belowType == EMPTY or (cellType == SAND and belowType == WATER) then
                                hasFallingMaterial = true
                                break
                            end
                        end
                    end
                end
                if hasFallingMaterial then break end
            end
            
            if hasFallingMaterial then
                level.clusters[cy][cx].active = true
                -- Give it activity score so it stays active
                if level.clusterActivityCounts[cy] and level.clusterActivityCounts[cy][cx] then
                    level.clusterActivityCounts[cy][cx] = 1.0
                end
                -- Note: No longer activating clusters below since sand/water always update anyway
            end
        end
    end
    
    -- Update scan position for next frame
    level.clusterScanPosition = (startPos + clustersPerFrame) % (clusterRows * clusterCols)
    
    -- Store active cells for debug visualization
    level.debugActiveCells = {}
    for _, cell in ipairs(level.activeCells) do
        table.insert(level.debugActiveCells, {x = cell.x, y = cell.y, time = love.timer.getTime()})
    end
    
    -- Clear active cells list for next frame
    level.activeCells = {}
end

return Updater
