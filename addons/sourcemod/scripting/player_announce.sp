#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <steamworks>
#include <geoip>
#include <colors>


public Plugin myinfo = {
    name        = "PlayerAnnounce",
    author      = "TouchMe",
    description = "Displays information about connecting/disconnecting players",
    version     = "build_0004",
    url         = "https://github.com/TouchMe-Inc/l4d2_player_announce"
};


#define TRANSLATIONS            "player_announce.phrases"
#define APP_L4D2                550


static const char g_szTeamColor[][] = {
    "{olive}",
    "{olive}",
    "{blue}",
    "{red}"
};


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
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);
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

public void Event_PlayerTeam(Event event, const char[] sEventName, bool bDontBroadcast)
{
    if (GetEventInt(event, "disconnect")) {
        return;
    }

    if (GetEventInt(event, "oldteam")) {
        return;
    }

    int iClientId = GetEventInt(event, "userid");

    RequestFrame(Frame_ClientInGame, iClientId);
}

public void Frame_ClientInGame(int iClientId)
{
    int iClient = GetClientOfUserId(iClientId);

    if (iClient <= 0 || IsFakeClient(iClient)) {
        return;
    }

    int iTeam = GetClientTeam(iClient);

    char sName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, sName, sizeof(sName), 18);

    char sIp[16];
    GetClientIP(iClient, sIp, sizeof(sIp));

    char szGeoData[64];
    if (!IsLanIP(sIp))
    {
        char sCountry[32];
        if (GeoipCountryEx(sIp, sCountry, sizeof(sCountry), LANG_SERVER))
        {
            char sCity[32];
            if (GeoipCity(sIp, sCity, sizeof(sCity), LANG_SERVER)) {
                FormatEx(szGeoData, sizeof(szGeoData), "%T", "COUNTRY_AND_CITY", LANG_SERVER, sCountry, sCity);
            } else {
                FormatEx(szGeoData, sizeof(szGeoData), "%T", "ONLY_COUNTRY", LANG_SERVER, sCountry);
            }
        }
        else
        {
            FormatEx(szGeoData, sizeof(szGeoData), "%T", "UNKNOWN_COUNTRY", LANG_SERVER);
        }
    }
    else
    {
        FormatEx(szGeoData, sizeof(szGeoData), "%T", "LAN", LANG_SERVER);
    }

    int iClientHours = GetClientHours(iClient);

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer)) {
            continue;
        }

        CPrintToChat(iPlayer, "%T", "PLAYER_CONNECTED", iPlayer, g_szTeamColor[iTeam], sName, szGeoData, iClientHours);
    }
}

void Event_PlayerDisconnect(Event event, const char[] sEventName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (!iClient || IsFakeClient(iClient)) {
        return;
    }

    SetEventBroadcast(event, true);

    int iTeam = GetClientTeam(iClient);

    char szClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szClientName, sizeof(szClientName), 18);

    char szReason[128];
    GetEventString(event, "reason", szReason, sizeof(szReason));

    if (strcmp(szReason, "Disconnect by user.") == 0) {
        CPrintToChatAll("%t", "PLAYER_DISCONNECTED", g_szTeamColor[iTeam], szClientName);
    } else {
        CPrintToChatAll("%t", "PLAYER_DISCONNECTED_WITH_REASON", g_szTeamColor[iTeam], szClientName, szReason);
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
int GetClientHours(int iClient)
{
    int iPlayedTime = 0;

    if (!SteamWorks_GetStatCell(iClient, "Stat.TotalPlayTime.Total", iPlayedTime)) {
        return 0;
    }

    return RoundToFloor(float(iPlayedTime) / 3600.0);
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
