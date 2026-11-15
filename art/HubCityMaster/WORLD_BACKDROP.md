# City and surrounding world

Open `Hub_City_World.blend` for the city with its surrounding landscape. The source `Hub_City_Master_Blockout.blend` is preserved, including its saved edits.

The new scene adds a roughly 2.8 × 3.2 km terrain surround, farther mountain silhouettes, a northern river valley, western boroughs and connecting roads, eastern villa grounds and woodland, and a southern estuary with marsh islands, jetties and boats. The new terrain meets the original city boundary at matching sampled heights. The sea extends well beyond the overview cameras.

Collections 11–16 contain the backdrop and its cameras. All placed building, foliage and boat components have independent editable mesh data; select a visible mesh and press Tab. Assembly parent empties organize the detailed components. The farther buildings remain simple masses suitable for judging the skyline and settlement footprint.

The saved scene opens in daylight with camera `07 City within the wider world`. Camera `08 Lagoon toward mountain valley` provides a lower view. Original city inspection cameras remain available. Preview files:

- `city_world_overview.png`
- `city_world_street.png`
- `city_world_night.png`

This is a world-layout pass. It establishes geographic continuity, not finished landscape art or playable outer districts. Terrain sculpting, richer architectural variation, dense local foliage, vineyard rows, final atmospheric effects, water animation and gameplay boundaries can be refined from here. The distant backdrop has finite geometry; flying beyond its intended viewing area will expose it.

`world_backdrop_validation.json` records realized assemblies, independent meshes, Edit Mode checks and preserved source objects. `tools/build_hub_city_backdrop.py` rebuilds this scene from the saved city master and overwrites the generated world file and previews. Save manual world edits under another filename before rebuilding.

## Rural outskirts

`Hub_City_World_Farms.blend` is the populated rural version, with six farmsteads and 714 placements from `../RuralLibrary/Rural_Component_Library.blend`. The farm collection is numbered 17. See `city_farming_outskirts.png` and `farmstead_detail.png`. The preceding world file is preserved.
