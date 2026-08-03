#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Chaos Control"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_CHAOS_TICK 42001
#define TASK_RESTORE_BASE 42100

#define CHAOS_MEAT      (1 << 0)
#define CHAOS_BEES      (1 << 1)
#define CHAOS_GRENADES  (1 << 2)
#define CHAOS_DAMAGE    (1 << 3)
#define CHAOS_ALL       (CHAOS_MEAT | CHAOS_BEES | CHAOS_GRENADES | CHAOS_DAMAGE)

#define TE_BREAKMODEL_CUSTOM 108
#define TE_BLOODSPRITE_CUSTOM 115

new g_effectMask[MAX_PLAYERS + 1];
new bool:g_protected[MAX_PLAYERS + 1];
new bool:g_adminBeeMode[MAX_PLAYERS + 1];
new g_selectedTarget[MAX_PLAYERS + 1];

new Float:g_lastBeeShot[MAX_PLAYERS + 1];
new Float:g_lastBeeBurst[MAX_PLAYERS + 1];
new Float:g_lastMeat[MAX_PLAYERS + 1];
new Float:g_lastWeird[MAX_PLAYERS + 1];
new Float:g_lastProtectNotice[MAX_PLAYERS + 1];

new bool:g_reflecting;
new g_chaosVault = INVALID_HANDLE;
new g_protectVault = INVALID_HANDLE;

new g_gibModel;
new g_bloodSprite;
new g_bloodSpraySprite;

new g_pcvarEnabled;
new g_pcvarDamageScale;
new g_pcvarBeeInterval;
new g_pcvarBeeSpeed;
new g_pcvarBeeBurstCount;
new g_pcvarMeatInterval;
new g_pcvarReflectScale;
new g_pcvarHealScale;
new g_pcvarProtectedMaxHealth;
new g_pcvarProtectIgnoreAdmins;
new g_pcvarPublicChaos;
new g_pcvarPublicProtect;
new g_pcvarWeirdPulse;

new const MEAT_SOUND[] = "common/bodysplat.wav";
new const FLESH_SOUND[] = "debris/bustflesh1.wav";

public plugin_precache()
{
    g_gibModel = precache_model("models/hgibs.mdl");
    g_bloodSprite = precache_model("sprites/blood.spr");
    g_bloodSpraySprite = precache_model("sprites/bloodspray.spr");
    precache_sound(MEAT_SOUND);
    precache_sound(FLESH_SOUND);
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_chaos_menu", "CmdChaosMenu", ADMIN_RCON, "- open chaos/protection player menu");
    register_concmd("amx_chaos_punish", "CmdChaosPunish", ADMIN_RCON, "<name|#userid|SteamID> - apply full chaos");
    register_concmd("amx_chaos_clear", "CmdChaosClear", ADMIN_RCON, "<name|#userid|SteamID> - clear chaos punishment");
    register_concmd("amx_chaos_meat", "CmdChaosMeat", ADMIN_RCON, "<name|#userid|SteamID> [0|1] - meat fountain");
    register_concmd("amx_chaos_bees", "CmdChaosBees", ADMIN_RCON, "<name|#userid|SteamID> [0|1] - hornet betrayal");
    register_concmd("amx_chaos_grenades", "CmdChaosGrenades", ADMIN_RCON, "<name|#userid|SteamID> [0|1] - grenade magnet");
    register_concmd("amx_chaos_damage", "CmdChaosDamage", ADMIN_RCON, "<name|#userid|SteamID> [0|1] - one-percent damage");
    register_concmd("amx_chaos_protect", "CmdChaosProtect", ADMIN_RCON, "<name|#userid|SteamID> [0|1] - reflect damage and heal target");
    register_concmd("amx_chaos_status", "CmdChaosStatus", ADMIN_RCON, "- print chaos/protection state");
    register_concmd("amx_bee_mode", "CmdBeeMode", ADMIN_RCON, "[0|1] - infinite admin hornet assist");
    register_concmd("amx_bee_burst", "CmdBeeBurst", ADMIN_RCON, "- fire an admin hornet swarm");

    register_clcmd("say /chaos", "CmdChatChaos");
    register_clcmd("say_team /chaos", "CmdChatChaos");

    g_pcvarEnabled = register_cvar("hldm_chaos_enabled", "1");
    g_pcvarDamageScale = register_cvar("hldm_chaos_damage_scale", "0.01");
    g_pcvarBeeInterval = register_cvar("hldm_chaos_admin_bee_interval", "0.12");
    g_pcvarBeeSpeed = register_cvar("hldm_chaos_bee_speed", "650.0");
    g_pcvarBeeBurstCount = register_cvar("hldm_chaos_bee_burst_count", "12");
    g_pcvarMeatInterval = register_cvar("hldm_chaos_meat_interval", "0.65");
    g_pcvarReflectScale = register_cvar("hldm_chaos_reflect_scale", "1.25");
    g_pcvarHealScale = register_cvar("hldm_chaos_heal_scale", "1.0");
    g_pcvarProtectedMaxHealth = register_cvar("hldm_chaos_protected_max_health", "200.0");
    g_pcvarProtectIgnoreAdmins = register_cvar("hldm_chaos_protect_ignore_admins", "1");
    g_pcvarPublicChaos = register_cvar("hldm_chaos_public_punish", "1");
    g_pcvarPublicProtect = register_cvar("hldm_chaos_public_protect", "0");
    g_pcvarWeirdPulse = register_cvar("hldm_chaos_weird_pulse", "1");

    AutoExecConfig(true, "hldm_chaos");

    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage", false);
    register_forward(FM_CmdStart, "OnCmdStart", false);
    register_forward(FM_Think, "OnEntityThinkPost", true);
    register_forward(FM_SetModel, "OnSetModelPost", true);

    set_task(0.20, "TaskChaosTick", TASK_CHAOS_TICK, _, _, "b");

    g_chaosVault = nvault_open("hldm_chaos_targets");
    g_protectVault = nvault_open("hldm_protected_targets");

    if (g_chaosVault == INVALID_HANDLE)
    {
        log_amx("Could not open hldm_chaos_targets vault.");
    }

    if (g_protectVault == INVALID_HANDLE)
    {
        log_amx("Could not open hldm_protected_targets vault.");
    }
}

public plugin_end()
{
    if (g_chaosVault != INVALID_HANDLE)
    {
        nvault_close(g_chaosVault);
        g_chaosVault = INVALID_HANDLE;
    }

    if (g_protectVault != INVALID_HANDLE)
    {
        nvault_close(g_protectVault);
        g_protectVault = INVALID_HANDLE;
    }
}

public client_connect(id)
{
    ResetClientState(id);
}

public client_authorized(id)
{
    LoadPersistentState(id);
}

public client_putinserver(id)
{
    LoadPersistentState(id);
    remove_task(TASK_RESTORE_BASE + id);
    set_task(1.0, "TaskRestorePunishment", TASK_RESTORE_BASE + id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    remove_task(TASK_RESTORE_BASE + id);
    ResetClientState(id);
}

public TaskRestorePunishment(taskId)
{
    new id = taskId - TASK_RESTORE_BASE;
    if (!is_user_connected(id) || !g_effectMask[id])
    {
        return;
    }

    server_cmd("amx_trap #%d", get_user_userid(id));
    server_exec();
}

public CmdChatChaos(id)
{
    if (!IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    ShowPlayerMenu(id);
    return PLUGIN_HANDLED;
}

public CmdChaosMenu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    ShowPlayerMenu(id);
    return PLUGIN_HANDLED;
}

public CmdChaosPunish(id, level, cid)
{
    new target = ResolvePunishTarget(id, level, cid);
    if (!target)
    {
        return PLUGIN_HANDLED;
    }

    ApplyFullChaos(id, target, "console");
    return PLUGIN_HANDLED;
}

public CmdChaosClear(id, level, cid)
{
    new target = ResolveAnyTarget(id, level, cid);
    if (!target)
    {
        return PLUGIN_HANDLED;
    }

    ClearChaos(id, target);
    return PLUGIN_HANDLED;
}

public CmdChaosMeat(id, level, cid)
{
    return HandleEffectCommand(id, level, cid, CHAOS_MEAT, "MEAT FOUNTAIN");
}

public CmdChaosBees(id, level, cid)
{
    return HandleEffectCommand(id, level, cid, CHAOS_BEES, "BEE BETRAYAL");
}

public CmdChaosGrenades(id, level, cid)
{
    return HandleEffectCommand(id, level, cid, CHAOS_GRENADES, "GRENADE MAGNET");
}

public CmdChaosDamage(id, level, cid)
{
    return HandleEffectCommand(id, level, cid, CHAOS_DAMAGE, "ONE-PERCENT DAMAGE");
}

public CmdChaosProtect(id, level, cid)
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

    new bool:enable = !g_protected[target];
    if (read_argc() >= 3)
    {
        new value[8];
        read_argv(2, value, charsmax(value));
        enable = bool:(str_to_num(value) != 0);
    }

    SetProtected(target, enable);
    PrintProtectionChange(id, target);
    return PLUGIN_HANDLED;
}

public CmdChaosStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(id, "[CHAOS] damage scale=%.4f", get_pcvar_float(g_pcvarDamageScale));

    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_connected(target) || (!g_effectMask[target] && !g_protected[target]))
        {
            continue;
        }

        new name[32], authid[40];
        get_user_name(target, name, charsmax(name));
        get_user_authid(target, authid, charsmax(authid));
        console_print(id, "  #%d %s <%s> mask=%d protected=%d", get_user_userid(target), name, authid, g_effectMask[target], g_protected[target]);
    }

    return PLUGIN_HANDLED;
}

public CmdBeeMode(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    if (read_argc() >= 2)
    {
        new value[8];
        read_argv(1, value, charsmax(value));
        g_adminBeeMode[id] = bool:(str_to_num(value) != 0);
    }
    else
    {
        g_adminBeeMode[id] = !g_adminBeeMode[id];
    }

    client_print(id, print_chat, "[CHAOS] infinite bee assist %s.", g_adminBeeMode[id] ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

public CmdBeeBurst(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !IsAdminClient(id) || !is_user_alive(id))
    {
        return PLUGIN_HANDLED;
    }

    new Float:now = get_gametime();
    if (now - g_lastBeeBurst[id] < 0.55)
    {
        return PLUGIN_HANDLED;
    }

    g_lastBeeBurst[id] = now;
    new count = ClampInt(get_pcvar_num(g_pcvarBeeBurstCount), 1, 32);
    for (new index = 0; index < count; index++)
    {
        SpawnHornet(id, 0.28);
    }

    client_print(id, print_center, "BEE SWARM RELEASED");
    return PLUGIN_HANDLED;
}

public OnCmdStart(id, userCmd, randomSeed)
{
    if (!get_pcvar_num(g_pcvarEnabled) || id < 1 || id > MaxClients || !is_user_alive(id))
    {
        return FMRES_IGNORED;
    }

    new buttons = get_uc(userCmd, UC_Buttons);
    new Float:now = get_gametime();

    if (g_adminBeeMode[id] && is_user_admin(id) && (buttons & IN_ATTACK))
    {
        new Float:interval = ClampFloat(get_pcvar_float(g_pcvarBeeInterval), 0.05, 1.0);
        if (now - g_lastBeeShot[id] >= interval)
        {
            g_lastBeeShot[id] = now;
            SpawnHornet(id, 0.045);
        }
    }

    if (g_effectMask[id] && (buttons & (IN_ATTACK | IN_ATTACK2)))
    {
        if ((g_effectMask[id] & CHAOS_MEAT) && now - g_lastMeat[id] > 0.45 && random_num(0, 99) < 18)
        {
            g_lastMeat[id] = now;
            EmitMeatBurst(id, 4);
        }

        if (get_pcvar_num(g_pcvarWeirdPulse) && now - g_lastWeird[id] > 2.5 && random_num(0, 99) < 8)
        {
            g_lastWeird[id] = now;
            ApplyWeirdPulse(id);
        }
    }

    return FMRES_IGNORED;
}

public OnEntityThinkPost(entity)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !pev_valid(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[24];
    pev(entity, pev_classname, classname, charsmax(classname));
    if (!equal(classname, "hornet"))
    {
        return FMRES_IGNORED;
    }

    new originalOwner = pev(entity, pev_iuser4);
    if (!originalOwner)
    {
        new owner = pev(entity, pev_owner);
        if (owner >= 1 && owner <= MaxClients && (g_effectMask[owner] & CHAOS_BEES))
        {
            originalOwner = owner;
            set_pev(entity, pev_iuser4, owner);
            set_pev(entity, pev_owner, 0);
        }
    }

    if (originalOwner < 1 || originalOwner > MaxClients || !is_user_alive(originalOwner) || !(g_effectMask[originalOwner] & CHAOS_BEES))
    {
        return FMRES_IGNORED;
    }

    new Float:hornetOrigin[3], Float:targetOrigin[3], Float:velocity[3];
    pev(entity, pev_origin, hornetOrigin);
    pev(originalOwner, pev_origin, targetOrigin);
    targetOrigin[2] += 34.0;

    velocity[0] = targetOrigin[0] - hornetOrigin[0];
    velocity[1] = targetOrigin[1] - hornetOrigin[1];
    velocity[2] = targetOrigin[2] - hornetOrigin[2];

    if (NormalizeVector(velocity))
    {
        new Float:speed = ClampFloat(get_pcvar_float(g_pcvarBeeSpeed), 250.0, 1400.0);
        velocity[0] *= speed;
        velocity[1] *= speed;
        velocity[2] *= speed;
        set_pev(entity, pev_velocity, velocity);
        set_pev(entity, pev_dmg, 12.0);
    }

    return FMRES_HANDLED;
}

public OnSetModelPost(entity, const model[])
{
    if (!get_pcvar_num(g_pcvarEnabled) || !pev_valid(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[24];
    pev(entity, pev_classname, classname, charsmax(classname));
    if (!equal(classname, "grenade"))
    {
        return FMRES_IGNORED;
    }

    if (contain(model, "grenade") < 0 && contain(model, "satchel") < 0)
    {
        return FMRES_IGNORED;
    }

    new owner = pev(entity, pev_owner);
    if (owner < 1 || owner > MaxClients || !is_user_alive(owner) || !(g_effectMask[owner] & CHAOS_GRENADES))
    {
        return FMRES_IGNORED;
    }

    new Float:origin[3];
    pev(owner, pev_origin, origin);
    origin[2] += 34.0;

    set_pev(entity, pev_iuser4, owner);
    set_pev(entity, pev_owner, 0);
    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_aiment, owner);
    set_pev(entity, pev_movetype, MOVETYPE_FOLLOW);
    set_pev(entity, pev_solid, SOLID_NOT);

    client_print(owner, print_center, "RETURN TO SENDER");
    return FMRES_HANDLED;
}

public OnPlayerTakeDamage(victim, inflictor, attacker, Float:damage, damageBits)
{
    if (!get_pcvar_num(g_pcvarEnabled) || damage <= 0.0)
    {
        return HAM_IGNORED;
    }

    if (!g_reflecting
        && victim >= 1
        && victim <= MaxClients
        && g_protected[victim]
        && attacker >= 1
        && attacker <= MaxClients
        && attacker != victim
        && is_user_connected(attacker))
    {
        if (get_pcvar_num(g_pcvarProtectIgnoreAdmins) && is_user_admin(attacker))
        {
            return HAM_IGNORED;
        }

        SetHamParamFloat(4, 0.0);
        HealProtectedPlayer(victim, damage);

        new Float:reflected = damage * ClampFloat(get_pcvar_float(g_pcvarReflectScale), 0.0, 5.0);
        g_reflecting = true;
        ExecuteHamB(Ham_TakeDamage, attacker, victim, victim, reflected, damageBits);
        g_reflecting = false;

        client_print(attacker, print_center, "KARMA: DAMAGE REFLECTED");
        FlashKarma(attacker);

        new Float:now = get_gametime();
        if (get_pcvar_num(g_pcvarPublicProtect) && now - g_lastProtectNotice[victim] > 1.5)
        {
            g_lastProtectNotice[victim] = now;
            new victimName[32], attackerName[32];
            get_user_name(victim, victimName, charsmax(victimName));
            get_user_name(attacker, attackerName, charsmax(attackerName));
            client_print(0, print_chat, "[KARMA] %s attacked protected %s and received the damage.", attackerName, victimName);
        }

        return HAM_HANDLED;
    }

    if (attacker >= 1
        && attacker <= MaxClients
        && attacker != victim
        && (g_effectMask[attacker] & CHAOS_DAMAGE))
    {
        new Float:scale = ClampFloat(get_pcvar_float(g_pcvarDamageScale), 0.0, 1.0);
        SetHamParamFloat(4, damage * scale);

        if (g_effectMask[attacker] & CHAOS_MEAT)
        {
            new Float:now = get_gametime();
            if (now - g_lastMeat[attacker] > 0.35)
            {
                g_lastMeat[attacker] = now;
                EmitMeatBurst(attacker, 3);
            }
        }

        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

public TaskChaosTick()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new Float:now = get_gametime();
    new Float:meatInterval = ClampFloat(get_pcvar_float(g_pcvarMeatInterval), 0.20, 5.0);

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_alive(id) || !g_effectMask[id])
        {
            continue;
        }

        if ((g_effectMask[id] & CHAOS_MEAT) && now - g_lastMeat[id] >= meatInterval)
        {
            g_lastMeat[id] = now;
            EmitMeatBurst(id, random_num(4, 8));
        }

        if (get_pcvar_num(g_pcvarWeirdPulse) && now - g_lastWeird[id] >= 3.0 && random_num(0, 99) < 7)
        {
            g_lastWeird[id] = now;
            ApplyWeirdPulse(id);
        }
    }
}

public PlayerMenuHandler(id, menu, item)
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
    if (!is_user_connected(target) || target == id || is_user_bot(target) || is_user_hltv(target))
    {
        client_print(id, print_chat, "[CHAOS] target unavailable.");
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
        ShowPlayerMenu(id);
        return PLUGIN_HANDLED;
    }

    new access, callback, info[8], displayName[96];
    menu_item_getinfo(menu, item, access, info, charsmax(info), displayName, charsmax(displayName), callback);
    menu_destroy(menu);

    new target = g_selectedTarget[id];
    if (!is_user_connected(target) || target == id || is_user_bot(target) || is_user_hltv(target))
    {
        client_print(id, print_chat, "[CHAOS] target unavailable.");
        return PLUGIN_HANDLED;
    }

    switch (str_to_num(info))
    {
        case 1: ApplyFullChaos(id, target, "menu");
        case 2: ToggleEffect(id, target, CHAOS_BEES, "BEE BETRAYAL");
        case 3: ToggleEffect(id, target, CHAOS_GRENADES, "GRENADE MAGNET");
        case 4: ToggleEffect(id, target, CHAOS_MEAT, "MEAT FOUNTAIN");
        case 5: ToggleEffect(id, target, CHAOS_DAMAGE, "ONE-PERCENT DAMAGE");
        case 6:
        {
            SetProtected(target, !g_protected[target]);
            PrintProtectionChange(id, target);
        }
        case 7: ClearChaos(id, target);
        case 8: PrintTargetStatus(id, target);
    }

    return PLUGIN_HANDLED;
}

stock ShowPlayerMenu(id)
{
    new menu = menu_create("\rHLDM Chaos / Protection", "PlayerMenuHandler");
    new count;

    for (new target = 1; target <= MaxClients; target++)
    {
        if (target == id || !is_user_connected(target) || is_user_bot(target) || is_user_hltv(target))
        {
            continue;
        }

        new name[32], info[8], itemText[112];
        get_user_name(target, name, charsmax(name));
        num_to_str(target, info, charsmax(info));
        formatex(
            itemText,
            charsmax(itemText),
            "#%d %s \y[%s%s]",
            get_user_userid(target),
            name,
            g_effectMask[target] ? "CHAOS" : "normal",
            g_protected[target] ? ", PROTECTED" : ""
        );
        menu_additem(menu, itemText, info);
        count++;
    }

    if (!count)
    {
        menu_destroy(menu);
        client_print(id, print_chat, "[CHAOS] no other players connected.");
        return;
    }

    menu_display(id, menu);
}

stock ShowActionMenu(id, target)
{
    new name[32], title[112];
    get_user_name(target, name, charsmax(name));
    formatex(title, charsmax(title), "\r%s \y#%d | mask=%d | protect=%d", name, get_user_userid(target), g_effectMask[target], g_protected[target]);

    new menu = menu_create(title, "ActionMenuHandler");
    menu_additem(menu, "\rFULL CHAOS: 1% + meat + bees + grenade magnet", "1");
    menu_additem(menu, "Toggle bee betrayal", "2");
    menu_additem(menu, "Toggle grenade magnet", "3");
    menu_additem(menu, "Toggle meat fountain", "4");
    menu_additem(menu, "Toggle one-percent damage", "5");
    menu_additem(menu, "\yToggle KARMA PROTECTION", "6");
    menu_additem(menu, "\wClear punishment", "7");
    menu_additem(menu, "Inspect SteamID / IP / state", "8");
    menu_display(id, menu);
}

stock ApplyFullChaos(admin, target, const reason[])
{
    if (!CanPunish(admin, target))
    {
        client_print(admin, print_chat, "[CHAOS] admins and bots are protected from punishment.");
        return;
    }

    g_effectMask[target] = CHAOS_ALL;
    SaveChaosState(target);

    new userId = get_user_userid(target);
    server_cmd("amx_trap #%d", userId);
    server_cmd("amx_guard_punish #%d", userId);
    server_exec();

    if (is_user_alive(target))
    {
        EmitMeatBurst(target, 12);
        user_kill(target, 1);
    }

    new name[32];
    get_user_name(target, name, charsmax(name));
    client_print(admin, print_chat, "[CHAOS] #%d %s: full chaos applied.", userId, name);

    if (get_pcvar_num(g_pcvarPublicChaos))
    {
        client_print(0, print_chat, "[SERVER] %s entered the meat-and-bees integrity program.", name);
    }

    log_amx("Admin %d applied full chaos to #%d reason=%s", admin, userId, reason);
}

stock ClearChaos(admin, target)
{
    g_effectMask[target] = 0;
    SaveChaosState(target);

    new userId = get_user_userid(target);
    server_cmd("amx_untrap #%d", userId);
    server_cmd("amx_guard_unpunish #%d", userId);
    server_exec();

    client_print(admin, print_chat, "[CHAOS] #%d restored to normal punishment state.", userId);
}

stock ToggleEffect(admin, target, effect, const label[])
{
    if (!CanPunish(admin, target))
    {
        client_print(admin, print_chat, "[CHAOS] target cannot be punished.");
        return;
    }

    if (g_effectMask[target] & effect)
    {
        g_effectMask[target] &= ~effect;
    }
    else
    {
        g_effectMask[target] |= effect;
    }

    SaveChaosState(target);
    client_print(admin, print_chat, "[CHAOS] #%d %s %s.", get_user_userid(target), label, (g_effectMask[target] & effect) ? "ON" : "OFF");
}

stock HandleEffectCommand(id, level, cid, effect, const label[])
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

    new bool:enable = !(g_effectMask[target] & effect);
    if (read_argc() >= 3)
    {
        new value[8];
        read_argv(2, value, charsmax(value));
        enable = bool:(str_to_num(value) != 0);
    }

    if (enable)
    {
        g_effectMask[target] |= effect;
    }
    else
    {
        g_effectMask[target] &= ~effect;
    }

    SaveChaosState(target);
    client_print(id, print_chat, "[CHAOS] #%d %s %s.", get_user_userid(target), label, enable ? "ON" : "OFF");
    return PLUGIN_HANDLED;
}

stock SpawnHornet(owner, Float:spread)
{
    if (!is_user_alive(owner))
    {
        return 0;
    }

    new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hornet"));
    if (!pev_valid(entity))
    {
        return 0;
    }

    new Float:origin[3], Float:viewOffset[3], Float:viewAngles[3];
    new Float:forward[3], Float:right[3], Float:up[3], Float:velocity[3];

    pev(owner, pev_origin, origin);
    pev(owner, pev_view_ofs, viewOffset);
    pev(owner, pev_v_angle, viewAngles);
    origin[0] += viewOffset[0];
    origin[1] += viewOffset[1];
    origin[2] += viewOffset[2];

    engfunc(EngFunc_AngleVectors, viewAngles, forward, right, up);

    new Float:xSpread = random_float(-spread, spread);
    new Float:ySpread = random_float(-spread, spread);
    velocity[0] = forward[0] + right[0] * xSpread + up[0] * ySpread;
    velocity[1] = forward[1] + right[1] * xSpread + up[1] * ySpread;
    velocity[2] = forward[2] + right[2] * xSpread + up[2] * ySpread;
    NormalizeVector(velocity);

    new Float:speed = ClampFloat(get_pcvar_float(g_pcvarBeeSpeed), 250.0, 1400.0);
    velocity[0] *= speed;
    velocity[1] *= speed;
    velocity[2] *= speed;

    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_owner, owner);
    set_pev(entity, pev_velocity, velocity);
    set_pev(entity, pev_dmg, 10.0);
    dllfunc(DLLFunc_Spawn, entity);
    set_pev(entity, pev_velocity, velocity);

    return entity;
}

stock EmitMeatBurst(id, count)
{
    if (!is_user_connected(id))
    {
        return;
    }

    new Float:origin[3];
    pev(id, pev_origin, origin);
    origin[2] += 34.0;

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_BREAKMODEL_CUSTOM);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    engfunc(EngFunc_WriteCoord, 18.0);
    engfunc(EngFunc_WriteCoord, 18.0);
    engfunc(EngFunc_WriteCoord, 32.0);
    engfunc(EngFunc_WriteCoord, random_float(-90.0, 90.0));
    engfunc(EngFunc_WriteCoord, random_float(-90.0, 90.0));
    engfunc(EngFunc_WriteCoord, random_float(120.0, 260.0));
    write_byte(45);
    write_short(g_gibModel);
    write_byte(ClampInt(count, 1, 24));
    write_byte(45);
    write_byte(4);
    message_end();

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_BLOODSPRITE_CUSTOM);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2]);
    write_short(g_bloodSpraySprite);
    write_short(g_bloodSprite);
    write_byte(70);
    write_byte(12);
    message_end();

    engfunc(EngFunc_EmitSound, id, CHAN_BODY, random_num(0, 1) ? MEAT_SOUND : FLESH_SOUND, 0.85, ATTN_NORM, 0, PITCH_NORM);
}

stock ApplyWeirdPulse(id)
{
    if (!is_user_alive(id))
    {
        return;
    }

    new Float:velocity[3], Float:punch[3];
    pev(id, pev_velocity, velocity);
    velocity[0] += random_float(-110.0, 110.0);
    velocity[1] += random_float(-110.0, 110.0);
    velocity[2] += random_float(100.0, 240.0);
    set_pev(id, pev_velocity, velocity);

    punch[0] = random_float(-10.0, 10.0);
    punch[1] = random_float(-12.0, 12.0);
    punch[2] = random_float(-5.0, 5.0);
    set_pev(id, pev_punchangle, punch);

    switch (random_num(0, 3))
    {
        case 0: client_print(id, print_center, "HIVE OWNERSHIP ERROR");
        case 1: client_print(id, print_center, "MEAT CALIBRATION FAILED");
        case 2: client_print(id, print_center, "GRENADE LOYALTY: HOSTILE");
        case 3: client_print(id, print_center, "AIM CONFIDENCE: POTATO");
    }
}

stock HealProtectedPlayer(id, Float:incomingDamage)
{
    new Float:health;
    pev(id, pev_health, health);

    new Float:heal = incomingDamage * ClampFloat(get_pcvar_float(g_pcvarHealScale), 0.0, 5.0);
    new Float:maximum = ClampFloat(get_pcvar_float(g_pcvarProtectedMaxHealth), 100.0, 1000.0);
    health += heal;
    if (health > maximum)
    {
        health = maximum;
    }

    set_pev(id, pev_health, health);
}

stock FlashKarma(id)
{
    static messageId;
    if (!messageId)
    {
        messageId = get_user_msgid("ScreenFade");
    }

    if (!messageId || !is_user_connected(id))
    {
        return;
    }

    message_begin(MSG_ONE_UNRELIABLE, messageId, _, id);
    write_short(1 << 10);
    write_short(1 << 9);
    write_short(0);
    write_byte(255);
    write_byte(20);
    write_byte(20);
    write_byte(110);
    message_end();
}

stock SetProtected(target, bool:enable)
{
    g_protected[target] = enable;
    SaveProtectionState(target);
}

stock PrintProtectionChange(admin, target)
{
    new name[32];
    get_user_name(target, name, charsmax(name));
    client_print(admin, print_chat, "[KARMA] #%d %s protection %s.", get_user_userid(target), name, g_protected[target] ? "ON" : "OFF");
}

stock PrintTargetStatus(admin, target)
{
    new name[32], authid[40], ip[32], model[32], ping, loss;
    get_user_name(target, name, charsmax(name));
    get_user_authid(target, authid, charsmax(authid));
    get_user_ip(target, ip, charsmax(ip), 1);
    get_user_info(target, "model", model, charsmax(model));
    get_user_ping(target, ping, loss);

    console_print(
        admin,
        "[CHAOS] #%d %s <%s> ip=%s model=%s hp=%d ping=%d mask=%d protected=%d",
        get_user_userid(target),
        name,
        authid,
        ip,
        model,
        get_user_health(target),
        ping,
        g_effectMask[target],
        g_protected[target]
    );
}

stock SaveChaosState(id)
{
    if (g_chaosVault == INVALID_HANDLE)
    {
        return;
    }

    new authid[40];
    if (!GetPersistentAuthId(id, authid, charsmax(authid)))
    {
        return;
    }

    if (!g_effectMask[id])
    {
        nvault_remove(g_chaosVault, authid);
        return;
    }

    new value[16];
    num_to_str(g_effectMask[id], value, charsmax(value));
    nvault_set(g_chaosVault, authid, value);
}

stock SaveProtectionState(id)
{
    if (g_protectVault == INVALID_HANDLE)
    {
        return;
    }

    new authid[40];
    if (!GetPersistentAuthId(id, authid, charsmax(authid)))
    {
        return;
    }

    if (g_protected[id])
    {
        nvault_set(g_protectVault, authid, "1");
    }
    else
    {
        nvault_remove(g_protectVault, authid);
    }
}

stock LoadPersistentState(id)
{
    if (id < 1 || id > MaxClients || !is_user_connected(id))
    {
        return;
    }

    new authid[40];
    if (!GetPersistentAuthId(id, authid, charsmax(authid)))
    {
        return;
    }

    if (g_chaosVault != INVALID_HANDLE)
    {
        new value[16];
        if (nvault_get(g_chaosVault, authid, value, charsmax(value)))
        {
            g_effectMask[id] = str_to_num(value) & CHAOS_ALL;
        }
    }

    if (g_protectVault != INVALID_HANDLE)
    {
        g_protected[id] = bool:(nvault_get(g_protectVault, authid) == 1);
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

stock ResolvePunishTarget(id, level, cid)
{
    new target = ResolveAnyTarget(id, level, cid);
    if (!target || !CanPunish(id, target))
    {
        return 0;
    }

    return target;
}

stock ResolveAnyTarget(id, level, cid)
{
    if (!cmd_access(id, level, cid, 2))
    {
        return 0;
    }

    new argument[64];
    read_argv(1, argument, charsmax(argument));
    return cmd_target(id, argument, CMDTARGET_NO_BOTS | CMDTARGET_OBEY_IMMUNITY);
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

stock bool:IsAdminClient(id)
{
    return id >= 1 && id <= MaxClients && is_user_connected(id) && is_user_admin(id);
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

stock ResetClientState(id)
{
    g_effectMask[id] = 0;
    g_protected[id] = false;
    g_adminBeeMode[id] = false;
    g_selectedTarget[id] = 0;
    g_lastBeeShot[id] = 0.0;
    g_lastBeeBurst[id] = 0.0;
    g_lastMeat[id] = 0.0;
    g_lastWeird[id] = 0.0;
    g_lastProtectNotice[id] = 0.0;
}
