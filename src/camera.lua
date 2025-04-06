-- camera.lua - Camera system for following the ball

local Camera = {
    -- Camera position
    x = 0,
    y = 0,
    
    -- Target position (ball position)
    targetX = 0,
    targetY = 0,
    
    -- Smoothing factor (lower = smoother/slower)
    smoothing = 0.1,
    
    -- Deadzone (camera won't move if ball moves less than this distance)
    deadzone = 5,
    
    -- Last known ball position for deadzone calculation
    lastBallX = 0,
    lastBallY = 0,
    
    -- Flag to track if camera has been initialized
    initialized = false,
    
    -- Flag to enable/disable automatic scaling
    enableScaling = true
}

-- Initialize the camera with the ball's position
function Camera.init(ballX, ballY)
    Camera.x = ballX
    Camera.y = ballY
    Camera.targetX = ballX
    Camera.targetY = ballY
    Camera.lastBallX = ballX
    Camera.lastBallY = ballY
    Camera.initialized = true
end

-- Update the camera position based on the ball's position
function Camera.update(ballX, ballY, dt)
    -- Initialize camera if not already initialized
    if not Camera.initialized then
        Camera.init(ballX, ballY)
        return
    end
    
    -- Calculate distance ball has moved since last frame
    local dx = math.abs(ballX - Camera.lastBallX)
    local dy = math.abs(ballY - Camera.lastBallY)
    
    -- Only update target if ball has moved beyond deadzone
    if dx > Camera.deadzone or dy > Camera.deadzone then
        Camera.targetX = ballX
        Camera.targetY = ballY
        
        -- Update last known position
        Camera.lastBallX = ballX
        Camera.lastBallY = ballY
    end
    
    -- Smoothly move camera toward target position
    Camera.x = Camera.x + (Camera.targetX - Camera.x) * Camera.smoothing * (dt * 60) -- Normalize by framerate
    Camera.y = Camera.y + (Camera.targetY - Camera.y) * Camera.smoothing * (dt * 60)
end

-- Apply camera transformation
function Camera.apply(Game)
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Get level dimensions
    local Cell = require("cell")
    local levelWidth = Game.level.width * Cell.SIZE
    local levelHeight = Game.level.height * Cell.SIZE
    
    -- Force cell size to be exactly 10px for all levels
    local scale = 1.0 -- This will make each cell exactly 10px (Cell.SIZE)
    
    -- We're completely disabling automatic scaling
    Camera.enableScaling = false
    
    -- Store the scale for other modules to use
    GAME_SCALE = scale
    
    -- Apply scaling transformation
    love.graphics.push()
    love.graphics.scale(scale, scale)
    
    -- Adjust width and height for scaled coordinates
    local scaledWidth = width / scale
    local scaledHeight = height / scale
    
    -- Center the game in the window
    local offsetX = (scaledWidth - levelWidth) / 2
    local offsetY = (scaledHeight - levelHeight) / 2
    
    -- Store the offsets for other modules to use
    GAME_OFFSET_X = offsetX
    GAME_OFFSET_Y = offsetY
    
    -- Calculate camera offset to center the ball
    local cameraOffsetX = levelWidth / 2 - Camera.x
    local cameraOffsetY = levelHeight / 2 - Camera.y
    
    -- Apply camera transformation with offsets
    love.graphics.translate(offsetX + cameraOffsetX, offsetY + cameraOffsetY)
    
    -- Apply camera shake offset if active
    local Sound = require("src.sound")
    if Sound.cameraShake and Sound.cameraShake.active then
        love.graphics.translate(Sound.cameraShake.offsetX, Sound.cameraShake.offsetY)
    end
end

-- Reset the camera
function Camera.reset()
    Camera.initialized = false
end

return Camera
