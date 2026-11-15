# Hub city component concept

`hub-city-component-concept.png` is the selected concept. It references the
actual HubTownLibrary building assembly, HubTownExpansion gate assembly, and
foliage sheet. Generated using the built-in image_gen tool; full initial prompt
and refinement summary are saved in generation-prompt.txt.

## Layout intent

North is the gate side. Use the kit's 4 m bay and 3 m story/rise standards.
The image establishes composition and connections, not measured geometry.

| Area | Target walking elevation | Required connections |
|---|---:|---|
| Central market and housing lanes | 0 m | West and east loops; both bridges; both gate-terrace stairs |
| Gate terrace | +3 m | Two market stair flights; open gate; wall-walk access |
| Canal towpaths | -3 m | Stair access on each bank beside both bridges; dock from south towpath |
| South workshop plaza | 0 m | Both bridge mouths; both workshop doors; stairs to south towpath |
| Wall walk and tower lookout | Follow tower modules | Visible terrace stair and tower doorway; internal stair/landing needed in blockout |

The two bridges cross ONE canal and connect banks at matching elevations.
Each bridge deck must be continuous with its approach landings. Keep stairs
beside bridge mouths, clear of the bridge deck and parapets.

## Routes to preserve when building

1. Market → west housing street → stone bridge → south workshop plaza →
   timber bridge → east housing street → market. This is the main circuit.
2. Market → west terrace stairs → gate terrace → east terrace stairs → market.
3. Each housing block has a front street and return lane; join both ends to
   the market/perimeter network. Connect every door threshold to a paved route.
4. North towpath has stair access on both sides of bridge abutments. If the
   bridge support interrupts a towpath, connect that segment with a stair rather
   than requiring a water crossing. Apply the same rule to the south towpath.
5. South dock connects directly to the south towpath with a clear entrance.
6. Gate terrace → battlement stairs → wall walk → tower door → lookout.
   Model the interior stair/landings explicitly; the illustration cannot show
   the tower's hidden interior route.

## Blockout constraints

- Main streets: at least 4 m clear. Lanes/towpaths: at least 2 m clear.
- A 3 m rise uses twelve 0.25 m risers and 0.40 m treads (4.8 m run), plus
  clear landings. Use these dimensions rather than counting painted steps.
- Keep stalls, trees, planters, crates, and door swings outside clear routes.
- Fountain and stalls leave a continuous circulation ring around the square.
- Building interiors and roof routes are not specified by this exterior plate.
  Add explicit floor, stair, and doorway connections for any playable interiors.
- Validate all routes with the actual player collider, step handling, headroom,
  and navigation in Godot before detailing. Image generation does not certify
  collision-free traversability or exact module fits.

## Component sources

- `../HubTownLibrary/HubTown_Component_Library.blend`: houses, roofs, inserts,
  fountain, stalls, bridges, props.
- `../HubTownExpansion/HubTown_Environment_Expansion.blend`: gate/tower,
  retaining masonry, terrain, foliage, paving and connection details.

Use this plate for arrangement and mood; use the Blender sources for actual
geometry, dimensions, pivots and materials.
