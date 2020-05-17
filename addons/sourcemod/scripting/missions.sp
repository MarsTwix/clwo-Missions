#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <missions>

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
    LoadTranslations("common.phrases.txt");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("MISSIONS_AddCoins", Native_AddCoins);
    CreateNative("MISSIONS_RemoveCoins", Native_RemoveCoins);
    CreateNative("MISSIONS_SetCoins", Native_SetCoins);

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
