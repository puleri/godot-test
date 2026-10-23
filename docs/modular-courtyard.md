# Modular courtyard generator

Open `Levels/ModularCourtyard.tscn` in Godot 4.7.2 and press **F6** (Run Current Scene).
The checked-in scene already contains the generated level; no generation runs at startup.

- **WASD / arrow keys:** camera-relative movement.
- **Space:** jump.
- **Tab:** switch between the full layout and a camera following the Rook.
- **R:** return to the entrance. Falling also returns you to the entrance.

## Make another layout

1. Open the courtyard scene itself and select its `ModularCourtyard` root.
2. Change **Layout Seed**, **Width Cells**, **Depth Cells**, **Terrace Height**,
   **Approach Length**, **Grass Density**, or **Barrel Count** in the Inspector.
3. Click **Generate Courtyard**, then save the scene. Generation supports editor undo/redo.
4. Use **Save As** to keep a separate level variant.

The seed changes terrace positions and dressing. The layout remains a courtyard
with a central aisle, entrance path, two raised terraces, and boundary walls/railings.
Dimensions use a 2-meter grid. Width and depth are odd cell counts so the entrance
stays centered. Supported ranges are 13–25 cells wide and 11–23 cells deep.

`Generated/Connections/Entrance` marks the open end of the approach at walking
height. Use it to attach the [connector kit](connector-kit.md); its 6-meter width
matches the straight, corner, T-junction, staircase and bridge modules.

All generated content lives under `Generated`, divided into `Ground`, `Terraces`,
`Boundary`, `Dressing`, and `Markers`. Each module contains a `Model` referencing
the original asset scene, plus separate collision where needed. You can move,
duplicate, or remove these modules normally. **Regeneration replaces everything
under `Generated`.** Put hand-authored additions beside `Generated` to retain them
when regenerating; move a generated module out of that subtree to preserve edits.

## Asset handling

The generator reuses the existing stone tile, harbor wall, archway, stone railing,
grass tuft, and barrel scenes. It measures imported mesh bounds to normalize their
different origins. Floors fit exact 2-meter footprints, with their top at the
placement height. Source models, materials, and scenes are not changed.

Floors, walls and railings use simple collision. The arch uses mesh collision to
keep its opening clear. Stair art uses scaled tile blocks over a smooth ramp
collider, allowing the existing character controller to walk up without a step
solver. Barrels reuse the existing art as static props, with the interactive
barrel script disabled on these instances. This prototype does not generate NPC
navigation or gameplay objectives.

## Command line

Regenerate the saved courtyard (replaces its `Generated` subtree):

```sh
godot --headless --path . --script tools/generate_courtyard.gd -- --seed=42
```

Save a separate variant while keeping the original:

```sh
godot --headless --path . --script tools/generate_courtyard.gd -- --seed=99 --output=res://Levels/Courtyard99.tscn
```

Verify deterministic generation, scene packing, floor support, passage through the
arch, both staircases, edge collision, and the largest supported terrace:

```sh
godot --headless --path . --fixed-fps 60 --script tests/test_modular_courtyard.gd
```

The editor implementation follows Godot's [tool-script scene ownership guidance](https://docs.godotengine.org/en/stable/tutorials/plugins/running_code_in_the_editor.html).
