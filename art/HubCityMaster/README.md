# Hub City — Master Blockout

Open `Hub_City_Master_Blockout.blend`. This is one master scene containing the full initial city layout, with directly editable component meshes. Existing component-library files are unchanged.

## Working dimensions

- Footprint: 400 × 400 meters. Blender units are meters, Z up.
- Lagoon and lower river water: Z=2 m.
- Upper river water: Z=7 m, falling five meters at the mill.
- Lagoon islands: ground Z=4 m, with raised bridge crossings.
- Western apartment district: Z=6 m; civic terrace: Z=10 m.
- Fortified upper district: Z=26 m, 24 m above lagoon water.

These are starting design decisions, not dimensions recovered from the concept image. The scene uses real component proportions. The large city should be judged from both the overview and pedestrian cameras before increasing detail.

## What is in the scene

1. One editable terrain heightfield, including the submerged river/lagoon bed and five irregular inhabited islands.
2. Separate upper river, lower river/lagoon and waterfall meshes.
3. Primary circulation surfaces, switchback stairs and supported bridge blockouts.
4. Continuous island quay strips.
5. Existing Clock Hall, bathhouse, mill, apartment courts, varied storefront homes, warehouses, villas, fortifications and garden structures placed as editable mesh assemblies.
6. Independent low-detail building masses establishing district density and street gaps.
7. Representative trees and a preliminary lighting rig.
8. Independently hideable plan labels and six inspection cameras.

Collections are numbered in the Outliner. `09 PLAN LABELS` is hidden in the saved scene; enable it for the overhead plan. The master opens with the daylight overview camera. Switch the scene camera to `02 Dimensioned overhead`, or a pedestrian camera, to inspect another view.

All placed components are real mesh objects with independent mesh data. Select a wall, roof, window, tree or building mass in the viewport and press **Tab** to enter Edit Mode. Editing one object does not change other copies. Assembly empties remain as parent containers for moving a complete building; expand a container in the Outliner and select its mesh child to edit geometry. Select several mesh children and press Tab to edit them together.

`Hub_City_Master_Instanced_Backup.blend` preserves the earlier compact instance-based layout. The main `Hub_City_Master_Blockout.blend` is the editable version. `editability_validation.json` records the conversion, direct Edit Mode check and unchanged world-space geometry check.

## Inspection images

- `city_blockout_day.png`: overview for judging masses and elevations.
- `city_plan.png`: overhead layout with district labels and a 100 m scale bar.
- `city_blockout_night.png`: preliminary night lighting study.

The saved master retains daylight settings for easier editing. The night image is a separate study; it is not a replacement for the concept art.

## What this pass establishes—and what remains

This is an editable city-scale blockout, not a finished city scene. Building masses intentionally omit windows, doors and interiors. Streets, bridges and stairs establish route corridors; they still need local junction cleanup, railings, bridge arches, individual building entrances and final surface modeling. Secondary lanes currently read mostly as gaps between building masses. Guard patrols, collision, navigation, gameplay traversal, UVs, distant LODs and final water effects are not included in this Blender layout.

The lagoon is a common lower water level; the upper river is separated by the mill drop. Its mountain source and the city's outer landscape can extend beyond the current footprint. The next useful pass is the merchant-island → bridge → bathhouse/quay section, followed by a detailed mill approach and upper-gate ascent.

`layout_manifest.json` records dimensions, district hubs, route lengths, elevations, building counts and component placements. `validation.json` checks that the saved file reopens, instances resolve, mesh coordinates/face areas are valid, and all major district hubs are connected in the planned route graph. That graph check is not a collision or pedestrian-clearance test.

Generator: `tools/build_hub_city_master.py`. Validator: `tools/validate_hub_city_master.py`. Regeneration replaces the generated master file and previews; keep manually edited versions under another name.

## Surrounding world

`Hub_City_World.blend` adds the editable river valley, outer boroughs, hills, distant mountains and open estuary around this city. See `WORLD_BACKDROP.md` for its collections and previews. The original city master remains available independently.

## Terrain and street redesign

`Hub_City_Terrain_Study.blend` is the metre-scale terrain study built from the saved farm world. It develops the lagoon → civic terrace → upper-gate route with ridges, refitted building plots, retaining walls and measured stairs. See `TERRAIN_STUDY.md` and `terrain_pass_validation.json` for scope and checks.
