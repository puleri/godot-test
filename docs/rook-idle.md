# Grounded Rook idle

Both Rook FBX imports use `tools/import_rook_idle.gd` as an import script. It
corrects only `Skeleton|Idle`, baking a normal looping animation with no runtime
foot correction. The original FBX files remain the source exports; the original
animation authoring project is not present in this repository.

The exported idle fixes the torso and pelvis in place while both feet rise.
The importer measures that rise relative to the first idle pose and transfers
it into an equal downward displacement of `Spine` and `Bone.027`, Rook's two
independent body roots. A two-bone leg solve keeps both ankles at their initial
positions and rotations, preserving the heels/toes and leg lengths. The arm,
head and cape animation tracks retain their original motion. The correction
uses the existing bounce timing and amplitude, sampled at 240 Hz, with matching
first/last keys. Other clips, collision and movement are unaffected.

This is part of the base idle, so it remains enabled when **P** switches the
procedural lean/turn/landing experiment off. It does not change walk contacts or
add terrain adaptation. Foot height follows the existing standing pose; scene
placement still determines the model's height above the floor.

Reimport `Objects/Rook.fbx` and `Rook/v2/Rook_v2.fbx` in Godot after editing the
import script. A clean project import runs it automatically. If a future source
FBX already has a grounded idle, remove its `import_script/path` setting rather
than applying the correction again.

Verify both imported models and both player wrappers with:

```sh
godot --headless --path . --script tests/test_rook_idle.gd
godot --headless --path . --fixed-fps 60 --script tests/test_procedural_animation.gd
```

For visual inspection, open `scenes/ProceduralAnimationTest.tscn`, press **F6**,
then **C** for the close camera. The body should dip while both feet remain
planted. Walk, stop and jump to inspect the existing animation transitions.
