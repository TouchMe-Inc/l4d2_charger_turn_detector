#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>


public Plugin myinfo =
{
    name        = "Charger Turn Detector",
    author      = "TouchMe",
    description = "Detects unnatural turning of Charger during charge (anti-cheat)",
    version     = "build_0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_charger_turn_detector"
};


float g_fStartAngle[MAXPLAYERS + 1][3];
bool  g_bIsCharging[MAXPLAYERS + 1] = {false, ...};
int   g_iAnomalies[MAXPLAYERS + 1] = {0, ...};

ConVar g_cvThreshold = null;
ConVar g_cvKick = null;
ConVar g_cvKickCount = null;


public void OnPluginStart()
{
    g_cvThreshold = CreateConVar(
        "sm_charger_turn_threshold", "10.0",
        "Yaw deviation in degrees to consider anomalous",
        _, true, 1.0, true, 180.0
    );

    g_cvKick = CreateConVar(
        "sm_charger_turn_kick", "1",
        "Kick player after N anomalies. 0=Log only, 1=Kick.",
        _, true, 0.0, true, 1.0
    );

    g_cvKickCount = CreateConVar(
        "sm_charger_turn_kick_count", "5",
        "Anomalies count before kicking",
        _, true, 1.0, true, 100.0
    );

    HookEvent("charger_charge_start", Event_ChargeStart);
    HookEvent("charger_charge_end",   Event_ChargeEnd);
    HookEvent("player_death",         Event_PlayerDeath);
    HookEvent("player_spawn",         Event_PlayerSpawn);
}

public void OnClientDisconnect(int iClient)
{
    g_bIsCharging[iClient] = false;
    g_iAnomalies[iClient] = 0;
}

void Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(event.GetInt("userid"));
    if (iClient < 1 || !IsClientInGame(iClient)) {
        return;
    }

    g_bIsCharging[iClient] = true;
    g_iAnomalies[iClient] = 0;

    GetClientEyeAngles(iClient, g_fStartAngle[iClient]);
}

void Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(event.GetInt("userid"));
    if (iClient < 1) {
        return;
    }

    g_bIsCharging[iClient] = false;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(event.GetInt("userid"));
    if (iClient < 1) return;

    ResetClientState(iClient);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int iClient = GetClientOfUserId(event.GetInt("userid"));
    if (iClient < 1) return;

    ResetClientState(iClient);
}

public Action OnPlayerRunCmd(int iClient, int &buttons)
{
    if (!g_bIsCharging[iClient]) {
        return Plugin_Continue;
    }

    int iAbility = GetEntPropEnt(iClient, Prop_Send, "m_customAbility");
    if (iAbility == -1) {
        g_bIsCharging[iClient] = false;
        return Plugin_Continue;
    }

    if (GetEntProp(iAbility, Prop_Send, "m_isCharging", 1) <= 0) {
        g_bIsCharging[iClient] = false;
        return Plugin_Continue;
    }

    float vAng[3];
    GetClientEyeAngles(iClient, vAng);

    float fDeltaYaw = FloatAbs(vAng[1] - g_fStartAngle[iClient][1]);
    if (fDeltaYaw > 180.0) {
        fDeltaYaw = 360.0 - fDeltaYaw;
    }

    if (fDeltaYaw > g_cvThreshold.FloatValue)
    {
        g_iAnomalies[iClient]++;
        g_fStartAngle[iClient] = vAng;

        LogMessage("[ChargerTurn] %N turned %.1f° (anomaly %d/%d)",
            iClient, fDeltaYaw, g_iAnomalies[iClient], g_cvKickCount.IntValue);

        if (g_cvKick.BoolValue && g_iAnomalies[iClient] >= g_cvKickCount.IntValue)
        {
            if (!IsFakeClient(iClient))
            {
                LogAction(0, iClient, "[ChargerTurn] Kicking for %d anomalies", g_iAnomalies[iClient]);
                KickClient(iClient, "Charger turn detected");
            }

            ResetClientState(iClient);
        }
    }

    return Plugin_Continue;
}

void ResetClientState(int iClient)
{
    g_bIsCharging[iClient] = false;
    g_iAnomalies[iClient] = 0;
    g_fStartAngle[iClient][0] = 0.0;
    g_fStartAngle[iClient][1] = 0.0;
    g_fStartAngle[iClient][2] = 0.0;
}
