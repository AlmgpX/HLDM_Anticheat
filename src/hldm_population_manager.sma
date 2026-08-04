#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Population Manager"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define TASK_POPULATION 63001
#define TASK_MONSTERS   63002
#define TASK_WELCOME    63100

new g_pcvarEnabled;
new g_pcvarHostname;
new g_pcvarBotEnabled;
new g_pcvarHumanReserve;
new g_pcvarBotFraction;
new g_pcvarBotCommand;
new g_pcvarBotInterval;
new g_pcvarMonsterEnabled;
new g_pcvarMonsterMax;
new g_pcvarMonsterInterval;
new g_pcvarMonsterSafeRadius;
new g_pcvarMonsterHeadcrabWeight;
new g_pcvarMonsterZombieWeight;

public plugin_precache()
{
    precache_model("models/headcrab.mdl");
    precache_model("models/zombie.mdl");

    precache_sound("headcrab/hc_idle1.wav");
    precache_sound("headcrab/hc_idle2.wav");
    precache_sound("headcrab/hc_idle3.wav");
    precache_sound("headcrab/hc_alert1.wav");
    precache_sound("headcrab/hc_attack1.wav");
    precache_sound("headcrab/hc_attack2.wav");
    precache_sound("headcrab/hc_attack3.wav");
    precache_sound("headcrab/hc_headbite.wav");
    precache_sound("headcrab/hc_die1.wav");
    precache_sound("headcrab/hc_die2.wav");
    precache_sound("headcrab/hc_pain1.wav");
    precache_sound("headcrab/hc_pain2.wav");
    precache_sound("headcrab/hc_pain3.wav");

    precache_sound("zombie/zo_idle1.wav");
    precache_sound("zombie/zo_idle2.wav");
    precache_sound("zombie/zo_alert10.wav");
    precache_sound("zombie/zo_alert20.wav");
    precache_sound("zombie/zo_alert30.wav");
    precache_sound("zombie/zo_attack1.wav");
    precache_sound("zombie/zo_attack2.wav");
    precache_sound("zombie/zo_pain1.wav");
    precache_sound("zombie/zo_pain2.wav");
    precache_sound("zombie/zo_die1.wav");
    precache_sound("zombie/zo_die2.wav");
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_population_status", "CmdStatus", ADMIN_RCON, "- show bot and monster targets");
    register_concmd("amx_population_fill", "CmdFill", ADMIN_RCON, "- immediately adjust bot count");
    register_concmd("amx_monster_spawn", "CmdMonsterSpawn", ADMIN_RCON, "- spawn one passive map monster");

    g_pcvarEnabled = register_cvar("hldm_population_enabled", "1");
    g_pcvarHostname = register_cvar("hldm_population_hostname", "Alex first HL server | playing with brother");

    g_pcvarBotEnabled = register_cvar("hldm_population_bots_enabled", "1");
    g_pcvarHumanReserve = register_cvar("hldm_population_human_reserve", "2");
    g_pcvarBotFraction = register_cvar("hldm_population_bot_fraction", "0.50");
    g_pcvarBotCommand = register_cvar("hldm_population_bot_add_command", "addbot");
    g_pcvarBotInterval = register_cvar("hldm_population_bot_interval", "8.0");

    g_pcvarMonsterEnabled = register_cvar("hldm_population_monsters_enabled", "1");
    g_pcvarMonsterMax = register_cvar("hldm_population_monster_max", "6");
    g_pcvarMonsterInterval = register_cvar("hldm_population_monster_interval", "18.0");
    g_pcvarMonsterSafeRadius = register_cvar("hldm_population_monster_safe_radius", "320.0");
    g_pcvarMonsterHeadcrabWeight = register_cvar("hldm_population_headcrab_weight", "65");
    g_pcvarMonsterZombieWeight = register_cvar("hldm_population_zombie_weight", "35");

    AutoExecConfig(true, "hldm_population_manager");

    set_task(ClampFloat(get_pcvar_float(g_pcvarBotInterval), 2.0, 60.0), "TaskPopulation", TASK_POPULATION, _, _, "b");
    set_task(ClampFloat(get_pcvar_float(g_pcvarMonsterInterval), 4.0, 120.0), "TaskMonsters", TASK_MONSTERS, _, _, "b");
}

public plugin_cfg()
{
    ApplyHostname();
}

public client_putinserver(id)
{
    if (!is_user_bot(id) && !is_user_hltv(id))
    {
        set_task(3.0, "TaskWelcome", TASK_WELCOME + id);
    }
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    remove_task(TASK_WELCOME + id);
}

public TaskWelcome(taskId)
{
    new id = taskId - TASK_WELCOME;
    if (!is_user_connected(id))
    {
        return;
    }

    client_print(id, print_chat, "Hi. I just made this server to play Half-Life with my brother.");
    client_print(id, print_chat, "Some plugins may be buggy. Please do not ruin the game.");
}

public TaskPopulation()
{
    if (!get_pcvar_num(g_pcvarEnabled) || !get_pcvar_num(g_pcvarBotEnabled))
    {
        return;
    }

    AdjustBots();
}

public TaskMonsters()
{
    if (!get_pcvar_num(g_pcvarEnabled) || !get_pcvar_num(g_pcvarMonsterEnabled))
    {
        return;
    }

    if (CountManagedMonsters() >= ClampInt(get_pcvar_num(g_pcvarMonsterMax), 0, 32))
    {
        return;
    }

    SpawnManagedMonster();
}

public CmdStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(id, "[POPULATION] max=%d humans=%d bots=%d target_bots=%d monsters=%d/%d", get_maxplayers(), CountHumans(), CountBots(), GetDesiredBots(), CountManagedMonsters(), ClampInt(get_pcvar_num(g_pcvarMonsterMax), 0, 32));
    return PLUGIN_HANDLED;
}

public CmdFill(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    AdjustBots();
    console_print(id, "[POPULATION] adjustment requested.");
    return PLUGIN_HANDLED;
}

public CmdMonsterSpawn(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    if (SpawnManagedMonster())
    {
        console_print(id, "[POPULATION] monster spawned.");
    }
    else
    {
        console_print(id, "[POPULATION] no safe deathmatch spawn point available.");
    }

    return PLUGIN_HANDLED;
}

stock ApplyHostname()
{
    new hostname[96];
    get_pcvar_string(g_pcvarHostname, hostname, charsmax(hostname));
    if (hostname[0])
    {
        set_cvar_string("hostname", hostname);
    }
}

stock AdjustBots()
{
    new desired = GetDesiredBots();
    new current = CountBots();

    if (current < desired)
    {
        new command[96];
        get_pcvar_string(g_pcvarBotCommand, command, charsmax(command));
        if (command[0])
        {
            server_cmd("%s", command);
            server_exec();
        }
        return;
    }

    if (current > desired)
    {
        for (new id = 1; id <= MaxClients; id++)
        {
            if (!is_user_connected(id) || !is_user_bot(id))
            {
                continue;
            }

            new kickCommand[] = "kick";
            server_cmd("%s #%d", kickCommand, get_user_userid(id));
            server_exec();
            return;
        }
    }
}

stock GetDesiredBots()
{
    new maximum = get_maxplayers();
    new reserve = ClampInt(get_pcvar_num(g_pcvarHumanReserve), 0, maximum);
    new Float:fraction = ClampFloat(get_pcvar_float(g_pcvarBotFraction), 0.0, 1.0);
    new desired = floatround(float(maximum - reserve) * fraction, floatround_floor);

    new hardMaximum = maximum - reserve;
    if (desired > hardMaximum)
    {
        desired = hardMaximum;
    }
    if (desired < 0)
    {
        desired = 0;
    }

    return desired;
}

stock CountBots()
{
    new count;
    for (new id = 1; id <= MaxClients; id++)
    {
        if (is_user_connected(id) && is_user_bot(id))
        {
            count++;
        }
    }
    return count;
}

stock CountHumans()
{
    new count;
    for (new id = 1; id <= MaxClients; id++)
    {
        if (is_user_connected(id) && !is_user_bot(id) && !is_user_hltv(id))
        {
            count++;
        }
    }
    return count;
}

stock CountManagedMonsters()
{
    new count;
    new entity = -1;

    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "monster_headcrab")) > 0)
    {
        if (pev_valid(entity) && pev(entity, pev_iuser4) == 63002)
        {
            count++;
        }
    }

    entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "monster_zombie")) > 0)
    {
        if (pev_valid(entity) && pev(entity, pev_iuser4) == 63002)
        {
            count++;
        }
    }

    return count;
}

stock bool:SpawnManagedMonster()
{
    new spawn = FindSafeSpawnPoint();
    if (!spawn)
    {
        return false;
    }

    new headcrabWeight = ClampInt(get_pcvar_num(g_pcvarMonsterHeadcrabWeight), 0, 100);
    new zombieWeight = ClampInt(get_pcvar_num(g_pcvarMonsterZombieWeight), 0, 100);
    new totalWeight = headcrabWeight + zombieWeight;
    if (totalWeight <= 0)
    {
        return false;
    }

    new roll = random_num(1, totalWeight);
    new classname[32];
    if (roll <= headcrabWeight)
    {
        copy(classname, charsmax(classname), "monster_headcrab");
    }
    else
    {
        copy(classname, charsmax(classname), "monster_zombie");
    }

    new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, classname));
    if (!pev_valid(entity))
    {
        return false;
    }

    new Float:origin[3], Float:angles[3];
    pev(spawn, pev_origin, origin);
    pev(spawn, pev_angles, angles);
    origin[2] += 12.0;

    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_angles, angles);
    set_pev(entity, pev_iuser4, 63002);
    dllfunc(DLLFunc_Spawn, entity);
    return bool:pev_valid(entity);
}

stock FindSafeSpawnPoint()
{
    new candidates[64];
    new count;
    new entity = -1;
    new Float:safeRadius = ClampFloat(get_pcvar_float(g_pcvarMonsterSafeRadius), 64.0, 1024.0);
    new Float:safeSquared = safeRadius * safeRadius;

    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "info_player_deathmatch")) > 0)
    {
        if (!pev_valid(entity) || count >= sizeof candidates)
        {
            continue;
        }

        new Float:origin[3];
        pev(entity, pev_origin, origin);
        if (!AnyAlivePlayerWithin(origin, safeSquared))
        {
            candidates[count++] = entity;
        }
    }

    if (!count)
    {
        return 0;
    }

    return candidates[random_num(0, count - 1)];
}

stock bool:AnyAlivePlayerWithin(const Float:origin[3], Float:maximumSquared)
{
    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id))
        {
            continue;
        }

        new Float:playerOrigin[3];
        pev(id, pev_origin, playerOrigin);
        if (DistanceSquared(origin, playerOrigin) <= maximumSquared)
        {
            return true;
        }
    }

    return false;
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
