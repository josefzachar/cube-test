-- heavy_ball.lua - Heavy ball implementation

local BaseBall = require("src.balls.ball_base")

local HeavyBall = {}
HeavyBall.__index = HeavyBall
setmetatable(HeavyBall, BaseBall) -- Inherit from BaseBall

-- Constructor
function HeavyBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.HEAVY)
    
    -- Override physics properties for heavy ball - similar to standard ball in the air
    self.fixture:destroy() -- Remove default fixture
    self.fixture = love.physics.newFixture(self.body, self.shape, 2) -- Similar to standard ball
    self.fixture:setRestitution(0.5) -- Standard bounce
    self.fixture:setFriction(0.5) -- Standard friction
    self.fixture:setUserData("ball")
    
    -- No linear damping - flies like standard ball
    self.body:setLinearDamping(0.0)
    
    return setmetatable(self, HeavyBall)
end

-- Override methods to provide heavy ball behavior
function HeavyBall:getColor()
    return BaseBall.COLORS.HEAVY_COLOR
end

function HeavyBall:drawSpecialIndicator()
    -- Draw a weight symbol (horizontal lines)
    love.graphics.setColor(0.2, 0.2, 0.4, 1)
    love.graphics.rectangle("fill", -7, -2, 14, 1)
    love.graphics.rectangle("fill", -7, 2, 14, 1)
end

function HeavyBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(BaseBall.COLORS.HEAVY_COLOR)
    love.graphics.print("Heavy Ball", x + 15, y + yOffset)
end

-- Heavy ball has less water resistance
function HeavyBall:getWaterDragCoefficient()
    return 0.005 -- Less water drag
end

function HeavyBall:getBuoyancyForce()
    return 50 -- Less buoyancy
end

function HeavyBall:getSandDragCoefficient()
    return 0.015 -- Less sand drag
end

function HeavyBall:getStoppedThreshold()
    return 8 -- Needs more speed to be considered "moving"
end

function HeavyBall:getPowerMultiplier()
    return 1.5 -- More power
end

function HeavyBall:getAngularMultiplier()
    return 80 -- More rotation
end

return HeavyBall
