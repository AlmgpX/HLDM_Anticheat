# HLDM Runtime Behavior Contract

[Русский](BEHAVIOR_CONTRACT_RU.md) | **English** | [Español](BEHAVIOR_CONTRACT_ES.md)

This file describes how the **current build is supposed to behave in-game**. It is not a history of experiments. If code, config and README disagree, this contract is the intended target and the mismatch is a bug.

## Primary rule

One effect should have one primary runtime owner. Two plugins must not simultaneously delete the same projectile, apply duplicate recoil to the same weapon, or create two payload paths for the same event.

## Behavior ownership

| Behavior | Owner | Must not also own it |
|---|---|---|
| Hornet cap/touch/lifetime | `hldm_hornet_policy` | `hldm_hornet_fix`, Weapon Lab hornet lifecycle |
| Python scatter/recoil/self-damage | `hldm_weapon_comedy` | extra Python recoil from Weapon Lab |
| Gauss recoil vector | `hldm_weapon_comedy` | legacy backward recoil from Weapon Lab |
| MP5 underbarrel, ordinary player | stock Half-Life | Weapon Comedy and payload plugins |
| MP5/hand-grenade betrayal | `hldm_weapon_lab` | global underbarrel replacement |
| Hand-grenade delayed hornets | `hldm_weapon_payloads` | old pre-blast Weapon Lab grenade payload |
| RPG wobble/betrayal | `hldm_weapon_lab` | creation of duplicate RPG rocket entities |
| RPG/Python/Gauss factory text | `hldm_weapon_comedy` | Egon vacuum text |
| Egon vacuum text | `hldm_egon_factory` | MP5/RPG/Python/Gauss |
| Crossbow impact payload | `hldm_weapon_payloads` | Python scatter projectiles |

## Hornet Gun

- maximum 10 active hornets per owner;
- the 11th is removed without exploding the oldest;
- touching world geometry is not an automatic explosion;
- live players, monsters and breakables may trigger an explosion;
- surviving hornets finish with a lifetime explosion;
- `hldm_hornet_fix` stays disabled;
- Weapon Lab does not own hornet lifecycle;
- Hornet Policy marks tracked entities so a reused GoldSrc edict index cannot inherit owner/time state from an older hornet.

## Python / revolver

Python should feel like an unreliable 16-pellet revolver without creating an entity storm.

- one native Python shot remains for ammo consumption, sound and animation;
- exact native PvP damage is suppressed;
- the real PvP hit pattern is produced by 16 hitscan traces with shotgun-like spread;
- each trace deals 3 damage by default;
- no native `crossbow_bolt` entities are created;
- Python therefore must not trigger crossbow explosion/snark payloads;
- owner self-damage is small and non-lethal by default;
- recoil belongs only to Weapon Comedy;
- Python messages come only from the Python/revolver factory bank.

## MP5

Primary fire may keep separate global Weapon Lab jokes, but the **underbarrel remains stock for ordinary players**.

- one stock contact grenade;
- no double rockets;
- no Weapon Comedy cooldown;
- no delayed hornet payload;
- no Egon/vacuum messages;
- under `QUIET_BETRAYAL`, the owned grenade may steer back toward its owner.

## RPG

- one stock `rpg_rocket` is used;
- no duplicate rocket entities are created;
- Weapon Lab may add mild wobble to the existing rocket;
- `QUIET_BETRAYAL` may turn the existing rocket back toward its owner;
- no legacy rocket-to-hornet touch payload;
- factory text must be RPG/rocket-specific, never vacuum-cleaner or Python text.

## Gauss

- Weapon Lab does not add a separate backward recoil impulse;
- secondary recoil is corrected only by Weapon Comedy;
- the final impulse is sharply downward or toward a random side;
- messages come only from the Gauss/magnetic factory bank.

## Egon

- vacuum/self-destruct messages belong only to `hldm_egon_factory`;
- hard gate: weapon id `10`;
- MP5 underbarrel cannot trigger Egon text;
- Weapon Lab may keep a separate Egon gameplay effect such as periodic hornets, but that must not affect message routing.

## Hand grenade / satchel / crossbow

- delayed guided hornets after the native blast belong only to the hand grenade;
- MP5 contact grenades do not receive that payload;
- satchel snarks are protected through their own blast and released after a delay;
- a real crossbow bolt gets a mini explosion plus delayed snarks;
- Python creates no real crossbow bolts and must never enter that payload path.

## Snarks

- `hldm_weaponlab_snark_max "30"` must actually allow 30 and must not be internally clamped below that value;
- the cap exists to protect the GoldSrc edict pool from uncontrolled multiplication.

## Population Manager

Defaults:

```cfg
hldm_population_bots_enabled "0"
hldm_population_monsters_enabled "0"
```

Enable `addbot` only after installing a compatible bot DLL. Do not enable late native `monster_zombie` / `monster_headcrab` spawning until a safe pooled/custom implementation exists.

## Minimum smoke test after an update

1. Python: fire six shots, no explosions/snarks, 16 traces, non-lethal self-damage.
2. MP5 alt-fire: one stock contact grenade, no rocket/vacuum/hornet payload.
3. RPG: one stock rocket, some wobble, no duplicate rocket entities.
4. Gauss secondary: no separate initial backward kick from Weapon Lab.
5. Egon: vacuum text only while Egon is selected.
6. Hornet Gun: cap 10, 11th does not explode oldest, wall contact is not automatically explosive.
7. `amxx plugins`: all current plugins are `running`, no stale duplicate builds are loaded.
