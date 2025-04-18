-- updater.lua - Cell update utilities

local CellTypes = require("src.cell_types")

local Updater = {}

-- Update all cells in the level
function Updater.updateCells(level, dt)
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
    
    -- Keep track of active cells for debug visualization
    level.debugActiveCells = {}
    for _, cell in ipairs(level.activeCells) do
        table.insert(level.debugActiveCells, {x = cell.x, y = cell.y, time = love.timer.getTime()})
    end
end

-- Update a row of cells from left to right
function Updater.updateRowLeftToRight(level, y, dt)
    local Cell = require("cell")
    
    for x = 0, level.width - 1 do
        if level.cells[y] and level.cells[y][x] then
            -- Update visual sand cells
            if level.cells[y][x].type == Cell.TYPES.VISUAL_SAND then
                level.cells[y][x]:update(dt, level)
            end
            
            -- Update sand cells - ALWAYS update ALL sand cells
            if level.cells[y][x].type == Cell.TYPES.SAND then
                local changed = level.cells[y][x]:update(dt, level)
                
                -- If the cell changed, mark it as active for next frame
                if changed then
                    table.insert(level.activeCells, {x = x, y = y})
                end
            end
            
            -- Update water cells - ALWAYS update ALL water cells
            if level.cells[y][x].type == Cell.TYPES.WATER then
                local changed = level.cells[y][x]:update(dt, level)
                
                -- If the cell changed, mark it as active for next frame
                if changed then
                    table.insert(level.activeCells, {x = x, y = y})
                end
            end
            
            -- Update dirt cells - ALWAYS update ALL dirt cells
            if level.cells[y][x].type == Cell.TYPES.DIRT then
                local changed = level.cells[y][x]:update(dt, level)
                
                -- If the cell changed, mark it as active for next frame
                if changed then
                    table.insert(level.activeCells, {x = x, y = y})
                end
            end
        end
    end
end

-- Update a row of cells from right to left
function Updater.updateRowRightToLeft(level, y, dt)
    local Cell = require("cell")
    
    for x = level.width - 1, 0, -1 do
        if level.cells[y] and level.cells[y][x] then
            -- Update visual sand cells
            if level.cells[y][x].type == Cell.TYPES.VISUAL_SAND then
                level.cells[y][x]:update(dt, level)
            end
            
            -- Update sand cells - ALWAYS update ALL sand cells
            if level.cells[y][x].type == Cell.TYPES.SAND then
                local changed = level.cells[y][x]:update(dt, level)
                
                -- If the cell changed, mark it as active for next frame
                if changed then
                    table.insert(level.activeCells, {x = x, y = y})
                end
            end
            
            -- Update water cells - ALWAYS update ALL water cells
            if level.cells[y][x].type == Cell.TYPES.WATER then
                local changed = level.cells[y][x]:update(dt, level)
                
                -- If the cell changed, mark it as active for next frame
                if changed then
                    table.insert(level.activeCells, {x = x, y = y})
                end
            end
        end
    end
end

-- Update visual sand cells
function Updater.updateVisualSand(level, dt)
    local i = 1
    while i <= #level.visualSandCells do
        local cell = level.visualSandCells[i]
        
        -- Update position based on velocity
        cell.visualX = cell.visualX + cell.velocityX * dt
        cell.visualY = cell.visualY + cell.velocityY * dt
        
        -- Apply gravity
        cell.velocityY = cell.velocityY + 500 * dt  -- Gravity
        
        -- Update lifetime and alpha
        cell.lifetime = (cell.lifetime or 0) + dt
        cell.alpha = math.max(0, 1 - (cell.lifetime / (cell.maxLifetime or 2.0)))
        
        -- Check if the visual sand should disappear
        if cell.lifetime >= (cell.maxLifetime or 2.0) or
           cell.visualX < 0 or cell.visualX >= level.width * cell.SIZE or 
           cell.visualY < 0 or cell.visualY >= level.height * cell.SIZE then
            -- Remove the visual sand
            table.remove(level.visualSandCells, i)
        else
            i = i + 1
        end
    end
end

-- Update active clusters
function Updater.updateActiveClusters(level, dt, ball)
    -- Reset all clusters to inactive
    local clusterRows = math.ceil(level.height / level.clusterSize)
    local clusterCols = math.ceil(level.width / level.clusterSize)
    
    for cy = 0, clusterRows - 1 do
        for cx = 0, clusterCols - 1 do
            level.clusters[cy][cx].active = false
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
                    -- Always activate clusters
                    level.clusters[cy][cx].active = true
                    
                    -- Store distance to ball for prioritization
                    local distX = cx - clusterX
                    local distY = cy - clusterY
                    level.clusters[cy][cx].distanceToBall = math.sqrt(distX * distX + distY * distY)
                end
            end
        end
    end
    
    -- Mark clusters as active based on recent changes
    for _, cell in ipairs(level.activeCells) do
        local clusterX = math.floor(cell.x / level.clusterSize)
        local clusterY = math.floor(cell.y / level.clusterSize)
        
        if clusterY >= 0 and clusterY < clusterRows and clusterX >= 0 and clusterX < clusterCols then
            level.clusters[clusterY][clusterX].active = true
            
            -- Also mark clusters below as active (for falling sand)
            if clusterY + 1 < clusterRows then
                level.clusters[clusterY + 1][clusterX].active = true
            end
        end
    end
    
    -- No cluster limiting needed
    
    -- Store active cells for debug visualization
    level.debugActiveCells = {}
    for _, cell in ipairs(level.activeCells) do
        table.insert(level.debugActiveCells, {x = cell.x, y = cell.y, time = love.timer.getTime()})
    end
    
    -- Clear active cells list for next frame
    level.activeCells = {}
end

return Updater
