# Rook motion polish

Open `scenes/ProceduralAnimationTest.tscn` in Godot and press **F6**. Move with
WASD/arrows, jump with **Space**, toggle the motion layer with **P**, switch
between overview and close cameras with **C**, and reset with **R**. **T** plays
or stops a short start/stop, quarter-turn, reversal and jump demonstration.
Movement keys interrupt the demonstration. The teal steps test landing heights;
the amber wall tests blocked movement. Falling off the floor resets the player.

## Movement and turning

The gameplay body remains responsive. The cosmetic heading follows a sequence:
head first, pelvis second, legs last. The chest bridges the head and pelvis;
neck and hip twists are capped at 55 and 32 degrees. The feet stay anchored
through the start of a turn, then take alternating pivot steps to face the new
heading. Turns finish after input is released, including 180-degree reversals
and crossing the -PI/PI boundary. Third-person steering uses the requested
heading, independently of the visual turn.

The walk phase advances by actual ground distance divided by calibrated stride
length. A time-seek node samples the authored walk at that phase, keeping the
upper-body gait synchronized with the feet. Stride and contact timing are sampled
once from each imported rig's walk clip; the stride is capped at two leg lengths
for a compact, grounded gait. Wall contact stops the gait. The existing idle
and jump clips still supply the base pose.

## Contacts and weight

`scripts/rook_foot_placement.gd` maintains world-space stance contacts. A foot
holds its position and orientation during support, then lifts along a smooth
swing toward its next placement. A foot approaching its reach limit can lift
early, which avoids dragging a sole during abrupt starts or direction changes.
On stopping, the current swing finishes and the trailing foot takes a short
recovery step. Only one recovery/pivot step runs at a time.

Ground probes use the player's collision mask and exclude its own body. Ankle
clearance is calibrated from the idle and capsule; probes adjust placement height
and refuse unsupported or overly steep contacts. Contacts follow their supporting
Node3D's transform, including moving platforms. This is height placement, not
full sole/toe articulation on slopes or a general obstacle-aware step planner.
Large steps and unreachable targets are limited by the existing leg lengths.

The pelvis shifts slightly toward the supporting foot. Acceleration/braking
produce torso lean and a small inertial body shift. Both independent Rook body
roots lower for landing compression and contact reach, while a two-bone leg solve
keeps the ankles planted without stretching bones. Reach compression releases
smoothly rather than popping upward at toe-off. Downward speed determines landing
strength, with the full response reached at 10 units/sec.

## Cape and tuning

The shoulder attachment stays with the torso. `Cape_1`, `Cape_2` and `CapeEnd`
receive progressively slower damped spring rotations driven by actual acceleration,
travel speed, chest turning and landing impacts. The hem follows last, with a
restrained overshoot after braking. Each joint is bounded at 16 degrees before
the strength multiplier. This adds follow-through to the authored cape animation;
it is not a cloth or body-collision simulation.

The shared player controller enables the layer in the existing Rook levels,
including courtyard and stealth controls. In **Procedural Animation**, tune the
base turn timing (default 0.055 s), lean (7 degrees), landing compression (12% of
leg length), foot planting, cape motion and cape strength. **P** switches the
entire layer off for comparison. The separately baked grounded idle remains part
of the base animation; see `docs/rook-idle.md`.

`scripts/rook_procedural_pose.gd` runs after the authored AnimationTree pose.
Offsets are temporary; imported FBX files, animation resources, collision and
input response are unchanged. Both Rook model scales are supported. Movement,
base pose and modifiers use the physics clock. Interaction locks, camera pauses,
barrel mode, toggles and respawns clear the motion and contact state.

## Validation

```sh
godot --headless --path . --fixed-fps 60 --script tests/test_procedural_animation.gd
godot --headless --path . --fixed-fps 60 --script tests/test_rook_weight.gd
godot --headless --path . --script tests/test_rook_idle.gd
```

The checks cover both rigs, rendered-bone turn order, planted ankle drift,
unchanged bone lengths, distance-driven gait, pivot/recovery steps, moving
supports, cape response and settling, 30/60/120 Hz spring stability, jumps,
resets, toggles and identical gameplay movement/collision with the layer on/off.
