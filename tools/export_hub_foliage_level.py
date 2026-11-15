"""Export visible city in spatial chunks; preserve Blender source and foliage overlay."""
import bpy, math, json
from pathlib import Path
from collections import defaultdict
from mathutils import Vector
R=Path(__file__).resolve().parents[1];OUT=R/'Assets/HubCity';OUT.mkdir(exist_ok=True,parents=True)
bpy.ops.wm.open_mainfile(filepath=str(R/'art/HubCityMaster/Hub_City_Developed.blend'))
EXPORT=R/'art/HubCityGameExport';EXPORT.mkdir(parents=True,exist_ok=True);(EXPORT/'.gdignore').touch()
s=bpy.context.scene;dg=bpy.context.evaluated_depsgraph_get();groups={};materials={};lamps=[]
# Export flat palette materials; keep the authored terrain colors exactly.
def material(src,terrain=False,authored=False):
 key=(src.name if src else 'Default',terrain,authored)
 if key in materials:return materials[key]
 m=bpy.data.materials.new('Game '+key[0]);m.diffuse_color=(1,1,1,1) if terrain else tuple(src.diffuse_color) if src else (.3,.3,.3,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=.85
 if terrain:
  a=m.node_tree.nodes.new('ShaderNodeVertexColor');a.layer_name='Color';m.node_tree.links.new(a.outputs['Color'],p.inputs['Base Color'])
 elif src and src.use_nodes:
  old=src.node_tree.nodes.get('Principled BSDF')
  if old:
   if authored:
    for n in ['Base Color','Roughness','Metallic']:
     if not old.inputs[n].is_linked:p.inputs[n].default_value=old.inputs[n].default_value
   for n in ['Emission Color','Emission Strength']:
    if n in old.inputs and not old.inputs[n].is_linked:p.inputs[n].default_value=old.inputs[n].default_value
 materials[key]=m;return m
for o in list(s.objects):
 if o.type=='LIGHT' and o.visible_get() and o.data.type=='POINT':
  p=o.matrix_world.translation;lamps.append([p.x,p.z,-p.y])
 if o.type!='MESH' or not o.visible_get() or o.get('foliage_asset'):continue
 cols=' '.join(c.name for c in o.users_collection)
 if 'scale references' in cols or 'LABEL' in cols:continue
 isterrain=o.name=='City terrain — 400 x 400 meters'
 decorative=any(x in cols.lower() for x in ['vegetation','foliage','water','light']) or any(x in o.name.lower() for x in ['lagoon and lower river','upper river'])
 stair=' step' in o.name or (' landing' in o.name and ' entry landing' not in o.name and ' exit landing' not in o.name)
 prefix='Decor' if decorative or stair else 'Solid'
 ev=o.evaluated_get(dg);me=ev.to_mesh();world=ev.matrix_world
 mirrored=world.to_3x3().determinant()<0
 authored=bool(o.get('world_hub_collection'))
 verts=[world@v.co for v in me.vertices]
 colors=me.color_attributes.get('RoadWearColor') if isterrain else None
 # Keep terrain pieces spatially culled, and batch buildings by parcel center.
 center=world@Vector(tuple(sum(c[i] for c in o.bound_box)/8 for i in range(3)))
 for poly in me.polygons:
  c=world@poly.center if isterrain else center
  key=('Sailboat' if o.get('sailing_boat') else prefix,math.floor(c.x/40),math.floor(c.y/40),isterrain)
  if key not in groups:groups[key]={'v':[],'f':[],'m':[],'slots':[],'colors':[]}
  g=groups[key];start=len(g['v']);indices=list(poly.vertices)[::-1] if mirrored else poly.vertices;g['v'].extend(verts[i] for i in indices);g['f'].append(tuple(range(start,start+len(poly.vertices))))
  src=me.materials[poly.material_index] if len(me.materials)>poly.material_index else None
  mat=material(src,isterrain,authored)
  if mat not in g['slots']:g['slots'].append(mat)
  g['m'].append(g['slots'].index(mat))
  if isterrain:g['colors'].extend(tuple(colors.data[i].color) for i in indices)
 ev.to_mesh_clear()
print('EXPORT_GROUPS',len(groups),flush=True)
# Remove original scene objects after extracting data; never save over the source.
bpy.data.batch_remove(ids=list(s.objects))
print("SOURCE_OBJECTS_CLEARED",flush=True)
for key,g in groups.items():
 name='%s_%d_%d%s'%(key[0],key[1],key[2],'_terrain' if key[3] else '')
 me=bpy.data.meshes.new(name);me.from_pydata(g['v'],[],g['f']);me.update();o=bpy.data.objects.new(name,me);s.collection.objects.link(o)
 for m in g['slots']:me.materials.append(m)
 for p,idx in zip(me.polygons,g['m']):p.material_index=idx
 if key[3]:
  a=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
  for d,col in zip(a.data,g['colors']):d.color=col
# Invisible smooth collision ramps replace riser collision, allowing existing Rook controller to climb.
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def warp(x,y):
 a=smooth(min(x+200,200-x,y+180,220-y)/28)*math.exp(-((y+45)/90)**2)
 return (x+a*(3.7*math.sin(y/19)+1.8*math.sin((x+y)/14)),y+a*(3*math.sin(x/23)+1.4*math.cos((x-y)/13)))
manifest=json.loads((R/'art/HubCityMaster/terrain_pass_manifest.json').read_text());rv=[];rf=[]
for route in manifest['routes']:
 for seg in route['segments']:
  if seg['kind']!='stairs':continue
  a,b=Vector(seg['a']),Vector(seg['b']);d=b-a;l=math.hypot(d.x,d.y);n=Vector((-d.y/l,d.x/l,0))*route['width_m']/2
  count=max(1,math.ceil(l/2))
  for k in range(count):
   p=a+d*k/count;q=a+d*(k+1)/count;start=len(rv)
   for v in [p-n,q-n,q+n,p+n]:rv.append((*warp(v.x,v.y),v.z+.015))
   rf.append(tuple(start+i for i in range(4)))
me=bpy.data.meshes.new('RampCollision');me.from_pydata(rv,[],rf);me.update();o=bpy.data.objects.new('RampCollision',me);s.collection.objects.link(o)
bpy.ops.export_scene.gltf(filepath=str(EXPORT/'hub_city.glb'),export_format='GLB',export_animations=False,export_cameras=False,export_lights=False,export_yup=True)
(OUT/'lights.json').write_text(json.dumps(lamps))
(OUT/'export_report.json').write_text(json.dumps({'chunks':len(groups),'ramp_quads':len(rf),'point_lights':len(lamps),'source':'Hub_City_Developed.blend'},indent=2))
print('HUB_CITY_EXPORTED',flush=True)
