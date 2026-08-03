#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Admin Tools"
#define PLUGIN_VERSION "1.1.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_RENDER 24501

#define ESP_MODE_HULL  1
#define ESP_MODE_ZONES 2
#define ESP_MODE_BOTH  3

new bool:g_adminEsp[MAX_PLAYERS + 1];
new g_adminMode[MAX_PLAYERS + 1];
new g_beamSprite;

new g_pcvarEnabled;
new g_pcvarDefaultMode;
new g_pcvarThroughWalls;
new g_pcvarRequireAlive;
new g_pcvarMaxDistance;
new g_pcvarLineLife;
new g_pcvarLineWidth;
new g_pcvarAimHud;

new const g_standardModels[][] =
{
    "barney",
    "gina",
    "gman",
    "gordon",
    "helmet",
    "hgrunt",
    "recon",
    "robo",
    "scientist",
    "zombie"
};

public plugin_precache()
{
    g_beamSprite = precache_model("sprites/laserbeam.spr");
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_ac_esp", "CmdEsp", ADMIN_RCON, "[0|1] - toggle personal admin overlay");
    register_concmd("amx_ac_esp_mode", "CmdEspMode", ADMIN_RCON, "[1|2|3] - hull, body zones, both");
    register_concmd("amx_ac_aim", "CmdAimAction", ADMIN_RCON, "<status|trap|untrap> - act on aimed player");
    register_concmd("amx_ac_binds", "CmdBinds", ADMIN_RCON, "- print recommended local binds");

    g_pcvarEnabled = register_cvar("hldm_admin_enabled", "1");
    g_pcvarDefaultMode = register_cvar("hldm_admin_default_mode", "3");
    g_pcvarThroughWalls = register_cvar("hldm_admin_through_walls", "1");
    g_pcvarRequireAlive = register_cvar("hldm_admin_require_alive", "0");
    g_pcvarMaxDistance = register_cvar("hldm_admin_max_distance", "4096.0");
    g_pcvarLineLife = register_cvar("hldm_admin_line_life", "4");
    g_pcvarLineWidth = register_cvar("hldm_admin_line_width", "1");
    g_pcvarAimHud = register_cvar("hldm_admin_aim_hud", "1");

    AutoExecConfig(true, "hldm_admin_tools");
    set_task(0.25, "TaskRender", TASK_RENDER, _, _, "b");
}

public client_connect(id)
{
    ResetAdmin(id);
}

public client_putinserver(id)
{
    ResetAdmin(id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    ResetAdmin(id);
}

public CmdEsp(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !RequirePlayerAdmin(id))
    {
        return PLUGIN_HANDLED;
    }

    if (read_argc() >= 2)
    {
        new argument[8];
        read_argv(1, argument, charsmax(argument));
        g_adminEsp[id] = bool:(str_to_num(argument) != 0);
    }
    else
    {
        g_adminEsp[id] = !g_adminEsp[id];
    }

    client_print(id, print_chat, "[HLDM Admin] ESP %s. Mode=%d.", g_adminEsp[id] ? "ON" : "OFF", g_adminMode[id]);
    console_print(id, "[HLDM Admin] ESP %s. Mode=%d.", g_adminEsp[id] ? "ON" : "OFF", g_adminMode[id]);
    return PLUGIN_HANDLED;
}

public CmdEspMode(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !RequirePlayerAdmin(id))
    {
        return PLUGIN_HANDLED;
    }

    if (read_argc() >= 2)
    {
        new argument[8];
        read_argv(1, argument, charsmax(argument));
        g_adminMode[id] = ClampInt(str_to_num(argument), ESP_MODE_HULL, ESP_MODE_BOTH);
    }
    else
    {
        g_adminMode[id]++;
        if (g_adminMode[id] > ESP_MODE_BOTH)
        {
            g_adminMode[id] = ESP_MODE_HULL;
        }
    }

    client_print(id, print_chat, "[HLDM Admin] ESP mode=%d (1 hull, 2 zones, 3 both).", g_adminMode[id]);
    console_print(id, "[HLDM Admin] ESP mode=%d (1 hull, 2 zones, 3 both).", g_adminMode[id]);
    return PLUGIN_HANDLED;
}

public CmdAimAction(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2) || !RequirePlayerAdmin(id))
    {
        return PLUGIN_HANDLED;
    }

    new action[16];
    read_argv(1, action, charsmax(action));

    new target, body;
    get_user_aiming(id, target, body, 8192);

    if (!IsLivePlayer(target) || target == id)
    {
        client_print(id, print_chat, "[HLDM Admin] No live player under crosshair.");
        console_print(id, "[HLDM Admin] No live player under crosshair.");
        return PLUGIN_HANDLED;
    }

    if (equali(action, "status"))
    {
        PrintAimStatus(id, target, body);
        return PLUGIN_HANDLED;
    }

    new userId = get_user_userid(target);

    if (equali(action, "trap"))
    {
        server_cmd("amx_trap #%d", userId);
        server_exec();
        client_print(id, print_chat, "[HLDM Admin] Trap requested for #%d.", userId);
        return PLUGIN_HANDLED;
    }

    if (equali(action, "untrap"))
    {
        server_cmd("amx_untrap #%d", userId);
        server_exec();
        client_print(id, print_chat, "[HLDM Admin] Untrap requested for #%d.", userId);
        return PLUGIN_HANDLED;
    }

    console_print(id, "Usage: amx_ac_aim <status|trap|untrap>");
    return PLUGIN_HANDLED;
}

public CmdBinds(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(id, "bind ^"F6^" ^"amx_ac_esp^"");
    console_print(id, "bind ^"F7^" ^"amx_ac_esp_mode^"");
    console_print(id, "bind ^"F8^" ^"amx_ac_aim status^"");
    console_print(id, "bind ^"F9^" ^"amx_ac_aim trap^"");
    console_print(id, "bind ^"F10^" ^"amx_ac_aim untrap^"");
    console_print(id, "bind ^"F11^" ^"amx_ac_status^"");
    console_print(id, "bind ^"F12^" ^"amx_trap_list^"");
    return PLUGIN_HANDLED;
}

public TaskRender()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new bool:throughWalls = bool:(get_pcvar_num(g_pcvarThroughWalls) != 0);
    new bool:requireAlive = bool:(get_pcvar_num(g_pcvarRequireAlive) != 0);
    new Float:maxDistance = ClampFloat(get_pcvar_float(g_pcvarMaxDistance), 256.0, 16384.0);
    new Float:maxDistanceSquared = maxDistance * maxDistance;

    for (new viewer = 1; viewer <= MaxClients; viewer++)
    {
        if (!g_adminEsp[viewer] || !is_user_connected(viewer) || !is_user_admin(viewer))
        {
            continue;
        }

        if (requireAlive && !is_user_alive(viewer))
        {
            continue;
        }

        new aimedTarget, aimedBody;
        get_user_aiming(viewer, aimedTarget, aimedBody, 8192);

        new Float:viewerOrigin[3];
        pev(viewer, pev_origin, viewerOrigin);

        for (new target = 1; target <= MaxClients; target++)
        {
            if (target == viewer || !IsLivePlayer(target))
            {
                continue;
            }

            new Float:targetOrigin[3];
            pev(target, pev_origin, targetOrigin);

            if (VectorDistanceSquared(viewerOrigin, targetOrigin) > maxDistanceSquared)
            {
                continue;
            }

            if (!throughWalls && !CanSeePlayer(viewer, target))
            {
                continue;
            }

            DrawTargetOverlay(viewer, target, target == aimedTarget);
        }

        if (get_pcvar_num(g_pcvarAimHud) && IsLivePlayer(aimedTarget) && aimedTarget != viewer)
        {
            ShowAimHud(viewer, aimedTarget, aimedBody);
        }
    }
}

stock DrawTargetOverlay(viewer, target, bool:isAimed)
{
    new red = 40;
    new green = 255;
    new blue = 90;

    new model[32];
    get_user_info(target, "model", model, charsmax(model));

    if (!IsStandardModel(model))
    {
        red = 255;
        green = 40;
        blue = 255;
    }

    if (isAimed)
    {
        red = 255;
        green = 64;
        blue = 64;
    }

    switch (g_adminMode[viewer])
    {
        case ESP_MODE_HULL:
        {
            DrawPlayerHull(viewer, target, red, green, blue);
        }
        case ESP_MODE_ZONES:
        {
            DrawBodyZones(viewer, target, red, green, blue);
        }
        default:
        {
            DrawPlayerHull(viewer, target, red, green, blue);
            DrawBodyZones(viewer, target, red, green, blue);
        }
    }
}

stock DrawPlayerHull(viewer, target, red, green, blue)
{
    new Float:minimum[3], Float:maximum[3];
    pev(target, pev_absmin, minimum);
    pev(target, pev_absmax, maximum);

    minimum[0] -= 1.0;
    minimum[1] -= 1.0;
    minimum[2] -= 1.0;
    maximum[0] += 1.0;
    maximum[1] += 1.0;
    maximum[2] += 1.0;

    DrawBox(viewer, minimum, maximum, red, green, blue);
}

stock DrawBodyZones(viewer, target, red, green, blue)
{
    new Float:minimum[3], Float:maximum[3];
    pev(target, pev_absmin, minimum);
    pev(target, pev_absmax, maximum);

    new Float:height = maximum[2] - minimum[2];
    if (height < 24.0)
    {
        return;
    }

    new Float:zoneMinimum[3], Float:zoneMaximum[3];

    CopyVector(minimum, zoneMinimum);
    CopyVector(maximum, zoneMaximum);
    InsetHorizontal(zoneMinimum, zoneMaximum, 4.0);
    zoneMinimum[2] = maximum[2] - height * 0.24;
    DrawBox(viewer, zoneMinimum, zoneMaximum, 255, 96, 64);

    CopyVector(minimum, zoneMinimum);
    CopyVector(maximum, zoneMaximum);
    InsetHorizontal(zoneMinimum, zoneMaximum, 5.0);
    zoneMinimum[2] = minimum[2] + height * 0.35;
    zoneMaximum[2] = maximum[2] - height * 0.24;
    DrawBox(viewer, zoneMinimum, zoneMaximum, red, green, blue);

    CopyVector(minimum, zoneMinimum);
    CopyVector(maximum, zoneMaximum);
    InsetHorizontal(zoneMinimum, zoneMaximum, 6.0);
    zoneMaximum[2] = minimum[2] + height * 0.35;
    DrawBox(viewer, zoneMinimum, zoneMaximum, 96, 160, 255);
}

stock DrawBox(viewer, const Float:minimum[3], const Float:maximum[3], red, green, blue)
{
    new Float:corner[8][3];

    corner[0][0] = minimum[0]; corner[0][1] = minimum[1]; corner[0][2] = minimum[2];
    corner[1][0] = maximum[0]; corner[1][1] = minimum[1]; corner[1][2] = minimum[2];
    corner[2][0] = maximum[0]; corner[2][1] = maximum[1]; corner[2][2] = minimum[2];
    corner[3][0] = minimum[0]; corner[3][1] = maximum[1]; corner[3][2] = minimum[2];
    corner[4][0] = minimum[0]; corner[4][1] = minimum[1]; corner[4][2] = maximum[2];
    corner[5][0] = maximum[0]; corner[5][1] = minimum[1]; corner[5][2] = maximum[2];
    corner[6][0] = maximum[0]; corner[6][1] = maximum[1]; corner[6][2] = maximum[2];
    corner[7][0] = minimum[0]; corner[7][1] = maximum[1]; corner[7][2] = maximum[2];

    DrawLine(viewer, corner[0], corner[1], red, green, blue);
    DrawLine(viewer, corner[1], corner[2], red, green, blue);
    DrawLine(viewer, corner[2], corner[3], red, green, blue);
    DrawLine(viewer, corner[3], corner[0], red, green, blue);

    DrawLine(viewer, corner[4], corner[5], red, green, blue);
    DrawLine(viewer, corner[5], corner[6], red, green, blue);
    DrawLine(viewer, corner[6], corner[7], red, green, blue);
    DrawLine(viewer, corner[7], corner[4], red, green, blue);

    DrawLine(viewer, corner[0], corner[4], red, green, blue);
    DrawLine(viewer, corner[1], corner[5], red, green, blue);
    DrawLine(viewer, corner[2], corner[6], red, green, blue);
    DrawLine(viewer, corner[3], corner[7], red, green, blue);
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
    write_byte(ClampInt(get_pcvar_num(g_pcvarLineLife), 1, 20));
    write_byte(ClampInt(get_pcvar_num(g_pcvarLineWidth), 1, 16));
    write_byte(0);
    write_byte(ClampInt(red, 0, 255));
    write_byte(ClampInt(green, 0, 255));
    write_byte(ClampInt(blue, 0, 255));
    write_byte(220);
    write_byte(0);
    message_end();
}

stock ShowAimHud(viewer, target, body)
{
    new name[32], authid[40], model[32], bodyName[16];
    get_user_name(target, name, charsmax(name));
    get_user_authid(target, authid, charsmax(authid));
    get_user_info(target, "model", model, charsmax(model));
    GetBodyName(body, bodyName, charsmax(bodyName));

    set_hudmessage(220, 240, 255, 0.02, 0.20, 0, 0.0, 0.35, 0.0, 0.0, 4);
    show_hudmessage(
        viewer,
        "#%d %s^n%s | model=%s^nHP=%d armor=%d | hit=%s",
        get_user_userid(target),
        name,
        authid,
        model,
        get_user_health(target),
        get_user_armor(target),
        bodyName
    );
}

stock PrintAimStatus(viewer, target, body)
{
    new name[32], authid[40], ip[32], model[32], bodyName[16];
    get_user_name(target, name, charsmax(name));
    get_user_authid(target, authid, charsmax(authid));
    get_user_ip(target, ip, charsmax(ip), 1);
    get_user_info(target, "model", model, charsmax(model));
    GetBodyName(body, bodyName, charsmax(bodyName));

    console_print(
        viewer,
        "[HLDM Admin] #%d %s <%s> ip=%s model=%s hp=%d armor=%d aimed=%s",
        get_user_userid(target),
        name,
        authid,
        ip,
        model,
        get_user_health(target),
        get_user_armor(target),
        bodyName
    );
    client_print(viewer, print_chat, "[HLDM Admin] #%d %s <%s> model=%s", get_user_userid(target), name, authid, model);
}

stock bool:RequirePlayerAdmin(id)
{
    if (id < 1 || id > MaxClients || !is_user_connected(id))
    {
        console_print(id, "[HLDM Admin] This command requires an in-game admin client.");
        return false;
    }

    return true;
}

stock bool:IsLivePlayer(id)
{
    return id >= 1 && id <= MaxClients && is_user_alive(id);
}

stock bool:CanSeePlayer(viewer, target)
{
    new Float:start[3], Float:finish[3], Float:viewOffset[3];
    pev(viewer, pev_origin, start);
    pev(viewer, pev_view_ofs, viewOffset);
    start[0] += viewOffset[0];
    start[1] += viewOffset[1];
    start[2] += viewOffset[2];

    pev(target, pev_origin, finish);
    finish[2] += 36.0;

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, start, finish, DONT_IGNORE_MONSTERS, viewer, trace);

    new hit = get_tr2(trace, TR_pHit);
    new Float:fraction;
    get_tr2(trace, TR_flFraction, fraction);
    free_tr2(trace);

    return hit == target || fraction >= 0.999;
}

stock Float:VectorDistanceSquared(const Float:left[3], const Float:right[3])
{
    new Float:x = left[0] - right[0];
    new Float:y = left[1] - right[1];
    new Float:z = left[2] - right[2];
    return x * x + y * y + z * z;
}

stock CopyVector(const Float:source[3], Float:destination[3])
{
    destination[0] = source[0];
    destination[1] = source[1];
    destination[2] = source[2];
}

stock InsetHorizontal(Float:minimum[3], Float:maximum[3], Float:amount)
{
    minimum[0] += amount;
    minimum[1] += amount;
    maximum[0] -= amount;
    maximum[1] -= amount;
}

stock bool:IsStandardModel(const model[])
{
    for (new index = 0; index < sizeof g_standardModels; index++)
    {
        if (equali(model, g_standardModels[index]))
        {
            return true;
        }
    }

    return false;
}

stock GetBodyName(body, output[], outputLength)
{
    switch (body)
    {
        case 1: copy(output, outputLength, "HEAD");
        case 2: copy(output, outputLength, "CHEST");
        case 3: copy(output, outputLength, "STOMACH");
        case 4: copy(output, outputLength, "LEFT ARM");
        case 5: copy(output, outputLength, "RIGHT ARM");
        case 6: copy(output, outputLength, "LEFT LEG");
        case 7: copy(output, outputLength, "RIGHT LEG");
        default: copy(output, outputLength, "NONE");
    }
}

stock ResetAdmin(id)
{
    g_adminEsp[id] = false;
    g_adminMode[id] = ClampInt(get_pcvar_num(g_pcvarDefaultMode), ESP_MODE_HULL, ESP_MODE_BOTH);
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
