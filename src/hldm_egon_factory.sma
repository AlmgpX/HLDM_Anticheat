#include <amxmodx>
#include <amxmisc>
#include <fakemeta>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Egon Factory"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define W_EGON 10

new g_previousButtons[33];
new Float:g_lastMessage[33];

new g_pcvarEnabled;
new g_pcvarChance;
new g_pcvarInterval;
new g_pcvarChatDuplicate;

new const g_egonLines[][] =
{
    "SELF-DESTRUCT VACUUM CLEANER: EXPORT MODEL",
    "MADE IN CHINA VACUUM TECHNOLOGY",
    "MADI EN INDIA BEAM CALIBRATION",
    "VACUUM CLEANER WARRANTY EXPIRED BEFORE FIRING",
    "SUCTION MODE ACCIDENTALLY REVERSED",
    "QUALITY CONTROL WAS ABSORBED BY THE BEAM",
    "FACTORY TEST RESULT: IT HUMMED LOUDLY",
    "POWER REGULATOR INSTALLED BACKWARDS",
    "CONTINUOUS FIRE NOT COVERED BY WARRANTY",
    "PREMIUM SELF-DISASSEMBLY FEATURE ARMED",
    "THE MANUAL CALLS THIS A HOUSEHOLD APPLIANCE",
    "ASSEMBLED FROM THREE VACUUM CLEANERS AND A LAMP",
    "EXPORT SAFETY MODULE SOLD SEPARATELY",
    "BEAM STABILITY IS WITHIN FACTORY TOLERANCE",
    "ENGINEERED WITH CONFIDENCE, NOT INSULATION"
};

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd(
        "amx_egonfactory_status",
        "CmdStatus",
        ADMIN_RCON,
        "- show Egon-only factory message routing"
    );

    g_pcvarEnabled = register_cvar("hldm_egonfactory_enabled", "1");
    g_pcvarChance = register_cvar("hldm_egonfactory_chance", "38");
    g_pcvarInterval = register_cvar("hldm_egonfactory_interval", "4.0");
    g_pcvarChatDuplicate = register_cvar("hldm_egonfactory_chat_duplicate", "1");

    AutoExecConfig(true, "hldm_egon_factory");
    register_forward(FM_CmdStart, "OnCmdStart", false);
}

public client_connect(id)
{
    ResetClient(id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    ResetClient(id);
}

public OnCmdStart(id, userCmd, randomSeed)
{
    if (!get_pcvar_num(g_pcvarEnabled)
        || id < 1
        || id > MaxClients
        || !is_user_alive(id))
    {
        return FMRES_IGNORED;
    }

    new buttons = get_uc(userCmd, UC_Buttons);
    new pressed = buttons & ~g_previousButtons[id];
    g_previousButtons[id] = buttons;

    // Hard routing boundary: no MP5, RPG, Gauss or other weapon can reach this.
    if (get_user_weapon(id) != W_EGON)
    {
        return FMRES_IGNORED;
    }

    if (!(pressed & (IN_ATTACK | IN_ATTACK2)))
    {
        return FMRES_IGNORED;
    }

    new Float:now = get_gametime();
    new Float:interval = ClampFloat(get_pcvar_float(g_pcvarInterval), 0.5, 30.0);
    if (now - g_lastMessage[id] < interval)
    {
        return FMRES_IGNORED;
    }

    if (random_num(1, 100) > ClampInt(get_pcvar_num(g_pcvarChance), 0, 100))
    {
        return FMRES_IGNORED;
    }

    g_lastMessage[id] = now;
    ShowEgonMessage(id);
    return FMRES_IGNORED;
}

public CmdStatus(id, level, cid)
{
    if (!cmd_access(id, level, cid, 1))
    {
        return PLUGIN_HANDLED;
    }

    console_print(
        id,
        "[EGON FACTORY] weapon_id=%d only chance=%d interval=%.2f",
        W_EGON,
        ClampInt(get_pcvar_num(g_pcvarChance), 0, 100),
        get_pcvar_float(g_pcvarInterval)
    );
    return PLUGIN_HANDLED;
}

stock ShowEgonMessage(id)
{
    new line = random_num(0, sizeof g_egonLines - 1);
    client_print(id, print_center, "%s", g_egonLines[line]);

    if (get_pcvar_num(g_pcvarChatDuplicate) && random_num(0, 2) == 0)
    {
        client_print(id, print_chat, "[EGON FACTORY] %s", g_egonLines[line]);
    }
}

stock ResetClient(id)
{
    g_previousButtons[id] = 0;
    g_lastMessage[id] = -9999.0;
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
