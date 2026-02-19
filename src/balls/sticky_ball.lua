-- sticky_ball.lua - Sticky ball implementation

local BaseBall = require("src.balls.ball_base")
local CellTypes = require("src.cell_types")

local StickyBall = {}
StickyBall.__index = StickyBall
setmetatable(StickyBall, BaseBall) -- Inherit from BaseBall

-- Constructor
function StickyBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.STICKY)
    
    -- Override physics properties for sticky ball - similar to standard ball in the air
    self.fixture:destroy() -- Remove default fixture
    self.fixture = love.physics.newFixture(self.body, self.shape, 1)
    self.fixture:setRestitution(0.0) -- No bounce when it hits something
    self.fixture:setFriction(10.0) -- Extremely high friction to stick to surfaces
    self.fixture:setUserData("ball")
    
    -- No linear damping while in the air - behaves like standard ball
    self.body:setLinearDamping(0.0)
    
    -- Flag to track if we've made contact with any cells
    self.hasContactedCell = false
    
    -- Add sticky ball specific properties
    self.stuck = false -- Track if the ball is stuck
    
    -- Add properties for carrying sand
    self.attachedSandCells = {} -- Table to store attached sand cells
    self.maxAttachedSand = 5 -- Maximum number of sand cells that can be attached
    
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
    
    -- Draw attached sand cells
    if #self.attachedSandCells > 0 then
        love.graphics.setColor(0.9, 0.8, 0.5, 1) -- Sand color
        for i, sandCell in ipairs(self.attachedSandCells) do
            -- Calculate position relative to ball center
            local offsetX = math.cos(i * math.pi * 0.5) * 12
            local offsetY = math.sin(i * math.pi * 0.5) * 12
            love.graphics.rectangle("fill", offsetX - 5, offsetY - 5, 10, 10)
        end
    end
end

function StickyBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(BaseBall.COLORS.STICKY_COLOR)
    love.graphics.print("Sticky Ball", x + 15, y + yOffset)
end

function StickyBall:update(dt)
    -- Handle sticky ball special case
    -- Skip the stuck-freeze when the win animation is running — BaseBall.update owns movement then
    if self.stuck and not self.hasWon then
        -- If the sticky ball is stuck, force it to stop completely
        self.body:setLinearVelocity(0, 0)
        self.body:setAngularVelocity(0)
        return true -- Ball is stationary
    end
    
    -- Call parent update method
    local stopped = BaseBall.update(self, dt)
    
    -- Check if the ball should become stuck
    -- Only stick if the ball doesn't have attached sand cells
    local vx, vy = self.body:getLinearVelocity()
    local speed = math.sqrt(vx*vx + vy*vy)
    
    if speed < 20 and not self.stuck and #self.attachedSandCells == 0 then
        self.stuck = true
    end
    
    -- We'll handle dropping sand cells in the enterWater method
    
    return stopped
end

-- New method to attach a sand cell to the sticky ball
function StickyBall:attachSandCell(x, y, level)
    -- Check if we've reached the maximum number of attached sand cells
    if #self.attachedSandCells >= self.maxAttachedSand then
        return false
    end
    
    -- Check if the cell is actually a sand cell
    if level:getCellType(x, y) ~= CellTypes.TYPES.SAND then
        return false
    end
    
    -- Add the sand cell to our attached cells
    table.insert(self.attachedSandCells, {x = x, y = y})
    
    -- Remove the sand cell from the level
    level:setCellType(x, y, CellTypes.TYPES.EMPTY)
    
    return true
end

-- Method to drop all attached sand cells
function StickyBall:dropAttachedSandCells(level)
    local ballX, ballY = self.body:getPosition()
    local gridX, gridY = level:getGridCoordinates(ballX, ballY)
    
    -- Drop sand cells around the ball
    for i, sandCell in ipairs(self.attachedSandCells) do
        -- Calculate position to drop the sand (in a circle around the ball)
        local angle = (i / #self.attachedSandCells) * math.pi * 2
        local dropX = math.floor(gridX + math.cos(angle))
        local dropY = math.floor(gridY + math.sin(angle))
        
        -- Make sure the drop position is within bounds
        if dropX >= 0 and dropX < level.width and dropY >= 0 and dropY < level.height then
            -- Only place sand if the cell is empty
            if level:getCellType(dropX, dropY) == CellTypes.TYPES.EMPTY then
                level:setCellType(dropX, dropY, CellTypes.TYPES.SAND)
            end
        end
    end
    
    -- Clear the attached sand cells
    self.attachedSandCells = {}
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
    
    -- Don't clear attached sand cells when shot
    -- They will only be dropped when the ball is in water
    
    -- Call parent method
    BaseBall.shoot(self, direction, power)
end

function StickyBall:reset(x, y)
    -- Reset stuck state
    self.stuck = false
    
    -- Clear attached sand cells
    self.attachedSandCells = {}
    
    -- Call parent method
    BaseBall.reset(self, x, y)
end

-- Override enterWater to check if we should drop sand cells
function StickyBall:enterWater(cellX, cellY)
    -- Call parent method first
    BaseBall.enterWater(self, cellX, cellY)
    
    -- Check if we have attached sand cells
    if #self.attachedSandCells > 0 then
        -- Clear the attached sand cells without trying to drop them
        -- This simulates the sand dissolving in water
        self.attachedSandCells = {}
    end
end

return StickyBall
