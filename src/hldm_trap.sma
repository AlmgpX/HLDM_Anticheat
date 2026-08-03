#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

#define PLUGIN_NAME    "HLDM Trap"
#define PLUGIN_VERSION "0.1.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_HUD 9100
#define TASK_MODEL_BASE 9200

enum TrapPhase
{
    TrapPhase_Soft = 0,
    TrapPhase_Recovery,
    TrapPhase_Hard
};

new bool:g_trapped[MAX_PLAYERS + 1];
new TrapPhase:g_phase[MAX_PLAYERS + 1];
new Float:g_phaseUntil[MAX_PLAYERS + 1];
new g_authId[MAX_PLAYERS + 1][40];
new g_vault = INVALID_HANDLE;

new g_pcvarEnabled;
new g_pcvarPersist;
new g_pcvarOutgoingScale;
new g_pcvarIncomingScale;
new g_pcvarJumpFailChance;
new g_pcvarAttackFailChance;
new g_pcvarStrafeFlipChance;
new g_pcvarPunishMin;
new g_pcvarPunishMax;
new g_pcvarRecoveryMin;
new g_pcvarRecoveryMax;
new g_pcvarHud;
new g_pcvarForceStandardModels;
new g_pcvarForcedModel;

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

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_trap", "CmdTrap", ADMIN_RCON, "<name|#userid|SteamID> - enable trap");
    register_concmd("amx_untrap", "CmdUntrap", ADMIN_RCON, "<name|#userid|SteamID> - disable trap");
    register_concmd("amx_trap_list", "CmdTrapList", ADMIN_RCON, "- list trapped players");

    g_pcvarEnabled = register_cvar("hldm_trap_enabled", "1");
    g_pcvarPersist = register_cvar("hldm_trap_persist", "1");
    g_pcvarOutgoingScale = register_cvar("hldm_trap_outgoing_scale", "0.08");
    g_pcvarIncomingScale = register_cvar("hldm_trap_incoming_scale", "1.75");
    g_pcvarJumpFailChance = register_cvar("hldm_trap_jump_fail_chance", "12");
    g_pcvarAttackFailChance = register_cvar("hldm_trap_attack_fail_chance", "6");
    g_pcvarStrafeFlipChance = register_cvar("hldm_trap_strafe_flip_chance", "4");
    g_pcvarPunishMin = register_cvar("hldm_trap_punish_min_seconds", "18");
    g_pcvarPunishMax = register_cvar("hldm_trap_punish_max_seconds", "35");
    g_pcvarRecoveryMin = register_cvar("hldm_trap_recovery_min_seconds", "7");
    g_pcvarRecoveryMax = register_cvar("hldm_trap_recovery_max_seconds", "15");
    g_pcvarHud = register_cvar("hldm_trap_hud", "1");
    g_pcvarForceStandardModels = register_cvar("hldm_trap_force_standard_models", "1");
    g_pcvarForcedModel = register_cvar("hldm_trap_forced_model", "gordon");

    AutoExecConfig(true, "hldm_trap");

    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage", false);
    register_forward(FM_CmdStart, "OnCmdStart", false);

    set_task(3.0, "TaskShowHud", TASK_HUD, _, _, "b");

    g_vault = nvault_open("hldm_trap_targets");
    if (g_vault == INVALID_HANDLE)
    {
        log_amx("Failed to open nVault. Persistence is disabled for this map.");
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

public client_authorized(id, const authid[])
{
    copy(g_authId[id], charsmax(g_authId[]), authid);

    if (equali(authid, "BOT") || equali(authid, "HLTV"))
    {
        return;
    }

    if (get_pcvar_num(g_pcvarPersist) && g_vault != INVALID_HANDLE && nvault_get(g_vault, authid) == 1)
    {
        EnableTrap(id, 0, false);
    }
}

public client_putinserver(id)
{
    remove_task(TASK_MODEL_BASE + id);
    set_task(1.0, "TaskEnforceModel", TASK_MODEL_BASE + id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    remove_task(TASK_MODEL_BASE + id);
    g_trapped[id] = false;
    g_phase[id] = TrapPhase_Soft;
    g_phaseUntil[id] = 0.0;
    g_authId[id][0] = '^0';
}

public client_infochanged(id)
{
    if (!is_user_connected(id))
    {
        return;
    }

    EnforceStandardModel(id);
}

public TaskEnforceModel(taskId)
{
    new id = taskId - TASK_MODEL_BASE;
    if (is_user_connected(id))
    {
        EnforceStandardModel(id);
    }
}

public CmdTrap(id, level, cid)
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

    EnableTrap(target, id, true);
    return PLUGIN_HANDLED;
}

public CmdUntrap(id, level, cid)
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

    DisableTrap(target, id, true);
    return PLUGIN_HANDLED;
}

public CmdTrapList(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    new count = 0;
    console_print(id, "[HLDM Trap] Active targets:");

    for (new player = 1; player <= MaxClients; player++)
    {
        if (!is_user_connected(player) || !g_trapped[player])
        {
            continue;
        }

        new name[32], authid[40];
        get_user_name(player, name, charsmax(name));
        get_user_authid(player, authid, charsmax(authid));
        console_print(id, "  #%d  %s  %s  phase=%d", get_user_userid(player), name, authid, _:g_phase[player]);
        count++;
    }

    if (!count)
    {
        console_print(id, "  none");
    }

    return PLUGIN_HANDLED;
}

public OnPlayerTakeDamage(victim, inflictor, attacker, Float:damage, damageBits)
{
    if (!get_pcvar_num(g_pcvarEnabled) || damage <= 0.0)
    {
        return HAM_IGNORED;
    }

    new Float:scale = 1.0;

    if (IsPlayerIndex(attacker) && attacker != victim && g_trapped[attacker])
    {
        new severity = GetSeverity(attacker);
        if (severity > 0)
        {
            new Float:minimumScale = ClampFloat(get_pcvar_float(g_pcvarOutgoingScale), 0.0, 1.0);
            scale *= 1.0 - ((1.0 - minimumScale) * float(severity) / 100.0);
        }
    }

    if (IsPlayerIndex(victim) && g_trapped[victim])
    {
        new severity = GetSeverity(victim);
        if (severity > 0)
        {
            new Float:maximumScale = ClampFloat(get_pcvar_float(g_pcvarIncomingScale), 1.0, 10.0);
            scale *= 1.0 + ((maximumScale - 1.0) * float(severity) / 100.0);
        }
    }

    if (floatabs(scale - 1.0) < 0.001)
    {
        return HAM_IGNORED;
    }

    SetHamParamFloat(4, damage * scale);
    return HAM_HANDLED;
}

public OnCmdStart(id, userCmd, randomSeed)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !is_user_alive(id) || !g_trapped[id])
    {
        return FMRES_IGNORED;
    }

    new severity = GetSeverity(id);
    if (severity <= 0)
    {
        return FMRES_IGNORED;
    }

    new buttons = get_uc(userCmd, UC_Buttons);
    new changed = 0;

    if ((buttons & IN_JUMP) && RollScaledChance(get_pcvar_num(g_pcvarJumpFailChance), severity))
    {
        buttons &= ~IN_JUMP;
        changed = 1;
    }

    if ((buttons & IN_ATTACK) && RollScaledChance(get_pcvar_num(g_pcvarAttackFailChance), severity))
    {
        buttons &= ~IN_ATTACK;
        changed = 1;
    }

    if (RollScaledChance(get_pcvar_num(g_pcvarStrafeFlipChance), severity))
    {
        new Float:sideMove;
        get_uc(userCmd, UC_SideMove, sideMove);

        if (floatabs(sideMove) > 1.0)
        {
            set_uc(userCmd, UC_SideMove, -sideMove);
            changed = 1;
        }
    }

    if (changed)
    {
        set_uc(userCmd, UC_Buttons, buttons);
        return FMRES_HANDLED;
    }

    return FMRES_IGNORED;
}

public TaskShowHud()
{
    if (!get_pcvar_num(g_pcvarEnabled) || !get_pcvar_num(g_pcvarHud))
    {
        return;
    }

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || !g_trapped[id])
        {
            continue;
        }

        UpdatePhase(id);

        new phaseText[24];
        switch (g_phase[id])
        {
            case TrapPhase_Recovery: copy(phaseText, charsmax(phaseText), "CALIBRATION OK");
            case TrapPhase_Hard: copy(phaseText, charsmax(phaseText), "AIM ASSIST FAILED");
            default: copy(phaseText, charsmax(phaseText), "INPUT DESYNC");
        }

        set_hudmessage(220, 220, 220, 0.70, 0.82, 0, 0.0, 2.7, 0.0, 0.0, -1);
        show_hudmessage(id, "%s^nTARGET CONFIDENCE: %d%%", phaseText, random_num(1, 17));
    }
}

stock EnableTrap(target, admin, bool:persist)
{
    g_trapped[target] = true;
    SetPhase(target, TrapPhase_Soft);

    if (persist && get_pcvar_num(g_pcvarPersist) && g_vault != INVALID_HANDLE)
    {
        EnsureAuthId(target);
        if (IsPersistentAuthId(g_authId[target]))
        {
            nvault_set(g_vault, g_authId[target], "1");
        }
    }

    new targetName[32];
    get_user_name(target, targetName, charsmax(targetName));
    console_print(admin, "[HLDM Trap] Enabled for %s (#%d)", targetName, get_user_userid(target));
    log_amx("Trap enabled for ^"%s^" <%s> by admin index %d", targetName, g_authId[target], admin);
}

stock DisableTrap(target, admin, bool:removePersistent)
{
    g_trapped[target] = false;
    g_phase[target] = TrapPhase_Soft;
    g_phaseUntil[target] = 0.0;

    if (removePersistent && g_vault != INVALID_HANDLE)
    {
        EnsureAuthId(target);
        if (IsPersistentAuthId(g_authId[target]))
        {
            nvault_remove(g_vault, g_authId[target]);
        }
    }

    new targetName[32];
    get_user_name(target, targetName, charsmax(targetName));
    console_print(admin, "[HLDM Trap] Disabled for %s (#%d)", targetName, get_user_userid(target));
    log_amx("Trap disabled for ^"%s^" <%s> by admin index %d", targetName, g_authId[target], admin);
}

stock SetPhase(id, TrapPhase:phase)
{
    g_phase[id] = phase;

    new minimumSeconds;
    new maximumSeconds;

    if (phase == TrapPhase_Recovery)
    {
        minimumSeconds = get_pcvar_num(g_pcvarRecoveryMin);
        maximumSeconds = get_pcvar_num(g_pcvarRecoveryMax);
    }
    else
    {
        minimumSeconds = get_pcvar_num(g_pcvarPunishMin);
        maximumSeconds = get_pcvar_num(g_pcvarPunishMax);
    }

    NormalizeRange(minimumSeconds, maximumSeconds, 1, 600);
    g_phaseUntil[id] = get_gametime() + float(random_num(minimumSeconds, maximumSeconds));
}

stock UpdatePhase(id)
{
    if (get_gametime() < g_phaseUntil[id])
    {
        return;
    }

    switch (g_phase[id])
    {
        case TrapPhase_Soft: SetPhase(id, TrapPhase_Recovery);
        case TrapPhase_Recovery: SetPhase(id, TrapPhase_Hard);
        case TrapPhase_Hard: SetPhase(id, TrapPhase_Recovery);
    }
}

stock GetSeverity(id)
{
    UpdatePhase(id);

    switch (g_phase[id])
    {
        case TrapPhase_Recovery: return 0;
        case TrapPhase_Soft: return 50;
    }

    return 100;
}

stock bool:RollScaledChance(baseChance, severity)
{
    baseChance = ClampInt(baseChance, 0, 100);
    severity = ClampInt(severity, 0, 100);

    new effectiveChance = (baseChance * severity) / 100;
    return effectiveChance > 0 && random_num(1, 100) <= effectiveChance;
}

stock EnforceStandardModel(id)
{
    if (!get_pcvar_num(g_pcvarForceStandardModels) || !is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
    {
        return;
    }

    new currentModel[32];
    get_user_info(id, "model", currentModel, charsmax(currentModel));

    if (IsStandardModel(currentModel))
    {
        return;
    }

    new forcedModel[32];
    get_pcvar_string(g_pcvarForcedModel, forcedModel, charsmax(forcedModel));

    if (!IsStandardModel(forcedModel))
    {
        copy(forcedModel, charsmax(forcedModel), "gordon");
    }

    log_amx("Rejected custom player model ^"%s^" from client index %d; forcing ^"%s^"", currentModel, id, forcedModel);
    set_user_info(id, "model", forcedModel);
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

stock EnsureAuthId(id)
{
    if (!g_authId[id][0])
    {
        get_user_authid(id, g_authId[id], charsmax(g_authId[]));
    }
}

stock bool:IsPersistentAuthId(const authid[])
{
    return authid[0]
        && !equali(authid, "BOT")
        && !equali(authid, "HLTV")
        && !equali(authid, "STEAM_ID_PENDING")
        && !equali(authid, "STEAM_ID_LAN")
        && !equali(authid, "VALVE_ID_LAN");
}

stock bool:IsPlayerIndex(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id);
}

stock NormalizeRange(&minimumValue, &maximumValue, lowerBound, upperBound)
{
    minimumValue = ClampInt(minimumValue, lowerBound, upperBound);
    maximumValue = ClampInt(maximumValue, lowerBound, upperBound);

    if (minimumValue > maximumValue)
    {
        new temporary = minimumValue;
        minimumValue = maximumValue;
        maximumValue = temporary;
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
