#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <nvault>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Weapon Lab"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_ENTITY_TICK 51001

#define W_CROWBAR     1
#define W_GLOCK       2
#define W_PYTHON      3
#define W_MP5         4
#define W_CROSSBOW    6
#define W_SHOTGUN     7
#define W_RPG         8
#define W_GAUSS       9
#define W_EGON       10
#define W_HORNETGUN  11
#define W_HANDGRENADE 12
#define W_TRIPMINE   13
#define W_SATCHEL    14
#define W_SNARK      15

#define QUIET_DAMAGE    (1 << 0)
#define QUIET_MISFIRE   (1 << 1)
#define QUIET_BETRAYAL  (1 << 2)
#define QUIET_DRIFT     (1 << 3)
#define QUIET_ALL       (QUIET_DAMAGE | QUIET_MISFIRE | QUIET_BETRAYAL | QUIET_DRIFT)

#define TAG_NONE      0
#define TAG_HORNET    51011
#define TAG_GRENADE   51012
#define TAG_TRIPMINE  51013
#define TAG_SNARK     51014
#define TAG_ROCKET    51015
#define TAG_SATCHEL   51016

#define TE_EXPLOSION_CUSTOM 3
#define TE_BREAKMODEL_CUSTOM 108
#define TE_BLOODSPRITE_CUSTOM 115

new g_quietMask[MAX_PLAYERS + 1];
new g_previousButtons[MAX_PLAYERS + 1];
new bool:g_blockPrimary[MAX_PLAYERS + 1];
new bool:g_blockSecondary[MAX_PLAYERS + 1];
new g_shotCounter[MAX_PLAYERS + 1];
new g_selectedTarget[MAX_PLAYERS + 1];

new Float:g_lastEgonHornet[MAX_PLAYERS + 1];
new Float:g_lastSnarkAlt[MAX_PLAYERS + 1];
new Float:g_lastDrift[MAX_PLAYERS + 1];

new g_quietVault = INVALID_HANDLE;

new g_explosionSprite;
new g_bloodSprite;
new g_bloodSpraySprite;
new g_gibModel;

new g_pcvarEnabled;
new g_pcvarGlobalMutators;
new g_pcvarQuietDamageScale;
new g_pcvarQuietPrimaryMisfire;
new g_pcvarQuietSecondaryMisfire;
new g_pcvarQuietDriftDegrees;
new g_pcvarQuietAdminImmunity;

new g_pcvarHornetMax;
new g_pcvarHornetLifetime;
new g_pcvarHornetDamage;
new g_pcvarHornetRadius;
new g_pcvarTripmineRadius;
new g_pcvarGrenadeHornets;
new g_pcvarRocketHornets;
new g_pcvarSnarkMax;
new g_pcvarSnarkPopHornets;
new g_pcvarSnarkAltCooldown;
new g_pcvarCrossbowSuicide;
new g_pcvarWeaponExtras;

public plugin_precache()
{
    g_explosionSprite = precache_model("sprites/zerogxplode.spr");
    g_bloodSprite = precache_model("sprites/blood.spr");
    g_bloodSpraySprite = precache_model("sprites/bloodspray.spr");
    g_gibModel = precache_model("models/hgibs.mdl");

    precache_model("models/hornet.mdl");
    precache_model("models/w_squeak.mdl");
    precache_model("sprites/muz1.spr");
    precache_model("sprites/laserbeam.spr");

    precache_sound("weapons/explode3.wav");
    precache_sound("common/bodysplat.wav");
    precache_sound("debris/bustflesh1.wav");
    precache_sound("squeek/sqk_blast1.wav");
    precache_sound("squeek/sqk_die1.wav");
    precache_sound("squeek/sqk_hunt1.wav");
    precache_sound("squeek/sqk_hunt2.wav");
    precache_sound("squeek/sqk_hunt3.wav");
    precache_sound("squeek/sqk_deploy1.wav");
    precache_sound("agrunt/ag_fire1.wav");
    precache_sound("agrunt/ag_fire2.wav");
    precache_sound("agrunt/ag_fire3.wav");
    precache_sound("hornet/ag_buzz1.wav");
    precache_sound("hornet/ag_buzz2.wav");
    precache_sound("hornet/ag_buzz3.wav");
    precache_sound("hornet/ag_hornethit1.wav");
    precache_sound("hornet/ag_hornethit2.wav");
    precache_sound("hornet/ag_hornethit3.wav");
}

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_quiet_menu", "CmdQuietMenu", ADMIN_RCON, "- open silent punishment menu");
    register_concmd("amx_quiet", "CmdQuiet", ADMIN_RCON, "<name|#userid|SteamID> <damage|misfire|betrayal|drift|all|clear>");
    register_concmd("amx_quiet_status", "CmdQuietStatus", ADMIN_RCON, "- list silent punishment state");
    register_clcmd("say /quiet", "CmdChatQuiet");
    register_clcmd("say_team /quiet", "CmdChatQuiet");

    g_pcvarEnabled = register_cvar("hldm_weaponlab_enabled", "1");
    g_pcvarGlobalMutators = register_cvar("hldm_weaponlab_global_mutators", "1");
    g_pcvarQuietDamageScale = register_cvar("hldm_weaponlab_quiet_damage_scale", "0.01");
    g_pcvarQuietPrimaryMisfire = register_cvar("hldm_weaponlab_quiet_primary_misfire", "12");
    g_pcvarQuietSecondaryMisfire = register_cvar("hldm_weaponlab_quiet_secondary_misfire", "18");
    g_pcvarQuietDriftDegrees = register_cvar("hldm_weaponlab_quiet_drift_degrees", "2.2");
    g_pcvarQuietAdminImmunity = register_cvar("hldm_weaponlab_quiet_admin_immunity", "1");

    g_pcvarHornetMax = register_cvar("hldm_weaponlab_hornet_max", "10");
    g_pcvarHornetLifetime = register_cvar("hldm_weaponlab_hornet_lifetime", "3.5");
    g_pcvarHornetDamage = register_cvar("hldm_weaponlab_hornet_damage", "40.0");
    g_pcvarHornetRadius = register_cvar("hldm_weaponlab_hornet_radius", "96.0");
    g_pcvarTripmineRadius = register_cvar("hldm_weaponlab_tripmine_radius", "200.0");
    g_pcvarGrenadeHornets = register_cvar("hldm_weaponlab_grenade_hornets", "3");
    g_pcvarRocketHornets = register_cvar("hldm_weaponlab_rocket_hornets", "4");
    g_pcvarSnarkMax = register_cvar("hldm_weaponlab_snark_max", "6");
    g_pcvarSnarkPopHornets = register_cvar("hldm_weaponlab_snark_pop_hornets", "2");
    g_pcvarSnarkAltCooldown = register_cvar("hldm_weaponlab_snark_alt_cooldown", "4.0");
    g_pcvarCrossbowSuicide = register_cvar("hldm_weaponlab_crossbow_alt_suicide", "1");
    g_pcvarWeaponExtras = register_cvar("hldm_weaponlab_weapon_extras", "1");

    AutoExecConfig(true, "hldm_weapon_lab");

    RegisterHam(Ham_TakeDamage, "player", "OnPlayerTakeDamage", false);
    RegisterHam(Ham_Killed, "monster_snark", "OnSnarkKilledPost", true);

    register_forward(FM_CmdStart, "OnCmdStart", false);
    register_forward(FM_Spawn, "OnEntitySpawnPost", true);
    register_forward(FM_SetModel, "OnSetModelPost", true);
    register_forward(FM_Touch, "OnEntityTouch", false);

    set_task(0.10, "TaskEntityTick", TASK_ENTITY_TICK, _, _, "b");

    g_quietVault = nvault_open("hldm_weapon_quiet");
    if (g_quietVault == INVALID_HANDLE)
    {
        log_amx("Could not open hldm_weapon_quiet vault.");
    }
}

public plugin_end()
{
    if (g_quietVault != INVALID_HANDLE)
    {
        nvault_close(g_quietVault);
        g_quietVault = INVALID_HANDLE;
    }
}

public client_connect(id)
{
    ResetClient(id);
}

public client_authorized(id)
{
    LoadQuietState(id);
}

public client_putinserver(id)
{
    LoadQuietState(id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    ResetClient(id);
}

public CmdChatQuiet(id)
{
    if (!IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    ShowTargetMenu(id);
    return PLUGIN_HANDLED;
}

public CmdQuietMenu(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1) || !IsAdminClient(id))
    {
        return PLUGIN_HANDLED;
    }

    ShowTargetMenu(id);
    return PLUGIN_HANDLED;
}

public CmdQuiet(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3))
    {
        return PLUGIN_HANDLED;
    }

    new targetArgument[64], mode[24];
    read_argv(1, targetArgument, charsmax(targetArgument));
    read_argv(2, mode, charsmax(mode));

    new target = cmd_target(id, targetArgument, CMDTARGET_NO_BOTS | CMDTARGET_OBEY_IMMUNITY);
    if (!target || !CanQuietTarget(id, target))
    {
        return PLUGIN_HANDLED;
    }

    if (equali(mode, "damage"))
    {
        ToggleQuietBit(id, target, QUIET_DAMAGE, "damage");
    }
    else if (equali(mode, "misfire"))
    {
        ToggleQuietBit(id, target, QUIET_MISFIRE, "misfire");
    }
    else if (equali(mode, "betrayal"))
    {
        ToggleQuietBit(id, target, QUIET_BETRAYAL, "betrayal");
    }
    else if (equali(mode, "drift"))
    {
        ToggleQuietBit(id, target, QUIET_DRIFT, "drift");
    }
    else if (equali(mode, "all"))
    {
        g_quietMask[target] = QUIET_ALL;
        SaveQuietState(target);
        PrintAdminQuietState(id, target, "FULL QUIET ON");
    }
    else if (equali(mode, "clear"))
    {
        ClearQuietState(id, target);
    }
    else
    {
        console_print(id, "Usage: amx_quiet <target> <damage|misfire|betrayal|drift|all|clear>");
    }

    return PLUGIN_HANDLED;
}

public CmdQuietStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(id, "[WEAPON LAB] quiet punishment state:");
    for (new target = 1; target <= MaxClients; target++)
    {
        if (!is_user_connected(target) || !g_quietMask[target])
        {
            continue;
        }

        new name[32], authid[40];
        get_user_name(target, name, charsmax(name));
        get_user_authid(target, authid, charsmax(authid));
        console_print(id, "  #%d %s <%s> mask=%d", get_user_userid(target), name, authid, g_quietMask[target]);
    }

    return PLUGIN_HANDLED;
}

public QuietTargetMenuHandler(id, menu, item)
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
    if (!CanQuietTarget(id, target))
    {
        client_print(id, print_chat, "[WEAPON LAB] target unavailable.");
        return PLUGIN_HANDLED;
    }

    g_selectedTarget[id] = target;
    ShowQuietActionMenu(id, target);
    return PLUGIN_HANDLED;
}

public QuietActionMenuHandler(id, menu, item)
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
    if (!CanQuietTarget(id, target))
    {
        client_print(id, print_chat, "[WEAPON LAB] target unavailable.");
        return PLUGIN_HANDLED;
    }

    switch (str_to_num(info))
    {
        case 1: ToggleQuietBit(id, target, QUIET_DAMAGE, "damage");
        case 2: ToggleQuietBit(id, target, QUIET_MISFIRE, "misfire");
        case 3: ToggleQuietBit(id, target, QUIET_BETRAYAL, "betrayal");
        case 4: ToggleQuietBit(id, target, QUIET_DRIFT, "drift");
        case 5:
        {
            g_quietMask[target] = QUIET_ALL;
            SaveQuietState(target);
            PrintAdminQuietState(id, target, "FULL QUIET ON");
        }
        case 6: ClearQuietState(id, target);
        case 7: PrintTargetQuietStatus(id, target);
    }

    return PLUGIN_HANDLED;
}

public OnCmdStart(id, userCmd, randomSeed)
{
    if (!get_pcvar_num(g_pcvarEnabled) || id < 1 || id > MaxClients || !is_user_alive(id))
    {
        return FMRES_IGNORED;
    }

    new buttons = get_uc(userCmd, UC_Buttons);
    new pressed = buttons & ~g_previousButtons[id];
    new weapon = get_user_weapon(id);
    new Float:now = get_gametime();

    if (get_pcvar_num(g_pcvarGlobalMutators))
    {
        HandleGlobalWeaponInput(id, weapon, buttons, pressed, now);
    }

    if (g_quietMask[id] & QUIET_DRIFT)
    {
        ApplyQuietDrift(id, pressed, now);
    }

    if (g_quietMask[id] & QUIET_MISFIRE)
    {
        ApplyQuietMisfire(id, userCmd, buttons, pressed);
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

    if (get_pcvar_num(g_pcvarGlobalMutators)
        && attacker >= 1
        && attacker <= MaxClients
        && attacker != victim
        && is_user_connected(attacker)
        && get_user_weapon(attacker) == W_CROWBAR
        && (damageBits & DMG_CLUB))
    {
        LaunchCrowbarVictim(attacker, victim);
    }

    if (attacker >= 1
        && attacker <= MaxClients
        && attacker != victim
        && (g_quietMask[attacker] & QUIET_DAMAGE))
    {
        new Float:scale = ClampFloat(get_pcvar_float(g_pcvarQuietDamageScale), 0.0, 1.0);
        SetHamParamFloat(4, damage * scale);
        return HAM_HANDLED;
    }

    return HAM_IGNORED;
}

public OnEntitySpawnPost(entity)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !pev_valid(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[32];
    pev(entity, pev_classname, classname, charsmax(classname));

    if (equal(classname, "hornet"))
    {
        TagHornet(entity);
    }
    else if (equal(classname, "monster_tripmine"))
    {
        TagEntity(entity, TAG_TRIPMINE, 2.8);
    }
    else if (equal(classname, "monster_snark"))
    {
        TagEntity(entity, TAG_SNARK, 0.0);
        EnforceSnarkLimit(GetTaggedOwner(entity));
    }
    else if (equal(classname, "rpg_rocket"))
    {
        TagEntity(entity, TAG_ROCKET, 0.0);
    }
    else if (equal(classname, "monster_satchel"))
    {
        TagEntity(entity, TAG_SATCHEL, 0.0);
    }
    else if (equal(classname, "grenade"))
    {
        TagEntity(entity, TAG_GRENADE, 0.0);
    }

    return FMRES_IGNORED;
}

public OnSetModelPost(entity, const model[])
{
    if (!get_pcvar_num(g_pcvarEnabled) || !pev_valid(entity))
    {
        return FMRES_IGNORED;
    }

    new classname[32];
    pev(entity, pev_classname, classname, charsmax(classname));

    if (equal(classname, "grenade") && containi(model, "grenade") >= 0)
    {
        if (pev(entity, pev_iuser3) != TAG_GRENADE)
        {
            TagEntity(entity, TAG_GRENADE, 0.0);
        }
    }

    return FMRES_IGNORED;
}

public OnEntityTouch(entity, other)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !pev_valid(entity))
    {
        return FMRES_IGNORED;
    }

    new tag = pev(entity, pev_iuser3);
    if (tag == TAG_HORNET)
    {
        new owner = GetTaggedOwner(entity);
        new Float:spawnTime;
        pev(entity, pev_fuser2, spawnTime);

        if (other == owner && get_gametime() - spawnTime < 0.25)
        {
            return FMRES_IGNORED;
        }

        ExplodeHornet(entity);
        return FMRES_SUPERCEDE;
    }

    if (tag == TAG_ROCKET)
    {
        new marker = pev(entity, pev_iuser4);
        if (!marker)
        {
            set_pev(entity, pev_iuser4, 1);
            new owner = GetTaggedOwner(entity);
            new Float:origin[3];
            pev(entity, pev_origin, origin);
            VisualExplosion(origin, 6);
            SpawnHornetBurst(owner, origin, ClampInt(get_pcvar_num(g_pcvarRocketHornets), 0, 10));
        }
    }

    return FMRES_IGNORED;
}

public OnSnarkKilledPost(entity, attacker, shouldGib)
{
    if (!get_pcvar_num(g_pcvarEnabled) || !pev_valid(entity))
    {
        return HAM_IGNORED;
    }

    new owner = GetTaggedOwner(entity);
    new Float:origin[3];
    pev(entity, pev_origin, origin);

    EmitMeatBurst(origin, random_num(5, 9));
    VisualExplosion(origin, 4);
    SpawnHornetBurst(owner, origin, ClampInt(get_pcvar_num(g_pcvarSnarkPopHornets), 0, 8));
    return HAM_IGNORED;
}

public TaskEntityTick()
{
    if (!get_pcvar_num(g_pcvarEnabled))
    {
        return;
    }

    new Float:now = get_gametime();
    ProcessHornets(now);
    ProcessTripmines(now);
    ProcessGrenades(now);
    ProcessSnarks();
}

stock HandleGlobalWeaponInput(id, weapon, buttons, pressed, Float:now)
{
    if (!get_pcvar_num(g_pcvarWeaponExtras))
    {
        if (weapon == W_CROSSBOW && (pressed & IN_ATTACK2) && get_pcvar_num(g_pcvarCrossbowSuicide))
        {
            CrossbowOwnerDetonation(id);
        }
        return;
    }

    switch (weapon)
    {
        case W_CROWBAR:
        {
            if (pressed & IN_ATTACK)
            {
                ApplyForwardImpulse(id, 70.0, 18.0);
            }
        }
        case W_GLOCK:
        {
            if (pressed & IN_ATTACK)
            {
                g_shotCounter[id]++;
                if (g_shotCounter[id] % 7 == 0)
                {
                    SpawnHornetFromPlayer(id, 900.0, 0.02);
                }
            }
        }
        case W_PYTHON:
        {
            if (pressed & IN_ATTACK)
            {
                ApplyBackRecoil(id, 210.0, 55.0);
            }
        }
        case W_MP5:
        {
            if (pressed & IN_ATTACK)
            {
                g_shotCounter[id]++;
                if (g_shotCounter[id] % 10 == 0)
                {
                    SpawnHornetFromPlayer(id, 850.0, 0.06);
                    SpawnHornetFromPlayer(id, 850.0, 0.10);
                }
            }

            if (pressed & IN_ATTACK2)
            {
                MiniAirburstAtAim(id, 18.0, 72.0);
            }
        }
        case W_CROSSBOW:
        {
            if ((pressed & IN_ATTACK2) && get_pcvar_num(g_pcvarCrossbowSuicide))
            {
                CrossbowOwnerDetonation(id);
            }
        }
        case W_SHOTGUN:
        {
            if (pressed & IN_ATTACK2)
            {
                ApplyBackRecoil(id, 360.0, 115.0);
            }
            else if (pressed & IN_ATTACK)
            {
                ApplyBackRecoil(id, 170.0, 45.0);
            }
        }
        case W_GAUSS:
        {
            if (pressed & IN_ATTACK2)
            {
                ApplyBackRecoil(id, 460.0, 240.0);
            }
        }
        case W_EGON:
        {
            if ((buttons & IN_ATTACK) && now - g_lastEgonHornet[id] >= 0.55)
            {
                g_lastEgonHornet[id] = now;
                SpawnHornetFromPlayer(id, 700.0, 0.04);
            }
        }
        case W_SATCHEL:
        {
            if (pressed & IN_ATTACK2)
            {
                HatchSnarksFromSatchels(id);
            }
        }
        case W_SNARK:
        {
            if (pressed & IN_ATTACK2)
            {
                new Float:cooldown = ClampFloat(get_pcvar_float(g_pcvarSnarkAltCooldown), 0.5, 20.0);
                if (now - g_lastSnarkAlt[id] >= cooldown)
                {
                    g_lastSnarkAlt[id] = now;
                    SpawnAlphaSnark(id);
                }
            }
        }
    }
}

stock ApplyQuietMisfire(id, userCmd, buttons, pressed)
{
    if (!(buttons & IN_ATTACK))
    {
        g_blockPrimary[id] = false;
    }
    else if ((pressed & IN_ATTACK)
        && random_num(1, 100) <= ClampInt(get_pcvar_num(g_pcvarQuietPrimaryMisfire), 0, 100))
    {
        g_blockPrimary[id] = true;
    }

    if (!(buttons & IN_ATTACK2))
    {
        g_blockSecondary[id] = false;
    }
    else if ((pressed & IN_ATTACK2)
        && random_num(1, 100) <= ClampInt(get_pcvar_num(g_pcvarQuietSecondaryMisfire), 0, 100))
    {
        g_blockSecondary[id] = true;
    }

    new changedButtons = buttons;
    if (g_blockPrimary[id])
    {
        changedButtons &= ~IN_ATTACK;
    }
    if (g_blockSecondary[id])
    {
        changedButtons &= ~IN_ATTACK2;
    }

    if (changedButtons != buttons)
    {
        set_uc(userCmd, UC_Buttons, changedButtons);
    }
}

stock ApplyQuietDrift(id, pressed, Float:now)
{
    if (!(pressed & (IN_ATTACK | IN_ATTACK2)) || now - g_lastDrift[id] < 0.12)
    {
        return;
    }

    g_lastDrift[id] = now;
    new Float:maximum = ClampFloat(get_pcvar_float(g_pcvarQuietDriftDegrees), 0.0, 12.0);
    new Float:punch[3];
    pev(id, pev_punchangle, punch);
    punch[0] += random_float(-maximum, maximum);
    punch[1] += random_float(-maximum, maximum);
    punch[2] += random_float(-maximum * 0.35, maximum * 0.35);
    set_pev(id, pev_punchangle, punch);
}

stock ProcessHornets(Float:now)
{
    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (!pev_valid(entity) || pev(entity, pev_iuser3) != TAG_HORNET)
        {
            continue;
        }

        new owner = GetTaggedOwner(entity);
        new Float:expireTime;
        pev(entity, pev_fuser3, expireTime);

        if (expireTime > 0.0 && now >= expireTime)
        {
            ExplodeHornet(entity);
            continue;
        }

        if (owner >= 1
            && owner <= MaxClients
            && is_user_alive(owner)
            && (g_quietMask[owner] & QUIET_BETRAYAL))
        {
            SteerEntityToward(entity, owner, 720.0, 28.0);
            set_pev(entity, pev_owner, 0);
        }
    }
}

stock ProcessTripmines(Float:now)
{
    new Float:radius = ClampFloat(get_pcvar_float(g_pcvarTripmineRadius), 32.0, 1024.0);
    new Float:radiusSquared = radius * radius;

    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "monster_tripmine")) > 0)
    {
        if (!pev_valid(entity) || pev(entity, pev_iuser3) != TAG_TRIPMINE)
        {
            continue;
        }

        new Float:armedAt;
        pev(entity, pev_fuser4, armedAt);
        if (now < armedAt)
        {
            continue;
        }

        new Float:mineOrigin[3];
        pev(entity, pev_origin, mineOrigin);

        for (new player = 1; player <= MaxClients; player++)
        {
            if (!is_user_alive(player))
            {
                continue;
            }

            new Float:playerOrigin[3];
            pev(player, pev_origin, playerOrigin);
            if (VectorDistanceSquared(mineOrigin, playerOrigin) <= radiusSquared)
            {
                DetonateTripmine(entity);
                break;
            }
        }
    }
}

stock ProcessGrenades(Float:now)
{
    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "grenade")) > 0)
    {
        if (!pev_valid(entity) || pev(entity, pev_iuser3) != TAG_GRENADE)
        {
            continue;
        }

        new owner = GetTaggedOwner(entity);
        new Float:spawnTime;
        pev(entity, pev_fuser2, spawnTime);

        if (owner >= 1
            && owner <= MaxClients
            && is_user_alive(owner)
            && (g_quietMask[owner] & QUIET_BETRAYAL)
            && now - spawnTime > 0.65)
        {
            SteerEntityToward(entity, owner, 620.0, 30.0);
        }

        new Float:damageTime;
        pev(entity, pev_dmgtime, damageTime);
        if (damageTime > 0.0 && now >= damageTime - 0.18 && !pev(entity, pev_iuser4))
        {
            set_pev(entity, pev_iuser4, 1);
            new Float:origin[3];
            pev(entity, pev_origin, origin);
            SpawnHornetBurst(owner, origin, ClampInt(get_pcvar_num(g_pcvarGrenadeHornets), 0, 10));
        }
    }
}

stock ProcessSnarks()
{
    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "monster_snark")) > 0)
    {
        if (!pev_valid(entity) || pev(entity, pev_iuser3) != TAG_SNARK)
        {
            continue;
        }

        new owner = GetTaggedOwner(entity);
        if (owner >= 1
            && owner <= MaxClients
            && is_user_alive(owner)
            && (g_quietMask[owner] & QUIET_BETRAYAL))
        {
            set_pev(entity, pev_enemy, owner);
            SteerEntityToward(entity, owner, 420.0, 18.0);
            set_pev(entity, pev_owner, 0);
        }
    }
}

stock TagHornet(entity)
{
    TagEntity(entity, TAG_HORNET, 0.0);

    new Float:now = get_gametime();
    set_pev(entity, pev_fuser2, now);
    set_pev(entity, pev_fuser3, now + ClampFloat(get_pcvar_float(g_pcvarHornetLifetime), 0.4, 10.0));

    EnforceHornetLimit(GetTaggedOwner(entity));
}

stock TagEntity(entity, tag, Float:delay)
{
    if (!pev_valid(entity))
    {
        return;
    }

    new owner = pev(entity, pev_owner);
    set_pev(entity, pev_iuser3, tag);
    set_pev(entity, pev_iuser2, owner);
    set_pev(entity, pev_fuser2, get_gametime());
    if (delay > 0.0)
    {
        set_pev(entity, pev_fuser4, get_gametime() + delay);
    }
}

stock GetTaggedOwner(entity)
{
    if (!pev_valid(entity))
    {
        return 0;
    }

    new owner = pev(entity, pev_iuser2);
    if (owner < 1 || owner > MaxClients)
    {
        owner = pev(entity, pev_owner);
    }

    return owner;
}

stock EnforceHornetLimit(owner)
{
    if (owner < 1 || owner > MaxClients)
    {
        return;
    }

    new maximum = ClampInt(get_pcvar_num(g_pcvarHornetMax), 1, 32);
    new count;
    new oldest;
    new Float:oldestTime = 999999999.0;

    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "hornet")) > 0)
    {
        if (!pev_valid(entity) || pev(entity, pev_iuser3) != TAG_HORNET || GetTaggedOwner(entity) != owner)
        {
            continue;
        }

        count++;
        new Float:spawnTime;
        pev(entity, pev_fuser2, spawnTime);
        if (spawnTime < oldestTime)
        {
            oldestTime = spawnTime;
            oldest = entity;
        }
    }

    if (count > maximum && oldest > 0 && pev_valid(oldest))
    {
        ExplodeHornet(oldest);
    }
}

stock EnforceSnarkLimit(owner)
{
    if (owner < 1 || owner > MaxClients)
    {
        return;
    }

    new maximum = ClampInt(get_pcvar_num(g_pcvarSnarkMax), 1, 24);
    new count;
    new oldest;
    new Float:oldestTime = 999999999.0;

    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "monster_snark")) > 0)
    {
        if (!pev_valid(entity) || pev(entity, pev_iuser3) != TAG_SNARK || GetTaggedOwner(entity) != owner)
        {
            continue;
        }

        count++;
        new Float:spawnTime;
        pev(entity, pev_fuser2, spawnTime);
        if (spawnTime < oldestTime)
        {
            oldestTime = spawnTime;
            oldest = entity;
        }
    }

    if (count > maximum && oldest > 0 && pev_valid(oldest))
    {
        ExecuteHamB(Ham_TakeDamage, oldest, owner, owner, 999.0, DMG_BLAST);
    }
}

stock ExplodeHornet(entity)
{
    if (!pev_valid(entity))
    {
        return;
    }

    new owner = GetTaggedOwner(entity);
    new Float:origin[3];
    pev(entity, pev_origin, origin);

    VisualExplosion(origin, 5);
    RadiusDamagePlayers(
        entity,
        owner,
        origin,
        ClampFloat(get_pcvar_float(g_pcvarHornetDamage), 0.0, 200.0),
        ClampFloat(get_pcvar_float(g_pcvarHornetRadius), 16.0, 512.0)
    );

    engfunc(EngFunc_EmitSound, entity, CHAN_BODY, "weapons/explode3.wav", 0.65, ATTN_NORM, 0, 120);
    engfunc(EngFunc_RemoveEntity, entity);
}

stock DetonateTripmine(entity)
{
    if (!pev_valid(entity))
    {
        return;
    }

    new owner = GetTaggedOwner(entity);
    new attacker = owner >= 1 && owner <= MaxClients ? owner : entity;
    ExecuteHamB(Ham_TakeDamage, entity, attacker, attacker, 9999.0, DMG_BLAST);
}

stock SpawnHornetFromPlayer(owner, Float:speed, Float:spread)
{
    if (!is_user_alive(owner))
    {
        return 0;
    }

    new Float:origin[3], Float:viewOffset[3], Float:angles[3];
    new Float:forwardVector[3], Float:rightVector[3], Float:upVector[3], Float:velocity[3];

    pev(owner, pev_origin, origin);
    pev(owner, pev_view_ofs, viewOffset);
    pev(owner, pev_v_angle, angles);
    origin[0] += viewOffset[0];
    origin[1] += viewOffset[1];
    origin[2] += viewOffset[2];

    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);
    origin[0] += forwardVector[0] * 18.0;
    origin[1] += forwardVector[1] * 18.0;
    origin[2] += forwardVector[2] * 18.0;

    velocity[0] = forwardVector[0] + rightVector[0] * random_float(-spread, spread) + upVector[0] * random_float(-spread, spread);
    velocity[1] = forwardVector[1] + rightVector[1] * random_float(-spread, spread) + upVector[1] * random_float(-spread, spread);
    velocity[2] = forwardVector[2] + rightVector[2] * random_float(-spread, spread) + upVector[2] * random_float(-spread, spread);
    NormalizeVector(velocity);
    velocity[0] *= speed;
    velocity[1] *= speed;
    velocity[2] *= speed;

    return SpawnHornet(owner, origin, velocity);
}

stock SpawnHornet(owner, const Float:origin[3], const Float:velocity[3])
{
    new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hornet"));
    if (!pev_valid(entity))
    {
        return 0;
    }

    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_owner, owner);
    dllfunc(DLLFunc_Spawn, entity);
    set_pev(entity, pev_velocity, velocity);
    TagHornet(entity);
    return entity;
}

stock SpawnHornetBurst(owner, const Float:origin[3], count)
{
    for (new index = 0; index < count; index++)
    {
        new Float:velocity[3];
        velocity[0] = random_float(-1.0, 1.0);
        velocity[1] = random_float(-1.0, 1.0);
        velocity[2] = random_float(0.15, 1.0);
        NormalizeVector(velocity);
        new Float:speed = random_float(420.0, 820.0);
        velocity[0] *= speed;
        velocity[1] *= speed;
        velocity[2] *= speed;
        SpawnHornet(owner, origin, velocity);
    }
}

stock SpawnAlphaSnark(owner)
{
    if (!is_user_alive(owner))
    {
        return;
    }

    new Float:origin[3], Float:viewOffset[3], Float:angles[3];
    new Float:forwardVector[3], Float:rightVector[3], Float:upVector[3], Float:velocity[3];
    pev(owner, pev_origin, origin);
    pev(owner, pev_view_ofs, viewOffset);
    pev(owner, pev_v_angle, angles);
    origin[0] += viewOffset[0];
    origin[1] += viewOffset[1];
    origin[2] += 6.0;

    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);
    origin[0] += forwardVector[0] * 34.0;
    origin[1] += forwardVector[1] * 34.0;

    velocity[0] = forwardVector[0] * 360.0;
    velocity[1] = forwardVector[1] * 360.0;
    velocity[2] = forwardVector[2] * 220.0 + 150.0;

    SpawnSnark(owner, origin, velocity);
}

stock SpawnSnark(owner, const Float:origin[3], const Float:velocity[3])
{
    new entity = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "monster_snark"));
    if (!pev_valid(entity))
    {
        return 0;
    }

    set_pev(entity, pev_origin, origin);
    set_pev(entity, pev_owner, owner);
    dllfunc(DLLFunc_Spawn, entity);
    set_pev(entity, pev_velocity, velocity);
    TagEntity(entity, TAG_SNARK, 0.0);
    EnforceSnarkLimit(owner);
    return entity;
}

stock HatchSnarksFromSatchels(owner)
{
    new entity = -1;
    while ((entity = engfunc(EngFunc_FindEntityByString, entity, "classname", "monster_satchel")) > 0)
    {
        if (!pev_valid(entity))
        {
            continue;
        }

        new savedOwner = GetTaggedOwner(entity);
        if (savedOwner != owner)
        {
            continue;
        }

        new Float:origin[3], Float:velocity[3];
        pev(entity, pev_origin, origin);
        origin[2] += 10.0;
        velocity[0] = random_float(-120.0, 120.0);
        velocity[1] = random_float(-120.0, 120.0);
        velocity[2] = random_float(180.0, 280.0);
        SpawnSnark(owner, origin, velocity);
        EmitMeatBurst(origin, 3);
    }
}

stock MiniAirburstAtAim(owner, Float:damage, Float:radius)
{
    new Float:start[3], Float:viewOffset[3], Float:angles[3];
    new Float:forwardVector[3], Float:rightVector[3], Float:upVector[3], Float:finish[3];
    pev(owner, pev_origin, start);
    pev(owner, pev_view_ofs, viewOffset);
    pev(owner, pev_v_angle, angles);
    start[0] += viewOffset[0];
    start[1] += viewOffset[1];
    start[2] += viewOffset[2];

    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);
    finish[0] = start[0] + forwardVector[0] * 700.0;
    finish[1] = start[1] + forwardVector[1] * 700.0;
    finish[2] = start[2] + forwardVector[2] * 700.0;

    new trace = create_tr2();
    engfunc(EngFunc_TraceLine, start, finish, DONT_IGNORE_MONSTERS, owner, trace);
    get_tr2(trace, TR_vecEndPos, finish);
    free_tr2(trace);

    VisualExplosion(finish, 3);
    RadiusDamagePlayers(owner, owner, finish, damage, radius);
}

stock CrossbowOwnerDetonation(id)
{
    if (!is_user_alive(id))
    {
        return;
    }

    new Float:origin[3];
    pev(id, pev_origin, origin);
    origin[2] += 28.0;
    VisualExplosion(origin, 8);
    EmitMeatBurst(origin, 10);
    user_kill(id, 1);
}

stock LaunchCrowbarVictim(attacker, victim)
{
    if (!is_user_alive(victim))
    {
        return;
    }

    new Float:attackerOrigin[3], Float:victimOrigin[3], Float:velocity[3];
    pev(attacker, pev_origin, attackerOrigin);
    pev(victim, pev_origin, victimOrigin);
    velocity[0] = victimOrigin[0] - attackerOrigin[0];
    velocity[1] = victimOrigin[1] - attackerOrigin[1];
    velocity[2] = 0.0;
    NormalizeVector(velocity);
    velocity[0] *= 380.0;
    velocity[1] *= 380.0;
    velocity[2] = 260.0;
    set_pev(victim, pev_velocity, velocity);
    EmitMeatBurst(victimOrigin, 2);
}

stock ApplyForwardImpulse(id, Float:horizontal, Float:vertical)
{
    new Float:angles[3], Float:forwardVector[3], Float:rightVector[3], Float:upVector[3], Float:velocity[3];
    pev(id, pev_v_angle, angles);
    pev(id, pev_velocity, velocity);
    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);
    velocity[0] += forwardVector[0] * horizontal;
    velocity[1] += forwardVector[1] * horizontal;
    velocity[2] += vertical;
    set_pev(id, pev_velocity, velocity);
}

stock ApplyBackRecoil(id, Float:horizontal, Float:vertical)
{
    new Float:angles[3], Float:forwardVector[3], Float:rightVector[3], Float:upVector[3], Float:velocity[3];
    pev(id, pev_v_angle, angles);
    pev(id, pev_velocity, velocity);
    engfunc(EngFunc_AngleVectors, angles, forwardVector, rightVector, upVector);
    velocity[0] -= forwardVector[0] * horizontal;
    velocity[1] -= forwardVector[1] * horizontal;
    velocity[2] += vertical;
    set_pev(id, pev_velocity, velocity);
}

stock SteerEntityToward(entity, target, Float:speed, Float:heightOffset)
{
    if (!pev_valid(entity) || !is_user_alive(target))
    {
        return;
    }

    new Float:entityOrigin[3], Float:targetOrigin[3], Float:velocity[3];
    pev(entity, pev_origin, entityOrigin);
    pev(target, pev_origin, targetOrigin);
    targetOrigin[2] += heightOffset;

    velocity[0] = targetOrigin[0] - entityOrigin[0];
    velocity[1] = targetOrigin[1] - entityOrigin[1];
    velocity[2] = targetOrigin[2] - entityOrigin[2];
    if (!NormalizeVector(velocity))
    {
        return;
    }

    velocity[0] *= speed;
    velocity[1] *= speed;
    velocity[2] *= speed;
    set_pev(entity, pev_velocity, velocity);
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

stock EmitMeatBurst(const Float:origin[3], count)
{
    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_BREAKMODEL_CUSTOM);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2] + 20.0);
    engfunc(EngFunc_WriteCoord, 18.0);
    engfunc(EngFunc_WriteCoord, 18.0);
    engfunc(EngFunc_WriteCoord, 28.0);
    engfunc(EngFunc_WriteCoord, random_float(-90.0, 90.0));
    engfunc(EngFunc_WriteCoord, random_float(-90.0, 90.0));
    engfunc(EngFunc_WriteCoord, random_float(100.0, 240.0));
    write_byte(40);
    write_short(g_gibModel);
    write_byte(ClampInt(count, 1, 24));
    write_byte(35);
    write_byte(4);
    message_end();

    message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
    write_byte(TE_BLOODSPRITE_CUSTOM);
    engfunc(EngFunc_WriteCoord, origin[0]);
    engfunc(EngFunc_WriteCoord, origin[1]);
    engfunc(EngFunc_WriteCoord, origin[2] + 24.0);
    write_short(g_bloodSpraySprite);
    write_short(g_bloodSprite);
    write_byte(70);
    write_byte(10);
    message_end();

    engfunc(EngFunc_EmitAmbientSound, 0, origin, random_num(0, 1) ? "common/bodysplat.wav" : "debris/bustflesh1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM);
}

stock ShowTargetMenu(id)
{
    new menu = menu_create("\rHLDM Quiet Modes", "QuietTargetMenuHandler");
    new count;

    for (new target = 1; target <= MaxClients; target++)
    {
        if (!CanQuietTarget(id, target))
        {
            continue;
        }

        new name[32], info[8], itemText[96];
        get_user_name(target, name, charsmax(name));
        num_to_str(target, info, charsmax(info));
        formatex(itemText, charsmax(itemText), "#%d %s \y[mask %d]", get_user_userid(target), name, g_quietMask[target]);
        menu_additem(menu, itemText, info);
        count++;
    }

    if (!count)
    {
        menu_destroy(menu);
        client_print(id, print_chat, "[WEAPON LAB] no eligible players connected.");
        return;
    }

    menu_display(id, menu);
}

stock ShowQuietActionMenu(id, target)
{
    new name[32], title[112];
    get_user_name(target, name, charsmax(name));
    formatex(title, charsmax(title), "\rQuiet target: \w%s \y#%d | mask=%d", name, get_user_userid(target), g_quietMask[target]);

    new menu = menu_create(title, "QuietActionMenuHandler");
    menu_additem(menu, "Toggle 1% outgoing damage", "1");
    menu_additem(menu, "Toggle silent misfires", "2");
    menu_additem(menu, "Toggle weapon betrayal", "3");
    menu_additem(menu, "Toggle aim/recoil drift", "4");
    menu_additem(menu, "\rFULL QUIET", "5");
    menu_additem(menu, "\yClear quiet punishment", "6");
    menu_additem(menu, "Inspect state", "7");
    menu_display(id, menu);
}

stock ToggleQuietBit(admin, target, bit, const label[])
{
    if (g_quietMask[target] & bit)
    {
        g_quietMask[target] &= ~bit;
    }
    else
    {
        g_quietMask[target] |= bit;
    }

    SaveQuietState(target);

    new message[64];
    formatex(message, charsmax(message), "%s %s", label, (g_quietMask[target] & bit) ? "ON" : "OFF");
    PrintAdminQuietState(admin, target, message);
}

stock ClearQuietState(admin, target)
{
    g_quietMask[target] = 0;
    g_blockPrimary[target] = false;
    g_blockSecondary[target] = false;
    SaveQuietState(target);
    PrintAdminQuietState(admin, target, "QUIET CLEARED");
}

stock PrintAdminQuietState(admin, target, const action[])
{
    new name[32];
    get_user_name(target, name, charsmax(name));
    client_print(admin, print_chat, "[WEAPON LAB] #%d %s: %s; mask=%d.", get_user_userid(target), name, action, g_quietMask[target]);
}

stock PrintTargetQuietStatus(admin, target)
{
    new name[32], authid[40], ip[32];
    get_user_name(target, name, charsmax(name));
    get_user_authid(target, authid, charsmax(authid));
    get_user_ip(target, ip, charsmax(ip), 1);
    console_print(admin, "[WEAPON LAB] #%d %s <%s> ip=%s quietMask=%d", get_user_userid(target), name, authid, ip, g_quietMask[target]);
}

stock SaveQuietState(id)
{
    if (g_quietVault == INVALID_HANDLE)
    {
        return;
    }

    new authid[40];
    if (!GetPersistentAuthId(id, authid, charsmax(authid)))
    {
        return;
    }

    if (!g_quietMask[id])
    {
        nvault_remove(g_quietVault, authid);
        return;
    }

    new value[16];
    num_to_str(g_quietMask[id], value, charsmax(value));
    nvault_set(g_quietVault, authid, value);
}

stock LoadQuietState(id)
{
    if (g_quietVault == INVALID_HANDLE || !is_user_connected(id))
    {
        return;
    }

    new authid[40];
    if (!GetPersistentAuthId(id, authid, charsmax(authid)))
    {
        return;
    }

    new value[16];
    if (nvault_get(g_quietVault, authid, value, charsmax(value)))
    {
        g_quietMask[id] = str_to_num(value) & QUIET_ALL;
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

stock bool:CanQuietTarget(admin, target)
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

    if (get_pcvar_num(g_pcvarQuietAdminImmunity) && is_user_admin(target))
    {
        return false;
    }

    return true;
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

stock ResetClient(id)
{
    g_quietMask[id] = 0;
    g_previousButtons[id] = 0;
    g_blockPrimary[id] = false;
    g_blockSecondary[id] = false;
    g_shotCounter[id] = 0;
    g_selectedTarget[id] = 0;
    g_lastEgonHornet[id] = 0.0;
    g_lastSnarkAlt[id] = 0.0;
    g_lastDrift[id] = 0.0;
}
