# Stealth Systems Lab

Open `Levels/StealthSystemsLab.tscn` in Godot and press **F6**. This playable
showcase adapts the sound, guard coordination and incident-search ideas from our
[Mark of the Ninja study](mark-of-the-ninja-study.md) to Rook's existing systems.
It uses our harbor room, connector, wall, barrel, bell and character assets, with
Demo_A2's white spotlights and lightning cycle.

## Walkthrough

1. **Sound through doors — press 1.** From the blue pad, press **E** to emit a
   12-metre sound pulse. The doorway listener hears a roughly 10.2-metre route
   around the partition. The sealed control hears nothing. Press **G** to close
   the door and **E** again to compare. These two stationary listeners isolate
   hearing; they do not detect or chase Rook.
2. **Divide the watch — press 2.** Press **E** from the blue pad. The nearest
   eligible Hound investigates while the other holds its exit. The sentry first
   turns toward the sound for 1.2 seconds, then walks a short watch route
   between points 1.2 metres either side of its home post. It pauses for one
   second at each end to sweep its body, vision and lamp across the exit. Stay
   behind the partition to
   watch. Both still respond to seeing Rook; an active pursuit takes priority
   over a distraction. Press **H** to mark the investigator unavailable: its
   lamp turns off, and the sentry takes over the remembered sound location.
   A sentry reacting to a sighting defers this handoff. On normal completion,
   the sentry returns to normal duty when the investigator reaches its post.
   To test later sounds, wait three seconds and press **E** again: the sentry
   glances toward the source, then resumes its watch patrol automatically. Move
   across the south side of the bay and walk normally within hearing range of
   the sentry: audible footsteps at a separate location can start its own
   investigation, without **E**. Quiet steps have a shorter hearing radius.
3. **Set the trap — press 3.** Press **F** to place a chime at Rook's feet.
   Hold **Shift** and move quietly around the west end of the partition into
   cover on its north side. Press **Q** to trigger the chime remotely. The Hound
   approaches the sound's location, visits nearby reachable search points, then
   returns home. The armed preview does not alert guards. A chime activates once;
   after the cooldown, place another to repeat.

Walk through the connectors to activate each bay, or use **1 / 2 / 3** to jump
there and reset its actors. Progress badges persist between bay resets. Getting
caught locks movement; reset the bay to try again.

## Controls and feedback

| Control | Action |
| --- | --- |
| WASD / Shift / Space | Move / move quietly / jump |
| 1 / 2 / 3 | Select and reset a bay |
| E | Emit a test sound pulse |
| G | Toggle the first bay's door |
| H | Disable the current investigator in bay 2 to demonstrate takeover |
| F / Q | Place / remotely activate a chime in bay 3 |
| Tab | Toggle guard sight overlays |
| M | Toggle the overview camera |
| L | Hold lightning illumination for inspection; press again to resume the storm |
| R | Reload the scene and clear progress |

The expanding circle shows the sound's **maximum reach** and can pass through
walls. Cyan paths show the routes to listeners that actually heard it. Labels
and the receipt readout distinguish heard, sealed and out-of-range results.
The held inspection light also affects Rook's real exposure and detection; use
normal storm mode when testing darkness and lightning timing.

## Implementation and limits

The lab is isolated from existing levels. Its guard and player scripts extend
our reusable controllers; it retains normal vision, pursuit, capture and exposure
in the second and third bays. Each of those guards has a single home post so the
coordination and investigation are easy to observe.

The sentry's glance, watch patrol and exit sweep are our own readability treatment. The
reference behavior definitions establish waiting and takeover after an
investigator dies; they do not establish this exact scanning animation or
timing. **H** is a lab simulation of an unavailable partner, not a combat or
takedown system. Resetting bay 2 restores both guards and their lamps.

In bay 2, sounds less than four metres from an assigned investigation are
treated as the same incident. They do not reset its search or move its target.
A separate pulse, footstep, chime or landing can assign the nearest available listener;
an investigator already busy with another incident is not redirected. Both
guards can therefore investigate separate incidents and finish independently.
Footsteps use the same assignment rules as other sounds. Nearby repeated steps
merge into an existing incident; steps at a separate location can draw an
available sentry. Busy investigators keep their targets, so successive steps
do not continuously redirect them.

A sentry on its watch route still hears later events. It glances again when its three-second
cooldown expires, or immediately if the new source is more than two metres from
its previous glance location. Inaudible sounds do not change its facing or
memory. Glances preserve the original incident it covers for partner takeover.
Visual suspicion and confirmed pursuit take priority over these sound reactions.
Once a guard enters search or pursuit, it recognizes a visible Rook at 30% of
its normal detection time (0.45 seconds rather than 1.5 seconds at full
recognition strength in this scene). That heightened response survives the
brief suspicious state and return journey, and clears on patrol or a bay reset.
Darkness and walls retain their normal protection.
These distance and timing rules are our prototype choices, not reconstructed
Mark of the Ninja interest-classification rules.

`lab_acoustics.gd` finds the shortest clear route through authored waypoints,
using physics rays at a fixed height. Distance along that route consumes the
sound's radius. This is a 2.5D prototype, without material absorption, vertical
sound propagation or physical diffraction. The door changes hearing collision
immediately; navigation is baked with the door open. Only stationary listeners
use that bay, so no moving guard relies on crossing a subsequently closed door.

The chime is placed, rather than thrown. It tests remote timing and a search
around a fixed incident. Footsteps during an existing search do not continuously
retarget the investigator; a new chime can supply a new incident. The search
uses up to three reachable points and a time limit, not a complete room sweep.
No Mark of the Ninja code or assets are included.

## Rebuild and verification

From the project directory:

```sh
godot --headless --path . --script tools/build_stealth_systems_lab.gd
godot --headless --path . --fixed-fps 60 --script tests/test_stealth_systems_lab.gd
godot --headless --path . --fixed-fps 60 --script tests/test_midnight_exchange.gd
```

The builder overwrites only `Levels/StealthSystemsLab.tscn`; edit the builder to
retain layout changes across rebuilds. The lab has 61 integration checks for
sound routes, the door, coordination, search movement, chime lifecycle, capture,
reset and camera setup, including sentry turning, lamp alignment, takeover
movement, repeated audio, independent incidents, autonomous watch-route
reversals, actual player footstep signals and pursuit priority. All 49
existing Midnight Exchange checks also passed.
Real Metal-renderer captures verify the layout, lighting and labels. The reused
storm can report resource/ObjectDB cleanup warnings when a test scene exits.

For repeatable captures without changing the saved scene:

```sh
godot --path . --windowed --resolution 1440x900 --audio-driver Dummy \
  --script tools/preview_stealth_systems_lab.gd
```

Images are written to `/private/tmp/systems-lab-{door,overview,team,chime}.png`.
Additional `sentry-glance`, `sentry-scan` and `takeover` views show the squad duty
transitions.
