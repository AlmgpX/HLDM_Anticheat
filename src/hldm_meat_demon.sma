#include <amxmodx>
#include <amxmisc>
#include <nvault>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Meat Demon"
#define PLUGIN_VERSION "1.1.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_DEMON_TICK 47001
#define CHAOS_MEAT (1 << 0)

new g_chaosVault = INVALID_HANDLE;
new Float:g_nextMessage[MAX_PLAYERS + 1];
new g_lastMessage[MAX_PLAYERS + 1];

new g_pcvarEnabled;
new g_pcvarMinInterval;
new g_pcvarMaxInterval;
new g_pcvarChatChance;
new g_pcvarHud;
new g_pcvarChat;

new const g_demonLines[][] =
{
    "THE HOMELESS-EATER DEMON HAS FOUND YOU",
    "IT EATS THE HOMELESS AND THE PUS IN HUMAN SOULS",
    "YOUR ANXIETY IS NOW DEMON FOOD",
    "THE CREATURE IS CHEWING THROUGH YOUR SELF-DOUBT",
    "THE PUS IN YOUR SOUL HAS BEEN LOCATED",
    "DO NOT PANIC. IT PREFERS PANIC.",
    "THE DEMON CAN SMELL INSECURITY",
    "YOUR INNER ROT HAS ATTRACTED A PREDATOR",
    "IT CAME FOR THE HOMELESS. IT STAYED FOR YOUR ANXIETY.",
    "MEAT EXORCISM FAILED",
    "THE DEMON IS LICKING FEAR OFF YOUR NERVOUS SYSTEM",
    "YOUR SELF-DOUBT HAS A STRONG AFTERTASTE",
    "THE SOUL PUS IS FRESH TODAY",
    "IT IS NOT EATING YOUR BODY. NOT YET.",
    "ANXIETY EXTRACTION: VIOLENTLY SUCCESSFUL",
    "THE HOMELESS-EATER REQUESTS MORE SOUL PUS",
    "YOUR CONFIDENCE WAS TOO SMALL TO BE A MEAL",
    "THE DEMON HAS FILED YOU UNDER EDIBLE",
    "THE BRIDGE DEMON IS AUDITING YOUR SOUL",
    "YOUR FEAR HAS BEEN TENDERIZED",
    "THE MEAT KNOWS WHAT YOU DID",
    "INSECURITY DETECTED. FEEDING PROCEDURE STARTED.",
    "YOUR SOUL IS LEAKING SOMETHING DELICIOUS",
    "THE DEMON EATS ANXIETY BEFORE BREAKFAST",
    "THE PUS WAS NOT IN THE WOUND. IT WAS IN THE PERSON.",
    "THE HOMELESS-EATER IS REMOVING YOUR INNER COWARDICE",
    "SELF-DOUBT EXTRACTION REQUIRES MORE MEAT",
    "THE DEMON CALLS THIS EMOTIONAL DRAINAGE",
    "YOUR PANIC HAS EXCELLENT MARBLING",
    "THE SOUL-CLEANING DEMON ACCEPTS NO REFUNDS"
};

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_meatdemon_test", "CmdTest", ADMIN_RCON, "<name|#userid|SteamID> - show one demon message now");

    g_pcvarEnabled = register_cvar("hldm_meatdemon_enabled", "1");
    g_pcvarMinInterval = register_cvar("hldm_meatdemon_min_interval", "3.5");
    g_pcvarMaxInterval = register_cvar("hldm_meatdemon_max_interval", "7.0");
    g_pcvarChatChance = register_cvar("hldm_meatdemon_chat_chance", "35");
    g_pcvarHud = register_cvar("hldm_meatdemon_hud", "1");
    g_pcvarChat = register_cvar("hldm_meatdemon_chat", "1");

    AutoExecConfig(true, "hldm_meat_demon");

    g_chaosVault = nvault_open("hldm_chaos_targets");
    if (g_chaosVault == INVALID_HANDLE)
    {
        log_amx("Could not open hldm_chaos_targets vault.");
    }

    set_task(0.50, "TaskDemonTick", TASK_DEMON_TICK, _, _, "b");
}

public plugin_end()
{
    // nVault closes plugin-owned handles during module shutdown. Explicitly
    // closing here can run after nVault teardown on listen-server shutdown.
    g_chaosVault = INVALID_HANDLE;
}
public client_connect(id)
{
    g_nextMessage[id] = 0.0;
    g_lastMessage[id] = -1;
}

public client_putinserver(id)
{
    ScheduleNextMessage(id, get_gametime());
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    g_nextMessage[id] = 0.0;
    g_lastMessage[id] = -1;
}

public CmdTest(id, level, cid)
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

    ShowDemonMessage(target);
    return PLUGIN_HANDLED;
}

public TaskDemonTick()
{
    if (!get_pcvar_num(g_pcvarEnabled) || g_chaosVault == INVALID_HANDLE)
    {
        return;
    }

    new Float:now = get_gametime();

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || !is_user_alive(id) || !HasMeatPunishment(id))
        {
            continue;
        }

        if (g_nextMessage[id] <= 0.0)
        {
            ScheduleNextMessage(id, now);
            continue;
        }

        if (now >= g_nextMessage[id])
        {
            ShowDemonMessage(id);
            ScheduleNextMessage(id, now);
        }
    }
}

stock bool:HasMeatPunishment(id)
{
    new authid[40];
    get_user_authid(id, authid, charsmax(authid));

    if (!IsPersistentAuthId(authid))
    {
        return false;
    }

    new value[16];
    if (!nvault_get(g_chaosVault, authid, value, charsmax(value)))
    {
        return false;
    }

    return bool:(str_to_num(value) & CHAOS_MEAT);
}

stock ShowDemonMessage(id)
{
    if (!is_user_connected(id))
    {
        return;
    }

    new index = ChooseMessage(id);

    if (get_pcvar_num(g_pcvarHud))
    {
        set_hudmessage(220, 40, 40, -1.0, 0.28, 1, 0.15, 2.6, 0.05, 0.20, 4);
        show_hudmessage(id, "%s", g_demonLines[index]);
    }

    if (get_pcvar_num(g_pcvarChat))
    {
        new chance = ClampInt(get_pcvar_num(g_pcvarChatChance), 0, 100);
        if (random_num(1, 100) <= chance)
        {
            client_print(id, print_chat, "[MEAT DEMON] %s", g_demonLines[index]);
        }
    }
}

stock ChooseMessage(id)
{
    new index = random_num(0, sizeof g_demonLines - 1);
    if (sizeof g_demonLines > 1 && index == g_lastMessage[id])
    {
        index = (index + random_num(1, sizeof g_demonLines - 1)) % sizeof g_demonLines;
    }

    g_lastMessage[id] = index;
    return index;
}

stock ScheduleNextMessage(id, Float:now)
{
    new Float:minimum = ClampFloat(get_pcvar_float(g_pcvarMinInterval), 0.5, 60.0);
    new Float:maximum = ClampFloat(get_pcvar_float(g_pcvarMaxInterval), minimum, 120.0);
    g_nextMessage[id] = now + random_float(minimum, maximum);
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
