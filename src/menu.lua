-- menu.lua - Main menu for Square Golf

local Menu = {}
local Camera = require("src.camera")
local Cell = require("cell")

-- Menu state
Menu.active = false
Menu.selectedOption = 1
Menu.options = {
    { text = "Play" },
    { text = "Editor" },
    { text = "Sandbox" }
}

-- Current level in play mode
Menu.currentLevel = 1
Menu.totalLevels = 0

-- Button dimensions
Menu.buttonWidth = 200
Menu.buttonHeight = 40
Menu.buttonSpacing = 10

-- Background level
Menu.backgroundLevel = nil
Menu.backgroundLevelLoaded = false

-- Initialize the menu
function Menu.init()
    -- Load the menu font if not already loaded
    if not Menu.titleFont then
        Menu.titleFont = love.graphics.newFont("fonts/pixel_font.ttf", 48)
    end
    
    if not Menu.optionFont then
        Menu.optionFont = love.graphics.newFont("fonts/pixel_font.ttf", 24)
    end
    
    if not Menu.descriptionFont then
        Menu.descriptionFont = love.graphics.newFont("fonts/pixel_font.ttf", 18)
    end
    
    -- Count available levels
    Menu.refreshLevelCount()
    
    -- Calculate button positions
    Menu.calculateButtonPositions()
    
    -- Load background level if not already loaded
    if not Menu.backgroundLevelLoaded then
        Menu.loadBackgroundLevel()
    end
end

-- Load level1.json as background
function Menu.loadBackgroundLevel()
    local levelData = Menu.loadLevel(1)
    if levelData then
        -- Create a level object to store the background
        local Level = require("level")
        local world = love.physics.newWorld(0, 0, true) -- Create a dummy physics world with no gravity
        
        -- Create the level with dimensions from the level file
        local levelWidth = tonumber(levelData.width) or 200
        local levelHeight = tonumber(levelData.height) or 100
        Menu.backgroundLevel = Level.new(world, levelWidth, levelHeight)
        
        -- Set level properties
        for y = 0, levelHeight - 1 do
            for x = 0, levelWidth - 1 do
                local cellType = 0
                
                -- Check if cells is an array or an object
                if type(levelData.cells) == "table" then
                    if type(levelData.cells[0]) == "table" then
                        -- Array of arrays format
                        if levelData.cells[y] and levelData.cells[y][x] then
                            cellType = levelData.cells[y][x]
                        end
                    else
                        -- Object format with y-coordinates as keys
                        if levelData.cells[tostring(y)] and levelData.cells[tostring(y)][tostring(x)] then
                            cellType = levelData.cells[tostring(y)][tostring(x)]
                        end
                    end
                end
                
                Menu.backgroundLevel:setCellType(x, y, cellType)
            end
        end
        
        -- Initialize grass on top of dirt cells
        Menu.backgroundLevel:initializeGrass()
        
        -- Store ball starting position for camera centering
        Menu.ballStartX = levelData.startX * Cell.SIZE
        Menu.ballStartY = levelData.startY * Cell.SIZE
        
        -- Initialize camera to ball starting position
        Camera.init(Menu.ballStartX, Menu.ballStartY)
        
        Menu.backgroundLevelLoaded = true
    end
end

-- Calculate button positions
function Menu.calculateButtonPositions()
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Calculate button positions
    for i, option in ipairs(Menu.options) do
        -- Set width and height
        option.width = Menu.buttonWidth
        option.height = Menu.buttonHeight
        
        -- Position at bottom left
        option.x = 50
        
        -- Set vertical position with proper spacing from bottom
        option.y = height - ((#Menu.options - i + 1) * (Menu.buttonHeight + Menu.buttonSpacing)) - 20
    end
end

-- Refresh the count of available levels
function Menu.refreshLevelCount()
    -- Check for level files in the project directory
    local projectLevelsDir = love.filesystem.getSourceBaseDirectory() .. "/cube-test/levels"
    print("Looking for levels in: " .. projectLevelsDir)
    local levelCount = 0
    
    -- Use io.popen to list files in the project directory
    local projectDir = io.popen('ls "' .. projectLevelsDir .. '"')
    if projectDir then
        for file in projectDir:lines() do
            if string.match(file, "^level%d+%.json$") then
                local levelNumber = tonumber(string.match(file, "level(%d+)"))
                if levelNumber and levelNumber > levelCount then
                    levelCount = levelNumber
                end
            end
        end
        projectDir:close()
    end
    
    Menu.totalLevels = levelCount
    print("Found " .. levelCount .. " levels")
end

-- Draw the menu
function Menu.draw()
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Draw background level if loaded (with zoom)
    if Menu.backgroundLevel and Menu.backgroundLevelLoaded then
        -- Apply camera transformation with zoom
        love.graphics.push()
        
        -- Get level dimensions
        local levelWidth = Menu.backgroundLevel.width * Cell.SIZE
        local levelHeight = Menu.backgroundLevel.height * Cell.SIZE
        
        -- Apply zoom level to scale
        local scale = ZOOM_LEVEL -- Use the global zoom level
        
        -- Apply scaling transformation
        love.graphics.scale(scale, scale)
        
        -- Adjust width and height for scaled coordinates
        local scaledWidth = width / scale
        local scaledHeight = height / scale
        
        -- Center the game in the window
        local offsetX = (scaledWidth - levelWidth) / 2
        local offsetY = (scaledHeight - levelHeight) / 2
        
        -- Calculate camera offset to center on ball starting position
        local cameraOffsetX = levelWidth / 2 - Menu.ballStartX
        local cameraOffsetY = levelHeight / 2 - Menu.ballStartY
        
        -- Apply camera transformation with offsets
        love.graphics.translate(offsetX + cameraOffsetX, offsetY + cameraOffsetY)
        
        -- Draw the level
        Menu.backgroundLevel:draw(false)
        
        -- Reset transformation
        love.graphics.pop()
    else
        -- Fallback background if level not loaded - use same dark navy blue as PLAY mode
        local GameState = require("src.game_state")
        
        -- Draw solid dark navy blue background to match PLAY mode level background
        love.graphics.setColor(GameState.LEVEL_BACKGROUND_COLOR[1], GameState.LEVEL_BACKGROUND_COLOR[2], 
                              GameState.LEVEL_BACKGROUND_COLOR[3], GameState.LEVEL_BACKGROUND_COLOR[4])
        love.graphics.rectangle("fill", 0, 0, width, height)
    end
    
    -- Draw UI elements without scaling
    Menu.drawUI(width, height)
end

-- Draw menu UI elements (without scaling)
function Menu.drawUI(width, height)
    -- Draw title
    love.graphics.setFont(Menu.titleFont)
    love.graphics.setColor(0, 0.8, 0.8, 1)
    local title = "SQUARE GOLF"
    local titleWidth = Menu.titleFont:getWidth(title)
    love.graphics.print(title, (width - titleWidth) / 2, 100)
    
    -- Draw options
    love.graphics.setFont(Menu.optionFont)
    for i, option in ipairs(Menu.options) do
        -- Highlight selected option
        if i == Menu.selectedOption then
            love.graphics.setColor(0.3, 0.3, 0.6, 1)
        else
            love.graphics.setColor(0.2, 0.2, 0.4, 1)
        end
        
        -- Draw button background
        -- love.graphics.rectangle("fill", option.x, option.y, option.width, option.height)
        
        -- Draw button border
        -- love.graphics.setColor(0, 0.8, 0.8, 1)
        -- love.graphics.rectangle("line", option.x, option.y, option.width, option.height)
        
        -- Draw button text
        if i == Menu.selectedOption then
            love.graphics.setColor(1, 1, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        
        local optionWidth = Menu.optionFont:getWidth(option.text)
        love.graphics.print(option.text, option.x + 30, option.y + 8)
    end
    
    -- Display zoom level
    love.graphics.setFont(Menu.descriptionFont)
    love.graphics.setColor(0, 0.8, 0.8, 1)
    local zoomText = "ZOOM: " .. string.format("%.1f", ZOOM_LEVEL) .. "x (Use +/- keys or mouse wheel)"
    love.graphics.print(zoomText, 10, 10)
end

-- Update the menu
function Menu.update(dt)
    Menu.calculateButtonPositions()
    
    -- Update camera if needed
    if Menu.backgroundLevelLoaded and Menu.ballStartX and Menu.ballStartY then
        Camera.update(Menu.ballStartX, Menu.ballStartY, dt)
    end
end

-- Handle key press in menu
function Menu.handleKeyPressed(key)
    if key == "up" then
        Menu.selectedOption = Menu.selectedOption - 1
        if Menu.selectedOption < 1 then
            Menu.selectedOption = #Menu.options
        end
        return true
    elseif key == "down" then
        Menu.selectedOption = Menu.selectedOption + 1
        if Menu.selectedOption > #Menu.options then
            Menu.selectedOption = 1
        end
        return true
    elseif key == "return" or key == "space" then
        -- Execute the selected option
        return Menu.executeOption(Menu.selectedOption)
    elseif key == "escape" then
        -- Exit menu
        Menu.active = false
        return { action = "sandbox" } -- Default to sandbox mode
    elseif key == "=" or key == "+" then
        -- Increase zoom level
        local GameState = require("src.game_state")
        GameState.increaseZoom()
        return true
    elseif key == "-" then
        -- Decrease zoom level
        local GameState = require("src.game_state")
        GameState.decreaseZoom()
        return true
    elseif key == "0" then
        -- Reset zoom level to default
        local GameState = require("src.game_state")
        GameState.resetZoom()
        return true
    end
    
    return false
end

-- Handle mouse press in menu
function Menu.handleMousePressed(x, y, button)
    if button ~= 1 then return false end -- Only handle left mouse button
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = x, y
    
    -- Check if clicking on a menu option
    for i, option in ipairs(Menu.options) do
        if gameX >= option.x and gameX <= option.x + option.width and
           gameY >= option.y and gameY <= option.y + option.height then
            Menu.selectedOption = i
            return Menu.executeOption(i)
        end
    end
    
    return false
end

-- Handle mouse wheel in menu
function Menu.handleMouseWheel(x, y)
    -- Use mouse wheel for zooming
    local GameState = require("src.game_state")
    if y > 0 then
        -- Scroll up - zoom in
        GameState.increaseZoom()
    elseif y < 0 then
        -- Scroll down - zoom out
        GameState.decreaseZoom()
    end
    return true
end

-- Execute the selected option
function Menu.executeOption(optionIndex)
    if optionIndex == 1 then
        -- PLAY
        Menu.active = false
        return { action = "play", level = Menu.currentLevel }
    elseif optionIndex == 2 then
        -- EDITOR
        Menu.active = false
        return { action = "editor" }
    elseif optionIndex == 3 then
        -- SANDBOX
        Menu.active = false
        return { action = "sandbox" }
    end
    return true
end

-- Load a specific level for play mode
function Menu.loadLevel(levelNumber)
    local filename = "levels/level" .. levelNumber .. ".json"
    local contents
    
    -- First try to load from the project directory
    local projectFilename = love.filesystem.getSourceBaseDirectory() .. "/cube-test/levels/level" .. levelNumber .. ".json"
    print("Trying to load level from project directory: " .. projectFilename)
    
    local file = io.open(projectFilename, "r")
    if file then
        contents = file:read("*all")
        file:close()
        print("Level loaded from project directory: " .. projectFilename)
    else
        -- If not found in project directory, try LÖVE save directory
        print("Level not found in project directory, trying LÖVE save directory")
        
        -- Check if the file exists in LÖVE save directory
        if not love.filesystem.getInfo(filename) then
            print("Level file not found: " .. filename)
            return nil
        end
        
        -- Read file from LÖVE save directory
        contents, size = love.filesystem.read(filename)
        
        if not contents then
            print("Failed to read level file: " .. filename)
            return nil
        end
        
        print("Level loaded from LÖVE save directory: " .. filename)
    end
    
    -- Parse JSON
    local json = require("src.json")
    local levelData = json.decode(contents)
    
    return levelData
end

return Menu
