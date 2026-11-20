"""Run in Blender with the existing rig open. Save a separate rigged variant."""
import math
from pathlib import Path

import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[1]
rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
collection = bpy.data.collections.new("SHIPMASTER · editable uniform")
bpy.context.scene.collection.children.link(collection)


def material(name, color, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = mat.diffuse_color
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = 0.55
    return mat


navy = material("Shipmaster · indigo wool", (0.036, 0.087, 0.153))
lining = material("Shipmaster · wine lining", (0.22, 0.048, 0.042))
leather = material("Shipmaster · dark leather", (0.031, 0.031, 0.041))
gold = material("Shipmaster · brushed brass", (0.53, 0.28, 0.07), 0.38)


def bind(obj, bone, mat):
    bpy.context.view_layer.update()
    if collection not in obj.users_collection:
        for group in list(obj.users_collection):
            group.objects.unlink(obj)
        collection.objects.link(obj)
    # The source armature is identity at rest. Bake primitive transforms into
    # the mesh so every new piece uses the original rig's coordinate system.
    matrix = obj.matrix_world.copy()
    obj.data.transform(matrix)
    obj.matrix_world = Matrix.Identity(4)
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    obj.parent = rig
    obj.vertex_groups.new(name=bone).add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Crow armature", "ARMATURE")
    modifier.object = rig
    return obj


def oval(name, center, size, bone, mat, vertices=16, rotation=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=1.0, depth=2.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    obj.rotation_euler.x = rotation
    return bind(obj, bone, mat)


def mesh(name, vertices, faces, bone, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    collection.objects.link(obj)
    return bind(obj, bone, mat)


def coat_panel(side):
    # Front remains open, so the profile and legs stay legible while walking.
    angles = [math.radians(a) for a in (17, 39, 64, 89, 114, 140, 165, 179)]
    vertices = []
    for z, width, depth in [(0.69, 0.29, 0.244), (0.50, 0.33, 0.247), (0.29, 0.36, 0.274)]:
        vertices.extend((side * width * math.sin(a), depth * math.cos(a) - 0.045, z - 0.08 * math.sin(a / 2)) for a in angles)
    faces = []
    for row in range(2):
        for column in range(len(angles) - 1):
            start = row * len(angles) + column
            face = (start, start + 1, start + 1 + len(angles), start + len(angles))
            faces.append(face if side < 0 else tuple(reversed(face)))
    clothing = mesh("Port coat skirt" if side < 0 else "Starboard coat skirt", vertices, faces, "Pelvis", navy)
    cloth = clothing.modifiers.new("Lined wool", "SOLIDIFY")
    cloth.thickness = 0.018
    clothing.data.materials.append(lining)
    cloth.material_offset_rim = 1


for name in ["Coat and collar", "Coat sleeve | left side", "Coat sleeve | right side"]:
    obj = bpy.data.objects.get(name)
    if obj:
        for i in range(len(obj.data.materials)):
            obj.data.materials[i] = navy
for obj in bpy.context.scene.objects:
    if obj.name.startswith(("Pocket placement", "Crossbody strap", "Satchel body", "Satchel flap")):
        obj.hide_set(True)

coat_panel(-1)
coat_panel(1)
oval("Cap · crown", (0.0, 0.081, 1.402), (0.223, 0.223, 0.078), "Head", navy)
oval("Cap · leather band", (0.0, 0.084, 1.363), (0.216, 0.217, 0.035), "Head", leather)
mesh("Cap · peak",
     [(-0.169, 0.19, 1.37), (0.169, 0.19, 1.37), (0.151, 0.262, 1.342),
      (0.086, 0.325, 1.318), (0.0, 0.337, 1.313), (-0.086, 0.325, 1.318),
      (-0.151, 0.262, 1.342)],
     [(0, 1, 2, 3, 4, 5, 6)], "Head", leather)
oval("Cap · brass badge", (0.0, 0.301, 1.408), (0.032, 0.032, 0.011), "Head", gold, 10, math.pi / 2)
for side in [-1, 1]:
    for number, (y, z) in enumerate([(0.248, 0.795), (0.242, 0.706), (0.215, 0.626)]):
        oval(f"Coat · brass button {side:+d}.{number}", (side * 0.098, y, z),
             (0.024, 0.024, 0.014), "Spine", gold, 10, math.pi / 2)
    mesh(f"Coat · lapel {side:+d}",
         [(side * 0.07, 0.227, 0.962), (side * 0.24, 0.195, 0.862), (side * 0.10, 0.263, 0.75)],
         [(0, 1, 2)], "Spine", lining)

bpy.context.scene["Role"] = "The Last Barrel / shipmaster"
bpy.context.scene["Variant source"] = "Crow - Rigged.blend"
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "art/TheLastBarrel/Shipmaster.blend"))
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
for obj in bpy.context.scene.objects:
    if obj.type == "MESH" and not obj.hide_get() and obj.find_armature() == rig:
        obj.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=str(ROOT / "Mesh/TheLastBarrel/Shipmaster.glb"),
    export_format="GLB", use_selection=True, export_yup=True, export_animations=False,
    export_cameras=False, export_lights=False, export_apply=True,
)
