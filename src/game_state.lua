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
    LEVEL_BACKGROUND_COLOR = {0.05, 0.05, 0.15, 1.0} -- Very dark navy blue
}

-- Global difficulty level (1-5) - Keep this global for now as it's used directly elsewhere
currentDifficulty = 1

-- Make these global so they can be accessed from other modules - Keep these global
GAME_SCALE = 1
GAME_OFFSET_X = 0
GAME_OFFSET_Y = 0

return GameState
