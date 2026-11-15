# Residential Streets and Apartments

32 new editable modules: 10 courtyard apartment pieces, 12 townhome pieces, 7 retail/restaurant pieces, and 3 street connection pieces. Includes six building examples and one connected shopping street. Existing asset libraries are unchanged; reused components are appended into this file, so it is self-contained.

## Open and polish

Open `Residential_Streets_and_Apartments.blend`. The scene selector contains:

- `00 New Components`: the 32 source modules, plus a separate gallery of reused modules.
- `01 Residential Overview`: presentation instances of the six buildings.
- `A Cream peaked bookshop`: twin sash windows and a large shopfront.
- `B Rose stepped tailor`: triple slender windows and separate shop/residential entrances.
- `C Sage arched cafe`: paired arches, stepped gable, striped awning and outdoor seating.
- `D Ochre oriel restaurant`: rectangular and faceted projecting windows, scroll gable, recessed entrance.
- `E Courtyard apartment complex`: three-story rear wing, lower side wings with rooftop rooms, gallery doors, stairs, laundry and planting.
- `F Corner restaurant apartments`: glazed corner storefront and upper arched windows on two elevations.
- `G Connected sloping shopping street`: four adjoining buildings, each raised 0.6 m, with pavement stair connections and shared party walls.
- Four labeled component sheet scenes.

The assembled building scenes contain real editable mesh objects. They share their mesh data with the source modules: editing one mesh updates its uses. For a unique variation, use Object → Relations → Make Single User → Object & Data first. Materials are also shared; duplicate a material to alter only one building. Bevel modifiers remain editable. Separate mesh islands within each component can be selected or separated in Edit Mode.

Add this directory to Blender Preferences → File Paths → Asset Libraries to use the catalogs. Source collections compensate for their gallery positions with instance offsets; instantiate the collection to use its authored origin.

## Dimensions and assembly

Meters, Z up, facades face -Y. Most new facade bays are 4 m wide and 3 m high. The townhomes have a 4 × 6 m footprint and three stories, including their retail ground floor. Corner facade modules include both elevations: do not place a second solid wall behind them. The wide-bay facade has a real opening intended for one of the two projecting window modules. Other new residential window walls include their glazing and frames.

The apartment galleries connect to two exterior stair flights. Doors are modeled closed and are not animated. The examples do not contain complete apartment/shop interiors or internal townhome staircases. Foundation and infill pieces are supplied for adapting the kit to a finished city terrain.

## Files and validation

`COMPONENTS.md` lists exact new/reused names and dimensions. `component_inventory.json` is the machine-readable inventory. PNGs are renders of the actual Blender geometry. `validation.json` records saved-file checks for mesh data, face areas, finite coordinates, asset pivots, bevels, assembly membership and coincident repeated module placement.

These are first-pass editable models for inspection and polish. Final UVs, texture work, LODs, collision/navigation, finished interiors and Godot integration remain. Render inspection and structural checks are not a guarantee against every possible z-fighting case.

Generator: `tools/build_residential_street_library.py`. Validator: `tools/validate_residential_street_library.py`. The generator uses the existing library builders' geometry helpers and appends reused assets from the previous three libraries. Rerunning it overwrites this generated file; save polished work under another name before regenerating.
