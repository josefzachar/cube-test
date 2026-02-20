-- balls/init.lua - Entry point for ball types

local BaseBall    = require("src.balls.ball_base")
local StandardBall = require("src.balls.standard_ball")
local HeavyBall   = require("src.balls.heavy_ball")
local ExplodingBall = require("src.balls.exploding_ball")
local StickyBall  = require("src.balls.sticky_ball")
local SprayingBall = require("src.balls.spraying_ball")
local BulletBall  = require("src.balls.bullet_ball")
local IceBall     = require("src.balls.ice_ball")
local WaterBall   = require("src.balls.water_ball")

local Balls = {
    -- Ball types enum
    TYPES = BaseBall.TYPES,
    
    -- Ball constructors
    StandardBall = StandardBall,
    HeavyBall = HeavyBall,
    ExplodingBall = ExplodingBall,
    StickyBall = StickyBall,
    SprayingBall = SprayingBall,
    BulletBall = BulletBall,
    IceBall = IceBall,
    WaterBall = WaterBall,
    
    -- Factory function to create a ball of the specified type
    createBall = function(world, x, y, ballType)
        ballType = ballType or BaseBall.TYPES.STANDARD
        
        if ballType == BaseBall.TYPES.HEAVY then
            return HeavyBall.new(world, x, y)
        elseif ballType == BaseBall.TYPES.EXPLODING then
            return ExplodingBall.new(world, x, y)
        elseif ballType == BaseBall.TYPES.STICKY then
            return StickyBall.new(world, x, y)
        elseif ballType == BaseBall.TYPES.SPRAYING then
            return SprayingBall.new(world, x, y)
        elseif ballType == BaseBall.TYPES.BULLET then
            return BulletBall.new(world, x, y)
        elseif ballType == BaseBall.TYPES.ICE_BALL then
            return IceBall.new(world, x, y)
        elseif ballType == BaseBall.TYPES.WATER_BALL then
            return WaterBall.new(world, x, y)
        else
            return StandardBall.new(world, x, y)
        end
    end,
    
    -- Function to change a ball's type
    changeBallType = function(ball, world, newType)
        -- Get current position and velocity
        local x, y = ball.body:getPosition()
        local vx, vy = ball.body:getLinearVelocity()
        local angle = ball.body:getAngle()
        local av = ball.body:getAngularVelocity()
        local isLaunched = ball.isLaunched
        
        -- Create a new ball of the desired type
        local newBall
        if newType == BaseBall.TYPES.HEAVY then
            newBall = HeavyBall.new(world, x, y)
        elseif newType == BaseBall.TYPES.EXPLODING then
            newBall = ExplodingBall.new(world, x, y)
        elseif newType == BaseBall.TYPES.STICKY then
            newBall = StickyBall.new(world, x, y)
        elseif newType == BaseBall.TYPES.SPRAYING then
            newBall = SprayingBall.new(world, x, y)
        elseif newType == BaseBall.TYPES.BULLET then
            newBall = BulletBall.new(world, x, y)
        elseif newType == BaseBall.TYPES.ICE_BALL then
            newBall = IceBall.new(world, x, y)
        elseif newType == BaseBall.TYPES.WATER_BALL then
            newBall = WaterBall.new(world, x, y)
        else
            newBall = StandardBall.new(world, x, y)
        end
        
        -- Set the same position and velocity
        newBall.body:setPosition(x, y)
        newBall.body:setLinearVelocity(vx, vy)
        newBall.body:setAngle(angle)
        newBall.body:setAngularVelocity(av)
        newBall.isLaunched = isLaunched
        
        -- Copy environment state
        newBall.inWater = ball.inWater
        newBall.waterCells = ball.waterCells
        newBall.inSand = ball.inSand
        newBall.sandCells = ball.sandCells
        
        return newBall
    end
}

return Balls
