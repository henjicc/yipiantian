---
type: Reference
title: "TileMapLayer Reference (Godot 4.3+)"
description: "`TileMap` is deprecated since Godot 4.3."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# TileMapLayer Reference (Godot 4.3+)

**Verified 2026-06-06** against Godot 4.x. The TileMapLayer API has been stable since 4.3; re-verify method signatures if a newer minor changes them.

## Architecture

`TileMap` is deprecated since Godot 4.3. Use individual `TileMapLayer` nodes instead.

**Old (deprecated):**
```
TileMap (with internal layers 0, 1, 2...)
```

**New:**
```
Node2D
  +-- GroundLayer (TileMapLayer)
  +-- WallLayer (TileMapLayer)
  +-- ObjectLayer (TileMapLayer)
```

Each TileMapLayer shares a `TileSet` resource but is independently configurable.

## Migration

In editor: select old TileMap -> TileMap bottom panel -> toolbox icon (top-right) -> convert. Creates TileMapLayer children.

## Properties

```gdscript
tile_set: TileSet
enabled: bool = true
collision_enabled: bool = true
navigation_enabled: bool = true
occlusion_enabled: bool = true
use_kinematic_bodies: bool = false
y_sort_origin: int = 0
rendering_quadrant_size: int = 16
```

## Core Cell Methods

```gdscript
# Set a tile
# source_id: index in TileSet sources
# atlas_coords: position in atlas texture
# alternative_tile: for flipped/rotated variants (0 = default)
func set_cell(coords: Vector2i, source_id: int = -1,
    atlas_coords: Vector2i = Vector2i(-1, -1),
    alternative_tile: int = 0) -> void

# Erase a tile
func erase_cell(coords: Vector2i) -> void

# Clear all
func clear() -> void
```

## Querying Cells

```gdscript
func get_cell_source_id(coords: Vector2i) -> int        # -1 if empty
func get_cell_atlas_coords(coords: Vector2i) -> Vector2i
func get_cell_alternative_tile(coords: Vector2i) -> int
func get_cell_tile_data(coords: Vector2i) -> TileData    # runtime properties
```

## Bulk Queries

```gdscript
func get_used_cells() -> Array[Vector2i]
func get_used_cells_by_id(source_id: int = -1,
    atlas_coords: Vector2i = Vector2i(-1, -1),
    alternative_tile: int = -1) -> Array[Vector2i]
func get_used_rect() -> Rect2i
func get_surrounding_cells(coords: Vector2i) -> Array[Vector2i]
func get_neighbor_cell(coords: Vector2i, neighbor: TileSet.CellNeighbor) -> Vector2i
```

## Coordinate Conversion

```gdscript
# Pixel position to grid coordinates
func local_to_map(local_position: Vector2) -> Vector2i

# Grid coordinates to pixel position (center of cell)
func map_to_local(map_position: Vector2i) -> Vector2
```

## Terrain Auto-tiling

```gdscript
# Auto-connect terrain tiles (handles corner/edge matching)
func set_cells_terrain_connect(cells: Array[Vector2i], terrain_set: int,
    terrain: int, ignore_empty_terrains: bool = true) -> void

# Draw terrain along a path
func set_cells_terrain_path(path: Array[Vector2i], terrain_set: int,
    terrain: int, ignore_empty_terrains: bool = true) -> void
```

## Patterns

```gdscript
func get_pattern(coords_array: Array[Vector2i]) -> TileMapPattern
func set_pattern(position: Vector2i, pattern: TileMapPattern) -> void
```

## Navigation

```gdscript
func get_navigation_map() -> RID
func set_navigation_map(map: RID) -> void
```

## Runtime Tile Data Override

```gdscript
# Override these in a subclass for runtime tile modifications
func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
    return true  # return true for cells that need runtime updates

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
    tile_data.set_custom_data("visited", true)
```

## Signal

```gdscript
signal changed()  # emitted when cells or properties change
```

## Practical Examples

```gdscript
extends TileMapLayer

# Place a tile
func place_floor(pos: Vector2i) -> void:
    set_cell(pos, 0, Vector2i(0, 0))

# Mouse click to grid
func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        var grid_pos := local_to_map(to_local(event.global_position))
        set_cell(grid_pos, 0, Vector2i(0, 0))

# Get world position of a tile
func get_tile_center(grid_pos: Vector2i) -> Vector2:
    return map_to_local(grid_pos)

# Check if cell is empty
func is_empty(pos: Vector2i) -> bool:
    return get_cell_source_id(pos) == -1

# Iterate all placed tiles
func process_all_tiles() -> void:
    for cell in get_used_cells():
        var data := get_cell_tile_data(cell)
        if data:
            pass  # use data
```

## TileSet Setup (Editor Workflow)

1. Create a TileSet resource (or share one across layers)
2. Add a TileSetAtlasSource with your sprite sheet
3. Configure tile size to match your grid (e.g., 16x16 or 24x24)
4. Paint physics (collision), navigation, and custom data per tile
5. Use terrain sets for auto-tiling (corners, edges, match rules)
6. Custom data layers let you tag tiles with arbitrary typed data (e.g., "walkable": bool, "damage": int)

## Custom Data on Tiles

In the TileSet editor, add custom data layers (Inspector -> Custom Data Layers):
- Name: "walkable", Type: bool
- Name: "damage", Type: int

Then query at runtime:
```gdscript
var tile_data := get_cell_tile_data(pos)
if tile_data:
    var walkable: bool = tile_data.get_custom_data("walkable")
    var damage: int = tile_data.get_custom_data("damage")
```
