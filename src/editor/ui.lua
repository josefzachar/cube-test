-- editor/ui.lua - UI handling for the Square Golf editor

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local Balls = require("src.balls")

local EditorUI = {
    editor = nil
}

-- Initialize the UI module
function EditorUI.init(editor)
    EditorUI.editor = editor
    
    -- Load the button font if not already loaded
    if not EditorUI.editor.buttonFont then
        EditorUI.editor.buttonFont = love.graphics.newFont("fonts/pixel_font.ttf", 18)
    end
    
    -- Create UI elements
    EditorUI.createUI()
end

-- Create editor UI elements
function EditorUI.createUI()
    -- Clear existing buttons
    EditorUI.editor.buttons = {}
    EditorUI.editor.toolButtons = {}
    EditorUI.editor.brushButtons = {}
    EditorUI.editor.ballButtons = {}
    
    -- Button dimensions
    local buttonWidth = 120
    local buttonHeight = 30
    local buttonMargin = 10
    local panelWidth = 150
    
    -- Create tool buttons
    local tools = {"draw", "erase", "fill", "start", "winhole"}
    local toolNames = {"DRAW", "ERASE", "FILL", "SET START", "SET HOLE"}
    
    for i, tool in ipairs(tools) do
        local button = {
            x = 10,
            y = 50 + (i-1) * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = toolNames[i],
            action = function()
                EditorUI.editor.currentTool = tool
            end,
            isSelected = function()
                return EditorUI.editor.currentTool == tool
            end
        }
        table.insert(EditorUI.editor.toolButtons, button)
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
                EditorUI.editor.brushSize = size
            end,
            isSelected = function()
                return EditorUI.editor.brushSize == size
            end
        }
        table.insert(EditorUI.editor.brushButtons, button)
    end
    
    -- Create cell type buttons
    for i, cellTypeName in ipairs(EditorUI.editor.CELL_TYPES) do
        local button = {
            x = 10,
            y = 500 + (i-1) * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = cellTypeName,
            action = function()
                EditorUI.editor.currentCellType = cellTypeName
            end,
            isSelected = function()
                return EditorUI.editor.currentCellType == cellTypeName
            end
        }
        table.insert(EditorUI.editor.buttons, button)
    end
    
    -- Create ball selection buttons
    local ballTypes = {
        {type = "standard", name = "STANDARD"},
        {type = "heavy", name = "HEAVY"},
        {type = "exploding", name = "EXPLODING"},
        {type = "sticky", name = "STICKY"}
    }
    
    -- Get screen dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    
    for i, ball in ipairs(ballTypes) do
        local button = {
            x = gameWidth - panelWidth + 20,
            y = 50 + (i-1) * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = ball.name,
            action = function()
                EditorUI.editor.availableBalls[ball.type] = not EditorUI.editor.availableBalls[ball.type]
            end,
            isSelected = function()
                return EditorUI.editor.availableBalls[ball.type]
            end
        }
        table.insert(EditorUI.editor.ballButtons, button)
    end
    
    -- Get EditorFile module
    local EditorFile = require("src.editor.file")
    
    -- Create main editor buttons
    local mainButtons = {
        {
            x = gameWidth - panelWidth + 20,
            y = 200,
            width = buttonWidth,
            height = buttonHeight,
            text = "SAVE",
            action = function()
                EditorFile.saveLevel()
            end
        },
        {
            x = gameWidth - panelWidth + 20,
            y = 200 + buttonHeight + buttonMargin,
            width = buttonWidth,
            height = buttonHeight,
            text = "LOAD",
            action = function()
                EditorFile.loadLevel()
            end
        },
        {
            x = gameWidth - panelWidth + 20,
            y = 200 + 2 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "CLEAR",
            action = function()
                EditorUI.editor.clearLevel()
            end
        },
        {
            x = gameWidth - panelWidth + 20,
            y = 200 + 3 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "SET NAME",
            action = function()
                EditorUI.editor.textInput.active = true
                EditorUI.editor.textInput.text = EditorUI.editor.levelName
                EditorUI.editor.textInput.cursor = #EditorUI.editor.levelName
            end
        },
        {
            x = gameWidth - panelWidth + 20,
            y = 200 + 4 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "TEST PLAY",
            action = function()
                -- Get Game module
                local Game = require("src.game")
                
                -- Test play the level
                local ball = EditorUI.editor.testPlay()
                
                -- Set the ball in the game
                Game.ball = ball
                
                -- Set test play mode
                Game.testPlayMode = true
            end
        },
        {
            x = gameWidth - panelWidth + 20,
            y = 200 + 5 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "EXIT EDITOR",
            action = function()
                EditorUI.editor.active = false
            end
        },
        {
            x = gameWidth - panelWidth + 20,
            y = 200 + 6 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "?",
            action = function()
                EditorUI.editor.showHelp = not EditorUI.editor.showHelp
            end
        }
    }
    
    for _, button in ipairs(mainButtons) do
        table.insert(EditorUI.editor.buttons, button)
    end
end

-- Draw the editor UI
function EditorUI.draw()
    -- Get game dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    
    -- Get actual screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Calculate scaled dimensions
    local scaleX = screenWidth / gameWidth
    local scaleY = screenHeight / gameHeight
    local scale = math.min(scaleX, scaleY)
    
    -- Calculate offsets for centering
    local scaledWidth = screenWidth / scale
    local scaledHeight = screenHeight / scale
    local offsetX = (scaledWidth - gameWidth) / 2
    local offsetY = (scaledHeight - gameHeight) / 2
    
    -- Save current transformation
    love.graphics.push()
    
    -- Reset transformation to draw UI in screen coordinates
    love.graphics.origin()
    
    -- Apply scaling to match game coordinates
    love.graphics.scale(scale, scale)
    
    -- Apply offset for centering
    love.graphics.translate(offsetX, offsetY)
    
    -- Draw left panel background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", 0, 0, 140, gameHeight)
    
    -- Draw right panel background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", gameWidth - 140, 0, 140, gameHeight)
    
    -- Draw tool buttons
    love.graphics.setFont(EditorUI.editor.buttonFont)
    for _, button in ipairs(EditorUI.editor.toolButtons) do
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
        local textWidth = EditorUI.editor.buttonFont:getWidth(button.text)
        local textHeight = EditorUI.editor.buttonFont:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    -- Draw brush size buttons
    for _, button in ipairs(EditorUI.editor.brushButtons) do
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
        local textWidth = EditorUI.editor.buttonFont:getWidth(button.text)
        local textHeight = EditorUI.editor.buttonFont:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    -- Draw ball selection buttons
    for _, button in ipairs(EditorUI.editor.ballButtons) do
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
        local textWidth = EditorUI.editor.buttonFont:getWidth(button.text)
        local textHeight = EditorUI.editor.buttonFont:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    -- Draw main buttons
    for _, button in ipairs(EditorUI.editor.buttons) do
        -- Button background
        if button.isSelected and button.isSelected() then
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
        local textWidth = EditorUI.editor.buttonFont:getWidth(button.text)
        local textHeight = EditorUI.editor.buttonFont:getHeight()
        love.graphics.print(button.text, 
            button.x + (button.width - textWidth) / 2, 
            button.y + (button.height - textHeight) / 2)
    end
    
    -- Draw level name
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("LEVEL NAME:", 10, 10)
    love.graphics.print(EditorUI.editor.levelName, 10, 30)
    
    -- Draw start position
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("START: " .. EditorUI.editor.startX .. "," .. EditorUI.editor.startY, 10, 700)
    
    -- Draw help panel if enabled
    if EditorUI.editor.showHelp then
        -- Draw semi-transparent background for help panel
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", gameWidth/2 - 200, 100, 400, 400)
        
        -- Draw help panel border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", gameWidth/2 - 200, 100, 400, 400)
        
        -- Draw help panel title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("EDITOR SHORTCUTS", gameWidth/2 - 180, 110)
        
        -- Draw help panel content
        local y = 140
        local lineHeight = 20
        love.graphics.print("A/D: Previous/Next Material", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("W/S: Increase/Decrease Brush Size", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("Mouse Wheel: Change Brush Size", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("Left Click: Draw with Selected Material", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("Right Click: Erase", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("T: Draw Tool", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("F: Fill Tool", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("X: Erase Tool", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("P: Start Position Tool", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("H: Win Hole Tool", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("Space: Toggle UI", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("1-6: Quick Select Materials", gameWidth/2 - 180, y); y = y + lineHeight
        love.graphics.print("?: Toggle Help Panel", gameWidth/2 - 180, y); y = y + lineHeight
    end
    
    -- Draw text input if active
    if EditorUI.editor.textInput.active then
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
        love.graphics.print(EditorUI.editor.textInput.text, gameWidth/2 - 180, gameHeight/2)
        
        -- Draw cursor
        if EditorUI.editor.textInput.cursorVisible then
            local cursorX = gameWidth/2 - 180 + EditorUI.editor.buttonFont:getWidth(string.sub(EditorUI.editor.textInput.text, 1, EditorUI.editor.textInput.cursor))
            love.graphics.rectangle("fill", cursorX, gameHeight/2, 2, 20)
        end
    end
    
    -- Restore previous transformation
    love.graphics.pop()
end

-- Draw cursor preview based on current tool
function EditorUI.drawCursorPreview()
    -- Get game dimensions
    local gameWidth = 1600  -- Same as ORIGINAL_WIDTH in main.lua
    local gameHeight = 1000 -- Same as ORIGINAL_HEIGHT in main.lua
    
    -- Get actual screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Calculate scaled dimensions
    local scaleX = screenWidth / gameWidth
    local scaleY = screenHeight / gameHeight
    local scale = math.min(scaleX, scaleY)
    
    -- Calculate offsets for centering
    local scaledWidth = screenWidth / scale
    local scaledHeight = screenHeight / scale
    local offsetX = (scaledWidth - gameWidth) / 2
    local offsetY = (scaledHeight - gameHeight) / 2
    
    -- Save current transformation
    love.graphics.push()
    
    -- Reset transformation to draw in screen coordinates
    love.graphics.origin()
    
    -- Apply scaling to match game coordinates
    love.graphics.scale(scale, scale)
    
    -- Apply offset for centering
    love.graphics.translate(offsetX, offsetY)
    
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    local gameX, gameY = EditorUI.editor.screenToGameCoords(mouseX, mouseY)
    local gridX, gridY = EditorUI.editor.level:getGridCoordinates(gameX, gameY)
    
    -- Check if mouse is in UI area (left or right panel)
    if gameX < 140 or gameX > gameWidth - 140 then
        -- Mouse is in UI area, don't draw cursor preview
        love.graphics.pop() -- Restore previous transformation
        return
    end
    
    -- Only draw cursor/preview if mouse is in the level area
    if gridX >= 0 and gridX < EditorUI.editor.level.width and gridY >= 0 and gridY < EditorUI.editor.level.height then
        if EditorUI.editor.currentTool == "start" then
            -- Draw ball cursor
            love.graphics.setColor(0, 1, 0, 0.7)
            love.graphics.rectangle("fill", gridX * Cell.SIZE, gridY * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            love.graphics.setColor(0, 1, 0, 1)
            love.graphics.rectangle("line", gridX * Cell.SIZE, gridY * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        elseif EditorUI.editor.currentTool == "winhole" then
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
                        if cellX >= 0 and cellX < EditorUI.editor.level.width and cellY >= 0 and cellY < EditorUI.editor.level.height then
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
                        if cellX >= 0 and cellX < EditorUI.editor.level.width and cellY >= 0 and cellY < EditorUI.editor.level.height then
                            love.graphics.rectangle("line", cellX * Cell.SIZE, cellY * Cell.SIZE, Cell.SIZE, Cell.SIZE)
                        end
                    end
                end
            end
        elseif EditorUI.editor.currentTool then
            -- Draw brush outline
            local brushSize = EditorUI.editor.brushSize
            local cellSize = Cell.SIZE
            
            -- Calculate brush rectangle
            local brushX = gridX * cellSize - (brushSize - 1) * cellSize / 2
            local brushY = gridY * cellSize - (brushSize - 1) * cellSize / 2
            local brushWidth = brushSize * cellSize
            local brushHeight = brushSize * cellSize
            
            -- Set color based on material type
            if EditorUI.editor.currentTool == "draw" or EditorUI.editor.currentTool == "fill" then
                if EditorUI.editor.currentCellType == "DIRT" then
                    love.graphics.setColor(0.5, 0.3, 0.1, 0.5) -- Brown for dirt
                elseif EditorUI.editor.currentCellType == "SAND" then
                    love.graphics.setColor(0.9, 0.8, 0.2, 0.5) -- Yellow for sand
                elseif EditorUI.editor.currentCellType == "STONE" then
                    love.graphics.setColor(0.5, 0.5, 0.5, 0.5) -- Gray for stone
                elseif EditorUI.editor.currentCellType == "WATER" then
                    love.graphics.setColor(0.2, 0.4, 0.8, 0.5) -- Blue for water
                elseif EditorUI.editor.currentCellType == "FIRE" then
                    love.graphics.setColor(0.9, 0.3, 0.1, 0.5) -- Red for fire
                else
                    love.graphics.setColor(1, 1, 1, 0.5) -- White for empty
                end
                
                -- Fill the brush area with a semi-transparent color
                love.graphics.rectangle("fill", brushX, brushY, brushWidth, brushHeight)
            else
                -- For erase tool, use white outline
                love.graphics.setColor(1, 1, 1, 0.5)
            end
            
            -- Draw brush outline
            love.graphics.rectangle("line", brushX, brushY, brushWidth, brushHeight)
            
            -- Display material type text above the brush
            if EditorUI.editor.currentTool == "draw" or EditorUI.editor.currentTool == "fill" then
                love.graphics.setColor(1, 1, 1, 1)
                local text = EditorUI.editor.currentCellType
                local textWidth = EditorUI.editor.buttonFont:getWidth(text)
                love.graphics.print(text, brushX + (brushWidth - textWidth) / 2, brushY - 25)
            end
        end
    end
    
    -- Restore previous transformation
    love.graphics.pop()
end

-- Handle mouse press in UI
function EditorUI.handleMousePressed(x, y, button)
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = EditorUI.editor.screenToGameCoords(x, y)
    
    -- Check if clicking on a button
    for _, buttonGroup in ipairs({EditorUI.editor.toolButtons, EditorUI.editor.brushButtons, EditorUI.editor.ballButtons, EditorUI.editor.buttons}) do
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
    if EditorUI.editor.textInput.active and 
       (gameX < gameWidth/2 - 200 or gameX > gameWidth/2 + 200 or
        gameY < gameHeight/2 - 50 or gameY > gameHeight/2 + 50) then
        EditorUI.editor.levelName = EditorUI.editor.textInput.text
        EditorUI.editor.textInput.active = false
        return true
    end
    
    -- Check if clicking in UI area
    if gameX < 140 or gameX > gameWidth - 140 then
        -- Clicking in UI area
        return true
    end
    
    return false
end

return EditorUI
