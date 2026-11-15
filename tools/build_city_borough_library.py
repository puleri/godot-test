"""Borough architecture, landmark and waterfront library. Native editable meshes."""
from pathlib import Path
helper_path=Path(__file__).with_name('build_hub_town_library.py')
helpers=helper_path.read_text().split('# BUILDING STRUCTURE')[0].replace("R/'art/HubTownLibrary'","R/'art/CityBoroughLibrary'")
exec(compile(helpers,str(helper_path),'exec'))
from mathutils import Matrix
import uuid
scene.name='00 Editable Components'
random.seed(20261106)
for name,col,metal,rough in [
 ('Brick',(.32,.10,.055),0,.9),('BrickLight',(.43,.17,.09),0,.9),('BrickDark',(.23,.075,.045),0,.9),
 ('Mortar',(.23,.21,.17),0,1),('Limewash',(.76,.66,.47),0,.9),('Limestone',(.64,.59,.47),0,.85),
 ('Terracotta',(.43,.17,.075),0,.8),('ClayLight',(.54,.24,.12),0,.8),('Copper',(.12,.32,.27),.45,.6),
 ('CopperDark',(.065,.18,.17),.5,.65),('Charcoal',(.055,.075,.09),0,.8),('Ochre',(.62,.39,.16),0,.9),
 ('Sage',(.30,.40,.28),0,.9),('DustyRed',(.47,.23,.17),0,.9),('VillaRoof',(.20,.27,.24),0,.8),
 ('ClockIvory',(.92,.75,.42),0,.4)]: mat(name,col,metal,rough)
M['ClockIvory'].node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(.9,.5,.15,1)
M['ClockIvory'].node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=.6
assemblies={}; assembly_info=[]

def shift_since(n,delta):
 for o in pieces[n:]: o.location+=Vector(delta)

def brickwall(w=4,h=3,d=.35,material='Brick'):
 # Mortar core keeps a solid wall; brick faces project 2 cm from the core.
 box('solid masonry core',(0,0,h/2),(w,d-.05,h),'Mortar')
 rows=max(1,round(h/.25)); rh=h/rows
 for row in range(rows):
  limits=[-w/2]; x=-w/2+(.25 if row%2 else .5)
  while x<w/2-.001: limits.append(x); x+=.5
  limits.append(w/2)
  for a,b in zip(limits,limits[1:]):
   box('brick',((a+b)/2,-d/2+.015,(row+.5)*rh),(b-a-.012,.07,rh-.012),random.choice(['Brick','BrickLight','BrickDark']) if material=='Brick' else material)

def archwall(w=4,h=3,ow=1.5,oh=2.4,bottom=0,d=.35,material='Limestone'):
 r=ow/2; spring=bottom+oh-r
 side=(w-ow)/2
 for s in [-1,1]: box('opening pier',(s*(ow/2+side/2),0,h/2),(side,d,h),material)
 if bottom: box('window apron',(0,0,bottom/2),(ow,d,bottom),material)
 for i in range(16):
  a=i*math.pi/16; b=(i+1)*math.pi/16
  x1,z1=r*math.cos(a),spring+r*math.sin(a); x2,z2=r*math.cos(b),spring+r*math.sin(b)
  prism('arched infill',[(x1,z1),(x1,h),(x2,h),(x2,z2)],d,material)
 # A shallow dressed arch ring only; no duplicate blocking piers.
 for i in range(12):
  a=i*math.pi/12; b=(i+1)*math.pi/12
  o=prism('dressed arch',[(r*math.cos(a),spring+r*math.sin(a)),((r+.13)*math.cos(a),spring+(r+.13)*math.sin(a)),((r+.13)*math.cos(b),spring+(r+.13)*math.sin(b)),(r*math.cos(b),spring+r*math.sin(b))],.09,'Limestone')
  o.location.y=-d/2-.035

def archglass(w=1.4,h=2.2,material='Glass'):
 r=w/2; spring=h-r
 pts=[(-r,0),(r,0)]+[(r*math.cos(i*math.pi/12),spring+r*math.sin(i*math.pi/12)) for i in range(13)]
 prism('arched glass',pts,.045,material)
 for x in [-r,r,0]: box('window mullion',(x,-.04,spring/2),(.055,.08,spring))
 for z in [.55,1.1]:
  if z<spring: box('cross rail',(0,-.04,z),(w,.08,.05))

def shingle_roof(w=4,run=2,rise=1,material='Charcoal'):
 for row in range(6):
  for col in range(8):
   x=-w/2+(col+.5)*w/8; y=-run+(row+.5)*run/6; z=(y+run)*rise/run
   box('roof tile',(x,y,z),(w/8-.008,math.hypot(run/6,rise/6)+.035,.065),material,(math.atan2(rise,run),0,0))
 for x in [-w/2+.1,w/2-.1]: beam('rafter',(x,-run,-.12),(x,0,rise-.12),.15)

def hiproof(w=8,d=6,rise=1.5,material='VillaRoof'):
 # Rectangular hipped roof with a ridge, solid underside.
 ridge=max(.1,(w-d)/2)
 vs=[(-w/2,-d/2,0),(w/2,-d/2,0),(w/2,d/2,0),(-w/2,d/2,0),(-ridge,0,rise),(ridge,0,rise)]
 mesh('hip roof',vs,[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4),(3,2,1,0)],material)
 for a,b in [((-w/2,-d/2,0),(-ridge,0,rise)),((-w/2,d/2,0),(-ridge,0,rise)),((w/2,-d/2,0),(ridge,0,rise)),((w/2,d/2,0),(ridge,0,rise)),((-ridge,0,rise),(ridge,0,rise))]: beam('hip seam',a,b,.07,material)
 for j in range(1,6):
  t=j/6; y=d/2*(1-t); x=w/2-(d/2)*t
  for s in [-1,1]: beam('roof course',(-x,s*y,rise*t),(x,s*y,rise*t),.025,material)

def stepped_gable(w=3):
 for i in range(7):
  x=-w/2+(i+.5)*w/7; h=.45+(3-abs(i-3))*.42
  box('gable step',(x,0,h/2),(w/7,.3,h),'Brick')
  box('stone step cap',(x,-.02,h+.055),(w/7+.06,.4,.11),'Limestone')

def facade(w=3,h=3,material='Sage'):
 ow=1.25; bottom=.7; oh=1.8; side=(w-ow)/2
 for s in [-1,1]: box('pier',(s*(ow/2+side/2),0,h/2),(side,.3,h),material)
 box('apron',(0,0,bottom/2),(ow,.3,bottom),material); box('lintel',(0,0,(bottom+oh+h)/2),(ow,.3,h-bottom-oh),material)
 box('sill',(0,-.12,.68),(1.45,.45,.1),'Limestone')
 box('story cornice',(0,0,h-.08),(w,.38,.16),'Limestone')

def tallwindow():
 box('glazing',(0,0,.89),(1.22,.05,1.76),'Glass')
 for x in [-.63,0,.63]: box('mullion',(x,-.035,.89),(.07,.10,1.83))
 for z in [0,.89,1.78]: box('rail',(0,-.04,z),(1.32,.10,.07))

def column(h=3):
 cyl('plinth',(0,0,.12),.28,.24,'Limestone',8)
 cyl('shaft',(0,0,h/2),.15,h-.35,'Limestone',12,r2=.13)
 cyl('capital',(0,0,h-.12),.25,.24,'Limestone',8)

def cornice(w=4):
 for z,d in [(.04,.4),(.12,.5),(.21,.6)]: box('cornice',(0,0,z),(w,d,.08),'Limestone')

def balustrade(w=4):
 box('base',(0,0,.08),(w,.3,.16),'Limestone'); box('handrail',(0,0,1),(w,.34,.15),'Limestone')
 for i in range(max(2,round(w/.35))):
  n=max(2,round(w/.35)); x=-w/2+(i+.5)*w/n
  cyl('baluster foot',(x,0,.24),.095,.16,'Limestone',8)
  cyl('baluster',(x,0,.58),.08,.58,'Limestone',8,r2=.045)

def pulley():
 ob=ring('pulley rim',(0,0,.25),.25,.18,.10,'Iron',16); ob.rotation_euler.x=math.pi/2
 for a in [0,math.pi/2,math.pi/4,-math.pi/4]: beam('spoke',(-.18*math.cos(a),0,.25-.18*math.sin(a)),(.18*math.cos(a),0,.25+.18*math.sin(a)),.035,'Iron')

def hook():
 last=None
 for i in range(13):
  t=-math.pi*.2+i*math.pi*1.45/12; p=(.15*math.cos(t),0,.2+.15*math.sin(t))
  if last: beam('hook curve',last,p,.045,'Iron')
  last=p
 beam('hook shank',last,(last[0],0,.6),.045,'Iron')

def shaft(length=2):
 ob=cyl('shaft',(0,0,0),.10,length,'Iron',12); ob.rotation_euler.x=math.pi/2

def bellshape(name,r,h,material):
 vessel(name,[(.02,0),(r,0),(r*.65,h*.25),(r*.48,h*.8),(r*.25,h),(r*.17,h),(r*.4,h*.76),(r*.57,h*.25),(r*.9,.08),(.02,.08)],material,16)

def dial():
 o=cyl('clock face',(0,0,0),1,.10,'ClockIvory',32); o.rotation_euler.x=math.pi/2
 o=ring('dial bezel',(0,-.06,0),1.08,1,.10,'Iron',32); o.rotation_euler.x=math.pi/2
 for i in range(12):
  a=i*math.pi/6; ob=box('hour marker',(.83*math.sin(a),-.12,.83*math.cos(a)),(.06,.04,.16),'Iron'); ob.rotation_euler.y=a

def hand(length=.85):
 prism('clock hand',[(-.04,-.12),(.04,-.12),(.04,length*.7),(0,length),(-.04,length*.7)],.055,'Iron')
 o=cyl('pivot',(0,0,0),.08,.08,'Iron',12); o.rotation_euler.x=math.pi/2

def dome_segment():
 # 45 degree shell; repeat eight times around Z. Base radius 5, top ring .65.
 n,m=4,8; vs=[]
 for inner in [False,True]:
  for j in range(m+1):
   phi=j*math.acos(.65/5)/m; r=5*math.cos(phi)-(.10 if inner else 0); z=3*math.sin(phi)
   for i in range(n+1):
    a=i*math.pi/4/n; vs.append((r*math.cos(a),r*math.sin(a),z))
 layer=(m+1)*(n+1); fs=[]
 for j in range(m):
  for i in range(n):
   a=j*(n+1)+i; fs.append((a,a+1,a+n+2,a+n+1)); fs.append((layer+a+n+1,layer+a+n+2,layer+a+1,layer+a))
 for j in range(m):
  a=j*(n+1); b=a+n+1; fs.extend([(a,b,layer+b,layer+a),(a+n,layer+a+n,layer+b+n,b+n)])
 for i in range(n):
  a=m*(n+1)+i; fs.extend([(i,layer+i,layer+i+1,i+1),(a,a+1,layer+a+1,layer+a)])
 mesh('copper dome shell',vs,fs,'Copper')
 for i in [0,n]:
  last=None
  for j in range(m+1):
   p=vs[j*(n+1)+i]
   if last: beam('standing seam',last,p,.055,'CopperDark')
   last=p

def octring(radius=4.85,height=.4,material='Limestone'):
 ring('octagonal ring',(0,0,height/2),radius+.22,radius-.22,height,material,8)

def wheel_segment():
 # One 30-degree rim segment; wheel rotates about Y, front is -Y.
 a,b=0,math.pi/6; r,R=2.25,2.5
 prism('rim segment',[(r*math.cos(a),r*math.sin(a)),(R*math.cos(a),R*math.sin(a)),(R*math.cos(b),R*math.sin(b)),(r*math.cos(b),r*math.sin(b))],.15,'Wood')

def wheel_spoke(): beam('spoke',(.2,0,0),(2.3,0,0),.16,'Timber')
def paddle(): box('paddle',(0,0,0),(.30,1.15,.12),'Wood')
def race():
 box('race bed',(0,0,.1),(2,6,.2),'Stone'); box('race side',(-1,0,.55),(.25,6,1.1),'Stone'); box('race side',(1,0,.55),(.25,6,1.1),'Stone')
def chimney(h=3):
 # Hollow top; repeat shaft module without stacked caps.
 for x in [-.35,.35]: box('brick shaft',(x,0,h/2),(.18,.9,h),'Brick')
 for y in [-.35,.35]: box('brick shaft',(0,y,h/2),(.52,.18,h),'Brick')
 for z in [.25,h-.25]:
  for x in [-.45,.45]: box('course',(x,0,z),(.10,1,.12),'BrickLight')
  for y in [-.45,.45]: box('course',(0,y,z),(.8,.10,.12),'BrickLight')

def lockgate(right=False):
 s=-1 if right else 1
 for i in range(10): box('gate plank',(s*(i+.5)*.2,0,1.5),(.19,.22,3),'Wood')
 for z in [.25,1.5,2.75]: box('cross tie',(s,0,z),(2.1,.35,.15))
 beam('brace',(s*.1,-.2,.1),(s*1.9,-.2,2.9),.15)
 for z in [.3,2.7]: cyl('hinge',(0,0,z),.07,.4,'Iron')
 box('balance beam',(s*.5,0,3.2),(4,.18,.18))

def boat(length=4,width=1.6):
 # Hollow hull, with six transverse stations and inner skin.
 ys=[-length/2,-length*.35,-length*.15,length*.15,length*.35,length/2]
 widths=[.04,width*.34,width*.5,width*.5,width*.34,.04]
 vs=[]
 for inner in [False,True]:
  for y,w in zip(ys,widths):
   w=max(.015,w-(.065 if inner else 0)); floor=.12 if inner else .03
   vs.extend([(-w,y,.8),(-w*.55,y,floor),(w*.55,y,floor),(w,y,.8)])
 fs=[]; layer=24
 for j in range(5):
  for k in range(3):
   a=j*4+k; fs.extend([(a,a+4,a+5,a+1),(layer+a+1,layer+a+5,layer+a+4,layer+a)])
  for k in [0,3]:
   a=j*4+k; fs.append((a,layer+a,layer+a+4,a+4))
 for j in [0,5]:
  for k in range(3):
   a=j*4+k; fs.append((a,a+1,layer+a+1,layer+a))
 mesh('hull shell',vs,fs,'Wood')
 for y in [-length*.22,0,length*.22]: box('seat',(0,y,.6),(width*.85,.24,.08),'Timber')
 for side in [-1,1]:
  for i in range(5): beam('gunwale',(side*widths[i],ys[i],.81),(side*widths[i+1],ys[i+1],.81),.06,'Timber')

def pergola():
 for x in [-1.5,1.5]:
  for y in [-1.5,1.5]: box('post',(x,y,1.4),(.15,.15,2.8),'Limestone')
 for x in [-1.5,1.5]: box('beam',(x,0,2.8),(.18,3.5,.18))
 for y in [-1.5,-1,-.5,0,.5,1,1.5]: box('rafter',(0,y,2.95),(3.5,.12,.12))

# ---- FOUR REPEATABLE ARCHITECTURAL FAMILIES ----
C='17 Canal Warehouse'
asset(C,'Warehouse brick wall',brickwall)
asset(C,'Warehouse loading arch',lambda:archwall(4,4,2.6,3.4,0,.45,'Brick'))
asset(C,'Warehouse double loading doors',lambda:door(True,True),'2.4 m wide × 2.26 m high, fits within the loading arch; upper arch remains glazed/open.')
asset(C,'Warehouse industrial window wall',lambda:archwall(4,3,1.5,2.25,.35,.35,'Brick'))
asset(C,'Warehouse industrial window',lambda:archglass(1.46,2.21))
asset(C,'Warehouse shallow roof half',lambda:shingle_roof(4,3,1.2))
asset(C,'Warehouse roof gable end',lambda:prism('brick gable',[(-3,0),(3,0),(0,1.2)],.3,'Brick'))
asset(C,'Warehouse skylight',lambda:(box('frame',(0,0,.12),(1.5,1,.24),'Iron'),box('glass',(0,0,.26),(1.3,.8,.04),'Glass'),box('mullion',(0,0,.29),(.05,.8,.05),'Iron')))
asset(C,'Warehouse loading platform',lambda:plankdeck(4,2))
asset(C,'Warehouse hoist frame',lambda:(box('wall post',(0,0,1.5),(.2,.2,3)),beam('hoist arm',(0,0,2.9),(0,-2,2.9),.18),beam('brace',(0,0,1.5),(0,-1.5,2.9),.14)))
asset(C,'Hoist pulley',pulley)
asset(C,'Cargo hook',hook)
asset(C,'Warehouse covered gallery',lambda:(plankdeck(4,2),box('post',(-1.8,-.85,1.5),(.18,.18,3)),box('post',(1.8,-.85,1.5),(.18,.18,3)),box('roof',(0,0,3.1),(4.2,2.2,.16),'Charcoal')))
asset(C,'Warehouse ridge cap',lambda:box('ridge',(0,0,.06),(4,.18,.12),'Iron'))
asset(C,'Warehouse corner quoin',lambda:[box('quoin',(0,0,.15+i*.3),(.4,.4,.28),'BrickLight') for i in range(10)])

C='18 Merchant Shophouse'
for color in ['Sage','Ochre','DustyRed']: asset(C,'Merchant facade '+color,lambda c=color:facade(material=c))
asset(C,'Merchant stepped gable',stepped_gable)
asset(C,'Merchant gable cap',lambda:box('cap',(0,0,.06),(.5,.4,.12),'Limestone'))
asset(C,'Merchant shop arcade',lambda:archwall(3,3,2.2,2.65,0,.4,'Limestone'))
asset(C,'Merchant tall window',tallwindow)
asset(C,'Merchant projecting bay',lambda:(box('bay base',(0,-.25,.1),(1.7,.65,.2),'Wood'),box('front glazing',(0,-.55,1),(1.5,.06,1.7),'Glass'),[box('mullion',(x,-.6,1),(.08,.1,1.8)) for x in [-.75,0,.75]],box('bay cap',(0,-.25,1.95),(1.7,.7,.15),'Limestone')))
asset(C,'Merchant recessed entry',lambda:(box('return',(-.7,.3,1.2),(.15,.8,2.4),'Limestone'),box('return',(.7,.3,1.2),(.15,.8,2.4),'Limestone'),(lambda n:(door(),shift_since(n,(0,.65,0))))(len(pieces))))
asset(C,'Merchant party wall',lambda:box('party wall',(0,0,1.5),(4,.3,3),'Brick'))
asset(C,'Merchant narrow roof half',lambda:shingle_roof(4,1.5,1.65,'Charcoal'))
asset(C,'Merchant floor bay',lambda:plankdeck(3,4))
asset(C,'Merchant arcade column',lambda:column(3))
asset(C,'Merchant front door',door)

C='19 Courtyard Tenement'
asset(C,'Tenement gallery wall',lambda:facade(4,3,'Limewash'))
asset(C,'Tenement passage arch',lambda:archwall(4,3,2.4,2.7,0,.4,'Limewash'))
asset(C,'Tenement plain wall',lambda:box('wall',(0,0,1.5),(4,.3,3),'Limewash'))
asset(C,'Tenement gallery floor',lambda:plankdeck(4,1.5))
asset(C,'Tenement gallery post',lambda:box('post',(0,0,1.5),(.16,.16,3)))
asset(C,'Tenement gallery railing',lambda:railing(4))
asset(C,'Tenement gallery corner',lambda:(plankdeck(1.5,1.5),box('corner post',(-.65,-.65,1.5),(.16,.16,3))))
asset(C,'Tenement timber stairs',lambda:([box('tread',(0,(i+.5)*.4,(i+1)*.25-.06),(1.5,.4,.12),'Wood') for i in range(12)],[beam('stringer',(x,0,0),(x,4.8,3),.16) for x in [-.65,.65]]))
asset(C,'Tenement stair landing',lambda:plankdeck(2,2))
asset(C,'Terracotta roof half',lambda:shingle_roof(4,2,1.5,'Terracotta'))
asset(C,'Terracotta hip roof',lambda:hiproof(4,4,1.5,'Terracotta'))
asset(C,'Terracotta valley',lambda:(beam('left valley',(-2,-2,0),(0,0,1.5),.18,'ClayLight'),beam('right valley',(2,-2,0),(0,0,1.5),.18,'ClayLight')))
asset(C,'Terracotta ridge',lambda:[(lambda o:setattr(o.rotation_euler,'y',math.pi/2))(cyl('ridge tile',(-1.8+i*.4,0,.08),.12,.39,'ClayLight',8)) for i in range(10)])
asset(C,'Tenement chimney short',lambda:chimney(1.5))
asset(C,'Tenement chimney tall',lambda:chimney(2.5))
asset(C,'Exposed brick repair patch',lambda:[box('exposed brick',((i%4-1.5)*.24,-.02,(i//4+.5)*.14),(.23,.05,.13),'BrickLight') for i in range(10)])
asset(C,'Laundry line',lambda:beam('line',(-2,0,.1),(2,0,.1),.015,'Canvas'))
asset(C,'Laundry hanging sheet',lambda:mesh('cloth',[(-.6,0,1.4),(.6,0,1.4),(.6,.06,0),(0,-.05,.03),(-.6,.06,0)],[(0,1,2,3,4)],'Canvas'))
asset(C,'Laundry hanging shirt',lambda:prism('shirt',[(-.3,0),(.3,0),(.3,.45),(.5,.35),(.62,.55),(.25,.8),(-.25,.8),(-.62,.55),(-.5,.35),(-.3,.45)],.025,'Blue'))

C='20 Hillside Villa'
asset(C,'Villa pale wall',lambda:box('wall',(0,0,1.5),(4,.35,3),'Limestone'))
asset(C,'Villa arched window wall',lambda:archwall(4,3,1.5,2.1,.5,.35,'Limestone'))
asset(C,'Villa arched window',lambda:archglass(1.46,2.06))
asset(C,'Villa arched door wall',lambda:archwall(4,3,1.5,2.7,0,.35,'Limestone'))
asset(C,'Villa arched door',lambda:archglass(1.46,2.66,'Wood'))
asset(C,'Villa loggia arch',lambda:archwall(4,3,3.2,2.7,0,.3,'Limestone'))
asset(C,'Villa loggia column',column)
asset(C,'Villa loggia corner',lambda:(column(),box('capital return',(0,0,2.95),(.7,.7,.1),'Limestone')))
asset(C,'Villa low hip roof',lambda:hiproof(8.6,6.6,1.6))
asset(C,'Villa garden balustrade',balustrade)
asset(C,'Villa terrace steps',lambda:stairs(4,3,.2,.4))
asset(C,'Villa garden wall',lambda:box('wall',(0,0,.65),(4,.25,1.3),'Limestone'))
asset(C,'Villa garden gatepost',lambda:(box('post',(0,0,1),(.45,.45,2),'Limestone'),uvball('cap',(0,0,2.18),(.23,.23,.23),'Limestone')))
asset(C,'Villa iron garden gate',lambda:([box('bar',(-.9+i*.2,0,.9),(.035,.04,1.8),'Iron') for i in range(10)],[box('rail',(0,0,z),(2,.06,.06),'Iron') for z in [.2,1.4]]))
asset(C,'Villa pergola bay',pergola)
asset(C,'Villa cornice',cornice)

# ---- UNIQUE LANDMARK PARTS ----
C='21 Clock Hall'
asset(C,'Clock Hall entrance arcade',lambda:archwall(4,4,2.4,3.3,0,.45,'Brick'))
asset(C,'Clock Hall grand window wall',lambda:archwall(4,3,1.6,2.3,.35,.4,'Brick'))
asset(C,'Clock Hall grand window',lambda:archglass(1.56,2.26))
asset(C,'Clock Hall ornate gable',lambda:(stepped_gable(4),[box('stone pilaster',(x,-.2,.45),(.1,.1,.9),'Limestone') for x in [-1.3,-.7,0,.7,1.3]]))
asset(C,'Clock tower base wall',lambda:brickwall(3,4,.4))
asset(C,'Clock tower shaft wall',lambda:brickwall(3,3,.4))
asset(C,'Clock face surround',lambda:(lambda o:setattr(o.rotation_euler,'x',math.pi/2))(ring('stone surround',(0,0,0),1.24,1.07,.18,'Limestone',24)),'Origin at clock center; front -Y.')
asset(C,'Clock illuminated dial',dial,'Origin at clock center; front -Y.')
asset(C,'Clock minute hand',lambda:hand(.85),'Pivot at dial center; rotate around Y.')
asset(C,'Clock hour hand',lambda:hand(.58),'Pivot at dial center; rotate around Y.')
asset(C,'Clock belfry opening',lambda:archwall(3,2,1.1,1.65,0,.3,'Brick'))
asset(C,'Clock spire base',lambda:(box('base',(0,0,.12),(3.6,3.6,.24),'Limestone'),box('copper base',(0,0,.3),(3.4,3.4,.12),'Copper')))
asset(C,'Clock copper spire',lambda:cyl('spire',(0,0,2.5),2.1,5,'Copper',4,r2=.06))
asset(C,'Clock spire finial',lambda:(cyl('shaft',(0,0,.5),.04,1,'Iron'),uvball('orb',(0,0,.65),(.12,.12,.12),'Copper')))
asset(C,'Clock Hall entrance stairs',lambda:stairs(3,4,.15,.4))
asset(C,'Clock Hall copper roof half',lambda:shingle_roof(4,4,2,'Copper'))
asset(C,'Clock Hall side gable',lambda:prism('gable',[(-4,0),(4,0),(0,2)],.4,'Brick'))

C='22 Canal Bathhouse'
asset(C,'Bathhouse octagonal window bay',lambda:archwall(4,3,1.8,2.3,.3,.35,'Limestone'))
asset(C,'Bathhouse entrance bay',lambda:archwall(4,3,2.1,2.8,0,.35,'Limestone'))
asset(C,'Bathhouse arched glazing',lambda:archglass(1.76,2.26))
asset(C,'Bathhouse corner pier',lambda:column(3))
asset(C,'Bathhouse curved cornice',lambda:octring(5.23,.25))
asset(C,'Bathhouse dome drum',lambda:ring('drum',(0,0,.35),5.15,4.85,.7,'Limestone',32))
asset(C,'Bathhouse copper dome segment',dome_segment,'One 45 degree segment. Repeat eight times about Z; radius 5 m.')
asset(C,'Bathhouse lantern base',lambda:ring('base',(0,0,.1),.80,.58,.2,'CopperDark',8))
asset(C,'Bathhouse roof lantern',lambda:([box('post',(.6*math.cos(i*math.pi/4),.6*math.sin(i*math.pi/4),.5),(.055,.055,1),'CopperDark') for i in range(8)],cyl('cap',(0,0,1.1),.85,.4,'Copper',8,r2=.08)))
asset(C,'Bathhouse roof vent',lambda:(cyl('vent',(0,0,.25),.12,.5,'CopperDark'),cyl('rain cap',(0,0,.55),.23,.1,'Copper',8,r2=.12)))
asset(C,'Bathhouse terrace segment',lambda:prism('terrace',[(-2,0),(2,0),(2,.3),(-2,.3)],3,'Limestone'))
asset(C,'Bathhouse broad entrance stair',lambda:stairs(5,4,.2,.4))
asset(C,'Bathhouse curved balustrade',lambda:balustrade(4))
asset(C,'Bathhouse octagonal floor',lambda:cyl('floor',(0,0,-.12),5.23,.24,'Limestone',8))

C='23 Great Waterwheel Mill'
asset(C,'Mill stone wall',lambda:brickwall(4,3,.4,'StoneLight'))
asset(C,'Mill timber upper wall',lambda:wall('window',True))
asset(C,'Mill window insert',window)
asset(C,'Mill door bay',lambda:wall('door'))
asset(C,'Mill wheel side opening',lambda:archwall(4,3,1.5,2.2,.3,.4,'Stone'))
asset(C,'Mill axle support',lambda:(box('stone pedestal',(0,0,.6),(.65,.65,1.2),'StoneLight'),box('bearing',(0,0,1.25),(.4,.4,.15),'Iron')))
asset(C,'Waterwheel hub',lambda:(lambda o:setattr(o.rotation_euler,'x',math.pi/2))(cyl('hub',(0,0,0),.32,1.3,'Timber',12)),'Rotational origin at wheel center, axle along Y.')
asset(C,'Waterwheel spoke',wheel_spoke,'Spoke points along +X; rotate around Y.')
asset(C,'Waterwheel rim segment',wheel_segment,'30-degree segment in XZ plane; repeat 12 times around Y.')
asset(C,'Waterwheel paddle',paddle,'Origin centered on paddle; place at radius 2.4 m.')
asset(C,'Mill drive shaft',lambda:shaft(3))
asset(C,'Mill water race',race)
asset(C,'Mill sluice gate',lambda:([box('board',(0,0,.12+i*.25),(1.6,.15,.23),'Wood') for i in range(6)],box('stem',(0,0,2),(.08,.08,1.3),'Iron')))
asset(C,'Mill sluice lifting frame',lambda:(box('upright',(-1,0,1.3),(.16,.16,2.6)),box('upright',(1,0,1.3),(.16,.16,2.6)),box('header',(0,0,2.6),(2.2,.18,.18)),(lambda o:setattr(o.rotation_euler,'x',math.pi/2))(ring('handwheel',(0,-.2,2.5),.28,.23,.06,'Iron'))))
asset(C,'Mill discharge chute',lambda:(prism('bed',[(-3,0),(3,0),(3,1),(-3,.15)],1.6,'Stone'),beam('edge',(-3,-.85,.2),(3,-.85,1.1),.15,'StoneLight'),beam('edge',(-3,.85,.2),(3,.85,1.1),.15,'StoneLight')))
asset(C,'Mill workshop roof half',lambda:shingle_roof(4,3,1.5,'Charcoal'))
asset(C,'Mill workshop gable',lambda:prism('gable',[(-3,0),(3,0),(0,1.5)],.25,'Plaster'))
asset(C,'Mill chimney base',lambda:box('base',(0,0,.5),(1.3,1.3,1),'Brick'))
asset(C,'Mill chimney shaft',chimney)
asset(C,'Mill chimney cap',lambda:ring('cap',(0,0,.12),.8,.42,.24,'BrickLight',4))
asset(C,'Mill covered passage',lambda:(plankdeck(4,2),[box('post',(x,y,1.5),(.15,.15,3)) for x in [-1.85,1.85] for y in [-.85,.85]],box('roof',(0,0,3.1),(4.3,2.3,.2),'Charcoal')))

C='24 Canal and Waterfront'
asset(C,'Lock chamber wall',lambda:brickwall(6,4,.7,'StoneLight'))
for right in [False,True]: asset(C,'Lock gate '+('right' if right else 'left'),lambda r=right:lockgate(r),'Hinge at origin; rotate around Z. Base at chamber sill.')
asset(C,'Lock gate winding mechanism',lambda:(box('pedestal',(0,0,.5),(.3,.3,1),'Iron'),(lambda o:setattr(o.rotation_euler,'x',math.pi/2))(ring('wheel',(0,-.1,1.15),.35,.29,.08,'Iron')),beam('handle',(.3,-.2,1.15),(.3,-.5,1.15),.04,'Timber')))
asset(C,'Spillway crest',lambda:box('weir crest',(0,0,.2),(4,.7,.4),'StoneLight'))
asset(C,'Water level transition bed',lambda:prism('sloping channel',[(-2,0),(2,0),(2,1.5),(-2,.15)],4,'Stone'))
asset(C,'Small cargo boat',lambda:boat(6,2.4),'Hollow hull; waterline approximately local Z=.35 m.')
asset(C,'Rowboat',boat)
asset(C,'Gangplank',lambda:plankdeck(1,3))
asset(C,'Mooring rope',lambda:[beam('rope',(math.sin(i*.4)*.08,i*.2,.03),(math.sin((i+1)*.4)*.08,(i+1)*.2,.03),.025,'Canvas') for i in range(15)])
asset(C,'Cargo bundles',lambda:([uvball('bundle',((i-1)*.5,0,.25),(.24,.35,.25),'Canvas') for i in range(3)],[box('strap',((i-1)*.5,0,.25),(.06,.72,.5),'Timber') for i in range(3)]))
asset(C,'Dock crane base',lambda:(cyl('foot',(0,0,.15),.7,.3,'StoneLight',8),box('mast',(0,0,2.2),(.3,.3,4.4))))
asset(C,'Dock crane boom',lambda:(beam('boom',(0,0,0),(3,0,1.3),.22),beam('brace',(0,0,-1.5),(2.5,0,1.1),.18)),'Mount at mast top; pivot about Z at base.')
asset(C,'Dock crane winding drum',lambda:(lambda o:setattr(o.rotation_euler,'x',math.pi/2))(cyl('drum',(0,0,.3),.3,.7,'Timber',12)))
asset(C,'Hoist hanging cable',lambda:beam('cable',(0,0,0),(0,0,2.2),.025,'Canvas'))
asset(C,'Dock bollard',lambda:(cyl('post',(0,0,.35),.16,.7,'Iron'),box('crosspiece',(0,0,.65),(.65,.16,.16),'Iron')))

C='25 Borough Identity and Distance'
for shape in ['Warehouse','Merchant','Villa']:
 asset(C,shape+' sign',lambda sh=shape:(box('sign',(0,0,.4),(1,.08,.8),'Wood' if sh!='Villa' else 'Limestone'),(lambda o:setattr(o.rotation_euler,'x',math.pi/2))(ring('emblem',(0,-.07,.4),.22,.16,.05,'Iron'))))
asset(C,'Civic banner',lambda:(prism('banner',[(-.5,2),(.5,2),(.5,.2),(0,0),(-.5,.2)],.03,'Red'),box('gold stripe',(0,-.025,1),(.08,.02,1.8),'ClockIvory')))
asset(C,'Warehouse number plaque',lambda:(box('plaque',(0,0,.2),(.65,.06,.4),'Iron'),[box('mark',(x,-.04,.2),(.035,.02,.22),'Canvas') for x in [-.12,0,.12]]))
asset(C,'Street lamp post',lambda:(cyl('foot',(0,0,.12),.25,.24,'Iron'),cyl('post',(0,0,1.5),.06,3,'Iron'),beam('arm',(0,0,2.9),(0,-.4,2.9),.06,'Iron'),(lambda n:(lantern(),shift_since(n,(0,-.4,2.1))))(len(pieces))))
asset(C,'Distant windmill body',lambda:(cyl('tower',(0,0,2),1.2,4,'Limewash',8,r2=.85),cyl('roof',(0,0,4.5),1.1,1,'Terracotta',8,r2=.03)))
asset(C,'Windmill sail cross',lambda:([beam('sail',(0,0,0),(2.6*math.cos(a),0,2.6*math.sin(a)),.12) for a in [0,math.pi/2,math.pi,math.pi*1.5]],[box('sail cloth',(1.6*math.cos(a),0,1.6*math.sin(a)),(1.6,.04,.45),'Canvas',(0,-a,0)) for a in [0,math.pi/2,math.pi,math.pi*1.5]]),'Pivot at rotor center; axle along Y.')
def distantcluster():
 for i,(x,y,h) in enumerate([(-2,-1,2),(1,-1,2.6),(-1,2,3),(2,2,1.8)]):
  box('distant house',(x,y,h/2),(2,2,h),'Limewash' if i%2 else 'Sage')
  o=prism('distant roof',[(-1.1,0),(1.1,0),(0,.8)],2.2,'Charcoal'); o.location=(x,y,h)
asset(C,'Distant neighborhood cluster',distantcluster)

# ---- COMPLETE EDITABLE ASSEMBLIES ----
# Real mesh objects with shared source mesh data; no opaque collection instances.
def begin_assembly(name):
 col=bpy.data.collections.new(name); assemblies[name]=col; return col

def place(col,name,loc=(0,0,0),yaw=0,scale=(1,1,1),rotation=None,parent=None):
 src=next(o for o in assets[name].objects if o.type=='MESH')
 ob=src.copy(); ob.data=src.data; ob.name=name; col.objects.link(ob)
 rot=Matrix.Rotation(yaw,4,'Z') if rotation is None else rotation
 ob.matrix_world=Matrix.Translation(Vector(loc))@rot@Matrix.Diagonal((*scale,1))
 if parent: ob.parent=parent
 return ob

def floors(col,xs,ys,zs):
 for x in xs:
  for y in ys:
   for z in zs: place(col,'Merchant floor bay',(x,y,z),scale=(4/3,1,1))

def gable_roof(col,xs,z,half,run,material_end):
 for x in xs:
  place(col,half,(x,0,z)); place(col,half,(x,0,z),math.pi)
 # Front/back slope bases are z with local ridge at z+rise, eaves y±run.
 for x in [min(xs)-2,max(xs)+2]: place(col,material_end,(x,0,z),math.pi/2)

col=begin_assembly('A Warehouse complete')
# 12 x 6 m footprint, loading front and long side elevations.
for x in [-4,0,4]:
 for y,yaw in [(-3,0),(3,math.pi)]:
  key='Warehouse loading arch' if y<0 and x==0 else 'Warehouse industrial window wall'
  place(col,key,(x,y,0),yaw)
  if key.endswith('window wall'): place(col,'Warehouse industrial window',(x,y+(-.2 if y<0 else .2),.35),yaw)
  else: place(col,'Warehouse double loading doors',(x,y-.24,0))
 # add wall strip for equal 4m roof seat where windows are only 3m high
 for y in [-3,3]:
  if not (x==0 and y==-3): place(col,'Warehouse brick wall',(x,y,3),scale=(1,1,1/3))
for x,yaw in [(-6,-math.pi/2),(6,math.pi/2)]:
 for y in [-1.5,1.5]: place(col,'Warehouse brick wall',(x,y,0),yaw,scale=(.75,1,4/3))
gable_roof(col,[-4,0,4],4,'Warehouse shallow roof half',3,'Warehouse roof gable end')
for x in [-4,0,4]: place(col,'Warehouse covered gallery',(x,-4.2,0))
place(col,'Warehouse hoist frame',(0,-3.2,1)); place(col,'Hoist pulley',(0,-5.1,3.55)); place(col,'Cargo hook',(0,-5.1,2.3))
place(col,'Hoist hanging cable',(0,-5.1,2.6),scale=(1,1,.43))
for x in [-4,0,4]:
 for y in [-1.5,1.5]: place(col,'Merchant floor bay',(x,y,-.24),scale=(4/3,.75,1))
place(col,'Warehouse skylight',(-3,-1.3,4.7),rotation=Matrix.Rotation(math.atan2(1.2,3),4,'X'))

col=begin_assembly('B Merchant shophouse complete')
for z in [0,3,6,9]:
 for y,yaw in [(-2,0),(2,math.pi)]:
  key='Merchant shop arcade' if z==0 else 'Merchant facade Sage'
  place(col,key,(0,y,z),yaw)
  if z: place(col,'Merchant tall window',(0,y+(-.2 if y<0 else .2),z+.7),yaw)
  else: place(col,'Merchant recessed entry',(0,y,z),yaw)
 for x,yaw in [(-1.5,-math.pi/2),(1.5,math.pi/2)]: place(col,'Merchant party wall',(x,0,z),yaw)
 place(col,'Merchant floor bay',(0,0,z-.24))
place(col,'Merchant stepped gable',(0,-2,12)); place(col,'Merchant stepped gable',(0,2,12),math.pi)
place(col,'Merchant narrow roof half',(0,0,12),math.pi/2); place(col,'Merchant narrow roof half',(0,0,12),-math.pi/2)

col=begin_assembly('C Courtyard tenement complete')
# Three wings around an open court; the court remains accessible from the south.
for z in [0,3,6]:
 for x in [-4,0,4]:
  place(col,'Tenement gallery wall',(x,4,z)); place(col,'Merchant tall window',(x,3.8,z+.7))
  place(col,'Tenement plain wall',(x,8,z),math.pi)
  place(col,'Tenement gallery floor',(x,3.15,z-.24))
  if z: place(col,'Tenement gallery railing',(x,2.45,z))
 for x,angle in [(-6,-math.pi/2),(6,math.pi/2)]:
  for y in [-2,2,6]: place(col,'Tenement plain wall',(x,y,z),angle)
 for x,angle in [(-2,math.pi/2),(2,-math.pi/2)]:
  for y in [-2,2]:
   place(col,'Tenement gallery wall',(x,y,z),angle)
   place(col,'Merchant tall window',(x+(.2 if x<0 else -.2),y,z+.7),angle)
 for x in [-4,4]:
  place(col,'Tenement passage arch',(x,-4,z))
  for y in [-2,2]: place(col,'Merchant floor bay',(x,y,z-.24),scale=(4/3,1,1))
 for x in [-4,0,4]: place(col,'Merchant floor bay',(x,6,z-.24),scale=(4/3,1,1))
for x in [-4,0,4]:
 for yaw in [0,math.pi]: place(col,'Terracotta roof half',(x,6,9),yaw)
for x in [-4,4]:
 for y in [-2,2]:
  for yaw in [math.pi/2,-math.pi/2]: place(col,'Terracotta roof half',(x,y,9),yaw)
for z,x in [(0,-.9),(3,.9)]: place(col,'Tenement timber stairs',(x,-3,z)); place(col,'Tenement stair landing',(x,2.8,z+3-.24))
place(col,'Tenement chimney tall',(-4,6,10)); place(col,'Laundry line',(0,3,4.5)); place(col,'Laundry hanging sheet',(-.7,3,3.2)); place(col,'Laundry hanging shirt',(.6,3,3.8))

col=begin_assembly('D Hillside villa complete')
for y,yaw in [(-3,0),(3,math.pi)]:
 for x in [-2,2]:
  key='Villa arched door wall' if x==-2 and y==-3 else 'Villa arched window wall'
  place(col,key,(x,y,0),yaw)
  place(col,'Villa arched door' if key=='Villa arched door wall' else 'Villa arched window',(x,y+(-.2 if y<0 else .2),0 if key=='Villa arched door wall' else .5),yaw)
for x,yaw in [(-4,-math.pi/2),(4,math.pi/2)]:
 for y in [-1.5,1.5]: place(col,'Villa pale wall',(x,y,0),yaw,scale=(.75,1,1))
for x in [-2,2]:
 for y in [-1.5,1.5]: place(col,'Merchant floor bay',(x,y,-.24),scale=(4/3,.75,1))
place(col,'Villa low hip roof',(0,0,3))
for x in [-2,2]: place(col,'Villa loggia arch',(x,-5,0)); place(col,'Villa cornice',(x,-5,3))
place(col,'Villa pergola bay',(0,-4,0),scale=(2,1,1))
place(col,'Villa terrace steps',(-2,-6.6,-.8))
for x in [-4,0,4]: place(col,'Villa garden wall',(x,5,0))
for x in [-1.2,1.2]: place(col,'Villa garden gatepost',(x,-8,0))
place(col,'Villa iron garden gate',(0,-8,0))

col=begin_assembly('E Clock Hall complete')
# Hall 12 x 8, roof at 7m; clock tower attached on the left frontage.
for x in [-4,0,4]:
 for y,yaw in [(-4,0),(4,math.pi)]:
  place(col,'Clock Hall entrance arcade',(x,y,0),yaw)
  place(col,'Clock Hall grand window wall',(x,y,4),yaw)
  place(col,'Clock Hall grand window',(x,y+(-.24 if y<0 else .24),4.35),yaw)
for x,yaw in [(-6,-math.pi/2),(6,math.pi/2)]:
 for y in [-2,2]: place(col,'Warehouse brick wall',(x,y,0),yaw,scale=(1,1,7/3))
gable_roof(col,[-4,0,4],7,'Clock Hall copper roof half',4,'Clock Hall side gable')
place(col,'Clock Hall ornate gable',(0,-4.05,7)); place(col,'Clock Hall entrance stairs',(0,-5.2,-.45))
tx,ty=-4,-5.6
for z,h,key in [(0,4,'Clock tower base wall'),(4,3,'Clock tower shaft wall'),(7,3,'Clock tower shaft wall'),(10,2,'Clock belfry opening')]:
 for dx,dy,yaw in [(0,-1.5,0),(0,1.5,math.pi),(-1.5,0,-math.pi/2),(1.5,0,math.pi/2)]: place(col,key,(tx+dx,ty+dy,z),yaw)
for dx,dy,yaw in [(0,-1.76,0),(1.76,0,math.pi/2),(0,1.76,math.pi),(-1.76,0,-math.pi/2)]:
 center=(tx+dx,ty+dy,8.5); place(col,'Clock face surround',center,yaw); place(col,'Clock illuminated dial',center,yaw)
 offset=Vector((0,-.18,0)); offset=Matrix.Rotation(yaw,4,'Z')@offset
 for key,angle in [('Clock minute hand',math.pi/6),('Clock hour hand',-math.pi/3)]:
  ob=place(col,key,Vector(center)+offset,rotation=Matrix.Rotation(yaw,4,'Z')@Matrix.Rotation(angle,4,'Y')); ob['animation_axis']='local Y at clock center'
place(col,'Clock spire base',(tx,ty,12)); place(col,'Clock copper spire',(tx,ty,12.3),math.pi/4); place(col,'Clock spire finial',(tx,ty,17.3))

col=begin_assembly('F Canal Bathhouse complete')
r=2/math.tan(math.pi/8)
for i in range(8):
 a=-math.pi/2+i*math.pi/4; pos=(r*math.cos(a),r*math.sin(a),0); yaw=a+math.pi/2
 place(col,'Bathhouse entrance bay' if i==0 else 'Bathhouse octagonal window bay',pos,yaw)
 if i: place(col,'Bathhouse arched glazing',((r+.2)*math.cos(a),(r+.2)*math.sin(a),.3),yaw)
 a+=math.pi/8; place(col,'Bathhouse corner pier',((r/math.cos(math.pi/8))*math.cos(a),(r/math.cos(math.pi/8))*math.sin(a),0))
place(col,'Bathhouse octagonal floor',(0,0,0),math.pi/8)
place(col,'Bathhouse curved cornice',(0,0,3),math.pi/8); place(col,'Bathhouse dome drum',(0,0,3.1))
for i in range(8): place(col,'Bathhouse copper dome segment',(0,0,3.8),i*math.pi/4)
place(col,'Bathhouse lantern base',(0,0,6.8)); place(col,'Bathhouse roof lantern',(0,0,7))
place(col,'Bathhouse broad entrance stair',(0,-6.8,-1))
for x in [-4,4]: place(col,'Bathhouse terrace segment',(x,-5,-.3)); place(col,'Bathhouse curved balustrade',(x,-6.3,0))

col=begin_assembly('G Great Waterwheel Mill complete')
for x in [-2,2]:
 for y,yaw in [(-3,0),(3,math.pi)]:
  key='Mill door bay' if x==-2 and y<0 else 'Mill stone wall'
  place(col,key,(x,y,0),yaw); place(col,'Mill timber upper wall',(x,y,3),yaw); place(col,'Mill window insert',(x,y+(-.2 if y<0 else .2),4),yaw)
for x,yaw in [(-4,-math.pi/2),(4,math.pi/2)]:
 for y in [-1.5,1.5]:
  place(col,'Mill stone wall',(x,y,0),yaw,scale=(.75,1,1)); place(col,'Mill timber upper wall',(x,y,3),yaw,scale=(.75,1,1))
gable_roof(col,[-2,2],6,'Mill workshop roof half',3,'Mill workshop gable')
for x in [-2,2]:
 for y in [-1.5,1.5]:
  for z in [-.24,2.76]: place(col,'Merchant floor bay',(x,y,z),scale=(4/3,.75,1))
for x,yaw in [(-4,-math.pi/2),(4,math.pi/2)]:
 for y in [-1.5,1.5]: place(col,'Mill window insert',(x+(-.2 if x<0 else .2),y,4),yaw)
# Rotor source geometry uses Y axle, so rotate it into the building side (X axle).
rotor=bpy.data.objects.new('ROTATE THIS — waterwheel axle X',None); col.objects.link(rotor); rotor.location=(5.2,0,2.8); rotor.rotation_euler.z=math.pi/2; rotor['purpose']='Animation pivot; rotate local Y. All wheel pieces are separate editable meshes.'
for name in ['Waterwheel hub','Mill drive shaft']:
 ob=place(col,name); ob.parent=rotor
for i in range(12):
 a=i*math.pi/6
 for y in [-.5,.5]:
  ob=place(col,'Waterwheel rim segment',(0,y,0),rotation=Matrix.Rotation(-a,4,'Y')); ob.parent=rotor
  ob=place(col,'Waterwheel spoke',(0,y,0),rotation=Matrix.Rotation(-a,4,'Y')); ob.parent=rotor
 ob=place(col,'Waterwheel paddle',(2.4*math.cos(a),0,2.4*math.sin(a)),rotation=Matrix.Rotation(-a,4,'Y')); ob.parent=rotor
place(col,'Mill water race',(5.2,0,-.1)); place(col,'Mill sluice gate',(5.2,3.2,0)); place(col,'Mill sluice lifting frame',(5.2,3.2,0))
for x in [4.4,6]: place(col,'Mill axle support',(x,0,1.5))
place(col,'Mill covered passage',(-6,-1,0))
place(col,'Mill chimney base',(-2,1,0))
for z in [1,4,7]: place(col,'Mill chimney shaft',(-2,1,z))
place(col,'Mill chimney cap',(-2,1,10))

# Working infrastructure example and distant windmill assembly.
col=begin_assembly('H Lock and dock crane complete')
for x,yaw in [(-2.5,-math.pi/2),(2.5,math.pi/2)]: place(col,'Lock chamber wall',(x,0,0),yaw)
for y in [-3,3]:
 place(col,'Lock gate left',(-2,y,0),.15); place(col,'Lock gate right',(2,y,0),-.15)
for x in [-3,3]: place(col,'Lock gate winding mechanism',(x,-3,3.2))
place(col,'Dock crane base',(5,0,0)); place(col,'Dock crane boom',(5,0,4)); place(col,'Hoist pulley',(7.8,0,4.9)); place(col,'Cargo hook',(7.8,0,2.5)); place(col,'Dock crane winding drum',(5,-.4,1))
place(col,'Hoist hanging cable',(7.8,0,2.8)); place(col,'Small cargo boat',(0,0,.2),scale=(1,.7,1)); place(col,'Dock bollard',(4,-2,0))
col=begin_assembly('I Distant windmill complete')
place(col,'Distant windmill body'); ob=place(col,'Windmill sail cross',(0,-1.2,3),rotation=Matrix.Rotation(math.pi/6,4,'Y')); ob['animation_axis']='local Y'

# ---- SAVE, VALIDATE, PRESENT ----
categories={cat:str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/boroughs/'+cat)) for cat in category_counts}
assembly_cat=str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/boroughs/26 Assemblies'))
for rec in catalog: assets[rec['name']].asset_data.catalog_id=categories[rec['kit']]
for name,col in assemblies.items():
 col.asset_mark(); col.asset_data.catalog_id=assembly_cat; col.asset_data.description='Complete editable assembly; real mesh objects share source component mesh data.'
 assembly_info.append({'name':name,'objects':len(col.objects),'mesh_objects':len([o for o in col.objects if o.type=='MESH'])})
(OUT/'blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{uid}:{cat}:{cat}' for cat,uid in categories.items())+f'\n{assembly_cat}:26 Assemblies:26 Assemblies\n')
for rec in catalog:
 td=bpy.data.curves.new('Caption','FONT'); td.body=rec['name']; td.size=.22; td.materials.append(M['Canvas']); ob=bpy.data.objects.new('Caption '+rec['name'],td); scene.collection.objects.link(ob); ob.location=Vector(rec['gallery_position'])+Vector((-2.7,-2.6,.02))
# Lighting helper re-used without invoking the original generation code.
src=helper_path.read_text(); lighting=src[src.index('def camera_light('):src.index('camera_light(example,')]
exec(compile(lighting,str(helper_path),'exec'))
render_scenes=[]
for i,(name,col) in enumerate(assemblies.items()):
 sc=bpy.data.scenes.new(name); sc.collection.children.link(col); sc.unit_settings.system='METRIC'
 bpy.context.window.scene=sc; bpy.context.view_layer.update()
 pts=[o.matrix_world@Vector(v) for o in col.objects if o.type=='MESH' for v in o.bound_box]
 low=Vector(tuple(min(p[k] for p in pts) for k in range(3))); high=Vector(tuple(max(p[k] for p in pts) for k in range(3))); center=(low+high)/2
 extent=max(high.x-low.x,high.y-low.y,high.z-low.z)
 camera_light(sc,center+Vector((extent*1.25,-extent*1.7,extent*1.15)),center,extent*1.8)
 sc.render.resolution_x=1400; sc.render.resolution_y=1200; sc.render.filepath=str(OUT/(name[0]+'_assembly.png')); render_scenes.append(sc)
# Overview uses instances for presentation, editable assemblies remain separate scenes.
overview=bpy.data.scenes.new('01 Borough Architecture Overview')
for i,(name,col) in enumerate(list(assemblies.items())[:7]):
 ob=bpy.data.objects.new(name,None); overview.collection.objects.link(ob); ob.instance_type='COLLECTION'; ob.instance_collection=col; ob.location=((i%4)*26,(i//4)*30,0)
 td=bpy.data.curves.new('Title','FONT'); td.body=name[2:]; td.size=.75; td.materials.append(M['Canvas']); to=bpy.data.objects.new('Title',td); overview.collection.objects.link(to); to.location=ob.location+Vector((-8,-11,0))
camera_light(overview,(110,-115,110),(35,12,4),117); overview.render.resolution_x=2200; overview.render.resolution_y=1450; overview.render.filepath=str(OUT/'architecture_overview.png')
sheets=[]
for cat in category_counts:
 sc=bpy.data.scenes.new(cat+' Sheet'); records=[r for r in catalog if r['kit']==cat]
 for i,rec in enumerate(records):
  ob=bpy.data.objects.new(rec['name'],None); ob.instance_type='COLLECTION'; ob.instance_collection=assets[rec['name']]; sc.collection.objects.link(ob); ob.location=((i%6)*8,(i//6)*8,0)
  scale=min(3,4.8/max(rec['dimensions_m'])); ob.scale=(scale,)*3; ob.rotation_euler.z=-.2
  td=bpy.data.curves.new('Caption','FONT'); td.body=rec['name']; td.size=.22; td.materials.append(M['Canvas']); to=bpy.data.objects.new('Caption',td); sc.collection.objects.link(to); to.location=ob.location+Vector((-3,-2.5,0))
 rows=math.ceil(len(records)/6); center=(20,(rows-1)*4,0)
 camera_light(sc,(20,-32,52),center,max(52,rows*11)); sc.render.resolution_x=1800; sc.render.resolution_y=1350; sc.render.filepath=str(OUT/(cat[:2]+'_contact_sheet.png')); sheets.append(sc)
# Validation includes the mesh itself, not only object counts.
errors=[]
for rec in catalog:
 ob=next(o for o in assets[rec['name']].objects if o.type=='MESH')
 if any(p.area<1e-10 for p in ob.data.polygons): errors.append(rec['name']+' zero-area face')
 if any(not math.isfinite(v) for vert in ob.data.vertices for v in vert.co): errors.append(rec['name']+' invalid coordinate')
assert not errors,errors
bpy.context.window.scene=overview
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   area.spaces.active.shading.type='MATERIAL'; area.spaces.active.region_3d.view_location=(35,12,4); area.spaces.active.region_3d.view_distance=120; area.spaces.active.region_3d.view_rotation=Vector((75,-127,106)).to_track_quat('Z','Y')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'City_Boroughs_and_Landmarks.blend'))
(OUT/'component_inventory.json').write_text(json.dumps({'count':len(catalog),'categories':category_counts,'components':catalog,'assemblies':assembly_info},indent=2)+'\n')
print('BOROUGH_LIBRARY_SAVED',len(catalog),'components',len(assemblies),'assemblies',flush=True)
for sc in [overview]+render_scenes+sheets:
 bpy.context.window.scene=sc; bpy.ops.render.render(write_still=True)
print('BOROUGH_LIBRARY_RENDERED',flush=True)
