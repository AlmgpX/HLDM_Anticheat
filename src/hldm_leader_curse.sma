#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fun>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Leader Curse"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_SCORE      61001
#define TASK_NOTICE     61002
#define TASK_JOIN_BASE  61100
#define TASK_TAUNT_BASE 61200

#define W_CROSSBOW 6
#define W_GAUSS     9
#define W_EGON     10

new g_previousButtons[MAX_PLAYERS + 1];
new g_lead[MAX_PLAYERS + 1];
new g_tier[MAX_PLAYERS + 1];
new bool:g_convertingAmmo[MAX_PLAYERS + 1];
new Float:g_lastSelfKill[MAX_PLAYERS + 1];

new g_explosionSprite;

new g_pcvarEnabled;
new g_pcvarAdminImmunity;
new g_pcvarMinimumOthers;
new g_pcvarThresholdAmmo;
new g_pcvarThresholdSteps;
new g_pcvarThresholdSelfKill;
new g_pcvarAmmoChance;
new g_pcvarAmmoMultiplier;
new g_pcvarPublicThresholds;
new g_pcvarPublicAmmo;
new g_pcvarNoticeInterval;
new g_pcvarTauntMin;
new g_pcvarTauntMax;

new const g_TestNotice[] = "[TEST SERVER] ZOV ZIP ZONA is experimental. A vindictive anti-cheat is being developed here.";
new const g_TestNotice2[] = "[ZONA] Suspicious dominance may mutate ammunition, footsteps, weapons and dignity.";

new const g_TierOneTaunts[][] =
{
    "LEAD +5: THE AMMO DEPARTMENT HAS JOINED A CROSSBOW CULT",
    "YOUR SCORE IS NOW BEING USED AS A BALLISTICS EXPERIMENT",
    "AMMUNITION MAY ARRIVE IN AN UNREASONABLY EXPLOSIVE FORMAT",
    "THE SERVER HAS NOTICED YOUR LEAD. THE BOXES HAVE NOTICED TOO.",
    "CONGRATULATIONS: ORDINARY AMMO IS NOW A RUMOR"
};

new const g_TierTwoTaunts[][] =
{
    "LEAD +10: YOUR FOOTSTEPS HAVE BEEN OUTSOURCED TO LIVESTOCK",
    "STEALTH STATUS: SCIENTIST HAVING A VERY BAD DAY",
    "YOUR SHOES ARE NOW OPERATED BY THE SCREAM DEPARTMENT",
    "THE MAP CAN HEAR YOUR CAREER ADVANCEMENT",
    "SILENT MOVEMENT HAS BEEN REMOVED FOR EXCESSIVE SUCCESS"
};

new const g_TierThreeTaunts[][] =
{
    "LEAD +15: GAUSS WARRANTY VOIDED BY EXCESSIVE TALENT",
    "THE EGON HAS IDENTIFIED ITS OWNER AS WASTE MATERIAL",
    "ENERGY WEAPONS NOW SUBMIT SELF-KILL REPORTS AUTOMATICALLY",
    "YOUR SCORE HAS EXCEEDED THE SAFE OPERATING LIMIT OF PHYSICS",
    "THE SERVER WOULD LIKE YOU TO EXPERIENCE YOUR OWN FIREPOWER"
};

new const g_ReplacementSteps[][] =
{
    "scientist/scream07.wav",
    "scientist/scream08.wav",
    "bullchicken/bc_attack2.wav",
    "bullchicken/bc_die1.wav"
};

public plugin_precache()
{
    g_explosionSprite = precache_model("sprites/zerogxplode.spr");

    for (new index = 0; index < sizeof g_ReplacementSteps; index++)
    {
        precache_sound(g_ReplacementSteps[index]);
    }
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_pcvarEnabled = register_cvar("hldm_leadercurse_enabled", "1");
    g_pcvarAdminImmunity = register_cvar("hldm_leadercurse_admin_immunity", "1");
    g_pcvarMinimumOthers = register_cvar("hldm_leadercurse_minimum_others", "1");

    g_pcvarThresholdAmmo = register_cvar("hldm_leadercurse_threshold_ammo", "5");
    g_pcvarThresholdSteps = register_cvar("hldm_leadercurse_threshold_steps", "10");
    g_pcvarThresholdSelfKill = register_cvar("hldm_leadercurse_threshold_selfkill", "15");

    g_pcvarAmmoChance = register_cvar("hldm_leadercurse_ammo_conversion_chance", "28");
    g_pcvarAmmoMultiplier = register_cvar("hldm_leadercurse_ammo_multiplier", "3");

    g_pcvarPublicThresholds = register_cvar("hldm_leadercurse_public_thresholds", "1");
    g_pcvarPublicAmmo = register_cvar("hldm_leadercurse_public_ammo", "0");
    g_pcvarNoticeInterval = register_cvar("hldm_leadercurse_notice_interval", "90.0");
    g_pcvarTauntMin = register_cvar("hldm_leadercurse_taunt_min", "12.0");
    g_pcvarTauntMax = register_cvar("hldm_leadercurse_taunt_max", "20.0");

    AutoExecConfig(true, "hldm_leader_curse");

    register_forward(FM_Touch, "OnEntityTouch", false);
    register_forward(FM_EmitSound, "OnEmitSound", false);
    register_forward(FM_CmdStart, "OnCmdStart", false);

    register_concmd("amx_leadercurse_status", "CmdStatus", ADMIN_RCON, "- show score leads and active tiers");
    register_concmd("amx_leadercurse_notice", "CmdNotice", ADMIN_RCON, "- broadcast the experimental-server notice");

    set_task(1.0, "TaskRecalculateScores", TASK_SCORE, _, _, "b");
    ScheduleGlobalNotice();
}

public client_connect(id)
{
    ResetClient(id);
}

public client_putinserver(id)
{
    ResetClient(id);
    remove_task(TASK_JOIN_BASE + id);
    remove_task(TASK_TAUNT_BASE + id);
    set_task(4.0, "TaskJoinNotice", TASK_JOIN_BASE + id);
    SchedulePlayerTaunt(id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    remove_task(TASK_JOIN_BASE + id);
    remove_task(TASK_TAUNT_BASE + id);
    ResetClient(id);
}

public TaskJoinNotice(taskId)
{
    new id = taskId - TASK_JOIN_BASE;
    if (!is_user_connected(id))
    {
        return;
    }

    client_print(id, print_chat, "%s", g_TestNotice);
    client_print(id, print_chat, "%s", g_TestNotice2);

    set_hudmessage(255, 170, 40, -1.0, 0.18, 0, 0.0, 6.0, 0.2, 0.4, 4);
    show_hudmessage(id, "TEST SERVER^nVINDICTIVE ANTI-CHEAT UNDER CONSTRUCTION^nYOUR SCORE MAY BECOME A GAME MECHANIC");
}

public TaskGlobalNotice()
{
    if (get_pcvar_num(g_pcvarEnabled))
    {
        client_print(0, print_chat, "%s", g_TestNotice);
        client_print(0, print_chat, "%s", g_TestNotice2);
    }

    ScheduleGlobalNotice();
}

public TaskPlayerTaunt(taskId)
{
    new id = taskId - TASK_TAUNT_BASE;
    if (!is_user_connected(id))
    {
        return;
    }

    if (get_pcvar_num(g_pcvarEnabled) && g_tier[id] > 0)
    {
        ShowTierTaunt(id, g_tier[id]);
    }

    SchedulePlayerTaunt(id);
}

public TaskRecalculateScores()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_hltv(id))
        {
            g_lead[id] = 0;
            UpdateTier(id, 0);
            continue;
        }

        if (get_pcvar_num(g_pcvarAdminImmunity) && is_user_admin(id))
        {
            g_lead[id] = 0;
            UpdateTier(id, 0);
            continue;
        }

        new others;
        new totalOtherFrags;

        for (new other = 1; other <= MaxClients; other++)
        {
            if (other == id || !is_user_connected(other) || is_user_hltv(other))
            {
                continue;
            }

            totalOtherFrags += get_user_frags(other);
            others++;
        }

        if (others < ClampInt(get_pcvar_num(g_pcvarMinimumOthers), 1, 31))
        {
            g_lead[id] = 0;
            UpdateTier(id, 0);
            continue;
        }

        new Float:average = float(totalOtherFrags) / float(others);
        new Float:difference = float(get_user_frags(id)) - average;
        g_lead[id] = floatround(difference, floatround_floor);

        new tier;
        if (g_lead[id] >= get_pcvar_num(g_pcvarThresholdSelfKill))
        {
            tier = 3;
        }
        else if (g_lead[id] >= get_pcvar_num(g_pcvarThresholdSteps))
        {
            tier = 2;
        }
        else if (g_lead[id] >= get_pcvar_num(g_pcvarThresholdAmmo))
        {
            tier = 1;
        }

        UpdateTier(id, tier);
    }
}

public OnEntityTouch(entity, player)
{
    if (!get_pcvar_num(g_pcvarEnabled)
        || player < 1
        || player > MaxClients
        || !is_user_alive(player)
        || g_tier[player] < 1
        || g_convertingAmmo[player]
        || !pev_valid(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[32];
    pev(entity, pev_classname, classname, charsmax(classname));
    if (!IsConvertibleAmmo(classname))
    {
        return FMRES_IGNORED;
    }

    new chance = ClampInt(get_pcvar_num(g_pcvarAmmoChance), 0, 100);
    if (random_num(1, 100) > chance)
    {
        return FMRES_IGNORED;
    }

    g_convertingAmmo[player] = true;
    engfunc(EngFunc_RemoveEntity, entity);

    if (!user_has_weapon(player, W_CROSSBOW))
    {
        give_item(player, "weapon_crossbow");
    }

    new multiplier = ClampInt(get_pcvar_num(g_pcvarAmmoMultiplier), 1, 8);
    for (new index = 0; index < multiplier; index++)
    {
        give_item(player, "ammo_crossbow");
    }

    g_convertingAmmo[player] = false;

    set_hudmessage(255, 90, 30, -1.0, 0.72, 0, 0.0, 2.5, 0.05, 0.15, 4);
    show_hudmessage(player, "AMMO SURPRISE^nORDINARY ROUNDS CONVERTED INTO EXPLOSIVE CROSSBOW BOLTS x%d", multiplier);
    client_print(player, print_chat, "[ZONA] The ammunition box rejected normality and became explosive crossbow bolts x%d.", multiplier);

    if (get_pcvar_num(g_pcvarPublicAmmo))
    {
        new name[32];
        get_user_name(player, name, charsmax(name));
        client_print(0, print_chat, "[ZONA] %s opened an ammo box. The box chose violence.", name);
    }

    return FMRES_SUPERCEDE;
}

public OnEmitSound(entity, channel, const sample[], Float:volume, Float:attenuation, flags, pitch)
{
    if (!get_pcvar_num(g_pcvarEnabled)
        || entity < 1
        || entity > MaxClients
        || !is_user_alive(entity)
        || g_tier[entity] < 2
        || !IsFootstepSample(sample))
    {
        return FMRES_IGNORED;
    }

    new replacement = random_num(0, sizeof g_ReplacementSteps - 1);
    engfunc(
        EngFunc_EmitSound,
        entity,
        channel,
        g_ReplacementSteps[replacement],
        ClampFloat(volume, 0.35, 1.0),
        attenuation,
        flags,
        random_num(92, 108)
    );

    return FMRES_SUPERCEDE;
}

public OnCmdStart(id, userCmd, randomSeed)
{
    if (!get_pcvar_num(g_pcvarEnabled) || id < 1 || id > MaxClients || !is_user_alive(id))
    {
        return FMRES_IGNORED;
    }

    new buttons = get_uc(userCmd, UC_Buttons);
    new pressed = buttons & ~g_previousButtons[id];
    g_previousButtons[id] = buttons;

    if (g_tier[id] < 3 || !(pressed & (IN_ATTACK | IN_ATTACK2)))
    {
        return FMRES_IGNORED;
    }

    new weapon = get_user_weapon(id);
    if (weapon != W_GAUSS && weapon != W_EGON)
    {
        return FMRES_IGNORED;
    }

    new Float:now = get_gametime();
    if (now - g_lastSelfKill[id] < 0.25)
    {
        return FMRES_IGNORED;
    }

    g_lastSelfKill[id] = now;

    new Float:origin[3];
    pev(id, pev_origin, origin);
    origin[2] += 30.0;
    VisualExplosion(origin, weapon == W_GAUSS ? 10 : 8);

    if (weapon == W_GAUSS)
    {
        client_print(id, print_center, "GAUSS WARRANTY VOIDED BY EXCESSIVE TALENT");
        client_print(0, print_chat, "[ZONA] Gauss completed a mandatory owner-calibration cycle.");
    }
    else
    {
        client_print(id, print_center, "EGON HAS CLASSIFIED ITS OWNER AS WASTE MATERIAL");
        client_print(0, print_chat, "[ZONA] Egon vacuumed the nearest available ego.");
    }

    user_kill(id, 1);
    return FMRES_HANDLED;
}

public CmdStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(id, "[LEADER CURSE] current score leads:");
    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_connected(target))
        {
            continue;
        }

        new name[32];
        get_user_name(target, name, charsmax(name));
        console_print(id, "  #%d %-24s frags=%d lead=%d tier=%d", get_user_userid(target), name, get_user_frags(target), g_lead[target], g_tier[target]);
    }

    return PLUGIN_HANDLED;
}

public CmdNotice(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    client_print(0, print_chat, "%s", g_TestNotice);
    client_print(0, print_chat, "%s", g_TestNotice2);
    return PLUGIN_HANDLED;
}

stock UpdateTier(id, newTier)
{
    new oldTier = g_tier[id];
    g_tier[id] = newTier;

    if (newTier == oldTier || !is_user_connected(id))
    {
        return;
    }

    if (newTier > oldTier)
    {
        ShowTierTaunt(id, newTier);

        if (get_pcvar_num(g_pcvarPublicThresholds))
        {
            new name[32];
            get_user_name(id, name, charsmax(name));

            switch (newTier)
            {
                case 1: client_print(0, print_chat, "[ZONA] %s leads by +%d. Ammo boxes are reviewing their career options.", name, g_lead[id]);
                case 2: client_print(0, print_chat, "[ZONA] %s leads by +%d. Their footsteps have entered animal testing.", name, g_lead[id]);
                case 3: client_print(0, print_chat, "[ZONA] %s leads by +%d. Energy weapons now consider this a containment breach.", name, g_lead[id]);
            }
        }
    }
}

stock ShowTierTaunt(id, tier)
{
    if (!is_user_connected(id))
    {
        return;
    }

    new text[128];
    switch (tier)
    {
        case 1: copy(text, charsmax(text), g_TierOneTaunts[random_num(0, sizeof g_TierOneTaunts - 1)]);
        case 2: copy(text, charsmax(text), g_TierTwoTaunts[random_num(0, sizeof g_TierTwoTaunts - 1)]);
        case 3: copy(text, charsmax(text), g_TierThreeTaunts[random_num(0, sizeof g_TierThreeTaunts - 1)]);
        default: return;
    }

    set_hudmessage(255, 130, 30, -1.0, 0.72, 0, 0.0, 3.5, 0.08, 0.25, 4);
    show_hudmessage(id, "%s^nCURRENT LEAD: +%d OVER THE OTHERS", text, g_lead[id]);
}

stock ScheduleGlobalNotice()
{
    remove_task(TASK_NOTICE);
    new Float:interval = ClampFloat(get_pcvar_float(g_pcvarNoticeInterval), 30.0, 600.0);
    set_task(interval, "TaskGlobalNotice", TASK_NOTICE);
}

stock SchedulePlayerTaunt(id)
{
    if (id < 1 || id > MaxClients || !is_user_connected(id))
    {
        return;
    }

    remove_task(TASK_TAUNT_BASE + id);

    new Float:minimum = ClampFloat(get_pcvar_float(g_pcvarTauntMin), 5.0, 120.0);
    new Float:maximum = ClampFloat(get_pcvar_float(g_pcvarTauntMax), minimum, 180.0);
    set_task(random_float(minimum, maximum), "TaskPlayerTaunt", TASK_TAUNT_BASE + id);
}

stock bool:IsConvertibleAmmo(const classname[])
{
    return equal(classname, "ammo_9mmclip")
        || equal(classname, "ammo_9mmbox")
        || equal(classname, "ammo_357")
        || equal(classname, "ammo_buckshot")
        || equal(classname, "ammo_crossbow")
        || equal(classname, "ammo_rpgclip")
        || equal(classname, "ammo_gaussclip")
        || equal(classname, "ammo_egonclip")
        || equal(classname, "ammo_ARgrenades")
        || equal(classname, "ammo_tripmine")
        || equal(classname, "ammo_satchel")
        || equal(classname, "ammo_snark");
}

stock bool:IsFootstepSample(const sample[])
{
    return containi(sample, "player/pl_step") >= 0
        || containi(sample, "player/pl_metal") >= 0
        || containi(sample, "player/pl_dirt") >= 0
        || containi(sample, "player/pl_duct") >= 0
        || containi(sample, "player/pl_grate") >= 0
        || containi(sample, "player/pl_slosh") >= 0
        || containi(sample, "player/pl_tile") >= 0;
}

stock VisualExplosion(const Float:origin[3], scale)
{
    engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
    write_byte(TE_EXPLOSION);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    write_short(g_explosionSprite);
    write_byte(ClampInt(scale, 1, 20));
    write_byte(15);
    write_byte(0);
    message_end();
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

stock ResetClient(id)
{
    g_previousButtons[id] = 0;
    g_lead[id] = 0;
    g_tier[id] = 0;
    g_convertingAmmo[id] = false;
    g_lastSelfKill[id] = 0.0;
}
