-- src/game_update.lua - Handles the game update loop logic

local Effects = require("src.effects")
local Collision = require("src.collision")
local Sound = require("src.sound")
local Fire = require("src.fire")
local UI = require("src.ui")
local Menu = require("src.menu")
local Editor = require("src.editor")
local Balls = require("src.balls") -- Added require for Balls

local GameUpdate = {}

-- Update the game
function GameUpdate.update(Game, dt)
    -- If menu is active, update menu
    if Game.currentMode == Game.MODES.MENU then
        Menu.update(dt)
        return
    end

    -- If editor is active, update editor instead of game
    if Editor.active then
        Editor.update(dt)
        return
    end

    -- Process sand cells that need to be converted to visual sand
    Effects.processSandConversion(Collision.sandToConvert, Game.level)
    Collision.sandToConvert = {} -- Clear the queue

    -- Update the physics world
    if Game.world then
        Game.world:update(dt)
    end

    -- Update sound system and camera shake effect
    Sound.update(dt)
    Sound.updateCameraShake(dt)

    -- Update the ball
    if Game.ball then
        local ballStopped = Game.ball:update(dt)

        -- Check if the exploding ball should switch to standard ball
        if Game.ball.shouldSwitchToStandard then
            Game.currentBallType = Balls.TYPES.STANDARD
            local newBall = Balls.changeBallType(Game.ball, Game.world, Game.currentBallType)
            if Game.ball and Game.ball.body then Game.ball.body:destroy() end -- Destroy old ball's body
            Game.ball = newBall
            if Game.ball and Game.ball.body then Game.ball.body:setUserData(Game.ball) end -- Set the ball as the user data for the ball body
            print("Switched to Standard Ball after explosion")
        end

        -- Check for win condition
        if Game.ball.hasWon and not Game.gameWon then
            Game.gameWon = true
            Game.winMessageTimer = 999999.0 -- Display win message until user dismisses it
            print("GAME WON! Congratulations!")

            -- If in PLAY mode, advance to next level
            if Game.currentMode == Game.MODES.PLAY and Menu.currentLevel < Menu.totalLevels then
                Menu.currentLevel = Menu.currentLevel + 1
            end
        end
    end


    -- Win message timer is no longer decremented automatically
    -- It will only be reset when the user clicks the continue button or presses R

    -- Update the level (always update all clusters)
    if Game.level then
        Game.level:update(dt, Game.ball)

        -- Update boulders if they exist
        if Game.level.boulders then
            for _, boulder in ipairs(Game.level.boulders) do
                boulder:update(dt)
            end
        end
    end


    -- Update fire and smoke
    Fire.update(dt, Game.level)

    -- Update input
    if Game.input then
        Game.input:update(Game.ball, Game.level)
    end

    -- Update UI
    local mouseX, mouseY = love.mouse.getPosition()
    UI.update(mouseX, mouseY)
end

return GameUpdate
