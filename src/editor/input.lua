-- editor/input.lua - Input handling for the Square Golf editor

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")

local EditorInput = {
    editor = nil
}

-- Initialize the input module
function EditorInput.init(editor)
    EditorInput.editor = editor
    -- Nothing else to initialize for now
end

-- Handle mouse press in editor
function EditorInput.handleMousePressed(x, y, button)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = EditorInput.editor.screenToGameCoords(x, y)
    
    -- Check if we're clicking on a button
    for _, buttonGroup in ipairs({EditorInput.editor.toolButtons, EditorInput.editor.brushButtons, EditorInput.editor.ballButtons, EditorInput.editor.buttons}) do
        for _, button in ipairs(buttonGroup) do
            if gameX >= button.x and gameX <= button.x + button.width and
               gameY >= button.y and gameY <= button.y + button.height then
                button.action()
                return true
            end
        end
    end
    
    -- If text input is active, clicking outside closes it
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    if EditorInput.editor.textInput.active and 
       (gameX < gameWidth/2 - 200 or gameX > gameWidth/2 + 200 or
        gameY < gameHeight/2 - 50 or gameY > gameHeight/2 + 50) then
        EditorInput.editor.levelName = EditorInput.editor.textInput.text
        EditorInput.editor.textInput.active = false
        return true
    end
    
    return false
end

-- Handle mouse press in file selector
function EditorInput.handleFileSelectorMousePressed(x, y, button)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = EditorInput.editor.screenToGameCoords(x, y)
    
    -- Get screen dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    
    -- Dialog dimensions
    local dialogWidth = 500
    local dialogHeight = 400
    local dialogX = (gameWidth - dialogWidth) / 2
    local dialogY = (gameHeight - dialogHeight) / 2
    
    -- File list dimensions
    local fileListY = dialogY + 60
    local fileListHeight = dialogHeight - 120
    local fileItemHeight = 30
    
    -- Check if clicking in file list
    if gameX >= dialogX + 20 and gameX <= dialogX + dialogWidth - 20 and
       gameY >= fileListY and gameY <= fileListY + fileListHeight then
        -- Calculate which file was clicked
        local visibleFiles = math.floor(fileListHeight / fileItemHeight)
        local startIndex = math.max(1, EditorInput.editor.fileSelector.selectedIndex - math.floor(visibleFiles / 2))
        startIndex = math.min(startIndex, math.max(1, #EditorInput.editor.fileSelector.files - visibleFiles + 1))
        
        local clickedIndex = startIndex + math.floor((gameY - fileListY) / fileItemHeight)
        if clickedIndex >= 1 and clickedIndex <= #EditorInput.editor.fileSelector.files then
            EditorInput.editor.fileSelector.selectedIndex = clickedIndex
            
            -- If in save mode, update the filename
            if EditorInput.editor.fileSelector.mode == "save" then
                EditorInput.editor.fileSelector.newFileName = EditorInput.editor.fileSelector.files[clickedIndex].displayName
            end
            
            return true
        end
    end
    
    -- Button dimensions
    local buttonWidth = 100
    local buttonHeight = 30
    local buttonSpacing = 20
    local buttonsY = dialogY + dialogHeight - 50
    
    if EditorInput.editor.fileSelector.mode == "save" then
        buttonsY = dialogY + dialogHeight - 90
    end
    
    -- Check if clicking OK button
    if gameX >= dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing and
       gameX <= dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonSpacing and
       gameY >= buttonsY and gameY <= buttonsY + buttonHeight then
        -- OK button clicked
        if EditorInput.editor.fileSelector.mode == "save" then
            EditorInput.editor.saveLevel()
        else
            EditorInput.editor.loadLevel()
        end
        return true
    end
    
    -- Check if clicking Cancel button
    if gameX >= dialogX + dialogWidth - buttonWidth - buttonSpacing and
       gameX <= dialogX + dialogWidth - buttonSpacing and
       gameY >= buttonsY and gameY <= buttonsY + buttonHeight then
        -- Cancel button clicked
        EditorInput.editor.fileSelector.active = false
        return true
    end
    
    -- If clicking outside the dialog, close it
    if gameX < dialogX or gameX > dialogX + dialogWidth or
       gameY < dialogY or gameY > dialogY + dialogHeight then
        EditorInput.editor.fileSelector.active = false
        return true
    end
    
    return false
end

-- Handle mouse drag for drawing
function EditorInput.handleMouseDrag(dt)
    -- Handle mouse input for drawing
    if love.mouse.isDown(1) and not EditorInput.editor.textInput.active and not EditorInput.editor.fileSelector.active then
        local mouseX, mouseY = love.mouse.getPosition()
        local gameX, gameY = EditorInput.editor.screenToGameCoords(mouseX, mouseY)
        local gridX, gridY = EditorInput.editor.level:getGridCoordinates(gameX, gameY)
        
        -- Check if mouse is in the level area and not over UI
        local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
        if gridX >= 0 and gridX < EditorInput.editor.level.width and gridY >= 0 and gridY < EditorInput.editor.level.height and
           gameX > 140 and gameX < gameWidth - 140 then
            -- If we're in "set start position" mode
            if EditorInput.editor.setStartPosition then
                EditorInput.editor.startX = gridX
                EditorInput.editor.startY = gridY
                EditorInput.editor.setStartPosition = false
                
                -- Create a ball at the start position to visualize it
                if EditorInput.editor.testBall then
                    EditorInput.editor.testBall.body:destroy()
                    EditorInput.editor.testBall = nil
                end
                
                EditorInput.editor.testBall = Balls.createBall(EditorInput.editor.world, EditorInput.editor.startX * Cell.SIZE, EditorInput.editor.startY * Cell.SIZE, Balls.TYPES.STANDARD)
                EditorInput.editor.testBall.body:setUserData(EditorInput.editor.testBall)
                EditorInput.editor.testBall.body:setType("static") -- Make it static so it doesn't fall
            -- If we're in "set win hole position" mode
            elseif EditorInput.editor.setWinHolePosition then
                EditorInput.editor.winHoleX = gridX
                EditorInput.editor.winHoleY = gridY
                EditorInput.editor.setWinHolePosition = false
                
                -- First, clear any existing win holes
                for y = 0, EditorInput.editor.level.height - 1 do
                    for x = 0, EditorInput.editor.level.width - 1 do
                        if EditorInput.editor.level:getCellType(x, y) == CellTypes.TYPES.WIN_HOLE then
                            EditorInput.editor.level:setCellType(x, y, CellTypes.TYPES.EMPTY)
                        end
                    end
                end
                
                -- Create a diamond-shaped win hole at the clicked position
                local WinHole = require("src.win_hole")
                WinHole.createWinHoleArea(EditorInput.editor.level, gridX - 2, gridY - 2, 5, 5)
            elseif EditorInput.editor.currentTool == "draw" then
                -- Draw with brush
                local cellType = EditorInput.editor.CELL_TYPE_TO_TYPE[EditorInput.editor.currentCellType]
                
                -- Apply brush with size for all cell types
                for y = -EditorInput.editor.brushSize + 1, EditorInput.editor.brushSize - 1 do
                    for x = -EditorInput.editor.brushSize + 1, EditorInput.editor.brushSize - 1 do
                        local distance = math.sqrt(x*x + y*y)
                        if distance < EditorInput.editor.brushSize then
                            local cellX = gridX + x
                            local cellY = gridY + y
                            if cellX >= 0 and cellX < EditorInput.editor.level.width and cellY >= 0 and cellY < EditorInput.editor.level.height then
                                EditorInput.editor.level:setCellType(cellX, cellY, cellType)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Handle key press in editor
function EditorInput.handleKeyPressed(key)
    -- Shortcut keys for tools (removed WIN_HOLE shortcut)
    if key == "1" then
        EditorInput.editor.currentTool = "EMPTY"
        EditorInput.editor.setStartPosition = false
        EditorInput.editor.setWinHolePosition = false
        return true
    elseif key == "2" then
        EditorInput.editor.currentTool = "DIRT"
        EditorInput.editor.setStartPosition = false
        EditorInput.editor.setWinHolePosition = false
        return true
    elseif key == "3" then
        EditorInput.editor.currentTool = "SAND"
        EditorInput.editor.setStartPosition = false
        EditorInput.editor.setWinHolePosition = false
        return true
    elseif key == "4" then
        EditorInput.editor.currentTool = "STONE"
        EditorInput.editor.setStartPosition = false
        EditorInput.editor.setWinHolePosition = false
        return true
    elseif key == "5" then
        EditorInput.editor.currentTool = "WATER"
        EditorInput.editor.setStartPosition = false
        EditorInput.editor.setWinHolePosition = false
        return true
    elseif key == "=" or key == "+" then
        -- Increase brush size
        local sizes = {1, 2, 3, 5, 7}
        for i, size in ipairs(sizes) do
            if EditorInput.editor.brushSize == size and i < #sizes then
                EditorInput.editor.brushSize = sizes[i+1]
                break
            end
        end
        return true
    elseif key == "-" then
        -- Decrease brush size
        local sizes = {1, 2, 3, 5, 7}
        for i, size in ipairs(sizes) do
            if EditorInput.editor.brushSize == size and i > 1 then
                EditorInput.editor.brushSize = sizes[i-1]
                break
            end
        end
        return true
    elseif key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Save level
        EditorInput.editor.saveLevel()
        return true
    elseif key == "l" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Load level
        EditorInput.editor.loadLevel()
        return true
    elseif key == "g" then
        -- Toggle grid
        EditorInput.editor.showGrid = not EditorInput.editor.showGrid
        return true
    elseif key == "escape" then
        -- Exit editor
        EditorInput.editor.active = false
        return true
    end
    
    return false
end

-- Handle key press in text input
function EditorInput.handleTextInputKeyPressed(key)
    if key == "return" or key == "escape" then
        EditorInput.editor.levelName = EditorInput.editor.textInput.text
        EditorInput.editor.textInput.active = false
    elseif key == "backspace" then
        if EditorInput.editor.textInput.cursor > 0 then
            EditorInput.editor.textInput.text = string.sub(EditorInput.editor.textInput.text, 1, EditorInput.editor.textInput.cursor - 1) .. 
                                   string.sub(EditorInput.editor.textInput.text, EditorInput.editor.textInput.cursor + 1)
            EditorInput.editor.textInput.cursor = EditorInput.editor.textInput.cursor - 1
        end
    elseif key == "left" then
        EditorInput.editor.textInput.cursor = math.max(0, EditorInput.editor.textInput.cursor - 1)
    elseif key == "right" then
        EditorInput.editor.textInput.cursor = math.min(#EditorInput.editor.textInput.text, EditorInput.editor.textInput.cursor + 1)
    end
    return true
end

-- Handle key press in file selector
function EditorInput.handleFileSelectorKeyPressed(key)
    if key == "escape" then
        -- Close file selector
        EditorInput.editor.fileSelector.active = false
        return true
    elseif key == "return" then
        -- Confirm selection
        if EditorInput.editor.fileSelector.mode == "save" then
            EditorInput.editor.saveLevel()
        else
            EditorInput.editor.loadLevel()
        end
        return true
    elseif key == "up" then
        -- Move selection up
        EditorInput.editor.fileSelector.selectedIndex = math.max(1, EditorInput.editor.fileSelector.selectedIndex - 1)
        
        -- If in save mode, update the filename
        if EditorInput.editor.fileSelector.mode == "save" and EditorInput.editor.fileSelector.selectedIndex <= #EditorInput.editor.fileSelector.files then
            EditorInput.editor.fileSelector.newFileName = EditorInput.editor.fileSelector.files[EditorInput.editor.fileSelector.selectedIndex].displayName
        end
        
        return true
    elseif key == "down" then
        -- Move selection down
        EditorInput.editor.fileSelector.selectedIndex = math.min(#EditorInput.editor.fileSelector.files, EditorInput.editor.fileSelector.selectedIndex + 1)
        
        -- If in save mode, update the filename
        if EditorInput.editor.fileSelector.mode == "save" and EditorInput.editor.fileSelector.selectedIndex <= #EditorInput.editor.fileSelector.files then
            EditorInput.editor.fileSelector.newFileName = EditorInput.editor.fileSelector.files[EditorInput.editor.fileSelector.selectedIndex].displayName
        end
        
        return true
    elseif key == "backspace" and EditorInput.editor.fileSelector.mode == "save" then
        -- Delete last character in filename
        if #EditorInput.editor.fileSelector.newFileName > 0 then
            EditorInput.editor.fileSelector.newFileName = string.sub(EditorInput.editor.fileSelector.newFileName, 1, -2)
        end
        return true
    end
    
    return false
end

-- Handle text input
function EditorInput.handleTextInput(text)
    if EditorInput.editor.textInput.active then
        -- Insert text at cursor position
        EditorInput.editor.textInput.text = string.sub(EditorInput.editor.textInput.text, 1, EditorInput.editor.textInput.cursor) .. 
                               text .. 
                               string.sub(EditorInput.editor.textInput.text, EditorInput.editor.textInput.cursor + 1)
        EditorInput.editor.textInput.cursor = EditorInput.editor.textInput.cursor + #text
        return true
    end
    return false
end

return EditorInput
