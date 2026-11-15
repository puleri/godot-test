# City Boroughs and Landmarks

141 modular components and nine editable assemblies, built for Blender polish. This library extends the HubTownLibrary and HubTownExpansion without modifying them. No characters were added.

## Open and edit

Open `City_Boroughs_and_Landmarks.blend`. The initial scene is `01 Borough Architecture Overview`. Use the scene selector to open a complete assembly (A–I) or `00 Editable Components` for the source modules. Each component is an asset-marked collection. Add this folder to Blender Preferences → File Paths → Asset Libraries to browse its catalogs.

Assembly objects are real editable meshes with shared mesh data. Editing a mesh updates its other uses; use Object → Relations → Make Single User → Object & Data before making a unique variation. Materials are shared too: duplicate a material before changing only one building. Bevel modifiers remain editable. Mesh islands within each component can be selected or separated in Edit Mode.

## Contents

- Four architecture families: canal warehouse, narrow merchant shophouse, courtyard tenement, hillside villa.
- Three landmarks: Clock Hall, octagonal copper-domed Canal Bathhouse, Great Waterwheel Mill.
- Waterfront: lock chamber and hinged gates, winding equipment, spillway, channel transition, cargo boat, rowboat, gangplank, mooring rope, bundles, dock crane and bollard.
- Borough identity: signs, banner, warehouse plaque, lamp, windmill and distant neighborhood cluster.
- Nine assemblies: four buildings, three landmarks, lock/crane example, windmill example.
- Nine labeled component sheets and nine assembly renders, plus `architecture_overview.png`.

See `COMPONENTS.md` for the full named inventory and measured dimensions.

## Placement and moving parts

Blender units are meters, Z up. Most wall bays use 4 m width and 3 m story height. Merchant facades use 3 m width; warehouse loading bays are 4 m tall. Dimensions vary intentionally; consult the inventory rather than scaling an entire building to a universal grid. Source collection offsets compensate for their gallery positions, so Asset Browser instances place around their authored origin.

Clock hands pivot at their centers around local Y. The mill's `ROTATE THIS — waterwheel axle X` empty owns all rotor parts; rotate its local Y axis (world X in the assembled mill). Lock gates pivot at their hinges around Z. Windmill sails pivot around local Y. These are editable pivots, not authored animations or gameplay mechanisms.

## Scope and validation

These are first-pass modeled assets with simple material slots, ready for inspection and hand polish. They are not a completed city level. Interior furnishing, stair access within every enclosed building, final UVs/textures, optimized LODs, collision/navigation and Godot export integration remain production work. Some architectural parts intentionally intersect at joints; mesh checks do not certify all assemblies free of rendering artifacts.

The saved file is reopened by `tools/validate_city_borough_library.py` to check asset collections, editable meshes and bevels, valid face areas and coordinates, source pivots, assembly membership, duplicate coincident component placements and the wheel hierarchy. Results are in `validation.json`. Preview PNGs show the actual Blender geometry, not generated concept art.

The source generator is `tools/build_city_borough_library.py` and reuses helpers from `tools/build_hub_town_library.py`. Rerunning it replaces this generated library. Save your polished version under another filename before regenerating.
