-- editor/tools.lua - Drawing tools for the Square Golf editor

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")

local EditorTools = {}

-- Initialize the tools module
function EditorTools.init(Editor)
    -- Nothing to initialize for now
end

-- Apply the current tool at the specified position
function EditorTools.applyTool(Editor, gridX, gridY)
    -- If we're in "set start position" mode
    if Editor.setStartPosition then
        EditorTools.setStartPosition(Editor, gridX, gridY)
    -- If we're in "set win hole position" mode
    elseif Editor.setWinHolePosition then
        EditorTools.setWinHolePosition(Editor, gridX, gridY)
    -- If we're using a drawing tool
    elseif Editor.currentTool then
        EditorTools.drawWithBrush(Editor, gridX, gridY)
    end
end

-- Set the start position
function EditorTools.setStartPosition(Editor, gridX, gridY)
    Editor.startX = gridX
    Editor.startY = gridY
    Editor.setStartPosition = false
    
    -- Create a ball at the start position to visualize it
    if Editor.testBall then
        Editor.testBall.body:destroy()
        Editor.testBall = nil
    end
    
    Editor.testBall = Balls.createBall(Editor.world, Editor.startX * Cell.SIZE, Editor.startY * Cell.SIZE, Balls.TYPES.STANDARD)
    Editor.testBall.body:setUserData(Editor.testBall)
    Editor.testBall.body:setType("static") -- Make it static so it doesn't fall
end

-- Set the win hole position
function EditorTools.setWinHolePosition(Editor, gridX, gridY)
    Editor.winHoleX = gridX
    Editor.winHoleY = gridY
    Editor.setWinHolePosition = false
    
    -- First, clear any existing win holes
    for y = 0, Editor.level.height - 1 do
        for x = 0, Editor.level.width - 1 do
            if Editor.level:getCellType(x, y) == CellTypes.TYPES.WIN_HOLE then
                Editor.level:setCellType(x, y, CellTypes.TYPES.EMPTY)
            end
        end
    end
    
    -- Create a diamond-shaped win hole at the clicked position
    local WinHole = require("src.win_hole")
    WinHole.createWinHoleArea(Editor.level, gridX - 2, gridY - 2, 5, 5)
end

-- Draw with the current brush
function EditorTools.drawWithBrush(Editor, gridX, gridY)
    local cellType = Editor.TOOL_TO_CELL_TYPE[Editor.currentTool]
    
    -- Apply brush with size for all cell types
    for y = -Editor.brushSize + 1, Editor.brushSize - 1 do
        for x = -Editor.brushSize + 1, Editor.brushSize - 1 do
            local distance = math.sqrt(x*x + y*y)
            if distance < Editor.brushSize then
                local cellX = gridX + x
                local cellY = gridY + y
                if cellX >= 0 and cellX < Editor.level.width and cellY >= 0 and cellY < Editor.level.height then
                    Editor.level:setCellType(cellX, cellY, cellType)
                end
            end
        end
    end
end

-- Get the pattern for a win hole
function EditorTools.getWinHolePattern()
    return {
        {0, 0, 1, 0, 0},
        {0, 1, 1, 1, 0},
        {1, 1, 1, 1, 1},
        {0, 1, 1, 1, 0},
        {0, 0, 1, 0, 0}
    }
end

return EditorTools
