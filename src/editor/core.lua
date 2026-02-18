-- editor/core.lua - Core functionality for the Square Golf editor

local CellTypes = require("src.cell_types")
local Cell = require("cell")
local WinHole = require("src.win_hole")
local EditorUI = require("src.editor.ui")
local EditorTools = require("src.editor.tools")
local EditorFile = require("src.editor.file")
local EditorInput = require("src.editor.input")
local EditorCamera = require("src.editor.camera")
local EditorLevel = require("src.editor.level")
local Balls = require("src.balls")

local EditorCore = {
    -- Editor state
    active = false,
    level = nil,
    world = nil,
    
    -- Editor state
    currentTool = "draw",
    currentCellType = "DIRT",
    brushSize = 1,
    showUI = true,
    showHelp = false, -- Help panel visibility
    
    -- Camera panning
    cameraX = 0,
    cameraY = 0,
    isPanning = false,
    lastMouseX = 0,
    lastMouseY = 0,
    
    -- Level size editing
    editingLevelSize = false,
    newWidth = nil,
    newHeight = nil,
    
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
        sticky = false,
        spraying = false
    },
    
    -- Grass state
    grassEnabled = true,
    
    -- Text input state
    textInput = {
        active = false,
        text = "",
        cursor = 0,
        cursorVisible = true,
        cursorBlinkTimer = 0,
        mode = "levelName" -- Can be "levelName", "levelWidth", or "levelHeight"
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
        "winhole",
        "boulder",
        "barrel"
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
function EditorCore.init(level, world)
    EditorCore.level = level
    EditorCore.world = world
    
    -- Initialize editor modules
    EditorUI.init(EditorCore)
    EditorTools.init(EditorCore)
    EditorFile.init(EditorCore)
    EditorInput.init(EditorCore)
    EditorCamera.init(EditorCore)
    EditorLevel.init(EditorCore)
end

-- Update the editor
function EditorCore.update(dt)
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Handle camera panning
    EditorCamera.handlePanning(dt)
    
    -- Get grid coordinates
    local gridX, gridY
    local gameX, gameY
    
    -- For mobile devices, use the InputUtils module for direct conversion
    if _G.isMobile then
        local InputUtils = require("src.input_utils")
        local Cell = require("cell")
        gameX, gameY = InputUtils.screenToGameCoords(mouseX, mouseY)
        gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, Cell.SIZE)
        
        -- Process mobile input
    else
        -- Desktop approach
        gameX, gameY = EditorCamera.screenToGameCoords(mouseX, mouseY)
        gridX, gridY = EditorCore.level:getGridCoordinates(gameX, gameY)
    end
    
    -- Update editor tools
    if EditorTools.update then
        EditorTools.update(dt, gridX, gridY)
    end
    
    -- Handle mouse drag for drawing (only if file selector is not active and not panning)
    if love.mouse.isDown(1) and EditorCore.currentTool and not EditorCore.fileSelector.active and not EditorCore.isPanning then
        EditorTools.handleMouseDrag(gridX, gridY)
    end
    
    -- Update text input cursor blink
    if EditorCore.textInput.active then
        EditorCore.textInput.cursorBlinkTimer = EditorCore.textInput.cursorBlinkTimer + dt
        if EditorCore.textInput.cursorBlinkTimer > 0.5 then
            EditorCore.textInput.cursorVisible = not EditorCore.textInput.cursorVisible
            EditorCore.textInput.cursorBlinkTimer = 0
        end
    end
end

-- Draw the editor
function EditorCore.draw()
    -- Get screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Draw background (dark blue)
    love.graphics.clear(0.05, 0.05, 0.15, 1)
    
    -- Apply camera transformation
    EditorCamera.applyTransform()
    
    -- Draw the level (noCull=true: render all cells regardless of viewport)
    EditorCore.level:draw(EditorCore.debug, true)
    
    -- Draw the editor tools
    EditorTools.draw()
    
    -- Draw a flag at the start position
    if EditorCore.startX and EditorCore.startY then
        local x = EditorCore.startX * Cell.SIZE + Cell.SIZE / 2
        local y = EditorCore.startY * Cell.SIZE + Cell.SIZE / 2
        
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
    
    -- Reset transformation before drawing UI
    EditorCamera.resetTransform()
    
    -- Draw the editor UI if enabled
    if EditorCore.showUI then
        -- Draw the editor UI
        EditorUI.draw()
    end
    
    -- Draw file selector if active
    if EditorCore.fileSelector.active then
        -- Draw the file selector
        EditorFile.drawFileSelector()
    end
    
    -- Draw cursor preview last, so it's on top of everything
    if not EditorCore.fileSelector.active and not EditorCore.textInput.active and not EditorCore.isPanning then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Get game coordinates
        local gameX, gameY
        
        -- For mobile devices, use the InputUtils module for direct conversion
        if _G.isMobile then
            local InputUtils = require("src.input_utils")
            gameX, gameY = InputUtils.screenToGameCoords(mouseX, mouseY)
        else
            gameX, gameY = EditorCamera.screenToGameCoords(mouseX, mouseY)
        end
        
        -- Draw cursor preview
        EditorUI.drawCursorPreview()
    end
    
    -- Draw zoom indicator
    EditorCamera.drawZoomIndicator()
end

-- Handle key press in editor
function EditorCore.handleKeyPressed(key)
    -- If text input is active, handle text input key presses
    if EditorCore.textInput.active then
        EditorInput.handleTextInputKeyPressed(key)
        return true
    end
    
    -- If file selector is active, handle file selector key presses
    if EditorCore.fileSelector.active then
        EditorFile.handleKeyPressed(key)
        return true
    end
    
    -- Handle space key for toggling UI
    if key == "space" then
        EditorCore.showUI = not EditorCore.showUI
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

-- Handle key release in editor
function EditorCore.handleKeyReleased(key)
    return false
end

-- Handle text input in editor
function EditorCore.handleTextInput(text)
    -- If text input is active, handle text input
    if EditorCore.textInput.active then
        EditorInput.handleTextInput(text)
        return true
    end
    
    -- If file selector is active, handle file selector text input
    if EditorCore.fileSelector.active then
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
function EditorCore.handleMousePressed(x, y, button)
    -- If file selector is active, handle file selector mouse press and prevent any other handlers
    if EditorCore.fileSelector.active then
        -- Always return true to prevent any other mouse handlers from processing this event
        EditorFile.handleMousePressed(x, y, button)
        return true
    end
    
    -- Handle middle mouse button (button 3) for camera panning
    if button == 3 then
        EditorCore.isPanning = true
        EditorCore.lastMouseX = x
        EditorCore.lastMouseY = y
        return true
    end
    
    -- Get grid coordinates
    local gridX, gridY
    local gameX, gameY
    
    -- For mobile devices, use the InputUtils module for direct conversion
    if _G.isMobile then
        local InputUtils = require("src.input_utils")
        local Cell = require("cell")
        gameX, gameY = InputUtils.screenToGameCoords(x, y)
        gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, Cell.SIZE)
    else
        -- Desktop approach
        gameX, gameY = EditorCamera.screenToGameCoords(x, y)
        gridX, gridY = EditorCore.level:getGridCoordinates(gameX, gameY)
    end
    
    -- Check if UI handled the mouse press
    if EditorCore.showUI and EditorUI.handleMousePressed(x, y, button) then
        return true
    end
    
    -- Handle tools (only if not panning)
    if not EditorCore.isPanning and EditorTools.handleMousePressed(gridX, gridY, button) then
        return true
    end
    
    return false
end

-- Handle mouse release in editor
function EditorCore.handleMouseReleased(x, y, button)
    -- Handle middle mouse button release for camera panning
    if button == 3 and EditorCore.isPanning then
        EditorCore.isPanning = false
        return true
    end
    
    -- If file selector is active, don't handle mouse release for tools
    if EditorCore.fileSelector.active then
        return false
    end
    
    -- Get grid coordinates
    local gridX, gridY
    local gameX, gameY
    
    -- For mobile devices, use the InputUtils module for direct conversion
    if _G.isMobile then
        local InputUtils = require("src.input_utils")
        local Cell = require("cell")
        gameX, gameY = InputUtils.screenToGameCoords(x, y)
        gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, Cell.SIZE)
        
        -- Process mobile input for mouse release
    else
        -- Desktop approach
        gameX, gameY = EditorCamera.screenToGameCoords(x, y)
        gridX, gridY = EditorCore.level:getGridCoordinates(gameX, gameY)
    end
    
    -- Handle tools (only if not panning)
    if not EditorCore.isPanning and EditorTools.handleMouseReleased(gridX, gridY, button) then
        return true
    end
    
    return false
end

-- Handle mouse wheel in editor
function EditorCore.handleMouseWheel(x, y)
    -- Pass to input handler
    return EditorInput.handleMouseWheel(x, y)
end

-- Resize the level (delegate to EditorLevel)
function EditorCore.resizeLevel(newWidth, newHeight)
    return EditorLevel.resizeLevel(newWidth, newHeight)
end

-- Save the level (delegate to EditorLevel)
function EditorCore.saveLevel(filename)
    return EditorLevel.saveLevel(filename)
end

-- Load a level (delegate to EditorLevel)
function EditorCore.loadLevel(filename)
    return EditorLevel.loadLevel(filename)
end

-- Clear the level (delegate to EditorLevel)
function EditorCore.clearLevel()
    return EditorLevel.clearLevel()
end

-- Create stone boundaries around the level (delegate to EditorLevel)
function EditorCore.createBoundaries()
    return EditorLevel.createBoundaries()
end

-- Test play the level (delegate to EditorLevel)
function EditorCore.testPlay()
    return EditorLevel.testPlay()
end

-- Return to editor after test play (delegate to EditorLevel)
function EditorCore.returnFromTestPlay()
    return EditorLevel.returnFromTestPlay()
end

-- Toggle grass on dirt cells (delegate to EditorLevel)
function EditorCore.toggleGrass()
    -- Call the EditorLevel function and update the grass state
    EditorCore.grassEnabled = EditorLevel.toggleGrass()
    return EditorCore.grassEnabled
end

-- Screen to game coordinates (delegate to EditorCamera)
function EditorCore.screenToGameCoords(screenX, screenY)
    return EditorCamera.screenToGameCoords(screenX, screenY)
end

return EditorCore
