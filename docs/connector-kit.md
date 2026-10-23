# Reusable connector kit

Open `Levels/ConnectorKitDemo.tscn` and press **F6**. Walk forward from the start
court to the T-junction. One branch turns onto a wooden bridge and a lower court;
the other climbs to an upper walkway and court. Both walks use the same saved
straight module. WASD/arrows move, Space jumps, Tab switches overview/follow
cameras, and R returns to the start.

## Modules

Drag these scenes from `Modules/Connectors/` into any level:

| Scene | Width × length | Connections |
| --- | --- | --- |
| `Straight.tscn` | 6 × 8 m | South, North |
| `Corner.tscn` | 6 × 6 m | South, East |
| `TJunction.tscn` | 6 × 6 m | South, East, West |
| `Staircase.tscn` | 6 × 8 m | South at 0 m, North at +2 m |
| `Bridge.tscn` | 6 × 12 m | South, North |

Every scene includes saved geometry, collision, and `Connections/` markers.
There is no runtime generation. Stone pieces and wooden planks use the existing
models and materials. `wood_planks.tscn` is a new material wrapper around the
existing `WoodPlanks.fbx`. The bridge has stone landings, a wooden span and supports.
The staircase uses eight visible treads over a smooth ramp collider so the Rook
can walk up and down normally.

## Join modules in the editor

1. Add two module instances to your level.
2. Select the root of the module you want to move.
3. In **Connect**, set **Source Connection** to the marker on that module
   (usually `South`; use `North` to attach the top of a staircase).
4. Assign **Target Connection** to a marker on the other module, such as
   `../Straight/Connections/North`.
5. Click **Snap To Connection**. Save the level. The snap supports editor undo/redo.

The moving module rotates and translates so the markers meet with opposite
outward directions. Height is included, so snapping a straight to the stair's
North marker places it exactly 2 meters higher. Keep modules and their parents
at unit scale. Rotate a corner to choose its orientation.

The existing courtyard now exposes `Generated/Connections/Entrance` at the open
end of its approach. It uses the same 6-meter connection width. The generator
recreates that marker when you regenerate the courtyard.

For manual placement, geometry uses 2-meter tiles and 90-degree turns. Use a
**1-meter translation snap** because a 6-meter-wide corner's side connection is
3 meters from its centerline. Marker snapping handles those offsets directly.
Markers sit on the walking surface; their local **-Z points outward**, and +Y
points up. Width is stored in their `width` metadata. Snap alignment requires a
matching width and the `level_connection` marker metadata.

Snapping aligns geometry; it does not reserve ports or check whether other parts
of two modules overlap. Finish unused openings with an end court or a boundary.
The demonstration's labels and terminal courts belong to that level, separate
from the reusable module scenes. NPC navigation is not included in this kit.

## Scripted assembly

Add both instances to their level parent, then connect them:

```gdscript
var straight = preload("res://Modules/Connectors/Straight.tscn").instantiate()
var stairs = preload("res://Modules/Connectors/Staircase.tscn").instantiate()
add_child(straight)
add_child(stairs)
stairs.connect_to("South", straight.get_connection("North"))
```

`connect_to()` also works on detached trees during scene construction. It returns
false for an invalid target, mismatched widths, or scaled transforms. Set scene
ownership when packing a level; `connector_kit_builder.gd` contains the example
assembly and ownership handling.

## Rebuild and verify

The builder overwrites the five kit scenes and the demo. Keep custom variants
under different names before rebuilding:

```sh
godot --headless --path . --script tools/build_connector_kit.gd
godot --headless --path . --fixed-fps 60 --script tests/test_connector_kit.gd
```

Checks cover each port's position/orientation under transformed parents,
courtyard compatibility, saved source/material references, collision at every
demo join, walking both complete routes, stair descent and bridge edge collision.
