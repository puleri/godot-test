import bpy, json, math
from pathlib import Path
R=Path(__file__).resolve().parents[1];out=R/'art/HubCityMaster'
bpy.ops.wm.open_mainfile(filepath=str(out/'Hub_City_Master_Blockout.blend'))
m=json.loads((out/'layout_manifest.json').read_text());errors=[]
assert len(bpy.data.scenes)==1,'Master must have one scene'
scene=bpy.context.scene
assert len(scene.collection.children)==10
assert not bpy.data.libraries,'Unexpected external library dependency'
terrain=bpy.data.objects.get('City terrain — 400 x 400 meters')
assert terrain and len(terrain.data.vertices)==m['terrain_vertices']
for ob in scene.objects:
 if ob.type=='MESH':
  if any(not math.isfinite(v) for vert in ob.data.vertices for v in vert.co):errors.append(ob.name+': invalid vertex')
  if any(p.area<1e-10 for p in ob.data.polygons):errors.append(ob.name+': degenerate face')
 if ob.instance_type=='COLLECTION' and ob.instance_collection is None:errors.append(ob.name+': missing instance source')
if any(o.instance_type=='COLLECTION' for o in scene.objects):errors.append('Unrealized collection instances remain')
if any(o.data.users>1 for o in scene.objects if o.type=='MESH'):errors.append('Shared scene mesh data remains')
# Every primary district hub is reachable from Civic via the planned circulation graph.
adjacency={name:set() for name in m['hubs']}
for r in m['routes']:
 if r['from'] in adjacency and r['to'] in adjacency:
  adjacency[r['from']].add(r['to']);adjacency[r['to']].add(r['from'])
seen=set();todo=['Civic']
while todo:
 name=todo.pop()
 if name in seen:continue
 seen.add(name);todo.extend(adjacency[name]-seen)
if set(adjacency)-seen:errors.append('Unconnected hubs: '+str(set(adjacency)-seen))
assert m['upper_river_water_z']>m['lagoon_water_z']
report={'single_scene':True,'terrain_vertices':len(terrain.data.vertices),'building_masses':m['building_mass_count'],'embedded_component_instances':len(m['component_placements']),'major_hubs_connected':len(seen),'major_hubs_total':len(adjacency),'camera_count':sum(o.type=='CAMERA' for o in scene.objects),'external_libraries':len(bpy.data.libraries),'errors':errors,'limits':'Graph connectivity is a layout check, not a collision, headroom or gameplay traversal certification.'}
(out/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print('CITY_MASTER_VALIDATION',json.dumps(report));assert not errors,errors
