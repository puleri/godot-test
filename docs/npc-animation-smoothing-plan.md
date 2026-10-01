# NPC animation smoothing — Terra implementation plan

## Outcome

Smooth Hound and Mouse starts, stops, turns, and alert transitions in Demo_A2, while retaining the corrected model forward axes and existing autonomous routes. Implement this as a focused improvement to the existing NPC system. Preserve Rook gameplay, collision safety, materials, scale, and the startup scene; do not deploy or regenerate web exports.

## Findings from the current code

These are code-level findings, not a claim that visual playback has been verified:

- `scripts/npc_animation_driver.gd` already requests 0.15-second AnimationPlayer crossfades. Simply adding a blend duration is not sufficient.
- `_play_safe()` passes a custom speed to `AnimationPlayer.play()`, then updates `AnimationPlayer.speed_scale` on subsequent frames. These are separate multipliers; their combination can produce unintended playback rates and contaminate later transitions.
- Locomotion switches discretely between a static idle pose and a gait. The previously inspected idle clips last only 0.001 seconds; verify how their end/hold behavior affects blending.
- Alert playback freezes motion sampling with an early return. Finishing alert clears the clip cache, rather than deliberately blending back to a continuously updated base pose. Route timing can resume movement before an alert finishes.
- `scripts/npc_controller.gd` smooths an internal heading, but the visual pivot does not follow that pre-turn. `_update_visual_facing()` directly assigns the resolved movement yaw; once movement resumes, the visible character can snap to the new heading.
- `_arrive()` and `_recover_from_blockage()` call `_stop_horizontal(1.0)`, effectively applying a large braking step in one physics frame.
- Stuck detection compares progress against a fixed 0.01 units per frame. Slow approach and turning can be mistaken for blockage, causing additional abrupt stops.

## 1. Establish a reproducible baseline

Use `scenes/NPCMovementTest.tscn` to inspect both species starting, reaching a point, reversing, and playing alert. Add deterministic scenarios for repeated start/stop, 90-degree and 180-degree turns, and a pause shorter than alert duration. Preserve existing obstacle and edge scenarios.

Inspect imported track paths, interpolation, and first/last locomotion poses. Separate transition defects from discontinuities inside a looping clip. Check the inherited skeleton overrides and root tracks before changing assets. Keep Hound's current +PI/2 and Mouse's PI forward offsets unless visual evidence proves an offset incorrect.

## 2. Use continuous base-pose blending

Replace the NPC driver's discrete idle/gait switching with a small per-instance AnimationTree, still configured by the existing explicit clip mappings. Keep the public motion-update and alert-request interface recognizable to the controller.

- Build a base idle-to-locomotion blend, with walk/run nodes supporting the configured gait and separate locomotion time scaling. The default Hound uses walk; the default Mouse uses run. Do not introduce automatic gait switching unless explicitly configured.
- Smooth measured post-collision horizontal speed with a delta-aware filter. Derive a continuous locomotion weight from that speed and a configurable blend-to-full-speed threshold. Retain a small hysteresis/deadband around zero. Do not leave the character half-idle at normal cruise speed just because reference stride speed differs from travel speed.
- Smooth blend weight and playback rate independently. Give start and stop blends separate tunable durations. Starting values: Hound 0.20 s in / 0.25 s out; Mouse 0.12 s in / 0.18 s out. Treat these as visual tuning starting points.
- Keep the locomotion timeline continuous while its weight changes. Never restart a gait every frame or on small speed fluctuations. If changing between walk and run is supported, blend it deliberately and inspect foot-phase compatibility rather than assuming the clips are synchronized.
- Use exactly one mechanism to scale gait playback (a locomotion time-scale node). Reset AnimationPlayer global/custom speed multipliers to neutral and stop issuing competing direct `play()` calls while the tree owns playback. Idle, alerts, and transition timing must not inherit gait speed.
- Make idle a reliable held pose that remains available throughout a blend. If the 0.001-second imported clip does not evaluate reliably, create an instance-local hold animation from that pose with a usable duration and stable keys. Do not invent a breathing animation or edit the FBX binary.
- Keep mutable animation libraries and tree resources independent per NPC. Preserve graceful missing-clip behavior: missing run uses walk, missing alert skips the accent, and missing player/base clips warn once without crashing movement or building invalid tree nodes.
- Use a consistent animation processing callback with physics motion updates; verify the ordering does not create a one-frame oscillation or visible jitter.

## 3. Blend alerts without freezing the base state

- Implement alert as a full-body one-shot over the continuously evaluated locomotion base, with explicit fade-in and fade-out. Suggested starting fades: 0.08–0.12 s in, 0.12–0.18 s out, adjusted to fit the short source clips.
- Continue sampling motion and updating the base blend while alert plays. Alerts are cosmetic and must not lock route logic.
- Only begin an arrival alert once the NPC has stopped. If movement resumes, smoothly abort/fade out alert to the current base pose; never slide across the floor while locked into a full-body alert.
- Handle repeated requests, completion, interruption, and missing clips explicitly. Do not use an animation-finished callback as the only way to unblock the driver; AnimationTree playback needs its own supported completion/one-shot handling.

## 4. Coordinate movement, visible turning, and stopping

Animation blending alone cannot hide transform snaps.

- Replace the invisible pre-turn plus visible yaw snap with an explicit visible turning phase. On large direction changes, decelerate, rotate the visual heading smoothly using shortest-angle interpolation, then accelerate once sufficiently aligned. An intentional turn may change facing at zero speed; ordinary idle should retain its last facing.
- For small course corrections, turn smoothly while moving. Coordinate travel direction/speed with visible heading so a longer turn does not reintroduce sideways/backward sliding. Reconcile facing with post-collision displacement when sliding against obstacles, with a low-speed deadband to avoid jitter.
- Preserve world/local transform correctness and apply the model forward offset exactly once. Include an NPC under a rotated parent in validation.
- Brake before arrival using distance and braking capability, then enter the pause after reaching the arrival region at low speed. Pass actual physics delta to normal deceleration; remove artificial one-second braking steps. Handle single-point routes consistently.
- Collision and ledge safety take priority over a soft stop. An emergency physics stop may be immediate while the visual pose blends out; do not lengthen stopping distance beyond the supported floor.
- Measure stuck progress over elapsed time/a window with a meaningful distance threshold. Do not count an intentional turn, pause, or successful slow final approach as blockage. Retain recovery for real obstructions.

## 5. Check source loops only when necessary

If a hitch remains at every loop boundary even at steady speed, inspect source keyframes and track interpolation. Correct the offending loop seam in an editable local animation resource or appropriate import setting, preserving rig motion and materials. Do not hide a bad loop by continually restarting it or applying huge crossfades. Report any source animation limitation that requires reauthoring.

## Validation and acceptance

- Both species visibly ease into and out of locomotion through repeated cycles, without pose pops or gait-speed jumps.
- Idle, gait, alert entry/exit, and alert interruption all blend; short pauses cannot leave a moving character stuck in alert.
- 90-degree and 180-degree turns show visible rotation without snapping or sustained sideways/backward movement. Model/body alignment remains correct under rotated parents.
- Normal waypoint arrivals decelerate smoothly. Slow movement and turning do not spuriously trigger blockage recovery.
- Obstacles and floor edges remain safe; no movement/collision regression is accepted to improve appearance.
- Two or more mice maintain independent animation state, including different speeds and overlapping alerts.
- Verify across at least 30 and 60 FPS render caps with the usual physics tick rate, and inspect steady locomotion across several loop boundaries.
- Add a focused automated regression check for effective playback rate, repeated transition stability, and alert interruption where practical; do not build a general test framework. Run headless parse/import and scene smoke checks with the installed compatible Godot version.
- Visually inspect NPCMovementTest and Demo_A2, then smoke-test Demo_A1 for Rook regressions. Headless checks alone cannot prove smoothness. If visual inspection is unavailable, explicitly mark it unverified.

## Expected changes and handoff

Primary files: `scripts/npc_animation_driver.gd`, `scripts/npc_controller.gd`, `Characters/Hound/hound_npc.tscn`, `Characters/Mouse/mouse_npc.tscn`, and `scenes/NPCMovementTest.tscn`. Add local animation resources only if the inspection justifies them. Update README with the new tuning exports and any asset limitations.

Report root causes confirmed, the chosen blend/turn settings, checks actually performed, and remaining visual limitations. This plan supersedes the original movement plan's simple AnimationPlayer-crossfade approach and strict stationary-facing rule where an intentional turn requires rotation.
