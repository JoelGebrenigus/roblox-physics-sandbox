# Roblox Physics Sandbox

The first playable milestone is a server-authoritative telekinesis prototype. Players can target,
grab, move, rotate, charge, throw, and drop rigid physics assemblies without setting object
`CFrame` values every frame.

## Files

- `default.project.json` maps the Rojo source tree into Roblox services.
- `src/shared` contains constants, typed remote payloads, remote setup, physics calculations, and
  object eligibility checks.
- `src/server/Systems` contains telekinesis authority, network ownership, cooldown, anti-spam, and
  Studio test arena services.
- `src/client/Controllers` contains desktop input, camera requests, presentation, and telekinesis
  client state.
- `src/ui/init.meta.json` declares the `StarterGui.TelekinesisGui` `ScreenGui`. Its visible children
  are constructed by `UIController`.

## Studio Setup

1. Install [Rojo](https://rojo.space/docs/).
2. Install the Rojo Studio plugin.
3. From this directory, run:

   ```powershell
   rojo serve
   ```

4. Open a blank Roblox Studio place.
5. Open the Rojo plugin, connect to `localhost:34872`, and sync the project.
6. Press Play.

The server creates the three remote events at runtime. While running in Studio, it also populates
`Workspace.PhysicsObjects` and `Workspace.TestArena` with labeled test props and a spawn location.
The test arena is not generated in a published server.

## Controls

| Input | Action |
| --- | --- |
| `E` | Grab the aimed object or drop the held object |
| Hold/release left mouse | Charge and release a throw |
| Mouse wheel | Move the hold point closer or farther |
| Hold `R` and move mouse | Rotate the held object |

## System Behavior

The client supplies input, camera direction, requested rotation, hover feedback, and UI. The server:

- Resolves the target to one connected rigid assembly.
- Requires the assembly to be in `Workspace.PhysicsObjects` or tagged `TelekinesisGrabbable`.
- Rejects characters, anchored or locked parts, disconnected models, protected tags, more than
  50 parts, bounds above 24 studs, mass above 250, excessive range, and blocked line of sight.
- Reconstructs the hold position from a validated camera origin, camera direction, and clamped hold
  distance. Client-supplied world positions are not applied directly.
- Uses `AlignPosition` and `AlignOrientation` with mass-scaled force, speed, and responsiveness.
- Temporarily assigns network ownership to the holder, while monitoring range, position error,
  velocity, assembly integrity, ownership, update freshness, and line of sight.
- Computes charge time, throw impulse, energy drain, and energy regeneration itself.
- Reclaims server ownership before applying a throw impulse, then restores automatic ownership.

Held parts temporarily use a collision group that ignores player characters but still collides with
the environment. Their previous collision groups are restored after release.

## Object Authoring

The simplest eligible object is an unanchored part or welded model placed under
`Workspace.PhysicsObjects`. Objects elsewhere must receive the `TelekinesisGrabbable` tag through
CollectionService.

Use either of these tags to block an object:

- `TelekinesisProtected`
- `NoTelekinesis`

A blocking tag on the selected part, another part in its assembly, or a relevant ancestor wins over
the allowed folder or tag.

Tune gameplay values in `src/shared/Constants.lua`. The main limits are:

- Grab distance: 60 studs
- Hold distance: 7 to 28 studs
- Maximum assembly mass: 250
- Maximum connected parts: 50
- Maximum bounds: 24 studs
- Energy: 100
- Maximum charge time: 1.5 seconds

## Test Checklist

### Play Solo

1. Grab the blue light crate and confirm it tracks quickly with slight sway.
2. Grab the orange heavy crate and confirm it has more lag and resistance.
3. Adjust distance, rotate it, drop it, and confirm momentum is retained.
4. Charge and throw both valid crates. The heavy crate should launch more slowly.
5. Hold an object until energy reaches zero, then confirm automatic drop and delayed regeneration.
6. Try the overweight, oversized, anchored, protected, locked, and disconnected props. Each should
   be rejected with a message.
7. Move a held object behind the test wall and confirm it releases after the short obstruction grace
   period.

### Multiplayer And Network

1. Start a local server with two players.
2. Confirm only one player can hold an assembly at a time.
3. Confirm death, respawn, and disconnect release the assembly.
4. Enable about 150 ms incoming replication lag in Studio network emulation.
5. Confirm held motion remains controllable and does not teleport to raw client positions.

### Remote Validation

From a temporary local test script, send malformed action/update tables, non-parts, invalid
`CFrame` values, extreme distances, and requests above the configured rates. The server should
ignore them, print throttled Studio warnings, and release a held object after repeated violations.
It does not automatically kick players.

## Known Limitations

- Keyboard and mouse only.
- One held rigid assembly per player and one holder per assembly.
- Temporary client network ownership can permit brief local physics manipulation; server monitoring
  limits its duration and gameplay reach.
- Rotation is world-constraint based and does not yet provide axis snapping.
- The generated arena is for Studio testing, not production level design.
- No scripted collision damage, destructible environment, persistence, mobile controls, gamepad
  controls, or additional powers.

The next recommended improvement is server-verified impact damage using recent throw ownership,
assembly mass, relative collision velocity, and a per-target hit cooldown.
