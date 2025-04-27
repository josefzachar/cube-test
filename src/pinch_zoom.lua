-- pinch_zoom.lua - Handles pinch-to-zoom gestures for mobile devices

local GameState = require("src.game_state")

local PinchZoom = {}

-- Touch points for pinch detection
PinchZoom.touches = {}

-- Previous pinch distance
PinchZoom.previousDistance = nil

-- Minimum distance change to trigger zoom
PinchZoom.minDistanceChange = 10

-- Zoom sensitivity (higher = more sensitive)
PinchZoom.sensitivity = 0.01

-- Initialize pinch zoom
function PinchZoom.init()
    PinchZoom.touches = {}
    PinchZoom.previousDistance = nil
end

-- Handle touch press
function PinchZoom.touchPressed(id, x, y)
    -- Store touch point
    PinchZoom.touches[id] = {x = x, y = y}
    
    -- Reset previous distance if we have exactly 2 touches (start of pinch)
    if PinchZoom.countTouches() == 2 then
        PinchZoom.previousDistance = PinchZoom.calculateDistance()
    else
        PinchZoom.previousDistance = nil
    end
    
    return false -- Not handled (allow other touch handlers to process)
end

-- Handle touch move
function PinchZoom.touchMoved(id, x, y)
    -- Update touch point
    if PinchZoom.touches[id] then
        PinchZoom.touches[id].x = x
        PinchZoom.touches[id].y = y
        
        -- Process pinch if we have exactly 2 touches
        if PinchZoom.countTouches() == 2 then
            return PinchZoom.processPinch()
        end
    end
    
    return false -- Not handled
end

-- Handle touch release
function PinchZoom.touchReleased(id)
    -- Remove touch point
    PinchZoom.touches[id] = nil
    
    -- Reset previous distance
    PinchZoom.previousDistance = nil
    
    return false -- Not handled
end

-- Count active touches
function PinchZoom.countTouches()
    local count = 0
    for _ in pairs(PinchZoom.touches) do
        count = count + 1
    end
    return count
end

-- Calculate distance between two touch points
function PinchZoom.calculateDistance()
    -- Get the two touch points
    local touchPoints = {}
    for id, touch in pairs(PinchZoom.touches) do
        table.insert(touchPoints, touch)
    end
    
    -- Need exactly 2 touch points
    if #touchPoints ~= 2 then
        return nil
    end
    
    -- Calculate distance
    local dx = touchPoints[1].x - touchPoints[2].x
    local dy = touchPoints[1].y - touchPoints[2].y
    return math.sqrt(dx * dx + dy * dy)
end

-- Process pinch gesture
function PinchZoom.processPinch()
    -- Calculate current distance
    local currentDistance = PinchZoom.calculateDistance()
    
    -- Need previous distance for comparison
    if not PinchZoom.previousDistance then
        PinchZoom.previousDistance = currentDistance
        return false
    end
    
    -- Calculate distance change
    local distanceChange = currentDistance - PinchZoom.previousDistance
    
    -- Only process if change is significant
    if math.abs(distanceChange) < PinchZoom.minDistanceChange then
        return false
    end
    
    -- Calculate zoom change
    local zoomChange = distanceChange * PinchZoom.sensitivity
    
    -- Apply zoom change
    if zoomChange > 0 then
        -- Pinch out - zoom in
        GameState.increaseZoomBy(zoomChange)
    else
        -- Pinch in - zoom out
        GameState.decreaseZoomBy(-zoomChange)
    end
    
    -- Update previous distance
    PinchZoom.previousDistance = currentDistance
    
    return true -- Handled
end

return PinchZoom
