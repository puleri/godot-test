# Mark of the Ninja: findings for Rook

Inspected November 3, 2026. The most useful additions for Rook are **visible,
predictable sound effects, hearing that respects routes around walls, and guards
that divide investigation duties**. We already have footsteps, landing noise,
bells, exposure sensing and last-known-position searches; this study identifies
ways to make those systems more legible and less repetitive.

This is a static investigation of the user's downloaded installation. No game
files were changed, no game scripts were executed, and no gameplay changes were
made to Rook. Findings below distinguish shipped definitions, native code
observations and proposed adaptations.

## Installation and evidence

- Steam application **214560**, original **Mark of the Ninja**, build **5908116**.
- Installation: `/Users/mattpuleri/Library/Application Support/Steam/steamapps/common/mark_of_the_ninja/ninja.app`.
- Executable: `Contents/MacOS/ninja`, 8,812,288 bytes, **32-bit i386 Mach-O**.
- Executable SHA-256: `443cac4d542bc65fdb72d10f8b622637125f81bc74d9fc43e5ecd7a0f79a14fe`.
- File inventory found **858 Lua files**, totaling 43,893,047 bytes. This is an
  inventory count, not a claim that every script was analyzed.
- Focused inspection parsed **nine** shipped Lua files as literals and inspected
  **five** selected native functions using retained symbols and Apple LLVM tools.
- Machine-readable findings, source SHA-256 values, JSON pointers, UTF-8 byte
  offsets, native addresses and call targets:
  [research/mark-of-the-ninja-evidence.json](research/mark-of-the-ninja-evidence.json).

REA 6.7.0 supplied a static artifact inventory through `inspect-artifact`. Its
authority is `shipped-artifact`; its own limitations explicitly exclude claims
of runtime behavior or format-specific semantics. The source-table and native
findings here came from the additional local inspection, not from a REA
decompiler. Raw REA output is `/private/tmp/mark-ninja-rea-artifact.json`; a compact
record of its provenance, report hash and coverage is retained in the JSON above.
The temporary CLI completed despite an npm warning that the host's Node 25.5.0
is outside this REA release's declared supported Node versions.

The installed original executable cannot run on this modern macOS installation:
Apple discontinued 32-bit app support with macOS Catalina. Static inspection of
its data and executable still works. No playtest or runtime measurements are
claimed. [Apple compatibility documentation](https://support.apple.com/en-us/103076).

All paths below are relative to `Contents/Resources`, except native executable
addresses. Debug filenames embedded in the shipped Lua identify original source
locations; they do not imply those original development files are installed.

## 1. Sound is a gameplay stimulus with a matching presentation

**Verified definitions.** `data/stategraphs/ninja.lua` includes common actions
that create both an `addinterestsource` with `sense=sound` and a sound-ring FX.
Examples, retaining the original game's units:

| Common action | Stimulus radius | Ring radius | Stimulus TTL |
| --- | ---: | ---: | ---: |
| `run_normal_noise` | 1088 | 1088 | approximately 0.1333 |
| `walk_normal_noise` | 384 | 384 | 0.5 |
| `noisemaker_noise` | 640 | 704 | 1 |

The emitted interests also declare source, priority, maximum distance, whether
they follow their owner and whether a lost target should be forgotten. The
noisemaker stimulus has source `noisemaker`, priority 4 and `followowner=false`.
These are definitions; movement dispatch and actual event frequency were not
fully traced. In particular, stimulus TTL is not the guard's search duration.

**Rook adaptation.** Have the same noise event drive hearing and a short visual
pulse, with feedback on guards that actually heard it. Preview a throwable's
effect before committing. Derive the display from the real hearing rules rather
than treating any decorative circle as an exact guarantee. The noisemaker's
640-versus-704 difference is a reason to account for listener sensitivity too.

Rook's `exchange_player.gd` already emits footsteps and landing events, and
`night_city.gd::_on_noise()` forwards them to guards. Build on that pipeline.

## 2. Hearing has a direct test and an optional path around obstacles

**Native observation.** `AI::cSensoryModel::CanHearSound` at **0x342e42** performs
a distance gate, calls `HasLineOfSightToSound` at **0x342f64**, and can call
`HasPathToSound` at **0x343036** when the direct test fails and a cached option
permits pathfinding. The path helper calls `AI::cSoundPathfinder::HasPath`.
The direct helper queries physics collision and inverts the collision result.
The distance comparison adds a stored hearing value to one supplied float before
squaring it; complete caller parameter semantics have not been traced.

**Rook adaptation.** Replace the blanket wall multiplier with a small acoustic
portal graph: an open doorway can carry sound around a screen, while a sealed
wall cannot. Budget the remaining sound distance along that route. Use a direct
ray first and cache portal routes to limit cost. A character navigation path is
only a possible approximation; it does not automatically model acoustics.

Current difference: `layered_stealth_guard.gd::hear_sound()` uses
`min(hearing_range, audible_radius)` and multiplies reach by
`sound_wall_transmission` after a blocked ray. It does not test an acoustic route.

## 3. Guards can divide investigation duties

**Verified definitions.** `data/behaviourgraphs/patroller.lua` handles
`onnewinterest` differently for the role tags `investigate` and `sentry`: one
enters `investigate`, the other `wait`, when the target is not visible. A waiting
guard transitions to `investigate` on `onsquadinvestigatordied`. The rifle guard
attributes enable `canjoinsquad` and declare `squadmergeradius=384`.

**Rook adaptation.** One nearby Hound investigates a bell while another watches
an exit or keeps its patrol. Keep this readable with distinct glance, movement
and alert indicators. This would improve the current bell behavior, which can
send several listeners toward the same location.

The data proves role-dependent reactions. It does not establish the complete
native algorithm for allocating or reassigning those roles, so Rook should use
its own simple, deterministic assignment rule.

## 4. Investigation, area search and memory are separate concerns

**Verified definitions.** The patroller's `investigate` state enters `search` on
`onreachpoint`; `ondonesearching` returns to patrol. The search behavior declares
`searcharea=64`, `searcharearandom=128` and `pathfinder=true`. Its native
`GenerateSearchPoints` function at **0xba766** queries valid segments, platform
ends, collision and projected collision positions. This supports geometry-aware
search-point generation rather than only an in-place head sweep; the full
selection algorithm was not reconstructed.

The rifle guard declares separate `forgetenemy` and `forgetinterest` values
(20 and 60 respectively). Those are different memory settings, not proof that
every encounter searches for those exact durations.

**Rook adaptation.** Keep separate stimulus lifetime, investigation destination,
search budget and enemy memory. After reaching the last seen/heard point, visit
two or three reachable nearby search points before returning to patrol. Never
update that destination from the hidden player's current location.

Rook already separates confirmed and suspected positions. Its current search
travels to one location and then turns in place, making area search a useful
extension rather than a replacement of the existing state machine.

## 5. Enemy senses are profiles, not one universal cone

**Verified definitions.** `data/attributes/med_guard_rifle.lua` defines four vision
regions with different `peripheral`, `nightvision`, `isrendered`, range and
one-way-platform settings. A short region has `nightvision=true`; other regions
do not. `data/attributes/guard_dog.lua` defines a different set, including a wider
night-vision peripheral region. Dogs also disable squad joining and have
different path capabilities and interest-memory settings.

Native `cVisionCone::TargetIsDetectable` at **0x2f61dc** calls
`LightingComponent::GetLitState` and branches on its returned state. Thus lighting
is part of target eligibility, beyond the existence of a geometric cone. Some
branches bypass this check; the exact flag and enum meanings are not all decoded.

**Rook adaptation.** Add opt-in sense profiles using the same reusable Hound art:
a lamp guard with a narrow strong region and weaker peripheral notice, and a
tracker with stronger nearby detection in darkness. Show each exception clearly.
Rook already has close recognition, graded exposure and uncertain sightings;
this is about differentiating profiles, not adding basic darkness detection again.

An important reference trap: the dog attribute actually selects `bgraph=patroller`.
The separately shipped `behaviourgraphs/guard_dog.lua` contains only an idle state;
its filename alone is not evidence of the dog's active AI logic.

## 6. A portable distraction can be placed and triggered later

**Verified definitions.** `data/stategraphs/projectile_noisemaker.lua` has `thrown`,
`land`, `pop` and `expire` states. Both `thrown` and `land` handle `remoteactivate`
by entering `pop`. `pop` calls the shared `noisemaker_noise` action. In
`data/attributes/ninja.lua`, the noisemaker's targeting entry declares
`arearadius=640`, `areatargeteffect=target_audible` and
`arearingeffect=target_sound_ring`.

**Rook adaptation.** A limited-use throwable chime or wind-up toy extends the
existing bell mechanic: preview the landing point, place it, move to cover and
trigger it when a patrol reaches the intended position. Reuse Rook's own prop
models and sound events. Timing and range should be tuned in Godot units.

## 7. Hiding and peeking have explicit states

**Verified definitions.** The player's state graph includes `hide_fg_idle`,
`hide_bg_idle`, foreground/background peeking states and transitions between
hiding spots. Their tags distinguish `hiding`, `peeking` and use transitions.
The player attributes also declare separate lit/unlit visual skins.

Klei's published design explanation describes concealment as a binary player
state and emphasizes observing, planning, executing and reacting. That supports
clear feedback, but does not imply every underlying engine predicate is binary.
[Developer design account](https://www.gamedeveloper.com/design/stealth-in-2d-design-lessons-from-i-mark-of-the-ninja-i-).

**Rook adaptation.** Explicit hide/peek interactions on an alcove or reusable
barrel could provide intentional hiding alongside ordinary wall occlusion. Keep
Rook's current graded simulation if desired, but make the visible ruling and any
near-contact exception clear. Whether peeking affects detection in the reference
was not established by this pass.

## Recommended prototype order

1. **Noise feedback and an acoustic doorway test.** Use an L-shaped alley, one
   doorway and a sealed wall. Compare the visual pulse with actual listener
   outcomes for footsteps, landings and bells. This offers the fastest practical
   improvement to systems already in Nocturne City.
2. **One investigator plus one sentry.** Use two Hounds and one bell. Check that
   the selected investigator changes predictably and the exit remains guarded.
3. **Reachable area search and a portable lure.** Check that guards search the
   incident area, do not track the hidden player, and eventually resume patrol.
4. **Enemy sense profiles and hide/peek props.** Add only after the first three
   interactions are readable and enjoyable in a small test room.

These are proposed Rook features. No copied implementation, tuning conversion,
new level or gameplay feature is included in this research pass.

## Reproduce the local source and native inspection

```sh
python3 tools/inspect_mark_of_ninja.py --native \
  --output /private/tmp/mark-ninja-selected-evidence.json
```

Pass `--app` for another installation path. Omit `--native` to inspect only the
literal Lua definitions. The parser rejects code and unsupported expressions
rather than executing them. Selected facts include source identity and offsets;
the original files remain in the game installation.

To repeat the REA inventory with a Node version supported by REA 6.7.0:

```sh
npx --yes --cache /private/tmp/mark-ninja-rea-npm-cache rea-agents@6.7.0 \
  inspect-artifact \
  "$HOME/Library/Application Support/Steam/steamapps/common/mark_of_the_ninja/ninja.app" \
  --format json > /private/tmp/mark-ninja-rea-artifact.json
```

Pass `--rea-evidence /private/tmp/mark-ninja-rea-artifact.json` to the Python tool
to retain its compact provenance alongside the selected source facts. REA's
native engines were not installed or used in this pass. Native addresses apply
only to the executable hash above; configuration can be overridden by level or
runtime state. Sound-path limits, all material-specific noise dispatch, full
alert accumulation, precise hiding/peeking detection and role allocation remain
unverified.

## Follow-up prototype

The [Stealth Systems Lab](stealth-systems-lab.md) now provides isolated playable
adaptations of doorway hearing, investigator/sentry coordination and a remote
chime with area search, using our own controllers and reusable assets. These
are design experiments, not claims about unverified native game behavior.
