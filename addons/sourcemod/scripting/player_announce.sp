#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <colors>
#include <steamworks>


public Plugin myinfo = {
    name        = "PlayerAnnounce",
    author      = "TouchMe",
    description = "Displays information about connecting/disconnecting players and lost/resotre connection",
    version     = "build_0008",
    url         = "https://github.com/TouchMe-Inc/l4d2_player_announce"
};


/*
 * Filenames.
 */
#define TRANSLATIONS            "player_announce.phrases"

/*
 * Steamworks const.
 */
#define APP_L4D2                550

#define MAX_SHOTR_NAME_LENGTH   21
#define MAX_IP_LENGTH           16

#define TEAM_SPECTATOR          1

int g_iResourceEntity = -1;

bool g_bClientLostConnection[MAXPLAYERS + 1] = {false, ...};
bool g_bClientPrint[MAXPLAYERS + 1] = {false, ...};

static const char g_szTeamColor[][] = {
    "{lightgreen}",
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

/**
 * Finding Resource Entity.
 */
public void OnMapStart() {
	g_iResourceEntity = GetResourceEntity();
}

Action Timer_CheckTimingOut(Handle hTimer)
{
    static char szClientName[MAX_NAME_LENGTH];

    for (int iClient = 1; iClient <= MaxClients; iClient++)
    {
        if (!IsClientInGame(iClient) || IsFakeClient(iClient)) {
            continue;
        }

        int iClientTeam = GetClientTeam(iClient);

        if (iClientTeam <= TEAM_SPECTATOR) {
            continue;
        }

        if (g_bClientLostConnection[iClient] && !IsClientTimingOut(iClient))
        {
            GetClientNameFixed(iClient, szClientName, sizeof(szClientName), MAX_SHOTR_NAME_LENGTH);
            CPrintToChatAll("%t", "PLAYER_CONNECTION_RESTORE", g_szTeamColor[iClientTeam], szClientName);
            g_bClientLostConnection[iClient] = false;
        }

        else if (!g_bClientLostConnection[iClient] && IsClientTimingOut(iClient))
        {
            GetClientNameFixed(iClient, szClientName, sizeof(szClientName), MAX_SHOTR_NAME_LENGTH);
            CPrintToChatAll("%t", "PLAYER_CONNECTION_LOST", g_szTeamColor[iClientTeam], szClientName);
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

    g_bClientLostConnection[iClient] = false;
    g_bClientPrint[iClient] = false;

    char szClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szClientName, sizeof(szClientName), MAX_SHOTR_NAME_LENGTH);

    CPrintToChatAll("%t", "PLAYER_CONNECTING", szClientName);
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

    if (iClient <= 0 || g_bClientPrint[iClient] || !IsClientInGame(iClient) || IsFakeClient(iClient)) {
        return Plugin_Stop;
    }

    int iClientTeam = GetClientTeam(iClient);

    char szClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szClientName, sizeof szClientName, MAX_SHOTR_NAME_LENGTH);

    char szClientIp[MAX_IP_LENGTH];
    GetClientIP(iClient, szClientIp, sizeof szClientIp);

    char szGeoData[64];
    if (!IsLanIP(szClientIp))
    {
        char szCountry[32];
        if (GeoipCountryEx(szClientIp, szCountry, sizeof szCountry, LANG_SERVER))
        {
            char szCity[32];
            if (GeoipCity(szClientIp, szCity, sizeof szCity, LANG_SERVER)) {
                FormatEx(szGeoData, sizeof szGeoData, "%T", "COUNTRY_AND_CITY", LANG_SERVER, szCountry, szCity);
            } else {
                FormatEx(szGeoData, sizeof szGeoData, "%T", "ONLY_COUNTRY", LANG_SERVER, szCountry);
            }
        }
        else
        {
            FormatEx(szGeoData, sizeof szGeoData, "%T", "UNKNOWN_COUNTRY", LANG_SERVER);
        }
    }
    else
    {
        FormatEx(szGeoData, sizeof szGeoData, "%T", "LAN", LANG_SERVER);
    }

    CPrintToChatAll("%t", "PLAYER_CONNECTED", g_szTeamColor[iClientTeam], szClientName, szGeoData, GetClientHours(iClient));

    g_bClientPrint[iClient] = true;

    return Plugin_Stop;
}

void Event_PlayerDisconnect(Event event, const char[] sEventName, bool bDontBroadcast)
{
    int iClient = GetClientOfUserId(GetEventInt(event, "userid"));

    if (iClient <= 0 || IsFakeClient(iClient)) {
        return;
    }

    SetEventBroadcast(event, true);

    int iClientTeam = IsClientInGame(iClient) ? GetClientTeam(iClient) : GetClientLastTeam(iClient);

    char szClientName[MAX_NAME_LENGTH];
    GetClientNameFixed(iClient, szClientName, sizeof szClientName, MAX_SHOTR_NAME_LENGTH);

    char szReason[192];
    GetEventString(event, "reason", szReason, sizeof szReason);

    if (strcmp(szReason, "Disconnect by user.") == 0) {
        CPrintToChatAll("%t", "PLAYER_DISCONNECTED", g_szTeamColor[iClientTeam], szClientName);
    } else {
        CPrintToChatAll("%t", "PLAYER_DISCONNECTED_WITH_REASON", g_szTeamColor[iClientTeam], szClientName, szReason);
    }

    g_bClientLostConnection[iClient] = false;
}

bool IsLanIP(const char ip[16])
{
    char ip4[4][4];
    if (ExplodeString(ip, ".", ip4, sizeof ip4, sizeof ip4[]) != 4) {
        return false;
    }

    int a = StringToInt(ip4[0]);
    int b = StringToInt(ip4[1]);

    if ((a == 10)
     || (a == 172 && b >= 16 && b <= 31)
     || (a == 192 && b == 168))
        return true;

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

/**
 * Get player's previous team.
 */
int GetClientLastTeam(int iClient) {
	return GetEntProp(g_iResourceEntity, Prop_Send, "m_iTeam", .element = iClient);
}

int GetResourceEntity() {
	return FindEntityByClassname(-1, "terror_player_manager");
}
