-- editor/file_input.lua - Input handling for the Square Golf editor file operations

local FileInput = {}

-- Handle key press for file operations
function FileInput.handleKeyPressed(editor, key)
    -- Save level with Ctrl+S
    if key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- This will be handled by the main file.lua
        if editor.saveLevel then
            editor.saveLevel()
            return true
        end
    end
    
    -- Load level with Ctrl+L
    if key == "l" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        -- This will be handled by the main file.lua
        if editor.loadLevel then
            editor.loadLevel()
            return true
        end
    end
    
    -- Handle file selector key presses
    if editor.fileSelector and editor.fileSelector.active then
        if key == "escape" then
            editor.fileSelector.active = false
            return true
        elseif key == "return" then
            if editor.fileSelector.mode == "save" then
                -- This will be handled by the main file.lua
                if editor.saveLevel then
                    editor.saveLevel()
                end
            else
                -- This will be handled by the main file.lua
                if editor.loadLevel then
                    editor.loadLevel()
                end
            end
            return true
        elseif key == "up" then
            editor.fileSelector.selectedIndex = math.max(1, editor.fileSelector.selectedIndex - 1)
            return true
        elseif key == "down" then
            editor.fileSelector.selectedIndex = math.min(#editor.fileSelector.files, editor.fileSelector.selectedIndex + 1)
            return true
        elseif key == "backspace" and editor.fileSelector.mode == "save" then
            if #editor.fileSelector.newFileName > 0 then
                editor.fileSelector.newFileName = string.sub(editor.fileSelector.newFileName, 1, -2)
            end
            return true
        end
    end
    
    return false
end

-- Handle text input for file operations
function FileInput.handleTextInput(editor, text)
    -- Handle file selector text input
    if editor.fileSelector and editor.fileSelector.active and editor.fileSelector.mode == "save" then
        editor.fileSelector.newFileName = editor.fileSelector.newFileName .. text
        return true
    end
    
    return false
end

-- Handle mouse press in file selector
function FileInput.handleMousePressed(editor, x, y, button)
    if not editor.fileSelector.active then
        return false
    end
    
    -- Always return true when file selector is active to prevent painting
    -- This ensures that no other mouse handlers will process this event
    
    -- Use raw screen coordinates for UI elements
    local screenX, screenY = x, y
    
    -- Get screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Dialog dimensions
    local dialogWidth = 600
    local dialogHeight = 500
    local dialogX = (screenWidth - dialogWidth) / 2
    local dialogY = (screenHeight - dialogHeight) / 2
    
    -- Check if clicking on breadcrumbs
    if editor.fileSelector.breadcrumbs then
        for _, crumb in ipairs(editor.fileSelector.breadcrumbs) do
            if crumb.x and crumb.y and crumb.width and crumb.height then
                if screenX >= crumb.x and screenX <= crumb.x + crumb.width and
                   screenY >= crumb.y and screenY <= crumb.y + crumb.height then
                    -- Navigate to the clicked breadcrumb path
                    if editor.navigateToDirectory then
                        editor.navigateToDirectory(crumb.path)
                    end
                    return true
                end
            end
        end
    end
    
    -- File list dimensions
    local breadcrumbY = dialogY + 50
    local fileListY = breadcrumbY + 30
    local fileListHeight = dialogHeight - 180
    local fileItemHeight = 30
    
    -- Check if clicking in file list
    if screenX >= dialogX + 20 and screenX <= dialogX + dialogWidth - 20 and
       screenY >= fileListY and screenY <= fileListY + fileListHeight then
        -- Calculate which file was clicked
        local visibleFiles = math.floor(fileListHeight / fileItemHeight)
        local startIndex = math.max(1, editor.fileSelector.selectedIndex - math.floor(visibleFiles / 2))
        startIndex = math.min(startIndex, math.max(1, #editor.fileSelector.files - visibleFiles + 1))
        
        local clickedIndex = startIndex + math.floor((screenY - fileListY) / fileItemHeight)
        if clickedIndex >= 1 and clickedIndex <= #editor.fileSelector.files then
            local clickedFile = editor.fileSelector.files[clickedIndex]
            editor.fileSelector.selectedIndex = clickedIndex
            
            -- Check for double-click
            local currentTime = love.timer.getTime()
            local lastClickTime = editor.fileSelector.lastClickTime or 0
            local lastClickIndex = editor.fileSelector.lastClickIndex or 0
            
            -- Store current click info for double-click detection
            editor.fileSelector.lastClickTime = currentTime
            editor.fileSelector.lastClickIndex = clickedIndex
            
            -- Check if this is a double-click on the same item
            if currentTime - lastClickTime < 0.5 and clickedIndex == lastClickIndex then
                -- Handle double-click
                if clickedFile.isDirectory then
                    -- Navigate to directory
                    if clickedFile.isParentDir then
                        -- Go to parent directory
                        local currentDir = editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
                        local parentDir = string.match(currentDir, "(.+)/[^/]+$") or "/"
                        if editor.navigateToDirectory then
                            editor.navigateToDirectory(parentDir)
                        end
                    else
                        -- Go to subdirectory
                        local currentDir = editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
                        local newDir = currentDir .. "/" .. clickedFile.filename
                        if editor.navigateToDirectory then
                            editor.navigateToDirectory(newDir)
                        end
                    end
                elseif clickedFile.fileType == "json" and editor.fileSelector.mode == "load" then
                    -- Load the JSON file
                    if editor.loadLevel then
                        editor.loadLevel()
                    end
                end
                return true
            end
            
            -- If in save mode, update the filename
            if editor.fileSelector.mode == "save" then
                if not clickedFile.isDirectory then
                    editor.fileSelector.newFileName = clickedFile.displayName
                end
            end
            
            return true
        end
    end
    
    -- Button dimensions
    local buttonWidth = 100
    local buttonHeight = 30
    local buttonSpacing = 20
    local buttonsY = dialogY + dialogHeight - 50
    
    -- Check if clicking OK button
    if screenX >= dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing and
       screenX <= dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonSpacing and
       screenY >= buttonsY and screenY <= buttonsY + buttonHeight then
        -- OK button clicked
        if editor.fileSelector.mode == "save" then
            if editor.saveLevel then
                editor.saveLevel()
            end
        else
            -- Check if selected item is a directory
            local selectedFile = editor.fileSelector.files[editor.fileSelector.selectedIndex]
            if selectedFile and selectedFile.isDirectory then
                -- Navigate to directory
                if selectedFile.isParentDir then
                    -- Go to parent directory
                    local currentDir = editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
                    local parentDir = string.match(currentDir, "(.+)/[^/]+$") or "/"
                    if editor.navigateToDirectory then
                        editor.navigateToDirectory(parentDir)
                    end
                else
                    -- Go to subdirectory
                    local currentDir = editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
                    local newDir = currentDir .. "/" .. selectedFile.filename
                    if editor.navigateToDirectory then
                        editor.navigateToDirectory(newDir)
                    end
                end
            else
                -- Load the selected file
                if editor.loadLevel then
                    editor.loadLevel()
                end
            end
        end
        return true
    end
    
    -- Check if clicking Cancel button
    if screenX >= dialogX + dialogWidth - buttonWidth - buttonSpacing and
       screenX <= dialogX + dialogWidth - buttonSpacing and
       screenY >= buttonsY and screenY <= buttonsY + buttonHeight then
        -- Cancel button clicked
        editor.fileSelector.active = false
        return true
    end
    
    -- If clicking outside the dialog, close it
    if screenX < dialogX or screenX > dialogX + dialogWidth or
       screenY < dialogY or screenY > dialogY + dialogHeight then
        editor.fileSelector.active = false
        return true
    end
    
    return true
end

return FileInput
