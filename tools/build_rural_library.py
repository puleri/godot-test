"""Editable rural modules and complete farm buildings."""
from pathlib import Path
helper=Path(__file__).with_name('build_hub_town_library.py')
exec(compile(helper.read_text().split('# BUILDING STRUCTURE')[0].replace("R/'art/HubTownLibrary'","R/'art/RuralLibrary'"),str(helper),'exec'))
scene.name='Rural components and building examples'
mat('RuralEarth',(.20,.13,.065));mat('Straw',(.58,.43,.15));mat('CropGreen',(.22,.34,.08));mat('FarmPlaster',(.70,.61,.43));mat('BarnRed',(.35,.13,.075));mat('RoofClay',(.36,.16,.08))
C='Rural Kit'
def wallbay(kind='plain',barn=False):
 h=4 if barn else 3;material='BarnRed' if barn else 'FarmPlaster';ow,oh,bottom=(3,3.3,0) if barn else ((1.2,1.4,.9) if kind=='window' else (1.3,2.3,0))
 if kind=='plain':box('wall',(0,0,h/2),(4,.24,h),material)
 else:
  side=(4-ow)/2
  for s in [-1,1]:box('opening pier',(s*(ow/2+side/2),0,h/2),(side,.24,h),material)
  box('lintel',(0,0,(h+bottom+oh)/2),(ow,.24,h-bottom-oh),material)
  if bottom:box('apron',(0,0,bottom/2),(ow,.24,bottom),material)
  if kind=='window':
   box('window glazing',(0,-.025,bottom+oh/2),(ow-.12,.08,oh-.12),'Amber')
   for x in [-ow/2,0,ow/2]:box('window mullion',(x,-.11,bottom+oh/2),(.07,.12,oh),'Timber')
   for z in [bottom,bottom+oh/2,bottom+oh]:box('window rail',(0,-.11,z),(ow+.1,.12,.07),'Timber')
   for x in [-.85,.85]:box('open shutter',(x,-.18,bottom+oh/2),(.36,.09,oh),'Green')
   box('stone sill',(0,-.16,bottom-.06),(1.5,.45,.12),'StoneLight')
 for x in [-1.91,1.91]:box('end post',(x,0,h/2),(.18,.32,h),'Timber')
 for z in [.1,h-.1]:box('wall tie',(0,0,z),(4,.32,.18),'Timber')
 if barn:
  for x in [-1.6,-1.2,-.8,-.4,0,.4,.8,1.2,1.6]:
   if kind!='plain' and abs(x)<ow/2:continue
   box('plank seam',(x,-.135,h/2),(.035,.035,h-.2),'Wood')

def roof(w=8,rise=2.5):
 e=w/2+.35;d=2;t=.16
 mesh('solid pitched roof',[(-e,-d,0),(e,-d,0),(e,d,0),(-e,d,0),(0,-d,rise),(0,d,rise),(-e,-d,-t),(e,-d,-t),(e,d,-t),(-e,d,-t),(0,-d,rise-t),(0,d,rise-t)],[(0,4,5,3),(4,1,2,5),(6,9,11,10),(10,11,8,7),(0,6,10,4),(4,10,7,1),(3,5,11,9),(5,2,8,11),(0,3,9,6),(1,7,8,2)],'RoofClay' if w==8 else 'Slate')
 for side in [-1,1]:
  for row in range(1,7):
   x=side*e*row/7;z=rise*(1-row/7)+.035;beam('roof course',(x,-d,z),(x,d,z),.045,'Clay')
 beam('ridge',(0,-d,rise+.04),(0,d,rise+.04),.14,'Clay')
def gable(w=8,rise=2.5):
 mesh('gable',[(-w/2,-.12,0),(w/2,-.12,0),(0,-.12,rise),(-w/2,.12,0),(w/2,.12,0),(0,.12,rise)],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],'FarmPlaster')
 beam('gable kingpost',(0,-.16,0),(0,-.16,rise),.15)
def fence(gate=False):
 for x in [-2,2]:box('post',(x,0,.75),(.16,.18,1.5),'Wood')
 for z in [.5,1.15]:box('rail',(0,0,z),(4,.12,.12),'Wood')
 if gate:beam('gate diagonal',(-1.9,-.08,.4),(1.9,-.08,1.25),.09,'Wood')
def well():
 ring('well masonry',(0,0,.5),.8,.58,1,'Stone',16)
 for x in [-1,1]:box('well post',(x,0,1.25),(.14,.14,2.5),'Wood')
 beam('well axle',(-1.1,0,1.6),(1.1,0,1.6),.10,'Wood');box('well canopy',(0,0,2.5),(2.5,1.8,.12),'Slate')
def hay():
 box('hay bale',(0,0,.45),(1.3,.8,.9),'Straw')
 for x in [-.35,.35]:box('bale binding',(x,0,.46),(.04,.82,.92),'Timber')
def cart():
 box('cart bed',(0,0,.65),(1.5,2,.12),'Wood')
 for x in [-.72,.72]:box('cart side',(x,0,.95),(.1,2,.5),'Wood')
 for x in [-.95,.95]:
  o=ring('cart wheel',(x,0,.55),.5,.38,.12,'Timber',12);o.rotation_euler.y=math.pi/2
  for a in range(6):beam('wheel spoke',(x,0,.55),(x,.43*math.sin(a*math.pi/3),.55+.43*math.cos(a*math.pi/3)),.05)
 for x in [-.5,.5]:beam('cart shaft',(x,-.8,.7),(x,-3,.8),.09,'Wood')
def orchard():
 cyl('trunk',(0,0,1.2),.18,2.4,'Timber',8)
 for x,y,z in [(-.8,0,2.7),(.8,.2,3),(0,-.7,3.3),(0,.5,3.6)]:uvball('leaf crown',(x,y,z),(1.1,1,1),'Leaf')
 for x,y,z in [(-1,0,2.4),(.7,-.8,2.9),(0,-1.2,3.2),(.5,.8,3)]:uvball('fruit',(x,y,z),(.12,.12,.12),'Red',8,4)
def crop(wheat=False):
 box('soil bed',(0,0,.035),(4,4,.07),'RuralEarth')
 for i in range(5):
  for j in range(5):
   x=-1.6+i*.8;y=-1.6+j*.8
   if wheat:
    beam('grain stalk',(x,y,.07),(x,y,.85),.025,'Straw');uvball('grain head',(x,y,.85),(.07,.07,.18),'Straw',6,4)
   else:uvball('cabbage',(x,y,.22),(.28,.28,.23),'CropGreen',8,4)
asset(C,'Farm foundation 4m',lambda:box('foundation',(0,0,.3),(4,4,.6),'Stone'))
for kind in ['plain','window','door']:asset(C,'Farm '+kind+' wall 4m',lambda kind=kind:wallbay(kind))
asset(C,'Farm door leaf',lambda:(box('door',(0,0,1.12),(1.18,.12,2.24),'Wood'),beam('door brace',(-.5,-.08,.2),(.5,-.08,2),.09)))
asset(C,'Farm roof bay 8m',roof);asset(C,'Farm gable 8m',gable)
asset(C,'Barn plank wall 4m',lambda:wallbay('plain',True));asset(C,'Barn door opening 4m',lambda:wallbay('door',True))
asset(C,'Barn door leaf',lambda:(box('barn door',(0,0,1.6),(1.45,.15,3.2),'Wood'),beam('door brace',(-.65,-.1,.2),(.65,-.1,3),.12)))
asset(C,'Barn roof bay 8m',lambda:roof(8,3.2));asset(C,'Barn gable 8m',lambda:gable(8,3.2))
asset(C,'Shed roof bay 4m',lambda:roof(4,1.2));asset(C,'Shed gable 4m',lambda:gable(4,1.2))
asset(C,'Farm chimney',lambda:(box('chimney',(0,0,1.25),(.65,.65,2.5),'Stone'),box('chimney cap',(0,0,2.5),(.85,.85,.14),'StoneLight')))
asset(C,'Fence bay 4m',fence);asset(C,'Farm gate 4m',lambda:fence(True));asset(C,'Hay bale',hay);asset(C,'Farm cart',cart);asset(C,'Farm well',well)
asset(C,'Water trough',lambda:(box('base',(0,0,.12),(2,.8,.24),'Stone'),box('front',(0,-.36,.4),(2,.08,.5),'Stone'),box('back',(0,.36,.4),(2,.08,.5),'Stone'),box('end',(-.96,0,.4),(.08,.64,.5),'Stone'),box('end',(.96,0,.4),(.08,.64,.5),'Stone'),box('water',(0,0,.5),(1.84,.6,.02),'Water')))
asset(C,'Wheat bed 4m',lambda:crop(True));asset(C,'Vegetable bed 4m',crop);asset(C,'Orchard fruit tree',orchard)
# Assemblies are built from these exact modules and saved as directly editable meshes.
def use(name,pos=(0,0,0),angle=0):
 source=next(iter(assets[name].objects));o=source.copy();o.data=source.data.copy();current.objects.link(o);o.location=pos;o.rotation_euler.z=angle;pieces.append(o)
def building(barn=False,tall=False,shed=False):
 w=4 if shed else 8;d=12 if barn else 4 if shed else 8;h=4 if barn else 3;stories=2 if tall else 1
 for x in range(-int(w/2)+2,int(w/2),4):
  for y in range(-int(d/2)+2,int(d/2),4):use('Farm foundation 4m',(x,y,0))
 for floor in range(stories):
  z=.6+floor*h
  for y,angle in [(-d/2,0),(d/2,math.pi)]:
   for x in range(-int(w/2)+2,int(w/2),4):
    door=floor==0 and y<0 and x==(-w/2+2)
    key=('Barn door opening 4m' if door else 'Barn plank wall 4m') if barn else ('Farm door wall 4m' if door else 'Farm window wall 4m')
    use(key,(x,y,z),angle)
    if door:
     if barn:
      for dx in [-.75,.75]:use('Barn door leaf',(x+dx,y,z))
     else:use('Farm door leaf',(x,y,z))
  for x,angle in [(-w/2,-math.pi/2),(w/2,math.pi/2)]:
   for y in range(-int(d/2)+2,int(d/2),4):use('Barn plank wall 4m' if barn else 'Farm window wall 4m',(x,y,z),angle)
 for y in range(-int(d/2)+2,int(d/2),4):use('Barn roof bay 8m' if barn else 'Shed roof bay 4m' if shed else 'Farm roof bay 8m',(0,y,.6+h*stories))
 for y in [-d/2,d/2]:use('Barn gable 8m' if barn else 'Shed gable 4m' if shed else 'Farm gable 8m',(0,y,.6+h*stories))
 if not barn:use('Farm chimney',(w/2-1,d/2-1,h*stories+.5))
asset('Examples','A Low farmhouse',building);asset('Examples','B Tall farmhouse',lambda:building(tall=True));asset('Examples','C Timber barn',lambda:building(barn=True));asset('Examples','D Farm shed',lambda:building(shed=True))
for i,record in enumerate(catalog):
 c=assets[record['name']];p=Vector(((i%6)*18,(i//6)*20,0));o=next(iter(c.objects));o.location=p;c.instance_offset=p;record['gallery_position']=list(p)
# Gallery lighting and render.
def camera(name,pos,target,ortho):
 d=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=ortho;return o
scene.camera=camera('Rural kit overview',(120,-130,140),(45,40,0),145)
world=bpy.data.worlds.new('Rural preview world');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.23,.28,.33,1);world.node_tree.nodes['Background'].inputs[1].default_value=.65;scene.world=world
ld=bpy.data.lights.new('Sun','SUN');ld.energy=2;ob=bpy.data.objects.new('Sun',ld);scene.collection.objects.link(ob);ob.rotation_euler=(.4,-.5,-.4)
scene.render.engine='CYCLES';scene.cycles.samples=20;scene.render.resolution_x=1800;scene.render.resolution_y=1400;scene.view_settings.view_transform='AgX'
(OUT/'component_inventory.json').write_text(json.dumps(catalog,indent=2)+'\n')
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Rural_Component_Library.blend'))
print('RURAL_LIBRARY_SAVED',len(catalog),flush=True)
scene.render.filepath=str(OUT/'rural_components.png');bpy.ops.render.render(write_still=True)
