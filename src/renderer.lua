-- renderer.lua - Cell rendering utilities

local CellTypes = require("src.cell_types")
local Fire = require("src.fire")

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
    local fireBatch = {}
    local smokeBatch = {}
    
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
                elseif cellType == CellTypes.TYPES.FIRE then
                    table.insert(fireBatch, {x = x, y = y})
                elseif cellType == CellTypes.TYPES.SMOKE then
                    table.insert(smokeBatch, {x = x, y = y})
                elseif debug and cellType == Cell.TYPES.EMPTY then
                    -- Draw empty cells only in debug mode
                    love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
                    love.graphics.rectangle("line", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
                end
            end
        end
    end
    
    -- Draw sand cells
    Renderer.drawSandBatch(level, sandBatch, debug)
    
    -- Draw stone cells
    Renderer.drawStoneBatch(level, stoneBatch, debug)
    
    -- Draw water cells
    Renderer.drawWaterBatch(level, waterBatch, debug)
    
    -- Draw dirt cells
    Renderer.drawDirtBatch(level, dirtBatch, debug)
    
    -- Draw fire cells
    Renderer.drawFireBatch(level, fireBatch, debug)
    
    -- Draw smoke cells
    Renderer.drawSmokeBatch(level, smokeBatch, debug)
    
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
            love.graphics.setColor(0, 0, 1, 1) -- Blue
            love.graphics.circle("fill", cellPos.x * Cell.SIZE + Cell.SIZE/2, cellPos.y * Cell.SIZE + Cell.SIZE/2, 2)
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
            love.graphics.setColor(0, 1, 1, 1) -- Cyan
            love.graphics.circle("fill", cellPos.x * Cell.SIZE + Cell.SIZE/2, cellPos.y * Cell.SIZE + Cell.SIZE/2, 2)
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

-- Draw dirt cells
function Renderer.drawDirtBatch(level, dirtBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local dirtColor = COLORS[Cell.TYPES.DIRT]
    -- Define grass color (green)
    local grassColor = {0.2, 0.7, 0.2, 1}
    
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
            love.graphics.setColor(0.8, 0.4, 0, 1) -- Orange
            love.graphics.circle("fill", x * Cell.SIZE + Cell.SIZE/2, y * Cell.SIZE + Cell.SIZE/2, 2)
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
