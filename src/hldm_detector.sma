#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Anticheat Detector"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_DECAY 19401

enum SignalType
{
    Signal_SnapFire = 0,
    Signal_InstantReaction,
    Signal_RapidSwitch,
    Signal_InvalidAngles,
    Signal_Count
};

new bool:g_inServer[MAX_PLAYERS + 1];
new bool:g_haveAngles[MAX_PLAYERS + 1];
new bool:g_autoApplied[MAX_PLAYERS + 1];

new Float:g_joinTime[MAX_PLAYERS + 1];
new Float:g_lastCmdTime[MAX_PLAYERS + 1];
new Float:g_lastAngles[MAX_PLAYERS + 1][3];
new Float:g_nextVisibilityScan[MAX_PLAYERS + 1];
new Float:g_visibleSince[MAX_PLAYERS + 1];
new Float:g_lastShotTime[MAX_PLAYERS + 1];
new Float:g_score[MAX_PLAYERS + 1];
new Float:g_lastAlertTime[MAX_PLAYERS + 1];
new Float:g_lastAutoTime[MAX_PLAYERS + 1];

new g_lastButtons[MAX_PLAYERS + 1];
new g_visibleTarget[MAX_PLAYERS + 1];
new g_lastShotTarget[MAX_PLAYERS + 1];
new g_signalCount[MAX_PLAYERS + 1][Signal_Count];
new g_categoryMask[MAX_PLAYERS + 1];

new g_pcvarEnabled;
new g_pcvarMode;
new g_pcvarWarmup;
new g_pcvarScanInterval;
new g_pcvarVisibleDot;
new g_pcvarScoreDecay;
new g_pcvarScoreMaximum;
new g_pcvarThreshold;
new g_pcvarAlertThreshold;
new g_pcvarAlertCooldown;
new g_pcvarAutoCooldown;
new g_pcvarMinimumCategories;
new g_pcvarMinimumEvents;
new g_pcvarExemptAdmins;
new g_pcvarSnapDegrees;
new g_pcvarSnapMaxInterval;
new g_pcvarSnapPoints;
new g_pcvarReactionMilliseconds;
new g_pcvarReactionPoints;
new g_pcvarSwitchDegrees;
new g_pcvarSwitchWindow;
new g_pcvarSwitchPoints;
new g_pcvarInvalidAnglePoints;
new g_pcvarLogging;

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_ac_status", "CmdStatus", ADMIN_RCON, "[name|#userid|SteamID] - show detector state");
    register_concmd("amx_ac_reset", "CmdReset", ADMIN_RCON, "<name|#userid|SteamID|@all> - reset detector state");
    register_concmd("amx_ac_mode", "CmdMode", ADMIN_RCON, "[0|1|2] - off, observe, automatic trap");
    register_concmd("amx_ac_testtrap", "CmdTestTrap", ADMIN_RCON, "<name|#userid|SteamID> - verify detector to trap integration");

    g_pcvarEnabled = register_cvar("hldm_ac_enabled", "1");
    g_pcvarMode = register_cvar("hldm_ac_mode", "2");
    g_pcvarWarmup = register_cvar("hldm_ac_warmup_seconds", "20.0");
    g_pcvarScanInterval = register_cvar("hldm_ac_visibility_scan_interval", "0.05");
    g_pcvarVisibleDot = register_cvar("hldm_ac_visible_dot_min", "0.94");
    g_pcvarScoreDecay = register_cvar("hldm_ac_score_decay_per_second", "1.5");
    g_pcvarScoreMaximum = register_cvar("hldm_ac_score_maximum", "250.0");
    g_pcvarThreshold = register_cvar("hldm_ac_auto_threshold", "100.0");
    g_pcvarAlertThreshold = register_cvar("hldm_ac_alert_threshold", "60.0");
    g_pcvarAlertCooldown = register_cvar("hldm_ac_alert_cooldown_seconds", "10.0");
    g_pcvarAutoCooldown = register_cvar("hldm_ac_auto_cooldown_seconds", "60.0");
    g_pcvarMinimumCategories = register_cvar("hldm_ac_minimum_categories", "2");
    g_pcvarMinimumEvents = register_cvar("hldm_ac_minimum_events", "5");
    g_pcvarExemptAdmins = register_cvar("hldm_ac_exempt_admins", "1");

    g_pcvarSnapDegrees = register_cvar("hldm_ac_snap_degrees", "35.0");
    g_pcvarSnapMaxInterval = register_cvar("hldm_ac_snap_max_cmd_interval", "0.08");
    g_pcvarSnapPoints = register_cvar("hldm_ac_snap_points", "18.0");

    g_pcvarReactionMilliseconds = register_cvar("hldm_ac_reaction_milliseconds", "90.0");
    g_pcvarReactionPoints = register_cvar("hldm_ac_reaction_points", "24.0");

    g_pcvarSwitchDegrees = register_cvar("hldm_ac_switch_degrees", "30.0");
    g_pcvarSwitchWindow = register_cvar("hldm_ac_switch_window_seconds", "0.35");
    g_pcvarSwitchPoints = register_cvar("hldm_ac_switch_points", "20.0");

    g_pcvarInvalidAnglePoints = register_cvar("hldm_ac_invalid_angle_points", "100.0");
    g_pcvarLogging = register_cvar("hldm_ac_log_events", "1");

    AutoExecConfig(true, "hldm_detector");

    register_forward(FM_CmdStart, "OnCmdStart", false);
    set_task(1.0, "TaskDecayScores", TASK_DECAY, _, _, "b");
}

public plugin_cfg()
{
    if (!cvar_exists("hldm_trap_enabled"))
    {
        log_amx("hldm_trap plugin was not detected. Automatic mode will fall back to observe-only.");
        set_pcvar_num(g_pcvarMode, 1);
    }
}

public client_connect(id)
{
    ResetPlayer(id);
}

public client_putinserver(id)
{
    ResetPlayer(id);
    g_inServer[id] = true;
    g_joinTime[id] = get_gametime();
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    ResetPlayer(id);
}

public OnCmdStart(id, userCmd, randomSeed)
{
    if (!get_pcvar_num(g_pcvarEnabled) || get_pcvar_num(g_pcvarMode) == 0 || !is_user_alive(id))
    {
        return FMRES_IGNORED;
    }

    if (IsExempt(id))
    {
        return FMRES_IGNORED;
    }

    new Float:now = get_gametime();
    new Float:warmup = ClampFloat(get_pcvar_float(g_pcvarWarmup), 0.0, 300.0);

    new buttons = get_uc(userCmd, UC_Buttons);
    new bool:attackEdge = bool:(buttons & IN_ATTACK) && !(g_lastButtons[id] & IN_ATTACK);

    new Float:angles[3];
    get_uc(userCmd, UC_ViewAngles, angles);

    new Float:cmdInterval = 0.0;
    new Float:angleDelta = 0.0;

    if (g_haveAngles[id])
    {
        cmdInterval = now - g_lastCmdTime[id];
        angleDelta = GetAngularDelta(g_lastAngles[id], angles);
    }

    if (HasInvalidAngles(angles))
    {
        AddSignal(id, Signal_InvalidAngles, get_pcvar_float(g_pcvarInvalidAnglePoints), angleDelta, "invalid-angles");
    }

    if (now >= g_nextVisibilityScan[id])
    {
        UpdateVisibleTarget(id, angles, now);
        g_nextVisibilityScan[id] = now + ClampFloat(get_pcvar_float(g_pcvarScanInterval), 0.02, 0.50);
    }

    if (attackEdge && g_haveAngles[id] && (now - g_joinTime[id]) >= warmup)
    {
        new aimTarget = TraceAimTarget(id, angles);

        if (aimTarget > 0)
        {
            new Float:snapDegrees = ClampFloat(get_pcvar_float(g_pcvarSnapDegrees), 5.0, 180.0);
            new Float:maxCmdInterval = ClampFloat(get_pcvar_float(g_pcvarSnapMaxInterval), 0.01, 0.50);

            if (angleDelta >= snapDegrees && cmdInterval > 0.0 && cmdInterval <= maxCmdInterval)
            {
                AddSignal(id, Signal_SnapFire, get_pcvar_float(g_pcvarSnapPoints), angleDelta, "snap-fire");
            }

            if (g_visibleTarget[id] == aimTarget && g_visibleSince[id] > 0.0)
            {
                new Float:reactionMilliseconds = (now - g_visibleSince[id]) * 1000.0;
                new Float:reactionLimit = ClampFloat(get_pcvar_float(g_pcvarReactionMilliseconds), 20.0, 500.0);

                if (reactionMilliseconds >= 0.0 && reactionMilliseconds <= reactionLimit)
                {
                    AddSignal(
                        id,
                        Signal_InstantReaction,
                        get_pcvar_float(g_pcvarReactionPoints),
                        reactionMilliseconds,
                        "instant-reaction"
                    );
                }
            }

            new Float:switchWindow = ClampFloat(get_pcvar_float(g_pcvarSwitchWindow), 0.05, 2.0);
            new Float:switchDegrees = ClampFloat(get_pcvar_float(g_pcvarSwitchDegrees), 5.0, 180.0);

            if (g_lastShotTarget[id] > 0
                && g_lastShotTarget[id] != aimTarget
                && (now - g_lastShotTime[id]) <= switchWindow
                && angleDelta >= switchDegrees)
            {
                AddSignal(id, Signal_RapidSwitch, get_pcvar_float(g_pcvarSwitchPoints), angleDelta, "rapid-target-switch");
            }

            g_lastShotTarget[id] = aimTarget;
        }

        g_lastShotTime[id] = now;
    }

    g_lastButtons[id] = buttons;
    g_lastCmdTime[id] = now;
    g_lastAngles[id][0] = angles[0];
    g_lastAngles[id][1] = angles[1];
    g_lastAngles[id][2] = angles[2];
    g_haveAngles[id] = true;

    return FMRES_IGNORED;
}

public TaskDecayScores()
{
    new Float:decay = ClampFloat(get_pcvar_float(g_pcvarScoreDecay), 0.0, 100.0);

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!g_inServer[id] || g_score[id] <= 0.0)
        {
            continue;
        }

        g_score[id] -= decay;
        if (g_score[id] < 0.0)
        {
            g_score[id] = 0.0;
        }
    }
}

public CmdStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    if (read_argc() >= 2)
    {
        new argument[64];
        read_argv(1, argument, charsmax(argument));

        new target = cmd_target(id, argument, CMDTARGET_ALLOW_SELF);
        if (target)
        {
            PrintStatus(id, target);
        }

        return PLUGIN_HANDLED;
    }

    console_print(id, "[HLDM AC] mode=%d enabled=%d", get_pcvar_num(g_pcvarMode), get_pcvar_num(g_pcvarEnabled));

    for (new player = 1; player <= MaxClients; player++)
    {
        if (is_user_connected(player) && (g_score[player] > 0.0 || g_autoApplied[player]))
        {
            PrintStatus(id, player);
        }
    }

    return PLUGIN_HANDLED;
}

public CmdReset(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
    {
        return PLUGIN_HANDLED;
    }

    new argument[64];
    read_argv(1, argument, charsmax(argument));

    if (equali(argument, "@all"))
    {
        for (new player = 1; player <= MaxClients; player++)
        {
            if (is_user_connected(player))
            {
                ResetEvidence(player);
            }
        }

        console_print(id, "[HLDM AC] Evidence reset for all connected clients.");
        return PLUGIN_HANDLED;
    }

    new target = cmd_target(id, argument, CMDTARGET_ALLOW_SELF);
    if (!target)
    {
        return PLUGIN_HANDLED;
    }

    ResetEvidence(target);
    console_print(id, "[HLDM AC] Evidence reset for #%d.", get_user_userid(target));
    return PLUGIN_HANDLED;
}

public CmdMode(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    if (read_argc() >= 2)
    {
        new argument[8];
        read_argv(1, argument, charsmax(argument));

        new mode = ClampInt(str_to_num(argument), 0, 2);
        set_pcvar_num(g_pcvarMode, mode);
        log_amx("Detector mode changed to %d by admin index %d", mode, id);
    }

    console_print(id, "[HLDM AC] mode=%d (0 off, 1 observe, 2 automatic trap)", get_pcvar_num(g_pcvarMode));
    return PLUGIN_HANDLED;
}

public CmdTestTrap(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
    {
        return PLUGIN_HANDLED;
    }

    new argument[64];
    read_argv(1, argument, charsmax(argument));

    new target = cmd_target(id, argument, CMDTARGET_ALLOW_SELF);
    if (!target)
    {
        return PLUGIN_HANDLED;
    }

    ApplyTrap(target, "integration-test");
    console_print(id, "[HLDM AC] Trap integration test sent for #%d.", get_user_userid(target));
    return PLUGIN_HANDLED;
}

stock AddSignal(id, SignalType:signal, Float:points, Float:value, const signalName[])
{
    if (!g_inServer[id] || points <= 0.0)
    {
        return;
    }

    new Float:maximum = ClampFloat(get_pcvar_float(g_pcvarScoreMaximum), 10.0, 1000.0);
    g_score[id] = ClampFloat(g_score[id] + points, 0.0, maximum);
    g_signalCount[id][signal]++;
    g_categoryMask[id] |= (1 << _:signal);

    if (get_pcvar_num(g_pcvarLogging))
    {
        LogSignal(id, signalName, points, value);
    }

    MaybeAlert(id);
    MaybeApplyTrap(id, signalName);
}

stock MaybeAlert(id)
{
    new Float:threshold = ClampFloat(get_pcvar_float(g_pcvarAlertThreshold), 1.0, 1000.0);
    if (g_score[id] < threshold)
    {
        return;
    }

    new Float:now = get_gametime();
    new Float:cooldown = ClampFloat(get_pcvar_float(g_pcvarAlertCooldown), 1.0, 300.0);
    if ((now - g_lastAlertTime[id]) < cooldown)
    {
        return;
    }

    g_lastAlertTime[id] = now;

    new name[32], authid[40];
    get_user_name(id, name, charsmax(name));
    get_user_authid(id, authid, charsmax(authid));

    for (new admin = 1; admin <= MaxClients; admin++)
    {
        if (!is_user_connected(admin) || !is_user_admin(admin))
        {
            continue;
        }

        client_print(
            admin,
            print_chat,
            "[HLDM AC] %s score=%.1f categories=%d events=%d",
            name,
            g_score[id],
            CountCategories(g_categoryMask[id]),
            CountEvents(id)
        );

        console_print(
            admin,
            "[HLDM AC] suspect #%d %s <%s> score=%.1f snap=%d reaction=%d switch=%d invalid=%d",
            get_user_userid(id),
            name,
            authid,
            g_score[id],
            g_signalCount[id][Signal_SnapFire],
            g_signalCount[id][Signal_InstantReaction],
            g_signalCount[id][Signal_RapidSwitch],
            g_signalCount[id][Signal_InvalidAngles]
        );
    }
}

stock MaybeApplyTrap(id, const reason[])
{
    if (get_pcvar_num(g_pcvarMode) != 2 || g_autoApplied[id])
    {
        return;
    }

    new Float:threshold = ClampFloat(get_pcvar_float(g_pcvarThreshold), 10.0, 1000.0);
    if (g_score[id] < threshold)
    {
        return;
    }

    new minimumCategories = ClampInt(get_pcvar_num(g_pcvarMinimumCategories), 1, _:Signal_Count);
    new minimumEvents = ClampInt(get_pcvar_num(g_pcvarMinimumEvents), 1, 100);

    if (CountCategories(g_categoryMask[id]) < minimumCategories || CountEvents(id) < minimumEvents)
    {
        return;
    }

    new Float:now = get_gametime();
    new Float:cooldown = ClampFloat(get_pcvar_float(g_pcvarAutoCooldown), 1.0, 3600.0);
    if ((now - g_lastAutoTime[id]) < cooldown)
    {
        return;
    }

    g_lastAutoTime[id] = now;
    g_autoApplied[id] = true;
    ApplyTrap(id, reason);
}

stock ApplyTrap(id, const reason[])
{
    if (!is_user_connected(id))
    {
        return;
    }

    new userId = get_user_userid(id);
    server_cmd("amx_trap #%d", userId);
    server_exec();

    new name[32], authid[40];
    get_user_name(id, name, charsmax(name));
    get_user_authid(id, authid, charsmax(authid));

    log_amx(
        "Automatic trap requested for ^"%s^" <%s> userid=%d score=%.1f reason=%s",
        name,
        authid,
        userId,
        g_score[id],
        reason
    );
}

stock UpdateVisibleTarget(id, const Float:angles[3], Float:now)
{
    new target = FindBestVisibleTarget(id, angles);

    if (target == g_visibleTarget[id])
    {
        return;
    }

    g_visibleTarget[id] = target;
    g_visibleSince[id] = target > 0 ? now : 0.0;
}

stock FindBestVisibleTarget(id, const Float:angles[3])
{
    new Float:eye[3];
    new Float:forwardVector[3], Float:rightVector[3], Float:upVector[3];
    GetEyePosition(id, eye);
    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);

    new Float:minimumDot = ClampFloat(get_pcvar_float(g_pcvarVisibleDot), 0.50, 0.9999);
    new bestTarget = 0;
    new Float:bestDot = minimumDot;

    for (new target = 1; target <= MaxClients; target++)
    {
        if (target == id || !is_user_alive(target))
        {
            continue;
        }

        new Float:targetEye[3], Float:direction[3];
        GetEyePosition(target, targetEye);

        direction[0] = targetEye[0] - eye[0];
        direction[1] = targetEye[1] - eye[1];
        direction[2] = targetEye[2] - eye[2];

        if (!NormalizeVector(direction))
        {
            continue;
        }

        new Float:dot = DotProduct(forwardVector, direction);
        if (dot <= bestDot || !CanSeeTarget(id, target, eye, targetEye))
        {
            continue;
        }

        bestDot = dot;
        bestTarget = target;
    }

    return bestTarget;
}

stock TraceAimTarget(id, const Float:angles[3])
{
    new Float:eye[3], Float:forwardVector[3], Float:rightVector[3], Float:upVector[3], Float:traceEnd[3];
    GetEyePosition(id, eye);
    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);

    traceEnd[0] = eye[0] + forwardVector[0] * 8192.0;
    traceEnd[1] = eye[1] + forwardVector[1] * 8192.0;
    traceEnd[2] = eye[2] + forwardVector[2] * 8192.0;

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, eye, traceEnd, DONT_IGNORE_MONSTERS, id, trace);
    new hit = get_tr2(trace, TR_pHit);
    free_tr2(trace);

    if (hit >= 1 && hit <= MaxClients && hit != id && is_user_alive(hit))
    {
        return hit;
    }

    return 0;
}

stock bool:CanSeeTarget(id, target, const Float:traceStart[3], const Float:traceEnd[3])
{
    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, traceStart, traceEnd, DONT_IGNORE_MONSTERS, id, trace);

    new hit = get_tr2(trace, TR_pHit);
    new Float:fraction;
    get_tr2(trace, TR_flFraction, fraction);
    free_tr2(trace);

    return hit == target || fraction >= 0.999;
}

stock GetEyePosition(id, Float:output[3])
{
    new Float:origin[3], Float:viewOffset[3];
    pev(id, pev_origin, origin);
    pev(id, pev_view_ofs, viewOffset);

    output[0] = origin[0] + viewOffset[0];
    output[1] = origin[1] + viewOffset[1];
    output[2] = origin[2] + viewOffset[2];
}

stock Float:GetAngularDelta(const Float:previous[3], const Float:current[3])
{
    new Float:pitch = NormalizeAngle(current[0] - previous[0]);
    new Float:yaw = NormalizeAngle(current[1] - previous[1]);

    return floatsqroot(pitch * pitch + yaw * yaw);
}

stock Float:NormalizeAngle(Float:value)
{
    while (value > 180.0)
    {
        value -= 360.0;
    }

    while (value < -180.0)
    {
        value += 360.0;
    }

    return value;
}

stock bool:HasInvalidAngles(const Float:angles[3])
{
    return floatabs(angles[0]) > 89.5 || floatabs(angles[1]) > 720.0 || floatabs(angles[2]) > 50.0;
}

stock bool:NormalizeVector(Float:vector[3])
{
    new Float:length = floatsqroot(
        vector[0] * vector[0]
        + vector[1] * vector[1]
        + vector[2] * vector[2]
    );

    if (length <= 0.001)
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

stock bool:IsExempt(id)
{
    return get_pcvar_num(g_pcvarExemptAdmins) && is_user_admin(id);
}

stock CountEvents(id)
{
    new total = 0;
    for (new signal = 0; signal < Signal_Count; signal++)
    {
        total += g_signalCount[id][signal];
    }

    return total;
}

stock CountCategories(mask)
{
    new count = 0;
    for (new bit = 0; bit < Signal_Count; bit++)
    {
        if (mask & (1 << bit))
        {
            count++;
        }
    }

    return count;
}

stock PrintStatus(admin, target)
{
    new name[32], authid[40];
    get_user_name(target, name, charsmax(name));
    get_user_authid(target, authid, charsmax(authid));

    console_print(
        admin,
        "[HLDM AC] #%d %s <%s> score=%.1f categories=%d events=%d auto=%d",
        get_user_userid(target),
        name,
        authid,
        g_score[target],
        CountCategories(g_categoryMask[target]),
        CountEvents(target),
        g_autoApplied[target]
    );

    console_print(
        admin,
        "          snap=%d reaction=%d switch=%d invalid=%d visible=#%d",
        g_signalCount[target][Signal_SnapFire],
        g_signalCount[target][Signal_InstantReaction],
        g_signalCount[target][Signal_RapidSwitch],
        g_signalCount[target][Signal_InvalidAngles],
        g_visibleTarget[target] > 0 ? get_user_userid(g_visibleTarget[target]) : 0
    );
}

stock LogSignal(id, const signalName[], Float:points, Float:value)
{
    new name[32], authid[40], ip[32];
    get_user_name(id, name, charsmax(name));
    get_user_authid(id, authid, charsmax(authid));
    get_user_ip(id, ip, charsmax(ip), 1);

    new ping, loss;
    get_user_ping(id, ping, loss);

    log_to_file(
        "hldm_anticheat_events.log",
        "signal=%s name=^"%s^" auth=^"%s^" ip=%s userid=%d points=%.1f value=%.2f score=%.1f ping=%d loss=%d",
        signalName,
        name,
        authid,
        ip,
        get_user_userid(id),
        points,
        value,
        g_score[id],
        ping,
        loss
    );
}

stock ResetPlayer(id)
{
    g_inServer[id] = false;
    g_haveAngles[id] = false;
    g_autoApplied[id] = false;

    g_joinTime[id] = 0.0;
    g_lastCmdTime[id] = 0.0;
    g_lastAngles[id][0] = 0.0;
    g_lastAngles[id][1] = 0.0;
    g_lastAngles[id][2] = 0.0;
    g_nextVisibilityScan[id] = 0.0;
    g_visibleSince[id] = 0.0;
    g_lastShotTime[id] = 0.0;
    g_score[id] = 0.0;
    g_lastAlertTime[id] = 0.0;
    g_lastAutoTime[id] = -9999.0;

    g_lastButtons[id] = 0;
    g_visibleTarget[id] = 0;
    g_lastShotTarget[id] = 0;
    g_categoryMask[id] = 0;

    for (new signal = 0; signal < Signal_Count; signal++)
    {
        g_signalCount[id][signal] = 0;
    }
}

stock ResetEvidence(id)
{
    g_autoApplied[id] = false;
    g_score[id] = 0.0;
    g_lastAlertTime[id] = 0.0;
    g_lastAutoTime[id] = -9999.0;
    g_lastShotTarget[id] = 0;
    g_categoryMask[id] = 0;

    for (new signal = 0; signal < Signal_Count; signal++)
    {
        g_signalCount[id][signal] = 0;
    }
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
