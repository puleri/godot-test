# Rural component library

Open `Rural_Component_Library.blend`. All 28 catalog items are directly editable mesh objects, arranged in a gallery and marked as collection assets.

The kit contains 24 source modules and props: foundation; plain, window and door wall bays; door leaf; farmhouse roof and gable; barn plank wall, door opening and door leaf; barn roof and gable; shed roof and gable; chimney; fence and gate; hay bale; cart; well; trough; wheat and vegetable beds; and orchard tree.

Four assembled examples use these modules: low farmhouse, tall farmhouse, timber barn and farm shed. These examples are joined meshes; use Edit Mode to adjust them, or assemble fresh buildings from the individual kit modules. Doors in the assembled examples are joined too; separate their mesh islands before animation.

Dimensions use meters, Z up, facade toward -Y. Walls and roof bays use a 4 m grid. Farmhouse walls are 3 m tall; barn walls are 4 m tall. Foundations are 0.6 m high. Roof bays meet at their ends without overlapping roof planes. Windows are incorporated into their wall module with an actual wall opening. Materials and bevel modifiers remain editable.

`component_inventory.json` records sizes and gallery positions. `validation.json` checks geometry and actual Edit Mode entry. `rural_components.png` shows the catalog.

The populated world is `../HubCityMaster/Hub_City_World_Farms.blend`: six farmsteads with yards, grain and vegetable plots, orchards, fenced paddocks and access lanes. The farms are grouped individually beneath collection 17. Local terrain is graded around the yards. Farm placements inherit the existing world transform, including its current 3.3517× scale; source kit dimensions remain in native meters. Displaced backdrop trees are retained in hidden collection 18. The earlier world scene remains available.

These are initial modeling assets for further polish. Fine textures, lightmap UV2s, collision, runtime batching, LODs and final lighting bakes are not included. Save edited copies before rerunning the generators, which overwrite their generated outputs.
