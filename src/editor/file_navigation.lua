-- editor/file_navigation.lua - File navigation for the Square Golf editor

local FileNavigation = {}

-- Refresh the list of files
function FileNavigation.refreshFileList(editor)
    editor.fileSelector.files = {}
    
    -- Get the current directory
    local currentDir = editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
    print("Looking for files in: " .. currentDir)
    
    -- Add parent directory entry if not at root
    if currentDir ~= "/" then
        table.insert(editor.fileSelector.files, {
            filename = "..",
            displayName = "..",
            isDirectory = true,
            isParentDir = true
        })
    end
    
    -- List directories first
    local dirs = {}
    local dirCmd = io.popen('find "' .. currentDir .. '" -maxdepth 1 -type d -not -path "' .. currentDir .. '" | sort')
    if dirCmd then
        for dir in dirCmd:lines() do
            -- Extract the directory name from the full path
            local dirName = string.match(dir, ".*/([^/]+)$")
            if dirName and dirName ~= "." and dirName ~= ".." then
                table.insert(dirs, {
                    filename = dirName,
                    displayName = dirName,
                    isDirectory = true,
                    fullPath = dir
                })
            end
        end
        dirCmd:close()
    end
    
    -- Sort directories alphabetically
    table.sort(dirs, function(a, b)
        return a.displayName:lower() < b.displayName:lower()
    end)
    
    -- Add directories to the file list
    for _, dir in ipairs(dirs) do
        table.insert(editor.fileSelector.files, dir)
    end
    
    -- List files
    local files = {}
    local fileCmd = io.popen('find "' .. currentDir .. '" -maxdepth 1 -type f | sort')
    if fileCmd then
        for file in fileCmd:lines() do
            -- Extract the file name from the full path
            local fileName = string.match(file, ".*/([^/]+)$")
            if fileName then
                local fileType = "file"
                local displayName = fileName
                
                -- Determine file type based on extension
                if string.match(fileName, "%.json$") then
                    fileType = "json"
                    -- For JSON files, remove extension and replace underscores with spaces
                    displayName = string.gsub(string.sub(fileName, 1, -6), "_", " ")
                elseif string.match(fileName, "%.lua$") then
                    fileType = "lua"
                elseif string.match(fileName, "%.txt$") then
                    fileType = "text"
                elseif string.match(fileName, "%.mp3$") or string.match(fileName, "%.wav$") then
                    fileType = "audio"
                elseif string.match(fileName, "%.png$") or string.match(fileName, "%.jpg$") then
                    fileType = "image"
                end
                
                table.insert(files, {
                    filename = fileName,
                    displayName = displayName,
                    fileType = fileType,
                    fullPath = file
                })
            end
        end
        fileCmd:close()
    end
    
    -- Sort files alphabetically
    table.sort(files, function(a, b)
        return a.displayName:lower() < b.displayName:lower()
    end)
    
    -- Add files to the file list
    for _, file in ipairs(files) do
        table.insert(editor.fileSelector.files, file)
    end
    
    -- Update breadcrumb path
    FileNavigation.updateBreadcrumbPath(editor)
end

-- Update the breadcrumb path display
function FileNavigation.updateBreadcrumbPath(editor)
    local currentDir = editor.fileSelector.currentDir or "/Users/joebrain/cube-test"
    
    -- Split the path into components
    local pathComponents = {}
    for component in string.gmatch(currentDir, "[^/]+") do
        table.insert(pathComponents, component)
    end
    
    -- Create breadcrumb path
    local breadcrumbPath = "/"
    editor.fileSelector.breadcrumbs = {
        { path = "/", name = "Root" }
    }
    
    local currentPath = ""
    for i, component in ipairs(pathComponents) do
        currentPath = currentPath .. "/" .. component
        table.insert(editor.fileSelector.breadcrumbs, {
            path = currentPath,
            name = component
        })
        breadcrumbPath = breadcrumbPath .. component .. "/"
    end
    
    editor.fileSelector.breadcrumbPath = breadcrumbPath
end

-- Navigate to a directory
function FileNavigation.navigateToDirectory(editor, dirPath)
    -- Update current directory
    editor.fileSelector.currentDir = dirPath
    
    -- Reset selected index
    editor.fileSelector.selectedIndex = 1
    
    -- Refresh file list
    FileNavigation.refreshFileList(editor)
    
    print("Navigated to directory: " .. dirPath)
end

-- Show file selector
function FileNavigation.showFileSelector(editor, mode)
    -- Initialize file selector if not already done
    if not editor.fileSelector then
        editor.fileSelector = {
            active = false,
            mode = "load",
            files = {},
            selectedIndex = 1,
            newFileName = "",
            currentDir = "/Users/joebrain/cube-test",
            breadcrumbs = {},
            lastClickTime = 0,
            lastClickIndex = 0
        }
    end
    
    -- Set file selector mode
    editor.fileSelector.mode = mode
    editor.fileSelector.active = true
    editor.fileSelector.selectedIndex = 1
    
    -- If in save mode, navigate to levels directory
    if mode == "save" and not editor.fileSelector.inLevelsDir then
        FileNavigation.navigateToDirectory(editor, "/Users/joebrain/cube-test/levels")
        editor.fileSelector.inLevelsDir = true
    else
        -- Refresh file list
        FileNavigation.refreshFileList(editor)
    end
    
    -- Set default filename for save mode
    if mode == "save" then
        editor.fileSelector.newFileName = editor.levelName
    end
end

return FileNavigation
