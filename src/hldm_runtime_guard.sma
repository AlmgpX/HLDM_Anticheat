#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Runtime Guard"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_SYNC 31001
#define TASK_RENDER 31002
#define TASK_HUD 31003
#define TASK_AUTO_BASE 31100

new bool:g_hardCap[MAX_PLAYERS + 1];
new bool:g_guardOwned[MAX_PLAYERS + 1];
new bool:g_xray[MAX_PLAYERS + 1];
new bool:g_noclip[MAX_PLAYERS + 1];
new g_selected[MAX_PLAYERS + 1];
new g_beamSprite;
new g_vault = INVALID_HANDLE;

new g_pcvarEnabled;
new g_pcvarDamageCap;
new g_pcvarSlayOnMark;
new g_pcvarXrayAuto;
new g_pcvarXrayDistance;
new g_pcvarNoclipSpeed;
new g_pcvarPublicNotice;

public plugin_precache()
{
    g_beamSprite = precache_model("sprites/laserbeam.spr");
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_guard_menu", "CmdMenu", ADMIN_RCON, "- open player control menu");
    register_concmd("amx_guard_punish", "CmdPunish", ADMIN_RCON, "<name|#userid|SteamID> - trap, slay and cap damage");
    register_concmd("amx_guard_unpunish", "CmdUnpunish", ADMIN_RCON, "<name|#userid|SteamID> - remove guard punishment");
    register_concmd("amx_guard_xray", "CmdXray", ADMIN_RCON, "[0|1] - toggle projected wall xray");
    register_concmd("amx_guard_noclip", "CmdNoclip", ADMIN_RCON, "[0|1] - toggle enforced admin noclip");
    register_concmd("amx_guard_status", "CmdStatus", ADMIN_RCON, "- show guard state");
    register_clcmd("say /ac", "CmdChatMenu");
    register_clcmd("say_team /ac", "CmdChatMenu");

    g_pcvarEnabled = register_cvar("hldm_guard_enabled", "1");
    g_pcvarDamageCap = register_cvar("hldm_guard_damage_cap", "1.0");
    g_pcvarSlayOnMark = register_cvar("hldm_guard_slay_on_mark", "1");
    g_pcvarXrayAuto = register_cvar("hldm_guard_xray_auto", "1");
    g_pcvarXrayDistance = register_cvar("hldm_guard_xray_distance", "16384.0");
    g_pcvarNoclipSpeed = register_cvar("hldm_guard_noclip_speed", "1000.0");
    g_pcvarPublicNotice = register_cvar("hldm_guard_public_notice", "1");

    AutoExecConfig(true, "hldm_runtime_guard");

    RegisterHam(Ham_TakeDamage, "player", "OnTakeDamage", false);
    RegisterHam(Ham_Spawn, "player", "OnPlayerSpawnPost", true);
    register_forward(FM_PlayerPreThink, "OnPlayerPreThink", false);

    set_task(0.25, "TaskSyncVault", TASK_SYNC, _, _, "b");
    set_task(0.08, "TaskRenderXray", TASK_RENDER, _, _, "b");
    set_task(0.50, "TaskHud", TASK_HUD, _, _, "b");

    g_vault = nvault_open("hldm_trap_targets");
    if (g_vault == INVALID_HANDLE)
    {
        log_amx("Could not open hldm_trap_targets vault; automatic mirroring is unavailable.");
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

public client_putinserver(id)
{
    ResetClient(id);
    remove_task(TASK_AUTO_BASE + id);
    set_task(1.0, "TaskAutoAdmin", TASK_AUTO_BASE + id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    remove_task(TASK_AUTO_BASE + id);
    DisableNoclip(id);
    ResetClient(id);
}

public TaskAutoAdmin(taskId)
{
    new id = taskId - TASK_AUTO_BASE;
    if (!is_user_connected(id))
    {
        return;
    }

    if (!is_user_admin(id))
    {
        set_task(1.0, "TaskAutoAdmin", taskId);
        return;
    }

    if (get_pcvar_num(g_pcvarXrayAuto))
    {
        g_xray[id] = true;
        client_print(id, print_chat, "[GUARD] X-ray enabled. F5 noclip, F6 x-ray, F8 player menu, or type /ac.");
    }
}

public OnPlayerSpawnPost(id)
{
    if (!is_user_alive(id))
    {
        return HAM_IGNORED;
    }

    if (g_noclip[id] && is_user_admin(id))
    {
        ApplyNoclip(id);
    }

    return HAM_IGNORED;
}

public OnPlayerPreThink(id)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !g_noclip[id] || !is_user_alive(id) || !is_user_admin(id))
    {
        return FMRES_IGNORED;
    }

    ApplyNoclip(id);
    return FMRES_HANDLED;
}

public OnTakeDamage(victim, inflictor, attacker, Float:damage, damageBits)
{
    if (!get_pcvar_num(g_pcvarEnabled)
        || attacker < 1
        || attacker > MaxClients
        || attacker == victim
        || !g_hardCap[attacker])
    {
        return HAM_IGNORED;
    }

    new Float:cap = ClampFloat(get_pcvar_float(g_pcvarDamageCap), 0.1, 10.0);
    SetHamParamFloat(4, cap);
    return HAM_HANDLED;
}

public TaskSyncVault()
{
    if (!get_pcvar_num(g_pcvarEnabled) || g_vault == INVALID_HANDLE)
    {
        return;
    }

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || is_user_admin(id) || is_user_bot(id) || is_user_hltv(id))
        {
            continue;
        }

        new authid[40];
        get_user_authid(id, authid, charsmax(authid));
        if (!IsPersistentAuthId(authid))
        {
            continue;
        }

        new bool:marked = nvault_get(g_vault, authid) == 1;
        if (marked && !g_hardCap[id])
        {
            MarkPlayer(id, false, "trap-vault");
        }
        else if (!marked && g_hardCap[id] && !g_guardOwned[id])
        {
            g_hardCap[id] = false;
        }
    }
}

public TaskRenderXray()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new Float:maxDistance = ClampFloat(get_pcvar_float(g_pcvarXrayDistance), 512.0, 32768.0);
    new Float:maxDistanceSquared = maxDistance * maxDistance;

    for (new viewer = 1; viewer <= MaxClients; viewer++)
    {
        if (!g_xray[viewer] || !is_user_alive(viewer) || !is_user_admin(viewer))
        {
            continue;
        }

        new Float:viewerOrigin[3];
        pev(viewer, pev_origin, viewerOrigin);

        for (new target = 1; target <= MaxClients; target++)
        {
            if (target == viewer || !is_user_alive(target))
            {
                continue;
            }

            new Float:targetOrigin[3];
            pev(target, pev_origin, targetOrigin);
            if (VectorDistanceSquared(viewerOrigin, targetOrigin) > maxDistanceSquared)
            {
                continue;
            }

            DrawProjectedMarker(viewer, target, g_hardCap[target]);
        }
    }
}

public TaskHud()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    for (new viewer = 1; viewer <= MaxClients; viewer++)
    {
        if (!g_xray[viewer] || !is_user_connected(viewer) || !is_user_admin(viewer))
        {
            continue;
        }

        ShowDebugHud(viewer);
    }
}

public CmdChatMenu(id)
{
    if (!IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    ShowPlayerMenu(id);
    return PLUGIN_HANDLED;
}

public CmdMenu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    ShowPlayerMenu(id);
    return PLUGIN_HANDLED;
}

public CmdPunish(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
    {
        return PLUGIN_HANDLED;
    }

    new argument[64];
    read_argv(1, argument, charsmax(argument));
    new target = cmd_target(id, argument, CMDTARGET_NO_BOTS | CMDTARGET_OBEY_IMMUNITY);
    if (!target || !CanPunish(id, target))
    {
        return PLUGIN_HANDLED;
    }

    MarkPlayer(target, true, "manual-command");
    AnnouncePunishment(id, target);
    return PLUGIN_HANDLED;
}

public CmdUnpunish(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
    {
        return PLUGIN_HANDLED;
    }

    new argument[64];
    read_argv(1, argument, charsmax(argument));
    new target = cmd_target(id, argument, CMDTARGET_NO_BOTS | CMDTARGET_OBEY_IMMUNITY);
    if (!target)
    {
        return PLUGIN_HANDLED;
    }

    UnmarkPlayer(target);
    server_cmd("amx_untrap #%d", get_user_userid(target));
    server_exec();
    return PLUGIN_HANDLED;
}

public CmdXray(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    if (read_argc() >= 2)
    {
        new argument[8];
        read_argv(1, argument, charsmax(argument));
        g_xray[id] = bool:(str_to_num(argument) != 0);
    }
    else
    {
        g_xray[id] = !g_xray[id];
    }

    client_print(id, print_chat, "[GUARD] projected wall x-ray %s.", g_xray[id] ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

public CmdNoclip(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    if (!is_user_alive(id))
    {
        client_print(id, print_chat, "[GUARD] noclip requires a living admin.");
        return PLUGIN_HANDLED;
    }

    new bool:enable = !g_noclip[id];
    if (read_argc() >= 2)
    {
        new argument[8];
        read_argv(1, argument, charsmax(argument));
        enable = bool:(str_to_num(argument) != 0);
    }

    g_noclip[id] = enable;
    if (enable)
    {
        ApplyNoclip(id);
    }
    else
    {
        DisableNoclip(id);
    }

    client_print(id, print_chat, "[GUARD] enforced noclip %s.", enable ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

public CmdStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(id, "[GUARD] enabled=%d cap=%.1f", get_pcvar_num(g_pcvarEnabled), get_pcvar_float(g_pcvarDamageCap));
    for (new target = 1; target <= MaxClients; target++)
    {
        if (is_user_connected(target) && g_hardCap[target])
        {
            new name[32], authid[40];
            get_user_name(target, name, charsmax(name));
            get_user_authid(target, authid, charsmax(authid));
            console_print(id, "  #%d %s <%s> hardcap=1", get_user_userid(target), name, authid);
        }
    }

    return PLUGIN_HANDLED;
}

public PlayerMenuHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    new access, callback, info[8], displayName[64];
    menu_item_getinfo(menu, item, access, info, charsmax(info), displayName, charsmax(displayName), callback);
    menu_destroy(menu);

    new target = str_to_num(info);
    if (!CanPunish(id, target))
    {
        client_print(id, print_chat, "[GUARD] target unavailable.");
        return PLUGIN_HANDLED;
    }

    g_selected[id] = target;
    ShowActionMenu(id, target);
    return PLUGIN_HANDLED;
}

public ActionMenuHandler(id, menu, item)
{
    if (item == MENU_EXIT)
    {
        menu_destroy(menu);
        ShowPlayerMenu(id);
        return PLUGIN_HANDLED;
    }

    new access, callback, info[8], displayName[64];
    menu_item_getinfo(menu, item, access, info, charsmax(info), displayName, charsmax(displayName), callback);
    menu_destroy(menu);

    new target = g_selected[id];
    if (!CanPunish(id, target))
    {
        client_print(id, print_chat, "[GUARD] target unavailable.");
        return PLUGIN_HANDLED;
    }

    switch (str_to_num(info))
    {
        case 1:
        {
            MarkPlayer(target, true, "menu");
            AnnouncePunishment(id, target);
        }
        case 2:
        {
            UnmarkPlayer(target);
            server_cmd("amx_untrap #%d", get_user_userid(target));
            server_exec();
        }
        case 3: PrintPlayerStatus(id, target);
        case 4: user_kill(target, 1);
    }

    return PLUGIN_HANDLED;
}

stock ShowPlayerMenu(id)
{
    new menu = menu_create("\rHLDM Runtime Guard", "PlayerMenuHandler");
    new count;

    for (new target = 1; target <= MaxClients; target++)
    {
        if (!CanPunish(id, target))
        {
            continue;
        }

        new name[32], model[32], item[96], info[8];
        get_user_name(target, name, charsmax(name));
        get_user_info(target, "model", model, charsmax(model));
        formatex(item, charsmax(item), "#%d %s \y[%s, HP %d%s]", get_user_userid(target), name, model, get_user_health(target), g_hardCap[target] ? ", CAPPED" : "");
        num_to_str(target, info, charsmax(info));
        menu_additem(menu, item, info);
        count++;
    }

    if (!count)
    {
        menu_destroy(menu);
        client_print(id, print_chat, "[GUARD] no non-admin players connected.");
        return;
    }

    menu_display(id, menu);
}

stock ShowActionMenu(id, target)
{
    new name[32], title[96];
    get_user_name(target, name, charsmax(name));
    formatex(title, charsmax(title), "\rTarget: \w%s \y#%d", name, get_user_userid(target));

    new menu = menu_create(title, "ActionMenuHandler");
    menu_additem(menu, "\rTRAP + SLAY + 1 DAMAGE CAP", "1");
    menu_additem(menu, "\yRemove all punishment", "2");
    menu_additem(menu, "Show SteamID / IP / model", "3");
    menu_additem(menu, "Slay once", "4");
    menu_display(id, menu);
}

stock MarkPlayer(target, bool:owned, const reason[])
{
    if (!is_user_connected(target) || is_user_admin(target) || is_user_bot(target))
    {
        return;
    }

    new bool:wasMarked = g_hardCap[target];
    g_hardCap[target] = true;
    if (owned)
    {
        g_guardOwned[target] = true;
    }

    new authid[40];
    get_user_authid(target, authid, charsmax(authid));
    if (g_vault != INVALID_HANDLE && IsPersistentAuthId(authid))
    {
        nvault_set(g_vault, authid, "1");
    }

    if (!wasMarked && get_pcvar_num(g_pcvarSlayOnMark) && is_user_alive(target))
    {
        user_kill(target, 1);
    }

    server_cmd("amx_trap #%d", get_user_userid(target));
    server_exec();
    log_amx("Guard marked #%d <%s> reason=%s", get_user_userid(target), authid, reason);
}

stock UnmarkPlayer(target)
{
    if (!is_user_connected(target))
    {
        return;
    }

    new authid[40];
    get_user_authid(target, authid, charsmax(authid));
    if (g_vault != INVALID_HANDLE && IsPersistentAuthId(authid))
    {
        nvault_remove(g_vault, authid);
    }

    g_hardCap[target] = false;
    g_guardOwned[target] = false;
}

stock AnnouncePunishment(admin, target)
{
    new name[32];
    get_user_name(target, name, charsmax(name));
    client_print(admin, print_chat, "[GUARD] #%d %s trapped; outgoing damage is capped at 1.", get_user_userid(target), name);

    if (get_pcvar_num(g_pcvarPublicNotice))
    {
        client_print(0, print_chat, "[SERVER] %s failed integrity control.", name);
    }
}

stock ApplyNoclip(id)
{
    set_pev(id, pev_movetype, MOVETYPE_NOCLIP);
    set_pev(id, pev_solid, SOLID_NOT);
    set_pev(id, pev_gravity, 0.0);
    set_pev(id, pev_maxspeed, ClampFloat(get_pcvar_float(g_pcvarNoclipSpeed), 200.0, 2000.0));
}

stock DisableNoclip(id)
{
    g_noclip[id] = false;
    if (!is_user_connected(id) || !is_user_alive(id))
    {
        return;
    }

    set_pev(id, pev_movetype, MOVETYPE_WALK);
    set_pev(id, pev_solid, SOLID_SLIDEBOX);
    set_pev(id, pev_gravity, 1.0);
}

stock DrawProjectedMarker(viewer, target, bool:punished)
{
    new Float:eye[3], Float:viewOffset[3], Float:targetCenter[3], Float:direction[3];
    pev(viewer, pev_origin, eye);
    pev(viewer, pev_view_ofs, viewOffset);
    eye[0] += viewOffset[0];
    eye[1] += viewOffset[1];
    eye[2] += viewOffset[2];

    pev(target, pev_origin, targetCenter);
    targetCenter[2] += 36.0;
    direction[0] = targetCenter[0] - eye[0];
    direction[1] = targetCenter[1] - eye[1];
    direction[2] = targetCenter[2] - eye[2];
    if (!NormalizeVector(direction))
    {
        return;
    }

    new Float:center[3];
    center[0] = eye[0] + direction[0] * 16.0;
    center[1] = eye[1] + direction[1] * 16.0;
    center[2] = eye[2] + direction[2] * 16.0;

    new red = punished ? 255 : 255;
    new green = punished ? 32 : 220;
    new blue = punished ? 32 : 32;

    new Float:left[3], Float:right[3], Float:down[3], Float:up[3];
    left[0] = center[0] - 0.8; left[1] = center[1]; left[2] = center[2];
    right[0] = center[0] + 0.8; right[1] = center[1]; right[2] = center[2];
    down[0] = center[0]; down[1] = center[1]; down[2] = center[2] - 0.8;
    up[0] = center[0]; up[1] = center[1]; up[2] = center[2] + 0.8;
    DrawLine(viewer, left, right, red, green, blue);
    DrawLine(viewer, down, up, red, green, blue);
}

stock DrawLine(viewer, const Float:start[3], const Float:finish[3], red, green, blue)
{
    message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, viewer);
    write_byte(TE_BEAMPOINTS);
    engfunc(EngFunc_WriteCoord, start[0]);
    engfunc(EngFunc_WriteCoord, start[1]);
    engfunc(EngFunc_WriteCoord, start[2]);
    engfunc(EngFunc_WriteCoord, finish[0]);
    engfunc(EngFunc_WriteCoord, finish[1]);
    engfunc(EngFunc_WriteCoord, finish[2]);
    write_short(g_beamSprite);
    write_byte(0);
    write_byte(0);
    write_byte(2);
    write_byte(5);
    write_byte(0);
    write_byte(red);
    write_byte(green);
    write_byte(blue);
    write_byte(255);
    write_byte(0);
    message_end();
}

stock ShowDebugHud(viewer)
{
    new output[512], length;
    length += formatex(output[length], charsmax(output) - length, "GUARD XRAY | /ac menu^n");

    new Float:viewAngles[3], Float:forward[3], Float:right[3], Float:up[3];
    pev(viewer, pev_v_angle, viewAngles);
    engfunc(EngFunc_AngleVectors, viewAngles, forward, right, up);

    new Float:viewerOrigin[3];
    pev(viewer, pev_origin, viewerOrigin);

    for (new target = 1; target <= MaxClients && length < charsmax(output) - 80; target++)
    {
        if (target == viewer || !is_user_alive(target))
        {
            continue;
        }

        new Float:targetOrigin[3], Float:direction[3];
        pev(target, pev_origin, targetOrigin);
        direction[0] = targetOrigin[0] - viewerOrigin[0];
        direction[1] = targetOrigin[1] - viewerOrigin[1];
        direction[2] = targetOrigin[2] - viewerOrigin[2];
        new distance = floatround(floatsqroot(VectorDistanceSquared(viewerOrigin, targetOrigin)));
        NormalizeVector(direction);

        new Float:frontDot = DotProduct(forward, direction);
        new Float:sideDot = DotProduct(right, direction);
        new bearing[8];
        if (frontDot < -0.25)
        {
            copy(bearing, charsmax(bearing), "BACK");
        }
        else if (floatabs(sideDot) < 0.25)
        {
            copy(bearing, charsmax(bearing), "AHEAD");
        }
        else if (sideDot > 0.0)
        {
            copy(bearing, charsmax(bearing), "RIGHT");
        }
        else
        {
            copy(bearing, charsmax(bearing), "LEFT");
        }

        new name[32];
        get_user_name(target, name, charsmax(name));
        length += formatex(output[length], charsmax(output) - length, "#%d %-12s %s D:%d%s^n", get_user_userid(target), name, bearing, distance, g_hardCap[target] ? " CAP" : "");
    }

    set_hudmessage(255, 230, 80, 0.01, 0.12, 0, 0.0, 0.55, 0.0, 0.0, 3);
    show_hudmessage(viewer, "%s", output);
}

stock PrintPlayerStatus(admin, target)
{
    new name[32], authid[40], ip[32], model[32], ping, loss;
    get_user_name(target, name, charsmax(name));
    get_user_authid(target, authid, charsmax(authid));
    get_user_ip(target, ip, charsmax(ip), 1);
    get_user_info(target, "model", model, charsmax(model));
    get_user_ping(target, ping, loss);
    console_print(admin, "[GUARD] #%d %s <%s> ip=%s model=%s hp=%d armor=%d ping=%d capped=%d", get_user_userid(target), name, authid, ip, model, get_user_health(target), get_user_armor(target), ping, g_hardCap[target]);
}

stock bool:IsAdminClient(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id) && is_user_admin(id);
}

stock bool:CanPunish(admin, target)
{
    return target >= 1
        && target <= MaxClients
        && target != admin
        && is_user_connected(target)
        && !is_user_admin(target)
        && !is_user_bot(target)
        && !is_user_hltv(target);
}

stock bool:IsPersistentAuthId(const authid[])
{
    return authid[0]
        && !equali(authid, "STEAM_ID_PENDING")
        && !equali(authid, "STEAM_ID_LAN")
        && !equali(authid, "VALVE_ID_LAN")
        && !equali(authid, "BOT")
        && !equali(authid, "HLTV");
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

stock Float:DotProduct(const Float:left[3], const Float:right[3])
{
    return left[0] * right[0] + left[1] * right[1] + left[2] * right[2];
}

stock Float:VectorDistanceSquared(const Float:left[3], const Float:right[3])
{
    new Float:x = left[0] - right[0];
    new Float:y = left[1] - right[1];
    new Float:z = left[2] - right[2];
    return x * x + y * y + z * z;
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
    g_hardCap[id] = false;
    g_guardOwned[id] = false;
    g_xray[id] = false;
    g_noclip[id] = false;
    g_selected[id] = 0;
}
