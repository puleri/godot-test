# The Last Barrel

Open `Levels/TheLastBarrel.tscn` in Godot and press **F6** for the full level. Open `Levels/TheLastBarrelShip.tscn` and press **F6** to begin aboard the merchant. Both scenes use the same ship and search sequence.

Rook starts above the quay at the closed fish market. Take the fish steps or cart ramp down to the gate. The east seawall has a short stair to the tide landing.

- **WASD / left stick** moves Rook. **Shift / L1** walks quietly.
- **E / Circle** interacts. **Q / Triangle** rings the bell or backs out of a minigame. **R** starts a fresh run.
- At the quarters, pick the lock between the smoking shipmaster’s glances. Ring the quay bell to draw him away. Walk quietly past the tea watch or rattle the kettle, then take the stairs to the writing room. Use the runner near the landing guard and the chart rack for cover.
- At the office lock, sweep left or right until the pick finds contact. Hold **E / Circle** to seat a pin. Backing out keeps the seated pins.
- At the desk, study the signature in the bottom-right corner. In cover, select strokes with **← / →** or the **stick / D-pad**. Use **E / Circle** to ink each stroke and submit the completed signature. **Space / Cross** undoes a stroke.
- After the lighter is loaded, cross to the guards’ courtyard. Wait until the card players leave for tea, climb in their table barrel, and reach the marked hoist spot before the manifest handoff. Pressing interact again climbs out.
- Aboard the merchant, **E / Circle** reads the cargo slate, inspects crate tags, and opens the purser’s strongbox.
- **Space / Cross** reveals each panel of the ending.

## Blender workspace

Open **TheLastBarrel.blend** in Blender 5.2. The viewport opens on the quay. The **Quay opening** and **Merchant cutaway** cameras frame the two halves of the level. The quay, office, cargo, cast, and gameplay markers have their own collections. Expand **03 · Outbound merchant** in the Outliner to edit the hull, freight deck, lower hold, stern passages, or purser’s cabin. The crate and strongbox lids retain their hinge pivots. The scene uses metres and matches the saved Godot layout.

Open Blender’s Text Editor and read **START HERE**. To export additions, place meshes and their required parents in **NEW OBJECTS**, then run **EXPORT NEW OBJECTS.py**. It writes an origin-aligned GLB into `Mesh/TheLastBarrel/` and versions subsequent exports. Instantiate the GLB in Godot at the level origin, with zero rotation and unit scale. Godot owns collision, navigation, and gameplay.

**Shipmaster.blend** holds the separate rigged crow variant. The peaked cap, longer coat, and brass fastenings are editable uniform pieces.

## Rebuild and verification

```sh
godot --headless --path . --script tools/build_last_barrel.gd
godot --headless --path . --script tools/export_last_barrel_workspace.gd -- /tmp/rook-last-barrel-workspace
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python tools/build_last_barrel_workspace.py -- /tmp/rook-last-barrel-workspace
godot --headless --path . --fixed-fps 60 --script tests/test_last_barrel.gd
```

Preserve hand edits before rebuilding the saved Godot or Blender layouts.
