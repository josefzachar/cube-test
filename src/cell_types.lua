-- cell_types.lua - Cell types and properties for Square Golf

local CellTypes = {}

-- Cell types
CellTypes.TYPES = {
    EMPTY = 0,
    SAND = 1,
    STONE = 2,
    VISUAL_SAND = 3,  -- Visual effect for flying sand (no physics)
    TEMP_STONE = 4    -- Temporary stone that looks like sand
}

-- Colors
CellTypes.COLORS = {
    [CellTypes.TYPES.EMPTY] = {0, 0, 0, 0}, -- Transparent
    [CellTypes.TYPES.SAND] = {0.9, 0.8, 0.5, 1}, -- Sand color
    [CellTypes.TYPES.STONE] = {0.5, 0.5, 0.5, 1}, -- Stone color
    [CellTypes.TYPES.VISUAL_SAND] = {1.0, 0.9, 0.6, 1}, -- Brighter sand for visual effect
    [CellTypes.TYPES.TEMP_STONE] = {0.9, 0.8, 0.5, 1}  -- Same as sand color
}

-- Cell size (half the size of the ball)
CellTypes.SIZE = 10

return CellTypes
