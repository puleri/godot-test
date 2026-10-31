# Midnight Exchange performance audit

Measured on 2026-10-30 using Godot 4.7.2 on an Apple M1 Pro, 14 GPU cores,
32 GB RAM. The current saved level, including its four harbor backdrop
instances and North Quay warehouse, was audited without changing the level.

## Assessment

A level with ten times the courtyard content is plausible on native desktop
at a controlled resolution with the current close camera. The fully rendered
4K stress case requires further optimization. Frustum culling keeps the visible workload
bounded. More independently animated actors, detailed multi-part props and
wide views need explicit budgets. The Compatibility renderer is substantially
more expensive for the expanded wide view; native Forward+ results do not
establish web performance.

The first scaling work should address shared geometry/materials, animation and
AI activity, and building/prop LOD. Blanket occlusion culling did little for
this open, overhead layout in the experiment below.

## Method and limits

`tools/profile_midnight_exchange.gd` instantiates the saved scene and writes
JSON statistics. It constructs temporary test content in memory and never
saves the level. The expansion repeats courtyard render/collision geometry
and a warehouse in a 5 by 2 arrangement: ten courts, not ten times each linear
dimension. It retains the existing four backdrops and fixed encounter lights.
The population rises from 3 to 30 existing guard controllers, adding their
27 headlamps. Forty additional rigged bells then loop their animation.

Camera comparisons freeze guard movement while leaving animation trees active.
Population tests enable guard physics. The player and encounter UI/game logic
remain frozen, and lightning is stopped. The wide camera matches the opening's
initial pose; it does not reproduce its temporary fill light or paused-actor
timeline. Remote courts have collision and patrol routes but no expanded baked
navigation map. These tests do not establish chase/pathfinding, crowd avoidance,
rigid-body pileups, loading times or the cost of repeating every fixed light.

The recorded completed cases warm up before collecting 120 frames. The tool
now also bounds warmup and sampling time for very slow cases. An exact-size SubViewport
avoids Retina/window sizing changes. The normal-window option is used for
Compatibility. Explicit RenderingServer draws prevent macOS window occlusion
from leaving stale camera counters. Frame intervals include engine/CPU work
and rendering submission, with no presentation; they are diagnostic timings,
not a shipping FPS guarantee. GPU timing returned zero and is unavailable in
these runs. Godot's process/physics monitors update less often than each frame,
so their percentiles are not independent per-frame CPU samples.

## Measurements

| Renderer / size | Case | Visible draws | Median interval | P95 interval |
|---|---|---:|---:|---:|
| Forward+ / 1440×900 | Current entry, 3 guards | 41 | 5.4 ms | 8.5 ms |
| Forward+ / 1440×900 | 10 courts, entry, 30 guards | 41 | 8.1 ms | 15.6 ms |
| Forward+ / 1440×900 | 10 courts, wide, 30 guards | 314 | 14.4 ms | 15.5 ms |
| Forward+ / 1440×900 | 10 courts, wide, 30 guards + 40 bells | 914 | 15.0 ms | 17.5 ms |
| Forward+ / 3840×2160 | Current entry, 3 guards | 47 | 22.4 ms | 24.3 ms |
| Forward+ / 3840×2160 | 10 courts, entry, 30 guards | 47 | 38.1 ms | 44.7 ms |
| Forward+ / 3840×2160 | 10 courts, wide, 30 guards | 328 | 40.4 ms | 45.8 ms |
| Forward+ / 3840×2160 | 10 courts, wide, 30 guards + 40 bells | 930 | 40.7 ms | 47.7 ms |
| Compatibility / 1440×900 | Current entry, 3 guards | 1,992 | 24.3 ms | 32.3 ms |
| Compatibility / 1440×900 | 10 courts, entry, 30 guards | 1,271 | 16.6 ms | 20.7 ms |
| Compatibility / 1440×900 | 10 courts, wide, 30 guards | 7,406 | 91.7 ms | 104.5 ms |

Native desktop at 1440×900 is the most promising configuration. The fully
rendered 4K expansion is substantially over a 16.7 ms frame budget in this
diagnostic workload. Compatibility is already expensive with 30 guards in
the wide view. The last Compatibility case with 40 additional bells did
not complete; no result or FPS claim is reported for that case.

Full recorded data: [midnight-exchange-2026-10-30.json](performance/midnight-exchange-2026-10-30.json).


Draw-call columns above use Godot's visible-pass counter. Forward+ shadow
passes and canvas draws add work. Compatibility groups passes differently,
so use its timings and counters as a separate renderer workload rather than
treating its visible count as equivalent to Forward+'s base material pass.

## Draw calls and instancing

The saved scene contains **437 MeshInstance3D nodes, 805 surfaces, 49 distinct
mesh resources and 53 material resources**. Those are scene inventory counts,
not frame draw calls. Its 366 courtyard meshes account for 699 surfaces but
only 7 mesh/material combinations, making shared instancing particularly useful.

The four harbor instances already use **28 MultiMesh batches for 1,756 pieces**.
Their decorative geometry has no collision or shadows. Keep this approach,
but split future large batches by spatial area: individual MultiMesh instances
cannot be frustum/occlusion culled independently. Each harbor instance also
creates a 1,200 m water plane; consolidating the four overlapping water planes
is a reasonable cleanup to benchmark.

Forward+ automatically instances compatible opaque meshes with shared mesh
and material resources. Mobile and Compatibility do not provide that automatic
path. Use explicit, spatially divided MultiMeshes for repeated tiles, walls,
vegetation and simple props when targeting those renderers.
[Godot automatic instancing](https://docs.godotengine.org/en/latest/tutorials/performance/optimizing_3d_performance.html#use-automatic-instancing),
[MultiMesh culling limits](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).

The warehouse script creates a new shader and palette per building instance
(`Mesh/StoneWarehouse/stone_warehouse_materials.gd:21`). Sharing these resources
across buildings would preserve more opportunities for instancing. Its five
meshes have 24 material surfaces and approximately 134,830 base triangles.

Each added bell has ten mesh instances and fifteen surfaces. Forty visible
bells add approximately **600 visible-pass draw calls** in Forward+. For large
numbers of similar moving props, share unskinned support meshes/materials,
combine compatible surfaces, and animate the necessary rigid pieces. A simple
rotating crate and this multi-part skeletal bell have different cost profiles.

## LOD at distance

LOD data exists on 683 of the courtyard's 699 surfaces and 17 of the
warehouse's 24 surfaces. Import settings alone are not the basis for this
finding: the audit inspects the loaded rendering mesh data and compares actual
primitive counters with LOD enabled and disabled.

The isolated warehouse test, at a 1 pixel LOD threshold and 1440 by 900:

| Distance | LOD on: primitives | LOD off: primitives | Reduction |
|---|---:|---:|---:|
| 15 m | 133,248 | 134,838 | 1.2% |
| 50 m | 133,248 | 134,838 | 1.2% |
| 150 m | 58,584 | 134,838 | 56.6% |

The warehouse remains close to full geometry at 15 and 50 m. A simpler
whole-building representation could reduce both its geometry and surface count
earlier. Compare LOD bias/threshold adjustments visually before adopting them.

Automatic LOD uses projected screen size, including resolution and field of
view. The close orthographic gameplay camera keeps object scale relatively
constant; distance alone is not a reliable way to budget that view. LOD reduces
triangles without necessarily reducing surfaces, draw submissions, AI or
skeleton updates. [Godot mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html).

## Occlusion culling

The saved level has **zero occluders**, occlusion is disabled, and no geometry
has an authored visibility range. Frustum culling is already effective.

An experimental pass enabled occlusion with 910 simplified static box
occluders derived from wall, cover and closed warehouse collision boxes.
Actors and animated props were excluded. This is a performance probe; these
proxies have not been approved as production occluder geometry.

The entry remained at 41 visible draws with occlusion off or on. The vault
remained at 60. The expanded wide view fell from 914 to 893 visible draws
and from 1,767,240 to 1,730,344 primitives, a 2.1% reduction.
Median intervals did not improve; render CPU time increased in this test.

The camera sees much of the courtyard from above and many background batches
have large bounds, leaving few fully hidden objects. Focus future occluder work
on tall buildings, enclosed streets and interiors with actual hidden content.
The CPU work of testing occlusion must earn its cost. Static collision walls
and guard sight rays do not automatically create rendering occluders.
[Godot occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html).

## NPC, animation and world activity

All active guards currently run movement, perception and feedback at the physics
rate. Each guard owns an animation tree and skeleton; visibility does not stop
this work. The observed physics monitor grows from roughly 1–1.5 ms with three
guards to several milliseconds with thirty, including when most guards are
offscreen. Thirty guards are a useful test point, not evidence that hundreds
will scale linearly within budget.

`NPCAnimationDriver` deep-copies its animation library per instance. This is
intentional isolation, but copying immutable animation data could be reduced
after separating it from per-instance playback state. Each guard also creates
labels, feedback meshes and a suspicion bubble. Hidden diagnostic feedback
should avoid unnecessary work as population increases.

`StealthExposureSensor` scans its registered lights at each physics tick.
Guard hearing casts an obstruction ray before rejecting distant sounds.
Spatial filtering and distance rejection before expensive queries would help
larger populations. Keep full simulation for nearby threats and active pursuits;
use reduced update rates or dormant simulation for distant, irrelevant actors.
Do not tie gameplay awareness solely to whether a mesh is onscreen.

The current level synchronously bakes one navigation region in `_ready()`.
For a much larger map, save baked navigation and partition the world into
manageable regions/chunks. Rendering culling alone does not unload nodes,
collision, animation state or script updates. The ten-court geometry test
already increases the node count from about 2,100 to about 18,800 before
additional actors/props.

## Recommended sequence

1. Establish separate Forward+ desktop and Compatibility/web budgets. Preserve
   shared meshes/materials and add explicit regional MultiMeshes where needed.
2. Reduce surfaces and skeleton overhead in props expected to repeat widely;
   share warehouse shader/material resources and author a cheaper building LOD.
3. Add NPC activity distances/update rates, stagger perception queries, and
   budget animation separately from AI and navigation.
4. Use saved navigation and world regions to limit active simulation and loading.
5. Add occluders where a measured camera view shows a meaningful reduction.
6. Profile shadow submissions and shader fill after those structural budgets.
   Shadow work is substantial, but changing lighting alone does not address
   the prop, simulation or Compatibility submission costs observed here.

## Reproduce

```sh
godot --headless --path . --script tools/profile_midnight_exchange.gd -- --inventory-only
godot --path . --audio-driver Dummy --disable-vsync --script tools/profile_midnight_exchange.gd
godot --path . --audio-driver Dummy --disable-vsync --script tools/profile_midnight_exchange.gd -- --brief --resolution=3840x2160 --output=/tmp/midnight-performance-4k.json
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --audio-driver Dummy --disable-vsync --script tools/profile_midnight_exchange.gd -- --brief --window-viewport --output=/tmp/midnight-performance-compat.json
```

The JSON includes per-case camera names, actual render sizes, draw counters,
frame intervals, render CPU/GPU readings, memory and scene inventory. The tool
also saves native entry and expanded-wide screenshots beside the output JSON;
Compatibility readbacks are skipped.

Verification: the final profiler parses and the headless inventory completes.
The two native render runs completed all cases without script or shader errors.
The Compatibility run completed 12 cases before it was stopped in its final
case. Headless runs emit the existing macOS certificate and shutdown resource
messages; earlier Compatibility shutdowns also emitted GL texture cleanup errors.
