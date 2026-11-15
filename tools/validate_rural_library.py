import bpy,json,math
from pathlib import Path
R=Path(__file__).resolve().parents[1];out=R/'art/RuralLibrary'
bpy.ops.wm.open_mainfile(filepath=str(out/'Rural_Component_Library.blend'))
catalog=json.loads((out/'component_inventory.json').read_text());errors=[];meshes=[]
for rec in catalog:
 c=bpy.data.collections.get(rec['collection']);assert c
 for o in c.objects:
  assert o.type=='MESH' and o.library is None
  meshes.append(o)
  if any(not math.isfinite(a) for v in o.data.vertices for a in v.co):errors.append(o.name+' nonfinite vertex')
  if any(p.area<1e-10 for p in o.data.polygons):errors.append(o.name+' zero area face')
bpy.ops.object.select_all(action='DESELECT')
for o in meshes:o.select_set(True)
bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.mode_set(mode='EDIT');assert all(o.mode=='EDIT' for o in meshes);bpy.ops.object.mode_set(mode='OBJECT')
report={'catalog_assets':len(catalog),'editable_meshes_verified':len(meshes),'errors':errors}
(out/'validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report));assert not errors,errors
