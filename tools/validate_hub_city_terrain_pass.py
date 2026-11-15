"""Check scale, hydrology and actual mesh clearance along the redesigned spine."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[1]/'art/HubCityMaster'
bpy.ops.wm.open_mainfile(filepath=str(R/'Hub_City_Terrain_Study.blend'));sc=bpy.context.scene;bpy.context.view_layer.update()
m=json.loads((R/'terrain_pass_manifest.json').read_text());errors=[]
assert sc.unit_settings.scale_length==1
core=bpy.data.objects['City terrain — 400 x 400 meters'];assert all(abs(v-1)<1e-5 for v in core.matrix_world.to_scale())
for name,z in [('Lagoon and lower river',2),('Upper river',7)]:
 o=bpy.data.objects[name];assert max(abs((o.matrix_world@v.co).z-z) for v in o.data.vertices)<.001
assert not any(o.instance_type=='COLLECTION' for o in sc.objects)
for c in [bpy.data.collections['19 TERRAIN PASS — rebuilt routes and stairs'],bpy.data.collections['20 TERRAIN PASS — foundations and retaining walls']]:
 for o in c.objects:
  if o.type=='MESH':
   if any(not math.isfinite(v) for vert in o.data.vertices for v in vert.co):errors.append(o.name+' invalid vertex')
   if any(p.area<1e-10 for p in o.data.polygons):errors.append(o.name+' degenerate face')
risers=[];treads=[]
for r in m['routes']:
 for segment in r['segments']:
  if segment['kind']=='stairs':risers.append(segment['riser_m']);treads.append(segment['tread_m'])
assert max(risers)<=.17 and min(treads)>=.28
# Test the saved meshes, not only abstract route graph connections.
def combined(objects):
 vs=[];fs=[];owners=[]
 for o in objects:
  if o.type!='MESH' or not o.visible_get():continue
  start=len(vs);vs.extend(o.matrix_world@v.co for v in o.data.vertices)
  for p in o.data.polygons:fs.append(tuple(start+i for i in p.vertices));owners.append(o.name)
 return BVHTree.FromPolygons(vs,fs),owners
floors,_=combined(bpy.data.collections['19 TERRAIN PASS — rebuilt routes and stairs'].all_objects)
obstacles,names=combined([o for cname in ['05 LANDMARKS — existing component assemblies','06 DISTRICTS — linked building masses','20 TERRAIN PASS — foundations and retaining walls','19 TERRAIN PASS — rebuilt routes and stairs','01 TERRAIN — continuous editable landform'] for o in bpy.data.collections[cname].all_objects])
missing=[];blocked=[]
for sample in m['walk_samples']:
 p=Vector(sample['position']);hit=floors.ray_cast(p+Vector((0,0,.5)),Vector((0,0,-1)),1.5)[0]
 if hit is None:missing.append(sample);continue
 obstruction=obstacles.ray_cast(hit+Vector((0,0,.12)),Vector((0,0,1)),1.78)
 if obstruction[0] is not None:blocked.append({'route':sample['route'],'position':list(hit),'object':names[obstruction[2]]})
# Graph connectivity among all 12 primary districts.
adj={n:set() for n in m['hubs']}
for r in m['routes']:
 if r['from'] in adj and r['to'] in adj:adj[r['from']].add(r['to']);adj[r['to']].add(r['from'])
seen=set();todo=['Market']
while todo:
 n=todo.pop()
 if n not in seen:seen.add(n);todo.extend(adj[n]-seen)
assert len(seen)==len(adj)
report={'workspaces':[w.name for w in bpy.data.workspaces],'units':'metres','scale_normalized':True,'water_levels_preserved':True,'connected_hubs':len(seen),'maximum_stair_riser_m':max(risers),'minimum_stair_tread_m':min(treads),'spine_surface_samples':len(m['walk_samples']),'missing_floor_samples':len(missing),'blocked_headroom_samples':len(blocked),'blocked_examples':blocked,'missing_examples':missing[:10],'geometry_errors':errors,'limits':'Geometry sampling validates a 1.3 m wide corridor and standing headroom; no Godot character-controller, collision or navigation test has been run.'}
(R/'terrain_pass_validation.json').write_text(json.dumps(report,indent=2)+'\n');print('TERRAIN_VALIDATION',json.dumps(report),flush=True)
assert not errors,errors
assert not missing,missing[:3]
assert not blocked,blocked[:3]
