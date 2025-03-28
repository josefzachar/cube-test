-- editor/init.lua - Main editor module for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Level = require("level")
local Balls = require("src.balls")

-- Import editor submodules
local EditorUI = require("src.editor.ui")
local EditorInput = require("src.editor.input")
local EditorFile = require("src.editor.file")
local EditorTools = require("src.editor.tools")

local Editor = {}

-- Editor state
Editor.active = false
Editor.currentTool = "DIRT" -- Default tool
Editor.brushSize = 1 -- Default brush size
Editor.levelName = "Untitled Level" -- Default level name
Editor.availableBalls = {
    [Balls.TYPES.STANDARD] = true,
    [Balls.TYPES.HEAVY] = true,
    [Balls.TYPES.EXPLODING] = true,
    [Balls.TYPES.STICKY] = true
}
Editor.startX = 20 -- Default start position
Editor.startY = 20
Editor.showGrid = true -- Show grid by default
Editor.setStartPosition = false -- Flag for setting start position
Editor.setWinHolePosition = false -- Flag for setting win hole position
Editor.winHoleX = 140 -- Default win hole position
Editor.winHoleY = 20
Editor.hideUI = false -- Flag to hide UI (toggled with SPACE)

-- File selection state
Editor.fileSelector = {
    active = false,
    mode = nil, -- "save" or "load"
    files = {},
    selectedIndex = 1,
    scrollOffset = 0,
    newFileName = ""
}

-- Tool types
Editor.TOOLS = {
    "draw",
    "erase",
    "fill",
    "start",
    "winhole"
}

-- Cell types
Editor.CELL_TYPES = {
    "EMPTY",
    "DIRT",
    "SAND",
    "STONE",
    "WATER",
    "FIRE"
}

-- Map cell type names to cell types
Editor.CELL_TYPE_TO_TYPE = {
    ["EMPTY"] = CellTypes.TYPES.EMPTY,
    ["DIRT"] = CellTypes.TYPES.DIRT,
    ["SAND"] = CellTypes.TYPES.SAND,
    ["STONE"] = CellTypes.TYPES.STONE,
    ["WATER"] = CellTypes.TYPES.WATER,
    ["FIRE"] = CellTypes.TYPES.FIRE
}

-- UI elements
Editor.buttons = {}
Editor.toolButtons = {}
Editor.brushButtons = {}
Editor.ballButtons = {}
Editor.textInput = {
    active = false,
    text = "Untitled Level",
    cursor = 0,
    cursorVisible = true,
    cursorBlinkTime = 0
}

-- Initialize the editor
function Editor.init(level, world)
    Editor.level = level
    Editor.world = world
    
    -- Initialize submodules
    EditorUI.init(Editor)
    EditorInput.init(Editor)
    EditorFile.init(Editor)
    EditorTools.init(Editor)
    
    -- Create editor UI buttons
    EditorUI.createUI(Editor)
end

-- Draw the editor
function Editor.draw()
    -- Draw the grid
    Editor.drawGrid()
    
    -- Draw the UI if not hidden
    if not Editor.hideUI then
        EditorUI.drawUI(Editor)
    end
    
    -- Draw the test ball if it exists
    if Editor.testBall then
        Editor.testBall:draw(false)
    end
    
    -- Draw file selector if active (always show this even if UI is hidden)
    if Editor.fileSelector.active then
        EditorUI.drawFileSelector(Editor)
    end
    
    -- If UI is hidden, show a small indicator
    if Editor.hideUI then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("Press SPACE to show UI", 10, 10)
    end
end

-- Update the editor
function Editor.update(dt)
    -- Update cursor blink
    Editor.textInput.cursorBlinkTime = Editor.textInput.cursorBlinkTime + dt
    if Editor.textInput.cursorBlinkTime > 0.5 then
        Editor.textInput.cursorVisible = not Editor.textInput.cursorVisible
        Editor.textInput.cursorBlinkTime = 0
    end
    
    -- Handle mouse input for drawing
    EditorInput.handleMouseDrag(Editor, dt)
end

-- Draw the level grid
function Editor.drawGrid()
    if not Editor.showGrid then return end
    
    love.graphics.setColor(0.5, 0.5, 0.5, 0.2)
    
    -- Draw vertical grid lines
    for x = 0, Editor.level.width do
        love.graphics.line(x * Cell.SIZE, 0, x * Cell.SIZE, Editor.level.height * Cell.SIZE)
    end
    
    -- Draw horizontal grid lines
    for y = 0, Editor.level.height do
        love.graphics.line(0, y * Cell.SIZE, Editor.level.width * Cell.SIZE, y * Cell.SIZE)
    end
    
    -- Draw start position
    love.graphics.setColor(0, 1, 0, 0.5)
    love.graphics.rectangle("fill", Editor.startX * Cell.SIZE, Editor.startY * Cell.SIZE, Cell.SIZE, Cell.SIZE)
end

-- Clear the level
function Editor.clearLevel()
    -- Clear all cells
    Editor.level:clearAllCells()
    
    -- Create stone walls around the level
    local Stone = require("src.stone")
    Stone.createWalls(Editor.level)
    
    -- Reset level name
    Editor.levelName = "Untitled Level"
    
    -- Reset start position
    Editor.startX = 20
    Editor.startY = 20
    
    -- Reset available balls
    Editor.availableBalls = {
        [Balls.TYPES.STANDARD] = true,
        [Balls.TYPES.HEAVY] = true,
        [Balls.TYPES.EXPLODING] = true,
        [Balls.TYPES.STICKY] = true
    }
end

-- Test play the level
function Editor.testPlay()
    -- Save current editor state
    Editor.active = false
    
    -- Create a ball at the start position
    local ball = Balls.createBall(Editor.world, Editor.startX * Cell.SIZE, Editor.startY * Cell.SIZE, Balls.TYPES.STANDARD)
    ball.body:setUserData(ball)
    
    -- Return the ball for main.lua to use
    return ball
end

-- Show file selector for loading or saving
function Editor.showFileSelector(mode)
    Editor.fileSelector.active = true
    Editor.fileSelector.mode = mode
    Editor.fileSelector.selectedIndex = 1
    Editor.fileSelector.scrollOffset = 0
    
    if mode == "save" then
        Editor.fileSelector.newFileName = Editor.levelName
    end
    
    -- Get list of level files
    EditorFile.refreshFileList(Editor)
end

-- Toggle UI visibility
function Editor.toggleUI()
    Editor.hideUI = not Editor.hideUI
end

-- Forward input handling to the appropriate submodule
function Editor.handleMousePressed(x, y, button)
    -- If UI is hidden, only handle file selector
    if Editor.hideUI and not Editor.fileSelector.active then
        return false
    end
    
    -- If file selector is active, handle its input first
    if Editor.fileSelector.active then
        return EditorInput.handleFileSelectorMousePressed(Editor, x, y, button)
    end
    
    return EditorInput.handleMousePressed(Editor, x, y, button)
end

function Editor.handleKeyPressed(key)
    -- Toggle UI with SPACE key
    if key == "space" and not Editor.fileSelector.active and not Editor.textInput.active then
        Editor.toggleUI()
        return true
    end
    
    -- If UI is hidden, only handle file selector and space key
    if Editor.hideUI and not Editor.fileSelector.active and not Editor.textInput.active then
        return false
    end
    
    -- If file selector is active, handle its input first
    if Editor.fileSelector.active then
        return EditorInput.handleFileSelectorKeyPressed(Editor, key)
    end
    
    -- If text input is active, handle its input first
    if Editor.textInput.active then
        return EditorInput.handleTextInputKeyPressed(Editor, key)
    end
    
    return EditorInput.handleKeyPressed(Editor, key)
end

function Editor.handleTextInput(text)
    -- If UI is hidden, only handle file selector
    if Editor.hideUI and not Editor.fileSelector.active and not Editor.textInput.active then
        return false
    end
    
    -- If file selector is active and in save mode, handle filename input
    if Editor.fileSelector.active and Editor.fileSelector.mode == "save" then
        Editor.fileSelector.newFileName = Editor.fileSelector.newFileName .. text
        return true
    end
    
    -- Otherwise handle normal text input
    if Editor.textInput.active then
        return EditorInput.handleTextInput(Editor, text)
    end
    
    return false
end

-- Forward file operations to the file submodule
function Editor.saveLevel()
    EditorFile.saveLevel(Editor)
end

function Editor.loadLevel()
    EditorFile.loadLevel(Editor)
end

return Editor
