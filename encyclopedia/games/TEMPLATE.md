# Field note template

Copy this file to `<host>-x-<guest>.md` and fill every field. Unknown values are `not recorded`; record `not recorded` rather than inventing a hash or a build id.

## Identity

| Field | Value |
|---|---|
| Host game / store edition | |
| Guest game / store edition | |
| Host build id | |
| Guest build id | |
| Host EXE SHA256 | |
| Guest EXE SHA256 | |
| Loader / proxy DLL | |
| Loader version | |
| Toolchain (compiler, SDK, shader compiler) | |
| Date verified | |
| Owner / workspace | |

## Coordinate conversion

| Property | Host | Guest |
|---|---|---|
| Handedness | | |
| Up axis | | |
| Forward axis | | |
| Unit scale (meters) | | |
| Rotation convention | | |

Matrix (guest -> host):

```
X_h = ...
Y_h = ...
Z_h = ...
```

Yaw conversion:

```
Yaw_h = ...
```

Known landmark used to verify the matrix:

## Verified AOB signatures

| Name | Build | Pattern | RVA | Unique | Notes |
|---|---|---|---|---|---|
| | | | | | |

## IPC / shared memory

| Field | Value |
|---|---|
| Mapping name | |
| Header version | |
| Slots | |
| Frame fields | |
| Bridge transport | |

## Authority matrix

| Interaction | Authority | Fallback |
|---|---|---|
| Player movement | | |
| Combat damage | | |
| Bone scaling / animation | | |
| Collision blocks | | |
| Camera | | |

## Known engine traps

- 

## Verification evidence

| Check | Result | Evidence |
|---|---|---|
| Offline IPC harness | | |
| Reversed-Z pixel test | | |
| Downstream sink fires | | |
| One traversal | | |
| One combat exchange | | |
| Save / reload | | |

## Rollback

- Backups:
- Disable order:
- Last known good:
