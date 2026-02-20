-- growing_ball.lua - Grows 25% larger mid-flight on every shot.
-- Growth triggers ~0.35s after launch so it happens visibly in the air.
-- A spring animation overshoots the new size and bounces back for a
-- cartoonish "pop" effect.

local BaseBall  = require("src.balls.ball_base")
local CellTypes = require("src.cell_types")

local GrowingBall = {}
GrowingBall.__index = GrowingBall
setmetatable(GrowingBall, BaseBall)

GrowingBall.BASE_SIZE  = 20    -- original 20×20 size
GrowingBall.GROW_DELAY = 0.35  -- seconds airborne before growth pops
GrowingBall.MAX_POLY   = 8     -- Box2D polygon vertex limit; 9+ → circle

-- Build a flat vertex list for a regular N-gon.
-- Uses circumradius so flat sides align with the original square edges.
local function polyVerts(n, r)
    -- r here is the "inradius" (half-side of original square).
    -- Circumradius = inradius / cos(π/n) so the flat edges sit at distance r.
    local cr = r / math.cos(math.pi / n)
    local v = {}
    for i = 0, n - 1 do
        local a = (2 * math.pi * i / n) - math.pi / 2 + math.pi / n
        v[#v + 1] = cr * math.cos(a)
        v[#v + 1] = cr * math.sin(a)
    end
    return v
end

-- Constructor
function GrowingBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.GROWING_BALL)

    self.sizeScale    = 1.0    -- permanent size factor; grows each shot
    self.numSides     = 4      -- starts as a square; gains a side every 2nd shot
    self.shotCount    = 0      -- total shots fired (used to time side additions)
    self.flightTimer  = 0
    self.hasGrown     = false  -- has the mid-flight growth fired this shot?
    self.pendingCrush = false  -- crush cells on next landing

    -- Spring animation: animMult is a visual-only multiplier on top of sizeScale
    -- 1.0 = no extra scale; values != 1.0 play the bounce
    self.animMult = 1.0
    self.animVel  = 0.0  -- spring velocity

    return setmetatable(self, GrowingBall)
end

-- ── Appearance ────────────────────────────────────────────────────────────────

function GrowingBall:getColor()
    -- Lime-green → yellow-orange as the ball grows
    local t = math.min((self.sizeScale - 1) / 3, 1)
    return {0.4 + 0.5 * t, 1.0 - 0.3 * t, 0.1, 1}
end

function GrowingBall:drawSpecialIndicator()
    love.graphics.setColor(1, 1, 1, 0.85)
    local arm = math.max(3, self.size * 0.15)
    love.graphics.setLineWidth(math.max(1.5, self.size * 0.07))
    love.graphics.line(-arm, 0, arm, 0)
    love.graphics.line(0, -arm, 0, arm)
    love.graphics.setLineWidth(1)

    -- Shot count above the ball
    love.graphics.setColor(1, 1, 1, 0.7)
    local shotCount = math.floor((self.sizeScale - 1) / 0.25 + 0.5)
    if shotCount > 0 then
        love.graphics.print(tostring(shotCount), -3, -self.size * 0.5 - 8)
    end
end

function GrowingBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(0.4, 1.0, 0.2, 1)
    love.graphics.print(string.format("Growing  x%.2f  sides:%d", self.sizeScale, self.numSides), x + 15, y + yOffset)
end

-- ── Custom draw (animMult-aware) ──────────────────────────────────────────────

function GrowingBall:draw(debug)
    if self.scale and self.scale <= 0 then return end

    love.graphics.push()

    local baseColor = self:getColor()
    if self.inWater then
        love.graphics.setColor(baseColor[1] * 0.8, baseColor[2] * 0.8, baseColor[3] * 1.2, baseColor[4])
    elseif self.inSand then
        love.graphics.setColor(baseColor[1] * 1.1, baseColor[2] * 0.9, baseColor[3] * 0.7, baseColor[4])
    else
        love.graphics.setColor(baseColor)
    end

    love.graphics.translate(self.body:getX(), self.body:getY())
    love.graphics.rotate(self.body:getAngle())

    -- Win animation shrink (from base class)
    local winShrink = (self.scale and self.scale < 1.0 and self.scale > 0) and self.scale or 1.0

    -- Combine win-shrink and bounce animation
    local visualMult = winShrink * self.animMult
    love.graphics.scale(visualMult, visualMult)

    local r = self.size / 2
    if self.numSides >= GrowingBall.MAX_POLY + 1 then
        love.graphics.circle("fill", 0, 0, r)
    else
        love.graphics.polygon("fill", polyVerts(self.numSides, r))
    end

    self:drawSpecialIndicator()

    if debug then
        love.graphics.setColor(1, 0, 0, 1)
        local r = self.size / 2
        if self.numSides >= GrowingBall.MAX_POLY + 1 then
            love.graphics.circle("line", 0, 0, r)
        else
            love.graphics.polygon("line", polyVerts(self.numSides, r))
        end
        love.graphics.setColor(1, 0, 0, 1); love.graphics.line(0, 0, 15, 0)
        love.graphics.setColor(0, 1, 0, 1); love.graphics.line(0, 0, 0, 15)
    end

    love.graphics.pop()

    -- Win burst particles (world-space)
    if self.winBurst and #self.winBurst > 0 then
        for _, p in ipairs(self.winBurst) do
            local frac  = p.life / p.maxLife
            local alpha = 1.0 - frac * frac
            love.graphics.setColor(p.col[1], p.col[2], p.col[3], alpha)
            love.graphics.rectangle("fill",
                math.floor(p.x / p.sz) * p.sz,
                math.floor(p.y / p.sz) * p.sz,
                p.sz, p.sz)
        end
    end

    if debug then
        local x, y = self.body:getPosition()
        local vx, vy = self.body:getLinearVelocity()
        love.graphics.setColor(1, 1, 0, 1)
        love.graphics.line(x, y, x + vx * 0.1, y + vy * 0.1)
        self:drawDebugInfo(x, y, -20)
    end
end

-- ── Physics ───────────────────────────────────────────────────────────────────

function GrowingBall:getPowerMultiplier()   return self.sizeScale end
function GrowingBall:getAngularMultiplier() return 50 end

-- Rebuild physics fixture to match sizeScale and numSides
function GrowingBall:applySize()
    self.size = math.floor(GrowingBall.BASE_SIZE * self.sizeScale)
    local r   = self.size / 2
    self.fixture:destroy()
    if self.numSides >= GrowingBall.MAX_POLY + 1 then
        self.shape = love.physics.newCircleShape(r)
    else
        self.shape = love.physics.newPolygonShape(unpack(polyVerts(self.numSides, r)))
    end
    self.fixture = love.physics.newFixture(self.body, self.shape, 2)
    self.fixture:setRestitution(0.3)
    self.fixture:setFriction(0.5)
    self.fixture:setUserData("ball")
end

-- ── Shoot / Reset ─────────────────────────────────────────────────────────────

function GrowingBall:shoot(direction, power)
    self.flightTimer = 0
    self.hasGrown    = false
    BaseBall.shoot(self, direction, power)
end

function GrowingBall:reset(x, y)
    BaseBall.reset(self, x, y)
end

-- ── Update ────────────────────────────────────────────────────────────────────

function GrowingBall:update(dt)
    -- ── Spring animation (runs every frame) ──
    -- Underdamped spring → one clean overshoot then settles at 1.0
    local SPRING_K    = 380
    local SPRING_DAMP = 9
    if math.abs(self.animMult - 1.0) > 0.001 or math.abs(self.animVel) > 0.001 then
        local force   = SPRING_K * (1.0 - self.animMult) - SPRING_DAMP * self.animVel
        self.animVel  = self.animVel + force * dt
        self.animMult = self.animMult + self.animVel * dt
        if self.animMult < 0.05 then self.animMult = 0.05; self.animVel = 0 end
    else
        self.animMult = 1.0
        self.animVel  = 0.0
    end

    -- ── Flight timer → trigger growth mid-air ──
    if self.isLaunched and not self.hasGrown then
        self.flightTimer = self.flightTimer + dt
        if self.flightTimer >= GrowingBall.GROW_DELAY then
            self.hasGrown  = true
            local prevScale = self.sizeScale
            self.sizeScale  = self.sizeScale * 1.25
            self.shotCount  = self.shotCount + 1
            if self.shotCount % 2 == 0 then
                self.numSides = self.numSides + 1
            end
            self:applySize()

            -- Spring starts at old/new ratio (~0.8) with a forward kick → overshoots 1.0
            self.animMult = prevScale / self.sizeScale
            self.animVel  = 2.8
        end
    end

    local wasMoving = self.isLaunched
    local stopped   = BaseBall.update(self, dt)

    if wasMoving and stopped and self.hasGrown then
        self.pendingCrush = true
    end

    return stopped
end

-- ── Cell crushing on landing ──────────────────────────────────────────────────

function GrowingBall:crushCells(level)
    local x, y = self.body:getPosition()
    local Cell  = require("cell")

    local gridX = math.floor(x / Cell.SIZE)
    local gridY = math.floor(y / Cell.SIZE)

    local radius = math.floor(self.sizeScale * 1.5) - 1

    local crushable = {
        [CellTypes.TYPES.DIRT]  = true,
        [CellTypes.TYPES.SAND]  = true,
        [CellTypes.TYPES.WATER] = true,
        [CellTypes.TYPES.FIRE]  = true,
    }

    for dy = -radius, radius do
        for dx = -radius, radius do
            if math.sqrt(dx*dx + dy*dy) <= radius then
                local cx = gridX + dx
                local cy = gridY + dy
                if level.cells[cy] and level.cells[cy][cx] and
                   crushable[level.cells[cy][cx].type] then
                    level:setCellType(cx, cy, CellTypes.TYPES.EMPTY)
                end
            end
        end
    end
end

return GrowingBall

