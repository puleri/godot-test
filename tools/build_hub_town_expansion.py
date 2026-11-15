"""Remaining environment modules; preserves the first library and manual edits."""
from pathlib import Path
helper_path=Path(__file__).with_name('build_hub_town_library.py')
helpers=helper_path.read_text().split('# BUILDING STRUCTURE')[0]
helpers=helpers.replace("R/'art/HubTownLibrary'", "R/'art/HubTownExpansion'")
exec(compile(helpers,str(helper_path),'exec'))
scene.name='00 Environment Assets'
mat('Moss',(.12,.19,.045)); mat('Flower',(.61,.18,.32)); mat('FlowerGold',(.9,.56,.10)); mat('Dirt',(.19,.13,.075)); mat('Bark',(.12,.065,.032))
mat('LeafDark',(.055,.15,.045)); mat('Mortar',(.18,.19,.18)); mat('StoneWarm',(.35,.33,.29))
random.seed(71)

def move_group(begin,delta):
 for ob in pieces[begin:]: ob.location+=Vector(delta)

def leaf(loc,size=.12,material='Leaf',angle=0):
 ob=mesh('pointed leaf',[(0,0,0),(-size*.42,0,size*.42),(0,-size*.12,size*.6),(size*.42,0,size*.42),(0,0,size)],[(0,1,2),(0,2,3),(1,4,2),(2,4,3)],material); ob.location=loc; ob.rotation_euler=(random.uniform(-.6,.6),random.uniform(-.5,.5),angle)
 return ob

def cluster(center,r=.6,count=65):
 center=Vector(center)
 uvball('inner foliage mass',center,(r*.72,r*.72,r*.48),'LeafDark',9,5)
 for i in range(count):
  t=random.uniform(0,math.tau); z=random.uniform(-1,1); rr=math.sqrt(1-z*z)*r
  p=center+Vector((rr*math.cos(t),rr*math.sin(t),z*r*.65))
  leaf(p,random.uniform(.22,.38),random.choice(['Leaf','Green','LeafDark']),t)

def tree(narrow=False,pine=0):
 h=5 if narrow else 7
 if pine:
  h=5+pine; cyl('pine trunk',(0,0,h*.45),.16,h*.9,'Bark',10,r2=.055)
  for j in range(5):
   z=1+j*(h-1)/5; r=(h-z)*.29
   cyl('needle tier',(0,0,z+.6),r,1.5,'LeafDark' if j%2 else 'Green',9,r2=.035)
  return
 cyl('trunk',(0,0,h*.25),.28 if not narrow else .18,h*.5,'Bark',10,r2=.11)
 for i in range(7):
  t=i*2.4; spread=.7 if narrow else 1.7
  end=(spread*math.cos(t),spread*math.sin(t),h*.48+i*.24)
  beam('branch',(0,0,1.5+i*.15),end,.12,'Bark')
  cluster(end,.7 if narrow else 1.15,100)
 cluster((0,0,h*.85),.8 if narrow else 1.2,110)
 for i in range(5):
  t=i*math.tau/5; beam('root',(0,0,.2),(.65*math.cos(t),.65*math.sin(t),.02),.10,'Bark')

def shrub(sprawl=False):
 for i in range(4):
  c=((i-1.5)*.35,.12*math.sin(i),.35 if sprawl else .65)
  beam('twig',(0,0,0),c,.045,'Bark'); cluster(c,.4 if sprawl else .55,55)

def grass(dry=False):
 for i in range(25):
  x,y=random.uniform(-.22,.22),random.uniform(-.22,.22); h=random.uniform(.18,.5)
  ob=mesh('grass blade',[(x-.02,y,0),(x+.02,y,0),(x+.08,y+.03,h*.65),(x+.10,y+.05,h)],[(0,1,2),(0,2,3)],'Canvas' if dry else 'Green')

def flowers():
 for i in range(9):
  x,y=random.uniform(-.3,.3),random.uniform(-.23,.23); h=random.uniform(.25,.5)
  beam('stem',(x,y,0),(x,y,h),.014,'Green')
  for j in range(5):
   t=j*math.tau/5; uvball('petal',(x+.06*math.cos(t),y+.06*math.sin(t),h),(.055,.035,.025),'Flower' if i%2 else 'FlowerGold',6,3)
  uvball('center',(x,y,h+.02),(.025,.025,.025),'FlowerGold',6,3)

def ivy(dense=False,hanging=False,corner=False):
 n=5 if dense else 2
 for strand in range(n):
  last=None
  for j in range(15):
   z=(2.2-j*.15) if hanging else j*.15
   x=(strand-(n-1)/2)*.22+.12*math.sin(j*.8+strand)
   y=.12*math.cos(j*.4) if corner else 0
   p=(x,y,z)
   if last: beam('vine',last,p,.018,'Bark')
   for side in [-1,1]: leaf((x+side*.07,y-.015,z),.18, 'LeafDark' if j%3==0 else 'Leaf',side*.8)
   last=p

def masonry(width=4,height=3,depth=.5):
 rows=round(height/.375); rh=height/rows
 for row in range(rows):
  # Staggered courses terminate precisely at module boundary.
  ends=[-width/2]; x=-width/2+(.4 if row%2 else .8)
  while x<width/2-.001: ends.append(x); x+=.8
  ends.append(width/2)
  for a,b in zip(ends,ends[1:]):
   box('masonry block',((a+b)/2,0,(row+.5)*rh),(b-a-.018,depth,rh-.018),random.choice(['Stone','StoneWarm','StoneLight']))

def cap_corner():
 box('cap',(0,0,.1),(1,.7,.2),'StoneLight'); box('return',(.15,.7,.1),(.7,.7,.2),'StoneLight')

def gate_arch():
 arch(4,5,2,.5)
 # Fill above the extrados, keeping the passage open and top level at six meters.
 for i in range(16):
  a=i*math.pi/16; b=(i+1)*math.pi/16
  x1,z1=2.5*math.cos(a),3+2.5*math.sin(a); x2,z2=2.5*math.cos(b),3+2.5*math.sin(b)
  prism('arch infill',[(x1,z1),(x1,6),(x2,6),(x2,z2)],2,'Stone')
 for side in [-1,1]:
  begin=len(pieces); masonry(1.5,6,2); move_group(begin,(side*3.25,0,0))
 box('gate crown',(0,0,6.1),(8.2,2.2,.2),'StoneLight')

def vaulted_ceiling():
 r=2
 for i in range(16):
  a=i*math.pi/16; b=(i+1)*math.pi/16
  prism('vault segment',[(r*math.cos(a),r*math.sin(a)),((r+.22)*math.cos(a),(r+.22)*math.sin(a)),((r+.22)*math.cos(b),(r+.22)*math.sin(b)),(r*math.cos(b),r*math.sin(b))],2,'StoneWarm')

def gate_leaf(right=False):
 direction=-1 if right else 1
 for i in range(8):
  a=i*.245+.006; b=(i+1)*.245-.006
  ha=3+math.sqrt(max(0,4-(2-a)**2)); hb=3+math.sqrt(max(0,4-(2-b)**2))
  prism('arched gate plank',[(direction*a,0),(direction*b,0),(direction*b,hb),(direction*a,ha)],.18,'Wood')
 for z in [.4,2,3.6]:
  box('iron strap',(direction*.98,-.13,z),(1.92,.065,.13),'Iron')
  for i in range(5): uvball('rivet',(direction*(.15+i*.4),-.17,z),(.025,.02,.025),'Iron',6,3)
 for z in [.4,3.6]: cyl('hinge pin',(0,0,z),.06,.38,'Iron')
 beam('diagonal',(direction*.1,-.12,.2),(direction*1.85,-.12,3.8),.14)

def tower_base():
 for y in [-2,2]:
  begin=len(pieces); masonry(4,3,.55); move_group(begin,(0,y,0))
 for x in [-2,2]:
  begin=len(pieces); masonry(3.45,3,.55)
  for ob in pieces[begin:]: ob.rotation_euler.z=math.pi/2; ob.location=Vector((x,-ob.location.x,ob.location.z))

def slitwall():
 for x in [-1.13,1.13]: box('pier',(x,0,1.5),(1.74,.55,3),'Stone')
 box('sill',(0,0,.5),(.52,.55,1),'Stone'); box('lintel',(0,0,2.65),(.52,.55,.7),'Stone')
 for x in [-.31,.31]: box('dressed jamb',(x,-.29,1.65),(.16,.12,1.3),'StoneLight')

def lookout():
 plankdeck(5,5)
 for x in [-2.3,2.3]:
  for y in [-2.3,2.3]: box('upright',(x,y,1.5),(.22,.22,3))
 for y in [-2.3,2.3]:
  for z in [.4,1,2.9]: box('rail',(0,y,z),(4.6,.16,.16))
  for x in [-1.8,-1.2,-.6,0,.6,1.2,1.8]: box('baluster',(x,y,.65),(.08,.08,.7))
 for x in [-2.3,2.3]:
  for z in [.4,1,2.9]: box('rail',(x,0,z),(.16,4.6,.16))
 for x,y in [(-2.3,-2.3),(2.3,-2.3),(-2.3,2.3),(2.3,2.3)]:
  beam('brace',(x,y,2),(x*.6,y,2.9),.12)

def pyramid_roof():
 # Solid hip shell with seam battens.
 verts=[(-2.8,-2.8,0),(2.8,-2.8,0),(2.8,2.8,0),(-2.8,2.8,0),(0,0,2.6)]
 mesh('hip roof',verts,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],'Slate')
 for x,y in [(-2.8,-2.8),(2.8,-2.8),(2.8,2.8),(-2.8,2.8)]: beam('hip trim',(x,y,0),(0,0,2.6),.10,'Iron')
 for j in range(1,8):
  z=j*.30; half=2.8*(1-z/2.6)
  for y in [-half,half]: box('slate course',(0,y,z),(half*2,.035,.04),'Slate')
  for x in [-half,half]: box('slate course',(x,0,z),(.035,half*2,.04),'Slate')
 cyl('finial',(0,0,2.85),.06,.5,'Iron',8,r2=.025)

def rock(scale=(3,2,3),seed=1):
 rng=random.Random(seed); ob=uvball('irregular rock',(0,0,scale[2]*.7),scale,'StoneWarm',9,5)
 for v in ob.data.vertices:
  v.co.x*=rng.uniform(.82,1.15); v.co.y*=rng.uniform(.85,1.1); v.co.z*=rng.uniform(.9,1.12)

def terrace(w=8,d=8,h=3):
 box('earth core',(0,0,h/2),(w,d,h),'Dirt')
 for x in [-w/2,w/2]:
  for y in [-d/2,d/2]:
   begin=len(pieces); rock((.7,.65,h*.65),int((x+10)*(y+10))); move_group(begin,(x,y,-.4))
 box('soil top',(0,0,h-.04),(w,d,.1),'Dirt')

def balcony():
 plankdeck(4,1.5)
 for x in [-1.9,1.9]: box('rail post',(x,-.7,.6),(.12,.12,1.2))
 for z in [.4,1.1]: box('rail',(0,-.7,z),(4,.12,.12))
 for x in [-1.5,-1,-.5,0,.5,1,1.5]: box('baluster',(x,-.7,.7),(.08,.08,.65))
 for x in [-1.5,1.5]: beam('support',(x,.6,-1),(x,-.6,0),.15)

def baywindow():
 for x in [-.75,.75]: box('side',(x,-.3,1),(.12,.8,2),'Timber')
 box('glass',(0,-.7,1),(1.5,.06,1.7),'Glass')
 for x in [-.8,0,.8]: box('mullion',(x,-.75,1),(.09,.12,2))
 for z in [.1,1,1.9]: box('rail',(0,-.75,z),(1.7,.12,.1))
 box('base',(0,-.3,0),(1.8,1,.16),'Wood')
 mesh('bay roof',[(-1,.2,2.0),(1,.2,2.0),(-1,-.9,2),(1,-.9,2),(0,.2,2.5),(0,-.9,2.5)],[(0,2,5,4),(4,5,3,1),(0,4,1),(2,3,5)],'Slate')

def irregular_paving():
 for row in range(10):
  x=-2
  while x<1.99:
   length=min(random.uniform(.32,.65),2-x)
   box('cobble',(x+length/2,-1.8+row*.4,.06),(max(.015,length-.015),.38,.12),'StoneWarm' if random.random()<.6 else 'StoneLight')
   x+=length

def cloth_sag():
 n=12; vs=[]
 for j in range(5):
  y=-1+j*.5
  for i in range(n+1):
   x=-1.5+3*i/n; z=.32*(1-(y*y))-.10*math.sin(math.pi*i/n)
   vs.append((x,y,z))
 fs=[(j*(n+1)+i,j*(n+1)+i+1,(j+1)*(n+1)+i+1,(j+1)*(n+1)+i) for j in range(4) for i in range(n)]
 ob=mesh('sagging cloth',vs,fs,'Canvas')
 for x in [-1.5,1.5]:
  for y in [-1,1]: beam('tie',(x,y,0),(x*1.12,y*1.12,-.3),.025,'Canvas')

C='09 Trees and Plants'
asset(C,'Mature broadleaf tree',tree)
asset(C,'Narrow courtyard tree',lambda:tree(True))
for i in range(1,4): asset(C,'Hillside pine '+str(i),lambda i=i:tree(pine=i))
asset(C,'Branching tree trunk',lambda:(cyl('trunk',(0,0,1.5),.25,3,'Bark',10,r2=.1),beam('branch',(0,0,1.8),(1,0,3),.12,'Bark'),beam('branch',(0,0,2),(-.8,.4,3.3),.1,'Bark')))
asset(C,'Broadleaf canopy cluster',lambda:cluster((0,0,.7),1,150))
asset(C,'Rounded shrub',shrub)
asset(C,'Sprawling shrub',lambda:shrub(True))
asset(C,'Hedge straight',lambda:[cluster((x,0,.65),.6,75) for x in [-.75,0,.75]])
asset(C,'Hedge corner',lambda:[cluster((x,y,.65),.6,65) for x,y in [(-.7,0),(0,0),(0,.7)]])
asset(C,'Grass tuft green',grass)
asset(C,'Grass tuft dry',lambda:grass(True))
asset(C,'Flower patch',flowers)
asset(C,'Planted flower box',lambda:(box('box',(0,0,.17),(1.5,.4,.34),'Wood'),[leaf((x,0,.3),.3,'Green') for x in [-.5,-.25,0,.25,.5]],(lambda b:(flowers(),move_group(b,(0,0,.35))))(len(pieces))))
asset(C,'Wall planter planted',lambda:(pot(True),(lambda b:(flowers(),move_group(b,(0,0,.8))))(len(pieces))))
for label,dense,hanging,corner in [('Ivy patch sparse',False,False,False),('Ivy patch dense',True,False,False),('Hanging vines',True,True,False),('Corner wrapping ivy',True,False,True),('Bridge trailing plant',False,True,True)]: asset(C,label,lambda d=dense,h=hanging,c=corner:ivy(d,h,c))

C='10 Gatehouse and Fortifications'
asset(C,'Complete gate arch surround',gate_arch,'8 m outer width; 4 m clear opening; 2 m passage depth; crown 6.2 m.')
asset(C,'Gate side masonry',lambda:masonry(2,6,2))
asset(C,'Gate overhead masonry',lambda:masonry(4,1,2))
asset(C,'Passage vaulted ceiling',vaulted_ceiling,'4 m clear span; spring plane Z=0; place at gate spring height Z=3.')
asset(C,'Passage sidewall',lambda:masonry(2,3,.4))
asset(C,'Gate threshold',lambda:box('threshold',(0,0,.1),(4,2,.2),'StoneLight'))
for right in [False,True]: asset(C,'Hinged gate '+('right' if right else 'left'),lambda r=right:gate_leaf(r),'Origin is hinge axis at base. Rotate about local Z to open.')
asset(C,'Fort wall block bay',lambda:masonry(4,6,1))
asset(C,'Corner quoin stack',lambda:[box('quoin',(0,0,.2+i*.4),(.75 if i%2 else .5,.5 if i%2 else .75,.38),'StoneLight') for i in range(15)])
asset(C,'Fort wall buttress',lambda:prism('tapered buttress',[(-.6,0),(.6,0),(.35,5),(-.35,5)],1.3,'Stone'))
asset(C,'Fort wall coping',lambda:box('coping',(0,0,.12),(4,1.15,.24),'StoneLight'))
asset(C,'Capped battlement bay',lambda:(masonry(4,.8,.6),[box('merlon',(x,0,1.1),(.65,.6,.6),'Stone') for x in [-1.6,-.5,.5,1.6]],[box('merlon cap',(x,0,1.45),(.75,.7,.1),'StoneLight') for x in [-1.6,-.5,.5,1.6]]))
asset(C,'Wall top walkway',lambda:(box('walkway',(0,0,.15),(4,2,.3),'Stone'),box('inner parapet',(0,.9,.75),(4,.2,1.2),'Stone')))
asset(C,'Wall to tower collar',lambda:(box('collar',(0,0,1.5),(1.2,1.2,3),'Stone'),box('cap',(0,0,3.1),(1.4,1.4,.2),'StoneLight')))
asset(C,'Wall height transition',lambda:prism('stepped join',[(-2,0),(2,0),(2,6),(0,6),(0,3),(-2,3)],1,'Stone'))
asset(C,'Battlement stair flight',lambda:stairs(12,1.5))
asset(C,'Upper gate landing',lambda:(box('landing',(0,0,.15),(4,3,.3),'Stone'),box('edge rail',(0,1.4,.7),(4,.2,1.1),'Stone')))

C='11 Watchtower'
asset(C,'Tower masonry base',tower_base,'4 m square perimeter; hollow center; stack in 3 m increments.')
asset(C,'Tower entrance wall',lambda:arch(1.3,2.4,.55,.4))
asset(C,'Tower slit window wall',slitwall)
asset(C,'Tower lookout transition',lambda:(box('ring front',(0,-2.1,.15),(4.8,.5,.3),'StoneLight'),box('ring back',(0,2.1,.15),(4.8,.5,.3),'StoneLight'),box('ring side',(-2.1,0,.15),(.5,3.7,.3),'StoneLight'),box('ring side',(2.1,0,.15),(.5,3.7,.3),'StoneLight')))
asset(C,'Tower stone corbel',lambda:prism('corbel',[(-.3,0),(.3,0),(.3,.8),(-.7,.8)],.45,'StoneLight'))
asset(C,'Complete lookout frame',lookout)
asset(C,'Lookout railing bay',lambda:railing(4.6))
asset(C,'Lookout corner brace',lambda:(beam('brace',(0,0,0),(1,0,1),.16),beam('return',(0,0,0),(0,1,1),.16)))
asset(C,'Complete watchtower hip roof',pyramid_roof)
asset(C,'Tower roof finial',lambda:(cyl('finial',(0,0,.35),.055,.7,'Iron'),uvball('orb',(0,0,.55),(.12,.12,.12),'Iron')))

C='12 Terrain and Retaining Walls'
asset(C,'Raised terrain platform',terrace)
asset(C,'Half terrace platform',lambda:terrace(4,8,3))
asset(C,'Vertical cliff face',lambda:rock((4,1.2,3),9))
asset(C,'Rock ledge',lambda:rock((3,1.5,.5),12))
asset(C,'Rock slope transition',lambda:prism('rock slope',[(-2,0),(2,0),(2,3),(-2,.3)],4,'StoneWarm'))
for i in range(3): asset(C,'Terrain masonry filler '+str(i+1),lambda i=i:rock((1.4,1,1.1),20+i))
asset(C,'Detailed retaining bay',lambda:masonry(4,3,.6))
asset(C,'Retaining reinforced corner',lambda:(retaining_corner(False),[box('corner block',(0,-.34,.2+i*.4),(.65,.16,.38),'StoneLight') for i in range(7)]))
asset(C,'Retaining buttress',lambda:prism('buttress',[(-.4,0),(.4,0),(.25,3),(-.25,3)],.9,'StoneWarm'))
asset(C,'Retaining arched niche',lambda:arch(1.4,2.4,.65,.35,True))
asset(C,'Stair following coping',lambda:beam('sloped cap',(0,0,0),(0,2.4,1.5),.35,'StoneLight',.45))
asset(C,'Retaining cap corner detailed',cap_corner)
asset(C,'Retaining height step cap',lambda:(box('lower cap',(-1,0,.1),(2,.75,.2),'StoneLight'),box('riser',(0,0,.85),(.2,.75,1.5),'StoneLight'),box('upper cap',(1,0,1.6),(2,.75,.2),'StoneLight')))

C='13 Bridges and Water Edge'
asset(C,'Dressed bridge arch stones',lambda:arch(4,3,.45,.5))
def spandrel():
 for i in range(16):
  a=i*math.pi/16; b=(i+1)*math.pi/16
  x1,z1=2.5*math.cos(a),1+2.5*math.sin(a); x2,z2=2.5*math.cos(b),1+2.5*math.sin(b)
  coords=[(x1,z1),(x1,3.6),(x2,3.6),(x2,z2)]
  prism('arched spandrel panel',coords,.25,'StoneWarm')
asset(C,'Bridge spandrel facade',spandrel,'Matches a 4 m clear-span arch with 0.5 m voussoirs; spring at Z=1.')
asset(C,'Bridge street abutment',lambda:(masonry(3,3,1.5),box('seat',(0,0,3.1),(3.2,1.8,.2),'StoneLight')))
asset(C,'Bridge parapet corner join',lambda:(railing(1,True),box('return',(.36,.65,.45),(.28,1,.9),'Stone'),cap_corner()))
asset(C,'Covered bridge entrance',lambda:(box('post',(-1.5,0,1.5),(.25,.25,3)),box('post',(1.5,0,1.5),(.25,.25,3)),beam('left gable',(-1.7,0,3),(0,0,4.2),.18),beam('right gable',(1.7,0,3),(0,0,4.2),.18),box('lintel',(0,0,3),(3,.2,.2))))
asset(C,'Waterline masonry bay',lambda:(masonry(4,2,.6),[box('moss stain',(x,-.31,.25),(.6,.02,.35),'Moss') for x in [-1.5,-.6,.4,1.4]]))
asset(C,'Water access steps',lambda:stairs(8,1.5,.25,.35))
asset(C,'Culvert grate arch',lambda:(arch(1.4,1.8,.3,.2),[box('grate bar',(x,0,.7),(.05,.08,1.4),'Iron') for x in [-.6,-.4,-.2,0,.2,.4,.6]]))
asset(C,'Drainage outlet pipe',lambda:(lambda o:setattr(o.rotation_euler,'x',math.pi/2))(ring('pipe',(0,0,.3),.3,.22,.8,'Stone')))
asset(C,'Canal maintenance walkway',lambda:(plankdeck(4,.8),[beam('support',(x,0,-.8),(x,-.4,0),.14) for x in [-1.5,1.5]]))

C='14 Building and Roof Variants'
asset(C,'Narrow timber facade',lambda:wall('window',True,2))
asset(C,'Tall timber facade',lambda:(wall('window',True),box('extra upper field',(0,0,3.5),(4,.3,1),'Plaster'),box('top tie',(0,0,4),(4,.36,.2))))
asset(C,'Projected upper story floor',lambda:(plankdeck(4,2),[beam('bracket',(x,.7,-1),(x,-.7,0),.18) for x in [-1.5,1.5]]))
asset(C,'Bay window assembly',baywindow)
asset(C,'Timber balcony section',balcony)
asset(C,'Recessed shop entrance',lambda:(box('left return',(-.8,.4,1.5),(.2,1,3),'Stone'),box('right return',(.8,.4,1.5),(.2,1,3),'Stone'),box('ceiling',(0,.4,3),(1.8,1,.2),'Wood'),(lambda b:(door(),move_group(b,(0,.9,0))))(len(pieces))))
asset(C,'Attached lean to shed',lambda:(box('back',(0,.7,1.1),(2,.15,2.2),'Wood'),box('side',(-1,0,1),(.15,1.5,2),'Wood'),box('side',(1,0,1),(.15,1.5,2),'Wood'),mesh('lean roof',[(-1.2,-.9,1.8),(1.2,-.9,1.8),(1.2,.9,2.4),(-1.2,.9,2.4)],[(0,1,2,3)],'Slate')))
asset(C,'Hip roof corner finished',lambda:(mesh('hip panel',[(-2,-2,0),(2,-2,0),(0,0,1.5)],[(0,1,2)],'Slate'),beam('hip edge',(-2,-2,0),(0,0,1.5),.12,'Iron'),beam('hip edge',(2,-2,0),(0,0,1.5),.12,'Iron')))
asset(C,'Roof valley flashing',lambda:mesh('valley flashing',[(-2,-.2,0),(2,-.2,0),(2,0,-.15),(-2,0,-.15),(-2,.2,0),(2,.2,0)],[(0,1,2,3),(3,2,5,4)],'Iron'))
asset(C,'Roof wall flashing',lambda:(box('upstand',(0,0,.15),(4,.025,.3),'Iron'),box('apron',(0,-.15,0),(4,.3,.025),'Iron')))
asset(C,'Overhanging eave detail',lambda:(box('fascia',(0,0,.12),(4,.15,.24)),[beam('rafter tail',(x,.3,0),(x,-.5,-.12),.10) for x in [-1.8,-1.2,-.6,0,.6,1.2,1.8]]))
for side in [-1,1]: asset(C,'Dormer sidewall '+('left' if side<0 else 'right'),lambda s=side:prism('cheek',[(s*x,z) for x,z in [(0,0),(1.2,0),(1.2,1),(0,.3)]],.15,'Plaster'))
asset(C,'Chimney flashing collar',lambda:(box('front',(0,-.4,.05),(1,.25,.1),'Iron'),box('back',(0,.4,.05),(1,.25,.1),'Iron'),box('left',(-.4,0,.05),(.25,.55,.1),'Iron'),box('right',(.4,0,.05),(.25,.55,.1),'Iron')))
asset(C,'Weathered slate roof panel',lambda:roof(opening=True),'Missing slates expose an opening; use backing/sheathing where required.')
asset(C,'Roof sheathing panel',lambda:box('roof boards',(0,0,.04),(4,2.5,.08),'Wood'))

C='15 Streets and Ground Dressing'
asset(C,'Irregular cobblestone bay',irregular_paving)
asset(C,'Curved street border',lambda:[(lambda ob,t:setattr(ob.rotation_euler,'z',t))(box('curb',(2*math.cos(i*math.pi/16),2*math.sin(i*math.pi/16),.12),(.25,.42,.24),'StoneLight'),i*math.pi/16) for i in range(9)])
asset(C,'Stair edge stones',lambda:[box('nosing',((i-2)*.4,0,.06),(.38,.35,.12),'StoneLight') for i in range(5)])
asset(C,'Stone drain channel',lambda:(box('bed',(0,0,.03),(4,.35,.06),'StoneWarm'),box('left edge',(0,-.22,.13),(4,.1,.26),'Stone'),box('right edge',(0,.22,.13),(4,.1,.26),'Stone')))
asset(C,'Paving dirt transition',lambda:(box('dirt',(0,0,.02),(4,2,.04),'Dirt'),[box('loose paver',(random.uniform(-2,2),random.uniform(-1,1),.07),(.35,.3,.1),'StoneWarm') for i in range(18)]))
asset(C,'Paving rock transition',lambda:(box('ground',(0,0,.02),(3,2,.04),'Dirt'),[uvball('rock',(random.uniform(-1.4,1.4),random.uniform(-.8,.8),.1),(.3,.22,.16),'StoneWarm',7,4) for i in range(12)]))
asset(C,'Moss patch',lambda:[uvball('moss',(random.uniform(-.6,.6),random.uniform(-.4,.4),.03),(.15,.1,.035),'Moss',7,3) for i in range(24)])
asset(C,'Exposed roots',lambda:[beam('root',(0,0,.12),(math.cos(i)*1.2,math.sin(i)*.8,.03),.07,'Bark') for i in range(7)])
asset(C,'Stone crack weeds',lambda:(grass(),[leaf((i*.09,0,.02),.15,'Leaf') for i in range(-3,4)]))
asset(C,'Leaf litter',lambda:[(lambda ob:setattr(ob.rotation_euler,'x',math.pi/2))(leaf((random.uniform(-.6,.6),random.uniform(-.5,.5),.03),.15,'Bread',random.uniform(0,6))) for i in range(20)])

C='16 Market Detail'
asset(C,'Filled apple basket',lambda:(basket(),[uvball('apple',(random.uniform(-.22,.22),random.uniform(-.22,.22),.4),(.09,.09,.09),'Red',8,4) for i in range(12)]))
asset(C,'Filled bread tray',lambda:(crate(.8,True),[uvball('loaf',(x,0,.34),(.11,.27,.09),'Bread',10,5) for x in [-.25,0,.25]]))
asset(C,'Stacked goods crates',lambda:(crate(),(lambda b:(crate(.7),move_group(b,(0,0,1))))(len(pieces))))
asset(C,'Fabric bundles',lambda:[(lambda ob:setattr(ob.rotation_euler,'y',math.pi/2))(cyl('fabric roll',(0,(i-1)*.25,.15),.13,.8,'Red' if i%2 else 'Canvas',12)) for i in range(3)])
asset(C,'Hanging shop display',lambda:(box('rack',(0,0,1),(1.5,.12,.12)),[beam('cord',(x,0,1),(x,0,.45),.015,'Canvas') for x in [-.5,0,.5]],[uvball('hanging bag',(x,0,.3),(.17,.13,.2),'Canvas') for x in [-.5,0,.5]]))
asset(C,'Sagging tied canopy',cloth_sag)
asset(C,'Weathered shop sign',lambda:([box('sign plank',(0,0,.12+i*.2),(.9-.04*(i%2),.08,.18),'Wood',(0,0,.025*(i-1))) for i in range(3)],[box('iron fixing',(x,-.06,.3),(.05,.04,.6),'Iron') for x in [-.32,.32]]))
asset(C,'Shutter hardware set',lambda:([box('hinge strap',(0,0,z),(.35,.04,.08),'Iron') for z in [.1,.8]],cyl('hinge pin',(-.18,0,.45),.025,.85,'Iron'),ring('pull',(0,-.04,.45),.07,.045,.03,'Iron')))
asset(C,'Wall planter bracket',lambda:(box('wall plate',(0,0,.2),(.12,.06,.4),'Iron'),beam('support',(0,0,.1),(0,-.4,.3),.045,'Iron'),ring('pot cradle',(0,-.4,.3),.26,.22,.05,'Iron')))

# Catalogs and labels.
import uuid
cats={c:str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/hub-expansion/'+c)) for c in category_counts}
for rec in catalog: assets[rec['name']].asset_data.catalog_id=cats[rec['kit']]
(OUT/'blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{v}:{k}:{k}' for k,v in cats.items())+'\n')
for rec in catalog:
 td=bpy.data.curves.new('Label','FONT'); td.body=rec['name']; td.size=.23
 ob=bpy.data.objects.new('Label '+rec['name'],td); scene.collection.objects.link(ob); ob.location=Vector(rec['gallery_position'])+Vector((-2.8,-2.5,.02)); td.materials.append(M['Canvas'])
example=bpy.data.scenes.new('01 Gate Terrace Example'); example.unit_settings.system='METRIC'
def inst(name,loc=(0,0,0),yaw=0):
 ob=bpy.data.objects.new(name,None); ob.instance_type='COLLECTION'; ob.instance_collection=assets[name]; ob.location=loc; ob.rotation_euler.z=yaw; example.collection.objects.link(ob); return ob
# Ground road and upper gate apron on an actual 3 m terrace.
inst('Raised terrain platform',(0,3,0)); inst('Raised terrain platform',(8,3,0))
for x in [-6,-2,2,6,10]:
 for y in [-7,-3]: inst('Irregular cobblestone bay',(x,y,-.12))
for x in [-2,2,6,10]:
 for y in [1,5]: inst('Irregular cobblestone bay',(x,y,3))
inst('Complete gate arch surround',(0,5,3))
inst('Hinged gate left',(-2,5,3),-.6); inst('Hinged gate right',(2,5,3),.6)
inst('Gate threshold',(0,5,3))
for x in [6,10]: inst('Fort wall block bay',(x,5,3)); inst('Capped battlement bay',(x,5,9)); inst('Wall top walkway',(x,5.5,9))
# Tower on the left; two hollow stone stories and open lookout.
inst('Tower masonry base',(-6,5,3)); inst('Tower masonry base',(-6,5,6)); inst('Tower lookout transition',(-6,5,9)); inst('Complete lookout frame',(-6,5,9.3)); inst('Complete watchtower hip roof',(-6,5,12.3))
for x in [-2,2,6,10]: inst('Detailed retaining bay',(x,-1,0))
inst('Battlement stair flight',(-5,-5.8,0)); inst('Upper gate landing',(-5,.5,2.7))
# Tower support platform under all four sides.
inst('Half terrace platform',(-6,3,0))
inst('Mature broadleaf tree',(10,1,3)); inst('Narrow courtyard tree',(-8,-1,0))
for x,y in [(8,-1.35),(10,-1.35),(2,-1.35),(-6,2.5)]: inst('Ivy patch dense',(x,y,.5))
for x,y in [(-7,-5),(7,-5),(11,-3)]: inst('Rounded shrub',(x,y,0)); inst('Flower patch',(x-.5,y-.5,0))
inst('Filled apple basket',(2,-4,0)); inst('Filled bread tray',(3,-4,0)); inst('Stacked goods crates',(3,-3,0))
inst('Pine' if 'Pine' in assets else 'Hillside pine 2',(11,7,3))
# Presentation setup reused without executing the original builder.
source=helper_path.read_text(); lighting=source[source.index('def camera_light('):source.index('camera_light(example,')]
exec(compile(lighting,str(helper_path),'exec'))
camera_light(example,(28,-35,28),(1,2,6),39)
# Warm local lighting gives readable night preview while keeping source materials editable.
example.world.node_tree.nodes['Background'].inputs[0].default_value=(.035,.07,.16,1)
example.world.node_tree.nodes['Background'].inputs[1].default_value=.35
for ob in example.objects:
 if ob.type=='LIGHT' and ob.data.type=='SUN': ob.data.energy=.6; ob.data.color=(.45,.61,1)
for x in [-2.7,2.7]:
 light=bpy.data.lights.new('Gate lantern light','POINT'); light.energy=160; light.color=(1,.48,.14); light.shadow_soft_size=.6
 ob=bpy.data.objects.new('Gate lantern light',light); example.collection.objects.link(ob); ob.location=(x,3.6,5.5)
# Daylight contact sheets.
sheets=[]
for cat in category_counts:
 sc=bpy.data.scenes.new(cat+' Sheet'); sheets.append(sc)
 records=[r for r in catalog if r['kit']==cat]
 for i,rec in enumerate(records):
  ob=bpy.data.objects.new(rec['name'],None); ob.instance_type='COLLECTION'; ob.instance_collection=assets[rec['name']]; sc.collection.objects.link(ob); ob.location=((i%6)*8,(i//6)*8,0)
  scale=min(3,5/max(rec['dimensions_m'])); ob.scale=(scale,)*3; ob.rotation_euler.z=-.25
  td=bpy.data.curves.new('Caption','FONT'); td.body=rec['name']; td.size=.25; td.materials.append(M['Canvas']); to=bpy.data.objects.new('Caption',td); sc.collection.objects.link(to); to.location=(ob.location.x-3,ob.location.y-2.4,0)
 rows=math.ceil(len(records)/6); center=(20,(rows-1)*4,0); camera_light(sc,(20,-30,52),center,52); sc.render.resolution_x=1800; sc.render.resolution_y=1350
# Check saved mesh contents before delivery.
errors=[]
for rec in catalog:
 ob=next(o for o in assets[rec['name']].objects if o.type=='MESH')
 if any(p.area<1e-10 for p in ob.data.polygons): errors.append(rec['name']+' zero-area face')
 if any(not math.isfinite(v) for vert in ob.data.vertices for v in vert.co): errors.append(rec['name']+' invalid vertex')
assert not errors,errors
bpy.context.window.scene=example
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_location=(1,2,5); area.spaces.active.region_3d.view_distance=38; area.spaces.active.region_3d.view_rotation=Vector((27,-37,23)).to_track_quat('Z','Y')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'HubTown_Environment_Expansion.blend'))
(OUT/'component_inventory.json').write_text(json.dumps({'count':len(catalog),'categories':category_counts,'components':catalog},indent=2)+'\n')
print('EXPANSION_SAVED',len(catalog),category_counts,flush=True)
example.render.filepath=str(OUT/'gate_terrace_preview.png'); bpy.ops.render.render(write_still=True)
for sc in sheets:
 bpy.context.window.scene=sc; sc.render.filepath=str(OUT/(sc.name[:2]+'_contact_sheet.png')); bpy.ops.render.render(write_still=True)
print('EXPANSION_RENDERED',flush=True)
