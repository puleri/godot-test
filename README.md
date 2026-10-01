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

The reusable wrappers are `Characters/Hound/hound_npc.tscn` and `Characters/Mouse/mouse_npc.tscn`. Their `NPCController` exports take a level-owned route `Node3D`, whose direct `Marker3D` children are the waypoints. Hounds use ordered routes; Mice choose a different waypoint at random. Tune speeds, acceleration, braking, arrival radius, pauses, optional alert chance, start delay, deterministic seed, and ground-probe distance on each wrapper instance. The `AnimationDriver` exports explicitly map idle/walk/run/alert clip names and the matching reference speeds.

The imported Idle clips are static poses rather than breathing cycles. Locomotion is driven by post-collision movement, loops while moving, and returns to that static idle pose when stopped. Clip orientation, foot contact, and root-motion quality still need a visual editor/gameplay inspection for any new character asset.

## Web export

The tracked `web/` directory is the release build served by Vercel. Regenerate it after gameplay or asset changes with Godot 4.7.2:

```sh
godot --headless --path . --export-release Web web/index.html
```

The `Web` preset is single-threaded, desktop-focused, and excludes `web/*` from the exported PCK so prior builds are never packaged into subsequent builds.

## Vercel

Import the repository into Vercel with the Framework Preset set to **Other**. The checked-in `vercel.json` skips a build step and serves `web/` as the static output directory. For CLI deployments, run `vercel` for a preview or `vercel --prod` for production from the repository root.
