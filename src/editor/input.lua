-- editor/input.lua - Input handling for the Square Golf editor

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")
local EditorTools = require("src.editor.tools")

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
    -- Use raw screen coordinates for UI elements
    local screenX, screenY = x, y
    
    -- Check if we're clicking on a button
    for _, buttonGroup in ipairs({EditorInput.editor.toolButtons, EditorInput.editor.brushButtons, EditorInput.editor.ballButtons, EditorInput.editor.buttons}) do
        for _, button in ipairs(buttonGroup) do
            if screenX >= button.x and screenX <= button.x + button.width and
               screenY >= button.y and screenY <= button.y + button.height then
                button.action()
                return true
            end
        end
    end
    
    -- If text input is active, clicking outside closes it
    local width, height = love.graphics.getDimensions()
    if EditorInput.editor.textInput.active and 
       (screenX < width/2 - 200 or screenX > width/2 + 200 or
        screenY < height/2 - 50 or screenY > height/2 + 50) then
        
        -- Handle different text input modes
        if EditorInput.editor.textInput.mode == "levelName" then
            EditorInput.editor.levelName = EditorInput.editor.textInput.text
        elseif EditorInput.editor.textInput.mode == "levelWidth" then
            local newWidth = tonumber(EditorInput.editor.textInput.text)
            if newWidth and newWidth >= 20 and newWidth <= 500 then
                EditorInput.editor.resizeLevel(newWidth, EditorInput.editor.level.height)
            end
        elseif EditorInput.editor.textInput.mode == "levelHeight" then
            local newHeight = tonumber(EditorInput.editor.textInput.text)
            if newHeight and newHeight >= 20 and newHeight <= 500 then
                EditorInput.editor.resizeLevel(EditorInput.editor.level.width, newHeight)
            end
        end
        
        EditorInput.editor.textInput.active = false
        return true
    end
    
    return false
end

-- Handle mouse press in file selector
function EditorInput.handleFileSelectorMousePressed(x, y, button)
    -- Use raw screen coordinates for UI elements
    local screenX, screenY = x, y
    
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Dialog dimensions
    local dialogWidth = 500
    local dialogHeight = 400
    local dialogX = (width - dialogWidth) / 2
    local dialogY = (height - dialogHeight) / 2
    
    -- File list dimensions
    local fileListY = dialogY + 60
    local fileListHeight = dialogHeight - 120
    local fileItemHeight = 30
    
    -- Check if clicking in file list
    if screenX >= dialogX + 20 and screenX <= dialogX + dialogWidth - 20 and
       screenY >= fileListY and screenY <= fileListY + fileListHeight then
        -- Calculate which file was clicked
        local visibleFiles = math.floor(fileListHeight / fileItemHeight)
        local startIndex = math.max(1, EditorInput.editor.fileSelector.selectedIndex - math.floor(visibleFiles / 2))
        startIndex = math.min(startIndex, math.max(1, #EditorInput.editor.fileSelector.files - visibleFiles + 1))
        
        local clickedIndex = startIndex + math.floor((screenY - fileListY) / fileItemHeight)
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
    if screenX >= dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing and
       screenX <= dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonSpacing and
       screenY >= buttonsY and screenY <= buttonsY + buttonHeight then
        -- OK button clicked
        if EditorInput.editor.fileSelector.mode == "save" then
            EditorInput.editor.saveLevel()
        else
            EditorInput.editor.loadLevel()
        end
        return true
    end
    
    -- Check if clicking Cancel button
    if screenX >= dialogX + dialogWidth - buttonWidth - buttonSpacing and
       screenX <= dialogX + dialogWidth - buttonSpacing and
       screenY >= buttonsY and screenY <= buttonsY + buttonHeight then
        -- Cancel button clicked
        EditorInput.editor.fileSelector.active = false
        return true
    end
    
    -- If clicking outside the dialog, close it
    if screenX < dialogX or screenX > dialogX + dialogWidth or
       screenY < dialogY or screenY > dialogY + dialogHeight then
        EditorInput.editor.fileSelector.active = false
        return true
    end
    
    return false
end

-- Handle mouse drag for drawing
function EditorInput.handleMouseDrag(dt)
    -- Check if text input or file selector is active
    if EditorInput.editor.textInput.active or EditorInput.editor.fileSelector.active then
        return
    end
    
    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = EditorInput.editor.screenToGameCoords(mouseX, mouseY)
    local gridX, gridY = EditorInput.editor.level:getGridCoordinates(gameX, gameY)
    
    -- Check if mouse is in the level area and not over UI
    local width = love.graphics.getWidth()
    if gridX < 0 or gridX >= EditorInput.editor.level.width or gridY < 0 or gridY >= EditorInput.editor.level.height or
       gameX <= 140 or gameX >= width - 140 then
        return
    end
    
    -- Left mouse button - draw or use current tool
    if love.mouse.isDown(1) then
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
            WinHole.createWinHoleArea(EditorInput.editor.level, gridX, gridY, 5, 5)
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
    -- Right mouse button - erase
    elseif love.mouse.isDown(2) then
        -- Erase with brush
        local emptyType = EditorInput.editor.CELL_TYPE_TO_TYPE["EMPTY"]
        
        -- Apply brush with size
        for y = -EditorInput.editor.brushSize + 1, EditorInput.editor.brushSize - 1 do
            for x = -EditorInput.editor.brushSize + 1, EditorInput.editor.brushSize - 1 do
                local distance = math.sqrt(x*x + y*y)
                if distance < EditorInput.editor.brushSize then
                    local cellX = gridX + x
                    local cellY = gridY + y
                    if cellX >= 0 and cellX < EditorInput.editor.level.width and cellY >= 0 and cellY < EditorInput.editor.level.height then
                        EditorInput.editor.level:setCellType(cellX, cellY, emptyType)
                    end
                end
            end
        end
    end
end

-- Handle key press in editor
function EditorInput.handleKeyPressed(key)
    -- If editor tools handles the key press, return
    if EditorTools.handleKeyPressed(key) then
        return true
    end
    
    -- Otherwise, handle other editor key presses
    if key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Save level
        EditorInput.editor.saveLevel()
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
    if key == "return" then
        -- Handle different text input modes
        if EditorInput.editor.textInput.mode == "levelName" then
            EditorInput.editor.levelName = EditorInput.editor.textInput.text
        elseif EditorInput.editor.textInput.mode == "levelWidth" then
            local newWidth = tonumber(EditorInput.editor.textInput.text)
            if newWidth and newWidth >= 20 and newWidth <= 500 then
                EditorInput.editor.resizeLevel(newWidth, EditorInput.editor.level.height)
            end
        elseif EditorInput.editor.textInput.mode == "levelHeight" then
            local newHeight = tonumber(EditorInput.editor.textInput.text)
            if newHeight and newHeight >= 20 and newHeight <= 500 then
                EditorInput.editor.resizeLevel(EditorInput.editor.level.width, newHeight)
            end
        elseif EditorInput.editor.textInput.mode == "levelSize" then
            -- Parse width and height from format "width,height"
            local width, height = EditorInput.editor.textInput.text:match("(%d+),(%d+)")
            width = tonumber(width)
            height = tonumber(height)
            
            if width and height and width >= 20 and width <= 500 and height >= 20 and height <= 500 then
                EditorInput.editor.resizeLevel(width, height)
            end
        end
        EditorInput.editor.textInput.active = false
    elseif key == "escape" then
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

-- Handle mouse wheel movement
function EditorInput.handleMouseWheel(x, y)
    -- If text input or file selector is active, don't handle mouse wheel
    if EditorInput.editor.textInput.active or EditorInput.editor.fileSelector.active then
        return false
    end
    
    -- Get camera module
    local EditorCamera = require("src.editor.camera")
    
    -- Check if Ctrl key is pressed for zooming
    if love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl") then
        -- Zoom with mouse wheel
        if y > 0 then
            -- Wheel up - zoom in
            EditorCamera.zoom = math.min(EditorCamera.zoom * 1.1, 5.0) -- Max zoom 5x
        elseif y < 0 then
            -- Wheel down - zoom out
            EditorCamera.zoom = math.max(EditorCamera.zoom * 0.9, 0.2) -- Min zoom 0.2x
        end
        
        -- Draw zoom indicator
        print("Zoom level: " .. string.format("%.2f", EditorCamera.zoom) .. "x")
        
        return true
    end
    
    -- Change brush size with mouse wheel (when Ctrl is not pressed)
    local sizes = {1, 2, 3, 5, 7}
    local currentSize = EditorInput.editor.brushSize
    local currentIndex = 1
    
    -- Find current size index
    for i, size in ipairs(sizes) do
        if size == currentSize then
            currentIndex = i
            break
        end
    end
    
    -- Adjust size based on wheel direction
    if y > 0 then
        -- Wheel up - increase size
        if currentIndex < #sizes then
            EditorInput.editor.brushSize = sizes[currentIndex + 1]
        end
    elseif y < 0 then
        -- Wheel down - decrease size
        if currentIndex > 1 then
            EditorInput.editor.brushSize = sizes[currentIndex - 1]
        end
    end
    
    return true
end

return EditorInput
