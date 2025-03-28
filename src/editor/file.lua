-- editor/file.lua - File operations for the Square Golf editor

local CellTypes = require("src.cell_types")

local EditorFile = {}

-- Initialize the file module
function EditorFile.init(Editor)
    -- Nothing to initialize for now
end

-- Save the current level
function EditorFile.saveLevel(Editor)
    -- Create level data table
    local levelData = {
        name = Editor.levelName,
        width = Editor.level.width,
        height = Editor.level.height,
        startX = Editor.startX,
        startY = Editor.startY,
        winHoleX = Editor.winHoleX,
        winHoleY = Editor.winHoleY,
        availableBalls = Editor.availableBalls,
        cells = {}
    }
    
    -- Save cell data
    for y = 0, Editor.level.height - 1 do
        levelData.cells[y] = {}
        for x = 0, Editor.level.width - 1 do
            levelData.cells[y][x] = Editor.level.cells[y][x].type
        end
    end
    
    -- Serialize to JSON
    local json = require("src.json")
    local levelJson = json.encode(levelData)
    
    -- Save to file
    local filename = "levels/" .. string.gsub(Editor.levelName, " ", "_") .. ".json"
    
    -- Create levels directory if it doesn't exist
    love.filesystem.createDirectory("levels")
    
    -- Write to file
    local success, message = love.filesystem.write(filename, levelJson)
    
    if success then
        print("Level saved to " .. filename)
    else
        print("Failed to save level: " .. message)
    end
end

-- Load a level
function EditorFile.loadLevel(Editor)
    -- Get list of level files
    local files = love.filesystem.getDirectoryItems("levels")
    local levelFiles = {}
    
    for _, file in ipairs(files) do
        if string.match(file, "%.json$") then
            table.insert(levelFiles, file)
        end
    end
    
    -- If no levels found
    if #levelFiles == 0 then
        print("No level files found in levels directory")
        return
    end
    
    -- For now, just load the first level file
    -- In a real implementation, you'd show a file selection dialog
    local filename = "levels/" .. levelFiles[1]
    
    -- Read file
    local contents, size = love.filesystem.read(filename)
    
    if not contents then
        print("Failed to read level file: " .. filename)
        return
    end
    
    -- Parse JSON
    local json = require("src.json")
    local levelData = json.decode(contents)
    
    -- Clear current level
    Editor.clearLevel()
    
    -- Set level properties
    Editor.levelName = levelData.name
    Editor.startX = levelData.startX
    Editor.startY = levelData.startY
    Editor.winHoleX = levelData.winHoleX or 140
    Editor.winHoleY = levelData.winHoleY or 20
    Editor.availableBalls = levelData.availableBalls
    
    -- Load cells
    for y = 0, levelData.height - 1 do
        for x = 0, levelData.width - 1 do
            if levelData.cells[y] and levelData.cells[y][x] then
                Editor.level:setCellType(x, y, levelData.cells[y][x])
            end
        end
    end
    
    print("Level loaded from " .. filename)
end

return EditorFile
