-- Square Golf Game
-- A simple golf game where the ball is a square and the level is made of cells

-- Load modules
local Balls = require("src.balls")
local Cell = require("cell")
local Level = require("level")
local Input = require("input")
local Collision = require("src.collision")
local Effects = require("src.effects")
local Debug = require("src.debug")
local CellTypes = require("src.cell_types")
local Fire = require("src.fire")
local WinHole = require("src.win_hole")
local UI = require("src.ui")
local Sound = require("src.sound")
local Editor = require("src.editor")

-- Game variables
local world
local ball
local level
local input
local attempts = 0
local debug = false -- Set to true to see physics bodies
local currentBallType = Balls.TYPES.STANDARD -- Start with standard ball
local gameWon = false -- Flag to track if the player has won
local winMessageTimer = 0 -- Timer for displaying the win message
currentDifficulty = 1 -- Current difficulty level (1-5) - global variable
local editorMode = false -- Flag to track if editor is active

-- Colors
local WHITE = {1, 1, 1, 1}
-- Background colors for gradient
BACKGROUND_COLOR = {0.2, 0.3, 0.6, 1.0} -- Dark blue (base color)
BACKGROUND_COLOR_TOP = {0.1, 0.2, 0.4, 1.0} -- Darker blue for top
BACKGROUND_COLOR_BOTTOM = {0.3, 0.4, 0.7, 1.0} -- Lighter blue for bottom

-- Original design dimensions
local ORIGINAL_WIDTH = 1600
local ORIGINAL_HEIGHT = 1000

-- Make these global so they can be accessed from other modules
GAME_SCALE = 1
GAME_OFFSET_X = 0
GAME_OFFSET_Y = 0

-- Function to create a diamond-shaped win hole
function createDiamondWinHole(level, holeX, holeY)
    -- First, scan the entire level and clear any existing win holes
    -- This ensures no win holes remain from previous level generations
    for y = 0, level.height - 1 do
        for x = 0, level.width - 1 do
            if level:getCellType(x, y) == CellTypes.TYPES.WIN_HOLE then
                level:setCellType(x, y, CellTypes.TYPES.EMPTY)
            end
        end
    end
    -- Ball starting position
    local ballStartX, ballStartY = 20, 20
    local minDistanceFromBall = 40 -- Minimum distance from ball starting position
    
    -- If no position is provided, choose a random position
    if not holeX or not holeY then
        -- Choose a random position from several possible locations
        local possibleLocations = {
            {x = level.width - 20, y = level.height - 20}, -- Bottom right
            {x = 20, y = level.height - 20},               -- Bottom left
            {x = level.width - 20, y = 20},                -- Top right
            {x = level.width / 2, y = 20},                 -- Top middle
            {x = level.width / 2, y = level.height - 20},  -- Bottom middle
            {x = 20, y = level.height / 2},                -- Left middle
            {x = level.width - 20, y = level.height / 2}   -- Right middle
        }
        
        -- Remove the top-left position (20, 20) as it's too close to the ball starting position
        -- And filter out any positions that are too close to the ball starting position
        local validLocations = {}
        for _, loc in ipairs(possibleLocations) do
            local distance = math.sqrt((loc.x - ballStartX)^2 + (loc.y - ballStartY)^2)
            if distance >= minDistanceFromBall then
                table.insert(validLocations, loc)
            end
        end
        
        -- Pick a random location from valid locations
        local randomIndex = math.random(1, #validLocations)
        holeX = math.floor(validLocations[randomIndex].x)
        holeY = math.floor(validLocations[randomIndex].y)
    else
        -- If position is provided, check if it's too close to the ball starting position
        local distance = math.sqrt((holeX - ballStartX)^2 + (holeY - ballStartY)^2)
        if distance < minDistanceFromBall then
            -- If too close, move it to a valid position
            holeX = level.width - 20
            holeY = level.height - 20
        end
    end
    -- The pattern is:
    --   X
    --  XXX
    -- XXXXX
    --  XXX
    --   X
    
    -- Define the diamond pattern explicitly
    local pattern = {
        {0, 0, 1, 0, 0},
        {0, 1, 1, 1, 0},
        {1, 1, 1, 1, 1},
        {0, 1, 1, 1, 0},
        {0, 0, 1, 0, 0}
    }
    
    -- Create a clear area around the win hole
    for y = holeY - 5, holeY + 5 do
        for x = holeX - 5, holeX + 5 do
            if x >= 0 and x < level.width and y >= 0 and y < level.height then
                level:setCellType(x, y, CellTypes.TYPES.EMPTY)
            end
        end
    end
    
    -- Create win holes based on the pattern
    local createdHoles = {}
    
    for dy = 0, 4 do
        for dx = 0, 4 do
            -- Only create a win hole if the pattern has a 1 at this position
            if pattern[dy + 1][dx + 1] == 1 then
                local cellX = holeX - 2 + dx
                local cellY = holeY - 2 + dy
                
                -- Only create win holes within the level bounds
                if cellX >= 0 and cellX < level.width and cellY >= 0 and cellY < level.height then
                    WinHole.createWinHole(level, cellX, cellY)
                    table.insert(createdHoles, {x = cellX, y = cellY})
                end
            end
        end
    end
    
    -- Check for isolated win holes and remove them
    for i = #createdHoles, 1, -1 do
        local hole = createdHoles[i]
        local hasAdjacent = false
        
        -- Check adjacent cells (up, down, left, right)
        local directions = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
        for _, dir in ipairs(directions) do
            local nx = hole.x + dir[1]
            local ny = hole.y + dir[2]
            
            -- Check if this adjacent cell is also a win hole
            if nx >= 0 and nx < level.width and ny >= 0 and ny < level.height then
                if level:getCellType(nx, ny) == CellTypes.TYPES.WIN_HOLE then
                    hasAdjacent = true
                    break
                end
            end
        end
        
        -- If this hole has no adjacent win holes, remove it
        if not hasAdjacent then
            level:setCellType(hole.x, hole.y, CellTypes.TYPES.EMPTY)
            table.remove(createdHoles, i)
        end
    end
end

function love.load()
    -- Initialize sound system
    Sound.load()
    
    -- Set up the physics world with gravity
    world = love.physics.newWorld(0, 9.81 * 64, true)
    
    -- Set up collision callbacks
    world:setCallbacks(
        function(a, b, coll) Collision.beginContact(a, b, coll, level, ball) end,
        function(a, b, coll) Collision.endContact(a, b, coll, level) end,
        Collision.preSolve,
        Collision.postSolve
    )
    
    -- Create the level (80x60 cells, each 10x10 pixels)
    level = Level.new(world, 160, 100)
    
    -- Create a procedural level with the current difficulty
    local LevelGenerator = require("src.level_generator")
    print("Creating level with difficulty:", currentDifficulty)
    level:createProceduralLevel(currentDifficulty)
    
    -- Create a diamond-shaped win hole at a random position
    createDiamondWinHole(level)
    
    -- Create the square ball at the starting position (matching the level generator)
    ball = Balls.createBall(world, 20 * Cell.SIZE, 20 * Cell.SIZE, currentBallType)
    
    -- Set the ball as the user data for the ball body
    ball.body:setUserData(ball)
    
    -- Create input handler
    input = Input.new()
    
    -- Reset game state
    gameWon = false
    winMessageTimer = 0
    attempts = 0
    
    -- Initialize editor
    Editor.init(level, world)
    
    -- Initialize UI
    if not UI.initialized then
        -- Set up UI callbacks
        UI.onBallTypeChange = function(ballTypeIndex)
            local ballTypes = {
                Balls.TYPES.STANDARD,
                Balls.TYPES.HEAVY,
                Balls.TYPES.EXPLODING,
                Balls.TYPES.STICKY
            }
            
            currentBallType = ballTypes[ballTypeIndex]
            local newBall = Balls.changeBallType(ball, world, currentBallType)
            ball.body:destroy() -- Destroy old ball's body
            ball = newBall
            ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
            
            local ballTypeNames = {"Standard", "Heavy", "Exploding", "Sticky"}
            print("Switched to " .. ballTypeNames[ballTypeIndex] .. " Ball")
        end
        
        UI.onAddWinHole = function()
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            WinHole.createWinHoleArea(level, gridX, gridY, 3, 3)
            print("Added a win hole at ball position")
        end
        
        UI.init()
        UI.initialized = true
    end
end

function love.update(dt)
    -- If editor is active, update editor instead of game
    if Editor.active then
        Editor.update(dt)
        return
    end
    
    -- Process sand cells that need to be converted to visual sand
    Effects.processSandConversion(Collision.sandToConvert, level)
    Collision.sandToConvert = {} -- Clear the queue
    
    -- Update the physics world
    world:update(dt)
    
    -- Update sound system and camera shake effect
    Sound.update(dt)
    Sound.updateCameraShake(dt)
    
    -- Update the ball
    local ballStopped = ball:update(dt)
    
    -- Check if the exploding ball should switch to standard ball
    if ball.shouldSwitchToStandard then
        currentBallType = Balls.TYPES.STANDARD
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Standard Ball after explosion")
    end
    
    -- Check for win condition
    if ball.hasWon and not gameWon then
        gameWon = true
        winMessageTimer = 999999.0 -- Display win message until user dismisses it
        print("GAME WON! Congratulations!")
    end
    
    -- Win message timer is no longer decremented automatically
    -- It will only be reset when the user clicks the continue button or presses R
    
    -- Update the level (pass the ball for cluster activation)
    level:update(dt, ball)
    
    -- Update fire and smoke
    Fire.update(dt, level)
    
    -- Update input
    input:update(ball, level)
    
    -- Update UI
    local mouseX, mouseY = love.mouse.getPosition()
    UI.update(mouseX, mouseY)
end

function love.keypressed(key)
    -- Toggle editor mode with F12
    if key == "f12" then
        Editor.active = not Editor.active
        return
    end
    
    -- If editor is active, handle editor key presses
    if Editor.active then
        Editor.handleKeyPressed(key)
        return
    end
    
    -- Handle ball type switching
    if key == "1" then
        currentBallType = Balls.TYPES.STANDARD
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Standard Ball")
    elseif key == "2" then
        currentBallType = Balls.TYPES.HEAVY
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Heavy Ball")
    elseif key == "3" then
        currentBallType = Balls.TYPES.EXPLODING
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Exploding Ball")
    elseif key == "4" then
        currentBallType = Balls.TYPES.STICKY
        local newBall = Balls.changeBallType(ball, world, currentBallType)
        ball.body:destroy() -- Destroy old ball's body
        ball = newBall
        ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
        print("Switched to Sticky Ball")
    elseif key == "e" then
        -- Always switch to exploding ball and trigger explosion immediately
        if ball.ballType ~= Balls.TYPES.EXPLODING then
            -- Switch to exploding ball first
            currentBallType = Balls.TYPES.EXPLODING
            local newBall = Balls.changeBallType(ball, world, currentBallType)
            ball.body:destroy() -- Destroy old ball's body
            ball = newBall
            ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
            print("Switched to Exploding Ball")
        end
        
        -- Trigger explosion
        local result = ball:explode(level, Collision.sandToConvert)
        if result then
            print("Exploded!")
            
            -- Check if we should switch to standard ball
            if result == "switch_to_standard" then
                currentBallType = Balls.TYPES.STANDARD
                local newBall = Balls.changeBallType(ball, world, currentBallType)
                ball.body:destroy() -- Destroy old ball's body
                ball = newBall
                ball.body:setUserData(ball) -- Set the ball as the user data for the ball body
                print("Switched to Standard Ball after explosion")
            end
        end
    elseif input:handleKeyPressed(key, ball) then
        -- Reset was performed
        -- Reset game state on reset
        gameWon = false
        winMessageTimer = 0
    else
        local result = Debug.handleKeyPressed(key, level)
        if result == true then
            -- Toggle debug mode
            debug = not debug
        elseif result == "sand_pile" then
            -- Add a sand pile
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            level:addSandPile(gridX, gridY, 10, 20)
            print("Added a sand pile at ball position")
        elseif result == "dirt_block" then
            -- Add a dirt block
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            level:addDirtBlock(gridX, gridY, 5, 5)
            print("Added a dirt block at ball position")
        elseif result == "water_pool" then
            -- Add a water pool
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            level:addWaterPool(gridX, gridY, 10, 3)
            print("Added a water pool at ball position")
        elseif key == "f" then
            -- Add fire at ball position
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            
            -- Create a small cluster of fire for better visibility
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local fireX = gridX + dx
                    local fireY = gridY + dy
                    
                    -- Only place fire in empty cells
                    if fireX >= 0 and fireX < level.width and 
                       fireY >= 0 and fireY < level.height and
                       level:getCellType(fireX, fireY) == CellTypes.TYPES.EMPTY then
                        Fire.createFire(level, fireX, fireY)
                    end
                end
            end
            print("Added fire at ball position")
        elseif key == "h" then
            -- Add a win hole at ball position
            local x, y = ball.body:getPosition()
            local gridX, gridY = level:getGridCoordinates(x, y)
            WinHole.createWinHoleArea(level, gridX, gridY, 3, 3)
            print("Added a win hole at ball position")
        end
    end
end

function love.textinput(text)
    -- If editor is active, handle editor text input
    if Editor.active then
        Editor.handleTextInput(text)
    end
end

function love.draw()
    -- Draw gradient background
    love.graphics.clear(0, 0, 0, 1) -- Clear with black first
    
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Calculate scale factors
    local scaleX = width / ORIGINAL_WIDTH
    local scaleY = height / ORIGINAL_HEIGHT
    local scale = math.min(scaleX, scaleY) -- Use the smaller scale to ensure everything fits
    
    -- Ensure minimum scale to prevent rendering issues
    scale = math.max(scale, 0.5) -- Minimum scale factor of 0.5
    
    -- Store the scale for other modules to use
    GAME_SCALE = scale
    
    -- Apply scaling transformation
    love.graphics.push()
    love.graphics.scale(scale, scale)
    
    -- Adjust width and height for scaled coordinates
    local scaledWidth = width / scale
    local scaledHeight = height / scale
    
    -- Center the game in the window
    local offsetX = (scaledWidth - ORIGINAL_WIDTH) / 2
    local offsetY = (scaledHeight - ORIGINAL_HEIGHT) / 2
    
    -- Store the offsets for other modules to use
    GAME_OFFSET_X = offsetX
    GAME_OFFSET_Y = offsetY
    
    love.graphics.translate(offsetX, offsetY)
    
    -- Apply camera shake offset
    local shakeX, shakeY = 0, 0
    local cameraShakeActive = false
    if Sound.cameraShake and Sound.cameraShake.active then
        shakeX, shakeY = Sound.cameraShake.offsetX, Sound.cameraShake.offsetY
        love.graphics.translate(shakeX, shakeY)
        cameraShakeActive = true
    end
    
    -- Draw gradient rectangle covering the entire screen
    love.graphics.setColor(BACKGROUND_COLOR_TOP[1], BACKGROUND_COLOR_TOP[2], BACKGROUND_COLOR_TOP[3], BACKGROUND_COLOR_TOP[4])
    love.graphics.rectangle("fill", 0, 0, ORIGINAL_WIDTH, ORIGINAL_HEIGHT)
    
    -- Create a subtle gradient mesh
    local gradient = love.graphics.newMesh({
        {0, 0, 0, 0, BACKGROUND_COLOR_TOP[1], BACKGROUND_COLOR_TOP[2], BACKGROUND_COLOR_TOP[3], BACKGROUND_COLOR_TOP[4]}, -- top-left
        {ORIGINAL_WIDTH, 0, 1, 0, BACKGROUND_COLOR_TOP[1], BACKGROUND_COLOR_TOP[2], BACKGROUND_COLOR_TOP[3], BACKGROUND_COLOR_TOP[4]}, -- top-right
        {ORIGINAL_WIDTH, ORIGINAL_HEIGHT, 1, 1, BACKGROUND_COLOR_BOTTOM[1], BACKGROUND_COLOR_BOTTOM[2], BACKGROUND_COLOR_BOTTOM[3], BACKGROUND_COLOR_BOTTOM[4]}, -- bottom-right
        {0, ORIGINAL_HEIGHT, 0, 1, BACKGROUND_COLOR_BOTTOM[1], BACKGROUND_COLOR_BOTTOM[2], BACKGROUND_COLOR_BOTTOM[3], BACKGROUND_COLOR_BOTTOM[4]} -- bottom-left
    }, "fan", "static")
    
    love.graphics.draw(gradient)
    
    -- Draw the level
    level:draw(debug) -- Pass debug flag to level:draw
    
    -- If editor is active, draw editor
    if Editor.active then
        Editor.draw()
    else
        -- Draw the ball
        ball:draw(debug) -- Pass debug flag to ball:draw
        
        -- Draw input (aim line, power indicator)
        input:draw(ball, attempts)
    end
    
    -- Display FPS counter
    love.graphics.setColor(WHITE)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 10)
    
    -- Shots counter will be displayed under the mode indicator in input.lua
    
    -- Debug info
    Debug.drawDebugInfo(level, ball, attempts, debug)
    
    -- Draw active cells for debugging
    Debug.drawActiveCells(level)
    
    -- Reset scaling transformation before drawing UI
    -- We only pushed once at the beginning, so we only need to pop once
    love.graphics.pop()
    
    -- Draw UI (UI is drawn at screen coordinates, not scaled)
    if not Editor.active then
        UI.draw()
    end
    
    -- Track if we've pushed any transformations for the win screen
    local winScreenTransformPushed = false
    
    -- Draw win message if the game is won
    if gameWon and winMessageTimer > 0 and not Editor.active then
        -- Load the win screen font if not already loaded
        if not winFont then
            winFont = love.graphics.newFont("fonts/pixel_font.ttf", 32)
        end
        if not winFontSmall then
            winFontSmall = love.graphics.newFont("fonts/pixel_font.ttf", 24)
        end
        
        -- Get screen dimensions
        local screenWidth, screenHeight = love.graphics.getDimensions()
        
        -- Draw a retro-styled background panel
        love.graphics.setColor(0.1, 0.1, 0.2, 0.9) -- Dark blue background
        love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
        
        -- Draw grid pattern for retro computer look
        love.graphics.setColor(0, 0, 0, 0.05)
        for i = 0, screenWidth, 16 do
            love.graphics.line(i, 0, i, screenHeight)
        end
        for i = 0, screenHeight, 16 do
            love.graphics.line(0, i, screenWidth, i)
        end
        
        -- Draw scanlines for CRT effect
        love.graphics.setColor(0, 0, 0, 0.1)
        for i = 0, screenHeight, 2 do
            love.graphics.line(0, i, screenWidth, i)
        end
        
        -- Draw a centered terminal-like window
        local windowWidth = 600
        local windowHeight = 400
        local windowX = (screenWidth - windowWidth) / 2
        local windowY = (screenHeight - windowHeight) / 2
        
        -- Window background
        love.graphics.setColor(0.05, 0.05, 0.15, 0.95)
        love.graphics.rectangle("fill", windowX, windowY, windowWidth, windowHeight, 0, 0) -- No rounded corners
        
        -- Window border
        love.graphics.setColor(0, 0.8, 0.8, 1) -- Cyan border
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", windowX, windowY, windowWidth, windowHeight, 0, 0)
        love.graphics.setLineWidth(1)
        
        -- Window header
        love.graphics.setColor(0.2, 0.2, 0.4, 1)
        love.graphics.rectangle("fill", windowX, windowY, windowWidth, 40, 0, 0)
        
        -- Header text
        love.graphics.setFont(winFont)
        love.graphics.setColor(0, 1, 1, 1) -- Cyan text
        local headerText = "MISSION COMPLETE"
        local headerWidth = winFont:getWidth(headerText)
        love.graphics.print(headerText, windowX + (windowWidth - headerWidth) / 2, windowY + 5)
        
        -- Content
        love.graphics.setFont(winFontSmall)
        
        -- Display current difficulty
        local difficultyName = "EASY"
        if currentDifficulty == 2 then
            difficultyName = "MEDIUM"
        elseif currentDifficulty == 3 then
            difficultyName = "HARD"
        elseif currentDifficulty == 4 then
            difficultyName = "EXPERT"
        elseif currentDifficulty == 5 then
            difficultyName = "INSANE"
        end
        
        -- Stats section
        local textY = windowY + 70
        local textX = windowX + 50
        local lineHeight = 35
        
        love.graphics.setColor(1, 0.5, 0, 1) -- Orange for headers
        love.graphics.print("MISSION STATS:", textX, textY)
        textY = textY + lineHeight
        
        love.graphics.setColor(0, 1, 1, 1) -- Cyan for text
        love.graphics.print("SHOTS FIRED: " .. attempts, textX, textY)
        textY = textY + lineHeight
        
        love.graphics.print("DIFFICULTY: " .. difficultyName, textX, textY)
        textY = textY + lineHeight * 1.5
        
        -- Next difficulty message
        if currentDifficulty < 5 then
            local nextDifficultyName = "MEDIUM"
            if currentDifficulty == 2 then
                nextDifficultyName = "HARD"
            elseif currentDifficulty == 3 then
                nextDifficultyName = "EXPERT"
            elseif currentDifficulty == 4 then
                nextDifficultyName = "INSANE"
            end
            
            love.graphics.setColor(1, 0.5, 0, 1) -- Orange for headers
            love.graphics.print("NEXT MISSION:", textX, textY)
            textY = textY + lineHeight
            
            love.graphics.setColor(0, 1, 1, 1) -- Cyan for text
            love.graphics.print("DIFFICULTY: " .. nextDifficultyName, textX, textY)
        else
            love.graphics.setColor(1, 0.5, 0, 1) -- Orange for headers
            love.graphics.print("MAXIMUM DIFFICULTY REACHED", textX, textY)
        end
        
        -- Draw buttons
        local buttonWidth = 200
        local buttonHeight = 50
        local buttonX = windowX + (windowWidth - buttonWidth) / 2
        local buttonY = windowY + windowHeight - buttonHeight - 40
        
        -- Draw "CONTINUE" button
        love.graphics.setColor(0.2, 0.2, 0.4, 1) -- Button background
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, buttonHeight, 0, 0)
        
        -- Button border
        love.graphics.setColor(0, 0.8, 0.8, 1) -- Cyan border
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", buttonX, buttonY, buttonWidth, buttonHeight, 0, 0)
        love.graphics.setLineWidth(1)
        
        -- Button highlight
        love.graphics.setColor(0, 1, 1, 0.3) -- Cyan highlight
        love.graphics.rectangle("fill", buttonX, buttonY, buttonWidth, 2)
        love.graphics.rectangle("fill", buttonX, buttonY, 2, buttonHeight)
        
        -- Button text
        love.graphics.setColor(0, 1, 1, 1) -- Cyan text
        local buttonText = "CONTINUE [R]"
        local buttonTextWidth = winFontSmall:getWidth(buttonText)
        love.graphics.print(buttonText, buttonX + (buttonWidth - buttonTextWidth) / 2, buttonY + (buttonHeight - winFontSmall:getHeight()) / 2)
    end
end

-- Function to convert screen coordinates to game coordinates
function screenToGameCoords(screenX, screenY)
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Calculate scale factors
    local scaleX = width / ORIGINAL_WIDTH
    local scaleY = height / ORIGINAL_HEIGHT
    local scale = math.min(scaleX, scaleY)
    
    -- Ensure minimum scale to prevent rendering issues
    scale = math.max(scale, 0.5) -- Minimum scale factor of 0.5
    
    -- Calculate offsets for centering
    local scaledWidth = width / scale
    local scaledHeight = height / scale
    local offsetX = (scaledWidth - ORIGINAL_WIDTH) / 2
    local offsetY = (scaledHeight - ORIGINAL_HEIGHT) / 2
    
    -- Convert screen coordinates to game coordinates
    local gameX = (screenX / scale) - offsetX
    local gameY = (screenY / scale) - offsetY
    
    return gameX, gameY
end

function love.mousepressed(x, y, button)
    -- If editor is active, handle editor mouse presses
    if Editor.active then
        Editor.handleMousePressed(x, y, button)
        return
    end
    
    -- Check if we're in the win screen
    if gameWon and winMessageTimer > 0 then
        -- Get screen dimensions
        local screenWidth, screenHeight = love.graphics.getDimensions()
        
        -- Button dimensions
        local windowWidth = 600
        local windowHeight = 400
        local windowX = (screenWidth - windowWidth) / 2
        local windowY = (screenHeight - windowHeight) / 2
        local buttonWidth = 200
        local buttonHeight = 50
        local buttonX = windowX + (windowWidth - buttonWidth) / 2
        local buttonY = windowY + windowHeight - buttonHeight - 40
        
        -- Check if click is on the continue button
        if x >= buttonX and x <= buttonX + buttonWidth and
           y >= buttonY and y <= buttonY + buttonHeight then
            -- Increase difficulty if not at max
            if currentDifficulty < 5 then
                currentDifficulty = currentDifficulty + 1
                print("Difficulty increased to:", currentDifficulty)
            end
            
            -- Reload the level
            love.load()
            return
        end
        
        return -- Don't process other clicks when win screen is active
    end
    
    -- Check if UI handled the mouse press
    if UI.handlePress(x, y) then
        return -- UI handled the press, don't process further
    end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = screenToGameCoords(x, y)
    
    -- Otherwise, let the input system handle it with converted coordinates
    if input:handleMousePressed(button, ball, gameX, gameY) then
        attempts = attempts + 1
    end
end

function love.mousereleased(x, y, button)
    -- If editor is active, don't handle game mouse releases
    if Editor.active then
        return
    end
    
    -- Convert screen coordinates to game coordinates
    local gameX, gameY = screenToGameCoords(x, y)
    
    if input:handleMouseReleased(button, ball, gameX, gameY) then
        attempts = attempts + 1
    end
end
