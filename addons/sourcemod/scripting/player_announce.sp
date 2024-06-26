#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <steamworks>
#include <geoip>
#include <colors>


public Plugin myinfo = {
	name = "PlayerAnnounce",
	author = "TouchMe",
	description = "Displays information about connecting/disconnecting players",
	version = "build_0002",
	url = "https://github.com/TouchMe-Inc/l4d2_player_announce"
};


#define TRANSLATIONS            "player_announce.phrases"
#define APP_L4D2                550


/**
  * Called before OnPluginStart.
  */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations(TRANSLATIONS);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnClientAuthorized(int iClient, const char[] sAuthId)
{
	if (sAuthId[0] == 'B' || sAuthId[9] == 'L') {
		return;
	}

	SteamWorks_RequestStats(iClient, APP_L4D2);
}

public void OnClientConnected(int iClient)
{
	if (IsFakeClient(iClient)) {
		return;
	}

	char sName[MAX_NAME_LENGTH];

	GetClientNameFixed(iClient, sName, sizeof(sName), 18);

	CPrintToChatAll("%t", "PLAYER_CONNECTING", sName);
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
		return;
	}

	char sIp[16], sName[MAX_NAME_LENGTH], sCountry[32], sCity[32];

	GetClientNameFixed(iClient, sName, sizeof(sName), 18);
	GetClientIP(iClient, sIp, sizeof(sIp));

	if (IsLanIP(sIp))
	{
		FormatEx(sCountry, sizeof(sCountry), "%T", "LAN_COUNTRY", iClient);
		FormatEx(sCity, sizeof(sCity), "%T", "LAN_CITY", iClient);
	}
	else
	{
		if (!GeoipCountry(sIp, sCountry, sizeof(sCountry))) {
			FormatEx(sCountry, sizeof(sCountry), "%T", "UNKNOWN_COUNTRY", iClient);
		}

		if (!GeoipCity(sIp, sCity, sizeof(sCity))) {
			FormatEx(sCity, sizeof(sCity), "%T", "UNKNOWN_CITY", iClient);
		}
	}

	CPrintToChatAll("%t", "PLAYER_CONNECTED", sName, sCountry, sCity, GetClientHours(iClient));
}

void Event_PlayerDisconnect(Event event, const char[] sEventName, bool bDontBroadcast)
{
	int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!iClient || IsFakeClient(iClient)) {
		return;
	}

	SetEventBroadcast(event, true);

	char sName[MAX_NAME_LENGTH];
	GetClientNameFixed(iClient, sName, sizeof(sName), 18);

	char sReason[128];
	GetEventString(event, "reason", sReason, sizeof(sReason));

	if (strcmp(sReason, "Disconnect by user.") == 0) {
		CPrintToChatAll("%t", "PLAYER_DISCONNECTED", sName);
	} else {
		CPrintToChatAll("%t", "PLAYER_DISCONNECTED_WITH_REASON", sName, sReason);
	}
}

bool IsLanIP(char ip[16])
{
	char ip4[4][4];

	if (ExplodeString(ip, ".", ip4, 4, 4) == 4)
	{
		int ipnum = StringToInt(ip4[0]) * 65536 + StringToInt(ip4[1]) * 256 + StringToInt(ip4[2]);

		if((ipnum >= 655360 && ipnum < 655360+65535)
		|| (ipnum >= 11276288 && ipnum < 11276288+4095)
		|| (ipnum >= 12625920 && ipnum < 12625920+255))
		{
			return true;
		}
	}

	return false;
}

/**
 * Returns the hours played by the player from steam statistics.
 */
float GetClientHours(int iClient)
{
	int iPlayedTime = 0;

	if (!SteamWorks_GetStatCell(iClient, "Stat.TotalPlayTime.Total", iPlayedTime)) {
		return 0.0;
	}

	return float(iPlayedTime) / 3600.0;
}

/**
 *
 */
void GetClientNameFixed(int iClient, char[] name, int length, int iMaxSize)
{
	GetClientName(iClient, name, length);

	if (strlen(name) > iMaxSize)
	{
		name[iMaxSize - 3] = name[iMaxSize - 2] = name[iMaxSize - 1] = '.';
		name[iMaxSize] = '\0';
	}
}
