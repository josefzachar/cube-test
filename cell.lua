-- cell.lua - Cell implementation (SAND and STONE) with cellular automata behavior

local CellTypes = require("src.cell_types")

local Cell = {}
Cell.__index = Cell

-- Import cell types and properties from CellTypes module
Cell.TYPES = CellTypes.TYPES
Cell.SIZE = CellTypes.SIZE
local COLORS = CellTypes.COLORS

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
    
    -- Create physics bodies for stone and sand cells
    if self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.SAND then
        self:createPhysics(world)
    end
    
    return self
end

function Cell:createPhysics(world)
    -- Create physics body based on cell type
    if self.type == Cell.TYPES.STONE then
        -- Stone cells are static (immovable)
        self.body = love.physics.newBody(world, self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, "static")
        self.shape = love.physics.newRectangleShape(Cell.SIZE, Cell.SIZE)
        self.fixture = love.physics.newFixture(self.body, self.shape)
        
        -- Set user data
        self.fixture:setUserData("stone")
    end
    
    -- Sand cells now also get physics bodies to interact with the ball
    if self.type == Cell.TYPES.SAND then
        -- Sand cells are static but can be displaced
        self.body = love.physics.newBody(world, self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, "static")
        self.shape = love.physics.newRectangleShape(Cell.SIZE, Cell.SIZE)
        self.fixture = love.physics.newFixture(self.body, self.shape)
        self.fixture:setUserData("sand")
        
        -- Make sand less solid than stone
        self.fixture:setFriction(0.3)
        self.fixture:setRestitution(0.2)
    end
end

function Cell:draw(debug)
    if self.type == Cell.TYPES.EMPTY then
        -- Only draw empty cells in debug mode
        if debug then
            love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
            love.graphics.rectangle("line", self.x * Cell.SIZE, self.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        end
        return
    end
    
    if self.type == Cell.TYPES.VISUAL_SAND then
        -- Draw visual sand at its actual position with alpha for fade out
        local color = COLORS[self.type]
        love.graphics.setColor(color[1], color[2], color[3], self.alpha)
        love.graphics.rectangle("fill", self.visualX, self.visualY, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info for visual sand
        if debug then
            love.graphics.setColor(1, 0, 0, self.alpha)
            love.graphics.rectangle("line", self.visualX, self.visualY, Cell.SIZE, Cell.SIZE)
        end
    else
        -- Draw regular cells
        love.graphics.setColor(COLORS[self.type])
        love.graphics.rectangle("fill", self.x * Cell.SIZE, self.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw cell type indicators only in debug mode
        if debug then
            if self.type == Cell.TYPES.SAND then
                love.graphics.setColor(0, 0, 1, 1) -- Blue
                love.graphics.circle("fill", self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, 2)
            elseif self.type == Cell.TYPES.STONE then
                love.graphics.setColor(1, 0, 0, 1) -- Red
                love.graphics.circle("fill", self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, 2)
            end
        end
        
        -- Draw cell coordinates in debug mode
        if debug then
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.rectangle("line", self.x * Cell.SIZE, self.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            
            -- Draw coordinates in tiny font
            love.graphics.setColor(1, 1, 1, 0.7)
            local coordText = self.x .. "," .. self.y
            love.graphics.print(coordText, self.x * Cell.SIZE + 1, self.y * Cell.SIZE + 1, 0, 0.4, 0.4)
        end
    end
end

-- Cache for faster lookups
local EMPTY = CellTypes.TYPES.EMPTY
local SAND = CellTypes.TYPES.SAND
local STONE = CellTypes.TYPES.STONE
local VISUAL_SAND = CellTypes.TYPES.VISUAL_SAND

function Cell:update(dt, level)
    local cellType = self.type
    
    -- Fast return for static cells
    if cellType == EMPTY or cellType == STONE then
        return false -- No update needed for empty or stone cells
    end
    
    -- Handle visual flying sand
    if cellType == VISUAL_SAND then
        -- Update position based on velocity (optimize: combine operations)
        self.visualX = self.visualX + self.velocityX * dt
        self.visualY = self.visualY + self.velocityY * dt
        self.velocityY = self.velocityY + 500 * dt  -- Gravity
        
        -- Update lifetime and alpha
        self.lifetime = self.lifetime + dt
        self.alpha = math.max(0, 1 - (self.lifetime / self.maxLifetime))
        
        -- Check if the visual sand should disappear (optimize: combine conditions)
        if self.lifetime >= self.maxLifetime or
           self.visualX < 0 or self.visualX >= level.width * Cell.SIZE or 
           self.visualY < 0 or self.visualY >= level.height * Cell.SIZE then
            -- Remove the visual sand
            level:setCellType(self.x, self.y, EMPTY)
            return true -- Cell changed
        end
        
        return true -- Visual sand always changes (moves)
    
    -- Handle regular sand (cellular automata)
    elseif cellType == SAND then
        -- Optimize: Cache level properties
        local levelHeight = level.height
        local levelWidth = level.width
        local x, y = self.x, self.y
        
        -- Optimize: Early return if at bottom of level
        if y >= levelHeight - 1 then
            return false
        end
        
        -- IMPORTANT: Mark cells below as active to ensure continuous falling
        -- This is critical to prevent horizontal lines
        if y < levelHeight - 2 then
            -- Mark the cell two rows below as active to ensure continuous falling
            table.insert(level.activeCells, {x = x, y = y + 2})
        end
        
        -- Optimize: Get cell types once
        local belowType = level:getCellType(x, y + 1)
        
        -- Check if there's empty space below
        if belowType == EMPTY then
            -- Fall straight down
            level:setCellType(x, y, EMPTY)
            level:setCellType(x, y + 1, SAND)
            
            -- Mark cells as active for next frame (optimize: use local variables)
            local activeCells = level.activeCells
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x, y = y + 1})
            
            -- IMPORTANT: Mark cells below as active to ensure continuous falling
            if y < levelHeight - 2 then
                table.insert(activeCells, {x = x, y = y + 2})
            end
            
            return true -- Cell changed
        end
        
        -- Optimize: Only check diagonals if we can't fall straight down
        -- Check if we're at the edges
        local canCheckLeft = x > 0
        local canCheckRight = x < levelWidth - 1
        
        -- Only get diagonal cell types if we need them
        local leftEmpty = canCheckLeft and level:getCellType(x - 1, y + 1) == EMPTY
        local rightEmpty = canCheckRight and level:getCellType(x + 1, y + 1) == EMPTY
        
        -- Optimize: Use local variables for activeCells
        local activeCells = level.activeCells
        
        if leftEmpty and rightEmpty then
            -- Both diagonal spaces are empty, choose randomly
            -- Use true random instead of deterministic pattern to avoid visual artifacts
            if math.random() < 0.5 then
                -- Fall diagonally left
                level:setCellType(x, y, EMPTY)
                level:setCellType(x - 1, y + 1, SAND)
                
                -- Mark cells as active for next frame
                table.insert(activeCells, {x = x, y = y})
                table.insert(activeCells, {x = x - 1, y = y + 1})
                
                -- IMPORTANT: Mark cells below as active to ensure continuous falling
                if y < levelHeight - 2 then
                    table.insert(activeCells, {x = x - 1, y = y + 2})
                end
            else
                -- Fall diagonally right
                level:setCellType(x, y, EMPTY)
                level:setCellType(x + 1, y + 1, SAND)
                
                -- Mark cells as active for next frame
                table.insert(activeCells, {x = x, y = y})
                table.insert(activeCells, {x = x + 1, y = y + 1})
                
                -- IMPORTANT: Mark cells below as active to ensure continuous falling
                if y < levelHeight - 2 then
                    table.insert(activeCells, {x = x + 1, y = y + 2})
                end
            end
            
            return true -- Cell changed
        elseif leftEmpty then
            -- Fall diagonally left
            level:setCellType(x, y, EMPTY)
            level:setCellType(x - 1, y + 1, SAND)
            
            -- Mark cells as active for next frame
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x - 1, y = y + 1})
            
            -- IMPORTANT: Mark cells below as active to ensure continuous falling
            if y < levelHeight - 2 then
                table.insert(activeCells, {x = x - 1, y = y + 2})
            end
            
            return true -- Cell changed
        elseif rightEmpty then
            -- Fall diagonally right
            level:setCellType(x, y, EMPTY)
            level:setCellType(x + 1, y + 1, SAND)
            
            -- Mark cells as active for next frame
            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x + 1, y = y + 1})
            
            -- IMPORTANT: Mark cells below as active to ensure continuous falling
            if y < levelHeight - 2 then
                table.insert(activeCells, {x = x + 1, y = y + 2})
            end
            
            return true -- Cell changed
        end
    end
    
    return false -- Cell didn't change
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
    if self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.SAND then
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
