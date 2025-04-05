-- editor/camera.lua - Camera functionality for the Square Golf editor

local EditorCamera = {
    editor = nil
}

-- Initialize the camera module
function EditorCamera.init(editor)
    EditorCamera.editor = editor
end

-- Function to convert screen coordinates to game coordinates
function EditorCamera.screenToGameCoords(screenX, screenY)
    -- Use the InputUtils module for coordinate conversion
    local InputUtils = require("src.input_utils")
    local gameX, gameY = InputUtils.screenToGameCoords(screenX, screenY)
    
    -- Apply camera offset
    gameX = gameX + EditorCamera.editor.cameraX
    gameY = gameY + EditorCamera.editor.cameraY
    
    return gameX, gameY
end

-- Handle camera panning
function EditorCamera.handlePanning(dt)
    -- Get mouse position
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Handle camera panning when isPanning is true (set by space key press)
    if EditorCamera.editor.isPanning then
        -- Continue panning
        local dx = mouseX - EditorCamera.editor.lastMouseX
        local dy = mouseY - EditorCamera.editor.lastMouseY
        
        -- Apply scale factor to make panning speed appropriate
        local width, height = love.graphics.getDimensions()
        local Cell = require("cell")
        local levelWidth = EditorCamera.editor.level.width * Cell.SIZE
        local levelHeight = EditorCamera.editor.level.height * Cell.SIZE
        
        local scaleX = width / levelWidth
        local scaleY = height / levelHeight
        local scale = math.min(scaleX, scaleY)
        
        EditorCamera.editor.cameraX = EditorCamera.editor.cameraX + dx / scale
        EditorCamera.editor.cameraY = EditorCamera.editor.cameraY + dy / scale
        
        EditorCamera.editor.lastMouseX = mouseX
        EditorCamera.editor.lastMouseY = mouseY
    end
end

-- Apply camera transformation
function EditorCamera.applyTransform()
    love.graphics.push()
    -- Note: We need to translate in the opposite direction of the camera offset
    -- to move the view in the direction the user is panning
    love.graphics.translate(-EditorCamera.editor.cameraX, -EditorCamera.editor.cameraY)
end

-- Reset camera transformation
function EditorCamera.resetTransform()
    love.graphics.pop()
end

-- Draw panning indicator
function EditorCamera.drawPanningIndicator()
    if EditorCamera.editor.isPanning then
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("PANNING MODE - Hold middle mouse button and drag", 10, 60)
    end
end

return EditorCamera
