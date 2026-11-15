# Upper City, Waterways and Gardens

40 new editable source components: 8 hillside/fortification connections, 16 river/waterfall pieces, 10 garden structure pieces, and 6 wisteria/formal garden pieces. Previous libraries are unchanged. Reused components and the mill assembly are appended into this Blender file, not externally linked.

## Blender

Open `Upper_City_Waterways_and_Gardens.blend`. Select `00 Editable Components` for source meshes, one of the four numbered contact-sheet scenes, or:

- `A Fortified hillside entrance`: terraced sculptable hillside, defended gate, towers, stairs, and upper villas.
- `B Winding canal waterfall and mill`: fitted curved banks, two bridge crossings, mountain river mouth, waterfall, lower pool, and the existing editable mill.
- `C Wisteria gazebo and open pavilion`: octagonal gazebo, arched pavilion open on every side, finished ceiling, pergola, hanging wisteria and cypresses.

The assemblies use real editable objects. Repeated modules share mesh data; editing a source mesh updates its uses. Make Object & Data single-user before a unique alteration. Materials are shared too. New source meshes retain editable bevel modifiers. Mesh islands within a module can be selected or separated in Edit Mode. Wisteria trunks, foliage and hanging flower clusters are separate assets and separately placed objects.

Add this folder to Blender Preferences → File Paths → Asset Libraries to browse the catalogs. Units are meters, Z up. Source collections have gallery offsets; collection instances place around their authored origins. Curved canal walls use 10 m and 4 m centerline radii with 45° and 90° turns. Pool-rim pieces use a pool-center pivot; flowers hang downward from their attachment origin.

The winding assembly uses editable meshes fitted to its centerline rather than forcing its bends into fixed-angle modules. Its hill is a separate sculptable mesh. These fitted assembly meshes are in addition to the 40 catalog modules.

## Godot water demo

Open `Levels/UpperCityWaterDemo.tscn` in Godot and run the current scene (F6). The project's main scene is unchanged. The demo imports `Assets/UpperCityKit/B_assembly.glb`; matching static exports for the hill and garden are `A_assembly.glb` and `C_assembly.glb`.

Hold right mouse and use WASD to fly, Q/E to move down/up, and Shift to move faster. The on-screen slider controls flow speed and the mill wheel. Zero flow stops wheel rotation and new particle emission.

`RiverPath` is an editable Curve3D. Editing it regenerates the water ribbon in the editor. The fitted stone banks, bridges, cave and waterfall endpoint remain authored model geometry: move/refit those when changing the route. River width changes likewise require matching banks. The shader follows UV distance along the path; the waterfall uses a vertical UV strip. The lower pool, impact foam, wheel foam, splash and mist are separate generated objects. Blender preview water is hidden by the demo to prevent duplicate surfaces.

The upper canal is at Godot Y=3.8 m and the lower pool at Y=0. The wheel rotates around its imported local axle, proportional to flow speed. This is a visual flow demonstration, not a fluid/lock simulation. The path remains at one water level above the drop, as a controlled canal would; a long descending mountain river would need additional authored reaches and drops.

Water shaders: `Materials/UpperCity/flowing_water.gdshader` and `foam.gdshader`. Runtime/editor generation and camera controls: `scripts/upper_city/water_demo.gd`. Effects use CPUParticles3D for the project's GL Compatibility renderer.

## Scope and checks

These are first-pass assets for polish and city assembly. The demo is a visual inspection scene, not a playable city level: collision/navigation, guard behavior, finished interiors, final UV/textures and LOD optimization remain. Water reflection/refraction and fluid simulation are not implemented. Some architectural parts intentionally intersect at joints; the validation does not certify all possible z-fighting cases.

`validation.json` records reopened Blender checks for mesh data, finite coordinates, nonzero face areas, source pivots, editable bevels, assembly membership and coincident repeated modules. `godot_validation.json` records runtime river generation, wheel motion and stopping behavior. PNG previews are renders of the actual models; `godot_water_demo.png` is a captured Godot frame.

Generators and checks: `tools/build_upper_city_library.py`, `tools/validate_upper_city_library.py`, `tools/validate_upper_city_water.gd`. Regeneration overwrites the generated Blender file and GLB exports. Save hand-polished versions under separate names before regenerating.
