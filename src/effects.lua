-- effects.lua - Visual effects for Square Golf

local Cell = require("cell")
local CellTypes = require("src.cell_types")

local Effects = {}

-- Process sand cells that need to be converted to visual sand
function Effects.processSandConversion(sandToConvert, level)
    if #sandToConvert > 0 then
        print("Converting", #sandToConvert, "sand cells to visual sand")
        for _, sand in ipairs(sandToConvert) do
            print("  Converting sand at", sand.x, sand.y, "to visual sand with velocity", sand.vx, sand.vy)
            
            -- Get the cell at this position
            if level.cells[sand.y] and level.cells[sand.y][sand.x] then
                -- Create a crater by setting the cell to EMPTY
                level:setCellType(sand.x, sand.y, CellTypes.TYPES.EMPTY)
                
                -- Create a visual effect of flying sand
                -- We'll just create a new cell at the same position with type VISUAL_SAND
                local visualSand = Cell.new(level.world, sand.x, sand.y, CellTypes.TYPES.VISUAL_SAND)
                visualSand.velocityX = sand.vx
                visualSand.velocityY = sand.vy
                
                -- Add the visual sand to the level's cells array
                level.visualSandCells = level.visualSandCells or {}
                table.insert(level.visualSandCells, visualSand)
            end
        end
    end
end

-- We no longer need to handle ball-sand collision specially since sand cells now have physics bodies

return Effects
