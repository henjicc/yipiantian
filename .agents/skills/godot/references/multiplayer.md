---
type: Reference
title: "High-Level Multiplayer Reference"
description: "Godot's high-level API runs over a `MultiplayerPeer` (usually `ENetMultiplayerPeer`; `WebSocketMultiplayerPeer`/`WebRTC` for the web)."
tags: [godot, gamedev, gdscript]
generated: { by: claude-code/unversioned, at: 2026-06-06T00:00:00Z }
---
# High-Level Multiplayer Reference

**Verified 2026-06-06** against Godot 4.x. Godot 4 replaced the 3.x `master`/`puppet`/`remote` keywords and `rset` with the `@rpc` annotation and the `MultiplayerSynchronizer` node. Re-verify if a newer minor changes them.

Godot's high-level API runs over a `MultiplayerPeer` (usually `ENetMultiplayerPeer`; `WebSocketMultiplayerPeer`/`WebRTC` for the web). Assign it to `multiplayer.multiplayer_peer` and the engine routes RPCs and node replication.

## Connect

```gdscript
const PORT := 7777

func host() -> void:
    var peer := ENetMultiplayerPeer.new()
    peer.create_server(PORT, 8)            # port, max clients
    multiplayer.multiplayer_peer = peer

func join(address: String) -> void:
    var peer := ENetMultiplayerPeer.new()
    peer.create_client(address, PORT)
    multiplayer.multiplayer_peer = peer

func _ready() -> void:
    multiplayer.peer_connected.connect(_on_peer_connected)     # id of the joiner
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    # client-only: connected_to_server / connection_failed / server_disconnected
```

## RPCs with @rpc

Annotate a function, then invoke it over the network. The function body runs on the *receiving* peers (and locally too with `call_local`).
```gdscript
@rpc("any_peer", "call_local", "reliable")
func spawn_bullet(pos: Vector2, dir: Vector2) -> void:
    # runs on every peer
    ...

rpc("spawn_bullet", global_position, aim)     # call on all peers
rpc_id(1, "request_action", payload)          # call only on peer 1 (the server)
```

`@rpc` options (any order; sensible defaults if omitted):
- **Who may call**: `"authority"` (default; only the node's authority sends) or `"any_peer"` (clients may send too).
- **Local execution**: `"call_remote"` (default; receivers only) or `"call_local"` (also run on the sender).
- **Transfer**: `"reliable"`, `"unreliable"`, or `"unreliable_ordered"`. Use reliable for state-changing events, unreliable for high-frequency transforms.

Inside an RPC, `multiplayer.get_remote_sender_id()` returns who sent it. **Never trust client input**: validate on the server before applying, and gate authoritative actions on `multiplayer.is_server()`.

## Identity

```gdscript
multiplayer.is_server()           # true on the host (peer id 1)
multiplayer.get_unique_id()       # this peer's id (1 = server)
multiplayer.get_remote_sender_id()# inside an RPC: the caller's id
```

## Authority and replication

Each node has a multiplayer authority (the peer allowed to drive it). The server is authority by default.
```gdscript
$Player.set_multiplayer_authority(peer_id)     # e.g. give a player node to its owner
if is_multiplayer_authority():                 # only the owner runs input/movement
    velocity = read_input()
```

- **`MultiplayerSpawner`**: auto-replicates instances of registered scenes that are added under a spawn path, so a node spawned on the server appears on all clients.
- **`MultiplayerSynchronizer`**: declaratively replicates listed properties (position, health) from the authority to other peers each tick, without hand-written RPCs.

A common split: `MultiplayerSpawner` for who exists, `MultiplayerSynchronizer` for their state, and `@rpc` for discrete events (fire, take damage, chat).

## Pitfalls

- 3.x keywords `master`/`puppet`/`remote`/`remotesync` and `rset` are gone. Use `@rpc` and `MultiplayerSynchronizer`.
- Trusting client-sent RPCs. Validate on the server; `"any_peer"` means any client can call it.
- Running input/movement on every peer for every node. Gate on `is_multiplayer_authority()`.
- Spawning replicated nodes by hand on each peer. Use `MultiplayerSpawner` so spawns stay consistent.
- Sending high-frequency transforms `"reliable"`. Prefer `"unreliable_ordered"` (or a synchronizer) to avoid congestion.
