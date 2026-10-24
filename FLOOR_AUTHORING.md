# Floor Authoring Guide

## Ownership and folders

Each owner edits only their floor folder:

- `floors/floor_1/` — teammate 1
- `floors/floor_2/` — teammate 2
- `floors/floor_3/` — you

A floor folder contains its floor scene and script plus a `rooms/` folder containing one `.tscn` per room. Keep floor-specific art, room nodes, and layout code in the same folder. Shared templates and transition code live under `shared/` and `scripts/`; change those on `main` and merge the update into each floor branch before using it.

## Room scene contract

- Inherit from `res://shared/room_template.tscn` so the root remains `DungeonRoom`.
- Keep the `EntryPoint` marker and the `Doorways` child.
- Use the standard doorway IDs `North`, `East`, `South`, and `West` for ordinary cardinal exits. Each exit is a `Marker2D` under `Doorways`; its local +X axis points out through the wall. If the room scene authors its own shape, place the marker at the wall plane and set `generate_rectangular_shell` to `false`.
- Set room-local `room_size`, `wall_thickness`, `door_gap`, and colors on the room scene. Do not add a project-wide tile or room size requirement.
- Keep floor geometry and collision in the room scene. The shared `DungeonFloor.connect_rooms(room_a, exit_a, room_b, exit_b)` method creates reciprocal travel triggers and flush, lockable barriers from those markers.

## Floor scene contract

- The root floor scene uses a script extending `DungeonFloor` and contains an `EntryPoint` marker.
- Load room scenes from that floor's own `rooms/` folder with `add_room(scene, room_id, origin)`.
- Connect adjacent rooms with `connect_rooms(room_a, &"East", room_b, &"West")` or the matching named exits. Keep room placement and connection lists in the floor's script.
- Request the next floor with `next_floor_requested.emit(floor_number)` from that floor's stairs trigger. The shared manager owns floor loading and transition labels.

## AI prompt outline

"Work only in `floors/floor_N/`. Create or update the requested room scene using `shared/room_template.tscn`. Keep the `DungeonRoom` root, `EntryPoint`, and named `Doorways` markers. Author this floor's geometry and collisions in its room scenes. Connect rooms in the floor script through `DungeonFloor.connect_rooms`; do not edit shared code or another floor. Preserve each doorway marker at its wall plane with local +X pointing outward."
