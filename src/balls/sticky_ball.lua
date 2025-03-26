-- sticky_ball.lua - Sticky ball implementation

local BaseBall = require("src.balls.ball_base")

local StickyBall = {}
StickyBall.__index = StickyBall
setmetatable(StickyBall, BaseBall) -- Inherit from BaseBall

-- Constructor
function StickyBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.STICKY)
    
    -- Override physics properties for sticky ball
    self.fixture:destroy() -- Remove default fixture
    self.fixture = love.physics.newFixture(self.body, self.shape, 1.5) -- Lower density
    self.fixture:setRestitution(0.0) -- No bounce
    self.fixture:setFriction(1.0) -- Maximum friction
    self.fixture:setUserData("ball")
    
    -- Add sticky ball specific properties
    self.stuck = false -- Track if the ball is stuck
    
    return setmetatable(self, StickyBall)
end

-- Override methods to provide sticky ball behavior
function StickyBall:getColor()
    return BaseBall.COLORS.STICKY_COLOR
end

function StickyBall:drawSpecialIndicator()
    -- Draw a dot pattern
    love.graphics.setColor(0.1, 0.5, 0.1, 1)
    love.graphics.circle("fill", -4, -4, 2)
    love.graphics.circle("fill", 4, -4, 2)
    love.graphics.circle("fill", -4, 4, 2)
    love.graphics.circle("fill", 4, 4, 2)
end

function StickyBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(BaseBall.COLORS.STICKY_COLOR)
    love.graphics.print("Sticky Ball", x + 15, y + yOffset)
end

function StickyBall:update(dt)
    -- Handle sticky ball special case
    if self.stuck then
        -- If the sticky ball is stuck, force it to stop completely
        self.body:setLinearVelocity(0, 0)
        self.body:setAngularVelocity(0)
        return true -- Ball is stationary
    end
    
    -- Call parent update method
    local stopped = BaseBall.update(self, dt)
    
    -- Check if the ball should become stuck
    local vx, vy = self.body:getLinearVelocity()
    local speed = math.sqrt(vx*vx + vy*vy)
    
    if speed < 20 and not self.stuck then
        self.stuck = true
    end
    
    return stopped
end

function StickyBall:isMoving()
    -- For sticky ball, if it's stuck, it's not considered moving
    if self.stuck then
        return false
    end
    return self.isLaunched
end

function StickyBall:getPowerMultiplier()
    return 0.8 -- Less power
end

function StickyBall:getAngularMultiplier()
    return 30 -- Less rotation
end

function StickyBall:shoot(direction, power)
    -- Reset stuck state when shot
    self.stuck = false
    
    -- Call parent method
    BaseBall.shoot(self, direction, power)
end

function StickyBall:reset(x, y)
    -- Reset stuck state
    self.stuck = false
    
    -- Call parent method
    BaseBall.reset(self, x, y)
end

return StickyBall
