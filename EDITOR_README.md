# Square Golf Level Editor

The Square Golf Level Editor allows you to create, save, and load custom levels for the game.

## Accessing the Editor

Press `F12` at any time during gameplay to toggle the editor mode.

## Editor Controls

### Basic Controls
- `F12`: Toggle editor mode on/off
- `Escape`: Exit editor mode
- `G`: Toggle grid display

### Drawing Tools
- `1`: Select Empty tool (eraser)
- `2`: Select Dirt tool
- `3`: Select Sand tool
- `4`: Select Stone tool
- `5`: Select Water tool
- `6`: Select Win Hole tool

### Brush Size
- `+` or `=`: Increase brush size
- `-`: Decrease brush size

### Level Management
- `Ctrl+S`: Save the current level
- `Ctrl+L`: Load a level

## Editor Interface

The editor interface consists of two panels:
- **Left Panel**: Contains drawing tools and brush size options
- **Right Panel**: Contains level management options and ball type selection

### Left Panel Options
- **EMPTY**: Erases cells
- **DIRT**: Places dirt blocks
- **SAND**: Places sand that can be destroyed
- **STONE**: Places solid stone blocks
- **WATER**: Places water
- **WIN_HOLE**: Places win holes
- **SIZE 1-7**: Select brush size

### Right Panel Options
- **SAVE**: Save the current level
- **LOAD**: Load a saved level
- **CLEAR**: Clear the current level
- **SET NAME**: Set the level name
- **SET START**: Set the ball starting position
- **TOGGLE GRID**: Toggle grid display
- **TEST PLAY**: Test play the current level
- **EXIT EDITOR**: Exit editor mode
- **Ball Selection**: Toggle which ball types are available in the level

## Creating a Level

1. Press `F12` to enter editor mode
2. Use the drawing tools to create your level
3. Set the starting position using the "SET START" button
4. Select which ball types are available
5. Set the level name using the "SET NAME" button
6. Save your level using the "SAVE" button or `Ctrl+S`

## Testing a Level

Click the "TEST PLAY" button to test your level. This will exit the editor and place a ball at the starting position you set.

## Loading a Level

Click the "LOAD" button or press `Ctrl+L` to load a saved level. The editor will load the first level file it finds in the "levels" directory.

## Tips for Level Design

- Create a clear path from the starting position to the win hole
- Use different cell types to create interesting challenges
- Make sure the level is possible to complete
- Test your level frequently to ensure it plays well
