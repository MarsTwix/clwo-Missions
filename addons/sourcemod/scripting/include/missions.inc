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
native void MISSIONS_AddCoins(int client, int coins);

/**
* Remove coins to a coins (currentCoins-Coins).
*
* @param client             Client index.
* @param coins              Coins to remove.
*/
native void MISSIONS_RemoveCoins(int client, int coins);

/**
 * Sets the coins of a client.
 *
 * @param client            Client index.
 * @param karma             coins for the client.
 */
 native void MISSIONS_SetCoins(int client, int coins);