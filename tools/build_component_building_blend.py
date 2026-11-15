"""Create the editable Blender copy of the same twelve-piece Godot assembly."""
from pathlib import Path
import json
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/ComponentBuilding'
SOURCE = ROOT / 'art/ComponentLibrary/Rook_Component_Library.blend'
manifest = json.loads((OUT / 'assembly.json').read_text())
inventory = {r['slug']: r for r in json.loads((SOURCE.parent / 'component_inventory.json').read_text())}
names = sorted({inventory[p['component']]['name'] for p in manifest['pieces']})
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = 'Component Building - seam inspection'
scene.unit_settings.system = 'METRIC'
scene.frame_set(0)
with bpy.data.libraries.load(str(SOURCE), link=False) as (source, target):
    target.collections = names
prototypes = {c.name: next(o for o in c.all_objects if o.type == 'MESH') for c in target.collections}
assembly = bpy.data.collections.new('BUILDING - 12 original components')
scene.collection.children.link(assembly)
groups = {}
for name in ['GroundFloor', 'UpperFloor']:
    group = bpy.data.collections.new(name)
    assembly.children.link(group)
    groups[name] = group
for piece in manifest['pieces']:
    record = inventory[piece['component']]
    prototype = prototypes[record['name']]
    obj = prototype.copy()
    # Share original mesh data. No mesh edits, new windows, modifiers, or resizing.
    obj.name = piece['name'].split('/')[1] + ' - ' + record['name']
    groups[piece['name'].split('/')[0]].objects.link(obj)
    x, y, z = piece['position']
    obj.matrix_world = Matrix.Translation((x, -z, y)) @ Matrix.Rotation(piece['yaw'], 4, 'Z') @ prototype.matrix_world
    obj['Library component'] = record['name']
    obj['Geometry changes'] = 'None; original library mesh and 4x library scale'
for prototype in prototypes.values():
    bpy.data.objects.remove(prototype, do_unlink=True)
for collection in target.collections:
    bpy.data.collections.remove(collection)
notes = bpy.data.texts.new('READ ME - component fit study')
notes.write('''ONE BUILDING / 12 ORIGINAL COMPONENTS

GroundFloor: 4 plain corners, 1 door wall, 1 windowed wall.
UpperFloor: 4 second-story corners, 1 second-story window, 1 second-story plain wall.

Every object is an unmodified native component from the current library.
Only translation and quarter-turn rotations were added. No extra windows,
trim overlays, fitted boxes, roof, merged meshes, or nonuniform scaling.
The top is open to make the inside joins and corner returns easy to inspect.
Native trim/proportion differences are retained; this is a fit study, not a
claim that the supplied pieces already form clean production seams.

Select an individual piece to inspect it, or hide UpperFloor in the Outliner.
The same placements are in assembly.json and Modules/Buildings/ComponentBuilding.tscn.
''')
assembly['Source'] = str(SOURCE.relative_to(ROOT))
assembly['Purpose'] = 'Component fit study; native trim and seam differences retained'
bpy.context.view_layer.update()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'SOLID'
            space.shading.color_type = 'SINGLE'
            space.shading.single_color = (0.52, 0.56, 0.60)
            space.shading.light = 'STUDIO'
            space.clip_end = 1000
            space.region_3d.view_distance = 62
            space.region_3d.view_location = Vector((0, 0, 6))
            direction = Vector((42, -48, 29))
            space.region_3d.view_rotation = direction.to_track_quat('Z', 'Y')
            space.overlay.show_floor = True
bpy.ops.object.select_all(action='DESELECT')
(OUT / '.gdignore').touch()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'ComponentBuilding.blend'))
print('COMPONENT_BUILDING_BLEND_SAVED', len(manifest['pieces']))
