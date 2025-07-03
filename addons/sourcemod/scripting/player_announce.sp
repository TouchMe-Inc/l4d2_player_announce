#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <steamworks>
#include <geoip>
#include <colors>


public Plugin myinfo = {
    name        = "PlayerAnnounce",
    author      = "TouchMe",
    description = "Displays information about connecting/disconnecting players and lost/resotre connection",
    version     = "build_0006",
    url         = "https://github.com/TouchMe-Inc/l4d2_player_announce"
};


#define TRANSLATIONS            "player_announce.phrases"
#define APP_L4D2                550

#define MAX_SHOTR_NAME_LENGTH   18

bool g_bClientLostConnection[MAXPLAYERS + 1] = {false, ...};

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

    CreateTimer(0.5, Timer_CheckTimingOut, .flags = TIMER_REPEAT);
}

Action Timer_CheckTimingOut(Handle hTimer)
{
    static char sClientName[MAX_NAME_LENGTH];

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
            continue;
        }

        int iClientTeam = GetClientTeam(iClient);

        if (!iClientTeam) {
            continue;
        }

        if (g_bClientLostConnection[iClient] && !IsClientTimingOut(iClient))
        {
            GetClientNameFixed(iClient, sClientName, sizeof(sClientName), MAX_SHOTR_NAME_LENGTH);
            CPrintToChatAll("%t", "PLAYER_CONNECTION_RESTORE", g_szTeamColor[iClientTeam], sClientName);
            g_bClientLostConnection[iClient] = false;
        }

        else if (!g_bClientLostConnection[iClient] && IsClientTimingOut(iClient))
        {
            GetClientNameFixed(iClient, sClientName, sizeof(sClientName), MAX_SHOTR_NAME_LENGTH);
            CPrintToChatAll("%t", "PLAYER_CONNECTION_LOST", g_szTeamColor[iClientTeam], sClientName);
            g_bClientLostConnection[iClient] = true;
        }
    }
    
    return Plugin_Continue;
}

public void OnClientConnected(int iClient)
{
    if (IsFakeClient(iClient)) {
        return;
    }

    SteamWorks_RequestStats(iClient, APP_L4D2);

    char sClientName[MAX_NAME_LENGTH];

    GetClientNameFixed(iClient, sClientName, sizeof(sClientName), MAX_SHOTR_NAME_LENGTH);

    CPrintToChatAll("%t", "PLAYER_CONNECTING", sClientName);

    g_bClientLostConnection[iClient] = false;
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

    CreateTimer(1.0, Timer_ClientInGame, iClientId, TIMER_FLAG_NO_MAPCHANGE);
}

Action Timer_ClientInGame(Handle hTimer, int iClientId)
{
    int iClient = GetClientOfUserId(iClientId);

    if (iClient <= 0 || !IsClientInGame(iClient) || IsFakeClient(iClient)) {
        return Plugin_Stop;
    }

    int iClientTeam = GetClientTeam(iClient);

    char sClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, sClientName, sizeof(sClientName), MAX_SHOTR_NAME_LENGTH);

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

    CPrintToChatAll("%t", "PLAYER_CONNECTED", g_szTeamColor[iClientTeam], sClientName, szGeoData, GetClientHours(iClient));

    return Plugin_Stop;
}

void Event_PlayerDisconnect(Event event, const char[] sEventName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (iClient <= 0 || IsFakeClient(iClient)) {
        return;
    }

    SetEventBroadcast(event, true);

    int iClientTeam = IsClientInGame(iClient) ? GetClientTeam(iClient) : 0;

    char szClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szClientName, sizeof(szClientName), MAX_SHOTR_NAME_LENGTH);

    char szReason[128];
    GetEventString(event, "reason", szReason, sizeof(szReason));

    if (strcmp(szReason, "Disconnect by user.") == 0) {
        CPrintToChatAll("%t", "PLAYER_DISCONNECTED", g_szTeamColor[iClientTeam], szClientName);
    } else {
        CPrintToChatAll("%t", "PLAYER_DISCONNECTED_WITH_REASON", g_szTeamColor[iClientTeam], szClientName, szReason);
    }

    g_bClientLostConnection[iClient] = false;
}

bool IsLanIP(char ip[16])
{
    char ip4[4][4];

    if (ExplodeString(ip, ".", ip4, 4, 4) == 4)
    {
        int ipnum = StringToInt(ip4[0]) * 65536 + StringToInt(ip4[1]) * 256 + StringToInt(ip4[2]);

        if ((ipnum >= 655360 && ipnum < 655360+65535)
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
 * Retrieves a player's name and safely truncates it if necessary.
 *
 * Copies the client's name into the specified buffer. If the name exceeds
 * the given maximum display size (iMaxSize), it is truncated and replaced
 * with an ellipsis ("...") at the end.
 *
 * This is useful for ensuring that player names fit within UI or HUD
 * constraints while preserving readability.
 *
 * @param iClient     Client index.
 * @param szName      Destination buffer to store the player's name.
 * @param iLength      Maximum size of the destination buffer.
 * @param iMaxSize    Maximum allowed length for display (excluding null terminator).
 */
void GetClientNameFixed(int iClient, char[] szName, int iLength, int iMaxSize)
{
    GetClientName(iClient, szName, iLength);

    if (strlen(szName) > iMaxSize)
    {
        szName[iMaxSize - 3] = szName[iMaxSize - 2] = szName[iMaxSize - 1] = '.';
        szName[iMaxSize] = '\0';
    }
}
