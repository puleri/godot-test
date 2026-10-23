"""Prepare the user's bell mesh. Run with Blender --background --python tools/prepare_bell.py.
Defaults to Desktop/bell.blend; override with -- /absolute/input.blend.
Only writes the prepared copy and GLB under Mesh/Bell; never overwrites the input.
"""
import bpy
import math
import os
import sys
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'Mesh', 'Bell')
source = sys.argv[sys.argv.index('--') + 1] if '--' in sys.argv else os.path.expanduser('~/Desktop/bell.blend')
if os.path.realpath(source) == os.path.realpath(os.path.join(OUT, 'source', 'bell_rigged.blend')):
    raise ValueError('Use the original unprepared bell as input; export the edited rig directly from Blender.')
bpy.ops.wm.open_mainfile(filepath=source)
scene = bpy.context.scene
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
source_meshes = [o for o in scene.objects if o.type == 'MESH']
if len(source_meshes) != 1:
    raise ValueError('Expected the original bell source with a single joined mesh.')
original = source_meshes[0]
vertices = [original.matrix_world @ v.co for v in original.data.vertices]
faces = [list(p.vertices) for p in original.data.polygons]
frame_ids = {i for i, v in enumerate(vertices) if abs(v.x) > 1.3}
clapper_ids = {i for i, v in enumerate(vertices) if math.hypot(v.x, v.y) < .18 and v.z < 1.56}
parts = {'TimberFrame': [], 'BellShell': [], 'Clapper': []}
for face in faces:
    key = 'TimberFrame' if all(i in frame_ids for i in face) else 'Clapper' if all(i in clapper_ids for i in face) else 'BellShell'
    parts[key].append(face)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for material in list(bpy.data.materials):
    bpy.data.materials.remove(material)
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
scene.render.fps = 30
scene.frame_start = 0
scene.frame_end = 120

def material(name, color, metallic, roughness):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = (*color, 1)
    node.inputs['Metallic'].default_value = metallic
    node.inputs['Roughness'].default_value = roughness
    return mat

bronze = material('Bell_Aged_Bronze', (.34, .155, .047), .72, .43)
lip = material('Bell_Polished_Rim', (.58, .32, .105), .8, .31)
patina = material('Bell_Verdigris', (.055, .17, .135), .42, .78)
inside = material('Bell_Inner_Bronze', (.17, .074, .024), .65, .62)
wood = material('Frame_Dark_Oak', (.115, .045, .019), 0, .88)
wood_light = material('Frame_Oak_Endgrain', (.21, .095, .036), 0, .85)
iron = material('Hardware_Blackened_Iron', (.045, .055, .065), .7, .49)
iron_edge = material('Hardware_Worn_Edges', (.16, .18, .19), .8, .36)
objects = []

def mesh_part(name, source_faces):
    ids = sorted({i for f in source_faces for i in f})
    remap = {v: i for i, v in enumerate(ids)}
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([vertices[i] for i in ids], [], [[remap[i] for i in f] for f in source_faces])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    objects.append(obj)
    return obj

frame = mesh_part('TimberFrame', parts['TimberFrame'])
frame.data.materials.clear()
for mat in (wood, wood_light): frame.data.materials.append(mat)
for p in frame.data.polygons:
    p.material_index = 1 if p.normal.z > .5 else 0
# The frame uses large, slightly non-planar handmade n-gons. Explicit face
# normals prevent its export triangulation from creating diagonal light bands.
frame_normals = [tuple(p.normal) for p in frame.data.polygons for _ in p.loop_indices]
for p in frame.data.polygons: p.use_smooth = True
frame.data.normals_split_custom_set(frame_normals)
shell = mesh_part('BellShell', parts['BellShell'])
for mat in (bronze, lip, patina, inside): shell.data.materials.append(mat)
for p in shell.data.polygons:
    center = p.center
    radius = math.hypot(center.x, center.y)
    # Keep the handmade facets; accents export as ordinary PBR material slots.
    if center.z < .92 and radius > .5:
        p.material_index = 1
    elif p.normal.x * center.x + p.normal.y * center.y < -.05:
        p.material_index = 3
    elif p.index % 13 == 5 and .95 < center.z < 1.95:
        p.material_index = 2
    else:
        p.material_index = 0
clapper = mesh_part('Clapper', parts['Clapper'])
for mat in (iron, iron_edge): clapper.data.materials.append(mat)
for p in clapper.data.polygons:
    p.material_index = 1 if p.center.z < .9 else 0

# Rigid weights keep the bell and clapper from bending like rubber.
rig_data = bpy.data.armatures.new('BellArmature')
rig = bpy.data.objects.new('BellRig', rig_data)
scene.collection.objects.link(rig)
rig.show_in_front = True
bpy.context.view_layer.objects.active = rig
rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
root = rig_data.edit_bones.new('Root'); root.head=(0,0,0); root.tail=(0,0,.35)
bell = rig_data.edit_bones.new('BellSwing'); bell.head=(0,0,2.16); bell.tail=(0,0,1.75); bell.parent=root
cl = rig_data.edit_bones.new('ClapperSwing'); cl.head=(0,0,1.5416); cl.tail=(0,0,.81); cl.parent=bell
bpy.ops.object.mode_set(mode='OBJECT')
rig_data.display_type = 'STICK'

def bind(obj, bone):
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    mod = obj.modifiers.new('Rigid bell armature', 'ARMATURE'); mod.object=rig
    obj.parent=rig

bind(frame, 'Root'); bind(shell, 'BellSwing'); bind(clapper, 'ClapperSwing')

def cylinder(name, loc, radius, depth, mat, bone):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth, location=loc, rotation=(0,math.pi/2,0))
    obj=bpy.context.object; obj.name=name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat); objects.append(obj); bind(obj,bone)
    return obj

cylinder('CrownAxle', (0,0,2.16), .075, .9, iron, 'Root')
for x in (-.4,.4):
    cylinder('AxleCollar', (x,0,2.16), .115, .09, iron_edge, 'Root')
# Restrained iron bands make the timber support read at gameplay distance.
for x in (-1.79,1.80):
    for z in (.27,1.98):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(x,0,z))
        obj=bpy.context.object;obj.name='FrameIronBand';obj.dimensions=(.235,.322,.11)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        obj.data.materials.append(iron);objects.append(obj);bind(obj,'Root')

# Both bones point down; local X coincides with world X. Bell swings through
# the frame (front/back), with a delayed clapper that approaches the inner rim.
for pose in rig.pose.bones: pose.rotation_mode='XYZ'

def animate(name, duration, looping):
    rig.animation_data_clear()
    for pose in rig.pose.bones: pose.rotation_euler=(0,0,0)
    steps=round(duration*30)
    for i in range(steps+1):
        t=i/30
        if looping:
            angle=math.radians(20)*math.sin(2*math.pi*t/1.6)
            striker=math.radians(26)*math.sin(2*math.pi*t/1.6-.65)
        else:
            # Smoothly start and stop exactly at rest over four seconds.
            envelope=math.sin(math.pi*t/duration)**2 * math.exp(-.38*t)
            angle=math.radians(38)*envelope*math.sin(2*math.pi*t/1.1)
            striker=math.radians(48)*envelope*math.sin(2*math.pi*t/1.1-.8)
        for bone, value in [('BellSwing',angle),('ClapperSwing',striker)]:
            pose=rig.pose.bones[bone];pose.rotation_euler.x=value
            pose.keyframe_insert('rotation_euler',frame=i,group=bone)
    action=rig.animation_data.action;action.name=name;action.use_fake_user=True
    for slot in action.slots:
        for layer in action.layers:
            for strip in layer.strips:
                bag=strip.channelbag(slot)
                if bag:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points: key.interpolation='LINEAR'
    return action

ring_action=animate('Ring',4.0,False)
loop_action=animate('RingLoop',3.2,True)
rig.animation_data.action=ring_action
scene.frame_set(0)
rig['instructions']='BellSwing: local X rotation. ClapperSwing: local X, parented to BellSwing. Root stays fixed. Ring = one-shot 4s; RingLoop = 3.2s.'
scene['source_file']=os.path.basename(source)
scene['asset_notes']='Preserved handmade bell, clapper and frame geometry. Split into rigid skinned parts; added axle and iron bands. Units: metres, Z up.'
# Export only model/rig, excluding the studio lights and camera.
bpy.ops.object.select_all(action='DESELECT')
for obj in [rig]+objects:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
os.makedirs(os.path.join(OUT,'source'),exist_ok=True)
open(os.path.join(OUT,'source','.gdignore'),'a').close()
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,'bell.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,export_force_sampling=True,export_cameras=False,export_lights=False,export_materials='EXPORT',export_yup=True)
# A studio preview is retained in the editable source, excluded from the GLB.
world=bpy.data.worlds.new('BellStudio');scene.world=world;world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.035,.045,.055,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
for name, loc, power, color, size in [('Key',(1,-4,6),1500,(1,.82,.6),4),('Fill',(-4,-2,3),950,(.65,.8,1),3),('Rim',(1,3,5),1800,(.8,.92,1),3)]:
    data=bpy.data.lights.new(name,'AREA');data.energy=power;data.color=color;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=loc
    obj.rotation_euler=(Vector((0,0,1.2))-obj.location).to_track_quat('-Z','Y').to_euler()
camera_data=bpy.data.cameras.new('PreviewCamera');camera=bpy.data.objects.new('PreviewCamera',camera_data);scene.collection.objects.link(camera)
camera.location=(4.2,-8,3.7);camera.rotation_euler=(Vector((0,0,1.25))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=4.9;scene.camera=camera
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.view_settings.look='AgX - Medium High Contrast'
for area in bpy.context.screen.areas:
    if area.type=='VIEW_3D':
        area.spaces.active.shading.type='MATERIAL'
        area.spaces.active.region_3d.view_distance=6
        area.spaces.active.region_3d.view_location=(0,0,1.2)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'source','bell_rigged.blend'))
scene.render.filepath=os.path.join(ROOT,'docs','images','bell-material-preview.png')
bpy.ops.render.render(write_still=True)
print('BELL_PREPARED',len(vertices),'source vertices;',len(rig_data.bones),'bones; Ring and RingLoop animations')
