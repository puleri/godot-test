# godot-test

A tiny Godot starter project with a first playable Rook controller.

## Getting Started

1. Install Godot 4.6.3 and its matching export templates.
2. Open this folder in Godot.
3. Press Run. Phase 1 uses WASD/Arrow keys for cardinal platform movement and Space to jump. Touch the glowing chessboard to switch into third-person movement.

## Player-two visual

`Rook/v2/Rook_v2-PlayerTwo.tscn` is an asset-only player-two variant. It uses the same model, skeleton, pose, and animations as the active rook, with a light toon body and dark accents. It is intentionally not spawned or wired to controls yet.

## Web export

The tracked `web/` directory is the release build served by Vercel. Regenerate it after gameplay or asset changes with Godot 4.6.3:

```sh
godot --headless --path . --export-release Web web/index.html
```

The `Web` preset is single-threaded, desktop-focused, and excludes `web/*` from the exported PCK so prior builds are never packaged into subsequent builds.

## Vercel

Import the repository into Vercel with the Framework Preset set to **Other**. The checked-in `vercel.json` skips a build step and serves `web/` as the static output directory. For CLI deployments, run `vercel` for a preview or `vercel --prod` for production from the repository root.
