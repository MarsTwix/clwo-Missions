#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adt_array>
#include <missions>

GlobalForward g_fwOnGivenMission = null;

ArrayList g_aMissionsList = null;
int g_iMissionCounter = 0;
char g_cClientMissions[(MAXPLAYERS + 1) * 3][32];
char g_cMissionSave[MAXPLAYERS + 1][32];
int g_iProgressionGoal[(MAXPLAYERS + 1) * 3];
int g_iProgression[(MAXPLAYERS + 1) * 3];
bool g_bCompleted[(MAXPLAYERS + 1) * 3];

ConVar g_cDebugging = null;

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
    version = "0.3.0",
    url = "clwo.eu"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_coins", Command_Coins, "Prints the amount of coins you got");
    RegConsoleCmd("sm_missions", Command_Missions, "Print own/all missions and add/remove/set missions");

    g_cDebugging = CreateConVar("missions_debug", "1", "This is to enable list/give/remove/set missions commands for testing/debugging.");

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

    CreateNative("Missions_GiveMission", Native_GiveMission);
    CreateNative("Missions_RemoveMission", Native_RemoveMission);

    CreateNative("Missions_SetProgressionGoal", Native_SetProgressionGoal);
    CreateNative("Missions_GetProgressionGoal", Native_GetProgressionGoal);
    CreateNative("Missions_AddProgression", Native_AddProgression);

    CreateNative("Missions_HasCompleted", Native_HasCompleted);
    CreateNative("Missions_RewardOnCompletion", Native_RewardOnCompletion);

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
        Menu mClientMissions = new Menu(MenuHandler_ClientMissions);
        mClientMissions.SetTitle("Your missions");
        for(int i = 0; i < 3; i++)
        {   
            if (g_cClientMissions[client*3+i][0] == 0)
            {
                mClientMissions.AddItem("NoMission" ,"No mission yet");
            }
            else
            {
                if (g_bCompleted[client*3+i])
                {
                    char message[32];
                    Format(message, sizeof(message), "%s (Completed)", g_cClientMissions[client*3+i], g_iProgression[client*3+i], g_iProgressionGoal[client*3+i]);
                    mClientMissions.AddItem(g_cClientMissions[client*3+i], message);
                }
                else
                {
                    char message[32];
                    Format(message, sizeof(message), "%s (%i/%i)", g_cClientMissions[client*3+i], g_iProgression[client*3+i], g_iProgressionGoal[client*3+i]);
                    mClientMissions.AddItem(g_cClientMissions[client*3+i], message);
                }
            }
        }
        mClientMissions.Display(client, 240);
        return Plugin_Handled;
    }
    if (g_cDebugging.BoolValue == true)
    {
        if (args == 1)
        {
            char arg1[32];
            GetCmdArg(1, arg1, sizeof(arg1));
            if (StrEqual(arg1, "usage", false))
            {
                ReplyToCommand(client, "Usages:");
                ReplyToCommand(client, "sm_missions ~ To show your missions.");
                ReplyToCommand(client, "sm_missions [usage] ~ Show these messages.");
                ReplyToCommand(client, "sm_missions [list] ~ To show a list of all available missions.");
            }

            else if (StrEqual(arg1, "list", false))
            {
                Menu mAvailableMissions = new Menu(MenuHandler_AvailableMissions);
                mAvailableMissions.SetTitle("Available missions");
                if (g_aMissionsList.Length == 0)
                {
                    mAvailableMissions.AddItem("NoAvailable", "There is no mission available!", ITEMDRAW_DISABLED);
                }

                else 
                {
                    for(int i = 0; i < g_aMissionsList.Length; i++)
                    {
                        char MissionName[32];
                        g_aMissionsList.GetString(i, MissionName, sizeof(MissionName));
                        mAvailableMissions.AddItem(MissionName, MissionName);
                    }
                }
                mAvailableMissions.Display(client, 240);
                return Plugin_Handled;
            }
            else if (StrEqual(arg1, "give", false))
            {
                Menu mGiveAvailableMissions = new Menu(MenuHandler_GiveAvailableMissions);
                mGiveAvailableMissions.SetTitle("Choose a mission");
                if (g_aMissionsList.Length == 0)
                {
                    mGiveAvailableMissions.AddItem("NoAvailable", "There is no mission available!", ITEMDRAW_DISABLED);
                }

                else 
                {
                    for(int i = 0; i < g_aMissionsList.Length; i++)
                    {
                        char MissionName[32];
                        g_aMissionsList.GetString(i, MissionName, sizeof(MissionName));
                        mGiveAvailableMissions.AddItem(MissionName, MissionName);
                    }
                }
                mGiveAvailableMissions.Display(client, 240);
                return Plugin_Handled;
            }
            else if(StrEqual(arg1, "remove", false))
            {
                Menu mRemoveClientMissions = new Menu(MenuHandler_RemoveClientMissions);
                mRemoveClientMissions.SetTitle("Choose a mission");
                for(int i = 0; i < 3; i++)
                {   
                    if (g_cClientMissions[client*3+i][0] == 0)
                    {
                        mRemoveClientMissions.AddItem("NoMission" ,"No mission yet", ITEMDRAW_DISABLED);
                    }
                    else
                    {
                        if (g_bCompleted[client*3+i])
                        {
                            char message[32];
                            Format(message, sizeof(message), "%s (Completed)", g_cClientMissions[client*3+i], g_iProgression[client*3+i], g_iProgressionGoal[client*3+i]);
                            mRemoveClientMissions.AddItem(g_cClientMissions[client*3+i], message);
                        }
                        else
                        {
                            char message[32];
                            Format(message, sizeof(message), "%s (%i/%i)", g_cClientMissions[client*3+i], g_iProgression[client*3+i], g_iProgressionGoal[client*3+i]);
                            mRemoveClientMissions.AddItem(g_cClientMissions[client*3+i], message);
                        }
                    }
                }
                mRemoveClientMissions.Display(client, 240);
                return Plugin_Handled;
            }
            else if (StrEqual(arg1, "set", false))
            {
                Menu mGetAvailableMissions = new Menu(MenuHandler_GetAvailableMissions);
                mGetAvailableMissions.SetTitle("Choose a mission");
                if (g_aMissionsList.Length == 0)
                {
                    mGetAvailableMissions.AddItem("NoAvailable", "There is no mission available!", ITEMDRAW_DISABLED);
                }

                else 
                {
                    for(int i = 0; i < g_aMissionsList.Length; i++)
                    {
                        char MissionName[32];
                        g_aMissionsList.GetString(i, MissionName, sizeof(MissionName));
                        mGetAvailableMissions.AddItem(MissionName, MissionName);
                    }
                }
                mGetAvailableMissions.Display(client, 240);
                return Plugin_Handled;
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
                        ReplyToCommand(client, "There is no available spot in your mission list!");
                    }
                }

                else
                {
                    ReplyToCommand(client, "'%s' is not a valid mission!", arg2);
                }
            }
        }
        else 
        {
            ReplyToCommand(client, "Usages:");
            ReplyToCommand(client, "sm_missions ~ To show your missions.");
            ReplyToCommand(client, "sm_missions [usage] ~ Show these messages.");
            ReplyToCommand(client, "sm_missions [all] ~ To show all missions that are available.");
        }
    }
    return Plugin_Handled;
}

public int MenuHandler_ClientMissions(Menu menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        delete menu;
    }
}

public int MenuHandler_AvailableMissions(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public int MenuHandler_GiveAvailableMissions(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            bool NoSpace = true;
            char info[32];
            menu.GetItem(param2, info, sizeof(info)); 
            for (int i = 0; i < 3; i++)
            {
                if (g_cClientMissions[param1*3+i][0] == 0)
                {
                    g_cClientMissions[param1*3+i] = info;

                    PrintToChat(param1, "Mission '%s' is now on spot %i!",info, i+1);
                    NoSpace = false;
                    int index = param1*3+i; 
                    Call_StartForward(g_fwOnGivenMission);
                    Call_PushCell(param1);
                    Call_PushString(info);
                    Call_PushCell(index);
                    Call_Finish();
                    break;
                }
            }
            if (NoSpace)
            {
                PrintToChat(param1, "There is no available spot in your mission list!");
            }
        }

        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public int MenuHandler_RemoveClientMissions(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            Missions_RemoveMission(param1, info);
            PrintToChat(param1, "Mission '%s' has been removed from your missions list!", info);
        }

        case MenuAction_End:
        {
            delete menu;
        }
    }
}

public int MenuHandler_GetAvailableMissions(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            g_cMissionSave[param1] = info;
            menu_SetClientMission(param1);
        }

        case MenuAction_End:
        {
            delete menu;
        }
    }
}

void menu_SetClientMission(int client)
{
    Menu mSetClientMissions = new Menu(MenuHandler_SetClientMissions);
    mSetClientMissions.SetTitle("Choose a mission");
    for(int i = 0; i < 3; i++)
    {   
        if (g_cClientMissions[client*3+i][0] == 0)
        {
            mSetClientMissions.AddItem("NoMission" ,"No mission yet");
        }
        else
        {
            if (g_bCompleted[client*3+i])
            {
                char message[32];
                Format(message, sizeof(message), "%s (Completed)", g_cClientMissions[client*3+i], g_iProgression[client*3+i], g_iProgressionGoal[client*3+i]);
                mSetClientMissions.AddItem(g_cClientMissions[client*3+i], message);
            }
            else
            {
                char message[32];
                Format(message, sizeof(message), "%s (%i/%i)", g_cClientMissions[client*3+i], g_iProgression[client*3+i], g_iProgressionGoal[client*3+i]);
                mSetClientMissions.AddItem(g_cClientMissions[client*3+i], message);
            }
        }
    }
    mSetClientMissions.Display(client, 240);
}

public int MenuHandler_SetClientMissions(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));
            Missions_RemoveMission(param1, info);
            Missions_GiveMission(param1, g_cMissionSave[param1]);
        }

        case MenuAction_End:
        {
            delete menu;
        }
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
    g_iMissionCounter++;
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
        g_iProgressionGoal[index] = goal;
    }
    return 0;
}

public int Native_GetProgressionGoal(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    int index = Missions_FindClientMission(client, MissionName);
    return g_iProgressionGoal[index];
}

public int Native_AddProgression(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    if (Missions_IsValidMission(MissionName))
    {
        int index = Missions_FindClientMission(client, MissionName);
        g_iProgression[index]++;
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
                return 0;
            }
        }
    }
    return -1;
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
        g_iProgression[index] = 0;
        g_iProgressionGoal[index] = 0;
        g_bCompleted[index] = false;

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
    if (g_iProgressionGoal[index] == g_iProgression[index])
    {
        g_bCompleted[index] = true;
        return g_bCompleted[index];
    }

    return g_bCompleted[index];
}

public int Native_RewardOnCompletion(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    int coins = GetNativeCell(3);

    Missions_AddCoins(client, coins);

    PrintToChat(client, "You've completed the mission '%s', You've been earned with %i coins!", MissionName, coins);

    return 0;
}
