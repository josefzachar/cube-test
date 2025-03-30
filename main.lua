-- Square Golf Game
-- A simple golf game where the ball is a square and the level is made of cells

-- Load core modules
local Game = require("src.game")
local Menu = require("src.menu")
local Draw = require("src.draw")
local Editor = require("src.editor")

function love.load()
    -- Initialize the menu
    Menu.init()
    Menu.active = true
    Game.currentMode = Game.MODES.MENU
    
    -- Initialize the game in sandbox mode (default)
    Game.init(Game.MODES.SANDBOX)
end

function love.update(dt)
    -- Update the game
    Game.update(dt)
end

function love.keypressed(key)
    -- Handle key presses
    Game.handleKeyPressed(key)
end

function love.textinput(text)
    -- If editor is active, handle editor text input
    if Editor.active then
        Editor.handleTextInput(text)
    end
end

function love.draw()
    -- Draw the game
    Draw.draw(Game)
end

function love.mousepressed(x, y, button)
    -- Handle mouse presses
    Game.handleMousePressed(x, y, button)
end

function love.mousereleased(x, y, button)
    -- Handle mouse releases
    Game.handleMouseReleased(x, y, button)
end

function love.wheelmoved(x, y)
    -- Handle mouse wheel movement
    Game.handleMouseWheel(x, y)
end

function love.resize(width, height)
    -- Handle window resize
    -- This is important to refresh UI and cursor position after resizing
    if Editor.active then
        -- Recreate UI elements to adjust to new window size
        local EditorUI = require("src.editor.ui")
        EditorUI.createUI()
    end
end

-- Global function to create a diamond-shaped win hole (used by debug.lua)
_G.createDiamondWinHole = function(level)
    local WinHoleGenerator = require("src.win_hole_generator")
    WinHoleGenerator.createDiamondWinHole(level, nil, nil, 20, 20)
end

-- Function to convert screen coordinates to game coordinates
function screenToGameCoords(screenX, screenY)
    -- Get screen dimensions
    local width, height = love.graphics.getDimensions()
    
    -- Calculate scale factors
    local scaleX = width / Game.ORIGINAL_WIDTH
    local scaleY = height / Game.ORIGINAL_HEIGHT
    local scale = math.min(scaleX, scaleY)
    
    -- Ensure minimum scale to prevent rendering issues
    scale = math.max(scale, 0.5) -- Minimum scale factor of 0.5
    
    -- Calculate offsets for centering
    local scaledWidth = width / scale
    local scaledHeight = height / scale
    local offsetX = (scaledWidth - Game.ORIGINAL_WIDTH) / 2
    local offsetY = (scaledHeight - Game.ORIGINAL_HEIGHT) / 2
    
    -- Convert screen coordinates to game coordinates
    local gameX = (screenX / scale) - offsetX
    local gameY = (screenY / scale) - offsetY
    
    return gameX, gameY
end
