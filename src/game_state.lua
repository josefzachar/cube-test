-- src/game_state.lua - Defines the core Game table, constants, and initial state

local Balls = require("src.balls")

local GameState = {
    -- Game variables
    world = nil,
    ball = nil,
    level = nil,
    input = nil,
    attempts = 0,
    debug = false, -- Set to true to see physics bodies
    currentBallType = Balls.TYPES.STANDARD, -- Start with standard ball
    gameWon = false, -- Flag to track if the player has won
    winMessageTimer = 0, -- Timer for displaying the win message
    testPlayMode = false, -- Flag to track if we're in test play mode
    
    -- Zoom control
    MIN_ZOOM = 0.3,
    MAX_ZOOM = 2.0,
    ZOOM_STEP = 0.05,

    -- Game modes
    MODES = {
        MENU = "menu",
        PLAY = "play",
        EDITOR = "editor",
        SANDBOX = "sandbox",
        TEST_PLAY = "test_play"
    },
    currentMode = nil,

    -- Colors
    WHITE = {1, 1, 1, 1},

    -- Background colors for gradient
    BACKGROUND_COLOR = {0.2, 0.3, 0.6, 1.0}, -- Dark blue (base color)
    BACKGROUND_COLOR_TOP = {0.1, 0.2, 0.4, 1.0}, -- Darker blue for top
    BACKGROUND_COLOR_BOTTOM = {0.3, 0.4, 0.7, 1.0}, -- Lighter blue for bottom
    
    -- Dark navy blue background color for level background in both menu and play mode
    LEVEL_BACKGROUND_COLOR = {0.074, 0.039, 0.137, 1.0} -- Very dark navy blue
}

-- Global difficulty level (1-5) - Keep this global for now as it's used directly elsewhere
currentDifficulty = 1

-- Global zoom level (0.5-2.0) - Controls the game's visual scale
ZOOM_LEVEL = 0.7

-- Make these global so they can be accessed from other modules - Keep these global
GAME_SCALE = 1
GAME_OFFSET_X = 0
GAME_OFFSET_Y = 0

-- Function to increase zoom level
function GameState.increaseZoom()
    ZOOM_LEVEL = math.min(ZOOM_LEVEL + GameState.ZOOM_STEP, GameState.MAX_ZOOM)
    print("Zoom level increased to: " .. ZOOM_LEVEL)
end

-- Function to increase zoom level by a specific amount
function GameState.increaseZoomBy(amount)
    ZOOM_LEVEL = math.min(ZOOM_LEVEL + amount, GameState.MAX_ZOOM)
    print("Zoom level increased to: " .. ZOOM_LEVEL)
end

-- Function to decrease zoom level
function GameState.decreaseZoom()
    ZOOM_LEVEL = math.max(ZOOM_LEVEL - GameState.ZOOM_STEP, GameState.MIN_ZOOM)
    print("Zoom level decreased to: " .. ZOOM_LEVEL)
end

-- Function to decrease zoom level by a specific amount
function GameState.decreaseZoomBy(amount)
    ZOOM_LEVEL = math.max(ZOOM_LEVEL - amount, GameState.MIN_ZOOM)
    print("Zoom level decreased to: " .. ZOOM_LEVEL)
end

-- Function to reset zoom level to default
function GameState.resetZoom()
    ZOOM_LEVEL = 1.0
    print("Zoom level reset to: " .. ZOOM_LEVEL)
end

return GameState
