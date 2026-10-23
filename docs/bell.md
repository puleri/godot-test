# Rigged bronze bell

The Desktop `bell.blend` has been prepared as an editable Blender source and a
self-contained, skinned GLB. Its handmade bell, internal clapper and timber
frame geometry are retained; an iron axle, collars and support bands were added.
Materials use ordinary exportable PBR slots: aged bronze, a brighter bronze rim,
subtle verdigris facets, dark inner bronze, oak and blackened iron.

## Use in Godot

Instance `res://Mesh/Bell/bell.tscn`. The wrapper is approximately 2.3 m wide and
1.43 m tall (the original model at 60% scale), with its origin at ground level.
Call `ring()` for a four-second one-shot, `start_loop()` for continuous ringing,
or `stop_ringing()` to return to rest. `ringing_finished` is emitted after the
one-shot. `autoplay_loop` defaults to false; each instance has its own animation
library. The imported clips are `Ring` and `RingLoop` (3.2 seconds, seamless).

Open `res://scenes/BellPreview.tscn` and press **F6**. It starts looping;
**Space** rings once, **L** loops and **R** restores the rest pose.

All three Midnight Exchange bell stations now instance this asset. **Q** drives
the skeletal ringing along with the existing chime, pulse, hearing behavior and
nine-second cooldown. Both the saved level and its builder use the same asset.
The reusable asset supplies visuals and animation; the level supplies audio and
interaction. It adds no collision bodies.

## Edit in Blender

`Mesh/Bell/source/bell_rigged.blend` contains the materials, rig and both actions.
The source folder has `.gdignore`; Godot imports the GLB directly, without needing
Blender on another developer's machine. The rig has three rigidly weighted bones:

- `Root`: stationary frame, axle, collars and support bands.
- `BellSwing`: bell shell, pivoting at the crown on local X.
- `ClapperSwing`: internal striker, parented to the bell with delayed local-X motion.

Use the Action Editor to select `Ring` or `RingLoop`. Model units are metres,
Z-up in Blender; GLB converts to Godot's Y-up convention. The studio camera and
lights are saved in Blender but excluded from the game export.

Rebuild from the untouched Desktop source, or pass another input after `--`:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/prepare_bell.py
```

The preparation script writes only the project copy, GLB and material preview;
it does not overwrite the Desktop source. Rebuilding from an edited prepared
file is not supported: export that file directly from Blender instead, selecting
the rig and skinned meshes and including both actions.

## Validation

```sh
godot --headless --path . --script tests/test_bell.gd
godot --headless --path . --fixed-fps 60 --script tests/test_midnight_exchange.gd
```

The asset checks cover imported materials and skins, actual bone motion, fixed
frame, independent instances, retriggering, rest poses, loop continuity and all
three saved level instances. `tools/preview_bell.gd` captures rest, ring and loop
poses with the real renderer into `/private/tmp/bell-godot-*.png`.
