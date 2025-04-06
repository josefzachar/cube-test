-- editor/file.lua - File operations for the Square Golf editor

local CellTypes = require("src.cell_types")
local FileUI = require("src.editor.file_selector_ui")
local FileNavigation = require("src.editor.file_navigation")
local FileOperations = require("src.editor.file_operations")
local FileInput = require("src.editor.file_input")

local EditorFile = {
    editor = nil
}

-- Initialize the file module
function EditorFile.init(editor)
    EditorFile.editor = editor
    
    -- Create levels directory if it doesn't exist
    love.filesystem.createDirectory("levels")
    
    -- Add methods to the editor object for file_input.lua to call
    editor.saveLevel = function()
        EditorFile.saveLevel()
    end
    
    editor.loadLevel = function()
        EditorFile.loadLevel()
    end
    
    editor.navigateToDirectory = function(dirPath)
        EditorFile.navigateToDirectory(dirPath)
    end
end

-- Draw the file selector
function EditorFile.drawFileSelector()
    FileUI.drawFileSelector(EditorFile.editor)
end

-- Refresh the list of files
function EditorFile.refreshFileList()
    FileNavigation.refreshFileList(EditorFile.editor)
end

-- Update the breadcrumb path display
function EditorFile.updateBreadcrumbPath()
    FileNavigation.updateBreadcrumbPath(EditorFile.editor)
end

-- Save the current level
function EditorFile.saveLevel()
    -- If file selector is not active, show it first
    if not EditorFile.editor.fileSelector or not EditorFile.editor.fileSelector.active then
        FileNavigation.showFileSelector(EditorFile.editor, "save")
        return
    end
    
    -- Otherwise, delegate to FileOperations
    FileOperations.saveLevel(EditorFile.editor)
end

-- Helper function to ensure cell type is a valid CellTypes.TYPES value
function EditorFile.validateCellType(cellType)
    return FileOperations.validateCellType(cellType)
end

-- Load a level
function EditorFile.loadLevel()
    -- If file selector is not active, show it first
    if not EditorFile.editor.fileSelector or not EditorFile.editor.fileSelector.active then
        FileNavigation.showFileSelector(EditorFile.editor, "load")
        return
    end
    
    -- Otherwise, delegate to FileOperations
    FileOperations.loadLevel(EditorFile.editor)
end

-- Show file selector
function EditorFile.showFileSelector(mode)
    FileNavigation.showFileSelector(EditorFile.editor, mode)
end

-- Handle key press for file operations
function EditorFile.handleKeyPressed(key)
    return FileInput.handleKeyPressed(EditorFile.editor, key)
end

-- Handle text input for file operations
function EditorFile.handleTextInput(text)
    return FileInput.handleTextInput(EditorFile.editor, text)
end

-- Navigate to a directory
function EditorFile.navigateToDirectory(dirPath)
    FileNavigation.navigateToDirectory(EditorFile.editor, dirPath)
end

-- Handle mouse press in file selector
function EditorFile.handleMousePressed(x, y, button)
    return FileInput.handleMousePressed(EditorFile.editor, x, y, button)
end

return EditorFile
