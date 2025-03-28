-- editor/ui.lua - UI handling for the Square Golf editor

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")

local EditorUI = {}

-- Initialize the UI module
function EditorUI.init(Editor)
    -- Load the button font if not already loaded
    if not Editor.buttonFont then
        Editor.buttonFont = love.graphics.newFont("fonts/pixel_font.ttf", 18)
    end
end

-- Create editor UI elements
function EditorUI.createUI(Editor)
    -- Clear existing buttons
    Editor.buttons = {}
    Editor.toolButtons = {}
    Editor.brushButtons = {}
    Editor.ballButtons = {}
    
    -- Button dimensions
    local buttonWidth = 120
    local buttonHeight = 30
    local buttonMargin = 10
    local panelWidth = 150
    
    -- Create tool buttons
    for i, tool in ipairs(Editor.TOOLS) do
        local button = {
            x = 10,
            y = 50 + (i-1) * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = tool,
            action = function()
                Editor.currentTool = tool
                Editor.setStartPosition = false
                Editor.setWinHolePosition = false
            end,
            isSelected = function()
                return Editor.currentTool == tool
            end
        }
        table.insert(Editor.toolButtons, button)
    end
    
    -- Create brush size buttons
    local brushSizes = {1, 2, 3, 5, 7}
    for i, size in ipairs(brushSizes) do
        local button = {
            x = 10,
            y = 300 + (i-1) * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "SIZE " .. size,
            action = function()
                Editor.brushSize = size
            end,
            isSelected = function()
                return Editor.brushSize == size
            end
        }
        table.insert(Editor.brushButtons, button)
    end
    
    -- Create ball selection buttons
    local ballTypes = {
        {type = Balls.TYPES.STANDARD, name = "STANDARD"},
        {type = Balls.TYPES.HEAVY, name = "HEAVY"},
        {type = Balls.TYPES.EXPLODING, name = "EXPLODING"},
        {type = Balls.TYPES.STICKY, name = "STICKY"}
    }
    
    -- Get screen dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    
    for i, ball in ipairs(ballTypes) do
        local button = {
            x = gameWidth - panelWidth - 10,
            y = 50 + (i-1) * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = ball.name,
            action = function()
                Editor.availableBalls[ball.type] = not Editor.availableBalls[ball.type]
            end,
            isSelected = function()
                return Editor.availableBalls[ball.type]
            end
        }
        table.insert(Editor.ballButtons, button)
    end
    
    -- Create main editor buttons
    local mainButtons = {
        {
            x = gameWidth - panelWidth - 10,
            y = 200,
            width = buttonWidth,
            height = buttonHeight,
            text = "SAVE",
            action = function()
                Editor.saveLevel()
            end
        },
        {
            x = gameWidth - panelWidth - 10,
            y = 200 + buttonHeight + buttonMargin,
            width = buttonWidth,
            height = buttonHeight,
            text = "LOAD",
            action = function()
                Editor.loadLevel()
            end
        },
        {
            x = gameWidth - panelWidth - 10,
            y = 200 + 2 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "CLEAR",
            action = function()
                Editor.clearLevel()
            end
        },
        {
            x = gameWidth - panelWidth - 10,
            y = 200 + 3 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "SET NAME",
            action = function()
                Editor.textInput.active = true
                Editor.textInput.text = Editor.levelName
                Editor.textInput.cursor = #Editor.levelName
            end
        },
        {
            x = gameWidth - panelWidth - 10,
            y = 200 + 4 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "SET START",
            action = function()
                Editor.setStartPosition = true
                Editor.setWinHolePosition = false
                Editor.currentTool = nil -- Disable drawing tools
            end
        },
        {
            x = gameWidth - panelWidth - 10,
            y = 200 + 5 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "SET HOLE",
            action = function()
                Editor.setWinHolePosition = true
                Editor.setStartPosition = false
                Editor.currentTool = nil -- Disable drawing tools
            end
        },
        {
            x = gameWidth - panelWidth - 10,
            y = 200 + 6 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "TOGGLE GRID",
            action = function()
                Editor.showGrid = not Editor.showGrid
            end
        },
        {
            x = gameWidth - panelWidth - 10,
            y = 200 + 7 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "TEST PLAY",
            action = function()
                Editor.testPlay()
            end
        },
        {
            x = gameWidth - panelWidth - 10,
            y = 200 + 8 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "EXIT EDITOR",
            action = function()
                Editor.active = false
            end
        }
    }
    
    for _, button in ipairs(mainButtons) do
        table.insert(Editor.buttons, button)
    end
end

-- Draw the editor UI
function EditorUI.drawUI(Editor)
    -- Get screen dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    
    -- Draw left panel background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", 0, 0, 140, gameHeight)
    
    -- Draw right panel background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", gameWidth - 140, 0, 140, gameHeight)
    
    -- Draw tool buttons
    love.graphics.setFont(Editor.buttonFont)
    for _, button in ipairs(Editor.toolButtons) do
        -- Button background
        if button.isSelected() then
            love.graphics.setColor(0.3, 0.3, 0.6, 1)
        else
            love.graphics.setColor(0.2, 0.2, 0.4, 1)
        end
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
        
        -- Button border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
        
        -- Button text
        love.graphics.setColor(1, 1, 1, 1)
        local textWidth = Editor.buttonFont:getWidth(button.text)
        local textHeight = Editor.buttonFont:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    -- Draw brush size buttons
    for _, button in ipairs(Editor.brushButtons) do
        -- Button background
        if button.isSelected() then
            love.graphics.setColor(0.3, 0.3, 0.6, 1)
        else
            love.graphics.setColor(0.2, 0.2, 0.4, 1)
        end
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
        
        -- Button border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
        
        -- Button text
        love.graphics.setColor(1, 1, 1, 1)
        local textWidth = Editor.buttonFont:getWidth(button.text)
        local textHeight = Editor.buttonFont:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    -- Draw ball selection buttons
    for _, button in ipairs(Editor.ballButtons) do
        -- Button background
        if button.isSelected() then
            love.graphics.setColor(0.3, 0.3, 0.6, 1)
        else
            love.graphics.setColor(0.2, 0.2, 0.4, 1)
        end
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
        
        -- Button border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
        
        -- Button text
        love.graphics.setColor(1, 1, 1, 1)
        local textWidth = Editor.buttonFont:getWidth(button.text)
        local textHeight = Editor.buttonFont:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    -- Draw main buttons
    for _, button in ipairs(Editor.buttons) do
        -- Button background
        love.graphics.setColor(0.2, 0.2, 0.4, 1)
        love.graphics.rectangle("fill", button.x, button.y, button.width, button.height)
        
        -- Button border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", button.x, button.y, button.width, button.height)
        
        -- Button text
        love.graphics.setColor(1, 1, 1, 1)
        local textWidth = Editor.buttonFont:getWidth(button.text)
        local textHeight = Editor.buttonFont:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    -- Draw level name
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("LEVEL NAME:", 10, 10)
    love.graphics.print(Editor.levelName, 10, 30)
    
    -- Draw start position
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("START: " .. Editor.startX .. "," .. Editor.startY, 10, 500)
    
    -- Draw win hole position
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("HOLE: " .. Editor.winHoleX .. "," .. Editor.winHoleY, 10, 530)
    
    -- Draw text input if active
    if Editor.textInput.active then
        -- Draw input background
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", gameWidth/2 - 200, gameHeight/2 - 50, 400, 100)
        
        -- Draw input border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", gameWidth/2 - 200, gameHeight/2 - 50, 400, 100)
        
        -- Draw input title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Enter Level Name:", gameWidth/2 - 180, gameHeight/2 - 40)
        
        -- Draw input text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(Editor.textInput.text, gameWidth/2 - 180, gameHeight/2)
        
        -- Draw cursor
        if Editor.textInput.cursorVisible then
            local cursorX = gameWidth/2 - 180 + Editor.buttonFont:getWidth(string.sub(Editor.textInput.text, 1, Editor.textInput.cursor))
            love.graphics.rectangle("fill", cursorX, gameHeight/2, 2, 20)
        end
    end
    
    -- Draw cursor/preview
    EditorUI.drawCursorPreview(Editor)
end

-- Draw cursor preview based on current tool
function EditorUI.drawCursorPreview(Editor)
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = screenToGameCoords(mouseX, mouseY)
    local gridX, gridY = Editor.level:getGridCoordinates(gameX, gameY)
    
    -- Only draw cursor/preview if mouse is in the level area
    if gridX >= 0 and gridX < Editor.level.width and gridY >= 0 and gridY < Editor.level.height then
        if Editor.setStartPosition then
            -- Draw ball cursor
            love.graphics.setColor(0, 1, 0, 0.7)
            love.graphics.rectangle("fill", gridX * Cell.SIZE, gridY * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            love.graphics.setColor(0, 1, 0, 1)
            love.graphics.rectangle("line", gridX * Cell.SIZE, gridY * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        elseif Editor.setWinHolePosition then
            -- Draw win hole cursor (diamond shape)
            love.graphics.setColor(1, 1, 0, 0.7)
            
            -- Draw a diamond shape
            local pattern = {
                {0, 0, 1, 0, 0},
                {0, 1, 1, 1, 0},
                {1, 1, 1, 1, 1},
                {0, 1, 1, 1, 0},
                {0, 0, 1, 0, 0}
            }
            
            for dy = 0, 4 do
                for dx = 0, 4 do
                    if pattern[dy + 1][dx + 1] == 1 then
                        local cellX = (gridX - 2) + dx
                        local cellY = (gridY - 2) + dy
                        if cellX >= 0 and cellX < Editor.level.width and cellY >= 0 and cellY < Editor.level.height then
                            love.graphics.rectangle("fill", cellX * Cell.SIZE, cellY * Cell.SIZE, Cell.SIZE, Cell.SIZE)
                        end
                    end
                end
            end
            
            -- Draw outline
            love.graphics.setColor(1, 1, 0, 1)
            for dy = 0, 4 do
                for dx = 0, 4 do
                    if pattern[dy + 1][dx + 1] == 1 then
                        local cellX = (gridX - 2) + dx
                        local cellY = (gridY - 2) + dy
                        if cellX >= 0 and cellX < Editor.level.width and cellY >= 0 and cellY < Editor.level.height then
                            love.graphics.rectangle("line", cellX * Cell.SIZE, cellY * Cell.SIZE, Cell.SIZE, Cell.SIZE)
                        end
                    end
                end
            end
        elseif Editor.currentTool then
            -- Draw brush outline
            love.graphics.setColor(1, 1, 1, 0.5)
            for y = -Editor.brushSize + 1, Editor.brushSize - 1 do
                for x = -Editor.brushSize + 1, Editor.brushSize - 1 do
                    local distance = math.sqrt(x*x + y*y)
                    if distance < Editor.brushSize then
                        local cellX = gridX + x
                        local cellY = gridY + y
                        if cellX >= 0 and cellX < Editor.level.width and cellY >= 0 and cellY < Editor.level.height then
                            love.graphics.rectangle("line", 
                                cellX * Cell.SIZE, 
                                cellY * Cell.SIZE, 
                                Cell.SIZE, Cell.SIZE)
                        end
                    end
                end
            end
        end
    end
end

return EditorUI
