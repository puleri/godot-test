# Foliage and worn road verges

`Hub_City_Foliage_Study.blend` extends the saved metre-scale terrain study without overwriting it. The civic approach and upper-gate corridor have a planted verge pilot. The whole core terrain carries an authored road-wear color mask.

## Worn ground

The mask uses three-dimensional proximity to actual route meshes. The strongest brown earth lies beside paving and blends back to green over about 2.5 m, with small irregularities along the edge. Roads more than 1.6 m vertically away do not paint terrain beneath bridges. Paved road materials remain unchanged.

Terrain has editable point attributes `road_wear` (float) and `RoadWearColor` (color). The terrain material reads RoadWearColor. Retain vertex colors when exporting terrain to Godot. Wear is authored, not a persistent footstep accumulation system. Regeneration derives both color and planting density from road geometry; manually changing the float mask alone does not regenerate colors or scatter.

Ground-cover density is multiplied by (1 - wear)^2. Placement excludes paving, nearby parcel geometry, overhead buildings, water and slopes steeper than about 35 degrees. Shrubs and trees are kept farther from roads. Plant objects share editable mesh data; make a mesh single-user before polishing only one placement.

## Runtime foliage

Instance `res://scenes/hub_foliage/HubFoliage.tscn` at the same origin as the metre-scale city export, with scale 1. The Blender Z-up coordinates are converted to Godot Y-up. This is a reusable foliage overlay; the existing main game level has not been replaced or connected to this Blender city study.

`Assets/HubFoliage/placements.json` and `meshes.json` contain deterministic placements and flat-shaded opaque vertex-color meshes. The runtime batches by asset and spatial cell: 20 m for ground plants/shrubs, 40 m for trees. Each batch has one material surface. Bounds include geometry extents and 0.5 m for potential future wind; wind is not yet implemented.

Distances are measured conservatively from the cell bounding sphere: detailed ground cover switches at 18 m and disappears at 35 m; shrubs switch at 45 m and disappear at 90 m; trees switch at 65/140 m and disappear at 250 m. Because of the cell radius, individual plants can remain farther away. The cutoff gets a deterministic 0–5 m offset per batch. Transitions use 2 m hysteresis and exclusive LOD switching, not alpha fading; mesh swaps can still be visible. No full-scene occluders or distant woodland replacement has been built in this pilot. Godot's normal frustum culling acts on each MultiMesh bound.

Ground cover and simplified meshes do not cast shadows. This project uses Compatibility, so do not assume Forward+ occlusion/fade behavior. Frame rate, shadow cost, and transition appearance need a rendered Godot playtest on the target hardware. The headless check validates near/far switching, mutually exclusive LOD visibility, instance counts and bounds.

Run validation:

`/Applications/Godot.app/Contents/MacOS/Godot --headless --log-file /tmp/hub-foliage-validation.log --path . --script tools/validate_hub_foliage.gd`

Regenerate with `tools/build_hub_city_foliage_pass.py` using Blender. Save manual edits under another filename before regenerating.
