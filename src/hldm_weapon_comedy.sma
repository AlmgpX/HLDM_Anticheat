#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Weapon Comedy"
#define PLUGIN_VERSION "2.3.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define TASK_TICK 62001

#define W_PYTHON 3
#define W_RPG 8
#define W_GAUSS 9

#define TE_TRACER_CUSTOM 6
#define TE_SPARKS_CUSTOM 9

new g_previousButtons[33];
new bool:g_gaussCorrectionPending[33];
new Float:g_gaussCorrectionTime[33];

new g_pcvarEnabled;
new g_pcvarPythonSelfDamage;
new g_pcvarPythonSelfDamageLethal;
new g_pcvarPythonPellets;
new g_pcvarPythonPelletDamage;
new g_pcvarPythonSpread;
new g_pcvarPythonRange;
new g_pcvarPythonRecoil;
new g_pcvarComedyChance;
new g_pcvarGaussImpulse;

new const g_factoryLines[][] =
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

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_weaponcomedy_status", "CmdStatus", ADMIN_RCON, "- show Weapon Comedy state");

    g_pcvarEnabled = register_cvar("hldm_weaponcomedy_enabled", "1");
    g_pcvarPythonSelfDamage = register_cvar("hldm_weaponcomedy_python_self_damage", "4.0");
    g_pcvarPythonSelfDamageLethal = register_cvar("hldm_weaponcomedy_python_self_damage_lethal", "0");
    g_pcvarPythonPellets = register_cvar("hldm_weaponcomedy_python_pellets", "16");
    g_pcvarPythonPelletDamage = register_cvar("hldm_weaponcomedy_python_pellet_damage", "3.0");
    g_pcvarPythonSpread = register_cvar("hldm_weaponcomedy_python_spread", "0.16");
    g_pcvarPythonRange = register_cvar("hldm_weaponcomedy_python_range", "4096.0");
    g_pcvarPythonRecoil = register_cvar("hldm_weaponcomedy_python_recoil", "220.0");
    g_pcvarComedyChance = register_cvar("hldm_weaponcomedy_text_chance", "38");
    g_pcvarGaussImpulse = register_cvar("hldm_weaponcomedy_gauss_impulse", "290.0");

    AutoExecConfig(true, "hldm_weapon_comedy");

    register_forward(FM_CmdStart, "OnCmdStart", false);
    set_task(0.05, "TaskTick", TASK_TICK, _, _, "b");
}

public client_connect(id)
{
    ResetClient(id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    ResetClient(id);
}

public OnCmdStart(id, userCmd, randomSeed)
{
    if (!get_pcvar_num(g_pcvarEnabled) || id < 1 || id > MaxClients || !is_user_alive(id))
    {
        return FMRES_IGNORED;
    }

    new buttons = get_uc(userCmd, UC_Buttons);
    new pressed = buttons & ~g_previousButtons[id];
    new weapon = get_user_weapon(id);
    new Float:now = get_gametime();

    if (weapon == W_PYTHON && (pressed & IN_ATTACK))
    {
        FirePythonScatter(id);
    }
    else if (weapon == W_RPG && (pressed & IN_ATTACK))
    {
        ShowFactoryLine(id);
    }
    else if (weapon == W_GAUSS && (pressed & IN_ATTACK2))
    {
        g_gaussCorrectionPending[id] = true;
        g_gaussCorrectionTime[id] = now + 0.04;
        ShowFactoryLine(id);
    }

    g_previousButtons[id] = buttons;
    return FMRES_IGNORED;
}

public TaskTick()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new Float:now = get_gametime();
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!g_gaussCorrectionPending[id] || now < g_gaussCorrectionTime[id])
        {
            continue;
        }

        g_gaussCorrectionPending[id] = false;
        if (is_user_alive(id))
        {
            ApplyGaussCorrection(id);
        }
    }
}

public CmdStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(
        id,
        "[WEAPON COMEDY] Python pellets=%d damage=%.1f zero-entity=1; MP5 untouched; RPG/Gauss enabled.",
        ClampInt(get_pcvar_num(g_pcvarPythonPellets), 1, 32),
        get_pcvar_float(g_pcvarPythonPelletDamage)
    );
    return PLUGIN_HANDLED;
}

stock FirePythonScatter(id)
{
    ApplyPythonSelfDamage(id);
    ApplyPythonRecoil(id);

    new count = ClampInt(get_pcvar_num(g_pcvarPythonPellets), 1, 32);
    for (new index = 0; index < count; index++)
    {
        FirePythonPellet(id);
    }

    ShowFactoryLine(id);
}

stock ApplyPythonSelfDamage(id)
{
    new Float:damage = ClampFloat(get_pcvar_float(g_pcvarPythonSelfDamage), 0.0, 100.0);
    if (damage <= 0.0 || !is_user_alive(id))
    {
        return;
    }

    if (!get_pcvar_num(g_pcvarPythonSelfDamageLethal))
    {
        new Float:health;
        pev(id, pev_health, health);
        new Float:maximumSafeDamage = health - 1.0;
        if (maximumSafeDamage <= 0.0)
        {
            return;
        }
        if (damage > maximumSafeDamage)
        {
            damage = maximumSafeDamage;
        }
    }

    ExecuteHamB(Ham_TakeDamage, id, id, id, damage, DMG_BULLET);
}

stock FirePythonPellet(owner)
{
    if (!is_user_alive(owner))
    {
        return;
    }

    new Float:start[3], Float:viewOffset[3], Float:angles[3];
    new Float:forwardVector[3], Float:rightVector[3], Float:upVector[3];
    new Float:direction[3], Float:end[3], Float:impact[3];

    pev(owner, pev_origin, start);
    pev(owner, pev_view_ofs, viewOffset);
    pev(owner, pev_v_angle, angles);
    start[0] += viewOffset[0];
    start[1] += viewOffset[1];
    start[2] += viewOffset[2];

    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);

    new Float:spread = ClampFloat(get_pcvar_float(g_pcvarPythonSpread), 0.01, 0.75);
    direction[0] = forwardVector[0]
        + rightVector[0] * random_float(-spread, spread)
        + upVector[0] * random_float(-spread, spread);
    direction[1] = forwardVector[1]
        + rightVector[1] * random_float(-spread, spread)
        + upVector[1] * random_float(-spread, spread);
    direction[2] = forwardVector[2]
        + rightVector[2] * random_float(-spread, spread)
        + upVector[2] * random_float(-spread, spread);

    if (!NormalizeVector(direction))
    {
        return;
    }

    new Float:range = ClampFloat(get_pcvar_float(g_pcvarPythonRange), 512.0, 8192.0);
    end[0] = start[0] + direction[0] * range;
    end[1] = start[1] + direction[1] * range;
    end[2] = start[2] + direction[2] * range;

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, owner, trace);

    new hit = get_tr2(trace, TR_pHit);
    get_tr2(trace, TR_vecEndPos, impact);

    DrawPythonTracer(start, impact);

    if (hit > 0 && pev_valid(hit) && pev(hit, pev_takedamage) != DAMAGE_NO)
    {
        new Float:damage = ClampFloat(get_pcvar_float(g_pcvarPythonPelletDamage), 0.0, 25.0);
        if (damage > 0.0)
        {
            ExecuteHamB(Ham_TakeDamage, hit, owner, owner, damage, DMG_BULLET);
        }
    }
    else
    {
        DrawImpactSparks(impact);
    }

    free_tr2(trace);
}

stock DrawPythonTracer(const Float:start[3], const Float:end[3])
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, start, 0);
    write_byte(TE_TRACER_CUSTOM);
    engfunc(EngFunc_WriteCoord, start[0]);
    engfunc(EngFunc_WriteCoord, start[1]);
    engfunc(EngFunc_WriteCoord, start[2]);
    engfunc(EngFunc_WriteCoord, end[0]);
    engfunc(EngFunc_WriteCoord, end[1]);
    engfunc(EngFunc_WriteCoord, end[2]);
    message_end();
}

stock DrawImpactSparks(const Float:origin[3])
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
    write_byte(TE_SPARKS_CUSTOM);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    message_end();
}

stock ApplyPythonRecoil(id)
{
    new Float:angles[3], Float:forwardVector[3], Float:rightVector[3], Float:upVector[3];
    new Float:velocity[3], Float:punch[3];

    pev(id, pev_v_angle, angles);
    pev(id, pev_velocity, velocity);
    pev(id, pev_punchangle, punch);
    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);

    new Float:recoil = ClampFloat(get_pcvar_float(g_pcvarPythonRecoil), 0.0, 800.0);
    velocity[0] -= forwardVector[0] * recoil;
    velocity[1] -= forwardVector[1] * recoil;
    velocity[2] += 60.0;
    set_pev(id, pev_velocity, velocity);

    punch[0] -= random_float(6.0, 10.0);
    punch[1] += random_float(-4.0, 4.0);
    punch[2] += random_float(-1.5, 1.5);
    set_pev(id, pev_punchangle, punch);
}

stock ApplyGaussCorrection(id)
{
    new Float:angles[3], Float:forwardVector[3], Float:rightVector[3], Float:upVector[3], Float:velocity[3];
    pev(id, pev_v_angle, angles);
    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);

    new Float:impulse = ClampFloat(get_pcvar_float(g_pcvarGaussImpulse), 80.0, 900.0);
    if (random_num(0, 2) == 0)
    {
        velocity[0] = random_float(-70.0, 70.0);
        velocity[1] = random_float(-70.0, 70.0);
        velocity[2] = -impulse;
    }
    else
    {
        new Float:direction = random_num(0, 1) ? 1.0 : -1.0;
        velocity[0] = rightVector[0] * impulse * direction + random_float(-50.0, 50.0);
        velocity[1] = rightVector[1] * impulse * direction + random_float(-50.0, 50.0);
        velocity[2] = random_float(-120.0, 80.0);
    }

    set_pev(id, pev_velocity, velocity);
}

stock ShowFactoryLine(id)
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

stock ResetClient(id)
{
    g_previousButtons[id] = 0;
    g_gaussCorrectionPending[id] = false;
    g_gaussCorrectionTime[id] = 0.0;
}

stock bool:NormalizeVector(Float:vector[3])
{
    new Float:length = floatsqroot(vector[0] * vector[0] + vector[1] * vector[1] + vector[2] * vector[2]);
    if (length <= 0.0001)
    {
        return false;
    }

    vector[0] /= length;
    vector[1] /= length;
    vector[2] /= length;
    return true;
}

stock ClampInt(value, minimumValue, maximumValue)
{
    if (value < minimumValue)
    {
        return minimumValue;
    }
    if (value > maximumValue)
    {
        return maximumValue;
    }
    return value;
}

stock Float:ClampFloat(Float:value, Float:minimumValue, Float:maximumValue)
{
    if (value < minimumValue)
    {
        return minimumValue;
    }
    if (value > maximumValue)
    {
        return maximumValue;
    }
    return value;
}
