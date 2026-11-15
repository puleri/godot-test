# Hub City foliage level with Rook

Open `Levels/HubCityFoliage.tscn` in Godot and run the current scene (F6). This separate level does not replace the project's main scene.

- Rook starts in the civic square using the existing Player_v2 model, controller, and animation setup.
- WASD/arrows move relative to the follow camera, Space jumps, R returns to the civic square. Falling below the waterfront respawns Rook.
- The follow camera tracks elevation and pulls inward when geometry blocks its view.
- Moonlight, emissive windows/lamps and nearby dynamic street lights provide nighttime lighting.
- The foliage pilot uses 3,859 placements with per-cell LOD/culling. Road-wear vertex colors are retained.
- City meshes are grouped spatially. Static collision covers terrain, buildings and roads. Invisible continuous ramps replace stair-riser collision so the existing controller can climb stairs. Rook's feet can intersect individual visual treads slightly; foot-by-foot stair animation is not implemented.

Source: `Hub_City_Foliage_Study.blend`. The Blender source remains editable. `tools/export_hub_foliage_level.py` writes an intermediate GLB under `art/HubCityGameExport` (excluded from automatic imports). `tools/build_hub_city_runtime.gd` converts it to compressed `Assets/HubCity/HubCityGeometry.scn` with baked collision and vertex-color materials. Palette material conversion approximates Blender shader appearance; it does not bake procedural textures.

This is a playable blockout, not a complete optimized world. Distant geometry and full building collision are still substantial; streaming, further collision simplification, occlusion setup and complete route-by-route QA remain. The test checks civic-square grounding, movement, a representative stair climb, respawn, active camera and foliage loading. Foliage collision and NPCs are not included.
