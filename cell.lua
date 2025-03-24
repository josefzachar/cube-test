-- cell.lua - Cell implementation (SAND and STONE) with cellular automata behavior

local Cell = {}
Cell.__index = Cell

-- Cell types
Cell.TYPES = {
    EMPTY = 0,
    SAND = 1,
    STONE = 2,
    FLYING_SAND = 3,  -- New type for sand that's been hit and is in the air
    TEMP_STONE = 4    -- Temporary stone that looks like sand
}

-- Cell states
Cell.STATES = {
    STATIC = 0,      -- Normal cellular automata behavior
    PHYSICS = 1      -- Controlled by physics engine
}

-- Colors
local COLORS = {
    [Cell.TYPES.EMPTY] = {0, 0, 0, 0}, -- Transparent
    [Cell.TYPES.SAND] = {0.9, 0.8, 0.5, 1}, -- Sand color
    [Cell.TYPES.STONE] = {0.5, 0.5, 0.5, 1}, -- Stone color
    [Cell.TYPES.FLYING_SAND] = {1.0, 0.9, 0.6, 1}, -- Brighter sand for flying sand
    [Cell.TYPES.TEMP_STONE] = {0.9, 0.8, 0.5, 1}  -- Same as sand color
}

-- Cell size (half the size of the ball)
Cell.SIZE = 10

function Cell.new(world, x, y, type)
    local self = setmetatable({}, Cell)
    
    self.x = x
    self.y = y
    self.type = type or Cell.TYPES.EMPTY
    self.state = Cell.STATES.STATIC
    self.body = nil
    self.shape = nil
    self.fixture = nil
    self.velocityY = 0  -- For cellular automata falling
    self.velocityX = 0  -- For cellular automata horizontal movement
    self.settled = true -- Whether the sand has settled
    self.airTime = 0    -- Time the sand has been in the air
    
    -- Create physics bodies for stone cells only
    if self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.TEMP_STONE then
        self:createPhysics(world)
    end
    
    return self
end

function Cell:createPhysics(world)
    -- Create physics body based on cell type
    if self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.TEMP_STONE then
        -- Stone cells are static (immovable)
        self.body = love.physics.newBody(world, self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, "static")
        self.shape = love.physics.newRectangleShape(Cell.SIZE, Cell.SIZE)
        self.fixture = love.physics.newFixture(self.body, self.shape)
        
        -- Set user data based on type
        if self.type == Cell.TYPES.STONE then
            self.fixture:setUserData("stone")
        else
            self.fixture:setUserData("temp_stone")
        end
    elseif self.type == Cell.TYPES.FLYING_SAND then
        -- Flying sand cells use dynamic physics
        self.body = love.physics.newBody(world, self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, "dynamic")
        self.shape = love.physics.newRectangleShape(Cell.SIZE, Cell.SIZE)
        self.fixture = love.physics.newFixture(self.body, self.shape, 0.5) -- Lower density for sand
        self.fixture:setFriction(0.8) -- High friction for sand
        self.fixture:setRestitution(0.1) -- Low bounciness
        self.fixture:setUserData("flying_sand")
        self.state = Cell.STATES.PHYSICS
    end
end

function Cell:draw()
    if self.type == Cell.TYPES.EMPTY then
        return -- Don't draw empty cells
    end
    
    love.graphics.setColor(COLORS[self.type])
    
    if self.body and self.state == Cell.STATES.PHYSICS then
        -- Draw physics-based cells
        love.graphics.push()
        love.graphics.translate(self.body:getX(), self.body:getY())
        -- No rotation for sand cells
        love.graphics.rectangle("fill", -Cell.SIZE/2, -Cell.SIZE/2, Cell.SIZE, Cell.SIZE)
        
        -- Draw a red dot in the center to indicate this cell has a physics body
        love.graphics.setColor(1, 0, 0, 1) -- Red
        love.graphics.circle("fill", 0, 0, 2) -- Small circle in the center
        
        love.graphics.pop()
    else
        -- Draw cellular automata cells
        love.graphics.rectangle("fill", self.x * Cell.SIZE, self.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw a small indicator in the center for different cell types
        if self.type == Cell.TYPES.SAND then
            love.graphics.setColor(0, 0, 1, 1) -- Blue
            love.graphics.circle("fill", self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, 2)
        elseif self.type == Cell.TYPES.STONE then
            love.graphics.setColor(1, 0, 0, 1) -- Red
            love.graphics.circle("fill", self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, 2)
        elseif self.type == Cell.TYPES.TEMP_STONE then
            love.graphics.setColor(1, 0, 1, 1) -- Magenta
            love.graphics.circle("fill", self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, 2)
        end
    end
end

function Cell:update(dt, level)
    if self.type == Cell.TYPES.EMPTY or self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.TEMP_STONE then
        return -- No update needed for empty or stone cells
    end
    
    -- Handle flying sand (physics-based)
    if self.type == Cell.TYPES.FLYING_SAND then
        -- Create physics body if it doesn't exist yet
        if not self.body then
            self:createPhysics(level.world)
            
            -- Apply initial velocity if set
            if self.body and (self.velocityX ~= 0 or self.velocityY ~= 0) then
                self.body:setLinearVelocity(self.velocityX, self.velocityY)
                self.velocityX = 0
                self.velocityY = 0
            end
            
            -- If we still don't have a body, convert back to regular sand
            if not self.body then
                self.type = Cell.TYPES.SAND
                self.state = Cell.STATES.STATIC
                return
            end
        end
        
        -- Get position from physics body
        local bodyX, bodyY = self.body:getPosition()
        
        -- Check if the position is valid
        if bodyX < 0 or bodyX >= level.width * Cell.SIZE or bodyY < 0 or bodyY >= level.height * Cell.SIZE then
            -- Out of bounds, destroy the cell
            self:destroy(level.world)
            level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
            return
        end
        
        -- Get grid coordinates
        local newX = math.floor(bodyX / Cell.SIZE)
        local newY = math.floor(bodyY / Cell.SIZE)
        
        -- Check if the cell has moved to a new grid position
        if newX ~= self.x or newY ~= self.y then
            -- Check if the new position is valid
            if newX >= 0 and newX < level.width and newY >= 0 and newY < level.height then
                -- Check if the new position is empty
                if level:getCellType(newX, newY) == Cell.TYPES.EMPTY then
                    -- Move to new grid position
                    level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
                    self.x = newX
                    self.y = newY
                    level:setCellType(newX, newY, Cell.TYPES.FLYING_SAND)
                    
                    -- Check if the cell has settled
                    if self.body then
                        local vx, vy = self.body:getLinearVelocity()
                        local speed = math.sqrt(vx*vx + vy*vy)
                        
                        if speed < 10 and (newY == level.height - 1 or level:getCellType(newX, newY + 1) ~= Cell.TYPES.EMPTY) then
                            -- Convert back to regular sand
                            self:destroy(level.world)
                            self.type = Cell.TYPES.SAND
                            self.state = Cell.STATES.STATIC
                        end
                    end
                else
                    -- Hit another cell, convert back to regular sand
                    self:destroy(level.world)
                    self.type = Cell.TYPES.SAND
                    self.state = Cell.STATES.STATIC
                end
            else
                -- Out of bounds, destroy the cell
                self:destroy(level.world)
                level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
            end
        end
        
        -- Increment air time
        self.airTime = self.airTime + dt
        
        -- Force conversion back to regular sand after 5 seconds in the air
        if self.airTime > 5 then
            self:destroy(level.world)
            self.type = Cell.TYPES.SAND
            self.state = Cell.STATES.STATIC
            self.airTime = 0
        end
    -- Handle regular sand (cellular automata)
    elseif self.type == Cell.TYPES.SAND then
        -- Check if there's empty space below
        if self.y < level.height - 1 and level:getCellType(self.x, self.y + 1) == Cell.TYPES.EMPTY then
            -- Fall straight down
            level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
            level:setCellType(self.x, self.y + 1, Cell.TYPES.SAND)
            return
        end
        
        -- Check if there's empty space diagonally down-left or down-right
        local leftEmpty = self.x > 0 and self.y < level.height - 1 and level:getCellType(self.x - 1, self.y + 1) == Cell.TYPES.EMPTY
        local rightEmpty = self.x < level.width - 1 and self.y < level.height - 1 and level:getCellType(self.x + 1, self.y + 1) == Cell.TYPES.EMPTY
        
        if leftEmpty and rightEmpty then
            -- Both diagonal spaces are empty, choose randomly
            if math.random() < 0.5 then
                -- Fall diagonally left
                level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
                level:setCellType(self.x - 1, self.y + 1, Cell.TYPES.SAND)
            else
                -- Fall diagonally right
                level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
                level:setCellType(self.x + 1, self.y + 1, Cell.TYPES.SAND)
            end
        elseif leftEmpty then
            -- Fall diagonally left
            level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
            level:setCellType(self.x - 1, self.y + 1, Cell.TYPES.SAND)
        elseif rightEmpty then
            -- Fall diagonally right
            level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
            level:setCellType(self.x + 1, self.y + 1, Cell.TYPES.SAND)
        end
    end
end

function Cell:destroy(world)
    if self.fixture and self.body then
        self.fixture:destroy()
        self.body:destroy()
        self.fixture = nil
        self.body = nil
    end
    self.state = Cell.STATES.STATIC
end

function Cell:setType(world, newType)
    -- Change cell type
    if self.type == newType then
        return -- No change needed
    end
    
    -- Destroy old physics if exists
    self:destroy(world)
    
    -- Set new type
    self.type = newType
    
    -- Create new physics if needed
    if self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.FLYING_SAND or self.type == Cell.TYPES.TEMP_STONE then
        self:createPhysics(world)
    end
end

-- Convert a static sand cell to a flying sand cell with initial velocity
function Cell:convertToFlyingSand(world, velocityX, velocityY)
    -- Only convert static sand cells
    if self.type ~= Cell.TYPES.SAND or self.state ~= Cell.STATES.STATIC then
        print("    ERROR: Cannot convert to flying sand - not a static sand cell")
        return
    end
    
    -- Destroy existing physics body if any
    self:destroy(world)
    
    -- Change type
    self.type = Cell.TYPES.FLYING_SAND
    self.state = Cell.STATES.PHYSICS
    self.airTime = 0
    
    -- Defer physics creation to the next frame to avoid Box2D errors
    -- Just set the initial velocity for now
    self.velocityX = velocityX
    self.velocityY = velocityY
    
    print("    SUCCESS: Cell converted to flying sand with velocity", velocityX, velocityY)
end

return Cell
