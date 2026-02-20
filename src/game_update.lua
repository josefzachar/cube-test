-- src/game_update.lua - Handles the game update loop logic

local Effects = require("src.effects")
local Collision = require("src.collision")
local Sound = require("src.sound")
local Fire = require("src.fire")
local UI = require("src.ui")
local Menu = require("src.menu")
local Editor = require("src.editor")
local Balls = require("src.balls") -- Added require for Balls
local CellTypes = require("src.cell_types")

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

    -- Process ICE cells that shattered to WATER (deferred to avoid Box2D world-lock)
    for _, cell in ipairs(Collision.iceToMelt) do
        Game.level:setCellType(cell.x, cell.y, CellTypes.TYPES.WATER)
    end
    Collision.iceToMelt = {}

    -- Update the physics world
    if Game.world then
        local physicsStart = love.timer.getTime()
        Game.world:update(dt)
        if Game.level and Game.level.perfStats then
            Game.level.perfStats.physicsStep = love.timer.getTime() - physicsStart
        end
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

        -- Check for win condition — wait for the spiral animation to finish before showing the win screen
        if Game.ball.hasWon and not Game.gameWon then
            -- Stage 1: animation done → start screen fade
            if Game.ball.winAnimTimer and Game.ball.scale and Game.ball.scale <= 0 then
                if not Game.winFadeTimer then
                    Game.winFadeTimer = 0  -- begin fade
                end
            end
            -- Stage 2: advance fade
            if Game.winFadeTimer then
                local FADE_DURATION = 0.65
                Game.winFadeTimer = Game.winFadeTimer + dt
                Game.winFadeAlpha = math.min(Game.winFadeTimer / FADE_DURATION, 1.0)
                Game.winFadeAlpha = Game.winFadeAlpha * Game.winFadeAlpha  -- ease-in
                if Game.winFadeTimer >= FADE_DURATION then
                    Game.winFadeTimer = nil
                    Game.winFadeAlpha = 1.0  -- stay fully black under modal
                    Game.gameWon = true
                    Game.winMessageTimer = 999999.0
                    print("GAME WON! Congratulations!")
                    if Game.currentMode == Game.MODES.PLAY and Menu.currentLevel < Menu.totalLevels then
                        Menu.currentLevel = Menu.currentLevel + 1
                    end
                end
            end
        end

        -- Proximity fallback: if the ball is very close to the win hole but the physics
        -- sensor didn't fire (e.g. high speed tunnelling), set hasWon manually.
        if not Game.ball.hasWon and Game.level then
            local bx, by = Game.ball.body:getPosition()
            local CellTypes = require("src.cell_types")
            local Cell = require("cell")
            local gx = math.floor(bx / Cell.SIZE)
            local gy = math.floor(by / Cell.SIZE)
            -- Check the 3x3 grid area around the ball's grid position
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local cx, cy = gx + dx, gy + dy
                    if Game.level.cells[cy] and Game.level.cells[cy][cx] and
                       Game.level.cells[cy][cx].type == CellTypes.TYPES.WIN_HOLE then
                        -- Ball centre is within one cell of a WIN_HOLE cell — trigger win
                        Game.ball.hasWon = true
                        local vx, vy = Game.ball.body:getLinearVelocity()
                        Game.ball.winEntrySpeed = math.sqrt(vx*vx + vy*vy)
                        local Sound = require("src.sound")
                        Sound.playWin()
                        -- Compute hole centroid
                        local holeSumX, holeSumY, holeCount = 0, 0, 0
                        for sy = 0, Game.level.height - 1 do
                            for sx = 0, Game.level.width - 1 do
                                if Game.level.cells[sy] and Game.level.cells[sy][sx] and
                                   Game.level.cells[sy][sx].type == CellTypes.TYPES.WIN_HOLE then
                                    holeSumX = holeSumX + sx
                                    holeSumY = holeSumY + sy
                                    holeCount = holeCount + 1
                                end
                            end
                        end
                        if holeCount > 0 then
                            Game.ball.winHoleCenterX = (holeSumX / holeCount + 0.5) * Cell.SIZE
                            Game.ball.winHoleCenterY = (holeSumY / holeCount + 0.5) * Cell.SIZE
                        end
                        print("Win triggered by proximity fallback!")
                        break
                    end
                end
                if Game.ball.hasWon then break end
            end
        end
    end


    -- Win message timer is no longer decremented automatically
    -- It will only be reset when the user clicks the continue button or presses R

    -- Process barrel explosions (including chain reactions between barrels)
    if Game.level and Game.level.barrels and #Game.level.barrels > 0 then
        local anyPending  = true
        local iterations  = 0
        local SAFE_LIMIT  = 30   -- prevent infinite loops on degenerate levels
        while anyPending and iterations < SAFE_LIMIT do
            anyPending = false
            iterations = iterations + 1
            for _, barrel in ipairs(Game.level.barrels) do
                if barrel.pendingExplosion and not barrel.exploded then
                    barrel:explode(
                        Game.level,
                        Collision.sandToConvert,
                        Game.level.barrels,
                        Game.ball
                    )
                    anyPending = true
                end
            end
        end
    end

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
    
    -- Update mobile UI if available
    if Game.mobileUI then
        Game.mobileUI.update(Game, dt)
    end
end

return GameUpdate
