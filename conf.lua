function love.conf(t)
    t.title = "Square Golf"        -- The title of the window
    t.version = "11.3"             -- The LÖVE version this game was made for
    t.window.width = 1600          -- The window width
    t.window.height = 1000         -- The window height
    
    -- Disable VSync to allow unlimited FPS
    t.window.vsync = 0             -- 0 = No VSync, 1 = VSync, 2 = Adaptive VSync
    
    -- For simplicity, we'll disable unused modules
    t.modules.joystick = false
    t.modules.touch = false
    t.modules.video = false
end
