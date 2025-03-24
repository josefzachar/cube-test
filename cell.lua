-- cell.lua - Cell implementation (SAND and STONE) with cellular automata behavior

local Cell = {}
Cell.__index = Cell

-- Cell types
Cell.TYPES = {
    EMPTY = 0,
    SAND = 1,
    STONE = 2,
    VISUAL_SAND = 3,  -- Visual effect for flying sand (no physics)
    TEMP_STONE = 4    -- Temporary stone that looks like sand
}

-- Colors
local COLORS = {
    [Cell.TYPES.EMPTY] = {0, 0, 0, 0}, -- Transparent
    [Cell.TYPES.SAND] = {0.9, 0.8, 0.5, 1}, -- Sand color
    [Cell.TYPES.STONE] = {0.5, 0.5, 0.5, 1}, -- Stone color
    [Cell.TYPES.VISUAL_SAND] = {1.0, 0.9, 0.6, 1}, -- Brighter sand for visual effect
    [Cell.TYPES.TEMP_STONE] = {0.9, 0.8, 0.5, 1}  -- Same as sand color
}

-- Cell size (half the size of the ball)
Cell.SIZE = 10

function Cell.new(world, x, y, type)
    local self = setmetatable({}, Cell)
    
    self.x = x
    self.y = y
    self.type = type or Cell.TYPES.EMPTY
    
    -- Visual sand properties
    self.visualX = x * Cell.SIZE  -- Actual pixel position for visual sand
    self.visualY = y * Cell.SIZE
    self.velocityX = 0
    self.velocityY = 0
    self.lifetime = 0
    self.maxLifetime = 2.0  -- Visual sand disappears after 2 seconds
    self.alpha = 1.0        -- For fade out effect
    
    -- Physics body for stone and temp_stone only
    self.body = nil
    self.shape = nil
    self.fixture = nil
    
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
    end
end

function Cell:draw()
    if self.type == Cell.TYPES.EMPTY then
        return -- Don't draw empty cells
    end
    
    if self.type == Cell.TYPES.VISUAL_SAND then
        -- Draw visual sand at its actual position with alpha for fade out
        local color = COLORS[self.type]
        love.graphics.setColor(color[1], color[2], color[3], self.alpha)
        love.graphics.rectangle("fill", self.visualX, self.visualY, Cell.SIZE, Cell.SIZE)
    else
        -- Draw regular cells
        love.graphics.setColor(COLORS[self.type])
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
    
    -- Handle visual flying sand
    if self.type == Cell.TYPES.VISUAL_SAND then
        -- Update position based on velocity
        self.visualX = self.visualX + self.velocityX * dt
        self.visualY = self.visualY + self.velocityY * dt
        
        -- Apply gravity
        self.velocityY = self.velocityY + 500 * dt  -- Gravity
        
        -- Update lifetime and alpha
        self.lifetime = self.lifetime + dt
        self.alpha = math.max(0, 1 - (self.lifetime / self.maxLifetime))
        
        -- Check if the visual sand should disappear
        if self.lifetime >= self.maxLifetime then
            -- Remove the visual sand
            level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
            return
        end
        
        -- Check if out of bounds
        if self.visualX < 0 or self.visualX >= level.width * Cell.SIZE or 
           self.visualY < 0 or self.visualY >= level.height * Cell.SIZE then
            -- Remove the visual sand
            level:setCellType(self.x, self.y, Cell.TYPES.EMPTY)
            return
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
    
    -- Create physics if needed
    if self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.TEMP_STONE then
        self:createPhysics(world)
    end
    
    -- Initialize visual sand properties
    if self.type == Cell.TYPES.VISUAL_SAND then
        self.visualX = self.x * Cell.SIZE
        self.visualY = self.y * Cell.SIZE
        self.lifetime = 0
        self.alpha = 1.0
    end
end

-- Convert a sand cell to visual flying sand with initial velocity
function Cell:convertToVisualSand(velocityX, velocityY)
    -- Only convert sand cells
    if self.type ~= Cell.TYPES.SAND then
        print("    ERROR: Cannot convert to visual sand - not a sand cell")
        return
    end
    
    -- Change type to VISUAL_SAND
    self.type = Cell.TYPES.VISUAL_SAND
    
    -- Set initial velocity
    self.velocityX = velocityX
    self.velocityY = velocityY
    
    -- Initialize visual position
    self.visualX = self.x * Cell.SIZE
    self.visualY = self.y * Cell.SIZE
    
    -- Reset lifetime
    self.lifetime = 0
    self.alpha = 1.0
    
    print("    SUCCESS: Cell converted to visual sand with velocity", velocityX, velocityY)
end

return Cell
