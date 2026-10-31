# Midnight Exchange Blender workspace

Open `art/MidnightExchange/MidnightExchange_Workspace.blend` in Blender 5.2 or
later. It contains the current saved Midnight Exchange level, character scale
references and all four saved harbor backdrop instances: **2,173 reference meshes**.
The reference collections are locked against selection. The empty **NEW OBJECTS -
export only this collection** collection is active and ready for modeling.
The file is self-contained and its folder has `.gdignore`, so Godot does not
import the reference level as a new game asset.

## Model and export your addition

1. Add meshes to **NEW OBJECTS**. The 3D cursor starts on the ground in the
   arrival court. Model in place against the existing geometry. Use **M** to
   move an object into this collection. Keep required parents in it too.
2. Save the Blender file. Open a **Text Editor** area, select the embedded
   **EXPORT NEW OBJECTS.py**, and click **Run Script** or press **Alt-P** while
   the pointer is over the Text Editor.
3. The helper exports only this collection to
   `Mesh/Custom/MidnightAddition.glb` in the Godot project. Existing exports are
   preserved with `_v2`, `_v3`, etc. Check the scene custom property **Last GLB
   export** for the resulting path. An empty collection refuses export.
4. In Godot, wait for the GLB to import, then drag it into
   `Levels/MidnightExchange.tscn`. Reset the new instance's position and rotation
   to zero and its scale to one. It will align with where you modeled it.
5. Add collision if it should block movement or sight. Apply Rook's toon
   material in a wrapper or inherited scene if needed. Save the level.

You can also export manually: select only your new objects, **File → Export →
glTF 2.0**, choose **GLB**, enable **Selected Objects** and **+Y Up**, and disable
animation, camera and light export. Save into `Mesh/Custom/`.

One Blender unit is one metre. Godot `(x,y,z)` becomes Blender `(x,-z,y)`;
the glTF exporter converts back. The export preserves world placement to support
an addition placed at the level origin. For a reusable prop with a local pivot,
export from a separate scene at its local origin and place it normally in Godot.

## Working with references

Toggle the Outliner eyes to hide the level, harbor or characters individually.
Large water planes are separated and hidden for modeling. Unlock the selection
restriction in the Outliner to inspect or duplicate a reference; move duplicates
into **NEW OBJECTS** to include them in exports. The component library remains
available through **File → Append → art/ComponentLibrary/Rook_Component_Library.blend
→ Collection**.

The scene includes modeling, establishing-shot and gameplay reference cameras.
Solid material-color view is intended for modeling. Shader materials have PBR
base-color approximations; clouds, storm lighting, collision, navigation, UI,
audio, gameplay and live synchronization are not part of the Blender file.
Editing the reference collections does not modify the saved Godot level; the
helper exports additions only.

The embedded **START HERE - Midnight Exchange** text and adjacent `README.txt`
contain the same workflow. `workspace_preview.png` shows the central level in
neutral modeling light.

## Rebuild and verification

`tools/export_midnight_workspace.gd` reads the scene without running gameplay,
materializes each procedural backdrop and expands its MultiMeshes for Blender.
It reuses the component-library exporter for visual cleanup and toon-material
conversion. `tools/build_midnight_workspace.py` imports the references, verifies
mesh counts, adds the modeling collection, cameras and embedded export helper,
packs resources and saves the file.

The builder refuses to overwrite an existing workspace. If you deliberately
want a fresh snapshot, first preserve your edits and run:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python tools/build_midnight_workspace.py -- --replace
```

Verification: reopened the saved file in Blender, checked collection locks and
mesh counts, verified that an empty modeling collection refuses export, and
exported a temporary two-metre cube through the embedded helper. Godot imported
exactly one mesh with the expected world bounds `(2,0,11)` to `(4,2,13)`. The
probe was not saved into the user's Blender file or project assets.
