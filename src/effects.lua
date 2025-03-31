-- effects.lua - Visual effects for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")
local MobileOptimizations = require("src.mobile_optimizations")

local Effects = {}

-- Process sand and dirt cells that need to be converted to visual particles
function Effects.processSandConversion(sandToConvert, level)
    if #sandToConvert > 0 then
        -- Initialize the visual particles table once
        level.visualSandCells = level.visualSandCells or {}
        
        -- Apply mobile optimizations if enabled
        local particlesToProcess = sandToConvert
        if MobileOptimizations.enabled then
            -- Limit the number of particles to process on mobile
            local maxParticles = MobileOptimizations.reduceParticles(#sandToConvert, #sandToConvert)
            
            -- If we have more particles than the limit, randomly select some to process
            if #sandToConvert > maxParticles then
                particlesToProcess = {}
                
                -- Create a copy of the array to avoid modifying the original
                local tempArray = {}
                for i, cell in ipairs(sandToConvert) do
                    table.insert(tempArray, cell)
                end
                
                -- Randomly select particles to process
                for i = 1, maxParticles do
                    if #tempArray == 0 then
                        break
                    end
                    
                    -- Select a random index
                    local randomIndex = math.random(1, #tempArray)
                    
                    -- Add the particle to the process list
                    table.insert(particlesToProcess, tempArray[randomIndex])
                    
                    -- Remove the selected particle from the temp array
                    table.remove(tempArray, randomIndex)
                end
            end
        end
        
        -- Process the selected cells
        for i, cell in ipairs(particlesToProcess) do
            -- Skip cells that shouldn't be converted
            -- Only process cells that have shouldConvert set to true
            if not cell.shouldConvert then
                goto continue
            end
            
            -- Get the cell type - use originalType if provided, otherwise check the current cell
            local cellType = cell.originalType or level:getCellType(cell.x, cell.y)
            local cellTypeName = "unknown"
            local visualType = CellTypes.TYPES.VISUAL_SAND -- Default to visual sand
            
            -- Determine the visual type based on the cell type
            if cellType == CellTypes.TYPES.SAND then
                cellTypeName = "sand"
                visualType = CellTypes.TYPES.VISUAL_SAND
            elseif cellType == CellTypes.TYPES.DIRT then
                cellTypeName = "dirt"
                visualType = CellTypes.TYPES.VISUAL_DIRT
            elseif cellType == CellTypes.TYPES.EMPTY then
                -- For cells that are already empty, check if we have an originalType
                -- Otherwise, skip this cell as we don't know what type it was
                if not cell.originalType then
                    -- Debug output removed
                    goto continue
                end
            end
            
            -- Debug output removed
            
            -- Get the cell at this position
            if level.cells[cell.y] and level.cells[cell.y][cell.x] then
                -- Debug output removed
                
                -- The cell should already be set to EMPTY in collision.lua
                -- But let's make sure it is
                if level:getCellType(cell.x, cell.y) ~= CellTypes.TYPES.EMPTY then
                    -- Debug output removed
                    level:setCellType(cell.x, cell.y, CellTypes.TYPES.EMPTY)
                end
                
                -- Only create visual particles if the speed is above the threshold
                -- AND the cell has a non-zero velocity
                if cell.shouldConvert and (cell.vx ~= 0 or cell.vy ~= 0) then
                    -- Check if we're under the particle limit for mobile
                    if not MobileOptimizations.enabled or 
                       #level.visualSandCells < MobileOptimizations.maxParticles then
                        
                        -- Create a visual effect of flying particle
                        -- We'll just create a new cell at the same position with the appropriate visual type
                        local visualParticle = Cell.new(level.world, cell.x, cell.y, visualType)
                        
                        -- Adjust velocity based on material properties
                        if CellTypes.PROPERTIES[cellType] then
                            -- Use the velocity multiplier from material properties
                            local multiplier = CellTypes.PROPERTIES[cellType].velocityMultiplier
                            visualParticle.velocityX = cell.vx * multiplier
                            visualParticle.velocityY = cell.vy * multiplier
                        else
                            -- Default behavior if no properties are defined
                            visualParticle.velocityX = cell.vx
                            visualParticle.velocityY = cell.vy
                        end
                        
                        -- On mobile, reduce particle lifetime for better performance
                        if MobileOptimizations.enabled then
                            visualParticle.maxLifetime = (visualParticle.maxLifetime or 2.0) * 0.7
                        end
                        
                        -- Add the visual particle to the level's cells array
                        table.insert(level.visualSandCells, visualParticle)
                    end
                end
            end
            
            ::continue::
        end
    end
end

-- We no longer need to handle ball-sand collision specially since sand cells now have physics bodies

return Effects
