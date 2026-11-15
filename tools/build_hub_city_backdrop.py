"""Add an editable surrounding world to the current saved city, preserving the source file."""
import bpy, math, random, json, sys
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1];OUT=R/'art/HubCityMaster'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Hub_City_Master_Blockout.blend'))
sc=bpy.context.scene;random.seed(261106)
original_objects=set(o.name for o in sc.objects)
def coll(name):
 c=bpy.data.collections.new(name);sc.collection.children.link(c);return c
land=coll('11 WORLD — surrounding terrain');water=coll('12 WORLD — river estuary and sea');town=coll('13 WORLD — outer boroughs and estates');trees=coll('14 WORLD — woodland and orchards');roads=coll('15 WORLD — distant roads and harbor');cams=coll('16 WORLD — inspection cameras')
def mat(name,c):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.85;return m
materials=[mat('World meadow',(.23,.29,.18)),mat('World stone ridge',(.23,.28,.30)),mat('World distant ridge',(.24,.31,.37)),mat('World road',(.41,.36,.27)),mat('World roof',(.10,.16,.19)),mat('World ochre plaster',(.43,.34,.22)),mat('World cream plaster',(.53,.49,.36)),mat('World rose plaster',(.37,.23,.18)),mat('World evergreen',(.07,.18,.11)),mat('World trunk',(.17,.11,.065))]
def mesh(name,vs,fs,c,m):
 d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.materials.append(m);d.update();o=bpy.data.objects.new(name,d);c.objects.link(o);return o
terrain=bpy.data.objects.get('City terrain — 400 x 400 meters')
heights={(round(v.co.x),round(v.co.y)):v.co.z for v in terrain.data.vertices}
def edge(x,y):return heights.get((round(max(-200,min(200,x))),round(max(-180,min(220,y)))),4)
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def riverx(y):return -40+30*math.sin(220/60)+85*math.sin((y-220)/175)
def coastwidth(y):return 18+310*smooth((-180-y)/230)+110*smooth((-400-y)/500)
def rawheight(x,y):
 h=10+9*math.sin(x/130)*math.cos(y/190)+5*math.sin((x+y)/77)
 h+=75*math.exp(-((x-500)/330)**2-((y-230)/380)**2)
 h+=45*math.exp(-((x+500)/390)**2-((y-210)/460)**2)
 if y>380:
  h+=max(0,(y-380)/4)*(.45+.55*abs(math.sin(x/230)+.4*math.cos(y/150)))
 if abs(x)>850:h+=((abs(x)-850)/4)*(.6+.4*math.sin(y/110)**2)
 if y>=220:
  d=abs(x-riverx(y));h=3+(h-3)*smooth((d-10)/100)
 if y<-180:
  shore=abs(x-8)-coastwidth(y);h=-8+(h+8)*smooth((shore+8)/70)
  # Low marsh islands in the broad estuary.
  for cx,cy,rx,ry in [(-170,-480,70,110),(210,-650,90,150),(-310,-860,100,130)]:
   r=((x-cx)/rx)**2+((y-cy)/ry)**2
   if r<1:h=max(h,3.5*(1-r)+1)
 return h

def height(x,y):
 if -200<=x<=200 and -180<=y<=220:return edge(x,y)
 d=max(max(-200-x,0,x-200),max(-180-y,0,y-220))
 t=smooth(d/85)
 return edge(x,y)*(1-t)+rawheight(x,y)*t
# Dense matching edge samples; progressively wider spacing toward the horizon.
xs=sorted(set(list(range(-1400,-300,20))+list(range(-300,-200,5))+list(range(-200,201,1))+list(range(205,301,5))+list(range(320,1401,20))))
ys=sorted(set(list(range(-1400,-280,20))+list(range(-280,-180,5))+list(range(-180,221,1))+list(range(225,321,5))+list(range(340,1801,20))))
vs=[];fs=[];lookup={}
def vertex(i,j):
 key=(i,j)
 if key not in lookup:lookup[key]=len(vs);vs.append((xs[i],ys[j],height(xs[i],ys[j])))
 return lookup[key]
for j in range(len(ys)-1):
 for i in range(len(xs)-1):
  x=(xs[i]+xs[i+1])/2;y=(ys[j]+ys[j+1])/2
  if -200<x<200 and -180<y<220:continue
  fs.append(tuple(vertex(a,b) for a,b in [(i,j),(i+1,j),(i+1,j+1),(i,j+1)]))
worldterrain=mesh('Continuous surrounding landscape',vs,fs,land,materials[0]);worldterrain.data.materials.append(materials[1]);worldterrain.data.materials.append(materials[2])
for p in worldterrain.data.polygons:p.use_smooth=True
# A continuous height-based color transition avoids bands at the terrain material boundaries.
nodes=materials[0].node_tree.nodes;links=materials[0].node_tree.links
geo=nodes.new('ShaderNodeNewGeometry');split=nodes.new('ShaderNodeSeparateXYZ');ramp=nodes.new('ShaderNodeValToRGB');divide=nodes.new('ShaderNodeMath');divide.operation='DIVIDE';divide.inputs[1].default_value=400
links.new(geo.outputs['Position'],split.inputs[0]);links.new(split.outputs['Z'],divide.inputs[0]);links.new(divide.outputs[0],ramp.inputs[0])
ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=(.23,.29,.18,1)
ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(.24,.31,.37,1)
links.new(ramp.outputs[0],nodes.get('Principled BSDF').inputs['Base Color'])
# Water extends beyond all view horizons, with an exact opening around the existing city.
wm=bpy.data.materials.get('Water');z=2
mesh('Open lagoon and sea',[(-9000,-9000,z),(9000,-9000,z),(9000,-180,z),(-9000,-180,z)],[(0,1,2,3)],water,wm)
# Northern river follows its valley and disappears between the mountain shoulders.
rv=[];rf=[]
for y in range(220,1501,5):
 x=riverx(y);rv.extend([(x-12,y,7),(x+12,y,7)])
 if len(rv)>2:a=len(rv)-4;rf.append((a,a+1,a+3,a+2))
mesh('Mountain river continuation',rv,rf,water,wm)
def ribbon(name,points,width):
 v=[]
 for k,(x,y) in enumerate(points):
  prev=Vector(points[max(0,k-1)]);nxt=Vector(points[min(len(points)-1,k+1)]);d=(nxt-prev).normalized();n=Vector((-d.y,d.x))*width/2
  for sign in [-1,1]:xx=x+n.x*sign;yy=y+n.y*sign;v.append((xx,yy,height(xx,yy)+.12))
 return mesh(name,v,[(i,i+1,i+3,i+2) for i in range(0,len(v)-2,2)],roads,materials[3])
avenues=[]
for idx,base in enumerate([-240,-295,-355,-425]):
 pts=[(base+24*math.sin(y/120+idx),y) for y in range(-160,[420,510,610,320][idx],8)];avenues.append(pts);ribbon('Outer borough winding avenue',pts,7)
ribbon('Northern valley road',[(riverx(y)-45,y) for y in range(220,1101,8)],5)
ribbon('Eastern estate road',[(205+i*4,70+80*math.sin(i/55)) for i in range(160)],6)
# Low detail houses are individually editable meshes, aligned to winding streets.
def house(x,y,z,w,d,h,angle):
 v=[(-w/2,-d/2,0),(w/2,-d/2,0),(w/2,d/2,0),(-w/2,d/2,0),(-w/2,-d/2,h),(w/2,-d/2,h),(w/2,d/2,h),(-w/2,d/2,h),(0,-d/2,h+3),(0,d/2,h+3)]
 faces=[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,8),(7,9,6),(4,8,9,7),(5,6,9,8)]
 o=mesh('Outer borough house',v,faces,town,random.choice(materials[5:8]));o.data.materials.append(materials[4]);o.location=(x,y,z);o.rotation_euler.z=angle
 for p in list(o.data.polygons)[5:]:p.material_index=1
 return o
houses=0
for idx,pts in enumerate(avenues):
 for k in range(1,len(pts)-1,2):
  x,y=pts[k]
  if random.random()<.12:continue
  dx=pts[k+1][0]-pts[k-1][0];dy=pts[k+1][1]-pts[k-1][1];angle=-math.atan2(dx,dy)+random.uniform(-.13,.13)
  for side in [-1,1]:
   xx=x+side*random.uniform(12,17);yy=y+random.uniform(-3,3);zz=height(xx,yy)
   if -202<xx<202 and -182<yy<222:continue
   if zz<3:continue
   house(xx,yy,zz,random.uniform(6,10),random.uniform(8,13),random.uniform(7,17),angle);houses+=1
for y in [-90,90,240]:ribbon('Outer borough connecting street',[(x,y+12*math.sin(x/65)) for x in range(-460,-199,6)],5)
# Existing detailed townhouse assets at the near western transition, and villas among eastern groves.
def assembly(key,pos,angle=0):
 c=bpy.data.collections.get(key)
 if not c:return
 o=bpy.data.objects.new('World '+key,None);town.objects.link(o);o.instance_type='COLLECTION';o.instance_collection=c;o.location=pos;o.rotation_euler.z=angle
for i in range(20):
 x=-211-8*math.sin(i*.7);y=-120+i*15
 assembly(['A Cream peaked bookshop','B Rose stepped tailor','C Sage arched cafe','D Ochre oriel restaurant'][i%4],(x,y,height(x,y)),math.pi/2)
for x,y in [(270,85),(340,125),(420,150),(510,115),(620,65)]:assembly('D Hillside villa complete',(x,y,height(x,y)))
# Tree meshes use the existing pine asset; editable realization occurs before saving.
for i in range(1000):
 x=random.uniform(230,750) if i>650 else random.uniform(-900,950);y=random.uniform(-40,450) if i>650 else random.uniform(-800,1250)
 if -215<x<215 and -195<y<235:continue
 z=height(x,y)
 if z<3 or z>180 or (x<-205 and -170<y<630):continue
 c=bpy.data.collections.get('Hillside pine 1')
 if c:
  o=bpy.data.objects.new('World hillside pine',None);trees.objects.link(o);o.instance_type='COLLECTION';o.instance_collection=c;o.location=(x,y,z);o.scale=(random.uniform(1.4,3),)*3
# Harbor docks and boats continue the waterfront into the estuary.
with bpy.data.libraries.load(str(R/'art/CityBoroughLibrary/City_Boroughs_and_Landmarks.blend'),link=False) as (src,dst):
 dst.collections=[n for n in ['Small cargo boat','Rowboat'] if n in src.collections]
for c in dst.collections:c.use_fake_user=True
for i,y in enumerate([-300,-340,-390]):
 x=8+coastwidth(y)
 v=[(x-18,y-2,3.2),(x+65,y-2,3.2),(x+65,y+2,3.2),(x-18,y+2,3.2),(x-18,y-2,2.8),(x+65,y-2,2.8),(x+65,y+2,2.8),(x-18,y+2,2.8)]
 mesh('Outer harbor timber jetty',v,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],roads,materials[9])
 assembly('Small cargo boat',(x-8,y+7,2),math.pi/2)
 assembly('Rowboat',(x+6,y-7,2),.3)
# Horizon ridges extend the silhouette beyond the surrounding terrain boundary.
for ring,(radius,base,amp) in enumerate([(2100,160,240),(3000,220,320)]):
 v=[];f=[]
 for i in range(129):
  a=math.radians(-12+i*204/128);x=radius*math.cos(a);y=radius*math.sin(a)+180
  top=base+amp*(.35+.65*abs(math.sin(a*6+ring)+.25*math.sin(a*19)))
  v.extend([(x,y,-40),(x,y,top)])
  if i:a0=len(v)-4;f.append((a0,a0+1,a0+3,a0+2))
 mesh('Far mountain silhouette '+str(ring+1),v,f,land,materials[2])
def camera(name,pos,target,lens=42):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);cams.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=16000;return o
hero=camera('07 City within the wider world',(620,-830,520),(-30,120,30),40)
street=camera('08 Lagoon toward mountain valley',(5,-130,9),(-35,350,38),30)
sc.camera=hero
for o in sc.objects:
 if o.type=='CAMERA':o.data.clip_end=16000
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.clip_end=16000;area.spaces.active.region_3d.view_perspective='CAMERA'
sys.path.insert(0,str(R/'tools'));from realize_hub_city_components import make_editable
report=make_editable(OUT/'world_backdrop_validation.json')
assert all(name in sc.objects for name in original_objects)
report.update({'original_objects_preserved':len(original_objects),'outer_building_masses':houses,'landscape_extent_m':[2800,3200],'source_master':'Hub_City_Master_Blockout.blend'})
(OUT/'world_backdrop_validation.json').write_text(json.dumps(report,indent=2)+'\n')
sc.render.resolution_x=1800;sc.render.resolution_y=1200;sc.cycles.samples=20
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hub_City_World.blend'))
print('WORLD_SAVED',json.dumps(report),flush=True)
sc.render.filepath=str(OUT/'city_world_overview.png');bpy.ops.render.render(write_still=True)
sc.camera=street;sc.render.filepath=str(OUT/'city_world_street.png');bpy.ops.render.render(write_still=True)
sc.camera=hero
sun=bpy.data.objects.get('Day / moon key');sun.data.energy=.45;sun.data.color=(.5,.65,1)
sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.045,.075,.15,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.4
sc.render.filepath=str(OUT/'city_world_night.png');bpy.ops.render.render(write_still=True)
print('WORLD_RENDERED',flush=True)
