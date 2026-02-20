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
    VISUAL_DIRT = 6,  -- Visual effect for flying dirt (no physics)
    FIRE = 7,         -- Fire that acts as an energy type
    SMOKE = 8,        -- Visual effect for smoke from fire
    WIN_HOLE = 9,     -- Win hole that makes the player win when the ball enters it
    ICE = 10,         -- Frozen water (static, slippery)
    SPRAY_WATER = 11  -- Water sprayed by WaterBall; flows like WATER but doesn't trigger ball floating
}

-- Colors
CellTypes.COLORS = {
    [CellTypes.TYPES.EMPTY] = {0.7, 0.8, 1.0, 1.0}, -- Bluish sky color
    [CellTypes.TYPES.SAND] = {0.9, 0.8, 0.5, 1}, -- Sand color
    [CellTypes.TYPES.STONE] = {0.5, 0.5, 0.5, 1}, -- Stone color
    [CellTypes.TYPES.VISUAL_SAND] = {1.0, 0.9, 0.6, 1}, -- Brighter sand for visual effect
    [CellTypes.TYPES.WATER] = {0.2, 0.4, 0.8, 0.8}, -- Blue with some transparency for water
    [CellTypes.TYPES.SPRAY_WATER] = {0.2, 0.4, 0.8, 0.8}, -- Same color as water (indistinguishable visually)
    [CellTypes.TYPES.DIRT] = {0.6, 0.4, 0.2, 1}, -- Brown for dirt
    [CellTypes.TYPES.VISUAL_DIRT] = {0.7, 0.5, 0.3, 1}, -- Brighter dirt for visual effect
    [CellTypes.TYPES.FIRE] = {1.0, 0.3, 0.1, 0.9}, -- Bright orange-red for fire with some transparency
    [CellTypes.TYPES.SMOKE] = {0.45, 0.45, 0.45, 0.55}, -- Medium dark gray smoke
    [CellTypes.TYPES.WIN_HOLE] = {0.0, 0.0, 0.0, 1.0}, -- Black for the win hole
    [CellTypes.TYPES.ICE] = {0.6, 0.9, 1.0, 1.0}        -- Light cyan for ice
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
    },

    -- Ice properties (breakable by heavy ball only, shatters back to water)
    [CellTypes.TYPES.ICE] = {
        -- Low thresholds so heavy ball (with 0.35 multiplier → effective ~52) easily triggers crater.
        -- Standard ball entering crater code is harmless — isHeavyBall guard prevents actual shattering.
        displacementThreshold = 150,
        directHitThreshold = 150,

        -- Crater size properties
        craterBaseRadius = 0.3,
        craterMaxRadius = 0.6,
        craterSpeedDivisor = 250,

        -- Visual properties
        velocityMultiplier = 0.5
    },
    
    -- Fire properties
    [CellTypes.TYPES.FIRE] = {
        -- Displacement properties
        displacementThreshold = 10,     -- Very low threshold - fire is easily displaced
        directHitThreshold = 20,        -- Very low threshold - fire is easily displaced
        
        -- Crater size properties
        craterBaseRadius = 0.1,         -- Small base radius
        craterMaxRadius = 0.2,          -- Small max radius
        craterSpeedDivisor = 500,       -- High divisor - small craters
        
        -- Visual properties
        velocityMultiplier = 3.0,       -- High multiplier - fire particles move fast
        
        -- Fire specific properties
        lifetime = 2.0,                 -- How long fire lasts in seconds before turning to smoke
        smokeRiseSpeed = 50,            -- How fast smoke rises
        smokeLifetime = 3.0,            -- How long smoke lasts before disappearing
        waterBoilRate = 0.8             -- Chance of boiling water per update
    }
}

-- Cell size (half the size of the ball)
CellTypes.SIZE = 10

return CellTypes
