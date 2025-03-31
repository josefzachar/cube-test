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
    
    -- Calculate scale factors
    local scaleX = screenWidth / MobileInput.GAME_WIDTH
    local scaleY = screenHeight / MobileInput.GAME_HEIGHT
    local scale = math.min(scaleX, scaleY)
    
    -- Calculate offsets for centering
    local offsetX = (screenWidth - (MobileInput.GAME_WIDTH * scale)) / 2
    local offsetY = (screenHeight - (MobileInput.GAME_HEIGHT * scale)) / 2
    
    -- Convert screen coordinates to game coordinates
    -- This is the inverse of the transformation applied in applyDrawTransform
    -- In applyDrawTransform, we do: scale, then translate
    -- So here we need to: subtract offset, then divide by scale
    local gameX = (screenX - offsetX) / scale
    local gameY = (screenY - offsetY) / scale
    
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
    
    -- Calculate scale to fit the screen
    local scaleX = screenWidth / MobileInput.GAME_WIDTH
    local scaleY = screenHeight / MobileInput.GAME_HEIGHT
    local scale = math.min(scaleX, scaleY)
    
    -- Calculate offsets for centering
    local offsetX = (screenWidth - (MobileInput.GAME_WIDTH * scale)) / 2
    local offsetY = (screenHeight - (MobileInput.GAME_HEIGHT * scale)) / 2
    
    -- Apply the transformation to match the game coordinates
    
    -- Apply transformation: first scale, then translate
    -- This matches how the green indicator position is calculated
    love.graphics.scale(scale, scale)
    love.graphics.translate(offsetX / scale, offsetY / scale)
end

return MobileInput
