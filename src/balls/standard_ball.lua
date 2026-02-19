-- standard_ball.lua - Standard ball implementation

local BaseBall = require("src.balls.ball_base")

-- Load the ball image
local ballImage = love.graphics.newImage("img/ball.png")

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

-- Override the draw method to use the ball image
function StandardBall:draw(debug)
    -- Skip drawing if the ball has won (disappeared)
    if self.scale and self.scale <= 0 then
        return
    end
    
    love.graphics.push()
    
    -- Get base color based on ball type
    local baseColor = self:getColor()
    
    -- Apply environment tint
    if self.inWater then
        -- Mix with blue tint
        love.graphics.setColor(
            baseColor[1] * 0.8, 
            baseColor[2] * 0.8, 
            baseColor[3] * 1.2, 
            baseColor[4]
        )
    elseif self.inSand then
        -- Mix with sand tint
        love.graphics.setColor(
            baseColor[1] * 1.1, 
            baseColor[2] * 0.9, 
            baseColor[3] * 0.7, 
            baseColor[4]
        )
    else
        love.graphics.setColor(baseColor)
    end
    
    love.graphics.translate(self.body:getX(), self.body:getY())
    love.graphics.rotate(self.body:getAngle())

    -- Shrink visually during win animation
    if self.scale and self.scale < 1.0 and self.scale > 0 then
        love.graphics.scale(self.scale, self.scale)
    end

    -- Draw the ball using the image instead of a rectangle
    local imgWidth, imgHeight = ballImage:getDimensions()
    local scaleX = 20 / imgWidth  -- Scale to fit 20x20 square (ball size)
    local scaleY = 20 / imgHeight
    love.graphics.draw(ballImage, -10, -10, 0, scaleX, scaleY)
    
    -- Draw debug info
    if debug then
        -- Draw a red outline
        love.graphics.setColor(1, 0, 0, 1)
        love.graphics.rectangle("line", -10, -10, 20, 20)
        
        -- Draw axes to show rotation
        love.graphics.setColor(1, 0, 0, 1) -- Red for X axis
        love.graphics.line(0, 0, 15, 0)
        love.graphics.setColor(0, 1, 0, 1) -- Green for Y axis
        love.graphics.line(0, 0, 0, 15)
    end
    
    love.graphics.pop()

    -- Draw win burst particles (world-space, outside the ball transform)
    if self.winBurst and #self.winBurst > 0 then
        for _, p in ipairs(self.winBurst) do
            local frac  = p.life / p.maxLife
            local alpha = 1.0 - frac * frac
            love.graphics.setColor(p.col[1], p.col[2], p.col[3], alpha)
            local sx = math.floor(p.x / p.sz) * p.sz
            local sy = math.floor(p.y / p.sz) * p.sz
            love.graphics.rectangle("fill", sx, sy, p.sz, p.sz)
        end
    end

    -- Draw additional debug info outside the transform
    if debug then
        local x, y = self.body:getPosition()
        local vx, vy = self.body:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        local angle = self.body:getAngle() * 180 / math.pi -- Convert to degrees
        
        -- Draw velocity vector
        love.graphics.setColor(1, 1, 0, 1) -- Yellow
        love.graphics.line(x, y, x + vx * 0.1, y + vy * 0.1)
        
        -- Draw bounding box
        love.graphics.setColor(0, 1, 1, 0.5) -- Cyan
        love.graphics.rectangle("line", x - 10, y - 10, 20, 20)
        
        -- Show environment and ball type status
        local yOffset = -20
        
        -- Show ball type
        self:drawDebugInfo(x, y, yOffset)
        yOffset = yOffset - 15
        
        -- Show environment status
        if self.inWater then
            love.graphics.setColor(0, 0.5, 1, 1)
            love.graphics.print("In Water", x + 15, y + yOffset)
        elseif self.inSand then
            love.graphics.setColor(0.9, 0.7, 0.3, 1)
            love.graphics.print("In Sand", x + 15, y + yOffset)
        end
    end
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
