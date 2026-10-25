# Native cave tile art

`cave_tiles.svg` is an original, editable 256×64 pixel atlas: 64 cells of 16×16
pixels. All shapes are aligned to its native integer pixel grid. Godot imports
it at its native size; TileMapLayers use nearest-neighbor filtering and 2× scale.

The atlas includes dirt, moss/grass, limestone walls and faces, water, fern
clusters, boulders, roots, stairs, flowers and dark exterior rock. Its restrained
palette and visible pixels follow the new reference's rendering style while
preserving the forest-cave theme.

`cave_tileset.tres` defines the shared atlas and solid tile polygons. The saved
room scenes reference this single resource. `tools/author_tiles.py` contains
the original palette and tile construction; `tools/build_rooms.gd` authors the
TileSet and editor-native room layers. No high-detail raster assets are used.
