#pragma semicolon 1

//sourcemod
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <adt_array>

//ttt or others
#include <colorlib>
#include <ttt>


//own
#include <missions>

#define CompletionSND "ui/coin_pickup_01.wav"
#define tag "[info] "

GlobalForward g_fwOnGivenMission = null;
GlobalForward g_fwOnMissionsReady = null;

Database g_DataBase = null;

ArrayList g_aMissionsList = null;
ArrayList g_aMissionsSounds = null;

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

//|----------Public plugins-----------|
public Plugin myinfo =
{
    name = "Missions",
    author = "MarsTwix",
    description = "Misions players can complete and get rewarded",
    version = "0.6.0",
    url = "clwo.eu"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_coins", Command_Coins, "Prints the amount of coins you got");
    RegConsoleCmd("sm_missions", Command_Missions, "Print own/all missions and add/remove/set missions");
    RegConsoleCmd("sm_dropdb", Command_DropDB, "");

    g_cDebugging = CreateConVar("missions_debug", "1", "This is to enable list/give/remove/set missions commands for testing/debugging.");

    g_aMissionsList = new ArrayList(32);
    g_aMissionsSounds = new ArrayList(PLATFORM_MAX_PATH);
    AddSounds();

    Database.Connect(DbCallback_Connect, "missions");

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
    g_fwOnMissionsReady = new GlobalForward("Missions_OnMissionsReady", ET_Ignore);

    return APLRes_Success;
}

public void OnMapStart()
{
    PrecacheSound(CompletionSND);
    for (int i = 0; i < g_aMissionsSounds.Length; i++)
    {
        char SND[PLATFORM_MAX_PATH];
        g_aMissionsSounds.GetString(i, SND, sizeof(SND));
        PrecacheSound(SND);
    }
}

public void OnClientPutInServer(int client)
{
    g_iPlayer[client].Coins = -1;

    Db_SelectClientCoins(client);
    Db_SelectClientMissions(client);
    Db_SelectClientProgression(client);
}

//|--------------Database-------------|
public void DbCallback_Connect(Database db, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("DbCallback_Connect: %s", error);
        return;
    }

    g_DataBase = db;
    g_DataBase.SetCharset("utf8");

    SQL_FastQuery(g_DataBase, "CREATE TABLE IF NOT EXISTS missions_coins (account_id INT UNSIGNED NOT NULL, coins INT UNSIGNED NOT NULL, PRIMARY KEY (account_id));");
    SQL_FastQuery(g_DataBase, "CREATE TABLE IF NOT EXISTS missions_player (id INTEGER PRIMARY KEY, account_id INT UNSIGNED NOT NULL, missions_id VARCHAR(32) NOT NULL);");
    SQL_FastQuery(g_DataBase, "CREATE TABLE IF NOT EXISTS missions_progression (id INTEGER PRIMARY KEY, account_id INT UNSIGNED NOT NULL, progression_made INT UNSIGNED NOT NULL, progression_goal INT UNSIGNED NOT NULL);");

    Call_StartForward(g_fwOnMissionsReady);
    Call_Finish();
}

void Db_SelectClientCoins(int client)
{
    int accountId = GetSteamAccountID(client, true);

    char query[128];
    Format(query, sizeof(query), "SELECT `coins` FROM `missions_coins` WHERE `account_id` = '%d';", accountId);
    g_DataBase.Query(DbCallback_SelectClientCoins, query, GetClientUserId(client));
}

public void DbCallback_SelectClientCoins(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_SelectClientCoins: %s", error);
        return;
    }

    int client = GetClientOfUserId(userid);
    if (IsValidClient(client))
    {
        if (results.FetchRow())
        {
            g_iPlayer[client].Coins = results.FetchInt(0);
        }
        else
        {
            g_iPlayer[client].Coins = 0;
            Db_InsertClientCoins(client);
        }
    }
}

void Db_InsertClientCoins(int client)
{
    int accountId = GetSteamAccountID(client, true);

    char query[255];
    Format(query, sizeof(query), "INSERT INTO `missions_coins` (`account_id`, `coins`) VALUES ('%d', '%d');", accountId, g_iPlayer[client].Coins);
    g_DataBase.Query(DbCallback_InsertClientCoins, query, GetClientUserId(client));
}

public void DbCallback_InsertClientCoins(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_InsertClientCoins: %s", error);
        return;
    }
}

void Db_UpdateClientCoins(int client)
{
    if (g_iPlayer[client].Coins < 0)
    {
        return;
    }

    int accountId = GetSteamAccountID(client, true);

    char query[255];
    Format(query, sizeof(query), "UPDATE `missions_coins` SET `coins` = '%d' WHERE `account_id` = '%d';", g_iPlayer[client].Coins, accountId);
    g_DataBase.Query(DbCallback_UpdateClientCoins, query, GetClientUserId(client));
}

public void DbCallback_UpdateClientCoins(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_UpdateClientCoins: %s", error);
    }
}

void Db_SelectClientMissions(int client)
{
    int accountId = GetSteamAccountID(client, true);

    char query[128];
    Format(query, sizeof(query), "SELECT `missions_id` FROM `missions_player` WHERE `account_id` = '%d';", accountId);
    g_DataBase.Query(DbCallback_SelectClientMissions, query, GetClientUserId(client));
}

public void DbCallback_SelectClientMissions(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_SelectClientMissions: %s", error);
        return;
    }
    int num = 0;
    char MissionName[32];
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client))
    {
        while (results.FetchRow())
        {
            results.FetchString(0, MissionName, sizeof(MissionName));
            g_cClientMissions[client*3+num] = MissionName;
            num++;
        }
    }
}

void DB_InsertClientMission(int client, char MissionName[32])
{
    int accountId = GetSteamAccountID(client, true);

    char query[255];
    Format(query, sizeof(query), "INSERT INTO missions_player (account_id, missions_id) VALUES('%d', '%s');", accountId, MissionName);
    g_DataBase.Query(DbCallback_InsertClientMission, query, GetClientUserId(client));
}

public void DbCallback_InsertClientMission(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_InsertClientMission: %s", error);
        return;
    }
}

void DB_DeleteClientMission(int client, char MissionName[32])
{
    int accountId = GetSteamAccountID(client, true);

    char query[255];
    Format(query, sizeof(query), "DELETE FROM missions_player WHERE account_id = '%d' AND missions_id = '%s';", accountId, MissionName);
    g_DataBase.Query(DbCallback_DeleteClientMission, query, GetClientUserId(client));
}

public void DbCallback_DeleteClientMission(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_DeleteClientMission: %s", error);
        return;
    }
}

void Db_SelectClientProgression(int client)
{
    int accountId = GetSteamAccountID(client, true);

    char query[128];
    Format(query, sizeof(query), "SELECT progression_made, progression_goal FROM `missions_progression` WHERE `account_id` = '%d';", accountId);
    g_DataBase.Query(DbCallback_SelectClientProgression, query, GetClientUserId(client));
}

public void DbCallback_SelectClientProgression(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_SelectClientMissions: %s", error);
        return;
    }
    int num = 0;
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client))
    {
        while (results.FetchRow())
        {
            int ProgressionMade = results.FetchInt(0);
            int ProgressionGoal = results.FetchInt(1);

            g_iProgression[client*3+num] = ProgressionMade;
            g_iProgressionGoal[client*3+num] = ProgressionGoal;
            if (ProgressionMade == ProgressionGoal)
            {
                g_bCompleted[client*3+num] = true;
            }
            num++;
        }
    }
}

void DB_InsertClientProgression(int id, int client, int ProgressionGoal)
{
    int accountId = GetSteamAccountID(client, true);

    char query[255];
    Format(query, sizeof(query), "INSERT INTO missions_progression (id, account_id, progression_made, progression_goal) VALUES('%i', '%d', '%i', '%i');", id, accountId, 0, ProgressionGoal);
    g_DataBase.Query(DbCallback_InsertClientProgression, query, GetClientUserId(client));
}

public void DbCallback_InsertClientProgression(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_InsertClientProgression: %s", error);
        return;
    }
}

int DB_GetId(int client, char MissionName[32])
{
    DBResultSet results;
    int accountId = GetSteamAccountID(client, true);

    char query[255];
    char error[255];
    Format(query, sizeof(query), "SELECT `id` FROM `missions_player` WHERE `account_id` = '%d' AND `missions_id` = '%s';", accountId, MissionName);

    results = SQL_Query(g_DataBase, query);
    SQL_GetError(g_DataBase, error, sizeof(error));

    if (results == null)
    {
        PrintToServer("DB_GetId: %s", error);
        return -1;
    }

    else if (IsValidClient(client) && results.FetchRow())
    {
        return results.FetchInt(0);
    }
    return -1;
}

void DB_DeleteClientProgression(int client, int id)
{
    int accountId = GetSteamAccountID(client, true);

    char query[255];
    Format(query, sizeof(query), "DELETE FROM missions_progression WHERE account_id = '%d' AND id = '%i';", accountId, id);
    g_DataBase.Query(DbCallback_DeleteClientProgression, query, GetClientUserId(client));
}

public void DbCallback_DeleteClientProgression(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_DeleteClientProgression: %s", error);
        return;
    }
}

void DB_UpdateClientProgression(int client, int id, char MissionName[32])
{
    int accountId = GetSteamAccountID(client, true);
    int index = Missions_FindClientMission(client, MissionName);

    char query[255];
    Format(query, sizeof(query), "UPDATE `missions_progression` SET `progression_made` = '%d' WHERE account_id = '%d' AND id = '%i';", g_iProgression[index], accountId, id);
    g_DataBase.Query(DbCallback_UpdateClientProgression, query, GetClientUserId(client));
}

public void DbCallback_UpdateClientProgression(Database db, DBResultSet results, const char[] error, int userid)
{
    if (results == null)
    {
        PrintToServer("DbCallback_UpdateClientProgression: %s", error);
        return;
    }
}

//|------------Commands-----------|
Action Command_Coins(int client, int args)
{
    if (args == 0){CReplyToCommand(client, "Coins: {orange}%i{default}", g_iPlayer[client].Coins);}

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
                CReplyToCommand(client, tag ... "Added {orange}%i{default} coins!", num);
            }

            else if (StrEqual(arg1, "remove"))
            {
                Missions_RemoveCoins(client, num);
                CReplyToCommand(client, tag ... "Removed {orange}%i{default} coins!", num);
            }

            else if (StrEqual(arg1, "set"))
            {
                Missions_SetCoins(client, num);
                CReplyToCommand(client, tag ... "Your coins has been set to {orange}%i{default} coins!", num);
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
                CReplyToCommand(client, tag ... "You have added {orange}%i{default} coins to {yellow}%s{default}!", num, name);
                CReplyToCommand(target, tag ... "There has been {orange}%i{default} coins added!", num);
            
            }

            else if (StrEqual(arg1, "remove"))
            {   
                Missions_RemoveCoins(target, num);
                CReplyToCommand(client, tag ... "You have removed {orange}%i{default} coins of {yellow}%s{default}!", num, name);
                CReplyToCommand(target, tag ... "There has been {orange}%i{default} coins removed!", num);
            }

            else if (StrEqual(arg1, "set"))
            {
                Missions_SetCoins(target, num);
                CReplyToCommand(client, tag ... "You have set the coins of {yellow}%s{default} to {orange}%i{default} coins!", name, num);
                CReplyToCommand(target, tag ... "Your coins has been set to {orange}%i{default} coins!", num);
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
                            DB_InsertClientMission(client, arg2);

                            CPrintToChat(client, tag ... "Mission {orange}%s{default} is now on spot {yellow}%i{default}!",arg2, i+1);
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
                        ReplyToCommand(client, tag ... "There is no available spot in your mission list!");
                    }
                }

                else
                {
                    CReplyToCommand(client, tag ... "{orange}%s{default} is not a valid mission!", arg2);
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

public Action Command_DropDB(int client, int args)
{
    if (args == 1)
    {
        char arg1[64];
        GetCmdArg(1, arg1, sizeof(arg1));
        char query[255];
        Format(query, sizeof(query), "DROP TABLE %s", arg1);
        g_DataBase.Query(DbCallback_DeleteTable, query, client);
    }
}

public void DbCallback_DeleteTable(Database db, DBResultSet results, const char[] error, int client)
{
    if (results == null)
    {
        PrintToServer("DbCallback_DeleteTable: %s", error);
        PrintToChat(client, "Something went wrong with deleting the table!");
        return;
    }
    else
    {
        PrintToChat(client, "The table has been deleted!");
    }
}

//|--------------Menu stuff-----------|

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
                    DB_InsertClientMission(param1, info);

                    CPrintToChat(param1, tag ... "Mission {orange}%s{default} is now on spot {yellow}%i{default}!",info, i+1);
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
                PrintToChat(param1, tag ... "There is no available spot in your mission list!");
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
            CPrintToChat(param1, tag ... "Mission {orange}%s{default} has been removed from your missions list!", info);
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

            if (StrEqual(info, "NoMission"))
            {
                CPrintToChat(param1, "An empty spot has been set to mission {orange}%s{default}!", g_cMissionSave[param1]);
            }

            else
            {
                CPrintToChat(param1, tag ... "Mission {yellow}%s{default} has been set to {orange}%s{default}!", info, g_cMissionSave[param1]);
            }
            
        }

        case MenuAction_End:
        {
            delete menu;
        }
    }
}

//|---------------Natives--------------|

public int Native_AddCoins(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int coins = GetNativeCell(2);

    g_iPlayer[client].Coins += coins;
    Db_UpdateClientCoins(client);
    return 0;
}

public int Native_RemoveCoins(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int coins = GetNativeCell(2);

    g_iPlayer[client].Coins -= coins;
    Db_UpdateClientCoins(client);
    return 0;
}

public int Native_SetCoins(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    int coins = GetNativeCell(2);

    g_iPlayer[client].Coins = coins;
    Db_UpdateClientCoins(client);
    return 0;
}

public int Native_RegisterMission(Handle plugin, int numParams)
{
    char MissionName[32];
    GetNativeString(1, MissionName, sizeof(MissionName));
    g_aMissionsList.PushString(MissionName);
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
        int id = DB_GetId(client, MissionName);
        DB_InsertClientProgression(id, client, goal);
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
    int index = Missions_FindClientMission(client, MissionName);
    if (Missions_IsValidMission(MissionName) && g_bCompleted[index] == false)
    {
        g_iProgression[index]++;
        int id = DB_GetId(client, MissionName);
        DB_UpdateClientProgression(client, id, MissionName);
        if(g_iProgressionGoal[index] == g_iProgression[index])
        {
            g_bCompleted[index] = true;
        }
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
                DB_InsertClientMission(client, MissionName);

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
        int id = DB_GetId(client, MissionName);
        DB_DeleteClientProgression(client, id);
        int index = Missions_FindClientMission(client, MissionName);
        g_cClientMissions[index][0] = 0;
        DB_DeleteClientMission(client, MissionName);

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
    return g_bCompleted[index];
}

public int Native_RewardOnCompletion(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char MissionName[32];
    GetNativeString(2, MissionName, sizeof(MissionName));
    int coins = GetNativeCell(3);

    Missions_AddCoins(client, coins);

    CPrintToChat(client, tag ... "You've completed the mission {yellow}%s{default}, You've been earned with {orange}%i{default} coins!", MissionName, coins);
    
    EmitSoundToClient(client, CompletionSND);
    int RandomNum = GetRandomInt(0, 56);
    char SND[PLATFORM_MAX_PATH];
    g_aMissionsSounds.GetString(RandomNum, SND, sizeof(SND));
    EmitSoundToClient(client, SND);
    return 0;
}

//|-------------Sounds-------------|
void AddSounds()
{
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag01.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag02.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag03.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag04.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag05.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag06.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag07.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag12.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag13.wav");
    g_aMissionsSounds.PushString("player/vo/sas/onarollbrag14.wav");

    g_aMissionsSounds.PushString("player/vo/phoenix/onarollbrag01.wav");
    g_aMissionsSounds.PushString("player/vo/phoenix/onarollbrag03.wav");
    g_aMissionsSounds.PushString("player/vo/phoenix/onarollbrag11.wav");

    g_aMissionsSounds.PushString("player/vo/leet/onarollbrag01.wav");
    g_aMissionsSounds.PushString("player/vo/leet/onarollbrag02.wav");
    g_aMissionsSounds.PushString("player/vo/leet/onarollbrag03.wav");

    g_aMissionsSounds.PushString("player/vo/idf/onarollbrag03.wav");
    g_aMissionsSounds.PushString("player/vo/idf/onarollbrag04.wav");
    g_aMissionsSounds.PushString("player/vo/idf/onarollbrag05.wav");
    g_aMissionsSounds.PushString("player/vo/idf/onarollbrag06.wav");
    g_aMissionsSounds.PushString("player/vo/idf/onarollbrag07.wav");
    g_aMissionsSounds.PushString("player/vo/idf/onarollbrag08.wav");
    g_aMissionsSounds.PushString("player/vo/idf/onarollbrag12.wav");

    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag01.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag02.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag03.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag04.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag05.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag06.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag07.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag08.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag09.wav");
    g_aMissionsSounds.PushString("player/vo/gsg9/onarollbrag09.wav");

    g_aMissionsSounds.PushString("player/vo/gign/onarollbrag01.wav");
    g_aMissionsSounds.PushString("player/vo/gign/onarollbrag02.wav");
    g_aMissionsSounds.PushString("player/vo/gign/onarollbrag03.wav");
    g_aMissionsSounds.PushString("player/vo/gign/onarollbrag04.wav");
    g_aMissionsSounds.PushString("player/vo/gign/onarollbrag05.wav");
    g_aMissionsSounds.PushString("player/vo/gign/onarollbrag06.wav");
    g_aMissionsSounds.PushString("player/vo/gign/onarollbrag07.wav");
    g_aMissionsSounds.PushString("player/vo/gign/onarollbrag08.wav");


    g_aMissionsSounds.PushString("player/vo/balkan/onarollbrag01.wav");
    g_aMissionsSounds.PushString("player/vo/balkan/onarollbrag03.wav");
    g_aMissionsSounds.PushString("player/vo/balkan/onarollbrag04.wav");
    g_aMissionsSounds.PushString("player/vo/balkan/onarollbrag05.wav");

    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag01.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag02.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag04.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag05.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag07.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag08.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag09.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag11.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag12.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag13.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag14.wav");
    g_aMissionsSounds.PushString("player/vo/anarchist/onarollbrag15.wav");
}