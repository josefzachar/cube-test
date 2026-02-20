-- water.lua - Water cell behavior and utilities

local CellTypes = require("src.cell_types")
local WATER = CellTypes.TYPES.WATER
local SPRAY_WATER = CellTypes.TYPES.SPRAY_WATER
local EMPTY = CellTypes.TYPES.EMPTY

local Water = {}

-- Add a pool of water at the specified position
function Water.createPool(level, x, y, width, height)
    -- Create a rectangular pool of water
    local startX = x - math.floor(width / 2)
    local endX = startX + width - 1
    local startY = y - math.floor(height / 2)
    local endY = startY + height - 1
    
    for py = startY, endY do
        for px = startX, endX do
            if px >= 0 and px < level.width and py >= 0 and py < level.height then
                level:setCellType(px, py, WATER)
            end
        end
    end
end

-- Create water physics for a cell
function Water.createPhysics(cell, world, skipBody)
    if skipBody then
        -- Don't create physics body for interior cells
        cell.body = nil
        cell.shape = nil
        cell.fixture = nil
        cell.hasPhysicsBody = false
        return
    end
    
    -- Water cells are static but have special properties
    cell.body = love.physics.newBody(world, cell.x * cell.SIZE + cell.SIZE/2, cell.y * cell.SIZE + cell.SIZE/2, "static")
    cell.shape = love.physics.newRectangleShape(cell.SIZE, cell.SIZE)
    cell.fixture = love.physics.newFixture(cell.body, cell.shape)
    cell.fixture:setUserData("water")
    cell.hasPhysicsBody = true
    
    -- Make water very slippery with medium restitution
    cell.fixture:setFriction(0.05)
    cell.fixture:setRestitution(0.3)
    
    -- Set sensor to true so the ball can pass through but still detect collisions
    cell.fixture:setSensor(true)
end

-- Update water cell behavior
-- Works for both WATER and SPRAY_WATER: the moved copy keeps the source type.
function Water.update(cell, dt, level)
    -- Cache level properties
    local levelHeight = level.height
    local levelWidth = level.width
    local x, y = cell.x, cell.y
    local myType = cell.type  -- preserve WATER or SPRAY_WATER when moving

    -- Early return if at bottom of level
    if y >= levelHeight - 1 then
        return false
    end

    -- Get cell types
    local belowType = level:getCellType(x, y + 1)

    -- Check if there's empty space below
    if belowType == EMPTY then
        -- Fall straight down
        level:setCellType(x, y, EMPTY)
        level:setCellType(x, y + 1, myType)

        return true -- Cell changed
    end

    -- Check if we're at the edges
    local canCheckLeft = x > 0
    local canCheckRight = x < levelWidth - 1

    -- Get diagonal cell types
    local leftEmpty = canCheckLeft and level:getCellType(x - 1, y + 1) == EMPTY
    local rightEmpty = canCheckRight and level:getCellType(x + 1, y + 1) == EMPTY

    local activeCells = level.activeCells

    -- Water flows diagonally like sand
    if leftEmpty and rightEmpty then
        -- Both diagonal spaces are empty, choose randomly
        if math.random() < 0.5 then
            level:setCellType(x, y, EMPTY)
            level:setCellType(x, y + 1, myType)
        else
            level:setCellType(x, y, EMPTY)
            level:setCellType(x + 1, y + 1, myType)
        end

        return true -- Cell changed
    elseif leftEmpty then
        level:setCellType(x, y, EMPTY)
        level:setCellType(x - 1, y + 1, myType)

        return true -- Cell changed
    elseif rightEmpty then
        level:setCellType(x, y, EMPTY)
        level:setCellType(x + 1, y + 1, myType)

        return true -- Cell changed
    end

    -- Water spreads horizontally more than sand
    -- Check left and right cells
    local leftType = canCheckLeft and level:getCellType(x - 1, y)
    local rightType = canCheckRight and level:getCellType(x + 1, y)

    -- Spread horizontally if possible
    if leftType == EMPTY and rightType == EMPTY then
        -- Both sides empty, choose randomly
        if math.random() < 0.5 then
            level:setCellType(x, y, EMPTY)
            level:setCellType(x - 1, y, myType)

            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x - 1, y = y})
        else
            level:setCellType(x, y, EMPTY)
            level:setCellType(x + 1, y, myType)

            table.insert(activeCells, {x = x, y = y})
            table.insert(activeCells, {x = x + 1, y = y})
        end

        return true -- Cell changed
    elseif leftType == EMPTY then
        level:setCellType(x, y, EMPTY)
        level:setCellType(x - 1, y, myType)

        return true -- Cell changed
    elseif rightType == EMPTY then
        level:setCellType(x, y, EMPTY)
        level:setCellType(x + 1, y, myType)

        return true -- Cell changed
    end

    -- SPRAY_WATER that can't move anymore has settled → promote to real WATER
    -- so the ball can float on it just like level-placed water.
    if myType == SPRAY_WATER then
        level:setCellType(x, y, WATER)
        return true
    end

    return false -- Water didn't move
end

-- Note: conversion of settled SPRAY_WATER → WATER happens here so the ball
-- can eventually float on water it sprayed once it has come to rest.

-- Check if a water cell should have a physics body (surface cell or near ball)
function Water.shouldHaveBody(cell, level, ballX, ballY)
    local x, y = cell.x, cell.y
    
    -- Check if near ball (within 12 cells)
    if ballX and ballY then
        local gridBallX, gridBallY = level:getGridCoordinates(ballX, ballY)
        local dist = math.sqrt((x - gridBallX)^2 + (y - gridBallY)^2)
        if dist <= 12 then
            return true
        end
    end
    
    -- Check if it's a surface cell (has empty space adjacent)
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local nx, ny = x + dx, y + dy
                if nx >= 0 and nx < level.width and ny >= 0 and ny < level.height then
                    if level.cells[ny] and level.cells[ny][nx] then
                        local neighborType = level.cells[ny][nx].type
                        if neighborType == EMPTY then
                            return true
                        end
                    end
                else
                    -- Edge of map counts as surface
                    return true
                end
            end
        end
    end
    
    return false
end

-- Ensure cell has a physics body
function Water.ensurePhysicsBody(cell, world)
    if not cell.hasPhysicsBody then
        Water.createPhysics(cell, world, false)
    end
end

-- Remove physics body from cell
function Water.removePhysicsBody(cell)
    if cell.hasPhysicsBody then
        if cell.fixture then cell.fixture:destroy() end
        if cell.body then cell.body:destroy() end
        cell.body = nil
        cell.shape = nil
        cell.fixture = nil
        cell.hasPhysicsBody = false
    end
end

return Water
