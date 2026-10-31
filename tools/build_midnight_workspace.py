"""Blender --background --factory-startup --python tools/build_midnight_workspace.py
Creates a self-contained modeling reference, never overwriting an edited workspace.
Use -- --replace explicitly to rebuild the original snapshot.
"""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art/MidnightExchange"
DEST = OUT / "MidnightExchange_Workspace.blend"
NEW_COLLECTION = "NEW OBJECTS - export only this collection"

EXPORT_HELPER = '''# Run from Blender's Text Editor (Alt-P). Exports NEW OBJECTS only.
# This script does not export the reference level or overwrite existing GLBs.
from pathlib import Path
import bpy

def export_new_objects(output_path=None):
    collection = bpy.data.collections.get("NEW OBJECTS - export only this collection")
    if collection is None:
        raise RuntimeError("The NEW OBJECTS collection is missing.")
    objects = list(collection.all_objects)
    if not any(obj.type == "MESH" for obj in objects):
        raise RuntimeError("Add your mesh to NEW OBJECTS before exporting.")
    for obj in objects:
        if obj.parent and obj.parent not in objects:
            raise RuntimeError("Move the object's parent into NEW OBJECTS too: " + obj.name)
    project = Path(bpy.context.scene["Godot project"])
    path = Path(output_path) if output_path else project / "Mesh/Custom/MidnightAddition.glb"
    path.parent.mkdir(parents=True, exist_ok=True)
    original = path
    version = 2
    while path.exists():
        path = original.with_name(original.stem + "_v" + str(version) + original.suffix)
        version += 1
    previous = list(bpy.context.selected_objects)
    active = bpy.context.view_layer.objects.active
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    try:
        for obj in objects:
            if not obj.visible_get():
                raise RuntimeError("Unhide this new object before exporting: " + obj.name)
            obj.select_set(True)
        bpy.context.view_layer.objects.active = next(obj for obj in objects if obj.type == "MESH")
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
            use_selection=True, export_yup=True, export_animations=False,
            export_cameras=False, export_lights=False, export_apply=True)
    finally:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in previous:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = active
    bpy.context.scene["Last GLB export"] = str(path)
    print("ROOK_NEW_OBJECTS_EXPORTED", path)
    return path

if __name__ == "__main__":
    export_new_objects()
'''

HELP = '''MIDNIGHT EXCHANGE / MODELING WORKSPACE

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
'''


def collection(name, scene):
    result = bpy.data.collections.new(name)
    scene.collection.children.link(result)
    return result


def add_camera(group, name, location, target, ortho=None):
    data = bpy.data.cameras.new(name)
    if ortho:
        data.type = "ORTHO"
        data.ortho_scale = ortho
    else:
        data.lens = 28.8
    obj = bpy.data.objects.new(name, data)
    group.objects.link(obj)
    obj.location = location
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z", "Y").to_euler()
    return obj


def main():
    if DEST.exists() and "--replace" not in sys.argv:
        raise RuntimeError("Workspace already exists. Preserve edits; use -- --replace only to rebuild.")
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ".gdignore").touch()
    with tempfile.TemporaryDirectory(prefix="rook-midnight-workspace-") as temporary:
        folder = Path(temporary)
        godot = shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
        result = subprocess.run([godot,"--headless","--log-file",str(folder/"godot.log"),
            "--path",str(ROOT),"--script","tools/export_midnight_workspace.gd","--",str(folder)],
            text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if result.returncode or "MIDNIGHT_WORKSPACE_EXPORTED" not in result.stdout:
            raise RuntimeError(result.stdout[-8000:])
        manifest = json.loads((folder/"manifest.json").read_text())
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.name = "Midnight Exchange - Modeling"
        scene.unit_settings.system = "METRIC"
        scene.unit_settings.scale_length = 1.0
        scene["Godot project"] = str(ROOT)
        scene["Instructions"] = "Read START HERE; model in NEW OBJECTS, then run EXPORT NEW OBJECTS.py."
        scene.cursor.location = (0,-14,0)
        water = collection("REFERENCE - water (hidden for modeling)",scene)
        count = 0
        for record in manifest["groups"]:
            before = set(bpy.data.objects)
            bpy.ops.import_scene.gltf(filepath=str(folder/(record["name"]+".glb")))
            objects = [obj for obj in set(bpy.data.objects)-before
                       if obj.users_collection and not any(c.name.startswith("glTF_not_exported") for c in obj.users_collection)]
            target = collection("REFERENCE - "+record["name"],scene)
            target["Source"] = manifest["source"]
            target["Read only reference"] = True
            actual_meshes = sum(obj.type == "MESH" for obj in objects)
            assert actual_meshes == record["stats"]["mesh_count"], (record["name"],actual_meshes,record["stats"]["mesh_count"])
            for obj in objects:
                destination = water if "OuterHarborWater" in obj.name else target
                for previous in list(obj.users_collection):
                    previous.objects.unlink(obj)
                destination.objects.link(obj)
                obj.select_set(False)
                if obj.type == "EMPTY":
                    obj.empty_display_size = 0.12
                    obj.hide_set(True)
                if obj.type == "ARMATURE":
                    obj.hide_set(True)
                if destination == water:
                    obj.hide_set(True)
                    obj.hide_render = True
            target.hide_select = True
            record["blender_mesh_count"] = actual_meshes
            count += actual_meshes
            print("WORKSPACE_IMPORTED",record["name"],actual_meshes,flush=True)
        water.hide_select = True
        helpers = collection("REFERENCE - cameras and preview lighting",scene)
        camera = add_camera(helpers,"Modeling overview",(43,-58,49),(0,2,0),ortho=58)
        add_camera(helpers,"Establishing shot reference",(30,-48,11),(-5,65,7))
        add_camera(helpers,"Gameplay camera reference",(12,-33,23.5),(0,-14,0.5),ortho=9.4)
        scene.camera = camera
        for name,position,energy,size in [("Preview softbox",(0,-8,28),6500,35),("Preview fill",(-25,5,18),4000,25)]:
            data = bpy.data.lights.new(name,"AREA")
            data.energy, data.shape, data.size = energy,"DISK",size
            obj = bpy.data.objects.new(name,data)
            helpers.objects.link(obj)
            obj.location = position
            obj.rotation_euler = (-obj.location).to_track_quat("-Z","Y").to_euler()
        helpers.hide_select = True
        for obj in helpers.objects:
            obj.hide_set(True)
        build = collection(NEW_COLLECTION,scene)
        build["Export destination"] = "Mesh/Custom/MidnightAddition.glb (versioned automatically)"
        root = bpy.data.objects.new("MidnightAddition",None)
        root.empty_display_size = 0.5
        build.objects.link(root)
        bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection.children[build.name]
        bpy.context.view_layer.objects.active = root
        root.select_set(True)
        bpy.data.texts.new("START HERE - Midnight Exchange").write(HELP)
        bpy.data.texts.new("EXPORT NEW OBJECTS.py").write(EXPORT_HELPER)
        scene.world = bpy.data.worlds.new("Modeling studio")
        scene.world.use_nodes = True
        scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.16,0.20,0.27,1)
        scene.world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
        for screen in bpy.data.screens:
            for area in screen.areas:
                if area.type == "VIEW_3D":
                    space = area.spaces.active
                    space.shading.type = "SOLID"
                    space.shading.color_type = "MATERIAL"
                    space.shading.light = "STUDIO"
                    space.shading.show_cavity = True
                    space.clip_end = 2500
                    space.region_3d.view_distance = 49
                    space.region_3d.view_location = (0,0,0)
                    space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
                elif area.type == "OUTLINER":
                    area.spaces.active.show_restrict_column_select = True
        for material in bpy.data.materials:
            # Solid viewport display only; keep imported render materials intact.
            if material.diffuse_color[0]+material.diffuse_color[1]+material.diffuse_color[2] < 0.12:
                material.diffuse_color = (0.12,0.15,0.20,1)
        for obj in bpy.data.objects:
            if obj.type == "ARMATURE":
                obj.data.display_type = "STICK"
        bpy.ops.file.pack_all()
        scene["Reference mesh count"] = count
        scene["Source level"] = manifest["source"]
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(DEST),compress=True)
        (OUT/"workspace_inventory.json").write_text(json.dumps(manifest,indent=2)+"\n")
        (OUT/"README.txt").write_text(HELP)
        scene.render.engine = "CYCLES"
        scene.cycles.samples = 8
        scene.cycles.use_denoising = True
        scene.render.resolution_x,scene.render.resolution_y = 1400,1000
        scene.render.resolution_percentage = 100
        scene.render.image_settings.file_format = "PNG"
        scene.render.filepath = str(OUT/"workspace_preview.png")
        # Only the central level matters for this preview. The full harbor remains
        # in the saved workspace and can be hidden separately in the Outliner.
        bpy.ops.render.render(write_still=True)
        print("MIDNIGHT_WORKSPACE_SAVED",DEST,"reference meshes",count,flush=True)

if __name__ == "__main__":
    main()
