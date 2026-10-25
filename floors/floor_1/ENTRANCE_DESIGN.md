# Separate entrance and Floor 1

The game starts in `entrance.tscn`: the original plain rectangular staging room.
It is outside Floor 1 and deliberately undecorated. Walk east to enter the cave;
walk west from room A to return. Floor 1's title appears on first entry only.
The manager keeps both area instances alive, hiding and disabling inactive
areas, so returning from the entrance preserves the same dungeon instance.

## Fixed eight-room graph

```
                       D: Spring Grotto ── E: Fern Chamber
                       │                   │
Entrance ── A: Threshold ── B: Root Hall ── C: Moss Junction ── G: Deep Cavern ── H: Descent
                                           │
                                           F: Stone Alcove
```

For exact placement and reciprocal links, see `floor_1.gd`'s `GRID` and
`CONNECTIONS`. D is north of B, E north of C, and F south of C. H contains stairs
to Floor 2, safely separated from its western arrival. The entrance does not
count among the eight dungeon rooms.

Each passage uses the existing iris transition and fixed room camera. Entrance
and Floor 1 opt into `DungeonFloor.free_exploration`; they need no manual door
unlock. Floors 2 and 3 retain their original locking policy and content.

## Editing the rooms

Each room scene inherits `shared/room_template.tscn`, uses `cave_room.gd`, and
contains editor-native layers:

- `Terrain`: nonblocking dirt, paths, moss and grass.
- `WallsWaterAndBoulders`: collision-bearing rock boundary, pools and obstacles.
- `RootsFernsAndFlowers`: decorative, nonblocking vegetation and H's stairs.
- `Lighting`: restrained warm-to-cool room tint beneath the player.

The common TileSet is `art/cave_tileset.tres`. Its original editable SVG atlas
uses native 16×16 tiles, displayed at 2× with nearest-neighbor filtering. Every
art pixel is two screen pixels at 1280×720. No dense image-generated sprites
are used. Room shape comes from irregular tile boundaries and natural passage
mouths rather than square wall shells.

Doorways are explicitly authored cardinal `Marker2D`s, with local +X pointing
outward. Their child `ArrivalPoint`s are clear of the doorway triggers. Keep
those markers and the room's inherited `EntryPoint` intact while painting.
Solid collision lives on the tiles, so moving a wall, rock or water tile also
moves its collision. Physics quadrant size is 1 because Godot 4.7.2's merged
quadrants omitted individual colliders in testing.

The optional authoring tools reproduce the baseline rooms and original atlas:

```sh
python3 floors/floor_1/tools/author_tiles.py
Godot --headless --path . --editor --import --quit
Godot --headless --path . --script res://floors/floor_1/tools/build_rooms.gd
```

The build tool overwrites the eight room scenes: keep hand-painted scenes by
editing those directly and avoiding regeneration. The saved `walkable_cells`
and `blocked_cells` arrays are baseline test metadata; update these alongside
hand-edited collision when maintaining the tile-by-tile regression checks.

## Verification

```sh
Godot --headless --path . --script res://floors/floor_1/tests/entrance_smoke.gd
```

The regression checks startup outside Floor 1, one-time title, keyboard entry,
walkable connectivity, tile collision, water, boulders, clear room routes, all
sixteen directed passages, repeated area travel, preserved dungeon instance,
descent to Floor 2, and unchanged Floor 2/3 progression and manual locks.

All eight rooms and the plain entrance are captured and inspected at 1280×720.
Combat, mobs, loot, puzzles, HUD/minimap, multiplayer and player art are deferred.
