"""Reopen and verify the delivered editable hub component file; render contact sheet."""
import bpy, json
from mathutils import Vector
from itertools import product
from pathlib import Path
R = Path(__file__).resolve().parents[1]
OUT = R / 'art/WorldHubComponents'
bpy.ops.wm.open_mainfile(filepath=str(OUT / 'World_Hub_Components.blend'))
m = json.loads((OUT / 'component_manifest.json').read_text())
errors = []
def raw_corners(ob):
    spans = [(min(v.co[i] for v in ob.data.vertices), max(v.co[i] for v in ob.data.vertices)) for i in range(3)]
    return [ob.matrix_world @ Vector(corner) for corner in product(*spans)]
seen_meshes = set()
seen_materials = {}
for record in m['components']:
    col = bpy.data.collections[record['collection']]
    assert col.asset_data
    meshes = [o for o in col.objects if o.type == 'MESH']
    assert len(meshes) == record['mesh_parts']
    assert meshes
    for ob in meshes:
        assert ob.data.library is None
        assert ob.data.users == 1
        assert ob.data not in seen_meshes
        seen_meshes.add(ob.data)
        for mat in ob.data.materials:
            if not mat:
                continue
            assert mat not in seen_materials or seen_materials[mat] == col.name, (mat.name, col.name)
            seen_materials[mat] = col.name
assert not [o.name for sc in bpy.data.scenes for o in sc.objects if o.instance_type == 'COLLECTION']
assert not [lib.filepath for lib in bpy.data.libraries]
assert not [im.filepath for im in bpy.data.images if im.source == 'FILE' and not im.packed_file]
assert len(bpy.data.scenes[m['reference_scene']].objects) > 8000
edit_verified = 0
for name in m['scenes']:
    bpy.context.window.scene = bpy.data.scenes[name]
    bpy.context.view_layer.update()
    for record in [r for r in m['components'] if r['scene'] == name]:
        collection = bpy.data.collections[record['collection']]
        bounds = [corner for o in collection.objects if o.type == 'MESH' for corner in raw_corners(o)]
        actual = [max(v[i] for v in bounds)-min(v[i] for v in bounds) for i in range(3)]
        assert max(abs(a-b) for a,b in zip(actual,record['dimensions_m'])) < .02, (record['name'],actual,record['dimensions_m'])
        if record['name'] == 'E Clock Hall complete':
            assert actual[2] > 17, actual  # 12 m tower, copper spire and finial above it.
        if record['name'] == 'A Cream peaked bookshop':
            assert actual[2] > 11, actual  # Three 3 m stories plus its pitched roof.
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for ob in bpy.context.scene.objects:
        ob.select_set(False)
    for ob in meshes:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.mode_set(mode='EDIT')
    assert all(o.mode == 'EDIT' for o in meshes)
    edit_verified += len(meshes)
    bpy.ops.object.mode_set(mode='OBJECT')
    for ob in meshes:
        ob.select_set(False)
report = {'components': len(m['components']), 'gallery_meshes': len(seen_meshes),
          'edit_mode_verified_gallery_meshes': edit_verified, 'independent_component_palettes': True, 'saved_assembly_bounds_verified': True,
          'linked_libraries': 0, 'remaining_instances': 0, 'errors': errors,
          'reference_objects': len(bpy.data.scenes[m['reference_scene']].objects)}
(OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
print('REOPEN_VALIDATION', json.dumps(report), flush=True)
sc = bpy.data.scenes['01 Used in Latest Hub']
bpy.context.window.scene = sc
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.light = 'STUDIO'
sc.display.shading.color_type = 'MATERIAL'
sc.display.shading.show_shadows = True
sc.display.shading.show_cavity = True
sc.display.shading.cavity_type = 'BOTH'
sc.display.shading.background_type = 'WORLD'
sc.world.color = (.045, .055, .075)
sc.render.resolution_x = 2200
sc.render.resolution_y = 1800
sc.render.filepath = str(OUT / 'used_components_overview.png')
bpy.ops.render.render(write_still=True)
print('PREVIEW_COMPLETE', flush=True)

# A closer contact sheet shows representative assemblies at useful viewing size.
from mathutils import Vector
preview = bpy.data.scenes.new('Temporary assembly preview')
preview.world = sc.world
bpy.context.window.scene = preview
names = ['A Cream peaked bookshop', 'B Rose stepped tailor', 'C Sage arched cafe', 'D Ochre oriel restaurant',
         'E Courtyard apartment complex', 'E Clock Hall complete', 'F Canal Bathhouse complete',
         'G Great Waterwheel Mill complete', 'A Warehouse complete', 'D Hillside villa complete',
         'C Wisteria gazebo and open pavilion', 'C Timber barn']
for index, name in enumerate(names):
    row = next(r for r in m['components'] if r['name'] == name and r['scene'] == '01 Used in Latest Hub')
    col = bpy.data.collections[row['collection']]
    preview.collection.children.link(col)
    bpy.context.view_layer.update()
    meshes = [o for o in col.objects if o.type == 'MESH']
    bounds = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    lo = Vector(tuple(min(p[i] for p in bounds) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    root = next(o for o in col.objects if o.type == 'EMPTY')
    x, y = index%4*36, index//4*36
    root.location += Vector((x-(lo.x+hi.x)/2, y-(lo.y+hi.y)/2, -lo.z))
    curve = bpy.data.curves.new('Assembly caption','FONT')
    curve.body = name
    curve.size = .65
    obj = bpy.data.objects.new(name+' caption',curve)
    preview.collection.objects.link(obj)
    obj.location = (x-14, y-16, .03)
camdata = bpy.data.cameras.new('Assembly preview')
cam = bpy.data.objects.new('Assembly preview',camdata)
preview.collection.objects.link(cam)
target = Vector((54,36,5))
cam.location = target + Vector((35,-125,165))
cam.rotation_euler = (target-cam.location).to_track_quat('-Z','Y').to_euler()
camdata.type = 'ORTHO'
camdata.ortho_scale = 166
camdata.clip_end = 2000
preview.camera = cam
preview.render.engine = 'BLENDER_WORKBENCH'
preview.display.shading.light = 'STUDIO'
preview.display.shading.color_type = 'MATERIAL'
preview.display.shading.show_shadows = True
preview.display.shading.show_cavity = True
preview.display.shading.cavity_type = 'BOTH'
preview.display.shading.background_type = 'WORLD'
preview.render.resolution_x = 2000
preview.render.resolution_y = 1600
preview.render.resolution_percentage = 100
preview.render.filepath = str(OUT / 'component_assemblies_preview.png')
bpy.ops.render.render(write_still=True)
print('ASSEMBLY_PREVIEW_COMPLETE',flush=True)
