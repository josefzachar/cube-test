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
                            Updater.updateCell(level, x, y, dt)
                        end
                    end
                else
                    -- Process right to left
                    for x = endX, startX, -1 do
                        if level.cells[y] and level.cells[y][x] then
                            Updater.updateCell(level, x, y, dt)
                        end
                    end
                end
            end
        end
    end
    
    -- Keep track of active cells for debug visualization
    level.debugActiveCells = {}
    for _, cell in ipairs(level.activeCells) do
        table.insert(level.debugActiveCells, {x = cell.x, y = cell.y, time = love.timer.getTime()})
    end
end

-- Update a row of cells from left to right
function Updater.updateRowLeftToRight(level, y, dt)
    for x = 0, level.width - 1 do
        if level.cells[y] and level.cells[y][x] then
            -- Get the cluster for this cell
            local clusterX = math.floor(x / level.clusterSize)
            local clusterY = math.floor(y / level.clusterSize)
            
            -- Only update cells in active clusters or visual sand cells
            local cellType = level.cells[y][x].type
            local isInActiveCluster = level.clusters[clusterY] and 
                                     level.clusters[clusterY][clusterX] and 
                                     level.clusters[clusterY][clusterX].active
            
            -- Always update visual sand cells regardless of cluster
            if cellType == Cell.TYPES.VISUAL_SAND or cellType == Cell.TYPES.VISUAL_DIRT then
                level.cells[y][x]:update(dt, level)
            -- Only update other cell types if they're in an active cluster
            elseif isInActiveCluster then
                if cellType == Cell.TYPES.SAND or cellType == Cell.TYPES.WATER or cellType == Cell.TYPES.DIRT then
                    local changed = level.cells[y][x]:update(dt, level)
                    
                    -- If the cell changed, mark it as active for next frame
                    if changed then
                        table.insert(level.activeCells, {x = x, y = y})
                    end
                end
            end
        end
    end
end

-- Update a row of cells from right to left
function Updater.updateRowRightToLeft(level, y, dt)
    for x = level.width - 1, 0, -1 do
        if level.cells[y] and level.cells[y][x] then
            -- Get the cluster for this cell
            local clusterX = math.floor(x / level.clusterSize)
            local clusterY = math.floor(y / level.clusterSize)
            
            -- Only update cells in active clusters or visual sand cells
            local cellType = level.cells[y][x].type
            local isInActiveCluster = level.clusters[clusterY] and 
                                     level.clusters[clusterY][clusterX] and 
                                     level.clusters[clusterY][clusterX].active
            
            -- Always update visual sand cells regardless of cluster
            if cellType == Cell.TYPES.VISUAL_SAND or cellType == Cell.TYPES.VISUAL_DIRT then
                level.cells[y][x]:update(dt, level)
            -- Only update other cell types if they're in an active cluster
            elseif isInActiveCluster then
                if cellType == Cell.TYPES.SAND or cellType == Cell.TYPES.WATER or cellType == Cell.TYPES.DIRT then
                    local changed = level.cells[y][x]:update(dt, level)
                    
                    -- If the cell changed, mark it as active for next frame
                    if changed then
                        table.insert(level.activeCells, {x = x, y = y})
                    end
                end
            end
        end
    end
end

-- Update visual sand cells with optimized boundary checks
function Updater.updateVisualSand(level, dt)
    -- Cache level boundaries for faster access
    local levelWidth = level.width * Cell.SIZE
    local levelHeight = level.height * Cell.SIZE
    local gravity = 500 -- Gravity constant
    
    local i = 1
    while i <= #level.visualSandCells do
        local cell = level.visualSandCells[i]
        local maxLifetime = cell.maxLifetime or 2.0
        
        -- Update position based on velocity
        cell.visualX = cell.visualX + cell.velocityX * dt
        cell.visualY = cell.visualY + cell.velocityY * dt
        
        -- Apply gravity
        cell.velocityY = cell.velocityY + gravity * dt
        
        -- Update lifetime and alpha
        cell.lifetime = (cell.lifetime or 0) + dt
        cell.alpha = math.max(0, 1 - (cell.lifetime / maxLifetime))
        
        -- Fast check for lifetime first (most common reason for removal)
        local shouldRemove = cell.lifetime >= maxLifetime
        
        -- Only check boundaries if lifetime hasn't expired yet
        if not shouldRemove then
            -- Combine boundary checks into a single condition
            shouldRemove = cell.visualX < 0 or cell.visualX >= levelWidth or 
                           cell.visualY < 0 or cell.visualY >= levelHeight
        end
        
        if shouldRemove then
            -- Remove the visual sand - use fast removal by swapping with the last element
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
    
    -- Decay activity counts for all clusters
    for cy = 0, clusterRows - 1 do
        for cx = 0, clusterCols - 1 do
            if level.clusterActivityCounts[cy] and level.clusterActivityCounts[cy][cx] then
                level.clusterActivityCounts[cy][cx] = level.clusterActivityCounts[cy][cx] * 0.9 -- Decay factor
            end
            
            -- Reset active state
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
    
    -- Mark clusters as active based on recent changes
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
            
            -- Also mark clusters below as active (for falling sand)
            if clusterY + 1 < clusterRows then
                if level.clusters[clusterY + 1] and level.clusters[clusterY + 1][clusterX] then
                    level.clusters[clusterY + 1][clusterX].active = true
                end
                
                -- Increase activity count for the cluster below
                if level.clusterActivityCounts[clusterY + 1] and level.clusterActivityCounts[clusterY + 1][clusterX] then
                    level.clusterActivityCounts[clusterY + 1][clusterX] = level.clusterActivityCounts[clusterY + 1][clusterX] + 0.5 -- Lower weight for clusters below
                end
            end
        end
    end
    
    -- NEW: Check for sand and water cells that should be moving
    -- This ensures cells don't freeze in mid-air when not near the ball
    for y = 0, level.height - 1 do
        for x = 0, level.width - 1 do
            if level.cells[y] and level.cells[y][x] then
                local cellType = level.cells[y][x].type
                
                -- Check if this is a sand or water cell
                if cellType == Cell.TYPES.SAND or cellType == Cell.TYPES.WATER then
                    -- Check if there's empty space or water below (for sand)
                    local shouldActivate = false
                    
                    -- Check below
                    if y < level.height - 1 then
                        local belowType = level.cells[y+1][x].type
                        if belowType == Cell.TYPES.EMPTY or 
                           (cellType == Cell.TYPES.SAND and belowType == Cell.TYPES.WATER) then
                            shouldActivate = true
                        end
                    end
                    
                    -- Check diagonally below
                    if not shouldActivate and y < level.height - 1 then
                        -- Check left diagonal
                        if x > 0 then
                            local diagLeftType = level.cells[y+1][x-1].type
                            if diagLeftType == Cell.TYPES.EMPTY or 
                               (cellType == Cell.TYPES.SAND and diagLeftType == Cell.TYPES.WATER) then
                                shouldActivate = true
                            end
                        end
                        
                        -- Check right diagonal
                        if x < level.width - 1 then
                            local diagRightType = level.cells[y+1][x+1].type
                            if diagRightType == Cell.TYPES.EMPTY or 
                               (cellType == Cell.TYPES.SAND and diagRightType == Cell.TYPES.WATER) then
                                shouldActivate = true
                            end
                        end
                    end
                    
                    -- For water, also check horizontally
                    if not shouldActivate and cellType == Cell.TYPES.WATER then
                        -- Check left
                        if x > 0 and level.cells[y][x-1].type == Cell.TYPES.EMPTY then
                            shouldActivate = true
                        end
                        
                        -- Check right
                        if x < level.width - 1 and level.cells[y][x+1].type == Cell.TYPES.EMPTY then
                            shouldActivate = true
                        end
                    end
                    
                    -- If this cell should be moving, activate its cluster
                    if shouldActivate then
                        local clusterX = math.floor(x / level.clusterSize)
                        local clusterY = math.floor(y / level.clusterSize)
                        
                        if clusterY >= 0 and clusterY < clusterRows and 
                           clusterX >= 0 and clusterX < clusterCols then
                            level.clusters[clusterY][clusterX].active = true
                            
                            -- Also mark the cluster below as active
                            if clusterY + 1 < clusterRows then
                                level.clusters[clusterY + 1][clusterX].active = true
                            end
                            
                            -- Add this cell to active cells for next frame
                            table.insert(level.activeCells, {x = x, y = y})
                        end
                    end
                end
            end
        end
    end
    
    -- Also activate clusters with high activity counts (from optimization commit)
    local activityThreshold = 0.5 -- Threshold for activation based on activity
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
    
    -- Store active cells for debug visualization
    level.debugActiveCells = {}
    for _, cell in ipairs(level.activeCells) do
        table.insert(level.debugActiveCells, {x = cell.x, y = cell.y, time = love.timer.getTime()})
    end
    
    -- Clear active cells list for next frame
    level.activeCells = {}
end

return Updater
