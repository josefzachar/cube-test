-- editor/tools.lua - Tools for the level editor

local CellTypes = require("src.cell_types")
local Cell = require("cell")
local WinHole = require("src.win_hole")

local EditorTools = {
    editor = nil,
    
    -- Mouse state
    mouseDown = false,
    lastGridX = -1,
    lastGridY = -1,
    
    -- Tool functions
    tools = {}
}

-- Calculate brush position based on grid coordinates and brush size
-- Returns startGridX, startGridY (top-left corner of the brush)
function EditorTools.calculateBrushPosition(gridX, gridY, brushSize)
    -- Calculate brush center at the grid position
    local centerX = gridX
    local centerY = gridY
    
    -- Calculate brush radius (half the brush size)
    local radius = math.floor(brushSize / 2)
    
    -- Calculate brush start position (top-left corner)
    local startGridX = centerX - radius
    local startGridY = centerY - radius
    
    return startGridX, startGridY
end

-- Initialize the tools
function EditorTools.init(editor)
    EditorTools.editor = editor
    
    -- Initialize tool functions
    EditorTools.tools = {
        draw = EditorTools.drawTool,
        erase = EditorTools.eraseTool,
        fill = EditorTools.fillTool,
        start = EditorTools.startTool,
        winhole = EditorTools.winholeTool
    }
end

-- Update the tools
function EditorTools.update(dt, gridX, gridY)
    -- If file selector is active, don't update tools
    if EditorTools.editor.fileSelector.active then
        return
    end
    
    -- If mouse is down, continue using the current tool
    if EditorTools.mouseDown and (gridX ~= EditorTools.lastGridX or gridY ~= EditorTools.lastGridY) then
        -- Only update if the grid position has changed
        
        -- Check which mouse button is down
        if love.mouse.isDown(1) then -- Left mouse button
            -- Use the current tool
            local toolFunc = EditorTools.tools[EditorTools.editor.currentTool]
            if toolFunc then
                toolFunc(gridX, gridY)
            end
        elseif love.mouse.isDown(2) then -- Right mouse button
            -- Use the erase tool
            EditorTools.eraseTool(gridX, gridY)
        end
        
        -- Update last grid position
        EditorTools.lastGridX = gridX
        EditorTools.lastGridY = gridY
    end
end

-- Handle mouse drag for drawing
function EditorTools.handleMouseDrag(gridX, gridY)
    -- Check if grid coordinates are valid
    if gridX < 0 or gridX >= EditorTools.editor.level.width or
       gridY < 0 or gridY >= EditorTools.editor.level.height then
        return
    end
    
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Get game coordinates
    local gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
    
    -- Use the current tool
    local toolFunc = EditorTools.tools[EditorTools.editor.currentTool]
    if toolFunc then
        toolFunc(gridX, gridY)
    end
    
    -- Update last grid position
    EditorTools.lastGridX = gridX
    EditorTools.lastGridY = gridY
end

-- Draw the tools
function EditorTools.draw()
    -- Draw the current tool cursor
    if EditorTools.editor.currentTool == "start" then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Get grid coordinates
        local gridX, gridY
        local gameX, gameY
        
        -- Use editor's camera for coordinate conversion
        gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
        
        -- Get grid coordinates
        local InputUtils = require("src.input_utils")
        local Cell = require("cell")
        gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, Cell.SIZE)
        
        -- Calculate position
        local cellSize = Cell.SIZE
        local cursorX = gridX * cellSize
        local cursorY = gridY * cellSize
        
        -- Display position text next to cursor
        love.graphics.setColor(1, 1, 1, 1)
        local posText = "Start: " .. math.floor(cursorX) .. "," .. math.floor(cursorY)
        love.graphics.print(posText, cursorX + cellSize + 5, cursorY)
        
        -- Display start position
    elseif EditorTools.editor.currentTool == "winhole" then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Get grid coordinates
        local gridX, gridY
        local gameX, gameY
        
        -- Use editor's camera for coordinate conversion
        gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
        
        -- Get grid coordinates
        local InputUtils = require("src.input_utils")
        local Cell = require("cell")
        gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, Cell.SIZE)
        
        -- Calculate position
        local cellSize = Cell.SIZE
        local cursorX = gridX * cellSize
        local cursorY = gridY * cellSize
        
        -- Display position text next to cursor
        love.graphics.setColor(1, 1, 1, 1)
        local posText = "Hole: " .. math.floor(cursorX) .. "," .. math.floor(cursorY)
        love.graphics.print(posText, cursorX + cellSize + 5, cursorY)
        
        -- Display hole position
    elseif EditorTools.editor.currentTool == "fill" then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Get grid coordinates
        local gridX, gridY
        local gameX, gameY
        
        -- Use editor's camera for coordinate conversion
        gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
        
        -- Get grid coordinates
        local InputUtils = require("src.input_utils")
        local Cell = require("cell")
        gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, Cell.SIZE)
        
        -- Calculate position
        local cellSize = Cell.SIZE
        local cursorX = gridX * cellSize
        local cursorY = gridY * cellSize
        
        -- Display position text next to cursor
        love.graphics.setColor(1, 1, 1, 1)
        local posText = "Fill: " .. math.floor(cursorX) .. "," .. math.floor(cursorY)
        love.graphics.print(posText, cursorX + cellSize + 5, cursorY)
        
        -- Display fill position
    elseif EditorTools.editor.currentTool == "draw" or EditorTools.editor.currentTool == "erase" then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Get grid coordinates
        local gridX, gridY
        local gameX, gameY
        
        -- Use editor's camera for coordinate conversion
        gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
        
        -- Get grid coordinates
        local InputUtils = require("src.input_utils")
        local Cell = require("cell")
        gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, Cell.SIZE)
        
        -- Get brush size and cell size
        local brushSize = EditorTools.editor.brushSize
        local cellSize = Cell.SIZE
        
        -- Calculate cursor position
        local cursorX = gridX * cellSize
        local cursorY = gridY * cellSize
        
        -- No need to display debug information or draw cursor indicator
        
        -- Display position text next to cursor
        love.graphics.setColor(1, 1, 1, 1)
        local posText = "Cursor: " .. math.floor(cursorX) .. "," .. math.floor(cursorY)
        love.graphics.print(posText, cursorX + cellSize + 5, cursorY)
        
        -- We don't need to draw a direct mouse position indicator anymore
        
        -- Draw cursor and position information
    end
end

-- Handle key press for tools
function EditorTools.handleKeyPressed(key)
    -- Tool selection
    if key == "t" then
        EditorTools.editor.currentTool = "draw"
        return true
    elseif key == "x" then
        EditorTools.editor.currentTool = "erase"
        return true
    elseif key == "f" then
        EditorTools.editor.currentTool = "fill"
        return true
    elseif key == "p" then
        EditorTools.editor.currentTool = "start"
        return true
    elseif key == "h" then
        EditorTools.editor.currentTool = "winhole"
        return true
    end
    
    -- Brush size
    if key == "w" then
        -- Increase brush size
        local sizes = {1, 2, 3, 5, 7}
        local currentSize = EditorTools.editor.brushSize
        local currentIndex = 1
        
        -- Find current size index
        for i, size in ipairs(sizes) do
            if size == currentSize then
                currentIndex = i
                break
            end
        end
        
        -- Increase size if not at max
        if currentIndex < #sizes then
            EditorTools.editor.brushSize = sizes[currentIndex + 1]
        end
        
        return true
    elseif key == "s" then
        -- Decrease brush size
        local sizes = {1, 2, 3, 5, 7}
        local currentSize = EditorTools.editor.brushSize
        local currentIndex = 1
        
        -- Find current size index
        for i, size in ipairs(sizes) do
            if size == currentSize then
                currentIndex = i
                break
            end
        end
        
        -- Decrease size if not at min
        if currentIndex > 1 then
            EditorTools.editor.brushSize = sizes[currentIndex - 1]
        end
        
        return true
    end
    
    -- Cell type selection with A/D keys
    if key == "a" or key == "d" then
        local cellTypes = {"EMPTY", "DIRT", "SAND", "STONE", "WATER", "FIRE"}
        local currentType = EditorTools.editor.currentCellType
        local currentIndex = 1
        
        -- Find current type index
        for i, cellType in ipairs(cellTypes) do
            if cellType == currentType then
                currentIndex = i
                break
            end
        end
        
        -- Change to next/previous type
        if key == "d" then
            -- Next type
            currentIndex = currentIndex % #cellTypes + 1
        else -- key == "a"
            -- Previous type
            currentIndex = (currentIndex - 2) % #cellTypes + 1
        end
        
        -- Set new cell type
        EditorTools.editor.currentCellType = cellTypes[currentIndex]
        EditorTools.editor.currentTool = "draw"
        return true
    end
    
    -- Cell type selection with number keys (keep for compatibility)
    if key == "1" then
        EditorTools.editor.currentCellType = "EMPTY"
        EditorTools.editor.currentTool = "draw"
        return true
    elseif key == "2" then
        EditorTools.editor.currentCellType = "DIRT"
        EditorTools.editor.currentTool = "draw"
        return true
    elseif key == "3" then
        EditorTools.editor.currentCellType = "SAND"
        EditorTools.editor.currentTool = "draw"
        return true
    elseif key == "4" then
        EditorTools.editor.currentCellType = "STONE"
        EditorTools.editor.currentTool = "draw"
        return true
    elseif key == "5" then
        EditorTools.editor.currentCellType = "WATER"
        EditorTools.editor.currentTool = "draw"
        return true
    elseif key == "6" then
        EditorTools.editor.currentCellType = "FIRE"
        EditorTools.editor.currentTool = "draw"
        return true
    end
    
    -- Ball type selection
    if key == "b" then
        -- Toggle standard ball
        EditorTools.editor.availableBalls.standard = not EditorTools.editor.availableBalls.standard
        return true
    elseif key == "v" then
        -- Toggle heavy ball
        EditorTools.editor.availableBalls.heavy = not EditorTools.editor.availableBalls.heavy
        return true
    elseif key == "n" then
        -- Toggle exploding ball
        EditorTools.editor.availableBalls.exploding = not EditorTools.editor.availableBalls.exploding
        return true
    elseif key == "m" then
        -- Toggle sticky ball
        EditorTools.editor.availableBalls.sticky = not EditorTools.editor.availableBalls.sticky
        return true
    end
    
    return false
end

-- Handle mouse press for tools
function EditorTools.handleMousePressed(gridX, gridY, button)
    -- If file selector is active, don't handle mouse press for tools
    if EditorTools.editor.fileSelector.active then
        return false
    end
    
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Get game coordinates directly from the editor's camera
    local gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
    
    if button == 1 then -- Left mouse button
        -- Start using the current tool
        EditorTools.mouseDown = true
        EditorTools.lastGridX = gridX
        EditorTools.lastGridY = gridY
        
        -- Use the current tool
        local toolFunc = EditorTools.tools[EditorTools.editor.currentTool]
        if toolFunc then
            toolFunc(gridX, gridY)
        end
        
        return true
    elseif button == 2 then -- Right mouse button
        -- Use the erase tool
        EditorTools.mouseDown = true
        EditorTools.lastGridX = gridX
        EditorTools.lastGridY = gridY
        
        -- Erase at the current position
        EditorTools.eraseTool(gridX, gridY)
        
        return true
    end
    
    return false
end

-- Handle mouse release for tools
function EditorTools.handleMouseReleased(gridX, gridY, button)
    -- If file selector is active, don't handle mouse release for tools
    if EditorTools.editor.fileSelector.active then
        return false
    end
    
    if button == 1 or button == 2 then -- Left or right mouse button
        -- Stop using the current tool
        EditorTools.mouseDown = false
        return true
    end
    
    return false
end

-- Draw tool
function EditorTools.drawTool(gridX, gridY)
    -- Check if grid coordinates are valid
    if gridX < 0 or gridX >= EditorTools.editor.level.width or
       gridY < 0 or gridY >= EditorTools.editor.level.height then
        return
    end
    
    -- Get cell type
    local cellType = EditorTools.editor.CELL_TYPE_TO_TYPE[EditorTools.editor.currentCellType]
    
    -- Apply brush with size
    local brushSize = EditorTools.editor.brushSize
    
    -- Calculate brush position using the universal function
    local startGridX, startGridY = EditorTools.calculateBrushPosition(gridX, gridY, brushSize)
    
    -- Draw with brush size
    for y = 0, brushSize - 1 do
        for x = 0, brushSize - 1 do
            local cellX = startGridX + x
            local cellY = startGridY + y
            
            -- Check if cell coordinates are valid
            if cellX >= 0 and cellX < EditorTools.editor.level.width and
               cellY >= 0 and cellY < EditorTools.editor.level.height then
                -- Set cell type
                EditorTools.editor.level:setCellType(cellX, cellY, cellType)
            end
        end
    end
end

-- Erase tool
function EditorTools.eraseTool(gridX, gridY)
    -- Check if grid coordinates are valid
    if gridX < 0 or gridX >= EditorTools.editor.level.width or
       gridY < 0 or gridY >= EditorTools.editor.level.height then
        return
    end
    
    -- Apply brush with size
    local brushSize = EditorTools.editor.brushSize
    
    -- Calculate brush position using the universal function
    local startGridX, startGridY = EditorTools.calculateBrushPosition(gridX, gridY, brushSize)
    
    -- Erase with brush size
    for y = 0, brushSize - 1 do
        for x = 0, brushSize - 1 do
            local cellX = startGridX + x
            local cellY = startGridY + y
            
            -- Check if cell coordinates are valid
            if cellX >= 0 and cellX < EditorTools.editor.level.width and
               cellY >= 0 and cellY < EditorTools.editor.level.height then
                -- Set cell type to empty
                EditorTools.editor.level:setCellType(cellX, cellY, CellTypes.TYPES.EMPTY)
            end
        end
    end
end

-- Fill tool
function EditorTools.fillTool(gridX, gridY)
    -- Check if grid coordinates are valid
    if gridX < 0 or gridX >= EditorTools.editor.level.width or
       gridY < 0 or gridY >= EditorTools.editor.level.height then
        return
    end
    
    -- Get the target cell type
    local targetType = EditorTools.editor.level:getCellType(gridX, gridY)
    
    -- Don't fill if target is already the desired type
    if targetType == EditorTools.editor.currentCellType then
        return
    end
    
    -- Flood fill algorithm
    local queue = {{x = gridX, y = gridY}}
    local visited = {}
    
    while #queue > 0 do
        -- Get next cell
        local cell = table.remove(queue, 1)
        local x, y = cell.x, cell.y
        
        -- Check if already visited
        local key = x .. "," .. y
        if visited[key] then
            goto continue
        end
        
        -- Mark as visited
        visited[key] = true
        
        -- Check if cell is valid and has the target type
        if x >= 0 and x < EditorTools.editor.level.width and
           y >= 0 and y < EditorTools.editor.level.height and
           EditorTools.editor.level:getCellType(x, y) == targetType then
            -- Set cell type
            EditorTools.editor.level:setCellType(x, y, EditorTools.editor.currentCellType)
            
            -- Add neighbors to queue
            table.insert(queue, {x = x - 1, y = y})
            table.insert(queue, {x = x + 1, y = y})
            table.insert(queue, {x = x, y = y - 1})
            table.insert(queue, {x = x, y = y + 1})
        end
        
        ::continue::
    end
end

-- Start position tool
function EditorTools.startTool(gridX, gridY)
    -- Check if grid coordinates are valid
    if gridX < 0 or gridX >= EditorTools.editor.level.width or
       gridY < 0 or gridY >= EditorTools.editor.level.height then
        return
    end
    
    -- Set start position
    EditorTools.editor.startX = gridX
    EditorTools.editor.startY = gridY
    
    -- Clear area around start position
    for y = gridY - 1, gridY + 1 do
        for x = gridX - 1, gridX + 1 do
            -- Check if cell coordinates are valid
            if x >= 0 and x < EditorTools.editor.level.width and
               y >= 0 and y < EditorTools.editor.level.height then
                -- Set cell type to empty
                EditorTools.editor.level:setCellType(x, y, CellTypes.TYPES.EMPTY)
            end
        end
    end
    
    -- Clean up any existing test ball
    if EditorTools.editor.testBall then
        EditorTools.editor.testBall.body:destroy()
        EditorTools.editor.testBall = nil
    end
    
    print("Start position set to: " .. gridX .. ", " .. gridY)
end

-- Win hole tool
function EditorTools.winholeTool(gridX, gridY)
    -- Check if grid coordinates are valid
    if gridX < 0 or gridX >= EditorTools.editor.level.width or
       gridY < 0 or gridY >= EditorTools.editor.level.height then
        return
    end
    
    -- First, clear any existing win holes
    for y = 0, EditorTools.editor.level.height - 1 do
        for x = 0, EditorTools.editor.level.width - 1 do
            if EditorTools.editor.level:getCellType(x, y) == CellTypes.TYPES.WIN_HOLE then
                EditorTools.editor.level:setCellType(x, y, CellTypes.TYPES.EMPTY)
            end
        end
    end
    
    -- Create win hole
    WinHole.createWinHoleArea(EditorTools.editor.level, gridX, gridY, 3, 3)
    
    -- Update win hole position in editor
    EditorTools.editor.winHoleX = gridX
    EditorTools.editor.winHoleY = gridY
    
    print("Win hole created at: " .. gridX .. ", " .. gridY)
end

return EditorTools
