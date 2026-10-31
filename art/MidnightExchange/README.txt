MIDNIGHT EXCHANGE / MODELING WORKSPACE

This is a reference snapshot of the saved Godot level and every current harbor
backdrop instance. Metres, original world origin, current asset placements.

START MODELING
The NEW OBJECTS collection is active. Add your mesh with Shift-A > Mesh, then
model against the reference. The cursor starts on the ground at the arrival
court. M moves an existing object into NEW OBJECTS. Reference collections are
locked against selection; unlock their selection restriction in the Outliner
if you want to inspect or duplicate them. Duplicates must move to NEW OBJECTS.

HIDE REFERENCES
Use the Outliner eye toggles for the backdrop, characters, or reference level.
The large water planes are in a separate collection, hidden in the viewport.
The file opens in solid material-color view for easy modeling, not game lighting.
Scene cameras approximate the establishing and gameplay views for composition.

EXPORT YOUR ADDITION INTO GODOT
1. Put ONLY your new model and any required parents in NEW OBJECTS.
2. Save your .blend. This folder is ignored by Godot to avoid importing the level.
3. Open a Text Editor area, choose EXPORT NEW OBJECTS.py, and click Run Script
   (Alt-P). No auto-run/trusted-script setting is required.
4. The helper exports Mesh/Custom/MidnightAddition.glb inside the project.
   Existing exports are preserved with _v2, _v3, etc. The path prints in the
   console and is recorded as the scene's Last GLB export custom property.
5. In Godot, wait for import and drag that GLB into Levels/MidnightExchange.tscn.
   Set the instance's position and rotation to zero and scale to one: your mesh
   keeps the position where you modeled it relative to this level.
6. Add collision in Godot if the object should block movement or sight. Apply
   the game's toon material in a wrapper/inherited scene if needed. Save the level.

MANUAL EXPORT ALTERNATIVE
Select only your new objects, File > Export > glTF 2.0, format GLB, Include >
Selected Objects, +Y Up, no animation/camera/light export. Use Mesh/Custom/.
Do not export the entire scene. Keep the saved Blender file in this ignored folder.

COORDINATES AND ORIGINS
Godot (x,y,z) becomes Blender (x,-z,y); glTF's +Y Up converts back automatically.
One Blender unit = one metre. Ground is Z=0; the reference arrives at Y=-14.
The helper preserves world placement for a level addition instanced at (0,0,0).
For a reusable prop with a local pivot, export it from a separate local-origin
scene instead, then position that prop normally in Godot.

LIMITS
Godot shaders are PBR base-color approximations. Animated clouds, storm lighting,
UI, collision, navigation, audio, scripts and gameplay are not reproduced here.
Characters/rigs are scale references; animations are omitted. Blender changes to
reference geometry do not automatically change the saved Godot level. The export
helper transfers your new additions only. There is no automatic live sync.

Read docs/midnight-blender-workspace.md in the project for the same workflow.
