"""Build the editable workspace from the saved Godot layout exports."""
import json
from math import pi
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
args = sys.argv[sys.argv.index("--") + 1:]
export_dir = Path(args[0])
destination = Path(args[1]) if len(args) > 1 else ROOT / "art/TheLastBarrel/TheLastBarrel.blend"
layout = json.loads((export_dir / "layout.json").read_text())
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "The Last Barrel"
scene.unit_settings.system = "METRIC"

collection_names = {
    "Quay": "01 · Quay, crank and sorting",
    "Office": "02 · Shipmaster’s office",
    "Merchant": "03 · Outbound merchant",
    "Lighter": "04 · Potato lighter",
    "Cargo": "05 · Moveable cargo",
    "Cast": "06 · Cast and scale",
    "Backdrop": "07 · Harbor backdrop",
}


def group(name, parent=scene.collection):
    collection = bpy.data.collections.new(name)
    parent.children.link(collection)
    return collection


def move_to(obj, collection):
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)


def arrange_props(imported, parent_collection, items):
    section_names = {
        "Hull": "Hull and rigging",
        "FreightDeck": "Freight deck",
        "LowerHold": "Lower hold",
        "SternPassages": "Stern passages",
        "PurserCabin": "Purser’s cabin",
    }
    anchors = {obj.name: obj for obj in imported}
    stowed = []
    inks = {}
    for record in items:
        anchor = anchors[record["id"]]
        anchor.name = record["name"]
        if record.get("section"):
            section = group(section_names[record["name"]], parent_collection)
            for obj in [anchor, *anchor.children_recursive]:
                move_to(obj, section)
        if record.get("stowed"):
            stowed.append(anchor)
        if "lantern_energy" in record:
            # The project uses Godot's nonphysical light units. Match irradiance
            # at one metre using the radiant flux of an isotropic point source.
            anchor.data.energy = 4 * pi * record["lantern_energy"]
            anchor.data.shadow_soft_size = 0.09
        if "label" in record:
            label = record["label"]
            curve = bpy.data.curves.new(label["text"], type="FONT")
            curve.body = label["text"]
            curve.size = label["size"]
            curve.align_x = ["LEFT", "CENTER", "RIGHT", "JUSTIFY"][label["horizontal"]]
            curve.align_y = ["TOP", "CENTER", "BOTTOM", "CENTER"][label["vertical"]]
            color = tuple(label["color"])
            if color not in inks:
                material = bpy.data.materials.new("Ship lettering")
                material.diffuse_color = color
                inks[color] = material
            curve.materials.append(inks[color])
            lettering = bpy.data.objects.new(label["text"], curve)
            anchor.users_collection[0].objects.link(lettering)
            lettering.parent = anchor
            lettering.rotation_euler.x = pi / 2
            anchor.empty_display_size = 0.1
    for anchor in stowed:
        state = group(f"Alternate · {anchor.name}", anchor.users_collection[0])
        for obj in [anchor, *anchor.children_recursive]:
            move_to(obj, state)
        state.hide_viewport = True
        state.hide_render = True


for entry in layout["groups"]:
    name = entry["name"]
    collection = group(collection_names[name])
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(export_dir / f"{name}.glb"), import_pack_images=True)
    imported = set(bpy.data.objects) - before
    assert any(obj.type == "MESH" for obj in imported), name
    for obj in imported:
        move_to(obj, collection)
    items = entry.get("items", layout.get("ship_items", []) if name == "Merchant" else [])
    if items:
        arrange_props(imported, collection, items)
    if name == "Merchant":
        bpy.context.view_layer.update()
        corners = [obj.matrix_world @ Vector(corner) for obj in imported if obj.type == "MESH"
                   for corner in obj.bound_box]
        low = Vector([min(v[i] for v in corners) for i in range(3)])
        high = Vector([max(v[i] for v in corners) for i in range(3)])
        ship_center = (low + high) / 2
        ship_span = (high - low).length
    if name == "Backdrop":
        collection.hide_viewport = True

markers = group("08 · Gameplay markers")
marker_groups = {}
for record in layout["markers"]:
    name = record["group"]
    if name not in marker_groups:
        marker_groups[name] = group(name, markers)
    obj = bpy.data.objects.new(record["name"], None)
    obj.location = record["position"]
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.32
    marker_groups[name].objects.link(obj)

output = group("NEW OBJECTS")
helper = bpy.data.texts.new("EXPORT NEW OBJECTS.py")
helper.write('''"""Export only the objects in NEW OBJECTS, at the original world origin."""
from pathlib import Path
import bpy

collection = bpy.data.collections["NEW OBJECTS"]
objects = [obj for obj in collection.all_objects if obj.type in {"MESH", "EMPTY", "ARMATURE"}]
if not any(obj.type == "MESH" for obj in objects):
    raise RuntimeError("Add a mesh to NEW OBJECTS first.")
if any(obj.parent is not None and obj.parent not in objects for obj in objects):
    raise RuntimeError("Put the parents of the exported objects in NEW OBJECTS too.")
if any(not obj.visible_get() for obj in objects):
    raise RuntimeError("Unhide the objects before exporting.")
root = Path(bpy.data.filepath).resolve().parents[2]
directory = root / "Mesh" / "TheLastBarrel"
directory.mkdir(parents=True, exist_ok=True)
path = directory / "LayoutAddition.glb"
version = 2
while path.exists():
    path = directory / f"LayoutAddition_v{version}.glb"
    version += 1
previous = list(bpy.context.selected_objects)
active = bpy.context.view_layer.objects.active
bpy.ops.object.select_all(action="DESELECT")
try:
    for obj in objects:
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
print("Exported", path)
''')
readme = bpy.data.texts.new("START HERE")
readme.write("""THE LAST BARREL

The viewport opens on Rook's arrival beside the barrel. The Quay opening and
Merchant cutaway cameras frame the two halves of the level. The collections
reproduce the saved Godot layout in metres. Use the Outliner to hide the quay, office, two ships, cast, and
markers independently. Expand the outbound merchant to work on an individual
deck. Collections marked “Alternate” hold the prop states revealed during the
search. Toggle the eye/monitor and camera icons to preview them. The harbor
backdrop starts hidden.

NEW OBJECTS is the export collection. Add your mesh and necessary parent
objects there. Run EXPORT NEW OBJECTS.py in the Text Editor to make a GLB.
Instance that GLB at the Godot level origin with zero rotation and unit scale.
Godot (x, y, z) is Blender (x, -z, y). Add collision and gameplay in Godot.

Shipmaster.blend contains the separate rigged crow variant and uniform.
""")
scene["Source level"] = "Levels/TheLastBarrel.tscn"
scene["Godot axes"] = "Blender (x, -z, y) from Godot (x, y, z)"
scene.cursor.location = (0, -15, 0)

preview = group("Workspace cameras and moon")
lighting = layout["lighting"]
world = bpy.data.worlds.new("Harbor night")
world.use_nodes = True
scene.world = world
nodes = world.node_tree.nodes
links = world.node_tree.links
ambient = nodes.get("Background")
ambient.inputs["Color"].default_value = (*lighting["ambient"], 1)
ambient.inputs["Strength"].default_value = lighting["ambient_energy"]
sky = nodes.new("ShaderNodeBackground")
sky.inputs["Color"].default_value = (*lighting["sky"], 1)
mix = nodes.new("ShaderNodeMixShader")
links.new(nodes.new("ShaderNodeLightPath").outputs["Is Camera Ray"], mix.inputs[0])
links.new(ambient.outputs[0], mix.inputs[1])
links.new(sky.outputs[0], mix.inputs[2])
links.new(mix.outputs[0], nodes.get("World Output").inputs["Surface"])
moon_data = bpy.data.lights.new("Harbor moonlight", type="SUN")
moon_data.energy = lighting["energy"]
moon_data.color = lighting["moon"]
moon = bpy.data.objects.new("Harbor moonlight", moon_data)
preview.objects.link(moon)
moon.rotation_euler = Vector(lighting["direction"]).to_track_quat("-Z", "Y").to_euler()
moon.location = (0, 0, 18)

camera_data = bpy.data.cameras.new("Blockout overview")
camera = bpy.data.objects.new("Blockout overview", camera_data)
preview.objects.link(camera)
camera.location = (31, -28, 47)
camera.rotation_euler = (Vector((0, 3, 0)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera_data.type = "ORTHO"
camera_data.ortho_scale = 57
quay_focus = Vector((-1.0, -1.4, 0.7))
quay_camera = bpy.data.objects.new("Quay opening", bpy.data.cameras.new("Quay opening"))
preview.objects.link(quay_camera)
quay_camera.location = (3.4, -29.4, 21.5)
quay_view = (quay_focus - quay_camera.location).to_track_quat("-Z", "Y")
quay_camera.rotation_euler = quay_view.to_euler()
quay_camera.data.type = "ORTHO"
quay_camera.data.ortho_scale = 32.0
ship_view = Vector((-0.17, 1.0, -0.82)).to_track_quat("-Z", "Y")
ship_camera = bpy.data.objects.new("Merchant cutaway", bpy.data.cameras.new("Merchant cutaway"))
preview.objects.link(ship_camera)
ship_camera.rotation_euler = ship_view.to_euler()
ship_camera.location = ship_center + ship_view @ Vector((0, 0, ship_span))
ship_camera.data.type = "ORTHO"
ship_camera.data.ortho_scale = ship_span * 1.03
scene.camera = ship_camera

bpy.ops.object.select_all(action="DESELECT")
for layer in bpy.context.view_layer.layer_collection.children:
    if layer.collection == output:
        bpy.context.view_layer.active_layer_collection = layer
for workspace in bpy.data.workspaces:
    for screen in workspace.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.shading.color_type = "MATERIAL"
                space.region_3d.view_distance = 33.0
                space.region_3d.view_location = quay_focus
                space.region_3d.view_rotation = quay_view

bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(destination))
print("LAST_BARREL_WORKSPACE_OK", len(layout["markers"]), "markers")
