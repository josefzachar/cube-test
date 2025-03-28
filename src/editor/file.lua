-- editor/file.lua - File operations for the Square Golf editor

local CellTypes = require("src.cell_types")

local EditorFile = {
    editor = nil
}

-- Initialize the file module
function EditorFile.init(editor)
    EditorFile.editor = editor
    
    -- Create levels directory if it doesn't exist
    love.filesystem.createDirectory("levels")
end

-- Draw the file selector
function EditorFile.drawFileSelector()
    if not EditorFile.editor.fileSelector.active then
        return
    end
    
    -- Get screen dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    
    -- Dialog dimensions
    local dialogWidth = 500
    local dialogHeight = 400
    local dialogX = (gameWidth - dialogWidth) / 2
    local dialogY = (gameHeight - dialogHeight) / 2
    
    -- Draw dialog background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", dialogX, dialogY, dialogWidth, dialogHeight)
    
    -- Draw dialog border
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX, dialogY, dialogWidth, dialogHeight)
    
    -- Draw dialog title
    love.graphics.setColor(1, 1, 1, 1)
    local title = EditorFile.editor.fileSelector.mode == "save" and "Save Level" or "Load Level"
    love.graphics.print(title, dialogX + 20, dialogY + 20)
    
    -- Draw file list
    local fileListY = dialogY + 60
    local fileListHeight = dialogHeight - 120
    local fileItemHeight = 30
    
    -- Draw file list background
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", dialogX + 20, fileListY, dialogWidth - 40, fileListHeight)
    
    -- Draw file list border
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX + 20, fileListY, dialogWidth - 40, fileListHeight)
    
    -- Draw files
    love.graphics.setColor(1, 1, 1, 1)
    local visibleFiles = math.floor(fileListHeight / fileItemHeight)
    local startIndex = math.max(1, EditorFile.editor.fileSelector.selectedIndex - math.floor(visibleFiles / 2))
    startIndex = math.min(startIndex, math.max(1, #EditorFile.editor.fileSelector.files - visibleFiles + 1))
    
    for i = 0, visibleFiles - 1 do
        local fileIndex = startIndex + i
        if fileIndex <= #EditorFile.editor.fileSelector.files then
            local file = EditorFile.editor.fileSelector.files[fileIndex]
            
            -- Draw selection highlight
            if fileIndex == EditorFile.editor.fileSelector.selectedIndex then
                love.graphics.setColor(0.3, 0.3, 0.6, 1)
                love.graphics.rectangle("fill", dialogX + 20, fileListY + i * fileItemHeight, dialogWidth - 40, fileItemHeight)
            end
            
            -- Draw file name
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(file.displayName, dialogX + 30, fileListY + i * fileItemHeight + 5)
        end
    end
    
    -- Draw buttons
    local buttonWidth = 100
    local buttonHeight = 30
    local buttonSpacing = 20
    local buttonsY = dialogY + dialogHeight - 50
    
    -- Draw OK button
    love.graphics.setColor(0.2, 0.2, 0.4, 1)
    love.graphics.rectangle("fill", dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing, buttonsY, buttonWidth, buttonHeight)
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing, buttonsY, buttonWidth, buttonHeight)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("OK", dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing + 40, buttonsY + 5)
    
    -- Draw Cancel button
    love.graphics.setColor(0.2, 0.2, 0.4, 1)
    love.graphics.rectangle("fill", dialogX + dialogWidth - buttonWidth - buttonSpacing, buttonsY, buttonWidth, buttonHeight)
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX + dialogWidth - buttonWidth - buttonSpacing, buttonsY, buttonWidth, buttonHeight)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Cancel", dialogX + dialogWidth - buttonWidth - buttonSpacing + 25, buttonsY + 5)
    
    -- Draw filename input for save mode
    if EditorFile.editor.fileSelector.mode == "save" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Filename:", dialogX + 20, buttonsY - 40)
        
        -- Draw input background
        love.graphics.setColor(0.1, 0.1, 0.2, 1)
        love.graphics.rectangle("fill", dialogX + 100, buttonsY - 40, dialogWidth - 120, 25)
        
        -- Draw input border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", dialogX + 100, buttonsY - 40, dialogWidth - 120, 25)
        
        -- Draw input text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(EditorFile.editor.fileSelector.newFileName, dialogX + 110, buttonsY - 35)
    end
end

-- Refresh the list of level files
function EditorFile.refreshFileList()
    -- Get list of level files
    local files = love.filesystem.getDirectoryItems("levels")
    EditorFile.editor.fileSelector.files = {}
    
    for _, file in ipairs(files) do
        if string.match(file, "%.json$") then
            -- Remove .json extension and replace underscores with spaces
            local displayName = string.gsub(string.sub(file, 1, -6), "_", " ")
            table.insert(EditorFile.editor.fileSelector.files, {
                filename = file,
                displayName = displayName
            })
        end
    end
    
    -- Sort files alphabetically
    table.sort(EditorFile.editor.fileSelector.files, function(a, b)
        return a.displayName < b.displayName
    end)
end

-- Save the current level
function EditorFile.saveLevel()
    -- If file selector is not active, show it
    if not EditorFile.editor.fileSelector.active then
        EditorFile.showFileSelector("save")
        return
    end
    
    -- Get filename from file selector
    local levelName = EditorFile.editor.fileSelector.newFileName
    if levelName == "" then
        levelName = "Untitled Level"
    end
    
    -- Update level name
    EditorFile.editor.levelName = levelName
    
    -- Create level data table
    local levelData = {
        name = EditorFile.editor.levelName,
        width = EditorFile.editor.level.width,
        height = EditorFile.editor.level.height,
        startX = EditorFile.editor.startX,
        startY = EditorFile.editor.startY,
        winHoleX = EditorFile.editor.winHoleX,
        winHoleY = EditorFile.editor.winHoleY,
        availableBalls = EditorFile.editor.availableBalls,
        cells = {}
    }
    
    -- Save cell data
    for y = 0, EditorFile.editor.level.height - 1 do
        levelData.cells[y] = {}
        for x = 0, EditorFile.editor.level.width - 1 do
            levelData.cells[y][x] = EditorFile.editor.level:getCellType(x, y)
        end
    end
    
    -- Serialize to JSON
    local json = require("src.json")
    local levelJson = json.encode(levelData)
    
    -- Save to file
    local filename = "levels/" .. string.gsub(EditorFile.editor.levelName, " ", "_") .. ".json"
    
    -- Create levels directory if it doesn't exist
    love.filesystem.createDirectory("levels")
    
    -- Write to file
    local success, message = love.filesystem.write(filename, levelJson)
    
    if success then
        print("Level saved to " .. filename)
    else
        print("Failed to save level: " .. message)
    end
    
    -- Close file selector
    EditorFile.editor.fileSelector.active = false
end

-- Helper function to ensure cell type is a valid CellTypes.TYPES value
function EditorFile.validateCellType(cellType)
    -- Check if the cell type is already a valid numeric value
    if type(cellType) == "number" and 
       (cellType == CellTypes.TYPES.EMPTY or
        cellType == CellTypes.TYPES.SAND or
        cellType == CellTypes.TYPES.STONE or
        cellType == CellTypes.TYPES.VISUAL_SAND or
        cellType == CellTypes.TYPES.WATER or
        cellType == CellTypes.TYPES.DIRT or
        cellType == CellTypes.TYPES.VISUAL_DIRT or
        cellType == CellTypes.TYPES.FIRE or
        cellType == CellTypes.TYPES.SMOKE or
        cellType == CellTypes.TYPES.WIN_HOLE) then
        return cellType
    end
    
    -- If not a valid numeric value, return EMPTY as default
    print("Invalid cell type: " .. tostring(cellType) .. ", using EMPTY instead")
    return CellTypes.TYPES.EMPTY
end

-- Load a level
function EditorFile.loadLevel()
    -- If file selector is not active, show it
    if not EditorFile.editor.fileSelector.active then
        EditorFile.showFileSelector("load")
        return
    end
    
    -- Check if there are any files to load
    if #EditorFile.editor.fileSelector.files == 0 then
        print("No level files found in levels directory")
        EditorFile.editor.fileSelector.active = false
        return
    end
    
    -- Get selected file
    local selectedFile = EditorFile.editor.fileSelector.files[EditorFile.editor.fileSelector.selectedIndex]
    if not selectedFile then
        print("No file selected")
        EditorFile.editor.fileSelector.active = false
        return
    end
    
    -- Read file
    local filename = "levels/" .. selectedFile.filename
    local contents, size = love.filesystem.read(filename)
    
    if not contents then
        print("Failed to read level file: " .. filename)
        EditorFile.editor.fileSelector.active = false
        return
    end
    
    -- Parse JSON
    local json = require("src.json")
    local levelData = json.decode(contents)
    
    -- Debug output
    print("Loaded level data: " .. contents)
    
    -- Clear current level
    EditorFile.editor.level:clearAllCells()
    
    -- Set level properties
    EditorFile.editor.levelName = levelData.name
    EditorFile.editor.startX = levelData.startX
    EditorFile.editor.startY = levelData.startY
    EditorFile.editor.winHoleX = levelData.winHoleX or 140
    EditorFile.editor.winHoleY = levelData.winHoleY or 20
    
    -- Set available balls
    if levelData.availableBalls then
        EditorFile.editor.availableBalls.standard = levelData.availableBalls.standard or true
        EditorFile.editor.availableBalls.heavy = levelData.availableBalls.heavy or false
        EditorFile.editor.availableBalls.exploding = levelData.availableBalls.exploding or false
        EditorFile.editor.availableBalls.sticky = levelData.availableBalls.sticky or false
    end
    
    -- Load cells
    if levelData.cells then
        -- Debug output
        print("Loading cells from level data")
        
        -- Count cells
        local cellCount = 0
        
        -- Iterate through all rows in the cells object
        for y_str, row in pairs(levelData.cells) do
            -- Convert string y index to number
            local y = tonumber(y_str)
            
            -- Iterate through all columns in the row
            for x_str, cellType in pairs(row) do
                -- Convert string x index to number
                local x = tonumber(x_str)
                
                -- Validate cell type
                local validCellType = EditorFile.validateCellType(cellType)
                
                -- Debug print to check cell type
                print("Setting cell at " .. x .. "," .. y .. " to type " .. validCellType)
                
                -- Set cell type
                EditorFile.editor.level:setCellType(x, y, validCellType)
                
                -- Increment cell count
                cellCount = cellCount + 1
            end
        end
        
        -- Debug output
        print("Loaded " .. cellCount .. " cells")
    else
        print("Warning: No cells data found in level file")
    end
    
    print("Level loaded from " .. filename)
    
    -- Close file selector
    EditorFile.editor.fileSelector.active = false
end

-- Show file selector
function EditorFile.showFileSelector(mode)
    -- Initialize file selector if not already done
    if not EditorFile.editor.fileSelector then
        EditorFile.editor.fileSelector = {
            active = false,
            mode = "load",
            files = {},
            selectedIndex = 1,
            newFileName = ""
        }
    end
    
    -- Set file selector mode
    EditorFile.editor.fileSelector.mode = mode
    EditorFile.editor.fileSelector.active = true
    EditorFile.editor.fileSelector.selectedIndex = 1
    
    -- Refresh file list
    EditorFile.refreshFileList()
    
    -- Set default filename for save mode
    if mode == "save" then
        EditorFile.editor.fileSelector.newFileName = EditorFile.editor.levelName
    end
end

-- Handle key press for file operations
function EditorFile.handleKeyPressed(key)
    -- Save level with Ctrl+S
    if key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        EditorFile.saveLevel()
        return true
    end
    
    -- Load level with Ctrl+L
    if key == "l" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        EditorFile.loadLevel()
        return true
    end
    
    -- Handle file selector key presses
    if EditorFile.editor.fileSelector and EditorFile.editor.fileSelector.active then
        if key == "escape" then
            EditorFile.editor.fileSelector.active = false
            return true
        elseif key == "return" then
            if EditorFile.editor.fileSelector.mode == "save" then
                EditorFile.saveLevel()
            else
                EditorFile.loadLevel()
            end
            return true
        elseif key == "up" then
            EditorFile.editor.fileSelector.selectedIndex = math.max(1, EditorFile.editor.fileSelector.selectedIndex - 1)
            return true
        elseif key == "down" then
            EditorFile.editor.fileSelector.selectedIndex = math.min(#EditorFile.editor.fileSelector.files, EditorFile.editor.fileSelector.selectedIndex + 1)
            return true
        elseif key == "backspace" and EditorFile.editor.fileSelector.mode == "save" then
            if #EditorFile.editor.fileSelector.newFileName > 0 then
                EditorFile.editor.fileSelector.newFileName = string.sub(EditorFile.editor.fileSelector.newFileName, 1, -2)
            end
            return true
        end
    end
    
    return false
end

-- Handle text input for file operations
function EditorFile.handleTextInput(text)
    -- Handle file selector text input
    if EditorFile.editor.fileSelector and EditorFile.editor.fileSelector.active and EditorFile.editor.fileSelector.mode == "save" then
        EditorFile.editor.fileSelector.newFileName = EditorFile.editor.fileSelector.newFileName .. text
        return true
    end
    
    return false
end

-- Handle mouse press in file selector
function EditorFile.handleMousePressed(x, y, button)
    if not EditorFile.editor.fileSelector.active then
        return false
    end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = EditorFile.editor.screenToGameCoords(x, y)
    
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
        local startIndex = math.max(1, EditorFile.editor.fileSelector.selectedIndex - math.floor(visibleFiles / 2))
        startIndex = math.min(startIndex, math.max(1, #EditorFile.editor.fileSelector.files - visibleFiles + 1))
        
        local clickedIndex = startIndex + math.floor((gameY - fileListY) / fileItemHeight)
        if clickedIndex >= 1 and clickedIndex <= #EditorFile.editor.fileSelector.files then
            EditorFile.editor.fileSelector.selectedIndex = clickedIndex
            
            -- If in save mode, update the filename
            if EditorFile.editor.fileSelector.mode == "save" then
                EditorFile.editor.fileSelector.newFileName = EditorFile.editor.fileSelector.files[clickedIndex].displayName
            end
            
            return true
        end
    end
    
    -- Button dimensions
    local buttonWidth = 100
    local buttonHeight = 30
    local buttonSpacing = 20
    local buttonsY = dialogY + dialogHeight - 50
    
    -- Check if clicking OK button
    if gameX >= dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing and
       gameX <= dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonSpacing and
       gameY >= buttonsY and gameY <= buttonsY + buttonHeight then
        -- OK button clicked
        if EditorFile.editor.fileSelector.mode == "save" then
            EditorFile.saveLevel()
        else
            EditorFile.loadLevel()
        end
        return true
    end
    
    -- Check if clicking Cancel button
    if gameX >= dialogX + dialogWidth - buttonWidth - buttonSpacing and
       gameX <= dialogX + dialogWidth - buttonSpacing and
       gameY >= buttonsY and gameY <= buttonsY + buttonHeight then
        -- Cancel button clicked
        EditorFile.editor.fileSelector.active = false
        return true
    end
    
    -- If clicking outside the dialog, close it
    if gameX < dialogX or gameX > dialogX + dialogWidth or
       gameY < dialogY or gameY > dialogY + dialogHeight then
        EditorFile.editor.fileSelector.active = false
        return true
    end
    
    return false
end

return EditorFile
