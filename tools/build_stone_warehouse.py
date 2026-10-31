"""Build an editable warehouse from the five native Architecture components.

Blender --background --factory-startup --python-exit-code 1 --python tools/build_stone_warehouse.py
"""
from pathlib import Path
import json
import math

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/ComponentLibrary/Rook_Component_Library.blend"
ART = ROOT / "art/StoneWarehouse"
GAME = ROOT / "Mesh/StoneWarehouse"
NAMES = ["Foundation", "Retaining wall", "Foundation corner", "Plain stone wall", "Windowed stone wall"]
PALETTE = {
    "Stone": (0.30, 0.34, 0.37, 1),
    "stone_wall": (0.19, 0.23, 0.26, 1),
    "wood": (0.19, 0.085, 0.035, 1),
    "wall-loop": (0.035, 0.045, 0.055, 1),
    "Material": (1.0, 0.62, 0.24, 1),
    "Slate": (0.075, 0.12, 0.17, 1),
    "SlateLight": (0.105, 0.16, 0.20, 1),
    "Iron": (0.045, 0.06, 0.075, 1),
    "Brass": (0.67, 0.40, 0.15, 1),
    "Recess": (0.018, 0.025, 0.035, 1),
}


def main():
    ART.mkdir(parents=True, exist_ok=True)
    GAME.mkdir(parents=True, exist_ok=True)
    (ART / ".gdignore").touch()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "Stone Warehouse - editable assembly"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1
    scene.frame_set(0)
    with bpy.data.libraries.load(str(SOURCE), link=False) as (source, target):
        target.collections = list(NAMES)
    prototypes = {c.name: c.objects[0] for c in target.collections}
    inventory = json.loads((SOURCE.parent / "component_inventory.json").read_text())
    dimensions = {r["name"]: Vector(r["blender_bounds_max"]) - Vector(r["blender_bounds_min"])
                  for r in inventory if r["name"] in NAMES}
    assembly = bpy.data.collections.new("Stone Warehouse")
    scene.collection.children.link(assembly)
    groups = {}
    for name in ["01 Stone plinth and quay", "02 Ground floor", "03 Upper floor", "04 Timber and roof", "05 Loading doors and details"]:
        group = bpy.data.collections.new(name)
        assembly.children.link(group)
        groups[name[:2]] = group
    materials = {}
    for name, color in PALETTE.items():
        material = bpy.data.materials.new("Warehouse_" + name)
        material.diffuse_color = color
        material.use_nodes = True
        bsdf = material.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Base Color"].default_value = color
        bsdf.inputs["Roughness"].default_value = 0.88
        if name == "Material":
            bsdf.inputs["Emission Color"].default_value = color
            bsdf.inputs["Emission Strength"].default_value = 1.2
        materials[name] = material
    for prototype in prototypes.values():
        prototype.data = prototype.data.copy()
        for index, material in enumerate(prototype.data.materials):
            key = material.name.split(".")[0] if material else "Recess"
            prototype.data.materials[index] = materials.get(key, materials["Stone"])

    def component(name, group, at, size, yaw=0):
        prototype = prototypes[name]
        obj = prototype.copy()
        obj.name = name.replace(" ", "_")
        groups[group].objects.link(obj)
        obj.select_set(False)
        scale = Vector(tuple(size[i] / dimensions[name][i] for i in range(3)))
        obj.matrix_world = (Matrix.Translation(at) @ Matrix.Rotation(yaw, 4, "Z") @
                            Matrix.Diagonal((*scale, 1)) @ prototype.matrix_basis)
        obj["Library component"] = name
        obj["Expected dimensions"] = tuple(abs(value) for value in
            (Matrix.Rotation(yaw, 3, "Z") @ Vector(size)))
        return obj

    def box(name, group, at, size, material="wood", bevel=0):
        bpy.ops.object.select_all(action="DESELECT")
        bpy.ops.mesh.primitive_cube_add(size=1, location=at)
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        for previous in list(obj.users_collection):
            previous.objects.unlink(obj)
        groups[group].objects.link(obj)
        obj.data.materials.append(materials[material])
        if bevel:
            modifier = obj.modifiers.new("Small worn edges", "BEVEL")
            modifier.width, modifier.segments = bevel, 1
        return obj

    def beam(name, a, b, width=0.14, depth=0.14, material="wood"):
        a, b = Vector(a), Vector(b)
        obj = box(name, "04", (a+b)/2, (width, depth, (b-a).length), material, 0.015)
        obj.rotation_euler = (b-a).to_track_quat("Z", "Y").to_euler()
        return obj

    # Local ground is Z=0; front is -Y (Godot +Z). The first floor begins at 1 m.
    box("Solid quay core", "01", (0, -0.45, -0.6), (10.5, 8.1, 2.64), "Stone", 0.06)
    for x in range(14):
        for y in range(11):
            box("Quay paving", "01", (-4.875+x*0.75, -4.1+y*0.75, 0.76),
                (0.73, 0.73, 0.12), "Stone", 0.025)
    for side in [-1, 1]:
        for i in range(10):
            component("Foundation", "01", (-3.375+i*0.75, side*2.72, 0), (0.76, 0.55, 1))
        for i in range(6):
            component("Foundation", "01", (side*4.22, -1.875+i*0.75, 0), (0.76, 0.55, 1), math.pi/2)
        for i in range(14):
            if not (side == -1 and 5 <= i <= 8):
                component("Retaining wall", "01", (-4.875+i*0.75, side*4.15-0.45, 0),
                          (0.75, 0.25, 0.82), 0 if side == -1 else math.pi)
    for x, y, yaw in [(-4.125,-2.625,0), (4.125,-2.625,math.pi/2),
                      (4.125,2.625,math.pi), (-4.125,2.625,math.pi*1.5)]:
        component("Foundation corner", "01", (x,y,0), (0.82,0.82,1), yaw)
    for i in range(3):
        box("Loading step", "01", (0,-5.35+i*0.35,0.14+i*0.14), (2.7,0.7,0.28+i*0.28), "Stone", 0.025)

    # Three 3 m bays across the facade, two along each side. The center front bay
    # becomes closed timber loading doors instead of a wall covering the opening.
    for floor in range(2):
        group, height = ("02" if floor == 0 else "03"), 1.0+floor*1.8
        for i, x in enumerate([-3, 0, 3]):
            if floor or i != 1:
                kind = "Windowed stone wall" if floor or i == 0 else "Plain stone wall"
                component(kind, group, (x,-3,height), (3.02,0.28,1.8))
            kind = "Windowed stone wall" if floor and i != 1 else "Plain stone wall"
            component(kind, group, (-x,3,height), (3.02,0.28,1.8), math.pi)
        for side in [-1, 1]:
            for i, y in enumerate([-1.5, 1.5]):
                kind = "Windowed stone wall" if floor or i == 0 else "Plain stone wall"
                component(kind, group, (side*4.5,y,height), (3.02,0.28,1.8), side*math.pi/2)
    for x in [-4.5, -1.5, 1.5, 4.5]:
        for y in [-3.06, 3.06]:
            box("Facade timber upright", "04", (x,y,2.8), (0.16,0.2,3.65), bevel=0.018)
    for y in [-3.08, 3.08]:
        for height in [1,2.8,4.62]:
            box("Facade timber ledger", "04", (0,y,height), (9.22,0.22,0.18), bevel=0.018)
    for side in [-1,1]:
        for height in [1,2.8,4.62]:
            box("Side timber ledger", "04", (side*4.56,0,height), (0.2,6.15,0.18), bevel=0.018)

    # A real pitched roof: slate courses, solid gables and exposed structural trim.
    eave, ridge, half_width = 4.7, 7.05, 4.95
    for side in [-1,1]:
        # Gable infill is a closed triangular prism, with editable mesh geometry.
        y = side*3.03
        verts = [(x,y+offset,z) for offset in [-0.08,0.08]
                 for x,z in [(-4.5,4.6),(4.5,4.6),(0,6.76)]]
        data = bpy.data.meshes.new("Gable stone infill")
        data.from_pydata(verts, [], [(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)])
        data.materials.append(materials["stone_wall"])
        obj = bpy.data.objects.new("Stone gable", data)
        groups["04"].objects.link(obj)
        frame_y = side*3.22
        for a,b in [((-4.6,frame_y,4.68),(0,frame_y,6.9)), ((0,frame_y,6.9),(4.6,frame_y,4.68)),
                    ((-4.55,frame_y,4.68),(4.55,frame_y,4.68)), ((0,frame_y,4.7),(0,frame_y,6.85)),
                    ((-2.4,frame_y,4.7),(0,frame_y,6.1)), ((2.4,frame_y,4.7),(0,frame_y,6.1))]:
            beam("Gable timber frame", a,b,0.16,0.24)
        for course in range(8):
            for tile in range(8):
                x0, x1 = side*half_width*course/8, side*half_width*(course+1)/8
                y0, y1 = -3.52+tile*0.88, -3.52+(tile+1)*0.88-0.016
                z0, z1 = ridge-(ridge-eave)*course/8, ridge-(ridge-eave)*(course+1)/8
                verts = [(x0,y0,z0),(x1,y0,z1),(x1,y1,z1),(x0,y1,z0)]
                verts += [(x,y,z-0.09) for x,y,z in verts]
                data = bpy.data.meshes.new("Slate tile")
                faces = [(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
                if side == -1:
                    faces = [tuple(reversed(face)) for face in faces]
                data.from_pydata(verts, [], faces)
                data.materials.append(materials["SlateLight" if (course+tile)%4 == 0 else "Slate"])
                obj = bpy.data.objects.new("Slate course",data)
                groups["04"].objects.link(obj)
        beam("Eave fascia", (side*4.95,-3.6,4.67),(side*4.95,3.6,4.67),0.22,0.22)
    beam("Roof ridge cap", (0,-3.6,7.07),(0,3.6,7.07),0.24,0.24,"Iron")
    # A stone chimney with a dark, capped opening adds an asymmetrical silhouette.
    box("Chimney stack", "04", (2.8,1.8,6.35), (0.65,0.7,2.2), "Stone",0.035)
    box("Chimney cap", "04", (2.8,1.8,7.5), (0.86,0.9,0.16), "Stone",0.025)
    box("Chimney opening", "04", (2.8,1.8,7.59), (0.48,0.52,0.025), "Recess")

    box("Loading door recess", "05", (0,-3.07,1.9), (2.95,0.16,1.82),"Recess")
    for i in range(10):
        box("Loading door plank", "05", (-1.305+i*0.29,-3.2,1.88), (0.275,0.10,1.73),bevel=0.018)
    for height in [1.25,2.45]:
        for side in [-1,1]:
            box("Door iron strap", "05", (side*0.74,-3.27,height), (1.32,0.055,0.09),"Iron",0.008)
    for side in [-1,1]:
        beam("Loading door diagonal",(side*0.12,-3.29,1.3),(side*1.38,-3.29,2.4),0.09,0.065)
        box("Door latch", "05", (side*0.13,-3.31,1.89), (0.07,0.065,0.24),"Iron",0.008)
    box("Cargo sign backing", "05", (0,-4.58,2.99),(2.3,0.13,0.36),"wood",0.025)
    text = bpy.data.curves.new("Night Cargo lettering", "FONT")
    text.body, text.align_x, text.align_y, text.size = "NIGHT CARGO", "CENTER", "CENTER", 0.22
    text.extrude = 0.002
    text.materials.append(materials["Brass"])
    obj = bpy.data.objects.new("Night Cargo sign", text)
    groups["05"].objects.link(obj)
    obj.location, obj.rotation_euler = (0,-4.66,3.0), (math.pi/2,0,0)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    # Convert only this lettering object, not the currently selected trim mesh.
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    for side in [-1,1]:
        x,y,z = side*1.68,-3.32,2.22
        box("Lantern iron hood", "05", (x,y,z+0.23), (0.24,0.24,0.1),"Iron",0.02)
        box("Lantern glass", "05", (x,y,z), (0.16,0.16,0.34),"Material",0.012)
        box("Lantern foot", "05", (x,y,z-0.22), (0.24,0.24,0.08),"Iron",0.012)
    # Crates and a loading awning make the quay readable as a working warehouse.
    for at in [(3.6,-3.8,1.16),(4.35,-3.6,1.13),(-3.8,-3.8,1.16)]:
        box("Dockside cargo crate", "05", at, (0.65,0.65,0.65),"wood",0.035)
        box("Crate binding", "05", (at[0],at[1]-0.335,at[2]),(0.67,0.04,0.09),"Iron")
    for side in [-1,1]:
        beam("Awning bracket",(side*1.65,-3.15,2.9),(side*1.65,-4.2,3.25),0.10,0.10)
    awning = box("Loading awning", "05", (0,-3.8,3.29),(3.6,1.5,0.12),"Slate",0.025)
    awning.rotation_euler.x = math.radians(9)

    # Delete authoring prototypes while retaining shared mesh/material datablocks.
    for prototype in prototypes.values():
        bpy.data.objects.remove(prototype, do_unlink=True)
    for collection in target.collections:
        bpy.data.collections.remove(collection)
    assembly.asset_mark()
    assembly.asset_data.description = "Two-story stone harbor warehouse assembled from the five native Architecture assets. Closed loading doors; reusable exterior."
    assembly.asset_data.author = "Rook project"
    assembly["Component library"] = str(SOURCE.relative_to(ROOT))
    assembly["Local front"] = "Blender -Y / Godot +Z; base at Z=0 / Y=0"
    assembly["Midnight Exchange placement"] = "NorthQuayWarehouse at Godot (-7, 0, -24)"
    bpy.context.view_layer.update()
    for obj in assembly.all_objects:
        if "Expected dimensions" in obj:
            corners = [obj.matrix_world @ Vector(v) for v in obj.bound_box]
            actual = [max(v[i] for v in corners) - min(v[i] for v in corners) for i in range(3)]
            assert max(abs(actual[i] - obj["Expected dimensions"][i]) for i in range(3)) < 0.001, (obj.name, actual)
    scene["Godot export"] = "Mesh/StoneWarehouse/stone_warehouse.glb"
    bpy.data.texts.new("START HERE - Stone Warehouse").write(
        "Editable warehouse assembled from Foundation, Retaining wall, Foundation corner, Plain stone wall and Windowed stone wall.\n"
        "Metres. Local front is -Y; origin at ground. Collections separate stonework, floors, roof and loading details.\n"
        "Godot wrapper: Modules/Buildings/StoneWarehouse.tscn. Placement: MidnightExchange/NorthQuayWarehouse.\n"
        "Closed exterior with simplified solid collision. Windows and lanterns glow without adding gameplay lights.\n"
        "Regenerate with tools/build_stone_warehouse.py, then tools/build_stone_warehouse.gd.\n")
    # Useful authoring viewport, with no presentation helpers exported to Godot.
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                space = area.spaces.active
                space.region_3d.view_location = (0,0,3)
                space.region_3d.view_distance = 18
                space.region_3d.view_rotation = Vector((11,-17,12)).to_track_quat("Z","Y")
                space.region_3d.view_perspective = "PERSP"
                space.shading.type = "MATERIAL"
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ART/"StoneWarehouse.blend"), compress=True)
    # Bake each assembly section into one export mesh. The saved source keeps
    # every editable piece; the game uses five meshes with shared materials.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    baked_groups = []
    for group in groups.values():
        copies = []
        for original in group.objects:
            evaluated = original.evaluated_get(depsgraph)
            mesh = bpy.data.meshes.new_from_object(evaluated, depsgraph=depsgraph)
            obj = bpy.data.objects.new(original.name + "_export", mesh)
            obj.matrix_world = original.matrix_world.copy()
            scene.collection.objects.link(obj)
            copies.append(obj)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in copies:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        baked = bpy.context.object
        baked.name = group.name
        baked_groups.append(baked)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in baked_groups:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = baked_groups[0]
    bpy.ops.export_scene.gltf(filepath=str(GAME/"stone_warehouse.glb"), export_format="GLB",
                             use_selection=True, export_yup=True, export_animations=False,
                             export_cameras=False, export_lights=False, export_apply=True)
    print("STONE_WAREHOUSE_BUILT",len(assembly.all_objects),"editable pieces",flush=True)


if __name__ == "__main__":
    main()
