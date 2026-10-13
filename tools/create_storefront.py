import bpy
import math
import os
import random
from mathutils import Vector


ROOT = "/Users/mattpuleri/Desktop/godot-test"
OUT_DIR = os.path.join(ROOT, "Mesh", "Storefront")
BLEND_PATH = os.path.join(OUT_DIR, "source", "storefront.blend")
GLB_PATH = os.path.join(OUT_DIR, "storefront.glb")
PREVIEW_PATH = os.path.join(OUT_DIR, "storefront_preview.png")

random.seed(27)
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(os.path.dirname(BLEND_PATH), exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    pass

scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.film_transparent = False
scene.render.filepath = PREVIEW_PATH
scene.render.use_freestyle = True
scene.render.line_thickness = 1.05
scene.view_settings.look = "AgX - Medium High Contrast"

world = bpy.data.worlds.new("StorefrontWorld") if not bpy.data.worlds else bpy.data.worlds[0]
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.018, 0.014, 0.021, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.22


def material(name, color, roughness=0.82, metallic=0.0, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        strength_input = bsdf.inputs.get("Emission Strength")
        if emission_input:
            emission_input.default_value = (*emission, 1.0)
        if strength_input:
            strength_input.default_value = emission_strength
    return mat


WALL = material("Wall_Charcoal", (0.075, 0.065, 0.066))
WALL_PATCH = material("Wall_Warm_Patch", (0.15, 0.125, 0.11))
STONE = material("Stone_Warm_Grey", (0.22, 0.195, 0.17))
STONE_LIGHT = material("Stone_Highlight", (0.34, 0.295, 0.25))
WOOD = material("Wood_Dark", (0.16, 0.085, 0.045))
WOOD_LIGHT = material("Wood_Warm", (0.31, 0.16, 0.075))
ROOF = material("Roof_Black_Brown", (0.035, 0.028, 0.035))
WINDOW = material("Window_Deep_Blue", (0.018, 0.032, 0.052), roughness=0.35)
SIGN = material("Sign_Blank", (0.20, 0.12, 0.17))
SIGN_EDGE = material("Sign_Edge", (0.055, 0.035, 0.04))
BRASS = material("Brass", (0.42, 0.25, 0.07), roughness=0.48, metallic=0.35)
WAX = material("Candle_Wax", (0.74, 0.58, 0.32), roughness=0.9)
FLAME = material("Candle_Flame", (1.0, 0.25, 0.025), roughness=0.35,
                 emission=(1.0, 0.085, 0.008), emission_strength=8.0)
GROUND_MAT = material("Preview_Ground", (0.045, 0.038, 0.045), roughness=1.0)

model_objects = []


def mark(obj):
    model_objects.append(obj)
    return obj


def add_box(name, loc, dims, mat, rotation=(0, 0, 0), bevel=0.04, model=True):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0:
        mod = obj.modifiers.new("Small hand-cut bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
    for poly in obj.data.polygons:
        poly.use_smooth = False
    if model:
        mark(obj)
    return obj


def add_cylinder(name, loc, radius, depth, mat, vertices=10, rotation=(0, 0, 0), model=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                       location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    if model:
        mark(obj)
    return obj


def add_arch_panel(name, cx, y, bottom, width, straight_height, radius, depth, mat):
    points = [(-width / 2, bottom), (width / 2, bottom), (width / 2, bottom + straight_height)]
    for i in range(1, 8):
        theta = i * math.pi / 8
        points.append((radius * math.cos(theta), bottom + straight_height + radius * math.sin(theta)))
    points.append((-width / 2, bottom + straight_height))
    verts = []
    for dy in (-depth / 2, depth / 2):
        verts.extend([(cx + x, y + dy, z) for x, z in points])
    n = len(points)
    faces = []
    faces.append(tuple(range(n)))
    faces.append(tuple(range(n, n * 2))[::-1])
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mark(obj)
    return obj


def add_flame(name, loc):
    x, y, z = loc
    verts = [(x, y, z - 0.09), (x, y, z + 0.18)]
    ring_count = 7
    for i in range(ring_count):
        a = 2 * math.pi * i / ring_count
        verts.append((x + 0.075 * math.cos(a), y + 0.052 * math.sin(a), z))
    faces = []
    for i in range(ring_count):
        j = (i + 1) % ring_count
        faces.append((0, 2 + j, 2 + i))
        faces.append((1, 2 + i, 2 + j))
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(FLAME)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mark(obj)
    return obj


def add_point_light(name, loc):
    data = bpy.data.lights.new(name + "Data", "POINT")
    data.color = (1.0, 0.22, 0.045)
    data.energy = 55
    data.shadow_soft_size = 0.65
    obj = bpy.data.objects.new(name, data)
    obj.location = loc
    bpy.context.collection.objects.link(obj)
    mark(obj)
    return obj


# Main massing: squat, readable silhouette and a slightly oversized roof.
add_box("StoreBody", (0, 0, 2.55), (8.0, 4.55, 5.1), WALL, bevel=0.10)
add_box("Foundation", (0, -0.02, 0.24), (8.35, 4.8, 0.48), STONE, bevel=0.10)

roof_angle = math.atan2(1.3, 2.55)
roof_length = math.sqrt(2.55 ** 2 + 1.3 ** 2)
add_box("RoofFront", (0, -1.275, 5.72), (8.75, roof_length, 0.24), ROOF,
        rotation=(roof_angle, 0, 0), bevel=0.08)
add_box("RoofBack", (0, 1.275, 5.72), (8.75, roof_length, 0.24), ROOF,
        rotation=(-roof_angle, 0, 0), bevel=0.08)
add_box("RoofRidge", (0, 0, 6.36), (8.72, 0.30, 0.30), ROOF, bevel=0.10)

# A simple uneven chimney keeps the silhouette from feeling too perfect.
add_box("Chimney", (2.72, 0.65, 6.25), (0.88, 0.82, 1.80), STONE, rotation=(0, 0.02, -0.025), bevel=0.08)
add_box("ChimneyCap", (2.72, 0.65, 7.12), (1.08, 1.02, 0.24), STONE_LIGHT, bevel=0.08)

# Hand-cut foundation blocks across the facade.
foundation_widths = [0.92, 1.05, 0.78, 1.12, 0.88, 1.02, 0.80, 0.98]
x = -3.95
for i, width in enumerate(foundation_widths):
    x_center = x + width / 2
    add_box(f"FoundationStone_{i:02d}",
            (x_center, -2.43 - random.uniform(-0.02, 0.025), 0.48 + random.uniform(-0.025, 0.03)),
            (width - 0.055, 0.30, 0.52 + random.uniform(-0.05, 0.06)),
            STONE_LIGHT if i in (1, 5) else STONE,
            rotation=(random.uniform(-0.025, 0.025), random.uniform(-0.04, 0.04), random.uniform(-0.035, 0.035)),
            bevel=0.075)
    x += width

# Alternating corner quoins, intentionally a little irregular.
for side in (-1, 1):
    for i, z in enumerate((0.9, 1.65, 2.45, 3.25, 4.08, 4.82)):
        wide = 0.78 if i % 2 == 0 else 0.60
        add_box(f"CornerStone_{'L' if side < 0 else 'R'}_{i}",
                (side * (3.88 - (wide - 0.60) * 0.18), -2.40, z),
                (wide, 0.34, 0.58 + random.uniform(-0.07, 0.05)),
                STONE_LIGHT if i in (1, 4) else STONE,
                rotation=(random.uniform(-0.02, 0.02), 0, random.uniform(-0.035, 0.035)),
                bevel=0.075)

# Sparse wall patches echo the broken, graphic stone shapes in Demo_A2.
patches = [(-3.05, 3.90, 0.82, 0.34, -0.12), (-2.85, 1.10, 0.62, 0.28, 0.08),
           (2.92, 3.65, 0.72, 0.32, 0.05), (3.06, 1.34, 0.55, 0.25, -0.09),
           (-0.62, 4.75, 0.88, 0.28, 0.04), (0.72, 4.88, 0.55, 0.22, -0.05)]
for i, (px, pz, pw, ph, rot) in enumerate(patches):
    add_box(f"WallPatch_{i}", (px, -2.335, pz), (pw, 0.10, ph), WALL_PATCH,
            rotation=(0, 0, rot), bevel=0.06)


def build_window(label, cx):
    bottom = 1.22
    straight = 1.26
    radius = 0.84
    add_arch_panel(f"{label}_DarkGlass", cx, -2.405, bottom, 1.68, straight, radius, 0.10, WINDOW)
    # Sill and upright stone frame.
    add_box(f"{label}_Sill", (cx, -2.49, bottom - 0.10), (2.05, 0.34, 0.26), STONE_LIGHT,
            rotation=(0, 0, random.uniform(-0.015, 0.015)), bevel=0.06)
    add_box(f"{label}_FrameLeft", (cx - 0.94, -2.47, bottom + 0.66), (0.25, 0.30, 1.52), STONE, bevel=0.055)
    add_box(f"{label}_FrameRight", (cx + 0.94, -2.47, bottom + 0.66), (0.25, 0.30, 1.52), STONE, bevel=0.055)
    # Blocked arch, five chunky stones.
    for i, theta in enumerate((0.12, 0.82, 1.57, 2.32, 3.02)):
        r = 0.95
        px = cx + r * math.cos(theta)
        pz = bottom + straight + r * math.sin(theta)
        add_box(f"{label}_ArchStone_{i}", (px, -2.47, pz), (0.58, 0.32, 0.30),
                STONE_LIGHT if i == 2 else STONE,
                rotation=(0, theta - math.pi / 2, 0), bevel=0.065)
    # Heavy wooden mullions remain legible against the near-black glass.
    add_box(f"{label}_MullionV", (cx, -2.535, bottom + 0.76), (0.105, 0.12, 1.48), WOOD_LIGHT, bevel=0.025)
    add_box(f"{label}_MullionH", (cx, -2.535, bottom + 0.70), (1.65, 0.12, 0.105), WOOD_LIGHT, bevel=0.025)
    # Candle, flame, and a tiny warm light in each window.
    add_cylinder(f"{label}_Candle", (cx, -2.62, bottom + 0.40), 0.12, 0.56, WAX, vertices=9)
    add_cylinder(f"{label}_Wick", (cx, -2.62, bottom + 0.70), 0.018, 0.12, SIGN_EDGE, vertices=7)
    add_flame(f"{label}_Flame", (cx, -2.62, bottom + 0.83))
    add_point_light(f"{label}_CandleLight", (cx, -2.70, bottom + 0.90))


build_window("LeftWindow", -2.32)
build_window("RightWindow", 2.32)

# Central plank door with a chunky, slightly crooked surround.
add_box("DoorSlab", (0, -2.42, 1.72), (1.48, 0.20, 3.14), WOOD, bevel=0.075)
for i, px in enumerate((-0.52, -0.17, 0.18, 0.53)):
    add_box(f"DoorPlank_{i}", (px, -2.55, 1.72), (0.055, 0.06, 2.88), WOOD_LIGHT, bevel=0.012)
add_box("DoorFrameLeft", (-0.89, -2.46, 1.73), (0.30, 0.34, 3.38), STONE, bevel=0.065)
add_box("DoorFrameRight", (0.89, -2.46, 1.73), (0.30, 0.34, 3.38), STONE, bevel=0.065)
add_box("DoorLintel", (0, -2.46, 3.43), (2.10, 0.36, 0.36), STONE_LIGHT,
        rotation=(0, 0, -0.015), bevel=0.07)
add_cylinder("DoorHandle", (0.46, -2.61, 1.68), 0.075, 0.09, BRASS, vertices=10,
             rotation=(math.pi / 2, 0, 0))
add_box("DoorStep", (0, -2.73, 0.34), (2.15, 0.85, 0.30), STONE_LIGHT, bevel=0.09)

# Blank sign: framed but deliberately free of lettering so it can be named later.
add_box("BlankStoreSign", (0, -2.62, 4.58), (3.18, 0.24, 0.92), SIGN,
        rotation=(0, 0, 0.012), bevel=0.12)
add_box("SignTopEdge", (0, -2.77, 4.99), (2.86, 0.09, 0.10), SIGN_EDGE, bevel=0.025)
add_box("SignBottomEdge", (0, -2.77, 4.17), (2.86, 0.09, 0.10), SIGN_EDGE, bevel=0.025)
add_box("SignLeftEdge", (-1.43, -2.77, 4.58), (0.10, 0.09, 0.73), SIGN_EDGE, bevel=0.025)
add_box("SignRightEdge", (1.43, -2.77, 4.58), (0.10, 0.09, 0.73), SIGN_EDGE, bevel=0.025)
for side in (-1, 1):
    add_box(f"SignBracket_{'L' if side < 0 else 'R'}", (side * 1.12, -2.48, 5.17),
            (0.12, 0.56, 0.12), SIGN_EDGE, rotation=(0.28, 0, 0), bevel=0.02)

# A few roof battens add graphic lines without turning the asset noisy.
for i, y in enumerate((-2.05, -1.35, -0.65)):
    z = 5.72 + (y + 1.275) * math.tan(roof_angle)
    add_box(f"RoofBatten_{i}", (0, y - 0.03, z + 0.12), (8.35, 0.10, 0.10), ROOF,
            rotation=(roof_angle, 0, 0), bevel=0.025)

# Parent the exportable asset to one clean root.
root = bpy.data.objects.new("Storefront", None)
bpy.context.collection.objects.link(root)
model_objects.append(root)
for obj in model_objects:
    if obj != root and obj.parent is None:
        obj.parent = root

# Preview-only ground and lighting.
add_box("PreviewGround", (0, 0, -0.10), (13, 11, 0.20), GROUND_MAT, bevel=0.02, model=False)

key_data = bpy.data.lights.new("PreviewKeyData", "AREA")
key_data.energy = 1050
key_data.color = (0.72, 0.58, 0.48)
key_data.shape = "DISK"
key_data.size = 7.0
key = bpy.data.objects.new("PreviewKey", key_data)
key.location = (-5.5, -7.0, 11.0)
bpy.context.collection.objects.link(key)

fill_data = bpy.data.lights.new("PreviewFillData", "AREA")
fill_data.energy = 520
fill_data.color = (0.24, 0.30, 0.55)
fill_data.size = 5.0
fill = bpy.data.objects.new("PreviewFill", fill_data)
fill.location = (6.5, 1.0, 7.0)
bpy.context.collection.objects.link(fill)


def point_camera(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


camera_data = bpy.data.cameras.new("PreviewCameraData")
camera_data.type = "ORTHO"
camera_data.ortho_scale = 10.0
camera = bpy.data.objects.new("PreviewCamera", camera_data)
camera.location = (10.2, -13.2, 8.8)
point_camera(camera, (0, 0, 3.0))
bpy.context.collection.objects.link(camera)
scene.camera = camera

# Export only the reusable object, then retain the preview rig in the .blend.
bpy.ops.object.select_all(action="DESELECT")
for obj in model_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.export_scene.gltf(
    filepath=GLB_PATH,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    # Godot supplies tightly ranged gameplay candle lights in storefront.tscn.
    # Keeping Blender's preview lights out of the GLB prevents accidental spill.
    export_lights=False,
    export_cameras=False,
)

bpy.ops.wm.save_as_mainfile(filepath=BLEND_PATH)
bpy.ops.render.render(write_still=True)
print(f"Saved {BLEND_PATH}")
print(f"Saved {GLB_PATH}")
print(f"Saved {PREVIEW_PATH}")
