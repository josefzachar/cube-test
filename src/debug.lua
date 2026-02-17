-- debug.lua - Debug functionality for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local Debug = {}

-- Load the pixel font for debug info
local debugFont = nil
local function loadDebugFont()
    -- Load the font with a size suitable for debug info
    debugFont = love.graphics.newFont("fonts/pixel_font.ttf", 16)
end

-- Retro color palette for 80s cassette futurism aesthetic (matching UI)
local retroColors = {
    background = {0.05, 0.05, 0.15, 0.9},  -- Dark blue background
    panel = {0.1, 0.1, 0.2, 0.9},          -- Slightly lighter panel
    panelBorder = {0, 0.8, 0.8, 1},        -- Cyan border
    text = {0, 1, 1, 1},                   -- Cyan text
    highlight = {1, 0.5, 0, 1},            -- Orange highlight
    warning = {1, 0.3, 0.3, 1},            -- Red warning
    success = {0.3, 1, 0.3, 1}             -- Green success
}

-- Draw scanlines effect for retro CRT look
local function drawScanlines(x, y, width, height, alpha)
    love.graphics.setColor(0, 0, 0, alpha or 0.1)
    for i = 0, height, 2 do
        love.graphics.line(x, y + i, x + width, y + i)
    end
end

-- Debug variables
Debug.showActiveCells = false
Debug.vsyncEnabled = false -- Start with VSync disabled (as set in conf.lua)

function Debug.drawDebugInfo(level, ball, attempts, debug)
    if not debug then return end
    
    -- Load font if not already loaded
    if not debugFont then
        loadDebugFont()
    end
    
    -- Get screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Draw retro terminal panel on the left side
    local panelWidth = 250
    local panelHeight = screenHeight
    
    -- Draw panel background
    love.graphics.setColor(retroColors.panel)
    love.graphics.rectangle("fill", 0, 0, panelWidth, panelHeight, 0, 0) -- No rounded corners for retro look
    
    -- Draw grid pattern for retro computer look
    love.graphics.setColor(0, 0, 0, 0.05)
    for i = 0, panelWidth, 8 do
        love.graphics.line(i, 0, i, panelHeight)
    end
    for i = 0, panelHeight, 8 do
        love.graphics.line(0, i, panelWidth, i)
    end
    
    -- Draw panel border
    love.graphics.setColor(retroColors.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 0, 0, panelWidth, panelHeight)
    love.graphics.line(panelWidth, 0, panelWidth, panelHeight) -- Right edge line
    love.graphics.setLineWidth(1)
    
    -- Draw scanlines for CRT effect
    drawScanlines(0, 0, panelWidth, panelHeight, 0.05)
    
    -- Set font for debug info
    love.graphics.setFont(debugFont)
    
    -- Draw "DEBUG" header
    love.graphics.setColor(retroColors.text)
    local headerText = "DEBUG TERMINAL"
    local headerWidth = debugFont:getWidth(headerText)
    love.graphics.print(headerText, (panelWidth - headerWidth) / 2, 10)
    
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
    
    -- Section headers
    local margin = 15
    local yPos = 40
    local lineHeight = 20
    
    -- Cell counts section
    love.graphics.setColor(retroColors.highlight)
    love.graphics.print("CELL COUNTS:", margin, yPos)
    yPos = yPos + lineHeight + 5
    
    -- Display cell counts with retro styling
    love.graphics.setColor(retroColors.text)
    love.graphics.print("SAND: " .. sandCount, margin, yPos); yPos = yPos + lineHeight
    love.graphics.print("STONE: " .. stoneCount, margin, yPos); yPos = yPos + lineHeight
    love.graphics.print("DIRT: " .. dirtCount, margin, yPos); yPos = yPos + lineHeight
    love.graphics.print("WATER: " .. waterCount, margin, yPos); yPos = yPos + lineHeight
    love.graphics.print("EMPTY: " .. emptyCount, margin, yPos); yPos = yPos + lineHeight
    love.graphics.print("VISUAL SAND: " .. visualSandCount, margin, yPos); yPos = yPos + lineHeight * 1.5
    
    -- Ball info section
    love.graphics.setColor(retroColors.highlight)
    love.graphics.print("BALL STATUS:", margin, yPos)
    yPos = yPos + lineHeight + 5
    
    -- Display ball info with retro styling
    love.graphics.setColor(retroColors.text)
    if ball.body then
        local x, y = ball.body:getPosition()
        local vx, vy = ball.body:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        love.graphics.print(string.format("POSITION: X=%.1f Y=%.1f", x, y), margin, yPos); yPos = yPos + lineHeight
        love.graphics.print(string.format("VELOCITY: VX=%.1f VY=%.1f", vx, vy), margin, yPos); yPos = yPos + lineHeight
        love.graphics.print(string.format("SPEED: %.1f", speed), margin, yPos); yPos = yPos + lineHeight * 1.5
    else
        love.graphics.print("NO BALL DATA", margin, yPos); yPos = yPos + lineHeight * 1.5
    end
    
    -- Performance section
    love.graphics.setColor(retroColors.highlight)
    love.graphics.print("PERFORMANCE:", margin, yPos)
    yPos = yPos + lineHeight + 5
    
    -- Display performance stats
    love.graphics.setColor(retroColors.text)
    local stats = level.perfStats or {}
    local totalMs = (stats.totalFrameTime or 0) * 1000
    local fps = love.timer.getFPS()
    
    love.graphics.print(string.format("FPS: %d (%.2f ms)", fps, totalMs), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print("", margin, yPos); yPos = yPos + lineHeight * 0.5
    
    -- Show breakdown of frame time
    local sandWaterMs = (stats.sandWaterUpdate or 0) * 1000
    local clusterMs = (stats.clusterUpdate or 0) * 1000
    local otherCellsMs = (stats.otherCellsUpdate or 0) * 1000
    local visualSandMs = (stats.visualSandUpdate or 0) * 1000
    local bouldersMs = (stats.bouldersUpdate or 0) * 1000
    local physicsBodyMs = (stats.physicsBodyManagement or 0) * 1000
    local physicsStepMs = (stats.physicsStep or 0) * 1000
    local renderingMs = (stats.renderingTime or 0) * 1000
    
    love.graphics.print(string.format("SAND/WATER: %.2f ms", sandWaterMs), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("  - %d cells", stats.sandWaterCellsCount or 0), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("CLUSTERS: %.2f ms", clusterMs), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("  - %d active", stats.activeClustersCount or 0), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("OTHER CELLS: %.2f ms", otherCellsMs), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("VISUAL SAND: %.2f ms", visualSandMs), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("BOULDERS: %.2f ms", bouldersMs), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("PHYSICS MGR: %.2f ms", physicsBodyMs), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("  - %d bodies", stats.physicsBodyCount or 0), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("PHYSICS STEP: %.2f ms", physicsStepMs), margin, yPos); yPos = yPos + lineHeight
    love.graphics.print(string.format("RENDERING: %.2f ms", renderingMs), margin, yPos); yPos = yPos + lineHeight
    
    -- Culling stats
    if stats.visibleCells and stats.totalCells then
        local cullPercent = 100 * (1 - stats.visibleCells / stats.totalCells)
        love.graphics.print(string.format("  - %d/%d cells (%.0f%% culled)", 
            stats.visibleCells, stats.totalCells, cullPercent), margin, yPos); yPos = yPos + lineHeight
    end
    yPos = yPos + lineHeight * 0.5
    
    -- Display optimization info with retro styling
    love.graphics.print("CLUSTER SIZE: " .. level.clusterSize .. "x" .. level.clusterSize, margin, yPos); yPos = yPos + lineHeight
    
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
    
    love.graphics.print("ACTIVE CELLS: " .. #level.activeCells, margin, yPos); yPos = yPos + lineHeight * 1.5
    
    -- Shortcuts section
    love.graphics.setColor(retroColors.highlight)
    love.graphics.print("KEYBOARD COMMANDS:", margin, yPos)
    yPos = yPos + lineHeight + 5
    
    -- Display shortcuts with retro styling
    love.graphics.setColor(retroColors.text)
    local shortcutCommands = {
        "D - TOGGLE DEBUG",
        "1-4 - SWITCH BALL TYPES",
        "E - EXPLODE BALL",
        "R - RESET LEVEL",
        "S - ADD SAND",
        "P - ADD SAND PILE",
        "A - TOGGLE ACTIVE CELLS",
        "V - TOGGLE VSYNC",
        "W - WATER TEST LEVEL",
        "T - DIRT-WATER TEST",
        "G - GENERATE NEW LEVEL",
        "F - ADD FIRE",
        "H - ADD WIN HOLE",
        "Q - ADD WATER POOL"
    }
    
    for _, cmd in ipairs(shortcutCommands) do
        love.graphics.print(cmd, margin, yPos)
        yPos = yPos + lineHeight
    end
    
    -- Only draw active clusters if specifically requested
    if Debug.showActiveCells then
        -- Draw active clusters with a green overlay
        for cy = 0, clusterRows - 1 do
            for cx = 0, clusterCols - 1 do
                if level.clusters[cy] and level.clusters[cy][cx] and level.clusters[cy][cx].active then
                    -- Use a more visible green color with pulsating effect
                    local time = love.timer.getTime()
                    local pulse = math.sin(time * 2) * 0.1 + 0.2 -- Values between 0.1 and 0.3
                    
                    love.graphics.setColor(0, 1, 0, pulse)
                    love.graphics.rectangle(
                        "fill", 
                        cx * level.clusterSize * CellTypes.SIZE, 
                        cy * level.clusterSize * CellTypes.SIZE, 
                        level.clusterSize * CellTypes.SIZE, 
                        level.clusterSize * CellTypes.SIZE
                    )
                    
                    -- Draw cluster border
                    love.graphics.setColor(0, 1, 0, 0.5)
                    love.graphics.rectangle(
                        "line", 
                        cx * level.clusterSize * CellTypes.SIZE, 
                        cy * level.clusterSize * CellTypes.SIZE, 
                        level.clusterSize * CellTypes.SIZE, 
                        level.clusterSize * CellTypes.SIZE
                    )
                    
                    -- Draw cluster coordinates in the center
                    love.graphics.setColor(1, 1, 1, 0.7)
                    local text = cx .. "," .. cy
                    local textWidth = debugFont:getWidth(text)
                    love.graphics.print(
                        text,
                        cx * level.clusterSize * CellTypes.SIZE + (level.clusterSize * CellTypes.SIZE - textWidth) / 2,
                        cy * level.clusterSize * CellTypes.SIZE + level.clusterSize * CellTypes.SIZE / 2 - 8
                    )
                end
            end
        end
    end
end

function Debug.drawActiveCells(level)
    if Debug.showActiveCells and level.debugActiveCells then
        -- Draw active cells with a bright highlight
        for _, cell in ipairs(level.debugActiveCells) do
            -- Fade out based on time
            local age = love.timer.getTime() - cell.time
            if age < 0.5 then
                -- Use a brighter color for active cells
                love.graphics.setColor(1, 0, 1, 0.7 * (1 - age / 0.5))  -- Magenta for contrast with green clusters
                love.graphics.rectangle("fill", cell.x * CellTypes.SIZE, cell.y * CellTypes.SIZE, CellTypes.SIZE, CellTypes.SIZE)
                
                -- Draw a border around the cell
                love.graphics.setColor(1, 0, 1, 0.9 * (1 - age / 0.5))
                love.graphics.rectangle("line", cell.x * CellTypes.SIZE, cell.y * CellTypes.SIZE, CellTypes.SIZE, CellTypes.SIZE)
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
    -- Removed "e" key handler to avoid conflict with exploding ball functionality
    elseif key == "q" then
        -- Add a water pool
        return "water_pool" -- Signal to add a water pool at ball position
    end
    
    return false -- No debug action taken
end

return Debug
