# Installing HLDM Anticheat / Chaos Server on Windows

[Русский](INSTALL_RU.md) | **English** | [Español](INSTALL_ES.md)

Target runtime behavior: [BEHAVIOR_CONTRACT_EN.md](BEHAVIOR_CONTRACT_EN.md).

This guide describes the **current full stack**, not only the early `hldm_trap` + `hldm_detector` setup.

## 1. Choose a Steam listen server or standalone HLDS

### Recommended for the current project: Steam listen server

Use an installed Steam copy of Half-Life and create the server from `Multiplayer -> Create Server`.

Advantages:

- the host is already inside the match;
- easy plugin testing on the same machine;
- Steam Friends / Join Game / Invite follows the normal listen-server workflow;
- current weapon/admin development is primarily exercised in this setup.

Typical path:

```text
E:\SteamLibrary\steamapps\common\Half-Life
```

### Standalone HLDS

Useful for an always-on server without a running game client. The repository still contains the PowerShell installer for HLDS AppID 90, but the complete experimental plugin set should always be checked against the current CI artifact.

## 2. Required chain

```text
Half-Life / HLDS
    -> Metamod
        -> AMX Mod X 1.10
            -> HLDM plugins
```

Required AMXX modules include:

```text
Fakemeta
Ham Sandwich
nVault
```

Verify after startup:

```text
meta list
amxx version
amxx modules
```

## 3. Getting compiled `.amxx` files

GitHub Actions compiles **all**:

```text
src\*.sma
```

with official AMX Mod X Compiler `1.10.0.5479` and places the resulting plugins in the CI artifact.

The CI package also contains:

```text
addons\amxmodx\plugins\*.amxx
addons\amxmodx\configs\plugins\*.cfg
docs\*.md
```

Prefer the CI binaries over ad-hoc local builds because CI rejects Pawn warnings.

## 4. Installing the full stack into Steam Half-Life

Close Half-Life completely before replacing `.amxx` files.

Copy plugins to:

```text
<HalfLifeRoot>\valve\addons\amxmodx\plugins\
```

Copy configs to:

```text
<HalfLifeRoot>\valve\addons\amxmodx\configs\plugins\
```

Example:

```text
E:\SteamLibrary\steamapps\common\Half-Life\valve\addons\amxmodx\plugins\
E:\SteamLibrary\steamapps\common\Half-Life\valve\addons\amxmodx\configs\plugins\
```

## 5. Critical cleanup of stale plugins

Before startup, inspect:

```text
valve\addons\amxmodx\configs\plugins.ini
```

Do not load several historical Weapon Comedy binaries together, for example:

```text
hldm_weapon_comedy.amxx
hldm_weapon_comedy_v2.amxx
hldm_weapon_comedy_v3.amxx
hldm_weapon_comedy_v4.amxx
```

Exactly **one current version** should be active.

The same applies to other experimental duplicates. An old `.amxx` sitting on disk is not automatically dangerous; two versions listed in `plugins.ini` and handling the same `Touch`, `Think` or `CmdStart` absolutely are.

## 6. Recommended relative order

The complete list depends on enabled experimental modules, but the important dependencies are:

```text
hldm_trap.amxx
hldm_detector.amxx

# admin / punishment modules
hldm_admin_tools.amxx
hldm_runtime_guard.amxx
hldm_chaos.amxx
hldm_meat_demon.amxx
hldm_silent_misery.amxx
hldm_leader_curse.amxx

# weapon stack
hldm_weapon_comedy.amxx
hldm_weapon_lab.amxx
hldm_weapon_payloads.amxx
hldm_population_manager.amxx
hldm_hornet_policy.amxx
hldm_egon_factory.amxx
```

Rules:

- load `hldm_trap` before `hldm_detector`;
- load Weapon Comedy before Weapon Lab;
- load `hldm_hornet_policy` after other modules that can observe hornets;
- preferably do not load the old `hldm_hornet_fix` at all. If it remains loaded, `hldm_hornetfix_enabled "0"` is mandatory.

## 7. Mandatory current stability settings

### Hornets

In `hldm_hornet_policy.cfg`:

```cfg
hldm_hornetpolicy_enabled "1"
hldm_hornetpolicy_max_active "10"
hldm_hornetpolicy_lifetime "3.20"
hldm_hornetfix_enabled "0"
```

In `hldm_weapon_lab.cfg`:

```cfg
hldm_weaponlab_manage_hornets "0"
hldm_weaponlab_rocket_hornets "0"
```

Do not let multiple plugins manage the same hornet lifetime/touch/removal path.

### MP5 underbarrel

For ordinary players it remains stock. No old plugin version should replace secondary fire with double rockets.

The current Weapon Comedy config should not contain the old experimental MP5 settings such as:

```text
second_rocket
rocket_max_active
rocket_speed
```

### Python / revolver

Current safe defaults:

```cfg
hldm_weaponcomedy_python_self_damage "4.0"
hldm_weaponcomedy_python_self_damage_lethal "0"
hldm_weaponcomedy_python_suppress_stock_pvp_damage "1"
hldm_weaponcomedy_python_pellets "16"
hldm_weaponcomedy_python_pellet_damage "3.0"
hldm_weaponcomedy_python_spread "0.16"
hldm_weaponcomedy_python_range "4096.0"
hldm_weaponcomedy_python_recoil "220.0"
```

Critical rule: the revolver does not create native `crossbow_bolt` entities. The 16 extra “bolts” are visual hitscan traces with no persistent entities.

### Egon

`hldm_egon_factory.amxx` is for Egon weapon id `10` only.

Check:

```text
amx_egonfactory_status
```

MP5 underbarrel must never trigger vacuum-cleaner messages.

### Population Manager

Current safe defaults:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

Reasons:

- `addbot` does not exist without a ParaBot-compatible bot DLL;
- late native `monster_zombie` / `monster_headcrab` spawning can trigger `PF_precache_sound_I` and `Host_Error` because the game DLL attempts sound precaching after map load.

Do not enable `hldm_population_monsters_enabled 1` in the current implementation.

## 8. Starting a Steam listen server

After installing Metamod/AMXX and the plugins:

1. Launch Half-Life through Steam.
2. Open `Multiplayer`.
3. Select `Create Server`.
4. Choose the map, player count and other settings.
5. Start the server.

If you already use a prepared launcher, use that instead of starting Half-Life normally.

Open the console after the map loads.

## 9. Initial verification

```text
meta list
amxx version
amxx modules
amxx plugins
```

Current HLDM plugins should not show:

```text
bad load
error
unknown
```

Core checks:

```text
amx_ac_status
amx_trap_list
```

Weapon-layer checks:

```text
amx_weaponcomedy_status
amx_hornetpolicy_status
amx_payload_status
amx_egonfactory_status
```

Quiet-mode check:

```text
amx_quiet_status
```

## 10. Post-update smoke test

Do not begin a ten-minute chaos session immediately after replacing weapon `.amxx` files. Run a short smoke test first.

### MP5

```text
10 single alt-fire shots
several held alt-fire attempts
```

Expected: one normal contact grenade per normal weapon event, no rocket swarm and no Egon/vacuum messages.

### RPG

```text
10 single shots
```

Expected: one stock rocket per shot. Some rockets may wobble slightly. No extra rockets are created.

### Hornet Gun

Fire several bursts.

Expected:

- at most 10 active hornets per owner;
- the 11th does not explode the oldest;
- wall contact does not have to destroy the hornet;
- remaining hornets end with a controlled lifetime explosion.

### Python

Test:

```text
1 shot into a wall
6 rapid shots into a wall
several shots into a player
```

Expected:

- tracers/sparks;
- no 16 physical crossbow entities;
- no 16 explosions;
- no 48 snarks;
- self-damage does not kill the owner with default settings.

### Real crossbow

Test separately to verify its own impact/payload still works. Python no longer shares the same native entity path.

### Egon

Fire Egon several times. Vacuum-cleaner messages may appear only here.

## 11. Quiet punishment test

Find the server `userid`:

```text
status
```

Example:

```text
amx_quiet #17 betrayal
```

Test a hand grenade, MP5 contact grenade and RPG from the **marked** client. Then clear the mode:

```text
amx_quiet #17 clear
```

`#17` is a server userid, not a slot index.

## 12. AMX Mod X administrator

Add the SteamID to:

```text
valve\addons\amxmodx\configs\users.ini
```

Example:

```text
"STEAM_0:1:12345678" "" "abcdefghijklmnopqrstu" "ce"
```

Then run:

```text
amx_reloadadmins
```

or restart the server.

## 13. Legacy repository setup scripts

The repository still contains:

```text
deploy\setup_hldm_server_windows.ps1
deploy\install_fresh_hlds_windows.ps1
deploy\uninstall_windows.ps1
```

They are useful for setting up the base Metamod + AMX Mod X + core anticheat chain. The project has grown much faster than its original installers, so **always compare the full active plugin set with the current CI artifact and `src/*.sma`**.

Base setup example:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\deploy\setup_hldm_server_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life" `
  -RconPassword "STRONG_PASSWORD" `
  -Hostname "HLDM" `
  -Port 27015 `
  -MaxPlayers 16
```

## 14. Manual compilation

Use AMX Mod X Compiler `1.10.0.5479`.

Sources:

```text
src\*.sma
```

Compile each `.sma` with `amxxpc.exe`. CI performs the same process automatically and rejects warnings.

Local contract check:

```text
python tools/check_contract.py
```

## 15. Crash diagnostics

When the server crashes, copy the console **starting from the first error**, not only the last two lines.

Important markers:

```text
Host_Error:
PF_precache_sound_I:
PF_precache_model_I:
ED_Alloc:
SZ_GetSpace:
Invalid entity
Run time error
```

Example of a real root cause already found:

```text
Host_Error: PF_precache_sound_I: 'zombie/claw_strike1.wav'
Precache can only be done in spawn functions
```

The later `nVault`, disconnect, unload and `Server shutdown` messages were teardown consequences, not the original cause.

## 16. Rollback

Before every manual or packaged update, back up:

```text
plugins.ini
replaced *.amxx
replaced *.cfg
```

For the base anticheat uninstall:

```powershell
.\deploy\uninstall_windows.ps1 `
  -HalfLifeRoot "E:\SteamLibrary\steamapps\common\Half-Life"
```

Later experimental plugins may need to be removed manually from `plugins.ini` and the `plugins` directory.

## 17. Final stable-install checklist

```text
[ ] exactly one current Weapon Comedy is loaded
[ ] hldm_hornet_policy enabled
[ ] hldm_hornet_fix disabled
[ ] hldm_weaponlab_manage_hornets = 0
[ ] MP5 underbarrel remains stock for ordinary players
[ ] Python uses zero-entity scatter
[ ] Egon Factory triggers only for weapon id 10
[ ] addbot disabled without a bot DLL
[ ] runtime native monsters disabled
[ ] amxx plugins contains no bad load
[ ] MP5/RPG/Hornet/Python/Crossbow/Egon smoke test passed
```

Only after that should the server be allowed to return to its natural state: several decades of GoldSrc code pretending that causality is optional.