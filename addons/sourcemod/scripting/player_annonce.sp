#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <steamworks>
#include <geoip>
#include <colors>


public Plugin myinfo = {
	name = "PlayerAnnonce",
	author = "TouchMe",
	description = "Plugin displays information about players (Country, lerp, hours)",
	version = "build_0001",
	url = "https://github.com/TouchMe-Inc/l4d2_player_annonce"
};


#define TRANSLATIONS            "player_annonce.phrases"
#define APP_L4D2                550


ConVar
	g_cvMinUpdateRate = null,
	g_cvMaxUpdateRate = null,
	g_cvMinInterpRatio = null,
	g_cvMaxInterpRatio = null
;

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

	g_cvMinUpdateRate = FindConVar("sv_minupdaterate");
	g_cvMaxUpdateRate = FindConVar("sv_maxupdaterate");
	g_cvMinInterpRatio = FindConVar("sv_client_min_interp_ratio");
	g_cvMaxInterpRatio = FindConVar("sv_client_max_interp_ratio");
}

public void SteamWorks_OnValidateClient(int iOwnAuthId, int iAuthId)
{
	int iClient = GetClientFromSteamID(iAuthId);

	if (iClient > 0) {
		SteamWorks_RequestStats(iClient, APP_L4D2);
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
		return;
	}

	SteamWorks_RequestStats(iClient, APP_L4D2);

	char sIp[16], sName[32], sCountry[32], sCity[32];

	FormatEx(sName, sizeof(sName), "%N", iClient);
	GetClientIP(iClient, sIp, sizeof(sIp));
	int iPlayedTime = 0;
	float fLerpTime = GetLerpTime(iClient) * 1000;

	if (SteamWorks_IsConnected()) {
		SteamWorks_GetStatCell(iClient, "Stat.TotalPlayTime.Total", iPlayedTime);
	}

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

	CPrintToChatAll("%t", "PLAYER_CONNECTED", sName, sCountry, sCity, fLerpTime, SecToHours(iPlayedTime));
}

float GetLerpTime(int iClient)
{
	char buffer[32];
	float fLerpRatio, fLerpAmount, fUpdateRate;

	if (GetClientInfo(iClient, "cl_interp_ratio", buffer, sizeof(buffer))) {
		fLerpRatio = StringToFloat(buffer);
	}

	if (g_cvMinInterpRatio != null && g_cvMaxInterpRatio != null && GetConVarFloat(g_cvMinInterpRatio) != -1.0) {
		fLerpRatio = clamp(fLerpRatio, GetConVarFloat(g_cvMinInterpRatio), GetConVarFloat(g_cvMaxInterpRatio));
	}

	if (GetClientInfo(iClient, "cl_interp", buffer, sizeof(buffer))) {
		fLerpAmount = StringToFloat(buffer);
	}

	if (GetClientInfo(iClient, "cl_updaterate", buffer, sizeof(buffer))) {
		fUpdateRate = StringToFloat(buffer);
	}

	fUpdateRate = clamp(fUpdateRate, GetConVarFloat(g_cvMinUpdateRate), GetConVarFloat(g_cvMaxUpdateRate));

	return max(fLerpAmount, fLerpRatio / fUpdateRate);
}

bool IsLanIP(char src[16])
{
	char ip4[4][4];
	int ipnum;

	if (ExplodeString(src, ".", ip4, 4, 4) == 4)
	{
		ipnum = StringToInt(ip4[0]) * 65536 + StringToInt(ip4[1]) * 256 + StringToInt(ip4[2]);

		if((ipnum >= 655360 && ipnum < 655360+65535) || (ipnum >= 11276288 && ipnum < 11276288+4095) || (ipnum >= 12625920 && ipnum < 12625920+255))
		{
			return true;
		}
	}

	return false;
}

int GetClientFromSteamID(int iAuthId)
{
	for (int iClient = 1; iClient <= MaxClients; iClient ++)
	{
		if (!IsClientConnected(iClient)) {
			continue;
		}

		int iSteamAccountId = GetSteamAccountID(iClient);

		if (iSteamAccountId && iSteamAccountId == iAuthId) {
			return iClient;
		}
	}

	return 0;
}

float SecToHours(int iSeconds) {
	return float(iSeconds) / 3600.0;
}

float max(float a, float b) {
	return (a > b) ? a : b;
}

float clamp(float inc, float low, float high) {
	return (inc > high) ? high : ((inc < low) ? low : inc);
}
