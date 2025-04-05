-- editor/init.lua - Main editor module for Square Golf

local EditorCore = require("src.editor.core")

-- This is the main entry point for the editor
-- It simply forwards all calls to the EditorCore module
local Editor = {}

-- Initialize the editor
function Editor.init(level, world)
    return EditorCore.init(level, world)
end

-- Update the editor
function Editor.update(dt)
    return EditorCore.update(dt)
end

-- Draw the editor
function Editor.draw()
    return EditorCore.draw()
end

-- Handle key press in editor
function Editor.handleKeyPressed(key)
    return EditorCore.handleKeyPressed(key)
end

-- Handle key release in editor
function Editor.handleKeyReleased(key)
    return EditorCore.handleKeyReleased(key)
end

-- Handle text input in editor
function Editor.handleTextInput(text)
    return EditorCore.handleTextInput(text)
end

-- Handle mouse press in editor
function Editor.handleMousePressed(x, y, button)
    return EditorCore.handleMousePressed(x, y, button)
end

-- Handle mouse release in editor
function Editor.handleMouseReleased(x, y, button)
    return EditorCore.handleMouseReleased(x, y, button)
end

-- Handle mouse wheel in editor
function Editor.handleMouseWheel(x, y)
    return EditorCore.handleMouseWheel(x, y)
end

-- Test play the level
function Editor.testPlay()
    return EditorCore.testPlay()
end

-- Return to editor after test play
function Editor.returnFromTestPlay()
    return EditorCore.returnFromTestPlay()
end

-- Forward all other properties to EditorCore
setmetatable(Editor, {
    __index = function(_, key)
        return EditorCore[key]
    end,
    __newindex = function(_, key, value)
        EditorCore[key] = value
    end
})

return Editor
