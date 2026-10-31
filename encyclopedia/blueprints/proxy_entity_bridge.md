# Proxy entity bridge (cross-engine combat and collision)

Use this when two runtimes must share collision and combat but neither engine can host the other's actors. The bridge is a small authority layer, not a second game.

## Topology

```
Guest (engine A)                         Host (engine B)
  guest player/camera                      host player/camera
  guest physics/collision                  host physics/collision
        |                                        |
        +---- WebSocket 127.0.0.1:<port> --------+
                     JSON messages
```

- One process owns the **authority** for a given interaction. Do not let both engines apply damage or impulse to the same event.
- The bridge is loopback-only. Bind `127.0.0.1`, require a token, and reject non-loopback peers.
- Tick order: host physics -> bridge exchange -> guest physics -> render. A frame of lag is expected; interpolate, do not teleport.

## Message schema

```json
{
  "v": 1,
  "tick": 12345,
  "kind": "raycast | block | damage | pose | hello",
  "id": "guest-entity-7",
  "pos": [0.0, 0.0, 0.0],
  "rot": [0.0, 0.0, 0.0, 1.0],
  "hit": {"point": [0.0, 0.0, 0.0], "normal": [0.0, 0.0, 1.0], "distance": 1.2},
  "damage": {"amount": 10.0, "type": "blunt", "source": "host-entity-3"},
  "flags": {"authority": "host", "hidden": true}
}
```

Rules:

1. `tick` is monotonic per sender; drop out-of-order messages.
2. `id` is namespaced (`guest-`, `host-`) so an id collision cannot silently bind the wrong actor.
3. `pos`/`rot` are already converted to the receiver's coordinate system by the sender's adapter. Do not convert twice.
4. `damage` carries `authority`; the receiver applies it only when it is not the authority.
5. Unknown `kind` is ignored and logged once, not fatal.

## Floor raycasts -> invisible barrier blocks

For a hollow guest building shell:

1. Cast down from the guest player every tick (or every N ticks) against the host collision world.
2. If the hit distance is below the guest floor height, spawn or move an invisible host collision block under the player.
3. Keep a small pool (8-16 blocks) and recycle; do not spawn per frame.
4. Despawn blocks when the player leaves the tile or after a timeout.

## Guest block placement -> host collision props

When the guest places a block:

1. Guest sends `kind: "block"` with the grid cell and material.
2. Host spawns a collision prop at the converted position, with `flags.hidden = true` and no render mesh.
3. Host acknowledges with the prop id; the guest stores the mapping.
4. On removal, host despawns the prop and acknowledges. If the ack is missing for two ticks, retry once, then log and drop.

## Invisible proxy entities and damage interception

- Spawn one host proxy entity per guest combatant. Give it an infinite hidden status effect (or the engine's equivalent) so it never dies or renders.
- The proxy carries the guest entity id in its name/metadata.
- Host damage events are intercepted before application:
  1. Read the attacker, target and damage type.
  2. Convert the target proxy id back to the guest entity id.
  3. Send `kind: "damage"` to the guest with `authority: "guest"`.
  4. Cancel the host application if the guest owns health.
- Guest health changes are sent back as `kind: "pose"`/`kind: "damage"` state updates; the host only displays them.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Proxy jitters between two positions | Both engines apply the same movement | Pick one authority per entity and make the other read-only |
| Damage applies twice | Host applies before forwarding | Intercept and cancel before the host health write |
| Proxy dies and respawns | No hidden/infinite status effect | Reapply the effect on spawn and on respawn |
| Blocks drift from the guest grid | Position converted twice | Convert once at the adapter boundary; log the raw and converted values |
| Bridge stalls the render thread | Synchronous socket call in `Present` | Move I/O to a worker thread; publish snapshots through a seqlock |

## Verification

- A raycast from the guest hits the host floor at the expected height.
- One block placed in the guest appears as a host collision prop at the same world point.
- One damage event crosses the bridge once, not twice.
- Kill the bridge: both engines keep running and log the disconnect; no hang.
