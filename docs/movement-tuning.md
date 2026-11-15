# Shared movement baseline

All levels use the Lamplight Store movement baseline:

| Character | Setting | Speed |
| --- | --- | --- |
| Rook | Normal movement | 4.2 m/s |
| Rook | Quiet movement | 45% of normal, or 1.89 m/s |
| Rook | R1 / Ctrl run | 150% of normal, or 6.3 m/s |
| Hound | Pursuit | 4.6 m/s |

The source of truth is `scripts/movement_tuning.gd`. Rook's shared controllers
apply its normal speed on startup. The reusable Hound scene belongs to the
`hounds` group, which survives controller replacement; `NPCController` applies
the shared pursuit speed to that group on startup. Legacy saved overrides
therefore cannot silently change the baseline. Existing saved scene values and
level builders have also been aligned with these defaults.

Hound patrol/search speeds, acceleration, detection profiles and Mouse tuning
remain independent. Temporary gameplay effects can use Rook's existing
`movement_speed_multiplier` rather than changing the baseline. Jump tuning and
camera framing are independent of this change.

Controller input uses a continuous, camera-relative direction on the ground
plane in every movement phase. The left stick has a radial 20% deadzone,
preserves tilt strength, and clamps diagonal speed to normal magnitude. Rook's
visual faces the travel direction without rotating the camera. The keyboard's
existing cardinal/tank controls remain available in the main demo.

R1/Ctrl applies `ROOK_SPRINT_MULTIPLIER`; L1/Shift applies
`ROOK_QUIET_MULTIPLIER` and takes priority. These combine with temporary gameplay
speed effects. Advanced stealth footsteps use an 8m audible radius when running,
5m normally and 1.6m with quiet walking or a gentle controller tilt.

## Building future levels

Use `scenes/Player_v2.tscn` for Rook and
`Characters/Hound/hound_npc.tscn` for Hounds. Keep the Hound's `hounds` group
when replacing its controller. Builders should reference
`MOVEMENT.ROOK_MOVE_SPEED` and `MOVEMENT.HOUND_PURSUIT_SPEED` from the shared
script, rather than introducing local speed numbers. Harbor-derived builders
already inherit that reference; other factories can preload it directly.

When intentionally changing the baseline, update the constants and rebuild or
align serialized scene values so the Inspector agrees with runtime. Add future
gameplay scenes to the consistency suite so accidental overrides are caught.

```sh
godot --headless --path . --fixed-fps 60 --script tests/test_movement_tuning.gd
```

The suite checks reusable character scenes, seven saved gameplay scenes, two
newly constructed levels, controller replacement, stale overrides and the
independence of Mouse tuning. Gameplay regressions also cover Lamplight Store,
Midnight Exchange, Stealth Systems Lab, Nocturne City and the original stealth
study.

## Pursuit response

`StealthGuard` uses separate chase steering so a sharp turn does not preserve
patrol momentum. It refreshes moving-target paths every 0.05 seconds and changes
horizontal velocity toward the next navigable segment using a 30 m/s² minimum
response. Sharp corners temporarily reduce target speed while the old forward
velocity is removed. Finishing a path uses the same prompt braking. Patrol and
search retain their existing turn-before-walk behavior.

The shared 4.6 m/s Hound pursuit speed is unchanged. Paths still respect collision
and navigation; destinations update only from confirmed sightings. Losing sight
still freezes the last known target rather than following a hidden player.
Tune `pursuit_response` and `pursuit_repath_seconds` on the guard controller.

```sh
godot --headless --path . --fixed-fps 60 --script tests/test_pursuit_steering.gd
```

The ten checks cover right-angle and reversing steering at 30/60/120 FPS,
end-of-path braking, unchanged patrol turning and a real navigation chase that
catches a moving player after a right-angle turn without a charging overshoot.
