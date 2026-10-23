"""Run in Blender: --background --factory-startup --python tools/build_component_library.py

Builds a standalone, editable reference library from the current Godot scenes.
Original project assets are only read. The native bell source retains its rig;
other components are resolved through Godot's glTF export.
"""
from pathlib import Path
import hashlib
import json
import math
import re
import shutil
import struct
import subprocess
import tempfile
import uuid

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "art" / "ComponentLibrary"
BLEND = OUT / "Rook_Component_Library.blend"
OUT.mkdir(parents=True, exist_ok=True)
(OUT / ".gdignore").touch()


def prepare_sources(folder):
    """Recover an absent source from the project's existing PCK, with checksum."""
    pack = (ROOT / "web/index.pck").read_bytes()
    assert pack[:4] == b"GDPC" and struct.unpack_from("<I", pack, 4)[0] == 3
    base, table = struct.unpack_from("<QQ", pack, 24)
    count = struct.unpack_from("<I", pack, table)[0]
    cursor = table + 4
    found = False
    for _ in range(count):
        length = struct.unpack_from("<I", pack, cursor)[0]
        cursor += 4
        name = pack[cursor:cursor + length].rstrip(b"\0").decode()
        cursor += length
        offset, size = struct.unpack_from("<QQ", pack, cursor)
        checksum = pack[cursor + 16:cursor + 32]
        cursor += 36
        if "Door_test.obj-" in name and name.endswith(".mesh"):
            data = pack[base + offset:base + offset + size]
            assert hashlib.md5(data).digest() == checksum, "Door checksum mismatch"
            (folder / "recovered_door.mesh").write_bytes(data)
            found = True
    assert found, "Original door mesh not found in web release"
    # Extract the actual chessboard subtree, not the broken scene's door dependency.
    parts = re.split(r"(?=^\[)", (ROOT / "scenes/Main_v2.tscn").read_text(), flags=re.M)
    output = ["[gd_scene format=3]\n\n"]
    for part in parts:
        header = part.split("\n")[0]
        if header.startswith('[ext_resource type="Material"') or header.startswith("[sub_resource"):
            output.append(part)
        elif header.startswith('[node name="Board" ') and 'parent="ChessboardTrigger"' in header:
            output.append(re.sub(r"\[node[^\n]*\]", '[node name="Board" type="Node3D"]', part, count=1))
        elif header.startswith("[node") and 'parent="ChessboardTrigger/Board"' in header:
            output.append(part.replace('parent="ChessboardTrigger/Board"', 'parent="."', 1))
    (folder / "chessboard.tscn").write_text("".join(output))


def export_godot(folder):
    prepare_sources(folder)
    godot = shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
    process = subprocess.run([
        godot, "--headless", "--log-file", str(folder / "godot.log"),
        "--path", str(ROOT), "--script", "tools/export_component_library.gd", "--", str(folder),
    ], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (folder / "export.log").write_text(process.stdout)
    if process.returncode or "COMPONENT_EXPORT_OK 44 components" not in process.stdout:
        raise RuntimeError(process.stdout[-6000:])
    return json.loads((folder / "manifest.json").read_text())


def activate(scene):
    bpy.context.window.scene = scene


def new_collection(name, scene):
    collection = bpy.data.collections.new(name)
    scene.collection.children.link(collection)
    return collection


def native_objects(record, collection):
    with bpy.data.libraries.load(str(ROOT / record["native_source"]), link=False) as (source, target):
        target.objects = source.objects
        target.actions = source.actions
    objects = [obj for obj in target.objects if obj]
    root = next(obj for obj in objects if obj.name == record["native_root"])

    def belongs(obj):
        return obj == root or (obj.parent is not None and belongs(obj.parent))

    kept = [obj for obj in objects if belongs(obj) and obj.type != "LIGHT"]
    for obj in objects:
        if obj not in kept:
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in kept:
        collection.objects.link(obj)
    root.scale *= record["native_scale"]
    for action in target.actions:
        if action:
            action.use_fake_user = True
            action.name = record["slug"] + "::" + action.name
    return kept


def import_component(record, folder, masters):
    collection = new_collection(record["name"], masters)
    if "native_source" in record:
        objects = native_objects(record, collection)
    else:
        before = set(bpy.data.objects)
        before_actions = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=str(folder / (record["slug"] + ".glb")))
        # The importer may also create an unlinked custom bone-display mesh.
        # It belongs to armature UI data, not the asset's visible geometry.
        objects = [obj for obj in set(bpy.data.objects) - before
                   if obj.users_collection and not any(c.name.startswith("glTF_not_exported") for c in obj.users_collection)]
        for obj in objects:
            for parent_collection in list(obj.users_collection):
                parent_collection.objects.unlink(obj)
            collection.objects.link(obj)
        for obj in objects:
            animation = obj.animation_data
            if animation:
                for track in animation.nla_tracks:
                    track.mute = True
                    for strip in track.strips:
                        if strip.action and strip.action.name.split("|")[-1].split(".")[0] == "Idle":
                            animation.action = strip.action
                            animation.action_slot = strip.action_slot
        for action in set(bpy.data.actions) - before_actions:
            action.name = record["slug"] + "::" + action.name
            action.use_fake_user = True
    for obj in objects:
        obj.name = record["slug"] + "::" + obj.name
        if obj.type == "ARMATURE":
            obj.show_in_front = False
            obj.data.display_type = "STICK"
        if obj.type == "EMPTY":
            obj.empty_display_size = 0.16
    collection["Godot source"] = record["source"]
    collection["Notes"] = record["notes"]
    collection["Units"] = "Metres; Blender Z up. Origin and relative transforms preserved."
    collection.asset_mark()
    collection.asset_data.description = record["name"] + ". " + record["notes"] + " Source: " + record["source"]
    collection.asset_data.author = "Rook project"
    collection.asset_data.catalog_id = str(uuid.uuid5(uuid.NAMESPACE_URL, "rook/" + record["category"]))
    for tag in ["Rook", record["category"][3:], "Reference", "Metres"]:
        collection.asset_data.tags.new(tag)
    if record["stats"]["bone_count"]:
        collection.asset_data.tags.new("Rigged")
    masters.frame_set(0)
    bpy.context.view_layer.update()
    points = []
    for obj in objects:
        if obj.type in {"MESH", "CURVE"}:
            evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            points.extend(evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box)
    assert points, record["name"]
    low = Vector(tuple(min(point[i] for point in points) for i in range(3)))
    high = Vector(tuple(max(point[i] for point in points) for i in range(3)))
    record["blender_bounds_min"] = list(low)
    record["blender_bounds_max"] = list(high)
    record["blender_mesh_count"] = sum(obj.type == "MESH" for obj in objects)
    record["blender_curve_count"] = sum(obj.type == "CURVE" for obj in objects)
    record["blender_bone_count"] = sum(len(obj.data.bones) for obj in objects if obj.type == "ARMATURE")
    record["unweighted_end_markers"] = sum(obj.type == "EMPTY" and obj.name.split(".")[0].endswith("_end") for obj in objects)
    assert record["blender_mesh_count"] + record["blender_curve_count"] == record["stats"]["mesh_count"], (record["name"], record["blender_mesh_count"], record["stats"]["mesh_count"])
    assert record["blender_bone_count"] + record["unweighted_end_markers"] == record["stats"]["bone_count"], record["name"]
    if record["unweighted_end_markers"]:
        record["notes"] += f" {record['unweighted_end_markers']} unweighted end bones are retained as named empties."
    # Compare exact static dimensions across the Y-up -> Z-up conversion.
    # Skinned scene AABBs are conservative, unlike Blender's evaluated pose bounds.
    if not record["stats"]["bone_count"]:
        source_low, source_high = record["stats"]["bounds_min"], record["stats"]["bounds_max"]
        expected = Vector((source_high[0] - source_low[0], source_high[2] - source_low[2], source_high[1] - source_low[1]))
        error = max(abs((high - low)[i] - expected[i]) for i in range(3))
        assert error < 0.025, (record["name"], "dimension error", error, tuple(high-low), tuple(expected))
    print("LIBRARY_IMPORTED", record["name"], tuple(round(value, 3) for value in high-low), flush=True)
    return collection, low, high


def text_object(collection, body, position, size, material, name=None):
    data = bpy.data.curves.new(name or body, "FONT")
    data.body = body
    data.size = size
    data.extrude = 0
    obj = bpy.data.objects.new(name or body, data)
    collection.objects.link(obj)
    obj.location = position
    obj.data.materials.append(material)
    obj.hide_select = True
    return obj


def flat_material(name, color):
    material = bpy.data.materials.new(name)
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (*color, 1)
    material.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])
    return material


def instance(collection, target, location, name):
    obj = bpy.data.objects.new(name, None)
    obj.instance_type = "COLLECTION"
    obj.instance_collection = collection
    obj.empty_display_size = 0.25
    target.objects.link(obj)
    obj.location = location
    return obj


def build_overview(records, components, overview):
    activate(overview)
    labels = new_collection("Labels and dimensions (display only)", overview)
    displays = new_collection("Component references - make instances real to edit", overview)
    title_mat = flat_material("Library / ivory text", (0.86, 0.88, 0.9))
    accent_mat = flat_material("Library / amber text", (0.95, 0.57, 0.21))
    muted_mat = flat_material("Library / slate text", (0.46, 0.56, 0.65))
    text_object(labels, "ROOK / COMPONENT LIBRARY", (0, 5, 0), 1.1, title_mat)
    text_object(labels, "44 reusable collections  /  metres  /  original pivots + editable meshes", (0, 3.5, 0), 0.43, muted_mat)
    text_object(labels, "Asset Browser: Current File  |  Drag into Modeling Workspace  |  Read START HERE in Text Editor", (0, 2.5, 0), 0.36, accent_mat)
    y = 0
    max_width = 76.0
    for category in sorted({record["category"] for record in records}):
        text_object(labels, category.upper(), (0, y, 0), 0.7, accent_mat)
        y -= 1.5
        x, row_depth = 0.0, 0.0
        for record in [item for item in records if item["category"] == category]:
            collection, low, high = components[record["slug"]]
            dims = high-low
            width = max(dims.x + 2.5, 9.2)
            depth = max(dims.y + 4.0, 6.5)
            if x + width > max_width and x:
                y -= row_depth + 1.5
                x, row_depth = 0.0, 0.0
            position = (x + width/2 - (low.x+high.x)/2, y - 1.0 - high.y, -low.z + 0.04)
            instance(collection, displays, position, record["name"])
            label_y = y - depth + 1.35
            text_object(labels, record["name"], (x+0.3, label_y, 0.02), 0.35, title_mat)
            text_object(labels, f"{dims.x:.2f} x {dims.y:.2f} x {dims.z:.2f} m", (x+0.3, label_y-0.5, 0.02), 0.29, muted_mat)
            record["display_position"] = list(position)
            x += width
            row_depth = max(row_depth, depth)
        y -= row_depth + 3
    return y


def add_studio(scene, bottom):
    studio = new_collection("Overview studio (display only)", scene)
    center = Vector((38, (bottom+7)/2, 0))
    data = bpy.data.cameras.new("Library overview")
    camera = bpy.data.objects.new("Library overview", data)
    studio.objects.link(camera)
    camera.location = center + Vector((0, -22, 95))
    camera.rotation_euler = (center-camera.location).to_track_quat("-Z", "Y").to_euler()
    data.type = "ORTHO"
    height = 7-bottom
    data.ortho_scale = max(height*1.06, 85)
    scene.camera = camera
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 16
    scene.cycles.use_denoising = True
    scene.render.resolution_y = 2400
    scene.render.resolution_x = int(2400*90/max(height*1.06, 85))
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.world = bpy.data.worlds.new("Neutral reference studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.19, 0.22, 0.27, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.75
    for name, direction, energy in [("Key", (0.35, -0.5, -1), 2.2), ("Fill", (-0.7, 0.1, -1), 0.8)]:
        light = bpy.data.lights.new(name, "SUN")
        light.energy = energy
        light.angle = math.radians(15)
        obj = bpy.data.objects.new(name, light)
        studio.objects.link(obj)
        obj.rotation_euler = Vector(direction).to_track_quat("-Z", "Y").to_euler()
    scene.view_settings.view_transform = "AgX"
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            space = area.spaces.active
            space.clip_end = 2000
            space.region_3d.view_location = center
            space.region_3d.view_distance = height*0.65
            space.region_3d.view_rotation = camera.rotation_euler.to_quaternion()
            space.region_3d.view_perspective = "ORTHO"
            space.shading.type = "MATERIAL"
            space.overlay.show_extras = False


def write_help(records):
    help_text = """ROOK COMPONENT LIBRARY — START HERE

44 component collections from the current project. All geometry is editable.
Units: metres; Blender Z up. Asset origins and relative transforms are retained.

REUSE IN THIS FILE
1. Switch to the Modeling Workspace scene using the top-right scene selector.
2. Change any area to Asset Browser. Select Current File, then a category.
3. Drag a component into the workspace. It initially arrives as a collection instance.
4. For independent editable geometry: Object > Apply > Make Instances Real (F3),
   then Object > Relations > Make Single User > Object & Data & Materials.
   Keep the parenting/rig when making a character or bell instance real.
5. For a reference that should update with its master, keep it as an instance.

EDIT A MASTER
Switch to Asset Sources scene and select the component collection in the Outliner.
Hide other collections or use Local View (numpad /) to focus on one asset.
Meshes, material slots, armatures, actions and connection empties remain separate.
Edits to a master update its overview/reference instances.

USE IN ANOTHER .BLEND
File > Append > this .blend > Collection > select a component (editable copy).
File > Link uses a live reference. Or add this folder as an Asset Library in
Preferences > File Paths > Asset Libraries; category catalogs are included.

SCALE AND PORTS
The current player/NPC wrappers include their in-game visual scale and offset.
Earlier versions remain at their original scene scale. Overview placements lift
each bounding box onto a display plane; that offset is never baked into masters.
Dimensions below each item are Blender X/Y/Z in metres. Individual stone tiles
are about 2 m, connectors use 6 m ports. Godot (x,y,z) maps to Blender (x,-z,y).
Connection markers retain their original names/transforms: local +Y outward.

RIGS
Bell: original native source, 3 bones, Ring / RingLoop actions, game scale 0.6.
Storefront: current game geometry with separate editable mesh pieces.
Rook/Hound/Mouse: imported scene rigs, vertex groups and animation clips retained.
Use frame 0 for the stored reference pose; inspect imported clips in NLA/Actions.

MATERIALS AND BEHAVIOR
Godot's toon shaders are represented by PBR base-color approximations in Blender.
The storefront uses its original authoring PBR materials, not its runtime palette.
Collision, scripts, audio, runtime lighting and UI are not Blender components.
This is a standalone snapshot; use the builder to refresh from changed project art.

SOURCE RECOVERY
Objects/Door_test.obj is absent. The exact door mesh was recovered with its MD5
checksum from web/index.pck and given Door01.tscn's transforms/material slots.
No replacement geometry was invented; the original project files are untouched.

INVENTORY
"""
    for record in records:
        help_text += "\n" + record["name"] + "\n  " + record["source"] + "\n"
    text = bpy.data.texts.new("START HERE - reuse and source notes")
    text.write(help_text)


def render_asset_previews(records, components, overview, folder):
    """Embed a useful three-quarter thumbnail for every Asset Browser entry."""
    scene = bpy.data.scenes.new("Temporary asset thumbnails")
    activate(scene)
    scene.world = overview.world
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    scene.cycles.use_denoising = True
    scene.render.resolution_x = scene.render.resolution_y = 256
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "AgX"
    scene.frame_set(0)
    collection = new_collection("Thumbnail studio", scene)
    for light in [obj for obj in overview.objects if obj.type == "LIGHT"]:
        copy = light.copy()
        collection.objects.link(copy)
    data = bpy.data.cameras.new("Thumbnail camera")
    data.type = "ORTHO"
    camera = bpy.data.objects.new("Thumbnail camera", data)
    collection.objects.link(camera)
    scene.camera = camera
    preview = instance(components[records[0]["slug"]][0], collection, (0, 0, 0), "Thumbnail asset")
    direction = Vector((0.9, -1.3, 0.85)).normalized()
    for record in records:
        master, low, high = components[record["slug"]]
        preview.instance_collection = master
        center = (low+high)/2
        camera.location = center + direction * (max(high-low)*3+3)
        camera.rotation_euler = (center-camera.location).to_track_quat("-Z", "Y").to_euler()
        inverse = camera.rotation_euler.to_matrix().transposed()
        corners = [inverse @ Vector((x, y, z)) for x in (low.x, high.x) for y in (low.y, high.y) for z in (low.z, high.z)]
        span = max(max(point[axis] for point in corners)-min(point[axis] for point in corners) for axis in (0, 1))
        data.ortho_scale = span*1.16
        scene.render.filepath = str(folder / (record["slug"] + "_preview.png"))
        bpy.ops.render.render(write_still=True)
        with bpy.context.temp_override(id=master):
            bpy.ops.ed.lib_id_load_custom_preview(filepath=scene.render.filepath)
        print("ASSET_PREVIEW", record["name"], flush=True)
    activate(overview)
    bpy.data.scenes.remove(scene)


def main():
    with tempfile.TemporaryDirectory(prefix="rook-component-library-") as temporary:
        folder = Path(temporary)
        records = export_godot(folder)
        bpy.ops.wm.read_factory_settings(use_empty=True)
        overview = bpy.context.scene
        overview.name = "Component Overview"
        masters = bpy.data.scenes.new("Asset Sources")
        workspace = bpy.data.scenes.new("Modeling Workspace")
        for scene in [overview, masters, workspace]:
            scene.unit_settings.system = "METRIC"
            scene.unit_settings.scale_length = 1
            scene.render.fps = 30
            scene.frame_start = 0
            scene.frame_end = 120
            scene.frame_set(0)
        activate(masters)
        components = {record["slug"]: import_component(record, folder, masters) for record in records}
        refs = new_collection("References - hide while exporting your new model", workspace)
        instance(components["rook_player"][0], refs, (-2, 0, 0), "Rook / size reference")
        new_collection("Build new objects here", workspace)
        write_help(records)
        bottom = build_overview(records, components, overview)
        add_studio(overview, bottom)
        render_asset_previews(records, components, overview, folder)
        # glTF image textures and native datablocks are embedded for portability.
        bpy.ops.file.pack_all()
        for collection in list(bpy.data.collections):
            if not collection.users and not collection.asset_data:
                bpy.data.collections.remove(collection)
        catalog = ["# Blender Asset Catalog Definition File", "VERSION 1", ""]
        for category in sorted({record["category"] for record in records}):
            catalog.append(f"{uuid.uuid5(uuid.NAMESPACE_URL, 'rook/' + category)}:{category}:{category}")
        (OUT / "blender_assets.cats.txt").write_text("\n".join(catalog) + "\n")
        (OUT / "component_inventory.json").write_text(json.dumps(records, indent=2) + "\n")
        bpy.context.preferences.filepaths.save_version = 0
        overview["Component count"] = len(records)
        overview["Instructions"] = "Read START HERE in the Text Editor; use Current File in Asset Browser."
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
        overview.render.filepath = str(OUT / "component_overview.png")
        bpy.ops.render.render(write_still=True)
        print("COMPONENT_LIBRARY_SAVED", BLEND, flush=True)


if __name__ == "__main__":
    main()
