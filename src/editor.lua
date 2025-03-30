-- editor.lua - Level editor for Square Golf

local CellTypes = require("src.cell_types")
local Cell = require("cell")
local WinHole = require("src.win_hole")
local EditorUI = require("src.editor.ui")
local EditorTools = require("src.editor.tools")
local EditorFile = require("src.editor.file")
local EditorInput = require("src.editor.input")
local Balls = require("src.balls")

local Editor = {
    active = false,
    level = nil,
    world = nil,
    
    -- Editor state
    currentTool = "draw",
    currentCellType = "DIRT",
    brushSize = 1,
    showUI = true,
    
    -- Start position for the ball
    startX = 20,
    startY = 20,
    
    -- Level name
    levelName = "New Level",
    
    -- Available balls for this level
    availableBalls = {
        standard = true,
        heavy = false,
        exploding = false,
        sticky = false
    },
    
    -- Text input state
    textInput = {
        active = false,
        text = "",
        cursor = 0,
        cursorVisible = true,
        cursorBlinkTimer = 0
    },
    
    -- File selector state
    fileSelector = {
        active = false,
        mode = "load",
        files = {},
        selectedIndex = 1,
        newFileName = ""
    },
    
    -- Tool types
    TOOLS = {
        "draw",
        "erase",
        "fill",
        "start",
        "winhole"
    },
    
    -- Cell types
    CELL_TYPES = {
        "EMPTY",
        "DIRT",
        "SAND",
        "STONE",
        "WATER",
        "FIRE"
    },
    
    -- Map cell type names to cell types
    CELL_TYPE_TO_TYPE = {
        ["EMPTY"] = CellTypes.TYPES.EMPTY,
        ["DIRT"] = CellTypes.TYPES.DIRT,
        ["SAND"] = CellTypes.TYPES.SAND,
        ["STONE"] = CellTypes.TYPES.STONE,
        ["WATER"] = CellTypes.TYPES.WATER,
        ["FIRE"] = CellTypes.TYPES.FIRE
    }
}

-- Initialize the editor
function Editor.init(level, world)
    Editor.level = level
    Editor.world = world
    
    -- Initialize editor modules
    EditorUI.init(Editor)
    EditorTools.init(Editor)
    EditorFile.init(Editor)
    EditorInput.init(Editor)
end

-- Update the editor
function Editor.update(dt)
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = Editor.screenToGameCoords(mouseX, mouseY)
    
    -- Get grid coordinates
    local gridX, gridY = Editor.level:getGridCoordinates(gameX, gameY)
    
    -- Update editor tools
    if EditorTools.update then
        EditorTools.update(dt, gridX, gridY)
    end
    
    -- Handle mouse drag for drawing (only if file selector is not active)
    if love.mouse.isDown(1) and Editor.currentTool and not Editor.fileSelector.active then
        EditorTools.handleMouseDrag(gridX, gridY)
    end
    
    -- Update text input cursor blink
    if Editor.textInput.active then
        Editor.textInput.cursorBlinkTimer = Editor.textInput.cursorBlinkTimer + dt
        if Editor.textInput.cursorBlinkTimer > 0.5 then
            Editor.textInput.cursorVisible = not Editor.textInput.cursorVisible
            Editor.textInput.cursorBlinkTimer = 0
        end
    end
end

-- Draw the editor
function Editor.draw()
    -- Draw the editor tools
    EditorTools.draw()
    
    -- Draw a flag at the start position
    if Editor.startX and Editor.startY then
        local x = Editor.startX * Cell.SIZE + Cell.SIZE / 2
        local y = Editor.startY * Cell.SIZE + Cell.SIZE / 2
        
        -- Draw flag pole
        love.graphics.setColor(0.6, 0.4, 0.2, 1) -- Brown
        love.graphics.setLineWidth(2)
        love.graphics.line(x, y, x, y - 20)
        
        -- Draw flag
        love.graphics.setColor(0, 1, 0, 1) -- Green
        love.graphics.polygon("fill", x, y - 20, x + 15, y - 15, x, y - 10)
        
        -- Draw base
        love.graphics.setColor(0.6, 0.4, 0.2, 1) -- Brown
        love.graphics.circle("fill", x, y, 3)
    end
    
    -- Draw the editor UI if enabled
    if Editor.showUI then
        -- Reset transformation before drawing UI
        love.graphics.origin()
        
        -- Draw the editor UI
        EditorUI.draw()
    end
    
    -- Draw file selector if active
    if Editor.fileSelector.active then
        -- Reset transformation before drawing file selector
        love.graphics.origin()
        
        -- Draw the file selector
        EditorFile.drawFileSelector()
    end
    
    -- Draw cursor preview last, so it's on top of everything
    if not Editor.fileSelector.active and not Editor.textInput.active then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Convert screen coordinates to game coordinates
        local gameX, gameY = Editor.screenToGameCoords(mouseX, mouseY)
        
        -- Get screen dimensions
        local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
        
        -- Check if mouse is in UI area (left or right panel)
        if not (gameX < 140 or gameX > gameWidth - 140) then
            -- Mouse is not in UI area, draw cursor preview
            -- Reset transformation before drawing cursor preview
            love.graphics.origin()
            
            -- Draw cursor preview
            EditorUI.drawCursorPreview()
        end
    end
end

-- Handle key press in editor
function Editor.handleKeyPressed(key)
    -- If text input is active, handle text input key presses
    if Editor.textInput.active then
        EditorInput.handleTextInputKeyPressed(key)
        return true
    end
    
    -- If file selector is active, handle file selector key presses
    if Editor.fileSelector.active then
        EditorFile.handleKeyPressed(key)
        return true
    end
    
    -- Toggle UI with space
    if key == "space" then
        Editor.showUI = not Editor.showUI
        return true
    end
    
    -- Handle file operations
    if EditorFile.handleKeyPressed(key) then
        return true
    end
    
    -- Handle tool selection
    if EditorTools.handleKeyPressed(key) then
        return true
    end
    
    -- Handle input
    if EditorInput.handleKeyPressed(key) then
        return true
    end
    
    return false
end

-- Handle text input in editor
function Editor.handleTextInput(text)
    -- If text input is active, handle text input
    if Editor.textInput.active then
        EditorInput.handleTextInput(text)
        return true
    end
    
    -- If file selector is active, handle file selector text input
    if Editor.fileSelector.active then
        EditorFile.handleTextInput(text)
        return true
    end
    
    -- Handle file operations
    if EditorFile.handleTextInput(text) then
        return true
    end
    
    -- Handle input
    if EditorInput.handleTextInput(text) then
        return true
    end
    
    return false
end

-- Handle mouse press in editor
function Editor.handleMousePressed(x, y, button)
    -- If file selector is active, handle file selector mouse press and prevent any other handlers
    if Editor.fileSelector.active then
        -- Always return true to prevent any other mouse handlers from processing this event
        EditorFile.handleMousePressed(x, y, button)
        return true
    end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = Editor.screenToGameCoords(x, y)
    
    -- Get grid coordinates
    local gridX, gridY = Editor.level:getGridCoordinates(gameX, gameY)
    
    -- Check if UI handled the mouse press
    if Editor.showUI and EditorUI.handleMousePressed(x, y, button) then
        return true
    end
    
    -- Handle tools
    if EditorTools.handleMousePressed(gridX, gridY, button) then
        return true
    end
    
    return false
end

-- Handle mouse release in editor
function Editor.handleMouseReleased(x, y, button)
    -- If file selector is active, don't handle mouse release for tools
    if Editor.fileSelector.active then
        return false
    end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = Editor.screenToGameCoords(x, y)
    
    -- Get grid coordinates
    local gridX, gridY = Editor.level:getGridCoordinates(gameX, gameY)
    
    -- Handle tools
    if EditorTools.handleMouseReleased(gridX, gridY, button) then
        return true
    end
    
    return false
end

-- Handle mouse wheel in editor
function Editor.handleMouseWheel(x, y)
    -- Pass to input handler
    return EditorInput.handleMouseWheel(x, y)
end

-- Function to convert screen coordinates to game coordinates
function Editor.screenToGameCoords(screenX, screenY)
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Calculate scale factors
    local scaleX = width / 1600
    local scaleY = height / 1000
    local scale = math.min(scaleX, scaleY)
    
    -- Ensure minimum scale to prevent rendering issues
    scale = math.max(scale, 0.5) -- Minimum scale factor of 0.5
    
    -- Calculate offsets for centering
    local scaledWidth = width / scale
    local scaledHeight = height / scale
    local offsetX = (scaledWidth - 1600) / 2
    local offsetY = (scaledHeight - 1000) / 2
    
    -- Convert screen coordinates to game coordinates
    local gameX = (screenX / scale) - offsetX
    local gameY = (screenY / scale) - offsetY
    
    return gameX, gameY
end

-- Save the current level
function Editor.saveLevel(filename)
    -- Create level data
    local levelData = {
        name = Editor.levelName,
        width = Editor.level.width,
        height = Editor.level.height,
        startX = Editor.startX,
        startY = Editor.startY,
        winHoleX = Editor.winHoleX,
        winHoleY = Editor.winHoleY,
        availableBalls = {
            standard = Editor.availableBalls.standard,
            heavy = Editor.availableBalls.heavy,
            exploding = Editor.availableBalls.exploding,
            sticky = Editor.availableBalls.sticky
        },
        cells = {}
    }
    
    -- Save cell data
    for y = 0, Editor.level.height - 1 do
        levelData.cells[y] = {}
        for x = 0, Editor.level.width - 1 do
            levelData.cells[y][x] = Editor.level:getCellType(x, y)
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
function Editor.loadLevel(filename)
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
    Editor.level:clearAllCells()
    
    -- Set level properties
    Editor.levelName = levelData.name or "Unnamed Level"
    Editor.startX = levelData.startX or 20
    Editor.startY = levelData.startY or 20
    Editor.winHoleX = levelData.winHoleX or 140
    Editor.winHoleY = levelData.winHoleY or 20
    
    -- Set available balls
    if levelData.availableBalls then
        Editor.availableBalls.standard = levelData.availableBalls.standard or true
        Editor.availableBalls.heavy = levelData.availableBalls.heavy or false
        Editor.availableBalls.exploding = levelData.availableBalls.exploding or false
        Editor.availableBalls.sticky = levelData.availableBalls.sticky or false
    end
    
    -- Set cell data
    for y = 0, levelData.height - 1 do
        for x = 0, levelData.width - 1 do
            if levelData.cells[y] and levelData.cells[y][x] then
                Editor.level:setCellType(x, y, levelData.cells[y][x])
            end
        end
    end
    
    -- Initialize grass on top of dirt cells
    Editor.level:initializeGrass()
    
    print("Level loaded from: levels/" .. filename)
    return true
end

-- Clear the level
function Editor.clearLevel()
    -- Clear all cells
    Editor.level:clearAllCells()
    
    -- Reset level properties
    Editor.levelName = "New Level"
    Editor.startX = 20
    Editor.startY = 20
    
    -- Reset available balls
    Editor.availableBalls = {
        standard = true,
        heavy = false,
        exploding = false,
        sticky = false
    }
    
    -- Initialize grass on top of dirt cells
    Editor.level:initializeGrass()
end

-- Test play the level
function Editor.testPlay()
    -- Initialize grass on top of dirt cells
    Editor.level:initializeGrass()
    
    -- Create a ball at the start position
    local ball = Balls.createBall(Editor.world, Editor.startX * Cell.SIZE, Editor.startY * Cell.SIZE, Balls.TYPES.STANDARD)
    ball.body:setUserData(ball)
    
    -- Store the current editor state
    Editor.testPlayState = {
        active = Editor.active,
        level = Editor.level
    }
    
    -- Disable editor temporarily
    Editor.active = false
    
    -- Return the ball for the game to use
    return ball
end

-- Return to editor after test play
function Editor.returnFromTestPlay()
    -- Restore editor state
    if Editor.testPlayState then
        Editor.active = Editor.testPlayState.active
        Editor.testPlayState = nil
    else
        Editor.active = true
    end
    
    -- Clear any test balls
    if Editor.testBall then
        Editor.testBall.body:destroy()
        Editor.testBall = nil
    end
end

-- Handle mouse wheel in editor
function Editor.handleMouseWheel(x, y)
    -- Pass to input handler
    return EditorInput.handleMouseWheel(x, y)
end

return Editor
