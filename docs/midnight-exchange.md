# Midnight Exchange

Open `Levels/MidnightExchange.tscn` in Godot and press **F6**. This is a new,
editable level; the existing demo and harbor scenes remain available.

Move with WASD/arrows, slow walk with Shift, jump with Space, hold E to work at
the current objective, and press Q near a gold bell to make a distraction.
Tab cycles **HUD only → HUD + guard vision → guard vision only → everything hidden → Styled HUD**,
then returns to HUD only (the default). Hidden HUD includes all screen panels,
result messages, floating labels, player/objective/exit rings, and bell pulses. Guard
vision includes diagnostic sight cones and search markers. Tab still works after
a win or capture, so hidden results can be revealed. R restarts. The objective display gives a
distance and a direction relative to the camera. The full HUD keeps only that
objective line at the top left, a suspicion eye and guard caption at top center,
and a single controls line at the bottom. **Styled HUD** shows only the suspicion
eye and the coin counter, using the hand-drawn artwork. Coin pickups update the
counter even while another display mode is selected. The result panel appears
in either HUD option when a run ends; Styled HUD hides world labels and markers.

## Encounter

The 32 × 34 metre exchange has a protected arrival court, separate sorting and
crank wings, two doors into the vault gallery, and solid screens that make
circuits for escaping pursuit. There is no global deadline. The medium
challenge comes from choosing an opening and spending time exposed at a task.

1. Copy the west-wing manifest: hold E for 1.8 seconds while the sorting mouse
   looks away. Its two-second pauses display a countdown.
2. Release the east-wing vault crank: hold E for 2.2 seconds. The Hound's whole
   normal circuit stays within five metres of the crank, so waiting for the
   patrol alone does not clear it. Ring the east bell, go around the screen's
   north end, and work the crank while the Hound investigates the south side.
   A sighting and pursuit can also draw it away; break sight before working.
3. Recover the night seal: hold E for 2.6 seconds. The vault mouse circles a
   central screen; time its turn or use the gallery bell to move it.
4. Return to the blue arrival circle with no guard seeing or chasing Rook.

Work resets when E is released, Rook leaves, a guard sees Rook, or a chase is
active. Completed stages persist for the current attempt. Rook can recover
from a sighting by breaking sight and moving away from the last seen position.

## Mouse guards and distractions

Both mice use the existing Mouse_v2 model and animations with the opt-in guard
controller. Compared with the Hound they have shorter sight (8m versus 10m), a
wider field of view (110° versus 100°), and faster detection (0.85s versus 1.2s).
Their view cones are wider and longer than their separate lamp beams. Deep shadow
protects stationary Rook, while movement and footsteps can trigger investigation.
They can pursue and catch Rook, investigate sounds, search, and rejoin their
ordered patrols. Their patrols move at 1.65m/s, with a 3.15m/s chase; Rook moves
at 4.2m/s. Solid cover blocks real sight rays as well as the lamp feedback.

The three bells use the rigged bronze asset in `Mesh/Bell/bell.tscn`; its bell
and clapper swing independently when struck (see [the asset guide](bell.md)).
Bells require Rook within 2.3m. A strike has an audible chime and an expanding
ring. Idle guards within hearing distance investigate the bell for six seconds
on arrival, then return. A bell cannot override a confirmed sighting or chase.
The shared nine-second cooldown prevents repeatedly pinning a guard in place.

## Camera and lighting

The orthographic camera follows smoothly with modest movement lead. Its size
is 9.4, tighter than Demo_A2's 10.286; orientation stays fixed so movement remains
consistent while the camera follows Rook. The HUD's direction cue uses this
same orientation.

The builder copies Demo_A2's environment, disabled steady directional light,
paired omni fixtures, white spotlights, and exact storm/thunder script and
assets. Fixture energy, falloff, and cone settings are preserved; fixtures now cast
shadows so illumination obstruction is visible. The diagonal
spotlights are positioned to land their pools on the new objectives and routes.
The storm shadow distance covers the larger footprint. Lightning changes exposure wherever its light reaches Rook. Recognition requires
illumination, guard view, and unobstructed sight. See the
[awareness system document](guard-awareness.md) for the complete rules and tuning.

## Source and checks

The scene is saved geometry, not a level generated during play. Edit it in
Godot, or regenerate it from `scripts/midnight_exchange_builder.gd`:

```sh
godot --headless --path . --script tools/build_midnight_exchange.gd
godot --headless --path . --fixed-fps 60 --script tests/test_midnight_exchange.gd
```

Rebuilding replaces only `Levels/MidnightExchange.tscn`; save a hand-edited
variant under a different name first. The new scripts extend the existing
stealth controllers without changing the ambient NPCs or earlier encounters.

The 49 integration assertions exercise all five display modes, styled coin
collection, frozen eye feedback, and hidden results,
saved-scene navigation, every patrol
corner, physical movement through the full route, real mouse vision and
capture, ordered/interruptible work, a physical kite around the live Hound,
noise investigation and cooldown, extraction, restart, and camera following.
They do not establish a human difficulty rating; medium is the intended tuning
and should be refined with playtesting. Godot may print the existing macOS
certificate and storm-resource shutdown messages despite passing assertions.

To render four gameplay views and a shadow/lightning comparison into `/tmp/midnight-*.png`, use a real renderer:

```sh
godot --path . --audio-driver Dummy --script tools/preview_midnight_exchange.gd
```

## Reference

[The WereCleaner App Store feature](https://apps.apple.com/ca/iphone/story/id1747961948)
describes visible pause timers, throwable distractions, and a brief opportunity
to break sight. This encounter adapts those ideas to Rook through deterministic
pause countdowns, reusable noise bells, short exposed tasks, and cover loops.
The game's cleaning/combat systems are not part of this level.
