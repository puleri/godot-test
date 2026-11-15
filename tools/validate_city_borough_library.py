import bpy, json, math
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'art/CityBoroughLibrary'
bpy.ops.wm.open_mainfile(filepath=str(root/'City_Boroughs_and_Landmarks.blend'))
inv=json.loads((root/'component_inventory.json').read_text())
errors=[]; faces=0; vertices=0
for r in inv['components']:
 c=bpy.data.collections.get(r['name'])
 if c is None or c.asset_data is None: errors.append(r['name']+': missing asset collection'); continue
 objects=[o for o in c.objects if o.type=='MESH']
 if len(objects)!=1: errors.append(r['name']+': source mesh count')
 for o in objects:
  faces+=len(o.data.polygons); vertices+=len(o.data.vertices)
  if not o.data.vertices or not o.data.polygons: errors.append(r['name']+': empty mesh')
  if any(p.area<1e-10 for p in o.data.polygons): errors.append(r['name']+': zero area face')
  if any(not math.isfinite(v) for vert in o.data.vertices for v in vert.co): errors.append(r['name']+': nonfinite vertex')
  if not o.modifiers or o.modifiers[0].type!='BEVEL': errors.append(r['name']+': missing editable bevel')
  if (o.location-c.instance_offset).length>1e-5: errors.append(r['name']+': instance pivot mismatch')
assembly_objects=0
for entry in inv['assemblies']:
 bpy.context.window.scene=bpy.data.scenes[entry['name']]
 bpy.context.view_layer.update()
 c=bpy.data.collections.get(entry['name'])
 if c is None or not c.asset_data: errors.append(entry['name']+': missing assembly'); continue
 if len(c.objects)!=entry['objects']: errors.append(entry['name']+': object count mismatch')
 signatures=set()
 for o in c.objects:
  if o.type!='MESH': continue
  assembly_objects+=1
  signature=(o.data.name,tuple(round(v,6) for row in o.matrix_local for v in row))
  if signature in signatures: errors.append(entry['name']+': duplicate coincident mesh '+o.name)
  signatures.add(signature)
rotor=bpy.data.objects.get('ROTATE THIS — waterwheel axle X')
if rotor is None or len(rotor.children)<50: errors.append('Missing editable wheel rotor hierarchy')
if bpy.data.libraries: errors.append('External library dependency')
assert len(inv['components'])==inv['count']==141
result={'assets':inv['count'],'editable_source_meshes':inv['count'],'mesh_vertices':vertices,'mesh_faces':faces,'assemblies':len(inv['assemblies']),'assembly_mesh_objects':assembly_objects,'scenes':len(bpy.data.scenes),'errors':errors}
(root/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
print('BOROUGH_LIBRARY_VALIDATION',json.dumps(result))
assert not errors,errors
