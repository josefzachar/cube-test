-- mobile_input.lua - Mobile-specific input handling and coordinate conversion

local MobileInput = {}

-- Game dimensions (must match original design dimensions)
MobileInput.GAME_WIDTH = 1600
MobileInput.GAME_HEIGHT = 1000

-- Convert screen coordinates to game coordinates for mobile devices
function MobileInput.screenToGameCoords(screenX, screenY)
    -- Get screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Get screen dimensions for coordinate conversion
    
    -- Calculate scale factors for fullscreen stretching
    local scaleX = screenWidth / MobileInput.GAME_WIDTH
    local scaleY = screenHeight / MobileInput.GAME_HEIGHT
    
    -- Convert screen coordinates to game coordinates
    -- Since we're stretching to fill the screen, we simply divide by the scale factors
    local gameX = screenX / scaleX
    local gameY = screenY / scaleY
    
    -- Return the converted coordinates
    
    return gameX, gameY
end

-- Convert game coordinates to grid coordinates
function MobileInput.gameToGridCoords(gameX, gameY, cellSize)
    local gridX = math.floor(gameX / cellSize)
    local gridY = math.floor(gameY / cellSize)
    
    return gridX, gridY
end

-- Convert screen coordinates directly to grid coordinates
function MobileInput.screenToGridCoords(screenX, screenY, cellSize)
    -- First convert screen to game coordinates
    local gameX, gameY = MobileInput.screenToGameCoords(screenX, screenY)
    
    -- Then convert game to grid coordinates
    local gridX, gridY = MobileInput.gameToGridCoords(gameX, gameY, cellSize)
    
    -- Return the converted grid coordinates
    
    return gridX, gridY
end

-- Apply mobile transformation for drawing
function MobileInput.applyDrawTransform()
    -- Get screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Reset transformation
    love.graphics.origin()
    
    -- Calculate scale to fill the screen (stretch to fullscreen)
    local scaleX = screenWidth / MobileInput.GAME_WIDTH
    local scaleY = screenHeight / MobileInput.GAME_HEIGHT
    
    -- Apply transformation: scale to fill the entire screen
    -- This will stretch the content to fill the screen completely
    love.graphics.scale(scaleX, scaleY)
end

return MobileInput
