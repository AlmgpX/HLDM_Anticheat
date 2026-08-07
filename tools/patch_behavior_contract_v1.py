from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f"Missing anchor: {label}")
    return text.replace(old, new, 1)


# -----------------------------------------------------------------------------
# Weapon Comedy 2.4.0
# -----------------------------------------------------------------------------
path = Path("src/hldm_weapon_comedy.sma")
text = path.read_text(encoding="utf-8")
text = replace_once(text, '#define PLUGIN_VERSION "2.3.0"', '#define PLUGIN_VERSION "2.4.0"', "Weapon Comedy version")

text = replace_once(
    text,
    'new Float:g_gaussCorrectionTime[33];\n',
    'new Float:g_gaussCorrectionTime[33];\n'
    'new Float:g_lastPythonShot[33];\n'
    'new bool:g_pythonPelletDamage[33];\n',
    "Python exact-hit state",
)

text = replace_once(
    text,
    'new g_pcvarPythonSelfDamageLethal;\n',
    'new g_pcvarPythonSelfDamageLethal;\n'
    'new g_pcvarPythonSuppressStockDamage;\n',
    "Python stock damage cvar declaration",
)

old_lines = '''new const g_factoryLines[][] =
{
    "MADE IN CHINA",
    "MADI EN INDIA",
    "RPG GUIDANCE PROVIDED BY CONFIDENCE",
    "ROCKET STABILIZER INSTALLED SIDEWAYS",
    "WARRANTY VALID UNTIL LAUNCH",
    "QUALITY CONTROL NOT INCLUDED",
    "ASSEMBLED FROM PREMIUM LEFTOVERS",
    "FACTORY TEST RESULT: IT LEFT THE TUBE",
    "TARGETING COMPUTER TRANSLATED THROUGH SIX LANGUAGES",
    "SAFE DISTANCE WAS SOLD SEPARATELY",
    "EXPORT MODEL: DOMESTIC SAFETY REMOVED",
    "ENGINEERED TO PASS INSPECTION, NOT COMBAT",
    "THE WARRANTY EXPLODED FIRST",
    "THIS TRAJECTORY IS WITHIN FACTORY TOLERANCE",
    "PREMIUM SELF-CORRECTION FEATURE ACTIVATED",
    "ASSEMBLED WITH CONFIDENCE, NOT MEASUREMENTS",
    "USER MANUAL PRINTED AFTER PRODUCTION ENDED",
    "FACTORY ZERO: SOMEWHERE IN FRONT OF YOU"
};
'''
new_lines = '''new const g_pythonLines[][] =
{
    "MADE IN CHINA HIGH-PRECISION REVOLVER",
    "MADI EN INDIA 16-PELLET CALIBRATION",
    "ACCURACY REPLACED WITH QUANTITY",
    "RECOIL COMPENSATOR INSTALLED BACKWARDS",
    "USER DAMAGE IS AN INTENDED FEATURE",
    "THE BARREL HAS SELECTED SIXTEEN DIRECTIONS",
    "FACTORY ZERO: SOMEWHERE IN FRONT OF YOU",
    "QUALITY CONTROL APPROVED THE LOUD PART",
    "CYLINDER ALIGNMENT IS WITHIN FACTORY TOLERANCE",
    "PREMIUM BALLISTICS CALCULATED BY ESTIMATION"
};

new const g_rpgLines[][] =
{
    "MADE IN CHINA RPG GUIDANCE",
    "MADI EN INDIA ROCKET STABILIZER",
    "RPG GUIDANCE PROVIDED BY CONFIDENCE",
    "ROCKET STABILIZER INSTALLED SIDEWAYS",
    "WARRANTY VALID UNTIL LAUNCH",
    "FACTORY TEST RESULT: IT LEFT THE TUBE",
    "TARGETING COMPUTER TRANSLATED THROUGH SIX LANGUAGES",
    "SAFE DISTANCE WAS SOLD SEPARATELY",
    "EXPORT MODEL: DOMESTIC SAFETY REMOVED",
    "THIS TRAJECTORY IS WITHIN FACTORY TOLERANCE"
};

new const g_gaussLines[][] =
{
    "MADE IN CHINA MAGNETIC CALIBRATION",
    "MADI EN INDIA COIL ALIGNMENT",
    "RECOIL VECTOR INSTALLED UPSIDE DOWN",
    "MAGNETIC FIELD PASSED VISUAL INSPECTION",
    "POLARITY LABELS WERE OPTIONAL",
    "ACCELERATOR COIL SYNCHRONIZED BY EAR",
    "FACTORY MANUAL RECOMMENDS NOT STANDING BEHIND IT",
    "ENERGY CONTAINMENT IS WITHIN FACTORY TOLERANCE",
    "PREMIUM PHYSICS MODULE SOLD SEPARATELY",
    "DIRECTION OF RECOIL MAY VARY BY REGION"
};
'''
text = replace_once(text, old_lines, new_lines, "factory message banks")

text = replace_once(
    text,
    '    g_pcvarPythonSelfDamageLethal = register_cvar("hldm_weaponcomedy_python_self_damage_lethal", "0");\n',
    '    g_pcvarPythonSelfDamageLethal = register_cvar("hldm_weaponcomedy_python_self_damage_lethal", "0");\n'
    '    g_pcvarPythonSuppressStockDamage = register_cvar("hldm_weaponcomedy_python_suppress_stock_pvp_damage", "1");\n',
    "Python stock damage registration",
)

text = replace_once(
    text,
    '    AutoExecConfig(true, "hldm_weapon_comedy");\n\n    register_forward(FM_CmdStart, "OnCmdStart", false);\n',
    '    AutoExecConfig(true, "hldm_weapon_comedy");\n\n'
    '    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage", false);\n'
    '    register_forward(FM_CmdStart, "OnCmdStart", false);\n',
    "Weapon Comedy Ham registration",
)

text = text.replace('        ShowFactoryLine(id);', '        ShowFactoryLine(id, W_RPG);', 1)
text = text.replace('        ShowFactoryLine(id);', '        ShowFactoryLine(id, W_GAUSS);', 1)

insert_after_cmd = '''    g_previousButtons[id] = buttons;
    return FMRES_IGNORED;
}

'''
player_damage = '''    g_previousButtons[id] = buttons;
    return FMRES_IGNORED;
}

public OnPlayerTakeDamage(victim, inflictor, attacker, Float:damage, damageBits)
{
    if (!get_pcvar_num(g_pcvarEnabled)
        || !get_pcvar_num(g_pcvarPythonSuppressStockDamage)
        || damage <= 0.0
        || !(damageBits & DMG_BULLET)
        || attacker < 1
        || attacker > MaxClients
        || attacker == victim
        || !is_user_connected(attacker)
        || g_pythonPelletDamage[attacker]
        || get_user_weapon(attacker) != W_PYTHON)
    {
        return HAM_IGNORED;
    }

    // Keep the native Python shot for ammo, animation and sound, but remove its
    // exact PvP damage. The actual hit pattern comes from the 16 scatter traces.
    if (get_gametime() - g_lastPythonShot[attacker] <= 0.10)
    {
        SetHamParamFloat(4, 0.0);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

'''
text = replace_once(text, insert_after_cmd, player_damage, "Python native damage suppressor")

text = replace_once(
    text,
    '''stock FirePythonScatter(id)
{
    ApplyPythonSelfDamage(id);
''',
    '''stock FirePythonScatter(id)
{
    g_lastPythonShot[id] = get_gametime();
    ApplyPythonSelfDamage(id);
''',
    "Python shot timestamp",
)

text = replace_once(
    text,
    '    ShowFactoryLine(id);\n}\n\nstock ApplyPythonSelfDamage',
    '    ShowFactoryLine(id, W_PYTHON);\n}\n\nstock ApplyPythonSelfDamage',
    "Python message routing",
)

text = replace_once(
    text,
    '''            ExecuteHamB(Ham_TakeDamage, hit, owner, owner, damage, DMG_BULLET);
''',
    '''            g_pythonPelletDamage[owner] = true;
            ExecuteHamB(Ham_TakeDamage, hit, owner, owner, damage, DMG_BULLET);
            g_pythonPelletDamage[owner] = false;
''',
    "Python pellet damage guard",
)

old_show = '''stock ShowFactoryLine(id)
{
    if (!is_user_connected(id)
        || random_num(1, 100) > ClampInt(get_pcvar_num(g_pcvarComedyChance), 0, 100))
    {
        return;
    }

    new line = random_num(0, sizeof g_factoryLines - 1);
    client_print(id, print_center, "%s", g_factoryLines[line]);
    if (random_num(0, 2) == 0)
    {
        client_print(id, print_chat, "[FACTORY] %s", g_factoryLines[line]);
    }
}
'''
new_show = '''stock ShowFactoryLine(id, weapon)
{
    if (!is_user_connected(id)
        || random_num(1, 100) > ClampInt(get_pcvar_num(g_pcvarComedyChance), 0, 100))
    {
        return;
    }

    new message[96];
    switch (weapon)
    {
        case W_PYTHON:
        {
            copy(message, charsmax(message), g_pythonLines[random_num(0, sizeof g_pythonLines - 1)]);
        }
        case W_RPG:
        {
            copy(message, charsmax(message), g_rpgLines[random_num(0, sizeof g_rpgLines - 1)]);
        }
        case W_GAUSS:
        {
            copy(message, charsmax(message), g_gaussLines[random_num(0, sizeof g_gaussLines - 1)]);
        }
        default:
        {
            return;
        }
    }

    client_print(id, print_center, "%s", message);
    if (random_num(0, 2) == 0)
    {
        client_print(id, print_chat, "[FACTORY] %s", message);
    }
}
'''
text = replace_once(text, old_show, new_show, "per-weapon factory routing")

text = replace_once(
    text,
    '''    g_gaussCorrectionPending[id] = false;
    g_gaussCorrectionTime[id] = 0.0;
''',
    '''    g_gaussCorrectionPending[id] = false;
    g_gaussCorrectionTime[id] = 0.0;
    g_lastPythonShot[id] = -9999.0;
    g_pythonPelletDamage[id] = false;
''',
    "Weapon Comedy reset state",
)
path.write_text(text, encoding="utf-8", newline="\n")

cfg = Path("configs/plugins/hldm_weapon_comedy.cfg")
cfg_text = cfg.read_text(encoding="utf-8")
cfg_text = cfg_text.replace("// HLDM Weapon Comedy 2.3.0", "// HLDM Weapon Comedy 2.4.0", 1)
cfg_text = replace_once(
    cfg_text,
    'hldm_weaponcomedy_python_self_damage_lethal "0"\n',
    'hldm_weaponcomedy_python_self_damage_lethal "0"\n'
    '// Keep native shot for ammo/animation/sound, but suppress exact PvP damage.\n'
    'hldm_weaponcomedy_python_suppress_stock_pvp_damage "1"\n',
    "Weapon Comedy config stock PvP damage",
)
cfg_text = cfg_text.replace(
    "// RPG launch and other factory comedy messages.",
    "// Per-weapon factory comedy for Python, RPG and Gauss. Egon has its own plugin.",
    1,
)
cfg.write_text(cfg_text, encoding="utf-8", newline="\n")


# -----------------------------------------------------------------------------
# Weapon Lab 1.3.0: remove duplicate ownership / legacy payload paths
# -----------------------------------------------------------------------------
path = Path("src/hldm_weapon_lab.sma")
text = path.read_text(encoding="utf-8")
text = replace_once(text, '#define PLUGIN_VERSION "1.2.0"', '#define PLUGIN_VERSION "1.3.0"', "Weapon Lab version")
text = text.replace('new g_pcvarGrenadeHornets;\n', '', 1)
text = text.replace('new g_pcvarRocketHornets;\n', '', 1)
text = text.replace('    g_pcvarGrenadeHornets = register_cvar("hldm_weaponlab_grenade_hornets", "3");\n', '', 1)
text = text.replace('    g_pcvarRocketHornets = register_cvar("hldm_weaponlab_rocket_hornets", "0");\n', '', 1)
text = replace_once(
    text,
    '    g_pcvarSnarkMax = register_cvar("hldm_weaponlab_snark_max", "6");\n',
    '    g_pcvarSnarkMax = register_cvar("hldm_weaponlab_snark_max", "30");\n',
    "Weapon Lab snark source default",
)

old_rocket_touch = '''    if (tag == TAG_ROCKET)
    {
        new marker = pev(entity, pev_iuser4);
        if (!marker)
        {
            set_pev(entity, pev_iuser4, 1);
            new owner = GetTaggedOwner(entity);
            new Float:origin[3];
            pev(entity, pev_origin, origin);
            VisualExplosion(origin, 6);
            SpawnHornetBurst(owner, origin, ClampInt(get_pcvar_num(g_pcvarRocketHornets), 0, 10));
        }
    }

'''
text = replace_once(text, old_rocket_touch, '', "remove duplicate RPG touch payload")

old_python_case = '''        case W_PYTHON:
        {
            if (pressed & IN_ATTACK)
            {
                ApplyBackRecoil(id, 210.0, 55.0);
            }
        }
'''
text = replace_once(text, old_python_case, '', "remove duplicate Python recoil")

old_gauss_case = '''        case W_GAUSS:
        {
            if (pressed & IN_ATTACK2)
            {
                ApplyBackRecoil(id, 460.0, 240.0);
            }
        }
'''
text = replace_once(text, old_gauss_case, '', "remove duplicate Gauss recoil")

old_grenade_payload = '''
        new Float:damageTime;
        pev(entity, pev_dmgtime, damageTime);
        if (damageTime > 0.0 && now >= damageTime - 0.18 && !pev(entity, pev_iuser4))
        {
            set_pev(entity, pev_iuser4, 1);
            new Float:origin[3];
            pev(entity, pev_origin, origin);
            SpawnHornetBurst(owner, origin, ClampInt(get_pcvar_num(g_pcvarGrenadeHornets), 0, 10));
        }
'''
text = replace_once(text, old_grenade_payload, '', "remove Weapon Lab grenade hornet payload")
text = replace_once(
    text,
    '    new maximum = ClampInt(get_pcvar_num(g_pcvarSnarkMax), 1, 24);\n',
    '    new maximum = ClampInt(get_pcvar_num(g_pcvarSnarkMax), 1, 64);\n',
    "snark max clamp",
)
path.write_text(text, encoding="utf-8", newline="\n")

cfg = Path("configs/plugins/hldm_weapon_lab.cfg")
cfg_text = cfg.read_text(encoding="utf-8")
cfg_text = cfg_text.replace("// HLDM Weapon Lab 1.2.0", "// HLDM Weapon Lab 1.3.0", 1)
cfg_text = cfg_text.replace(
    "// Hornet gun values are retained for Weapon Lab-created hornets. The dedicated\n// hldm_hornet_fix plugin enforces the native primary/secondary cap and explosions.\n",
    "// Legacy Hornet values are retained only for optional Weapon Lab-created hornets.\n// The dedicated hldm_hornet_policy plugin owns native hornet cap/touch/lifetime.\n",
    1,
)
cfg_text = cfg_text.replace(
    "// Grenade hornets are now created after the blast by hldm_weapon_payloads,\n// otherwise the native explosion kills them in the same frame.\nhldm_weaponlab_grenade_hornets \"0\"\nhldm_weaponlab_rocket_hornets \"0\"\n\n",
    "// Hand-grenade delayed hornets belong only to hldm_weapon_payloads.\n// RPG uses its stock rocket; Weapon Lab no longer adds a touch payload.\n\n",
    1,
)
cfg_text = cfg_text.replace(
    "// MP5 underbarrel stays stock for ordinary players. Hand grenades and\n// MP5 contact grenades return only under QUIET_BETRAYAL.\n// RPG comedy modifies the existing rocket only; no duplicate rockets.\n",
    "// MP5 underbarrel stays stock for ordinary players. Hand grenades and\n// MP5 contact grenades return only under QUIET_BETRAYAL.\n// RPG comedy modifies the existing stock rocket only; no duplicate touch payload.\n// Python and Gauss recoil are owned by hldm_weapon_comedy to avoid double impulses.\n",
    1,
)
cfg.write_text(cfg_text, encoding="utf-8", newline="\n")


# -----------------------------------------------------------------------------
# Hornet Policy 2.2.0: protect against stale edict-slot tracking
# -----------------------------------------------------------------------------
path = Path("src/hldm_hornet_policy.sma")
text = path.read_text(encoding="utf-8")
text = replace_once(text, '#define PLUGIN_VERSION "2.1.0"', '#define PLUGIN_VERSION "2.2.0"', "Hornet Policy version")
text = replace_once(
    text,
    '#define TASK_SWEEP 61001\n',
    '#define TASK_SWEEP 61001\n#define POLICY_MARKER 61021\n',
    "Hornet policy marker define",
)
old_track_head = '''stock TrackHornet(entity)
{
    if (!IsTrackable(entity) || g_tracked[entity])
    {
        return;
    }

'''
new_track_head = '''stock TrackHornet(entity)
{
    if (!IsTrackable(entity))
    {
        return;
    }

    if (g_tracked[entity] && pev(entity, pev_iuser4) == POLICY_MARKER)
    {
        return;
    }

    // GoldSrc can reuse an edict index after a native entity disappears.
    // If that slot belonged to an older hornet, clear the cached ownership/time.
    if (g_tracked[entity])
    {
        ResetEntity(entity);
    }

'''
text = replace_once(text, old_track_head, new_track_head, "Hornet stale slot reset")
text = replace_once(
    text,
    '''    g_tracked[entity] = true;
    g_exploding[entity] = false;
''',
    '''    g_tracked[entity] = true;
    g_exploding[entity] = false;
    set_pev(entity, pev_iuser4, POLICY_MARKER);
''',
    "Hornet policy marker assignment",
)
text = replace_once(
    text,
    '''        if (IsTrackable(entity) && g_tracked[entity] && g_owner[entity] == owner)
''',
    '''        if (IsTrackable(entity)
            && g_tracked[entity]
            && pev(entity, pev_iuser4) == POLICY_MARKER
            && g_owner[entity] == owner)
''',
    "Hornet policy marker count",
)
path.write_text(text, encoding="utf-8", newline="\n")

cfg = Path("configs/plugins/hldm_hornet_policy.cfg")
cfg_text = cfg.read_text(encoding="utf-8")
cfg_text = cfg_text.replace("// HLDM Hornet Policy 2.1.0", "// HLDM Hornet Policy 2.2.0", 1)
cfg_text += "\n// 2.2 tracks an ownership marker so reused GoldSrc edict slots cannot inherit stale hornet state.\n"
cfg.write_text(cfg_text, encoding="utf-8", newline="\n")
