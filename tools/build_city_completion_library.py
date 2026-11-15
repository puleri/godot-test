"""48 completion assets and 32 editable building variants, reusing authored modules."""
from pathlib import Path
helper=Path(__file__).with_name('build_hub_town_library.py')
exec(compile(helper.read_text().split('# BUILDING STRUCTURE')[0].replace("R/'art/HubTownLibrary'","R/'art/CityCompletionLibrary'"),str(helper),'exec'))
from mathutils import Matrix
scene.name='City completion — editable assets'
for n,c in [('Soil',(.22,.12,.055)),('Straw',(.61,.44,.16)),('Crop',(.27,.39,.10)),('WetRock',(.15,.19,.20)),('Foam',(.58,.72,.70)),('Sail',(.78,.68,.45))]:mat(n,c)
reused={}
files={'HubTownLibrary':'HubTown_Component_Library.blend','CityBoroughLibrary':'City_Boroughs_and_Landmarks.blend','ResidentialStreetLibrary':'Residential_Streets_and_Apartments.blend','RuralLibrary':'Rural_Component_Library.blend','UpperCityLibrary':'Upper_City_Waterways_and_Gardens.blend','HubTownExpansion':'HubTown_Environment_Expansion.blend'}
requests={
 'HubTownLibrary':['Timber wall plain','Timber wall window','Timber wall door','Square window insert','House door','Slate roof panel','Gable timber window','Chimney stack 1','Wall lantern','Hanging sign bracket','Shop sign rectangular','Table','Chair','Barrel closed','Storage sack','Rope coil','Dock ladder','Mooring ring','Market stall frame','Market canopy striped','Market counter straight','Produce tray','Large crate','Stone stairs short'],
 'CityBoroughLibrary':['A Warehouse complete','B Merchant shophouse complete','C Courtyard tenement complete','D Hillside villa complete','Small cargo boat','Rowboat','Dock bollard','Gangplank','Warehouse hoist frame','Warehouse loading platform','Warehouse covered gallery','Villa pergola bay','Villa garden balustrade','Tenement gallery floor','Tenement gallery railing','Tenement chimney short','Laundry line','Laundry hanging sheet'],
 'ResidentialStreetLibrary':['A Cream peaked bookshop','B Rose stepped tailor','C Sage arched cafe','D Ochre oriel restaurant','E Courtyard apartment complex','F Corner restaurant apartments','Apartment paired window wall','Apartment gallery door wall','Restaurant window frontage','Recessed restaurant entrance','Curved striped awning','Restaurant menu board','Peaked gable','Bell stepped gable','Scroll gable'],
 'RuralLibrary':['A Low farmhouse','B Tall farmhouse','C Timber barn','D Farm shed','Fence bay 4m','Farm gate 4m','Farm well','Farm cart','Vegetable bed 4m','Wheat bed 4m','Orchard fruit tree'],
 'UpperCityLibrary':['Natural to masonry bank','Natural rocky bank','Shallow planted bank'],
 'HubTownExpansion':['Detailed retaining bay','Retaining buttress','Water access steps','Dock platform straight']}
# The last optional module belongs to the base library instead.
requests['HubTownExpansion'].remove('Dock platform straight');requests['HubTownLibrary'].append('Dock platform straight')
for folder,names in requests.items():
 with bpy.data.libraries.load(str(R/'art'/folder/files[folder]),link=False) as (src,dst):
  assert not set(names)-set(src.collections),(folder,set(names)-set(src.collections));dst.collections=names[:]
 for name,c in zip(names,dst.collections):reused[name]=c;c.use_fake_user=True

def source_world(o):
 return source_world(o.parent)@o.matrix_parent_inverse@o.matrix_basis if o.parent else o.matrix_basis.copy()

def use(name,pos=(0,0,0),yaw=0,scale=(1,1,1)):
 c=assets.get(name) or reused[name]
 xf=Matrix.Translation(Vector(pos))@Matrix.Rotation(yaw,4,'Z')@Matrix.Diagonal(Vector((*scale,1)))@Matrix.Translation(-c.instance_offset)
 for source in c.all_objects:
  if source.type!='MESH':continue
  o=bpy.data.objects.new(name,source.data.copy());current.objects.link(o);o.data.transform(xf@source_world(source));pieces.append(o)

def rock(size=(3,2,2),wet=False):
 bm=bmesh.new();bmesh.ops.create_icosphere(bm,subdivisions=1,radius=1)
 for v in bm.verts:v.co=Vector((v.co.x*size[0]*random.uniform(.8,1.1),v.co.y*size[1],(v.co.z+1)*size[2]/2))
 me=bpy.data.meshes.new('faceted rock');bm.to_mesh(me);bm.free();o=bpy.data.objects.new('rock',me);current.objects.link(o);pieces.append(o);me.materials.append(M['WetRock' if wet else 'Stone'])

def arch(span=6,h=3,depth=1):
 r=span*.42;spring=h-r-.35
 # Segmental arch opening, with masonry solid from arch intrados up to deck.
 for i in range(16):
  a=math.pi*i/16;b=math.pi*(i+1)/16
  x1=r*math.cos(a);x2=r*math.cos(b);z1=spring+r*math.sin(a);z2=spring+r*math.sin(b)
  vs=[(x,y,z) for y in [-depth/2,depth/2] for x,z in [(x1,z1),(x2,z2),(x2,h),(x1,h)]]
  mesh('arch voussoir',vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'StoneLight' if i%3==0 else 'Stone')
 for sign in [-1,1]:box('arch pier',(sign*(span/2+r)/2,0,h/2),((span/2-r),depth,h),'Stone')

def retaining(h=6,slope=0):
 # Cap follows optional slope; face has deliberate buttresses rather than surface noise.
 w=4;verts=[(-2,-.4,0),(2,-.4,0),(2,.4,0),(-2,.4,0),(-2,-.4,h),(2,-.4,h+slope),(2,.4,h+slope),(-2,.4,h)]
 mesh('wall',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'Stone')
 for x in [-1.7,1.7]:box('buttress',(x,-.48,h*.45),(.4,.7,h*.9),'StoneLight')
 for z in [1.5,3,4.5]:
  if z<h:box('course',(0,-.415,z),(4,.035,.10),'StoneLight')
 beam('coping',(-2,0,h+.1),(2,0,h+slope+.1),.22,'StoneLight',.95)

def boat(sail=False,furled=False,fishing=False):
 # Closed thick shell with an open interior; bow and stern retain distinct shapes.
 outline=[(-.6,-2.4),(.6,-2.4),(1,-1.2),(1,1.1),(.55,2.15),(0,2.8),(-.55,2.15),(-1,1.1),(-1,-1.2)];n=len(outline)
 v=[]
 for scale,z in [(.45,-.55),(1,.50),(.88,.45),(.36,-.32)]:v.extend((x*scale,y*scale,z) for x,y in outline)
 fs=[]
 for i in range(n):
  j=(i+1)%n;fs.extend([(i,j,n+j,n+i),(n+i,n+j,2*n+j,2*n+i),(2*n+i,2*n+j,3*n+j,3*n+i)])
 fs.extend([tuple(reversed(range(n))),tuple(range(3*n,4*n))]);mesh('hollow hull',v,fs,'Wood')
 for y in [-1.4,0,1.4]:box('seat',(0,y,.15),(1.5,.35,.12),'Timber')
 for i in range(n):j=(i+1)%n;beam('gunwale',(*outline[i],.52),(*outline[j],.52),.09,'Timber')
 if sail or furled:
  cyl('mast',(0,.1,2.4),.055,5.5,'Timber',8);beam('boom',(0,.1,1),(0,-2,1),.075,'Timber')
  if sail:
   mesh('billowing sail',[(0,.1,4.9),(0,-2.1,1.1),(.5,-.9,2.1),(0,.1,1.1)],[(0,1,2),(0,2,3),(1,3,2)],'Sail')
  else:box('furled sail',(0,-.9,1.15),(.2,2,.2),'Sail')
  for p in [(-.9,-1,.5),(.9,-1,.5),(0,2.6,.5)]:beam('rigging',p,(0,.1,4.8),.018,'Timber')
  box('rudder',(0,-2.48,-.05),(.1,.7,1.1),'Timber')
 if fishing:use('Storage sack',(.2,1,.2),scale=(.6,.6,.6));use('Rope coil',(-.4,-1,.25),scale=(.65,.65,.65))

def net():
 for i in range(9):
  x=-1+i*.25;beam('net cord',(x,-1,.12),(x,1,.12+abs(x)*.08),.015,'Canvas');beam('net cord',(-1,x,.2),(1,x,.2),.015,'Canvas')

def crop(kind='wheat',length=8):
 box('soil',(0,0,.035),(4,length,.07),'Soil')
 for row in range(4):
  x=-1.5+row
  for j in range(int(length*2)):
   y=-length/2+.3+j*.5
   if kind=='furrow':continue
   if kind=='vegetable':uvball('leaf',(x,y,.23),(.25,.3,.2),'Crop',6,3)
   else:beam('stem',(x,y,.05),(x,y,.8),.025,'Straw');uvball('head',(x,y,.85),(.07,.07,.15),'Straw',6,3)
  box('ridge',(x,0,.10),(.3,length,.12),'Soil')

def hedgecurve():
 for i in range(8):
  a=i*math.pi/14;uvball('hedge',(3*math.cos(a)-1.5,3*math.sin(a)-1.5,.65),(.6,.6,.7),'Leaf',7,4)

# 48 additions; each is a separately editable asset.
asset('Boats','Fishing boat',lambda:boat(fishing=True));asset('Boats','Furled sail launch',lambda:boat(furled=True));asset('Boats','Lagoon sailing boat',lambda:boat(sail=True))
asset('Boats','Fishing net bundle',net)
asset('Boats','Oar pair',lambda:[(beam('shaft',(x,-1.1,0),(x,1.1,0),.045,'Wood'),box('paddle',(x,1.2,0),(.18,.6,.055),'Wood')) for x in [-.22,.22]])
asset('Boats','Rope boat fender',lambda:uvball('rope fender',(0,0,.3),(.18,.18,.3),'Canvas',8,5))
asset('Boats','Net drying frame',lambda:([beam('upright',(x,0,0),(x,0,2.3),.10,'Wood') for x in [-1,1]],beam('top',(-1,0,2.3),(1,0,2.3),.1,'Wood'),[beam('hanging net',(x,0,.3),(x,0,2.3),.02,'Canvas') for x in [-.8,-.4,0,.4,.8]]))
asset('Boats','Timber boat cradle',lambda:[(box('foot',(0,y,.1),(2.4,.25,.2),'Timber'),beam('cradle',(-1,y,.2),(0,y,.05),.15,'Timber'),beam('cradle',(0,y,.05),(1,y,.2),.15,'Timber')) for y in [-1,1]])
asset('Bridges','Arch support 6m',lambda:arch(6,3,1));asset('Bridges','Long span arch 10m',lambda:arch(10,5,1.1))
asset('Bridges','Cutwater pier',lambda:mesh('cutwater',[(-.8,-1,0),(.8,-1,0),(.8,1,0),(0,2,0),(-.8,1,0),(-.8,-1,4),(.8,-1,4),(.8,1,4),(0,2,4),(-.8,1,4)],[(0,4,3,2,1),(5,6,7,8,9),(0,1,6,5),(1,2,7,6),(2,3,8,7),(3,4,9,8),(4,0,5,9)],'Stone'))
asset('Bridges','Angled bridge deck connector',lambda:mesh('connector',[(-2,-2,0),(2,-2,0),(2.8,2,0),(-1.2,2,0),(-2,-2,.3),(2,-2,.3),(2.8,2,.3),(-1.2,2,.3)],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],'StoneLight'))
asset('Bridges','Curved parapet connector',lambda:[box('parapet',(2*math.cos(i*.12),2*math.sin(i*.12),.5),(.3,.28,1),'Stone',rot=(0,0,i*.12)) for i in range(7)])
asset('Bridges','Bridge pier footing',lambda:(box('footing',(0,0,.2),(2.4,2.4,.4),'Stone'),box('plinth',(0,0,.6),(1.8,1.8,.4),'StoneLight')))
asset('Retaining','Tall reinforced wall 6m',retaining);asset('Retaining','Sloping retaining return',lambda:retaining(4,2))
asset('Retaining','Wall to rock junction',lambda:(retaining(3),rock((2.5,1.2,3))))
asset('Retaining','Retaining drainage outlet',lambda:(ring('outlet',(0,0,.4),.4,.25,.4,'StoneLight',10)))
asset('Retaining','Stair buttress 4m',lambda:box('buttress',(0,0,2),(.7,1.3,4),'Stone'))
asset('Retaining','Retaining terrace corner',lambda:(retaining(4),box('return',(1.6,1.6,2),(.8,3.2,4),'Stone')))
for name,sz in [('Shore boulder broad',(3,2,2)),('Shore boulder tall',(1.5,1.5,3.5)),('Shore rock shelf',(3,2,.8))]:asset('Shore',name,lambda sz=sz:rock(sz))
asset('Shore','Concave inlet rocks',lambda:[(lambda n: (rock((1.5,1,1.8)), setattr(pieces[-1],'location',(3*math.cos(n),3*math.sin(n),0))))(i*math.pi/6) for i in range(7)])
asset('Shore','Headland rock cluster',lambda:(rock((4,2.5,2.8)),rock((2,3,1.2))))
asset('Shore','Wet waterline rock',lambda:rock((2,1.5,.8),True))
asset('Quays','Building quay foundation',lambda:(box('base',(0,0,1.5),(4,3,3),'Stone'),box('cap',(0,0,3),(4.2,3.2,.2),'StoneLight')))
asset('Quays','Quay height transition',lambda:retaining(2,1))
asset('Quays','Dock quay connector',lambda:(box('abutment',(0,0,.75),(2,1,1.5),'Stone'),box('landing',(0,-1,1.5),(2,3,.18),'Wood')))
asset('Quays','Recessed mooring bay',lambda:(box('back',(0,1,1),(4,.5,2),'Stone'),[box('side',(x,0,1),(.5,2,2),'Stone') for x in [-2,2]]))
asset('Quays','Quay corner bollard plinth',lambda:(box('plinth',(0,0,.15),(1,1,.3),'StoneLight'),use('Dock bollard',(0,0,.3))))
asset('Quays','Waterline masonry face 4m',lambda:(box('core',(0,0,1.5),(4,.5,3),'Stone'),[box('course',(0,-.26,z),(4,.04,.09),'StoneLight') for z in [.4,1,1.6,2.2,2.8]]))
asset('Farmland','Curved hedgerow boundary',hedgecurve)
asset('Farmland','Wheat strip 8m',crop);asset('Farmland','Vegetable strip 8m',lambda:crop('vegetable'));asset('Farmland','Ploughed furrow strip',lambda:crop('furrow'))
asset('Farmland','Irrigation ditch 4m',lambda:mesh('ditch',[(-2,-.7,.15),(2,-.7,.15),(-2,-.3,-.3),(2,-.3,-.3),(-2,.3,-.3),(2,.3,-.3),(-2,.7,.15),(2,.7,.15)],[(0,1,3,2),(2,3,5,4),(4,5,7,6)],'Soil'))
asset('Farmland','Field ditch crossing',lambda:(box('bridge',(0,0,.15),(2,2,.2),'Wood'),[box('rail',(x,0,.6),(.1,2,1),'Wood') for x in [-.95,.95]]))
asset('Farmland','Covered haystack',lambda:(uvball('hay',(0,0,1),(1.5,1.2,1),'Straw',8,5),box('cover',(0,0,1.9),(2.5,1.8,.08),'Canvas')))
asset('Farmland','Orchard ground patch',lambda:(box('soil',(0,0,.015),(4,4,.03),'Soil'),[uvball('grass',(x,y,.04),(.45,.5,.05),'Crop',6,3) for x,y in [(-1,-1),(1,1),(-1,1),(1,-1)]]))
asset('Farmland','Field boundary stone stile',lambda:(box('wall',(0,0,.45),(4,.45,.9),'Stone'),[box('step',(0,y,z),(1,.5,.2),'StoneLight') for y,z in [(-.6,.2),(0,.5),(.6,.2)]]))
asset('Farmland','Compost and tool rack',lambda:(box('compost',(0,0,.4),(1.5,1.2,.8),'Soil'),[beam('tool',(x,1,0),(x,1,1.8),.04,'Wood') for x in [-.5,0,.5]]))
asset('Architecture','Workshop open canopy',lambda:([beam('post',(x,y,0),(x,y,2.8),.12,'Timber') for x in [-2,2] for y in [-1.5,1.5]],box('roof',(0,0,2.8),(4.4,3.4,.2),'Slate')))
asset('Architecture','Service rear stoop',lambda:(box('landing',(0,0,.45),(1.5,1,.9),'Stone'),[box('step',(0,-.75-i*.35,.35-i*.1),(1.5,.35,.2),'Stone') for i in range(3)]))
asset('Architecture','Restaurant terrace railing',lambda:([box('rail',(0,0,z),(4,.10,.10),'Wood') for z in [.2,1]],[box('spindle',(x,0,.6),(.07,.07,.8),'Wood') for x in [-1.9,-1.3,-.7,0,.7,1.3,1.9]]))
asset('Architecture','Boathouse slip frame',lambda:([box('pier',(x,0,1.4),(.25,1,2.8),'Timber') for x in [-1.8,1.8]],box('lintel',(0,0,2.8),(3.85,.4,.3),'Timber')))
asset('Architecture','Attached lean-to roof',lambda:box('shed roof',(0,0,.5),(3,2.5,.18),'Slate',(.18,0,0)))
asset('Architecture','Roof gutter and downpipe',lambda:(beam('gutter',(-2,0,3),(2,0,3),.08,'Iron'),beam('downpipe',(1.9,0,0),(1.9,0,3),.08,'Iron')))
assert len(catalog)==48,len(catalog)
# Complete building families. Every façade is from existing windowed modules.
def timber_house(width=4,depth=6,stories=2,variant=0,slip=False):
 for floor in range(stories):
  z=floor*3
  box('floor',(0,0,z+.08),(width,depth,.16),'Wood')
  for y,yaw in [(-depth/2,0),(depth/2,math.pi)]:
   if slip and floor==0 and y<0:use('Boathouse slip frame',(0,y,z),scale=(width/4,1,1));continue
   name='Timber wall door' if floor==0 else 'Timber wall window'
   use(name,(0,y,z),yaw,(width/4,1,1))
   use('House door' if floor==0 else 'Square window insert',(0,y+(-.02 if y<0 else .02),z+(0 if floor==0 else 1)),yaw)
  for x,yaw in [(-width/2,-math.pi/2),(width/2,math.pi/2)]:
   for y in [-depth/4,depth/4]:
    use('Apartment paired window wall',(x,y,z),yaw,(depth/8,1,1))
 for yaw in [-math.pi/2,math.pi/2]:use('Slate roof panel',(0,0,stories*3),yaw,(depth/4,width/4,1))
 for y,yaw in [(-depth/2,0),(depth/2,math.pi)]:use('Gable timber window',(0,y,stories*3),yaw,(width/4,1,1))
 use('Chimney stack 1',(width*.23,depth*.18,stories*3+.6))
 use('Roof gutter and downpipe',(width/2+.1,0,0),math.pi/2,(depth/4,1,stories))
 use('Wall lantern',(-width*.35,-depth/2-.15,2.1),scale=(.6,.6,.6))

def family(kind,v):
 if kind=='Merchant':use(['A Cream peaked bookshop','B Rose stepped tailor','C Sage arched cafe','D Ochre oriel restaurant'][v])
 elif kind=='Apartment':
  use('C Courtyard tenement complete' if v%2==0 else 'E Courtyard apartment complex')
  for i in range(v+1):use('Laundry hanging sheet',(-3+i*1.6,-.5,4.2),scale=(.7,.7,.7))
  if v>=2:use('Villa pergola bay',(0,-4,0))
 elif kind=='Warehouse':
  use('A Warehouse complete')
  if v%2:use('Warehouse covered gallery',(0,-4,0))
  if v>=2:use('Warehouse hoist frame',(3,-3,3))
  for i in range(v+1):use('Large crate',(-2+i*1.1,-4,0))
 elif kind=='Villa':
  use('D Hillside villa complete')
  if v%2:use('Villa pergola bay',(0,-5,0))
  if v>=2:use('Villa pergola bay',(5,0,0),math.pi/2)
  use('Villa garden balustrade',(-4,-5,0))
 elif kind=='Farm':
  use(['A Low farmhouse','B Tall farmhouse','C Timber barn','D Farm shed'][v])
  if v<2:use('D Farm shed',(6,2,0),math.pi/2)
  if v==2:use('Covered haystack',(5,2,0))
 elif kind=='Artisan':
  timber_house(4,6,2 if v<3 else 3,v)
  if v%2:
   use('Workshop open canopy',(0,-5,0),scale=(.9,.8,1))
   for i in range(v+1):use('Barrel closed',(-1.3+i*.7,-4.7,0),scale=(.7,.7,.7))
  else:use('Shop sign rectangular',(0,-3.2,2.5),scale=(.6,.6,.6))
  if v%2:use('Attached lean-to roof',(2.5,1,2.4))
 elif kind=='Inn':
  timber_house(8 if v>=2 else 6,8,3,v)
  use('Workshop open canopy',(0,-5.5,0),scale=(1.4,1,1))
  use('Restaurant terrace railing',(0,-7,0),scale=(1.4,1,1))
  for x in [-1.4,1.4]:use('Table',(x,-5.5,0),scale=(.8,.8,.8));use('Chair',(x,-6.4,0))
  use('Shop sign rectangular',(-2,-4.3,2.6));use('Restaurant menu board',(2.5,-5,0))
  if v%2:use('Curved striped awning',(0,-4.2,5.2))
 elif kind=='Boathouse':
  timber_house(4 if v<2 else 6,6 if v%2==0 else 8,1,v,True)
  if v:use('Dock platform straight',(0,-4,0),scale=(1,1,.7))
  if v%2:use('Net drying frame',(3,0,0))
  if v>=2:use('Fishing net bundle',(0,-4,.1))

for kind in ['Merchant','Apartment','Warehouse','Villa','Farm','Artisan','Inn','Boathouse']:
 for v in range(4):asset('Building assemblies',f'{kind} variant {v+1:02}',lambda k=kind,v=v:family(k,v),'Complete editable mesh assembly; reuses original windowed modules and materials.')
import uuid
category_ids={r['kit']:str(uuid.uuid5(uuid.NAMESPACE_URL,'rook/city-completion/'+r['kit'])) for r in catalog}
(OUT/'blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{u}:City Completion/{k}:{k}' for k,u in category_ids.items())+'\n')
# Normalize gallery and mark each mesh as an asset as well as its collection.
for i,r in enumerate(catalog):
 ob=next(o for o in assets[r['name']].objects if o.type=='MESH');ob.modifiers.clear()
 ob.location=((i%8)*22,(i//8)*24,0);assets[r['name']].instance_offset=ob.location
 ob.asset_mark();ob.asset_data.catalog_id=category_ids[r['kit']];assets[r['name']].asset_data.catalog_id=category_ids[r['kit']];ob['asset_name']=r['name'];r['gallery_position']=list(ob.location)
 r['triangles']=sum(len(p.vertices)-2 for p in ob.data.polygons)
 ob.data.update()
(OUT/'component_inventory.json').write_text(json.dumps({'new_components':48,'building_assemblies':32,'components':catalog,'reused_sources':requests},indent=2))
# Assembly-only overview for visual review.
d=bpy.data.cameras.new('Completion library');cam=bpy.data.objects.new('Completion library',d);scene.collection.objects.link(cam);cam.location=(170,70,170);target=Vector((77,180,3));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=215;scene.camera=cam
world=bpy.data.worlds.new('Library sky');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[1].default_value=.6;scene.world=world
ld=bpy.data.lights.new('Sun','SUN');ld.energy=2;ob=bpy.data.objects.new('Sun',ld);scene.collection.objects.link(ob);ob.rotation_euler=(.4,-.5,-.5)
scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=2000;scene.render.resolution_y=1400;scene.render.resolution_percentage=100
for scr in bpy.data.screens:
 for area in scr.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.clip_end=1000
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'City_Completion_Library.blend'))
print('COMPLETION_LIBRARY_SAVED',len(catalog),flush=True)
scene.render.filepath=str(OUT/'building_variants.png');bpy.ops.render.render(write_still=True)
