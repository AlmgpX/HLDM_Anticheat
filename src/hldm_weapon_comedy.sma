#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Weapon Comedy"
#define PLUGIN_VERSION "2.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_TRACKED 2048
#define TASK_TICK 62001

#define W_PYTHON 3
#define W_MP5 4
#define W_GAUSS 9

#define TE_EXPLOSION_CUSTOM 3

new g_previousButtons[33];
new bool:g_secondRocketPending[33];
new Float:g_secondRocketTime[33];
new bool:g_gaussCorrectionPending[33];
new Float:g_gaussCorrectionTime[33];

new bool:g_customRocket[MAX_TRACKED + 1];
new g_rocketOwner[MAX_TRACKED + 1];
new Float:g_rocketSpawnTime[MAX_TRACKED + 1];

new g_explosionSprite;

new g_pcvarEnabled;
new g_pcvarPythonSelfDamage;
new g_pcvarPythonBolts;
new g_pcvarPythonSpread;
new g_pcvarPythonBoltSpeed;
new g_pcvarPythonRecoil;
new g_pcvarRocketDelay;
new g_pcvarRocketSpeed;
new g_pcvarRocketTurn;
new g_pcvarRocketSnarks;
new g_pcvarRocketDamage;
new g_pcvarRocketRadius;
new g_pcvarComedyChance;
new g_pcvarGaussImpulse;

new const g_factoryLines[][] =
{
    "MADE IN CHINA",
    "MADI EN INDIA",
    "SELF-DESTRUCT VACUUM CLEANER: EXPORT MODEL",
    "WARRANTY VALID UNTIL FIRST SHOT",
    "QUALITY CONTROL NOT INCLUDED",
    "ASSEMBLED FROM PREMIUM LEFTOVERS",
    "FACTORY TEST RESULT: IT TURNED ON ONCE",
    "RECOIL COMPENSATOR INSTALLED BACKWARDS",
    "USER DAMAGE IS AN INTENDED FEATURE",
    "THE BARREL HAS SELECTED SIXTEEN DIRECTIONS",
    "FACTORY ZERO: SOMEWHERE IN FRONT OF YOU",
    "MISSILE GUIDANCE PROVIDED BY CONFIDENCE",
    "SECOND ROCKET ADDED AFTER CUSTOMER COMPLAINTS",
    "SAFE LAUNCH DISTANCE WAS NOT TRANSLATED",
    "ENGINEERED TO PASS INSPECTION, NOT COMBAT",
    "THE WARRANTY EXPLODED FIRST",
    "THIS FAILURE IS WITHIN FACTORY TOLERANCE",
    "PREMIUM SELF-DISASSEMBLY FEATURE ACTIVATED",
    "ASSEMBLED WITH CONFIDENCE, NOT MEASUREMENTS",
    "THE MANUAL WAS TRANSLATED THROUGH SIX LANGUAGES"
};

public plugin_precache()
{
    g_explosionSprite = precache_model("sprites/zerogxplode.spr");
    precache_model("models/crossbow_bolt.mdl");
    precache_model("models/rpgrocket.mdl");
    precache_model("models/w_squeak.mdl");
    precache_sound("weapons/rocketfire1.wav");
    precache_sound("weapons/explode3.wav");
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_weaponcomedy_status", "CmdStatus", ADMIN_RCON, "- show custom rocket state");

    g_pcvarEnabled = register_cvar("hldm_weaponcomedy_enabled", "1");
    g_pcvarPythonSelfDamage = register_cvar("hldm_weaponcomedy_python_self_damage", "5.0");
    g_pcvarPythonBolts = register_cvar("hldm_weaponcomedy_python_bolts", "16");
    g_pcvarPythonSpread = register_cvar("hldm_weaponcomedy_python_spread", "0.19");
    g_pcvarPythonBoltSpeed = register_cvar("hldm_weaponcomedy_python_bolt_speed", "1500.0");
    g_pcvarPythonRecoil = register_cvar("hldm_weaponcomedy_python_recoil", "260.0");
    g_pcvarRocketDelay = register_cvar("hldm_weaponcomedy_second_rocket_delay", "0.30");
    g_pcvarRocketSpeed = register_cvar("hldm_weaponcomedy_rocket_speed", "720.0");
    g_pcvarRocketTurn = register_cvar("hldm_weaponcomedy_rocket_turn", "0.28");
    g_pcvarRocketSnarks = register_cvar("hldm_weaponcomedy_rocket_snarks", "3");
    g_pcvarRocketDamage = register_cvar("hldm_weaponcomedy_rocket_damage", "95.0");
    g_pcvarRocketRadius = register_cvar("hldm_weaponcomedy_rocket_radius", "180.0");
    g_pcvarComedyChance = register_cvar("hldm_weaponcomedy_text_chance", "38");
    g_pcvarGaussImpulse = register_cvar("hldm_weaponcomedy_gauss_impulse", "290.0");

    AutoExecConfig(true, "hldm_weapon_comedy");

    register_forward(FM_CmdStart, "OnCmdStart", false);
    register_forward(FM_Touch, "OnTouchPre", false);
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
    else if (weapon == W_MP5 && (pressed & IN_ATTACK2))
    {
        buttons &= ~IN_ATTACK2;
        set_uc(userCmd, UC_Buttons, buttons);

        SpawnHomingRocket(id, 0.0);
        g_secondRocketPending[id] = true;
        g_secondRocketTime[id] = now + ClampFloat(get_pcvar_float(g_pcvarRocketDelay), 0.10, 1.5);
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

public OnTouchPre(entity, other)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackable(entity) || !g_customRocket[entity])
    {
        return FMRES_IGNORED;
    }

    new owner = g_rocketOwner[entity];
    if (other == owner && get_gametime() - g_rocketSpawnTime[entity] < 0.55)
    {
        return FMRES_SUPERCEDE;
    }

    ExplodeRocket(entity);
    return FMRES_SUPERCEDE;
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
        if (g_secondRocketPending[id] && now >= g_secondRocketTime[id])
        {
            g_secondRocketPending[id] = false;
            if (is_user_alive(id))
            {
                SpawnHomingRocket(id, 14.0);
            }
        }

        if (g_gaussCorrectionPending[id] && now >= g_gaussCorrectionTime[id])
        {
            g_gaussCorrectionPending[id] = false;
            if (is_user_alive(id))
            {
                ApplyGaussCorrection(id);
            }
        }
    }

    ProcessRockets();
}

public CmdStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    new count;
    for (new entity = MaxClients + 1; entity <= MAX_TRACKED; entity++)
    {
        if (g_customRocket[entity] && pev_valid(entity))
        {
            count++;
        }
    }

    console_print(id, "[WEAPON COMEDY] active custom rockets=%d", count);
    return PLUGIN_HANDLED;
}

stock FirePythonScatter(id)
{
    new Float:selfDamage = ClampFloat(get_pcvar_float(g_pcvarPythonSelfDamage), 0.0, 100.0);
    if (selfDamage > 0.0)
    {
        ExecuteHamB(Ham_TakeDamage, id, id, id, selfDamage, DMG_BULLET);
    }

    ApplyPythonRecoil(id);

    new count = ClampInt(get_pcvar_num(g_pcvarPythonBolts), 1, 32);
    for (new index = 0; index < count; index++)
    {
        SpawnScatterBolt(id);
    }

    ShowFactoryLine(id);
}

stock SpawnScatterBolt(owner)
{
    if (!is_user_alive(owner))
    {
        return 0;
    }

    new Float:origin[3], Float:viewOffset[3], Float:angles[3];
    new Float:forwardVector[3], Float:right[3], Float:up[3], Float:velocity[3];

    pev(owner, pev_origin, origin);
    pev(owner, pev_view_ofs, viewOffset);
    pev(owner, pev_v_angle, angles);
    origin[0] += viewOffset[0];
    origin[1] += viewOffset[1];
    origin[2] += viewOffset[2];

    engfunc(EngFunc_AngleVectors, angles, forwardVector, right, up);
    origin[0] += forwardVector[0] * 24.0;
    origin[1] += forwardVector[1] * 24.0;
    origin[2] += forwardVector[2] * 24.0;

    new Float:spread = ClampFloat(get_pcvar_float(g_pcvarPythonSpread), 0.01, 0.75);
    velocity[0] = forwardVector[0] + right[0] * random_float(-spread, spread) + up[0] * random_float(-spread, spread);
    velocity[1] = forwardVector[1] + right[1] * random_float(-spread, spread) + up[1] * random_float(-spread, spread);
    velocity[2] = forwardVector[2] + right[2] * random_float(-spread, spread) + up[2] * random_float(-spread, spread);
    NormalizeVector(velocity);

    new Float:speed = ClampFloat(get_pcvar_float(g_pcvarPythonBoltSpeed), 500.0, 2600.0);
    velocity[0] *= speed;
    velocity[1] *= speed;
    velocity[2] *= speed;

    new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "crossbow_bolt"));
    if (!pev_valid(entity))
    {
        return 0;
    }

    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_owner, owner);
    dllfunc(DLLFunc_Spawn, entity);
    set_pev(entity, pev_velocity, velocity);
    return entity;
}

stock ApplyPythonRecoil(id)
{
    new Float:angles[3], Float:forwardVector[3], Float:right[3], Float:up[3], Float:velocity[3], Float:punch[3];
    pev(id, pev_v_angle, angles);
    pev(id, pev_velocity, velocity);
    pev(id, pev_punchangle, punch);
    engfunc(EngFunc_AngleVectors, angles, forwardVector, right, up);

    new Float:recoil = ClampFloat(get_pcvar_float(g_pcvarPythonRecoil), 0.0, 800.0);
    velocity[0] -= forwardVector[0] * recoil;
    velocity[1] -= forwardVector[1] * recoil;
    velocity[2] += 75.0;
    set_pev(id, pev_velocity, velocity);

    punch[0] -= random_float(7.0, 13.0);
    punch[1] += random_float(-5.0, 5.0);
    punch[2] += random_float(-2.0, 2.0);
    set_pev(id, pev_punchangle, punch);
}

stock SpawnHomingRocket(owner, Float:sideOffset)
{
    if (!is_user_alive(owner))
    {
        return 0;
    }

    new Float:origin[3], Float:viewOffset[3], Float:angles[3];
    new Float:forwardVector[3], Float:right[3], Float:up[3], Float:velocity[3];
    pev(owner, pev_origin, origin);
    pev(owner, pev_view_ofs, viewOffset);
    pev(owner, pev_v_angle, angles);
    origin[0] += viewOffset[0];
    origin[1] += viewOffset[1];
    origin[2] += viewOffset[2];

    engfunc(EngFunc_AngleVectors, angles, forwardVector, right, up);
    origin[0] += forwardVector[0] * 58.0 + right[0] * sideOffset;
    origin[1] += forwardVector[1] * 58.0 + right[1] * sideOffset;
    origin[2] += forwardVector[2] * 58.0 + 4.0;

    new Float:speed = ClampFloat(get_pcvar_float(g_pcvarRocketSpeed), 300.0, 1600.0);
    velocity[0] = forwardVector[0] * speed;
    velocity[1] = forwardVector[1] * speed;
    velocity[2] = forwardVector[2] * speed;

    new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "rpg_rocket"));
    if (!IsTrackable(entity))
    {
        return 0;
    }

    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_owner, owner);
    dllfunc(DLLFunc_Spawn, entity);
    set_pev(entity, pev_velocity, velocity);

    g_customRocket[entity] = true;
    g_rocketOwner[entity] = owner;
    g_rocketSpawnTime[entity] = get_gametime();

    engfunc(EngFunc_EmitSound, entity, CHAN_WEAPON, "weapons/rocketfire1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM);
    return entity;
}

stock ProcessRockets()
{
    new Float:turn = ClampFloat(get_pcvar_float(g_pcvarRocketTurn), 0.02, 0.95);
    new Float:speed = ClampFloat(get_pcvar_float(g_pcvarRocketSpeed), 300.0, 1600.0);

    for (new entity = MaxClients + 1; entity <= MAX_TRACKED; entity++)
    {
        if (!g_customRocket[entity])
        {
            continue;
        }

        if (!pev_valid(entity))
        {
            ResetRocket(entity);
            continue;
        }

        if (get_gametime() - g_rocketSpawnTime[entity] > 8.0)
        {
            ExplodeRocket(entity);
            continue;
        }

        new target = FindNearestTarget(entity, g_rocketOwner[entity]);
        if (!target)
        {
            continue;
        }

        new Float:origin[3], Float:targetOrigin[3], Float:desired[3], Float:current[3];
        pev(entity, pev_origin, origin);
        pev(target, pev_origin, targetOrigin);
        targetOrigin[2] += 30.0;

        desired[0] = targetOrigin[0] - origin[0];
        desired[1] = targetOrigin[1] - origin[1];
        desired[2] = targetOrigin[2] - origin[2];
        if (!NormalizeVector(desired))
        {
            continue;
        }

        pev(entity, pev_velocity, current);
        NormalizeVector(current);
        current[0] = current[0] * (1.0 - turn) + desired[0] * turn;
        current[1] = current[1] * (1.0 - turn) + desired[1] * turn;
        current[2] = current[2] * (1.0 - turn) + desired[2] * turn;
        NormalizeVector(current);

        current[0] *= speed;
        current[1] *= speed;
        current[2] *= speed;
        set_pev(entity, pev_velocity, current);
    }
}

stock FindNearestTarget(entity, owner)
{
    new Float:origin[3];
    pev(entity, pev_origin, origin);

    new best;
    new Float:bestDistance = 4096.0 * 4096.0;
    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_alive(target) || target == owner)
        {
            continue;
        }

        new Float:targetOrigin[3];
        pev(target, pev_origin, targetOrigin);
        new Float:distance = DistanceSquared(origin, targetOrigin);
        if (distance < bestDistance)
        {
            bestDistance = distance;
            best = target;
        }
    }

    return best;
}

stock ExplodeRocket(entity)
{
    if (!IsTrackable(entity) || !g_customRocket[entity])
    {
        return;
    }

    new owner = g_rocketOwner[entity];
    new attacker = owner >= 1 && owner <= MaxClients && is_user_connected(owner) ? owner : entity;
    new Float:origin[3];
    pev(entity, pev_origin, origin);

    VisualExplosion(origin, 9);
    RadiusDamage(entity, attacker, origin, ClampFloat(get_pcvar_float(g_pcvarRocketDamage), 0.0, 300.0), ClampFloat(get_pcvar_float(g_pcvarRocketRadius), 32.0, 512.0));
    SpawnSnarkBurst(owner, origin, ClampInt(get_pcvar_num(g_pcvarRocketSnarks), 0, 8));
    engfunc(EngFunc_EmitSound, entity, CHAN_BODY, "weapons/explode3.wav", 0.85, ATTN_NORM, 0, 105);

    ResetRocket(entity);
    if (pev_valid(entity))
    {
        engfunc(EngFunc_RemoveEntity, entity);
    }
}

stock SpawnSnarkBurst(owner, const Float:origin[3], count)
{
    for (new index = 0; index < count; index++)
    {
        new Float:spawnOrigin[3], Float:velocity[3];
        spawnOrigin[0] = origin[0] + random_float(-18.0, 18.0);
        spawnOrigin[1] = origin[1] + random_float(-18.0, 18.0);
        spawnOrigin[2] = origin[2] + random_float(12.0, 28.0);

        velocity[0] = random_float(-240.0, 240.0);
        velocity[1] = random_float(-240.0, 240.0);
        velocity[2] = random_float(220.0, 380.0);

        new snark = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "monster_snark"));
        if (!pev_valid(snark))
        {
            continue;
        }

        set_pev(snark, pev_origin, spawnOrigin);
        set_pev(snark, pev_owner, owner);
        dllfunc(DLLFunc_Spawn, snark);
        set_pev(snark, pev_velocity, velocity);
    }
}

stock ApplyGaussCorrection(id)
{
    new Float:angles[3], Float:forwardVector[3], Float:right[3], Float:up[3], Float:velocity[3];
    pev(id, pev_v_angle, angles);
    engfunc(EngFunc_AngleVectors, angles, forwardVector, right, up);

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
        velocity[0] = right[0] * impulse * direction + random_float(-50.0, 50.0);
        velocity[1] = right[1] * impulse * direction + random_float(-50.0, 50.0);
        velocity[2] = random_float(-120.0, 80.0);
    }

    set_pev(id, pev_velocity, velocity);
}

stock ShowFactoryLine(id)
{
    if (!is_user_connected(id) || random_num(1, 100) > ClampInt(get_pcvar_num(g_pcvarComedyChance), 0, 100))
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

stock RadiusDamage(inflictor, attacker, const Float:origin[3], Float:maximumDamage, Float:radius)
{
    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_alive(target))
        {
            continue;
        }

        new Float:targetOrigin[3];
        pev(target, pev_origin, targetOrigin);
        new Float:distance = floatsqroot(DistanceSquared(origin, targetOrigin));
        if (distance > radius)
        {
            continue;
        }

        new Float:damage = maximumDamage * (1.0 - distance / radius);
        if (damage < 1.0)
        {
            damage = 1.0;
        }

        ExecuteHamB(Ham_TakeDamage, target, inflictor, attacker, damage, DMG_BLAST);
    }
}

stock VisualExplosion(const Float:origin[3], scale)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
    write_byte(TE_EXPLOSION_CUSTOM);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    write_short(g_explosionSprite);
    write_byte(ClampInt(scale, 1, 20));
    write_byte(15);
    write_byte(0);
    message_end();
}

stock bool:IsTrackable(entity)
{
    return bool:(entity > MaxClients && entity <= MAX_TRACKED && pev_valid(entity));
}

stock ResetRocket(entity)
{
    if (entity < 1 || entity > MAX_TRACKED)
    {
        return;
    }

    g_customRocket[entity] = false;
    g_rocketOwner[entity] = 0;
    g_rocketSpawnTime[entity] = 0.0;
}

stock ResetClient(id)
{
    g_previousButtons[id] = 0;
    g_secondRocketPending[id] = false;
    g_secondRocketTime[id] = 0.0;
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

stock Float:DistanceSquared(const Float:left[3], const Float:right[3])
{
    new Float:x = left[0] - right[0];
    new Float:y = left[1] - right[1];
    new Float:z = left[2] - right[2];
    return x * x + y * y + z * z;
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
