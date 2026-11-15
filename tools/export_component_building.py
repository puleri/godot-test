"""Refresh this building from foundation.blend; bake unsupported Blender color graphs.
The authoring file is read only. Topology/normals/proportions stay authored;
only an export-copy UV map and PBR material adapters are added.
"""
from pathlib import Path
import hashlib
import json
import math
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'art/ComponentBuilding'
OUT = ROOT / 'Mesh/ComponentBuilding'
SOURCE = ROOT / 'ComponentLibrary/foundation.blend'
records = {r['slug']: r for r in json.loads((ROOT/'ComponentLibrary/component_inventory.json').read_text())}
assembly = json.loads((ART/'assembly.json').read_text())
slugs = sorted({p['component'] for p in assembly['pieces']})
OUT.mkdir(parents=True, exist_ok=True)
(ART/'textures').mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.frame_set(0)
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
scene.render.bake.margin = 8
scene.render.bake.use_clear = True
report = {'source': str(SOURCE.relative_to(ROOT)), 'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(), 'material_conversion': 'Authored base color/procedural graphs baked to sRGB PNG; Toon BSDF adapted to matte PBR; original Principled metallic/roughness retained.', 'components': []}
with bpy.data.libraries.load(str(SOURCE), link=False) as (_, loaded):
    loaded.objects = [records[s]['native_object'] for s in slugs]
prototypes = {}
for slug, obj in zip(slugs, loaded.objects):
    scene.collection.objects.link(obj)
    bpy.context.view_layer.update()
    pose = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
    obj.animation_data_clear()
    obj.matrix_world = pose
    points = [pose @ v.co for v in obj.data.vertices]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    obj.location -= Vector(((low.x+high.x)/2, (low.y+high.y)/2, low.z))
    obj.location *= records[slug]['library_scale']
    obj.scale *= records[slug]['library_scale']
    obj.name = slug
    obj.data = obj.data.copy()
    counts = (len(obj.data.vertices), len(obj.data.polygons))
    material_correction = None
    if slug == 'windowed_stone_wall':
        # The source assigns the broad panel to Stone along with the detail
        # stones. Restore the existing stone_wall material used by its peers,
        # on the export copy only. Identify the connected panel geometrically.
        stone_slot = next(i for i, slot in enumerate(obj.material_slots)
                          if slot.material and slot.material.name == 'Stone')
        by_vertex = {}
        for face in obj.data.polygons:
            if face.material_index == stone_slot:
                for vertex in face.vertices:
                    by_vertex.setdefault(vertex, []).append(face.index)
        seen, islands = set(), []
        for face in obj.data.polygons:
            if face.material_index != stone_slot or face.index in seen:
                continue
            pending, island = [face.index], []
            while pending:
                index = pending.pop()
                if index in seen:
                    continue
                seen.add(index)
                island.append(index)
                for vertex in obj.data.polygons[index].vertices:
                    pending.extend(by_vertex[vertex])
            islands.append(island)
        def width(island):
            xs = [obj.data.vertices[v].co.x for i in island
                  for v in obj.data.polygons[i].vertices]
            return max(xs) - min(xs)
        panel = max(islands, key=width)
        assert len(panel) == 26 and width(panel) > 20, 'Window wall panel changed; inspect assignment'
        original_wall = bpy.data.materials['stone_wall']
        obj.data.materials.append(original_wall)
        panel_slot = len(obj.data.materials) - 1
        for index in panel:
            obj.data.polygons[index].material_index = panel_slot
        assert all(obj.data.polygons[i].material_index == panel_slot for i in panel)
        material_correction = {'from': 'Stone', 'to': original_wall.name,
                               'panel_faces': sorted(panel), 'scope': 'export copy only'}
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for uv in list(obj.data.uv_layers):
        obj.data.uv_layers.remove(uv)
    obj.data.uv_layers.new(name='GodotAuthoredColor')
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.025)
    bpy.ops.object.mode_set(mode='OBJECT')
    image = bpy.data.images.new(slug+'_authored_color',width=1024,height=1024,alpha=False)
    image.colorspace_settings.name = 'sRGB'
    source_materials = []
    for slot in obj.material_slots:
        original = slot.material
        if original is None:
            original = bpy.data.materials.new('Unassigned_Blender_Default')
            original.use_nodes = True
        mat = original.copy()
        slot.material = mat
        mat.use_nodes = True
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        output = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL' and n.is_active_output)
        surface = output.inputs['Surface']
        shader = surface.links[0].from_node if surface.is_linked else None
        color = shader.inputs.get('Color') if shader and shader.type == 'BSDF_TOON' else shader.inputs.get('Base Color') if shader else None
        if shader and shader.type not in {'BSDF_TOON','BSDF_PRINCIPLED'}:
            raise RuntimeError('Unsupported authored shader: '+shader.type)
        roughness = float(shader.inputs['Roughness'].default_value) if shader and shader.type == 'BSDF_PRINCIPLED' else 1.0
        metallic = float(shader.inputs['Metallic'].default_value) if shader and shader.type == 'BSDF_PRINCIPLED' else 0.0
        source_materials.append((original.name, roughness, metallic, shader.type if shader else 'DEFAULT'))
        emit = nodes.new('ShaderNodeEmission')
        if color and color.is_linked:
            links.new(color.links[0].from_socket,emit.inputs['Color'])
        else:
            emit.inputs['Color'].default_value = color.default_value if color else original.diffuse_color
        links.new(emit.outputs[0],surface)
        target = nodes.new('ShaderNodeTexImage')
        target.image = image
        nodes.active = target
        target.select = True
    bpy.ops.object.bake(type='EMIT')
    image.filepath_raw = str(ART/'textures'/(slug+'_basecolor.png'))
    image.file_format = 'PNG'
    image.save()
    converted = []
    for name, roughness, metallic, shader_type in source_materials:
        material = bpy.data.materials.new(name+'_Authored')
        material.use_nodes = True
        material.use_backface_culling = False
        nodes = material.node_tree.nodes
        principled = nodes.get('Principled BSDF')
        principled.inputs['Roughness'].default_value = roughness
        principled.inputs['Metallic'].default_value = metallic
        if shader_type == 'BSDF_TOON':
            principled.inputs['Specular IOR Level'].default_value = 0.0
        texture = nodes.new('ShaderNodeTexImage')
        texture.image = image
        material.node_tree.links.new(texture.outputs['Color'],principled.inputs['Base Color'])
        converted.append(material)
    for slot, material in zip(obj.material_slots,converted):
        slot.material = material
    assert counts == (len(obj.data.vertices),len(obj.data.polygons)), 'Export changed geometry'
    bpy.ops.export_scene.gltf(filepath=str(OUT/(slug+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_normals=True,export_materials='EXPORT')
    prototypes[slug] = obj
    report['components'].append({'slug':slug,'vertices':counts[0],'polygons':counts[1],'material_correction':material_correction,'materials':[{'source':a,'roughness':b,'metallic':c,'shader':d} for a,b,c,d in source_materials]})
# Save a matching Blender reference with the actual Godot export-copy materials.
collection = bpy.data.collections.new('Building - same geometry and materials as Godot')
scene.collection.children.link(collection)
for part in assembly['pieces']:
    prototype = prototypes[part['component']]
    obj = prototype.copy()
    obj.name = part['name'].replace('/',' - ')
    collection.objects.link(obj)
    x,y,z = part['position']
    obj.matrix_world = Matrix.Translation((x,-z,y)) @ Matrix.Rotation(part['yaw'],4,'Z') @ prototype.matrix_world
for obj in prototypes.values():
    bpy.data.objects.remove(obj,do_unlink=True)
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.shading.type = 'MATERIAL'
            area.spaces.active.region_3d.view_location = Vector((0,0,6))
            area.spaces.active.region_3d.view_distance = 62
            area.spaces.active.region_3d.view_rotation = Vector((42,-48,29)).to_track_quat('Z','Y')
scene.unit_settings.system = 'METRIC'
bpy.ops.object.select_all(action='DESELECT')
for image in bpy.data.images:
    if image.name.endswith('_authored_color'):
        image.pack()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'ComponentBuilding_GodotReference.blend'))
(ART/'godot_export.json').write_text(json.dumps(report,indent=2)+'\n')
print('COMPONENT_BUILDING_REFRESHED',len(prototypes),'source components; geometry unchanged')
