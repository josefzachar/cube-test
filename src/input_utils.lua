-- input_utils.lua - Coordinate conversion utilities for input handling

local InputUtils = {}

-- Convert screen coordinates to game coordinates
function InputUtils.screenToGameCoords(screenX, screenY)
    -- Use the global scale and offset variables that are set in draw.lua
    -- These variables are updated every frame to match the current viewport
    
    -- Get camera position
    local Camera = require("src.camera")
    local Game = require("src.game")
    local Cell = require("cell")
    
    -- Get level dimensions
    local levelWidth = Game.level.width * Cell.SIZE
    local levelHeight = Game.level.height * Cell.SIZE
    
    local cameraOffsetX = levelWidth / 2 - Camera.x
    local cameraOffsetY = levelHeight / 2 - Camera.y
    
    -- Convert screen coordinates to game coordinates using global scale and offsets
    local gameX = (screenX / GAME_SCALE) - GAME_OFFSET_X - cameraOffsetX
    local gameY = (screenY / GAME_SCALE) - GAME_OFFSET_Y - cameraOffsetY
    
    return gameX, gameY
end

-- Convert game coordinates to grid coordinates
function InputUtils.gameToGridCoords(gameX, gameY, cellSize)
    local gridX = math.floor(gameX / cellSize)
    local gridY = math.floor(gameY / cellSize)
    
    return gridX, gridY
end

-- Convert screen coordinates directly to grid coordinates
function InputUtils.screenToGridCoords(screenX, screenY, cellSize)
    -- First convert screen to game coordinates
    local gameX, gameY = InputUtils.screenToGameCoords(screenX, screenY)
    
    -- Then convert game to grid coordinates
    local gridX, gridY = InputUtils.gameToGridCoords(gameX, gameY, cellSize)
    
    return gridX, gridY
end

-- Apply transformation for drawing
function InputUtils.applyDrawTransform()
    -- Reset transformation
    love.graphics.origin()
    
    -- Use the global scale variables that are set in draw.lua
    -- These variables are updated every frame to match the current viewport
    
    -- Apply transformation: scale to fill the entire screen
    -- This will stretch the content to fill the screen completely
    love.graphics.scale(GAME_SCALE, GAME_SCALE)
    love.graphics.translate(GAME_OFFSET_X, GAME_OFFSET_Y)
end

return InputUtils
