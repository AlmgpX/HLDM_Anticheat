#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Silent Misery"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_MISERY_TICK 53001

#define MISERY_GHOST      (1 << 0)
#define MISERY_MERCY      (1 << 1)
#define MISERY_FRAILTY    (1 << 2)
#define MISERY_STUTTER    (1 << 3)
#define MISERY_CHOKE      (1 << 4)
#define MISERY_FOOTSTEPS  (1 << 5)
#define MISERY_SHADOW     (1 << 6)
#define MISERY_ALL        (MISERY_GHOST | MISERY_MERCY | MISERY_FRAILTY | MISERY_STUTTER | MISERY_CHOKE | MISERY_FOOTSTEPS | MISERY_SHADOW)

new g_miseryMask[MAX_PLAYERS + 1];
new g_selectedTarget[MAX_PLAYERS + 1];
new g_previousButtons[MAX_PLAYERS + 1];
new bool:g_choking[MAX_PLAYERS + 1];
new bool:g_stuttering[MAX_PLAYERS + 1];

new Float:g_nextChokeCheck[MAX_PLAYERS + 1];
new Float:g_chokeUntil[MAX_PLAYERS + 1];
new Float:g_nextStutter[MAX_PLAYERS + 1];
new Float:g_stutterUntil[MAX_PLAYERS + 1];
new Float:g_nextFootstep[MAX_PLAYERS + 1];
new Float:g_nextShadowNudge[MAX_PLAYERS + 1];

new g_vault = INVALID_HANDLE;

new g_pcvarEnabled;
new g_pcvarHostname;
new g_pcvarSkullGrenades;
new g_pcvarGhostChance;
new g_pcvarFrailtyScale;
new g_pcvarFrailtyLowHealthScale;
new g_pcvarFrailtyThreshold;
new g_pcvarChokeChance;
new g_pcvarChokeDuration;
new g_pcvarStutterMinInterval;
new g_pcvarStutterMaxInterval;
new g_pcvarStutterDuration;
new g_pcvarStutterFactor;
new g_pcvarFootstepMinInterval;
new g_pcvarFootstepMaxInterval;
new g_pcvarShadowDegrees;
new g_pcvarShadowJamChance;
new g_pcvarAdminImmunity;

new const SKULL_MODEL[] = "models/hgibs.mdl";

new const FOOTSTEP_SOUNDS[][] =
{
    "player/pl_step1.wav",
    "player/pl_step2.wav",
    "player/pl_step3.wav",
    "player/pl_step4.wav"
};

public plugin_precache()
{
    precache_model(SKULL_MODEL);

    for (new index = 0; index < sizeof FOOTSTEP_SOUNDS; index++)
    {
        precache_sound(FOOTSTEP_SOUNDS[index]);
    }
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_misery_menu", "CmdMiseryMenu", ADMIN_RCON, "- open silent misery menu");
    register_concmd("amx_misery", "CmdMisery", ADMIN_RCON, "<target> <ghost|mercy|frailty|stutter|choke|footsteps|shadow|all|clear>");
    register_concmd("amx_misery_status", "CmdMiseryStatus", ADMIN_RCON, "- list silent misery state");

    register_clcmd("say /misery", "CmdChatMisery");
    register_clcmd("say_team /misery", "CmdChatMisery");

    g_pcvarEnabled = register_cvar("hldm_misery_enabled", "1");
    g_pcvarHostname = register_cvar("hldm_misery_hostname", "ZOV ZIP ZONA");
    g_pcvarSkullGrenades = register_cvar("hldm_misery_skull_grenades", "1");

    g_pcvarGhostChance = register_cvar("hldm_misery_ghost_hit_chance", "18");
    g_pcvarFrailtyScale = register_cvar("hldm_misery_frailty_scale", "1.35");
    g_pcvarFrailtyLowHealthScale = register_cvar("hldm_misery_frailty_low_health_scale", "1.75");
    g_pcvarFrailtyThreshold = register_cvar("hldm_misery_frailty_threshold", "35.0");

    g_pcvarChokeChance = register_cvar("hldm_misery_choke_chance", "11");
    g_pcvarChokeDuration = register_cvar("hldm_misery_choke_duration", "0.11");

    g_pcvarStutterMinInterval = register_cvar("hldm_misery_stutter_min_interval", "1.8");
    g_pcvarStutterMaxInterval = register_cvar("hldm_misery_stutter_max_interval", "4.8");
    g_pcvarStutterDuration = register_cvar("hldm_misery_stutter_duration", "0.12");
    g_pcvarStutterFactor = register_cvar("hldm_misery_stutter_factor", "0.12");

    g_pcvarFootstepMinInterval = register_cvar("hldm_misery_footstep_min_interval", "1.9");
    g_pcvarFootstepMaxInterval = register_cvar("hldm_misery_footstep_max_interval", "4.4");

    g_pcvarShadowDegrees = register_cvar("hldm_misery_shadow_degrees", "1.15");
    g_pcvarShadowJamChance = register_cvar("hldm_misery_shadow_jam_chance", "16");
    g_pcvarAdminImmunity = register_cvar("hldm_misery_admin_immunity", "1");

    AutoExecConfig(true, "hldm_silent_misery");

    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage", false);
    register_forward(FM_CmdStart, "OnCmdStart", false);
    register_forward(FM_SetModel, "OnSetModelPost", true);

    set_task(0.20, "TaskMiseryTick", TASK_MISERY_TICK, _, _, "b");

    g_vault = nvault_open("hldm_silent_misery");
    if (g_vault == INVALID_HANDLE)
    {
        log_amx("Could not open hldm_silent_misery vault.");
    }
}

public plugin_cfg()
{
    new hostname[96];
    get_pcvar_string(g_pcvarHostname, hostname, charsmax(hostname));
    trim(hostname);

    if (hostname[0])
    {
        server_cmd("hostname ^\"%s^\"", hostname);
        server_exec();
    }
}

public plugin_end()
{
    if (g_vault != INVALID_HANDLE)
    {
        nvault_close(g_vault);
        g_vault = INVALID_HANDLE;
    }
}

public client_connect(id)
{
    ResetClient(id);
}

public client_authorized(id)
{
    LoadState(id);
}

public client_putinserver(id)
{
    LoadState(id);
    ScheduleClientEffects(id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    ResetClient(id);
}

public CmdChatMisery(id)
{
    if (!IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    ShowTargetMenu(id);
    return PLUGIN_HANDLED;
}

public CmdMiseryMenu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    ShowTargetMenu(id);
    return PLUGIN_HANDLED;
}

public CmdMisery(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3))
    {
        return PLUGIN_HANDLED;
    }

    new targetArgument[64], mode[24];
    read_argv(1, targetArgument, charsmax(targetArgument));
    read_argv(2, mode, charsmax(mode));

    new target = cmd_target(id, targetArgument, CMDTARGET_NO_BOTS | CMDTARGET_OBEY_IMMUNITY);
    if (!CanTarget(id, target))
    {
        return PLUGIN_HANDLED;
    }

    if (equali(mode, "ghost"))
    {
        ToggleBit(id, target, MISERY_GHOST, "ghost hits");
    }
    else if (equali(mode, "mercy"))
    {
        ToggleBit(id, target, MISERY_MERCY, "one-HP mercy");
    }
    else if (equali(mode, "frailty"))
    {
        ToggleBit(id, target, MISERY_FRAILTY, "frailty");
    }
    else if (equali(mode, "stutter"))
    {
        ToggleBit(id, target, MISERY_STUTTER, "movement stutter");
    }
    else if (equali(mode, "choke"))
    {
        ToggleBit(id, target, MISERY_CHOKE, "weapon choke");
    }
    else if (equali(mode, "footsteps"))
    {
        ToggleBit(id, target, MISERY_FOOTSTEPS, "phantom footsteps");
    }
    else if (equali(mode, "shadow"))
    {
        ToggleBit(id, target, MISERY_SHADOW, "shadow pressure");
    }
    else if (equali(mode, "all"))
    {
        g_miseryMask[target] = MISERY_ALL;
        SaveState(target);
        ScheduleClientEffects(target);
        PrintAdminState(id, target, "FULL SILENT MISERY ON");
    }
    else if (equali(mode, "clear"))
    {
        ClearState(id, target);
    }
    else
    {
        console_print(id, "Usage: amx_misery <target> <ghost|mercy|frailty|stutter|choke|footsteps|shadow|all|clear>");
    }

    return PLUGIN_HANDLED;
}

public CmdMiseryStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(id, "[MISERY] silent state:");

    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_connected(target) || !g_miseryMask[target])
        {
            continue;
        }

        new name[32], authid[40];
        get_user_name(target, name, charsmax(name));
        get_user_authid(target, authid, charsmax(authid));
        console_print(id, "  #%d %s <%s> mask=%d", get_user_userid(target), name, authid, g_miseryMask[target]);
    }

    return PLUGIN_HANDLED;
}

public TargetMenuHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new access, callback, info[8], displayName[96];
    menu_item_getinfo(menu, item, access, info, charsmax(info), displayName, charsmax(displayName), callback);
    menu_destroy(menu);

    new target = str_to_num(info);
    if (!CanTarget(id, target))
    {
        client_print(id, print_chat, "[MISERY] target unavailable.");
        return PLUGIN_HANDLED;
    }

    g_selectedTarget[id] = target;
    ShowActionMenu(id, target);
    return PLUGIN_HANDLED;
}

public ActionMenuHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        ShowTargetMenu(id);
        return PLUGIN_HANDLED;
    }

    new access, callback, info[8], displayName[96];
    menu_item_getinfo(menu, item, access, info, charsmax(info), displayName, charsmax(displayName), callback);
    menu_destroy(menu);

    new target = g_selectedTarget[id];
    if (!CanTarget(id, target))
    {
        client_print(id, print_chat, "[MISERY] target unavailable.");
        return PLUGIN_HANDLED;
    }

    switch (str_to_num(info))
    {
        case 1: ToggleBit(id, target, MISERY_GHOST, "ghost hits");
        case 2: ToggleBit(id, target, MISERY_MERCY, "one-HP mercy");
        case 3: ToggleBit(id, target, MISERY_FRAILTY, "frailty");
        case 4: ToggleBit(id, target, MISERY_STUTTER, "movement stutter");
        case 5: ToggleBit(id, target, MISERY_CHOKE, "weapon choke");
        case 6: ToggleBit(id, target, MISERY_FOOTSTEPS, "phantom footsteps");
        case 7: ToggleBit(id, target, MISERY_SHADOW, "shadow pressure");
        case 8:
        {
            g_miseryMask[target] = MISERY_ALL;
            SaveState(target);
            ScheduleClientEffects(target);
            PrintAdminState(id, target, "FULL SILENT MISERY ON");
        }
        case 9: ClearState(id, target);
        case 10: PrintTargetStatus(id, target);
    }

    return PLUGIN_HANDLED;
}

public OnCmdStart(id, userCmd, randomSeed)
{
    if (!get_pcvar_num(g_pcvarEnabled)
        || id < 1
        || id > MaxClients
        || !is_user_alive(id)
        || !g_miseryMask[id])
    {
        return FMRES_IGNORED;
    }

    new buttons = get_uc(userCmd, UC_Buttons);
    new pressed = buttons & ~g_previousButtons[id];
    new Float:now = get_gametime();

    if (g_miseryMask[id] & MISERY_STUTTER)
    {
        ApplyMovementStutter(id, userCmd, now);
    }

    if (g_miseryMask[id] & MISERY_CHOKE)
    {
        ApplyWeaponChoke(id, userCmd, buttons, now);
        buttons = get_uc(userCmd, UC_Buttons);
    }

    if ((g_miseryMask[id] & MISERY_SHADOW) && (pressed & (IN_ATTACK | IN_ATTACK2)))
    {
        ApplyShadowPressure(id, userCmd, buttons, now);
    }

    g_previousButtons[id] = buttons;
    return FMRES_IGNORED;
}

public OnPlayerTakeDamage(victim, inflictor, attacker, Float:damage, damageBits)
{
    if (!get_pcvar_num(g_pcvarEnabled) || damage <= 0.0)
    {
        return HAM_IGNORED;
    }

    new Float:modifiedDamage = damage;
    new bool:changed;

    if (victim >= 1
        && victim <= MaxClients
        && is_user_connected(victim)
        && (g_miseryMask[victim] & MISERY_FRAILTY))
    {
        new Float:health;
        pev(victim, pev_health, health);

        new Float:scale = ClampFloat(get_pcvar_float(g_pcvarFrailtyScale), 1.0, 5.0);
        new Float:threshold = ClampFloat(get_pcvar_float(g_pcvarFrailtyThreshold), 1.0, 100.0);
        if (health <= threshold)
        {
            scale = ClampFloat(get_pcvar_float(g_pcvarFrailtyLowHealthScale), scale, 8.0);
        }

        modifiedDamage *= scale;
        changed = true;
    }

    if (attacker >= 1
        && attacker <= MaxClients
        && attacker != victim
        && is_user_connected(attacker))
    {
        if ((g_miseryMask[attacker] & MISERY_GHOST)
            && random_num(1, 100) <= ClampInt(get_pcvar_num(g_pcvarGhostChance), 0, 100))
        {
            modifiedDamage = 0.0;
            changed = true;
        }

        if (g_miseryMask[attacker] & MISERY_MERCY)
        {
            new Float:victimHealth;
            pev(victim, pev_health, victimHealth);

            if (modifiedDamage >= victimHealth)
            {
                modifiedDamage = victimHealth > 1.0 ? victimHealth - 1.0 : 0.0;
                changed = true;
            }
        }
    }

    if (changed)
    {
        SetHamParamFloat(4, modifiedDamage);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

public OnSetModelPost(entity, const model[])
{
    if (!get_pcvar_num(g_pcvarEnabled)
        || !get_pcvar_num(g_pcvarSkullGrenades)
        || !pev_valid(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[24];
    pev(entity, pev_classname, classname, charsmax(classname));

    if (!equal(classname, "grenade") || containi(model, "grenade") < 0)
    {
        return FMRES_IGNORED;
    }

    new Float:minimums[3] = {-2.0, -2.0, -2.0};
    new Float:maximums[3] = {2.0, 2.0, 2.0};

    engfunc(EngFunc_SetModel, entity, SKULL_MODEL);
    engfunc(EngFunc_SetSize, entity, minimums, maximums);
    set_pev(entity, pev_body, 0);
    set_pev(entity, pev_skin, 0);
    set_pev(entity, pev_sequence, 0);

    return FMRES_HANDLED;
}

public TaskMiseryTick()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new Float:now = get_gametime();

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id) || !(g_miseryMask[id] & MISERY_FOOTSTEPS))
        {
            continue;
        }

        if (now >= g_nextFootstep[id])
        {
            EmitPhantomFootstep(id);
            ScheduleNextFootstep(id, now);
        }
    }
}

stock ApplyMovementStutter(id, userCmd, Float:now)
{
    if (!g_stuttering[id] && now >= g_nextStutter[id])
    {
        g_stuttering[id] = true;
        g_stutterUntil[id] = now + ClampFloat(get_pcvar_float(g_pcvarStutterDuration), 0.03, 0.50);
    }

    if (g_stuttering[id] && now >= g_stutterUntil[id])
    {
        g_stuttering[id] = false;
        ScheduleNextStutter(id, now);
        return;
    }

    if (!g_stuttering[id])
    {
        return;
    }

    new Float:forwardMove;
    new Float:sideMove;
    new Float:upMove;
    get_uc(userCmd, UC_ForwardMove, forwardMove);
    get_uc(userCmd, UC_SideMove, sideMove);
    get_uc(userCmd, UC_UpMove, upMove);

    new Float:factor = ClampFloat(get_pcvar_float(g_pcvarStutterFactor), 0.0, 1.0);
    set_uc(userCmd, UC_ForwardMove, forwardMove * factor);
    set_uc(userCmd, UC_SideMove, sideMove * factor);
    set_uc(userCmd, UC_UpMove, upMove * factor);
}

stock ApplyWeaponChoke(id, userCmd, buttons, Float:now)
{
    if (!(buttons & (IN_ATTACK | IN_ATTACK2)))
    {
        g_choking[id] = false;
        return;
    }

    if (g_choking[id] && now >= g_chokeUntil[id])
    {
        g_choking[id] = false;
    }

    if (!g_choking[id] && now >= g_nextChokeCheck[id])
    {
        g_nextChokeCheck[id] = now + 0.09;

        if (random_num(1, 100) <= ClampInt(get_pcvar_num(g_pcvarChokeChance), 0, 100))
        {
            g_choking[id] = true;
            g_chokeUntil[id] = now + ClampFloat(get_pcvar_float(g_pcvarChokeDuration), 0.03, 0.50);
        }
    }

    if (g_choking[id])
    {
        buttons &= ~(IN_ATTACK | IN_ATTACK2);
        set_uc(userCmd, UC_Buttons, buttons);
    }
}

stock ApplyShadowPressure(id, userCmd, buttons, Float:now)
{
    if (now < g_nextShadowNudge[id])
    {
        return;
    }

    new target, body;
    get_user_aiming(id, target, body, 8192);
    if (target < 1 || target > MaxClients || !is_user_alive(target))
    {
        return;
    }

    g_nextShadowNudge[id] = now + 0.16;

    new Float:maximum = ClampFloat(get_pcvar_float(g_pcvarShadowDegrees), 0.0, 8.0);
    new Float:punch[3];
    pev(id, pev_punchangle, punch);
    punch[0] += random_float(-maximum, maximum);
    punch[1] += random_float(-maximum, maximum);
    punch[2] += random_float(-maximum * 0.25, maximum * 0.25);
    set_pev(id, pev_punchangle, punch);

    if (random_num(1, 100) <= ClampInt(get_pcvar_num(g_pcvarShadowJamChance), 0, 100))
    {
        buttons &= ~(IN_ATTACK | IN_ATTACK2);
        set_uc(userCmd, UC_Buttons, buttons);
    }
}

stock EmitPhantomFootstep(id)
{
    new soundIndex = random_num(0, sizeof FOOTSTEP_SOUNDS - 1);
    emit_sound(id, CHAN_BODY, FOOTSTEP_SOUNDS[soundIndex], 0.72, ATTN_NORM, 0, random_num(94, 106));
}

stock ScheduleClientEffects(id)
{
    new Float:now = get_gametime();
    ScheduleNextStutter(id, now);
    ScheduleNextFootstep(id, now);
    g_nextChokeCheck[id] = now + random_float(0.20, 0.70);
    g_nextShadowNudge[id] = now;
}

stock ScheduleNextStutter(id, Float:now)
{
    new Float:minimum = ClampFloat(get_pcvar_float(g_pcvarStutterMinInterval), 0.25, 30.0);
    new Float:maximum = ClampFloat(get_pcvar_float(g_pcvarStutterMaxInterval), minimum, 60.0);
    g_nextStutter[id] = now + random_float(minimum, maximum);
}

stock ScheduleNextFootstep(id, Float:now)
{
    new Float:minimum = ClampFloat(get_pcvar_float(g_pcvarFootstepMinInterval), 0.25, 30.0);
    new Float:maximum = ClampFloat(get_pcvar_float(g_pcvarFootstepMaxInterval), minimum, 60.0);
    g_nextFootstep[id] = now + random_float(minimum, maximum);
}

stock ShowTargetMenu(id)
{
    new menu = menu_create("\rHLDM Silent Misery", "TargetMenuHandler");
    new count;

    for (new target = 1; target <= MaxClients; target++)
    {
        if (!CanTarget(id, target))
        {
            continue;
        }

        new name[32], info[8], itemText[96];
        get_user_name(target, name, charsmax(name));
        num_to_str(target, info, charsmax(info));
        formatex(itemText, charsmax(itemText), "#%d %s \y[mask %d]", get_user_userid(target), name, g_miseryMask[target]);
        menu_additem(menu, itemText, info);
        count++;
    }

    if (!count)
    {
        menu_destroy(menu);
        client_print(id, print_chat, "[MISERY] no eligible players connected.");
        return;
    }

    menu_display(id, menu);
}

stock ShowActionMenu(id, target)
{
    new name[32], title[112];
    get_user_name(target, name, charsmax(name));
    formatex(title, charsmax(title), "\rSilent Misery: \w%s \y#%d | mask=%d", name, get_user_userid(target), g_miseryMask[target]);

    new menu = menu_create(title, "ActionMenuHandler");
    menu_additem(menu, "Ghost hits: some impacts do zero damage", "1");
    menu_additem(menu, "One-HP mercy: lethal hits leave the victim alive", "2");
    menu_additem(menu, "Frailty: incoming damage increases", "3");
    menu_additem(menu, "Movement stutter: brief input collapse", "4");
    menu_additem(menu, "Weapon choke: automatic fire quietly coughs", "5");
    menu_additem(menu, "Phantom footsteps: false position noise", "6");
    menu_additem(menu, "Shadow pressure: aim fails near a real target", "7");
    menu_additem(menu, "\rFULL SILENT MISERY", "8");
    menu_additem(menu, "\yClear silent misery", "9");
    menu_additem(menu, "Inspect state", "10");
    menu_display(id, menu);
}

stock ToggleBit(admin, target, bit, const label[])
{
    if (g_miseryMask[target] & bit)
    {
        g_miseryMask[target] &= ~bit;
    }
    else
    {
        g_miseryMask[target] |= bit;
    }

    SaveState(target);
    ScheduleClientEffects(target);

    new message[96];
    formatex(message, charsmax(message), "%s %s", label, (g_miseryMask[target] & bit) ? "ON" : "OFF");
    PrintAdminState(admin, target, message);
}

stock ClearState(admin, target)
{
    g_miseryMask[target] = 0;
    g_choking[target] = false;
    g_stuttering[target] = false;
    SaveState(target);
    PrintAdminState(admin, target, "SILENT MISERY CLEARED");
}

stock PrintAdminState(admin, target, const action[])
{
    new name[32];
    get_user_name(target, name, charsmax(name));
    client_print(admin, print_chat, "[MISERY] #%d %s: %s; mask=%d.", get_user_userid(target), name, action, g_miseryMask[target]);
}

stock PrintTargetStatus(admin, target)
{
    new name[32], authid[40], ip[32];
    get_user_name(target, name, charsmax(name));
    get_user_authid(target, authid, charsmax(authid));
    get_user_ip(target, ip, charsmax(ip), 1);
    console_print(admin, "[MISERY] #%d %s <%s> ip=%s mask=%d", get_user_userid(target), name, authid, ip, g_miseryMask[target]);
}

stock SaveState(id)
{
    if (g_vault == INVALID_HANDLE)
    {
        return;
    }

    new authid[40];
    if (!GetPersistentAuthId(id, authid, charsmax(authid)))
    {
        return;
    }

    if (!g_miseryMask[id])
    {
        nvault_remove(g_vault, authid);
        return;
    }

    new value[16];
    num_to_str(g_miseryMask[id], value, charsmax(value));
    nvault_set(g_vault, authid, value);
}

stock LoadState(id)
{
    if (g_vault == INVALID_HANDLE || !is_user_connected(id))
    {
        return;
    }

    new authid[40];
    if (!GetPersistentAuthId(id, authid, charsmax(authid)))
    {
        return;
    }

    new value[16];
    if (nvault_get(g_vault, authid, value, charsmax(value)))
    {
        g_miseryMask[id] = str_to_num(value) & MISERY_ALL;
    }
}

stock bool:GetPersistentAuthId(id, output[], outputLength)
{
    get_user_authid(id, output, outputLength);
    return output[0]
        && !equali(output, "STEAM_ID_PENDING")
        && !equali(output, "STEAM_ID_LAN")
        && !equali(output, "VALVE_ID_LAN")
        && !equali(output, "BOT")
        && !equali(output, "HLTV");
}

stock bool:CanTarget(admin, target)
{
    if (target < 1
        || target > MaxClients
        || target == admin
        || !is_user_connected(target)
        || is_user_bot(target)
        || is_user_hltv(target))
    {
        return false;
    }

    if (get_pcvar_num(g_pcvarAdminImmunity) && is_user_admin(target))
    {
        return false;
    }

    return true;
}

stock bool:IsAdminClient(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id) && is_user_admin(id);
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
    g_miseryMask[id] = 0;
    g_selectedTarget[id] = 0;
    g_previousButtons[id] = 0;
    g_choking[id] = false;
    g_stuttering[id] = false;
    g_nextChokeCheck[id] = 0.0;
    g_chokeUntil[id] = 0.0;
    g_nextStutter[id] = 0.0;
    g_stutterUntil[id] = 0.0;
    g_nextFootstep[id] = 0.0;
    g_nextShadowNudge[id] = 0.0;
}
