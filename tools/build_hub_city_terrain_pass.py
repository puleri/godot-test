"""Metre-scale urban landform and circulation study built from the user's saved farm world."""
import bpy,bmesh,math,json,random,sys
from pathlib import Path
from mathutils import Vector,Matrix
from collections import defaultdict
R=Path(__file__).resolve().parents[1];OUT=R/'art/HubCityMaster'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Hub_City_World_Farms.blend'));sc=bpy.context.scene;random.seed(719)
core=bpy.data.objects['City terrain — 400 x 400 meters'];restore=core.matrix_world.inverted();old_scale=list(core.matrix_world.to_scale())
# Normalize every scene object's world transform exactly once, in parent-first order.
saved={o:o.matrix_world.copy() for o in sc.objects}
def depth(o):
 n=0
 while o.parent:n+=1;o=o.parent
 return n
for o in saved:
 if o.parent not in saved:o.matrix_world=restore@saved[o]
bpy.context.view_layer.update();sc.unit_settings.system='METRIC';sc.unit_settings.scale_length=1;sc.unit_settings.length_unit='METERS'
original={o.name for o in sc.objects}
# Snapshot the saved terrain before sculpting, including user-authored changes.
base={(round(v.co.x),round(v.co.y)):v.co.z for v in core.data.vertices}
def baseh(x,y):
 x=max(-200,min(199.999,x));y=max(-180,min(219.999,y));i=math.floor(x);j=math.floor(y);u=x-i;v=y-j
 return (base[(i,j)]*(1-u)+base[(i+1,j)]*u)*(1-v)+(base[(i,j+1)]*(1-u)+base[(i+1,j+1)]*u)*v

def collection(name):
 c=bpy.data.collections.new(name);sc.collection.children.link(c);return c
routescol=collection('19 TERRAIN PASS — rebuilt routes and stairs');foundationcol=collection('20 TERRAIN PASS — foundations and retaining walls');rockscol=collection('21 TERRAIN PASS — shore rocks and planted folds');refcol=collection('22 TERRAIN PASS — scale references and cameras')
oldroutes=bpy.data.collections.get('03 ROUTES — streets bridges and switchbacks');oldroutes.hide_render=True;oldroutes.hide_viewport=True
M={k:bpy.data.materials.get(k) for k in ['Terrain','Road','Bridge','Quay','Stone','Water','Label','Timber']}
if not M['Stone']:M['Stone']=M['Quay']
def mesh(name,vs,fs,col,mat):
 d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update();d.materials.append(M[mat]);o=bpy.data.objects.new(name,d);col.objects.link(o);return o

def box(name,p,size,col,mat):
 x,y,z=p;a,b,c=[s/2 for s in size]
 return mesh(name,[(x+sx*a,y+sy*b,z+sz*c) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],col,mat)
def smooth(t):t=max(0,min(1,t));return t*t*(3-2*t)
def gauss(x,y,cx,cy,rx,ry):return math.exp(-((x-cx)/rx)**2-((y-cy)/ry)**2)
def boundary(x,y):return smooth(min(x+200,200-x,y+180,220-y)/28)
def warp(x,y):
 # Shared horizontal deformation keeps terrain, water, quays and parcels aligned.
 a=boundary(x,y)*math.exp(-((y+45)/90)**2)
 return (x+a*(3.7*math.sin(y/19)+1.8*math.sin((x+y)/14)),y+a*(3.0*math.sin(x/23)+1.4*math.cos((x-y)/13)))
def riverx(y):return -40+30*math.sin(y/60)
islands=[('West artisans',(-65,-55),(27,20)),('Merchant island',(-5,-35),(32,24)),('Bathhouse island',(58,-70),(30,26)),('South homes',(4,-115),(24,18)),('Fisher island',(-70,-115),(21,15))]
def island(x,y):
 for name,(cx,cy),(rx,ry) in islands:
  a=math.atan2((y-cy)/ry,(x-cx)/rx);f=1+.10*math.sin(3*a+cx*.03)+.055*math.cos(5*a)
  r=math.sqrt(((x-cx)/rx)**2+((y-cy)/ry)**2)/f
  if r<=1:return name,r
 return None,None

def landform(x,y):
 old=baseh(x,y);name,r=island(x,y)
 if old<0:return old
 if name:
  uplift={'Merchant island':2.5,'West artisans':1.4,'Bathhouse island':1.1,'South homes':.6,'Fisher island':.8}[name]
  return old+uplift*smooth((.88-r)/.55)
 b=boundary(x,y)
 h=old+10*gauss(x,y,-130,55,65,80)+8*gauss(x,y,-155,130,40,58)
 h+=9*gauss(x,y,55,65,48,60)+5*gauss(x,y,125,50,45,60)
 # Low riverbank shelves and a shallow ravine between the civic ridge and river.
 h-=3*gauss(x,y,-52,75,12,58)
 h+=1.4*math.sin(x/18+y/31)*gauss(x,y,-105,80,95,105)
 # Compound remains a coherent elevated estate, with its approach sculpted separately.
 dx=max(70-x,0,x-158);dy=max(65-y,0,y-150);t=1-smooth(max(dx,dy)/18)
 h=h*(1-t)+34*t
 # Historic civic platform leaves a flat public square and level hall footprint.
 dx=max(abs(x+105)-17,0);dy=max(abs(y-62)-20,0);t=1-smooth(max(dx,dy)/10)
 h=h*(1-t)+18*t
 # Working mill platform remains below the upper water intake.
 dx=max(abs(x-(riverx(55)-11))-11,0);dy=max(abs(y-53)-9,0);t=1-smooth(max(dx,dy)/5)
 h=h*(1-t)+2*t
 return old+(h-old)*b

# Explicit connected network; first routes form the detailed lagoon/civic/gate spine.
H={'Market':(-5,-35,6),'Artisans':(-65,-55,5),'Apartments':(-145,-35,8),'Civic':(-105,49,18),'North':(-95,150,20),'Mill':(-38,44,5),'Upper gate':(70,95,34),'Gardens':(112,110,34),'Bathhouse':(58,-70,4.6),'South':(4,-115,4.4),'Fisher':(-70,-115,4.4),'Docks':(150,-45,4)}
routes=[]
def route(name,a,b,pts,width=4,bridge=False):routes.append({'name':name,'from':a,'to':b,'points':[Vector(p) for p in pts],'width':width,'bridge':bridge})
route('Market island bridge','Market','Artisans',[H['Market'],(-30,-35,6.5),(-43,-45,6.5),H['Artisans']],5,True)
route('Artisan west crossing','Artisans','Apartments',[H['Artisans'],(-84,-51,6),(-110,-42,7),H['Apartments']],5,True)
route('Western contour avenue','Apartments','Civic',[H['Apartments'],(-130,-32,8.5),(-130,0,11),(-135,25,13.5),(-140,50,15.5),(-124,49,18),H['Civic']],6)
route('Civic ridge promenade','Civic','Upper gate',[H['Civic'],(-127,56,18),(-127,85,18),(-60,105,16),(-36,100,14),(-25,85,14),(5,85,14),(20,65,16),(48,52,18),(62,52,20),(62,70,24),(40,70,26),(40,95,30),H['Upper gate']],5)
route('Old north contour road','Civic','North',[H['Civic'],(-140,67,18),(-147,103,21),(-128,135,22),H['North']],5)
route('Mill delivery lane','Civic','Mill',[H['Civic'],(-88,49,18),(-85,39,16),(-65,39,12),(-48,39,8),H['Mill']],4)
route('Mill entry steps','Mill','Mill',[H['Mill'],(-34,47,3),(-29,47,2)],3)
route('Upper garden promenade','Upper gate','Gardens',[H['Upper gate'],(90,95,34),(112,95,34),H['Gardens']],5)
route('Eastern hillside descent','Gardens','Docks',[H['Gardens'],(165,110,30),(165,70,22),(145,70,18),(145,30,11),(165,30,7),(165,-20,4),H['Docks']],5)
route('Bathhouse crossing','Market','Bathhouse',[H['Market'],(18,-45,6.5),(34,-55,6.5),H['Bathhouse']],5,True)
route('East docks crossing','Bathhouse','Docks',[H['Bathhouse'],(81,-61,6),(111,-51,6),(139,-46,6),H['Docks']],5,True)
route('South island bridge','Market','South',[H['Market'],(-3,-55,6),(0,-98,6),H['South']],4,True)
route('Fisher bridge','Artisans','Fisher',[H['Artisans'],(-67,-71,6),(-69,-101,6),H['Fisher']],4,True)
route('Lagoon south crossing','Fisher','South',[H['Fisher'],(-52,-115,6),(-17,-115,6),H['South']],4,True)
for name,(cx,cy),(rx,ry) in islands:
 for axis in [0,1]:
  coords=[(cx-rx*.65,cy),(cx,cy),(cx+rx*.65,cy)] if axis==0 else [(cx,cy-ry*.60),(cx,cy),(cx,cy+ry*.60)]
  route(name+' neighborhood lane '+str(axis),name,name,[(x,y,landform(x,y)+.08) for x,y in coords],3)
segments=[]
for r in routes:
 for a,b in zip(r['points'],r['points'][1:]):segments.append((a,b,r))
def profile_height(a,b,r,t):
 length=math.hypot(b.x-a.x,b.y-a.y);inset=min(r['width']/2+.3,length*.15);u=max(0,min(1,(t*length-inset)/(length-2*inset)));return a.z+(b.z-a.z)*u
def near(x,y,a,b):
 dx=b.x-a.x;dy=b.y-a.y;t=max(0,min(1,((x-a.x)*dx+(y-a.y)*dy)/(dx*dx+dy*dy)));return math.hypot(x-a.x-t*dx,y-a.y-t*dy),a.z+t*(b.z-a.z),t

# Move whole building assemblies, preserving their editable child geometry.
def descendants(root):
 stack=list(root.children);out=[]
 while stack:
  o=stack.pop();out.append(o);stack.extend(o.children)
 return out

def bounds(root):
 points=[]
 for o in ([root]+descendants(root)):
  if o.type=='MESH':points.extend(o.matrix_world@Vector(v) for v in o.bound_box)
 if not points:return None
 return [min(p[i] for p in points) for i in range(3)],[max(p[i] for p in points) for i in range(3)]
plots=[];moved=[];displaced=[]
for cname in ['05 LANDMARKS — existing component assemblies','06 DISTRICTS — linked building masses']:
 c=bpy.data.collections[cname]
 for o in list(c.objects):
  if o.parent is not None:continue
  p=o.matrix_world.translation.copy();x,y,z=p
  if not(-195<x<195 and -175<y<210):continue
  bb=bounds(o)
  if not bb:continue
  lo,hi=bb;w=hi[0]-lo[0];d=hi[1]-lo[1]
  # Fortification pieces share the estate's eight-metre rise, retaining relative heights.
  fort=70-.1<=x<=158.1 and 64<=y<=151 and z>=25
  if fort:
   nz=z+8
  elif 'Mill complete' in o.name:nz=z
  else:
   if cname.startswith('06') and not island(x,y)[0]:
    dist,aa,bb0,rr=min(((near(x,y,a,b)[0],a,b,r) for a,b,r in segments),key=lambda item:item[0])
    clearance=rr['width']/2+max(w,d)/2+1
    if dist<clearance:
     dx=bb0.x-aa.x;dy=bb0.y-aa.y;length=math.hypot(dx,dy);nx=-dy/length;ny=dx/length
     side=1 if (x-aa.x)*nx+(y-aa.y)*ny>=0 else -1
     tx=x+side*nx*(clearance-dist);ty=y+side*ny*(clearance-dist)
     if baseh(tx,ty)>0:x,y=tx,ty;displaced.append(o.name)
   samples=[landform(x+sx*w*.4,y+sy*d*.4) for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1),(0,0)]]
   nz=math.ceil(max(samples)*2)/2+.12
   if 'Clock Hall' in o.name:nz=18.12
   if 'Courtyard apartment' in o.name:nz=max(8,nz)
   if 'Warehouse' in o.name:nz=max(4,nz)
   # Broad landmark footprints and small individual plots receive their own level pad.
   plots.append((x,y,w/2+.25,d/2+.25,nz-.12,o.name))
  wx,wy=warp(x,y);matrix=o.matrix_world.copy();matrix.translation=Vector((wx,wy,nz));o.matrix_world=matrix
  moved.append({'name':o.name,'old_position':list(p),'position':[wx,wy,nz]})
bpy.context.view_layer.update()
# Connect the raised apartment courtyard to the western approach with its own entry stair.
apt=next(p for p in plots if p[5]=='E Courtyard apartment complex')
route('Apartment court entrance','Apartments','Apartments',[H['Apartments'],(-147,-28,9.3),(-147,-22,apt[4]+.12)],2.4)
for aa,bb in zip(routes[-1]['points'],routes[-1]['points'][1:]):segments.append((aa,bb,routes[-1]))
# Spatial lookup keeps fine-grained terrain edits practical across hundreds of parcels.
plotgrid=defaultdict(list)
for p in plots:
 x,y,rx,ry,z,name=p
 for i in range(math.floor((x-rx-3)/10),math.floor((x+rx+3)/10)+1):
  for j in range(math.floor((y-ry-3)/10),math.floor((y+ry+3)/10)+1):plotgrid[(i,j)].append(p)
routegrid=defaultdict(list)
for a,b,r in segments:
 pad=r['width']/2+4
 for i in range(math.floor((min(a.x,b.x)-pad)/10),math.floor((max(a.x,b.x)+pad)/10)+1):
  for j in range(math.floor((min(a.y,b.y)-pad)/10),math.floor((max(a.y,b.y)+pad)/10)+1):routegrid[(i,j)].append((a,b,r))
def finalheight(x,y):
 h=landform(x,y)
 if h<0:return h
 cell=(math.floor(x/10),math.floor(y/10))
 for px,py,rx,ry,z,name in plotgrid[cell]:
  d=max(abs(x-px)-rx,abs(y-py)-ry,0);t=1-smooth(d/.9);h=h*(1-t)+z*t
 for a,b,r in routegrid[cell]:
  d,z,u=near(x,y,a,b);z=profile_height(a,b,r,u);t=1-smooth((d-r['width']/2)/2)
  # Bridge decks leave the navigable channel and low banks open underneath.
  if r['bridge'] and d<r['width']/2 and baseh(x,y)<0:continue
  h=h*(1-t)+(z-.65)*t
 return h
for v in core.data.vertices:
 x,y,_=v.co;v.co=(*warp(x,y),finalheight(x,y))
core.data.update()
for polygon in core.data.polygons:polygon.use_smooth=True
core['terrain_pass']='District ridges, river shelves and individual building pads; units metres.'
# Shoreline and water are deformed together, preserving water heights and the 7m-to-2m drop.
for cname in ['02 WATER — lagoon 2m, river 7m','04 QUAYS — island edges']:
 for o in bpy.data.collections[cname].objects:
  if o.type!='MESH':continue
  for v in o.data.vertices:
   p=o.matrix_world@v.co;p.x,p.y=warp(p.x,p.y);v.co=o.matrix_world.inverted()@p
  o.data.update()
# Refit core vegetation to new slopes; old street lights get repositioned below.
for o in bpy.data.collections['07 VEGETATION — representative planting'].objects:
 if o.parent is None:
  p=o.matrix_world.translation.copy();x,y=p.x,p.y
  if -200<x<200 and -180<y<220:
   p.x,p.y=warp(x,y);p.z=finalheight(x,y);m=o.matrix_world.copy();m.translation=p;o.matrix_world=m

# Foundations show the changes in level, rather than leaving raised buildings floating.
for x,y,rx,ry,z,name in plots:
 bottom=min(finalheight(x+sx*rx,y+sy*ry) for sx,sy in [(-1,-1),(1,-1),(1,1),(-1,1)])-.4
 if bottom>=z-.05:bottom=z-.45
 verts=[]
 for zz in [bottom,z+.12]:
  for xx,yy in [(x-rx,y-ry),(x+rx,y-ry),(x+rx,y+ry),(x-rx,y+ry)]:verts.append((*warp(xx,yy),zz))
 mesh('Stepped plot base — '+name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],foundationcol,'Quay')
# Masonry terrace edges at civic square and alongside the formal upper ascent.
for pts,z in [([(-123,39),(-87,39)],18),([(-123,39),(-123,77)],18),([(36,70),(36,95)],30),([(38,99),(69,99)],34)]:
 for a,b in zip(pts,pts[1:]):
  length=math.dist(a,b);n=max(1,math.ceil(length/2))
  for i in range(n):
   x=a[0]+(b[0]-a[0])*(i+.5)/n;y=a[1]+(b[1]-a[1])*(i+.5)/n;lo=min(landform(x,y),z-1)-.5;wx,wy=warp(x,y)
   if abs(x+123)<1 and abs(y-49)<5.5:continue
   ob=box('Terrace retaining masonry',(wx,wy,(lo+z)/2),(length/n+.02,.5,z-lo),foundationcol,'Quay')
   angle=math.atan2(b[1]-a[1],b[0]-a[0]);co=math.cos(angle);si=math.sin(angle)
   for vertex in ob.data.vertices:
    dx=vertex.co.x-wx;dy=vertex.co.y-wy;vertex.co.x=wx+co*dx-si*dy;vertex.co.y=wy+si*dx+co*dy
# Physical route surfaces, closed step volumes, landings and bridge piers.
reports=[];walk_samples=[];spine_names={'Market island bridge','Artisan west crossing','Western contour avenue','Civic ridge promenade'}
def slab(name,a,b,width,topa,topb,thick=.75):
 dx=b.x-a.x;dy=b.y-a.y;L=math.hypot(dx,dy);nx=-dy/L*width/2;ny=dx/L*width/2
 if any(name.startswith(prefix) for prefix in spine_names):
  for k in range(max(1,math.ceil(L))):
   t=(k+.5)/max(1,math.ceil(L));x=a.x+(b.x-a.x)*t;y=a.y+(b.y-a.y)*t;z=topa+(topb-topa)*t
   for offset in [-.65,0,.65]:
    sx=x+nx/(width/2)*offset;sy=y+ny/(width/2)*offset;walk_samples.append({'route':name,'position':[*warp(sx,sy),z]})
 points=[(a.x-nx,a.y-ny,topa),(a.x+nx,a.y+ny,topa),(b.x+nx,b.y+ny,topb),(b.x-nx,b.y-ny,topb)]
 v=[(*warp(x,y),z-thick) for x,y,z in points]+[(*warp(x,y),z) for x,y,z in points]
 return mesh(name,v,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],routescol,'Road')
for r in routes:
 report={'name':r['name'],'from':r['from'],'to':r['to'],'width_m':r['width'],'segments':[]}
 for a,b in zip(r['points'],r['points'][1:]):
  full_length=math.hypot(b.x-a.x,b.y-a.y);inset=min(r['width']/2+.3,full_length*.15)
  start=a+(b-a)*(inset/full_length);start.z=a.z
  finish=b-(b-a)*(inset/full_length);finish.z=b.z
  slab(r['name']+' entry landing',a,start,r['width'],a.z,a.z)
  slab(r['name']+' exit landing',finish,b,r['width'],b.z,b.z)
  a,b=start,finish
  length=math.hypot(b.x-a.x,b.y-a.y);rise=b.z-a.z;grade=abs(rise)/length
  # Bridges are ramps; steeper land climbs use real risers and intermediate landings.
  stair=grade>.085 and not r['bridge']
  info={'length_m':length,'rise_m':rise,'kind':'stairs' if stair else 'ramp','grade':grade,'a':list(a),'b':list(b)}
  if stair:
   count=math.ceil(abs(rise)/.17);landings=(count-1)//12;landingrun=1.5;run=(length-landings*landingrun)/count
   assert run>=.28,(r['name'],run)
   direction=(b-a)/length;travel=0
   for k in range(count):
    p=a+direction*travel;q=a+direction*(travel+run);top=a.z+rise*(k+1)/count
    slab(r['name']+' step',p,q,r['width'],top,top,.8);travel+=run
    if (k+1)%12==0 and k+1<count:
     p=a+direction*travel;q=a+direction*(travel+landingrun);slab(r['name']+' landing',p,q,r['width'],top,top,.8);travel+=landingrun
   info.update({'risers':count,'riser_m':abs(rise)/count,'tread_m':run,'landings':landings})
  else:
   count=max(1,math.ceil(length/3))
   for k in range(count):
    p=a+(b-a)*k/count;q=a+(b-a)*(k+1)/count;slab(r['name']+' paved segment',p,q,r['width'],p.z,q.z)
  if r['bridge'] or (r['name']=='Civic ridge promenade' and a.x==-25):
   for k in range(max(1,int(length/8))):
    p=a+(b-a)*(k+.5)/max(1,int(length/8))
    if baseh(p.x,p.y)<0:
     x,y=warp(p.x,p.y);box('Crossing masonry pier',(x,y,(p.z-1)/2),(1.1,1.1,p.z+1),routescol,'Quay')
  # Rounded paving at joins closes wedges between differently angled segments.
  report['segments'].append(info)
 for index,p in enumerate(r['points']):
  adjacent=[math.hypot(q.x-p.x,q.y-p.y) for q in r['points'][max(0,index-1):index+2] if (q-p).length>.001]
  radius=min(r['width']/2,min(adjacent)*.15);vs=[(*warp(p.x,p.y),p.z+.015)]+[(*warp(p.x+radius*math.cos(i*math.tau/16),p.y+radius*math.sin(i*math.tau/16)),p.z+.015) for i in range(16)]
  mesh('Route joint — '+r['name'],vs,[(0,i+1,(i+1)%16+1) for i in range(16)],routescol,'Road')
 reports.append(report)
# Public square terrace with clear access in front of Clock Hall.
box('Civic square paving',(*warp(-105,49),18.03),(29,17,.12),routescol,'Road')
# Selectively exposed shoreline rock clusters, kept away from quay walking strips.
for i in range(70):
 a=random.uniform(0,math.tau);cx,cy=(-65,-55) if i%2 else (-5,-35);rx,ry=(27,20) if i%2 else (32,24);f=1+.10*math.sin(3*a+cx*.03)+.055*math.cos(5*a)
 x=cx+rx*f*1.045*math.cos(a);y=cy+ry*f*1.045*math.sin(a)
 if any(near(x,y,aa,bb)[0]<rr['width']/2+3 for aa,bb,rr in segments):continue
 wx,wy=warp(x,y);rad=random.uniform(.6,1.7);height=random.uniform(1,2.5);n=6;vs=[]
 for zz,scale in [(1.4,1),(1.4+height,.6)]:
  for k in range(n):ang=k*math.tau/n;vs.append((wx+rad*scale*math.cos(ang),wy+rad*.75*scale*math.sin(ang),zz+random.uniform(-.15,.15)))
 fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(k,(k+1)%n,(k+1)%n+n,k+n) for k in range(n)]
 mesh('Exposed shoreline rock',vs,fs,rockscol,'Stone')
# Existing route lamp geometry was generated in world coordinates: relocate lamp/light pairs to new routes.
lightcol=bpy.data.collections['08 LIGHTING'];old_lights=[o for o in lightcol.objects if o.type=='LIGHT' and o.data.type=='POINT'];old_lamps=[o for o in lightcol.objects if o.type=='MESH']
positions=[]
for r in routes[:9]:
 for a,b in zip(r['points'],r['points'][1:]):
  L=math.hypot(b.x-a.x,b.y-a.y)
  for k in range(max(1,int(L/18))):p=a+(b-a)*(k+.5)/max(1,int(L/18));positions.append(Vector((*warp(p.x,p.y),p.z+3)))
for i,o in enumerate(old_lights):
 if i<len(positions):o.location=positions[i]
 else:o.hide_render=True;o.hide_viewport=True
for i,o in enumerate(old_lamps):
 if i<len(positions):
  center=sum((o.matrix_world@Vector(c) for c in o.bound_box),Vector())/8;m=o.matrix_world.copy();m.translation+=positions[i]-center;o.matrix_world=m
 else:o.hide_render=True;o.hide_viewport=True
# Recalculate outward normals on closed generated geometry.
for col in [routescol,foundationcol,rockscol]:
 for ob in col.objects:
  if ob.type=='MESH':
   bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
# Height reference stands at the civic plaza, with a true 1.8m overall height.
px,py=warp(-114,45);pz=18.10
box('Player scale torso 1.8m total',(px,py,pz+1.12),(.45,.24,.65),refcol,'Label')
box('Player scale head',(px,py,pz+1.65),(.25,.25,.30),refcol,'Label')
for dx in [-.12,.12]:box('Player scale leg',(px+dx,py,pz+.39),(.15,.18,.78),refcol,'Label')
# Camera and per-file workspaces; global user preferences are not overwritten.
def camera(name,pos,target,lens=45,ortho=None):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);refcol.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-Vector(pos)).to_track_quat('-Z','Y').to_euler();d.lens=lens;d.clip_end=6000
 if ortho:d.type='ORTHO';d.ortho_scale=ortho
 return o
hero=camera('11 Terrain redesign overview',(300,-370,300),(-30,35,12),46)
close=camera('12 Civic terrace and upper ascent',(-220,-125,145),(-40,65,15),48)
ped=camera('13 Civic pedestrian at 1.8m',(*warp(-105,49),19.89),(*warp(-105,69),23),30)
plan=camera('14 Terrain redesign plan',(0,20,600),(0,20,0),ortho=540)
sc.camera=hero
for c in [bpy.data.collections.get('09 PLAN LABELS')]:
 if c:c.hide_viewport=True;c.hide_render=True
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.clip_start=.1;space.clip_end=6000;space.region_3d.view_perspective='CAMERA';space.region_3d.view_location=(-30,35,12);space.region_3d.view_distance=400
# Two editing workspaces share the same scene, with purpose-appropriate view ranges.
try:
 overview=bpy.context.window.workspace;overview.name='City Overview'
 before_workspaces=set(bpy.data.workspaces)
 bpy.ops.workspace.duplicate()
 detail=next(w for w in bpy.data.workspaces if w not in before_workspaces);detail.name='Detail Editing'
 bpy.context.window.workspace=detail
 for area in detail.screens[0].areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active;space.clip_start=.05;space.clip_end=250;space.region_3d.view_perspective='PERSP';space.region_3d.view_location=(-105,55,18);space.region_3d.view_distance=42;space.region_3d.view_rotation=close.rotation_euler.to_quaternion()
 bpy.context.window.workspace=overview
except Exception as error:print('WORKSPACE_SETUP',str(error),flush=True)
# Custom properties keep inspection guidance visible without changing app-wide preferences.
sc['editing_tip']='Use Frame Selected on a building or selected terrain vertices, then Shift during transforms for fine control. Overview clip range: 0.1–6000 m; detail: 0.05–250 m.'
sc['world_units']='1 Blender unit = 1 metre. Source global scale and translation reversed.'
report={'source':'Hub_City_World_Farms.blend','source_scale_reversed':old_scale,'water_levels_m':{'lagoon':2,'upper_river':7,'mill_drop':5},'district_levels_m':{'merchant_hub':6,'civic_square':18,'upper_gate':34},'building_assemblies_refitted':len(moved),'building_plots':len(plots),'buildings_shifted_clear_of_roads':len(displaced),'routes':reports,'walk_samples':walk_samples,'hubs':H,'moved_buildings':moved,'remaining_work':'Gameplay collision/navigation test, final entrance-by-entrance detailing, railings and countryside landform refinement.'}
(OUT/'terrain_pass_manifest.json').write_text(json.dumps(report,indent=2)+'\n')
sc.render.resolution_x=1800;sc.render.resolution_y=1300;sc.cycles.samples=20;bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hub_City_Terrain_Study.blend'));print('TERRAIN_STUDY_SAVED',len(moved),len(plots),flush=True)
if '--no-render' in sys.argv:sys.exit(0)
for cam,file in [(hero,'terrain_study_overview.png'),(close,'terrain_study_civic.png'),(ped,'terrain_study_pedestrian.png')]:
 sc.camera=cam;sc.render.filepath=str(OUT/file);bpy.ops.render.render(write_still=True)
print('TERRAIN_STUDY_RENDERED',flush=True)
