import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parents[1]/'art/HubCityMaster'
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Hub_City_Terrain_Study.blend'));s=bpy.context.scene
s.render.resolution_x=1600;s.render.resolution_y=1100;s.cycles.samples=16
for name,file in [('11 Terrain redesign overview','terrain_study_overview.png'),('12 Civic terrace and upper ascent','terrain_study_civic.png'),('13 Civic pedestrian at 1.8m','terrain_study_pedestrian.png')]:
 s.camera=bpy.data.objects[name];s.render.filepath=str(OUT/file);bpy.ops.render.render(write_still=True)
print('FINAL_TERRAIN_PREVIEWS_COMPLETE',flush=True)
