# Reference study and first stealth test level

The first guard-detection and hiding pass is implemented in
`Levels/StealthTraversalTest.tscn`, following the user's selection on October 20,
2026. The reference projects and installed game were inspected read-only.

The subsequent asset-based level is [Night Shift at the Harbor](harbor-night-shift.md),
saved in `Levels/HarborNightShift.tscn`. It reuses these guard rules in connected
modular rooms with two patrols, three objectives, and Demo_A2's storm treatment.

## Implemented first pass

Run the scene with F6 in Godot, or
`godot --path . Levels/StealthTraversalTest.tscn`.

- Existing Rook and Hound assets in a small, editable courtyard with three
  full-height cover walls, a gold relic and a blue extraction circle.
- Guard range and horizontal view angle, followed by a raycast to the player's
  sight point. Walls block both detection and capture. The overlay is clipped by
  the same blockers and shows the guard's horizontal sight footprint.
- Time-based awareness, suspicious/pursuing/searching/returning behavior,
  navigation around obstacles, and a bounded search of the last seen position.
  The hidden player's position does not update that remembered destination.
- An awareness bar, state feedback, optional vision overlay, capture/win feedback
  and scene restart. Extraction requires the relic and breaking visible pursuit.
- A fixed overview camera with camera-relative input, using a subclass of the
  existing player controller. Shift only slows movement; it does not confer
  invisibility. Cover and guard facing determine visibility.

`scripts/stealth_guard.gd` extends the ambient controller only for this scene;
`scripts/stealth_test_player.gd` and `scripts/stealth_test_level.gd` provide the
study's controls and encounter. Shared controllers and the startup scene are
unchanged. Navigation is baked from the study's static colliders on startup.

All 31 focused checks in `tests/test_stealth_guard.gd` pass, covering physical
occlusion, angle/range, frame-rate-independent awareness, hidden-position
memory, search/return, navigation around cover, reachable remembered positions,
capture, restart, player input, extraction and real-light alignment while turning.
The rendered scene was inspected in darkness and during a lightning flash.
`Demo_A2` also received a short headless startup smoke check.

The first pass adapts the reference patterns; its numbers and search rules are
Rook design choices, not a claim of exact WereCleaner behavior. The default
sight range is 7 units, the view angle is 80 degrees, detection takes 1.1 seconds
of uninterrupted sight, and searching lasts 4 seconds after arrival. These are
exposed on `Guard` for tuning after playtesting.

### Darkness and lighting pass

The scene's geometry now uses the existing `Materials/stylized.gdshader` from the
demo's toon material system. Constant directional illumination is replaced with
Demo_A2's `scripts/storm_flash_light.gd` and its ambience/thunder assets. Two
overhead spotlights light the entry and relic areas between flashes.

`Guard/SightLight` uses the detection eye origin, `sight_forward()`, `sight_range`
and half of the full field-of-view angle. World geometry casts shadows into the
beam. A dedicated render layer prevents the Hound's own head from blocking its
eye-origin lamp; the Hound still casts shadows from the other lights. The optional
debug fan starts hidden and does not control the real light. Darkness and
lightning are visual effects; this pass does not introduce illumination-based
changes to detection.

### Toon shader repair

The Hound's light exposed black wedges in the shared toon shader. Isolated
renders reproduced the wedges with spotlight shadows disabled; guarding the
specular power calculation removed them while keeping the material and lights.
`Materials/stylized.gdshader` now skips that calculation for disabled specular
or unlit pixels, bounds its input, and handles zero-width band, rim and pattern
transitions with explicit hard steps. Fresnel powers and zero band counts also
have defined boundary behavior. The existing diffuse response and storm rim
suppression remain in place.

`tests/test_toon_lighting.gd` renders smooth, stepped, specular, hard-rim and
zero-band materials. A non-shadowing spotlight must not erase illumination from
another light, tested in three directions. The original shader fails seven of
the 20 checks; the repaired shader passes all 20 on the Mac's Metal renderer.
The 31 stealth checks also pass. The courtyard and Demo_A2 were rendered for
visual verification with the shared shader.

Run the GPU check without `--headless`:

```sh
godot --path . --audio-driver Dummy --script tests/test_toon_lighting.gd
```

## Reference sources

### Sly Cooper: A Thief in Godot

Local project: `/Users/mattpuleri/Desktop/games/Sly-Cooper--A-Thief-in-Godot`.
It declares Godot 4.7 with Forward Plus rendering. The Rook project declares
Godot 4.7 with Compatibility rendering. The reference has not been run here.

Useful starting points, relative to the reference project:

| Feature | Evidence to inspect |
| --- | --- |
| Ledge grab and traversal targets | `Scripts/player__sly.gd`: `ledge_detect`, `apply_target`, `apply_magnetism`; target states for ropes, poles and ledges |
| Camera movement and obstruction | `Scripts/camera_parent.gd` |
| Guard vision and occlusion | `Scripts/spotlight_detection.gd`: an Area3D supplies a candidate target and a ray checks visibility |
| Guard behavior | `Scripts/enemy_base_flashlight.gd`: idle, chase, search and attack states; grounded sprinting can also trigger pursuit |
| Level construction | `Scenes/Worlds/paris.tscn`, `MonacoGreybox.tscn`, `development_test_room.tscn`, and `test_scene.tscn` |

Read the source directly for this reference. Adapt the behavior into small Rook
components: its controller depends on its own animation tree, scene hierarchy,
input actions and singleton managers, so copying the whole controller would be
a large integration task. A script being present does not verify runtime quality.

### The WereCleaner

Installed application: `/Applications/The WereCleaner.app`.

The installation contains `Contents/Frameworks/UnityPlayer.dylib` and a managed
gameplay assembly at
`Contents/Resources/Data/Managed/Assembly-CSharp.dll` (378,368 bytes at audit time).
This is a suitable starting point for REA's static managed-code inspection.
Hopper or Ghidra is not required for that route.

Start with a narrow question: **How does an NPC acquire and lose sight of the
player, and how does that change its behavior?**

For each investigation, keep three separate records:

1. Observed gameplay: repeatable inputs, what happened, and approximate timing.
2. Code evidence: assembly digest, type/method identity, relevant instructions,
   constants and dependencies. Scene/asset values can override code defaults.
3. Rook design decision: the rule to implement, tunable values, and checks that
   demonstrate the intended behavior. Label any remaining inference.

REA can inspect metadata and intermediate instructions; that does not guarantee
recovery of original C# source, scene geometry or every runtime value.

Initial REA 6.7.0 inspection succeeded with the managed static provider. It
classified the assembly as Unity Mono / CIL / AnyCPU, with complete metadata
coverage (392 TypeDef rows and 2,186 MethodDef rows). A focused member scan of
`NPCDetection`, `SuspiciousState` and `SuspiciousDarylState` matched all three
names and reported complete selected coverage for 26 methods.

Useful next investigation anchors:

| Member | Build-local metadata token |
| --- | --- |
| `NPCDetection.CanSeeItem` | `0x0600024f` |
| `NPCDetection.GetDetectionLevel` | `0x06000251` |
| `NPCDetection.IncreaseDetection` | `0x06000252` |
| `NPCDetection.DecreaseDetection` | `0x06000253` |
| `SuspiciousState.StateUpdate` | `0x0600028c` |

The field inventory also includes room, hallway and default cone radii/angles,
personal-space settings and a vision layer mask. These are verified member
names, not yet a verified explanation of their runtime behavior or tuned values.

The selected `CanSeeItem` method has complete decoded instruction coverage and
anchors that read cone radii/angles, call `Dot` and `Acos`, and then call
`Raycast` with the vision mask. `IncreaseDetection` and `DecreaseDetection` call
`Clamp` before updating the detection collection. These support the cone,
occlusion and bounded-awareness patterns used in the study. Context-dependent
room/hallway settings and personal-space overrides were not ported in this pass.

Assembly SHA-256:
`4dca533d66aef62628bc78137759402b8cc8b6accca2bbcb16d01d6218a7c583`.
Module MVID: `73adda44-8f10-46d0-835e-47ce6f44b46d`.
The metadata tokens above are meaningful only for this identified build.

Raw local reports: `/private/tmp/werecleaner-rea-artifact.json` and
`/private/tmp/werecleaner-rea-detection.json`. Temporary reports can be regenerated
if cleared; the identity and investigation anchors are retained in this document.

## Current Rook integration points

- `scripts/player_controller.gd` already supports several camera/control phases,
  jumping, acceleration and animation blending. Third-person movement currently
  turns the body with left/right input and moves forward/back; camera-relative
  movement would be a separate feature to evaluate.
- `scripts/npc_controller.gd` handles ordered/random routes, acceleration,
  stopping, edge probing and pauses. Its states are idle and moving. Its random
  alert animation is not a player-detection system.
- `Characters/Hound/hound_npc.tscn` supplies a reusable animated patrol character.
- `scenes/NPCMovementTest.tscn` is a useful precedent for an isolated test scene.

## Scene layout and next passes

Implemented path: `Levels/StealthTraversalTest.tscn`.

Build a small courtyard using simple geometry and the existing Rook/Hound assets:

1. A safe starting corner and clear view of the objective.
2. A ground route crossing one Hound's patrol, with two full-height cover walls.
3. Space for a future elevated alternate route after the stealth encounter is tuned.
4. One collectible objective and a marked escape area.
5. Visible guard state/awareness feedback, a restart control and fast respawn.

Implement in separate passes:

1. **Vision and cover (implemented).** Range, field of view and raycast occlusion; a tunable
   awareness increase/decrease; patrol, investigate, pursue and return states.
2. **Traversal (future).** Add one ledge grab/pull-up interaction after checking its fit
   with Rook's model, collision capsule and available animations.
3. **Third-person camera (future).** Evaluate orbit and obstruction handling
   in the same level. The current overview already has camera-relative movement.

These are proposed Rook rules, not claims about The WereCleaner's implementation.
Launch the new scene independently while experimenting; changes to shared
controllers should be opt-in so existing levels keep their established behavior.

## First-pass checks

- An unobstructed player in the guard's field of view raises awareness.
- A full-height wall blocks sight; a player behind the guard is not seen.
- Losing sight stops exact-position tracking; investigation uses the last seen
  position and eventually returns to the route.
- Detection timing is based on elapsed time rather than frame counts.
- Capture/restart reliably resets the guard, objective and player.
- After changes to shared code, existing Rook movement and ambient patrols still
  behave as before.

## Tool readiness

No REA MCP connection or `rea` executable was initially found in this chat's environment.
Node 24.20.0 is installed and satisfies the documented REA Node 24 requirement;
the default shell Node 20 does not. The initial inspections ran successfully
using a temporary npm-based CLI, without registering an MCP server or installing
an analysis engine. No restart is needed to continue with this CLI route.

Official documentation:

- https://github.com/morluto/rea
- https://github.com/morluto/rea/blob/main/docs/managed-code-analysis.md
