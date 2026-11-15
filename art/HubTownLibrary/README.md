# Hub Town — editable component library

Open **HubTown_Component_Library.blend** in Blender. This is a new library of
204 modeled assets covering the hub-town component checklist. It is a first
modeling pass intended for manual refinement: simple stylized forms, shared
materials, editable polygon geometry, and non-applied bevel modifiers.

## Find and edit components

The file opens on **01 Assembly Example**. Use Blender's Scene dropdown:

- **00 Component Library** contains the original editable meshes, arranged in
  labeled rows. Every component has its own named collection.
- **01 Assembly Example** combines linked collection instances into a building,
  market, fountain, bridge, and stair/landing fit sample.
- Eight numbered **Sheet** scenes provide compact per-kit layouts. Small
  objects are enlarged for readability in these sheets; source dimensions stay
  unchanged in the main library.

To polish a component, switch to **00 Component Library**, select its mesh and
press Tab for Edit Mode. Each asset is one mesh with separately selectable loose
parts and material slots. Hover a part and press L to select its connected
geometry; use P → Selection if you want that part as a separate object. Bevels
remain adjustable in the modifier stack. Instance edits in the example are made
through the original library mesh; use Make Instances Real for an independent
editable assembly copy.

Every source collection is marked as an Asset. Add this folder under Blender
Preferences → File Paths → Asset Libraries to browse it from other projects.
The supplied `blender_assets.cats.txt` organizes the eight catalogs. Collection
instance offsets compensate for the source gallery positions so assets insert at
their local connector origins.

## Kit inventory

| Kit | Assets |
|---|---:|
| Buildings | 27 |
| Roofs and openings | 32 |
| Streets and terraces | 30 |
| Bridges and canals | 31 |
| Gatehouse and tower | 17 |
| Market and landmarks | 21 |
| Props and dressing | 34 |
| Character bases and accessories | 12 |
| **Total** | **204** |

See `COMPONENTS.md` for every asset and its dimensions, or
`component_inventory.json` for a machine-readable inventory.

## Dimensions and assembly

- Units: meters. Blender Z up; wall fronts face -Y.
- Standard wall bay: 4 m wide × 3 m high × 0.30 m thick.
- Half wall bay: 2 m. Window opening: 1.20 m × 1.35 m, sill at 1 m.
- Door opening: 1.20 m × 2.30 m. Inserts have small fitting clearances.
- Straight wall origins are centered horizontally at the story base.
- Wall posts are separate. Offset exposed posts toward the visible face;
  avoid stacking two posts at one junction.
- Corner wall assets have 0.5 m returns; terminate adjacent panels at their ends.
- Roof half-panel: 4 m along ridge, 2 m horizontal run, 1.5 m rise.
  Eave is at local Y=-2, Z=0; ridge end at Y=0, Z=1.5. Repeat along
  the slope with Y=2, Z=1.5 offsets. Rotate the opposite pitch 180° around Z.
- Full-story stairs: twelve 0.25 m risers and 0.40 m treads; 3 m total rise.
  The 0.30 m-thick landing sits at Z=2.70 so its top is at Z=3.
- Bridge arch: 4 m clear opening, 6 m total length, 3 m width.
  Deck seat at Z=3.50; 0.30 m deck top at Z=3.80. Parapets start there.
- Props use their modeled origins. Some connector pieces intentionally extend
  below Z=0 (e.g. walkway joists); the pivot represents their mating plane.

The assembly is a fit example rather than the finished town. It demonstrates
wall/window/door mating, a complete pitched roof, a supported bridge deck, and a
stair-to-landing connection. Building corners, prop contact, and intersections
should still be checked from gameplay camera distances during production polish.

## Materials and polish

Materials are ordinary editable Principled BSDF materials, with shared slots for
stone, plaster, timber, slate, metal, cloth and props. The stone wall base color
is sampled from the author's original `stone_wall` color ramp. These are simple
working materials, not a full recreation of the concept image's painted finish.
The file needs no external textures.

Characters are **unrigged modeling bases**, including six dressed figures and
separate helmet, belt, clothing and hair assets. They still need facial detail,
production topology, UVs, rigging and animation. Environment assets also need
art-directed wear/detail, final UVs or trim-sheet mapping, collision and LOD work
before game integration. Water, mist, fountain spray, and lantern illumination
are engine effects and are not modeled assets.

## Preview files

- `assembly_preview.png`: assembled fit sample.
- `01_contact_sheet.png` through `08_contact_sheet.png`: all eight kits.
- `concept_reference.png`: original hub-town concept for visual direction.

## Rebuild

The editable `.blend` is the deliverable. Save a working copy before rebuilding
because the generator overwrites its generated library and previews. Manual
polish should live in your working copy.

From the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python tools/build_hub_town_library.py
```

The existing component library and Godot levels are independent of this new file.
