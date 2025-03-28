# Square Golf Level Editor

The Square Golf Level Editor allows you to create and test custom levels for the game. This document explains how to use the editor effectively.

## Getting Started

To access the editor, you can:
1. Press F12 during gameplay to toggle the editor mode
2. Select "Editor" from the main menu

## Editor Interface

The editor interface consists of:
- Left panel: Tools and cell types
- Right panel: Level settings and actions
- Main area: Level grid where you can draw and edit cells

## Tools

The editor provides several tools to help you create levels:

### Draw Tool (D)
- Allows you to place cells of the selected type
- Use the brush size controls to adjust the drawing area

### Erase Tool (E)
- Removes cells, setting them to empty
- Also uses the brush size setting

### Fill Tool (F)
- Fills an area with the selected cell type
- Click on a cell to fill all connected cells of the same type

### Start Position Tool (S)
- Sets the starting position for the ball
- Creates a clear area around the start position

### Win Hole Tool (W)
- Creates a win hole at the selected position
- The player must reach this to complete the level

## Cell Types

You can place different types of cells in your level:

- **EMPTY**: Clear space where the ball can move freely
- **DIRT**: Basic terrain that can be destroyed
- **SAND**: Loose terrain that slows the ball
- **STONE**: Solid terrain that cannot be destroyed
- **WATER**: Liquid that affects ball physics
- **FIRE**: Hazard that can destroy certain balls

## Controls

### Keyboard Shortcuts

- **D**: Select Draw tool
- **E**: Select Erase tool
- **F**: Select Fill tool
- **S**: Select Start Position tool
- **W**: Select Win Hole tool
- **1-5**: Select cell types (DIRT, SAND, STONE, WATER, FIRE)
- **+/-**: Increase/decrease brush size
- **G**: Toggle grid display
- **Space**: Toggle UI visibility
- **Ctrl+S**: Save level
- **Ctrl+L**: Load level
- **Escape**: Exit editor

### Mouse Controls

- **Left Click**: Use the selected tool
- **Right Click**: Cancel current action

## Ball Types

You can specify which ball types are available in your level:

- **Standard Ball**: Basic ball with normal physics
- **Heavy Ball**: Heavier ball that breaks through terrain more easily
- **Exploding Ball**: Can be detonated to destroy surrounding terrain
- **Sticky Ball**: Can stick to surfaces

## Saving and Loading Levels

- Click the "SAVE" button to save your level
- Click the "LOAD" button to load an existing level
- Levels are saved in the "levels" directory with a .json extension

## Testing Your Level

- Click the "TEST PLAY" button to play your level
- This allows you to test the level without exiting the editor
- Click the "TO EDITOR" button to return to editing

## Tips for Good Level Design

1. **Start Simple**: Begin with a clear path and gradually add challenges
2. **Balance Difficulty**: Make levels challenging but not frustrating
3. **Create Multiple Paths**: Give players different ways to solve the level
4. **Use Terrain Variety**: Mix different cell types for interesting gameplay
5. **Test Thoroughly**: Make sure your level is possible to complete
6. **Consider Ball Types**: Design with different ball abilities in mind

## Example Level Creation Process

1. Clear the level using the "CLEAR" button
2. Use the Start Position tool to set where the ball begins
3. Create the basic terrain using the Draw tool with DIRT cells
4. Add challenges with SAND, WATER, and other cell types
5. Place a win hole at the destination
6. Test play your level to ensure it works as expected
7. Make adjustments as needed
8. Save your level with a descriptive name

Enjoy creating your own Square Golf levels!
