-- effects.lua - Visual effects for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local Effects = {}

-- Process sand and dirt cells that need to be converted to visual particles
function Effects.processSandConversion(sandToConvert, level)
    if #sandToConvert > 0 then
        print("Converting", #sandToConvert, "cells to visual particles")
        for _, cell in ipairs(sandToConvert) do
            local cellType = level:getCellType(cell.x, cell.y)
            local cellTypeName = "unknown"
            local visualType = CellTypes.TYPES.VISUAL_SAND -- Default to visual sand
            
            if cellType == CellTypes.TYPES.SAND then
                cellTypeName = "sand"
                visualType = CellTypes.TYPES.VISUAL_SAND
            elseif cellType == CellTypes.TYPES.DIRT then
                cellTypeName = "dirt"
                visualType = CellTypes.TYPES.VISUAL_DIRT
            end
            
            print("  Converting " .. cellTypeName .. " at", cell.x, cell.y, "to visual particle with velocity", cell.vx, cell.vy)
            
            -- Get the cell at this position
            if level.cells[cell.y] and level.cells[cell.y][cell.x] then
                -- Create a crater by setting the cell to EMPTY
                level:setCellType(cell.x, cell.y, CellTypes.TYPES.EMPTY)
                
                -- Create a visual effect of flying particle
                -- We'll just create a new cell at the same position with the appropriate visual type
                local visualParticle = Cell.new(level.world, cell.x, cell.y, visualType)
                visualParticle.velocityX = cell.vx
                visualParticle.velocityY = cell.vy
                
                -- Add the visual particle to the level's cells array
                level.visualSandCells = level.visualSandCells or {}
                table.insert(level.visualSandCells, visualParticle)
            end
        end
    end
end

-- We no longer need to handle ball-sand collision specially since sand cells now have physics bodies

return Effects
