"""Make master city components directly editable, with independent mesh data."""
import bpy, json, shutil
from pathlib import Path
from collections import Counter
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'art/HubCityMaster'

def geometry_signature():
    bpy.context.view_layer.update()
    graph=bpy.context.evaluated_depsgraph_get()
    result=Counter()
    for item in graph.object_instances:
        ob=item.object
        if ob.type!='MESH':continue
        corners=[item.matrix_world @ Vector(c) for c in ob.bound_box]
        bounds=tuple(round(v,4) for axis in range(3) for v in (min(p[axis] for p in corners),max(p[axis] for p in corners)))
        result[(len(ob.data.vertices),len(ob.data.polygons),bounds)]+=1
    return result

def make_editable(report_path=None):
    if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
    before=geometry_signature()
    realized=0
    for depth in range(20):
        instances=[o for o in bpy.context.scene.objects if o.instance_type=='COLLECTION' and o.instance_collection]
        if not instances:break
        bpy.ops.object.select_all(action='DESELECT')
        for ob in instances:ob.hide_select=False;ob.select_set(True)
        bpy.context.view_layer.objects.active=instances[0]
        bpy.ops.object.duplicates_make_real(use_base_parent=True,use_hierarchy=True)
        for ob in instances:
            ob.instance_type='NONE';ob.instance_collection=None
            ob['assembly_container']=True
        realized+=len(instances)
    else:raise RuntimeError('Nested instances remain')
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for ob in meshes:
        if ob.data.users>1:ob.data=ob.data.copy()
        ob.hide_select=False;ob.data.name=ob.name+' mesh'
    after=geometry_signature()
    missing=list((before-after).elements());added=list((after-before).elements())
    max_delta=0.0
    for original in missing:
        matches=[(max(abs(a-b) for a,b in zip(original[2],candidate[2])),i) for i,candidate in enumerate(added) if original[:2]==candidate[:2]]
        assert matches, 'Missing geometry topology after conversion'
        delta,index=min(matches)
        assert delta<=.001, f'World geometry moved by {delta} meters'
        max_delta=max(max_delta,delta);added.pop(index)
    assert not added, 'Unexpected additional geometry' 
    # Enter Edit Mode on every visible mesh together, including all realized buildings.
    bpy.ops.object.select_all(action='DESELECT')
    editable=[o for o in meshes if o.visible_get()]
    for ob in editable:ob.select_set(True)
    bpy.context.view_layer.objects.active=editable[0]
    bpy.ops.object.mode_set(mode='EDIT')
    failures=[o.name for o in editable if o.mode!='EDIT']
    assert not failures, failures
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT')
    focus=next((o for o in meshes if o.name.startswith('Simple pitched roof')),editable[0])
    focus.select_set(True);bpy.context.view_layer.objects.active=focus
    report={'realized_assemblies':realized,'directly_editable_mesh_objects':len(meshes),'edit_mode_verified_objects':len(editable),'remaining_collection_instances':sum(o.instance_type=='COLLECTION' for o in bpy.context.scene.objects),'shared_scene_meshes':sum(o.data.users>1 for o in meshes),'world_geometry_unchanged':True,'max_bounds_rounding_difference_m':max_delta,'errors':[]}
    (report_path or OUT/'editability_validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print('EDITABILITY_VALIDATION',json.dumps(report),flush=True)
    return report

if __name__=='__main__':
    master=OUT/'Hub_City_Master_Blockout.blend'
    backup=OUT/'Hub_City_Master_Instanced_Backup.blend'
    if not backup.exists():shutil.copy2(master,backup)
    bpy.ops.wm.open_mainfile(filepath=str(master))
    make_editable()
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(master))
