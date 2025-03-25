-- renderer.lua - Cell rendering utilities

local CellTypes = require("src.cell_types")

local Renderer = {}

-- Draw all cells in the level
function Renderer.drawLevel(level, debug)
    -- Get visible area (camera view)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local Cell = require("cell")
    
    -- Calculate visible cell range with some margin
    local margin = 5 -- Extra cells to draw outside the visible area
    local minX = math.max(0, math.floor(0 / CellTypes.SIZE) - margin)
    local maxX = math.min(level.width - 1, math.ceil(screenWidth / CellTypes.SIZE) + margin)
    local minY = math.max(0, math.floor(0 / CellTypes.SIZE) - margin)
    local maxY = math.min(level.height - 1, math.ceil(screenHeight / CellTypes.SIZE) + margin)
    
    -- Batch drawing for better performance
    local sandBatch = {}
    local stoneBatch = {}
    local waterBatch = {}
    local dirtBatch = {}
    
    -- Collect cells for batch drawing
    for y = minY, maxY do
        for x = minX, maxX do
            if level.cells[y] and level.cells[y][x] then
                local cell = level.cells[y][x]
                local cellType = cell.type
                
                if cellType == Cell.TYPES.SAND then
                    table.insert(sandBatch, {x = x, y = y})
                elseif cellType == Cell.TYPES.STONE then
                    table.insert(stoneBatch, {x = x, y = y})
                elseif cellType == Cell.TYPES.WATER then
                    table.insert(waterBatch, {x = x, y = y})
                elseif cellType == Cell.TYPES.DIRT then
                    table.insert(dirtBatch, {x = x, y = y})
                elseif debug and cellType == Cell.TYPES.EMPTY then
                    -- Draw empty cells only in debug mode
                    love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
                    love.graphics.rectangle("line", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
                end
            end
        end
    end
    
    -- Draw sand cells
    Renderer.drawSandBatch(sandBatch, debug)
    
    -- Draw stone cells
    Renderer.drawStoneBatch(stoneBatch, debug)
    
    -- Draw water cells
    Renderer.drawWaterBatch(waterBatch, debug)
    
    -- Draw dirt cells
    Renderer.drawDirtBatch(dirtBatch, debug)
    
    -- Draw visual sand cells
    Renderer.drawVisualSand(level, minX, maxX, minY, maxY, debug)
    
    -- Draw grid lines in debug mode
    if debug then
        Renderer.drawGrid(minX, maxX, minY, maxY)
    end
end

-- Draw sand cells
function Renderer.drawSandBatch(sandBatch, debug)
    local Cell = require("cell")
    
    love.graphics.setColor(0.9, 0.8, 0.5, 1) -- Sand color
    for _, cell in ipairs(sandBatch) do
        love.graphics.rectangle("fill", cell.x * Cell.SIZE, cell.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(0, 0, 1, 1) -- Blue
            love.graphics.circle("fill", cell.x * Cell.SIZE + Cell.SIZE/2, cell.y * Cell.SIZE + Cell.SIZE/2, 2)
            love.graphics.setColor(0.9, 0.8, 0.5, 1) -- Reset to sand color
        end
    end
end

-- Draw stone cells
function Renderer.drawStoneBatch(stoneBatch, debug)
    local Cell = require("cell")
    
    love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Stone color
    for _, cell in ipairs(stoneBatch) do
        love.graphics.rectangle("fill", cell.x * Cell.SIZE, cell.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(1, 0, 0, 1) -- Red
            love.graphics.circle("fill", cell.x * Cell.SIZE + Cell.SIZE/2, cell.y * Cell.SIZE + Cell.SIZE/2, 2)
            love.graphics.setColor(0.5, 0.5, 0.5, 1) -- Reset to stone color
        end
    end
end

-- Draw water cells
function Renderer.drawWaterBatch(waterBatch, debug)
    local Cell = require("cell")
    
    love.graphics.setColor(0.2, 0.4, 0.8, 0.8) -- Water color (blue with transparency)
    for _, cell in ipairs(waterBatch) do
        love.graphics.rectangle("fill", cell.x * Cell.SIZE, cell.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(0, 1, 1, 1) -- Cyan
            love.graphics.circle("fill", cell.x * Cell.SIZE + Cell.SIZE/2, cell.y * Cell.SIZE + Cell.SIZE/2, 2)
            love.graphics.setColor(0.2, 0.4, 0.8, 0.8) -- Reset to water color
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
                    -- Apply alpha for fade out
                    love.graphics.setColor(color[1], color[2], color[3], cell.alpha or 1.0)
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

-- Draw dirt cells
function Renderer.drawDirtBatch(dirtBatch, debug)
    local Cell = require("cell")
    
    love.graphics.setColor(0.6, 0.4, 0.2, 1) -- Dirt color (brown)
    for _, cell in ipairs(dirtBatch) do
        love.graphics.rectangle("fill", cell.x * Cell.SIZE, cell.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(0.8, 0.4, 0, 1) -- Orange
            love.graphics.circle("fill", cell.x * Cell.SIZE + Cell.SIZE/2, cell.y * Cell.SIZE + Cell.SIZE/2, 2)
            love.graphics.setColor(0.6, 0.4, 0.2, 1) -- Reset to dirt color
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
