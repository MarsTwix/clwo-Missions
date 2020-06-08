#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <missions>

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
    MISSIONS_RegisterMission("Kill-Mission");
    HookEvent("grenade_thrown", Event_GrenadeThrown);
}

public Action Event_GrenadeThrown(Event event, const char[] name, bool dontBroadcast)
{
    
}