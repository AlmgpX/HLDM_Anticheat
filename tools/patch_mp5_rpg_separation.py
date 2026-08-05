from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing anchor: {label}")
    return text.replace(old, new, 1)


# ---------------- Weapon Lab ----------------
path = Path("src/hldm_weapon_lab.sma")
text = path.read_text(encoding="utf-8")

text = replace_once(
    text,
    '#define PLUGIN_VERSION "1.1.0"',
    '#define PLUGIN_VERSION "1.2.0"',
    "Weapon Lab version",
)
text = replace_once(
    text,
    "new g_pcvarRocketHornets;\n",
    "new g_pcvarRocketHornets;\n"
    "new g_pcvarRpgWobbleChance;\n"
    "new g_pcvarRpgWobbleStrength;\n",
    "RPG cvar declarations",
)
text = replace_once(
    text,
    '    g_pcvarRocketHornets = register_cvar("hldm_weaponlab_rocket_hornets", "4");\n',
    '    g_pcvarRocketHornets = register_cvar("hldm_weaponlab_rocket_hornets", "0");\n'
    '    g_pcvarRpgWobbleChance = register_cvar("hldm_weaponlab_rpg_wobble_chance", "55");\n'
    '    g_pcvarRpgWobbleStrength = register_cvar("hldm_weaponlab_rpg_wobble_strength", "42.0");\n',
    "RPG cvar registration",
)

text = replace_once(
    text,
    '''    else if (equal(classname, "rpg_rocket"))
    {
        TagEntity(entity, TAG_ROCKET, 0.0);
    }
''',
    '''    else if (equal(classname, "rpg_rocket"))
    {
        TagEntity(entity, TAG_ROCKET, 0.0);
        set_pev(
            entity,
            pev_iuser1,
            random_num(1, 100) <= ClampInt(get_pcvar_num(g_pcvarRpgWobbleChance), 0, 100) ? 1 : 0
        );
        set_pev(entity, pev_fuser3, get_gametime() + 0.18);
    }
''',
    "RPG spawn tagging",
)

text = replace_once(
    text,
    "    ProcessGrenades(now);\n",
    "    ProcessGrenades(now);\n    ProcessRockets(now);\n",
    "RPG tick call",
)

text = replace_once(
    text,
    '''
            if (pressed & IN_ATTACK2)
            {
                MiniAirburstAtAim(id, 18.0, 72.0);
            }
''',
    '''
            // The MP5 underbarrel remains completely stock for ordinary players.
            // Its grenade is redirected only by QUIET_BETRAYAL in ProcessGrenades.
''',
    "remove MP5 underbarrel mutation",
)

process_anchor = "stock ProcessGrenades(Float:now)\n"
process_rockets = '''stock ProcessRockets(Float:now)
{
    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "rpg_rocket")) > 0)
    {
        if (!pev_valid(entity) || pev(entity, pev_iuser3) != TAG_ROCKET)
        {
            continue;
        }

        new owner = GetTaggedOwner(entity);
        new Float:spawnTime;
        pev(entity, pev_fuser2, spawnTime);
        new Float:age = now - spawnTime;

        // The same hidden betrayal principle as hand/MP5 grenades: a punished
        // shooter's own rocket gradually turns around and comes home.
        if (owner >= 1
            && owner <= MaxClients
            && is_user_alive(owner)
            && (g_quietMask[owner] & QUIET_BETRAYAL)
            && age > 0.45)
        {
            SteerEntityToward(entity, owner, 900.0, 48.0);
            set_pev(entity, pev_owner, 0);
            continue;
        }

        // Ordinary RPG comedy never creates extra rockets or entities. It only
        // gives some stock rockets a mild defective-stabilizer wobble.
        if (pev(entity, pev_iuser1) != 1 || age < 0.18)
        {
            continue;
        }

        new Float:nextWobble;
        pev(entity, pev_fuser3, nextWobble);
        if (now < nextWobble)
        {
            continue;
        }
        set_pev(entity, pev_fuser3, now + 0.12);

        new Float:velocity[3];
        pev(entity, pev_velocity, velocity);
        new Float:speed = floatsqroot(
            velocity[0] * velocity[0]
            + velocity[1] * velocity[1]
            + velocity[2] * velocity[2]
        );
        if (speed < 100.0)
        {
            continue;
        }

        new Float:strength = ClampFloat(
            get_pcvar_float(g_pcvarRpgWobbleStrength),
            0.0,
            180.0
        );
        velocity[0] += random_float(-strength, strength);
        velocity[1] += random_float(-strength, strength);
        velocity[2] += random_float(-strength * 0.35, strength * 0.35);
        NormalizeVector(velocity);
        velocity[0] *= speed;
        velocity[1] *= speed;
        velocity[2] *= speed;
        set_pev(entity, pev_velocity, velocity);
    }
}

'''
text = replace_once(
    text,
    process_anchor,
    process_rockets + process_anchor,
    "insert ProcessRockets",
)

path.write_text(text, encoding="utf-8", newline="\n")

cfg = Path("configs/plugins/hldm_weapon_lab.cfg")
cfg_text = cfg.read_text(encoding="utf-8")
cfg_text = cfg_text.replace(
    "// HLDM Weapon Lab 1.1.0",
    "// HLDM Weapon Lab 1.2.0",
    1,
)
cfg_text = replace_once(
    cfg_text,
    'hldm_weaponlab_rocket_hornets "0"\n',
    'hldm_weaponlab_rocket_hornets "0"\n\n'
    '// MP5 underbarrel stays stock for ordinary players. Hand grenades and\n'
    '// MP5 contact grenades return only under QUIET_BETRAYAL.\n'
    '// RPG comedy modifies the existing rocket only; no duplicate rockets.\n'
    'hldm_weaponlab_rpg_wobble_chance "55"\n'
    'hldm_weaponlab_rpg_wobble_strength "42.0"\n',
    "Weapon Lab RPG config",
)
cfg.write_text(cfg_text, encoding="utf-8", newline="\n")


# ---------------- Weapon Payloads ----------------
path = Path("src/hldm_weapon_payloads.sma")
text = path.read_text(encoding="utf-8")
text = replace_once(
    text,
    '#define PLUGIN_VERSION "1.0.0"',
    '#define PLUGIN_VERSION "1.1.0"',
    "Payloads version",
)
text = replace_once(
    text,
    "new bool:g_grenadeScheduled[MAX_EDICTS + 1];\n",
    "new bool:g_grenadeScheduled[MAX_EDICTS + 1];\n"
    "new bool:g_handGrenade[MAX_EDICTS + 1];\n",
    "hand grenade marker",
)
text = replace_once(
    text,
    "    // Hand/MP5 grenade payload.\n",
    "    // Hand grenade payload only. MP5 contact grenades remain stock.\n",
    "payload comment",
)
text = replace_once(
    text,
    '''    else if (containi(model, "grenade") >= 0)
    {
        g_grenadeScheduled[entity] = false;
    }
''',
    '''    else if (containi(model, "grenade") >= 0)
    {
        g_grenadeScheduled[entity] = false;
        g_handGrenade[entity] = containi(model, "w_grenade.mdl") >= 0;
    }
''',
    "grenade model classification",
)
text = replace_once(
    text,
    '''    if (equal(classname, "grenade"))
    {
        ScheduleGrenadePayload(entity, now);
    }
''',
    '''    if (equal(classname, "grenade") && g_handGrenade[entity])
    {
        ScheduleGrenadePayload(entity, now);
    }
''',
    "hand grenade payload gate",
)
text = replace_once(
    text,
    '''        g_grenadeScheduled[entity] = false;
        g_boltScheduled[entity] = false;
''',
    '''        g_grenadeScheduled[entity] = false;
        g_handGrenade[entity] = false;
        g_boltScheduled[entity] = false;
''',
    "hand grenade cleanup",
)
path.write_text(text, encoding="utf-8", newline="\n")

cfg = Path("configs/plugins/hldm_weapon_payloads.cfg")
cfg_text = cfg.read_text(encoding="utf-8")
cfg_text = cfg_text.replace(
    "// HLDM Weapon Payloads 1.0.0",
    "// HLDM Weapon Payloads 1.1.0",
    1,
)
cfg_text = cfg_text.replace(
    "// Grenade explosion payload: guided hornets appear after the native blast.",
    "// Hand-grenade payload only. MP5 underbarrel contact grenades stay stock.",
    1,
)
cfg.write_text(cfg_text, encoding="utf-8", newline="\n")
