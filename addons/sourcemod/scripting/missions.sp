#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adt_array>
#include <missions>

GlobalForward g_fwOnGivenMission = null;

ArrayList g_aMissionsList = null;
int MissionCounter = 0;
char g_cClientMissions[(MAXPLAYERS + 1) * 3][32];
char g_cProgressionGoal[(MAXPLAYERS + 1) * 3];
char g_cProgression[(MAXPLAYERS + 1) * 3];

#pragma newdecls required

enum struct PlayerData
{
    int Coins;
}

PlayerData g_iPlayer[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "Missions",
    author = "MarsTwix",
    description = "Misions players can complete and get rewarded",
    version = "1.0.0",
    url = "clwo.eu"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_coins", Command_Coins, "Prints the amount of coins you got");
    RegConsoleCmd("sm_missions", Command_Missions, "Print own/all missions and add/remove/set missions");

    g_aMissionsList = new ArrayList(32);
    LoadTranslations("common.phrases.txt");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("Missions_AddCoins", Native_AddCoins);
    CreateNative("Missions_RemoveCoins", Native_RemoveCoins);
    CreateNative("Missions_SetCoins", Native_SetCoins);

    CreateNative("Missions_RegisterMission", Native_RegisterMission);
    CreateNative("Missions_IsValidMission", Native_IsValidMission);
    CreateNative("Missions_IsValidClientMission", Native_IsValidClientMission);
    CreateNative("Missions_FindClientMission", Native_FindClientMission);

    CreateNative("Mission_GiveMission", Native_GiveMission);
    CreateNative("Mission_RemoveMission", Native_RemoveMission);

    CreateNative("Missions_SetProgressionGoal", Native_SetProgressionGoal);
    CreateNative("Missions_GetProgressionGoal", Native_GetProgressionGoal);
    CreateNative("Missions_AddProgression", Native_AddProgression);

    CreateNative("Mission_HasCompleted", Native_HasCompleted);
    CreateNative("Mission_RewardOnCompletion", Native_RewardOnCompletion);

    g_fwOnGivenMission = new GlobalForward("Missions_OnGivenMission", ET_Ignore, Param_Cell, Param_String, Param_Cell);

    return APLRes_Success;
}

Action Command_Coins(int client, int args)
{
    if (args == 0){ReplyToCommand(client, "Coins: %i", g_iPlayer[client].Coins);}

    else if (args == 2 || args == 3)
    {
        char arg1[8], arg2[16];

        GetCmdArg(1, arg1, sizeof(arg1));
        GetCmdArg(2, arg2, sizeof(arg2));

        int num = StringToInt(arg2);
        if (args == 2)
        {
            if (StrEqual(arg1, "add"))
            {
                Missions_AddCoins(client, num);
                ReplyToCommand(client, "Added %i coins!", num);
                ReplyToCommand(client, "Coins: %i", g_iPlayer[client].Coins);
            }

            else if (StrEqual(arg1, "remove"))
            {
                Missions_RemoveCoins(client, num);
                ReplyToCommand(client, "Removed %i coins!", num);
                ReplyToCommand(client, "Coins: %i", g_iPlayer[client].Coins);
            }

            else if (StrEqual(arg1, "set"))
            {
                Missions_SetCoins(client, num);
                ReplyToCommand(client, "Your coins has been set to %i coins!", num);
                ReplyToCommand(client, "Coins: %i", g_iPlayer[client].Coins);
            }
            else
            {
                ReplyToCommand(client, "use: add/remove/set");
            }
        }
        else if (args == 3)
        {
            char arg3[32], name[32];
            GetCmdArg(3, arg3, sizeof(arg3));
            int target = FindTarget(client, arg3);
            if (target == -1)
            {
                return Plugin_Handled;
            }
            GetClientName(target, name, sizeof(name));

            if (StrEqual(arg1, "add"))
            { 
                Missions_AddCoins(target, num);
                ReplyToCommand(client, "You have added %i coins to %s!", num, name);
                ReplyToCommand(target, "There has been %i coins added!", num);
                ReplyToCommand(target, "Coins: %i", g_iPlayer[target].Coins);
            
            }

            else if (StrEqual(arg1, "remove"))
            {   
                Missions_RemoveCoins(target, num);
                ReplyToCommand(client, "You have removed %i coins of %s!", num, name);
                ReplyToCommand(target, "There has been %i coins removed!", num);
                ReplyToCommand(target, "Coins: %i", g_iPlayer[target].Coins);
            }

            else if (StrEqual(arg1, "set"))
            {
                Missions_SetCoins(target, num);
                ReplyToCommand(client, "You have set the coins of %s to %i coins!", name, num);
                ReplyToCommand(target, "Your coins has been set to %i coins!", num);
                ReplyToCommand(target, "Coins: %i", g_iPlayer[target].Coins);
            }

            else
            {
                ReplyToCommand(client, "use: add/remove/set");
            }
        }
    }

    else
    {
        ReplyToCommand(client, "Usages:");
        ReplyToCommand(client, "sm_coins");
        ReplyToCommand(client, "sm_coins (add/remove/set) (amount)");
        ReplyToCommand(client, "sm_coins (add/remove/set) (amount) (username)");
    }
    
    return Plugin_Handled;
}

public Action Command_Missions(int client, int args)
{
    if (args == 0)
    {
        bool HasMission = false;
        for (int x = 0; x < 3; x++)
        {
            if (g_cClientMissions[client*3+x][0] != 0)
            {
                HasMission = true;
                break;
            }
        }
        if (HasMission)
        {
            for(int i = 0; i < 3; i++)
            {   
                if (g_cClientMissions[client*3+i][0] == 0)
                {
                    PrintToChat(client, "%i. No mission yet!", i+1, g_cClientMissions[client*3+i]);
                }
                else
                {
                    PrintToChat(client, "%i. %s (%i/%i)", i+1, g_cClientMissions[client*3+i], g_cProgression[client*3+i], g_cProgressionGoal[client*3+i]);
                    char time[16];
                    FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
                    PrintToConsoleAll("[%s] The shown index is %i for client number %i", time, client*3+i, client);
                }
            }
        }
        else
        {
            PrintToChat(client, "You don't have any missions!");
        }
    }

    else if (args == 1)
    {
        char arg1[32];
        GetCmdArg(1, arg1, sizeof(arg1));
        if (StrEqual(arg1, "usage", false))
        {
            PrintToChat(client, "Usages:");
            PrintToChat(client, "sm_missions ~ To show your missions.");
            PrintToChat(client, "sm_missions [usage] ~ Show these messages.");
            PrintToChat(client, "sm_missions [all] ~ To show all missions that are available.");
        }

        else if (StrEqual(arg1, "all", false))
        {
            if (g_aMissionsList.Length == 0)
            {
                PrintToChat(client, "There are no available missions!");
            }
            else 
            {
                PrintToChat(client, "Available missions:");
                for(int i = 0; i < g_aMissionsList.Length; i++)
                {
                    char MissionName[32];
                    g_aMissionsList.GetString(i, MissionName, sizeof(MissionName));
                    PrintToChat(client, "%i. %s", i+1, MissionName);
                }
            }
        }
    }

    else if (args == 2)
    {
        char arg1[32], arg2[32];
        GetCmdArg(1, arg1, sizeof(arg1));
        GetCmdArg(2, arg2, sizeof(arg2));

        if (StrEqual(arg1, "give", false))
        {
            if (Missions_IsValidMission(arg2))
            {
                bool NoSpace = true;
                for (int i = 0; i < 3; i++)
                {
                    if (g_cClientMissions[client*3+i][0] == 0)
                    {
                        g_cClientMissions[client*3+i] = arg2;

                        char time[16];
                        FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
                        PrintToConsoleAll("[%s] the index of the given mission is %i", time, client*3+i);

                        PrintToChat(client, "Mission '%s' is now on spot %i!",arg2, i+1);
                        NoSpace = false;
                        int index = client*3+i; 
                        Call_StartForward(g_fwOnGivenMission);
                        Call_PushCell(client);
                        Call_PushString(arg2);
                        Call_PushCell(index);
                        Call_Finish();
                        break;
                    }
                }
                if (NoSpace)
                {
                    PrintToChat(client, "There is no available spot in your mission list!");
                }
            }

            else
            {
                PrintToChat(client, "'%s' is not a valid mission!", arg2);
            }
        }
    }
    else 
    {
        PrintToChat(client, "Usages:");
        PrintToChat(client, "sm_missions ~ To show your missions.");
        PrintToChat(client, "sm_missions [usage] ~ Show these messages.");
        PrintToChat(client, "sm_missions [all] ~ To show all missions that are available.");
    }
    
}

public int Native_AddCoins(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int coins = GetNativeCell(2);

    g_iPlayer[client].Coins += coins;
    return 0;
}

public int Native_RemoveCoins(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int coins = GetNativeCell(2);

    g_iPlayer[client].Coins -= coins;
    return 0;
}

public int Native_SetCoins(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int coins = GetNativeCell(2);

    g_iPlayer[client].Coins = coins;
    return 0;
}

public int Native_RegisterMission(Handle plugin, int numParams)
{
    char MissionName[32];
    GetNativeString(1, MissionName, sizeof(MissionName));
    g_aMissionsList.PushString(MissionName);
    MissionCounter++;
}

public int Native_IsValidMission(Handle plugin, int numParams)
{
    char MissionName[32];
    GetNativeString(1, MissionName, sizeof(MissionName));
    if (g_aMissionsList.FindString(MissionName) == -1)
    {
        return false;
    }

    else
    {
        return true;
    }
}

public int Native_IsValidClientMission(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    for(int i = 0; i < 3; i++)
    {
        if (StrEqual(g_cClientMissions[client*3+i], MissionName, false))
        {
            return true;
        }
    }
    return false;
}

public int Native_FindClientMission(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    for (int i = 0; i < 3; i++)
    {
        if(StrEqual(g_cClientMissions[client*3+i], MissionName))
        {
            return client*3+i;
        }
    }
    return -1;
}

public int Native_SetProgressionGoal(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    int goal = GetNativeCell(3);
    if (Missions_IsValidMission(MissionName))
    {
        int index = Missions_FindClientMission(client, MissionName);
        char time[16];
        FormatTime(time, sizeof(time), "%H:%M:%S", GetTime());
        PrintToConsoleAll("[%s] the index of the goal is %i", time, index);
        g_cProgressionGoal[index] = goal;
    }
    return 0;
}

public int Native_GetProgressionGoal(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    int index = Missions_FindClientMission(client, MissionName);
    return g_cProgressionGoal[index];
}

public int Native_AddProgression(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    if (Missions_IsValidMission(MissionName))
    {
        int index = Missions_FindClientMission(client, MissionName);
        g_cProgression[index]++;
    }
    return 0;
}

public int Native_GiveMission(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));

    if (Missions_IsValidMission(MissionName))
    {
        for (int i = 0; i < 3; i++)
        {
            if (g_cClientMissions[client*3+i][0] == 0)
            {
                g_cClientMissions[client*3+i] = MissionName;
                int index = client*3+i;
                Call_StartForward(g_fwOnGivenMission);
                Call_PushCell(client);
                Call_PushString(MissionName);
                Call_PushCell(index);
                Call_Finish();
                break;
            }
        }
    }
    return 0;
}

public int Native_RemoveMission(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    if (Missions_IsValidMission(MissionName))
    {
        int index = Missions_FindClientMission(client, MissionName);
        g_cClientMissions[index][0] = 0;
        g_cProgression[index] = 0;
        g_cProgressionGoal[index] = 0;

        return 0;
    }
    return -1;
}

public int Native_HasCompleted(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    int index = Missions_FindClientMission(client, MissionName);
    if (g_cProgressionGoal[index] == g_cProgression[index])
    {
        return true;
    }

    return false;
}

public int Native_RewardOnCompletion(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    int coins = GetNativeCell(3);

    Missions_AddCoins(client, coins);

    Mission_RemoveMission(client, MissionName);
    PrintToChat(client, "You've completed the mission '%s', You've been earned with %i coins!", MissionName, coins);

    return 0;
}