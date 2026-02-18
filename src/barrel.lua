-- src/barrel.lua - Exploding barrel implementation

local CellTypes = require("src.cell_types")
local Fire      = require("src.fire")

local Barrel = {}
Barrel.__index = Barrel

-- Visual dimensions (pixels)
Barrel.WIDTH  = 24
Barrel.HEIGHT = 32

-- Physics dimensions (slightly smaller than visual)
local PHYS_W = 20
local PHYS_H = 27

-- Colors
local COLORS = {
    BODY      = {0.55, 0.18, 0.15, 1},   -- Dark rust-red body
    CAP       = {0.42, 0.13, 0.11, 1},   -- Slightly darker cap / rim
    BAND      = {0.20, 0.13, 0.08, 1},   -- Very dark metal hoop
    DANGER    = {1.00, 0.55, 0.00, 1},   -- Orange X danger marking
    HIGHLIGHT = {0.68, 0.28, 0.22, 1},   -- Left-edge highlight streak
}

-- Constructor
function Barrel.new(world, x, y)
    local self = setmetatable({}, Barrel)

    self.isBarrel = true   -- Marker used by collision detection

    self.body    = love.physics.newBody(world, x, y, "dynamic")
    self.shape   = love.physics.newRectangleShape(PHYS_W, PHYS_H)
    self.fixture = love.physics.newFixture(self.body, self.shape, 3)  -- density 3
    self.fixture:setRestitution(0.20)
    self.fixture:setFriction(0.70)
    self.fixture:setUserData(self)   -- barrel object as fixture user-data
    self.body:setUserData(self)      -- also on the body for easy retrieval

    -- Explosion state
    self.exploded         = false
    self.pendingExplosion = false
    self.armed            = false    -- becomes true after armTimer seconds
    self.armTimer         = 0.5     -- grace period before barrel can be triggered

    -- Environment state (identical pattern to boulder.lua)
    self.inWater   = false
    self.waterCells = {}
    self.inSand    = false
    self.sandCells  = {}
    self.world = world

    return self
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Update
-- ──────────────────────────────────────────────────────────────────────────────
function Barrel:update(dt)
    if self.exploded then return true end

    -- Arm timer: ignore collisions right after placement so the barrel
    -- doesn't immediately explode from the initial physics settling.
    if not self.armed then
        self.armTimer = self.armTimer - dt
        if self.armTimer <= 0 then
            self.armed = true
        end
    end

    local vx, vy = self.body:getLinearVelocity()
    local speed  = math.sqrt(vx * vx + vy * vy)

    -- Water drag + slight buoyancy
    if self.inWater and speed > 10 then
        local drag = 0.025
        self.body:applyForce(-vx * speed * drag, -vy * speed * drag + 35)
    end

    -- Sand drag
    if self.inSand and speed > 5 then
        local drag = 0.06
        self.body:applyForce(-vx * speed * drag, -vy * speed * drag)
        local av = self.body:getAngularVelocity()
        self.body:setAngularVelocity(av * 0.97)
    end

    return speed < 5
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Draw
-- ──────────────────────────────────────────────────────────────────────────────
function Barrel:draw(debug)
    if self.exploded then return end

    love.graphics.push()

    local x, y = self.body:getPosition()
    love.graphics.translate(x, y)
    love.graphics.rotate(self.body:getAngle())

    local hw = Barrel.WIDTH  / 2   -- 12
    local hh = Barrel.HEIGHT / 2   -- 16

    -- Environment tint multipliers
    local tr, tg, tb = 1, 1, 1
    if self.inWater then
        tr, tg, tb = 0.78, 0.82, 1.20
    elseif self.inSand then
        tr, tg, tb = 1.10, 0.90, 0.70
    end

    local function setCol(c)
        love.graphics.setColor(c[1] * tr, c[2] * tg, c[3] * tb, c[4])
    end

    -- ── main body ──────────────────────────────────────────────────────────
    setCol(COLORS.BODY)
    love.graphics.rectangle("fill", -hw, -hh, Barrel.WIDTH, Barrel.HEIGHT, 2, 2)

    -- ── top and bottom caps ───────────────────────────────────────────────
    setCol(COLORS.CAP)
    love.graphics.rectangle("fill", -hw, -hh,    Barrel.WIDTH, 5)   -- top
    love.graphics.rectangle("fill", -hw,  hh - 5, Barrel.WIDTH, 5)  -- bottom

    -- ── metal hoops ────────────────────────────────────────────────────────
    setCol(COLORS.BAND)
    love.graphics.rectangle("fill", -hw, -hh + 7,  Barrel.WIDTH, 3)  -- upper hoop
    love.graphics.rectangle("fill", -hw,        -2, Barrel.WIDTH, 4)  -- centre hoop
    love.graphics.rectangle("fill", -hw,  hh - 10, Barrel.WIDTH, 3)  -- lower hoop

    -- ── orange X danger marker (centred in the upper belly) ────────────────
    setCol(COLORS.DANGER)
    love.graphics.setLineWidth(2)
    local mx, my = 7, 5
    -- X centred at (0, -6) in local coords
    love.graphics.line(-mx, -6 - my,  mx, -6 + my)
    love.graphics.line( mx, -6 - my, -mx, -6 + my)
    love.graphics.setLineWidth(1)

    -- ── left-edge highlight streak ─────────────────────────────────────────
    setCol(COLORS.HIGHLIGHT)
    love.graphics.rectangle("fill", -hw, -hh + 5, 2, Barrel.HEIGHT - 10)

    -- ── debug physics shape ────────────────────────────────────────────────
    if debug and self.body then
        love.graphics.setColor(1, 0, 0, 0.8)
        love.graphics.rectangle("line", -PHYS_W / 2, -PHYS_H / 2, PHYS_W, PHYS_H)
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.line(0, 0, PHYS_W / 2, 0)
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.line(0, 0, 0, PHYS_H / 2)
    end

    love.graphics.pop()

    -- Labels rendered outside the local transform
    if debug then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Barrel", x + hw + 3, y - 15)
        if self.pendingExplosion then
            love.graphics.setColor(1, 0.2, 0.2, 1)
            love.graphics.print("BOOM!", x + hw + 3, y)
        end
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Explode
--   level         – the Level object (for cell manipulation)
--   sandToConvert – Collision.sandToConvert table (particle queue)
--   allBarrels    – level.barrels list (for chain reactions)
--   ball          – the player ball (receives physics impulse)
-- ──────────────────────────────────────────────────────────────────────────────
function Barrel:explode(level, sandToConvert, allBarrels, ball)
    if self.exploded then return false end

    self.exploded         = true
    self.pendingExplosion = false

    -- Grab world position BEFORE destroying the body
    local wx, wy = self.body:getPosition()

    -- Destroy physics body completely so no invisible obstacle remains.
    -- setSensor + setActive is not enough in Love2D/Box2D – the fixture
    -- can still block queries. Full destroy is the only safe option here.
    if self.fixture then
        self.fixture:destroy()
        self.fixture = nil
    end
    self.body:destroy()
    self.body = nil

    local Cell    = require("cell")
    local gridX   = math.floor(wx / Cell.SIZE)
    local gridY   = math.floor(wy / Cell.SIZE)
    local radius  = 8   -- explosion radius in grid cells

    -- ── Sound & camera shake ───────────────────────────────────────────────
    local Sound = require("src.sound")
    Sound.playExplosion(radius * 1.5)

    -- ── Fire wave ──────────────────────────────────────────────────────────
    Fire.createExplosion(level, gridX, gridY, radius)

    -- Dense fire at the centre
    for dy = -2, 2 do
        for dx = -2, 2 do
            local cx, cy = gridX + dx, gridY + dy
            if math.sqrt(dx * dx + dy * dy) <= 2 and
               cx >= 0 and cx < level.width and
               cy >= 0 and cy < level.height then
                Fire.createFire(level, cx, cy)
            end
        end
    end

    -- ── Destroy cells & create flying particles ────────────────────────────
    for dy = -radius, radius do
        for dx = -radius, radius do
            local cx, cy   = gridX + dx, gridY + dy
            local distance = math.sqrt(dx * dx + dy * dy)

            if distance <= radius and
               cx >= 0 and cx < level.width and
               cy >= 0 and cy < level.height then

                local cellType = level:getCellType(cx, cy)

                -- Only blast material cells; leave water/fire/smoke/win_hole alone
                if cellType ~= CellTypes.TYPES.EMPTY    and
                   cellType ~= CellTypes.TYPES.WATER    and
                   cellType ~= CellTypes.TYPES.FIRE     and
                   cellType ~= CellTypes.TYPES.SMOKE    and
                   cellType ~= CellTypes.TYPES.WIN_HOLE then

                    local dirX, dirY = dx, dy
                    if dx == 0 and dy == 0 then
                        dirX, dirY = 0, -1
                    else
                        local len = math.sqrt(dirX * dirX + dirY * dirY)
                        dirX = dirX / len
                        dirY = dirY / len
                    end

                    local impact = 1 - distance / radius
                    local flyVx  = dirX * 700 * impact + math.random(-100, 100)
                    local flyVy  = dirY * 700 * impact - 300 + math.random(-100, 100)

                    level:setCellType(cx, cy, CellTypes.TYPES.EMPTY)
                    table.insert(sandToConvert, {
                        x            = cx,
                        y            = cy,
                        vx           = flyVx,
                        vy           = flyVy,
                        originalType = cellType,
                        shouldConvert = true,
                    })
                end
            end
        end
    end

    -- ── Push the ball away ─────────────────────────────────────────────────
    if ball and ball.body then
        local bx, by     = ball.body:getPosition()
        local dist       = math.sqrt((bx - wx) ^ 2 + (by - wy) ^ 2)
        local blastRange = radius * Cell.SIZE * 2.0
        if dist < blastRange and dist > 0 then
            local force = (1 - dist / blastRange) * 3500
            local nx    = (bx - wx) / dist
            local ny    = (by - wy) / dist
            ball.body:applyLinearImpulse(nx * force, ny * force - force * 0.3)
        end
    end

    -- ── Chain reaction: mark nearby barrels ───────────────────────────────
    if allBarrels then
        local blastRange = radius * Cell.SIZE * 1.5
        for _, other in ipairs(allBarrels) do
            if other ~= self and not other.exploded then
                local bx, by = other.body:getPosition()
                local dist   = math.sqrt((bx - wx) ^ 2 + (by - wy) ^ 2)
                if dist <= blastRange then
                    other.pendingExplosion = true
                end
            end
        end
    end

    return true
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Environment helpers  (identical contract to boulder.lua)
-- ──────────────────────────────────────────────────────────────────────────────

function Barrel:isCollidingWithCell(cellX, cellY, cellSize)
    if not self.body then return false end
    local bx, by     = self.body:getPosition()
    local hw, hh     = PHYS_W / 2, PHYS_H / 2
    local cellLeft   = cellX * cellSize
    local cellRight  = cellLeft + cellSize
    local cellTop    = cellY * cellSize
    local cellBottom = cellTop + cellSize
    return not (bx + hw < cellLeft  or bx - hw > cellRight or
                by + hh < cellTop   or by - hh > cellBottom)
end

function Barrel:getPosition()
    if not self.body then return 0, 0 end
    return self.body:getPosition()
end

function Barrel:enterWater(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.waterCells[key] = true
    self.inWater = true
end

function Barrel:exitWater(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.waterCells[key] = nil
    local sw = false
    for _ in pairs(self.waterCells) do sw = true; break end
    self.inWater = sw
end

function Barrel:enterSand(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.sandCells[key] = true
    self.inSand = true
end

function Barrel:exitSand(cellX, cellY)
    local key = cellX .. "," .. cellY
    self.sandCells[key] = nil
    local ss = false
    for _ in pairs(self.sandCells) do ss = true; break end
    self.inSand = ss
end

return Barrel
