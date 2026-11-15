# Lamplight Store

Open `Levels/LamplightStore.tscn` in Godot and press **F6**. This isolated playable
encounter explores hide/peek interactions, switchable lighting, distinct guard
senses and a seamless exterior-to-interior camera transition. It uses our own
harbor floor, wall, arch, railing, barrel and plank assets with the Demo_A2
night environment, white spotlights, storm and thunder.

## Try the camera first

Press **P** to pause the guards. Walk north through the central archway. The
wide courtyard shot eases toward a closer view centered on the store interior.
The roof and camera-facing walls become a cutaway so they do not obscure Rook.
Walk back through the doorway to restore the wider shot and exterior shell.
There is no scene load, teleport or movement lock at the doorway.

The threshold has hysteresis: entering requires moving 0.4m inside the building
bounds; exiting requires moving 0.6m outside them. Standing in the doorway does
not repeatedly flip shots. Orthographic size eases from 30m to 15.5m, with a
corresponding change in camera offset and room-focused framing. The camera
continues updating while Rook is hidden. Peeking slightly shifts its focus.

`lamplight_player.gd` exposes `interior_bounds`, `exterior_camera_size`,
`interior_camera_size` and `camera_transition_rate` for tuning in the Inspector.
The scene's building shell uses render layer 19. Only the camera excludes that
layer indoors: roof and wall collision and light-shadow participation stay
active. The real roof blocks the sensor's lightning rays even in cutaway view.
The shell reveal is a discrete cutaway; the framing and zoom ease continuously.

## Explore the encounter

1. Enter the store and use **E** at the gold light-switch marker just left of
   the entrance. It switches both indoor white spotlights and changes actual
   exposure, not just the displayed brightness. Operating it makes a small noise.
2. Approach the blue marker between the barrels in the back-left alcove and
   press **E** to hide. Movement locks and Rook's visible model disappears.
   Hold **Q** to peek out of the alcove; release it to return to concealment.
   Peeking makes Rook eligible for normal visual detection. **E** leaves cover.
3. Press **P** again to resume the guards. The courtyard watchman uses ordinary
   light-dependent recognition and a lamp. The indoor tracker has no lamp, hears
   farther and senses Rook within 2.6m even in darkness or concealment. Solid
   walls block this close sense. Both still use graded detection and search;
   hearing does not instantly identify Rook.
4. Collect the ledger at the gold marker near the back wall with **E**, then
   return to the blue courtyard marker. **R** restarts after success or capture.

The ordinary watchman also retains close-contact recognition. Entering the
alcove while a guard already sees Rook is refused; hiding does not erase a
witnessed sighting. After losing line of sight, hiding can conceal Rook again.
The tracker patrol stays on the right side, but sounds can lure it toward the
alcove. These are Rook prototype rules, rather than a recreation of unverified
Mark of the Ninja hiding or dog-detection predicates.

The indoor tracker patrols and searches at **1.9 m/s**, pursues at **4.6 m/s**
and confirms a clear sighting in **0.9 seconds** at full recognition strength.
Its weak-evidence suspicion gain is **0.5 per second**, with investigation
starting after **0.45 seconds** of uncertain evidence. The existing heightened
recognition multiplier still applies after search or pursuit. All Hounds now share the same pursuit speed through the
[global movement baseline](movement-tuning.md). The courtyard watchman's
patrol speed and detection tuning remain unchanged.

Suspicion and pursuit use the shared animated notification. Indoors, its camera
occlusion ray ignores only the roof and walls that are cut away from the shot.
Normal visible geometry still occludes it. Returning outdoors restores the full
occlusion test; guard sight, collision and lightning shelter are unaffected.

| Control | Action |
| --- | --- |
| WASD / Shift / Space | Move / quiet movement / jump |
| E | Operate nearby switch, hide/leave, or collect ledger |
| Hold Q | Peek while concealed |
| Tab | Toggle guard vision overlays |
| P | Pause/resume guard AI for camera and interaction exploration |
| R | Restart the scene |

## Build and check

```sh
godot --headless --path . --script tools/build_lamplight_store.gd
godot --headless --path . --fixed-fps 60 --script tests/test_lamplight_store.gd
godot --path . --windowed --resolution 1440x900 --audio-driver Dummy \
  --script tools/preview_lamplight_store.gd
```

Rebuilding overwrites only `Levels/LamplightStore.tscn`. Keep layout changes in
`lamplight_store_builder.gd` to preserve them across rebuilds. The 35 integration
checks cover navigation, physical doorway traversal, camera easing and
hysteresis, saved mesh culling, lighting/exposure, lightning shelter,
hide/peek detection, tracker range and occlusion, capture, pause/resume,
interaction, completion, cutaway notification visibility and tracker tuning.
Renderer captures in `/private/tmp/lamplight-{exterior,interior,dark,hide,peek}.png`
verify the framing and cutaway. Captures freeze the storm illumination and guards
for repeatability; normal play uses the automatic storm. The reused storm may
report existing resource/ObjectDB cleanup warnings when a test exits.
