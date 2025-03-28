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
    -- If mouse is down, continue using the current tool
    if EditorTools.mouseDown and (gridX ~= EditorTools.lastGridX or gridY ~= EditorTools.lastGridY) then
        -- Only update if the grid position has changed
        local toolFunc = EditorTools.tools[EditorTools.editor.currentTool]
        if toolFunc then
            toolFunc(gridX, gridY)
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
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
    
    -- Get screen dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    
    -- Check if mouse is in UI area (left or right panel)
    if gameX < 140 or gameX > gameWidth - 140 then
        -- Mouse is in UI area, don't draw
        return
    end
    
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
    if EditorTools.editor.currentTool == "draw" or EditorTools.editor.currentTool == "erase" then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Convert screen coordinates to game coordinates
        local gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
        
        -- Get grid coordinates
        local gridX, gridY = EditorTools.editor.level:getGridCoordinates(gameX, gameY)
        
        -- Draw brush outline
        love.graphics.setColor(1, 1, 1, 0.5)
        local brushSize = EditorTools.editor.brushSize
        local cellSize = Cell.SIZE
        
        -- Calculate brush rectangle
        local brushX = gridX * cellSize - (brushSize - 1) * cellSize / 2
        local brushY = gridY * cellSize - (brushSize - 1) * cellSize / 2
        local brushWidth = brushSize * cellSize
        local brushHeight = brushSize * cellSize
        
        -- Draw brush outline
        love.graphics.rectangle("line", brushX, brushY, brushWidth, brushHeight)
    end
end

-- Handle key press for tools
function EditorTools.handleKeyPressed(key)
    -- Tool selection
    if key == "d" then
        EditorTools.editor.currentTool = "draw"
        return true
    elseif key == "e" then
        EditorTools.editor.currentTool = "erase"
        return true
    elseif key == "f" then
        EditorTools.editor.currentTool = "fill"
        return true
    elseif key == "s" then
        EditorTools.editor.currentTool = "start"
        return true
    elseif key == "w" then
        EditorTools.editor.currentTool = "winhole"
        return true
    end
    
    -- Brush size
    if key == "=" or key == "+" then
        EditorTools.editor.brushSize = math.min(EditorTools.editor.brushSize + 1, 10)
        return true
    elseif key == "-" or key == "_" then
        EditorTools.editor.brushSize = math.max(EditorTools.editor.brushSize - 1, 1)
        return true
    end
    
    -- Cell type selection
    if key == "1" then
        EditorTools.editor.currentCellType = CellTypes.TYPES.DIRT
        return true
    elseif key == "2" then
        EditorTools.editor.currentCellType = CellTypes.TYPES.SAND
        return true
    elseif key == "3" then
        EditorTools.editor.currentCellType = CellTypes.TYPES.STONE
        return true
    elseif key == "4" then
        EditorTools.editor.currentCellType = CellTypes.TYPES.WATER
        return true
    elseif key == "5" then
        EditorTools.editor.currentCellType = CellTypes.TYPES.FIRE
        return true
    end
    
    -- Ball type selection
    if key == "b" then
        -- Toggle standard ball
        EditorTools.editor.availableBalls.standard = not EditorTools.editor.availableBalls.standard
        return true
    elseif key == "h" then
        -- Toggle heavy ball
        EditorTools.editor.availableBalls.heavy = not EditorTools.editor.availableBalls.heavy
        return true
    elseif key == "x" then
        -- Toggle exploding ball
        EditorTools.editor.availableBalls.exploding = not EditorTools.editor.availableBalls.exploding
        return true
    elseif key == "t" then
        -- Toggle sticky ball
        EditorTools.editor.availableBalls.sticky = not EditorTools.editor.availableBalls.sticky
        return true
    end
    
    return false
end

-- Handle mouse press for tools
function EditorTools.handleMousePressed(gridX, gridY, button)
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = EditorTools.editor.screenToGameCoords(mouseX, mouseY)
    
    -- Get screen dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    
    -- Check if mouse is in UI area (left or right panel)
    if gameX < 140 or gameX > gameWidth - 140 then
        -- Mouse is in UI area, don't use tool
        return false
    end
    
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
        -- Stop using the current tool
        EditorTools.mouseDown = false
        return true
    end
    
    return false
end

-- Handle mouse release for tools
function EditorTools.handleMouseReleased(gridX, gridY, button)
    if button == 1 then -- Left mouse button
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
    
    -- Get brush size
    local brushSize = EditorTools.editor.brushSize
    
    -- Calculate brush bounds
    local startX = gridX - math.floor((brushSize - 1) / 2)
    local startY = gridY - math.floor((brushSize - 1) / 2)
    local endX = startX + brushSize - 1
    local endY = startY + brushSize - 1
    
    -- Draw cells within brush
    for y = startY, endY do
        for x = startX, endX do
            -- Check if cell coordinates are valid
            if x >= 0 and x < EditorTools.editor.level.width and
               y >= 0 and y < EditorTools.editor.level.height then
                -- Set cell type
                local cellType = EditorTools.editor.CELL_TYPE_TO_TYPE[EditorTools.editor.currentCellType]
                EditorTools.editor.level:setCellType(x, y, cellType)
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
    
    -- Get brush size
    local brushSize = EditorTools.editor.brushSize
    
    -- Calculate brush bounds
    local startX = gridX - math.floor((brushSize - 1) / 2)
    local startY = gridY - math.floor((brushSize - 1) / 2)
    local endX = startX + brushSize - 1
    local endY = startY + brushSize - 1
    
    -- Erase cells within brush
    for y = startY, endY do
        for x = startX, endX do
            -- Check if cell coordinates are valid
            if x >= 0 and x < EditorTools.editor.level.width and
               y >= 0 and y < EditorTools.editor.level.height then
                -- Set cell type to empty
                EditorTools.editor.level:setCellType(x, y, CellTypes.TYPES.EMPTY)
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
    
    print("Start position set to: " .. gridX .. ", " .. gridY)
end

-- Win hole tool
function EditorTools.winholeTool(gridX, gridY)
    -- Check if grid coordinates are valid
    if gridX < 0 or gridX >= EditorTools.editor.level.width or
       gridY < 0 or gridY >= EditorTools.editor.level.height then
        return
    end
    
    -- Create win hole
    WinHole.createWinHoleArea(EditorTools.editor.level, gridX, gridY, 3, 3)
    
    print("Win hole created at: " .. gridX .. ", " .. gridY)
end

return EditorTools
