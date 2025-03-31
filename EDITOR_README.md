# Square Golf Editor

The Square Golf Editor allows you to create and edit levels for the Square Golf game.

## Features

- Draw and edit levels using various cell types (dirt, sand, water, stone, etc.)
- Set the starting position for the ball
- Place win holes
- Configure which ball types are available in the level
- Save and load levels

## Controls

### General Controls

- **F12**: Toggle editor mode
- **Escape**: Return to menu (when not in editor mode)
- **Ctrl+S**: Save level
- **Ctrl+L**: Load level

### Editor Tools

- **1-9**: Select different cell types to place
- **Left Mouse Button**: Place selected cell type
- **Right Mouse Button**: Erase (place empty cell)
- **Middle Mouse Button**: Pick cell type under cursor
- **B**: Set ball starting position to cursor location
- **H**: Place win hole at cursor location
- **Tab**: Toggle available ball types menu

## File Manager

The editor includes a file manager that allows you to:

- Navigate through directories
- View files with appropriate icons based on type
- Save and load levels

### File Manager Controls

- **Click on breadcrumb path**: Navigate to that directory
- **Double-click on folder**: Open that folder
- **Double-click on JSON file**: Load that level (in load mode)
- **Click on file**: Select file (in save mode, updates filename)
- **Enter**: Confirm selection (save or load)
- **Escape**: Cancel and close file manager

### File Types

The file manager displays different icons for different file types:

- **Folders**: Yellow folder icon
- **JSON files**: Blue JSON icon
- **Lua files**: Blue Lua icon
- **Audio files**: Red audio icon
- **Image files**: Green image icon
- **Other files**: Gray generic file icon

## Creating a Level

1. Press **F12** to enter editor mode
2. Use the tools to draw your level:
   - Place dirt, sand, water, and other cell types
   - Set the ball starting position with **B**
   - Place a win hole with **H**
   - Click the **BOUNDARIES** button to automatically add stone walls around the level
3. Press **Ctrl+S** to save your level
4. Enter a name for your level and click **OK**

## Testing a Level

1. Create your level in the editor
2. Press **T** to test play your level
3. Press **R** to return to the editor

## Tips

- Use different cell types to create interesting challenges
- Place the win hole in a location that requires skill to reach
- Test your level frequently to ensure it's playable
- Consider which ball types should be available for your level
- Use the **BOUNDARIES** button to quickly add stone walls around your level
- Save your work often!
