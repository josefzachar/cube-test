-- standard_ball.lua - Standard ball implementation

local BaseBall = require("src.balls.ball_base")

local StandardBall = {}
StandardBall.__index = StandardBall
setmetatable(StandardBall, BaseBall) -- Inherit from BaseBall

-- Constructor
function StandardBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.STANDARD)
    return setmetatable(self, StandardBall)
end

-- Override methods to provide standard ball behavior
function StandardBall:getColor()
    return BaseBall.COLORS.WHITE
end

function StandardBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(BaseBall.COLORS.WHITE)
    love.graphics.print("Standard Ball", x + 15, y + yOffset)
end

-- Standard ball has default physics properties
function StandardBall:getWaterDragCoefficient()
    return 0.01 -- Default water drag
end

function StandardBall:getBuoyancyForce()
    return 100 -- Default buoyancy
end

function StandardBall:getSandDragCoefficient()
    return 0.03 -- Default sand drag
end

function StandardBall:getStoppedThreshold()
    return 5 -- Default stopped threshold
end

function StandardBall:getPowerMultiplier()
    return 1.0 -- Default power
end

function StandardBall:getAngularMultiplier()
    return 50 -- Default angular impulse
end

return StandardBall
