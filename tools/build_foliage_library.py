"""Build solid, flat-shaded editable foliage at metre scale; no external textures."""
from pathlib import Path
helper=Path(__file__).with_name('build_hub_town_library.py')
exec(compile(helper.read_text().split('# BUILDING STRUCTURE')[0].replace("R/'art/HubTownLibrary'","R/'art/FoliageLibrary'"),str(helper),'exec'))
scene.name='Stylized foliage component library'
for name,col in [('Bark',(.19,.105,.055)),('BarkLight',(.32,.21,.12)),('OakLeaf',(.19,.32,.075)),('LindenLeaf',(.29,.43,.10)),('CypressLeaf',(.055,.18,.105)),('AppleLeaf',(.16,.32,.10)),('GrassLeaf',(.30,.40,.12)),('ReedLeaf',(.27,.34,.13)),('FlowerPurple',(.43,.20,.61)),('FlowerPink',(.69,.29,.43)),('FlowerCream',(.84,.76,.45)),('Fruit',(.64,.12,.055))]:
 mat(name,col)
 for suffix,f in [('Shade',.78),('Light',1.16)]:mat(name+suffix,tuple(min(.95,c*f) for c in col))

def lump(pos,scale,material):
 # Triangular, irregular facets retain a readable volume at player height.
 bm=bmesh.new();bmesh.ops.create_icosphere(bm,subdivisions=1,radius=1)
 for v in bm.verts:
  f=random.uniform(.87,1.12);v.co=Vector((v.co.x*scale[0]*f,v.co.y*scale[1]*f,v.co.z*scale[2]*f))
 me=bpy.data.meshes.new('faceted crown');bm.to_mesh(me);bm.free()
 ob=bpy.data.objects.new('leaf cluster',me);current.objects.link(ob);pieces.append(ob);ob.location=pos
 for k in [material,material+'Shade',material+'Light']:me.materials.append(M[k])
 for p in me.polygons:p.material_index=random.choices([0,1,2],[7,1,2])[0]
 return ob

def branch(a,b,r,material='Bark'):
 a,b=Vector(a),Vector(b);o=cyl('tapered branch',(a+b)/2,r,(b-a).length,material,7,r*.55);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()

def tree(species,variant):
 random.seed(120+variant+list(['Oak','Linden','Cypress','Apple']).index(species)*20)
 h={'Oak':7.2,'Linden':8,'Cypress':8.5,'Apple':4.2}[species]*(.85+variant*.13)
 leaf=species+'Leaf';r=.24 if species!='Apple' else .15
 branch((0,0,0),(.15,-.08,h*.65),r)
 for i in range(5):
  a=i*math.tau/5;branch((0,0,.2),(.55*math.cos(a),.55*math.sin(a),.035),r*.6)
 if species=='Cypress':
  for i in range(7):
   z=h*(.22+i*.105);w=h*.13*(1-i*.11);lump((.10*math.sin(i),0,z),(w,w*.83,h*.20),leaf)
 else:
  spread=h*(.32 if species=='Oak' else .25)
  for i in range(9):
   a=i*2.399+variant*.5;rad=spread*(.65 if i<6 else .32);z=h*(.52+.055*i)
   end=(rad*math.cos(a),rad*math.sin(a),z)
   branch((.08,0,h*(.30+.025*i)),end,r*.56)
   lump(end,(spread*.70,spread*.60,h*.19),leaf)
   if species=='Apple':
    for j in range(3):lump((end[0]+random.uniform(-.5,.5),end[1]+random.uniform(-.5,.5),z-.45),(.10,.10,.11),'Fruit')

def shrub(kind):
 random.seed(81+len(kind))
 if kind=='hedge':
  for x in [-.75,-.25,.25,.75]:lump((x,0,.63),(.43,.48,.70),'CypressLeaf')
 else:
  for i in range(7):
   a=i*2.4;x=.5*math.cos(a);y=.45*math.sin(a);z=.45+random.random()*.3
   branch((0,0,0),(x,y,z),.035);lump((x,y,z),(.45,.4,.45),'LindenLeaf' if kind=='wild' else 'AppleLeaf')
   if kind in ['flowering','rose']:
    for j in range(3):lump((x+random.uniform(-.25,.25),y+random.uniform(-.2,.2),z+.33),(.09,.09,.075),'FlowerPurple' if kind=='flowering' else 'FlowerPink')

def blade(x,y,h,a,material='GrassLeaf',width=.06):
 dx,dy=math.cos(a),math.sin(a);sx,sy=-dy*width,dx*width
 # Folded diamond cross section, closed tapered blade; no alpha planes.
 mesh('folded grass blade',[(x+sx,y+sy,0),(x-sx,y-sy,0),(x+dx*.035,y+dy*.035,0),(x+sx*.5+dx*h*.12,y+sy*.5+dy*h*.12,h*.55),(x-sx*.5+dx*h*.12,y-sy*.5+dy*h*.12,h*.55),(x+dx*h*.18,y+dy*h*.18,h*.55),(x+dx*h*.35,y+dy*h*.35,h)],[(0,1,2),(0,3,4,1),(1,4,5,2),(2,5,3,0),(3,6,4),(4,6,5),(5,6,3)],material)

def grass(kind):
 random.seed(420+len(kind))
 for i in range(22 if kind!='reeds' else 14):
  x=random.uniform(-.42,.42);y=random.uniform(-.42,.42);a=random.random()*math.tau
  h=random.uniform(.2,.55) if kind=='short' else random.uniform(.55,1.0) if kind=='meadow' else random.uniform(1.0,1.8)
  blade(x,y,h,a,'ReedLeaf' if kind=='reeds' else 'GrassLeaf')
  if kind=='reeds':
   branch((x,y,0),(x,y,h),.017,'ReedLeaf');lump((x,y,h),(.045,.045,.16),'BarkLight')

def fern():
 for i in range(8):
  a=i*math.tau/8
  for j in range(1,7):
   t=j/7;center=Vector((math.cos(a)*t*.7,math.sin(a)*t*.7,math.sin(t*math.pi)*.45+.10))
   for s in [-1,1]:
    p=center+Vector((math.cos(a+s*.9),math.sin(a+s*.9),.1))*(.24*(1-t)+.05)
    lump(p,(.16*(1-t)+.025,.055,.025),'AppleLeaf')

def flowers():
 for i in range(11):
  a=i*2.4;x=.38*math.cos(a);y=.38*math.sin(a);z=.28+random.random()*.25
  branch((x,y,0),(x,y,z),.012,'GrassLeaf');lump((x,y,z),(.075,.075,.045),'FlowerCream')

def vine(kind):
 horizontal=kind in ['ivy horizontal 2m','wisteria canopy 2m'];wisteria='wisteria' in kind
 length=2
 for i in range(13):
  t=i/12*length
  p=(t,math.sin(t*5)*.10,0) if horizontal else (math.sin(t*5)*.10,0,t)
  if i:
   branch(prev,p,.025,'BarkLight')
  prev=p
  for s in [-1,1]:
   pos=(p[0]+(0 if horizontal else s*.18),p[1]+(s*.18 if horizontal else -.04),p[2])
   lump(pos,(.24,.14,.12),'AppleLeaf')
  if wisteria and i%2==0:
   for j in range(5):lump((p[0],p[1]-.07,p[2]-.12-j*.10),(.11-j*.015,.09-j*.01,.10),'FlowerPurple')

for species in ['Oak','Linden','Cypress','Apple']:
 for v in range(3):asset('Trees',f'{species} tree {v+1:02}',lambda s=species,v=v:tree(s,v),'Base pivot; metres; solid flat-shaded crown and modeled branches.')
for label,kind in [('Wild shrub','wild'),('Flowering shrub','flowering'),('Rose shrub','rose'),('Clipped hedge 2m','hedge')]:asset('Shrubs',label,lambda k=kind:shrub(k))
for kind in ['short','meadow','reeds']:asset('Ground plants',kind.title()+' clump',lambda k=kind:grass(k))
asset('Ground plants','Fern clump',fern);asset('Ground plants','Wildflower clump',flowers)
for kind in ['ivy vertical 2m','ivy horizontal 2m','wisteria canopy 2m','wisteria hanging 2m']:asset('Climbers',kind.title(),lambda k=kind:vine(k),'Start-point pivot; 2m main vine; foliage extends beyond endpoints; place slightly clear of wall.')
asset('Planters','Terracotta planted pot',lambda:(vessel('pot',[(.25,0),(.35,0),(.48,.6),(.42,.6),(.30,.09),(.25,.09)]),))
# Fill the pot with a raised flowering bush.
pot=next(iter(assets['Terracotta planted pot'].objects))
s=start('Planters','Window flower box 1.2m')
box('soil',(0,0,.13),(1.1,.30,.20),'Bark')
for y in [-.20,.20]:box('box side',(0,y,.16),(1.2,.06,.32),'Wood')
for x in [-.57,.57]:box('box end',(x,0,.16),(.06,.4,.32),'Wood')
box('box base',(0,0,.025),(1.2,.4,.05),'Wood')
for x in [-.4,0,.4]:lump((x,0,.34),(.26,.24,.19),'AppleLeaf');lump((x,-.03,.51),(.13,.11,.07),'FlowerPurple')
finish(s)
# Add actual foliage to the pot using a fresh assembly, then remove the empty prototype.
old=assets.pop('Terracotta planted pot');catalog[:]=[r for r in catalog if r['name']!='Terracotta planted pot']
for o in list(old.objects):bpy.data.objects.remove(o,do_unlink=True)
bpy.data.collections.remove(old)
def planted_pot():
 vessel('pot',[(.02,0),(.30,0),(.45,.6),(.39,.6),(.24,.08),(.02,.08)])
 lump((0,0,.8),(.50,.45,.42),'AppleLeaf')
 for i in range(7):a=i*2.4;lump((.32*math.cos(a),.30*math.sin(a),1.05),(.09,.09,.07),'FlowerPink')
asset('Planters','Terracotta planted pot',planted_pot)
# Compact organized gallery; retain a zero-height ground pivot per asset.
for i,record in enumerate(catalog):
 ob=next(iter(assets[record['name']].objects));ob.modifiers.clear();ob.location=((i%7)*10,(i//7)*12,0)
 assets[record['name']].instance_offset=ob.location;ob.asset_mark();ob.asset_data.description='Editable solid low-poly foliage. Metric scale; base pivot. '+record['notes']
 record['gallery_position']=list(ob.location);record['triangles']=sum(len(p.vertices)-2 for p in ob.data.polygons)
 ob['wind_hint']='Use local vertex height for wind weight; anchor base.'
# Camera, readable labels, and neutral backdrop are separate from the assets.
current=bpy.data.collections.new('00 Gallery presentation');scene.collection.children.link(current);pieces=[]
for record in catalog:
 x,y,z=record['gallery_position'];d=bpy.data.curves.new('label','FONT');d.body=record['name'];d.size=.48;d.align_x='CENTER';o=bpy.data.objects.new(record['name']+' label',d);current.objects.link(o);o.location=(x,y-3,0.02)
box('gallery floor',(30,22,-.20),(82,66,.30),'StoneLight')
d=bpy.data.cameras.new('Library overview');cam=bpy.data.objects.new('Library overview',d);scene.collection.objects.link(cam);cam.location=(85,-95,105);cam.rotation_euler=(Vector((30,22,2))-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=91;scene.camera=cam
world=bpy.data.worlds.new('Soft studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.38,.45,1);world.node_tree.nodes['Background'].inputs[1].default_value=.6;scene.world=world
ld=bpy.data.lights.new('Sun','SUN');ld.energy=2.5;ob=bpy.data.objects.new('Sun',ld);scene.collection.objects.link(ob);ob.rotation_euler=(.35,-.5,-.4);ld.angle=.15
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=2000;scene.render.resolution_y=1500;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
# Validate saved assets and catalog; no external resources or instances.
errors=[]
for r in catalog:
 ob=next(iter(assets[r['name']].objects))
 if ob.type!='MESH' or not ob.data.vertices:errors.append(r['name'])
 if any(not math.isfinite(c) for v in ob.data.vertices for c in v.co):errors.append(r['name']+' nonfinite')
 if min(v.co.z for v in ob.data.vertices)<-.8:errors.append(r['name']+' unexpected lower bounds')
assert not errors,errors
(OUT/'component_inventory.json').write_text(json.dumps(catalog,indent=2)+'\n')
(OUT/'validation.json').write_text(json.dumps({'assets':len(catalog),'editable_meshes':len(catalog),'errors':errors,'total_triangles':sum(r['triangles'] for r in catalog),'units':'meters','textures':'none; opaque palette materials'},indent=2)+'\n')
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.clip_end=1000
bpy.ops.object.select_all(action='DESELECT');first=next(iter(assets[catalog[0]['name']].objects));first.select_set(True);bpy.context.view_layer.objects.active=first
bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Foliage_Component_Library.blend'))
print('FOLIAGE_SAVED',len(catalog),flush=True)
scene.render.filepath=str(OUT/'foliage_components.png');bpy.ops.render.render(write_still=True)
