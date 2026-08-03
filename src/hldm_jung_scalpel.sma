#include <amxmodx>
#include <amxmisc>
#include <nvault>

#pragma semicolon 1

#define PLUGIN_NAME    "HLDM Jungian Scalpel"
#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_AUTHOR  "Alex Merqury"

#define MAX_PLAYERS 32
#define TASK_SCALPEL_TICK 48001
#define CHAOS_MEAT (1 << 0)

#define STAGE_CALIBRATION 0
#define STAGE_MASK        1
#define STAGE_SHADOW      2
#define STAGE_CHOICE      3

new g_chaosVault = INVALID_HANDLE;
new Float:g_punishStart[MAX_PLAYERS + 1];
new Float:g_nextMessage[MAX_PLAYERS + 1];
new g_lastMessage[MAX_PLAYERS + 1];
new g_lastStage[MAX_PLAYERS + 1];

new g_pcvarEnabled;
new g_pcvarMinInterval;
new g_pcvarMaxInterval;
new g_pcvarMaskSeconds;
new g_pcvarShadowSeconds;
new g_pcvarChoiceSeconds;
new g_pcvarHud;
new g_pcvarChat;
new g_pcvarChatChance;

new const g_calibrationLines[][] =
{
    "THE SYSTEM DID NOT MISS. IT WAITED.",
    "YOUR CERTAINTY HAS BEEN REPLACED WITH A QUESTION.",
    "THE CROSSHAIR MOVED. THE PLAYER DID NOT.",
    "THE TOOL STILL RUNS. THE REWARD DOES NOT.",
    "THE MACHINE IS NOW AIMING AT YOUR ASSUMPTIONS.",
    "NOTHING WAS TAKEN EXCEPT THE ADVANTAGE YOU BORROWED.",
    "THE SERVER HAS STOPPED BELIEVING THE PERFORMANCE.",
    "YOU CANNOT DEBUG A MIRROR.",
    "THE OUTPUT CHANGED. THE INPUT DID NOT.",
    "THE TOOL PROMISED CONTROL. THE SERVER RETURNED UNCERTAINTY.",
    "THE SCOREBOARD NO LONGER CONFIRMS THE STORY.",
    "THE SYSTEM IS QUIET BECAUSE THE ANSWER IS ALREADY RUNNING."
};

new const g_maskLines[][] =
{
    "THE MASK CLAIMED SKILL. THE HANDS COULD NOT CONFIRM IT.",
    "PERSONA ONLINE. COMPETENCE NOT FOUND.",
    "YOU WANTED TO BE SEEN AS STRONG. THE TOOL WAS SEEN FIRST.",
    "THE SCOREBOARD WAS A COSTUME.",
    "THE PERFORMANCE ENDED. THE ACTOR REMAINS.",
    "THE NAME WAS YOURS. THE AIM WAS RENTED.",
    "A BORROWED VICTORY STILL KNOWS ITS OWNER.",
    "THE MASK DOES NOT SURVIVE CONTACT WITH SILENCE.",
    "THE TOOL PLAYED THE ROLE. YOU COLLECTED THE APPLAUSE.",
    "THE SERVER REMOVED THE COSTUME, NOT THE PLAYER.",
    "THE PERSONA WANTED ADMIRATION. THE INPUT LEFT RECEIPTS.",
    "WHEN THE ADVANTAGE VANISHES, THE MASK STARTS EXPLAINING."
};

new const g_shadowLines[][] =
{
    "THE SHADOW BEGINS WHERE THE EXCUSE ENDS.",
    "WHAT YOU PROJECTED ONTO OTHERS HAS RETURNED.",
    "THE ENEMY BEHIND THE WALL WAS NOT THE ONLY THING YOU AVOIDED.",
    "THE SHADOW DOES NOT NEED WALLHACK.",
    "EVERY FALSE ADVANTAGE CASTS A TRUE SHADOW.",
    "THE PART YOU HID BEHIND THE TOOL IS STILL PLAYING.",
    "YOU CANNOT OUTAIM WHAT YOU REFUSE TO OWN.",
    "THE MIRROR HAS NO HITBOX.",
    "THE SERVER REMOVED THE VICTIMS. NOW ONLY THE MOTIVE REMAINS.",
    "THE SHADOW IS NOT A BAN. IT IS THE UNEDITED PLAYER.",
    "THE MACHINE EXPOSED WHAT THE SCOREBOARD WAS HIDING.",
    "THE TARGET DISAPPEARED. THE NEED FOR CONTROL DID NOT."
};

new const g_choiceLines[][] =
{
    "TURN IT OFF AND SEE WHAT REMAINS.",
    "THE NEXT HONEST MISS IS WORTH MORE THAN EVERY FALSE HIT.",
    "YOU CAN LEAVE THE MASK HERE.",
    "SKILL BEGINS WHERE THE EXCUSE ENDS.",
    "THE SERVER DOES NOT NEED A CONFESSION. ONLY A CHOICE.",
    "THE SHADOW IS NOT DESTROYED. IT IS OWNED.",
    "QUIT THE TOOL OR KEEP PLAYING AGAINST YOURSELF.",
    "THE DARK IS WHAT REMAINS WHEN THE PERFORMANCE STOPS.",
    "AN HONEST INPUT IS THE ONLY EXIT.",
    "NO SCORE CAN REPAIR A PLAYER WHO REFUSES TO PLAY.",
    "YOU CAN STILL CHOOSE A RESULT THAT BELONGS TO YOU.",
    "THE HANDS CAN LEARN WHAT THE TOOL PRETENDED TO KNOW."
};

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    register_concmd("amx_scalpel_test", "CmdTest", ADMIN_RCON, "<name|#userid|SteamID> [0|1|2|3] - show one staged line");
    register_concmd("amx_scalpel_reset", "CmdReset", ADMIN_RCON, "<name|#userid|SteamID> - restart the sequence");

    g_pcvarEnabled = register_cvar("hldm_scalpel_enabled", "1");
    g_pcvarMinInterval = register_cvar("hldm_scalpel_min_interval", "6.0");
    g_pcvarMaxInterval = register_cvar("hldm_scalpel_max_interval", "11.0");
    g_pcvarMaskSeconds = register_cvar("hldm_scalpel_mask_seconds", "35.0");
    g_pcvarShadowSeconds = register_cvar("hldm_scalpel_shadow_seconds", "90.0");
    g_pcvarChoiceSeconds = register_cvar("hldm_scalpel_choice_seconds", "180.0");
    g_pcvarHud = register_cvar("hldm_scalpel_hud", "1");
    g_pcvarChat = register_cvar("hldm_scalpel_chat", "1");
    g_pcvarChatChance = register_cvar("hldm_scalpel_chat_chance", "20");

    AutoExecConfig(true, "hldm_jung_scalpel");

    g_chaosVault = nvault_open("hldm_chaos_targets");
    if (g_chaosVault == INVALID_HANDLE)
    {
        log_amx("Could not open hldm_chaos_targets vault.");
    }

    set_task(0.50, "TaskScalpelTick", TASK_SCALPEL_TICK, _, _, "b");
}

public plugin_end()
{
    if (g_chaosVault != INVALID_HANDLE)
    {
        nvault_close(g_chaosVault);
        g_chaosVault = INVALID_HANDLE;
    }
}

public client_connect(id)
{
    ResetSequence(id);
}

public client_putinserver(id)
{
    ResetSequence(id);
}

public client_disconnected(id, bool:drop, message[], maxlen)
{
    ResetSequence(id);
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

    new stage = STAGE_CALIBRATION;
    if (read_argc() >= 3)
    {
        new stageArg[8];
        read_argv(2, stageArg, charsmax(stageArg));
        stage = ClampInt(str_to_num(stageArg), STAGE_CALIBRATION, STAGE_CHOICE);
    }

    ShowScalpelMessage(target, stage);
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
    new target = cmd_target(id, argument, CMDTARGET_NO_BOTS | CMDTARGET_OBEY_IMMUNITY);
    if (!target)
    {
        return PLUGIN_HANDLED;
    }

    ResetSequence(target);
    client_print(id, print_console, "[SCALPEL] sequence reset for #%d", get_user_userid(target));
    return PLUGIN_HANDLED;
}

public TaskScalpelTick()
{
    if (!get_pcvar_num(g_pcvarEnabled) || g_chaosVault == INVALID_HANDLE)
    {
        return;
    }

    new Float:now = get_gametime();

    for (new id = 1; id <= MaxClients; id++)
    {
        if (!is_user_connected(id) || !is_user_alive(id))
        {
            continue;
        }

        if (!HasMeatPunishment(id))
        {
            if (g_punishStart[id] > 0.0)
            {
                ResetSequence(id);
            }
            continue;
        }

        if (g_punishStart[id] <= 0.0)
        {
            g_punishStart[id] = now;
            ScheduleNextMessage(id, now);
            continue;
        }

        if (g_nextMessage[id] <= 0.0)
        {
            ScheduleNextMessage(id, now);
            continue;
        }

        if (now >= g_nextMessage[id])
        {
            new stage = DetermineStage(now - g_punishStart[id]);
            ShowScalpelMessage(id, stage);
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

stock DetermineStage(Float:elapsed)
{
    new Float:maskSeconds = ClampFloat(get_pcvar_float(g_pcvarMaskSeconds), 5.0, 600.0);
    new Float:shadowSeconds = ClampFloat(get_pcvar_float(g_pcvarShadowSeconds), maskSeconds, 1200.0);
    new Float:choiceSeconds = ClampFloat(get_pcvar_float(g_pcvarChoiceSeconds), shadowSeconds, 2400.0);

    if (elapsed < maskSeconds)
    {
        return STAGE_CALIBRATION;
    }
    if (elapsed < shadowSeconds)
    {
        return STAGE_MASK;
    }
    if (elapsed < choiceSeconds)
    {
        return STAGE_SHADOW;
    }
    return STAGE_CHOICE;
}

stock ShowScalpelMessage(id, stage)
{
    if (!is_user_connected(id))
    {
        return;
    }

    new line[128];
    ChooseStageLine(id, stage, line, charsmax(line));

    if (get_pcvar_num(g_pcvarHud))
    {
        switch (stage)
        {
            case STAGE_CALIBRATION: set_hudmessage(170, 210, 255, -1.0, 0.24, 0, 0.0, 3.2, 0.10, 0.20, 4);
            case STAGE_MASK: set_hudmessage(255, 210, 80, -1.0, 0.24, 0, 0.0, 3.2, 0.10, 0.20, 4);
            case STAGE_SHADOW: set_hudmessage(190, 80, 255, -1.0, 0.24, 1, 0.15, 3.2, 0.10, 0.20, 4);
            default: set_hudmessage(235, 235, 235, -1.0, 0.24, 0, 0.0, 3.2, 0.10, 0.20, 4);
        }
        show_hudmessage(id, "%s", line);
    }

    if (get_pcvar_num(g_pcvarChat))
    {
        new chance = ClampInt(get_pcvar_num(g_pcvarChatChance), 0, 100);
        if (random_num(1, 100) <= chance)
        {
            client_print(id, print_chat, "[MIRROR] %s", line);
        }
    }
}

stock ChooseStageLine(id, stage, output[], outputLength)
{
    new index;

    switch (stage)
    {
        case STAGE_CALIBRATION:
        {
            index = ChooseNonRepeatingIndex(id, stage, sizeof g_calibrationLines);
            copy(output, outputLength, g_calibrationLines[index]);
        }
        case STAGE_MASK:
        {
            index = ChooseNonRepeatingIndex(id, stage, sizeof g_maskLines);
            copy(output, outputLength, g_maskLines[index]);
        }
        case STAGE_SHADOW:
        {
            index = ChooseNonRepeatingIndex(id, stage, sizeof g_shadowLines);
            copy(output, outputLength, g_shadowLines[index]);
        }
        default:
        {
            index = ChooseNonRepeatingIndex(id, stage, sizeof g_choiceLines);
            copy(output, outputLength, g_choiceLines[index]);
        }
    }
}

stock ChooseNonRepeatingIndex(id, stage, count)
{
    new index = random_num(0, count - 1);
    if (count > 1 && stage == g_lastStage[id] && index == g_lastMessage[id])
    {
        index = (index + random_num(1, count - 1)) % count;
    }

    g_lastStage[id] = stage;
    g_lastMessage[id] = index;
    return index;
}

stock ScheduleNextMessage(id, Float:now)
{
    new Float:minimum = ClampFloat(get_pcvar_float(g_pcvarMinInterval), 1.0, 60.0);
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

stock ResetSequence(id)
{
    g_punishStart[id] = 0.0;
    g_nextMessage[id] = 0.0;
    g_lastMessage[id] = -1;
    g_lastStage[id] = -1;
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
