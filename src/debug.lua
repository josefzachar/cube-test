-- debug.lua - Debug functionality for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local Debug = {}

-- Colors
local WHITE = {1, 1, 1, 1}

-- Debug variables
Debug.showActiveCells = false
Debug.vsyncEnabled = false -- Start with VSync disabled (as set in conf.lua)

function Debug.drawDebugInfo(level, ball, attempts, debug)
    if not debug then return end
    
    love.graphics.setColor(1, 0, 0, 1)
    
    -- FPS
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Cell counts (only update every 10 frames to improve performance)
    if not level.cellCounts or love.timer.getTime() - (level.lastCountTime or 0) > 0.5 then
        level.cellCounts = level.cellCounts or {}
        level.cellCounts.sandCount = 0
        level.cellCounts.stoneCount = 0
        level.cellCounts.tempStoneCount = 0
        level.cellCounts.emptyCount = 0
        level.cellCounts.visualSandCount = 0
        
        -- Only count cells in visible area
        local screenWidth, screenHeight = love.graphics.getDimensions()
        local margin = 10
        local minX = math.max(0, math.floor(0 / CellTypes.SIZE) - margin)
        local maxX = math.min(level.width - 1, math.ceil(screenWidth / CellTypes.SIZE) + margin)
        local minY = math.max(0, math.floor(0 / CellTypes.SIZE) - margin)
        local maxY = math.min(level.height - 1, math.ceil(screenHeight / CellTypes.SIZE) + margin)
        
        -- Count cells by type (only in visible area)
        level.cellCounts.dirtCount = 0
        level.cellCounts.waterCount = 0
        
        for y = minY, maxY do
            for x = minX, maxX do
                local cellType = level:getCellType(x, y)
                if cellType == CellTypes.TYPES.SAND then
                    level.cellCounts.sandCount = level.cellCounts.sandCount + 1
                elseif cellType == CellTypes.TYPES.STONE then
                    level.cellCounts.stoneCount = level.cellCounts.stoneCount + 1
                elseif cellType == CellTypes.TYPES.EMPTY then
                    level.cellCounts.emptyCount = level.cellCounts.emptyCount + 1
                elseif cellType == CellTypes.TYPES.VISUAL_SAND then
                    level.cellCounts.visualSandCount = level.cellCounts.visualSandCount + 1
                elseif cellType == CellTypes.TYPES.DIRT then
                    level.cellCounts.dirtCount = level.cellCounts.dirtCount + 1
                elseif cellType == CellTypes.TYPES.WATER then
                    level.cellCounts.waterCount = level.cellCounts.waterCount + 1
                end
            end
        end
        
        -- Add visual sand particles count
        level.cellCounts.visualSandCount = level.cellCounts.visualSandCount + #(level.visualSandCells or {})
        level.lastCountTime = love.timer.getTime()
    end
    
    -- Use cached cell counts
    local sandCount = level.cellCounts.sandCount
    local stoneCount = level.cellCounts.stoneCount
    local emptyCount = level.cellCounts.emptyCount
    local visualSandCount = level.cellCounts.visualSandCount
    local dirtCount = level.cellCounts.dirtCount or 0
    local waterCount = level.cellCounts.waterCount or 0
    
    -- Display cell counts
    love.graphics.print("Sand: " .. sandCount, 10, 30)
    love.graphics.print("Stone: " .. stoneCount, 10, 50)
    love.graphics.print("Dirt: " .. dirtCount, 10, 70)
    love.graphics.print("Water: " .. waterCount, 10, 90)
    love.graphics.print("Empty: " .. emptyCount, 10, 110)
    love.graphics.print("Visual Sand: " .. visualSandCount, 10, 130)
    
    -- Display ball info
    if ball.body then
        local x, y = ball.body:getPosition()
        local vx, vy = ball.body:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        love.graphics.print(string.format("Ball: x=%.1f, y=%.1f", x, y), 10, 150)
        love.graphics.print(string.format("Velocity: vx=%.1f, vy=%.1f", vx, vy), 10, 170)
        love.graphics.print(string.format("Speed: %.1f", speed), 10, 190)
    end
    
    -- Display optimization info
    love.graphics.print("Performance Optimization:", 10, 220)
    love.graphics.print("Cluster Size: " .. level.clusterSize .. "x" .. level.clusterSize, 10, 240)
    
    -- Count active clusters
    local clusterRows = math.ceil(level.height / level.clusterSize)
    local clusterCols = math.ceil(level.width / level.clusterSize)
    local activeClusterCount = 0
    local totalClusters = clusterRows * clusterCols
    
    for cy = 0, clusterRows - 1 do
        for cx = 0, clusterCols - 1 do
            if level.clusters[cy] and level.clusters[cy][cx] and level.clusters[cy][cx].active then
                activeClusterCount = activeClusterCount + 1
            end
        end
    end
    
    love.graphics.print("Active Clusters: " .. activeClusterCount .. "/" .. totalClusters, 10, 260)
    love.graphics.print("Active Cells: " .. #level.activeCells, 10, 280)
    
    -- Only draw active clusters if specifically requested
    if Debug.showActiveCells then
        love.graphics.setColor(0, 1, 0, 0.2)
        for cy = 0, clusterRows - 1 do
            for cx = 0, clusterCols - 1 do
                if level.clusters[cy] and level.clusters[cy][cx] and level.clusters[cy][cx].active then
                    love.graphics.rectangle(
                        "fill", 
                            cx * level.clusterSize * CellTypes.SIZE, 
                            cy * level.clusterSize * CellTypes.SIZE, 
                            level.clusterSize * CellTypes.SIZE, 
                            level.clusterSize * CellTypes.SIZE
                    )
                end
            end
        end
    end
end

function Debug.drawActiveCells(level)
    if Debug.showActiveCells and level.debugActiveCells then
        love.graphics.setColor(0, 1, 0, 0.7)
        for _, cell in ipairs(level.debugActiveCells) do
            -- Fade out based on time
            local age = love.timer.getTime() - cell.time
            if age < 0.5 then
                love.graphics.setColor(0, 1, 0, 0.7 * (1 - age / 0.5))
                love.graphics.rectangle("fill", cell.x * CellTypes.SIZE, cell.y * CellTypes.SIZE, CellTypes.SIZE, CellTypes.SIZE)
            end
        end
    end
end

function Debug.handleKeyPressed(key, level)
    if key == "d" then
        -- Toggle debug mode
        return true -- Debug mode toggled
    elseif key == "s" then
        -- Add more sand for performance testing
        level:addLotsOfSand(5000)
        print("Added 1000 sand cells for performance testing")
    elseif key == "p" then
        -- Add a sand pile
        return "sand_pile" -- Signal to add a sand pile at ball position
    elseif key == "a" then
        -- Toggle active cells visualization
        Debug.showActiveCells = not Debug.showActiveCells
        print("Active cells visualization: " .. (Debug.showActiveCells and "ON" or "OFF"))
    elseif key == "v" then
        -- Toggle VSync
        Debug.vsyncEnabled = not Debug.vsyncEnabled
        love.window.setVSync(Debug.vsyncEnabled and 1 or 0)
        print("VSync: " .. (Debug.vsyncEnabled and "ON" or "OFF"))
    elseif key == "w" then
        -- Create water test level
        level:createWaterTestLevel()
        print("Created water test level")
    elseif key == "t" then
        -- Create dirt-water test level
        level:createDirtWaterTestLevel()
        print("Created dirt-water test level")
    elseif key == "g" then
        -- Create a new procedural level
        level:createProceduralLevel()
        
        -- Add a diamond-shaped win hole at a random position
        -- This function is defined in main.lua
        _G.createDiamondWinHole(level)
        
        print("Created new procedural level with win hole at random position")
    elseif key == "e" then
        -- Add a dirt block
        return "dirt_block" -- Signal to add a dirt block at ball position
    elseif key == "q" then
        -- Add a water pool
        return "water_pool" -- Signal to add a water pool at ball position
    end
    
    return false -- No debug action taken
end

return Debug
