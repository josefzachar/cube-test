-- sound.lua - Sound management for Square Golf

local CellTypes = require("src.cell_types")

local Sound = {}

-- Table to store sound effects
Sound.sounds = {}

-- Flag to check if sounds are loaded
Sound.loaded = false

-- Volume settings
Sound.volume = 0.7 -- Default volume (0.0 to 1.0)

-- Function to load all sound effects
function Sound.load()
    -- Only load sounds once
    if Sound.loaded then
        return
    end
    
    -- Create a sounds directory if it doesn't exist
    if not love.filesystem.getInfo("sounds") then
        love.filesystem.createDirectory("sounds")
        print("Created sounds directory. Please add sound files.")
    end
    
    -- Try to load sound files (supports both WAV and MP3)
    local soundFiles = {
        grass = {"sounds/grass_hit.mp3"},
        dirt = {"sounds/dirt_hit.mp3"},
        sand = {"sounds/sand_hit.mp3"},
        water = {"sounds/water_hit.mp3"},
        stone = {"sounds/stone_hit.mp3"}
    }
    
    -- Load each sound file if it exists
    for name, paths in pairs(soundFiles) do
        local loaded = false
        
        -- Try each file format (MP3 first, then WAV)
        for _, path in ipairs(paths) do
            if love.filesystem.getInfo(path) then
                Sound.sounds[name] = love.audio.newSource(path, "static")
                Sound.sounds[name]:setVolume(Sound.volume)
                print("Loaded sound: " .. name .. " from " .. path)
                loaded = true
                break -- Stop after finding the first valid file
            end
        end
        
        -- If no file was found, create a placeholder
        if not loaded then
            print("Warning: Sound file not found for: " .. name)
            -- Create a placeholder sound (1 second of silence)
            local silenceData = love.sound.newSoundData(44100, 44100, 16, 1)
            Sound.sounds[name] = love.audio.newSource(silenceData)
            Sound.sounds[name]:setVolume(0) -- Mute the placeholder
        end
    end
    
    Sound.loaded = true
    print("Sound system initialized")
end

-- Function to play a sound with optional parameters
function Sound.play(name, volume, pitch)
    -- Check if sounds are loaded
    if not Sound.loaded then
        Sound.load()
    end
    
    -- Check if the sound exists
    if not Sound.sounds[name] then
        print("Warning: Sound not found: " .. name)
        return
    end
    
    -- Clone the source to allow overlapping sounds
    local source = Sound.sounds[name]:clone()
    
    -- Apply volume if provided
    if volume then
        source:setVolume(volume * Sound.volume)
    end
    
    -- Apply pitch if provided
    if pitch then
        source:setPitch(pitch)
    end
    
    -- Play the sound
    source:play()
    
    return source
end

-- Function to play a sound based on the cell type
function Sound.playCollisionSound(cellType, speed)
    -- Calculate volume based on impact speed with improved scaling
    -- Minimum speed threshold to play any sound
    local minSpeedThreshold = 20
    
    -- No sound for very low speeds
    if speed < minSpeedThreshold then
        return
    end
    
    -- Adjust speed to be relative to the threshold
    local adjustedSpeed = speed - minSpeedThreshold
    
    -- Use a non-linear (quadratic) curve for more dynamic volume scaling
    -- This makes soft impacts quieter and hard impacts louder
    local volumeScale = (adjustedSpeed / 380) ^ 1.5
    
    -- Clamp volume between 0.1 (very quiet) and 1.0 (full volume)
    local volume = math.max(0.1, math.min(1.0, volumeScale))
    
    -- Adjust pitch slightly based on speed - faster impacts have higher pitch
    local pitchVariation = math.random() * 0.2 - 0.1 -- Random variation of ±0.1
    local speedPitchFactor = math.min(0.2, speed / 1000) -- Up to 0.2 higher pitch for fast impacts
    local pitch = 1.0 + pitchVariation + speedPitchFactor
    
    -- Play different sounds based on cell type
    if cellType == CellTypes.TYPES.SAND then
        Sound.play("sand", volume, pitch)
    elseif cellType == CellTypes.TYPES.DIRT then
        Sound.play("dirt", volume, pitch)
    elseif cellType == CellTypes.TYPES.STONE then
        Sound.play("stone", volume, pitch)
    elseif cellType == CellTypes.TYPES.WATER then
        Sound.play("water", volume, pitch)
    else
        -- Default to grass sound for empty cells or other types
        Sound.play("grass", volume, pitch)
    end
end

-- Function to set the master volume
function Sound.setVolume(volume)
    Sound.volume = math.max(0, math.min(1, volume))
    
    -- Update volume for all loaded sounds
    for _, source in pairs(Sound.sounds) do
        source:setVolume(Sound.volume)
    end
end

return Sound
