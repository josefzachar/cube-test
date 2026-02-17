-- renderer.lua - Cell rendering utilities

local CellTypes = require("src.cell_types")
local Fire = require("src.fire")

local Renderer = {}

-- Initialize sprite batches for efficient rendering
local cellTexture = nil
local spriteBatches = {}
local quadCache = {}

function Renderer.initSpriteBatches()
    -- Create a simple 1x1 white texture
    local imageData = love.image.newImageData(1, 1)
    imageData:setPixel(0, 0, 1, 1, 1, 1)
    cellTexture = love.graphics.newImage(imageData)
    
    -- Create sprite batches for each cell type (max 10000 cells per type)
    local Cell = require("cell")
    spriteBatches[Cell.TYPES.SAND] = love.graphics.newSpriteBatch(cellTexture, 10000, "dynamic")
    spriteBatches[Cell.TYPES.STONE] = love.graphics.newSpriteBatch(cellTexture, 10000, "dynamic")
    spriteBatches[Cell.TYPES.WATER] = love.graphics.newSpriteBatch(cellTexture, 10000, "dynamic")
    spriteBatches[Cell.TYPES.DIRT] = love.graphics.newSpriteBatch(cellTexture, 10000, "dynamic")
    spriteBatches[CellTypes.TYPES.FIRE] = love.graphics.newSpriteBatch(cellTexture, 1000, "dynamic")
    spriteBatches[CellTypes.TYPES.SMOKE] = love.graphics.newSpriteBatch(cellTexture, 1000, "dynamic")
    spriteBatches[CellTypes.TYPES.WIN_HOLE] = love.graphics.newSpriteBatch(cellTexture, 100, "dynamic")
    
    -- Create quad for a single cell (covers entire 1x1 texture)
    quadCache.cell = love.graphics.newQuad(0, 0, 1, 1, 1, 1)
end

-- Draw all cells in the level
function Renderer.drawLevel(level, debug)
    -- Get visible area (camera view)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local Camera = require("src.camera")
    
    -- Calculate visible cell range based on screen size and zoom
    local margin = 10 -- Extra cells to draw outside the visible area to avoid pop-in
    
    -- Get zoom level
    local zoom = ZOOM_LEVEL or 1
    
    -- Calculate viewport in world coordinates (unscaled)
    local viewportWidth = screenWidth / zoom
    local viewportHeight = screenHeight / zoom
    
    -- Get camera position
    local cameraX = Camera.x or (level.width * Cell.SIZE / 2)
    local cameraY = Camera.y or (level.height * Cell.SIZE / 2)
    
    -- Calculate viewport bounds in world space (centered on camera)
    local viewLeft = cameraX - viewportWidth / 2
    local viewRight = cameraX + viewportWidth / 2
    local viewTop = cameraY - viewportHeight / 2
    local viewBottom = cameraY + viewportHeight / 2
    
    -- Convert to grid coordinates with margin
    local minX = math.max(0, math.floor(viewLeft / Cell.SIZE) - margin)
    local maxX = math.min(level.width - 1, math.ceil(viewRight / Cell.SIZE) + margin)
    local minY = math.max(0, math.floor(viewTop / Cell.SIZE) - margin)
    local maxY = math.min(level.height - 1, math.ceil(viewBottom / Cell.SIZE) + margin)
    
    -- Store culling stats in perfStats
    if level.perfStats then
        level.perfStats.visibleCells = (maxX - minX + 1) * (maxY - minY + 1)
        level.perfStats.totalCells = level.width * level.height
    end
    
    -- Initialize sprite batches if not already done
    if not cellTexture then
        Renderer.initSpriteBatches()
    end
    
    -- Clear all sprite batches
    for _, batch in pairs(spriteBatches) do
        batch:clear()
    end
    
    -- Add cells to sprite batches
    for y = minY, maxY do
        for x = minX, maxX do
            if level.cells[y] and level.cells[y][x] then
                local cell = level.cells[y][x]
                local cellType = cell.type
                
                -- Skip empty cells unless in debug mode
                if cellType == Cell.TYPES.EMPTY then
                    if debug then
                        love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
                        love.graphics.rectangle("line", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
                    end
                elseif cellType == Cell.TYPES.DIRT then
                    -- Dirt has special rendering with grass
                    Renderer.drawDirtCell(cell, x, y, Cell.SIZE, debug)
                elseif spriteBatches[cellType] then
                    -- Add to sprite batch with color variation
                    local color = COLORS[cellType]
                    local r = color[1] * cell.colorVariation.r
                    local g = color[2] * cell.colorVariation.g
                    local b = color[3] * cell.colorVariation.b
                    local a = color[4]
                    
                    spriteBatches[cellType]:setColor(r, g, b, a)
                    spriteBatches[cellType]:add(quadCache.cell, x * Cell.SIZE, y * Cell.SIZE, 0, Cell.SIZE, Cell.SIZE)
                end
            end
        end
    end
    
    -- Draw all sprite batches
    love.graphics.setColor(1, 1, 1, 1)
    for _, batch in pairs(spriteBatches) do
        love.graphics.draw(batch)
    end
    
    -- Draw visual sand cells
    Renderer.drawVisualSand(level, minX, maxX, minY, maxY, debug)
    
    -- Draw grid lines in debug mode
    if debug then
        Renderer.drawGrid(minX, maxX, minY, maxY)
    end
end

-- Draw sand cells
function Renderer.drawSandBatch(level, sandBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local sandColor = COLORS[Cell.TYPES.SAND]
    local Debug = require("src.debug")
    
    for _, cellPos in ipairs(sandBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        
        -- Apply color variation
        love.graphics.setColor(
            sandColor[1] * cell.colorVariation.r,
            sandColor[2] * cell.colorVariation.g,
            sandColor[3] * cell.colorVariation.b,
            sandColor[4]
        )
        love.graphics.rectangle("fill", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            -- If debug mode is on and active cells visualization is enabled, 
            -- show which cells are in active clusters
            if Debug.showActiveCells and cellPos.active then
                -- Draw a small indicator for active cells
                love.graphics.setColor(1, 1, 0, 0.7) -- Yellow for active cells
                love.graphics.rectangle("line", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            else
                -- Regular debug indicator
                love.graphics.setColor(0, 0, 1, 1) -- Blue
                love.graphics.circle("fill", cellPos.x * Cell.SIZE + Cell.SIZE/2, cellPos.y * Cell.SIZE + Cell.SIZE/2, 2)
            end
        end
    end
end

-- Draw stone cells
function Renderer.drawStoneBatch(level, stoneBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local stoneColor = COLORS[Cell.TYPES.STONE]
    
    for _, cellPos in ipairs(stoneBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        
        -- Apply color variation
        love.graphics.setColor(
            stoneColor[1] * cell.colorVariation.r,
            stoneColor[2] * cell.colorVariation.g,
            stoneColor[3] * cell.colorVariation.b,
            stoneColor[4]
        )
        love.graphics.rectangle("fill", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(1, 0, 0, 1) -- Red
            love.graphics.circle("fill", cellPos.x * Cell.SIZE + Cell.SIZE/2, cellPos.y * Cell.SIZE + Cell.SIZE/2, 2)
        end
    end
end

-- Draw water cells
function Renderer.drawWaterBatch(level, waterBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local waterColor = COLORS[Cell.TYPES.WATER]
    local Debug = require("src.debug")
    
    for _, cellPos in ipairs(waterBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        
        -- Apply color variation
        love.graphics.setColor(
            waterColor[1] * cell.colorVariation.r,
            waterColor[2] * cell.colorVariation.g,
            waterColor[3] * cell.colorVariation.b,
            waterColor[4]
        )
        love.graphics.rectangle("fill", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            -- If debug mode is on and active cells visualization is enabled, 
            -- show which cells are in active clusters
            if Debug.showActiveCells and cellPos.active then
                -- Draw a small indicator for active cells
                love.graphics.setColor(1, 1, 0, 0.7) -- Yellow for active cells
                love.graphics.rectangle("line", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            else
                -- Regular debug indicator
                love.graphics.setColor(0, 1, 1, 1) -- Cyan
                love.graphics.circle("fill", cellPos.x * Cell.SIZE + Cell.SIZE/2, cellPos.y * Cell.SIZE + Cell.SIZE/2, 2)
            end
        end
    end
end

-- Draw visual particles (sand and dirt)
function Renderer.drawVisualSand(level, minX, maxX, minY, maxY, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    
    if #level.visualSandCells > 0 then
        for _, cell in ipairs(level.visualSandCells) do
            -- Only draw if within visible area
            if cell.visualX >= minX * Cell.SIZE - Cell.SIZE and 
               cell.visualX <= maxX * Cell.SIZE + Cell.SIZE and
               cell.visualY >= minY * Cell.SIZE - Cell.SIZE and
               cell.visualY <= maxY * Cell.SIZE + Cell.SIZE then
                
                -- Get the correct color based on cell type
                local color = COLORS[cell.type]
                if color then
                    -- Apply color variation and alpha for fade out
                    love.graphics.setColor(
                        color[1] * cell.colorVariation.r, 
                        color[2] * cell.colorVariation.g, 
                        color[3] * cell.colorVariation.b, 
                        cell.alpha or 1.0
                    )
                    love.graphics.rectangle("fill", cell.visualX, cell.visualY, Cell.SIZE, Cell.SIZE)
                    
                    -- Draw debug info for visual particles
                    if debug then
                        love.graphics.setColor(1, 0, 0, cell.alpha or 1.0)
                        love.graphics.rectangle("line", cell.visualX, cell.visualY, Cell.SIZE, Cell.SIZE)
                    end
                end
            end
        end
    end
end

-- Draw a single dirt cell (helper for optimized renderer)
function Renderer.drawDirtCell(cell, x, y, cellSize, debug)
    local COLORS = CellTypes.COLORS
    local dirtColor = COLORS[require("cell").TYPES.DIRT]
    local grassColor = {0.2, 0.7, 0.2, 1}
    
    -- Choose color based on whether this cell has grass
    local color = cell.hasGrass and grassColor or dirtColor
    
    -- Apply color variation
    love.graphics.setColor(
        color[1] * cell.colorVariation.r,
        color[2] * cell.colorVariation.g,
        color[3] * cell.colorVariation.b,
        color[4]
    )
    love.graphics.rectangle("fill", x * cellSize, y * cellSize, cellSize, cellSize)
end

-- Draw dirt cells
function Renderer.drawDirtBatch(level, dirtBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local dirtColor = COLORS[Cell.TYPES.DIRT]
    -- Define grass color (green)
    local grassColor = {0.2, 0.7, 0.2, 1}
    local Debug = require("src.debug")
    
    for _, cellPos in ipairs(dirtBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        local x, y = cellPos.x, cellPos.y
        
        -- Choose color based on whether this cell has grass (set during level initialization)
        local color = cell.hasGrass and grassColor or dirtColor
        
        -- Apply color variation
        love.graphics.setColor(
            color[1] * cell.colorVariation.r,
            color[2] * cell.colorVariation.g,
            color[3] * cell.colorVariation.b,
            color[4]
        )
        love.graphics.rectangle("fill", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            -- If debug mode is on and active cells visualization is enabled, 
            -- show which cells are in active clusters
            if Debug.showActiveCells and cellPos.active then
                -- Draw a small indicator for active cells
                love.graphics.setColor(1, 1, 0, 0.7) -- Yellow for active cells
                love.graphics.rectangle("line", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            else
                -- Regular debug indicator
                love.graphics.setColor(0.8, 0.4, 0, 1) -- Orange
                love.graphics.circle("fill", x * Cell.SIZE + Cell.SIZE/2, y * Cell.SIZE + Cell.SIZE/2, 2)
            end
        end
    end
end

-- Draw fire cells with simple animated effect
function Renderer.drawFireBatch(level, fireBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local fireColor = COLORS[CellTypes.TYPES.FIRE]
    
    for _, cellPos in ipairs(fireBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        local x, y = cellPos.x, cellPos.y
        
        -- Apply color variation and simple animation
        local time = love.timer.getTime()
        local flicker = math.sin(time * 10 + x * 0.5 + y * 0.7) * 0.2 + 0.8 -- Flickering effect
        
        love.graphics.setColor(
            fireColor[1] * cell.colorVariation.r * flicker,
            fireColor[2] * cell.colorVariation.g * flicker,
            fireColor[3] * cell.colorVariation.b * flicker,
            fireColor[4]
        )
        
        -- Draw main fire cell
        love.graphics.rectangle("fill", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(1, 0.5, 0, 1) -- Orange
            love.graphics.circle("fill", x * Cell.SIZE + Cell.SIZE/2, y * Cell.SIZE + Cell.SIZE/2, 2)
        end
    end
end

-- Draw smoke cells with simple rising effect
function Renderer.drawSmokeBatch(level, smokeBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local smokeColor = COLORS[CellTypes.TYPES.SMOKE]
    
    for _, cellPos in ipairs(smokeBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        local x, y = cellPos.x, cellPos.y
        
        -- Check if this is steam (from Fire.steamCells) or regular smoke
        local isInSteamTable = Fire and Fire.steamCells and Fire.steamCells[x .. "," .. y]
        
        -- Apply color variation and animation
        local time = love.timer.getTime()
        local drift = math.sin(time * 2 + x * 0.3 + y * 0.5) * 0.1 -- Slow drifting effect
        
        -- Determine if this is steam or smoke for coloring
        if isInSteamTable then
            -- Steam is more white/blue tinted
            love.graphics.setColor(0.9, 0.9, 1.0, 0.7)
        else
            -- Regular smoke is gray
            love.graphics.setColor(
                smokeColor[1] * cell.colorVariation.r,
                smokeColor[2] * cell.colorVariation.g,
                smokeColor[3] * cell.colorVariation.b,
                smokeColor[4] * (0.8 + drift) -- Varying opacity
            )
        end
        
        -- Draw smoke with slight offset for drifting effect
        love.graphics.rectangle(
            "fill", 
            x * Cell.SIZE + drift * Cell.SIZE, 
            y * Cell.SIZE, 
            Cell.SIZE, 
            Cell.SIZE
        )
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(0.7, 0.7, 0.7, 1) -- Light gray
            love.graphics.circle("fill", x * Cell.SIZE + Cell.SIZE/2, y * Cell.SIZE + Cell.SIZE/2, 2)
        end
    end
end

-- Draw win hole cells with slower, gradient pulsating effect
function Renderer.drawWinHoleBatch(level, winHoleBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    
    -- Get current time for animation
    local time = love.timer.getTime()
    
    for _, cellPos in ipairs(winHoleBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        local x, y = cellPos.x, cellPos.y
        
        -- Calculate cell position
        local cellX = x * Cell.SIZE
        local cellY = y * Cell.SIZE
        
        -- Slower, smoother pulsating animation (using sine wave)
        local pulse = math.sin(time * 1.5 + x * 0.05 + y * 0.05) * 0.5 + 0.5 -- Values between 0 and 1
        
        -- Create a gradient between dark blue and dark purple
        local r = 0.2 + (0.4 * pulse) -- Range: 0.2 to 0.6
        local g = 0.1 + (0.1 * pulse) -- Range: 0.1 to 0.2
        local b = 0.5 + (0.3 * pulse) -- Range: 0.5 to 0.8
        
        -- Set the color with the gradient effect
        love.graphics.setColor(r, g, b, 1.0)
        
        -- Draw the entire win hole cell with the colorful effect
        love.graphics.rectangle("fill", cellX, cellY, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(0, 1, 0, 1) -- Green
            love.graphics.rectangle("fill", cellX + Cell.SIZE/2 - 1, cellY + Cell.SIZE/2 - 1, 2, 2)
        end
    end
end

-- Draw grid lines
function Renderer.drawGrid(minX, maxX, minY, maxY)
    local Cell = require("cell")
    
    love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
    for x = minX, maxX + 1 do
        love.graphics.line(x * Cell.SIZE, minY * Cell.SIZE, x * Cell.SIZE, (maxY + 1) * Cell.SIZE)
    end
    for y = minY, maxY + 1 do
        love.graphics.line(minX * Cell.SIZE, y * Cell.SIZE, (maxX + 1) * Cell.SIZE, y * Cell.SIZE)
    end
end

return Renderer
