#if defined _missions_included
    #endinput
#endif
#define _missions_included


/**
* Add coins to a coins (currentCoins+Coins).
*
* @param client             Client index.
* @param coins              Coins that will be added.
*/
native void Missions_AddCoins(int client, int coins);

/**
* Remove coins to a coins (currentCoins-Coins).
*
* @param client             Client index.
* @param coins              Coins to remove.
*/
native void Missions_RemoveCoins(int client, int coins);

/**
 * Sets the coins of a client.
 *
 * @param client            Client index.
 * @param coins             coins for the client.
 */
 native void Missions_SetCoins(int client, int coins);

 /**
 * Registers the name of the mission in an array
 *
 * @param MissionName       The name of the mission.
 */
 native void Missions_RegisterMission(char[] MissionName);

 /**
 *Checks if the given name is in the array of missions names.
 *
 * @param MissionName       The name of the mission.
 */
 native bool Missions_IsValidMission(char[] MissionName);

 /**
 *Checks if the client has the given mission.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 */
 native bool Missions_IsValidClientMission(int client, char[] MissionName);

 /**
 *Returns the index of the given mission.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 */
 native int Missions_FindClientMission(int client, char[] MissionName);

 /**
 *Gives the given mission to a client.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 */
 native void Mission_GiveMission(int client, char[] MissionName);

/**
 *Removes the given mission of a client.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 */
 native void Mission_RemoveMission(int client, char[] MissionName);

 /**
 *Sets the Progression goal of the given mission of the client.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 * @param goal              The progression goal.
 */
 native void Missions_SetProgressionGoal(int client, char[] MissionName, int goal);

/**
 *Gets the Progression goal of the given mission of the client.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 * @param goal              The progression goal.
 */
 native int Missions_GetProgressionGoal(int client, char[] MissionName);

 /**
 *Adds a point to the progression.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 */
 native void Missions_AddProgression(int client, char[] MissionName);
 
 /**
 *Checks if the client has completed the given mission.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 */
 native bool Mission_HasCompleted(int client, char[] MissionName);
 
 /**
 *Checks if the client has completed the given mission.
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 * @param Coins             The amount of coins.
 */
 native void Mission_RewardOnCompletion(int client, char[] MissionName, int coins);

 /**
 *Gets called when A mission has been given to a client
 *
 * @param client            Client index.
 * @param MissionName       The name of the mission.
 * @param index             The index where the mission is placed.
 */         
 forward void Missions_OnGivenMission(int client, char[] MissionName, int index);