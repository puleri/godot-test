"""Editable hub-town modular kit. Run with Blender --background --python this_file."""
from pathlib import Path
import bpy, bmesh, math, json, random
from mathutils import Vector
R=Path(__file__).resolve().parents[1]; OUT=R/'art/HubTownLibrary'; OUT.mkdir(exist_ok=True,parents=True)
(OUT/'.gdignore').touch()
bpy.ops.wm.read_factory_settings(use_empty=True)
random.seed(19)
scene=bpy.context.scene; scene.name='00 Component Library'
scene.unit_settings.system='METRIC'
M={}
def mat(name,color,metal=0,rough=.8,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
 if emit: p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emit
 M[name]=m; return m
for a in [('Stone',(.29,.31,.33)),('StoneLight',(.42,.43,.41)),('Plaster',(.65,.55,.37)),('Timber',(.16,.075,.033)),('Wood',(.31,.16,.067)),('Slate',(.07,.11,.17)),('Iron',(.055,.065,.075)),('Glass',(.26,.43,.56)),('Amber',(.95,.43,.08)),('Canvas',(.71,.59,.37)),('Red',(.42,.09,.075)),('Blue',(.055,.14,.23)),('Green',(.10,.25,.085)),('Leaf',(.20,.36,.105)),('Skin',(.52,.31,.19)),('Bread',(.58,.32,.10)),('Clay',(.45,.22,.12)),('Water',(.06,.20,.26))]:
 mat(a[0],a[1],metal=.65 if a[0]=='Iron' else 0,rough=.25 if a[0] in ('Glass','Water') else .8,emit=2 if a[0]=='Amber' else 0)
# Read the author's stone palette rather than replacing it with a new color guess.
with bpy.data.libraries.load(str(R/'ComponentLibrary/foundation.blend'),link=False) as (src,dst):
 dst.materials=[n for n in ('stone_wall','Stone','wood') if n in src.materials]
for source,target in [('stone_wall','Stone'),('Stone','StoneLight')]:
 material=next((m for m in dst.materials if m and m.name==source),None)
 if material and material.node_tree:
  ramp=next((n for n in material.node_tree.nodes if n.type=='VALTORGB'),None)
  if ramp:
   color=ramp.color_ramp.evaluate(ramp.inputs[0].default_value)
   M[target].diffuse_color=color; M[target].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=color
catalog=[]; assets={}; category_counts={}; current=None; pieces=[]
def mesh(name,verts,faces,material):
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
 ob=bpy.data.objects.new(name,me); current.objects.link(ob); ob.data.materials.append(M[material]); pieces.append(ob); return ob

def box(name,loc,size,material='Timber',rot=None):
 x,y,z=[v/2 for v in size]
 ob=mesh(name,[(-x,-y,-z),(x,-y,-z),(x,y,-z),(-x,y,-z),(-x,-y,z),(x,-y,z),(x,y,z),(-x,y,z)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],material)
 ob.location=loc
 if rot: ob.rotation_euler=rot
 return ob

def cyl(name,loc,r,depth,material='Timber',n=12,r2=None):
 r2=r if r2 is None else r2
 v=[(rr*math.cos(i*2*math.pi/n),rr*math.sin(i*2*math.pi/n),z) for rr,z in [(r,-depth/2),(r2,depth/2)] for i in range(n)]
 f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 ob=mesh(name,v,f,material); ob.location=loc; return ob

def beam(name,a,b,width=.12,material='Timber',depth=None):
 a,b=Vector(a),Vector(b); ob=box(name,(a+b)/2,(width,depth or width,(b-a).length),material); ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return ob

def uvball(name,loc,scale,material,n=10,rings=6):
 vs=[(0,0,-scale[2])]
 for j in range(1,rings):
  lat=-math.pi/2+math.pi*j/rings
  for i in range(n):
   t=2*math.pi*i/n; vs.append((scale[0]*math.cos(lat)*math.cos(t),scale[1]*math.cos(lat)*math.sin(t),scale[2]*math.sin(lat)))
 vs.append((0,0,scale[2])); top=len(vs)-1
 fs=[(0,1+(i+1)%n,1+i) for i in range(n)]
 for j in range(rings-2):
  for i in range(n):
   a=1+j*n+i; b=1+j*n+(i+1)%n; fs.append((a,b,b+n,a+n))
 fs.extend((top,1+(rings-2)*n+i,1+(rings-2)*n+(i+1)%n) for i in range(n))
 ob=mesh(name,vs,fs,material); ob.location=loc; return ob

def ring(name,loc,outer,inner,height,material='StoneLight',n=16):
 vs=[]
 for z,r in [(-height/2,outer),(-height/2,inner),(height/2,outer),(height/2,inner)]:
  vs += [(r*math.cos(i*2*math.pi/n),r*math.sin(i*2*math.pi/n),z) for i in range(n)]
 fs=[]
 for i in range(n):
  j=(i+1)%n; fs.extend([(i,j,2*n+j,2*n+i),(n+j,n+i,3*n+i,3*n+j),(2*n+i,2*n+j,3*n+j,3*n+i),(j,i,n+i,n+j)])
 ob=mesh(name,vs,fs,material); ob.location=loc; return ob

def vessel(name,profile,material='Clay',n=16):
 # Revolve a closed cross-section to produce a real interior and rim.
 vs=[(r*math.cos(i*2*math.pi/n),r*math.sin(i*2*math.pi/n),z)
     for r,z in profile for i in range(n)]
 fs=[]
 for j in range(len(profile)):
  k=(j+1)%len(profile)
  for i in range(n):
   q=(i+1)%n; fs.append((j*n+i,j*n+q,k*n+q,k*n+i))
 return mesh(name,vs,fs,material)

def basket():
 vessel('woven bowl',[(.02,0),(.25,0),(.35,.4),(.31,.4),(.21,.05),(.02,.05)],'Canvas')
 for j in range(8):
  z=.05+j*.045; r=.25+z*.25
  ring('woven horizontal band',(0,0,z),r+.012,r-.006,.022,'Wood',16)
 for i in range(16):
  t=i*math.pi/8
  beam('woven upright',(.25*math.cos(t),.25*math.sin(t),.02),(.35*math.cos(t),.35*math.sin(t),.4),.018,'Timber')
 ring('rim',(0,0,.42),.37,.30,.07,'Timber')

def retaining_corner(inside):
 box('corner',(0,0,1.5),(1,.6,3),'Stone'); box('return',(.2,.8,1.5),(.6,1,3),'Stone')
 if inside:
  for ob in pieces: ob.location.y=-ob.location.y

def start(cat,name,notes=''):
 global current,pieces
 current=bpy.data.collections.new(name); scene.collection.children.link(current); pieces=[]
 return (cat,name,notes)
def finish(spec):
 cat,name,notes=spec
 bpy.context.view_layer.update()
 bpy.ops.object.select_all(action='DESELECT')
 for ob in pieces: ob.select_set(True)
 bpy.context.view_layer.objects.active=pieces[0]
 if len(pieces)>1: bpy.ops.object.join()
 ob=bpy.context.object; ob.name=name+' | editable mesh'
 # Bake primitive transforms, keep final mesh in local coordinates around its base pivot.
 scene.cursor.location=(0,0,0); bpy.ops.object.origin_set(type='ORIGIN_CURSOR'); bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
 bm=bmesh.new(); bm.from_mesh(ob.data); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(ob.data); bm.free()
 bevel=ob.modifiers.new('Polish bevel (editable)','BEVEL'); bevel.width=.015; bevel.segments=1
 bevel.limit_method='ANGLE'
 ob['module']=name; ob['kit']=cat
 index=category_counts.get(cat,0); category_counts[cat]=index+1
 ci=list(category_counts).index(cat); pos=Vector(((index%8)*7,ci*56+(index//8)*7,0))
 ob.location=pos; current.instance_offset=pos
 current.asset_mark(); current.asset_data.description=notes or 'Editable hub-town module. Meters; Z up; facade -Y; base-center origin.'
 dims=[round(v,4) for v in ob.dimensions]
 record={'name':name,'kit':cat,'dimensions_m':dims,'vertices':len(ob.data.vertices),'faces':len(ob.data.polygons),'gallery_position':list(pos),'notes':notes,'collection':current.name}
 catalog.append(record); assets[name]=current
 return ob

def asset(cat,name,fn,notes=''):
 s=start(cat,name,notes); fn(); return finish(s)

def wall(kind='plain',upper=False,width=4):
 h=3; d=.30; surface='Plaster' if upper else 'Stone'
 if kind=='plain': box('wall field',(0,0,h/2),(width,d,h),surface)
 else:
  ow,oh,bottom=(1.2,1.35,1.0) if kind=='window' else (1.2,2.3,0)
  side=(width-ow)/2
  for x in [-1,1]: box('opening pier',(x*(ow/2+side/2),0,h/2),(side,d,h),surface)
  box('opening lintel',(0,0,(bottom+oh+h)/2),(ow,d,h-bottom-oh),surface)
  if bottom: box('window apron',(0,0,bottom/2),(ow,d,bottom),surface)
 if upper:
  # End posts deliberately separate assets; these horizontal ties stop at bay edges.
  for z in [.12,2.88]: box('timber tie',(0,-.015,z),(width,.36,.24))
  if kind=='plain':
   for x in [-1,1]: beam('diagonal brace',(x*(width/2-.15),-.19,.25),(x*.2,-.19,2.72),.14)
 else:
  for row in range(3):
   for col in range(int(width)):
    x=-width/2+.5+col
    if kind!='plain' and abs(x)<.7: continue
    box('stone accent',(x,-.17,.45+row*.87),(.28,.07,.16),'StoneLight')

def corner(upper=False,inside=False):
 # Half-meter corner footprint; straight bays terminate at the exposed end faces.
 material='Plaster' if upper else 'Stone'
 box('corner leg x',(.25,0,1.5),(.5,.3,3),material)
 box('corner leg y',(0,.25,1.5),(.3,.5,3),material)
 if upper: box('corner timber',(0,-.025,1.5),(.25,.36,3))
 if inside:
  for ob in pieces:
   ob.location.x=-ob.location.x; ob.location.y=-ob.location.y; ob.rotation_euler.z+=math.pi

def roof(width=4,run=2,rise=1.5,opening=False):
 # One pitched half-roof: lower eave y=-run,z=0; ridge y=0,z=rise.
 for row in range(5):
  for col in range(8):
   if opening and 2<=col<=4 and 1<=row<=3: continue
   x=-width/2+(col+.5)*width/8; y=-run+(row+.5)*run/5; z=(y+run)*rise/run
   box('slate shingle',(x,y,z),(width/8-.008,math.hypot(run/5,rise/5)+.06,.08),'Slate',(math.atan2(rise,run),0,0))
 for x in [-width/2+.09,width/2-.09]: beam('rafter',(x,-run,-.12),(x,0,rise-.12),.16)

def prism(name,coords,depth,material):
 n=len(coords); vs=[(x,y,z) for y in [-depth/2,depth/2] for x,z in coords]
 return mesh(name,vs,[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)],material)

def arch(width=3,height=3,depth=.5,thick=.4,solid=False):
 r=width/2; spring=height-r
 for sign in [-1,1]: box('arch pier',(sign*(r+thick/2),0,spring/2),(thick,depth,spring),'Stone')
 for i in range(12):
  a=i*math.pi/12; b=(i+1)*math.pi/12
  coords=[(r*math.cos(a),spring+r*math.sin(a)),((r+thick)*math.cos(a),spring+(r+thick)*math.sin(a)),((r+thick)*math.cos(b),spring+(r+thick)*math.sin(b)),(r*math.cos(b),spring+r*math.sin(b))]
  prism('voussoir',coords,depth,'StoneLight')
 if solid: box('recess back',(0,depth/2,height/2),(width,.12,height),'Stone')

def window(tall=False):
 w=1.18; h=1.33 if not tall else 1.9
 box('glass',(0,0,h/2),(w,.055,h),'Glass')
 for x in [-w/2,w/2]: box('jamb',(x,-.045,h/2),(.10,.16,h+.10))
 for z in [0,h,h/2]: box('cross rail',(0,-.07,z),(w+.10,.14,.08))
 box('mullion',(0,-.08,h/2),(.075,.13,h))

def door(double=False,reinforced=False):
 w=2.4 if double else 1.16
 for i in range(8 if double else 4): box('door plank',(-w/2+(i+.5)*w/(8 if double else 4),0,1.13),(w/(8 if double else 4)-.012,.12,2.26),'Wood')
 for z in [.35,1.85]: box('strap',(0,-.085,z),(w-.08,.045,.10),'Iron' if reinforced else 'Timber')
 for x in ([-.14,.14] if double else [.38]): uvball('door handle',(x,-.13,1.1),(.055,.04,.055),'Iron')

def stairs(count=6,width=2,rise=.25,tread=.4):
 for i in range(count): box('step',(0,(i+.5)*tread,(i+1)*rise/2),(width,tread,(i+1)*rise),'Stone')

def railing(length=4,stone=False,sloped=False):
 if stone:
  if sloped: prism('sloped parapet',[(-2,0),(2,1.5),(2,2.4),(-2,.9)],.28,'Stone')
  else: box('parapet',(0,0,.45),(length,.28,.9),'Stone'); box('cap',(0,0,.96),(length,.38,.12),'StoneLight')
 else:
  for x in [-length/2+.07,length/2-.07]: box('post',(x,0,.55),(.14,.14,1.1))
  for z in [.35,1.0]: box('rail',(0,0,z),(length,.10,.12))
  beam('brace',(-length/2+.1,0,.4),(length/2-.1,0,.95),.08)

def plankdeck(w=4,d=2):
 for i in range(max(2,int(w/.25))):
  n=max(2,int(w/.25)); box('deck plank',(-w/2+(i+.5)*w/n,0,.12),(w/n-.015,d,.24),'Wood')
 for y in [-d/2+.2,d/2-.2]: box('joist',(0,y,-.03),(w,.18,.18))

def barrel(opened=False):
 n=12; levels=[(0,.32),(.12,.38),(.55,.45),(1,.38),(1.08,.34)]
 for i in range(n):
  a=2*math.pi*i/n+.012; b=2*math.pi*(i+1)/n-.012
  vs=[]
  for z,r in levels: vs.extend([(r*math.cos(a),r*math.sin(a),z),(r*math.cos(b),r*math.sin(b),z)])
  mesh('barrel stave',vs,[(2*j,2*j+1,2*j+3,2*j+2) for j in range(4)],'Wood')
 for z,r in [(.15,.395),(.9,.405)]: ring('hoop',(0,0,z),r+.018,r,.075,'Iron',12)
 cyl('bottom',(0,0,.05),.32,.07,'Wood')
 if not opened: cyl('lid',(0,0,1.06),.33,.045,'Wood')

def crate(size=1,shallow=False):
 h=size*.35 if shallow else size
 for i in range(4): box('bottom plank',((i-1.5)*size/4,0,.045),(size/4-.01,size,.09),'Wood')
 for z in [h*.25,h*.65,h-.06]:
  for s in [-1,1]:
   box('side slat',(s*(size/2-.04),0,z),(.08,size,h*.22),'Wood'); box('end slat',(0,s*(size/2-.04),z),(size,.08,h*.22),'Wood')
 for x in [-1,1]:
  for y in [-1,1]: box('corner post',(x*(size/2-.06),y*(size/2-.06),h/2),(.10,.10,h))

def lantern():
 box('glowing pane',(0,0,.30),(.22,.22,.35),'Amber')
 for x in [-.13,.13]:
  for y in [-.13,.13]: box('frame',(x,y,.3),(.035,.035,.42),'Iron')
 for z in [.07,.52]: box('cap',(0,0,z),(.31,.31,.06),'Iron')
 cyl('top hood',(0,0,.60),.23,.14,'Iron',4,r2=.08)
 r=ring('hanging loop',(0,0,.76),.09,.065,.035,'Iron',12); r.rotation_euler.x=math.pi/2

def table(bench=False,stool=False,chair=False):
 w,d,h=(1.5,.4,.5) if bench else (.45,.45,.5) if stool or chair else (1.5,.8,.8)
 box('top',(0,0,h),(w,d,.10),'Wood')
 for x in [-1,1]:
  for y in [-1,1]: box('leg',(x*(w/2-.09),y*(d/2-.08),h/2),(.11,.11,h))
 if chair:
  for x in [-.17,.17]: box('back upright',(x,d/2-.05,.78),(.08,.08,.65))
  for z in [.78,.98]: box('back slat',(0,d/2-.05,z),(w,.08,.12),'Wood')

def canopy(width=3,depth=2,striped=False):
 for i in range(8):
  x=-width/2+(i+.5)*width/8
  vs=[(x-width/16,-depth/2,0),(x+width/16,-depth/2,0),(x+width/16,0,.28),(x-width/16,0,.28),(x-width/16,depth/2,0),(x+width/16,depth/2,0)]
  mesh('cloth strip',vs,[(0,1,2,3),(3,2,5,4)],'Red' if striped and i%2 else 'Canvas')
  box('valance',(x,-depth/2,-.12),(width/8,.025,.24),'Red' if striped and i%2 else 'Canvas')

def pot(plant=False):
 vessel('pot body',[(.02,0),(.19,0),(.30,.44),(.25,.44),(.15,.06),(.02,.06)],'Clay',12); ring('lip',(0,0,.44),.32,.25,.09,'Clay')
 if plant:
  for i in range(7):
   t=i*2.4; beam('stem',(0,0,.45),(.19*math.cos(t),.19*math.sin(t),.9),.025,'Green')
   uvball('leaf cluster',(.22*math.cos(t),.22*math.sin(t),.78),(.22,.12,.15),'Leaf',8,4)

def person(role='town',variant=0):
 cloth='Blue' if role=='guard' else ['Canvas','Red','Green'][variant%3]
 for x in [-.14,.14]:
  beam('trouser leg',(x,0,.16),(x,0,.85),.19,cloth,.21); box('boot',(x,-.08,.10),(.22,.36,.2),'Timber')
 cyl('tunic skirt',(0,0,.82),.30,.35,cloth,8,r2=.24)
 uvball('torso',(0,0,1.12),(.30,.17,.37),cloth,10,6)
 for s in [-1,1]:
  beam('sleeve',(s*.25,0,1.32),(s*.39,0,.99),.18,cloth)
  beam('forearm',(s*.39,0,.99),(s*.40,-.03,.79),.13,'Skin')
  uvball('hand',(s*.40,-.03,.76),(.085,.07,.10),'Skin')
 cyl('neck',(0,0,1.48),.075,.16,'Skin')
 uvball('head',(0,0,1.67),(.15,.14,.20),'Skin')
 uvball('nose',(0,-.14,1.67),(.045,.06,.045),'Skin',8,4)
 if role=='guard':
  uvball('helmet',(0,0,1.81),(.18,.17,.13),'Iron'); ring('helmet brim',(0,0,1.77),.23,.15,.045,'Iron')
  box('belt',(0,-.01,.91),(.52,.36,.065),'Timber'); box('buckle',(0,-.20,.91),(.09,.04,.08),'Iron')
 else:
  uvball('hair',(0,.025,1.79),(.16,.145,.11),'Timber',10,5)
  if role in ('merchant','innkeeper'): box('apron',(0,-.18,.88),(.42,.04,.60),'Canvas')

# BUILDING STRUCTURE
C='01 Buildings'
for upper in [False,True]:
 for kind in ['plain','window','door']: asset(C,('Timber' if upper else 'Stone')+' wall '+kind,lambda k=kind,u=upper:wall(k,u),'4 m bay × 3 m story; facade -Y; opening inserts separate.')
 for inside in [False,True]: asset(C,('Timber' if upper else 'Stone')+' corner '+('inner' if inside else 'outer'),lambda u=upper,i=inside:corner(u,i),'0.5 m return corner; straight panels terminate at corner ends.')
 asset(C,('Timber' if upper else 'Stone')+' half wall',lambda u=upper:wall('plain',u,2))
for name,a,b,w in [('Vertical post',(0,0,0),(0,0,3),.22),('Horizontal beam',(-2,0,0),(2,0,0),.22),('Diagonal brace',(-1,0,0),(1,0,2.5),.16)]: asset(C,name,lambda a=a,b=b,w=w:beam('structural timber',a,b,w))
asset(C,'Interior floor',lambda:plankdeck(4,4))
asset(C,'Exposed floor underside',lambda:(plankdeck(4,4),beam('cross joist',(-2,0,-.18),(2,0,-.18),.22)))
asset(C,'Projecting upper floor bay',lambda:(plankdeck(4,1),beam('front rim',(-2,-.5,-.1),(2,-.5,-.1),.25)))
asset(C,'Projecting corner floor',lambda:(plankdeck(2,2),beam('rim',(-1,-1,-.1),(1,-1,-.1),.25)))
for length in [.6,1.3]: asset(C,'Overhang bracket '+str(length),lambda l=length:(beam('wall fixing',(0,0,0),(0,0,l),.14),beam('diagonal',(0,0,0),(0,-l,l),.14),beam('shelf',(0,0,l),(0,-l,l),.14)))
asset(C,'Foundation straight',lambda:box('foundation',(0,0,.3),(4,.6,.6),'Stone'))
asset(C,'Foundation corner',lambda:(box('leg',(0,0,.3),(1,.6,.6),'Stone'),box('return',(.2,.5,.3),(.6,.4,.6),'Stone')))
asset(C,'Foundation stepped',lambda:stairs(3,4,.2,.4))
for name,size in [('Base course',(4,.42,.25)),('Wall cap',(4,.45,.15)),('Projecting stone',(.4,.3,.22))]: asset(C,name,lambda s=size:box('stone', (0,0,s[2]/2),s,'StoneLight'))
# ROOF AND OPENINGS
C='02 Roofs and Openings'
asset(C,'Slate roof panel',lambda:roof())
asset(C,'Slate roof dormer opening',lambda:roof(opening=True))
asset(C,'Gable roof end',lambda:prism('gable',[(-2,0),(2,0),(0,1.5)],.2,'Plaster'))
asset(C,'Hip roof end',lambda:mesh('hip',[(-2,-2,0),(2,-2,0),(0,0,1.5)],[(0,1,2)],'Slate'))
asset(C,'Roof valley junction',lambda:(beam('valley channel',(-2,-2,0),(0,0,1.5),.18,'Iron'),mesh('valley flashing',[(-2,-1.8,0),(-1.8,-2,0),(.2,0,1.5),(0,.2,1.5)],[(0,1,2,3)],'Slate')))
for name,a,b in [('Roof ridge',(-2,0,0),(2,0,0)),('Roof eave',(-2,0,0),(2,0,0)),('Roof verge',(0,-2,0),(0,0,1.5))]: asset(C,name,lambda a=a,b=b:beam('trim',a,b,.17,'Timber'))
asset(C,'Roof ridge end cap',lambda:cyl('finial',(0,0,.15),.13,.3,'Slate',8,r2=.04))
asset(C,'Gable timber window',lambda:(prism('gable',[(-2,0),(2,0),(0,1.5)],.2,'Plaster'),beam('left verge',(-2,-.15,0),(0,-.15,1.5),.15),beam('right verge',(2,-.15,0),(0,-.15,1.5),.15),box('attic glazing',(0,-.16,.55),(.55,.05,.6),'Glass')))
asset(C,'Window dormer',lambda:(box('dormer face',(0,0,.55),(1.3,.22,1.1),'Plaster'),box('dormer glass',(0,-.13,.55),(.8,.04,.75),'Glass'),prism('dormer gable',[(-.7,1.1),(.7,1.1),(0,1.6)],.3,'Plaster'),mesh('dormer roof',[(-.8,-.3,1.1),(0,-.3,1.65),(.8,-.3,1.1),(-.8,1,1.1),(0,1,1.65),(.8,1,1.1)],[(0,3,4,1),(1,4,5,2)],'Slate')))
for h in [1,2]: asset(C,'Chimney stack '+str(h),lambda h=h:(box('stack',(0,0,h/2),(.55,.55,h),'Stone'),box('collar',(0,0,h-.12),(.65,.65,.14),'StoneLight')))
asset(C,'Chimney cap',lambda:ring('open chimney cap',(0,0,.1),.43,.25,.2,'StoneLight',4))
asset(C,'Square window insert',lambda:window())
asset(C,'Tall window insert',lambda:window(True))
for opened in [False,True]:
 def shutters(opened=opened):
  for s in [-1,1]:
   x=s*(.94 if opened else .3)
   for i in range(3): box('shutter plank',(x+(i-1)*.19,0,.67),(.18,.07,1.3),'Wood')
   for z in [.18,1.12]: box('shutter strap',(x,-.06,z),(.58,.05,.08),'Iron')
 asset(C,'Shutters '+('open' if opened else 'closed'),shutters)
asset(C,'Window sill',lambda:box('sill',(0,0,.08),(1.5,.4,.16),'StoneLight'))
asset(C,'Window flower box',lambda:(box('base',(0,0,.04),(1.4,.32,.08),'Wood'),box('front',(0,-.16,.18),(1.4,.06,.3),'Wood'),box('back',(0,.16,.18),(1.4,.06,.3),'Wood'),box('end',(-.67,0,.18),(.06,.32,.3),'Wood'),box('end',(.67,0,.18),(.06,.32,.3),'Wood')))
asset(C,'House door',lambda:door())
asset(C,'Reinforced door',lambda:door(reinforced=True))
asset(C,'Double shop door',lambda:door(True))
asset(C,'Timber door surround',lambda:(box('jamb',(-.68,0,1.18),(.16,.24,2.36)),box('jamb',(.68,0,1.18),(.16,.24,2.36)),box('lintel',(0,0,2.4),(1.52,.24,.18))))
asset(C,'Stone arched doorway',lambda:arch(1.3,2.4,.35,.25))
asset(C,'Entrance single step',lambda:stairs(1,1.6,.2,.45))
asset(C,'Entrance short steps',lambda:stairs(3,1.8,.2,.4))
asset(C,'Open service window',lambda:(wall('window'),box('service shelf',(0,-.45,1),(1.6,.85,.12),'Wood')))
asset(C,'Shop display counter',lambda:(box('counter body',(0,0,.5),(2,.7,1),'Wood'),box('counter top',(0,-.05,1.05),(2.15,.85,.1),'Timber')))
asset(C,'Straight shop awning',lambda:canopy(4,1.8))
asset(C,'Awning end piece',lambda:prism('cloth side',[(-.9,0),(0,.28),(.9,0)],.03,'Canvas'))
asset(C,'Awning timber supports',lambda:(beam('post',(-1.9,0,0),(-1.9,0,2.5),.12),beam('post',(1.9,0,0),(1.9,0,2.5),.12),beam('crossbar',(-2,0,2.5),(2,0,2.5),.12)))
# STREETS
C='03 Streets and Terraces'
def paving(w=4,d=4):
 for row in range(int(d/.4)):
  for col in range(int(w/.5)):
   box('cobble',(-w/2+(col+.5)*.5,-d/2+(row+.5)*.4,.06),(.48,.38,.12),'StoneLight' if (col+row)%3 else 'Stone')
asset(C,'Cobblestone square',lambda:paving())
asset(C,'Cobblestone edge',lambda:paving(4,1))
asset(C,'Cobblestone corner',lambda:paving(1,1))
asset(C,'Street slope',lambda:prism('ramp',[(-2,0),(2,0),(2,1),(-2,.12)],4,'Stone'))
asset(C,'Slope landing transition',lambda:prism('transition',[(-1,0),(1,0),(1,.35),(-1,.12)],4,'Stone'))
for name,fn in [('Curb straight',lambda:box('curb',(0,0,.12),(4,.24,.24),'StoneLight')),('Curb corner',lambda:(box('curb',(0,0,.12),(1,.24,.24),'StoneLight'),box('return',(.38,.5,.12),(.24,.76,.24),'StoneLight'))),('Curb end',lambda:box('curb end',(0,0,.12),(.3,.24,.24),'StoneLight'))]: asset(C,name,fn)
asset(C,'Retaining wall straight',lambda:box('retaining wall',(0,0,1.5),(4,.6,3),'Stone'))
for inside in [False,True]: asset(C,'Retaining wall '+('inner' if inside else 'outer')+' corner',lambda i=inside:retaining_corner(i))
for name,sz in [('Retaining cap straight',(4,.75,.18)),('Retaining cap corner',(1,.75,.18)),('Retaining cap end',(.65,.75,.18))]: asset(C,name,lambda s=sz:box('cap',(0,0,s[2]/2),s,'StoneLight'))
asset(C,'Arched passage',lambda:arch(2,3,.7,.5))
asset(C,'Arched closed recess',lambda:arch(2,3,.7,.5,True))
asset(C,'Stone stairs short',lambda:stairs())
asset(C,'Stone stairs full story',lambda:stairs(12))
asset(C,'Landing square',lambda:box('landing',(0,0,.15),(2,2,.3),'Stone'))
asset(C,'Landing rectangular',lambda:box('landing',(0,0,.15),(4,2,.3),'Stone'))
asset(C,'Stair sidewall',lambda:prism('stair side',[(-1.2,0),(1.2,0),(1.2,2.4),(-1.2,.9)],.3,'Stone'))
asset(C,'Stair end post',lambda:(box('post',(0,0,.65),(.4,.4,1.3),'Stone'),box('cap',(0,0,1.33),(.5,.5,.12),'StoneLight')))
asset(C,'Stone parapet straight',lambda:railing(stone=True))
asset(C,'Stone parapet corner',lambda:(railing(1,True),box('return',(.36,.65,.45),(.28,1,.9),'Stone')))
asset(C,'Stone parapet end',lambda:box('end post',(0,0,.52),(.38,.38,1.04),'StoneLight'))
asset(C,'Timber railing bay',lambda:railing())
asset(C,'Timber railing corner post',lambda:(box('post',(0,0,.6),(.18,.18,1.2)),box('crosscap',(0,0,1.22),(.28,.28,.08))))
asset(C,'Timber railing end post',lambda:box('post',(0,0,.6),(.18,.18,1.2)))
asset(C,'Gutter channel',lambda:(box('channel bed',(0,0,.04),(4,.3,.08),'Stone'),box('edge',(0,.18,.1),(4,.08,.2),'Stone')))
asset(C,'Drain grate',lambda:[box('grate bar',((i-3)*.09,0,.04),(.04,.6,.08),'Iron') for i in range(7)])
# BRIDGES
C='04 Bridges and Canals'
def bridge_arch():
 arch(4,3,3,.5)
 for i in range(12):
  a=i*math.pi/12; b=(i+1)*math.pi/12
  x1,z1=2.5*math.cos(a),1+2.5*math.sin(a)
  x2,z2=2.5*math.cos(b),1+2.5*math.sin(b)
  coords=[(x1,z1),(x1,3.5),(x2,3.5),(x2,z2)]
  # Remove duplicate crown vertices so the spandrel has no zero-area faces.
  unique=[]
  for point in coords:
   if not unique or (Vector(point)-Vector(unique[-1])).length>1e-6: unique.append(point)
  if len(unique)>2 and (Vector(unique[0])-Vector(unique[-1])).length<1e-6: unique.pop()
  if len(unique)>=3: prism('spandrel',unique,3,'Stone')
 for x in [-2.75,2.75]: box('abutment edge',(x,0,1.75),(.5,3,3.5),'Stone')
asset(C,'Stone bridge arch bay',bridge_arch,'4 m clear span; 6 m total bay; 3 m width; flat deck seat at 3.5 m.')
asset(C,'Stone bridge deck',lambda:box('deck',(0,0,.15),(6,3,.3),'Stone'))
asset(C,'Bridge approach',lambda:prism('approach',[(-2,0),(2,0),(2,1),(-2,.2)],3,'Stone'))
asset(C,'Bridge middle pier',lambda:(box('pier',(0,0,1.5),(1,3.4,3),'Stone'),cyl('cutwater',(0,-1.8,1),.65,2,'Stone',4)))
asset(C,'Bridge abutment',lambda:box('abutment',(0,0,1.5),(1.5,3.4,3),'Stone'))
asset(C,'Bridge parapet straight',lambda:railing(6,stone=True))
asset(C,'Bridge parapet slope',lambda:railing(stone=True,sloped=True))
asset(C,'Bridge end post',lambda:(box('post',(0,0,.6),(.45,.45,1.2),'Stone'),cyl('cap',(0,0,1.28),.34,.16,'StoneLight',4)))
asset(C,'Timber walkway straight',lambda:plankdeck())
asset(C,'Timber walkway corner',lambda:plankdeck(2,2))
asset(C,'Timber walkway junction',lambda:plankdeck(4,4))
asset(C,'Walkway post',lambda:box('post',(0,0,1.5),(.25,.25,3)))
asset(C,'Walkway crossbeam',lambda:box('beam',(0,0,.12),(3,.25,.24)))
asset(C,'Walkway diagonal support',lambda:beam('support',(0,0,0),(0,2,2),.22))
asset(C,'Covered bridge frame',lambda:(box('post',(-1.4,0,1.4),(.2,.2,2.8)),box('post',(1.4,0,1.4),(.2,.2,2.8)),box('tie',(0,0,2.8),(3,.22,.22)),beam('brace',(-1.4,0,1.8),(-.5,0,2.8),.14),beam('brace',(1.4,0,1.8),(.5,0,2.8),.14)))
asset(C,'Covered bridge end frame',lambda:(arch(2.4,2.8,.22,.15),box('threshold',(0,0,.1),(3,.3,.2))))
asset(C,'Covered bridge roof',lambda:roof(4,1.7,1.1))
asset(C,'Canal wall straight',lambda:box('quay',(0,0,1.5),(4,.6,3),'Stone'))
asset(C,'Canal wall corner',lambda:(box('quay',(0,0,1.5),(1,.6,3),'Stone'),box('return',(.2,.8,1.5),(.6,1,3),'Stone')))
asset(C,'Canal outlet',lambda:arch(1.3,1.7,.8,.35))
asset(C,'Canal coping straight',lambda:box('coping',(0,0,.1),(4,.8,.2),'StoneLight'))
asset(C,'Canal coping corner',lambda:(box('coping',(0,0,.1),(1,.8,.2),'StoneLight'),box('return',(.1,.8,.1),(.8,.8,.2),'StoneLight')))
asset(C,'Dock platform straight',lambda:plankdeck(4,2))
asset(C,'Dock platform corner',lambda:plankdeck(2,2))
asset(C,'Dock platform end',lambda:(plankdeck(2,2),box('end beam',(0,-1,.2),(2,.18,.35))))
asset(C,'Dock ladder',lambda:([box('stile',(x,0,1.5),(.09,.1,3)) for x in [-.35,.35]],[box('rung',(0,-.03,.2+i*.32),(.8,.1,.09)) for i in range(9)]))
asset(C,'Mooring post',lambda:(cyl('bollard',(0,0,.4),.18,.8),cyl('cap',(0,0,.82),.23,.08)))
asset(C,'Mooring ring',lambda:ring('ring',(0,0,.08),.22,.16,.06,'Iron'))
for name,scale in [('Cliff mass',(3,2,3)),('Rock outcrop',(1.5,1,1.5)),('Rock filler',(.5,.4,.4))]: asset(C,name,lambda s=scale:uvball('faceted rock',(0,0,s[2]*.65),s,'Stone',7,4))
# FORTIFICATIONS
C='05 Gatehouse and Tower'
asset(C,'Fortification wall bay',lambda:box('wall',(0,0,2),(4,1,4),'Stone'))
asset(C,'Fortification corner',lambda:(box('wall',(0,0,2),(2,1,4),'Stone'),box('return',(.5,1.5,2),(1,2,4),'Stone')))
asset(C,'Battlement repeat',lambda:(box('base',(0,0,.35),(4,.7,.7),'Stone'),[box('merlon',(x,0,1),( .65,.7,.6),'Stone') for x in [-1.65,-.55,.55,1.65]]))
asset(C,'Battlement end',lambda:box('merlon',(0,0,.65),(.7,.7,1.3),'Stone'))
asset(C,'Gate stone arch',lambda:arch(4,5,1,.65))
for side in ['left','right']: asset(C,'Gate door '+side,lambda:(box('gate leaf',(0,0,2),(1.95,.22,4),'Wood'),[box('band',(0,-.14,z),(1.9,.06,.16),'Iron') for z in [.5,2,3.5]],beam('gate brace',(-.85,-.17,.3),(.85,-.17,3.7),.14,'Iron')))
asset(C,'Portcullis',lambda:([box('vertical bar',(x,0,2),(.10,.12,4),'Iron') for x in [-1.8,-1.2,-.6,0,.6,1.2,1.8]],[box('crossbar',(0,-.03,z),(4,.13,.09),'Iron') for z in [.4,1,1.6,2.2,2.8,3.4,4]]))
asset(C,'Tower wall plain',lambda:wall())
asset(C,'Tower wall window',lambda:wall('window'))
asset(C,'Tower corner',lambda:corner())
asset(C,'Tower platform',lambda:plankdeck(4,4))
asset(C,'Tower projecting support',lambda:beam('bracket',(0,0,0),(0,-1,1),.3))
asset(C,'Watchtower observation bay',lambda:(box('post',(-2,0,1.5),(.25,.25,3)),box('post',(2,0,1.5),(.25,.25,3)),box('header',(0,0,2.9),(4,.25,.2)),railing()))
asset(C,'Tower roof half',lambda:roof(4.8,2.4,2))
asset(C,'Banner wall bracket',lambda:(box('wall plate',(0,0,.35),(.12,.08,.7),'Iron'),beam('arm',(0,0,.65),(0,-.8,.65),.06,'Iron')))
asset(C,'Banner pole',lambda:cyl('pole',(0,0,1.5),.045,3,'Iron'))
# LANDMARKS
C='06 Market and Landmarks'
asset(C,'Fountain basin quarter',lambda:mesh('basin quarter',[(r*math.cos(t),r*math.sin(t),z) for z,r in [(0,1.5),(0,1.8),(.5,1.5),(.5,1.8)] for t in [i*math.pi/16 for i in range(9)]],[(i,i+1,9+i+1,9+i) for i in range(8)]+[(18+i,27+i,28+i,19+i) for i in range(8)]+[(i,18+i,19+i,i+1) for i in range(8)]+[(9+i,10+i,28+i,27+i) for i in range(8)]+[(0,9,27,18),(8,26,35,17)],'StoneLight'))
asset(C,'Fountain pedestal',lambda:(cyl('foot',(0,0,.12),.65,.24,'StoneLight'),cyl('column',(0,0,.8),.25,1.4,'StoneLight',12,r2=.19)))
asset(C,'Fountain lower tier',lambda:(cyl('bowl',(0,0,.15),.4,.3,'StoneLight',16,r2=.85),ring('rim',(0,0,.32),.9,.75,.1,'StoneLight')))
asset(C,'Fountain upper tier spout',lambda:(cyl('stem',(0,0,.35),.12,.7,'StoneLight'),cyl('upper bowl',(0,0,.65),.2,.2,'StoneLight',16,r2=.45),cyl('spout',(0,0,.95),.08,.4,'Iron')))
asset(C,'Inn grand doorway',lambda:arch(2.4,3,.4,.35))
asset(C,'Inn porch',lambda:(plankdeck(4,2),box('post',(-1.85,-.85,1.5),(.2,.2,3)),box('post',(1.85,-.85,1.5),(.2,.2,3)),box('porch roof',(0,0,3.1),(4.3,2.3,.2),'Slate')))
asset(C,'Hanging sign bracket',lambda:(box('plate',(0,0,.3),(.12,.08,.6),'Iron'),beam('arm',(0,0,.55),(0,-1,.55),.06,'Iron'),beam('brace',(0,0,.2),(0,-.7,.55),.045,'Iron')))
asset(C,'Inn signboard',lambda:(box('sign',(0,0,.4),(.8,.08,.8),'Wood'),ring('mug motif',(0,-.06,.4),.19,.14,.04,'Amber')))
asset(C,'Market stall frame',lambda:([box('post',(x,y,1.2),(.12,.12,2.4)) for x in [-1.5,1.5] for y in [-1,1]],box('ridge',(0,0,2.6),(3.2,.12,.12))))
asset(C,'Market stall end frame',lambda:(box('post',(-1,0,1.2),(.12,.12,2.4)),box('post',(1,0,1.2),(.12,.12,2.4)),beam('tie',(-1,0,2.4),(1,0,2.4),.12)))
asset(C,'Market canopy plain',lambda:canopy())
asset(C,'Market canopy striped',lambda:canopy(striped=True))
asset(C,'Market counter straight',lambda:box('counter',(0,0,.5),(3,.8,1),'Wood'))
asset(C,'Market counter corner',lambda:(box('counter',(0,0,.5),(1,.8,1),'Wood'),box('return',(.1,.8,.5),(.8,.8,1),'Wood')))
asset(C,'Produce tray',lambda:crate(.8,True))
asset(C,'Woven basket',basket)
asset(C,'Shallow display crate',lambda:crate(1,True))
for shape in ['rectangular','round','shield']:
 def sign(shape=shape):
  if shape=='round':
   o=cyl('sign',(0,0,.4),.4,.08,'Wood'); o.rotation_euler.x=math.pi/2
  elif shape=='shield': prism('sign',[(-.4,.8),(.4,.8),(.35,.3),(0,0),(-.35,.3)],.08,'Wood')
  else: box('sign',(0,0,.3),(.9,.08,.6),'Wood')
 asset(C,'Shop sign '+shape,sign)
asset(C,'Public noticeboard',lambda:(box('board',(0,0,1.5),(1.6,.12,1.1),'Wood'),[box('post',(x,0,1),(.14,.14,2)) for x in [-.7,.7]],[box('notice',(x,-.075,1.5),(.35,.02,.5),'Canvas') for x in [-.45,0,.45]]))
# PROPS
C='07 Props and Dressing'
asset(C,'Hanging lantern',lantern)
asset(C,'Wall lantern',lambda:(lantern(),beam('wall arm',(0,.05,.75),(0,.5,.75),.05,'Iron'),box('plate',(0,.5,.65),(.12,.05,.35),'Iron')))
asset(C,'Handheld lantern',lantern)
asset(C,'Lantern mounting bracket',lambda:(beam('hook',(0,0,.4),(0,-.4,.4),.04,'Iron'),box('plate',(0,0,.25),(.1,.06,.5),'Iron')))
asset(C,'Barrel closed',barrel)
asset(C,'Barrel open',lambda:barrel(True))
asset(C,'Large crate',crate)
asset(C,'Small crate',lambda:crate(.55))
asset(C,'Storage sack',lambda:(uvball('sack',(0,0,.38),(.30,.25,.38),'Canvas'),cyl('tied neck',(0,0,.76),.09,.16,'Canvas',8,r2=.13)))
asset(C,'Bench',lambda:table(bench=True))
asset(C,'Stool',lambda:table(stool=True))
asset(C,'Table',table)
asset(C,'Chair',lambda:table(chair=True))
asset(C,'Bottle',lambda:(cyl('body',(0,0,.15),.09,.3,'Green'),cyl('shoulder',(0,0,.32),.09,.08,'Green',12,r2=.035),cyl('neck',(0,0,.4),.035,.1,'Green')))
asset(C,'Pottery jug',lambda:(pot(),(lambda o:setattr(o.rotation_euler,'x',math.pi/2))(ring('handle',(.25,0,.26),.17,.12,.065,'Clay'))))
asset(C,'Bread loaf',lambda:uvball('loaf',(0,0,.12),(.30,.14,.12),'Bread'))
asset(C,'Produce cluster',lambda:[uvball('apple',((i%3-.9)*.15,(i//3-.5)*.15,.10),(.09,.09,.1),'Red',8,4) for i in range(6)])
asset(C,'Handcart',lambda:(plankdeck(1.2,1.5),box('side',(-.6,0,.4),(.08,1.5,.6),'Wood'),box('side',(.6,0,.4),(.08,1.5,.6),'Wood'),beam('axle',(-.9,0,0),(.9,0,0),.12,'Iron'),[beam('handle',(x,-.5,.2),(x,-2,.3),.08) for x in [-.45,.45]],[(lambda o:setattr(o.rotation_euler,'y',math.pi/2))(ring('wheel',(x,0,0),.48,.36,.12,'Timber')) for x in [-.8,.8]]))
asset(C,'Bucket',lambda:(vessel('open bucket',[(.02,0),(.18,0),(.24,.4),(.20,.4),(.14,.05),(.02,.05)],'Wood',12),ring('rim',(0,0,.40),.26,.20,.06,'Iron')))
asset(C,'Rope coil',lambda:[ring('rope loop',(0,0,.035+i*.05),.34-i*.025,.315-i*.025,.035,'Canvas',24) for i in range(5)])
asset(C,'Hanging banner',lambda:prism('banner',[(-.4,2),(.4,2),(.4,.2),(0,0),(-.4,.2)],.035,'Red'))
asset(C,'Bunting strand',lambda:([beam('cord',(-2,0,1),(2,0,1),.015,'Canvas')],[prism('flag',[(x-.14,1),(x+.14,1),(x,.65)],.02,'Red' if i%2 else 'Canvas') for i,x in enumerate([-1.6,-.8,0,.8,1.6])]))
asset(C,'Rolled cloth',lambda:cyl('fabric roll',(0,0,.15),.15,1,'Red',12))
asset(C,'Flower box planting',lambda:[uvball('foliage',((i-2)*.24,0,.15),(.18,.16,.18),'Leaf',8,4) for i in range(5)])
asset(C,'Potted plant',lambda:pot(True))
asset(C,'Ivy strip',lambda:[uvball('leaf',(.12*math.sin(i),0,.1+i*.15),(.14,.04,.12),'Leaf',6,3) for i in range(15)])
asset(C,'Ivy corner cluster',lambda:[uvball('leaf',(.18*math.sin(i),.18*math.cos(i),.15+i*.12),(.14,.12,.10),'Green',6,3) for i in range(12)])
asset(C,'Loose stones',lambda:[uvball('stone',(i*.18-.3,.1*math.sin(i),.08),(.13,.09,.08),'StoneLight',7,4) for i in range(4)])
asset(C,'Rubble cluster',lambda:[uvball('rubble',(.5*math.sin(i*2.3),.5*math.cos(i*2.3),.15),(.22,.18,.15),'Stone',7,4) for i in range(9)])
asset(C,'Scattered boards',lambda:[box('board',((i-1)*.2,0,.04+i*.035),(.13,1,.05),'Wood',(0,0,i*.3)) for i in range(3)])
asset(C,'Door hinge',lambda:(box('plate',(0,0,.12),(.24,.04,.24),'Iron'),cyl('pin',(.12,0,.12),.035,.3,'Iron')))
asset(C,'Door handle',lambda:ring('pull',(0,0,.12),.12,.085,.04,'Iron'))
asset(C,'Metal strap',lambda:box('strap',(0,0,.04),(.8,.12,.08),'Iron'))
asset(C,'Iron angle bracket',lambda:(box('leg',(0,0,.15),(.12,.04,.3),'Iron'),box('return',(0,-.15,.02),(.12,.3,.04),'Iron')))
# CHARACTER BASES AND SEPARATE ACCESSORIES
C='08 Character Bases'
asset(C,'Guard base',lambda:person('guard'),'Unrigged editable stylized character base; separate gear assets below.')
for i in range(3): asset(C,'Townsperson '+str(i+1),lambda i=i:person('town',i),'Unrigged editable base for sculpting, retopology and rigging.')
asset(C,'Merchant base',lambda:person('merchant',1))
asset(C,'Innkeeper base',lambda:person('innkeeper',2))
asset(C,'Guard helmet',lambda:(uvball('helmet',(0,0,.13),(.18,.17,.13),'Iron'),ring('brim',(0,0,.05),.23,.15,.045,'Iron')))
asset(C,'Guard equipment belt',lambda:(ring('belt',(0,0,.05),.29,.25,.1,'Timber'),box('pouch',(.25,0,-.05),(.15,.18,.22),'Wood'),box('buckle',(0,-.28,.05),(.10,.04,.10),'Iron')))
asset(C,'Town tunic',lambda:(uvball('tunic',(0,0,.3),(.31,.18,.35),'Canvas'),cyl('hem',(0,0,.08),.32,.16,'Canvas',8,r2=.27)))
asset(C,'Town apron',lambda:box('apron',(0,0,.35),(.43,.035,.7),'Canvas'))
asset(C,'Hair short',lambda:uvball('hair',(0,0,.12),(.16,.15,.12),'Timber'))
asset(C,'Hair bun',lambda:(uvball('hair',(0,0,.12),(.16,.15,.12),'Timber'),uvball('bun',(0,.16,.12),(.09,.08,.09),'Timber')))
# Asset Browser catalogs.
import uuid
cats={cat:str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/hub-town/'+cat)) for cat in category_counts}
for rec in catalog: assets[rec['name']].asset_data.catalog_id=cats[rec['kit']]
(OUT/'blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{uid}:{cat}:{cat}' for cat,uid in cats.items())+'\n')
# Gallery labels remain editable text in a dedicated collection.
labels=bpy.data.collections.new('Labels'); scene.collection.children.link(labels)
for rec in catalog:
 text=bpy.data.curves.new(rec['name'],'FONT'); text.body=rec['name']; text.size=.22; text.extrude=0
 ob=bpy.data.objects.new('Label '+rec['name'],text); labels.objects.link(ob); ob.location=(rec['gallery_position'][0]-2.5,rec['gallery_position'][1]-2.5,.02)
 text.materials.append(M['Canvas'])
# Linked module fit example, in its own scene. Source meshes stay editable in the library.
example=bpy.data.scenes.new('01 Assembly Example'); example.unit_settings.system='METRIC'
def inst(name,loc=(0,0,0),yaw=0):
 ob=bpy.data.objects.new(name,None); ob.instance_type='COLLECTION'; ob.instance_collection=assets[name]; ob.location=loc; ob.rotation_euler.z=yaw; example.collection.objects.link(ob); return ob
# 8 x 8 courtyard house, panels form butt joints; independent end posts cover joins.
for z,u in [(0,False),(3,True)]:
 for y,angle in [(-4,0),(4,math.pi)]:
  for x in [-2,2]:
   kind='door' if not u and y==-4 and x==-2 else 'window' if (u or y==4) else 'plain'
   inst(('Timber' if u else 'Stone')+' wall '+kind,(x,y,z),angle)
   if kind=='window': inst('Square window insert',(x,y+(-.18 if y==-4 else .18),z+1),angle)
   if kind=='door': inst('House door',(x,y-.18,z),angle)
 for x,angle in [(-4,-math.pi/2),(4,math.pi/2)]:
  for y in [-2,2]: inst(('Timber' if u else 'Stone')+' wall plain',(x,y,z),angle)
 for x,y in [(-4,-4),(0,-4),(4,-4),(-4,0),(4,0),(-4,4),(0,4),(4,4)]: inst('Vertical post',(x+(.1 if x==4 else -.1 if x==-4 else 0),y+(.1 if y==4 else -.1 if y==-4 else 0),z))
# Two 4 m roof bays across x, pitch made from contiguous 2 m slope modules.
for x in [-2,2]:
 for y,z,rot in [(-2,6,0),(0,7.5,0),(0,7.5,math.pi),(2,6,math.pi)]: inst('Slate roof panel',(x,y,z),rot)
 inst('Roof ridge',(x,0,9))
for x in [-4,4]:
 # Assembly-only scaled gable uses the same source, with inspectable scale.
 ob=inst('Gable roof end',(x,0,6),math.pi/2); ob.scale=(2,1,2)
for x in [-2,2]:
 for y in [-2,2]: inst('Interior floor',(x,y,-.24)); inst('Interior floor',(x,y,2.76))
for x in range(-6,11,4):
 for y in range(-10,3,4): inst('Cobblestone square',(x,y,-.36))
inst('Entrance single step',(-2,-4.6,-.2))
inst('Wall lantern',(-3.3,-4.3,2)); inst('Wall lantern',(2.8,-4.3,2))
inst('Chimney stack 2',(2,1,8))
for x in [7,11]:
 inst('Market stall frame',(x,-7,0)); inst('Market canopy striped',(x,-7,2.4)); inst('Market counter straight',(x,-7,0))
 inst('Produce tray',(x,-7,1)); inst('Produce cluster',(x,-7,1.1))
for angle in range(4): inst('Fountain basin quarter',(5,-2,0),angle*math.pi/2)
inst('Fountain pedestal',(5,-2,0)); inst('Fountain lower tier',(5,-2,1.4)); inst('Fountain upper tier spout',(5,-2,1.7))
inst('Guard base',(0,-7,0)); inst('Merchant base',(7,-6,0)); inst('Barrel closed',(-5,-3,0)); inst('Large crate',(-5,-4.3,0))
# Structural fit samples: complete arch/deck/parapets and stair/landing at one story.
inst('Stone bridge arch bay',(14,2,0)); inst('Stone bridge deck',(14,2,3.5))
for y in [.5,3.5]: inst('Bridge parapet straight',(14,y,3.8))
inst('Stone stairs full story',(-8,0,0)); inst('Landing square',(-8,5.8,2.7))
# Lighting/camera helpers, only for presentation.
def camera_light(sc,loc,target,ortho):
 camdata=bpy.data.cameras.new(sc.name+' Camera'); cam=bpy.data.objects.new('Presentation camera',camdata); sc.collection.objects.link(cam)
 cam.location=loc; cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler(); camdata.type='ORTHO'; camdata.ortho_scale=ortho; sc.camera=cam
 world=bpy.data.worlds.new(sc.name+' World'); world.use_nodes=True; world.node_tree.nodes['Background'].inputs[0].default_value=(.14,.19,.28,1); world.node_tree.nodes['Background'].inputs[1].default_value=.5; sc.world=world
 ld=bpy.data.lights.new('Soft key','AREA'); lo=bpy.data.objects.new('Soft key',ld); sc.collection.objects.link(lo); lo.location=(loc[0]-5,loc[1]-3,loc[2]+10); ld.energy=4500; ld.shape='DISK'; ld.size=15; lo.rotation_euler=(Vector(target)-lo.location).to_track_quat('-Z','Y').to_euler()
 sun=bpy.data.lights.new('Sun','SUN'); so=bpy.data.objects.new('Sun',sun); sc.collection.objects.link(so); so.rotation_euler=(.5,-.4,-.6); sun.energy=2
 sc.render.engine='CYCLES'; sc.cycles.samples=24; sc.cycles.use_denoising=True
 sc.render.resolution_x=1600; sc.render.resolution_y=1100; sc.render.resolution_percentage=100
 sc.view_settings.view_transform='AgX'
camera_light(example,(26,-32,24),(2,-1,3),32)
# Category contact sheets use linked collections centered at their existing gallery positions.
for cat in category_counts:
 sc=bpy.data.scenes.new(cat+' Sheet')
 for rec in catalog:
  if rec['kit']!=cat: continue
  ob=bpy.data.objects.new(rec['name'],None); ob.instance_type='COLLECTION'; ob.instance_collection=assets[rec['name']]; sc.collection.objects.link(ob)
  i=[r for r in catalog if r['kit']==cat].index(rec); ob.location=((i%8)*7,(i//8)*7,0)
  display_scale=min(3.0,4.5/max(rec['dimensions_m'])); ob.scale=(display_scale,)*3; ob.rotation_euler.z=math.radians(-18)
  td=bpy.data.curves.new('Caption','FONT'); td.body=rec['name']; td.size=.28; to=bpy.data.objects.new('Caption',td); sc.collection.objects.link(to); to.location=(ob.location.x-2.7,ob.location.y-2.6,.02); td.materials.append(M['Canvas'])
 rows=math.ceil(category_counts[cat]/8); center=(24.5,(rows-1)*3.5,0)
 camera_light(sc,(24.5,-30,55),center,max(60,rows*9)); sc.render.resolution_x=2000; sc.render.resolution_y=1400
# QA topology data and consistent module sizes.
assert len(catalog)==len(set(r['name'] for r in catalog))
assert all(r['vertices']>0 and r['faces']>0 for r in catalog)
for rec in catalog:
 ob=next(o for o in assets[rec['name']].objects if o.type=='MESH')
 assert all(math.isfinite(v) for vert in ob.data.vertices for v in vert.co)
 assert ob.scale==Vector((1,1,1))
# Save with example visible, library and eight catalog sheets selectable in Scene dropdown.
bpy.context.window.scene=example
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_location=(2,-1,3); area.spaces.active.region_3d.view_distance=35
   area.spaces.active.region_3d.view_rotation=Vector((24,-30,23)).to_track_quat('Z','Y')
example['library_scene']='00 Component Library'; example['module_grid']='4m bay, 3m story, 2m half bay; Blender Z up; facade -Y'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'HubTown_Component_Library.blend'))
(OUT/'component_inventory.json').write_text(json.dumps({'module_standard':{'wall_bay_m':4,'story_height_m':3,'half_bay_m':2,'up':'Z','facade':'-Y','pivot':'base center unless connector noted'},'count':len(catalog),'categories':category_counts,'components':catalog},indent=2)+'\n')
print('HUB_LIBRARY_SAVED',len(catalog),category_counts,flush=True)
example.render.filepath=str(OUT/'assembly_preview.png'); bpy.ops.render.render(write_still=True)
for cat in category_counts:
 sc=bpy.data.scenes[cat+' Sheet']; bpy.context.window.scene=sc; sc.render.filepath=str(OUT/(cat[:2]+'_contact_sheet.png')); bpy.ops.render.render(write_still=True)
print('HUB_LIBRARY_RENDERED',flush=True)
