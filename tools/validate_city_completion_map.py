import bpy,json,math
from pathlib import Path
from collections import Counter
R=Path(__file__).resolve().parents[1];out=R/'art/HubCityMaster'
bpy.ops.wm.open_mainfile(filepath=str(out/'Hub_City_Developed.blend'))
new=[o for o in bpy.context.scene.objects if o.get('completion_asset')]
families=Counter(o['completion_asset'].split(' variant')[0] for o in new if ' variant' in o['completion_asset'])
assert len(families)==8,families
assert all(o.type=='MESH' and o.data.users==1 for o in new)
assert all(math.isfinite(x) for o in new for x in o.location)
backup=bpy.data.collections['99 COMPLETION — original blockouts (hidden)'];assert backup.hide_render and backup.hide_viewport
assert not any(o.visible_get() for o in backup.all_objects)
# Verify Edit Mode on one deployed object from each family, plus infrastructure.
bpy.ops.object.select_all(action='DESELECT');selected=[]
for family in families:
 o=next(o for o in new if o['completion_asset'].startswith(family+' variant'));o.select_set(True);selected.append(o)
for name in ['Long span arch 10m','Tall reinforced wall 6m','Waterline masonry face 4m','Wheat strip 8m','Lagoon sailing boat']:
 o=next(o for o in new if o['completion_asset']==name);o.select_set(True);selected.append(o)
bpy.context.view_layer.objects.active=selected[0];bpy.ops.object.mode_set(mode='EDIT');assert all(o.mode=='EDIT' for o in selected);bpy.ops.object.mode_set(mode='OBJECT')
result={'deployed_families':dict(families),'new_meshes':len(new),'independent_mesh_data':True,'edit_mode_verified_samples':len(selected),'original_blockouts_hidden':True}
(out/'city_completion_validation.json').write_text(json.dumps(result,indent=2));print('CITY_COMPLETION_MAP_PASS',result,flush=True)
# Inspect field density independently of the city overview.
s=bpy.context.scene;d=bpy.data.cameras.new('Completed farmland review');o=bpy.data.objects.new(d.name,d);s.collection.objects.link(o)
from mathutils import Vector
o.location=(-405,-345,225);o.rotation_euler=(Vector((-555,-185,40))-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=220;s.camera=o;s.render.resolution_x=1400;s.render.resolution_y=1000;s.cycles.samples=12;s.render.filepath=str(out/'developed_farmland.png');bpy.ops.render.render(write_still=True)
