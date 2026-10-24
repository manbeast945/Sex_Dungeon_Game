# Dungeon Game

This is the official Godot project for the full dungeon game. It is prepared for three teammates to build their floors independently using the shared room contract in [FLOOR_AUTHORING.md](FLOOR_AUTHORING.md).

## Run

Open this repository's `project.godot` in Godot 4.x and press **F5**. The player starts in Floor 1.

## Controls

- **WASD** or **Arrow keys**: move.
- **1**: unlock room doorways after entering a new room or floor. Locked openings have invisible collision barriers. Initial spawn starts unlocked.

## Project structure

- `floors/floor_1/`, `floors/floor_2/`, `floors/floor_3/`: floor scene, script, room scenes, and floor-specific content, grouped by owner.
- `shared/`: reusable room template and floor-room connection interface.
- `scripts/floor_manager.gd`: persistent player, camera, iris transition, floor loading, and door locks.
- `scripts/player_movement.gd`: temporary movement controller, to be replaced when combat mechanics are integrated.
- `FLOOR_AUTHORING.md`: room and floor contract plus AI prompt outline.

## Current route

Floor 1 starter → boss placeholder → stairs → Floor 2 starter → boss placeholder → stairs → Floor 3 starter. Floor 3 stairs are decorative. Bosses and combat are placeholders.
