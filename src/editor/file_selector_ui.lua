-- editor/file_selector_ui.lua - File selector UI for the Square Golf editor

local EditorFileUI = {}

-- Draw the file selector
function EditorFileUI.drawFileSelector(editor)
    if not editor.fileSelector.active then
        return
    end
    
    -- Save current graphics state
    love.graphics.push()
    
    -- Reset transformation to draw UI in screen coordinates
    love.graphics.origin()
    
    -- Get screen dimensions
    local screenWidth, screenHeight = love.graphics.getDimensions()
    
    -- Dialog dimensions
    local dialogWidth = 600
    local dialogHeight = 500
    local dialogX = (screenWidth - dialogWidth) / 2
    local dialogY = (screenHeight - dialogHeight) / 2
    
    -- Draw dialog background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", dialogX, dialogY, dialogWidth, dialogHeight)
    
    -- Draw dialog border
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX, dialogY, dialogWidth, dialogHeight)
    
    -- Draw dialog title
    love.graphics.setColor(1, 1, 1, 1)
    local title = editor.fileSelector.mode == "save" and "Save Level" or "Load Level"
    love.graphics.print(title, dialogX + 20, dialogY + 20)
    
    -- Draw breadcrumb path
    local breadcrumbY = dialogY + 50
    local breadcrumbX = dialogX + 20
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    
    if editor.fileSelector.breadcrumbs then
        for i, crumb in ipairs(editor.fileSelector.breadcrumbs) do
            -- Draw breadcrumb
            love.graphics.setColor(0.2, 0.5, 0.8, 1)
            local crumbWidth = love.graphics.getFont():getWidth(crumb.name) + 20
            love.graphics.rectangle("fill", breadcrumbX, breadcrumbY, crumbWidth, 20)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(crumb.name, breadcrumbX + 10, breadcrumbY + 2)
            
            -- Store breadcrumb position for click detection
            crumb.x = breadcrumbX
            crumb.y = breadcrumbY
            crumb.width = crumbWidth
            crumb.height = 20
            
            breadcrumbX = breadcrumbX + crumbWidth + 5
            
            -- Draw separator if not the last breadcrumb
            if i < #editor.fileSelector.breadcrumbs then
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
                love.graphics.print(">", breadcrumbX - 3, breadcrumbY + 2)
                breadcrumbX = breadcrumbX + 10
            end
        end
    end
    
    -- Draw file list
    local fileListY = breadcrumbY + 30
    local fileListHeight = dialogHeight - 180
    local fileItemHeight = 30
    
    -- Draw file list background
    love.graphics.setColor(0.1, 0.1, 0.2, 1)
    love.graphics.rectangle("fill", dialogX + 20, fileListY, dialogWidth - 40, fileListHeight)
    
    -- Draw file list border
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX + 20, fileListY, dialogWidth - 40, fileListHeight)
    
    -- Draw files
    local visibleFiles = math.floor(fileListHeight / fileItemHeight)
    local startIndex = math.max(1, editor.fileSelector.selectedIndex - math.floor(visibleFiles / 2))
    startIndex = math.min(startIndex, math.max(1, #editor.fileSelector.files - visibleFiles + 1))
    
    for i = 0, visibleFiles - 1 do
        local fileIndex = startIndex + i
        if fileIndex <= #editor.fileSelector.files then
            local file = editor.fileSelector.files[fileIndex]
            local itemY = fileListY + i * fileItemHeight
            
            -- Draw selection highlight
            if fileIndex == editor.fileSelector.selectedIndex then
                love.graphics.setColor(0.3, 0.3, 0.6, 1)
                love.graphics.rectangle("fill", dialogX + 20, itemY, dialogWidth - 40, fileItemHeight)
            end
            
            -- Draw file icon based on type
            love.graphics.setColor(1, 1, 1, 1)
            if file.isDirectory then
                -- Draw folder icon
                love.graphics.setColor(0.9, 0.7, 0.2, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 15)
                love.graphics.setColor(0.7, 0.5, 0.1, 1)
                love.graphics.rectangle("fill", dialogX + 25, itemY + 10, 30, 15)
            elseif file.fileType == "json" then
                -- Draw JSON file icon
                love.graphics.setColor(0.2, 0.6, 0.8, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
                love.graphics.setColor(0, 0, 0, 1)
                love.graphics.print("{ }", dialogX + 32, itemY + 7)
            elseif file.fileType == "lua" then
                -- Draw Lua file icon
                love.graphics.setColor(0.2, 0.2, 0.8, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("lua", dialogX + 32, itemY + 7)
            elseif file.fileType == "audio" then
                -- Draw audio file icon
                love.graphics.setColor(0.8, 0.2, 0.2, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("♪", dialogX + 35, itemY + 7)
            elseif file.fileType == "image" then
                -- Draw image file icon
                love.graphics.setColor(0.2, 0.8, 0.2, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("IMG", dialogX + 32, itemY + 7)
            else
                -- Draw generic file icon
                love.graphics.setColor(0.7, 0.7, 0.7, 1)
                love.graphics.rectangle("fill", dialogX + 30, itemY + 5, 20, 20)
            end
            
            -- Draw file name
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(file.displayName, dialogX + 60, itemY + 5)
            
            -- Store file item position for double-click detection
            file.x = dialogX + 20
            file.y = itemY
            file.width = dialogWidth - 40
            file.height = fileItemHeight
        end
    end
    
    -- Draw buttons
    local buttonWidth = 100
    local buttonHeight = 30
    local buttonSpacing = 20
    local buttonsY = dialogY + dialogHeight - 50
    
    -- Draw OK button
    love.graphics.setColor(0.2, 0.2, 0.4, 1)
    love.graphics.rectangle("fill", dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing, buttonsY, buttonWidth, buttonHeight)
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing, buttonsY, buttonWidth, buttonHeight)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("OK", dialogX + dialogWidth - buttonWidth - buttonSpacing - buttonWidth - buttonSpacing + 40, buttonsY + 5)
    
    -- Draw Cancel button
    love.graphics.setColor(0.2, 0.2, 0.4, 1)
    love.graphics.rectangle("fill", dialogX + dialogWidth - buttonWidth - buttonSpacing, buttonsY, buttonWidth, buttonHeight)
    love.graphics.setColor(0, 0.8, 0.8, 1)
    love.graphics.rectangle("line", dialogX + dialogWidth - buttonWidth - buttonSpacing, buttonsY, buttonWidth, buttonHeight)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Cancel", dialogX + dialogWidth - buttonWidth - buttonSpacing + 25, buttonsY + 5)
    
    -- Draw filename input for save mode
    if editor.fileSelector.mode == "save" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("Filename:", dialogX + 20, buttonsY - 40)
        
        -- Draw input background
        love.graphics.setColor(0.1, 0.1, 0.2, 1)
        love.graphics.rectangle("fill", dialogX + 100, buttonsY - 40, dialogWidth - 120, 25)
        
        -- Draw input border
        love.graphics.setColor(0, 0.8, 0.8, 1)
        love.graphics.rectangle("line", dialogX + 100, buttonsY - 40, dialogWidth - 120, 25)
        
        -- Draw input text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(editor.fileSelector.newFileName, dialogX + 110, buttonsY - 35)
    end
    
    -- Restore previous graphics state
    love.graphics.pop()
end

return EditorFileUI
