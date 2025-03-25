-- cell.lua - Cell implementation with cellular automata behavior

local CellTypes = require("src.cell_types")
local Sand = require("src.sand")
local Water = require("src.water")
local Stone = require("src.stone")
local Dirt = require("dirt") -- Use dirt.lua from root directory

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
    
    -- Create physics bodies for stone, sand, water, and dirt cells
    if self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.SAND or self.type == Cell.TYPES.WATER or self.type == Cell.TYPES.DIRT then
        self:createPhysics(world)
    end
    
    return self
end

function Cell:createPhysics(world)
    -- Create physics body based on cell type
    if self.type == Cell.TYPES.STONE then
        Stone.createPhysics(self, world)
    elseif self.type == Cell.TYPES.SAND then
        Sand.createPhysics(self, world)
    elseif self.type == Cell.TYPES.WATER then
        Water.createPhysics(self, world)
    elseif self.type == Cell.TYPES.DIRT then
        Dirt.createPhysics(self, world)
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
    
    if self.type == Cell.TYPES.VISUAL_SAND or self.type == Cell.TYPES.VISUAL_DIRT then
        -- Draw visual particles at their actual position with alpha for fade out
        local color = COLORS[self.type]
        love.graphics.setColor(color[1], color[2], color[3], self.alpha)
        love.graphics.rectangle("fill", self.visualX, self.visualY, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info for visual particles
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
            elseif self.type == Cell.TYPES.WATER then
                love.graphics.setColor(0, 1, 1, 1) -- Cyan
                love.graphics.circle("fill", self.x * Cell.SIZE + Cell.SIZE/2, self.y * Cell.SIZE + Cell.SIZE/2, 2)
            elseif self.type == Cell.TYPES.DIRT then
                love.graphics.setColor(0.8, 0.4, 0, 1) -- Orange
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
local VISUAL_DIRT = CellTypes.TYPES.VISUAL_DIRT
local WATER = CellTypes.TYPES.WATER
local DIRT = CellTypes.TYPES.DIRT

function Cell:update(dt, level)
    local cellType = self.type
    
    -- Fast return for static cells (dirt is static but can displace water)
    if cellType == EMPTY or cellType == STONE then
        return false -- No update needed for empty or stone cells
    end
    
    -- Handle dirt
    if cellType == DIRT then
        return Dirt.update(self, dt, level)
    end
    
    -- Handle water
    if cellType == WATER then
        return Water.update(self, dt, level)
    end
    
    -- Handle visual flying sand and dirt
    if cellType == VISUAL_SAND then
        return Sand.updateVisual(self, dt, level)
    elseif cellType == VISUAL_DIRT then
        -- Use the same visual update logic as sand for dirt
        return Sand.updateVisual(self, dt, level)
    
    -- Handle regular sand (cellular automata)
    elseif cellType == SAND then
        return Sand.update(self, dt, level)
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
    if self.type == Cell.TYPES.STONE or self.type == Cell.TYPES.SAND or self.type == Cell.TYPES.WATER or self.type == Cell.TYPES.DIRT then
        self:createPhysics(world)
    end
    
    -- Initialize visual particle properties
    if self.type == Cell.TYPES.VISUAL_SAND or self.type == Cell.TYPES.VISUAL_DIRT then
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
    
    -- Use the Sand module to convert to visual sand
    Sand.convertToVisual(self, velocityX, velocityY)
    
    print("    SUCCESS: Cell converted to visual sand with velocity", velocityX, velocityY)
end

return Cell
