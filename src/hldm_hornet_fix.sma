#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Hornet Hard Fix"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define MAX_TRACKED_ENTITIES 2048
#define TASK_SWEEP 57001
#define W_HORNETGUN 11
#define TE_EXPLOSION_CUSTOM 3

new bool:g_tracked[MAX_TRACKED_ENTITIES + 1];
new bool:g_exploding[MAX_TRACKED_ENTITIES + 1];
new g_owner[MAX_TRACKED_ENTITIES + 1];
new Float:g_spawnTime[MAX_TRACKED_ENTITIES + 1];
new Float:g_expireTime[MAX_TRACKED_ENTITIES + 1];

new g_explosionSprite;

new g_pcvarEnabled;
new g_pcvarMaxActive;
new g_pcvarLifetime;
new g_pcvarDamage;
new g_pcvarRadius;
new g_pcvarOwnerGrace;
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

    register_concmd("amx_hornetfix_status", "CmdStatus", ADMIN_RCON, "- show tracked native hornets per owner");

    g_pcvarEnabled = register_cvar("hldm_hornetfix_enabled", "1");
    g_pcvarMaxActive = register_cvar("hldm_hornetfix_max_active", "10");
    g_pcvarLifetime = register_cvar("hldm_hornetfix_lifetime", "3.35");
    g_pcvarDamage = register_cvar("hldm_hornetfix_damage", "40.0");
    g_pcvarRadius = register_cvar("hldm_hornetfix_radius", "96.0");
    g_pcvarOwnerGrace = register_cvar("hldm_hornetfix_owner_grace", "0.25");
    g_pcvarDebug = register_cvar("hldm_hornetfix_debug", "0");

    AutoExecConfig(true, "hldm_hornet_fix");

    register_forward(FM_SetModel, "OnSetModelPost", true);
    register_forward(FM_Spawn, "OnSpawnPost", true);
    register_forward(FM_Think, "OnThinkPre", false);
    register_forward(FM_Touch, "OnTouchPre", false);

    set_task(0.05, "TaskSweep", TASK_SWEEP, _, _, "b");
}

public OnSpawnPost(entity)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackableEntity(entity))
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
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackableEntity(entity))
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
    if (!get_pcvar_num(g_pcvarEnabled) || !IsHornetEntity(entity))
    {
        return FMRES_IGNORED;
    }

    EnsureTracked(entity);

    if (!IsTrackableEntity(entity) || !g_tracked[entity])
    {
        return FMRES_IGNORED;
    }

    new Float:now = get_gametime();
    if (g_expireTime[entity] > 0.0 && now >= g_expireTime[entity])
    {
        ExplodeHornet(entity);
        return FMRES_SUPERCEDE;
    }

    return FMRES_IGNORED;
}

public OnTouchPre(entity, other)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsHornetEntity(entity))
    {
        return FMRES_IGNORED;
    }

    EnsureTracked(entity);

    if (!IsTrackableEntity(entity) || !g_tracked[entity])
    {
        return FMRES_IGNORED;
    }

    new owner = g_owner[entity];
    new Float:age = get_gametime() - g_spawnTime[entity];
    new Float:grace = ClampFloat(get_pcvar_float(g_pcvarOwnerGrace), 0.0, 1.0);

    if (other == owner && age < grace)
    {
        return FMRES_IGNORED;
    }

    ExplodeHornet(entity);
    return FMRES_SUPERCEDE;
}

public TaskSweep()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new Float:now = get_gametime();
    new entity = -1;

    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (!IsTrackableEntity(entity))
        {
            continue;
        }

        EnsureTracked(entity);

        if (!IsTrackableEntity(entity) || !g_tracked[entity])
        {
            continue;
        }

        new Float:age = now - g_spawnTime[entity];
        new Float:grace = ClampFloat(get_pcvar_float(g_pcvarOwnerGrace), 0.0, 1.0);

        if (age >= grace && (pev(entity, pev_modelindex) == 0 || pev(entity, pev_solid) == SOLID_NOT))
        {
            ExplodeHornet(entity);
            continue;
        }

        if (g_expireTime[entity] > 0.0 && now >= g_expireTime[entity])
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
    new tracked;
    new untracked;
    new perOwner[MAX_PLAYERS + 1];

    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (!IsTrackableEntity(entity))
        {
            continue;
        }

        total++;
        if (g_tracked[entity])
        {
            tracked++;
            new owner = g_owner[entity];
            if (owner >= 1 && owner <= MaxClients)
            {
                perOwner[owner]++;
            }
        }
        else
        {
            untracked++;
        }
    }

    console_print(
        id,
        "[HORNET FIX] total=%d tracked=%d untracked=%d max_active=%d lifetime=%.2f",
        total,
        tracked,
        untracked,
        ClampInt(get_pcvar_num(g_pcvarMaxActive), 1, 32),
        get_pcvar_float(g_pcvarLifetime)
    );

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

stock EnsureTracked(entity)
{
    if (!IsTrackableEntity(entity) || g_tracked[entity])
    {
        return;
    }

    TrackHornet(entity);
}

stock TrackHornet(entity)
{
    if (!IsTrackableEntity(entity) || g_tracked[entity])
    {
        return;
    }

    new owner = pev(entity, pev_owner);
    if (owner < 1 || owner > MaxClients || !is_user_connected(owner))
    {
        owner = InferOwner(entity);
    }

    g_tracked[entity] = true;
    g_exploding[entity] = false;
    g_owner[entity] = owner;
    g_spawnTime[entity] = get_gametime();
    g_expireTime[entity] = g_spawnTime[entity] + ClampFloat(get_pcvar_float(g_pcvarLifetime), 0.4, 10.0);

    if (get_pcvar_num(g_pcvarDebug))
    {
        log_amx("Hornet tracked: ent=%d owner=%d", entity, owner);
    }

    EnforceOwnerLimit(owner);
}

stock EnforceOwnerLimit(owner)
{
    if (owner < 1 || owner > MaxClients)
    {
        return;
    }

    new maximum = ClampInt(get_pcvar_num(g_pcvarMaxActive), 1, 32);

    while (CountOwnerHornets(owner) > maximum)
    {
        new oldest = FindOldestOwnerHornet(owner);
        if (!oldest)
        {
            break;
        }

        ExplodeHornet(oldest);
    }
}

stock CountOwnerHornets(owner)
{
    new count;
    new entity = -1;

    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (IsTrackableEntity(entity) && g_tracked[entity] && g_owner[entity] == owner)
        {
            count++;
        }
    }

    return count;
}

stock FindOldestOwnerHornet(owner)
{
    new oldest;
    new Float:oldestTime = 999999999.0;
    new entity = -1;

    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (!IsTrackableEntity(entity) || !g_tracked[entity] || g_owner[entity] != owner)
        {
            continue;
        }

        if (g_spawnTime[entity] < oldestTime)
        {
            oldestTime = g_spawnTime[entity];
            oldest = entity;
        }
    }

    return oldest;
}

stock InferOwner(entity)
{
    new Float:hornetOrigin[3];
    pev(entity, pev_origin, hornetOrigin);

    new bestPlayer;
    new Float:bestDistanceSquared = 192.0 * 192.0;

    for (new player = 1; player <= MaxClients; player++)
    {
        if (!is_user_alive(player) || get_user_weapon(player) != W_HORNETGUN)
        {
            continue;
        }

        new Float:playerOrigin[3];
        pev(player, pev_origin, playerOrigin);
        new Float:distanceSquared = VectorDistanceSquared(hornetOrigin, playerOrigin);

        if (distanceSquared < bestDistanceSquared)
        {
            bestDistanceSquared = distanceSquared;
            bestPlayer = player;
        }
    }

    return bestPlayer;
}

stock ExplodeHornet(entity)
{
    if (!IsTrackableEntity(entity) || g_exploding[entity])
    {
        return;
    }

    g_exploding[entity] = true;

    new owner = g_owner[entity];
    new attacker = owner >= 1 && owner <= MaxClients && is_user_connected(owner) ? owner : entity;

    new Float:origin[3];
    pev(entity, pev_origin, origin);

    VisualExplosion(origin);
    RadiusDamage(
        entity,
        attacker,
        origin,
        ClampFloat(get_pcvar_float(g_pcvarDamage), 0.0, 200.0),
        ClampFloat(get_pcvar_float(g_pcvarRadius), 16.0, 512.0)
    );

    engfunc(EngFunc_EmitSound, entity, CHAN_BODY, "weapons/explode3.wav", 0.65, ATTN_NORM, 0, 120);

    ResetTrackedEntity(entity);
    if (pev_valid(entity))
    {
        engfunc(EngFunc_RemoveEntity, entity);
    }
}

stock RadiusDamage(inflictor, attacker, const Float:origin[3], Float:maximumDamage, Float:radius)
{
    if (maximumDamage <= 0.0 || radius <= 0.0)
    {
        return;
    }

    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_alive(target))
        {
            continue;
        }

        new Float:targetOrigin[3];
        pev(target, pev_origin, targetOrigin);
        new Float:distance = floatsqroot(VectorDistanceSquared(origin, targetOrigin));
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

stock bool:IsHornetEntity(entity)
{
    if (!IsTrackableEntity(entity))
    {
        return false;
    }

    new classname[24];
    pev(entity, pev_classname, classname, charsmax(classname));
    return equal(classname, "hornet");
}

stock bool:IsTrackableEntity(entity)
{
    return entity > MaxClients && entity <= MAX_TRACKED_ENTITIES && pev_valid(entity);
}

stock ResetTrackedEntity(entity)
{
    if (entity < 1 || entity > MAX_TRACKED_ENTITIES)
    {
        return;
    }

    g_tracked[entity] = false;
    g_exploding[entity] = false;
    g_owner[entity] = 0;
    g_spawnTime[entity] = 0.0;
    g_expireTime[entity] = 0.0;
}

stock Float:VectorDistanceSquared(const Float:left[3], const Float:right[3])
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
