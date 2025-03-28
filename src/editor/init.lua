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

-- Tool types (removed WIN_HOLE as requested)
Editor.TOOLS = {
    "EMPTY",
    "DIRT",
    "SAND",
    "STONE",
    "WATER"
}

-- Map tool names to cell types (removed WIN_HOLE mapping)
Editor.TOOL_TO_CELL_TYPE = {
    ["EMPTY"] = CellTypes.TYPES.EMPTY,
    ["DIRT"] = CellTypes.TYPES.DIRT,
    ["SAND"] = CellTypes.TYPES.SAND,
    ["STONE"] = CellTypes.TYPES.STONE,
    ["WATER"] = CellTypes.TYPES.WATER
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
    
    -- Draw the UI
    EditorUI.drawUI(Editor)
    
    -- Draw the test ball if it exists
    if Editor.testBall then
        Editor.testBall:draw(false)
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

-- Forward input handling to the appropriate submodule
function Editor.handleMousePressed(x, y, button)
    return EditorInput.handleMousePressed(Editor, x, y, button)
end

function Editor.handleKeyPressed(key)
    return EditorInput.handleKeyPressed(Editor, key)
end

function Editor.handleTextInput(text)
    return EditorInput.handleTextInput(Editor, text)
end

-- Forward file operations to the file submodule
function Editor.saveLevel()
    EditorFile.saveLevel(Editor)
end

function Editor.loadLevel()
    EditorFile.loadLevel(Editor)
end

return Editor
