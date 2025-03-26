# Square Golf with Cellular Automata

A physics-based golf game where the ball is a square and the level is made of cells that behave like cellular automata. The game is viewed from the side and features interactive sand that can be disrupted by the ball.

## How to Play

1. Install LÖVE (Love2D) from https://love2d.org/
2. Run the game by either:
   - Dragging the game folder onto the LÖVE executable
   - Running `love .` from the command line in the game directory

## Game Controls

- **Mouse**: Aim the ball (direction and power)
- **Left Click**: Shoot the square ball
- **R**: Reset the ball to the starting position
- **D**: Toggle debug mode
- **S**: Add 1000 random sand cells (for performance testing)
- **P**: Add a sand pile at the ball's position
- **E**: Add a dirt block at the ball's position
- **Q**: Add a water pool at the ball's position
- **G**: Generate a new procedural level
- **W**: Create a water test level
- **T**: Create a dirt-water test level

## Game Features

### Physics-Based Square Ball
- The ball is a square that rotates and bounces realistically
- Aim and shoot with the mouse to navigate through the level

### Cellular Automata Sand
- Sand cells behave like traditional sand simulations:
  - Sand falls downward due to gravity
  - Sand piles up naturally at angles of repose
  - When hit by the ball, sand can be disrupted and sent flying

### Four Types of Terrain
- **Sand**: Can be disrupted by the ball, behaves like cellular automata, falls and forms piles
- **Stone**: Solid obstacles that the ball bounces off of
- **Dirt**: More durable than sand, doesn't fall but can be displaced by the ball
- **Water**: Flows like a liquid, the ball can pass through it with altered physics

### Hybrid Physics System
- Sand normally follows cellular automata rules
- When sand is hit by the ball with enough force, it temporarily becomes physics-based
- Flying sand eventually settles back into cellular automata behavior

### Procedural Level Generation
- The game features a procedural level generator that creates unique levels each time
- Generated levels include:
  - Dirt terrain as the main landscape
  - Stone structures for variety and challenge
  - Winding tunnels for the ball to navigate through
  - Occasional water ponds that add fluid dynamics
  - Strategic sand traps that can slow down the ball
- Press 'G' at any time to generate a new procedural level

## Performance Optimizations

The game includes several optimizations to handle large numbers of sand cells efficiently:

### Cluster-Based Updates
- The level is divided into clusters (8x8 cells by default)
- Only active clusters are updated every frame
- Inactive clusters are updated less frequently (staggered updates)
- Clusters are marked as active when:
  - They are near the ball
  - They contain cells that changed recently
  - They are below clusters with active cells (for falling sand)

### Selective Cell Updates
- Only cells that need updating are processed
- Cells track whether they've changed and mark themselves as active
- Empty and stone cells are skipped entirely during updates
- Visual sand particles are always updated for smooth animation

### Debug Visualization
- Toggle debug mode (D key) to see performance metrics:
  - FPS counter
  - Cell counts by type
  - Active cluster count and visualization
  - Active cells count
  - Ball physics information

## Code Structure

The game is organized into multiple modules:
- **ball.lua**: Square ball implementation
- **cell.lua**: Base cell implementation
- **level.lua**: Level management and interface to level generator
- **input.lua**: Mouse and keyboard handling
- **main.lua**: Game initialization and main loop
- **src/level_generator.lua**: Procedural level generation and test levels
- **src/cell_types.lua**: Definition of all cell types and their properties
- **src/dirt.lua**: Dirt cell behavior and utilities
- **src/sand.lua**: Sand cell behavior and utilities
- **src/stone.lua**: Stone cell behavior and utilities
- **src/water.lua**: Water cell behavior and utilities
- **src/collision.lua**: Physics collision handling
- **src/effects.lua**: Visual effects for cells
- **src/renderer.lua**: Level and cell rendering
- **src/updater.lua**: Cell update logic and optimization
- **src/debug.lua**: Debug visualization and tools
