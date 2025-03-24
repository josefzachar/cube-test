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

-- Handle ball collision with sand cells
function Effects.handleBallSandCollision(ball, level, sandToStone)
    if ball.body then
        local vx, vy = ball.body:getLinearVelocity()
        local speed = math.sqrt(vx*vx + vy*vy)
        local ballX, ballY = ball.body:getPosition()
        local gridX, gridY = level:getGridCoordinates(ballX, ballY)
        
        -- Only convert sand to temporary stone if the ball is moving
        if speed > 10 then
            -- Optimize: Use a smaller radius for slow-moving balls
            local radius = math.min(4, math.max(2, math.floor(speed / 100) + 2))
            
            -- Optimize: Only convert sand in the direction of movement
            local dirX = 0
            local dirY = 0
            
            if speed > 50 then
                dirX = vx / speed
                dirY = vy / speed
            end
            
            -- Calculate the distance from the ball to each cell
            for dy = -radius, radius do
                for dx = -radius, radius do
                    -- Skip cells that are not in the direction of movement (for fast balls)
                    if speed <= 50 or (dx * dirX + dy * dirY > -0.5) then
                        local checkX = gridX + dx
                        local checkY = gridY + dy
                        
                        -- Calculate distance from ball center to cell center
                        local distSq = dx*dx + dy*dy
                        
                        -- Only convert cells within the radius
                        if distSq <= radius*radius then
                            if checkX >= 0 and checkX < level.width and checkY >= 0 and checkY < level.height then
                                if level:getCellType(checkX, checkY) == CellTypes.TYPES.SAND then
                                    -- Convert sand to temporary stone
                                    level:setCellType(checkX, checkY, CellTypes.TYPES.TEMP_STONE)
                                    
                                    -- Add to the list of converted cells
                                    table.insert(sandToStone, {
                                        x = checkX,
                                        y = checkY,
                                        timer = 0.1 -- Convert back after 0.1 seconds (reduced from 0.2)
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

return Effects
