# godot-test

A tiny Godot starter project with a first playable Rook controller.

## Getting Started

1. Install Godot 4.7.2 and its matching export templates.
2. Open this folder in Godot.
3. Press Run. Phase 1 uses WASD/Arrow keys for cardinal platform movement and Space to jump. Touch the glowing chessboard to switch into third-person movement.

## Player-two visual

`Rook/v2/Rook_v2-PlayerTwo.tscn` is an asset-only player-two variant. It uses the same model, skeleton, pose, and animations as the active rook, with a light toon body and dark accents. It is intentionally not spawned or wired to controls yet.

## Ambient NPCs

`Levels/Demo_A2.tscn` includes a patrolling Hound and three independently pausing Mice. The project startup scene remains `Demo_A1`; open Demo_A2 in Godot and use **Run Current Scene** to test the NPC integration. `scenes/NPCMovementTest.tscn` is a small movement smoke scene with an obstacle, an exposed floor boundary, and visible gold route markers.

The reusable wrappers are `Characters/Hound/hound_npc.tscn` and `Characters/Mouse/mouse_npc.tscn`. Their `NPCController` exports take a level-owned route `Node3D`, whose direct `Marker3D` children are the waypoints. Hounds use ordered routes; Mice choose a different waypoint at random. Tune speeds, acceleration, braking, arrival radius, pauses, optional alert chance, start delay, deterministic seed, and ground-probe distance on each wrapper instance. The `AnimationDriver` exports explicitly map idle/walk/run/alert clip names and reference speeds, plus blend-full speed, speed/playback smoothing, and independent locomotion blend-in/out times. It uses an instance-local AnimationTree, so gait rate and blend weight are smoothed separately and alert overlays fade over the continuously updated base pose.

The imported Idle clips are static poses rather than breathing cycles. Locomotion is driven by post-collision movement, loops while moving, and returns to that static idle pose when stopped. Clip orientation, foot contact, and root-motion quality still need a visual editor/gameplay inspection for any new character asset.

## Guard detection and hiding study

Open `Levels/StealthTraversalTest.tscn` and use **Run Current Scene (F6)**. Take the gold relic and return to the blue extraction circle unseen. WASD/arrow keys move relative to the overview camera, Shift slows movement, Space jumps, Tab toggles the guard vision overlay, and R resets the encounter. Full-height walls block sight; hiding means breaking line of sight rather than pressing a hide button.

The Hound patrols, builds awareness, pursues on detection, searches the last seen position, and returns to its route. Its navigation routes around cover. Tune sight range, field of view, awareness timing, search duration and capture distance on the scene's `Guard` node. The new scripts are specific to this study; the main scene, existing player controller and ambient NPC controller are unchanged.

The courtyard uses the existing darkness/toon shader, a shadow-casting Hound spotlight aligned with its sight origin, direction, range and angle, two overhead spotlights, and Demo_A2's lightning/thunder cycle. The debug cone starts hidden; Tab toggles it independently of the real light. Tune the fixed lights under `CourtyardLights`, the Hound's beam under `Guard/SightLight`, and storm timing under `StormFlashLight`. Lighting is visual feedback; detection still depends on the guard's view and cover.

The REA evidence, design choices and limits are recorded in `docs/reference-feature-study.md`. Run the focused checks with:

```sh
godot --headless --path . --fixed-fps 60 --script tests/test_stealth_guard.gd
```

The shared toon shader guards its specular calculations and handles zero-width
toon bands as hard steps, fixing black wedges around overlapping spotlights.
Run its GPU regression with a real renderer (without `--headless`):

```sh
godot --path . --audio-driver Dummy --script tests/test_toon_lighting.gd
```

## Modular level building

Open `Levels/ModularCourtyard.tscn` and press **F6** to explore a generated courtyard
built from the existing stone tiles, walls, arch, railings, grass, and barrel art.
WASD/arrows move, Space jumps, Tab switches cameras, and R returns to the entrance.
Select the scene root and click **Generate Courtyard** in the Inspector to rebuild
it with a different seed or dimensions. The result is a saved, editable scene;
regeneration replaces only the `Generated` subtree and supports undo.
See [the generator guide](docs/modular-courtyard.md) for variants, collision details,
and command-line generation and checks.

`Modules/Connectors/` contains reusable straight, corner, T-junction, staircase,
and wooden bridge scenes. Open `Levels/ConnectorKitDemo.tscn` and press **F6** to
walk the assembled branching route. Each module has connection markers and a
**Snap To Connection** Inspector action; they also fit the courtyard's entrance.
See [the connector kit guide](docs/connector-kit.md) for placement and scripted assembly.

## Night Shift at the Harbor

Open `Levels/HarborNightShift.tscn` and press **F6**. Recover three cargo seals
across a customs hall and two connected storehouses, evade two Hounds, and
return to the blue extraction circle unseen. The level uses the reusable
connector kit, harbor art, stone screens and barrels, with toon night lighting,
guard sight lamps and Demo_A2's lightning/thunder cycle.

WASD/arrows move, Shift slows movement, Space jumps, **M** toggles the full
overview, **Tab** toggles sight overlays, and **R** restarts. Layout editing,
rebuilding and checks are documented in [docs/harbor-night-shift.md](docs/harbor-night-shift.md).

## Midnight Exchange

Open `Levels/MidnightExchange.tscn` and press **F6** for a medium stealth puzzle
with Demo_A2's lighting and storm, a tighter camera following Rook, two mouse
guards, and a Hound. Time the manifest pickup, draw the Hound from the vault
crank, recover the seal, and return unseen. Hold **E** at objectives and press
**Q** near a gold bell to distract guards. See the [level guide](docs/midnight-exchange.md)
for controls, encounter tuning, rebuilding and the 34 integration checks.
The [guard awareness document](docs/guard-awareness.md) explains the implemented
light, shadow, hearing, and memory layers. Midnight Exchange now rewards staying
still in deep shadow, supports quiet footsteps and landing noise, and lets
spotlights, other guards’ lamps, and real lightning expose Rook.

## Procedural animation study

Open `scenes/ProceduralAnimationTest.tscn` and press **F6** to compare Rook's
head-first turning, planted steps, body weight shifts, cape follow-through and
landing recovery. **P** toggles the effects, **C** switches to a close camera,
**T** plays a motion demo, **Space** jumps, and **R** resets.
The shared Rook controller also enables the experiment in the existing levels.
See [the motion study guide](docs/procedural-animation.md) for tuning and checks.
Rook's base idle now keeps both feet planted while the body dips. This is baked
during FBX import and remains active with **P** off; see the
[idle animation guide](docs/rook-idle.md) for reimport instructions and checks.

## Rigged bell

`Mesh/Bell/bell.tscn` is the reusable bronze bell with oak supports, iron hardware,
and independent bell/clapper bones. Open `scenes/BellPreview.tscn` and press **F6**
to preview it: **Space** rings once, **L** loops, **R** rests. Midnight Exchange's
three bells now use this asset and animate when **Q** is pressed. The editable
Blender source, API and checks are described in [docs/bell.md](docs/bell.md).

## Blender reference library

`art/ComponentLibrary/Rook_Component_Library.blend` contains 44 reusable component
collections: building pieces, vegetation, props, characters, the storefront and
bell, connector/room modules, and existing entryway assemblies. It opens to a
labeled overview and includes a modeling workspace, asset catalogs and source
notes. See [the library guide](docs/component-library.md) for appending, linking,
editing and refreshing the components.

## Web export

The tracked `web/` directory is the release build served by Vercel. Regenerate it after gameplay or asset changes with Godot 4.7.2:

```sh
godot --headless --path . --export-release Web web/index.html
```

The `Web` preset is single-threaded, desktop-focused, and excludes `web/*` from the exported PCK so prior builds are never packaged into subsequent builds.

## Vercel

Import the repository into Vercel with the Framework Preset set to **Other**. The checked-in `vercel.json` skips a build step and serves `web/` as the static output directory. For CLI deployments, run `vercel` for a preview or `vercel --prod` for production from the repository root.
