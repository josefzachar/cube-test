-- mobile_optimizations.lua - Performance optimizations for mobile devices

local MobileOptimizations = {}

-- Configuration
MobileOptimizations.enabled = false -- Will be set to true when on mobile
MobileOptimizations.particleReductionFactor = 0.5 -- Reduce particles by 50% on mobile
MobileOptimizations.maxActiveClusters = 20 -- Limit active clusters on mobile
MobileOptimizations.updateDistance = 15 -- Only update cells within this distance from the ball
MobileOptimizations.maxParticles = 100 -- Maximum number of particles on screen at once

-- Initialize mobile optimizations
function MobileOptimizations.init()
    print("Mobile optimizations initialized")
end

-- Apply particle reduction to a particle system
function MobileOptimizations.reduceParticles(particleSystem, originalCount)
    if not MobileOptimizations.enabled then
        return originalCount
    end
    
    -- Calculate reduced particle count
    local reducedCount = math.floor(originalCount * MobileOptimizations.particleReductionFactor)
    
    -- Ensure we have at least 1 particle
    reducedCount = math.max(1, reducedCount)
    
    -- Cap at maximum particles
    reducedCount = math.min(reducedCount, MobileOptimizations.maxParticles)
    
    return reducedCount
end

-- Check if a cluster should be updated based on distance from ball
function MobileOptimizations.shouldUpdateCluster(clusterX, clusterY, ballX, ballY, clusterSize)
    if not MobileOptimizations.enabled then
        return true -- Always update on desktop
    end
    
    -- Convert ball position to cluster coordinates
    local ballClusterX = math.floor(ballX / clusterSize)
    local ballClusterY = math.floor(ballY / clusterSize)
    
    -- Calculate distance in clusters
    local distX = math.abs(clusterX - ballClusterX)
    local distY = math.abs(clusterY - ballClusterY)
    local distance = math.sqrt(distX * distX + distY * distY)
    
    -- Only update clusters within the update distance
    return distance <= MobileOptimizations.updateDistance
end

-- Limit the number of active clusters
function MobileOptimizations.limitActiveClusters(activeClusters)
    if not MobileOptimizations.enabled then
        return activeClusters -- No limit on desktop
    end
    
    -- If we have too many active clusters, prioritize ones closest to the ball
    if #activeClusters > MobileOptimizations.maxActiveClusters then
        -- Sort clusters by distance to ball (assuming ball position is stored in the cluster)
        table.sort(activeClusters, function(a, b)
            local distA = a.distanceToBall or 0
            local distB = b.distanceToBall or 0
            return distA < distB
        end)
        
        -- Keep only the closest clusters
        while #activeClusters > MobileOptimizations.maxActiveClusters do
            table.remove(activeClusters)
        end
    end
    
    return activeClusters
end

-- Adjust update frequency based on device performance
function MobileOptimizations.getUpdateFrequency(fps)
    if not MobileOptimizations.enabled then
        return 1 -- Update every frame on desktop
    end
    
    -- Adjust update frequency based on FPS
    if fps < 30 then
        return 3 -- Update every 3 frames on low-end devices
    elseif fps < 45 then
        return 2 -- Update every 2 frames on mid-range devices
    else
        return 1 -- Update every frame on high-end devices
    end
end

-- Apply mobile-specific rendering optimizations
function MobileOptimizations.optimizeRendering()
    if not MobileOptimizations.enabled then
        return
    end
    
    -- Disable shader effects on mobile
    love.graphics.setShader()
    
    -- Use simpler drawing methods
    love.graphics.setLineStyle("rough") -- Use rough line style for better performance
    love.graphics.setLineWidth(1) -- Use minimum line width
end

-- Apply mobile-specific physics optimizations
function MobileOptimizations.optimizePhysics(world)
    if not MobileOptimizations.enabled then
        return
    end
    
    -- Reduce physics precision on mobile
    world:setCallbacks(nil, nil, nil, nil) -- Disable collision callbacks when not needed
end

return MobileOptimizations
