import bpy
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
OUT=Path(__file__).resolve().parents[1]/'art/HubCityMaster'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Hub_City_World_Farms.blend'))
s=bpy.context.scene;t=bpy.data.objects['Continuous surrounding landscape'];world=t.matrix_world.copy()
bvh=BVHTree.FromPolygons([v.co for v in t.data.vertices],[tuple(p.vertices) for p in t.data.polygons]);z=bvh.ray_cast(Vector((-560,-140,4000)),Vector((0,0,-1)),8000)[0].z
for name,pos,target in [('09 Farmstead inspection',(-460,-285,z+115),(-555,-160,z+1)),('10 City and farming outskirts',(-1150,-1250,1050),(-80,100,25))]:
 o=bpy.data.objects[name];rotation=(Vector(target)-Vector(pos)).to_track_quat('-Z','Y').to_matrix().to_4x4();rotation.translation=Vector(pos);o.matrix_world=world@rotation
s.camera=bpy.data.objects['10 City and farming outskirts'];bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hub_City_World_Farms.blend'))
s.render.filepath=str(OUT/'city_farming_outskirts.png');bpy.ops.render.render(write_still=True)
s.camera=bpy.data.objects['09 Farmstead inspection'];s.render.filepath=str(OUT/'farmstead_detail.png');bpy.ops.render.render(write_still=True)
