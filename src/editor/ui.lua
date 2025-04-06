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
    local width, height = love.graphics.getDimensions()
    
    for i, ball in ipairs(ballTypes) do
        local button = {
            x = width - panelWidth + 20,
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
            x = width - panelWidth + 20,
            y = 200,
            width = buttonWidth,
            height = buttonHeight,
            text = "SAVE",
            action = function()
                EditorFile.saveLevel()
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + buttonHeight + buttonMargin,
            width = buttonWidth,
            height = buttonHeight,
            text = "LOAD",
            action = function()
                EditorFile.loadLevel()
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + 2 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "CLEAR",
            action = function()
                EditorUI.editor.clearLevel()
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + 3 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "SET NAME",
            action = function()
                EditorUI.editor.textInput.active = true
                EditorUI.editor.textInput.text = EditorUI.editor.levelName
                EditorUI.editor.textInput.cursor = #EditorUI.editor.levelName
                EditorUI.editor.textInput.mode = "levelName"
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + 4 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "SET WIDTH",
            action = function()
                EditorUI.editor.textInput.active = true
                EditorUI.editor.textInput.text = tostring(EditorUI.editor.level.width)
                EditorUI.editor.textInput.cursor = #EditorUI.editor.textInput.text
                EditorUI.editor.textInput.mode = "levelWidth"
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + 5 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "SET HEIGHT",
            action = function()
                EditorUI.editor.textInput.active = true
                EditorUI.editor.textInput.text = tostring(EditorUI.editor.level.height)
                EditorUI.editor.textInput.cursor = #EditorUI.editor.textInput.text
                EditorUI.editor.textInput.mode = "levelHeight"
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + 6 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "RESIZE LEVEL",
            action = function()
                -- Open a dialog to resize the level
                EditorUI.editor.textInput.active = true
                EditorUI.editor.textInput.text = tostring(EditorUI.editor.level.width) .. "," .. tostring(EditorUI.editor.level.height)
                EditorUI.editor.textInput.cursor = #EditorUI.editor.textInput.text
                EditorUI.editor.textInput.mode = "levelSize"
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + 7 * (buttonHeight + buttonMargin),
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
            x = width - panelWidth + 20,
            y = 200 + 8 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "EXIT EDITOR",
            action = function()
                EditorUI.editor.active = false
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + 9 * (buttonHeight + buttonMargin),
            width = buttonWidth,
            height = buttonHeight,
            text = "BOUNDARIES",
            action = function()
                EditorUI.editor.createBoundaries()
            end
        },
        {
            x = width - panelWidth + 20,
            y = 200 + 10 * (buttonHeight + buttonMargin),
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
    -- Get actual screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Save current transformation
    love.graphics.push()
    
    -- Reset transformation to draw UI in screen coordinates
    love.graphics.origin()
    
    -- Draw left panel background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", 0, 0, 140, height)
    
    -- Draw right panel background
    love.graphics.setColor(0.1, 0.1, 0.2, 0.9)
    love.graphics.rectangle("fill", width - 140, 0, 140, height)
    
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
    
    -- Draw level size
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("SIZE: " .. EditorUI.editor.level.width .. "x" .. EditorUI.editor.level.height, 10, 730)
    
    -- Draw help panel if enabled
    if EditorUI.editor.showHelp then
        -- Draw semi-transparent background for help panel
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", width/2 - 200, 100, 400, 400)
        
        -- Draw help panel border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", width/2 - 200, 100, 400, 400)
        
        -- Draw help panel title
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("EDITOR SHORTCUTS", width/2 - 180, 110)
        
        -- Draw help panel content
        local y = 140
        local lineHeight = 20
        love.graphics.print("A/D: Previous/Next Material", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("W/S: Increase/Decrease Brush Size", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("Mouse Wheel: Change Brush Size", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("Left Click: Draw with Selected Material", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("Right Click: Erase", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("T: Draw Tool", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("F: Fill Tool", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("X: Erase Tool", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("P: Start Position Tool", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("H: Win Hole Tool", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("Space: Toggle UI", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("1-6: Quick Select Materials", width/2 - 180, y); y = y + lineHeight
        love.graphics.print("?: Toggle Help Panel", width/2 - 180, y); y = y + lineHeight
    end
    
    -- Draw text input if active
    if EditorUI.editor.textInput.active then
        -- Draw input background
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", width/2 - 200, height/2 - 50, 400, 100)
        
        -- Draw input border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", width/2 - 200, height/2 - 50, 400, 100)
        
        -- Draw input title based on mode
        love.graphics.setColor(1, 1, 1, 1)
        local titleText = "Enter Level Name:"
        if EditorUI.editor.textInput.mode == "levelWidth" then
            titleText = "Enter Level Width (20-500):"
        elseif EditorUI.editor.textInput.mode == "levelHeight" then
            titleText = "Enter Level Height (20-500):"
        elseif EditorUI.editor.textInput.mode == "levelSize" then
            titleText = "Enter Level Size (width,height):"
        end
        love.graphics.print(titleText, width/2 - 180, height/2 - 40)
        
        -- Draw input text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(EditorUI.editor.textInput.text, width/2 - 180, height/2)
        
        -- Draw cursor
        if EditorUI.editor.textInput.cursorVisible then
            local cursorX = width/2 - 180 + EditorUI.editor.buttonFont:getWidth(string.sub(EditorUI.editor.textInput.text, 1, EditorUI.editor.textInput.cursor))
            love.graphics.rectangle("fill", cursorX, height/2, 2, 20)
        end
    end
    
    -- Restore previous transformation
    love.graphics.pop()
end

-- Draw cursor preview based on current tool
function EditorUI.drawCursorPreview()
    -- Get mouse position first
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Get game coordinates using editor's camera
    local gameX, gameY = EditorUI.editor.screenToGameCoords(mouseX, mouseY)
    
    -- Get grid coordinates
    local Cell = require("cell")
    local InputUtils = require("src.input_utils")
    local gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, Cell.SIZE)
    
    -- Get cell size
    local cellSize = Cell.SIZE
    
    -- Get screen dimensions
    local width = love.graphics.getWidth()
    
    -- Save current transformation
    love.graphics.push()
    
    -- Get camera module
    local EditorCamera = require("src.editor.camera")
    
    -- Apply camera transformation with zoom
    love.graphics.scale(EditorCamera.zoom, EditorCamera.zoom)
    love.graphics.translate(-EditorUI.editor.cameraX, -EditorUI.editor.cameraY)
    
    -- No need to check if mouse is in UI area anymore
    
    -- Only draw cursor/preview if mouse is in the level area
    if gridX >= 0 and gridX < EditorUI.editor.level.width and gridY >= 0 and gridY < EditorUI.editor.level.height then
        -- Get brush size
        local brushSize = EditorUI.editor.brushSize
        
        -- Calculate brush dimensions based on brush size
        local brushWidth = cellSize * brushSize
        local brushHeight = cellSize * brushSize
        
        -- Calculate brush center at the grid position
        local centerX = gridX
        local centerY = gridY
        
        -- Calculate brush radius (half the brush size)
        local radius = math.floor(brushSize / 2)
        
        -- Calculate brush start position (top-left corner)
        local startGridX = centerX - radius
        local startGridY = centerY - radius
        
        -- Calculate brush position in game coordinates
        local brushX = startGridX * cellSize
        local brushY = startGridY * cellSize
        
        -- Calculate brush position for drawing
        
        if EditorUI.editor.currentTool == "start" then
            -- Draw start position cursor
            love.graphics.setColor(0.2, 0.8, 0.2, 0.5) -- Light green with transparency
            
            -- Draw brush with proper size (single cell for start position)
            local cellX = gridX
            local cellY = gridY
            if cellX >= 0 and cellX < EditorUI.editor.level.width and cellY >= 0 and cellY < EditorUI.editor.level.height then
                -- Fill the cell with a semi-transparent color
                love.graphics.rectangle("fill", cellX * cellSize, cellY * cellSize, cellSize, cellSize)
                -- Draw cell outline
                love.graphics.setColor(0.2, 0.8, 0.2, 1) -- Solid green for outline
                love.graphics.rectangle("line", cellX * cellSize, cellY * cellSize, cellSize, cellSize)
            end
            
            -- Display position text above the brush
            love.graphics.setColor(1, 1, 1, 1)
            local text = "START"
            local textWidth = EditorUI.editor.buttonFont:getWidth(text)
            love.graphics.print(text, (cellX * cellSize) + (cellSize - textWidth) / 2, (cellY * cellSize) - 25)
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
                            love.graphics.rectangle("fill", cellX * cellSize, cellY * cellSize, cellSize, cellSize)
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
                            love.graphics.rectangle("line", cellX * cellSize, cellY * cellSize, cellSize, cellSize)
                        end
                    end
                end
            end
        elseif EditorUI.editor.currentTool == "draw" or EditorUI.editor.currentTool == "fill" then
            -- Set color based on material type
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
            
            -- Draw brush with proper size
            for by = 0, brushSize - 1 do
                for bx = 0, brushSize - 1 do
                    local cellX = startGridX + bx
                    local cellY = startGridY + by
                    if cellX >= 0 and cellX < EditorUI.editor.level.width and cellY >= 0 and cellY < EditorUI.editor.level.height then
                        -- Fill the cell with a semi-transparent color
                        love.graphics.rectangle("fill", cellX * cellSize, cellY * cellSize, cellSize, cellSize)
                        -- Draw cell outline
                        love.graphics.rectangle("line", cellX * cellSize, cellY * cellSize, cellSize, cellSize)
                    end
                end
            end
            
            -- Display material type text above the brush
            love.graphics.setColor(1, 1, 1, 1)
            local text = EditorUI.editor.currentCellType
            local textWidth = EditorUI.editor.buttonFont:getWidth(text)
            love.graphics.print(text, brushX + (brushWidth - textWidth) / 2, brushY - 25)
        elseif EditorUI.editor.currentTool == "erase" then
            -- For erase tool, use white outline
            love.graphics.setColor(1, 1, 1, 0.5)
            
            -- Draw brush with proper size
            for by = 0, brushSize - 1 do
                for bx = 0, brushSize - 1 do
                    local cellX = startGridX + bx
                    local cellY = startGridY + by
                    if cellX >= 0 and cellX < EditorUI.editor.level.width and cellY >= 0 and cellY < EditorUI.editor.level.height then
                        -- Draw cell outline
                        love.graphics.rectangle("line", cellX * cellSize, cellY * cellSize, cellSize, cellSize)
                    end
                end
            end
        end
    end
    
    -- Restore previous transformation
    love.graphics.pop()
    
    -- End of cursor preview drawing
end

-- Handle mouse press in UI
function EditorUI.handleMousePressed(x, y, button)
    -- Use raw screen coordinates for UI elements
    local screenX, screenY = x, y
    
    -- Check if clicking on a button
    for _, buttonGroup in ipairs({EditorUI.editor.toolButtons, EditorUI.editor.brushButtons, EditorUI.editor.ballButtons, EditorUI.editor.buttons}) do
        for _, button in ipairs(buttonGroup) do
            if screenX >= button.x and screenX <= button.x + button.width and
               screenY >= button.y and screenY <= button.y + button.height then
                button.action()
                return true
            end
        end
    end
    
    -- If text input is active, clicking outside closes it
    local width, height = love.graphics.getDimensions()
    if EditorUI.editor.textInput.active and 
       (screenX < width/2 - 200 or screenX > width/2 + 200 or
        screenY < height/2 - 50 or screenY > height/2 + 50) then
        
        -- Handle different text input modes
        if EditorUI.editor.textInput.mode == "levelName" then
            EditorUI.editor.levelName = EditorUI.editor.textInput.text
        elseif EditorUI.editor.textInput.mode == "levelWidth" then
            local newWidth = tonumber(EditorUI.editor.textInput.text)
            if newWidth and newWidth >= 20 and newWidth <= 500 then
                EditorUI.editor.resizeLevel(newWidth, EditorUI.editor.level.height)
            end
        elseif EditorUI.editor.textInput.mode == "levelHeight" then
            local newHeight = tonumber(EditorUI.editor.textInput.text)
            if newHeight and newHeight >= 20 and newHeight <= 500 then
                EditorUI.editor.resizeLevel(EditorUI.editor.level.width, newHeight)
            end
        end
        
        EditorUI.editor.textInput.active = false
        return true
    end
    
    -- No need to check if clicking in UI area anymore
    
    return false
end

return EditorUI
