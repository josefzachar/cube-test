-- water_ball.lua - Water ball implementation
-- Sprays water cells behind it while flying through air (like spraying ball sprays sand).
-- Detects "real" water by grid-scanning cells around itself each frame (like ice ball).
-- Self-placed cells are always 3+ cells behind the ball and fall away, so they
-- never appear in the scan window → no false in-water triggers while airborne.
-- When properly submerged it bobs up to the surface quickly.

local BaseBall  = require("src.balls.ball_base")
local CellTypes = require("src.cell_types")

local WaterBall = {}
WaterBall.__index = WaterBall
setmetatable(WaterBall, BaseBall)

-- How many WATER cells must be in the scan window to count as "in water"
WaterBall.WATER_THRESHOLD = 2
-- Scan radius in cells around the ball center
WaterBall.SCAN_RADIUS = 1

-- Constructor
function WaterBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.WATER_BALL)

    self.fixture:destroy()
    self.fixture = love.physics.newFixture(self.body, self.shape, 1.5)
    self.fixture:setRestitution(0.0)  -- no bouncing off water surface
    self.fixture:setFriction(0.1)
    self.fixture:setUserData("ball")

    self.body:setLinearDamping(0.1)

    -- Spray state (mirror spraying ball)
    self.sprayTimer    = 0
    self.sprayInterval = 0.02
    self.sprayRate     = 8

    -- Floating animation timer
    self.bobTimer = 0

    return setmetatable(self, WaterBall)
end

-- ── Appearance ────────────────────────────────────────────────────────────────

function WaterBall:getColor()
    return BaseBall.COLORS.WATER_COLOR
end

function WaterBall:drawSpecialIndicator()
    -- Three water-drop dots at the bottom of the ball
    love.graphics.setColor(0.4, 0.8, 1, 0.9)
    love.graphics.circle("fill", -5,  5, 2.5)
    love.graphics.circle("fill",  0,  7, 2.5)
    love.graphics.circle("fill",  5,  5, 2.5)

    -- Ripple arcs while floating on real water
    if self.inWater then
        local wave = math.sin(self.bobTimer * 5) * 2
        love.graphics.setColor(0.5, 0.9, 1, 0.55)
        love.graphics.setLineWidth(1.5)
        love.graphics.arc("line", "open", 0, 11 + wave, 9,  0.1, math.pi - 0.1)
        love.graphics.arc("line", "open", 0, 13 + wave, 6,  0.2, math.pi - 0.2)
        love.graphics.setLineWidth(1)
    end
end

function WaterBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(BaseBall.COLORS.WATER_COLOR)
    love.graphics.print("Water Ball", x + 15, y + yOffset)
end

-- ── Physics overrides ─────────────────────────────────────────────────────────

function WaterBall:getPowerMultiplier()          return 1.2  end
function WaterBall:getAngularMultiplier()        return 70   end
-- gravity force on ball ≈ mass(2) × gravity(9.81×64≈628) ≈ 1256
-- Return 0 here so ball_base doesn't add its own (wrongly-signed) buoyancy.
-- WaterBall handles all buoyancy itself in update().
function WaterBall:getBuoyancyForce()            return 0    end
function WaterBall:getWaterDragCoefficient()     return 0.0  end  -- also handled manually
function WaterBall:getSandDragCoefficient()      return 0.005 end
function WaterBall:getStoppedThreshold()         return 5    end

-- ── Grid-based water detection (replaces collision-callback approach) ──────────
-- Scan the level grid cells around the ball position each frame.
-- Self-sprayed cells are always 4 cells behind the movement direction, so they
-- fall outside the scan radius (1 cell) and are never counted.

function WaterBall:detectWater()
    local Game  = require("src.game")
    local level = Game.level
    if not level then return end

    local bx, by = self.body:getPosition()
    local SIZE   = CellTypes.SIZE
    local gx     = math.floor(bx / SIZE)
    local gy     = math.floor(by / SIZE)
    local r      = WaterBall.SCAN_RADIUS
    local count  = 0

    for dy = -r, r do
        for dx = -r, r do
            local cx, cy = gx + dx, gy + dy
            if cx >= 0 and cx < level.width and cy >= 0 and cy < level.height then
                if level:getCellType(cx, cy) == CellTypes.TYPES.WATER then
                    -- Only count settled WATER, not SPRAY_WATER (self-sprayed cells)
                    count = count + 1
                end
            end
        end
    end

    if count >= WaterBall.WATER_THRESHOLD then
        self.inWater    = true
        self.waterCells = self.waterCells or {}
    else
        self.inWater    = false
        self.waterCells = {}
    end
end

-- ── Update ────────────────────────────────────────────────────────────────────

function WaterBall:update(dt)
    self.bobTimer = self.bobTimer + dt

    -- Grid-based water check every frame (bypasses collision callbacks)
    self:detectWater()

    -- Spray water trail only while airborne
    if self.isLaunched and not self.inWater then
        self.sprayTimer = self.sprayTimer + dt
        if self.sprayTimer >= self.sprayInterval then
            self.sprayTimer = 0

            local vx, vy = self.body:getLinearVelocity()
            local speed  = math.sqrt(vx * vx + vy * vy)
            if speed > 50 then
                local Game  = require("src.game")
                local level = Game.level
                if level then
                    local bx, by = self.body:getPosition()
                    local SIZE   = CellTypes.SIZE
                    local gx     = math.floor(bx / SIZE)
                    local gy     = math.floor(by / SIZE)
                    local dirX   = -vx / speed
                    local dirY   = -vy / speed
                    local perpX  = -dirY
                    local perpY  =  dirX

                    for _ = 1, self.sprayRate do
                        -- 1-3 cells behind along movement, ±1 perpendicular spread
                        -- Placed as SPRAY_WATER so detectWater() never counts them
                        local baseDist = math.random(1, 3)
                        local spread   = math.random(-1, 1)
                        local ox = math.floor(dirX * baseDist + perpX * spread)
                        local oy = math.floor(dirY * baseDist + perpY * spread)
                        local sx = gx + ox
                        local sy = gy + oy
                        if sx >= 0 and sx < level.width and sy >= 0 and sy < level.height then
                            if level:getCellType(sx, sy) == CellTypes.TYPES.EMPTY then
                                level:setCellType(sx, sy, CellTypes.TYPES.SPRAY_WATER)
                                if level.activeCells then
                                    table.insert(level.activeCells, {x = sx, y = sy})
                                    if sy < level.height - 1 then
                                        table.insert(level.activeCells, {x = sx, y = sy + 1})
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    else
        self.sprayTimer = 0
    end

    -- Full water physics handled here (bypasses ball_base which has wrong-sign buoyancy)
    if self.inWater then
        local vx, vy = self.body:getLinearVelocity()

        -- 1. Constant upward buoyancy — always overcomes gravity (1256 N)
        --    High value = ball barely sinks, pops up fast
        self.body:applyForce(0, -4000)

        -- 2. Damp sinking velocity
        if vy > 0 then
            vy = vy * 0.75
        end

        -- 3. Damp upward bounce so ball doesn't skip off the water surface
        if vy < -30 then
            vy = vy * 0.3
        end

        -- 4. Horizontal damping so ball settles on surface
        self.body:setLinearVelocity(vx * 0.9, vy)

        -- 5. Kill spin so the aiming arrow is stable while floating
        self.body:setAngularVelocity(self.body:getAngularVelocity() * 0.6)
    end

    return BaseBall.update(self, dt)
end

-- Reset on new shot
function WaterBall:shoot(direction, power)
    self.sprayTimer = 0
    BaseBall.shoot(self, direction, power)
end

function WaterBall:reset(x, y)
    self.sprayTimer = 0
    self.bobTimer   = 0
    BaseBall.reset(self, x, y)
end

return WaterBall

