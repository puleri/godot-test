import bpy,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[1]/'art/HubCityMaster'
bpy.ops.wm.open_mainfile(filepath=str(R/'Hub_City_World_Farms.blend'))
root=bpy.data.collections['17 FARMLANDS — six editable farmsteads'];terrain=bpy.data.objects['Continuous surrounding landscape'];inv=terrain.matrix_world.inverted()
surface=BVHTree.FromPolygons([v.co for v in terrain.data.vertices],[tuple(p.vertices) for p in terrain.data.polygons])
errors=[];checked=0;crop_count=0;min_clearance=100
for o in root.all_objects:
 if o.type!='MESH':continue
 checked+=1
 if o.data.users!=1:errors.append(o.name+' shared mesh')
 if any(not math.isfinite(a) for v in o.data.vertices for a in v.co):errors.append(o.name+' invalid coordinates')
 if o.name.startswith('Wheat bed 4m') or o.name.startswith('Vegetable bed 4m'):
  crop_count+=1
  for v in list(o.data.vertices)[:8]:
   p=inv@o.matrix_world@v.co;hit=surface.ray_cast(Vector((p.x,p.y,4000)),Vector((0,0,-1)),8000)[0];clear=p.z-hit.z;min_clearance=min(min_clearance,clear)
   if clear<.15:errors.append(o.name+' bed intersects terrain')
assert not errors,errors
assert crop_count==414,crop_count
p=R/'rural_placement_validation.json';report=json.loads(p.read_text());report.update({'saved_file_reopened':True,'rural_meshes_checked':checked,'conformed_crop_beds_checked':crop_count,'minimum_bed_clearance_local_m':min_clearance,'errors':errors});p.write_text(json.dumps(report,indent=2)+'\n');print('RURAL_FINAL_VALIDATION',json.dumps(report))
