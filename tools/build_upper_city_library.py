"""Editable upper-city terrain, waterways and garden structures: 40 source assets."""
from pathlib import Path
base=Path(__file__).with_name('build_city_borough_library.py')
exec(compile(base.read_text().split("C='17 Canal Warehouse'")[0].replace('CityBoroughLibrary','UpperCityLibrary'),str(base),'exec'))
scene.name='00 Editable Components'
mat('Earth',(.20,.19,.115)); mat('Grass',(.23,.30,.12)); mat('Wisteria',(.43,.19,.65)); mat('WisteriaLight',(.69,.42,.81)); mat('GardenStone',(.66,.61,.49)); mat('WaterPreview',(.045,.22,.27),metal=.25,rough=.22)
reused={}
requests={
 'HubTownExpansion/HubTown_Environment_Expansion.blend':['Complete gate arch surround','Gate overhead masonry','Hinged gate left','Hinged gate right','Fort wall block bay','Capped battlement bay','Wall top walkway','Tower masonry base','Tower lookout transition','Complete lookout frame','Complete watchtower hip roof','Detailed retaining bay','Rock ledge','Rock slope transition','Hillside pine 1','Rounded shrub','Hedge straight','Hedge corner','Planted flower box'],
 'HubTownLibrary/HubTown_Component_Library.blend':['Stone stairs full story','Stone stairs short','Stone bridge arch bay','Stone bridge deck','Bridge parapet straight','Bridge middle pier','Wall lantern','Table','Chair','Bench'],
 'CityBoroughLibrary/City_Boroughs_and_Landmarks.blend':['Villa low hip roof','Villa pergola bay','Villa garden balustrade','Villa garden gatepost','Villa iron garden gate','Villa terrace steps','Villa pale wall','Villa arched window wall','Villa arched window','Villa arched door wall','Villa arched door','Spillway crest','Mill sluice gate','Mill sluice lifting frame']}
reuse_root=bpy.data.collections.new('Existing Reused Components');scene.collection.children.link(reuse_root)
for file,names in requests.items():
 with bpy.data.libraries.load(str(R/'art'/file),link=False) as (src,dst):
  assert all(n in src.collections for n in names),(file,set(names)-set(src.collections));dst.collections=names
 for c in dst.collections:
  reuse_root.children.link(c); reused[c.name]=c; assets[c.name]=c
  i=len(reused)-1;p=Vector(((i%8)*7,-25-(i//8)*7,0))
  for o in c.objects:
   if o.type=='MESH':o.location=p
  c.instance_offset=p

def at(fn,xyz):
 n=len(pieces);fn()
 for o in pieces[n:]:o.location+=Vector(xyz)
def terrain(shape=0,w=8,d=8):
 n=8; vs=[]
 for j in range(n+1):
  t=j/n
  for i in range(n+1):
   u=i/n; z=3*t
   if shape==1:z+=1.2*math.sin(math.pi*u)*math.sin(math.pi*t)
   if shape==2:z-=1.1*math.sin(math.pi*u)*math.sin(math.pi*t)
   if shape==3:z=3*min(1,t*1.6)+.15*math.sin(u*8)*math.sin(t*math.pi)
   vs.append(((u-.5)*w,(t-.5)*d,z))
 fs=[]
 for j in range(n):
  for i in range(n):a=j*(n+1)+i;fs.append((a,a+1,a+n+2,a+n+1))
 perimeter=list(range(n+1))+[j*(n+1)+n for j in range(1,n+1)]+list(range(n*(n+1)+n-1,n*(n+1)-1,-1))+[j*(n+1) for j in range(n-1,0,-1)]
 bottom=[]
 for k in perimeter:bottom.append(len(vs));vs.append((vs[k][0],vs[k][1],-.4))
 for i,k in enumerate(perimeter):j=(i+1)%len(perimeter);fs.append((k,bottom[i],bottom[j],perimeter[j]))
 fs.append(tuple(reversed(bottom)));mesh('terrain',vs,fs,'Grass')
def slopedwall():
 prism('ascending curtain',[(-2,0),(2,1.5),(2,5.5),(-2,4)],.9,'StoneLight')
 for i in range(8):
  x=-1.75+i*.5;z=4+(x+2)*1.5/4;box('merlon',(x,0,z+.35),(.35,1,.7),'StoneLight')
def stepsbase():
 for i in range(4):box('foundation',(i-1.5,0,(i+1)*.2),(1,.95,(i+1)*.4),'Stone')
def anglecollar():
 box('wall end',(0,0,2),(.8,1.3,4),'StoneLight');o=box('tower connector',(.55,.28,2),(1.1,1.3,4),'StoneLight');o.rotation_euler.z=math.pi/4
C='33 Fortified Hillside'
for k,name in enumerate(['Broad sloping terrain','Convex hillside','Concave hillside','Terrace slope transition']):asset(C,name,lambda k=k:terrain(k))
asset(C,'Sloped defensive wall',slopedwall)
asset(C,'Stepped defensive foundation',stepsbase)
asset(C,'Angled tower connector',anglecollar)
asset(C,'Switchback stair landing',lambda:(box('landing',(0,0,-.2),(6,4,.4),'GardenStone'),box('rear parapet',(0,1.85,.5),(6,.3,1),'StoneLight')))

def arcwall(radius=8,angle=math.pi/4,height=3,thick=.6):
 n=16;vs=[]
 for z in [0,height]:
  for r in [radius-thick/2,radius+thick/2]:
   vs.extend((r*math.cos(i*angle/n)-radius,r*math.sin(i*angle/n),z) for i in range(n+1))
 m=n+1;fs=[]
 for i in range(n):fs += [(i,i+1,2*m+i+1,2*m+i),(m+i,3*m+i,3*m+i+1,m+i+1),(2*m+i,2*m+i+1,3*m+i+1,3*m+i),(i,m+i,m+i+1,i+1)]
 fs += [(0,2*m,3*m,m),(n,m+n,3*m+n,2*m+n)];mesh('curved masonry',vs,fs,'StoneLight')
def bank(plant=False):
 for i in range(7):uvball('bank rock',((i-3)*.65,.1*math.sin(i),.25),(.5,.7,.4),'Stone',8,4)
 if plant:
  for i in range(12):
   x=(i/11-.5)*4;beam('reed',(x,.2,0),(x+.08,.2,.6+random.random()*.4),.025,'Grass')
def forkbank():
 prism('dividing island',[(-2,0),(2,0),(.4,1.2),(-.4,1.2)],3,'Earth')
 for x in [-.4,.4]:uvball('fork rock',(x,1.3,.5),(.6,.7,.65),'Stone',8,4)
def poolrim():
 n=len(pieces)
 arcwall(4,math.pi/2,.8,1.1)
 for i in range(6):
  a=i*math.pi/10;uvball('pool rock',(4*math.cos(a)-4,4*math.sin(a),.5),(.6,.55,.7),'Stone',8,4)
 for o in pieces[n:]:o.location.x+=4

def mouth():
 for side in [-1,1]:
  for j in range(4):uvball('cave buttress',(side*(2.6+.25*math.sin(j)),.2,j*1.25+.5),(1.1,1.8,1.05),'Stone',8,4)
 uvball('cave crown',(0,.5,4.2),(2.8,1.9,1.2),'Stone',9,4)
 for x in [-2,0,2]:uvball('mountain crag',(x,2.2,5.5),(1.3,1.5,2+random.random()),'Stone',7,4)

C='34 River and Waterfall'
asset(C,'Gentle curved canal wall',lambda:arcwall(10))
asset(C,'Tight curved canal wall',lambda:arcwall(4,math.pi/2))
asset(C,'Gentle curved canal coping',lambda:arcwall(10,math.pi/4,.18,.85))
asset(C,'Tight curved canal coping',lambda:arcwall(4,math.pi/2,.18,.85))
def widthtransition():
 for sign in [-1,1]:
  vs=[]
  for z in [0,3]:
   for x,y in [(2-.3,-2),(2+.3,-2),(3+.3,2),(3-.3,2)]:vs.append((sign*x,y,z))
  mesh('tapered retaining wall',vs,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],'StoneLight')
 box('bed',(0,0,-.2),(6.6,4,.4),'Earth')
asset(C,'Canal width transition',widthtransition)
asset(C,'River confluence bank',forkbank)
asset(C,'Natural rocky bank',bank)
asset(C,'Shallow planted bank',lambda:bank(True))
asset(C,'Natural to masonry bank',lambda:(bank(),box('dressed end',(1.5,.1,.6),(1,1,1.2),'StoneLight')))
asset(C,'Riverbed channel',lambda:(box('bed',(0,0,-.2),(6,8,.4),'Earth'),box('left bank',(-3.2,0,.7),(.4,8,1.8),'Earth'),box('right bank',(3.2,0,.7),(.4,8,1.8),'Earth')))
asset(C,'Mountain river mouth',mouth)
asset(C,'Waterfall lip',lambda:(box('stone sill',(0,0,-.15),(4,1,.3),'StoneLight'),[box('lip block',(-1.75+i*.5,-.4,-.08),(.48,.35,.3),'Stone') for i in range(8)]))
asset(C,'Waterfall side cliff',lambda:([uvball('cliff',(0,0,.6+i*1.1),(1.1,.9,.9),'Stone',7,4) for i in range(4)]))
asset(C,'Plunge pool rock surround',poolrim)
asset(C,'Cascade rock shelf',lambda:(box('shelf',(0,0,.15),(4,2,.3),'Stone'),[uvball('edge rock',(-1.7+i*.65,-.8,.3),(.5,.4,.3),'Stone',8,4) for i in range(6)]))
asset(C,'Angled bridge abutment',lambda:prism('splayed abutment',[(-1.6,0),(1.6,0),(1,3),(-1,3)],2.4,'StoneLight'))

def gazeboroof():
 a=math.pi/4;r=3.4
 vs=[(0,0,1.7),(r,0,0),(r*math.cos(a),r*math.sin(a),0),(0,0,1.58),(r,0,-.12),(r*math.cos(a),r*math.sin(a),-.12)]
 mesh('roof wedge',vs,[(0,1,2),(5,4,3),(0,3,4,1),(1,4,5,2),(2,5,3,0)],'VillaRoof')
 beam('hip rafter',(0,0,1.55),(r,0,-.15),.12,'Timber')
def pavilioncorner():
 box('corner pier',(0,0,1.5),(.45,.45,3),'GardenStone')
 box('base',(0,0,.1),(.65,.65,.2),'GardenStone');box('capital',(0,0,3),(.65,.65,.22),'GardenStone')
def arcade():archwall(4,3.2,3.3,2.95,0,.35,'GardenStone')
def ceiling():
 box('finished ceiling',(0,0,0),(4,3,.12),'Wood')
 for x in [-1.8,-.9,0,.9,1.8]:box('ceiling beam',(x,0,-.16),(.14,3,.2),'Timber')
C='35 Garden Structures'
asset(C,'Octagonal gazebo floor',lambda:cyl('floor',(0,0,.15),3.15,.3,'GardenStone',8))
asset(C,'Gazebo post',lambda:(box('post',(0,0,1.6),(.18,.18,3.2),'Timber'),box('foot',(0,0,.15),(.35,.35,.3),'GardenStone'),beam('brace',(0,0,2.5),(.6,0,3.1),.1)))
asset(C,'Gazebo roof wedge',gazeboroof)
asset(C,'Gazebo roof cap',lambda:(cyl('cap',(0,0,.15),.3,.3,'Copper',8,r2=.08),cyl('finial',(0,0,.5),.06,.5,'Copper',8,r2=.01)))
asset(C,'Gazebo railing bay',lambda:balustrade(2.14))
asset(C,'Open pavilion arcade',arcade)
asset(C,'Open pavilion corner',pavilioncorner)
asset(C,'Pavilion entablature beam',lambda:(box('architrave',(0,0,.15),(4,.5,.3),'GardenStone'),at(lambda:cornice(4),(0,0,.3))))
asset(C,'Finished pavilion ceiling',ceiling)
asset(C,'Pergola corner junction',lambda:(box('post',(0,0,1.5),(.2,.2,3),'Timber'),box('header',(1,0,3),(2.2,.2,.2),'Timber'),box('return',(0,1,3.05),(.2,2.2,.2),'Timber'),beam('brace',(0,0,2.3),(.7,0,3),.12),beam('brace',(0,0,2.3),(0,.7,3.05),.12)))

def vine(vertical=False):
 for j in range(22):
  t=j/21*3.2;u=(j+1)/21*3.2
  a=(.11*math.sin(t*5),.11*math.cos(t*5),t) if vertical else (t,.12*math.sin(t*4),.1*math.cos(t*5))
  b=(.11*math.sin(u*5),.11*math.cos(u*5),u) if vertical else (u,.12*math.sin(u*4),.1*math.cos(u*5))
  beam('woody vine',a,b,.07 if vertical else .04,'Timber')
def canopy():
 for i in range(18):uvball('foliage',(random.uniform(-1.5,1.5),random.uniform(-.65,.65),random.uniform(-.1,.1)),(.4,.35,.19),'Leaf',7,4)
def bloom(length=.65):
 beam('flower stem',(0,0,0),(0,0,-length),.015,'Green')
 for j in range(9):
  t=j/9;r=.12*(1-t)+.025
  for k in range(3):
   a=k*math.tau/3+j*.6;uvball('flower',(r*math.cos(a),r*math.sin(a),-length*t),(.065*(1-t)+.02,.055,.055),'Wisteria' if j%2 else 'WisteriaLight',5,3)
def cypress():
 cyl('trunk',(0,0,1.4),.13,2.8,'Timber',8,r2=.08)
 for i in range(5):uvball('cypress crown',(0,0,1.1+i*.65),(.52-i*.07,.48-i*.06,.85),'Green',9,5)
C='36 Wisteria and Gardens'
asset(C,'Wisteria twisting trunk',lambda:vine(True))
asset(C,'Wisteria trained horizontal vine',vine)
asset(C,'Wisteria foliage canopy',canopy)
asset(C,'Wisteria short flower cluster',bloom,'Origin at hanging attachment; flowers extend downward.')
asset(C,'Wisteria long flower cluster',lambda:bloom(1.1),'Origin at hanging attachment; flowers extend downward.')
asset(C,'Slender cypress',cypress)
assert len(catalog)==40,len(catalog)
helpers='def begin_assembly(name):'+base.read_text().split('def begin_assembly(name):')[1].split('col=begin_assembly(')[0];exec(compile(helpers,str(base),'exec'))
def direct(col,fn,name):
 global current,pieces
 current=col;pieces=[];fn()
 for o in pieces:o.name=name+' '+o.name
 bpy.context.view_layer.update()
 return pieces[:]

col=begin_assembly('A Fortified hillside entrance')
# Broad hill, flattened into two architectural terraces. One mesh remains sculptable.
def hill():
 n=20;vs=[]
 for j in range(n+1):
  y=-12+j*1.7;z=4*max(0,min(1,(y+8)/8)) if y<8 else 4+4*min(1,(y-8)/5)
  for i in range(n+1):
   x=-18+i*1.8;zz=z
   if abs(x)<2 and y<0:zz=4*max(0,(y+6.24)/6.24)-.15
   vs.append((x,y,zz-.08))
 fs=[]
 for j in range(n):
  for i in range(n):a=j*(n+1)+i;fs.append((a,a+1,a+n+2,a+n+1))
 mesh('sculptable terraced hillside',vs,fs,'Grass')
direct(col,hill,'Terrain')
place(col,'Complete gate arch surround',(0,0,4));place(col,'Gate overhead masonry',(0,0,4))
for x in [-1,1]:place(col,'Hinged gate left' if x<0 else 'Hinged gate right',(x*2,0,4))
for x in [-14,-10,-6,6,10,14]:
 place(col,'Fort wall block bay',(x,0,4));place(col,'Capped battlement bay',(x,0,10));place(col,'Wall top walkway',(x,.4,10))
for x in [-10,10]:
 for z in [4,7,10]:place(col,'Tower masonry base',(x,1,z))
 place(col,'Tower lookout transition',(x,1,13));place(col,'Complete lookout frame',(x,1,13.3));place(col,'Complete watchtower hip roof',(x,1,16.3))
place(col,'Stone stairs full story',(0,-6.24,0),scale=(1.5,1.3,4/3))
place(col,'Switchback stair landing',(0,3,4))
# Villas on the upper terrace, using existing openings and materials.
for cx in [-8,8]:
 for x in [-2,2]:
  for y,yaw in [(13,0),(19,math.pi)]:
   key='Villa arched door wall' if x==-2 and y==13 else 'Villa arched window wall';place(col,key,(cx+x,y,8),yaw)
   place(col,'Villa arched door' if 'door' in key else 'Villa arched window',(cx+x,y+(-.2 if y==13 else .2),8 if 'door' in key else 8.5),yaw)
 for x,yaw in [(-4,-math.pi/2),(4,math.pi/2)]:
  for y in [14.5,17.5]:place(col,'Villa pale wall',(cx+x,y,8),yaw,scale=(.75,1,1))
 place(col,'Villa low hip roof',(cx,16,11))
for x in [-16,-12,12,16]:
 place(col,'Hillside pine 1',(x,18,8));place(col,'Slender cypress',(x,8,4))
place(col,'Stone stairs full story',(0,8,4),scale=(1.4,1.04,4/3))
for x in [-3,3]:place(col,'Wall lantern',(x,-1.1,7))

col=begin_assembly('B Winding canal waterfall and mill')
# Centerline is upstream -> downstream. Blender coordinates; Godot conversion is x,z,-y.
river_points=[(3,29,3.8),(-1,23,3.8),(-3,17,3.8),(0,12,3.8),(2,7,3.8),(0,2,3.8),(0,-2,3.8)]
# Catmull-Rom sampling keeps the banks and water on exactly the same centerline.
def samples(points,steps=12):
 out=[]
 for i in range(len(points)-1):
  p0=Vector(points[max(0,i-1)]);p1=Vector(points[i]);p2=Vector(points[i+1]);p3=Vector(points[min(len(points)-1,i+2)])
  for j in range(steps):
   t=j/steps;out.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
 out.append(Vector(points[-1]));return out
river_samples=samples(river_points)
def ribbon(points,width,zoffset=0,material='WaterPreview',name='water',side_offset=0):
 vs=[]
 for i,p in enumerate(points):
  d=points[min(i+1,len(points)-1)]-points[max(i-1,0)];normal=Vector((-d.y,d.x,0)).normalized()
  for side in [-1,1]:vs.append(tuple(p+normal*(side_offset+side*width/2)+Vector((0,0,zoffset))))
 fs=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(points)-1)];mesh(name,vs,fs,material)
direct(col,lambda:ribbon(river_samples,4), 'WATER_PREVIEW_RIVER')
for side in [-1,1]:
 direct(col,lambda side=side:ribbon(river_samples,1.0,.25,'StoneLight','fitted coping',side*2.5),'Canal bank')
 # Vertical channel wall beneath coping.
 def bankface(side=side):
  vs=[]
  for i,p in enumerate(river_samples):
   d=river_samples[min(i+1,len(river_samples)-1)]-river_samples[max(i-1,0)];n=Vector((-d.y,d.x,0)).normalized();q=p+n*side*2
   vs.extend([tuple(q+Vector((0,0,.25))),tuple(q-Vector((0,0,1.1)))])
  mesh('fitted canal wall',vs,[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(river_samples)-1)],'StoneLight')
 direct(col,bankface,'Canal bank')
direct(col,lambda:ribbon(river_samples,6,-1.1,'Earth','channel bed'),'River bed')
place(col,'Mountain river mouth',(3,30,3.0))
for x in [-3,3]:place(col,'Waterfall side cliff',(x,-2,0))
place(col,'Waterfall lip',(0,-2,3.8))
direct(col,lambda:mesh('drop',[(-2,-2,3.8),(2,-2,3.8),(2,-2.5,0),(-2,-2.5,0)],[(0,1,2,3)],'WaterPreview'),'WATER_PREVIEW_FALL')
direct(col,lambda:box('pool',(0,-8,-.08),(12,12,.15),'WaterPreview'),'WATER_PREVIEW_POOL')
for i in [2,3]:place(col,'Plunge pool rock surround',(0,-8,0),i*math.pi/2,scale=(1.3,1.3,1))
for x in [-5.2,5.2]:place(col,'Natural rocky bank',(x,-5,0),math.pi/2,scale=(1.3,1,1))
# Bridges cross the canal and join its maintenance paths at two locations.
for idx in [3,1]:
 x,y,_=river_points[idx];d=Vector(river_points[idx+1])-Vector(river_points[idx-1]);yaw=math.atan2(d.x,-d.y)
 rot=Matrix.Rotation(yaw,4,'Z')
 def bridgepos(dx,dy,z):return Vector((x,y,z))+rot@Vector((dx,dy,0))
 place(col,'Stone bridge arch bay',bridgepos(0,0,2.7),yaw)
 place(col,'Stone bridge deck',bridgepos(0,0,6.2),yaw)
 for sy in [-1.35,1.35]:place(col,'Bridge parapet straight',bridgepos(0,sy,6.5),yaw)
 for side in [-1,1]:place(col,'Stone stairs full story',bridgepos(side*7.8,0,4.05),yaw+side*math.pi/2,scale=(1.5,1,2.45/3))
# Append the existing mill assembly, preserving its rotor parent hierarchy.
with bpy.data.libraries.load(str(R/'art/CityBoroughLibrary/City_Boroughs_and_Landmarks.blend'),link=False) as (src,dst):dst.collections=['G Great Waterwheel Mill complete']
mill=dst.collections[0];scene.collection.children.link(mill);bpy.context.view_layer.update();mapping={};matrices={}
for source in mill.objects:
 ob=source.copy();ob.data=source.data;col.objects.link(ob);ob.parent=None;ob.matrix_world=Matrix.Translation(Vector((-6.7,-2,0)))@source.matrix_world;mapping[source]=ob;matrices[source]=ob.matrix_world.copy()
for source,ob in mapping.items():
 if source.parent in mapping:ob.parent=mapping[source.parent];ob.matrix_world=matrices[source]
scene.collection.children.unlink(mill)

col=begin_assembly('C Wisteria gazebo and open pavilion')
direct(col,lambda:box('garden terrace',(0,0,-.2),(23,16,.4),'GardenStone'),'Terrace')
cx=-6
place(col,'Octagonal gazebo floor',(cx,0,0),math.pi/8)
for i in range(8):
 a=math.pi/8+i*math.pi/4;place(col,'Gazebo post',(cx+2.8*math.cos(a),2.8*math.sin(a),.3),a)
 place(col,'Gazebo roof wedge',(cx,0,3.5),a)
 if i!=5:
  mid=a+math.pi/8;place(col,'Gazebo railing bay',(cx+2.8*math.cos(math.pi/8)*math.cos(mid),2.8*math.cos(math.pi/8)*math.sin(mid),.3),mid+math.pi/2)
place(col,'Gazebo roof cap',(cx,0,5.2));place(col,'Stone stairs short',(cx,-3.4,0),scale=(1,.25,.2))
# Open pavilion, with a finished visible ceiling and no solid walls behind arches.
for x in [3,7]:
 for y in [-3,3]:place(col,'Open pavilion arcade',(x,y,0),0 if y<0 else math.pi);place(col,'Pavilion entablature beam',(x,y,3.2))
for x in [1,9]:
 place(col,'Open pavilion arcade',(x,0,0),math.pi/2,scale=(1.5,1,1));place(col,'Pavilion entablature beam',(x,0,3.2),math.pi/2,scale=(1.5,1,1))
for x in [3,7]:
 for y in [-1.5,1.5]:place(col,'Finished pavilion ceiling',(x,y,3.65))
place(col,'Villa low hip roof',(5,0,3.75))
for x in [3,7]:place(col,'Villa pergola bay',(x,-4.6,0),scale=(1.2,.7,1))
# Wisteria pieces remain independent objects for hand placement.
for x in [1.5,4.8,8.3]:place(col,'Wisteria twisting trunk',(x,-5.5,0))
for x in [2,5,8]:
 place(col,'Wisteria foliage canopy',(x,-5.4,3.2));place(col,'Wisteria trained horizontal vine',(x-1.5,-5.4,3.1))
 for j in range(7):place(col,'Wisteria long flower cluster' if j%3==0 else 'Wisteria short flower cluster',(x-1.3+j*.4,-5.9,3.2),j*.7)
for i in range(8):
 a=math.pi/8+i*math.pi/4
 place(col,'Wisteria foliage canopy',(cx+3.05*math.cos(a),3.05*math.sin(a),3.6),a+math.pi/2,scale=(.75,.6,.7))
 for j in range(4):
  t=a+(j-1.5)*.15;place(col,'Wisteria short flower cluster',(cx+3.2*math.cos(t),3.2*math.sin(t),3.5),t)
 if i%2==0:place(col,'Wisteria twisting trunk',(cx+2.8*math.cos(a),2.8*math.sin(a),.3))
for x,y in [(-10,-5),(-10,5),(10,-6),(10,6)]:place(col,'Slender cypress',(x,y,0))
for x in [-7,-3,1,5,9]:place(col,'Hedge straight',(x,7,0))
for x,y in [(3,0),(7,0)]:
 place(col,'Table',(x,y,0));place(col,'Chair',(x,y-1,0));place(col,'Chair',(x,y+1,0),math.pi)
place(col,'Bench',(-6,0,.3))

assembly_info=[{'name':n,'objects':len(c.objects),'mesh_objects':sum(o.type=='MESH' for o in c.objects)} for n,c in assemblies.items()]
ids={c:str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/upper-city/'+c)) for c in category_counts}
for rec in catalog:assets[rec['name']].asset_data.catalog_id=ids[rec['kit']]
for label,cols in [('37 Reused Components',reused),('38 Upper City Assemblies',assemblies)]:
 uid=str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/upper-city/'+label));ids[label]=uid
 for c in cols.values():c.asset_mark();c.asset_data.catalog_id=uid
(OUT/'blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{uid}:{cat}:{cat}' for cat,uid in ids.items())+'\n')
src=helper_path.read_text();exec(compile(src[src.index('def camera_light('):src.index('camera_light(example,')],str(helper_path),'exec'))
renders=[];exportdir=R/'Assets/UpperCityKit';exportdir.mkdir(exist_ok=True,parents=True)
for name,col in assemblies.items():
 sc=bpy.data.scenes.new(name);sc.collection.children.link(col);sc.unit_settings.system='METRIC';bpy.context.window.scene=sc;bpy.context.view_layer.update()
 pts=[o.matrix_world@Vector(v) for o in col.objects if o.type=='MESH' for v in o.bound_box];lo=Vector([min(p[k] for p in pts) for k in range(3)]);hi=Vector([max(p[k] for p in pts) for k in range(3)]);center=(lo+hi)/2;extent=max(hi-lo)
 # Export only assembly geometry and transform parents, not studio lights/cameras.
 bpy.ops.object.select_all(action='DESELECT')
 for o in col.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(exportdir/(name[0]+'_assembly.glb')),export_format='GLB',use_selection=True,export_extras=True)
 camera_light(sc,center+Vector((extent*.85,-extent*1.25,extent)),center,extent*1.55);sc.render.resolution_x=1800;sc.render.resolution_y=1400;sc.render.filepath=str(OUT/(name[0]+'_assembly.png'));renders.append(sc)
for cat in category_counts:
 sc=bpy.data.scenes.new(cat+' Sheet');records=[r for r in catalog if r['kit']==cat]
 for i,r in enumerate(records):
  ob=bpy.data.objects.new(r['name'],None);sc.collection.objects.link(ob);ob.instance_type='COLLECTION';ob.instance_collection=assets[r['name']];ob.location=((i%4)*8,(i//4)*8,0);scale=min(2,4.8/max(r['dimensions_m']));ob.scale=(scale,)*3
  td=bpy.data.curves.new('Caption','FONT');td.body=r['name'];td.size=.21;td.materials.append(M['Canvas']);txt=bpy.data.objects.new('Caption',td);sc.collection.objects.link(txt);txt.location=ob.location+Vector((-3,-2.7,0))
 rows=math.ceil(len(records)/4);camera_light(sc,(20,-32,50),(12,(rows-1)*4,0),max(40,rows*10));sc.render.resolution_x=1700;sc.render.resolution_y=1400;sc.render.filepath=str(OUT/(cat[:2]+'_contact_sheet.png'));renders.append(sc)
bpy.context.window.scene=bpy.data.scenes['C Wisteria gazebo and open pavilion']
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.shading.type='MATERIAL';area.spaces.active.region_3d.view_location=(0,0,2);area.spaces.active.region_3d.view_distance=32
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Upper_City_Waterways_and_Gardens.blend'))
(OUT/'component_inventory.json').write_text(json.dumps({'count':40,'categories':category_counts,'components':catalog,'reused_components':list(reused),'assemblies':assembly_info,'river_points_blender':river_points},indent=2)+'\n')
print('UPPER_CITY_SAVED',flush=True)
for sc in renders:bpy.context.window.scene=sc;bpy.ops.render.render(write_still=True)
print('UPPER_CITY_RENDERED',flush=True)
