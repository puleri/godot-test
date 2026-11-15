"""Populate the terrain study with editable completion assets; preserve the source."""
import bpy, math, json, random
from pathlib import Path
from collections import Counter
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[1]; OUT=R/'art/HubCityMaster';random.seed(71)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Hub_City_Foliage_Study.blend'));s=bpy.context.scene
inventory=json.loads((R/'art/CityCompletionLibrary/component_inventory.json').read_text())
names=[a['collection'] for a in inventory['components']]
with bpy.data.libraries.load(str(R/'art/CityCompletionLibrary/City_Completion_Library.blend'),link=False) as (src,dst):dst.collections=names[:]
assets={r['name']:c for r,c in zip(inventory['components'],dst.collections)}
def col(name):
 c=bpy.data.collections.new(name);s.collection.children.link(c);return c
buildings=col('24 COMPLETION — detailed buildings');waterfront=col('25 COMPLETION — bridges quays and shore');farmcol=col('26 COMPLETION — cultivated fields');boats=col('27 COMPLETION — boats and dock');backup=col('99 COMPLETION — original blockouts (hidden)');backup.hide_render=True;backup.hide_viewport=True
counts=Counter(); replacements=[]
def source_matrix(o):return source_matrix(o.parent)@o.matrix_parent_inverse@o.matrix_basis if o.parent else o.matrix_basis.copy()
# Cached normalized geometry; every placement receives independent editable mesh data.
cache={}
for name,c in assets.items():
 src=next(o for o in c.all_objects if o.type=='MESH');me=src.data.copy();me.transform(Matrix.Translation(-c.instance_offset)@source_matrix(src));cache[name]=me

def place(name,p,collection=waterfront,yaw=0,scale=(1,1,1)):
 o=bpy.data.objects.new(name,cache[name].copy());collection.objects.link(o);o.location=p;o.rotation_euler.z=yaw;o.scale=scale;o['completion_asset']=name;o['editable_source']='City_Completion_Library.blend';counts[name]+=1;return o

def bounds(objects):
 ps=[o.matrix_world@Vector(v) for o in objects if o.type=='MESH' for v in o.bound_box]
 return Vector([min(v[i] for v in ps) for i in range(3)]),Vector([max(v[i] for v in ps) for i in range(3)])
def stash(objects):
 for o in objects:
  for c in list(o.users_collection):c.objects.unlink(o)
  backup.objects.link(o)

dimension_cache={}
def dims(name):
 if name in dimension_cache:return dimension_cache[name]
 vs=cache[name].vertices;dimension_cache[name]=Vector([max(v.co[i] for v in vs)-min(v.co[i] for v in vs) for i in range(3)]);return dimension_cache[name]
# Keep the existing parcel footprint, ground level and road setbacks. Larger families
# are used only when the old parcel accommodates them at >= 90% horizontal scale.
core=bpy.data.collections['06 DISTRICTS — linked building masses']
outer=bpy.data.collections['13 WORLD — outer boroughs and estates']
roots=[o for o in core.all_objects if not o.parent]+[o for o in outer.all_objects if not o.parent and o.name.startswith('Outer borough house')]
for i,root in enumerate(roots):
 obs=[root]+list(root.children_recursive);lo,hi=bounds(obs);size=hi-lo;p=(lo+hi)/2;p.z=lo.z
 large=root.name.startswith('Outer borough house');v=i%4+1
 candidates=[]
 if large:
  candidates=[f'{k} variant {v:02}' for k in (['Villa','Apartment','Inn','Warehouse','Artisan'] if p.z>28 else ['Apartment','Warehouse','Inn','Artisan','Villa'])]
  # Rotate family priority to prevent blocks of identical structures.
  shift=(i//4)%len(candidates);candidates=candidates[shift:]+candidates[:shift]
 elif p.y<-90 and i%5==0:candidates=['Boathouse variant 01']
 elif i%3==0:candidates=[f'Artisan variant {1 if i%2 else 3:02}']
 candidates.append(f'Merchant variant {v:02}')
 chosen=candidates[-1];rot=0;factor=1
 for n in candidates:
  d=dims(n);f=min(size.x/d.x,size.y/d.y,1)
  if f>=.90:chosen=n;factor=f;break
 else:factor=max(.90,min(size.x/dims(chosen).x,size.y/dims(chosen).y,1))
 o=place(chosen,p,buildings,scale=(factor,factor,1));o['replaces']=root.name
 # Center the complete mesh bounds, including its awning, inside the previous plot.
 vs=cache[chosen].vertices;center=Vector([(min(v.co[j] for v in vs)+max(v.co[j] for v in vs))/2 for j in range(2)]+[0]);o.location-=Vector((center.x*factor,center.y*factor,0))
 stash(obs);replacements.append({'old':root.name,'asset':chosen,'position':list(o.location),'scale_xy':factor})
print('BUILDINGS_REPLACED',len(replacements),flush=True)
# Ground queries use actual edited world-space surfaces.
def tree(o):return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[list(p.vertices) for p in o.data.polygons],all_triangles=False)
terrain=tree(bpy.data.objects['City terrain — 400 x 400 meters'])
land=bpy.data.objects.get('Continuous surrounding landscape');outertree=tree(land) if land else terrain
def ground(x,y):
 for t in ([terrain,outertree] if -200<=x<=200 and -180<=y<=220 else [outertree,terrain]):
  hit=t.ray_cast(Vector((x,y,1000)),Vector((0,0,-1)))
  if hit[0] is not None:return hit[0].z
 return 0

def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def warp(x,y):
 a=smooth(min(x+200,200-x,y+180,220-y)/28)*math.exp(-((y+45)/90)**2)
 return x+a*(3.7*math.sin(y/19)+1.8*math.sin((x+y)/14)),y+a*(3*math.sin(x/23)+1.4*math.cos((x-y)/13))
manifest=json.loads((OUT/'terrain_pass_manifest.json').read_text());route_segments=[]
for route in manifest['routes']:
 for seg in route['segments']:
  a=Vector((*warp(*seg['a'][:2]),seg['a'][2]));b=Vector((*warp(*seg['b'][:2]),seg['b'][2]));route_segments.append((a,b,route['width_m']))
def roadclear(x,y,r=2):
 p=Vector((x,y,0))
 for a,b,w in route_segments:
  aa=Vector((a.x,a.y,0));d=Vector((b.x-a.x,b.y-a.y,0));t=max(0,min(1,(p-aa).dot(d)/max(d.length_squared,.001)))
  if (p-aa-d*t).length<w/2+r:return False
 return True
# Arch supports are below the existing decks and along their outside edges.
for route in manifest['routes']:
 isbridge=any(k in route['name'].lower() for k in ['bridge','crossing'])
 for seg in route['segments']:
  a=Vector(seg['a']);b=Vector(seg['b']);d=b-a;length=math.hypot(d.x,d.y)
  if not isbridge and not (route['name']=='Civic ridge promenade' and a.x<0<b.x):continue
  n=max(1,round(length/9));normal=Vector((-d.y/length,d.x/length,0))
  for k in range(n):
   p=a+d*(k+.5)/n;x,y=warp(p.x,p.y);water=7 if p.y>57 else 2
   if ground(x,y)>water+.2:continue
   base=water-.65;h=p.z-base-.22
   if h<1:continue
   for sign in [-1,1]:
    q=p+normal*sign*(route['width_m']/2-.48);xx,yy=warp(q.x,q.y)
    place('Long span arch 10m',(xx,yy,base),yaw=math.atan2(d.y,d.x),scale=(length/n/10,1,h/5))
# Replace old piers whose tops were coplanar with the road deck.
for o in list(bpy.data.collections['19 TERRAIN PASS — rebuilt routes and stairs'].objects):
 if o.name.startswith('Crossing masonry pier'):stash([o])
# Retaining faces below the switchbacks. Their upper edges follow each segment.
stone=cache['Tall reinforced wall 6m'].materials[0]
for route in manifest['routes']:
 if route['name'] not in ['Civic ridge promenade','Eastern hillside descent','Western contour avenue']:continue
 for seg in route['segments']:
  a,b=Vector(seg['a']),Vector(seg['b']);d=b-a;l=math.hypot(d.x,d.y);normal=Vector((-d.y/l,d.x/l,0));n=max(1,math.ceil(l/4))
  for side in [-1,1]:
   for k in range(n):
    p=a+d*k/n+normal*side*(route['width_m']/2+.3);q=a+d*(k+1)/n+normal*side*(route['width_m']/2+.3)
    pp=Vector((*warp(p.x,p.y),p.z-.12));qq=Vector((*warp(q.x,q.y),q.z-.12));mid=(pp+qq)/2
    probe=mid+normal*side*2;g=ground(probe.x,probe.y);base=min(g-.5,mid.z-1)
    if mid.z-g<.65:continue
    h=mid.z-base
    ob=place('Tall reinforced wall 6m',(mid.x,mid.y,base),yaw=math.atan2(qq.y-pp.y,qq.x-pp.x)+(math.pi if side>0 else 0),scale=((qq-pp).xy.length/4,1,h/6))
    # Shear top courses to follow ascent while keeping foot at its sampled level.
    rise=(qq.z-pp.z)*(-1 if side>0 else 1)
    for v in ob.data.vertices:v.co.z+=(v.co.x/4)*rise/(h/6)*min(1,max(0,v.co.z/6))
    if k%4==0:place('Retaining drainage outlet',(mid.x,mid.y,base+.6),yaw=ob.rotation_euler.z)
# Masonry veneers sit just outside existing quay faces, avoiding coplanar surfaces.
quays=bpy.data.collections['04 QUAYS — island edges'];quay_points=[]
for old in quays.objects:
 if old.type!='MESH':continue
 for poly in old.data.polygons:
  pts=[old.matrix_world@old.data.vertices[i].co for i in poly.vertices]
  if max(p.z for p in pts)-min(p.z for p in pts)<1:continue
  low=sorted(pts,key=lambda p:p.z)[:2];a,b=low;mid=(a+b)/2;length=(b-a).xy.length
  if length<.1:continue
  center=sum((old.matrix_world@v.co for v in old.data.vertices),Vector())/len(old.data.vertices);out=Vector((mid.x-center.x,mid.y-center.y,0)).normalized();mid+=out*.30
  top=max(p.z for p in pts);height=top-mid.z-.12
  place('Waterline masonry face 4m',mid,yaw=math.atan2(b.y-a.y,b.x-a.x),scale=(length/4,1,height/3));quay_points.append(mid)
# Rocky shoreline sampled where dry ground meets the actual water height, away from quays/routes.
for y in range(-160,140,5):
 for x in range(-170,180,5):
  z=ground(x,y);water=7 if y>57 else 2
  if not water+.05<z<water+24 or not roadclear(x,y,3):continue
  if not any(ground(x+dx,y+dy)<water-.1 for dx,dy in [(4,0),(-4,0),(0,4),(0,-4)]):continue
  if any((Vector((x,y,0))-Vector((p.x,p.y,0))).length<4 for p in quay_points):continue
  name='Shore boulder tall' if z-water>3 else random.choice(['Shore boulder broad','Shore rock shelf','Wet waterline rock','Headland rock cluster'])
  place(name,(x,y,water-.25),yaw=random.random()*math.tau,scale=(1.3,1.3,max(.7,(z-water+.4)/dims(name).z)))
# A southern fishing landing, connected to the south-island quay at y~-133.
for j in range(3):
 ob=place('Dock quay connector',(4,-133-j*2.5,2.1),boats);ob['dock_access']=True
for i in range(6):
 x=0 if i<3 else 9;y=-135-(i%3)*5
 place('Fishing boat' if i%2==0 else 'Furled sail launch',(x,y,2.25),boats,yaw=.15 if i<3 else -.1)
 place('Rope boat fender',(x+(1 if i<3 else -1),y,2.4),boats)
place('Net drying frame',(7,-132,4.12),boats)
place('Fishing net bundle',(5,-135,3.65),boats)
place('Oar pair',(5,-138,3.65),boats)
sail=place('Lagoon sailing boat',(60,-122,2.25),boats,yaw=-.6,scale=(1.7,1.7,1.7));sail['sailing_boat']=True
# Fill countryside with contour-following strips, leaving a 4m lane between fields.
farms=[(-560,-140),(-700,100),(-550,380),(410,400),(660,220),(780,540)]
for site,(cx,cy) in enumerate(farms):
 for patch,(ox,oy) in enumerate([(-48,-58),(0,-96),(48,-82)]):
  for row in range(6):
   for j in range(4):
    x=cx+ox+(row-2.5)*4.1;y=cy+oy+(j-1.5)*8.1;name=['Wheat strip 8m','Vegetable strip 8m','Ploughed furrow strip'][(patch+site)%3]
    o=place(name,(x,y,0),farmcol)
    for v in o.data.vertices:v.co.z+=ground(x+v.co.x,y+v.co.y)+.025
  for j in range(7):
   x=cx+ox-13.8;y=cy+oy-15+j*5;place('Curved hedgerow boundary',(x,y,ground(x,y)),farmcol,yaw=math.pi/2)
  for j in range(8):
   x=cx+ox-12+j*4;y=cy+oy-18;o=place('Irrigation ditch 4m',(x,y,ground(x,y)),farmcol)
  x=cx+ox;y=cy+oy-18;place('Field ditch crossing',(x,y,ground(x,y)+.2),farmcol)
 for dx,dy,name in [(17,-10,'Covered haystack'),(-20,-8,'Compost and tool rack'),(-31,-25,'Field boundary stone stile')]:
  x,y=cx+dx,cy+dy;place(name,(x,y,ground(x,y)),farmcol)
 # Keep the extra farm assembly outside established yards and crop lanes.
 x,y=cx+90,cy+30;place(f'Farm variant {site%4+1:02}',(x,y,ground(x,y)),buildings)
# Deploy boathouses in suitable existing waterfront-size parcels. Keep the same
# plot center and preserve independent mesh editing.
for idx,o in enumerate(list(buildings.objects)):
 if not o.get('replaces','').startswith('Outer borough house') or o.location.y>-100 or idx%7:continue
 if o.get('completion_asset','').startswith(('Artisan','Inn')):
  old=o['completion_asset'];name=f'Boathouse variant {idx%4+1:02}';counts[old]-=1;counts[name]+=1;o.data=cache[name].copy();o.name=name;o['completion_asset']=name
  for rec in replacements:
   if rec['old']==o['replaces']:rec['asset']=name
# Clear established tree meshes only where new cultivated plots occupy ground.
cleared=0
for c in [bpy.data.collections.get('14 WORLD — woodland and orchards'),bpy.data.collections.get('07 VEGETATION — representative planting')]:
 if not c:continue
 for o in list(c.all_objects):
  if o.type!='MESH':continue
  p=o.matrix_world.translation
  if any(abs(p.x-(cx+ox))<14 and abs(p.y-(cy+oy))<18 for cx,cy in farms for ox,oy in [(-48,-58),(0,-96),(48,-82)]):stash([o]);cleared+=1
# Sloped landing connects the fishing dock to the actual warped quay edge.
anchor=min(quay_points,key=lambda p:(p.x-4)**2+(p.y+133)**2)
ax,ay=anchor.x,anchor.y
verts=[(ax-1,ay+1,4.12),(ax+1,ay+1,4.12),(5,-134,3.62),(3,-134,3.62)]
me=bpy.data.meshes.new('Dock access ramp');me.from_pydata(verts,[],[(0,3,2,1)]);me.materials.append(stone);o=bpy.data.objects.new('Dock access ramp',me);boats.objects.link(o)
print('FIELD_TREES_CLEARED',cleared,flush=True)

print('COMPLETION_PLACED',json.dumps(counts),flush=True)
# Save a camera framing the developed city; original inspection cameras remain available.
def camera(name,p,target,size):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=p;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=size;return o
s.camera=camera('14 Developed city overview',(350,-460,370),(0,0,12),490)
camera('15 Completed south waterfront',(95,-185,85),(0,-95,4),180)
s.render.resolution_x=1800;s.render.resolution_y=1300;s.render.resolution_percentage=100;s.cycles.samples=16
bpy.context.view_layer.update()
# All new objects are real meshes with independent data, ready for Tab/Edit Mode.
new=list(buildings.objects)+list(waterfront.objects)+list(farmcol.objects)+list(boats.objects)
assert all(o.type=='MESH' and o.data.users==1 for o in new)
assert all(all(math.isfinite(v) for v in o.location) for o in new)
(OUT/'city_completion_manifest.json').write_text(json.dumps({'source':'Hub_City_Foliage_Study.blend','library_assets':80,'building_replacements':replacements,'placement_counts':dict(counts),'new_editable_meshes':len(new),'sailboat_position':list(sail.location)},indent=2))
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hub_City_Developed.blend'))
s.render.filepath=str(OUT/'developed_city_overview.png');bpy.ops.render.render(write_still=True)
s.camera=bpy.data.objects['15 Completed south waterfront'];s.render.filepath=str(OUT/'developed_south_waterfront.png');bpy.ops.render.render(write_still=True)
print('DEVELOPED_CITY_SAVED',flush=True)
