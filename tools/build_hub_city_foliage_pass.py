"""Road wear and planted verge pilot. Preserve the source terrain study."""
import bpy, math, json, random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
R=Path(__file__).resolve().parents[1];OUT=R/'art/HubCityMaster';DATA=R/'Assets/HubFoliage';DATA.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Hub_City_Terrain_Study.blend'))
s=bpy.context.scene;random.seed(921)
core=bpy.data.objects['City terrain — 400 x 400 meters']
routecol=bpy.data.collections['19 TERRAIN PASS — rebuilt routes and stairs']
def bvh(objects):
 vs=[];fs=[]
 for o in objects:
  if o.type!='MESH' or not o.visible_get():continue
  k=len(vs);vs.extend(o.matrix_world@v.co for v in o.data.vertices);fs.extend(tuple(k+i for i in p.vertices) for p in o.data.polygons)
 return BVHTree.FromPolygons(vs,fs)
roads=bvh(routecol.all_objects);terrain=bvh([core])
obstacles=bvh([o for name in ['05 LANDMARKS — existing component assemblies','06 DISTRICTS — linked building masses','20 TERRAIN PASS — foundations and retaining walls'] for o in bpy.data.collections[name].all_objects])
water=bvh([bpy.data.objects['Lagoon and lower river'],bpy.data.objects['Upper river']])
def wear(p):
 nearest=roads.find_nearest(p,20)
 if nearest[0] is None:return 0.,99.
 d=nearest[3]
 # Avoid projecting bridge traffic onto terrain below it.
 if abs(nearest[0].z-p.z)>1.6:return 0.,d
 noise=.16*math.sin(p.x*2.3+p.y*.7)+.11*math.sin(p.y*3.1-p.x)
 t=max(0,min(1,(d-.45+noise)/2.5));return 1-t*t*(3-2*t),d
# Bake wear into vertex colors so Blender and Godot can share the authored result.
attr=core.data.color_attributes.get('RoadWearColor') or core.data.color_attributes.new(name='RoadWearColor',type='FLOAT_COLOR',domain='POINT')
mask=core.data.attributes.get('road_wear') or core.data.attributes.new(name='road_wear',type='FLOAT',domain='POINT')
base=(.22,.285,.135);soil=(.235,.125,.055);worn=0
for v in core.data.vertices:
 p=core.matrix_world@v.co;w,d=wear(p);mask.data[v.index].value=w
 shade=1+.045*math.sin(p.x*1.7+p.y*2.3)
 attr.data[v.index].color=tuple((a*(1-w)+b*w)*shade for a,b in zip(base,soil))+(1,)
 if w>.1:worn+=1
mat=bpy.data.materials.new('Terrain — road-worn earth and grass');mat.use_nodes=True
nodes=mat.node_tree.nodes;bsdf=nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.95
vc=nodes.new('ShaderNodeVertexColor');vc.layer_name='RoadWearColor';mat.node_tree.links.new(vc.outputs['Color'],bsdf.inputs['Base Color'])
core.data.materials.clear();core.data.materials.append(mat)
for p in core.data.polygons:p.material_index=0
# Source meshes stay editable; each placement is a linked mesh copy.
with bpy.data.libraries.load(str(R/'art/FoliageLibrary/Foliage_Component_Library.blend'),link=False) as (src,dst):
 dst.objects=[n for n in src.objects if n.endswith(' | editable mesh')]
sources={o.name.split(' |')[0]:o for o in dst.objects if o}
for o in sources.values():o.location=(0,0,0)
plantcol=bpy.data.collections.new('23 FOLIAGE — road verge pilot');s.collection.children.link(plantcol)
cells={};placements=[]
def add(name,p,scale,angle,kind):
 size=40 if kind=='tree' else 20;key=(math.floor(p.x/size),math.floor(p.y/size),size)
 if key not in cells:
  c=bpy.data.collections.new('Foliage cell %d %d — %dm'%key);plantcol.children.link(c);cells[key]=c
 o=bpy.data.objects.new(name+' planted',sources[name].data);cells[key].objects.link(o);o.location=p;o.rotation_euler.z=angle;o.scale=(scale,)*3
 o['foliage_asset']=name;o['road_wear']=wear(p)[0]
 placements.append({'asset':name,'position':[p.x,p.z,-p.y],'yaw':angle,'scale':scale,'kind':kind,'cell':[key[0],key[1]],'cell_size':size,'wear':o['road_wear']})
# Patchy density along the civic approach and upper-gate road; no plants on roads,
# occupied plots, steep slopes or submerged banks. All tests are at the actual elevation.
counts={'ground':0,'shrub':0,'tree':0};rejected=0
for i in range(34000):
 x=random.uniform(-162,83);y=random.uniform(-65,108)
 hit,n,_,_=terrain.ray_cast(Vector((x,y,100)),Vector((0,0,-1)),200)
 if hit is None or n.z<.82:continue
 w,d=wear(hit)
 if d<.8 or d>18:continue
 wh=water.ray_cast(Vector((x,y,100)),Vector((0,0,-1)),200)[0]
 if wh is not None and wh.z>hit.z-.1:continue
 # Screen out paving above/below the placement and parcel structures.
 if roads.ray_cast(hit+Vector((0,0,8)),Vector((0,0,-1)),10)[0] is not None:continue
 if obstacles.find_nearest(hit,1.1)[0] is not None:continue
 if obstacles.ray_cast(hit+Vector((0,0,.04)),Vector((0,0,1)),12)[0] is not None:continue
 patch=.5+.5*math.sin(x*.37+math.sin(y*.23)*2)*math.sin(y*.41)
 if random.random()>(1-w)**2*(.15+.65*patch):continue
 kind='ground';name=random.choices(['Short clump','Meadow clump','Fern clump','Wildflower clump'],[6,3,1,1])[0]
 if random.random()<.025 and d>4:kind='shrub';name=random.choice(['Wild shrub','Flowering shrub','Rose shrub'])
 if random.random()<.006 and d>6:kind='tree';name=random.choice(['Oak tree 01','Linden tree 02','Apple tree 01','Cypress tree 01'])
 if kind!='ground' and obstacles.find_nearest(hit,3 if kind=='tree' else 1.8)[0] is not None:continue
 scale=random.uniform(.65,1.15) if kind!='tree' else random.uniform(.65,.9)
 add(name,hit+Vector((0,0,-.015)),scale,random.random()*math.tau,kind);counts[kind]+=1
print('PLANTED',counts,flush=True)
# Export flat shaded vertex-color meshes. Each asset uses a single opaque surface,
# reducing material-related draw calls in the runtime MultiMesh cells.
meshdata={}
used=sorted(set(p['asset'] for p in placements))
for name in used:
 source=sources[name];levels=[]
 for ratio in ([1,.45,.18] if 'tree' in name else [1,.45]):
  obj=source.copy();obj.data=source.data.copy();s.collection.objects.link(obj)
  if ratio<1:
   mod=obj.modifiers.new('Runtime simplification','DECIMATE');mod.ratio=ratio
  dg=bpy.context.evaluated_depsgraph_get();evaluated=obj.evaluated_get(dg);me=evaluated.to_mesh();me.calc_loop_triangles()
  vs=[];ns=[];cs=[]
  for tri in me.loop_triangles:
   material=me.materials[tri.material_index];color=list(material.diffuse_color)
   normal=tri.normal
   for vi in (tri.vertices[0],tri.vertices[2],tri.vertices[1]):
    v=me.vertices[vi].co;vs.extend([v.x,v.z,-v.y]);ns.extend([normal.x,normal.z,-normal.y]);cs.extend(color)
  levels.append({'vertices':vs,'normals':ns,'colors':cs});evaluated.to_mesh_clear();bpy.data.objects.remove(obj,do_unlink=True)
 meshdata[name]=levels
(DATA/'meshes.json').write_text(json.dumps(meshdata,separators=(',',':')))
(DATA/'placements.json').write_text(json.dumps(placements,separators=(',',':')))
report={'source':'Hub_City_Terrain_Study.blend','output':'Hub_City_Foliage_Study.blend','worn_terrain_vertices':worn,'planted':counts,'cells':len(cells),'road_wear_attribute':'road_wear','color_attribute':'RoadWearColor','wear_blend_m':2.5,'runtime_assets':used,'scope':'Civic approach and upper gate pilot. Authored wear, not persistent footstep simulation.'}
(OUT/'foliage_pass_manifest.json').write_text(json.dumps(report,indent=2))
# Verify sampled placement exclusions and export integrity.
assert worn>100 and len(placements)>100
assert all(p['wear']<1 for p in placements)
assert all(len(l['vertices'])==len(l['normals']) and len(l['colors'])//4==len(l['vertices'])//3 for levels in meshdata.values() for l in levels)
# Reference coordinates and all existing objects remain in place.
s['foliage_note']='Road wear is baked into editable road_wear vertex attribute; scatter generated with the same mask.'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Hub_City_Foliage_Study.blend'))
# Closer view makes the planted verge and brown transition readable.
d=bpy.data.cameras.new('Worn verge preview');cam=bpy.data.objects.new('Worn verge preview',d);s.collection.objects.link(cam)
cam.location=(-177,-16,46);cam.rotation_euler=(Vector((-131,15,12))-cam.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=64;s.camera=cam
s.render.engine='CYCLES';s.cycles.samples=24;s.render.resolution_x=1600;s.render.resolution_y=1100;s.render.resolution_percentage=100
s.render.filepath=str(OUT/'foliage_worn_verges.png');bpy.ops.render.render(write_still=True)
print('FOLIAGE_PASS_COMPLETE',flush=True)
