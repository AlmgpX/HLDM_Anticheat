#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Weapon Payloads"
#define PLUGIN_VERSION "1.1.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define MAX_EDICTS 2048
#define MAX_EVENTS 64
#define TASK_PAYLOAD_TICK 58001

#define EVENT_NONE 0
#define EVENT_GRENADE_HORNETS 1
#define EVENT_CROSSBOW_SNARKS 2

#define TE_EXPLOSION_CUSTOM 3

new bool:g_grenadeScheduled[MAX_EDICTS + 1];
new bool:g_handGrenade[MAX_EDICTS + 1];
new bool:g_boltScheduled[MAX_EDICTS + 1];

new bool:g_incubatingSnark[MAX_EDICTS + 1];
new Float:g_snarkReleaseTime[MAX_EDICTS + 1];
new Float:g_snarkReleaseOrigin[MAX_EDICTS + 1][3];
new g_snarkOwner[MAX_EDICTS + 1];

new bool:g_guidedHornet[MAX_EDICTS + 1];
new g_guidedOwner[MAX_EDICTS + 1];

new bool:g_eventActive[MAX_EVENTS];
new g_eventType[MAX_EVENTS];
new g_eventOwner[MAX_EVENTS];
new Float:g_eventTime[MAX_EVENTS];
new Float:g_eventOrigin[MAX_EVENTS][3];

new g_explosionSprite;

new g_pcvarEnabled;
new g_pcvarSatchelReleaseDelay;
new g_pcvarSatchelDetectRadius;
new g_pcvarGrenadeHornets;
new g_pcvarGrenadeSpawnDelay;
new g_pcvarHornetSpeed;
new g_pcvarHornetTurnSpeed;
new g_pcvarCrossbowSnarks;
new g_pcvarCrossbowSpawnDelay;
new g_pcvarCrossbowExplosionDamage;
new g_pcvarCrossbowExplosionRadius;
new g_pcvarDebug;

public plugin_precache()
{
    g_explosionSprite = precache_model("sprites/zerogxplode.spr");
    precache_model("models/hornet.mdl");
    precache_model("models/w_squeak.mdl");
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_payload_status", "CmdPayloadStatus", ADMIN_RCON, "- show delayed payload state");

    g_pcvarEnabled = register_cvar("hldm_payload_enabled", "1");

    // Existing Weapon Lab creates satchel snarks before the native blast.
    // Hide and protect them, then release them after the explosion has ended.
    g_pcvarSatchelReleaseDelay = register_cvar("hldm_payload_satchel_release_delay", "0.85");
    g_pcvarSatchelDetectRadius = register_cvar("hldm_payload_satchel_detect_radius", "96.0");

    // Hand grenade payload only. MP5 contact grenades remain stock.
    g_pcvarGrenadeHornets = register_cvar("hldm_payload_grenade_hornets", "5");
    g_pcvarGrenadeSpawnDelay = register_cvar("hldm_payload_grenade_spawn_delay", "0.14");
    g_pcvarHornetSpeed = register_cvar("hldm_payload_hornet_speed", "720.0");
    g_pcvarHornetTurnSpeed = register_cvar("hldm_payload_hornet_turn_speed", "0.42");

    // Crossbow bolt impact payload.
    g_pcvarCrossbowSnarks = register_cvar("hldm_payload_crossbow_snarks", "3");
    g_pcvarCrossbowSpawnDelay = register_cvar("hldm_payload_crossbow_spawn_delay", "0.22");
    g_pcvarCrossbowExplosionDamage = register_cvar("hldm_payload_crossbow_explosion_damage", "35.0");
    g_pcvarCrossbowExplosionRadius = register_cvar("hldm_payload_crossbow_explosion_radius", "96.0");

    g_pcvarDebug = register_cvar("hldm_payload_debug", "0");

    AutoExecConfig(true, "hldm_weapon_payloads");

    RegisterHam(Ham_TakeDamage, "monster_snark", "OnSnarkTakeDamage", false);

    register_forward(FM_Spawn, "OnEntitySpawnPost", true);
    register_forward(FM_SetModel, "OnSetModelPost", true);
    register_forward(FM_Think, "OnEntityThinkPre", false);
    register_forward(FM_Touch, "OnEntityTouchPre", false);

    set_task(0.05, "TaskPayloadTick", TASK_PAYLOAD_TICK, _, _, "b");
}

public OnEntitySpawnPost(entity)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackableEntity(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[32];
    pev(entity, pev_classname, classname, charsmax(classname));

    if (equal(classname, "monster_snark"))
    {
        TryIncubateSatchelSnark(entity);
    }
    else if (equal(classname, "hornet") && g_guidedHornet[entity])
    {
        // The custom guided marker was assigned before DLLFunc_Spawn.
        // Keep the owner cached even if native hornet code changes pev_owner.
        if (!g_guidedOwner[entity])
        {
            g_guidedOwner[entity] = pev(entity, pev_owner);
        }
    }

    return FMRES_IGNORED;
}

public OnSetModelPost(entity, const model[])
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackableEntity(entity))
    {
        return FMRES_IGNORED;
    }

    if (containi(model, "crossbow_bolt") >= 0)
    {
        g_boltScheduled[entity] = false;
    }
    else if (containi(model, "grenade") >= 0)
    {
        g_grenadeScheduled[entity] = false;
        g_handGrenade[entity] = containi(model, "w_grenade.mdl") >= 0;
    }

    return FMRES_IGNORED;
}

public OnSnarkTakeDamage(entity, inflictor, attacker, Float:damage, damageBits)
{
    if (!get_pcvar_num(g_pcvarEnabled)
        || !IsTrackableEntity(entity)
        || !g_incubatingSnark[entity])
    {
        return HAM_IGNORED;
    }

    SetHamParamFloat(4, 0.0);
    return HAM_HANDLED;
}

public OnEntityThinkPre(entity)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackableEntity(entity))
    {
        return FMRES_IGNORED;
    }

    new Float:now = get_gametime();

    if (g_incubatingSnark[entity])
    {
        if (now < g_snarkReleaseTime[entity])
        {
            set_pev(entity, pev_nextthink, g_snarkReleaseTime[entity]);
            return FMRES_SUPERCEDE;
        }

        ReleaseIncubatingSnark(entity);
        return FMRES_IGNORED;
    }

    new classname[32];
    pev(entity, pev_classname, classname, charsmax(classname));

    if (equal(classname, "grenade") && g_handGrenade[entity])
    {
        ScheduleGrenadePayload(entity, now);
    }

    return FMRES_IGNORED;
}

public OnEntityTouchPre(entity, other)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !IsTrackableEntity(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[32];
    pev(entity, pev_classname, classname, charsmax(classname));

    if ((equal(classname, "crossbow_bolt") || equal(classname, "bolt"))
        && !g_boltScheduled[entity])
    {
        g_boltScheduled[entity] = true;

        new owner = pev(entity, pev_owner);
        new Float:origin[3];
        pev(entity, pev_origin, origin);

        VisualExplosion(origin, 5);
        RadiusDamagePlayers(
            entity,
            owner,
            origin,
            ClampFloat(get_pcvar_float(g_pcvarCrossbowExplosionDamage), 0.0, 200.0),
            ClampFloat(get_pcvar_float(g_pcvarCrossbowExplosionRadius), 16.0, 512.0)
        );

        QueuePayloadEvent(
            EVENT_CROSSBOW_SNARKS,
            owner,
            origin,
            get_gametime() + ClampFloat(get_pcvar_float(g_pcvarCrossbowSpawnDelay), 0.05, 2.0)
        );

        if (get_pcvar_num(g_pcvarDebug))
        {
            log_amx("Crossbow payload queued: bolt=%d owner=%d", entity, owner);
        }
    }

    return FMRES_IGNORED;
}

public TaskPayloadTick()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new Float:now = get_gametime();

    ProcessPayloadEvents(now);
    ProcessGuidedHornets();
    CleanupDeadTracking();
}

public CmdPayloadStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    new incubating;
    new guided;
    new events;

    for (new entity = MaxClients + 1; entity <= MAX_EDICTS; entity++)
    {
        if (g_incubatingSnark[entity])
        {
            incubating++;
        }
        if (g_guidedHornet[entity])
        {
            guided++;
        }
    }

    for (new slot = 0; slot < MAX_EVENTS; slot++)
    {
        if (g_eventActive[slot])
        {
            events++;
        }
    }

    console_print(
        id,
        "[PAYLOADS] incubating_snarks=%d guided_hornets=%d queued_events=%d",
        incubating,
        guided,
        events
    );

    return PLUGIN_HANDLED;
}

stock ScheduleGrenadePayload(entity, Float:now)
{
    if (g_grenadeScheduled[entity])
    {
        return;
    }

    new Float:damageTime;
    pev(entity, pev_dmgtime, damageTime);
    if (damageTime <= 0.0 || damageTime - now > 0.08)
    {
        return;
    }

    g_grenadeScheduled[entity] = true;

    new owner = pev(entity, pev_owner);
    new Float:origin[3];
    pev(entity, pev_origin, origin);

    QueuePayloadEvent(
        EVENT_GRENADE_HORNETS,
        owner,
        origin,
        damageTime + ClampFloat(get_pcvar_float(g_pcvarGrenadeSpawnDelay), 0.05, 2.0)
    );

    if (get_pcvar_num(g_pcvarDebug))
    {
        log_amx("Grenade hornet payload queued: grenade=%d owner=%d", entity, owner);
    }
}

stock TryIncubateSatchelSnark(entity)
{
    new owner = pev(entity, pev_owner);
    if (owner < 1 || owner > MaxClients || !is_user_connected(owner))
    {
        return;
    }

    new Float:snarkOrigin[3];
    pev(entity, pev_origin, snarkOrigin);

    new Float:maximumDistance = ClampFloat(get_pcvar_float(g_pcvarSatchelDetectRadius), 24.0, 256.0);
    new Float:maximumDistanceSquared = maximumDistance * maximumDistance;

    new satchel = -1;
    while ((satchel = engfunc(EngFunc_FindEntityByString, satchel, "classname", "monster_satchel")) > 0)
    {
        if (!pev_valid(satchel))
        {
            continue;
        }

        new satchelOwner = pev(satchel, pev_owner);
        if (satchelOwner != owner)
        {
            continue;
        }

        new Float:satchelOrigin[3];
        pev(satchel, pev_origin, satchelOrigin);
        if (VectorDistanceSquared(snarkOrigin, satchelOrigin) > maximumDistanceSquared)
        {
            continue;
        }

        g_incubatingSnark[entity] = true;
        g_snarkOwner[entity] = owner;
        g_snarkReleaseTime[entity] = get_gametime() + ClampFloat(get_pcvar_float(g_pcvarSatchelReleaseDelay), 0.15, 3.0);
        g_snarkReleaseOrigin[entity][0] = satchelOrigin[0];
        g_snarkReleaseOrigin[entity][1] = satchelOrigin[1];
        g_snarkReleaseOrigin[entity][2] = satchelOrigin[2] + 14.0;

        new effects = pev(entity, pev_effects);
        set_pev(entity, pev_effects, effects | EF_NODRAW);
        set_pev(entity, pev_solid, SOLID_NOT);
        set_pev(entity, pev_movetype, MOVETYPE_NONE);
        set_pev(entity, pev_takedamage, DAMAGE_NO);
        set_pev(entity, pev_velocity, Float:{0.0, 0.0, 0.0});
        set_pev(entity, pev_nextthink, g_snarkReleaseTime[entity]);

        if (get_pcvar_num(g_pcvarDebug))
        {
            log_amx("Satchel snark incubated: snark=%d owner=%d release=%.2f", entity, owner, g_snarkReleaseTime[entity]);
        }

        return;
    }
}

stock ReleaseIncubatingSnark(entity)
{
    if (!IsTrackableEntity(entity) || !g_incubatingSnark[entity])
    {
        return;
    }

    new Float:origin[3];
    origin[0] = g_snarkReleaseOrigin[entity][0] + random_float(-20.0, 20.0);
    origin[1] = g_snarkReleaseOrigin[entity][1] + random_float(-20.0, 20.0);
    origin[2] = g_snarkReleaseOrigin[entity][2] + random_float(4.0, 18.0);

    new Float:velocity[3];
    velocity[0] = random_float(-180.0, 180.0);
    velocity[1] = random_float(-180.0, 180.0);
    velocity[2] = random_float(220.0, 340.0);

    new effects = pev(entity, pev_effects);
    set_pev(entity, pev_effects, effects & ~EF_NODRAW);
    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_movetype, MOVETYPE_BOUNCE);
    set_pev(entity, pev_solid, SOLID_BBOX);
    set_pev(entity, pev_takedamage, DAMAGE_AIM);
    set_pev(entity, pev_owner, g_snarkOwner[entity]);
    set_pev(entity, pev_velocity, velocity);
    set_pev(entity, pev_nextthink, get_gametime() + 0.05);

    g_incubatingSnark[entity] = false;
    g_snarkReleaseTime[entity] = 0.0;

    if (get_pcvar_num(g_pcvarDebug))
    {
        log_amx("Satchel snark released: snark=%d owner=%d", entity, g_snarkOwner[entity]);
    }
}

stock QueuePayloadEvent(type, owner, const Float:origin[3], Float:executeTime)
{
    for (new slot = 0; slot < MAX_EVENTS; slot++)
    {
        if (g_eventActive[slot])
        {
            continue;
        }

        g_eventActive[slot] = true;
        g_eventType[slot] = type;
        g_eventOwner[slot] = owner;
        g_eventTime[slot] = executeTime;
        g_eventOrigin[slot][0] = origin[0];
        g_eventOrigin[slot][1] = origin[1];
        g_eventOrigin[slot][2] = origin[2];
        return;
    }

    log_amx("Payload event queue is full; dropped type=%d owner=%d", type, owner);
}

stock ProcessPayloadEvents(Float:now)
{
    for (new slot = 0; slot < MAX_EVENTS; slot++)
    {
        if (!g_eventActive[slot] || now < g_eventTime[slot])
        {
            continue;
        }

        switch (g_eventType[slot])
        {
            case EVENT_GRENADE_HORNETS:
            {
                new count = ClampInt(get_pcvar_num(g_pcvarGrenadeHornets), 0, 10);
                SpawnGuidedHornetBurst(g_eventOwner[slot], g_eventOrigin[slot], count);
            }
            case EVENT_CROSSBOW_SNARKS:
            {
                new count = ClampInt(get_pcvar_num(g_pcvarCrossbowSnarks), 0, 8);
                SpawnSnarkBurst(g_eventOwner[slot], g_eventOrigin[slot], count);
            }
        }

        g_eventActive[slot] = false;
        g_eventType[slot] = EVENT_NONE;
        g_eventOwner[slot] = 0;
        g_eventTime[slot] = 0.0;
    }
}

stock SpawnGuidedHornetBurst(owner, const Float:origin[3], count)
{
    for (new index = 0; index < count; index++)
    {
        new Float:spawnOrigin[3];
        spawnOrigin[0] = origin[0] + random_float(-10.0, 10.0);
        spawnOrigin[1] = origin[1] + random_float(-10.0, 10.0);
        spawnOrigin[2] = origin[2] + random_float(12.0, 28.0);

        new Float:velocity[3];
        velocity[0] = random_float(-1.0, 1.0);
        velocity[1] = random_float(-1.0, 1.0);
        velocity[2] = random_float(0.25, 1.0);
        NormalizeVector(velocity);

        new Float:speed = ClampFloat(get_pcvar_float(g_pcvarHornetSpeed), 250.0, 1400.0);
        velocity[0] *= speed;
        velocity[1] *= speed;
        velocity[2] *= speed;

        SpawnGuidedHornet(owner, spawnOrigin, velocity);
    }
}

stock SpawnGuidedHornet(owner, const Float:origin[3], const Float:velocity[3])
{
    new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hornet"));
    if (!IsTrackableEntity(entity))
    {
        return 0;
    }

    g_guidedHornet[entity] = true;
    g_guidedOwner[entity] = owner;

    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_owner, owner);
    dllfunc(DLLFunc_Spawn, entity);
    set_pev(entity, pev_velocity, velocity);

    return entity;
}

stock ProcessGuidedHornets()
{
    new Float:turn = ClampFloat(get_pcvar_float(g_pcvarHornetTurnSpeed), 0.05, 1.0);
    new Float:speed = ClampFloat(get_pcvar_float(g_pcvarHornetSpeed), 250.0, 1400.0);

    for (new entity = MaxClients + 1; entity <= MAX_EDICTS; entity++)
    {
        if (!g_guidedHornet[entity])
        {
            continue;
        }

        if (!IsTrackableEntity(entity))
        {
            g_guidedHornet[entity] = false;
            g_guidedOwner[entity] = 0;
            continue;
        }

        new classname[24];
        pev(entity, pev_classname, classname, charsmax(classname));
        if (!equal(classname, "hornet"))
        {
            g_guidedHornet[entity] = false;
            g_guidedOwner[entity] = 0;
            continue;
        }

        new target = FindNearestEnemy(entity, g_guidedOwner[entity]);
        if (!target)
        {
            continue;
        }

        new Float:entityOrigin[3], Float:targetOrigin[3];
        new Float:desired[3], Float:current[3];
        pev(entity, pev_origin, entityOrigin);
        pev(target, pev_origin, targetOrigin);
        targetOrigin[2] += 32.0;

        desired[0] = targetOrigin[0] - entityOrigin[0];
        desired[1] = targetOrigin[1] - entityOrigin[1];
        desired[2] = targetOrigin[2] - entityOrigin[2];
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

stock FindNearestEnemy(entity, owner)
{
    new Float:origin[3];
    pev(entity, pev_origin, origin);

    new bestTarget;
    new Float:bestDistanceSquared = 4096.0 * 4096.0;

    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_alive(target) || target == owner)
        {
            continue;
        }

        new Float:targetOrigin[3];
        pev(target, pev_origin, targetOrigin);
        new Float:distanceSquared = VectorDistanceSquared(origin, targetOrigin);
        if (distanceSquared < bestDistanceSquared)
        {
            bestDistanceSquared = distanceSquared;
            bestTarget = target;
        }
    }

    return bestTarget;
}

stock SpawnSnarkBurst(owner, const Float:origin[3], count)
{
    for (new index = 0; index < count; index++)
    {
        new Float:spawnOrigin[3];
        spawnOrigin[0] = origin[0] + random_float(-18.0, 18.0);
        spawnOrigin[1] = origin[1] + random_float(-18.0, 18.0);
        spawnOrigin[2] = origin[2] + random_float(12.0, 28.0);

        new Float:velocity[3];
        velocity[0] = random_float(-220.0, 220.0);
        velocity[1] = random_float(-220.0, 220.0);
        velocity[2] = random_float(220.0, 360.0);

        SpawnSnark(owner, spawnOrigin, velocity);
    }
}

stock SpawnSnark(owner, const Float:origin[3], const Float:velocity[3])
{
    new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "monster_snark"));
    if (!IsTrackableEntity(entity))
    {
        return 0;
    }

    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_owner, owner);
    dllfunc(DLLFunc_Spawn, entity);
    set_pev(entity, pev_velocity, velocity);
    return entity;
}

stock RadiusDamagePlayers(inflictor, attacker, const Float:origin[3], Float:maximumDamage, Float:radius)
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

        new validInflictor = pev_valid(inflictor) ? inflictor : attacker;
        new validAttacker = attacker >= 1 && attacker <= MaxClients ? attacker : validInflictor;
        ExecuteHamB(Ham_TakeDamage, target, validInflictor, validAttacker, damage, DMG_BLAST);
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

stock CleanupDeadTracking()
{
    for (new entity = MaxClients + 1; entity <= MAX_EDICTS; entity++)
    {
        if (pev_valid(entity))
        {
            continue;
        }

        g_grenadeScheduled[entity] = false;
        g_handGrenade[entity] = false;
        g_boltScheduled[entity] = false;
        g_incubatingSnark[entity] = false;
        g_snarkReleaseTime[entity] = 0.0;
        g_snarkOwner[entity] = 0;
        g_guidedHornet[entity] = false;
        g_guidedOwner[entity] = 0;
    }
}

stock bool:IsTrackableEntity(entity)
{
    return bool:(entity > MaxClients && entity <= MAX_EDICTS && pev_valid(entity));
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
