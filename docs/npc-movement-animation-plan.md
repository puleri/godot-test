# Hound and Mouse NPC movement and animation

Implementation handoff for Terra. Planning only; gameplay has not been changed.

## Goal and scope

Make the Hound and three Mice in `Levels/Demo_A2.tscn` autonomous NPCs with collision-aware movement, readable facing, and animations driven by actual movement. The user confirmed NPCs, not playable characters.

Proposed first-pass behavior: the Hound patrols a short authored route at a walk; the Mice scurry between nearby authored points with individually varied pauses. These are ambient behaviors. Chasing, combat, fleeing from the player, jumping, and character switching are outside this implementation. Keep the existing Rook controls, cameras, interactions, and project startup scene intact.

## Verified starting point

- `Characters/Hound/hound_v2.tscn` and `Characters/Mouse/mouse_v2.tscn` are visual scenes inheriting imported FBX assets. They have material and skeleton-pose overrides, but no added movement controller or physics body.
- `Levels/Demo_A2.tscn` contains `Hound_v2`, `Mouse_v2`, `Mouse_v3`, and `Mouse_v4`, all at scale 0.5. It has floor collision but no authored navigation nodes in its scene file.
- `project.godot` starts `Levels/Demo_A1.tscn`. Test the NPC integration by running Demo_A2 explicitly.
- `scripts/player_controller.gd` combines Rook movement, camera phases, interactions, and animation logic tied to `Skeleton|...` clip names. Do not attach or duplicate this controller for the NPCs.
- The installed engine reports Godot 4.7.2 and the project declares 4.7; README's 4.6.3 instruction is stale. Verify with the installed/project-compatible engine.
- Direct headless scene inspection found an `AnimationPlayer` at `AnimationPlayer` in each visual scene and these imported clips. All currently report loop mode NONE.

| Character | Clip | Duration | Intended use |
| --- | --- | --- | --- |
| Hound | `Root\|Idle` | 0.001 s | Stationary pose |
| Hound | `Root\|Walk` | 2.5 s | Default patrol gait |
| Hound | `Root\|Walk-StopMotion` | 0.625 s | Optional alternative; compare visually |
| Hound | `Root\|Run` | 0.667 s | Supported gait, not default patrol |
| Hound | `Root\|Alert` | 0.542 s | Optional pause accent |
| Hound | `Root\|Eating`, `Root\|Sit`, `Root\|Sniff` | 0.001 s each | Poses, not full actions |
| Mouse | `Root\|Idle` | 0.001 s | Stationary pose |
| Mouse | `Root\|Walk01` | 1.25 s | Slow locomotion |
| Mouse | `Root\|Run` | 1.25 s | Scurry gait |
| Mouse | `Root\|Alert` | 0.333 s | Optional pause accent |
| Mouse | `Root\|KO` | 0.001 s | Out of scope |

Clip presence and duration are verified; facing axes, foot contact, root displacement, and visual quality still require editor inspection. Do not describe the static poses as breathing/eating/sniffing animation cycles.

## Implementation sequence

### 1. Inspect clips and build reusable actor scenes

Create `Characters/Hound/hound_npc.tscn` and `Characters/Mouse/mouse_npc.tscn`, wrapping the existing v2 visual scenes:

```text
CharacterBody3D (npc_controller.gd; group: npcs)
  CollisionShape3D
  VisualPivot
    Model (existing v2 visual scene, including AnimationPlayer)
  AnimationDriver (npc_animation_driver.gd)
```

- Keep body scale at `(1, 1, 1)`; put the existing 0.5 visual scale on the model/pivot and size the collision shape directly. Do not copy the level's scale onto both wrapper and model.
- Fit a simple capsule or box around each torso, excluding tail and decorative parts. Set the body origin at ground level and adjust the visual offset so feet meet the floor.
- Inspect idle, walk, run, and alert on both models. Confirm the forward axis and expose a per-character visual yaw offset. Rotate the visual pivot without tilting the physics body.
- Check whether inherited skeleton-pose overrides conflict with animation tracks. Remove only conflicting overrides if necessary, retaining materials and intentional visual settings.
- Check for animated root translation/rotation. Use in-place locomotion: physics owns world movement. If clips move the model away from its body, correct the relevant tracks/import settings without removing normal skeletal bobbing. Do not edit FBX binaries or generated `.godot` files.

### 2. Implement bounded patrol movement

Add `scripts/npc_controller.gd`, shared by both characters. Use a small behavior state machine: `IDLE`, `MOVING`, and optional `ALERT`.

- Export a route node path, walk/run speeds, acceleration, braking, turn speed, arrival radius, pause range, locomotion gait, and an optional deterministic random seed.
- Store route points as level-owned `Marker3D` children under a stationary route `Node3D`, not children of the moving NPC. Resolve targets in world space.
- Hound: follow route points in order, looping after the last point, with a short pause at each arrival.
- Mouse: choose another point from its own local route, scurry there, then pause. Avoid selecting the current point when alternatives exist. Use independent random generators/start delays so the three mice do not synchronize.
- No route or no valid points: safely remain idle and report one actionable configuration warning. One point: approach it, then stay idle without a busy arrival loop.
- In `_physics_process`, accelerate/brake horizontal velocity toward the target, apply gravity, and call `move_and_slide()`. Reduce speed near arrivals to avoid overshooting and oscillation. Keep vertical physics active during pauses.
- Turn toward actual horizontal movement with smooth yaw interpolation; retain facing while stationary.
- Detect lack of progress while trying to move. After a configurable timeout, stop, wait, then try another valid waypoint or retry later. Never teleport through an obstacle or remain in an endless walking-in-place state.
- Add a forward/down ground probe sized to the character footprint and stopping distance. Brake before unsupported edges; do not pick points across gaps or on inaccessible levels.
- Use short, hand-authored routes on connected, clear floor for this first pass. Collision sliding is not pathfinding: if the intended route requires navigating around architecture, add a bounded navigation region and agent as a follow-up rather than claiming waypoint steering solves it.

Initial tuning values, to adjust after seeing scale and stride: Hound walk 0.8 units/s, pause 1–3 s; Mouse run 1.2 units/s, pause 0.5–2 s. Keep each route near its original placement and out of the player's critical path.

### 3. Add character-specific animation playback

Add `scripts/npc_animation_driver.gd` with explicit exported `AnimationPlayer` path and idle/walk/run/alert clip names. Configure exact mappings in each NPC scene; never infer Rook clip names.

- Use `AnimationPlayer` crossfades for this small state set; begin around 0.12–0.18 s and tune visually. An AnimationTree is unnecessary unless actual blend quality warrants it.
- Configure walk/run loops and keep alert one-shot. Hold idle as a pose. Make mutable animation resources instance-local, or configure loops through authored import settings, so one NPC cannot change another's playback resources.
- Drive idle versus locomotion from measured horizontal displacement after collision resolution, not requested target velocity. Smooth the speed signal and use separate start/stop thresholds to prevent flickering near zero.
- Select the configured walk or run gait during movement. Scale playback by actual speed relative to a per-clip reference travel speed, within sensible bounds, to reduce foot sliding. Verify the differing Hound walk clip durations visually before selecting an alternative.
- Start clips only when state/gait changes; do not restart them every frame. Reset playback speed to 1 for idle and alert.
- Optional alert accents may play during a pause, with a cooldown; return to idle when the clip finishes. Route logic owns movement and pause timing. Missing alert skips the accent, and no behavior waits indefinitely for an animation signal.
- Missing run falls back to walk; missing locomotion or idle uses the best available safe pose and warns once with character and clip name. A missing AnimationPlayer must not break movement. Acceptance for the supplied assets still requires correctly configured clips.
- If extra idle life is desired later, author a deliberate additive animation; a static imported idle pose is acceptable for this pass.

### 4. Integrate into Demo_A2 and protect interactions

- Replace the four visual-only instances with the NPC wrapper scenes, retaining names and approximate placements. Recalculate ground-height offsets for the new body origin.
- Add one Hound route and three small Mouse routes as level-owned markers. Inspect geometry around their existing positions before placing routes; do not choose coordinates blindly.
- Give NPCs a dedicated collision layer (choose an unused bit after auditing inherited geometry). Let them collide with world geometry. For this first pass, NPCs should not block the Rook or one another; configure masks accordingly and verify actual behavior in both directions.
- Audit player-only Areas. In particular, `scripts/Collectibles.gd` currently collects on **any** body entering; add a player-only guard consistent with the existing `CharacterBody3D` + `Player` convention. Layer filtering should also exclude NPCs from player-only triggers.
- Confirm doors, barrels, pressure plates, and camera-flip triggers keep their player-only behavior. Several already check `body.name == "Player"`; do not rename NPC roots to `Player` or add them to player groups.
- Leave `Demo_A1`, the Rook controller, player cameras/input bindings, and project main scene unchanged. Do not regenerate the tracked web release or deploy as part of this task.

### 5. Validate and document

Create a compact `scenes/NPCMovementTest.tscn` with both species, two independent mice, a floor, an obstacle, an exposed edge, and visible route markers. Keep this focused on exercising movement and animation rather than building a test framework.

Acceptance checks:

1. Both actors spawn grounded at the expected size, retain materials, and face travel direction correctly.
2. Hound visibly patrols; three mice independently alternate between scurrying and pauses for at least two minutes in Demo_A2.
3. Walk/run loops continue across multiple cycles; stopping settles into idle without restarting clips or repeated transition flicker. Feet do not visibly drift far from the collision body.
4. Blocking a route makes the NPC stop/recover without clipping through the obstacle; approaching an edge brakes safely. Missing, single-point, and unreachable routes remain stable.
5. Per-instance pause randomness and animation playback are independent. Optional alert plays once and returns to idle.
6. NPCs crossing a coin or player trigger do not collect coins, move cameras, activate plates, knock on doors, or enter barrels. Rook still performs those existing interactions.
7. Run Demo_A1 as a regression check and Demo_A2 for integration. Check logs for missing clips, invalid node paths, physics warnings, and parse errors. Record pre-existing failures separately.
8. Run a headless project import/parse check and brief scene smoke runs with the installed compatible engine. Headless checks cannot establish visual animation quality; also inspect in the editor/game viewport.

Update README with how to run Demo_A2/the test scene, how to assign routes and clip names, tuning exports, and the static-idle limitation. Include a brief completion report naming files changed and validation actually performed.

## Expected files

- New: `scripts/npc_controller.gd`, `scripts/npc_animation_driver.gd`.
- New: `Characters/Hound/hound_npc.tscn`, `Characters/Mouse/mouse_npc.tscn`.
- New: `scenes/NPCMovementTest.tscn`.
- Modified: `Levels/Demo_A2.tscn`, `scripts/Collectibles.gd`, `README.md`.
- Conditional: v2 visual scenes/import settings for verified pose or root-motion issues; collision layer settings only as needed after auditing the scene.

## Prompt to hand to Terra

Implement `docs/npc-movement-animation-plan.md`. The new Hound and Mouse are autonomous ambient NPCs. Start by verifying visual orientation, clip motion, and collider dimensions, then implement shared patrol movement and character-specific animation playback, integrate the existing four instances in Demo_A2, and complete the acceptance checks. Preserve Rook gameplay and the project startup scene. Do not deploy or regenerate the web release. Report any asset limitations and distinguish checks actually run from those still needing manual verification.
