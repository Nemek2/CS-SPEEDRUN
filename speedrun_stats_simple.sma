#include <amxmodx>
#include <amxmisc>
#include <fun>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <sqlx>
#include <speedrun>


new const	PluginAuthor 	[] = "IceBeam / SQN, Mistrick, R3X"

new const PREFIX[] = "^4[Speedrun]";

#define    FL_WATERJUMP    (1<<11)
#define    FL_ONGROUND    (1<<9)

#define TaskID 3456
#define DeadID 3356

const Float:CO_ILE = 0.1;

#define MAX_STRAFES 2000
#define MAX_PLAYERS 32

forward SR_ChangedCategory(id);
native get_user_save(id);

enum _:Categories
{
	
	Cat_60fps = 0,  
        Cat_100fps,
	Cat_200fps,
	Cat_250fps,
	Cat_333fps,
	Cat_500fps,
        Cat_1000fps,         
	Cat_CS,
	Cat_HCS,
        Cat_MCS,
	Cat_2kRun,
	Cat_3kRun,
	Cat_4kRun,
	Cat_5kRun,
        Cat_Strafespeed,
	Cat_Gravity,
	Cat_Legit, 
        Cat_DoubleJump,     
};

new const szSounds[][] = {
	"sound/utwory/utwor0.mp3",  
        "sound/utwory/utwor1.mp3",
        "sound/utwory/utwor2.mp3", 
        "sound/utwory/utwor3.mp3",   
        "sound/utwory/utwor4.mp3",  
}

new const DATABASE[] = "addons/amxmodx/data/speedrun_stats.db";

new const g_szCategory[][] = { "60 FPS", "100 FPS", "200 FPS", "250 FPS", "333 FPS", "500 FPS", "1000 FPS", "Crazy Speed", "Hard Crazy Speed", "MEGA Crazy Speed", "2k Run", "3k Run", "4k Run", "5k Run", "Strafes Speed", "Low Gravity", "Legit", "DoubleJump"};
 
new Handle:g_hTuple, g_szQuery[512];
new g_szMapName[32];
new g_iMapIndex;
new g_iBestTime[33][Categories];
new g_iBestTimeofMap[Categories];
new g_iBestJumps[33][Categories];
new g_iBestStrafes[33][Categories];
new g_iBestSpeeds[33][Categories];
new g_iPlayerFinished;
new g_iReturn;

new m_iPlayerIndex[33];
new m_iPlayerAuthorized[33];
new m_iPlayerConnected[33];

new Float:m_iStarted[33];
new bool:m_iFinished[33];
new m_iTimerStarted[33];
new m_iJumpCount[33];
new m_iStrafeCount[33];
new bool:m_iSpeed[33];
new m_CheckButton[33];

new m_LastTime[33];
new Float:m_LastInfo[33];

new bool:g_bStrafingAw[33], bool:g_bStrafingSd[33], bool:g_bTurningLeft[33], bool:g_bTurningRight[33];
new Float:g_fMaxSpeed[33], Float:g_fOldAngles[33], Float:g_fOldSpeed[33]
new g_iGoodSync[33], g_iSyncFrames[33]
new g_iStrafeFrames[33][MAX_STRAFES], g_iStrafeGoodSync[33][MAX_STRAFES];
//new Float: m_iSpeed[MAX_PLAYERS+1];  


new g_SpeedrunTop;
new g_DetailedTop;
new HudObj;
//new g_iSyncHudSpeed;

new bool: m_insidePlayer[33];

 
new lt_block[33];
new bool: inv_TimerStatus[33],velocity[33],
strafes[33],jumps[33],cat[33];
         



public plugin_init() 
{
	register_plugin("Speedrun - Stats", "0.4", PluginAuthor)

       // UTIL_CheckServerLicense( "91.224.117.42", 0 );     

	register_saycmd("top", "Command_Top15", -1, "")
	register_saycmd("top15", "Command_Top15", -1, "")

        register_clcmd("say /timer", "Command_Timer");

        register_clcmd("say /speed", "Command_Speed");
      
        register_clcmd("show", "ShowMenu");
        register_clcmd("say /show", "ShowMenu");

        
	register_saycmd("rank", "Command_Rank", -1, "")
	
	register_saycmd("nick", "Command_Update", -1, "")
	register_saycmd("update", "Command_Update", -1, "")
	register_saycmd("updatenickname", "Command_Update", -1, "")

	RegisterHam(Ham_Spawn, "player", "CBasePlayer_Spawn");

	register_forward(FM_PlayerPreThink, "CBasePlayer_PreThink");
	register_forward(FM_PlayerPreThink, "CBasePlayer_StartTimer");
	register_forward(FM_CmdStart, "CBasePlayer_JumpCount");

        HudObj = CreateHudSyncObj();
        //g_iSyncHudSpeed = CreateHudSyncObj();
	
	register_forward(FM_PlayerPostThink, "SRPlayer_Strafecount", 0);
        register_forward(FM_PlayerPreThink, "Fw_PlayerPreThink") 
   
        RegisterHam(Ham_Killed, "player", "EvPlayerKilled", 1); 


	g_iPlayerFinished = CreateMultiForward("SR_PlayerFinished", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);

	
	SQL_Init();	
}

public plugin_precache() 
{  	
	for(new i=0; i<sizeof(szSounds); i++)
	{
		precache_generic(szSounds[i]);
		{
			
		}
	}   
}

SQL_Init() {
	SQL_SetAffinity("sqlite");
	
	if(!file_exists(DATABASE)) 
	{
		new file = fopen(DATABASE, "w");
		if(!file)
		{
			new szMsg[128]; formatex(szMsg, charsmax(szMsg), "%s file not found and cant be created.", DATABASE);
			set_fail_state(szMsg);
		}
		fclose(file);
	}
	
	g_hTuple = SQL_MakeDbTuple("", "", "", DATABASE, 0);
	
	formatex(g_szQuery, charsmax(g_szQuery),
			"CREATE TABLE IF NOT EXISTS `runners`( \
			id 		INTEGER		PRIMARY KEY,\
			steamid		TEXT 	NOT NULL, \
			nickname	TEXT 	NOT NULL, \
			ip		TEXT 	NOT NULL)")
	
	SQL_ThreadQuery(g_hTuple, "Query_IngnoredHandle", g_szQuery);
	
	formatex(g_szQuery, charsmax(g_szQuery),
			"CREATE TABLE IF NOT EXISTS `maps`( \
			mid 		INTEGER		PRIMARY KEY,\
			mapname		TEXT 		NOT NULL	UNIQUE)")
	
	SQL_ThreadQuery(g_hTuple, "Query_IngnoredHandle", g_szQuery);
	
	formatex(g_szQuery, charsmax(g_szQuery),
			"CREATE TABLE IF NOT EXISTS `results`( \
			id			INTEGER 	NOT NULL, \
			mid 		INTEGER 	NOT NULL, \
			category	INTEGER 	NOT NULL, \
			besttime	INTEGER 	NOT NULL, \
			bestjumps	INTEGER 	NOT NULL, \
                        beststrafes     INTEGER         NOT NULL, \
                        bestspeeds      INTEGER         NOT NULL, \
			recorddate	DATETIME	NULL, \
			FOREIGN KEY(id) REFERENCES `runners`(id) ON DELETE CASCADE, \
			FOREIGN KEY(mid) REFERENCES `maps`(mid) ON DELETE CASCADE, \
			PRIMARY KEY(id, mid, category))");
	
	SQL_ThreadQuery(g_hTuple, "Query_IngnoredHandle", g_szQuery);
	
	set_task(1.0, "DelayedLoadMapInfo");
}
public DelayedLoadMapInfo() 
{
	get_mapname(g_szMapName, charsmax(g_szMapName));
	formatex(g_szQuery, charsmax(g_szQuery), "SELECT mid FROM `maps` WHERE mapname='%s'", g_szMapName);
	SQL_ThreadQuery(g_hTuple, "Query_LoadMapHandle", g_szQuery);
}
public Query_LoadMapHandle(failstate, Handle:query, error[], errnum, data[], size) 
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("SQL error[LoadMapHandle]: %s", error); return;
	}
	
	if(SQL_MoreResults(query))
	{
		g_iMapIndex = SQL_ReadResult(query, 0);
	}
	else
	{		
		formatex(g_szQuery, charsmax(g_szQuery), "INSERT INTO `maps`(mapname) VALUES ('%s')", g_szMapName);
		SQL_ThreadQuery(g_hTuple, "Query_IngnoredHandle", g_szQuery);
		
		formatex(g_szQuery, charsmax(g_szQuery), "SELECT mid FROM `maps` WHERE mapname='%s'", g_szMapName);
		SQL_ThreadQuery(g_hTuple, "Query_LoadMapHandle", g_szQuery);
	}

	if(g_iMapIndex)
	{
		for(new i = 1; i <= 32; i++)
		{
			if(m_iPlayerConnected[i]) ClientAuthorization(i);
		}
		
		for(new i; i < Categories; i++)
		{
			ShowTop15(0, i);
		}
	}
}
public Query_IngnoredHandle(failstate, Handle:query, error[], errnum, data[], size) 
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("SQL error[IngnoredHandle]: %s", error); return;
	}
}

public client_connect(id) 
{
	m_iPlayerAuthorized[id] = false;
	m_iFinished[id] = false;
	m_iTimerStarted[id] = false;
	m_iPlayerIndex[id] = 0;
	m_LastTime[id] = 0;
	m_CheckButton[id] = 0;
	m_iJumpCount[id] = 0;
	m_iStrafeCount[id] = 0;
}

public client_putinserver(id) 
{
	if(!is_user_bot(id) && !is_user_hltv(id))
	{
		m_iPlayerConnected[id] = true;
		ClientAuthorization(id);
                m_insidePlayer[id] = true;
                inv_TimerStatus[id] = true;
                velocity[id] = true;
                cat[id] = true;
     
	}
}

public client_authorized(id){ 
          
      // set_task(0.1, "Task_ShowSpeed", id+TASK_SHOWSPEED, .flags = "b"); 

}

public CBasePlayer_JumpCount(id, uc_handle)
{
	static button,flags
        button = get_uc(uc_handle,UC_Buttons)
        flags = pev(id, pev_flags)
    
        if(m_insidePlayer[id] == false && button & IN_JUMP) {
               if(flags & FL_ONGROUND) {
                                if(lt_block[id]){
                       m_iJumpCount[id]++;
                       lt_block[id] = 0;
                                }
           }
                   else lt_block[id] = 1;
       }
}

public CBasePlayer_Spawn(id) 
{
	if(!is_user_alive(id)) return;

	m_iTimerStarted[id] = false;
	m_iFinished[id] = false;
	m_iStarted[id] = -1.0;
	m_iJumpCount[id] = 0;
	m_iStrafeCount[id] = 0;
	m_CheckButton[id] = 0;
        m_insidePlayer[id] = true;
	
	hide_timer(id);
}
 
 
public plugin_natives() {
        
        register_native("cmd_timer", "Command_Timer",1);
        register_native("native_set_timer", "native_set_timer",1);
        register_native("native_get_timer", "native_get_timer",1);
        register_native("get_user_wr", "_get_user_wr", 1);
        register_native("native_set_speed", "native_set_speed", 1);
        register_native("native_get_speed", "native_get_speed", 1);
         
   
       // register_native("get_user_pb", "_get_user_pb", 1);
       // register_native("start_timer", "_start_timer", 1);
       // register_native("stop_timer", "_stop_timer", 1);  
} 
   
public native_set_timer(id, jaki, bool:co){
        switch(jaki){
                case 0: inv_TimerStatus[id] = co; 
        }
}
public native_get_timer(id, jaki){
        switch(jaki){
                case 0: return inv_TimerStatus[id];
        }
        return 0;
}
 
public native_set_speed(id, jaki, bool:co){
        switch(jaki){
                
                case 0: velocity[id] = co;
        }
}
public native_get_speed(id, jaki){
        switch(jaki){
                case 0: return velocity[id];
        }
        return 0;
}

public _get_user_wr(id, category) 
{
	category = get_user_category(id);
	return g_iBestTimeofMap[category];
}
/*
public _get_user_pb(id, category) 
{
	category = get_user_category(id);
	return g_iBestTimeofMap[category];
}
public _start_timer(id)
{
	   	m_iStarted[id] = get_gametime();
}
public _stop_timer(id)
{
	m_iStarted[id] = -1.0;
}
*/
public CBasePlayer_PreThink(id)
{
	static Float:fNow;

	if(!is_user_alive(id) || m_iStarted[id]  <= 0.0)
	return FMRES_IGNORED;
		
	if(!m_iFinished[id]) 
	{
		fNow = get_gametime();
		
		if((fNow-m_LastInfo[id]) <= 0.5) return FMRES_IGNORED;

		
		display_time(id, get_running_time(id));
	}
	return FMRES_IGNORED;
}

public SRPlayer_Strafecount(id)
{
    if(!is_user_alive(id) || m_insidePlayer[id]) return FMRES_IGNORED;
    
    static bool:bOnGround; bOnGround = bool:(pev(id, pev_flags) & FL_ONGROUND);
    
    static Float:fAngles[3]; pev(id, pev_angles, fAngles);
    
    g_bTurningRight[id] = false;
    g_bTurningLeft[id] = false;
    
    if(fAngles[1] < g_fOldAngles[id])
    {
        g_bTurningRight[id] = true;
    }
    else if(fAngles[1] > g_fOldAngles[id])
    {
        g_bTurningLeft[id] = true;
    }    
    g_fOldAngles[id] = fAngles[1];
    
    if(bOnGround) return FMRES_IGNORED;
    
    static iButtons; iButtons = pev(id, pev_button);
    static Float:fVelocity[3]; pev(id, pev_velocity, fVelocity);
    static Float:fSpeed; fSpeed = floatsqroot(fVelocity[0] * fVelocity[0] + fVelocity[1] * fVelocity[1]);
    
    if(g_bTurningLeft[id] || g_bTurningRight[id])
    {
        if(!g_bStrafingAw[id] && ((iButtons & IN_FORWARD)
            || (iButtons & IN_MOVELEFT)) && !(iButtons & IN_MOVERIGHT) && !(iButtons & IN_BACK))
        {
            g_bStrafingAw[id] = true;
            g_bStrafingSd[id] = false;
            
            m_iStrafeCount[id]++;
        }
        else if(!g_bStrafingSd[id] && ((iButtons & IN_BACK)
            || (iButtons & IN_MOVERIGHT)) && !(iButtons & IN_MOVELEFT) && !(iButtons & IN_FORWARD))
        {
            g_bStrafingAw[id] = false;
            g_bStrafingSd[id] = true;
            
            m_iStrafeCount[id]++;
        }
    }
    
    if(g_fMaxSpeed[id] < fSpeed)
    {
        g_fMaxSpeed[id] = fSpeed;
    }
    
    if(g_fOldSpeed[id] < fSpeed)
    {
        g_iGoodSync[id]++;
        
        if(m_iStrafeCount[id] && m_iStrafeCount[id] <= MAX_STRAFES)
        {
            g_iStrafeGoodSync[id][m_iStrafeCount[id] - 1]++;
        }
    }
    
    g_iSyncFrames[id]++;
    
    if(m_iStrafeCount[id] && m_iStrafeCount[id] <= MAX_STRAFES)
    {
        g_iStrafeFrames[id][m_iStrafeCount[id] - 1]++;
    }
    
    g_fOldSpeed[id] = fSpeed; 
    
    return FMRES_IGNORED;
} 

public CBasePlayer_StartTimer(id) 
{
	if (entity_get_int(id, EV_INT_button) & 2) {
		new flags = entity_get_int(id, EV_INT_flags)
		
		if (flags & FL_WATERJUMP)
		return PLUGIN_CONTINUE
		if (entity_get_int(id, EV_INT_waterlevel) >= 2)
		return PLUGIN_CONTINUE
		if (!(flags & FL_ONGROUND))
		return PLUGIN_CONTINUE
		
		if(m_CheckButton[id] == 0 && !m_iTimerStarted[id]) 
		{
			PlayerStarted(id);
			m_CheckButton[id] = 1;
		}
	}
	new button = get_user_button(id)
	if (button & IN_DUCK) 
	{
		if(m_CheckButton[id] == 0 && !m_iTimerStarted[id]) 
		{
			PlayerStarted(id);
			m_CheckButton[id] = 1;
		}
	}
	return PLUGIN_CONTINUE
}
ClientAuthorization(id) 
{
	if(!g_iMapIndex) return;
	
	new szAuth[32]; get_user_authid(id, szAuth, charsmax(szAuth));
	
	new data[1]; data[0] = id;
	formatex(g_szQuery, charsmax(g_szQuery), "SELECT id, ip FROM `runners` WHERE steamid='%s'", szAuth);
	SQL_ThreadQuery(g_hTuple, "Query_LoadRunnerInfoHandler", g_szQuery, data, sizeof(data));
}
public Query_LoadRunnerInfoHandler(failstate, Handle:query, error[], errnum, data[], size) 
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("SQL error[LoadRunnerInfo]: %s",error); return;
	}
	
	new id = data[0];
	if(!is_user_connected(id)) return;

	if(SQL_MoreResults(query))
	{
		client_authorized_db(id, SQL_ReadResult(query, 0));
	} else {
		new szAuth[32]; get_user_authid(id, szAuth, charsmax(szAuth));
		new szIP[32]; get_user_ip(id, szIP, charsmax(szIP), 1);
		new szName[64]; get_user_name(id, szName, charsmax(szName));
		SQL_PrepareString(szName, szName, 63);
		
		formatex(g_szQuery, charsmax(g_szQuery), "INSERT INTO `runners` (steamid, nickname, ip) VALUES ('%s', '%s', '%s')", szAuth, szName, szIP);
		SQL_ThreadQuery(g_hTuple, "Query_InsertRunnerHandle", g_szQuery, data, size);
	}
}
public Query_InsertRunnerHandle(failstate, Handle:query, error[], errnum, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("SQL error[InsertRunner]: %s",error); return;
	}
	
	new id = data[0];
	if(!is_user_connected(id)) return;
	
	client_authorized_db(id , SQL_GetInsertId(query));
}
client_authorized_db(id, pid)
{
	m_iPlayerIndex[id] = pid;
	m_iPlayerAuthorized[id] = true;
	
	arrayset(g_iBestTime[id], 0, sizeof(g_iBestTime[]));
	arrayset(g_iBestJumps[id], 0, sizeof(g_iBestJumps[]));
        arrayset(g_iBestStrafes[id], 0, sizeof(g_iBestStrafes[]));
        arrayset(g_iBestSpeeds[id], 0, sizeof(g_iBestSpeeds[]));


	LoadRunnerData(id);
}
LoadRunnerData(id) 
{
	if(!m_iPlayerAuthorized[id]) return;
	
	new data[1]; data[0] = id;
	
	formatex(g_szQuery, charsmax(g_szQuery), "SELECT * FROM `results` WHERE id=%d AND mid=%d", m_iPlayerIndex[id], g_iMapIndex);
	SQL_ThreadQuery(g_hTuple, "Query_LoadDataHandle", g_szQuery, data, sizeof(data));
}
public Query_LoadDataHandle(failstate, Handle:query, error[], errnum, data[], size) 
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("SQL Insert error: %s",error); return;
	}
	
	new id = data[0];
	if(!is_user_connected(id)) return;
	
	while(SQL_MoreResults(query))
	{
		new category = SQL_ReadResult(query, 2);
		g_iBestTime[id][category] = SQL_ReadResult(query, 3);
		g_iBestJumps[id][category] = SQL_ReadResult(query, 4);
                g_iBestStrafes[id][category] = SQL_ReadResult(query, 5);
                g_iBestSpeeds[id][category] = SQL_ReadResult(query, 6);
		
		SQL_NextRow(query);
	}
}

public client_disconnected(id)
{
	m_iPlayerAuthorized[id] = false;
	m_iPlayerConnected[id] = false;
	m_iFinished[id] = false;
	m_iTimerStarted[id] = false;
        m_iStarted[id] = -1.0;

}

public Command_Update(id) 
{
	if(!m_iPlayerAuthorized[id] || is_flooding(id)) return PLUGIN_HANDLED;
	
	new szName[32]; get_user_name(id, szName, charsmax(szName)); SQL_PrepareString(szName, szName, charsmax(szName));
	formatex(g_szQuery, charsmax(g_szQuery), "UPDATE `runners` SET nickname = '%s' WHERE id=%d", szName, m_iPlayerIndex[id]);
	
	client_print_color(id, print_team_default, "%s Nickname updated!", PREFIX);
	
	SQL_ThreadQuery(g_hTuple, "Query_IngnoredHandle", g_szQuery);
	
	return PLUGIN_CONTINUE;
}

PlayerStarted(id) 
{
	m_iStarted[id] = get_gametime();
	m_iTimerStarted[id] = true;
        m_iJumpCount[id] = 0;
        m_iStrafeCount[id] = 0;
}
PlayerFinished(id)
{   
        m_iFinished[id] = true; 

	if(!get_user_save(id))
	{
	client_print_color(id, print_team_red, "%s^3 Save to respawn position ", PREFIX);
	return PLUGIN_HANDLED;
	}
        new record = false;
        new iTime = get_running_time(id);
        new iJumps =  get_jumps(id); 
        new iStrafes = get_strafes(id);
        new iSpeed = get_units(id);  
        new category = get_user_category(id);
        new szName[32]; get_user_name(id, szName, charsmax(szName));
        new szTime[32]; get_formated_time(iTime, szTime, charsmax(szTime));
        new szBestTime[32]; get_formated_time(iTime - g_iBestTimeofMap[category], szBestTime, charsmax(szBestTime));  
        //new szBesTTime[32]; get_formated_time(g_iBestTimeofMap[category], szBesTTime, charsmax(szBesTTime));
       //new szPersonalBest[32]; get_formated_time(g_iBestTime[id][category], szPersonalBest, charsmax(szPersonalBest));  

                                                             
	if(g_iBestTimeofMap[category] != 0 && g_iBestTimeofMap[category]<iTime)
        { 
                   client_print_color(0, print_team_default, "^4(^1%s^4) ^3Run Time: ^4%s ^1[^3Wr: ^3+%s ^1- ^4%s ^1] ^3Jumps ^4%d ^3Strafes ^4%i", szName, szTime, szBestTime, g_szCategory[category], iJumps, iStrafes);   
                   client_cmd(0, "hud_saytext_time 1 "); 
                                                                               
        }
        if(g_iBestTime[id][category] == 0)
        {
                SaveRunnerData(id, category, iTime, iJumps, iStrafes,iSpeed);
        }
        else if(g_iBestTime[id][category] > iTime)
        {
                get_formated_time(g_iBestTime[id][category] - iTime, szTime, charsmax(szTime));
 
                set_hudmessage(255, 0, 0, -1.0, 0.90, 0, 6.0, 7.0)
                show_hudmessage(0, "you corrected^n [%s - Time: -%s!]", g_szCategory[category], szTime); 
                
                SaveRunnerData(id, category, iTime, iJumps, iStrafes,iSpeed);
                
        }
        else if(g_iBestTime[id][category] < iTime)
        {
               // get_formated_time(iTime - g_iBestTime[id][category], szTime, charsmax(szTime));       
                //client_print_color(id, print_team_default, "%s%s^3 TO THE TOP:^1 +%s", PREFIX, g_szCategory[category], szTime);                          
        }
        else
        {
                client_print_color(id, print_team_default, "%s ^4WR: Own record equal!", PREFIX);
        }       
        if(g_iBestTimeofMap[category] == 0 || g_iBestTimeofMap[category] > iTime)
        {
                g_iBestTimeofMap[category] = iTime;
                
                new szName[32]; get_user_name(id, szName, charsmax(szName));
                get_formated_time(iTime, szTime, charsmax(szTime));
                
                client_print_color(0, print_team_default, "^4(^1%s^4) ^3New Time: ^4%s ^1[ ^3%s ^1] ^3Jumps ^4%d ^3Strafes ^4%i ^3Speed ^4%3.2f", szName, szTime, g_szCategory[category],iJumps, iStrafes,iSpeed);                                                           
 
                record = true;
                
                client_cmd(0, "mp3 play %s", szSounds[random(sizeof(szSounds))]);
                new Float:vOrigin[3] 
                pev(id, pev_origin, vOrigin)
    
                
                screen_player_effects(id) 
        }
        
        ExecuteForward(g_iPlayerFinished, g_iReturn, id, iTime, record);
 
        hide_timer(id);

        return PLUGIN_CONTINUE  
}
public SaveRunnerData(id, category, iTime, iJumps,iStrafes,Speeds) 
{
       
	if(!m_iPlayerAuthorized[id]) return;
	
	g_iBestTime[id][category] = iTime;
	g_iBestJumps[id][category] = iJumps
        g_iBestStrafes[id][category] = iStrafes;
        g_iBestSpeeds[id][category] = Speeds;

	new szRecordTime[32]; get_time("%Y-%m-%d %H:%M:%S", szRecordTime, charsmax(szRecordTime));
 

	
	formatex(g_szQuery, charsmax(g_szQuery), "INSERT OR IGNORE INTO `results` VALUES (%d, %d, %d, %d, %d, %d, %d, '%s'); \
			UPDATE `results` SET besttime=%d, bestjumps=%d, beststrafes=%d, bestspeeds=%d,recorddate='%s' WHERE id=%d AND mid=%d AND category=%d",
		m_iPlayerIndex[id], g_iMapIndex, category, iTime, iJumps, iStrafes, Speeds, szRecordTime,
		iTime, iJumps, iStrafes, Speeds, szRecordTime, m_iPlayerIndex[id], g_iMapIndex, category);
	
	SQL_ThreadQuery(g_hTuple, "Query_IngnoredHandle", g_szQuery);
}
ShowRank(id, category)
{
	formatex(g_szQuery, charsmax(g_szQuery), "SELECT COUNT(*) FROM `results` WHERE mid=%d AND category=%d AND besttime > 0 AND besttime < %d", 
			g_iMapIndex, category, g_iBestTime[id][category]);
		
	new data[2]; data[0] = id; data[1] = category;
	SQL_ThreadQuery(g_hTuple, "Query_LoadRankHandle", g_szQuery, data, sizeof(data));
}
public Query_LoadRankHandle(failstate, Handle:query, error[], errnum, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("SQL error[LoadRankHandle]: %s", error); return;
	}
	
	new id = data[0];
	new category = data[1];
	
	if(!is_user_connected(id) || !SQL_MoreResults(query)) return;
	
	new Rank = SQL_ReadResult(query, 0) + 1;
	
	client_print_color(id, print_team_default, "%s^3 Your rank is ^4#%d^3 on^1 ^4(%s)^3 category.^1", PREFIX, Rank, g_szCategory[category]);
}

public Command_Rank(id)
{
	if(is_flooding(id)) return PLUGIN_HANDLED;
	
	new category = get_user_category(id);
	if(g_iBestTime[id][category] == 0)
	{
		client_print_color(id, print_team_red, "%s^3 You don't have any record for this category. Finish the map", PREFIX);
		return PLUGIN_CONTINUE;
	}
	
	ShowRank(id, category);
	
	return PLUGIN_CONTINUE;
}
ShowTop15(id, category)
{
    if(!g_iBestTimeofMap[category])
    {
       
        client_print_color(id, print_team_red, "%s^3 No records found.", PREFIX);
    }     
    formatex(g_szQuery, charsmax(g_szQuery), "SELECT nickname, besttime, bestjumps, beststrafes, bestspeeds, recorddate FROM `results` JOIN `runners` ON `runners`.id=`results`.id WHERE mid=%d AND category=%d AND besttime ORDER BY besttime ASC LIMIT 100",
    g_iMapIndex, category);
       
    new data[2]; data[0] = id; data[1] = category;
    SQL_ThreadQuery(g_hTuple, "Query_LoadTop15Handle", g_szQuery, data, sizeof(data)); 
}
public Query_LoadTop15Handle(failstate, Handle:query, error[], errnum, data[], size)
{
	if(failstate != TQUERY_SUCCESS)
	{
		log_amx("SQL error[LoadTop15]: %s",error); return;
	}

	new id = data[0];
	if(!is_user_connected(id) && id != 0) return;

	new category = data[1];

	new title[64] = ""; format(title, charsmax(title), "\rSpeedrun \d> Top %s", g_szCategory[category]);
	g_SpeedrunTop = menu_create(title, "TopMenu_Handler");

	new szData[256];
	new szPosition[2];
	new iPosition = 1;
	
	new iTime, iJumps, iStrafes, Speeds, szName[32], szTime[32], szRecdate[64], szInfo[128]; 
        
       
       
	
	while(SQL_MoreResults(query))
	{
		 SQL_ReadResult(query, 0, szName, 31);
                 iTime = SQL_ReadResult(query, 1);
                 iJumps = SQL_ReadResult(query, 2);
                 iStrafes = SQL_ReadResult(query, 3);
                 Speeds = SQL_ReadResult(query, 4);
                 SQL_ReadResult(query, 5, szRecdate, 31);

		 get_formated_time(iTime, szTime, 31);
		 num_to_str(iPosition, szPosition, charsmax(szPosition));
              		
		 if(iPosition == 1)
		 {
			g_iBestTimeofMap[category] = iTime;
		 }
                
		 format(szData, charsmax(szData), "\r#%s\w - %s - \y%s", szPosition, szName, szTime);
		 format(szInfo, charsmax(szInfo), " %d %i %3.2f %s ", iJumps, iStrafes,  Speeds, szRecdate) 

		 menu_additem(g_SpeedrunTop, szData, szInfo); 

		 if(id == 0) return;

		 ++iPosition;
		
		 SQL_NextRow(query);
	}

	menu_setprop(g_SpeedrunTop, MPROP_NEXTNAME, "Next");
	menu_setprop(g_SpeedrunTop, MPROP_BACKNAME, "Previous");
	menu_setprop(g_SpeedrunTop, MPROP_EXITNAME, "Exit");
}

public TopMenu_Handler(id, menu, item)
{
    if(!is_user_connected(id) || item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
           
    new dummy, szInfo[128], iJumps[32],Speeds[32], iStrafes[32], szRecdate[32]
  
 
    menu_item_getinfo(menu, item, dummy, szInfo, charsmax(szInfo), _, _, dummy)
    parse(szInfo, iJumps, charsmax(iJumps), iStrafes, charsmax(iStrafes), Speeds, charsmax(Speeds),   szRecdate, charsmax(szRecdate))
 
    new title[64] = ""; format(title, charsmax(title), "\r[\dSR\r] \d> Record Stats") 
    g_DetailedTop = menu_create(title, "InfoMenu_Handler")
 
    new TextJump[64]  =   "";format(TextJump, charsmax(TextJump), "Jumps:\y %s", iJumps)
    new TextStrafe[64] =   "";format(TextStrafe, charsmax(TextStrafe), "Strafes:\y %s", iStrafes)
    new TextSpeed[64] =   "";format(TextSpeed, charsmax(TextSpeed), "Speed:\y %s m/s", Speeds)
    new TextRecDate[64] =   "";format(TextRecDate, charsmax(TextRecDate), "Record Date:\y %s", szRecdate)
 
    menu_additem(g_DetailedTop, TextJump)
    menu_additem(g_DetailedTop, TextStrafe)
    menu_additem(g_DetailedTop, TextSpeed)
    menu_additem(g_DetailedTop, TextRecDate)
 
    menu_display(id, g_DetailedTop, 0);  
  
    return PLUGIN_HANDLED;
}
public InfoMenu_Handler(id, menu, item)
{
    if(!is_user_connected(id) || item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
 
    menu_display(id, g_SpeedrunTop);
 
    return PLUGIN_HANDLED;
}
public Command_Top15(id)
{
	if(!m_iPlayerAuthorized[id] || is_flooding(id)) return PLUGIN_HANDLED;

        new menuTitle[128];
      
        formatex(menuTitle, charsmax(menuTitle), "\d[\rSR\d] \y> Top\r");
 
        g_SpeedrunTop = menu_create(menuTitle, "Toplist_Handler");

  
        menu_additem(g_SpeedrunTop, "Current category^n", "1");
  
        menu_additem(g_SpeedrunTop, "100", "2");
        menu_additem(g_SpeedrunTop, "200", "3");
        menu_additem(g_SpeedrunTop, "250", "4");
        menu_additem(g_SpeedrunTop, "333", "5");
        menu_additem(g_SpeedrunTop, "500", "6");
        menu_additem(g_SpeedrunTop, "1000", "7");

        menu_display(id, g_SpeedrunTop, 0);

        return PLUGIN_CONTINUE;
}
 
public Toplist_Handler(id, menu, item,category)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
 
    switch(item)
    {
        case 0:ShowTop15(id, get_user_category(id))
        case 1:ShowTop15(id, Cat_100fps)
        case 2:ShowTop15(id, Cat_200fps)
        case 3:ShowTop15(id, Cat_250fps)
        case 4:ShowTop15(id, Cat_333fps)
        case 5:ShowTop15(id, Cat_500fps) 
        case 6:ShowTop15(id, Cat_1000fps)
    }
   
    set_task(0.1, "DelayedTop", id)  
    client_print(id, print_center, "Top Loading...");

    return PLUGIN_CONTINUE;
} 

public DelayedTop(id)
{
     menu_display(id, g_SpeedrunTop); 	   
} 

screen_player_effects(id) 
{
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenFade"), _, id);
        write_short((1<<12) * 1)       //ammount 
        write_short(1<<12)             //lasts this long 
        write_short(0)                 //frequency 
        write_byte(random(255))
        write_byte(random(255))
        write_byte(random(255))
        write_byte(155)
        message_end()
      
        message_begin(MSG_ONE,get_user_msgid("ScreenShake"),{0,0,0},id); //trzesiawa ekranu
        write_short(7<<14); //ammount  
        write_short(1<<13); //lasts this long 
        write_short(1<<14); //frequency 
        message_end();
}

public EvPlayerKilled(iVictim)
{
	if(task_exists(TaskID + iVictim))
		remove_task(TaskID + iVictim);
        set_task(0.1, "DeadTask", iVictim + DeadID, .flags="b"); 

}

public DeadTask(Spec)
{ 
        Spec -= DeadID;
        static key[6][6]
        static target, Float:speed;   	
      	
	if(!is_user_connected(Spec) || is_user_alive(Spec))
	{
		remove_task(target + DeadID);
		return PLUGIN_CONTINUE;
        
	}
       
        new id = entity_get_int(Spec, EV_INT_iuser2);
	if(id <= 0 || id >= 33 || !is_user_alive(id))


		return PLUGIN_CONTINUE;
	new Name[32];
	get_user_name(id, Name, 31);
      	new button = pev(id, pev_button)


	format(key[0], 5, "%s", (button & IN_FORWARD) ? "W" : ".")
	format(key[1], 5, "%s", (button & IN_BACK) ? "S" : ".")
	format(key[2], 5, "%s", (button & IN_MOVELEFT) ? "A" : ".")
	format(key[3], 5, "%s", (button & IN_MOVERIGHT) ? "D" : ".")
	format(key[4], 5, "%s", (button & IN_JUMP) ? "JUMP" : "  ")
	format(key[5], 5, "%s", (button & IN_DUCK) ? "DUCK" : "  ")


        target = pev(id, pev_iuser1) == 4 ? pev(id, pev_iuser2) : id;


        speed = Player_Speed(target)


        set_hudmessage(255, 255, 255, 0.70, 0.15, 0, 0.0, 1.0 + 0.1, 0.0, 0.0, -1);
        ShowSyncHudMsg(Spec, HudObj, "Spectating %s: ^nSpeed: %3.2f^n ^t%s^n%s %s %s^n^n%s %s", Name,  speed, key[0], key[2], key[1], key[3], key[4], key[5]);     

        return PLUGIN_CONTINUE;  
}
public box_start_touch(box, id, const szClass[]) 
{
	if(!is_user_alive(id))
                return PLUGIN_CONTINUE;
        
        if(equal(szClass, "finish") && !m_iFinished[id])
        {
                PlayerFinished(id);                                                                     
        }       
        if(equal(szClass, "box"))
        {
                m_insidePlayer[id] = true; 

                                     
        }
        return PLUGIN_CONTINUE;   
}
public box_stop_touch(box, id, const szClass[]) 
{ 
        if(!is_user_alive(id))
                return PLUGIN_CONTINUE; 

        if(equal(szClass, "box"))
        { 
               
        if(m_iPlayerAuthorized[id] && !m_iTimerStarted[id])
        {
            PlayerStarted(id); 
            
	} 
        m_insidePlayer[id] = false; 
    
        }  
 
        if(equal(szClass, "start") && !m_iTimerStarted[id])
        {         
               PlayerStarted(id);   
        } 
      
        return PLUGIN_CONTINUE;  
}
public ShowMenu(id) 
{        
        new menu = menu_create("\r[\wSR\r] \wShowMenu", "ShowMenu_Handler");


        new jump[64], strafe[64], cate[64];
        format(jump, charsmax(jump), "\d Show jump %s", jumps[id] ? "\rOFF" : "\wON");
       	format(strafe, charsmax(strafe), "\d Show strafe \d[%s\d]", strafes[id] ? "\rOFF" : "\wON");	
        format(cate, charsmax(cate), "\d Show Category \d[%s\d]", cat[id] ? "\rOFF" : "\wON");


	menu_additem(menu, jump,    "1");
        menu_additem(menu, strafe,  "2");
        menu_additem(menu, cate,    "3");
      
 
        menu_display(id, menu, 0);
   
        return PLUGIN_HANDLED;
}
public ShowMenu_Handler(id, menu, item)
{
	if(!is_user_alive(id)) return PLUGIN_HANDLED;
	
        if(item == MENU_EXIT) 
	{
            menu_destroy(menu);
            return PLUGIN_HANDLED;
        }
 
        switch(item)
        {
	case 0:
	{
		jumps[id] = !jumps[id]	
	}
	case 1: 
	{
		strafes[id] = !strafes[id]	
	}
	case 2: 
	{	
		cat[id] = !cat[id]  	               
	}
         
        }	
	
        if(item < 4) ShowMenu(id);

        return PLUGIN_CONTINUE; 
}
 
display_time(id, iTime) 
{
        new formats1[64],formats2[64],formats3[64],formats4[64]  
        new category = get_user_category(id); 
    
        Player_Speed(id)
        

        if(inv_TimerStatus[id])
        { 
    
        
        if(!velocity[id] ||  Player_Speed(id) < 0.1)  
    
                        format(formats3, 63, "");
        else
                        format(formats3, 63, "| speed: %3.2f ", Player_Speed(id));  

        if(strafes[id])
          
                        format(formats1, 63, "");
        else
                        format(formats1, 63, "| strafe: %d",  m_iStrafeCount[id]);

        if(jumps[id])
          
                        format(formats2, 63, "");
        else
                        format(formats2, 63, "| jump: %d ",  m_iJumpCount[id]);

        if(cat[id])            
          
                        format(formats4, 63, "");
        else
                        format(formats4, 63, "| cat: %s ", g_szCategory[category]);
       
             
        show_status(id, "Time: %d:%02d,%03d %s %s %s %s", iTime / 60000, (iTime / 1000) % 60, iTime % 1000, formats1, formats2, formats3, formats4);   
                                                                                 
        }
}
public Command_Timer(id)
{
      
        inv_TimerStatus[id] = !inv_TimerStatus[id] || show_status(id, "")

        client_print_color(id, print_team_red, "^1 Timer ^4[^3%s^4]", inv_TimerStatus[id] ? "ON" : "OFF");
}

public Command_Speed(id) 
{
        velocity[id] = !velocity[id];
}

stock Float:Player_Speed(id)
{ 
        new Float:fVect[3]

        pev(id, pev_velocity,fVect)

        return floatsqroot(fVect[0]*fVect[0]+fVect[1]*fVect[1] ) 
}  
  
public Fw_PlayerPreThink(id) 
{  
     if (!is_user_alive(id))
		return FMRES_IGNORED;


       m_iSpeed[id] = Player_Speed(id)
 

       return FMRES_IGNORED;
} 

hide_timer(id) 
{
        show_status(id, "");
}
get_running_time(id)
{
        return floatround((get_gametime() - m_iStarted[id]) * 1000, floatround_ceil);
}

get_jumps(id)
{
        return m_iJumpCount[id]
}

get_strafes(id)  
{
        return m_iStrafeCount[id]
} 

get_units(id) 
{ 
        return m_iSpeed[id]
      
}

get_formated_time(iTime, szTime[], size) 
{
        format(szTime, size, "%d:%02d.%03d", iTime / 60000, (iTime / 1000) % 60, iTime % 1000);
}
stock show_status(id, const input[], any:...) 
{
        static szStatus[191]
        vformat(szStatus, 190, input, 3)
        
       // static szStatus[128]; vformat(szStatus, charsmax(szStatus), input, 3);
        static StatusText; if(!StatusText) StatusText = get_user_msgid("StatusText");

        message_begin(MSG_ONE_UNRELIABLE, StatusText, _, id);
        write_byte(0);
        write_string(szStatus);
        message_end();
}
bool:is_flooding(id) 
{
        static Float:fAntiFlood[33];
        new bool:fl = false;
        new Float:fNow = get_gametime();
        
        if((fNow-fAntiFlood[id]) < 1.0) fl = true;
        
        fAntiFlood[id] = fNow;
        return fl;
}
stock SQL_PrepareString(const szQuery[], szOutPut[], size) 
{
        copy(szOutPut, size, szQuery);
        replace_all(szOutPut, size, "'", "\'");
        replace_all(szOutPut,size, "`", "\`");
        replace_all(szOutPut,size, "\\", "\\\\");
}
/*
stock UTIL_CheckServerLicense( const szIP[ ], iShutDown = 1 )
{
        new szServerIP[ 50 ];
        get_cvar_string( "ip", szServerIP, charsmax( szServerIP ) );
        
        if( !equal( szServerIP, szIP ) )
        {
                if( iShutDown == 1 )
                {
                        server_cmd( "exit" );
                
                        log_amx( "[SR] License IP: <%s>. Your Server IP is: <%s>. IP Checking failed...Shutting down...", szIP, szServerIP );
                }
                
                else if( iShutDown == 0 )
                {
                        new szFormatFailState[ 250 ];
                        formatex( szFormatFailState, charsmax( szFormatFailState ), "[SR] License IP: <%s>. Your Server IP is: <%s>. IP Checking failed.", szIP, szServerIP );
 
                        set_fail_state( szFormatFailState );
                }
        }
        
        else
        {
                log_amx( "[SR] License IP: <%s>. Your Server IP is: <%s>. IP Checking verified! Acces.", szIP, szServerIP );
        }
}*/
