-- bullet_ball.lua - Bullet ball implementation
-- Fires like a projectile: punches through sand/dirt based on shot power,
-- buries itself when it runs out of penetration energy.

local BaseBall  = require("src.balls.ball_base")
local CellTypes = require("src.cell_types")
local Fire      = require("src.fire")

local BulletBall = {}
BulletBall.__index = BulletBall
setmetatable(BulletBall, BaseBall)

-- Speed cost (px/s) subtracted from ballspeed each time a material cell is removed.
-- Note: tunnel is 3 cells wide so effective drain is 3× this per column.
-- Higher value = harder to penetrate.
BulletBall.HARDNESS = {
    [CellTypes.TYPES.SAND]  = 12,   -- Easy – punches through many sand cells
    [CellTypes.TYPES.DIRT]  = 40,   -- Medium – punches several dirt cells
    [CellTypes.TYPES.ICE]   = 25,   -- Between sand and dirt – ice cracks but slows bullet
    [CellTypes.TYPES.STONE] = 1200, -- Very hard – only a max-power shot can crack it
}

-- Constructor
function BulletBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.BULLET)

    self.fixture:destroy()
    self.fixture = love.physics.newFixture(self.body, self.shape, 3) -- dense
    self.fixture:setRestitution(0.0)  -- No bounce – buries itself
    self.fixture:setFriction(0.8)
    self.fixture:setUserData("ball")

    self.body:setLinearDamping(0.0)

    -- Tracks remaining penetration energy (set when shot)
    self.penetrationEnergy = 0

    return setmetatable(self, BulletBall)
end

-- ── Appearance ────────────────────────────────────────────────────────────────

function BulletBall:getColor()
    return BaseBall.COLORS.BULLET_COLOR
end

function BulletBall:drawSpecialIndicator()
    -- Draw a simple bullet tip pointing right
    love.graphics.setColor(0.6, 0.6, 0.65, 1)
    love.graphics.polygon("fill", 8, 0, 2, -4, 2, 4)
end

function BulletBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(BaseBall.COLORS.BULLET_COLOR)
    love.graphics.print(string.format("Bullet Ball (E:%.0f)", self.penetrationEnergy or 0),
                        x + 15, y + yOffset)
end

-- ── Physics overrides ─────────────────────────────────────────────────────────

function BulletBall:getPowerMultiplier()
    return 2.2   -- Fired fast with extra penetration energy
end

function BulletBall:getAngularMultiplier()
    return 20    -- Less spin
end

function BulletBall:getWaterDragCoefficient()
    return 0.004 -- Cuts through water
end

function BulletBall:getBuoyancyForce()
    return 30
end

function BulletBall:getSandDragCoefficient()
    return 0.0   -- Sand drag handled by the penetration energy system
end

function BulletBall:getStoppedThreshold()
    return 8
end

-- Prevent sand-physics state from being set (bullet ignores sand drag)
function BulletBall:enterSand(cellX, cellY) end
function BulletBall:exitSand(cellX, cellY)  end

-- ── Shoot ─────────────────────────────────────────────────────────────────────

function BulletBall:shoot(direction, power)
    -- Reset pen-energy; base it on the shot power so weak shots penetrate less
    self.penetrationEnergy = power * self:getPowerMultiplier()
    BaseBall.shoot(self, direction, power)
end

function BulletBall:reset(x, y)
    self.penetrationEnergy = 0
    BaseBall.reset(self, x, y)
end

-- ── Update ────────────────────────────────────────────────────────────────────

function BulletBall:update(dt)
    if self.isLaunched and self.penetrationEnergy > 0 then
        local Game  = require("src.game")
        local level = Game.level

        if level then
            local vx, vy = self.body:getLinearVelocity()
            local speed  = math.sqrt(vx * vx + vy * vy)

            if speed > 20 then
                local bx, by = self.body:getPosition()
                local nx, ny = vx / speed, vy / speed
                local SIZE   = CellTypes.SIZE

                -- Scan ½-cell behind (handles tunnelling) and 1 cell ahead.
                -- Also sweep 1 cell on each side perpendicular to velocity (3-cell wide tunnel).
                -- De-duplicate by grid coordinates so the same cell is charged once.
                local px_perp = -ny  -- perpendicular direction
                local py_perp =  nx
                local visited = {}
                local totalDrain = 0

                for _, scale in ipairs({ -0.5, 0, 0.7, 1.3 }) do
                    for _, side in ipairs({ -1, 0, 1 }) do
                        local px = bx + nx * SIZE * scale + px_perp * SIZE * side
                        local py = by + ny * SIZE * scale + py_perp * SIZE * side
                        local gx = math.floor(px / SIZE)
                        local gy = math.floor(py / SIZE)
                        local key = gx .. "," .. gy

                        if not visited[key] then
                            visited[key] = true

                            if gx >= 0 and gx < level.width and gy >= 0 and gy < level.height then
                                local ct      = level:getCellType(gx, gy)
                                local hardness = BulletBall.HARDNESS[ct]

                                if hardness then
                                    level:setCellType(gx, gy, CellTypes.TYPES.EMPTY)
                                    Fire.createSmoke(level, gx, gy)
                                    totalDrain = totalDrain + hardness
                                end
                            end
                        end
                    end
                end

                if totalDrain > 0 then
                    -- Drain penetration energy
                    self.penetrationEnergy = math.max(0, self.penetrationEnergy - totalDrain)

                    -- Place a small fire plume 2-3 cells ahead of the bullet
                    for _, fireScale in ipairs({ 1.8, 2.5 }) do
                        local fx = math.floor((bx + nx * SIZE * fireScale) / SIZE)
                        local fy = math.floor((by + ny * SIZE * fireScale) / SIZE)
                        if fx >= 0 and fx < level.width and fy >= 0 and fy < level.height then
                            local fct = level:getCellType(fx, fy)
                            -- Only place fire in empty cells or penetrable material
                            if fct == CellTypes.TYPES.EMPTY or BulletBall.HARDNESS[fct] then
                                Fire.createFire(level, fx, fy)
                            end
                        end
                    end

                    -- Also reduce actual speed proportionally
                    local newSpeed = math.max(0, speed - totalDrain)
                    if newSpeed > 0 then
                        self.body:setLinearVelocity(vx * newSpeed / speed,
                                                    vy * newSpeed / speed)
                    else
                        self.body:setLinearVelocity(0, 0)
                    end
                end
            end
        end
    end

    return BaseBall.update(self, dt)
end

return BulletBall
