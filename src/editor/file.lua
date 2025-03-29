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
    local dialogWidth = 600
    local dialogHeight = 500
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
    
    -- Draw breadcrumb path
    local breadcrumbY = dialogY + 50
    local breadcrumbX = dialogX + 20
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    
    if EditorFile.editor.fileSelector.breadcrumbs then
        for i, crumb in ipairs(EditorFile.editor.fileSelector.breadcrumbs) do
            -- Draw breadcrumb
            love.graphics.setColor(0.2, 0.5, 0.8, 1)
            local crumbWidth = love.graphics.getFont():getWidth(crumb.name) + 20
            love.graphics.rectangle("fill", breadcrumbX, breadcrumbY, crumbWidth, 20)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(crumb.name, breadcrumbX + 10, breadcrumbY + 2)
            
            -- Store breadcrumb position for click detection
            crumb.x = breadcrumbX
            crumb.y = breadcrumbY
            crumb.width = crumbWidth
            crumb.height = 20
            
            breadcrumbX = breadcrumbX + crumbWidth + 5
            
            -- Draw separator if not the last breadcrumb
            if i < #EditorFile.editor.fileSelector.breadcrumbs then
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
                love.graphics.print(">", breadcrumbX - 3, breadcrumbY + 2)
                breadcrumbX = breadcrumbX + 10
            end
        end
    end
    
    -- Draw file list
    local fileListY = breadcrumbY + 30
    local fileListHeight = dialogHeight - 180
    local fileItemHeight = 30
    
    -- Draw file list background
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", dialogX + 20, fileListY, dialogWidth - 40, fileListHeight)
    
    -- Draw file list border
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX + 20, fileListY, dialogWidth - 40, fileListHeight)
    
    -- Draw files
    local visibleFiles = math.floor(fileListHeight / fileItemHeight)
    local startIndex = math.max(1, EditorFile.editor.fileSelector.selectedIndex - math.floor(visibleFiles / 2))
    startIndex = math.min(startIndex, math.max(1, #EditorFile.editor.fileSelector.files - visibleFiles + 1))
    
    for i = 0, visibleFiles - 1 do
        local fileIndex = startIndex + i
        if fileIndex <= #EditorFile.editor.fileSelector.files then
            local file = EditorFile.editor.fileSelector.files[fileIndex]
            local itemY = fileListY + i * fileItemHeight
            
            -- Draw selection highlight
            if fileIndex == EditorFile.editor.fileSelector.selectedIndex then
                love.graphics.setColor(0.3, 0.3, 0.6, 1)
                love.graphics.rectangle("fill", dialogX + 20, itemY, dialogWidth - 40, fileItemHeight)
            end
            
            -- Draw file icon based on type
            love.graphics.setColor(1, 1, 1, 1)
            if file.isDirectory then
                -- Draw folder icon
                love.graphics.setColor(0.9, 0.7, 0.2, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 15)
                love.graphics.setColor(0.7, 0.5, 0.1, 1)
                love.graphics.rectangle("fill", dialogX + 25, itemY + 10, 30, 15)
            elseif file.fileType == "json" then
                -- Draw JSON file icon
                love.graphics.setColor(0.2, 0.6, 0.8, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.print("{ }", dialogX + 32, itemY + 7)
            elseif file.fileType == "lua" then
                -- Draw Lua file icon
                love.graphics.setColor(0.2, 0.2, 0.8, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("lua", dialogX + 32, itemY + 7)
            elseif file.fileType == "audio" then
                -- Draw audio file icon
                love.graphics.setColor(0.8, 0.2, 0.2, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("♪", dialogX + 35, itemY + 7)
            elseif file.fileType == "image" then
                -- Draw image file icon
                love.graphics.setColor(0.2, 0.8, 0.2, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("IMG", dialogX + 32, itemY + 7)
            else
                -- Draw generic file icon
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
            end
            
            -- Draw file name
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(file.displayName, dialogX + 60, itemY + 5)
            
            -- Store file item position for double-click detection
            file.x = dialogX + 20
            file.y = itemY
            file.width = dialogWidth - 40
            file.height = fileItemHeight
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

-- Refresh the list of files
function EditorFile.refreshFileList()
    EditorFile.editor.fileSelector.files = {}
    
    -- Get the current directory
    local currentDir = EditorFile.editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
    print("Looking for files in: " .. currentDir)
    
    -- Add parent directory entry if not at root
    if currentDir ~= "/" then
        table.insert(EditorFile.editor.fileSelector.files, {
            filename = "..",
            displayName = "..",
            isDirectory = true,
            isParentDir = true
        })
    end
    
    -- List directories first
    local dirs = {}
    local dirCmd = io.popen('find "' .. currentDir .. '" -maxdepth 1 -type d -not -path "' .. currentDir .. '" | sort')
    if dirCmd then
        for dir in dirCmd:lines() do
            -- Extract the directory name from the full path
            local dirName = string.match(dir, ".*/([^/]+)$")
            if dirName and dirName ~= "." and dirName ~= ".." then
                table.insert(dirs, {
                    filename = dirName,
                    displayName = dirName,
                    isDirectory = true,
                    fullPath = dir
                })
            end
        end
        dirCmd:close()
    end
    
    -- Sort directories alphabetically
    table.sort(dirs, function(a, b)
        return a.displayName:lower() < b.displayName:lower()
    end)
    
    -- Add directories to the file list
    for _, dir in ipairs(dirs) do
        table.insert(EditorFile.editor.fileSelector.files, dir)
    end
    
    -- List files
    local files = {}
    local fileCmd = io.popen('find "' .. currentDir .. '" -maxdepth 1 -type f | sort')
    if fileCmd then
        for file in fileCmd:lines() do
            -- Extract the file name from the full path
            local fileName = string.match(file, ".*/([^/]+)$")
            if fileName then
                local fileType = "file"
                local displayName = fileName
                
                -- Determine file type based on extension
                if string.match(fileName, "%.json$") then
                    fileType = "json"
                    -- For JSON files, remove extension and replace underscores with spaces
                    displayName = string.gsub(string.sub(fileName, 1, -6), "_", " ")
                elseif string.match(fileName, "%.lua$") then
                    fileType = "lua"
                elseif string.match(fileName, "%.txt$") then
                    fileType = "text"
                elseif string.match(fileName, "%.mp3$") or string.match(fileName, "%.wav$") then
                    fileType = "audio"
                elseif string.match(fileName, "%.png$") or string.match(fileName, "%.jpg$") then
                    fileType = "image"
                end
                
                table.insert(files, {
                    filename = fileName,
                    displayName = displayName,
                    fileType = fileType,
                    fullPath = file
                })
            end
        end
        fileCmd:close()
    end
    
    -- Sort files alphabetically
    table.sort(files, function(a, b)
        return a.displayName:lower() < b.displayName:lower()
    end)
    
    -- Add files to the file list
    for _, file in ipairs(files) do
        table.insert(EditorFile.editor.fileSelector.files, file)
    end
    
    -- Update breadcrumb path
    EditorFile.updateBreadcrumbPath()
end

-- Update the breadcrumb path display
function EditorFile.updateBreadcrumbPath()
    local currentDir = EditorFile.editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
    
    -- Split the path into components
    local pathComponents = {}
    for component in string.gmatch(currentDir, "[^/]+") do
        table.insert(pathComponents, component)
    end
    
    -- Create breadcrumb path
    local breadcrumbPath = "/"
    EditorFile.editor.fileSelector.breadcrumbs = {
        { path = "/", name = "Root" }
    }
    
    local currentPath = ""
    for i, component in ipairs(pathComponents) do
        currentPath = currentPath .. "/" .. component
        table.insert(EditorFile.editor.fileSelector.breadcrumbs, {
            path = currentPath,
            name = component
        })
        breadcrumbPath = breadcrumbPath .. component .. "/"
    end
    
    EditorFile.editor.fileSelector.breadcrumbPath = breadcrumbPath
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
    
    -- Also save to the project directory for easier access
    local projectFilename = "/Users/joebrain/cube-test/levels/" .. string.gsub(EditorFile.editor.levelName, " ", "_") .. ".json"
    print("Saving level to project directory: " .. projectFilename)
    local file = io.open(projectFilename, "w")
    if file then
        file:write(levelJson)
        file:close()
        print("Level also saved to project directory: " .. projectFilename)
    else
        print("Failed to save level to project directory")
    end
    
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
    
    local contents
    
    -- Check if this is a project file or a LÖVE save file
    if selectedFile.isProjectFile then
        -- Read from project directory
        local projectFilename = love.filesystem.getSourceBaseDirectory() .. "/cube-test/levels/" .. selectedFile.filename
        print("Loading level from project directory: " .. projectFilename)
        local file = io.open(projectFilename, "r")
        if file then
            contents = file:read("*all")
            file:close()
            print("Loading level from project directory: " .. projectFilename)
        else
            print("Failed to read level file from project directory: " .. projectFilename)
            EditorFile.editor.fileSelector.active = false
            return
        end
    else
        -- Read from LÖVE save directory
        local filename = "levels/" .. selectedFile.filename
        local size
        contents, size = love.filesystem.read(filename)
        
        if not contents then
            print("Failed to read level file: " .. filename)
            EditorFile.editor.fileSelector.active = false
            return
        end
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
    
    print("Level loaded successfully")
    
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
            newFileName = "",
            currentDir = "/Users/joebrain/cube-test",
            breadcrumbs = {},
            lastClickTime = 0,
            lastClickIndex = 0
        }
    end
    
    -- Set file selector mode
    EditorFile.editor.fileSelector.mode = mode
    EditorFile.editor.fileSelector.active = true
    EditorFile.editor.fileSelector.selectedIndex = 1
    
    -- If in save mode, navigate to levels directory
    if mode == "save" and not EditorFile.editor.fileSelector.inLevelsDir then
        EditorFile.navigateToDirectory("/Users/joebrain/cube-test/levels")
        EditorFile.editor.fileSelector.inLevelsDir = true
    else
        -- Refresh file list
        EditorFile.refreshFileList()
    end
    
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

-- Navigate to a directory
function EditorFile.navigateToDirectory(dirPath)
    -- Update current directory
    EditorFile.editor.fileSelector.currentDir = dirPath
    
    -- Reset selected index
    EditorFile.editor.fileSelector.selectedIndex = 1
    
    -- Refresh file list
    EditorFile.refreshFileList()
    
    print("Navigated to directory: " .. dirPath)
end

-- Handle mouse press in file selector
function EditorFile.handleMousePressed(x, y, button)
    if not EditorFile.editor.fileSelector.active then
        return false
    end
    
    -- Always return true when file selector is active to prevent painting
    -- This ensures that no other mouse handlers will process this event
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = EditorFile.editor.screenToGameCoords(x, y)
    
    -- Get screen dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    
    -- Dialog dimensions
    local dialogWidth = 600
    local dialogHeight = 500
    local dialogX = (gameWidth - dialogWidth) / 2
    local dialogY = (gameHeight - dialogHeight) / 2
    
    -- Check if clicking on breadcrumbs
    if EditorFile.editor.fileSelector.breadcrumbs then
        for _, crumb in ipairs(EditorFile.editor.fileSelector.breadcrumbs) do
            if crumb.x and crumb.y and crumb.width and crumb.height then
                if gameX >= crumb.x and gameX <= crumb.x + crumb.width and
                   gameY >= crumb.y and gameY <= crumb.y + crumb.height then
                    -- Navigate to the clicked breadcrumb path
                    EditorFile.navigateToDirectory(crumb.path)
                    return true
                end
            end
        end
    end
    
    -- File list dimensions
    local breadcrumbY = dialogY + 50
    local fileListY = breadcrumbY + 30
    local fileListHeight = dialogHeight - 180
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
            local clickedFile = EditorFile.editor.fileSelector.files[clickedIndex]
            EditorFile.editor.fileSelector.selectedIndex = clickedIndex
            
            -- Check for double-click
            local currentTime = love.timer.getTime()
            local lastClickTime = EditorFile.editor.fileSelector.lastClickTime or 0
            local lastClickIndex = EditorFile.editor.fileSelector.lastClickIndex or 0
            
            -- Store current click info for double-click detection
            EditorFile.editor.fileSelector.lastClickTime = currentTime
            EditorFile.editor.fileSelector.lastClickIndex = clickedIndex
            
            -- Check if this is a double-click on the same item
            if currentTime - lastClickTime < 0.5 and clickedIndex == lastClickIndex then
                -- Handle double-click
                if clickedFile.isDirectory then
                    -- Navigate to directory
                    if clickedFile.isParentDir then
                        -- Go to parent directory
                        local currentDir = EditorFile.editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
                        local parentDir = string.match(currentDir, "(.+)/[^/]+$") or "/"
                        EditorFile.navigateToDirectory(parentDir)
                    else
                        -- Go to subdirectory
                        local currentDir = EditorFile.editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
                        local newDir = currentDir .. "/" .. clickedFile.filename
                        EditorFile.navigateToDirectory(newDir)
                    end
                elseif clickedFile.fileType == "json" and EditorFile.editor.fileSelector.mode == "load" then
                    -- Load the JSON file
                    EditorFile.loadLevel()
                end
                return true
            end
            
            -- If in save mode, update the filename
            if EditorFile.editor.fileSelector.mode == "save" then
                if not clickedFile.isDirectory then
                    EditorFile.editor.fileSelector.newFileName = clickedFile.displayName
                end
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
            -- Check if selected item is a directory
            local selectedFile = EditorFile.editor.fileSelector.files[EditorFile.editor.fileSelector.selectedIndex]
            if selectedFile and selectedFile.isDirectory then
                -- Navigate to directory
                if selectedFile.isParentDir then
                    -- Go to parent directory
                    local currentDir = EditorFile.editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
                    local parentDir = string.match(currentDir, "(.+)/[^/]+$") or "/"
                    EditorFile.navigateToDirectory(parentDir)
                else
                    -- Go to subdirectory
                    local currentDir = EditorFile.editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
                    local newDir = currentDir .. "/" .. selectedFile.filename
                    EditorFile.navigateToDirectory(newDir)
                end
            else
                -- Load the selected file
                EditorFile.loadLevel()
            end
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
