#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adt_array>
#include <missions>

ArrayList g_aMissionsList = null;
int MissionCounter = 0;
char g_cClientMissions[(MAXPLAYERS + 1) * 3][32];

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
    RegConsoleCmd("sm_missions", Command_Missions, "Prints the missions you got");
    RegConsoleCmd("sm_allmissions", Command_AllMissions, "Prints every missions in the array");

    g_aMissionsList = new ArrayList(32);
    LoadTranslations("common.phrases.txt");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MISSIONS_AddCoins", Native_AddCoins);
    CreateNative("MISSIONS_RemoveCoins", Native_RemoveCoins);
    CreateNative("MISSIONS_SetCoins", Native_SetCoins);

    CreateNative("MISSIONS_RegisterMission", Native_RegisterMission);
    CreateNative("MISSIONS_IsValidMission", Native_IsValidMission);
    CreateNative("MISSIONS_IsValidClientMission", Native_IsValidClientMission);

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
                MISSIONS_AddCoins(client, num);
                ReplyToCommand(client, "Added %i coins!", num);
                ReplyToCommand(client, "Coins: %i", g_iPlayer[client].Coins);
            }

            else if (StrEqual(arg1, "remove"))
            {
                MISSIONS_RemoveCoins(client, num);
                ReplyToCommand(client, "Removed %i coins!", num);
                ReplyToCommand(client, "Coins: %i", g_iPlayer[client].Coins);
            }

            else if (StrEqual(arg1, "set"))
            {
                MISSIONS_SetCoins(client, num);
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
                MISSIONS_AddCoins(target, num);
                ReplyToCommand(client, "You have added %i coins to %s!", num, name);
                ReplyToCommand(target, "There has been %i coins added!", num);
                ReplyToCommand(target, "Coins: %i", g_iPlayer[target].Coins);
            
            }

            else if (StrEqual(arg1, "remove"))
            {   
                MISSIONS_RemoveCoins(target, num);
                ReplyToCommand(client, "You have removed %i coins of %s!", num, name);
                ReplyToCommand(target, "There has been %i coins removed!", num);
                ReplyToCommand(target, "Coins: %i", g_iPlayer[target].Coins);
            }

            else if (StrEqual(arg1, "set"))
            {
                MISSIONS_SetCoins(target, num);
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
    for(int i = 0; i < 3; i++)
    {

        PrintToChat(client, "%i. %s", i++, g_cClientMissions[client*3+i]);
    }
}

public Action Command_AllMissions(int client, int args)
{
    for(int i = 0; i <= g_aMissionsList.Length; i++)
    {
        char MissionName[32];
        g_aMissionsList.GetString(i, MissionName, sizeof(MissionName));
        PrintToChat(client, "%i. %s", i, MissionName);
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