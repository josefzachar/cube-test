-- editor/level.lua - Level manipulation for the Square Golf editor

local CellTypes = require("src.cell_types")
local Balls = require("src.balls")
local Cell = require("cell")

local EditorLevel = {
    editor = nil
}

-- Initialize the level module
function EditorLevel.init(editor)
    EditorLevel.editor = editor
end

-- Resize the level
function EditorLevel.resizeLevel(newWidth, newHeight)
    -- Validate new dimensions
    newWidth = math.max(20, math.min(500, newWidth))
    newHeight = math.max(20, math.min(500, newHeight))
    
    -- Create a new level with the new dimensions
    local newLevel = require("level").new(EditorLevel.editor.world, newWidth, newHeight)
    
    -- Copy cells from the old level to the new level
    for y = 0, math.min(EditorLevel.editor.level.height - 1, newHeight - 1) do
        for x = 0, math.min(EditorLevel.editor.level.width - 1, newWidth - 1) do
            local cellType = EditorLevel.editor.level:getCellType(x, y)
            if cellType then
                newLevel:setCellType(x, y, cellType)
            end
        end
    end
    
    -- Ensure start position is within the new level bounds
    EditorLevel.editor.startX = math.min(EditorLevel.editor.startX, newWidth - 1)
    EditorLevel.editor.startY = math.min(EditorLevel.editor.startY, newHeight - 1)
    
    -- Ensure win hole position is within the new level bounds
    if EditorLevel.editor.winHoleX and EditorLevel.editor.winHoleY then
        EditorLevel.editor.winHoleX = math.min(EditorLevel.editor.winHoleX, newWidth - 1)
        EditorLevel.editor.winHoleY = math.min(EditorLevel.editor.winHoleY, newHeight - 1)
    end
    
    -- Destroy the old level
    EditorLevel.editor.level:destroy()
    
    -- Set the new level
    EditorLevel.editor.level = newLevel
    
    -- Initialize grass on top of dirt cells
    EditorLevel.editor.level:initializeGrass()
    
    print("Level resized to " .. newWidth .. "x" .. newHeight)
end

-- Save the current level
function EditorLevel.saveLevel(filename)
    -- Create level data
    local levelData = {
        name = EditorLevel.editor.levelName,
        width = EditorLevel.editor.level.width,
        height = EditorLevel.editor.level.height,
        startX = EditorLevel.editor.startX,
        startY = EditorLevel.editor.startY,
        winHoleX = EditorLevel.editor.winHoleX,
        winHoleY = EditorLevel.editor.winHoleY,
        availableBalls = {
            standard = EditorLevel.editor.availableBalls.standard,
            heavy = EditorLevel.editor.availableBalls.heavy,
            exploding = EditorLevel.editor.availableBalls.exploding,
            sticky = EditorLevel.editor.availableBalls.sticky
        },
        cells = {},
        boulders = {}
    }
    
    -- Save cell data
    for y = 0, EditorLevel.editor.level.height - 1 do
        levelData.cells[y] = {}
        for x = 0, EditorLevel.editor.level.width - 1 do
            levelData.cells[y][x] = EditorLevel.editor.level:getCellType(x, y)
        end
    end
    
    -- Save boulder data
    if EditorLevel.editor.level.boulders then
        for i, boulder in ipairs(EditorLevel.editor.level.boulders) do
            local x, y = boulder:getPosition()
            table.insert(levelData.boulders, {
                x = x,
                y = y,
                size = boulder.size
            })
        end
    end
    
    -- Save to file
    local json = require("src.json")
    local jsonString = json.encode(levelData)
    
    -- Create levels directory if it doesn't exist
    if not love.filesystem.getInfo("levels") then
        love.filesystem.createDirectory("levels")
    end
    
    -- Write to file
    local success, message = love.filesystem.write("levels/" .. filename, jsonString)
    
    if success then
        print("Level saved to: levels/" .. filename)
        return true
    else
        print("Failed to save level: " .. message)
        return false
    end
end

-- Load a level
function EditorLevel.loadLevel(filename)
    -- Read file
    local contents, size = love.filesystem.read("levels/" .. filename)
    
    if not contents then
        print("Failed to read level file: " .. filename)
        return false
    end
    
    -- Parse JSON
    local json = require("src.json")
    local levelData = json.decode(contents)
    
    -- Clear the level
    EditorLevel.editor.level:clearAllCells()
    
    -- Set level properties
    EditorLevel.editor.levelName = levelData.name or "Unnamed Level"
    EditorLevel.editor.startX = levelData.startX or 20
    EditorLevel.editor.startY = levelData.startY or 20
    EditorLevel.editor.winHoleX = levelData.winHoleX or 140
    EditorLevel.editor.winHoleY = levelData.winHoleY or 20
    
    -- Set available balls
    if levelData.availableBalls then
        EditorLevel.editor.availableBalls.standard = levelData.availableBalls.standard or true
        EditorLevel.editor.availableBalls.heavy = levelData.availableBalls.heavy or false
        EditorLevel.editor.availableBalls.exploding = levelData.availableBalls.exploding or false
        EditorLevel.editor.availableBalls.sticky = levelData.availableBalls.sticky or false
    end
    
    -- Set cell data
    local height = tonumber(levelData.height) or EditorLevel.editor.level.height
    local width = tonumber(levelData.width) or EditorLevel.editor.level.width
    
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            if levelData.cells[y] and levelData.cells[y][x] then
                EditorLevel.editor.level:setCellType(x, y, levelData.cells[y][x])
            end
        end
    end
    
    -- Load boulder data
    if levelData.boulders then
        -- Clear existing boulders
        if EditorLevel.editor.level.boulders then
            for _, boulder in ipairs(EditorLevel.editor.level.boulders) do
                if boulder.body then
                    boulder.body:destroy()
                end
            end
            EditorLevel.editor.level.boulders = {}
        end
        
        -- Create new boulders
        local Boulder = require("src.boulder")
        for _, boulderData in ipairs(levelData.boulders) do
            local boulder = Boulder.new(EditorLevel.editor.world, boulderData.x, boulderData.y, boulderData.size)
            table.insert(EditorLevel.editor.level.boulders, boulder)
        end
    end
    
    -- Initialize grass on top of dirt cells
    EditorLevel.editor.level:initializeGrass()
    
    print("Level loaded from: levels/" .. filename)
    return true
end

-- Clear the level
function EditorLevel.clearLevel()
    -- Clear all cells
    EditorLevel.editor.level:clearAllCells()
    
    -- Reset level properties
    EditorLevel.editor.levelName = "New Level"
    EditorLevel.editor.startX = 20
    EditorLevel.editor.startY = 20
    
    -- Reset available balls
    EditorLevel.editor.availableBalls = {
        standard = true,
        heavy = false,
        exploding = false,
        sticky = false
    }
    
    -- Initialize grass on top of dirt cells
    EditorLevel.editor.level:initializeGrass()
end

-- Toggle grass on dirt cells
function EditorLevel.toggleGrass()
    -- Check if grass is currently enabled by looking at a dirt cell
    local hasGrass = false
    local foundDirt = false
    
    -- Find a dirt cell to check its grass state
    for y = 0, EditorLevel.editor.level.height - 1 do
        for x = 0, EditorLevel.editor.level.width - 1 do
            if EditorLevel.editor.level.cells[y][x].type == CellTypes.TYPES.DIRT then
                foundDirt = true
                if EditorLevel.editor.level.cells[y][x].hasGrass then
                    hasGrass = true
                end
                break
            end
        end
        if foundDirt then break end
    end
    
    -- Toggle grass state
    if hasGrass then
        -- Remove grass from all dirt cells
        for y = 0, EditorLevel.editor.level.height - 1 do
            for x = 0, EditorLevel.editor.level.width - 1 do
                if EditorLevel.editor.level.cells[y][x].type == CellTypes.TYPES.DIRT then
                    EditorLevel.editor.level.cells[y][x].hasGrass = false
                end
            end
        end
        print("Grass removed from all dirt cells")
    else
        -- Add grass to dirt cells with empty space above
        EditorLevel.editor.level:initializeGrass()
        print("Grass added to dirt cells with empty space above")
    end
    
    return not hasGrass -- Return the new grass state
end

-- Create stone boundaries around the level
function EditorLevel.createBoundaries()
    -- Add stone cells around the perimeter of the level
    for x = 0, EditorLevel.editor.level.width - 1 do
        -- Top boundary
        EditorLevel.editor.level:setCellType(x, 0, CellTypes.TYPES.STONE)
        
        -- Bottom boundary
        EditorLevel.editor.level:setCellType(x, EditorLevel.editor.level.height - 1, CellTypes.TYPES.STONE)
    end
    
    for y = 0, EditorLevel.editor.level.height - 1 do
        -- Left boundary
        EditorLevel.editor.level:setCellType(0, y, CellTypes.TYPES.STONE)
        
        -- Right boundary
        EditorLevel.editor.level:setCellType(EditorLevel.editor.level.width - 1, y, CellTypes.TYPES.STONE)
    end
    
    print("Stone boundaries created around the level")
end

-- Test play the level
function EditorLevel.testPlay()
    -- Initialize grass on top of dirt cells
    EditorLevel.editor.level:initializeGrass()
    
    -- Create a ball at the start position
    local ball = Balls.createBall(EditorLevel.editor.world, EditorLevel.editor.startX * Cell.SIZE, EditorLevel.editor.startY * Cell.SIZE, Balls.TYPES.STANDARD)
    ball.body:setUserData(ball)
    
    -- Store the current editor state
    EditorLevel.editor.testPlayState = {
        active = EditorLevel.editor.active,
        level = EditorLevel.editor.level,
        boulderData = {} -- Store boulder data, not the actual boulder objects
    }
    
    -- Store boulder data for later recreation
    if EditorLevel.editor.level.boulders then
        for _, boulder in ipairs(EditorLevel.editor.level.boulders) do
            local x, y = boulder:getPosition()
            table.insert(EditorLevel.editor.testPlayState.boulderData, {
                x = x,
                y = y,
                size = boulder.size
            })
        end
        
        -- Destroy all existing boulders to prevent physics duplicates
        for _, boulder in ipairs(EditorLevel.editor.level.boulders) do
            if boulder.body then
                boulder.body:destroy()
            end
        end
        
        -- Create new boulders for test play
        EditorLevel.editor.level.boulders = {}
        local Boulder = require("src.boulder")
        for _, data in ipairs(EditorLevel.editor.testPlayState.boulderData) do
            local newBoulder = Boulder.new(EditorLevel.editor.world, data.x, data.y, data.size)
            table.insert(EditorLevel.editor.level.boulders, newBoulder)
        end
    end
    
    -- Disable editor temporarily
    EditorLevel.editor.active = false
    
    -- Note: Camera scaling is now completely disabled in camera.lua
    -- to ensure cells are always displayed at their original size (10px)
    
    -- Return the ball for the game to use
    return ball
end

-- Return to editor after test play
function EditorLevel.returnFromTestPlay()
    -- Restore editor state
    if EditorLevel.editor.testPlayState then
        EditorLevel.editor.active = EditorLevel.editor.testPlayState.active
        
        -- Recreate boulders from stored data
        if EditorLevel.editor.level.boulders then
            -- Destroy all current boulders
            for _, boulder in ipairs(EditorLevel.editor.level.boulders) do
                if boulder.body then
                    boulder.body:destroy()
                end
            end
            
            -- Create fresh boulders from the stored data
            EditorLevel.editor.level.boulders = {}
            local Boulder = require("src.boulder")
            for _, data in ipairs(EditorLevel.editor.testPlayState.boulderData) do
                local newBoulder = Boulder.new(EditorLevel.editor.world, data.x, data.y, data.size)
                table.insert(EditorLevel.editor.level.boulders, newBoulder)
            end
        end
        
        EditorLevel.editor.testPlayState = nil
    else
        EditorLevel.editor.active = true
    end
    
    -- Clear any test balls
    if EditorLevel.editor.testBall then
        EditorLevel.editor.testBall.body:destroy()
        EditorLevel.editor.testBall = nil
    end
end

return EditorLevel
