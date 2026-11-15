"""Place rural kit farmsteads in the editable world scene."""
import bpy,math,json,sys,random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[1];OUT=R/'art/HubCityMaster';KIT=R/'art/RuralLibrary'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Hub_City_World.blend'));sc=bpy.context.scene;random.seed(42)
original=set(o.name for o in sc.objects)
root=bpy.data.collections.new('17 FARMLANDS — six editable farmsteads');sc.collection.children.link(root)
inventory=json.loads((KIT/'component_inventory.json').read_text());names=[r['name'] for r in inventory]
with bpy.data.libraries.load(str(KIT/'Rural_Component_Library.blend'),link=False) as (src,dst):dst.collections=names[:]
assets={name:c for name,c in zip(names,dst.collections)}
for c in assets.values():c.use_fake_user=True
terrain=bpy.data.objects['Continuous surrounding landscape']
world_transform=terrain.matrix_world.copy();world_inverse=world_transform.inverted()
def bvh():return BVHTree.FromPolygons([v.co for v in terrain.data.vertices],[tuple(p.vertices) for p in terrain.data.polygons])
surface=bvh()
def ground(x,y):
 hit=surface.ray_cast(Vector((x,y,4000)),Vector((0,0,-1)),8000)[0]
 if hit is None:raise RuntimeError(f'No terrain at {x},{y}')
 return hit.z
sites=[('West orchard farm',-560,-140),('Old grain farm',-700,100),('North pasture farm',-550,380),('Eastern market garden',410,400),('Hill orchard farm',660,220),('Upper valley farm',780,540)]
levels={(x,y):ground(x,y) for _,x,y in sites}
# Flatten only farmyard footprints, with a broad soft transition into surrounding land.
for v in terrain.data.vertices:
 x,y,z=v.co
 for _,cx,cy in sites:
  d=math.sqrt(((x-cx)/40)**2+((y-cy)/33)**2)
  if d<2:
   t=max(0,min(1,2-d));t=t*t*(3-2*t);v.co.z=v.co.z*(1-t)+levels[(cx,cy)]*t
terrain.data.update();surface=bvh()
soil=bpy.data.materials.get('RuralEarth');lane=bpy.data.materials.get('World road');placements=[]
def mesh(name,vs,fs,col,mat):
 d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.materials.append(mat);d.update();o=bpy.data.objects.new(name,d);col.objects.link(o);return o

def place(name,x,y,col,yaw=0,conform=False):
 o=bpy.data.objects.new(name,None);col.objects.link(o);o.instance_type='COLLECTION';o.instance_collection=assets[name];o.location=(x,y,ground(x,y)+.03);o.rotation_euler.z=yaw
 if conform:
  dx=ground(x+1,y)-ground(x-1,y);dy=ground(x,y+1)-ground(x,y-1);normal=Vector((-dx/2,-dy/2,1)).normalized();o.rotation_mode='QUATERNION';o.rotation_quaternion=normal.to_track_quat('Z','Y')
 placements.append({'component':name,'position':list(o.location)});return o

def patch(name,cx,cy,w,d,col,material):
 nx=math.ceil(w);ny=math.ceil(d);v=[];f=[]
 for j in range(ny+1):
  for i in range(nx+1):
   x=cx-w/2+w*i/nx;y=cy-d/2+d*j/ny;v.append((x,y,ground(x,y)+.12))
 for j in range(ny):
  for i in range(nx):a=j*(nx+1)+i;f.append((a,a+1,a+nx+2,a+nx+1))
 return mesh(name,v,f,col,material)
def road(name,points,col):
 v=[]
 for i,(x,y) in enumerate(points):
  a=Vector(points[max(0,i-1)]);b=Vector(points[min(len(points)-1,i+1)]);d=(b-a).normalized();n=Vector((-d.y,d.x))*2
  for s in [-1,1]:xx=x+s*n.x;yy=y+s*n.y;v.append((xx,yy,ground(xx,yy)+.20))
 return mesh(name,v,[(i,i+1,i+3,i+2) for i in range(0,len(v)-2,2)],col,lane)
for index,(name,cx,cy) in enumerate(sites):
 col=bpy.data.collections.new(name);root.children.link(col)
 patch('Farmyard',cx,cy,38,29,col,lane)
 place('A Low farmhouse' if index%2==0 else 'B Tall farmhouse',cx-11,cy,col)
 place('C Timber barn',cx+12,cy+5,col,math.pi/2)
 place('D Farm shed',cx-9,cy+16,col)
 place('Farm well',cx-1,cy-7,col);place('Farm cart',cx+10,cy-8,col,.3);place('Water trough',cx+18,cy-5,col)
 for j in range(4):place('Hay bale',cx+7+j*1.5,cy+15,col)
 # Contoured grain and kitchen-garden parcels.
 patch('Grain field soil',cx,cy-48,35,32,col,soil)
 for row in range(7):
  for column in range(7):place('Wheat bed 4m',cx-12+column*4.2,cy-60+row*4.2,col,conform=False)
 patch('Vegetable field soil',cx+47,cy-33,19,25,col,soil)
 for row in range(5):
  for column in range(4):place('Vegetable bed 4m',cx+40.5+column*4.2,cy-41.5+row*4.2,col,conform=False)
 for row in range(3):
  for column in range(4):place('Orchard fruit tree',cx+35+column*5,cy+row*6,col)
 # Pasture fence; leave an access gate on the south edge.
 for side in [-1,1]:
  for k in range(8):
   if side==-1 and k==4:continue
   place('Fence bay 4m',cx-64+k*4,cy+side*12,col)
  for k in range(6):place('Fence bay 4m',cx+(-66 if side<0 else -34),cy-10+k*4,col,math.pi/2)
 place('Farm gate 4m',cx-48,cy-12,col)
 # Connect each yard toward an existing borough or estate road.
 target=(-395,max(-130,min(280,cy))) if cx<0 else (min(cx,700),70+80*math.sin(((min(cx,700)-205)/4)/55))
 points=[]
 start=(cx+18,cy-12)
 for k in range(151):
  t=k/150;x=start[0]*(1-t)+target[0]*t;y=start[1]*(1-t)+target[1]*t+10*math.sin(t*math.pi);points.append((x,y))
 road('Farm access lane',points,col)
# Clear existing backdrop pines from the cultivated parcels; retain them in a hidden collection.
cleared=bpy.data.collections.new('18 FARM CLEARING — retained displaced trees');sc.collection.children.link(cleared);cleared.hide_render=True;cleared.hide_viewport=True
forest=bpy.data.collections.get('14 WORLD — woodland and orchards')
if forest:
 bpy.context.view_layer.update()
 for o in list(forest.objects):
  if o.type!='MESH':continue
  corners=[world_inverse@o.matrix_world@Vector(c) for c in o.bound_box];x=sum(p.x for p in corners)/8;y=sum(p.y for p in corners)/8
  if any(cx-70<x<cx+62 and cy-68<y<cy+30 for _,cx,cy in sites):
   cleared.objects.link(o);forest.objects.unlink(o)
# Match the saved world's scale and offset for all new farm geometry.
for o in list(root.all_objects):o.matrix_world=world_transform@o.matrix_world
bpy.context.view_layer.update()
# Keep terrain from poking through fields: crop beds follow each local surface tangent.
sys.path.insert(0,str(R/'tools'));from realize_hub_city_components import make_editable
report=make_editable(OUT/'rural_placement_validation.json')
# Bend crop mesh vertices to the terrain; preserve each plant's height above its bed.
for o in root.all_objects:
 if o.type!='MESH' or not (o.name.startswith('Wheat bed 4m') or o.name.startswith('Vegetable bed 4m')):continue
 logical=world_inverse@o.matrix_world;inv=o.matrix_world.inverted()
 for v in o.data.vertices:
  p=logical@v.co;p.z=ground(p.x,p.y)+v.co.z+.18;v.co=inv@world_transform@p
 o.data.update()
assert all(n in sc.objects for n in original)
report.update({'farmsteads':len(sites),'rural_component_placements':len(placements),'original_objects_preserved':len(original),'inherited_world_scale':list(terrain.matrix_world.to_scale()),'farm_locations':[{'name':n,'x':x,'y':y} for n,x,y in sites]})
(OUT/'rural_placement_validation.json').write_text(json.dumps(report,indent=2)+'\n');(OUT/'rural_placements.json').write_text(json.dumps(placements,indent=2)+'\n')
def camera(name,pos,target,lens):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);root.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=50000;bpy.context.view_layer.update();o.matrix_world=world_transform@o.matrix_world;return o
cx,cy=sites[0][1:];z=ground(cx,cy)
close=camera('09 Farmstead inspection',(cx+100,cy-145,z+115),(cx+5,cy-20,z+1),48)
wide=camera('10 City and farming outskirts',(-1150,-1250,1050),(-80,100,25),42)
sc.camera=wide;sc.cycles.samples=20;sc.render.resolution_x=1800;sc.render.resolution_y=1200
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hub_City_World_Farms.blend'))
print('FARMS_SAVED',json.dumps(report),flush=True)
sc.render.filepath=str(OUT/'city_farming_outskirts.png');bpy.ops.render.render(write_still=True)
sc.camera=close;sc.render.filepath=str(OUT/'farmstead_detail.png');bpy.ops.render.render(write_still=True)
print('FARMS_RENDERED',flush=True)
