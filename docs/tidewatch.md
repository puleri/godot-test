# Tidewatch

Tidewatch is a playable 2.5D Rook level set at a harbor floodgate. Open
`res://Levels/Tidewatch.tscn` in Godot and use **Run Current Scene** (F6), or
launch it directly from the project directory.

```sh
godot --path . res://Levels/Tidewatch.tscn
```

## Walkthrough

1. Walk right from the service dock and keep pressing **D** into the first
   shutter. Rook plants his feet and leans while the camera looks ahead.
   Release movement to end the peek and let the shutter settle, or keep
   pressing to lift it and walk through in one motion.
2. Click the first amber lamp or press **F** to fire at the nearest clear lamp
   in front of Rook. The shot needs a clear path and has a limited range.
   Jump onto the low step, move to its right edge, then jump onto the
   inspection catwalk. If the far lamp is still on, take it out before
   crossing. Drop down after the catwalk and continue to the pump house.
3. Lean into the second shutter. From the doorway, shoot the recessed pump
   house lamp. Wait until the Hound moves toward the back wall to inspect the
   glass. Hold **Shift** to walk quietly past it along the foreground lane.
   Rook is still recognizable at close range, even in darkness.
4. Jump right onto the raised winch deck. The final lamp can be shot if it
   is still on. Stand by the brass wheel and press **E** to lift the gate.
   Pass through it and keep right to finish at the east quay. **R** restarts
   the scene from either result screen or during play.

## Reference and adaptation

| Evidence | What it establishes |
| --- | --- |
| Installed `Contents/Resources/data/campaigns.lua` and `data-pc/bootstrap/localization/english.str` | The default campaign starts at `0-1`. The English localization contains the title **Ink & Dreams**. |
| Installed `data-pc/levels/0_1_tutorialtest/0_1_tutorialtest.lua` | The level declares hiding, grappling, light, and dart tutorials. Its scripted flow includes hostage rescue and named checkpoints for saving Azai. The file is readable as text. |
| Installed `data/movies/World0/0-1_` clips and `data-pc/levels/0_1_tutorialtest/` | The bundle contains intro, mid-level, and outro movies alongside compiled level files and packaged data. These files establish what shipped. The executable is an i386 Mach-O, so the reference evidence here is static. |
| [Klei's game description](https://support.klei.com/hc/en-us/articles/360029879991-MOTN-Classic-What-is-Mark-of-the-Ninja) and the [lead designer's interview on 2D stealth](https://www.destructoid.com/interview-defining-2d-stealth-in-mark-of-the-ninja/) | The original uses bamboo darts to break lights and makes sound from a break visible to the player. |
| [Earlier REA study](mark-of-the-ninja-study.md) | The stored artifact inventory supports the installation identification. The research also records the shipped peek states and lighting-dependent perception. REA's inventory does not establish a runtime route or exact peek behavior. |

Tidewatch uses an original floor plan, two Hound patrols, a service catwalk,
and a winch escape. The shutter and Rook's lean timing are designed for this
scene. The slingshot borrows the role of the bamboo dart. Each lamp's physical
light also feeds the existing exposure sensor, so a break changes what guards
can see and makes a sound at the lamp's location. Tidewatch uses Rook's normal
jump for the vertical route and the existing layered Hound senses for patrol,
suspicion, investigation, and pursuit.

## Verification

```sh
godot --headless --fixed-fps 60 --script res://tests/test_tidewatch.gd
```

The route test drives movement, jumps, leaning, keyboard and mouse firing, the
winch, and restart through Godot input. It also checks shutter occlusion,
shared movement speeds, investigation routing, capture, and the escape state.
