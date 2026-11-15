"""Single-scene city master blockout. Meters, Z up; editable terrain and independent component meshes."""
import bpy, math, json, random, bmesh
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1];OUT=R/'art/HubCityMaster';OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').touch()
bpy.ops.wm.read_factory_settings(use_empty=True);random.seed(1106)
sc=bpy.context.scene;sc.name='HUB CITY — Master Layout';sc.unit_settings.system='METRIC'
M={}
def material(name,color,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.8
 if emit:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
 M[name]=m;return m
for name,c in [('Terrain',(.23,.29,.18)),('Quay',(.42,.43,.37)),('Road',(.50,.43,.32)),('Bridge',(.62,.58,.46)),('Water',(.035,.19,.25)),('Roof',(.095,.15,.18)),('Terracotta',(.40,.19,.10)),('Cream',(.65,.59,.42)),('Sage',(.32,.44,.36)),('Rose',(.47,.25,.20)),('Brick',(.36,.15,.10)),('Label',(.95,.88,.63))]:material(name,c)
material('Lamp',(.95,.46,.12),5)
collections={}
def collection(name):
 c=bpy.data.collections.new(name);sc.collection.children.link(c);collections[name]=c;return c
terraincol=collection('01 TERRAIN — continuous editable landform');watercol=collection('02 WATER — lagoon 2m, river 7m');routecol=collection('03 ROUTES — streets bridges and switchbacks');quaycol=collection('04 QUAYS — island edges');detailcol=collection('05 LANDMARKS — existing component assemblies');masscol=collection('06 DISTRICTS — linked building masses');green=collection('07 VEGETATION — representative planting');lightcol=collection('08 LIGHTING');labels=collection('09 PLAN LABELS');cameras=collection('10 CAMERAS')
def mesh(name,vs,fs,col,mat):
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.materials.append(M[mat]);me.update();o=bpy.data.objects.new(name,me);col.objects.link(o);return o
def box(name,center,dims,col,mat):
 x,y,z=center;a,b,c=[v/2 for v in dims];vs=[(x+sx*a,y+sy*b,z+sz*c) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 return mesh(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],col,mat)
def smooth(a,b,v):
 t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
islands=[('West artisans',(-65,-55),(27,20)),('Merchant island',(-5,-35),(32,24)),('Bathhouse island',(58,-70),(30,26)),('South homes',(4,-115),(24,18)),('Fisher island',(-70,-115),(21,15))]
def shoreline_factor(angle,cx):return 1+.10*math.sin(3*angle+cx*.03)+.055*math.cos(5*angle)
def island_at(x,y):
 for name,(cx,cy),(rx,ry) in islands:
  angle=math.atan2((y-cy)/ry,(x-cx)/rx)
  if ((x-cx)/rx)**2+((y-cy)/ry)**2<=shoreline_factor(angle,cx)**2:return name
 return None
def river_x(y):return -40+30*math.sin(y/60)
def is_water(x,y):
 if island_at(x,y):return False
 lagoon=((x-10)/125)**2+((y+65)/90)**2 < 1
 outlet=abs(x-8)<18 and y<-135
 river=y>=15 and abs(x-river_x(y))<7
 return lagoon or outlet or river
def elevation(x,y):
 if island_at(x,y):return 4.0
 if is_water(x,y):return -1.0
 if river_x(55)-23<x<river_x(55)-6 and 43<y<59:return 2.0
 h=4+22*smooth(30,110,x)*smooth(25,95,y)
 if x<-65 and y>20:h=4+6*smooth(20,55,y)+2*smooth(105,150,y)
 if -178<x<-118 and -75<y<12:h=6
 if -145<x<-65 and 30<y<90:h=10
 if 70<=x<=158 and 65<=y<=150:h=26
 if y>=55 and abs(x-river_x(y))<20:h=max(9,h)
 return h
# Deliberate network, with every district connected to another by a road or bridge.
hubs={'Civic':(-105,55,10),'North':(-95,150,12),'Apartments':(-145,-35,6),'Artisans':(-65,-55,4),'Market':(-5,-35,4),'Bathhouse':(58,-70,4),'South':(4,-115,4),'Fisher':(-70,-115,4),'Docks':(150,-45,4),'Upper gate':(70,95,26),'Gardens':(112,110,26),'Mill':(-38,44,4)}
routes=[]
def route(name,from_hub,to_hub,points,width=5,kind='street'):
 pts=[Vector(p) for p in points];routes.append({'name':name,'from':from_hub,'to':to_hub,'points':pts,'width':width,'kind':kind})
route('West borough avenue','Apartments','Civic',[hubs['Apartments'],(-145,10,6),(-145,30,10),hubs['Civic']],7)
route('Old north road','Civic','North',[hubs['Civic'],(-110,105,10),hubs['North']],6)
route('Artisan crossing','Apartments','Artisans',[hubs['Apartments'],(-124,-35,6),(-95,-46,6),(-82,-51,6),hubs['Artisans']],5,'bridge')
route('Market crossing','Artisans','Market',[hubs['Artisans'],(-45,-48,6),(-31,-43,6),hubs['Market']],5,'bridge')
route('Bathhouse crossing','Market','Bathhouse',[hubs['Market'],(18,-45,6),(34,-55,6),hubs['Bathhouse']],6,'bridge')
route('East docks crossing','Bathhouse','Docks',[hubs['Bathhouse'],(81,-61,6),(111,-51,6),(139,-46,6),hubs['Docks']],5,'bridge')
route('South island bridge','Market','South',[hubs['Market'],(-3,-55,6),(0,-98,6),hubs['South']],4,'bridge')
route('Fisher bridge','Artisans','Fisher',[hubs['Artisans'],(-67,-71,6),(-69,-101,6),hubs['Fisher']],4,'bridge')
route('Lagoon south crossing','Fisher','South',[hubs['Fisher'],(-52,-115,6),(-17,-115,6),hubs['South']],4,'bridge')
route('Civic to mill lane','Civic','Mill',[hubs['Civic'],(-65,55,10),(-43,55,9),(-43,44,4),hubs['Mill']],5)
route('Mill entrance stairs','Mill','Mill',[hubs['Mill'],(river_x(55)-13,47,2),(river_x(55)-13,50,2)],4)
route('North river bridge and hill ascent','Civic','Upper gate',[hubs['Civic'],(-65,85,10),(-30,85,12),(4,85,12),(25,85,10),(30,50,10),(60,50,14),(60,75,18),(40,75,20),(40,95,22),hubs['Upper gate']],6,'mixed')
route('Upper garden promenade','Upper gate','Gardens',[hubs['Upper gate'],(90,95,26),(112,95,26),hubs['Gardens']],6)
route('Eastern hillside descent','Gardens','Docks',[hubs['Gardens'],(145,110,26),(165,110,26),(165,70,20),(145,70,16),(145,30,10),(165,30,7),(165,-20,4),hubs['Docks']],6,'mixed')
# Additional island streets establish buildable blocks and circulation around water edges.
for name,(cx,cy),(rx,ry) in islands:
 route(name+' cross street',name,name,[(cx-rx*.7,cy,4),(cx+rx*.7,cy,4)],4)
 route(name+' side lane',name,name,[(cx,cy-ry*.7,4),(cx,cy+ry*.7,4)],4)
segments=[]
for r in routes:
 for a,b in zip(r['points'],r['points'][1:]):segments.append((a,b,r['width'],r['name']))
def nearest_segment(x,y,a,b):
 dx=b.x-a.x;dy=b.y-a.y;t=max(0,min(1,((x-a.x)*dx+(y-a.y)*dy)/(dx*dx+dy*dy)))
 return math.hypot(x-(a.x+t*dx),y-(a.y+t*dy)),a.z+t*(b.z-a.z)
def ground(x,y):
 h=elevation(x,y)
 if h<0:return h
 for a,b,w,_ in segments:
  d,z=nearest_segment(x,y,a,b)
  if d<w/2+1:h=min(h,z-.12)
 return h
# A single heightfield includes submerged channels, the lagoon bed and five islands.
step=1;nx=400;ny=400;vs=[]
for j in range(ny+1):
 y=-180+j*step
 for i in range(nx+1):
  x=-200+i*step;vs.append((x,y,ground(x,y)))
fs=[]
for j in range(ny):
 for i in range(nx):a=j*(nx+1)+i;fs.append((a,a+1,a+nx+2,a+nx+1))
terrain=mesh('City terrain — 400 x 400 meters',vs,fs,terraincol,'Terrain');terrain['purpose']='Sculptable city landform. Roads are cut into the heightfield; lagoon and riverbed are submerged.'
# Water tessellation follows the land mask; inner boundaries respect island shorelines.
for level,name,predicate in [(2,'Lagoon and lower river',lambda x,y:y<55),(7,'Upper river',lambda x,y:y>=55)]:
 vs=[];fs=[]
 for j in range(ny):
  y=-180+j*step
  for i in range(nx):
   x=-200+i*step
   if predicate(x+step/2,y+step/2) and is_water(x+step/2,y+step/2):
    a=len(vs);vs.extend([(x,y,level),(x+step,y,level),(x+step,y+step,level),(x,y+step,level)]);fs.append((a,a+1,a+2,a+3))
 mesh(name,vs,fs,watercol,'Water')
fx=river_x(55);mesh('Mill waterfall 7m to 2m',[(fx-7,55,7),(fx+7,55,7),(fx+7,52,2),(fx-7,52,2)],[(0,1,2,3)],watercol,'Water')
# Island quay rings: vertical dressed banks and continuous accessible perimeter walks.
for name,(cx,cy),(rx,ry) in islands:
 vs=[];fs=[];n=96
 for i in range(n):
  a=i*math.tau/n;factor=shoreline_factor(a,cx)
  for rr,z in [(1,1.5),(1,4.1),(.88,4.1)]:vs.append((cx+rx*rr*factor*math.cos(a),cy+ry*rr*factor*math.sin(a),z))
 for i in range(n):j=(i+1)%n;fs.extend([(3*i,3*j,3*j+1,3*i+1),(3*i+1,3*j+1,3*j+2,3*i+2)])
 mesh(name+' perimeter quay',vs,fs,quaycol,'Quay')
# Road meshes, physical stair treads on steep land sections, bridge piers on water.
road_reports=[]
for r in routes:
 distance=0;max_grade=0;piers=0
 for si,(a,b) in enumerate(zip(r['points'],r['points'][1:])):
  delta=b-a;length=Vector((delta.x,delta.y,0)).length;distance+=length;grade=abs(delta.z)/length;max_grade=max(max_grade,grade);n=Vector((-delta.y,delta.x,0)).normalized()*r['width']/2
  steep=grade>.10 and not(is_water(a.x,a.y) or is_water(b.x,b.y))
  if steep:
   count=max(1,math.ceil(abs(delta.z)/.18))
   # Closed stepped prism spans both endpoints; lower side follows the slope beneath treads.
   for k in range(count):
    p=a+delta*k/count;q=a+delta*(k+1)/count;z=max(p.z,q.z)+.12
    v=[tuple(p-n+Vector((0,0,z-p.z))),tuple(p+n+Vector((0,0,z-p.z))),tuple(q+n+Vector((0,0,z-q.z))),tuple(q-n+Vector((0,0,z-q.z)))]
    mesh(r['name']+' stair tread',v,[(0,1,2,3)],routecol,'Road')
  else:
   mesh(r['name']+' surface '+str(si),[tuple(a-n+Vector((0,0,.12))),tuple(a+n+Vector((0,0,.12))),tuple(b+n+Vector((0,0,.12))),tuple(b-n+Vector((0,0,.12)))],[(0,1,2,3)],routecol,'Bridge' if r['kind']=='bridge' else 'Road')
  for k in range(max(1,int(length/10))):
   t=(k+.5)/max(1,int(length/10));p=a+delta*t
   if is_water(p.x,p.y):
    box('Bridge pier — '+r['name'],(p.x,p.y,(p.z-1)/2),(1.3,1.3,p.z+1),routecol,'Quay');piers+=1
 road_reports.append({'name':r['name'],'from':r['from'],'to':r['to'],'length_m':round(distance,1),'max_grade':round(max_grade,3),'water_piers':piers})
box('Mill upper approach landing',(-38,44,3),(5,5,2),routecol,'Quay')
# Embedded reusable source collections, not visible as a separate gallery in the master scene.
assets={}
requests={
 'CityBoroughLibrary/City_Boroughs_and_Landmarks.blend':['A Warehouse complete','D Hillside villa complete','E Clock Hall complete','F Canal Bathhouse complete','G Great Waterwheel Mill complete'],
 'ResidentialStreetLibrary/Residential_Streets_and_Apartments.blend':['A Cream peaked bookshop','B Rose stepped tailor','C Sage arched cafe','D Ochre oriel restaurant','E Courtyard apartment complex','F Corner restaurant apartments'],
 'UpperCityLibrary/Upper_City_Waterways_and_Gardens.blend':['C Wisteria gazebo and open pavilion'],
 'HubTownExpansion/HubTown_Environment_Expansion.blend':['Fort wall block bay','Capped battlement bay','Complete gate arch surround','Tower masonry base','Tower lookout transition','Complete lookout frame','Complete watchtower hip roof','Hillside pine 1']}
for file,names in requests.items():
 with bpy.data.libraries.load(str(R/'art'/file),link=False) as (src,dst):assert all(n in src.collections for n in names);dst.collections=names
 for c in dst.collections:assets[c.name]=c;c.use_fake_user=True
placements=[]
def instance(key,pos,yaw=0,col=detailcol,scale=1):
 o=bpy.data.objects.new(key,None);col.objects.link(o);o.instance_type='COLLECTION';o.instance_collection=assets[key];o.location=pos;o.rotation_euler.z=yaw;o.scale=(scale,)*3;placements.append({'asset':key,'position':list(pos),'yaw':yaw});return o
# Reserved detailed landmarks are clear of primary circulation.
reserved=[]
def reserve(x,y,rx,ry):reserved.append((x,y,rx,ry))
instance('E Clock Hall complete',(-105,69,10));reserve(-109,68,15,13)
instance('F Canal Bathhouse complete',(68,-77,4));reserve(68,-77,10,10)
instance('G Great Waterwheel Mill complete',(fx-11,53,2));reserve(fx-11,53,10,10)
instance('E Courtyard apartment complex',(-150,-15,6));reserve(-150,-12,11,13)
instance('E Courtyard apartment complex',(-150,-60,6),math.pi);reserve(-150,-63,11,13)
instance('C Wisteria gazebo and open pavilion',(116,126,26));reserve(116,126,15,12)
for x,y in [(87,118),(145,133),(142,86)]:instance('D Hillside villa complete',(x,y,26));reserve(x,y,8,11)
for y in [-75,-53,-25]:instance('A Warehouse complete',(152,y,4),math.pi/2);reserve(152,y,8,10)
for i,key in enumerate(['A Cream peaked bookshop','B Rose stepped tailor','C Sage arched cafe','D Ochre oriel restaurant']):
 for y,yaw in [(-26,math.pi),(-44,0)]:instance(key,(-20+i*5,y,4),yaw);reserve(-20+i*5,y,2.5,6)
instance('F Corner restaurant apartments',(11,-26,4));reserve(11,-26,4,7)
# Guarded hill perimeter and a west-facing entrance exactly at the route endpoint.
instance('Complete gate arch surround',(70,95,26),-math.pi/2)
for y in list(range(67,91,4))+list(range(101,150,4)):
 instance('Fort wall block bay',(70,y,26),math.pi/2);instance('Capped battlement bay',(70,y,32),math.pi/2)
for x in range(74,158,4):
 for y in [65,150]:instance('Fort wall block bay',(x,y,26));instance('Capped battlement bay',(x,y,32))
for y in range(69,150,4):instance('Fort wall block bay',(158,y,26),math.pi/2);instance('Capped battlement bay',(158,y,32),math.pi/2)
for x,y in [(70,85),(70,106),(158,65),(158,150)]:
 for z in [26,29,32]:instance('Tower masonry base',(x,y,z))
 instance('Tower lookout transition',(x,y,35));instance('Complete lookout frame',(x,y,35.3));instance('Complete watchtower hip roof',(x,y,38.3));reserve(x,y,4,4)
# Eight shared massing prototypes. No bespoke window details in the distant blockout.
mass_sources=[]
for i in range(8):
 c=bpy.data.collections.new('MASS prototype '+str(i));c.use_fake_user=True;h=[7,9,11,8,10,7,12,9][i];w=5.5;d=7
 box('Simple building mass',(0,0,h/2),(w,d,h),c,['Cream','Sage','Rose','Brick'][i%4])
 mesh('Simple pitched roof',[(-w/2-.2,-d/2-.2,h),(w/2+.2,-d/2-.2,h),(w/2+.2,d/2+.2,h),(-w/2-.2,d/2+.2,h),(0,-d/2-.2,h+2),(0,d/2+.2,h+2)],[(0,1,4),(3,5,2),(0,4,5,3),(1,2,5,4),(0,3,2,1)],c,'Terracotta' if i%3==0 else 'Roof');mass_sources.append(c)
buildings=[]
for y in range(-150,190,11):
 for x in range(-180,185,9):
  x=x+random.uniform(-.7,.7);yy=y+random.uniform(-.6,.6)
  if 64<x<165 and 59<yy<157:continue
  if is_water(x,yy) or island_at(x,yy):continue
  z=elevation(x,yy)
  if any(is_water(x+dx,yy+dy) or abs(elevation(x+dx,yy+dy)-z)>.15 for dx in [-3.1,3.1] for dy in [-3.9,3.9]):continue
  if any(abs(x-cx)<rx+3 and abs(yy-cy)<ry+4 for cx,cy,rx,ry in reserved):continue
  if any(nearest_segment(x,yy,a,b)[0]<w/2+5 for a,b,w,_ in segments):continue
  if any(((x-cx)/(rx*.82))**2+((yy-cy)/(ry*.82))**2>1 and ((x-cx)/rx)**2+((yy-cy)/ry)**2<=1 for _,(cx,cy),(rx,ry) in islands):continue
  if random.random()<.16:continue
  c=mass_sources[random.randrange(8)];o=bpy.data.objects.new('BLOCKOUT building %03d'%len(buildings),None);masscol.objects.link(o);o.instance_type='COLLECTION';o.instance_collection=c;o.location=(x,yy,z);o.rotation_euler.z=0 if random.random()<.8 else math.pi
  buildings.append({'position':[round(x,2),round(yy,2),round(z,2)],'prototype':c.name})
# Smaller, denser island parcels leave room for quays and narrow lanes.
for district,(cx,cy),(rx,ry) in islands:
 for ix in range(-6,7):
  for iy in range(-5,6):
   x=cx+ix*5.8;yy=cy+iy*7.2
   if island_at(x,yy)!=district:continue
   angle=math.atan2((yy-cy)/ry,(x-cx)/rx)
   if ((x-cx)/rx)**2+((yy-cy)/ry)**2>(shoreline_factor(angle,cx)*.77)**2:continue
   if any(is_water(x+dx,yy+dy) for dx in [-2.1,2.1] for dy in [-2.7,2.7]):continue
   if any(abs(x-px)<prx+2.2 and abs(yy-py)<pry+2.8 for px,py,prx,pry in reserved):continue
   if any(nearest_segment(x,yy,a,b)[0]<w/2+2.5 for a,b,w,_ in segments):continue
   c=mass_sources[random.randrange(8)];o=bpy.data.objects.new(district+' mass',None);masscol.objects.link(o);o.instance_type='COLLECTION';o.instance_collection=c;o.location=(x,yy,4);o.scale=(.7,.7,.85)
   buildings.append({'position':[round(x,2),round(yy,2),4],'prototype':c.name,'district':district})
# Sparse trees help read hills without obscuring the blockout.
for i in range(85):
 x=random.uniform(-190,190);y=random.uniform(150,212)
 if not is_water(x,y) and not any(nearest_segment(x,y,a,b)[0]<6 for a,b,_,_ in segments):instance('Hillside pine 1',(x,y,ground(x,y)),random.random()*math.tau,green,random.uniform(.8,1.3))
# Plan labels remain independently hideable.
def label(text,pos,size=5):
 data=bpy.data.curves.new(text,'FONT');data.body=text;data.size=size;data.align_x='CENTER';data.materials.append(M['Label']);o=bpy.data.objects.new(text,data);labels.objects.link(o);o.location=pos
for name,p in [('CIVIC / CLOCK HALL',(-105,95,40)),('APARTMENT COURTS',(-150,-87,20)),('MERCHANT ISLAND',(-5,-8,20)),('BATHHOUSE',(68,-100,20)),('WAREHOUSE QUAYS',(155,-98,20)),('FORTIFIED UPPER CITY',(112,157,45)),('OLD NORTH BOROUGH',(-105,190,30)),('MILL DROP / 7m → 2m',(river_x(55)+28,51,30))]:label(name,p,4)
label('100 m',(-120,-168,30),4);box('100 meter scale bar',(-120,-174,30),(100,1.5,.3),labels,'Label')
# Cameras: broad city, plan, and ground-level inspection locations.
def camera(name,pos,target,ortho=None):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);cameras.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.clip_end=2000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
 else:d.lens=24
 return o
hero=camera('01 City overview',(350,-420,350),(0,15,5),500);plan=camera('02 Dimensioned overhead',(0,20,600),(0,20,0),540)
camera('03 Merchant pedestrian',(-18,-35,5.7),(10,-35,6));camera('04 Bathhouse approach',(42,-65,5.7),(68,-77,7));camera('05 Upper gate approach',(58,95,26),(76,95,28));camera('06 Civic square',(-112,52,11.7),(-105,69,15))
world=bpy.data.worlds.new('City world');world.use_nodes=True;sc.world=world
sun_data=bpy.data.lights.new('Day / moon key','SUN');sun=bpy.data.objects.new('Day / moon key',sun_data);lightcol.objects.link(sun);sun.rotation_euler=(.5,-.4,-.6);sun_data.angle=.2
sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True;sc.render.resolution_x=2000;sc.render.resolution_y=1600;sc.render.resolution_percentage=100;sc.view_settings.view_transform='AgX'
# Route lamps for a readable night study (not a final lighting pass).
for r in routes[:13]:
 for a,b in zip(r['points'],r['points'][1:]):
  count=max(1,int((b-a).length/18))
  for i in range(count):
   p=a+(b-a)*(i+.5)/count;box('Route lamp',(p.x,p.y,p.z+3),(.35,.35,.5),lightcol,'Lamp')
   ld=bpy.data.lights.new('Warm route light','POINT');ld.energy=100;ld.color=(1,.48,.16);ld.shadow_soft_size=1;ob=bpy.data.objects.new('Warm route light',ld);lightcol.objects.link(ob);ob.location=(p.x,p.y,p.z+3)
labels.hide_render=True;labels.hide_viewport=True;sc.camera=hero
world.node_tree.nodes['Background'].inputs[0].default_value=(.22,.28,.36,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;sun_data.energy=2
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.shading.type='MATERIAL';area.spaces.active.region_3d.view_location=(0,15,5);area.spaces.active.region_3d.view_distance=500;area.spaces.active.clip_end=2000
# Realize assemblies so selecting a building component allows direct mesh editing.
import sys
sys.path.insert(0,str(R/'tools'))
from realize_hub_city_components import make_editable
make_editable()
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hub_City_Master_Blockout.blend'))
manifest={'footprint_m':[400,400],'lagoon_water_z':2,'upper_river_water_z':7,'upper_city_ground_z':26,'islands':[{'name':n,'center':c,'radii':r} for n,c,r in islands],'hubs':hubs,'routes':road_reports,'building_mass_count':len(buildings),'building_masses':buildings,'component_placements':placements,'terrain_vertices':len(terrain.data.vertices),'notes':'Concept-scale layout, not a gameplay-validated level. Components are realized as independent editable mesh objects; assembly empties organize their children.'}
(OUT/'layout_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('MASTER_SAVED',len(buildings),'building masses',len(placements),'component instances',flush=True)
sc.render.filepath=str(OUT/'city_blockout_day.png');bpy.ops.render.render(write_still=True)
sc.camera=plan;labels.hide_render=False;labels.hide_viewport=False;sc.render.filepath=str(OUT/'city_plan.png');bpy.ops.render.render(write_still=True)
labels.hide_render=True;labels.hide_viewport=True;sc.camera=hero;sun_data.energy=.35;sun_data.color=(.5,.65,1);world.node_tree.nodes['Background'].inputs[0].default_value=(.045,.075,.15,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35
sc.render.filepath=str(OUT/'city_blockout_night.png');bpy.ops.render.render(write_still=True)
print('MASTER_RENDERED',flush=True)
