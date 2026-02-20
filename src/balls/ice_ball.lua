-- ice_ball.lua - Ice ball implementation
-- Slides on surfaces (very low friction), freezes water cells it touches into ICE.

local BaseBall  = require("src.balls.ball_base")
local CellTypes = require("src.cell_types")

local IceBall = {}
IceBall.__index = IceBall
setmetatable(IceBall, BaseBall)

-- Radius (in cells) around the ball that gets frozen each update while launched
IceBall.FREEZE_RADIUS = 2

-- Constructor
function IceBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.ICE_BALL)

    self.fixture:destroy()
    self.fixture = love.physics.newFixture(self.body, self.shape, 1.2)
    self.fixture:setRestitution(0.65) -- Bouncy, icy feel
    self.fixture:setFriction(0.04)    -- Extremely slippery
    self.fixture:setUserData("ball")

    self.body:setLinearDamping(0.0)

    return setmetatable(self, IceBall)
end

-- ── Appearance ────────────────────────────────────────────────────────────────

function IceBall:getColor()
    return BaseBall.COLORS.ICE_COLOR
end

function IceBall:drawSpecialIndicator()
    -- Draw small crystal/snowflake cross
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.line(-6, 0, 6, 0)
    love.graphics.line(0, -6, 0, 6)
    love.graphics.line(-4, -4, 4, 4)
    love.graphics.line(-4, 4, 4, -4)
end

function IceBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(BaseBall.COLORS.ICE_COLOR)
    love.graphics.print("Ice Ball", x + 15, y + yOffset)
end

-- ── Physics overrides ─────────────────────────────────────────────────────────

function IceBall:getPowerMultiplier()
    return 1.1
end

function IceBall:getAngularMultiplier()
    return 35
end

function IceBall:getWaterDragCoefficient()
    return 0.006
end

function IceBall:getBuoyancyForce()
    return 90
end

function IceBall:getSandDragCoefficient()
    return 0.012 -- Slides over sand somewhat better
end

function IceBall:getStoppedThreshold()
    return 4  -- Keeps sliding longer before "stopping"
end

-- ── Update – freeze water ─────────────────────────────────────────────────────

function IceBall:update(dt)
    if self.isLaunched then
        local Game  = require("src.game")
        local level = Game.level

        if level then
            local bx, by = self.body:getPosition()
            local gx = math.floor(bx / CellTypes.SIZE)
            local gy = math.floor(by / CellTypes.SIZE)
            local r  = IceBall.FREEZE_RADIUS

            for dy = -r, r do
                for dx = -r, r do
                    local cx, cy = gx + dx, gy + dy
                    if cx >= 0 and cx < level.width and cy >= 0 and cy < level.height then
                        if level:getCellType(cx, cy) == CellTypes.TYPES.WATER then
                            level:setCellType(cx, cy, CellTypes.TYPES.ICE)
                        end
                    end
                end
            end
        end
    end

    return BaseBall.update(self, dt)
end

return IceBall
