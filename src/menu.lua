-- menu.lua - Main menu for Square Golf

local Menu = {}

-- Menu state
Menu.active = false
Menu.selectedOption = 1
Menu.options = {
    { text = "PLAY" },
    { text = "EDITOR" },
    { text = "SANDBOX" },
    { text = "EXIT" }
}

-- Current level in play mode
Menu.currentLevel = 1
Menu.totalLevels = 0

-- Button dimensions
Menu.buttonWidth = 300
Menu.buttonHeight = 60
Menu.buttonSpacing = 20

-- Initialize the menu
function Menu.init()
    -- Load the menu font if not already loaded
    if not Menu.titleFont then
        Menu.titleFont = love.graphics.newFont("fonts/pixel_font.ttf", 48)
    end
    
    if not Menu.optionFont then
        Menu.optionFont = love.graphics.newFont("fonts/pixel_font.ttf", 32)
    end
    
    if not Menu.descriptionFont then
        Menu.descriptionFont = love.graphics.newFont("fonts/pixel_font.ttf", 18)
    end
    
    -- Count available levels
    Menu.refreshLevelCount()
    
    -- Calculate button positions
    Menu.calculateButtonPositions()
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
        
        -- Center horizontally
        option.x = (width - option.width) / 2
        
        -- Set vertical position with proper spacing
        if i == 1 then
            -- First button position
            option.y = 200
        else
            local extraSpace = 0
            -- Add extra space after PLAY button for level selector
            if i == 2 then
                extraSpace = 70
            end
            
            -- Previous button's bottom position + spacing + any extra space
            option.y = Menu.options[i-1].y + Menu.buttonHeight + Menu.buttonSpacing + extraSpace
        end
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
    
    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
    
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
        love.graphics.rectangle("fill", option.x, option.y, option.width, option.height)
        
        -- Draw button border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", option.x, option.y, option.width, option.height)
        
        -- Draw button text
        if i == Menu.selectedOption then
            love.graphics.setColor(1, 1, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, 1)
        end
        
        local optionWidth = Menu.optionFont:getWidth(option.text)
        love.graphics.print(option.text, option.x + (option.width - optionWidth) / 2, option.y + 10)
    end
    
    -- Draw level info if PLAY is selected
    if Menu.selectedOption == 1 then
        love.graphics.setFont(Menu.descriptionFont)
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        local levelInfo = "Level " .. Menu.currentLevel .. " / " .. Menu.totalLevels
        local levelInfoWidth = Menu.descriptionFont:getWidth(levelInfo)
        love.graphics.print(levelInfo, (width - levelInfoWidth) / 2, Menu.options[1].y + Menu.buttonHeight + 25)
        
        -- Draw level navigation buttons
        if Menu.totalLevels > 1 then
            -- Left arrow
            love.graphics.setColor(0.2, 0.2, 0.4, 1)
            love.graphics.rectangle("fill", (width - levelInfoWidth) / 2 - 40, Menu.options[1].y + Menu.buttonHeight + 20, 30, 30)
            love.graphics.setColor(0, 0.8, 0.8, 1)
            love.graphics.rectangle("line", (width - levelInfoWidth) / 2 - 40, Menu.options[1].y + Menu.buttonHeight + 20, 30, 30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("<", (width - levelInfoWidth) / 2 - 35, Menu.options[1].y + Menu.buttonHeight + 20)
            
            -- Right arrow
            love.graphics.setColor(0.2, 0.2, 0.4, 1)
            love.graphics.rectangle("fill", (width + levelInfoWidth) / 2 + 10, Menu.options[1].y + Menu.buttonHeight + 20, 30, 30)
            love.graphics.setColor(0, 0.8, 0.8, 1)
            love.graphics.rectangle("line", (width + levelInfoWidth) / 2 + 10, Menu.options[1].y + Menu.buttonHeight + 20, 30, 30)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(">", (width + levelInfoWidth) / 2 + 15, Menu.options[1].y + Menu.buttonHeight + 20)
        end
    end
end

-- Update the menu
function Menu.update(dt)
    Menu.calculateButtonPositions()
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
    elseif key == "left" and Menu.selectedOption == 1 then
        -- Decrease level number in PLAY mode
        Menu.currentLevel = math.max(1, Menu.currentLevel - 1)
        return true
    elseif key == "right" and Menu.selectedOption == 1 then
        -- Increase level number in PLAY mode
        Menu.currentLevel = math.min(Menu.totalLevels, Menu.currentLevel + 1)
        return true
    elseif key == "escape" then
        -- Exit menu
        Menu.active = false
        return { action = "sandbox" } -- Default to sandbox mode
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
    
    -- Check if clicking on level navigation buttons
    if Menu.selectedOption == 1 and Menu.totalLevels > 1 then
        -- Get screen dimensions
        local width = love.graphics.getWidth()
        
        -- Calculate level info position
        local levelInfo = "Level " .. Menu.currentLevel .. " / " .. Menu.totalLevels
        local levelInfoWidth = Menu.descriptionFont:getWidth(levelInfo)
        
        -- Left arrow button
        local leftArrowX = (width - levelInfoWidth) / 2 - 40
        local leftArrowY = Menu.options[1].y + Menu.buttonHeight + 40
        if gameX >= leftArrowX and gameX <= leftArrowX + 30 and
           gameY >= leftArrowY and gameY <= leftArrowY + 30 then
            -- Decrease level number
            Menu.currentLevel = math.max(1, Menu.currentLevel - 1)
            return true
        end
        
        -- Right arrow button
        local rightArrowX = (width + levelInfoWidth) / 2 + 10
        local rightArrowY = Menu.options[1].y + Menu.buttonHeight + 40
        if gameX >= rightArrowX and gameX <= rightArrowX + 30 and
           gameY >= rightArrowY and gameY <= rightArrowY + 30 then
            -- Increase level number
            Menu.currentLevel = math.min(Menu.totalLevels, Menu.currentLevel + 1)
            return true
        end
    end
    
    return false
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
    elseif optionIndex == 4 then
        -- EXIT
        love.event.quit()
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
