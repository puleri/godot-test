"""Check editable library geometry and catalog assignments."""
import bpy,json,math,uuid
from pathlib import Path
R=Path(__file__).resolve().parents[1];out=R/'art/CityCompletionLibrary'
bpy.ops.wm.open_mainfile(filepath=str(out/'City_Completion_Library.blend'))
j=json.loads((out/'component_inventory.json').read_text());assert len(j['components'])==80
ids={r['kit']:str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/city-completion/'+r['kit'])) for r in j['components']}
(out/'blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{u}:City Completion/{k}:{k}' for k,u in ids.items())+'\n')
bpy.ops.object.select_all(action='DESELECT');checked=[]
for rec in j['components']:
 c=bpy.data.collections[rec['collection']];o=next(o for o in c.objects if o.type=='MESH')
 assert o.data.vertices and o.data.polygons
 assert max(o.dimensions)<30,(rec['name'],list(o.dimensions))
 assert all(math.isfinite(x) for v in o.data.vertices for x in v.co)
 assert not o.data.validate(verbose=True),rec['name']
 o.select_set(True);checked.append(o);o.asset_data.catalog_id=ids[rec['kit']];c.asset_data.catalog_id=ids[rec['kit']]
bpy.context.view_layer.objects.active=checked[0];bpy.ops.object.mode_set(mode='EDIT');assert all(o.mode=='EDIT' for o in checked);bpy.ops.object.mode_set(mode='OBJECT');bpy.ops.object.select_all(action='DESELECT')
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(out/'City_Completion_Library.blend'))
(out/'validation.json').write_text(json.dumps({'assets':len(checked),'edit_mode_verified':True,'finite_coordinates':True,'valid_mesh_topology':True,'maximum_asset_extent_m':max(max(o.dimensions) for o in checked)},indent=2))
print('CITY_COMPLETION_LIBRARY_PASS',len(checked),flush=True)
