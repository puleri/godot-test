# Stylized foliage library

Open `Foliage_Component_Library.blend` in Blender. All 27 components are ordinary editable meshes, with solid faceted geometry and opaque palette materials. No textures or collection instances are required. Dimensions use metres.

## Components

- 12 trees: oak, linden, cypress, apple; three silhouette/size variants each.
- 4 shrubs: wild, purple flowering, rose, and a repeatable 2 m clipped hedge.
- 5 ground plants: short grass, meadow grass, reeds, fern, wildflowers.
- 4 climbers: vertical ivy, horizontal ivy, wisteria canopy, hanging wisteria.
- 2 containers: planted terracotta pot and 1.2 m window flower box.

## Editing and placement

Select a plant and press Tab for Edit Mode. Each plant is one mesh with disconnected, editable branches, leaves and flowers. Hover a part and press L to select its connected geometry. Materials distinguish bark, foliage and flowers. Duplicate with Shift+D for independent mesh edits, or Alt+D to share mesh data.

Objects and collections are marked as assets. Add this directory as an asset library, or append collections from the blend file. Collection offsets compensate for the gallery arrangement. Appending individual objects retains their gallery location: reset Location to place their base at the origin. Trees, shrubs and ground plants use ground/base pivots. Vine sections use their starting point as the origin; the 2 m length describes the main stem, and leaves extend beyond it. Wisteria flowers hang below the stem; position canopy pieces overhead. Hide `00 Gallery presentation` when selecting/exporting components.

The gallery is a component display; the city scene has not been modified. `component_inventory.json` records mesh counts and dimensions; `validation.json` records generation checks. The models have no collision, wind animation, runtime LODs or Godot MultiMesh placement yet. Use the local vertex height as a starting point for wind weights, with a fixed base; vines need attachment-aware weights.

Rebuild with Blender's background Python using `tools/build_foliage_library.py`. This overwrites the generated library, so save polished edits in a separate file before regenerating.
