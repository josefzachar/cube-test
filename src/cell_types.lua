-- cell_types.lua - Cell types and properties for Square Golf

local CellTypes = {}

-- Cell types
CellTypes.TYPES = {
    EMPTY = 0,
    SAND = 1,
    STONE = 2,
    VISUAL_SAND = 3,  -- Visual effect for flying sand (no physics)
    WATER = 4,        -- Water that flows and has different physics properties
    DIRT = 5,         -- Dirt that doesn't fall but can be displaced like sand
    VISUAL_DIRT = 6   -- Visual effect for flying dirt (no physics)
}

-- Colors
CellTypes.COLORS = {
    [CellTypes.TYPES.EMPTY] = {0, 0, 0, 0}, -- Transparent
    [CellTypes.TYPES.SAND] = {0.9, 0.8, 0.5, 1}, -- Sand color
    [CellTypes.TYPES.STONE] = {0.5, 0.5, 0.5, 1}, -- Stone color
    [CellTypes.TYPES.VISUAL_SAND] = {1.0, 0.9, 0.6, 1}, -- Brighter sand for visual effect
    [CellTypes.TYPES.WATER] = {0.2, 0.4, 0.8, 0.8}, -- Blue with some transparency for water
    [CellTypes.TYPES.DIRT] = {0.6, 0.4, 0.2, 1}, -- Brown for dirt
    [CellTypes.TYPES.VISUAL_DIRT] = {0.7, 0.5, 0.3, 1} -- Brighter dirt for visual effect
}

-- Material properties for physics and displacement
CellTypes.PROPERTIES = {
    -- Sand properties
    [CellTypes.TYPES.SAND] = {
        -- Displacement properties
        displacementThreshold = 50,     -- Speed threshold for creating craters
        directHitThreshold = 100,       -- Speed threshold for direct hit conversion
        
        -- Crater size properties
        craterBaseRadius = 0.5,         -- Base radius for craters
        craterMaxRadius = 3.5,          -- Maximum additional radius
        craterSpeedDivisor = 150,       -- Divisor for speed to radius conversion
        
        -- Visual properties
        velocityMultiplier = 2.0        -- Multiplier for visual particle velocity
    },
    
    -- Dirt properties
    [CellTypes.TYPES.DIRT] = {
        -- Displacement properties
        displacementThreshold = 350,    -- Speed threshold for creating craters
        directHitThreshold = 400,       -- Speed threshold for direct hit conversion
        
        -- Crater size properties
        craterBaseRadius = 0.3,         -- Base radius for craters
        craterMaxRadius = 0.7,          -- Maximum additional radius
        craterSpeedDivisor = 250,       -- Divisor for speed to radius conversion
        
        -- Visual properties
        velocityMultiplier = 1.2        -- Multiplier for visual particle velocity
    },
    
    -- Stone properties
    [CellTypes.TYPES.STONE] = {
        -- Displacement properties
        displacementThreshold = 300,    -- Speed threshold for creating craters
        directHitThreshold = 500,       -- Speed threshold for direct hit conversion
        
        -- Crater size properties
        craterBaseRadius = 0.2,         -- Base radius for craters
        craterMaxRadius = 0.5,          -- Maximum additional radius
        craterSpeedDivisor = 300,       -- Divisor for speed to radius conversion
        
        -- Visual properties
        velocityMultiplier = 0.8        -- Multiplier for visual particle velocity
    }
}

-- Cell size (half the size of the ball)
CellTypes.SIZE = 10

return CellTypes
