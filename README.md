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

## Game Features

### Physics-Based Square Ball
- The ball is a square that rotates and bounces realistically
- Aim and shoot with the mouse to navigate through the level

### Cellular Automata Sand
- Sand cells behave like traditional sand simulations:
  - Sand falls downward due to gravity
  - Sand piles up naturally at angles of repose
  - When hit by the ball, sand can be disrupted and sent flying

### Two Types of Terrain
- **Sand**: Can be disrupted by the ball, behaves like cellular automata
- **Stone**: Solid obstacles that the ball bounces off of

### Hybrid Physics System
- Sand normally follows cellular automata rules
- When sand is hit by the ball with enough force, it temporarily becomes physics-based
- Flying sand eventually settles back into cellular automata behavior

## Code Structure

The game is organized into multiple modules:
- **ball.lua**: Square ball implementation
- **cell.lua**: Cell types and behavior (sand and stone)
- **level.lua**: Level generation and management
- **input.lua**: Mouse and keyboard handling
- **main.lua**: Game initialization and main loop
