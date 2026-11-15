import bpy,json,hashlib,array,math
from pathlib import Path
R=Path(__file__).resolve().parents[1]/'art/HubCityMaster'
def snapshot():
 result={}
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  v=array.array('f',[0])*(len(o.data.vertices)*3);o.data.vertices.foreach_get('co',v)
  result[o.name]=(len(o.data.polygons),hashlib.sha256(v.tobytes()).hexdigest(),tuple(v for row in o.matrix_world for v in row))
 return result
bpy.ops.wm.open_mainfile(filepath=str(R/'Hub_City_Master_Blockout.blend'));before=snapshot()
bpy.ops.wm.open_mainfile(filepath=str(R/'Hub_City_World.blend'));after=snapshot()
assert all(after.get(k)==v for k,v in before.items()),'Source mesh or placement changed'
assert not any(o.instance_type=='COLLECTION' for o in bpy.context.scene.objects)
assert not any(o.data.users>1 for o in bpy.context.scene.objects if o.type=='MESH')
terrain=bpy.data.objects['City terrain — 400 x 400 meters'];core={(round(v.co.x),round(v.co.y)):v.co.z for v in terrain.data.vertices}
seam=[]
for v in bpy.data.objects['Continuous surrounding landscape'].data.vertices:
 x,y,z=v.co
 if ((x in (-200,200) and -180<=y<=220) or (y in (-180,220) and -200<=x<=200)):
  seam.append(abs(z-core[(round(x),round(y))]))
assert len(seam)>=1600 and max(seam)<.0001
p=R/'world_backdrop_validation.json';report=json.loads(p.read_text());report.update({'saved_file_reopened':True,'source_meshes_unchanged':len(before),'boundary_vertices_checked':len(seam),'max_boundary_gap_m':max(seam)});p.write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
