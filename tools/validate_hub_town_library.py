import bpy, json, math
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'art/HubTownLibrary'
bpy.ops.wm.open_mainfile(filepath=str(root/'HubTown_Component_Library.blend'))
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
# Source file survived reopening, and all display instances point to source assets.
example=bpy.data.scenes['01 Assembly Example']
instances=[o for o in example.objects if o.instance_type=='COLLECTION']
assert all(o.instance_collection.name in {r['name'] for r in inv['components']} for o in instances)
assert len(inv['components'])==204
result={'assets':204,'editable_meshes':204,'mesh_vertices':vertices,'mesh_faces':faces,'assembly_instances':len(instances),'scenes':len(bpy.data.scenes),'errors':errors}
(root/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
print('HUB_LIBRARY_VALIDATION',json.dumps(result))
assert not errors,errors
