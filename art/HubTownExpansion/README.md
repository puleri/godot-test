# Hub Town — environment expansion

Open **HubTown_Environment_Expansion.blend**. This companion library adds 109
editable environment assets to the first hub-town library. It contains no new
characters. The original library is independent, so manual edits there are kept.

## Editing and reuse

The file opens on **01 Gate Terrace Example**, an assembly of linked collection
instances. Switch the Scene dropdown to **00 Environment Assets** to edit the
source meshes. Every model has a named collection marked as a Blender Asset,
material slots, and an adjustable bevel modifier. Select the source mesh and
press Tab to edit it. Connected loose parts remain individually selectable with
L; use P → Selection to split them into separate objects if needed.

The eight **Sheet** scenes show the kits in labeled layouts. Display instances
are scaled for readability in these sheets; source assets retain their real
meter dimensions. Add this folder to Blender's Asset Libraries preferences to
use the provided catalogs. Assets insert with collection offsets compensating
for their position in the source gallery.

## Included kits

| Kit | Assets |
|---|---:|
| Trees and plants | 21 |
| Gatehouse and fortifications | 18 |
| Watchtower | 10 |
| Terrain and retaining walls | 15 |
| Bridges and water edge | 10 |
| Building and roof variants | 16 |
| Streets and ground dressing | 10 |
| Market detail | 9 |
| **Total** | **109** |

`COMPONENTS.md` lists every model and its bounds. `component_inventory.json`
provides the same information for scripts.

## Connections

- Blender Z up, meters, wall facade -Y. General wall bays are 4 m wide, with
  3 m stories. Stone courses terminate at each bay boundary.
- Gate surround: 8 m outside width, 4 m clear opening, 2 m passage depth;
  arch spring at 3 m, clear crown at 5 m, exterior cap at 6.2 m.
- Gate leaves use hinge-axis origins and an arched upper profile. The left leaf
  extends toward +X from its hinge, the right toward -X. Rotate about Z to open.
- The separate vaulted ceiling starts at the spring plane. It is an alternative
  passage treatment; avoid layering it over the full surround's existing vault.
- Tower base: 4 m square hollow perimeter, 3 m tall. Stack it vertically, then
  add the transition ring, lookout frame, and complete hip roof.
- Terrace blocks are 3 m high. Full stair flight has twelve 0.25 m risers,
  0.40 m treads. Landings have a 0.30 m slab, so their base is at 2.70 m.
- Bridge spandrel facade follows a 4 m clear arch with a 0.5 m arch ring and
  spring height 1 m. Place it on the outside face of the structural bridge,
  with a small physical separation where surfaces would otherwise coincide.
- Ivy and vines face -Y; position them slightly in front of the receiving wall.
- Plant leaves are actual editable geometry. Most are thin surfaces, intended
  for a two-sided material when exported to a game engine.

The example demonstrates the gate, tower, retaining wall, staircase, foliage,
and market dressing. It is a modeling/assembly reference, not a playable level.

## Materials and production work

Shared materials use editable Principled BSDF nodes. There are no required
external textures. Trees include branching trunks, inner canopy masses, and
individual shaped leaves; vines, grass, flowers, and roots are mesh geometry.

These are first-pass stylized models for further polish. Final UV layouts,
texture/detail work, foliage wind, collisions, LODs, and gameplay navigation still
belong to the game-integration pass. Water, mist, smoke, fountain spray, and
animated lighting are effects rather than additional modeled components. The
example includes simple moonlight and warm gate lights for preview only.

## Files

- `gate_terrace_preview.png`: assembled example.
- `09_contact_sheet.png` through `16_contact_sheet.png`: the eight asset kits.
- `validation.json`: saved-file mesh verification.

## Rebuild

Save manual polish in a separate working file. Rebuilding replaces this generated
expansion and its previews. From the project root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python tools/build_hub_town_expansion.py
```

The expansion generator reuses geometry helpers from
`tools/build_hub_town_library.py` but does not run or overwrite the first library.
