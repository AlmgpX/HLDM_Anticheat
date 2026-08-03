# HLDM Chaos Control 1.0

Server-side administrator extension for Half-Life Deathmatch.

## Administrator controls

- `amx_bee_mode` toggles infinite hornet assist while firing.
- `amx_bee_burst` releases a hornet swarm.
- `amx_chaos_menu` or chat `/chaos` opens the target menu.

Recommended client binds:

```cfg
bind "F2" "amx_bee_mode"
bind "F3" "amx_bee_burst"
bind "F4" "amx_chaos_menu"
```

## Punishment options

- exact 1% outgoing damage;
- hornets fired by the punished player turn around and home back to their owner;
- the punished player's grenades and satchels attach to their own body;
- periodic meat/gib bursts with flesh sounds;
- random velocity and punch-angle pulses;
- full chaos mode persists by valid SteamID and also invokes the existing trap.

## Karma protection

A selected trusted player can be marked protected. Damage from another player is cancelled, reflected to the attacker, and converted into health for the protected player. Protection persists by valid SteamID.

Commands:

```text
amx_chaos_protect #userid 1
amx_chaos_protect #userid 0
amx_chaos_punish #userid
amx_chaos_clear #userid
amx_chaos_status
```

Bots, HLTV and administrators are excluded from chaos punishment.
