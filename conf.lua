function love.conf(t)
    t.title = "Square Golf"        -- The title of the window
    t.version = "11.3"             -- The LÖVE version this game was made for
    
    -- Mobile-friendly configuration
    t.window.width = 1280          -- 16:9 aspect ratio, common for mobile
    t.window.height = 720          -- HD resolution, good balance for mobile
    t.window.resizable = true      -- Allow the window to be resized
    t.window.minwidth = 320        -- Lower minimum window width for mobile
    t.window.minheight = 180       -- Lower minimum window height for mobile
    
    -- VSync disabled by default
    t.window.vsync = 0             -- 0 = No VSync, 1 = VSync, 2 = Adaptive VSync
    
    -- Enable touch for all devices
    t.modules.joystick = false
    t.modules.touch = true         -- Always enable touch module
    t.modules.video = false
    
    -- Mobile-specific settings
    t.window.highdpi = true        -- Enable high-DPI mode for crisp rendering on mobile
    t.window.fullscreen = false    -- Start windowed, can be toggled to fullscreen
    t.window.fullscreentype = "desktop" -- "desktop" fullscreen uses the desktop resolution
end
