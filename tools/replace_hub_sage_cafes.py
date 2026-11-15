"""Replace Sage Arched Café geometry in the developed world with the edited apartments."""
from pathlib import Path
import re

import bpy
from mathutils import Matrix, Vector

project = Path(__file__).resolve().parents[1]
world = project / "art/HubCityMaster/Hub_City_Developed.blend"
library = project / "art/WorldHubComponents/World_Hub_Components.blend"
source_name = "01 024 | F Corner restaurant apartments"
cafe_name = "C Sage arched cafe"
replacement_name = "F Corner restaurant apartments"


def local_matrix(obj):
    if obj.parent is None:
        return obj.matrix_basis.copy()
    return local_matrix(obj.parent) @ obj.matrix_parent_inverse @ obj.matrix_basis


def bounds(points):
    points = list(points)
    return tuple(Vector([end(point[i] for point in points) for i in range(3)])
                 for end in (min, max))


bpy.ops.wm.open_mainfile(filepath=str(world))
scene = bpy.context.scene
landmarks = scene.collection.children["05 LANDMARKS — existing component assemblies"]
buildings = scene.collection.children["24 COMPLETION — detailed buildings"]
assemblies = [obj for obj in landmarks.objects if obj.type == 'EMPTY'
              and re.fullmatch(re.escape(cafe_name) + r"(?:\.\d+)?", obj.name)]
merchants = [obj for obj in buildings.objects if obj.type == 'MESH'
             and obj.get("completion_asset") == "Merchant variant 03"]

if not assemblies and not merchants:
    print("No Sage Arched Café placements remain.")
else:
    with bpy.data.libraries.load(str(library), link=False) as (available, appended):
        assert source_name in available.collections
        appended.collections = [source_name]

    source = appended.collections[0]
    source_objects = set(source.all_objects)
    source_meshes = [obj for obj in source_objects if obj.type == 'MESH']
    assert len(source_meshes) == 1, "Expected the edited restaurant as one mesh"
    model = source_meshes[0]
    assert not model.modifiers, "Evaluate the source modifiers before fitting the mesh"
    template = model.data.copy()
    for index, slot in enumerate(model.material_slots):
        template.materials[index] = slot.material
    transform = Matrix.Translation(-source.instance_offset) @ local_matrix(model)
    template.transform(transform)
    if transform.to_3x3().determinant() < 0:
        template.flip_normals()
    new_lo, new_hi = bounds(v.co for v in template.vertices)
    bpy.data.batch_remove(ids=source_objects | {source})

    for target in assemblies + merchants:
        placement = target.matrix_world.copy()
        if target in assemblies:
            old_parts = list(target.children_recursive)
            inverse = placement.inverted()
            local_placements = [(obj, inverse @ obj.matrix_world)
                                for obj in old_parts if obj.type == 'MESH']
            old_lo, old_hi = bounds(matrix @ v.co for obj, matrix in local_placements
                                    for v in obj.data.vertices)
        else:
            old_lo, old_hi = bounds(v.co for v in target.data.vertices)

        # Fit the frontage to the existing lot, preserve height, and keep the same base.
        # Leave a shallower replacement centered within the former footprint.
        new_size = new_hi - new_lo
        lot_size = old_hi - old_lo
        scale = Vector((min(1.0, lot_size.x / new_size.x),
                        min(1.0, lot_size.y / new_size.y), 1.0))
        old_anchor = Vector(((old_lo.x + old_hi.x) / 2, (old_lo.y + old_hi.y) / 2, old_lo.z))
        new_anchor = Vector(((new_lo.x + new_hi.x) / 2, (new_lo.y + new_hi.y) / 2, new_lo.z))
        fitted = template.copy()
        fitted.name = replacement_name + " | Fitted café lot"
        fitted.transform(Matrix.Translation(old_anchor) @ Matrix.Diagonal((*scale, 1.0))
                         @ Matrix.Translation(-new_anchor))
        fitted.update()
        fit_lo, fit_hi = bounds(v.co for v in fitted.vertices)
        assert all(fit_lo[i] >= old_lo[i] - 0.001 and fit_hi[i] <= old_hi[i] + 0.001
                   for i in (0, 1))
        assert abs(fit_lo.z - old_lo.z) < 0.001
        if target in assemblies:
            replacement = bpy.data.objects.new(replacement_name + " | Café lot", fitted)
            landmarks.objects.link(replacement)
            replacement.parent = target
            bpy.data.batch_remove(ids=old_parts)
        else:
            replacement = target
            replacement.data = fitted
            target["completion_asset"] = replacement_name
            target["editable_source"] = library.name
        replacement["world_hub_collection"] = source_name
        replacement["replaces_building"] = cafe_name
        target.name = replacement_name + " | Former café"
        bpy.context.view_layer.update()
        assert replacement.visible_get() and replacement.data.users == 1
        assert target.matrix_world == placement

    bpy.data.meshes.remove(template)
    staged = world.with_name(".hub_cafe_replacement.blend")
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(staged), copy=True)
    staged.replace(world)
    print(f"CAFE_REPLACEMENT_PASS assemblies={len(assemblies)} merchants={len(merchants)}", flush=True)
