"""32 residential and retail modules; standalone editable Blender assemblies."""
from pathlib import Path
base=Path(__file__).with_name('build_city_borough_library.py')
exec(compile(base.read_text().split("C='17 Canal Warehouse'")[0].replace('CityBoroughLibrary','ResidentialStreetLibrary'),str(base),'exec'))
scene.name='00 New Components'
mat('Cream',(.78,.66,.45)); mat('Rose',(.55,.25,.18)); mat('SageBlue',(.25,.39,.38)); mat('WarmGlass',(.70,.39,.13),rough=.3,emit=.3)
reused={}
# Append reused modules, keeping the delivered file independent of its source libraries.
requests={
 'CityBoroughLibrary/City_Boroughs_and_Landmarks.blend':['Merchant party wall','Merchant floor bay','Merchant stepped gable','Merchant narrow roof half','Merchant front door','Tenement plain wall','Tenement passage arch','Tenement gallery floor','Tenement gallery post','Tenement gallery railing','Tenement timber stairs','Tenement stair landing','Terracotta hip roof','Terracotta roof half','Terracotta ridge','Tenement chimney short','Tenement chimney tall','Laundry line','Laundry hanging sheet','Laundry hanging shirt'],
 'HubTownLibrary/HubTown_Component_Library.blend':['Window flower box','Flower box planting','Wall lantern','Straight shop awning','Shop sign rectangular','Hanging sign bracket','Table','Chair','Potted plant','Fountain basin quarter','Fountain pedestal','Fountain lower tier','Fountain upper tier spout','Stone stairs short','Stone parapet straight'],
 'HubTownExpansion/HubTown_Environment_Expansion.blend':['Planted flower box','Wall planter planted','Exposed roots','Ivy patch sparse']}
reuse_root=bpy.data.collections.new('Reused Modules'); scene.collection.children.link(reuse_root)
for file,names in requests.items():
 with bpy.data.libraries.load(str(R/'art'/file),link=False) as (src,dst):
  assert all(n in src.collections for n in names),(file,set(names)-set(src.collections))
  dst.collections=names
 for c in dst.collections:
  reuse_root.children.link(c); reused[c.name]=c; assets[c.name]=c
  # Reposition gallery originals, preserving their authored local geometry.
  idx=len(reused)-1; pos=Vector(((idx%8)*7,-30-(idx//8)*7,0))
  for o in c.objects:
   if o.type=='MESH': o.location=pos
  c.instance_offset=pos

def move(n,xyz):
 for o in pieces[n:]: o.location+=Vector(xyz)
def group(fn,xyz):
 n=len(pieces); fn(); move(n,xyz)
def glazing(w=1,h=1.6):
 box('warm glazing',(0,.015,h/2),(w,.055,h),'WarmGlass')
 for x in [-w/2,0,w/2]: box('window mullion',(x,-.045,h/2),(.055,.1,h+.06),'Timber')
 for z in [0,h/2,h]: box('window rail',(0,-.045,z),(w+.08,.1,.055),'Timber')
def panel(w=4,h=3,openings=(),material='Limewash'):
 # Partition wall around true rectangular openings; no overlay on a solid wall.
 edges=sorted(set([-w/2,w/2]+[x-wi/2 for x,wi,b,hi in openings]+[x+wi/2 for x,wi,b,hi in openings]))
 for a,b in zip(edges,edges[1:]):
  mid=(a+b)/2; hole=next((v for v in openings if v[0]-v[1]/2<mid<v[0]+v[1]/2),None)
  spans=[(0,h)] if hole is None else [(0,hole[2]),(hole[2]+hole[3],h)]
  for low,high in spans:
   if high-low>.001: box('wall masonry',(mid,0,(low+high)/2),(b-a,.3,high-low),material)
def residential(kind='paired',material='Limewash'):
 holes=[(-.92,1.0,.65,1.75),(.92,1.0,.65,1.75)] if kind=='paired' else [(0,1.2,.65,1.75)]
 if kind=='door': holes=[(0,1.2,0,2.3)]
 panel(openings=holes,material=material)
 for x,w,b,h in holes:
  group(lambda:door() if kind=='door' else glazing(w,h),(x,-.18,b))
  if kind=='shutters':
   for side in [-1,1]:
    for j in range(5): box('shutter board',(side*.96,-.21,b+(j+.5)*h/5),(.55,.09,h/5-.025),'Green')
  if kind!='door': box('stone sill',(x,-.15,b-.05),(w+.18,.45,.1),'Limestone')
def gallery_corner():
 residential('door')
 # Return is a short solid wing; no intersecting coplanar wall faces.
 box('corner return',(1.85,.9,1.5),(.3,1.5,3),'Limewash')
def roofroom():
 residential('shutters')
 box('rear',(0,3,1.5),(4,.3,3),'Limewash')
 for x in [-1.85,1.85]: box('side',(x,1.5,1.5),(.3,2.7,3),'Limewash')
 group(lambda:hiproof(4.35,3.35,1.0,'Terracotta'),(0,1.5,3))
def rooftransition():
 prism('height step flashing',[(-2,0),(2,0),(2,.65),(-2,.65)],.12,'Terracotta')
 box('top coping',(0,0,.69),(4,.25,.1),'ClayLight')
def tiled_eave():
 for i in range(16):
  o=cyl('rolled tile',(-1.875+i*.25,0,.06),.105,.45,'ClayLight',8); o.rotation_euler.x=math.pi/2
 box('eave timber',(0,.04,-.1),(4,.25,.15),'Timber')
C='27 Courtyard Apartments'
asset(C,'Apartment paired window wall',lambda:residential())
asset(C,'Apartment shuttered window wall',lambda:residential('shutters'))
asset(C,'Apartment gallery door wall',lambda:residential('door'))
asset(C,'Apartment balcony corner doorway',gallery_corner)
def corbels():
 for x in [-1.5,1.5]:
  o=prism('corbel',[(-.12,0),(.9,.75),(-.12,.75)],.28,'Limestone'); o.rotation_euler.z=-math.pi/2; o.location.x=x
asset(C,'Masonry balcony supports',corbels)
asset(C,'Gallery stair railing',lambda:([beam('handrail',(x,0,1),(x,4.8,4),.09) for x in [-.75,.75]],[beam('baluster',(x,i*.8,i*.5),(x,i*.8,i*.5+1),.07) for x in [-.75,.75] for i in range(7)]))
asset(C,'Apartment rooftop room',roofroom)
asset(C,'Terracotta lean to roof',lambda:shingle_roof(4,3,1,'Terracotta'))
asset(C,'Roof height transition',rooftransition)
asset(C,'Tiled eave',tiled_eave)

def townfacade(style):
 material=['Cream','Rose','SageBlue','Ochre'][style]
 if style==2:
  for x in [-1,1]:
   group(lambda:archwall(2,3,1.15,1.9,.6,.3,material),(x,0,0)); group(lambda:archglass(1.15,1.9,'WarmGlass'),(x,-.18,.6))
 else:
  holes=[(-.95,1.15,.65,1.8),(.95,1.15,.65,1.8)] if style==0 else ([(-1.15,.65,.5,2), (0,.65,.5,2),(1.15,.65,.5,2)] if style==1 else [(0,1.8,.5,2)])
  panel(openings=holes,material=material)
  for x,w,b,h in holes:
   if style!=3: group(lambda:glazing(w,h),(x,-.18,b))
   box('window sill',(x,-.17,b-.05),(w+.16,.42,.1),'Limestone')
 for x in [-1.91,1.91]: box('edge pilaster',(x,-.19,1.5),(.14,.12,3),'Limestone')
 box('floor cornice',(0,-.04,2.91),(4,.43,.18),'Limestone')
def gable(style):
 outlines=[ [(-2,0),(2,0),(0,2.1)], [(-2,0),(2,0),(1.6,.6),(.8,.6),(.8,1.5),(.45,1.5),(.45,2.3),(-.45,2.3),(-.45,1.5),(-.8,1.5),(-.8,.6),(-1.6,.6)], [(-2,0),(2,0),(1.6,.4),(1.45,.8),(1,1),(.75,1.55),(.35,1.8),(-.35,1.8),(-.75,1.55),(-1,1),(-1.45,.8),(-1.6,.4)] ]
 pts=outlines[style]; prism('gable field',pts,.35,['Cream','Rose','Ochre'][style])
 for a,b in zip(pts[1:],pts[2:]): beam('stone gable trim',(a[0],-.22,a[1]),(b[0],-.22,b[1]),.12,'Limestone')
 group(lambda:glazing(.38,.55),(0,-.23,.45))
def boxbay():
 w=1.8; d=.65
 box('bay apron',(0,-d,.15),(w,.13,.3),'Timber'); box('bay head',(0,-d,1.95),(w,.18,.12),'Timber')
 group(lambda:glazing(1.65,1.55),(0,-d,.3))
 for side in [-1,1]:
  box('bay side glazing',(side*.87,-d/2,1.1),(.055,d,1.6),'WarmGlass')
  for y in [0,-d]: box('bay corner',(side*.9,y,1.12),(.08,.08,1.8),'Timber')
 box('bay canopy',(0,-.3,2.08),(2,.95,.12),'Charcoal')
 for x in [-.65,.65]: beam('bay support',(x,0,-.5),(x,-.6,0),.12)
def oriel():
 # Faceted three-sided projection, with oblique side panes.
 box('oriel base',(0,-.4,.12),(1.9,1,.24),'Limestone')
 for x,y,yaw,w in [(0,-.85,0,1.1),(-.72,-.55,-math.pi/4,.8),(.72,-.55,math.pi/4,.8)]:
  n=len(pieces); glazing(w,1.7)
  for o in pieces[n:]: o.location=Matrix.Rotation(yaw,4,'Z')@o.location+Vector((x,y,.24)); o.rotation_euler.z+=yaw
 group(lambda:hiproof(2.05,1.4,.5,'Copper'),(0,-.35,2.0))
 for x in [-.6,.6]: beam('oriel bracket',(x,0,-.45),(x,-.6,0),.13,'Limestone')
C='28 Townhome Variety'
for i,name in enumerate(['Twin sash','Triple slender','Paired arches','Wide bay opening']): asset(C,'Townhome '+name+' facade',lambda i=i:townfacade(i))
for i,name in enumerate(['Peaked','Bell stepped','Scroll']): asset(C,name+' gable',lambda i=i:gable(i))
asset(C,'Rectangular projecting window',boxbay)
asset(C,'Faceted oriel window',oriel)
def cornerfacade():
 townfacade(2)
 n=len(pieces); townfacade(2)
 for o in pieces[n:]: o.location=Matrix.Rotation(math.pi/2,4,'Z')@o.location+Vector((2.15,2.15,0)); o.rotation_euler.z+=math.pi/2
asset(C,'Townhome corner facade',cornerfacade)
asset(C,'Decorative floor band',lambda:(cornice(4),[box('dentil',(-1.85+i*.285,-.2,-.1),(.13,.2,.2),'Limestone') for i in range(14)]))
asset(C,'Party wall roof junction',lambda:(box('party upstand',(0,0,.3),(.28,6,.6),'Brick'),box('weather cap',(0,0,.65),(.42,6,.12),'Limestone')))

def shop(kind):
 # Each frontage includes frames and glazing in real openings, and a distinct door.
 holes=[(-.7,2.1,.4,2),(1.2,1.0,0,2.4)]
 if kind=='residential': holes=[(-1.35,.9,0,2.4),(.65,2.0,.45,1.95)]
 if kind=='restaurant': holes=[(-1.25,1.1,.5,1.9),(.2,1.0,.5,1.9),(1.35,.9,0,2.4)]
 if kind=='recess': holes=[(0,2,0,2.5)]
 panel(openings=holes,material='Limestone')
 for x,w,b,h in holes:
  if b==0:
   if kind=='recess':
    for sx in [-.95,.95]: box('recess return',(sx,.45,1.25),(.1,.9,2.5),'Limestone')
    group(lambda:door(double=True),(x,.9,0))
   else:
    n=len(pieces); door()
    for o in pieces[n:]: o.location.x*=w/1.16; o.scale.x*=w/1.16
    move(n,(x,-.18,0))
  else: group(lambda:glazing(w,h),(x,-.18,b))
 box('shop fascia',(0,-.18,2.72),(4,.15,.35),'Green' if kind=='restaurant' else 'Timber')
 for x in [-1.9,1.9]: box('shop pilaster',(x,-.22,1.25),(.15,.16,2.5),'Timber')
def cornershop():
 shop('restaurant'); n=len(pieces); shop('retail')
 for o in pieces[n:]: o.location=Matrix.Rotation(math.pi/2,4,'Z')@o.location+Vector((2.15,2.15,0)); o.rotation_euler.z+=math.pi/2

def canopy():
 for col in range(12):
  x0=-1.8+col*.3; x1=x0+.3
  for j in range(8):
   a=j*math.pi/16; b=(j+1)*math.pi/16
   verts=[(x0,-1.2*math.sin(a),.9*math.cos(a)),(x1,-1.2*math.sin(a),.9*math.cos(a)),(x1,-1.2*math.sin(b),.9*math.cos(b)),(x0,-1.2*math.sin(b),.9*math.cos(b))]
   mesh('striped canopy',verts,[(0,1,2,3)],'Canvas' if col%2 else 'Red')
  box('valance',((x0+x1)/2,-1.2,-.12),(.3,.035,.24),'Canvas' if col%2 else 'Red')
 for x in [-1.8,1.8]: beam('canopy brace',(x,0,-.6),(x,-1.2,0),.035,'Iron')
def menuboard():
 for y,a in [(-.2,-.16),(.2,.16)]: box('menu panel',(0,y,.65),(.65,.07,1),'Charcoal',(a,0,0))
 for x in [-.36,.36]:
  for y in [-.3,.3]: beam('leg',(x,y,0),(x,0,1.25),.06,'Timber')
 for z,w in [(1,.4),(.85,.48),(.7,.35),(.55,.45)]: box('chalk line',(0,-.29,z),(w,.012,.018),'Canvas')
C='29 Shops and Restaurants'
for kind,name in [('retail','Large glazed shopfront'),('restaurant','Restaurant window frontage'),('residential','Shop with separate residential entrance'),('recess','Recessed restaurant entrance')]: asset(C,name,lambda k=kind:shop(k))
asset(C,'Corner shopfront',cornershop)
asset(C,'Curved striped awning',canopy)
asset(C,'Restaurant menu board',menuboard)
C='30 Sloping Street Connections'
asset(C,'Stepped arcade connector',lambda:(stairs(3,2,.2,.4),[group(lambda:column(3),(x,1,0)) for x in [-.85,.85]],beam('sloped lintel',(-1,1,3),(1,1,3.6),.2,'Limestone')))
asset(C,'Narrow facade infill',lambda:(box('infill',(0,0,1.5),(.4,.32,3),'Limestone'),box('cap',(0,0,2.95),(.5,.45,.1),'Limestone')))
asset(C,'Shopfront foundation height transition',lambda:prism('sloped plinth',[(-2,-.6),(2,-.6),(2,.6),(-2,0)],.45,'StoneLight'))
assert len(catalog)==32,len(catalog)

# Assemble real editable mesh objects with linked source geometry.
assembly_helpers='def begin_assembly(name):'+base.read_text().split('def begin_assembly(name):')[1].split('col=begin_assembly(')[0]
exec(compile(assembly_helpers,str(base),'exec'))
# Helper above defines begin_assembly, place, floors, gable_roof only.
def addfloor(col,x,y,z,w=4,d=3): return place(col,'Merchant floor bay',(x,y,z-.24),scale=(w/3,d/4,1))
def roofhouse(col,z,style=0):
 for yaw in [-math.pi/2,math.pi/2]: place(col,'Merchant narrow roof half',(0,0,z),yaw,scale=(1.5,4/3,[2.1,1.6,1.65,1.6][style]/1.65))
 for y,yaw in [(-3,0),(3,math.pi)]: place(col,['Peaked gable','Bell stepped gable','Merchant stepped gable','Scroll gable'][style],(0,y,z),yaw,scale=(4/3,1,1) if style==2 else (1,1,1))
 place(col,'Tenement chimney short',(-1,1.7,z+.8))
def town(name,style):
 col=begin_assembly(name)
 for z in [0,3,6]:
  for y in [-1.5,1.5]: addfloor(col,0,y,z)
  for x,yaw in [(-2,-math.pi/2),(2,math.pi/2)]:
   place(col,'Merchant party wall',(x,0,z),yaw,scale=(1.5,1,1))
  place(col,'Apartment paired window wall',(0,3,z),math.pi)
  if z:
   key=['Townhome Twin sash facade','Townhome Triple slender facade','Townhome Paired arches facade','Townhome Wide bay opening facade'][style]
   place(col,key,(0,-3,z))
   if style==3: place(col,'Faceted oriel window' if z==6 else 'Rectangular projecting window',(0,-3.18,z+.5))
   if style<3:
    place(col,'Planted flower box',(-.9,-3.3,z+.5),scale=(.7,.7,.7))
  else: place(col,['Large glazed shopfront','Shop with separate residential entrance','Restaurant window frontage','Recessed restaurant entrance'][style],(0,-3,0))
 roofhouse(col,9,style)
 place(col,'Curved striped awning' if style in [2,3] else 'Straight shop awning',(0,-3.3,2.35),scale=(.9,1,1))
 place(col,'Decorative floor band',(0,-3.05,3))
 for x in [-1.8,1.8]: place(col,'Wall lantern',(x,-3.35,2.2),scale=(.65,.65,.65))
 place(col,'Hanging sign bracket',(-1.7,-3.3,2.5)); place(col,'Shop sign rectangular',(-1.7,-3.7,2.0),scale=(.65,.65,.65))
 if style in [2,3]:
  place(col,'Restaurant menu board',(1.3,-4.5,0))
  place(col,'Table',(-.8,-4.4,0),scale=(.7,.7,.7))
  for x in [-1.6,0]: place(col,'Chair',(x,-4.4,0),math.pi/2 if x<0 else -math.pi/2,scale=(.8,.8,.8))
 return col
for i,n in enumerate(['A Cream peaked bookshop','B Rose stepped tailor','C Sage arched cafe','D Ochre oriel restaurant']): town(n,i)

col=begin_assembly('E Courtyard apartment complex')
# Three-story rear wing, two-story side wings, sheltered galleries and roof apartment.
for z in [0,3,6]:
 for x in [-6,-2,2,6]:
  for y,yaw in [(4,0),(8,math.pi)]: place(col,'Apartment gallery door wall' if y==4 and z else 'Apartment paired window wall',(x,y,z),yaw)
  addfloor(col,x,6,z,4,4)
  
  if z: place(col,'Tenement gallery floor',(x,3.1,z-.24))
  if z:
   
   if abs(x)==6: place(col,'Tenement gallery railing',(x,2.38,z))
   else: place(col,'Tenement gallery railing',(-3 if x<0 else 3,2.38,z),scale=(.45,1,1))
   place(col,'Masonry balcony supports',(x,3.8,z-.75))
 for x,yaw in [(-8,-math.pi/2),(8,math.pi/2)]: place(col,'Apartment shuttered window wall',(x,6,z),yaw)
for x in [-6,6]:
 for z in [0,3]:
  for y in [-2,2]:
   addfloor(col,x,y,z,4,4)
   for dx,yaw in [(-2,-math.pi/2),(2,math.pi/2)]: place(col,'Apartment shuttered window wall',(x+dx,y,z),yaw)
  place(col,'Tenement passage arch' if z==0 else 'Apartment paired window wall',(x,-4,z))
 # side roofs: hip ends behind and an elevated rooftop room in front.
 place(col,'Terracotta hip roof',(x,1.2,6),scale=(1,.6,1))
 place(col,'Apartment rooftop room',(x,-4,6))
 place(col,'Roof height transition',(x,0,6))
 place(col,'Terracotta lean to roof',(x,0,6),scale=(1,1/3,1))
for x in [-6,-2,2,6]:
 for yaw in [0,math.pi]: place(col,'Terracotta roof half',(x,6,9),yaw)
 place(col,'Terracotta ridge',(x,6,10.5))
 place(col,'Tiled eave',(x,3.9,9))
for x in [-8,8]: place(col,'Peaked gable',(x,6,9),math.pi/2,scale=(1,1,1.5/2.1))
for z,x in [(0,-.9),(3,.9)]:
 place(col,'Tenement timber stairs',(x,-2.4,z)); place(col,'Gallery stair railing',(x,-2.4,z))
# Return gallery connects the lower flight's rear landing to the upper flight's front start.
place(col,'Tenement gallery floor',(2.9,-.025,2.76),math.pi/2,scale=(4.75/4,1,1))
place(col,'Tenement gallery floor',(1.8,-2.85,2.76),scale=(1,.6,1))
place(col,'Tenement gallery railing',(2.15,0,3),math.pi/2,scale=(1.2,1,1))
place(col,'Tenement gallery railing',(1.8,-3.3,3))
for z in [0,3]:
 for x in [-7.8,-4.2,4.2,7.8]: place(col,'Tenement gallery post',(x,2.4,z))
place(col,'Laundry line',(0,2.35,5)); place(col,'Laundry hanging sheet',(-.8,2.35,3.7)); place(col,'Laundry hanging shirt',(.8,2.35,4.2))
for x in [-6,6]:
 place(col,'Tenement chimney short',(x,1.8,7))
 for z in [3,6]: place(col,'Planted flower box',(x,-4.25,z+.5))
for x in [-1.8,1.8]: place(col,'Potted plant',(x,-3.8,0))
# Small court fountain leaves the stairs' approach clear.
for a in [0,math.pi/2,math.pi,math.pi*1.5]: place(col,'Fountain basin quarter',(0,-5.6,0),a,scale=(.5,.5,.5))
for key in ['Fountain pedestal','Fountain lower tier','Fountain upper tier spout']: place(col,key,(0,-5.6,0),scale=(.5,.5,.5))

# Stone courtyard paving, extending to the gallery and both wings.
for x in [-2,2]:
 for y in [-2,2]:
  ob=addfloor(col,x,y,0,4,4); ob.data=ob.data.copy()
  for slot in ob.material_slots: slot.material=M['StoneLight']
for x in [-6,-2,2,6]:
 ob=addfloor(col,x,-5.5,0,4,3); ob.data=ob.data.copy()
 for slot in ob.material_slots: slot.material=M['StoneLight']

col=begin_assembly('F Corner restaurant apartments')
# 4 x 4 corner block. Corner parts cover south and east, with no second wall behind them.
for z in [0,3,6]:
 place(col,'Corner shopfront' if z==0 else 'Townhome corner facade',(0,-2.15,z))
 place(col,'Apartment paired window wall',(0,2,z),math.pi)
 place(col,'Apartment shuttered window wall',(-2,0,z),-math.pi/2)
 addfloor(col,0,0,z,4,4)
place(col,'Terracotta hip roof',(0,0,9),scale=(1.1,1.1,1))
place(col,'Tenement chimney short',(-1.1,1.1,9.6))
for pos,yaw in [((0,-2.35,2.35),0),((2.35,0,2.35),math.pi/2)]: place(col,'Curved striped awning',pos,yaw)
for x in [-1.1,1.1]:
 place(col,'Table',(x,-3.8,0),scale=(.65,.65,.65))
 for y in [-3.1,-4.5]: place(col,'Chair',(x,y,0),0 if y<-4 else math.pi,scale=(.7,.7,.7))
place(col,'Restaurant menu board',(2.9,-2.5,0))

# Continuous street: shared party walls owned by one neighbor, stepped sidewalks.
row=begin_assembly('G Connected sloping shopping street')
for i,(name,col) in enumerate(list(assemblies.items())[:4]):
 offset=Vector((i*4,0,i*.6))
 for source in col.objects:
  # Remove west walls of all but the first home; adjacent east wall owns seam.
  if i and source.get('module')=='Merchant party wall' and source.location.x<0: continue
  ob=source.copy(); ob.data=source.data; row.objects.link(ob); ob.location+=offset
  if i<3 and source.get('module')=='Restaurant menu board': ob.location.x=i*4+.35
 # Fill the extra 0.6m wall exposed above the lower neighbor.
 if i: place(row,'Merchant party wall',(i*4-2,0,9+(i-1)*.6),-math.pi/2,scale=(1.5,1,.2))
 place(row,'Shopfront foundation height transition',(i*4,-3.05,i*.6-.6))
 for y in [-1.5,1.5]: addfloor(row,i*4,y,i*.6-.01,4,3)
 # Pavement is a reused floor mesh with an independent stone material copy.
 ob=addfloor(row,i*4-(.6 if i<3 else 0),-4.8,i*.6,2.8 if i<3 else 4,3.3); ob.data=ob.data.copy()
 for slot in ob.material_slots: slot.material=M['StoneLight']
 if i<3:
  # 0.6m stair connection along the direction of the street.
  place(row,'Stone stairs short',(i*4+.8,-4.8,i*.6),-math.pi/2,scale=(1.65,.5,.4))
 place(row,'Party wall roof junction',(i*4+2,0,9+i*.6))
# Remove duplicate complete ground floors in row: foundations already provide support.
# Architectural floors remain; no additional slabs overlap them.
for o in list(row.objects):
 if o.get('module')=='Merchant floor bay' and abs(o.location.y)==1.5 and any(abs(o.location.z-(i*.6-.25))<1e-5 for i in range(4)):
  row.objects.unlink(o); bpy.data.objects.remove(o)

# Documentation metadata and scene presentation.
assembly_info=[{'name':n,'objects':len(c.objects),'mesh_objects':sum(o.type=='MESH' for o in c.objects)} for n,c in assemblies.items()]
catids={cat:str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/residential/'+cat)) for cat in category_counts}
for r in catalog: assets[r['name']].asset_data.catalog_id=catids[r['kit']]
for label,cols in [('31 Reused Modules',reused),('32 Residential Assemblies',assemblies)]:
 uid=str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/residential/'+label)); catids[label]=uid
 for c in cols.values(): c.asset_mark(); c.asset_data.catalog_id=uid
(OUT/'blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{v}:{k}:{k}' for k,v in catids.items())+'\n')
src=helper_path.read_text(); exec(compile(src[src.index('def camera_light('):src.index('camera_light(example,')],str(helper_path),'exec'))
renders=[]
for name,col in assemblies.items():
 sc=bpy.data.scenes.new(name); sc.collection.children.link(col); sc.unit_settings.system='METRIC'; bpy.context.window.scene=sc; bpy.context.view_layer.update()
 pts=[o.matrix_world@Vector(v) for o in col.objects if o.type=='MESH' for v in o.bound_box]
 lo=Vector([min(p[k] for p in pts) for k in range(3)]); hi=Vector([max(p[k] for p in pts) for k in range(3)]); center=(lo+hi)/2; extent=max(hi-lo)
 camera_light(sc,center+Vector((extent*.95,-extent*1.8,extent*.9)),center,extent*1.8)
 sc.render.resolution_x=1600; sc.render.resolution_y=1300; sc.render.filepath=str(OUT/(name[0]+'_assembly.png')); renders.append(sc)
overview=bpy.data.scenes.new('01 Residential Overview')
for i,(name,col) in enumerate(list(assemblies.items())[:6]):
 ob=bpy.data.objects.new(name,None); overview.collection.objects.link(ob); ob.instance_type='COLLECTION'; ob.instance_collection=col; ob.location=((i%4)*12,(i//4)*22,0)
camera_light(overview,(50,-68,55),(17,8,4),72); overview.render.resolution_x=2000; overview.render.resolution_y=1500; overview.render.filepath=str(OUT/'residential_overview.png')
for cat in category_counts:
 sc=bpy.data.scenes.new(cat+' Sheet'); recs=[r for r in catalog if r['kit']==cat]
 for i,r in enumerate(recs):
  ob=bpy.data.objects.new(r['name'],None); sc.collection.objects.link(ob); ob.instance_type='COLLECTION'; ob.instance_collection=assets[r['name']]; ob.location=((i%4)*8,(i//4)*8,0); scale=min(1.4,5/max(r['dimensions_m'])); ob.scale=(scale,)*3
  td=bpy.data.curves.new('Caption','FONT'); td.body=r['name']; td.size=.23; td.materials.append(M['Canvas']); txt=bpy.data.objects.new('Caption',td); sc.collection.objects.link(txt); txt.location=ob.location+Vector((-3,-2.7,0))
 rows=math.ceil(len(recs)/4); camera_light(sc,(20,-32,40),(12,(rows-1)*4,0),40); sc.render.resolution_x=1600; sc.render.resolution_y=1300; sc.render.filepath=str(OUT/(cat[:2]+'_contact_sheet.png')); renders.append(sc)
bpy.context.window.scene=overview
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_location=(17,8,4); area.spaces.active.region_3d.view_distance=75; area.spaces.active.region_3d.view_rotation=Vector((33,-76,51)).to_track_quat('Z','Y')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Residential_Streets_and_Apartments.blend'))
(OUT/'component_inventory.json').write_text(json.dumps({'count':len(catalog),'categories':category_counts,'components':catalog,'reused_components':list(reused),'assemblies':assembly_info},indent=2)+'\n')
print('RESIDENTIAL_SAVED',len(catalog),len(assemblies),flush=True)
import sys
selected=[overview]+renders
if '--apartment-only' in sys.argv: selected=[overview]+[sc for sc in renders if sc.name.startswith('E Courtyard')]
for sc in selected:
 bpy.context.window.scene=sc; bpy.ops.render.render(write_still=True)
print('RESIDENTIAL_RENDERED',flush=True)
