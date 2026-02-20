-- renderer.lua - Cell rendering utilities

local CellTypes = require("src.cell_types")
local Fire = require("src.fire")

local Renderer = {}

-- Initialize sprite batches for efficient rendering
local cellTexture = nil
local spriteBatches = {}
local quadCache = {}

-- Orbit-particle state for win hole (persists across frames)
local orbitParticles    = {}
local orbitCenterSnap   = nil  -- "x,y" string, detects level change
local currentBall       = nil  -- set each frame by Renderer.setBall()
local prevBallHasWon    = false -- edge-detect the moment ball enters hole

-- Called by draw.lua each frame so the win-hole animator can read ball state
function Renderer.setBall(ball)
    currentBall = ball
end
local ORBIT_COLORS = {
    {0.78, 0.08, 1.00},  -- vivid violet
    {0.92, 0.35, 1.00},  -- lavender
    {0.55, 0.00, 0.88},  -- deep purple
    {1.00, 0.55, 1.00},  -- pink
    {0.45, 0.00, 0.80},  -- indigo
    {0.65, 0.10, 0.95},  -- mid-purple
}

function Renderer.initSpriteBatches()
    -- Create a simple 1x1 white texture
    local imageData = love.image.newImageData(1, 1)
    imageData:setPixel(0, 0, 1, 1, 1, 1)
    cellTexture = love.graphics.newImage(imageData)
    
    -- Create sprite batches for each cell type (max 10000 cells per type)
    local Cell = require("cell")
    spriteBatches[Cell.TYPES.SAND] = love.graphics.newSpriteBatch(cellTexture, 10000, "dynamic")
    spriteBatches[Cell.TYPES.STONE] = love.graphics.newSpriteBatch(cellTexture, 10000, "dynamic")
    spriteBatches[Cell.TYPES.WATER] = love.graphics.newSpriteBatch(cellTexture, 10000, "dynamic")
    spriteBatches[Cell.TYPES.DIRT] = love.graphics.newSpriteBatch(cellTexture, 10000, "dynamic")
    spriteBatches[CellTypes.TYPES.FIRE] = love.graphics.newSpriteBatch(cellTexture, 1000, "dynamic")
    spriteBatches[CellTypes.TYPES.SMOKE] = love.graphics.newSpriteBatch(cellTexture, 1000, "dynamic")
    spriteBatches[CellTypes.TYPES.WIN_HOLE] = love.graphics.newSpriteBatch(cellTexture, 100, "dynamic")
    spriteBatches[CellTypes.TYPES.ICE] = love.graphics.newSpriteBatch(cellTexture, 5000, "dynamic")
    
    -- Create quad for a single cell (covers entire 1x1 texture)
    quadCache.cell = love.graphics.newQuad(0, 0, 1, 1, 1, 1)
end

-- Draw all cells in the level
-- noCull: when true, draw ALL cells regardless of viewport (used by the editor)
function Renderer.drawLevel(level, debug, noCull)
    -- Get visible area (camera view)
    local screenWidth, screenHeight = love.graphics.getDimensions()
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local Camera = require("src.camera")
    
    -- Calculate visible cell range based on screen size and zoom
    local margin = 10 -- Extra cells to draw outside the visible area to avoid pop-in
    
    local minX, maxX, minY, maxY

    if noCull then
        -- Editor mode: render every cell so nothing is invisible off-screen
        minX = 0
        maxX = level.width  - 1
        minY = 0
        maxY = level.height - 1
    else
        -- Game mode: frustum-cull to visible viewport for performance
        local zoom = ZOOM_LEVEL or 1
        local viewportWidth  = screenWidth  / zoom
        local viewportHeight = screenHeight / zoom
        local cameraX = Camera.x or (level.width  * Cell.SIZE / 2)
        local cameraY = Camera.y or (level.height * Cell.SIZE / 2)
        local viewLeft   = cameraX - viewportWidth  / 2
        local viewRight  = cameraX + viewportWidth  / 2
        local viewTop    = cameraY - viewportHeight / 2
        local viewBottom = cameraY + viewportHeight / 2
        minX = math.max(0,              math.floor(viewLeft   / Cell.SIZE) - margin)
        maxX = math.min(level.width  - 1, math.ceil(viewRight  / Cell.SIZE) + margin)
        minY = math.max(0,              math.floor(viewTop    / Cell.SIZE) - margin)
        maxY = math.min(level.height - 1, math.ceil(viewBottom / Cell.SIZE) + margin)
    end
    
    -- Store culling stats in perfStats
    if level.perfStats then
        level.perfStats.visibleCells = (maxX - minX + 1) * (maxY - minY + 1)
        level.perfStats.totalCells = level.width * level.height
    end
    
    -- Initialize sprite batches if not already done
    if not cellTexture then
        Renderer.initSpriteBatches()
    end
    
    -- Clear all sprite batches
    for _, batch in pairs(spriteBatches) do
        batch:clear()
    end

    -- Collect win hole cells for custom animated rendering
    local winHoleCells = {}

    -- Add cells to sprite batches
    for y = minY, maxY do
        for x = minX, maxX do
            if level.cells[y] and level.cells[y][x] then
                local cell = level.cells[y][x]
                local cellType = cell.type
                
                -- Skip empty cells unless in debug mode
                if cellType == Cell.TYPES.EMPTY then
                    if debug then
                        love.graphics.setColor(0.2, 0.2, 0.2, 0.2)
                        love.graphics.rectangle("line", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
                    end
                elseif cellType == Cell.TYPES.DIRT then
                    -- Dirt has special rendering with grass
                    Renderer.drawDirtCell(cell, x, y, Cell.SIZE, debug)
                elseif cellType == CellTypes.TYPES.WIN_HOLE then
                    -- Collect for special animated rendering (drawn after sprite batches)
                    table.insert(winHoleCells, {x = x, y = y})
                elseif spriteBatches[cellType] then
                    -- Add to sprite batch with color variation
                    local color = COLORS[cellType]
                    local r = color[1] * cell.colorVariation.r
                    local g = color[2] * cell.colorVariation.g
                    local b = color[3] * cell.colorVariation.b
                    local a = color[4]
                    
                    spriteBatches[cellType]:setColor(r, g, b, a)
                    spriteBatches[cellType]:add(quadCache.cell, x * Cell.SIZE, y * Cell.SIZE, 0, Cell.SIZE, Cell.SIZE)
                end
            end
        end
    end
    
    -- Draw all sprite batches
    love.graphics.setColor(1, 1, 1, 1)
    for _, batch in pairs(spriteBatches) do
        love.graphics.draw(batch)
    end
    
    -- Draw win hole cells with special vortex animation
    Renderer.drawWinHoleBatch(level, winHoleCells, debug)

    -- Draw visual sand cells
    Renderer.drawVisualSand(level, minX, maxX, minY, maxY, debug)
    
    -- Draw grid lines in debug mode
    if debug then
        Renderer.drawGrid(minX, maxX, minY, maxY)
    end
end

-- Draw sand cells
function Renderer.drawSandBatch(level, sandBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local sandColor = COLORS[Cell.TYPES.SAND]
    local Debug = require("src.debug")
    
    for _, cellPos in ipairs(sandBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        
        -- Apply color variation
        love.graphics.setColor(
            sandColor[1] * cell.colorVariation.r,
            sandColor[2] * cell.colorVariation.g,
            sandColor[3] * cell.colorVariation.b,
            sandColor[4]
        )
        love.graphics.rectangle("fill", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            -- If debug mode is on and active cells visualization is enabled, 
            -- show which cells are in active clusters
            if Debug.showActiveCells and cellPos.active then
                -- Draw a small indicator for active cells
                love.graphics.setColor(1, 1, 0, 0.7) -- Yellow for active cells
                love.graphics.rectangle("line", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            else
                -- Regular debug indicator
                love.graphics.setColor(0, 0, 1, 1) -- Blue
                love.graphics.circle("fill", cellPos.x * Cell.SIZE + Cell.SIZE/2, cellPos.y * Cell.SIZE + Cell.SIZE/2, 2)
            end
        end
    end
end

-- Draw stone cells
function Renderer.drawStoneBatch(level, stoneBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local stoneColor = COLORS[Cell.TYPES.STONE]
    
    for _, cellPos in ipairs(stoneBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        
        -- Apply color variation
        love.graphics.setColor(
            stoneColor[1] * cell.colorVariation.r,
            stoneColor[2] * cell.colorVariation.g,
            stoneColor[3] * cell.colorVariation.b,
            stoneColor[4]
        )
        love.graphics.rectangle("fill", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(1, 0, 0, 1) -- Red
            love.graphics.circle("fill", cellPos.x * Cell.SIZE + Cell.SIZE/2, cellPos.y * Cell.SIZE + Cell.SIZE/2, 2)
        end
    end
end

-- Draw water cells
function Renderer.drawWaterBatch(level, waterBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local waterColor = COLORS[Cell.TYPES.WATER]
    local Debug = require("src.debug")
    
    for _, cellPos in ipairs(waterBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        
        -- Apply color variation
        love.graphics.setColor(
            waterColor[1] * cell.colorVariation.r,
            waterColor[2] * cell.colorVariation.g,
            waterColor[3] * cell.colorVariation.b,
            waterColor[4]
        )
        love.graphics.rectangle("fill", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            -- If debug mode is on and active cells visualization is enabled, 
            -- show which cells are in active clusters
            if Debug.showActiveCells and cellPos.active then
                -- Draw a small indicator for active cells
                love.graphics.setColor(1, 1, 0, 0.7) -- Yellow for active cells
                love.graphics.rectangle("line", cellPos.x * Cell.SIZE, cellPos.y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            else
                -- Regular debug indicator
                love.graphics.setColor(0, 1, 1, 1) -- Cyan
                love.graphics.circle("fill", cellPos.x * Cell.SIZE + Cell.SIZE/2, cellPos.y * Cell.SIZE + Cell.SIZE/2, 2)
            end
        end
    end
end

-- Draw visual particles (sand and dirt)
function Renderer.drawVisualSand(level, minX, maxX, minY, maxY, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    
    if #level.visualSandCells > 0 then
        for _, cell in ipairs(level.visualSandCells) do
            -- Only draw if within visible area
            if cell.visualX >= minX * Cell.SIZE - Cell.SIZE and 
               cell.visualX <= maxX * Cell.SIZE + Cell.SIZE and
               cell.visualY >= minY * Cell.SIZE - Cell.SIZE and
               cell.visualY <= maxY * Cell.SIZE + Cell.SIZE then
                
                -- Get the correct color based on cell type
                local color = COLORS[cell.type]
                if color then
                    -- Apply color variation and alpha for fade out
                    love.graphics.setColor(
                        color[1] * cell.colorVariation.r, 
                        color[2] * cell.colorVariation.g, 
                        color[3] * cell.colorVariation.b, 
                        cell.alpha or 1.0
                    )
                    love.graphics.rectangle("fill", cell.visualX, cell.visualY, Cell.SIZE, Cell.SIZE)
                    
                    -- Draw debug info for visual particles
                    if debug then
                        love.graphics.setColor(1, 0, 0, cell.alpha or 1.0)
                        love.graphics.rectangle("line", cell.visualX, cell.visualY, Cell.SIZE, Cell.SIZE)
                    end
                end
            end
        end
    end
end

-- Draw a single dirt cell (helper for optimized renderer)
function Renderer.drawDirtCell(cell, x, y, cellSize, debug)
    local COLORS = CellTypes.COLORS
    local dirtColor = COLORS[require("cell").TYPES.DIRT]
    local grassColor = {0.2, 0.7, 0.2, 1}
    
    -- Choose color based on whether this cell has grass
    local color = cell.hasGrass and grassColor or dirtColor
    
    -- Apply color variation
    love.graphics.setColor(
        color[1] * cell.colorVariation.r,
        color[2] * cell.colorVariation.g,
        color[3] * cell.colorVariation.b,
        color[4]
    )
    love.graphics.rectangle("fill", x * cellSize, y * cellSize, cellSize, cellSize)
end

-- Draw dirt cells
function Renderer.drawDirtBatch(level, dirtBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local dirtColor = COLORS[Cell.TYPES.DIRT]
    -- Define grass color (green)
    local grassColor = {0.2, 0.7, 0.2, 1}
    local Debug = require("src.debug")
    
    for _, cellPos in ipairs(dirtBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        local x, y = cellPos.x, cellPos.y
        
        -- Choose color based on whether this cell has grass (set during level initialization)
        local color = cell.hasGrass and grassColor or dirtColor
        
        -- Apply color variation
        love.graphics.setColor(
            color[1] * cell.colorVariation.r,
            color[2] * cell.colorVariation.g,
            color[3] * cell.colorVariation.b,
            color[4]
        )
        love.graphics.rectangle("fill", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            -- If debug mode is on and active cells visualization is enabled, 
            -- show which cells are in active clusters
            if Debug.showActiveCells and cellPos.active then
                -- Draw a small indicator for active cells
                love.graphics.setColor(1, 1, 0, 0.7) -- Yellow for active cells
                love.graphics.rectangle("line", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
            else
                -- Regular debug indicator
                love.graphics.setColor(0.8, 0.4, 0, 1) -- Orange
                love.graphics.circle("fill", x * Cell.SIZE + Cell.SIZE/2, y * Cell.SIZE + Cell.SIZE/2, 2)
            end
        end
    end
end

-- Draw fire cells with simple animated effect
function Renderer.drawFireBatch(level, fireBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local fireColor = COLORS[CellTypes.TYPES.FIRE]
    
    for _, cellPos in ipairs(fireBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        local x, y = cellPos.x, cellPos.y
        
        -- Apply color variation and simple animation
        local time = love.timer.getTime()
        local flicker = math.sin(time * 10 + x * 0.5 + y * 0.7) * 0.2 + 0.8 -- Flickering effect
        
        love.graphics.setColor(
            fireColor[1] * cell.colorVariation.r * flicker,
            fireColor[2] * cell.colorVariation.g * flicker,
            fireColor[3] * cell.colorVariation.b * flicker,
            fireColor[4]
        )
        
        -- Draw main fire cell
        love.graphics.rectangle("fill", x * Cell.SIZE, y * Cell.SIZE, Cell.SIZE, Cell.SIZE)
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(1, 0.5, 0, 1) -- Orange
            love.graphics.circle("fill", x * Cell.SIZE + Cell.SIZE/2, y * Cell.SIZE + Cell.SIZE/2, 2)
        end
    end
end

-- Draw smoke cells with simple rising effect
function Renderer.drawSmokeBatch(level, smokeBatch, debug)
    local Cell = require("cell")
    local COLORS = CellTypes.COLORS
    local smokeColor = COLORS[CellTypes.TYPES.SMOKE]
    
    for _, cellPos in ipairs(smokeBatch) do
        -- Get the actual cell from the level
        local cell = level.cells[cellPos.y][cellPos.x]
        local x, y = cellPos.x, cellPos.y
        
        -- Check if this is steam (from Fire.steamCells) or regular smoke
        local isInSteamTable = Fire and Fire.steamCells and Fire.steamCells[x .. "," .. y]
        
        -- Apply color variation and animation
        local time = love.timer.getTime()
        local drift = math.sin(time * 2 + x * 0.3 + y * 0.5) * 0.1 -- Slow drifting effect
        
        -- Determine if this is steam or smoke for coloring
        if isInSteamTable then
            -- Steam is more white/blue tinted
            love.graphics.setColor(0.9, 0.9, 1.0, 0.7)
        else
            -- Regular smoke is gray
            love.graphics.setColor(
                smokeColor[1] * cell.colorVariation.r,
                smokeColor[2] * cell.colorVariation.g,
                smokeColor[3] * cell.colorVariation.b,
                smokeColor[4] * (0.8 + drift) -- Varying opacity
            )
        end
        
        -- Draw smoke with slight offset for drifting effect
        love.graphics.rectangle(
            "fill", 
            x * Cell.SIZE + drift * Cell.SIZE, 
            y * Cell.SIZE, 
            Cell.SIZE, 
            Cell.SIZE
        )
        
        -- Draw debug info
        if debug then
            love.graphics.setColor(0.7, 0.7, 0.7, 1) -- Light gray
            love.graphics.circle("fill", x * Cell.SIZE + Cell.SIZE/2, y * Cell.SIZE + Cell.SIZE/2, 2)
        end
    end
end

-- Draw win hole: orbiting purple pixel-art cells, like moths around a flame
function Renderer.drawWinHoleBatch(level, winHoleBatch, debug)
    if not winHoleBatch or #winHoleBatch == 0 then
        orbitParticles  = {}
        orbitCenterSnap = nil
        return
    end
    local Cell = require("cell")
    local dt   = love.timer.getDelta()
    local time = love.timer.getTime()
    local CS   = Cell.SIZE  -- 10 px

    -- Centroid of the physical hole cells (world pixels)
    local sumX, sumY = 0, 0
    for _, p in ipairs(winHoleBatch) do
        sumX = sumX + p.x
        sumY = sumY + p.y
    end
    local n       = #winHoleBatch
    local centerX = (sumX / n + 0.5) * CS
    local centerY = (sumY / n + 0.5) * CS
    local snapKey = math.floor(centerX) .. "," .. math.floor(centerY)

    -- (Re-)initialise particles when hole appears or level changes
    if orbitCenterSnap ~= snapKey then
        orbitCenterSnap = snapKey
        orbitParticles  = {}
        local TOTAL = 42
        for i = 1, TOTAL do
            -- bias radius toward center: t^1.8 gives high density near 0
            local t          = math.random() ^ 1.8
            local baseRadius = 8 + t * 58
            -- inner particles orbit faster (Kepler-like: faster near centre)
            local clockwise  = (math.random() < 0.25) and -1 or 1
            local speedFactor = 1.0 + (1.0 - t) * 2.0
    table.insert(orbitParticles, {
                angle        = math.random() * math.pi * 2,
                angSpeed     = clockwise * (0.4 + math.random() * 1.6) * speedFactor,
                baseRadius   = baseRadius,
                wobbleAmp    = 2  + t * 16,
                wobbleFreq   = 0.8 + math.random() * 2.5,
                wobbleOff    = math.random() * math.pi * 2,
                stutterAcc   = 0,
                stutterTimer = math.random() * 2.0,
                driftAmp     = 1 + t * 9,
                driftFreq    = 0.4 + math.random() * 1.2,
                driftOff     = math.random() * math.pi * 2,
                col          = ORBIT_COLORS[math.random(#ORBIT_COLORS)],
                pulseFreq    = 2.0 + math.random() * 4.0,
                pulseOff     = math.random() * math.pi * 2,
                scatterRadius = 0,   -- extra outward push on ball impact
                scatterDecay  = 2.5 + math.random() * 2.0,  -- how fast scatter fades (per-particle variation)
            })
        end
    end

    -- Draw the gravity-centre: tiny dark void so the eye has a target
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill",
        math.floor(centerX/CS)*CS - CS,
        math.floor(centerY/CS)*CS - CS,
        CS * 2, CS * 2)
    -- Faint purple glint at centre, slow pulse
    local glint = math.sin(time * 1.8) * 0.5 + 0.5
    love.graphics.setColor(0.6, 0.0, 0.9, 0.35 + glint * 0.35)
    love.graphics.rectangle("fill",
        math.floor(centerX/CS)*CS,
        math.floor(centerY/CS)*CS,
        CS, CS)

    -- Win-spiral progress: 0 when idle, 0→1 as ball animates into the hole
    local winProg = 0
    if currentBall and currentBall.hasWon and
       currentBall.winAnimTimer and currentBall.winAnimDuration then
        winProg = math.min(currentBall.winAnimTimer / currentBall.winAnimDuration, 1.0)
    end

    -- Detect the exact frame the ball enters the hole → apply scatter impulse
    local ballJustWon = currentBall and currentBall.hasWon and not prevBallHasWon
    prevBallHasWon    = (currentBall and currentBall.hasWon) or false
    if ballJustWon then
        local es = (currentBall and currentBall.winEntrySpeed) or 0
        -- Power curve: gentle tap barely reacts, hard shot strongly reacts
        -- es=50→1px, es=100→4px, es=200→11px, es=300→21px, es=500→45px
        local scatterStrength = math.min(es, 500) ^ 1.5 * 0.004
        for _, p in ipairs(orbitParticles) do
            -- Each particle gets a slightly different kick (inner ones react more)
            local innerFactor = 1.0 + (1.0 - p.baseRadius / 66) * 0.6
            p.scatterRadius = scatterStrength * innerFactor * (0.6 + math.random() * 0.8)
        end
    end

    -- Particles start spiraling in only after ball is 30% through its own animation
    local SPIRAL_DELAY = 0.30
    local delayedProg  = winProg > SPIRAL_DELAY
        and math.min((winProg - SPIRAL_DELAY) / (1.0 - SPIRAL_DELAY), 1.0)
        or  0.0

    -- Update & draw each orbiting cell
    for _, p in ipairs(orbitParticles) do
        -- Stutter kick every few seconds (suppressed during win spiral)
        if winProg == 0 then
            p.stutterTimer = p.stutterTimer - dt
            if p.stutterTimer <= 0 then
                p.stutterAcc   = (math.random() - 0.5) * 6.0
                p.stutterTimer = 1.2 + math.random() * 3.0
            end
            p.stutterAcc = p.stutterAcc * (1 - dt * 8)
        else
            p.stutterAcc = 0
        end

        -- Decay scatter impulse
        if p.scatterRadius > 0.1 then
            p.scatterRadius = p.scatterRadius * (1 - p.scatterDecay * dt)
        else
            p.scatterRadius = 0
        end

        -- During win: radius shrinks to zero using delayedProg (30% lag behind ball)
        local radFrac = delayedProg > 0
            and math.max(0.0, 1.0 - delayedProg ^ 0.75)
            or  1.0
        local effectiveBase = p.baseRadius * radFrac

        -- Angular speed: Kepler-like, faster as radius shrinks
        local speedMult = delayedProg > 0
            and (p.baseRadius / math.max(effectiveBase, 2))
            or  1.0
        p.angle = p.angle + (p.angSpeed + p.stutterAcc) * speedMult * dt

        -- Wobble amplitude also shrinks to zero during win
        local wobble = math.sin(time * p.wobbleFreq + p.wobbleOff)
                       * p.wobbleAmp * radFrac
        local r = effectiveBase + wobble + p.scatterRadius

        -- Perpendicular drift (also shrinks)
        local drift     = math.sin(time * p.driftFreq + p.driftOff)
                          * p.driftAmp * radFrac
        local perpAngle = p.angle + math.pi * 0.5

        local wx = centerX + math.cos(p.angle) * r + math.cos(perpAngle) * drift
        local wy = centerY + math.sin(p.angle) * r + math.sin(perpAngle) * drift

        -- Snap to game pixel grid (cell-aligned like every other block)
        local sx = math.floor(wx / CS) * CS
        local sy = math.floor(wy / CS) * CS

        local pulse  = math.sin(time * p.pulseFreq + p.pulseOff) * 0.5 + 0.5
        local bright = 0.55 + pulse * 0.45
        -- Fade out in the final 30% of win animation (mapped to delayedProg)
        local alpha  = delayedProg > 0.70
            and (1.0 - (delayedProg - 0.70) / 0.30)
            or  1.0

        love.graphics.setColor(
            p.col[1] * bright,
            p.col[2] * bright,
            p.col[3] * bright,
            alpha)
        love.graphics.rectangle("fill", sx, sy, CS, CS)
    end

    -- Pixelated rotating ring just outside the orbiting cloud
    -- Two rings: outer slow clockwise, inner faster counter-clockwise
    local ringAlpha = delayedProg > 0.60
        and (1.0 - (delayedProg - 0.60) / 0.40)
        or  1.0
    local ringScale = delayedProg > 0
        and math.max(0.0, 1.0 - delayedProg ^ 0.75)
        or  1.0

    local rings = {
        { radius = 82,  speed =  0.28, dots = 20, r = 0.50, g = 0.00, b = 0.72, a = 0.55 },
        { radius = 96,  speed = -0.18, dots = 14, r = 0.70, g = 0.10, b = 0.95, a = 0.35 },
    }
    for _, ring in ipairs(rings) do
        local ringRot = time * ring.speed
        local ringR   = ring.radius * ringScale
        local seen    = {}  -- deduplicate snapped positions
        for i = 0, ring.dots - 1 do
            local a = ringRot + (i / ring.dots) * math.pi * 2
            local wx = centerX + math.cos(a) * ringR
            local wy = centerY + math.sin(a) * ringR
            local sx = math.floor(wx / CS) * CS
            local sy = math.floor(wy / CS) * CS
            local key = sx .. "," .. sy
            if not seen[key] then
                seen[key] = true
                -- Individual dot brightness: slow twinkle
                local twinkle = math.sin(time * 3.0 + i * 1.3) * 0.5 + 0.5
                local b = 0.30 + twinkle * 0.55
                love.graphics.setColor(ring.r * b, ring.g * b, ring.b * b,
                                       ring.a * ringAlpha)
                love.graphics.rectangle("fill", sx, sy, CS, CS)
            end
        end
    end
end

-- Draw grid lines
function Renderer.drawGrid(minX, maxX, minY, maxY)
    local Cell = require("cell")
    
    love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
    for x = minX, maxX + 1 do
        love.graphics.line(x * Cell.SIZE, minY * Cell.SIZE, x * Cell.SIZE, (maxY + 1) * Cell.SIZE)
    end
    for y = minY, maxY + 1 do
        love.graphics.line(minX * Cell.SIZE, y * Cell.SIZE, (maxX + 1) * Cell.SIZE, y * Cell.SIZE)
    end
end

return Renderer
