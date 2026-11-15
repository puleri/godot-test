"""Export the eleven native library masters for the city without changing Blender sources.
Run with Blender --background --factory-startup --python tools/export_night_city_components.py.
"""
import json
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Mesh/NightCity'
OUT.mkdir(parents=True, exist_ok=True)
records = json.loads((ROOT / 'ComponentLibrary/component_inventory.json').read_text())
for record in records:
    if record.get('native_source') != 'ComponentLibrary/foundation.blend':
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    with bpy.data.libraries.load(str(ROOT / record['native_source']), link=False) as (source, target):
        target.objects = [record['native_object']]
    obj = target.objects[0]
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    pose = obj.evaluated_get(bpy.context.evaluated_depsgraph_get()).matrix_world.copy()
    obj.animation_data_clear()
    obj.matrix_world = pose
    points = [pose @ v.co for v in obj.data.vertices]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    obj.location -= Vector(((low.x + high.x)/2, (low.y + high.y)/2, low.z))
    obj.location *= record['library_scale']
    obj.scale *= record['library_scale']
    obj.name = record['slug']
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT / (record['slug'] + '.glb')), export_format='GLB', use_selection=True, export_animations=False)
    print('CITY_COMPONENT', record['slug'], [(m.name if m else '') for m in obj.data.materials])
