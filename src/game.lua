-- src/game.lua - Main game module, delegates to sub-modules

-- Require the sub-modules
local GameState = require("src.game_state")
local GameInit = require("src.game_init")
local GameUpdate = require("src.game_update")
local GameInput = require("src.game_input")

-- Initialize the main Game table from the state module
local Game = GameState

-- Assign functions from the sub-modules to the Game table
-- Note: We pass the 'Game' table itself to these functions as the first argument
--       so they can access and modify the game state.

Game.init = function(mode, levelNumber)
    GameInit.init(Game, mode, levelNumber)
end

Game.update = function(dt)
    GameUpdate.update(Game, dt)
end

Game.handleKeyPressed = function(key)
    GameInput.handleKeyPressed(Game, key)
end

Game.handleMousePressed = function(x, y, button)
    GameInput.handleMousePressed(Game, x, y, button)
end

Game.handleMouseReleased = function(x, y, button)
    GameInput.handleMouseReleased(Game, x, y, button)
end

Game.handleKeyReleased = function(key)
    GameInput.handleKeyReleased(Game, key)
end

Game.handleMouseWheel = function(x, y)
    GameInput.handleMouseWheel(Game, x, y)
end

-- Keep the screenToGameCoords function accessible directly via Game if needed,
-- although it's primarily used internally by game_input.lua now.
Game.screenToGameCoords = GameInput.screenToGameCoords

-- Return the assembled Game object
return Game
