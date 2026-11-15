# City terrain and street study

Open `Hub_City_Terrain_Study.blend`. This first terrain pass concentrates on the lagoon, western approach, civic terrace and upper-gate ascent. The earlier farm world remains available unchanged.

## Scale and editing

The shared 3.3517× world scale and translation have been reversed. One Blender unit now represents one metre. Relative saved placements and edits are retained before the terrain-specific changes are applied. A 1.8 m reference figure stands in the civic square.

The file includes overview/detail workspace setup and inspection cameras 11–14. For detailed editing, select a building or terrain vertices and use View → Frame Selected. Hold Shift during transforms for fine control. Suggested clipping ranges are 0.1–6000 m for the overview and 0.05–250 m for local detail. Global Blender preferences are not changed.

## Landform and circulation

- Western neighborhoods rise over ridges and smaller individual building pads.
- The civic square and Clock Hall sit at approximately 18 m.
- The fortified estate and gate sit at 34 m, reached by a river crossing, contour roads and broad stairs with intermediate landings.
- Lagoon water remains at 2 m; the upper river remains at 7 m; the mill drop remains 5 m.
- The lagoon terrain, water boundaries and island quays share a horizontal deformation to create less regular banks while retaining their connections.
- Building assemblies are refitted to their plots. New masonry bases, retaining edges and an apartment entry stair support the changed levels.
- Selected rocky edges and adjusted vegetation add detail to the shore and slopes.

New collections 19–22 contain the rebuilt routes, foundations, local rocks, reference figure and inspection cameras. The old route collection is hidden for comparison. All geometry remains editable. The foundation volumes and city buildings are still blockout geometry intended for further architectural refinement.

## Validation and limits

`terrain_pass_manifest.json` records route segments, dimensions, building movement and the terrain design. `terrain_pass_validation.json` checks metric scale, fixed water elevations, stair dimensions, primary-district connectivity, and samples actual saved path surfaces and standing headroom across the main lagoon-to-gate spine. The final check passed 2,259 samples with no missing floor or overhead obstruction; the largest riser is 0.167 m and the smallest tread is 0.292 m.

This is not a Godot character-controller, collision or navigation test. Individual secondary building entrances, railings, facade/basement detailing, remaining road connections beyond the city, and countryside landform refinement remain for subsequent passes. The outer farms and mountain landscape have been normalized in scale but are not comprehensively redesigned in this pass.

Generators overwrite the generated study and its previews. Save manual edits to another filename before rerunning `tools/build_hub_city_terrain_pass.py`.
