# Developed city pass

Open **Hub_City_Developed.blend** for the updated editable map. The earlier **Hub_City_Foliage_Study.blend** is preserved.

New collections:

- **24 COMPLETION — detailed buildings:** detailed replacements and rural assemblies.
- **25 COMPLETION — bridges quays and shore:** arch supports, retaining faces, masonry edges and faceted shore rocks.
- **26 COMPLETION — cultivated fields:** crop strips fitted to the countryside heightfield, boundaries, ditches and crossings.
- **27 COMPLETION — boats and dock:** six moored boats, fishing equipment, access landing and lagoon sailboat.
- **99 COMPLETION — original blockouts (hidden):** replaced buildings and superseded bridge piers, retained for reference.

New placements have independent mesh data and can be edited directly with Tab. Building variants preserve existing window modules/materials. Large apartments are limited to parcels that fit them; storefronts and compact workshops fill smaller lots. The scene remains in metres.

The companion library is `art/CityCompletionLibrary/City_Completion_Library.blend`. The full placement inventory is `city_completion_manifest.json`.

The corner restaurant apartments, canal bathhouse, and wisteria gazebo and open pavilion use the edited collections from `art/WorldHubComponents/World_Hub_Components.blend`. To reapply these three collections in place, run `tools/refresh_hub_landmarks.py` in Blender, then follow the export and Godot steps below. A full rebuild from the blockout also needs the refresh after step 3.

Run `tools/replace_hub_sage_cafes.py` after that refresh to swap the two Sage Arched Café landmarks and the Merchant Variant 03 placements for the edited corner restaurant. Each replacement retains the old lot's footprint limits, base elevation, and orientation.

## Godot

The updated playable scene remains **Levels/HubCityFoliage.tscn**, with Rook, existing foliage streaming, road-wear colors, lighting and smooth stair collision. The exported city uses spatial geometry chunks. The lagoon sailboat has a separate animated chunk and follows a small open-water circuit.

From the project root:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://Levels/HubCityFoliage.tscn
```

WASD/arrows move, Space jumps, R returns to the civic square. Open this scene and press F6 to run it in the editor.

## Rebuild

1. Run `tools/build_city_completion_library.py` in Blender.
2. Run `tools/validate_city_completion.py` in Blender.
3. Run `tools/populate_city_completion.py` in Blender.
4. Run `tools/export_hub_foliage_level.py` in Blender.
5. Run Godot with `--headless --path . --script res://tools/build_hub_city_runtime.gd`.
6. Run Godot with `--headless --path . --script res://tools/validate_hub_city_level.gd`.

The map is a detailed development pass. It retains the established street network and broader terrain layout; additional hand-authored streetscape composition, interiors and game-specific traversal tuning remain polish work.
