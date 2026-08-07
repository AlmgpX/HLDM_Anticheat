# HLDM Anticheat / Chaos Server

[Русский](README.md) | **English** | [Español](README_ES.md)

A server-side Half-Life Deathmatch / GoldSrc stack combining behavioral anti-cheat logic, admin tooling, silent punishment modes for marked clients, and deliberately absurd weapon mutations.

The project runs on the server side. It does not scan client processes, modify client files or key binds, and does not require a custom client mod. Punishment and weapon effects happen inside the match.

## Current architecture

Core layer:

- `hldm_detector.amxx` observes server-side `usercmd`, aim angles, visibility and shooting behavior;
- `hldm_trap.amxx` applies a trap manually, by SteamID, or automatically after a sustained detector score;
- `hldm_admin_tools.amxx` and `hldm_runtime_guard.amxx` provide local admin tools, ESP/x-ray, menus and protection modes;
- optional modules (`hldm_chaos`, `hldm_silent_misery`, `hldm_leader_curse`, `hldm_meat_demon`, the Jungian phrase layer, etc.) add separate punishment and comedy layers.

Current weapon layer:

- `hldm_weapon_comedy.amxx` — Python/revolver, Gauss and general factory-failure comedy;
- `hldm_weapon_lab.amxx` — quiet modes, tripmine behavior, RPG wobble, snark logic and other mutations;
- `hldm_weapon_payloads.amxx` — delayed payloads for satchels, hand grenades and real crossbow bolts;
- `hldm_hornet_policy.amxx` — the single current owner of normal hornet lifetime/touch/cap behavior;
- `hldm_egon_factory.amxx` — self-destructing-vacuum-cleaner jokes routed only to Egon;
- `hldm_population_manager.amxx` — bot population math and an experimental monster layer, with dangerous runtime functions disabled by default.

## Current stability rules

After several very educational encounters with GoldSrc, the project follows strict runtime rules:

1. **One entity type, one primary runtime owner.** Hornet touch/lifetime/cap is controlled by `hldm_hornet_policy`.
2. The old `hldm_hornet_fix` must remain disabled: `hldm_hornetfix_enabled "0"`.
3. `hldm_weaponlab_manage_hornets "0"`: Weapon Lab must not delete or retime the same hornets in parallel.
4. MP5 underbarrel fire remains stock for ordinary players. It is not replaced with rockets and does not receive extra payloads.
5. Python/revolver no longer creates 16 native `crossbow_bolt` entities. It uses 16 zero-entity hitscan tracers, preventing one shot from turning into 16 explosions and 48 snarks.
6. Native `monster_zombie` / `monster_headcrab` cannot be safely created with late `DLLFunc_Spawn` after map load because the game DLL attempts sound precaching and may trigger `Host_Error`. Runtime monster spawning is therefore disabled.
7. Automatic `addbot` calls remain disabled until a real ParaBot-compatible bot DLL providing that command is installed.

## Current weapon behavior

### Hornet Gun

- maximum 10 active hornets per owner;
- the 11th does not explode the oldest hornet;
- world contact does not have to kill a hornet; the policy can let it continue/bounce;
- hitting a live target causes a mini explosion;
- surviving hornets explode on a timer before GoldSrc performs its stock silent cleanup;
- repeated world touches are throttled to avoid touch storms from entities trapped in geometry.

### Python / revolver

Current `Weapon Comedy 2.3.0` behavior:

- 16 visual hitscan tracers with shotgun-like spread;
- no native `crossbow_bolt` entities are created by the revolver;
- configurable pellet damage;
- physical/visual recoil;
- small owner self-damage, non-lethal by default;
- the real crossbow remains a separate weapon and keeps its own payload behavior.

### MP5 underbarrel

Completely stock for ordinary players:

- one normal contact grenade;
- no double rockets;
- no extra hornets;
- no Weapon Comedy cooldown.

When a player is marked with `QUIET_BETRAYAL`, that player's grenade may gradually steer back toward the owner. That is a hidden punishment rule, not a global MP5 mutation.

### RPG

The normal stock rocket is used. No extra rockets are created.

- some rockets receive a mild defective-stabilizer wobble;
- a `QUIET_BETRAYAL` player's rocket may turn back toward its owner;
- factory lines such as `MADE IN CHINA`, `MADI EN INDIA`, `RPG GUIDANCE PROVIDED BY CONFIDENCE` can appear as a comedy layer.

### Egon

Vacuum-cleaner jokes live in a separate `hldm_egon_factory.amxx` plugin and are hard-routed to weapon id `10` only.

MP5 has a different weapon id and must not trigger lines such as:

```text
SELF-DESTRUCT VACUUM CLEANER
MADE IN CHINA VACUUM TECHNOLOGY
MADI EN INDIA BEAM CALIBRATION
```

### Hand grenade / satchel / crossbow

- hand grenades can release delayed guided hornets after the stock explosion;
- MP5 contact grenades do not receive that payload;
- satchel-created snarks stay hidden/invulnerable through the satchel blast and are released after a delay;
- real crossbow bolt impact gets its own mini explosion and delayed snark payload.

## Quiet modes

`hldm_weapon_lab` provides server-side silent modes without notifying the target:

```text
amx_quiet #USERID damage
amx_quiet #USERID misfire
amx_quiet #USERID betrayal
amx_quiet #USERID drift
amx_quiet #USERID all
amx_quiet #USERID clear
amx_quiet_status
```

Main effects:

- `damage` — heavily reduces outgoing damage;
- `misfire` — suppresses some primary/secondary inputs;
- `betrayal` — some owned projectile/grenade entities return toward the owner;
- `drift` — adds a small server-side punch-angle drift.

Admin commands require the corresponding AMX Mod X permissions.

## Quick start

Detailed instructions: [docs/INSTALL_EN.md](docs/INSTALL_EN.md).

For the current Steam listen-server setup, the general flow is:

1. Prepare Metamod + AMX Mod X under `Half-Life\valve`.
2. Copy current `.amxx` files to:

```text
Half-Life\valve\addons\amxmodx\plugins\
```

3. Copy `.cfg` files to:

```text
Half-Life\valve\addons\amxmodx\configs\plugins\
```

4. Check `plugins.ini` and remove stale duplicates such as multiple `hldm_weapon_comedy*.amxx` files.
5. Launch Half-Life through Steam and create a normal listen server.
6. After the map loads, run:

```text
meta list
amxx version
amxx modules
amxx plugins
```

For the weapon layer also run:

```text
amx_weaponcomedy_status
amx_egonfactory_status
amx_hornetpolicy_status
amx_payload_status
```

## Recommended relative plugin order

The complete `plugins.ini` depends on which experimental modules are enabled, but the critical relative order is:

```text
hldm_trap.amxx
hldm_detector.amxx
...
hldm_weapon_comedy.amxx
hldm_weapon_lab.amxx
hldm_weapon_payloads.amxx
hldm_population_manager.amxx
hldm_hornet_policy.amxx
hldm_egon_factory.amxx
```

`hldm_hornet_policy` should load after other modules that can see hornets. Do not load the old `hldm_hornet_fix`, or keep it disabled through configuration.

## Population Manager

Current safe defaults:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

The target bot formula already exists:

```text
floor((maxplayers - human_reserve) * bot_fraction)
```

Defaults are `human_reserve = 2`, `bot_fraction = 0.50`. Half-Life does not contain built-in bots, so `addbot` requires a real ParaBot-compatible bot DLL.

## Current weapon-stack configs

```text
configs/plugins/hldm_weapon_comedy.cfg
configs/plugins/hldm_weapon_lab.cfg
configs/plugins/hldm_weapon_payloads.cfg
configs/plugins/hldm_hornet_policy.cfg
configs/plugins/hldm_egon_factory.cfg
configs/plugins/hldm_population_manager.cfg
```

## CI and builds

GitHub Actions uses AMX Mod X Compiler `1.10.0.5479`, compiles **all** `src/*.sma`, rejects Pawn warnings, and packages all `.amxx`, plugin configs and documentation into the CI artifact.

Local contract check:

```text
python tools/check_contract.py
```

## Crash diagnostics

For a listen-server crash, capture the console tail **from the first error through `Server shutdown`**. Lines printed after a `Host_Error` are often teardown symptoms rather than the original cause.

Especially useful markers:

```text
Host_Error:
PF_precache_*:
ED_Alloc:
SZ_GetSpace:
Run time error
Invalid entity
```

## Documentation

- [Russian installation](docs/INSTALL_RU.md)
- [English installation](docs/INSTALL_EN.md)
- [Spanish installation](docs/INSTALL_ES.md)
- [Detector](docs/DETECTOR_RU.md)
- [Test plan](docs/TEST_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)

## Accuracy limits

A behavioral server-side detector cannot mathematically prove the name of a specific cheat client and cannot inspect another process's memory. It evaluates observable server-side patterns. Calibrate the detector in observe/log mode first, then enable automatic punishment after testing real players and maps.

And because this is GoldSrc, a successful compile means the code is syntactically alive. It does not mean twenty entities, three old plugins and an ancient game DLL have suddenly learned to respect causality.