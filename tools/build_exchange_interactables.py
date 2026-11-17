"""Build a separate editable prop workbook; refuses to overwrite artist edits."""
from pathlib import Path
import bpy, json, math, sys
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'art/MidnightExchange/MidnightExchange_Interactables.blend'
if DEST.exists() and "--replace" not in sys.argv:
    raise RuntimeError('Preserve or rename the existing artist workbook before rebuilding.')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 80
scene.render.fps = 30
scene.unit_settings.system = 'METRIC'
records = json.loads(Path('/tmp/exchange-interactables/manifest.json').read_text())
for index, rec in enumerate(records):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath='/tmp/exchange-interactables/' + rec['slug'] + '.glb')
    objects = set(bpy.data.objects) - before
    shapes = {bone.custom_shape for obj in objects if obj.type == 'ARMATURE' for bone in obj.pose.bones if bone.custom_shape}
    for shape in shapes:
        shape.hide_render = True
        shape.hide_set(True)
    objects -= shapes
    collection = bpy.data.collections.new(f"{index+1:02} {rec['name']}")
    scene.collection.children.link(collection)
    offset = Vector(((index % 3) * 3.5 - 3.5, -(index // 3) * 4.0, 0))
    for obj in objects:
        for old in list(obj.users_collection): old.objects.unlink(obj)
        collection.objects.link(obj)
        if obj.parent is None: obj.location += offset
        obj['Source'] = rec['source']
    name = rec['name']
    moving = next((o for o in objects if o.name.startswith('TurningPage' if name == 'Manifest' else 'CrankRotor')), None) if name in ('Manifest', 'Crank') else None
    if name == 'NightSeal':
        moving = next(o for o in objects if o.name.startswith('Visual'))
    if moving:
        moving.rotation_mode = 'XYZ'
        rest_loc, rest_rot = moving.location.copy(), moving.rotation_euler.copy()
        duration = {'Manifest':1.8, 'Crank':2.2, 'NightSeal':2.6}[name]
        for frame in range(1, round(duration*30)+2):
            t = (frame-1)/(duration*30)
            moving.location, moving.rotation_euler = rest_loc.copy(), rest_rot.copy()
            if name == 'Manifest':
                moving.rotation_euler.y += -math.sin(t*math.pi*4)*0.3
                moving.location.z += abs(math.sin(t*math.pi*4))*0.1
            elif name == 'Crank': moving.rotation_euler.y += t*math.tau*2
            else:
                moving.rotation_euler.z += t*math.tau
                moving.location.z += t*0.4
            moving.keyframe_insert(data_path='location', frame=frame)
            moving.keyframe_insert(data_path='rotation_euler', frame=frame)
        moving.animation_data.action.name = name + ' — Use Preview'
    # Imported bells retain their bone rig and Ring / RingLoop animation tracks.
    bpy.ops.object.text_add(location=offset + Vector((-1.1, -1.4, 0.02)))
    label=bpy.context.object
    label.name = name + ' label'
    label.data.body = name
    label.data.size = 0.28
scene.frame_set(1)
help_text = '''MIDNIGHT EXCHANGE — INTERACTABLES
Six actual level props, four designs: Manifest, Crank, NightSeal, Bell_0/1/2.
Each numbered collection contains editable meshes at game scale. One unit = one metre.
Press Space in the timeline to preview use motions. Bells retain imported skeletal clips;
select their armature in the Animation workspace to inspect Ring / RingLoop tracks.
Manifest: TurningPage moves while copying. Crank: CrankRotor turns wheel and crossbar.
NightSeal: Visual rotates and rises while recovered (hidden at completion in game).
Bells: bell and clapper swing when rung. All three placements use the same source design.
The ground labels are presentation aids, not game assets.
Layout offsets are for this workbook only. Export one numbered collection at a time,
restore its root to the origin, and include the moving-part hierarchy and animations.
This workbook is a snapshot; edits do not automatically update the game.
The game currently drives station motion by progress; preserve TurningPage and CrankRotor
when integrating a polished replacement. Bell animation uses the existing Ring action.
Original bell authoring file: Mesh/Bell/source/bell_rigged.blend.
'''
bpy.data.texts.new('START HERE').write(help_text)
scene['README'] = help_text
# A useful modeling overview and a renderable preview.
bpy.ops.object.camera_add(location=(9,-14,12))
cam=bpy.context.object
cam.rotation_euler=(Vector((0,-2,0.5))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=13;scene.camera=cam
for pos,energy,size in [((2,-5,10),1800,8),((-6,1,7),1000,6)]:
    bpy.ops.object.light_add(type='AREA', location=pos)
    light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=size
    light.rotation_euler=(Vector((0,-2,0))-light.location).to_track_quat('-Z','Y').to_euler()
scene.world.color=(0.18,0.18,0.18)
scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=13
            area.spaces.active.region_3d.view_location=Vector((0,-2,0.5))
            area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
            area.spaces.active.shading.color_type='MATERIAL'
bpy.ops.object.select_all(action='DESELECT')
mesh_count = len([o for o in bpy.data.objects if o.type=='MESH'])
print('WORKBOOK_MESHES', mesh_count)
assert mesh_count == 41  # 38 prop meshes plus three hidden bone widgets
assert all(any(o.type == 'MESH' for o in c.all_objects) for c in scene.collection.children if c.name[:2].isdigit())
bpy.ops.wm.save_as_mainfile(filepath=str(DEST))
scene.render.filepath=str(DEST.with_suffix('.png'))
bpy.ops.render.render(write_still=True)
print('INTERACTABLE_WORKBOOK_SAVED', DEST)
