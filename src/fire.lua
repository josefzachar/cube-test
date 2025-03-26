-- fire.lua - Fire and smoke behavior for Square Golf

local CellTypes = require("src.cell_types")

local Fire = {}

-- Table to track fire cells and their lifetimes
Fire.fireCells = {}

-- Table to track smoke cells and their lifetimes
Fire.smokeCells = {}

-- Table to track steam cells and their lifetimes
Fire.steamCells = {}

-- Initialize fire at a specific position
function Fire.createFire(level, x, y)
    -- Set the cell type to fire
    level:setCellType(x, y, CellTypes.TYPES.FIRE)
    
    -- Add to fire cells table with lifetime
    local key = x .. "," .. y
    Fire.fireCells[key] = {
        x = x,
        y = y,
        lifetime = CellTypes.PROPERTIES[CellTypes.TYPES.FIRE].lifetime
    }
end

-- Create steam at a specific position
function Fire.createSteam(level, x, y)
    -- Set the cell type to smoke (we'll use smoke for steam too)
    level:setCellType(x, y, CellTypes.TYPES.SMOKE)
    
    -- Add to steam cells table with lifetime
    local key = x .. "," .. y
    Fire.steamCells[key] = {
        x = x,
        y = y,
        lifetime = CellTypes.PROPERTIES[CellTypes.TYPES.FIRE].smokeLifetime * 0.7, -- Steam dissipates faster
        isRising = true
    }
end

-- Create smoke at a specific position
function Fire.createSmoke(level, x, y)
    -- Set the cell type to smoke
    level:setCellType(x, y, CellTypes.TYPES.SMOKE)
    
    -- Add to smoke cells table with much shorter lifetime
    local key = x .. "," .. y
    Fire.smokeCells[key] = {
        x = x,
        y = y,
        lifetime = CellTypes.PROPERTIES[CellTypes.TYPES.FIRE].smokeLifetime * 0.4, -- 60% shorter lifetime
        creationTime = love.timer.getTime() -- Track when this smoke was created
    }
end

-- Create a fire explosion at a specific position with a given radius
function Fire.createExplosion(level, x, y, radius)
    -- Create fire in a circular pattern
    for dy = -radius, radius do
        for dx = -radius, radius do
            local checkX = x + dx
            local checkY = y + dy
            
            -- Calculate distance from center
            local distance = math.sqrt(dx*dx + dy*dy)
            
            -- Only affect cells within the explosion radius
            if distance <= radius and
               checkX >= 0 and checkX < level.width and 
               checkY >= 0 and checkY < level.height then
                
                -- Get the cell type
                local cellType = level:getCellType(checkX, checkY)
                
                -- Handle different cell types
                if cellType == CellTypes.TYPES.WATER then
                    -- Water has a chance to be boiled away by fire
                    if math.random() < CellTypes.PROPERTIES[CellTypes.TYPES.FIRE].waterBoilRate then
                        level:setCellType(checkX, checkY, CellTypes.TYPES.EMPTY)
                        -- Create steam where water was
                        Fire.createSteam(level, checkX, checkY)
                    end
                elseif cellType ~= CellTypes.TYPES.EMPTY and 
                       cellType ~= CellTypes.TYPES.FIRE and
                       cellType ~= CellTypes.TYPES.SMOKE then
                    -- Create fire at the center and edge of the explosion
                    if distance <= radius * 0.3 or (distance > radius * 0.7 and distance <= radius) then
                        Fire.createFire(level, checkX, checkY)
                    end
                end
            end
        end
    end
end

-- Maximum lifetime for fire and smoke cells (in seconds)
Fire.MAX_FIRE_LIFETIME = 5.0
Fire.MAX_SMOKE_LIFETIME = 2.0

-- Update fire and smoke behavior
function Fire.update(dt, level)
    -- Update fire cells
    local firesToRemove = {}
    for key, fireCell in pairs(Fire.fireCells) do
        -- Reduce lifetime
        fireCell.lifetime = fireCell.lifetime - dt
        
        -- Check if fire should turn to smoke
        if fireCell.lifetime <= 0 then
            -- Mark for removal
            table.insert(firesToRemove, key)
            
            -- Turn into smoke if the cell is still fire
            if level:getCellType(fireCell.x, fireCell.y) == CellTypes.TYPES.FIRE then
                Fire.createSmoke(level, fireCell.x, fireCell.y)
            end
        else
            -- Fire rises upward
            if fireCell.y > 0 and math.random() < 0.2 then
                local aboveType = level:getCellType(fireCell.x, fireCell.y - 1)
                if aboveType == CellTypes.TYPES.EMPTY then
                    -- Move fire upward
                    level:setCellType(fireCell.x, fireCell.y, CellTypes.TYPES.EMPTY)
                    level:setCellType(fireCell.x, fireCell.y - 1, CellTypes.TYPES.FIRE)
                    
                    -- Update position in fire cells table
                    Fire.fireCells[key] = nil
                    local newKey = fireCell.x .. "," .. (fireCell.y - 1)
                    Fire.fireCells[newKey] = {
                        x = fireCell.x,
                        y = fireCell.y - 1,
                        lifetime = fireCell.lifetime
                    }
                    
                    -- Skip the rest of this iteration
                    goto continue_fire
                end
            end
            
            -- Fire has a reduced chance to burn out and turn to smoke
            if math.random() < 0.03 then -- Reduced from 0.05 to 0.03
                -- Mark for removal
                table.insert(firesToRemove, key)
                
                -- Only 50% chance to create smoke when fire burns out
                if math.random() < 0.5 and level:getCellType(fireCell.x, fireCell.y) == CellTypes.TYPES.FIRE then
                    Fire.createSmoke(level, fireCell.x, fireCell.y)
                else
                    -- Just remove the fire without creating smoke
                    level:setCellType(fireCell.x, fireCell.y, CellTypes.TYPES.EMPTY)
                end
                
                -- Skip the rest of this iteration
                goto continue_fire
            end
            
            -- Fire evaporates water
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if dx ~= 0 or dy ~= 0 then -- Skip the fire cell itself
                        local newX, newY = fireCell.x + dx, fireCell.y + dy
                        
                        -- Check if the position is valid
                        if newX >= 0 and newX < level.width and newY >= 0 and newY < level.height then
                            local cellType = level:getCellType(newX, newY)
                            
                            -- Only interact with water
                            if cellType == CellTypes.TYPES.WATER then
                                -- Water has a chance to be boiled away by fire
                                if math.random() < 0.3 then
                                    level:setCellType(newX, newY, CellTypes.TYPES.EMPTY)
                                    -- Create steam where water was
                                    Fire.createSteam(level, newX, newY)
                                    
                                    -- Fire is consumed when it evaporates water
                                    level:setCellType(fireCell.x, fireCell.y, CellTypes.TYPES.EMPTY)
                                    table.insert(firesToRemove, key)
                                    
                                    -- Skip the rest of this iteration
                                    goto continue_fire
                                end
                            end
                        end
                    end
                end
            end
        end
        
        ::continue_fire::
    end
    
    -- Remove expired fire cells
    for _, key in ipairs(firesToRemove) do
        Fire.fireCells[key] = nil
    end
    
    -- Update steam cells
    local steamsToRemove = {}
    for key, steamCell in pairs(Fire.steamCells) do
        -- Reduce lifetime
        steamCell.lifetime = steamCell.lifetime - dt
        
        -- Check if steam should disappear
        if steamCell.lifetime <= 0 then
            -- Mark for removal
            table.insert(steamsToRemove, key)
            
            -- Remove steam if the cell is still smoke
            if level:getCellType(steamCell.x, steamCell.y) == CellTypes.TYPES.SMOKE then
                level:setCellType(steamCell.x, steamCell.y, CellTypes.TYPES.EMPTY)
            end
        else
            -- Steam rises upward faster than smoke
            local riseChance = 0.5 -- 50% chance per update
            if math.random() < riseChance then
                local newY = steamCell.y - 1 -- Move up
                
                -- Check if the position is valid and empty
                if newY >= 0 and level:getCellType(steamCell.x, newY) == CellTypes.TYPES.EMPTY then
                    -- Move steam upward
                    level:setCellType(steamCell.x, steamCell.y, CellTypes.TYPES.EMPTY)
                    level:setCellType(steamCell.x, newY, CellTypes.TYPES.SMOKE)
                    
                    -- Update position in steam cells table
                    Fire.steamCells[key] = nil
                    local newKey = steamCell.x .. "," .. newY
                    Fire.steamCells[newKey] = {
                        x = steamCell.x,
                        y = newY,
                        lifetime = steamCell.lifetime,
                        isRising = true
                    }
                    
                    -- Skip the rest of this iteration
                    goto continue_steam
                end
            end
            
            -- Steam can also move diagonally upward
            if steamCell.isRising then
                local leftClear = steamCell.x > 0 and steamCell.y > 0 and 
                                 level:getCellType(steamCell.x - 1, steamCell.y - 1) == CellTypes.TYPES.EMPTY
                local rightClear = steamCell.x < level.width - 1 and steamCell.y > 0 and 
                                  level:getCellType(steamCell.x + 1, steamCell.y - 1) == CellTypes.TYPES.EMPTY
                
                if leftClear and rightClear then
                    -- Choose randomly between left and right
                    if math.random() < 0.5 then
                        level:setCellType(steamCell.x, steamCell.y, CellTypes.TYPES.EMPTY)
                        level:setCellType(steamCell.x - 1, steamCell.y - 1, CellTypes.TYPES.SMOKE)
                        
                        -- Update position in steam cells table
                        Fire.steamCells[key] = nil
                        local newKey = (steamCell.x - 1) .. "," .. (steamCell.y - 1)
                        Fire.steamCells[newKey] = {
                            x = steamCell.x - 1,
                            y = steamCell.y - 1,
                            lifetime = steamCell.lifetime,
                            isRising = true
                        }
                    else
                        level:setCellType(steamCell.x, steamCell.y, CellTypes.TYPES.EMPTY)
                        level:setCellType(steamCell.x + 1, steamCell.y - 1, CellTypes.TYPES.SMOKE)
                        
                        -- Update position in steam cells table
                        Fire.steamCells[key] = nil
                        local newKey = (steamCell.x + 1) .. "," .. (steamCell.y - 1)
                        Fire.steamCells[newKey] = {
                            x = steamCell.x + 1,
                            y = steamCell.y - 1,
                            lifetime = steamCell.lifetime,
                            isRising = true
                        }
                    end
                elseif leftClear then
                    level:setCellType(steamCell.x, steamCell.y, CellTypes.TYPES.EMPTY)
                    level:setCellType(steamCell.x - 1, steamCell.y - 1, CellTypes.TYPES.SMOKE)
                    
                    -- Update position in steam cells table
                    Fire.steamCells[key] = nil
                    local newKey = (steamCell.x - 1) .. "," .. (steamCell.y - 1)
                    Fire.steamCells[newKey] = {
                        x = steamCell.x - 1,
                        y = steamCell.y - 1,
                        lifetime = steamCell.lifetime,
                        isRising = true
                    }
                elseif rightClear then
                    level:setCellType(steamCell.x, steamCell.y, CellTypes.TYPES.EMPTY)
                    level:setCellType(steamCell.x + 1, steamCell.y - 1, CellTypes.TYPES.SMOKE)
                    
                    -- Update position in steam cells table
                    Fire.steamCells[key] = nil
                    local newKey = (steamCell.x + 1) .. "," .. (steamCell.y - 1)
                    Fire.steamCells[newKey] = {
                        x = steamCell.x + 1,
                        y = steamCell.y - 1,
                        lifetime = steamCell.lifetime,
                        isRising = true
                    }
                end
            end
        end
        
        ::continue_steam::
    end
    
    -- Remove expired steam cells
    for _, key in ipairs(steamsToRemove) do
        Fire.steamCells[key] = nil
    end
    
    -- Update smoke cells
    local smokesToRemove = {}
    for key, smokeCell in pairs(Fire.smokeCells) do
        -- Reduce lifetime faster
        smokeCell.lifetime = smokeCell.lifetime - dt * 2.5 -- Make smoke disappear faster
        
        -- Check if smoke should disappear
        if smokeCell.lifetime <= 0 then
            -- Mark for removal
            table.insert(smokesToRemove, key)
            
            -- Remove smoke if the cell is still smoke
            if level:getCellType(smokeCell.x, smokeCell.y) == CellTypes.TYPES.SMOKE then
                level:setCellType(smokeCell.x, smokeCell.y, CellTypes.TYPES.EMPTY)
            end
        else
            -- Smoke rises upward
            local riseChance = 0.4 -- 40% chance per update (faster rising)
            if math.random() < riseChance then
                local newY = smokeCell.y - 1 -- Move up
                
                -- Check if the position is valid and empty
                if newY >= 0 and level:getCellType(smokeCell.x, newY) == CellTypes.TYPES.EMPTY then
                    -- Move smoke upward
                    level:setCellType(smokeCell.x, smokeCell.y, CellTypes.TYPES.EMPTY)
                    level:setCellType(smokeCell.x, newY, CellTypes.TYPES.SMOKE)
                    
                    -- Update position in smoke cells table
                    Fire.smokeCells[key] = nil
                    local newKey = smokeCell.x .. "," .. newY
                    Fire.smokeCells[newKey] = {
                        x = smokeCell.x,
                        y = newY,
                        lifetime = smokeCell.lifetime * 0.9 -- Further reduce lifetime as it rises
                    }
                end
            end
        end
    end
    
    -- Remove expired smoke cells
    for _, key in ipairs(smokesToRemove) do
        Fire.smokeCells[key] = nil
    end
    
    -- Scan for and clean up any stray fire or smoke cells
    Fire.cleanupStrayCells(level)
end

-- Scan the level for any fire or smoke cells that aren't being tracked
-- and remove them to prevent them from getting stuck
function Fire.cleanupStrayCells(level)
    -- Only run this cleanup every 30 frames to save performance
    Fire.cleanupCounter = (Fire.cleanupCounter or 0) + 1
    if Fire.cleanupCounter < 30 then
        return
    end
    Fire.cleanupCounter = 0
    
    -- Scan a portion of the level each time (divide into 4 quadrants)
    -- and rotate through them for better performance
    Fire.cleanupQuadrant = (Fire.cleanupQuadrant or 0) + 1
    if Fire.cleanupQuadrant > 4 then
        Fire.cleanupQuadrant = 1
    end
    
    local startX, endX, startY, endY
    
    -- Determine which quadrant to scan
    if Fire.cleanupQuadrant == 1 then
        -- Top-left quadrant
        startX, endX = 0, math.floor(level.width / 2)
        startY, endY = 0, math.floor(level.height / 2)
    elseif Fire.cleanupQuadrant == 2 then
        -- Top-right quadrant
        startX, endX = math.floor(level.width / 2), level.width - 1
        startY, endY = 0, math.floor(level.height / 2)
    elseif Fire.cleanupQuadrant == 3 then
        -- Bottom-left quadrant
        startX, endX = 0, math.floor(level.width / 2)
        startY, endY = math.floor(level.height / 2), level.height - 1
    else
        -- Bottom-right quadrant
        startX, endX = math.floor(level.width / 2), level.width - 1
        startY, endY = math.floor(level.height / 2), level.height - 1
    end
    
    -- Scan the current quadrant for fire and smoke cells
    for y = startY, endY do
        for x = startX, endX do
            if level.cells[y] and level.cells[y][x] then
                local cellType = level.cells[y][x].type
                
                -- Check for fire cells
                if cellType == CellTypes.TYPES.FIRE then
                    local key = x .. "," .. y
                    -- If this fire cell isn't being tracked, either track it or remove it
                    if not Fire.fireCells[key] then
                        -- Add it to the tracking table with a short lifetime
                        Fire.fireCells[key] = {
                            x = x,
                            y = y,
                            lifetime = 0.5 -- Short lifetime so it will disappear soon
                        }
                    end
                -- Check for smoke cells
                elseif cellType == CellTypes.TYPES.SMOKE then
                    local key = x .. "," .. y
                    -- If this smoke cell isn't being tracked, either track it or remove it
                    if not Fire.smokeCells[key] and not Fire.steamCells[key] then
                        -- Just remove it directly
                        level:setCellType(x, y, CellTypes.TYPES.EMPTY)
                    end
                end
            end
        end
    end
end

return Fire
