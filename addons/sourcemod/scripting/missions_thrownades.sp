#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <missions>

#define Mission_Name "ThrowNades"
#define CoinsPerNade 10

public Plugin myinfo =
{
    name = "ThrowNade-Mission",
    author = "MarsTwix",
    description = "A mission that requires you to throw nades",
    version = "1.0.0",
    url = "clwo.eu"
};

public void OnPluginStart()
{
    Missions_RegisterMission(Mission_Name);
    HookEvent("grenade_thrown", Event_GrenadeThrown);
}

public void Missions_OnGivenMission(int client, char[] MissionName, int index)
{
    if (StrEqual(Mission_Name, MissionName, false))
    {
        int RandomNum = GetRandomInt(4, 6);
        Missions_SetProgressionGoal(client, MissionName, RandomNum);
    }
}

public Action Event_GrenadeThrown(Event event, const char[] name, bool dontBroadcast)
{
    int clientId = event.GetInt("userid");
    int client = GetClientOfUserId(clientId);
    if (Missions_IsValidClientMission(client, Mission_Name))
    {
        if (!Missions_HasCompleted(client, Mission_Name))
        {
            Missions_AddProgression(client, Mission_Name);
            if (Missions_HasCompleted(client, Mission_Name))
            {
                int goal = Missions_GetProgressionGoal(client, Mission_Name);
                int coins = CoinsPerNade * goal;
                Missions_RewardOnCompletion(client, Mission_Name, coins);
            }
        }
    }
}