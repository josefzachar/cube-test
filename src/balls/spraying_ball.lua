-- spraying_ball.lua - Spraying ball implementation

local BaseBall = require("src.balls.ball_base")
local CellTypes = require("src.cell_types")
local Cell = require("cell")

local SprayingBall = {}
SprayingBall.__index = SprayingBall
setmetatable(SprayingBall, BaseBall) -- Inherit from BaseBall

-- Available material types for spraying
SprayingBall.MATERIALS = {
    CellTypes.TYPES.SAND,
    CellTypes.TYPES.WATER,
    CellTypes.TYPES.DIRT,
    CellTypes.TYPES.STONE,
    CellTypes.TYPES.FIRE
}

-- Material names for display
SprayingBall.MATERIAL_NAMES = {
    [CellTypes.TYPES.SAND] = "SAND",
    [CellTypes.TYPES.WATER] = "WATER",
    [CellTypes.TYPES.DIRT] = "DIRT",
    [CellTypes.TYPES.STONE] = "STONE",
    [CellTypes.TYPES.FIRE] = "FIRE"
}

-- Special mode for random material selection
SprayingBall.RANDOM_MODE = "RANDOM"

-- Override methods to provide spraying ball behavior
function SprayingBall:getColor()
    -- Base color is yellow-orange
    local baseColor = {0.9, 0.8, 0.3, 1}
    
    -- If we have a current material, tint the color based on the material
    if self.currentMaterial and CellTypes.COLORS[self.currentMaterial] then
        local materialColor = CellTypes.COLORS[self.currentMaterial]
        -- Mix the base color with the material color
        return {
            baseColor[1] * 0.7 + materialColor[1] * 0.3,
            baseColor[2] * 0.7 + materialColor[2] * 0.3,
            baseColor[3] * 0.7 + materialColor[3] * 0.3,
            baseColor[4]
        }
    end
    
    return baseColor
end

function SprayingBall:drawSpecialIndicator()
    -- Draw a spray symbol (three dots in a row)
    love.graphics.setColor(0.9, 0.7, 0.2, 1)
    love.graphics.circle("fill", -5, 0, 2)
    love.graphics.circle("fill", 0, 0, 2)
    love.graphics.circle("fill", 5, 0, 2)
    
    -- Draw a small indicator of the current material
    if self.currentMaterial and CellTypes.COLORS[self.currentMaterial] then
        love.graphics.setColor(CellTypes.COLORS[self.currentMaterial])
        love.graphics.rectangle("fill", -4, 4, 8, 3)
    elseif self.materialMode == SprayingBall.RANDOM_MODE then
        -- Draw a rainbow indicator for random mode
        love.graphics.setColor(1, 0, 0, 1) -- Red
        love.graphics.rectangle("fill", -6, 4, 2, 3)
        love.graphics.setColor(1, 1, 0, 1) -- Yellow
        love.graphics.rectangle("fill", -4, 4, 2, 3)
        love.graphics.setColor(0, 1, 0, 1) -- Green
        love.graphics.rectangle("fill", -2, 4, 2, 3)
        love.graphics.setColor(0, 0, 1, 1) -- Blue
        love.graphics.rectangle("fill", 0, 4, 2, 3)
        love.graphics.setColor(0.5, 0, 1, 1) -- Purple
        love.graphics.rectangle("fill", 2, 4, 2, 3)
        love.graphics.setColor(1, 0.5, 0, 1) -- Orange
        love.graphics.rectangle("fill", 4, 4, 2, 3)
    end
end

function SprayingBall:drawDebugInfo(x, y, yOffset)
    love.graphics.setColor(0.9, 0.8, 0.3, 1)
    
    local materialText = ""
    if self.materialMode == SprayingBall.RANDOM_MODE then
        materialText = " (RANDOM)"
    elseif self.currentMaterial and SprayingBall.MATERIAL_NAMES[self.currentMaterial] then
        materialText = " (" .. SprayingBall.MATERIAL_NAMES[self.currentMaterial] .. ")"
    end
    
    love.graphics.print("Spraying Ball" .. materialText, x + 15, y + yOffset)
end

-- Cycle to the next material type
function SprayingBall:cycleMaterial()
    if self.materialMode == SprayingBall.RANDOM_MODE then
        -- If in random mode, switch to the first material
        self.materialMode = nil
        self.currentMaterialIndex = 1
        self.currentMaterial = SprayingBall.MATERIALS[self.currentMaterialIndex]
    else
        -- Cycle to the next material, or to random mode if at the end
        self.currentMaterialIndex = self.currentMaterialIndex + 1
        if self.currentMaterialIndex > #SprayingBall.MATERIALS then
            -- Switch to random mode
            self.materialMode = SprayingBall.RANDOM_MODE
            self.currentMaterialIndex = nil
            self.currentMaterial = nil
        else
            self.currentMaterial = SprayingBall.MATERIALS[self.currentMaterialIndex]
        end
    end
    
    print("Switched to " .. (self.materialMode or SprayingBall.MATERIAL_NAMES[self.currentMaterial]) .. " spraying mode")
end

-- Select a random material
function SprayingBall:selectRandomMaterial()
    local randomIndex = math.random(1, #SprayingBall.MATERIALS)
    return SprayingBall.MATERIALS[randomIndex]
end

-- Override update method to add spraying functionality
function SprayingBall:update(dt)
    -- Call parent update method first
    local isStopped = BaseBall.update(self, dt)
    
    -- If the ball was moving but is now stopped, and we're in random mode, select a new random material
    if isStopped and self.isLaunched and self.materialMode == SprayingBall.RANDOM_MODE then
        -- Only select a new material if the ball was previously moving (isLaunched is true)
        -- and has now stopped
        self.currentMaterial = self:selectRandomMaterial()
        print("Ball stopped, new random material selected: " .. SprayingBall.MATERIAL_NAMES[self.currentMaterial])
        
        -- Reset isLaunched flag so we don't keep selecting new materials while stopped
        self.isLaunched = false
    end
    
    -- Only spray when the ball is moving
    if not isStopped and self.isLaunched then
        -- Get ball velocity
        local vx, vy = self.body:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        
        -- Only spray if the ball is moving fast enough
        if speed > 50 then
            -- Update spray timer
            self.sprayTimer = self.sprayTimer + dt
            
            -- Spray sand at regular intervals
            if self.sprayTimer >= self.sprayInterval then
                self.sprayTimer = 0
                
                -- Calculate spray direction (opposite to movement direction)
                local dirX = -vx / speed
                local dirY = -vy / speed
                
                -- Get ball position
                local ballX, ballY = self.body:getPosition()
                
                -- Get the level from the game
                local Game = require("src.game")
                local level = Game.level
                
                -- Get grid coordinates
                local gridX, gridY = level:getGridCoordinates(ballX, ballY)
                
                -- Spray sand particles
                self:spraySand(gridX, gridY, dirX, dirY, speed)
            end
        end
    end
    
    return isStopped
end

-- Spray material particles in the specified direction
function SprayingBall:spraySand(gridX, gridY, dirX, dirY, speed)
    -- Get the level from the game
    local Game = require("src.game")
    local level = Game.level
    if not level then return end
    
    -- Use the current material (which is already selected for the entire flight)
    local materialType = self.currentMaterial
    
    -- Spray multiple material cells
    for i = 1, self.sprayRate do
        -- Calculate spray position (slightly behind the ball in the opposite direction of movement)
        local offsetX = math.random(-self.sprayRadius, self.sprayRadius)
        local offsetY = math.random(-self.sprayRadius, self.sprayRadius)
        
        -- Add directional bias (opposite to movement)
        -- Place cells further away from the ball to avoid immediate collisions
        local sprayX = gridX + math.floor(dirX * 4) + offsetX
        local sprayY = gridY + math.floor(dirY * 4) + offsetY
        
        -- Check if the position is valid and empty
        if sprayX >= 0 and sprayX < level.width and sprayY >= 0 and sprayY < level.height then
            if level:getCellType(sprayX, sprayY) == CellTypes.TYPES.EMPTY then
                -- Special handling for fire
                if materialType == CellTypes.TYPES.FIRE then
                    -- Use the Fire module to create fire properly
                    local Fire = require("src.fire")
                    Fire.createFire(level, sprayX, sprayY)
                else
                    -- Create a normal cell of the current material type
                    level:setCellType(sprayX, sprayY, materialType)
                    
                    -- Mark cells as active for next frame to ensure proper physics
                    if level.activeCells then
                        table.insert(level.activeCells, {x = sprayX, y = sprayY})
                        
                        -- Also mark cells below as active to ensure proper physics
                        if sprayY < level.height - 1 then
                            table.insert(level.activeCells, {x = sprayX, y = sprayY + 1})
                        end
                    end
                end
            end
        end
    end
end

-- Override physics properties
function SprayingBall:getWaterDragCoefficient()
    return 0.015 -- Slightly more water drag than standard
end

function SprayingBall:getBuoyancyForce()
    return 120 -- Slightly more buoyancy than standard
end

function SprayingBall:getSandDragCoefficient()
    -- Much less sand drag to prevent the ball from being slowed down by sand
    return 0.005 -- Significantly reduced from standard (0.03)
end

function SprayingBall:getStoppedThreshold()
    return 5 -- Same as standard
end

function SprayingBall:getPowerMultiplier()
    return 1.2 -- More power than standard (was 1.1)
end

function SprayingBall:getAngularMultiplier()
    return 70 -- More angular impulse than standard (was 60)
end

-- Constructor (modified to override physics properties)
function SprayingBall.new(world, x, y)
    local self = BaseBall.new(world, x, y, BaseBall.TYPES.SPRAYING)
    
    -- Add spraying ball specific properties
    self.sprayTimer = 0
    self.sprayInterval = 0.03 -- Spray more frequently (was 0.05)
    self.sprayRadius = 2 -- Increased radius of spray (was 1)
    self.sprayRate = 5 -- Increased number of particles per spray (was 3)
    
    -- Initialize material properties
    self.currentMaterialIndex = 1 -- Start with first material (SAND)
    self.currentMaterial = SprayingBall.MATERIALS[self.currentMaterialIndex]
    self.materialMode = nil -- Not in random mode initially
    
    -- Override physics properties for spraying ball
    self.fixture:destroy() -- Remove default fixture
    self.fixture = love.physics.newFixture(self.body, self.shape, 1.5) -- Lower density (was 2)
    self.fixture:setRestitution(0.4) -- Higher restitution (was 0.3)
    self.fixture:setFriction(0.3) -- Lower friction (was 0.5)
    self.fixture:setUserData("ball")
    
    return setmetatable(self, SprayingBall)
end

-- Override shoot method to handle random material selection on shoot
function SprayingBall:shoot(direction, power)
    -- If in random mode, select a random material for this shot
    if self.materialMode == SprayingBall.RANDOM_MODE then
        self.currentMaterial = self:selectRandomMaterial()
        print("Random material selected: " .. SprayingBall.MATERIAL_NAMES[self.currentMaterial])
    end
    
    -- Call parent method
    BaseBall.shoot(self, direction, power)
end

return SprayingBall
