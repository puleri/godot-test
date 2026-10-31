# Performance note

Keep the lighting, atmosphere, and gameplay cues that make the game readable,
then reduce the cost of producing them. Optimize from measurements rather than
assuming that an effect, asset, or engine feature is the bottleneck.

This note distills the user-provided video transcript beginning “Is it Godot's
fault?” and applies it to this project, especially Midnight Exchange. The
video's reported improvement from roughly 50 FPS to a 75 FPS cap describes its
own scene and hardware. It is not a benchmark or predicted gain for this game.
The priorities below are proposed experiments; no optimization or new benchmark
was performed when writing this note.

## Priorities for this game

| Priority | Takeaway | Application |
| --- | --- | --- |
| 1 | Preserve the lighting; tune its shadows. | The Midnight Exchange builder enables shadows on every discovered `Light3D`. Measure lower shadow resolution, shorter directional shadow distance, and selective removal of decorative shadow casters before removing lights. |
| 2 | Keep visual shelter consistent with gameplay. | Guard lamps, cover shadows, and lightning communicate exposure. Check hiding places and lamp obstruction after every lighting change. |
| 3 | Compare one change at a time. | Use identical resolution, renderer, camera, and scene state. Record frame time, CPU/GPU timings, draw calls, and spikes alongside FPS. |
| 4 | Limit distant decoration and batch repeated meshes. | Use MultiMesh for large populations of identical static decoration, limit visibility distance, and avoid unnecessary decorative shadows. The harbor backdrop already uses batched meshes with shadows disabled. |
| 5 | Improve lighting and materials before stacking effects. | Preserve the authored toon lighting. Add GI, ambient occlusion, depth of field, or heavier anti-aliasing only when they solve a visible problem and their measured cost is worthwhile. Check support in the intended renderer and export target first. |
| 6 | Judge the result while playing. | Walk through the encounter and move the camera. Fog, vegetation, and screen-space shading must preserve clear paths, Rook's silhouette, objectives, and patrol beams. |

Relevant implementation:

- [Midnight Exchange builder](../scripts/midnight_exchange_builder.gd): registers
  lights for gameplay exposure and enables their visual shadows.
- [Exposure sensor](../scripts/stealth_exposure_sensor.gd): calculates illumination
  from light properties and physics rays, independently of rendered pixels.
- [Guard awareness guide](guard-awareness.md): explains illumination, obstruction,
  recognition, and readable toon lamp cones.
- [Harbor backdrop](../scripts/harbor_backdrop.gd): batches decorative silhouettes
  using MultiMesh and disables their shadows.

## Lighting changes must preserve stealth feedback

The exposure sensor reads light visibility, energy, position, range, cone, and
falloff, and checks obstruction using collision geometry. It does not inspect
the rendered shadow map. Removing visual shadows can therefore make a sheltered
area look illuminated while gameplay still considers it dark.

Start with shadow resolution and filtering experiments while retaining light
properties. When reducing directional shadow distance or decorative shadow
casters, check that visible shelter still matches gameplay obstruction. Changing
a registered light's energy, visibility, range, or cone also changes gameplay
exposure and needs encounter validation. Camera-based light disabling must not
silently change whether guards can detect Rook.

A character fill light, as suggested in the transcript, also needs deliberate
handling: keep a cosmetic fill outside `stealth_lights` and check that Rook still
looks appropriately hidden in deep shadow. Emissive windows and decorative glow
do not automatically contribute to the current exposure model.

## Repeatable profiling

Use the existing [profiling tool](../tools/profile_midnight_exchange.gd) with a
real renderer. For example, capture a comparison at 1920 × 1080:

```sh
godot --path . --audio-driver Dummy --disable-vsync --script tools/profile_midnight_exchange.gd -- --brief --resolution=1920x1080 --output=/tmp/midnight-performance-baseline-1080p.json
```

After changing one setting, run the same command with a different output name
and compare matching sample labels. The tool does not yet automate the shadow
and post-processing switches proposed in this note.

1. Choose the target hardware, renderer, export target, and frame budget. A
   proposed 60 FPS target allows about 16.7 ms per frame; confirm the intended
   target before using it as an acceptance criterion.
2. Match actual render sizes. The [project configuration](../project.godot) sets
   a 3840 × 2160 base viewport, while the profiler defaults to 1440 × 900 in an
   offscreen viewport. Check the report's `render_size`; window size alone is
   not sufficient. Compare equivalent workloads and test the shipping size.
3. Warm up the scene and compare the entry, sorting wing, crank wing, vault, and
   opening view. The tool settles before sampling and records mean, median,
   95th-percentile, and maximum frame times as well as render and physics metrics.
4. Inspect CPU and GPU timings and visible/shadow draw calls before choosing
   the next experiment. A high object count alone does not establish a bottleneck.
5. Repeat promising comparisons to distinguish consistent gains from noise.
   Keep a change only if the improvement and visual tradeoff are worthwhile.
6. Replay live gameplay, camera motion, moving lamps, and lightning. Validate
   the actual release export on target hardware, including the browser build
   when evaluating web performance.

The profiler disables the opening sequence and stops lightning. Most current
scene samples freeze actor movement; a separate sample enables the three live
guards, while animation trees remain active. It also builds synthetic ten-court,
30-guard, and animated-prop stress cases, including in brief mode. Use the
`current_*` samples for current-level comparisons and label stress results
separately. These controlled samples do not replace a moving gameplay test or
measure lightning spikes. Do not use headless runs as GPU performance evidence.

## First experiments

- **Shadow quality:** lower one shadow setting at a time. Preserve guard lamp
  obstruction, cover readability, and lightning shelter. Compare storm and
  non-storm gameplay separately.
- **Resolution:** compare 1920 × 1080 and 3840 × 2160 using explicit profiler
  resolutions to establish sensitivity to pixel count. This comparison tests
  resolution cost; it is not a same-workload comparison between optimizations.
- **Decoration:** test distance limits for small props and vegetation, and
  compare the opening view with and without the warehouse. MultiMesh reduces
  object submission overhead but does not make geometry or shading free.
- **Optional effects:** evaluate each effect independently at the gameplay
  camera distance. Start with light direction, ambient balance, and material
  response when improving appearance rather than adding every effect from the
  video's village demo.

For each retained experiment, record the exact setting change, engine and
renderer, hardware, export type, actual render size, sample label, before/after
frame timings, and a visual/gameplay verdict. A capped FPS result establishes
that the cap was reached, not the maximum achievable performance.
