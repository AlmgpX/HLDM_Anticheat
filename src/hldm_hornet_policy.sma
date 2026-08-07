#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Hornet Policy"
#define PLUGIN_VERSION "2.2.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_TRACKED 2048
#define W_HORNETGUN 11
#define TE_EXPLOSION_CUSTOM 3
#define TASK_SWEEP 61001
#define POLICY_MARKER 61021

new bool:g_tracked[MAX_TRACKED + 1];
new bool:g_exploding[MAX_TRACKED + 1];
new g_owner[MAX_TRACKED + 1];
new Float:g_spawnTime[MAX_TRACKED + 1];
new Float:g_expireTime[MAX_TRACKED + 1];
new Float:g_nextWorldTouch[MAX_TRACKED + 1];

new g_explosionSprite;
new g_pcvarEnabled;
new g_pcvarMaxActive;
new g_pcvarLifetime;
new g_pcvarDamage;
new g_pcvarRadius;
new g_pcvarOwnerGrace;
new g_pcvarBounceSpeed;
new g_pcvarDebug;

public plugin_precache()
{
    g_explosionSprite = precache_model("sprites/zerogxplode.spr");
    precache_model("models/hornet.mdl");
    precache_sound("weapons/explode3.wav");
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_hornetpolicy_status", "CmdStatus", ADMIN_RCON, "- show hornet ownership and cap state");

    g_pcvarEnabled = register_cvar("hldm_hornetpolicy_enabled", "1");
    g_pcvarMaxActive = register_cvar("hldm_hornetpolicy_max_active", "10");
    g_pcvarLifetime = register_cvar("hldm_hornetpolicy_lifetime", "3.20");
    g_pcvarDamage = register_cvar("hldm_hornetpolicy_damage", "40.0");
    g_pcvarRadius = register_cvar("hldm_hornetpolicy_radius", "96.0");
    g_pcvarOwnerGrace = register_cvar("hldm_hornetpolicy_owner_grace", "0.30");
    g_pcvarBounceSpeed = register_cvar("hldm_hornetpolicy_bounce_speed", "520.0");
    g_pcvarDebug = register_cvar("hldm_hornetpolicy_debug", "0");

    AutoExecConfig(true, "hldm_hornet_policy");

    register_forward(FM_Spawn, "OnSpawnPost", true);
    register_forward(FM_SetModel, "OnSetModelPost", true);
    register_forward(FM_Think, "OnThinkPre", false);
    register_forward(FM_Touch, "OnTouchPre", false);

    set_task(0.05, "TaskSweep", TASK_SWEEP, _, _, "b");
}

public OnSpawnPost(entity)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackable(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[24];
    pev(entity, pev_classname, classname, charsmax(classname));
    if (equal(classname, "hornet"))
    {
        TrackHornet(entity);
    }

    return FMRES_IGNORED;
}

public OnSetModelPost(entity, const model[])
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackable(entity))
    {
        return FMRES_IGNORED;
    }

    if (equali(model, "models/hornet.mdl"))
    {
        TrackHornet(entity);
    }

    return FMRES_IGNORED;
}

public OnThinkPre(entity)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsHornet(entity))
    {
        return FMRES_IGNORED;
    }

    TrackHornet(entity);
    if (!IsTrackable(entity) || !g_tracked[entity])
    {
        return FMRES_IGNORED;
    }

    if (get_gametime() >= g_expireTime[entity])
    {
        ExplodeHornet(entity);
        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public OnTouchPre(entity, other)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsHornet(entity))
    {
        return FMRES_IGNORED;
    }

    TrackHornet(entity);
    if (!IsTrackable(entity) || !g_tracked[entity])
    {
        return FMRES_IGNORED;
    }

    new owner = g_owner[entity];
    new Float:age = get_gametime() - g_spawnTime[entity];
    if (other == owner && age < ClampFloat(get_pcvar_float(g_pcvarOwnerGrace), 0.0, 1.5))
    {
        return FMRES_SUPERCEDE;
    }

    if (IsDamageTarget(other))
    {
        ExplodeHornet(entity);
        return FMRES_SUPERCEDE;
    }

    new Float:now = get_gametime();
    if (now >= g_nextWorldTouch[entity])
    {
        g_nextWorldTouch[entity] = now + 0.08;
        BounceHornet(entity);
    }
    return FMRES_SUPERCEDE;
}

public TaskSweep()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new entity = -1;
    new Float:now = get_gametime();

    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (!IsTrackable(entity))
        {
            continue;
        }

        TrackHornet(entity);
        if (!IsTrackable(entity) || !g_tracked[entity])
        {
            continue;
        }

        if (now >= g_expireTime[entity])
        {
            ExplodeHornet(entity);
        }
    }
}

public CmdStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    new total;
    new perOwner[33];
    new entity = -1;

    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (!IsTrackable(entity))
        {
            continue;
        }

        TrackHornet(entity);
        if (!IsTrackable(entity) || !g_tracked[entity])
        {
            continue;
        }

        total++;
        new owner = g_owner[entity];
        if (owner >= 1 && owner <= MaxClients)
        {
            perOwner[owner]++;
        }
    }

    console_print(id, "[HORNET POLICY] total=%d cap=%d lifetime=%.2f", total, ClampInt(get_pcvar_num(g_pcvarMaxActive), 1, 32), get_pcvar_float(g_pcvarLifetime));
    for (new owner = 1; owner <= MaxClients; owner++)
    {
        if (!perOwner[owner])
        {
            continue;
        }

        new name[32];
        get_user_name(owner, name, charsmax(name));
        console_print(id, "  #%d %s active=%d", get_user_userid(owner), name, perOwner[owner]);
    }

    return PLUGIN_HANDLED;
}

stock TrackHornet(entity)
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

    new owner = pev(entity, pev_owner);
    if (owner < 1 || owner > MaxClients || !is_user_connected(owner))
    {
        owner = InferOwner(entity);
    }

    new maximum = ClampInt(get_pcvar_num(g_pcvarMaxActive), 1, 32);
    if (owner >= 1 && owner <= MaxClients && CountOwnerHornets(owner) >= maximum)
    {
        if (get_pcvar_num(g_pcvarDebug))
        {
            log_amx("Hornet rejected without explosion: ent=%d owner=%d cap=%d", entity, owner, maximum);
        }

        engfunc(EngFunc_RemoveEntity, entity);
        return;
    }

    g_tracked[entity] = true;
    g_exploding[entity] = false;
    set_pev(entity, pev_iuser4, POLICY_MARKER);
    g_owner[entity] = owner;
    g_spawnTime[entity] = get_gametime();
    g_expireTime[entity] = g_spawnTime[entity] + ClampFloat(get_pcvar_float(g_pcvarLifetime), 0.5, 15.0);
    g_nextWorldTouch[entity] = 0.0;
}

stock CountOwnerHornets(owner)
{
    new count;
    new entity = -1;

    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (IsTrackable(entity)
            && g_tracked[entity]
            && pev(entity, pev_iuser4) == POLICY_MARKER
            && g_owner[entity] == owner)
        {
            count++;
        }
    }

    return count;
}

stock InferOwner(entity)
{
    new Float:origin[3];
    pev(entity, pev_origin, origin);

    new best;
    new Float:bestDistance = 192.0 * 192.0;

    for (new player = 1; player <= MaxClients; player++)
    {
        if (!is_user_alive(player) || get_user_weapon(player) != W_HORNETGUN)
        {
            continue;
        }

        new Float:playerOrigin[3];
        pev(player, pev_origin, playerOrigin);
        new Float:distance = DistanceSquared(origin, playerOrigin);
        if (distance < bestDistance)
        {
            bestDistance = distance;
            best = player;
        }
    }

    return best;
}

stock bool:IsDamageTarget(entity)
{
    if (entity >= 1 && entity <= MaxClients)
    {
        return bool:is_user_alive(entity);
    }

    if (!pev_valid(entity))
    {
        return false;
    }

    new classname[32];
    pev(entity, pev_classname, classname, charsmax(classname));
    return bool:(containi(classname, "monster_") == 0 || equal(classname, "func_breakable"));
}

stock BounceHornet(entity)
{
    if (!IsTrackable(entity))
    {
        return;
    }

    new Float:origin[3], Float:velocity[3];
    pev(entity, pev_origin, origin);
    pev(entity, pev_velocity, velocity);

    if (!NormalizeVector(velocity))
    {
        velocity[0] = random_float(-1.0, 1.0);
        velocity[1] = random_float(-1.0, 1.0);
        velocity[2] = random_float(-0.4, 1.0);
        NormalizeVector(velocity);
    }

    origin[0] -= velocity[0] * 8.0;
    origin[1] -= velocity[1] * 8.0;
    origin[2] -= velocity[2] * 8.0;
    set_pev(entity, pev_origin, origin);

    velocity[0] = -velocity[0] + random_float(-0.65, 0.65);
    velocity[1] = -velocity[1] + random_float(-0.65, 0.65);
    velocity[2] = -velocity[2] + random_float(-0.25, 0.75);
    NormalizeVector(velocity);

    new Float:speed = ClampFloat(get_pcvar_float(g_pcvarBounceSpeed), 180.0, 1200.0);
    velocity[0] *= speed;
    velocity[1] *= speed;
    velocity[2] *= speed;
    set_pev(entity, pev_velocity, velocity);
}

stock ExplodeHornet(entity)
{
    if (!IsTrackable(entity) || g_exploding[entity])
    {
        return;
    }

    g_exploding[entity] = true;

    new owner = g_owner[entity];
    new attacker = owner >= 1 && owner <= MaxClients && is_user_connected(owner) ? owner : entity;
    new Float:origin[3];
    pev(entity, pev_origin, origin);

    VisualExplosion(origin);
    RadiusDamage(entity, attacker, origin, ClampFloat(get_pcvar_float(g_pcvarDamage), 0.0, 200.0), ClampFloat(get_pcvar_float(g_pcvarRadius), 16.0, 512.0));
    engfunc(EngFunc_EmitSound, entity, CHAN_BODY, "weapons/explode3.wav", 0.65, ATTN_NORM, 0, 120);

    ResetEntity(entity);
    if (pev_valid(entity))
    {
        engfunc(EngFunc_RemoveEntity, entity);
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

stock VisualExplosion(const Float:origin[3])
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
    write_byte(TE_EXPLOSION_CUSTOM);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    write_short(g_explosionSprite);
    write_byte(5);
    write_byte(15);
    write_byte(0);
    message_end();
}

stock bool:IsHornet(entity)
{
    if (!IsTrackable(entity))
    {
        return false;
    }

    new classname[24];
    pev(entity, pev_classname, classname, charsmax(classname));
    return bool:equal(classname, "hornet");
}

stock bool:IsTrackable(entity)
{
    return bool:(entity > MaxClients && entity <= MAX_TRACKED && pev_valid(entity));
}

stock ResetEntity(entity)
{
    if (entity < 1 || entity > MAX_TRACKED)
    {
        return;
    }

    g_tracked[entity] = false;
    g_exploding[entity] = false;
    g_owner[entity] = 0;
    g_spawnTime[entity] = 0.0;
    g_expireTime[entity] = 0.0;
    g_nextWorldTouch[entity] = 0.0;
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
