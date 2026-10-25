# Dungeon Game

This is the official Godot project for the full dungeon game. It is prepared for three teammates to build their floors independently using the shared room contract in [FLOOR_AUTHORING.md](FLOOR_AUTHORING.md).

## Run

Open this repository's `project.godot` in Godot 4.7.2 and press **F5**. The player starts in the plain entrance, outside Floor 1. Walk east to enter the dungeon.

## Controls

- **WASD** or **Arrow keys**: move.
- Entrance and Floor 1 passages are freely accessible in both directions.
- **1**: unlock room doorways on Floors 2 and 3. Their original lock behavior is preserved.

## Project structure

- `floors/floor_1/`, `floors/floor_2/`, `floors/floor_3/`: floor scene, script, room scenes, and floor-specific content, grouped by owner.
- `shared/`: reusable room template and floor-room connection interface.
- `scripts/floor_manager.gd`: persistent player, camera, iris transitions, cached area loading, and per-area door policy.
- `scripts/player_movement.gd`: temporary movement controller, to be replaced when combat mechanics are integrated.
- `FLOOR_AUTHORING.md`: room and floor contract plus AI prompt outline.

## Current route

Plain entrance ↔ Floor 1's eight cave rooms → Floor 2 → Floor 3. Floor 1 includes a main route, a four-room loop, and an optional side chamber; all its passages permit backtracking. Its descent chamber leads to Floor 2. Floors 2 and 3 retain their original placeholders; Floor 3 stairs are decorative. Combat is not implemented.

See [Floor 1 layout and editing notes](floors/floor_1/ENTRANCE_DESIGN.md) for the map, editable tile layers, and regression command.
