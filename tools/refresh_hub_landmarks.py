"""Apply the three edited World Hub Components collections to the developed city."""
from pathlib import Path
import bpy
from mathutils import Matrix

root_dir = Path(__file__).resolve().parents[1]
library = root_dir / "art/WorldHubComponents/World_Hub_Components.blend"
world = root_dir / "art/HubCityMaster/Hub_City_Developed.blend"
names = (
    "01 024 | F Corner restaurant apartments",
    "01 023 | F Canal Bathhouse complete",
    "01 013 | C Wisteria gazebo and open pavilion",
)

def object_matrix(obj):
    if obj.parent:
        return object_matrix(obj.parent) @ obj.matrix_parent_inverse @ obj.matrix_basis
    return obj.matrix_basis.copy()

bpy.ops.wm.open_mainfile(filepath=str(world))
scene = bpy.context.scene
landmarks = scene.collection.children["05 LANDMARKS — existing component assemblies"]
with bpy.data.libraries.load(str(library), link=False, relative=False) as (src, dst):
    assert set(names) <= set(src.collections), "Edited collections are missing"
    dst.collections = list(names)

for name, source in zip(names, dst.collections):
    target = landmarks.objects[name.split(" | ", 1)[1]]
    old_objects = set(target.children_recursive)
    objects = set(source.all_objects)
    incoming = {obj for obj in objects if obj.type != 'EMPTY' or obj.children}
    meshes = {obj for obj in incoming if obj.type == 'MESH'}
    assert meshes and not any(obj.instance_type == 'COLLECTION' for obj in incoming)
    assert all(obj.parent is None or obj.parent in incoming for obj in incoming)
    assert not any(obj.library or (obj.data and obj.data.library) for obj in incoming)
    placement = target.matrix_world.copy()
    offset = Matrix.Translation(-source.instance_offset)
    expected = {obj: placement @ offset @ object_matrix(obj) for obj in meshes}

    for obj in sorted(incoming, key=lambda obj: obj.name):
        landmarks.objects.link(obj)
        if obj.parent is None:
            obj.parent = target
            obj.matrix_parent_inverse = offset
        obj.hide_select = False
        if obj.type == 'MESH':
            if obj.data.users > 1:
                obj.data = obj.data.copy()
            obj["world_hub_collection"] = name
    bpy.data.batch_remove(ids=old_objects | (objects - incoming) | {source})
    bpy.context.view_layer.update()
    assert set(target.children_recursive) == incoming
    assert target.matrix_world == placement
    for obj in meshes:
        assert obj.visible_get() and obj.data.users == 1 and obj.data.polygons, obj.name
        assert max(abs(a-b) for r,s in zip(obj.matrix_world, expected[obj]) for a,b in zip(r,s)) < 0.001, obj.name
    target["world_hub_collection"] = name
    print(f"REFRESHED {name}: {len(meshes)} editable meshes", flush=True)

# Stage the result before replacing the developed world; leave the existing .blend1 alone.
staged = world.with_name(".hub_landmark_refresh.blend")
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(staged), copy=True)
staged.replace(world)
