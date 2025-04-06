-- editor/file_operations.lua - File operations for the Square Golf editor

local CellTypes = require("src.cell_types")

local FileOperations = {}

-- Helper function to ensure cell type is a valid CellTypes.TYPES value
function FileOperations.validateCellType(cellType)
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

-- Save the current level
function FileOperations.saveLevel(editor)
    -- If file selector is not active, show it
    if not editor.fileSelector.active then
        -- This will be handled by the main file.lua
        return false
    end
    
    -- Get filename from file selector
    local levelName = editor.fileSelector.newFileName
    if levelName == "" then
        levelName = "Untitled Level"
    end
    
    -- Update level name
    editor.levelName = levelName
    
    -- Create level data table
    local levelData = {
        name = editor.levelName,
        width = editor.level.width,
        height = editor.level.height,
        startX = editor.startX,
        startY = editor.startY,
        winHoleX = editor.winHoleX,
        winHoleY = editor.winHoleY,
        availableBalls = editor.availableBalls,
        cells = {}
    }
    
    -- Initialize grass on top of dirt cells
    editor.level:initializeGrass()
    
    -- Save cell data
    for y = 0, editor.level.height - 1 do
        levelData.cells[y] = {}
        for x = 0, editor.level.width - 1 do
            levelData.cells[y][x] = editor.level:getCellType(x, y)
        end
    end
    
    -- Serialize to JSON
    local json = require("src.json")
    local levelJson = json.encode(levelData)
    
    -- Save to file
    local filename = "levels/" .. string.gsub(editor.levelName, " ", "_") .. ".json"
    
    -- Create levels directory if it doesn't exist
    love.filesystem.createDirectory("levels")
    
    -- Write to file
    local success, message = love.filesystem.write(filename, levelJson)
    
    -- Also save to the project directory for easier access
    local projectFilename = "/Users/joebrain/cube-test/levels/" .. string.gsub(editor.levelName, " ", "_") .. ".json"
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
    editor.fileSelector.active = false
    
    return true
end

-- Load a level
function FileOperations.loadLevel(editor)
    -- If file selector is not active, show it
    if not editor.fileSelector.active then
        -- This will be handled by the main file.lua
        return false
    end
    
    -- Check if there are any files to load
    if #editor.fileSelector.files == 0 then
        print("No level files found in levels directory")
        editor.fileSelector.active = false
        return true
    end
    
    -- Get selected file
    local selectedFile = editor.fileSelector.files[editor.fileSelector.selectedIndex]
    if not selectedFile then
        print("No file selected")
        editor.fileSelector.active = false
        return true
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
            editor.fileSelector.active = false
            return true
        end
    else
        -- Read from LÖVE save directory
        local filename = "levels/" .. selectedFile.filename
        local size
        contents, size = love.filesystem.read(filename)
        
        if not contents then
            print("Failed to read level file: " .. filename)
            editor.fileSelector.active = false
            return true
        end
    end
    
    -- Parse JSON
    local json = require("src.json")
    local levelData = json.decode(contents)
    
    -- Debug output
    print("Loaded level data: " .. contents)
    
    -- Clear current level
    editor.level:clearAllCells()
    
    -- Set level properties
    editor.levelName = levelData.name
    editor.startX = levelData.startX
    editor.startY = levelData.startY
    editor.winHoleX = levelData.winHoleX or 140
    editor.winHoleY = levelData.winHoleY or 20
    
    -- Set available balls
    if levelData.availableBalls then
        editor.availableBalls.standard = levelData.availableBalls.standard or true
        editor.availableBalls.heavy = levelData.availableBalls.heavy or false
        editor.availableBalls.exploding = levelData.availableBalls.exploding or false
        editor.availableBalls.sticky = levelData.availableBalls.sticky or false
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
                local validCellType = FileOperations.validateCellType(cellType)
                
                -- Debug print to check cell type
                print("Setting cell at " .. x .. "," .. y .. " to type " .. validCellType)
                
                -- Set cell type
                editor.level:setCellType(x, y, validCellType)
                
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
    
    -- Initialize grass on top of dirt cells
    editor.level:initializeGrass()
    
    -- Close file selector
    editor.fileSelector.active = false
    
    return true
end

return FileOperations
