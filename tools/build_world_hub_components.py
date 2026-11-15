"""Consolidate latest saved hub and its modular kits into an editable Blender library.
Run with Blender --background --factory-startup --python-exit-code 1 --python this_file.
Writes only art/WorldHubComponents; never saves over the source world or source kits.
"""
import bpy, json, math, re, uuid
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'art/WorldHubComponents'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'art/HubCityMaster/Hub_City_Terrain_Study.blend'
TARGET = OUT / 'World_Hub_Components.blend'
if TARGET.exists():
    raise RuntimeError('Output exists. Rename it before regenerating to protect manual restyling.')
bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
world = bpy.context.scene
world.name = '08 Latest Hub — editable reference'
source_collections = list(bpy.data.collections)
embedded = [c for c in source_collections if c.asset_data or c.use_fake_user]
manifest = {'source_world': str(SOURCE.relative_to(ROOT)), 'source_modified_ns': SOURCE.stat().st_mtime_ns,
            'units': 'metres', 'components': [], 'scenes': [], 'catalogs': {}}

# Every placed object remains at its original position in the reference scene.
# Make material palettes independent per assembly; parts within one assembly share its palette.
palettes = {}
for ob in world.objects:
    ob.hide_select = False
    ob.lock_location = (False,) * 3
    ob.lock_rotation = (False,) * 3
    ob.lock_scale = (False,) * 3
    if ob.data and ob.type in {'MESH', 'CURVE', 'FONT', 'LIGHT', 'CAMERA'}:
        ob.data = ob.data.copy()
    if ob.type not in {'MESH', 'CURVE', 'FONT'}:
        continue
    root = ob
    while root.parent:
        root = root.parent
    palette = palettes.setdefault(root.name, {})
    for slot in ob.material_slots:
        mat = slot.material
        if mat:
            if mat not in palette:
                palette[mat] = mat.copy()
                palette[mat].name = root.name + ' / ' + mat.name
            slot.material = palette[mat]

print('REFERENCE_READY', len(world.objects), flush=True)
catalogs = {}
def catalog(name):
    if name not in catalogs:
        catalogs[name] = str(uuid.uuid5(uuid.NAMESPACE_URL, 'rook/world-hub-components/' + name))
    return catalogs[name]

def scene(name):
    sc = bpy.data.scenes.new(name)
    sc.unit_settings.system = 'METRIC'
    sc.unit_settings.scale_length = 1
    sc.unit_settings.length_unit = 'METERS'
    sc.world = bpy.data.worlds.new(name + ' World')
    sc.world.color = (.18, .18, .18)
    sc.render.engine = 'BLENDER_EEVEE'
    sc.render.resolution_x = 1800
    sc.render.resolution_y = 1200
    sc.render.resolution_percentage = 100
    manifest['scenes'].append(name)
    return sc

# Detached appended collections have unevaluated matrix_world caches. Resolve their actual
# object hierarchy from local transform channels, including inverse parent matrices.
def object_matrix(ob):
    if ob.parent:
        return object_matrix(ob.parent) @ ob.matrix_parent_inverse @ ob.matrix_basis
    return ob.matrix_basis.copy()

# Flatten collection instances into directly selectable geometry, while retaining editable modifiers.
def pieces(col, transform=None, ancestry=()):
    if col in ancestry:
        raise RuntimeError('Recursive collection: ' + col.name)
    transform = transform if transform is not None else Matrix.Identity(4)
    transform = transform @ Matrix.Translation(-col.instance_offset)
    for ob in col.all_objects:
        mat = transform @ object_matrix(ob)
        if ob.instance_type == 'COLLECTION' and ob.instance_collection:
            yield from pieces(ob.instance_collection, mat, ancestry + (col,))
        elif ob.type in {'MESH', 'CURVE', 'FONT', 'LIGHT'}:
            yield ob, mat

used = scene('01 Used in Latest Hub')
scenes = [used]
layouts = {}
all_gallery_objects = []
labelmat = bpy.data.materials.new('Gallery captions')
labelmat.diffuse_color = (.80, .84, .90, 1)
labelmat.use_nodes = True
labelmat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (.80, .84, .90, 1)

def add_component(sc, name, category, source_pieces, source_file, notes=''):
    source_pieces = list(source_pieces)
    if not any(ob.type == 'MESH' for ob, _ in source_pieces):
        return
    index = len([r for r in manifest['components'] if r['scene'] == sc.name]) + 1
    col = bpy.data.collections.new(f'{sc.name[:2]} {index:03d} | {name}')
    sc.collection.children.link(col)
    col.asset_mark()
    col.asset_data.catalog_id = catalog(category)
    col.asset_data.description = notes or 'Editable real geometry and independent component material palette. Metres, Z up.'
    anchor = bpy.data.objects.new(name + ' — move whole component', None)
    anchor.empty_display_type = 'PLAIN_AXES'
    anchor.empty_display_size = .3
    anchor['component'] = name
    anchor['source'] = source_file
    anchor['editing'] = 'Select a mesh child and press Tab. Materials are independent of other components.'
    col.objects.link(anchor)
    clones = []
    palette = {}
    mapping = {}
    for ob, transform in source_pieces:
        clone = ob.copy()
        clone.name = name + ' | ' + ob.name
        clone.parent = None
        clone.data = ob.data.copy()
        clone.hide_viewport = False
        clone.hide_render = False
        clone.hide_select = False
        clone.lock_location = clone.lock_rotation = clone.lock_scale = (False,) * 3
        col.objects.link(clone)
        clone.parent = anchor
        clone.matrix_parent_inverse = Matrix.Identity(4)
        clone.matrix_basis = transform
        clone['source_object'] = ob.name
        for slot in clone.material_slots:
            mat = slot.material
            if mat:
                if mat not in palette:
                    palette[mat] = mat.copy()
                    palette[mat].name = f'{sc.name[:2]}.{index:03d} {name} / {mat.name}'
                slot.material = palette[mat]
        clones.append(clone)
        mapping[ob] = clone
    # Remap modifier/constraint targets when they are part of the same component.
    for clone in clones:
        for owner in list(clone.modifiers) + list(clone.constraints):
            for prop in owner.bl_rna.properties:
                if prop.type == 'POINTER' and not prop.is_readonly:
                    try:
                        value = getattr(owner, prop.identifier)
                        if isinstance(value, bpy.types.Object) and value in mapping:
                            setattr(owner, prop.identifier, mapping[value])
                    except (AttributeError, TypeError):
                        pass
    corners = [transform @ Vector(corner) for ob, transform in source_pieces if ob.type == 'MESH' for corner in ob.bound_box]
    lo = Vector(tuple(min(p[i] for p in corners) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in corners) for i in range(3)))
    width, depth = hi.x - lo.x, hi.y - lo.y
    layout = layouts.setdefault(sc.name, {'x': 0., 'y': 0., 'row_depth': 0., 'bounds': []})
    if layout['x'] and layout['x'] + width + 6 > 170:
        layout['x'] = 0.
        layout['y'] += layout['row_depth'] + 8
        layout['row_depth'] = 0.
    x, y = layout['x'], layout['y']
    anchor.location = (x - lo.x, y - lo.y, -lo.z)
    col.instance_offset = Vector((x+width/2, y+depth/2, 0)) if notes.startswith('Representative') else anchor.location.copy()
    layout['x'] += max(width, min(23, len(name) * .28)) + 6
    layout['row_depth'] = max(layout['row_depth'], depth)
    layout['bounds'].append((x, y, width, depth, hi.z-lo.z))
    label = bpy.data.curves.new(name + ' caption', 'FONT')
    label.body = f'{index:03d}  {name}'
    label.size = .40
    label.materials.append(labelmat)
    text = bpy.data.objects.new(name + ' caption', label)
    sc.collection.objects.link(text)
    text.location = (x, y - 1.4, .02)
    manifest['components'].append({'name': name, 'scene': sc.name, 'collection': col.name,
        'category': category, 'source': source_file, 'mesh_parts': sum(o.type == 'MESH' for o in clones),
        'material_count': len(palette), 'gallery_position': list(anchor.location),
        'dimensions_m': list(hi-lo), 'notes': notes})
    all_gallery_objects.extend(clones)

# Start with every embedded source asset used by the world, including mass prototypes.
for col in sorted(embedded, key=lambda c: c.name):
    add_component(used, col.name, '01 Used in Latest Hub', pieces(col), str(SOURCE.relative_to(ROOT)))

# World-specific mesh families, including the current route and terrain pass, have no kit source.
# Keep one exact representative per named family here; every placed variant remains in the reference scene.
seen = set()
for col in list(world.collection.children):
    if col.name.startswith(('05 ', '06 ', '07 ', '09 ', '10 ', '16 ', '17 ', '18 ', '22 ')):
        continue
    for ob in col.objects:
        if ob.type != 'MESH' or ob.parent:
            continue
        name = re.sub(r'\.\d{3}$', '', ob.name)
        if name in seen:
            continue
        seen.add(name)
        if max(ob.dimensions) > 175:
            # Full-size terrain and water stay together in a dedicated, directly editable reference scene.
            continue
        add_component(used, name, '01 Used in Latest Hub', [(ob, ob.matrix_world.copy())], str(SOURCE.relative_to(ROOT)),
                      'Representative world-authored component. All placed variants and full terrain are in scene 08.')

print('USED_GALLERY_READY', len(manifest['components']), flush=True)
kits = [
    ('02 Architecture and Props', 'HubTownLibrary', 'HubTown_Component_Library.blend'),
    ('03 Environment and Fortifications', 'HubTownExpansion', 'HubTown_Environment_Expansion.blend'),
    ('04 Boroughs and Landmarks', 'CityBoroughLibrary', 'City_Boroughs_and_Landmarks.blend'),
    ('05 Residential Streets', 'ResidentialStreetLibrary', 'Residential_Streets_and_Apartments.blend'),
    ('06 Upper City and Waterways', 'UpperCityLibrary', 'Upper_City_Waterways_and_Gardens.blend'),
    ('07 Farms and Countryside', 'RuralLibrary', 'Rural_Component_Library.blend'),
]
for title, folder, filename in kits:
    sc = scene(title)
    scenes.append(sc)
    source = ROOT / 'art' / folder / filename
    inventory = json.loads((source.parent / 'component_inventory.json').read_text())
    records = inventory if isinstance(inventory, list) else inventory['components']
    assemblies = [] if isinstance(inventory, list) else inventory.get('assemblies', [])
    requested = list(dict.fromkeys([r.get('collection', r['name']) for r in records] + [r['name'] for r in assemblies]))
    with bpy.data.libraries.load(str(source), link=False) as (src, dst):
        missing = [name for name in requested if name not in src.collections]
        assert not missing, (filename, missing)
        dst.collections = requested[:]
    for original_name, col in zip(requested, dst.collections):
        rec = next((r for r in records if r.get('collection', r['name']) == original_name), {})
        add_component(sc, original_name, title + '/' + rec.get('kit', 'Complete assemblies'), pieces(col),
                      str(source.relative_to(ROOT)), rec.get('notes', ''))
    print('KIT_COMPLETE', title, len(requested), flush=True)

# Real cameras and useful editing views for each gallery, with a compact used-component scene first.
for sc in scenes:
    bounds = layouts[sc.name]['bounds']
    xmax = max(x+w for x,y,w,d,h in bounds)
    ymax = max(y+d for x,y,w,d,h in bounds)
    center = Vector((xmax/2, ymax/2, 0))
    camdata = bpy.data.cameras.new(sc.name + ' overview')
    cam = bpy.data.objects.new(sc.name + ' overview', camdata)
    sc.collection.objects.link(cam)
    cam.location = center + Vector((0, -max(ymax, xmax)*.6, max(ymax, xmax)))
    cam.rotation_euler = (center - cam.location).to_track_quat('-Z','Y').to_euler()
    camdata.type = 'ORTHO'
    camdata.ortho_scale = max(xmax*1.15, ymax*1.65)
    camdata.clip_end = 10000
    sc.camera = cam
    lightdata = bpy.data.lights.new(sc.name + ' daylight', 'SUN')
    lightdata.energy = 2.5
    light = bpy.data.objects.new(sc.name + ' daylight', lightdata)
    sc.collection.objects.link(light)
    light.rotation_euler = (.4, -.5, -.4)
    sc['editing_guide'] = 'Each collection is one editable component. Select a mesh, Tab to edit. Material palettes are independent per component. Frame Selected: numpad decimal.'

# Validate actual editable geometry, material isolation, and source coverage before saving.
mesh_objects = [o for sc in scenes + [world] for o in sc.objects if o.type == 'MESH']
assert all(o.data.library is None and o.data.users == 1 for o in mesh_objects)
assert not [o.name for sc in scenes + [world] for o in sc.objects if o.instance_type == 'COLLECTION']
assert all(math.isfinite(c) for o in mesh_objects for v in o.data.vertices for c in v.co)
bpy.context.window.scene = used
bpy.context.view_layer.update()
visible_meshes = [o for o in used.objects if o.type == 'MESH']
for o in used.objects:
    o.select_set(False)
for o in visible_meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = visible_meshes[0]
bpy.ops.object.mode_set(mode='EDIT')
assert all(o.mode == 'EDIT' for o in visible_meshes)
bpy.ops.object.mode_set(mode='OBJECT')
for o in used.objects:
    o.select_set(False)
focus = next(o for o in visible_meshes if 'Cream peaked' in o.name)
focus.select_set(True)
bpy.context.view_layer.objects.active = focus
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type == 'VIEW_3D':
            space = area.spaces.active
            space.shading.type = 'MATERIAL'
            space.clip_start = .03
            space.clip_end = 10000
            space.region_3d.view_location = focus.matrix_world.translation
            space.region_3d.view_distance = 32
            space.region_3d.view_rotation = Vector((1,-1,1)).to_track_quat('Z','Y')
            space.region_3d.view_perspective = 'PERSP'

manifest['catalogs'] = catalogs
manifest['component_count'] = len(manifest['components'])
manifest['mesh_count'] = len(mesh_objects)
manifest['reference_scene'] = world.name
manifest['edit_mode_verified_meshes'] = len(visible_meshes)
manifest['remaining_instances'] = 0
manifest['shared_meshes'] = 0
manifest['errors'] = []
readme = '''WORLD HUB — EDITABLE COMPONENTS

Start in scene 01 Used in Latest Hub. Scenes 02–07 contain the complete modular kits.
Scene 08 Latest Hub — editable reference preserves the latest saved terrain study,
including all placed variants, full terrain, water, farms and lighting.

OUTLINER: Each numbered collection is one component. Expand it to select a wall,
roof, window, trim piece, etc. Select a mesh and press Tab for Edit Mode.
Some original kit modules are a single mesh with disconnected parts: hover a part
in Edit Mode and press L to select it; P > Selection separates it into an object.

RESTYLE: Material Properties contains the component's independent material palette.
Changing a component material affects its own parts only. Each mesh has unique data.
Gallery copies and the world reference are independent: edits do not propagate.

MOVE: Select the named 'move whole component' parent empty to move the whole asset.
Numpad decimal frames selection. Shift during transforms enables fine adjustments.
Use Scene dropdown for kits/reference; Asset Browser exposes collection assets.
All geometry is stored locally. Units are metres, Z up. Nothing is a flattened image.

Save your restyled version under a new name. The builder refuses to overwrite this file.
'''
text = bpy.data.texts.new('START HERE — Editing Guide')
text.write(readme)
(OUT / 'README.md').write_text(readme)
(OUT / 'component_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
(OUT / 'blender_assets.cats.txt').write_text('VERSION 1\n\n' + '\n'.join(f'{uid}:{name}:{name.rsplit("/",1)[-1]}' for name,uid in catalogs.items()) + '\n')
# Keep only the consolidated assets visible in Asset Browser; discard unused source IDs.
gallery_names = {r['collection'] for r in manifest['components']}
for col in bpy.data.collections:
    if col.name not in gallery_names:
        if col.asset_data:
            col.asset_clear()
        col.use_fake_user = False
for datablock in list(bpy.data.user_map()):
    if datablock.library:
        datablock.make_local()
bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)
bpy.ops.file.pack_all()
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
print('EDITABLE_LIBRARY_SAVED', json.dumps({k:manifest[k] for k in ['component_count','mesh_count','edit_mode_verified_meshes','remaining_instances','shared_meshes']}), flush=True)
