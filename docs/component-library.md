# Blender component library

Open `art/ComponentLibrary/Rook_Component_Library.blend` in Blender 5.2 or later.
It contains **44 reusable component collections** from the project, marked as
Blender assets and grouped into nine catalogs:

- Architecture: stone tiles, cobblestones, harbor walls/arch, railings, planks and supports.
- Vegetation: both grass blocks and both tuft variations.
- Props/gameplay: both barrel wrappers, coin, cargo seal, pressure plate, prototype
  arch, hinged door, rigged bronze bell, manifest desk, vault crank and chessboard.
- Buildings: the current exported storefront.
- Characters: current Rook, light player-two variant, Hound and Mouse.
- Connectors: straight, corner, T-junction, staircase and bridge.
- Rooms: harbor hall and storehouse.
- Assemblies: both existing entryway builds.
- Earlier versions: earlier Rook, Hound v1 and Mouse v1.

The file opens to **Component Overview**, with each component labeled and its
dimensions shown in metres. The overview uses collection instances; its display
offsets do not change the original asset pivots. **Asset Sources** contains the
editable master collections at their original origins. **Modeling Workspace**
is a blank building scene with a Rook size reference.

## Build with an existing component

1. Switch to the **Modeling Workspace** scene in Blender's scene selector.
2. Change an area to **Asset Browser**, choose **Current File**, and drag in an asset.
3. Keep the collection instance as a reference, or use **Object → Apply → Make
   Instances Real** for editable objects. Then use **Object → Relations → Make
   Single User → Object & Data & Materials** for an independent variation.
4. Keep the parenting and armature when converting a rigged instance.

To use a component in another Blender file, choose **File → Append**, select this
library, open **Collection**, and select a component. **File → Link** keeps a live
reference to the library. Alternatively, add `art/ComponentLibrary` under
**Preferences → File Paths → Asset Libraries**; the accompanying
`blender_assets.cats.txt` supplies the categories.

The embedded **START HERE** text block contains these instructions and the full
source inventory. `component_inventory.json` records source scene paths, mesh and
bone counts, animation names, bounds, and connector ports.

## Fidelity

Geometry, material slots, relative transforms, rigs and imported animation clips
are retained. The bell is appended from its native source to keep its original
three-bone rig and Ring/RingLoop actions, at the wrapper's 0.6 scale. The current
Rook/NPC wrappers include their in-game visual scale and offsets. Earlier
versions remain at their own scene scale.

Blender uses Z up: Godot `(x, y, z)` becomes Blender `(x, -z, y)`. Connector
markers remain named empties; their local +Y points outward. Most stone building
pieces use approximately 2 m footprints; connectors have 6 m ports.

Godot toon shaders use PBR base-color approximations in Blender. The storefront
retains the game model's original PBR materials; its runtime toon palette and
lighting are separate. Its authoring `.blend` differs from the current exported
game geometry, so the library uses the game mesh. Collision, scripts, audio,
runtime lighting and UI are not included as model components.

`Objects/Door_test.obj` is absent from the working project. The builder recovers
the exact original mesh from the existing `web/index.pck`, validates its stored
MD5 checksum, and applies the transforms/material slots from `Door01.tscn`.
It does not write to the existing door scene or invent replacement geometry.

## Refresh the snapshot

The library is self-contained; images are packed into the Blender file. It is
a snapshot rather than an automatic sync with Godot. Rebuild after changing or
adding source art (add new component entries in `tools/export_component_library.gd`):

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python tools/build_component_library.py
```

This overwrites the library, its overview image, catalogs and inventory. Save
new models and hand-edited library variants under another filename first.
The builder reads existing project assets, exports temporary GLBs through Godot,
checks geometry/bone counts and static dimensions, and writes the library.
The `.gdignore` prevents Godot from importing the reference file as game content.
