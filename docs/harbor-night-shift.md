# Night Shift at the Harbor

Open `Levels/HarborNightShift.tscn` and press **F6**, or run:

```sh
godot --path . Levels/HarborNightShift.tscn
```

Recover the three gold cargo seals in the Customs Hall, Salt Stores and Bonded
Archive, then return to the blue extraction circle unseen. Two Hounds patrol
independently. The arcades and wooden tide bridge form a complete loop, so you
can approach either storehouse first and choose another route home. The Salt
Stores offer a quieter space to regroup; the Archive has a second patrol and an
L-shaped screen around its objective.

WASD/arrows move relative to the camera, Shift slows movement, Space jumps,
**M** switches between the close following view and a full overview, **Tab**
toggles the sight overlays, and **R** restarts the entire encounter.

## Reference behavior and design decisions

The WereCleaner inspection in [reference-feature-study.md](reference-feature-study.md)
identified cone/range tests, raycast occlusion, and clamped detection accumulation.
This level reuses `StealthGuard` from the earlier study: awareness builds before
pursuit; losing sight preserves the last seen position; a bounded search ends in
a return to patrol. Full-height stone screens and the static cargo barrels block
the actual raycast. Lighting is visual feedback; darkness and lightning do not
change detection rules or reveal a player through a wall.

The harbor setting, loop, three pickups, two patrols, 1.25-second detection time,
and extraction rules are Rook design decisions. This is a playable adaptation
of the observed patterns rather than a recreation of the WereCleaner's layout.

## Reusable assets and editing

All geometry is saved in the scene; level construction does not run during play.
The navigation mesh bakes from static collision on startup and waits for server
registration before enabling the patrols.

- `NavigationRegion3D/Modules` contains instances of the existing straight,
  corner and bridge scenes. The two storehouses instance the same new
  `Modules/Rooms/HarborStorehouse.tscn`; the hall uses `HarborHall.tscn`.
  Both rooms expose the kit's four 6-meter connection markers.
- `PortCaps` beneath room instances close unused connections. Keep the cap
  collision when moving or duplicating them.
- `NavigationRegion3D/Cover` contains harbor wall screens and static barrels.
  `Modules/Props/CargoBarrel.tscn` reuses the existing barrel model and toon
  materials without the interactive barrel behavior. The level supplies its
  collision independently of the scaled art.
- `Details` contains the existing arch, grass and location signs. Camera-facing
  boundaries use stone parapets so characters remain visible.
- `CargoSeals` instances `Modules/Gameplay/CargoSeal.tscn`, a reusable player-only
  objective using existing coin art. The level counts pickups and requires all
  three plus no confirmed sight/pursuit to extract.
- `Guards` contains the reusable Hound models with the existing opt-in stealth
  script. Their ordered route markers are under `Routes`. Screens and props
  leave enough clearance for both full patrols.

The saved scene can be edited normally. To reconstruct this authored layout and
its two new room scenes, run the builder below. **It replaces those three saved
scenes**, so save hand-edited variants under another name first. It does not
rebuild the original connector kit or change the project's startup scene.

```sh
godot --headless --path . --script tools/build_harbor_night_shift.gd
```

## Lighting

The original harbor art retains its repaired shared toon shader and materials.
The environment is copied from Demo_A2, including its sky and ambient settings,
with its steady directional light disabled. All fixed spotlights duplicate
Demo_A2's white `SpotLight3D`: energy 1, range 10.035, cone half-angle 22.36 degrees,
zero distance attenuation, and the same angular falloff and shadow settings.
The reference's two white omni lights are repeated in each room at corresponding
heights above the floor. Each Hound's beam is white too; its detection-aligned
origin, direction, range, field of view, strength and shadow casting are retained.
Its own model is excluded from casting shadows into that lamp.

`StormFlashLight` reuses Demo_A2's exact `storm_flash_light.gd`, storm ambience and
three thunder sounds, including its variable flash timing, restrikes, fades and
storm rim suppression. Its shadow distance is expanded for the larger harbor.
Tune lamps under `HarborLights`, the two beams under `Guards`, and the storm on
`StormFlashLight`. The scene was rendered at night and during an actual flash;
the flash reached the requested peak and returned to darkness afterward.
The builder's `apply_demo_lighting()` applies this treatment to an existing
saved layout without regenerating its rooms, props, routes or objectives.

## Verification

```sh
godot --headless --path . --fixed-fps 60 --script tests/test_harbor_night_shift.gd
```

The integration suite checks both full patrol circuits, sight and cover,
navigation from the entrance to both storehouses and bridge, pursuit around the
customs screen, and a physical walk through the entire loop. That walk triggers
all three pickups and completes extraction via the opposite arcade. It also
checks duplicate/player-only pickups, sight/pursuit blocking extraction, capture,
restart, camera modes, movement input, saved lamps and Demo_A2 audio/script reuse.

All 31 harbor checks and the 31 existing stealth-study checks pass. The headless
runs still print the existing macOS certificate and storm shutdown/resource
messages also seen in the original study; these do not fail the assertions.
