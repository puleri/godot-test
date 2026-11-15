# Guard motion

Run `scenes/GuardMotionTest.tscn` with F6. Two production StealthGuard instances
patrol short circuits with stops and quarter turns. C cycles overview, Hound
close-up and Mouse close-up; P toggles the additive pose layer; S switches
between patrol and stationary look-around; R restarts.
The distance-driven gait remains active for both sides of the pose comparison.

## What changes

`StealthGuard` configures an optional guard pose in `NPCAnimationDriver`.
All derived guards inherit it, including LayeredStealthGuard, ExchangeGuard,
SystemsLabGuard and NightCityGuard. Ambient NPCs retain their animation driver.
The layer is enabled by default; the guard Inspector exposes
`weighted_motion_enabled` and `guard_motion_strength` (default 1.0).

The head follows the existing gameplay heading. The chest, hindquarters and legs
follow with separate response times. During a stationary glance of up to 75
degrees from the planted stance, hips and paws hold their heading; the chest
follows 22% of the glance and the neck supplies the rest. Larger changes still
initiate a complete pivot. Separate start/stop speed thresholds prevent low-speed
jitter from repeatedly switching between these behaviors. This keeps the head facing the direction
used by detection and the real lamp, while the body visibly catches up. Turning
never writes the collision transform, navigation heading, route, awareness,
hearing or capture rules.

Resolved acceleration and braking drive damped torso lean, a small weight shift
and accessory inertia. Falling into a floor adds a bounded compression impulse.
Breathing phases vary deterministically with the guard's seed, preventing lines
of idle guards from moving in unison. The motion state clears for inactive guards,
relocation, explicit lab resets and disabling the layer. Sleeping city branches
pause their animation and pose together.

## Hound rig

`guard_paw_contacts.gd` samples separate walk and run profiles from the actual
Hound skeleton. The imported Walk clip contains two repeated strides; the guard
uses its first half as the walk period. Paw timing and forward placement are
calibrated from each clip. Walk/run transitions blend for 0.22 seconds, with
contacts fading through the handover. Alerts temporarily release paw constraints
so the authored gesture remains visible.

Four two-bone solves hold stance ankles in world space, preserving paw orientation
and leg lengths. Front contacts follow the forequarters' frame; rear contacts
follow the pelvis frame. Early toe-off, smooth swing arcs and diagonal recovery
steps avoid dragging paws during starts, stops and turns. The trunk lowers as
needed for reach and recovers smoothly; no leg is stretched. TailBase adds
restrained acceleration/turn follow-through.

Ground rays use the guard collision mask, exclude its own body and reject steep
or missing support. Contacts follow moving support transforms. This provides
placement height and stance stability, not articulated toes, sole fitting on
slopes, full cloth physics or general obstacle-aware step planning. Contact reach
is bounded; extreme ledges and imported pose limitations still need authored
animation work.

## Mouse rig

The current Mouse export contains Base, Head, Hat, Bone.004, Arm and Baton.
There are no articulated leg chains. It therefore receives head-led body turns,
body weight/impact motion, independent hat and baton lag and seeded breathing.
It cannot receive skeletal foot planting without adding leg bones and skinning
to the source asset. The Hound's leg solver is never applied to this rig.

## Playback and implementation

The guard's AnimationTree selects the configured patrol gait and blends to Run
for pursuit. Both walk and run poses are sampled by seek nodes from resolved
horizontal distance divided by stride length. Standing still or pushing a wall
stops the gait phase; platform carriage is excluded from travel. Idle, alert and
their blend clocks remain independent. The pre-existing ambient driver continues
using its configured playback behavior.

`guard_procedural_pose.gd` runs as a physics-clock SkeletonModifier3D after the
animation pose. Imported FBX files, skins and shared animation resources are not
edited. The driver already duplicates animation libraries per actor; guard gait
sampling restores the skeleton's original pose after calibration.

## Checks

```sh
godot --headless --path . --fixed-fps 60 --script tests/test_guard_weight.gd
godot --headless --path . --fixed-fps 60 --script tests/test_guard_scan.gd
godot --headless --path . --fixed-fps 60 --script tests/test_stealth_guard.gd
godot --headless --path . --fixed-fps 60 --script tests/test_guard_awareness.gd
godot --headless --path . --fixed-fps 60 --script tests/test_stealth_systems_lab.gd
godot --headless --path . --fixed-fps 60 --script tests/test_night_city.gd
godot --headless --path . --fixed-fps 60 --script tests/test_rook_weight.gd
```

The guard-specific checks measure patrol contact drift, unchanged leg lengths,
rendered turn order, head/sight agreement, Mouse accessory response, distance
phase, gait selection, alert release, resets and identical AI/movement with the
pose layer on/off. Springs, landing and heading wrapping are checked at
30/60/120 Hz. Integration suites exercise detection, pursuit, lab duties, city
routes and Rook motion. Inspect the motion room visually as well: numeric checks
cannot establish the final animation quality.
