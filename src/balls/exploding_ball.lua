-- exploding_ball.lua - Exploding ball implementation

local BaseBall = require("src.balls.ball_base")
local CellTypes = require("src.cell_types")
local Fire = require("src.fire")

local ExplodingBall = {}
ExplodingBall.__index = ExplodingBall
setmetatable(ExplodingBall, BaseBall) -- Inherit from BaseBall

-- Constructor
function ExplodingBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.EXPLODING)
    
    -- Override physics properties for exploding ball
    self.fixture:destroy() -- Remove default fixture
    self.fixture = love.physics.newFixture(self.body, self.shape, 2)
    self.fixture:setRestitution(0.3)
    self.fixture:setFriction(0.5)
    self.fixture:setUserData("ball")
    
    -- Add exploding ball specific properties
    self.exploded = false -- Track if the ball has exploded
    
    return setmetatable(self, ExplodingBall)
end

-- Override methods to provide exploding ball behavior
function ExplodingBall:getColor()
    return BaseBall.COLORS.EXPLODING_COLOR
end

function ExplodingBall:drawSpecialIndicator()
    -- Draw an X symbol
    love.graphics.setColor(0.9, 0.1, 0.1, 1)
    love.graphics.line(-5, -5, 5, 5)
    love.graphics.line(-5, 5, 5, -5)
end

function ExplodingBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(BaseBall.COLORS.EXPLODING_COLOR)
    love.graphics.print("Exploding Ball", x + 15, y + yOffset)
end

function ExplodingBall:getPowerMultiplier()
    return 1.2 -- Slightly more power
end

function ExplodingBall:shoot(direction, power)
    -- Reset explosion state when shot
    self.exploded = false
    
    -- Call parent method
    BaseBall.shoot(self, direction, power)
end

function ExplodingBall:reset(x, y)
    -- Reset explosion state
    self.exploded = false
    
    -- Call parent method
    BaseBall.reset(self, x, y)
end

-- Handle explosion for exploding ball
function ExplodingBall:explode(level, sandToConvert)
    if self.exploded then
        return false -- Already exploded
    end
    
    -- Mark as exploded
    self.exploded = true
    
    -- Get ball position
    local x, y = self.body:getPosition()
    local gridX, gridY = level:getGridCoordinates(x, y)
    
    -- Explosion radius
    local explosionRadius = 12 -- Much larger radius for more dramatic effect
    
    -- Create fire explosion at the ball's position
    Fire.createExplosion(level, gridX, gridY, explosionRadius)
    
    -- Create additional fire at the center of the explosion
    for dy = -2, 2 do
        for dx = -2, 2 do
            local centerX = gridX + dx
            local centerY = gridY + dy
            
            -- Calculate distance from center
            local distance = math.sqrt(dx*dx + dy*dy)
            
            -- Only affect cells within the center radius
            if distance <= 2 and
               centerX >= 0 and centerX < level.width and 
               centerY >= 0 and centerY < level.height then
                
                -- Create fire at the center
                Fire.createFire(level, centerX, centerY)
            end
        end
    end
    
    -- Create explosion effect with particles
    for dy = -explosionRadius, explosionRadius do
        for dx = -explosionRadius, explosionRadius do
            local checkX = gridX + dx
            local checkY = gridY + dy
            
            -- Calculate distance from center
            local distance = math.sqrt(dx*dx + dy*dy)
            
            -- Only affect cells within the explosion radius
            if distance <= explosionRadius and
               checkX >= 0 and checkX < level.width and 
               checkY >= 0 and checkY < level.height then
                
                -- Get the cell type
                local cellType = level:getCellType(checkX, checkY)
                
                -- Only affect certain cell types (not empty, fire, smoke, or water)
                if cellType ~= CellTypes.TYPES.EMPTY and 
                   cellType ~= CellTypes.TYPES.WATER and
                   cellType ~= CellTypes.TYPES.FIRE and
                   cellType ~= CellTypes.TYPES.SMOKE then
                    
                    -- Direction away from explosion center
                    local dirX = dx
                    local dirY = dy
                    if dx == 0 and dy == 0 then
                        dirX, dirY = 0, -1 -- Default upward
                    else
                        local dirLen = math.sqrt(dirX*dirX + dirY*dirY)
                        dirX = dirX / dirLen
                        dirY = dirY / dirLen
                    end
                    
                    -- Calculate velocity based on distance from center
                    local impactFactor = (1 - distance/explosionRadius)
                    local flyVx = dirX * 700 * impactFactor -- Increased velocity
                    local flyVy = dirY * 700 * impactFactor - 300 -- Extra upward boost
                    
                    -- Add randomness
                    flyVx = flyVx + math.random(-100, 100)
                    flyVy = flyVy + math.random(-100, 100)
                    
                    -- Clear the cell
                    level:setCellType(checkX, checkY, CellTypes.TYPES.EMPTY)
                    
                    -- Queue up for conversion to visual particles
                    table.insert(sandToConvert, {
                        x = checkX,
                        y = checkY,
                        vx = flyVx,
                        vy = flyVy,
                        originalType = cellType,
                        shouldConvert = true
                    })
                end
            end
        end
    end
    
    -- Switch to standard ball after explosion
    -- We'll return a special value to indicate that the ball should be switched
    return "switch_to_standard"
end

return ExplodingBall
