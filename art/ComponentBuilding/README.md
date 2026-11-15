# Component building fit study

The Godot assembly now uses the current `ComponentLibrary/foundation.blend`
source, exported to `Mesh/ComponentBuilding/`. Twelve separate components keep
the library's 4× scale and the existing placements. No windows, trim, or other
geometry were added. The authoring source is unchanged by this export.

Blender's Toon BSDF and procedural wood graphs do not export directly to glTF.
The export bakes their authored base colors and grain into 1024×1024 textures
per component, then adapts Toon BSDF to matte PBR materials. Principled
metallic/roughness values are retained. Lighting will differ from Blender's
Toon rendering. The former inspection palette overrides are no longer used.
The windowed ground-floor wall's broad panel uses the original `stone_wall`
material shared by its neighbors; its individual stone details retain `Stone`.
This assignment is corrected on the export copy, not the authoring file.
Only export copies receive new UVs; vertex/polygon counts are checked before
export. `godot_export.json` records the source hash and conversion details.

Open `ComponentBuilding_GodotReference.blend` for the matching assembly with
packed export textures. `ComponentBuilding.blend` is the earlier editable
library-snapshot assembly with its original material graphs and solid shading.

For Godot, open `Levels/ComponentBuildingInspection.tscn` and press F6:

- Left drag: orbit. Right drag: pan. Wheel: zoom.
- 1: both floors. 2: ground floor. 3: upper floor.
- X: separate/reassemble stories. F: reset camera.

The reusable module is `Modules/Buildings/ComponentBuilding.tscn`.
Ground floor: four Plain stone corner wall components, Door stone wall at the
front, Windowed stone wall at the back. Upper floor: four Second story corner
components, Second story window at the front, Second story plain at the back.
The open top exposes the interior joins.

This remains a fit study. Native trim and proportion differences remain
visible. Inspect the paired end posts, side center joins, and seam between
stories; the material refresh does not establish that joints are free of
z-fighting.

`assembly.json` records the placements. From the project root, rebuild with:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python tools/export_component_building.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/build_component_building.gd
godot --path . --resolution 1440x900 --script tools/preview_component_building.gd
```

`preview.png`, `ground-floor.png`, and `join-closeup.png` show the refreshed
Godot export. `preview-before-refresh.png` preserves the previous appearance.
The city scenes continue to use their existing exports.
