-- editor/input.lua - Input handling for the Square Golf editor

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")

local EditorInput = {}

-- Initialize the input module
function EditorInput.init(Editor)
    -- Nothing to initialize for now
end

-- Handle mouse press in editor
function EditorInput.handleMousePressed(Editor, x, y, button)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = screenToGameCoords(x, y)
    
    -- Check if we're clicking on a button
    for _, buttonGroup in ipairs({Editor.toolButtons, Editor.brushButtons, Editor.ballButtons, Editor.buttons}) do
        for _, button in ipairs(buttonGroup) do
            if gameX >= button.x and gameX <= button.x + button.width and
               gameY >= button.y and gameY <= button.y + button.height then
                button.action()
                return true
            end
        end
    end
    
    -- If text input is active, clicking outside closes it
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    if Editor.textInput.active and 
       (gameX < gameWidth/2 - 200 or gameX > gameWidth/2 + 200 or
        gameY < gameHeight/2 - 50 or gameY > gameHeight/2 + 50) then
        Editor.levelName = Editor.textInput.text
        Editor.textInput.active = false
        return true
    end
    
    return false
end

-- Handle mouse drag for drawing
function EditorInput.handleMouseDrag(Editor, dt)
    -- Handle mouse input for drawing
    if love.mouse.isDown(1) and not Editor.textInput.active then
        local mouseX, mouseY = love.mouse.getPosition()
        local gameX, gameY = screenToGameCoords(mouseX, mouseY)
        local gridX, gridY = Editor.level:getGridCoordinates(gameX, gameY)
        
        -- Check if mouse is in the level area and not over UI
        local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
        if gridX >= 0 and gridX < Editor.level.width and gridY >= 0 and gridY < Editor.level.height and
           gameX > 140 and gameX < gameWidth - 140 then
            -- If we're in "set start position" mode
            if Editor.setStartPosition then
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
            -- If we're in "set win hole position" mode
            elseif Editor.setWinHolePosition then
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
            elseif Editor.currentTool then
                -- Draw with brush
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
        end
    end
end

-- Handle key press in editor
function EditorInput.handleKeyPressed(Editor, key)
    -- Handle text input
    if Editor.textInput.active then
        if key == "return" or key == "escape" then
            Editor.levelName = Editor.textInput.text
            Editor.textInput.active = false
        elseif key == "backspace" then
            if Editor.textInput.cursor > 0 then
                Editor.textInput.text = string.sub(Editor.textInput.text, 1, Editor.textInput.cursor - 1) .. 
                                       string.sub(Editor.textInput.text, Editor.textInput.cursor + 1)
                Editor.textInput.cursor = Editor.textInput.cursor - 1
            end
        elseif key == "left" then
            Editor.textInput.cursor = math.max(0, Editor.textInput.cursor - 1)
        elseif key == "right" then
            Editor.textInput.cursor = math.min(#Editor.textInput.text, Editor.textInput.cursor + 1)
        end
        return true
    end
    
    -- Shortcut keys for tools (removed WIN_HOLE shortcut)
    if key == "1" then
        Editor.currentTool = "EMPTY"
        Editor.setStartPosition = false
        Editor.setWinHolePosition = false
        return true
    elseif key == "2" then
        Editor.currentTool = "DIRT"
        Editor.setStartPosition = false
        Editor.setWinHolePosition = false
        return true
    elseif key == "3" then
        Editor.currentTool = "SAND"
        Editor.setStartPosition = false
        Editor.setWinHolePosition = false
        return true
    elseif key == "4" then
        Editor.currentTool = "STONE"
        Editor.setStartPosition = false
        Editor.setWinHolePosition = false
        return true
    elseif key == "5" then
        Editor.currentTool = "WATER"
        Editor.setStartPosition = false
        Editor.setWinHolePosition = false
        return true
    elseif key == "=" or key == "+" then
        -- Increase brush size
        local sizes = {1, 2, 3, 5, 7}
        for i, size in ipairs(sizes) do
            if Editor.brushSize == size and i < #sizes then
                Editor.brushSize = sizes[i+1]
                break
            end
        end
        return true
    elseif key == "-" then
        -- Decrease brush size
        local sizes = {1, 2, 3, 5, 7}
        for i, size in ipairs(sizes) do
            if Editor.brushSize == size and i > 1 then
                Editor.brushSize = sizes[i-1]
                break
            end
        end
        return true
    elseif key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Save level
        Editor.saveLevel()
        return true
    elseif key == "l" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- Load level
        Editor.loadLevel()
        return true
    elseif key == "g" then
        -- Toggle grid
        Editor.showGrid = not Editor.showGrid
        return true
    elseif key == "escape" then
        -- Exit editor
        Editor.active = false
        return true
    end
    
    return false
end

-- Handle text input
function EditorInput.handleTextInput(Editor, text)
    if Editor.textInput.active then
        -- Insert text at cursor position
        Editor.textInput.text = string.sub(Editor.textInput.text, 1, Editor.textInput.cursor) .. 
                               text .. 
                               string.sub(Editor.textInput.text, Editor.textInput.cursor + 1)
        Editor.textInput.cursor = Editor.textInput.cursor + #text
        return true
    end
    return false
end

return EditorInput
