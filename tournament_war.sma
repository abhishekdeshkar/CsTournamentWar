#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>
#include <csx>
#include <engine>
#include <sockets>

#define PLUGIN "||ECS|| PuB War"
#define VERSION "1.0"
#define AUTHOR "||ECS||nUy aka Abhishek Deshkar"
#define SVNUM 1

//HLTV
new hltv_id
new hltv_ip[32]
new hltv_port
new hltv_password[64] 


//No reset score on round restart for freeze time-out

new Frags[33], Deaths[33], RestartGame
new Float:RestartTime
new HamHook:PlayerSpawn

//Timeout declaration.

new bool:is_timeout = false
new ct_timeout_count = 0
new ts_timeout_count = 0


//======= Overtime Declarations ==================

new bool:g_OverTime     = false
new OTCount             = 0

//==============================================


//Detect Freezetime.
new bool:is_freezetime = false

//If player selected as captain
new bool:is_player_selected[33]

//get the current status of the HALF. By default false because no half started.
new bool:isFirstHalfStarted = false
new bool:isSecondHalfStarted = false

//Captains for match.
new gCptT
new gCptCT
new CaptainCount = 0
new bool:g_KnifeRound  = false

new bool:g_MapKnifeRound = false

// Is Match Initialized ?
new bool:g_MatchInit = false

//Owner of: who started the match
new MatchStarterOwner = 0

//Check if captain is choosen
new bool:CaptainSChosen

// Is Match started !
new bool:g_MatchStarted = false

//Set main match started to true: useful for leaving players + Count for leaving players.
new bool:g_MainMatchStarted = false

//By default first half if the second half is false.
new bool:is_secondHalf = false

//Handle the score. By default to: 0 score.
new ScoreFtrstTeam = 0
new ScoreScondteam = 0

//Show menu to the first captain == winner
new ShowMenuFirst
new ShowMenuSecond

//Captains Chosen Teams.- 2 == CT & 1 == T
new FirstCaptainTeamName
new SecondCaptainTeamName

//Store the name of the Captains.
new FirstCaptainName[52]
new SecondCaptainName[52]

//Store the Auth ID of the captains.
new FirstCaptainAuthID[128]
new SecondCaptainAuthID[128]

//Temp captain Names !
new TempFirstCaptain[32]
new TempSecondCaptain[32]

//Store current map.
new szMapname[50]

new RoundCounter = 0

// 1 = first captain 2 = second captain.
new CaptainChoosenID
new WhoChoseThePlayer


public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	register_clcmd("amx_startmatch", "ShowMenu", ADMIN_IMMUNITY, "Get All The players");

    //No score reset on round restart.
    register_event("TextMsg", "RoundRestart", "a", "2&#Game_w") 
	register_event("HLTV", "NewRound", "a", "1=0", "2=0")
	
	PlayerSpawn = RegisterHam(Ham_Spawn, "player", "FwPlayerSpawn", 1)

    //block advertise by cs
    set_msg_block(get_user_msgid("HudTextArgs"), BLOCK_SET);
	
    //Main menu
    register_clcmd("amx_ecsmenu", "ShowECSMenu", ADMIN_IMMUNITY, "ECS Tournament Menu");

    //For Knife round.
    register_event("CurWeapon", "Event_CurWeapon_NotKnife", "be", "1=1", "2!29")  
    
    //Round end event.
    register_logevent("round_end", 2, "1=Round_End")

    //Round start event.
    register_logevent("logevent_round_start", 2, "1=Round_Start")

    // T OR CT WIN.
    register_event( "SendAudio","on_TerroristWin","a","2=%!MRAD_terwin");
    register_event( "SendAudio","on_CTWin","a","2=%!MRAD_ctwin");

    //For Freezetime.
    register_event("HLTV", "new_round_timeout", "a", "1=0", "2=0")  

    //show score.
    register_clcmd("say !score", "ShowScoreToUser")
   
    get_mapname(szMapname, charsmax(szMapname))

}

public plugin_natives()
{
    register_library("tourny_war")

    register_native("is_match_started", "native_is_match_started")
}

public native_is_match_started()
{
    return g_MatchStarted
}

public new_round_timeout()
{

    //Set Freezetime to true.
    is_freezetime = true

    if(is_timeout)
    {
        set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	    show_dhudmessage(0,"2-Minute Time-Out Session ^n Round-Restart will be Given Automatically.")

        ColorChat(0,"!g[ECS-TOURNAMENT] !y: !tTime-out session.")
        ColorChat(0,"!g[ECS-TOURNAMENT] !y: !tTime-out session.")
        ColorChat(0,"!g[ECS-TOURNAMENT] !y: !tTime-out session.")
        ColorChat(0,"!g[ECS-TOURNAMENT] !y: !tTime-out session.")
        server_cmd("mp_freezetime 10.0")
    }
}


//Restart Round with no score update.
public NewRound() 
{


    if(g_MatchStarted)
    {
        if(RestartGame)
        {		
            new Players[32], num, user
            get_players(Players, num, "h")
            for(new i = 0; i < num; i++)
            {
                user = Players[i] 
                if(is_user_connected(user))
                {
                    Frags[user] = get_user_frags(user)
                    Deaths[user] = cs_get_user_deaths(user)
                    if(Frags[user] || Deaths[user])
                        RestartTime = get_gametime()
                }
            }

            EnableHamForward(PlayerSpawn)
            RestartGame = false
        }
    }
}	

public FwPlayerSpawn(user)
{

    if(g_KnifeRound || g_MapKnifeRound)
    {

        if((user != gCptCT) && (user != gCptT))
        {
            user_kill(user)
        }
        
    }

    if(g_MatchStarted)
    {
        new Float:GameTime = get_gametime()
        if(GameTime != RestartTime)
        {
            DisableHamForward(PlayerSpawn)
        }
        else
        {
            if(is_user_alive(user))
            {
                set_user_frags(user, Frags[user])
                cs_set_user_deaths(user, Deaths[user])
            }
        }
    }
}

public RoundRestart() 
{

    if(g_MatchStarted)
    {
        RestartGame = true
    }
}

//Terrorist Win event.
public on_TerroristWin()
{

    if(g_MapKnifeRound)
    {

        // T WOWN.
        ShowMenuFirst = gCptT
        ShowMenuSecond = gCptCT

        //Set Names of the Captain. because captain may leave the game.
        get_user_name(ShowMenuFirst, FirstCaptainName, charsmax(FirstCaptainName)) 
        get_user_name(ShowMenuSecond, SecondCaptainName, charsmax(SecondCaptainName))

        

        set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 

        set_task(2.0,"FirstCaptainWillSlectMap",gCptT)

        g_MapKnifeRound = false

    }

    //Terrorrist Knife round winner.
    if(g_KnifeRound == true)
    {
        
        // T WOWN.
        ShowMenuFirst = gCptT
        ShowMenuSecond = gCptCT

        //Set Names of the Captain. because captain may leave the game.
        get_user_name(ShowMenuFirst, FirstCaptainName, charsmax(FirstCaptainName)) 
        get_user_name(ShowMenuSecond, SecondCaptainName, charsmax(SecondCaptainName))

        

        set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 

        set_task(2.0,"FirstCaptainWonKnifeRoundMessage",gCptT)

        g_KnifeRound = false
        LoadMatchSettings()
    }

    if(g_MatchStarted)
    {

        if(isFirstHalfStarted)
        {
            if(FirstCaptainTeamName == 1)
            {
                ScoreFtrstTeam++
            }
            else
            {
                ScoreScondteam++
            }
        }
        if(isSecondHalfStarted)
        {
            if(FirstCaptainTeamName == 1)
            {
                ScoreScondteam++
            }
            else
            {
                ScoreFtrstTeam++
            }

        }
    }
}

//CT WIN Event.
public on_CTWin()
{


    if(g_MapKnifeRound)
    {
        // CT WON.
        ShowMenuFirst = gCptCT
        ShowMenuSecond = gCptT

            //Set Names of the Captain. because captain may leave the game.
        get_user_name(ShowMenuFirst, FirstCaptainName, charsmax(FirstCaptainName)) 
        get_user_name(ShowMenuSecond, SecondCaptainName, charsmax(SecondCaptainName)) 

        get_user_authid(ShowMenuFirst, FirstCaptainAuthID, 127)
        get_user_authid(ShowMenuSecond, SecondCaptainAuthID, 127)

        g_MapKnifeRound = false
    

        set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 

        set_task(2.0,"SecondCaptainSelectMap",gCptCT)
        
    }

    if(g_KnifeRound)
    {
        	
            // CT WON.
            ShowMenuFirst = gCptCT
            ShowMenuSecond = gCptT

             //Set Names of the Captain. because captain may leave the game.
            get_user_name(ShowMenuFirst, FirstCaptainName, charsmax(FirstCaptainName)) 
            get_user_name(ShowMenuSecond, SecondCaptainName, charsmax(SecondCaptainName)) 

            get_user_authid(ShowMenuFirst, FirstCaptainAuthID, 127)
            get_user_authid(ShowMenuSecond, SecondCaptainAuthID, 127)

             g_KnifeRound = false
        

            set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 

            set_task(2.0,"SecondCaptWonKnifeRoundWonMessage",gCptCT)
            
            LoadMatchSettings()
    }
    
    if(g_MatchStarted)
    {
        if(isFirstHalfStarted)
        {
            if(FirstCaptainTeamName == 2)
            {
                ScoreFtrstTeam++
            }
            else
            {
                ScoreScondteam++
            }

           
        }

        if(isSecondHalfStarted)
        {
            if(FirstCaptainTeamName == 2)
            {
                ScoreScondteam++
            }
            else
            {
                ScoreFtrstTeam++
            }

        }
    }
}


//ROUND START Event.
public logevent_round_start()
{

    is_freezetime = false

    if(is_timeout)
    {
        
        set_task(2.0,"TimeOutOverMessage")

        is_timeout = false
        server_cmd("sv_restart 1")
    }

    if(g_MapKnifeRound)
    {
       

        set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"-= Map selection Knife Round Begins =- ^n Captain: %s ^n Vs. ^n Captain: %s",TempFirstCaptain,TempSecondCaptain)

        ColorChat(0,"!t[ECS MAP-SELECTION-KNIFE] !g !tKnife Round for Map selection !yhas !gbeen started ! ")
        ColorChat(0,"!t[ECS MAP-SELECTION-KNIFE] !g Knife War for Map selection: !yCaptain- !t %s !gVs. !yCaptain- !t%s",TempFirstCaptain,TempSecondCaptain)
        ColorChat(0,"!t[ECS MAP-SELECTION-KNIFE] !g Knife War for Map selection: !yCaptain- !t %s !gVs. !yCaptain- !t%s",TempFirstCaptain,TempSecondCaptain)
     
    }

    if(g_KnifeRound)
    {
        set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0,"-= Knife Round Begins =- ^n Captain: %s ^n Vs. ^n Captain: %s",TempFirstCaptain,TempSecondCaptain)  

        ColorChat(0,"!t[ECS KNIFE FOR SIDE] !g !tKnife Round !yhas !gbeen started ! ")
        ColorChat(0,"!t[ECS KNIFE FOR SIDE] !g Knife War: !yCaptain- !t %s !gVs. !yCaptain- !t%s",TempFirstCaptain,TempSecondCaptain)
        ColorChat(0,"!t[ECS KNIFE FOR SIDE] !g Knife War: !yCaptain- !t %s !gVs. !yCaptain- !t%s",TempFirstCaptain,TempSecondCaptain)
     
    }
    
    if(g_MatchStarted)
    {
        //Show Score info in Hud on every round start.
        ShowScoreHud()
        set_task(3.0,"ShowScoreOnRoundStart")
    }
}


public TimeOutOverMessage()
{
    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
    show_dhudmessage(0,"Time-Out Session is OVER! ^n LIVE LIVE !!")
}

//Choose Captains and Initialize Match.
public ShowMenu(id)
{
	if(!cmd_access(id, ADMIN_IMMUNITY, 0, 0))
		return PLUGIN_HANDLED;

    if(g_MatchInit || g_MatchStarted)
    return PLUGIN_HANDLED


    MatchStarterOwner = id


    //Log AMX, Who stopped the match!.
    new MatchStarterName[32] 
    get_user_name(id, MatchStarterName, charsmax(MatchStarterName)) 

    new MatchStarterAuthID[128] 
    get_user_authid(id, MatchStarterAuthID, 127)

    // Match has been initialized! 
    g_MatchInit = true

    //Send message to players about message.
    MatchInitHudMessage()


    //Task 2 - Show Players Menu to who started the match.
    set_task(3.0, "ShowMenuPlayers", id)
    

	return PLUGIN_HANDLED;
}

//======================= Tournament MENU ===================================================

public ShowECSMenu(id, lvl, cid)
{
    	if(!cmd_access(id, lvl, cid, 0))
		return PLUGIN_HANDLED;

	new menu = menu_create("ECS Tournament Menu", "mh_ecsmenu");

    menu_additem(menu, "Map Selection", "", 0); // case 0
    menu_additem(menu, "Start Match", "", 0); // case 1
	menu_additem(menu, "Kick Menu", "", 0); // case 2
	menu_additem(menu, "Time Out", "", 0); // case 3
    menu_additem(menu,"Change Map","",0);

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);

	menu_display(id, menu, 0);

	return PLUGIN_HANDLED;
}

public mh_ecsmenu(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_cancel(id);
		return PLUGIN_HANDLED;
	}

	new command[6], name[64], access, callback;

	menu_item_getinfo(menu, item, access, command, sizeof command - 1, name, sizeof name - 1, callback);

	switch(item)
	{

        case 0:

        MapSelectionKnifeRound(id)

        case 1:

        ShowMenu(id)

		case 2:

        ShowKickMenu(id)

		case 3:

        AskedForTimeout(id)

        case 4: 

        ChooseMapMenu(id)

	}

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}


public MapSelectionKnifeRound(id)
{

    if(g_MatchInit || g_MatchStarted)
    return PLUGIN_HANDLED

    MatchStarterOwner = id

    //Log AMX, Who stopped the match!.
    new MatchStarterName[32] 
    get_user_name(id, MatchStarterName, charsmax(MatchStarterName)) 

    new MatchStarterAuthID[128] 
    get_user_authid(id, MatchStarterAuthID, 127)

    // Match has been initialized! 
    g_MatchInit = true

    //Send message to players about message.
    MatchInitHudMessage()


    //Task 2 - Show Players Menu to who started the match.
    set_task(3.0, "ShowMenuPlayersMapSelection", id)
    

	return PLUGIN_HANDLED;

}

public ShowMenuPlayersMapSelection(id)
{

    new iMenu = MakePlayerMenuMapSelection( id, "Choose a Captain For Map selection Knife", "PlayersMenuHandlerMapSelection" );
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
    menu_display( id, iMenu );

    return PLUGIN_CONTINUE;
}

MakePlayerMenuMapSelection( id, const szMenuTitle[], const szMenuHandler[] )
{
    new iMenu = menu_create( szMenuTitle, szMenuHandler );
    new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[33];
    get_players( iPlayers, iNum, "h" );

    new PlayerWithPoints[128]

    for(new i=0;i<iNum;i++)
    {
        iPlayer = iPlayers[i];
        
        //Add user in the menu if - CONNECTED and TEAM IS T.
        if(is_user_hltv(iPlayer) == 0)
        {

            if(!is_player_selected[iPlayer])
            {
                get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );

                formatex(PlayerWithPoints,127,"%s",szPlayerName)

                formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
                menu_additem( iMenu, PlayerWithPoints, szUserId, 0 );
            }
        }
        
        
    }


    return iMenu;
}

public PlayersMenuHandlerMapSelection( id, iMenu, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        // Recreate menu because user's team has been changed.
        new iMenu = MakePlayerMenuMapSelection( id, "Choose a Captain For Map Selection Knife", "PlayersMenuHandlerMapSelection" );
        menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
        menu_display( id, iMenu );

        return PLUGIN_HANDLED;
    }

    new szUserId[32], szPlayerName[32], iPlayer, iCallback;

    menu_item_getinfo( iMenu, iItem, iCallback, szUserId, charsmax( szUserId ), szPlayerName, charsmax( szPlayerName ), iCallback );

    if ( ( iPlayer = find_player( "k", str_to_num( szUserId ) ) )  )
    {
      
        if(CaptainCount == 0)
        {
            new ChosenCaptain[32] 
            get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
            ColorChat(0,"!t[ECS CAPTAIN SELECTION] !gPlayer  !t%s chosen !yas  First !tCaptain! ", ChosenCaptain)  

            is_player_selected[iPlayer] = true

            CaptainCount++  

            //Temp captain name.
            get_user_name(iPlayer, TempFirstCaptain, charsmax(TempFirstCaptain)) 
          

            if(get_user_team(iPlayer) == 1)
            {
                gCptT = iPlayer
            }

            if(get_user_team(iPlayer) == 2)
            {
                gCptCT = iPlayer
            }

            //Recreate menu.
            menu_destroy(iMenu)
            new iMenu = MakePlayerMenuMapSelection( id, "Choose a Captain For Map Selection Knife", "PlayersMenuHandlerMapSelection" );
            menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
            menu_display( id, iMenu );

            return PLUGIN_HANDLED;

        }

        if(CaptainCount == 1)
        {
            
            new ChosenCaptain[32] 
            get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
            ColorChat(0,"!t[ECS CAPTAIN SELECTION] !gPlayer  !t%s chosen !yas Second !tCaptain! ", ChosenCaptain)

            is_player_selected[iPlayer] = true

            CaptainCount++


             //Temp captain name.
            get_user_name(iPlayer, TempSecondCaptain, charsmax(TempSecondCaptain)) 

            if(get_user_team(iPlayer) == 1)
            {
                gCptT = iPlayer
            }

            if(get_user_team(iPlayer) == 2)
            {
                gCptCT = iPlayer
            }

            //Set it to true because captains have been chosen.
            CaptainSChosen = true

            //Announcement.
            set_dhudmessage(255, 0, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	        show_dhudmessage(0,"Get Ready Captains! ^n The Knife Round will Start in 10 seconds....")
            ColorChat(0,"!t[ECS KNIFE FOR SIDE] !gAttention ! !yThe !tKnife Round !gWill Start in 10 seconds!")


            //Start knife round.
            set_task(10.0,"Map_Knife_Round")

            //Captain choosing is over so destroy menu.
            menu_destroy(iMenu)
            return PLUGIN_HANDLED;
        }
        
    }
    
    // Recreate menu because user's team has been changed.
    new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
    menu_display( id, iMenu );

    return PLUGIN_HANDLED;
}

public ShowKickMenu(id)
{
    //Create a variable to hold the menu
    new menu = menu_create( "\rPlayer Kick Menu:", "KickMenu_Handler" );

    //We will need to create some variables so we can loop through all the players
    new players[32], pnum, tempid;

    //Some variables to hold information about the players
    new szName[32], szUserId[32];

	if(cs_get_user_team(id) == CS_TEAM_T )
	{
		get_players( players, pnum, "e","TERRORIST");
	}
	else
	{
		get_players( players, pnum, "e","CT");
	}

    //Start looping through all players
    for ( new i; i<pnum; i++ )
    {
        //Save a tempid so we do not re-index
        tempid = players[i];

        //Get the players name and userid as strings
        get_user_name( tempid, szName, charsmax( szName ) );
        //We will use the data parameter to send the userid, so we can identify which player was selected in the handler
        formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( tempid ) );

        //Add the item for this player
        menu_additem( menu, szName, szUserId, 0 );
    }

    //We now have all players in the menu, lets display the menu
    menu_display( id, menu, 0 );
}

public KickMenu_Handler( id, menu, item )
{
	if ( item == MENU_EXIT )
    {
        menu_destroy( menu );
        return PLUGIN_HANDLED;
    }

    new szData[6], szName[64];
    new _access, item_callback;

    menu_item_getinfo( menu, item, _access, szData,charsmax( szData ), szName,charsmax( szName ), item_callback );

    new userid = str_to_num( szData );

    new player = find_player( "k", userid ); // flag "k" : find player from userid

	new kickid = get_user_userid(player)

	server_cmd("kick #%d ^"You have been kicked by your Captain.^"",kickid)

	menu_destroy( menu );
    return PLUGIN_HANDLED;

}

public AskedForTimeout(id)
{

    if(!g_MatchStarted)
    {
        ColorChat(id,"!g[Tournament Time-Out] !y: !tFirst start the match!")
        return PLUGIN_HANDLED
    }

    if(is_freezetime)
    {
        ColorChat(id,"!g[ECS-Tournament] !y: !tYou !ycan !gask !yfor !gTime-out !yonce !tRound Starts!")
        return PLUGIN_HANDLED
    }

    if(is_timeout)
    {
        ColorChat(id,"!g[ECS-Tournament] !y: !tOne Team !yhas already !gasked !yfor the !gTime-Out!")
        return PLUGIN_HANDLED
    }
    else
    {
        if(isFirstHalfStarted)
        {
            if(get_user_team(id) == 1)
            {
                if(ts_timeout_count >= 3)
                {
                    ColorChat(id,"!g[ECS-Tournament TimeOut] !tYou have used all time-outs")
                }
                else
                {
                    //Increase for TS.
                    is_timeout = true
                    ts_timeout_count = ts_timeout_count + 1
                    server_cmd("mp_freezetime 120.0")

                    //TS.
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")          

                }

            }

            if(get_user_team(id) == 2)
            {
                if(ct_timeout_count >= 3)
                {
                    ColorChat(id,"!g[ECS-Tournament] !tYou have used all time-outs")
                }
                else
                {
                    //Increase for CT.
                    is_timeout = true
                    ct_timeout_count = ct_timeout_count + 1
                    server_cmd("mp_freezetime 120.0")
                    

                    //CT.
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")

                }
            }

        }

        if(isSecondHalfStarted)
        {
            if(get_user_team(id) == 1)
            {
                //Increase for CT.
                if(ct_timeout_count >= 3)
                {
                    ColorChat(id,"!g[ECS-Tournament] !tYou have used all time-outs")
                }
                else
                {
                    //Increase for CT.
                    is_timeout = true
                    ct_timeout_count = ct_timeout_count + 1
                    server_cmd("mp_freezetime 120.0")

                    //CT.
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Terrorist Captain")
                }
            }

            if(get_user_team(id) == 2)
            {
                //Increase for TS.
                if(ts_timeout_count >= 3)
                {
                    ColorChat(id,"!g[ECS-Tournament] !tYou have used all time-outs")
                }
                else
                {
                    //Increase for TS.
                    is_timeout = true
                    ts_timeout_count = ts_timeout_count + 1
                    server_cmd("mp_freezetime 120.0")

                    //TS.
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")
                    ColorChat(0,"!g[ECS-Tournament] !y: !tNext Round Time-Out Session. !gGiven By Counter-Terrorist Captain")

                }
            }
        }
    }

}


//Show HUD Message and Print message to inform player about match started !
public MatchInitHudMessage()
{
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"The Match has been Initialized ! ^n Captains will be chosen by the Match Lord.")

    ColorChat(0,"!t[ECS Tournamnt] !g The Match has been !tInitialized.")
    ColorChat(0,"!t[ECS Tournamnt] !g The Match has been !tInitialized.")
    ColorChat(0,"!t[ECS Tournamnt] !g Captains will be !tchosen.")
}

public ShowMenuPlayers(id)
{

    new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
    menu_display( id, iMenu );

    return PLUGIN_CONTINUE;
}

MakePlayerMenu( id, const szMenuTitle[], const szMenuHandler[] )
{
    new iMenu = menu_create( szMenuTitle, szMenuHandler );
    new iPlayers[32], iNum, iPlayer, szPlayerName[32], szUserId[33];
    get_players( iPlayers, iNum, "h" );

    new PlayerWithPoints[128]

    for(new i=0;i<iNum;i++)
    {
        iPlayer = iPlayers[i];
        
        //Add user in the menu if - CONNECTED and TEAM IS T.
        if(is_user_hltv(iPlayer) == 0)
        {

            if(!is_player_selected[iPlayer])
            {
                get_user_name( iPlayer, szPlayerName, charsmax( szPlayerName ) );

                formatex(PlayerWithPoints,127,"%s",szPlayerName)

                formatex( szUserId, charsmax( szUserId ), "%d", get_user_userid( iPlayer ) );
                menu_additem( iMenu, PlayerWithPoints, szUserId, 0 );
            }
        }
        
        
    }


    return iMenu;
}

public PlayersMenuHandler( id, iMenu, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        // Recreate menu because user's team has been changed.
        new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
        menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
        menu_display( id, iMenu );

        return PLUGIN_HANDLED;
    }

    new szUserId[32], szPlayerName[32], iPlayer, iCallback;

    menu_item_getinfo( iMenu, iItem, iCallback, szUserId, charsmax( szUserId ), szPlayerName, charsmax( szPlayerName ), iCallback );

    if ( ( iPlayer = find_player( "k", str_to_num( szUserId ) ) )  )
    {
      
        if(CaptainCount == 0)
        {
            
            new ChosenCaptain[32] 
            get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
            ColorChat(0,"!t[ECS CAPTAIN SELECTION] !gPlayer  !t%s chosen !yas  First !tCaptain! ", ChosenCaptain)  

            is_player_selected[iPlayer] = true

            CaptainCount++  

            //Temp captain name.
            get_user_name(iPlayer, TempFirstCaptain, charsmax(TempFirstCaptain)) 
          
            if(get_user_team(iPlayer) == 1)
            {
                gCptT = iPlayer
            }

            if(get_user_team(iPlayer) == 2)
            {
                gCptCT = iPlayer
            }

            //Recreate menu.
            menu_destroy(iMenu)
            new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
            menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
            menu_display( id, iMenu );

            return PLUGIN_HANDLED;

        }

        if(CaptainCount == 1)
        {

            new ChosenCaptain[32] 
            get_user_name(iPlayer, ChosenCaptain, charsmax(ChosenCaptain)) 
            ColorChat(0,"!t[ECS WAR] !gPlayer  !t%s chosen !yas Second !tCaptain! ", ChosenCaptain)

            is_player_selected[iPlayer] = true

            CaptainCount++


             //Temp captain name.
            get_user_name(iPlayer, TempSecondCaptain, charsmax(TempSecondCaptain)) 


            if(get_user_team(iPlayer) == 1)
            {
                gCptT = iPlayer
            }

            if(get_user_team(iPlayer) == 2)
            {
                gCptCT = iPlayer
            }

            //Set it to true because captains have been chosen.
            CaptainSChosen = true

            //Announcement.
            set_dhudmessage(255, 0, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	        show_dhudmessage(0,"Get Ready Captains! ^n The Knife Round will Start in 10 seconds....")
            ColorChat(0,"!t[ECS Tournamnt] !gAttention ! !yThe !tKnife Round !gWill Start in 10 seconds!")

            //Start knife round.
            set_task(10.0,"Knife_Round")

            //Captain choosing is over so destroy menu.
            menu_destroy(iMenu)
            return PLUGIN_HANDLED;
        }
        
    }
    
    // Recreate menu because user's team has been changed.
    new iMenu = MakePlayerMenu( id, "Choose a Captain", "PlayersMenuHandler" );
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" );
    menu_display( id, iMenu );

    return PLUGIN_HANDLED;
}

public Map_Knife_Round()
{

    server_cmd("mp_autokick 0")
    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 3 ); 
    set_task(10.0,"SetMapKnifeRoundTrue")  
}

public SetMapKnifeRoundTrue()
{
    g_MapKnifeRound = true
}

public Knife_Round()
{

    server_cmd("mp_autokick 0")
    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 3 ); 
    set_task(10.0,"SetKnifeRoundTrue")
}

public SetKnifeRoundTrue()
{
    g_KnifeRound = true
}

//Round end Checker
public round_end()
{

    new Players[ MAX_PLAYERS ], iNum,id;
	get_players( Players, iNum, "h" );

    if(g_MatchStarted)
    {
       //Increment rounds.
        RoundCounter++


        ShowScoreHud()
        CheckForWinningTeam()


        if(g_OverTime)
        {
            //Over time logic.
            if(RoundCounter == 3)
            {
                screenshot_setup()

                server_cmd("mp_freezetime 999")
                set_task(7.0,"SwapTeamsOverTimeMessage")
            }
        }
        else
        {
            if(RoundCounter == 15)
            {
                screenshot_setup()

                server_cmd("mp_freezetime 999")
                set_task(7.0,"SwapTeamsMessage")
                
            }
        }

    }
}

//Choose the team.
public ChooseTeam(id)
{

    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Captain %s will decide to Stay or Swap",FirstCaptainName)
    
    new TeamChooser = MakeTeamSelectorMenu( id, "Decide Stay or Swap.", "TeamHandler" );
    menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "\y" );
    menu_display( id, TeamChooser );

}

MakeTeamSelectorMenu( id, const szMenuTitle[], const szMenuHandler[])
{
     new TeamChooser = menu_create( szMenuTitle, szMenuHandler );
     menu_additem( TeamChooser, "Stay" );
     menu_additem( TeamChooser, "Swap");

     return TeamChooser;
}

public TeamHandler(id, TeamChooser, iItem )
{
    if ( iItem == MENU_EXIT )
    {
        // Recreate menu because user's team has been changed.
        new TeamChooser = MakeTeamSelectorMenu( id, "Please Choose the Team.", "TeamHandler" );
        menu_setprop( TeamChooser, MPROP_NUMBER_COLOR, "\y" );
        menu_display( id, TeamChooser );

        return PLUGIN_HANDLED;
    }


    switch(iItem)
    {
        //Chosen STAY.
        case 0:
        {
            ColorChat(0,"!t[ECS SIDE SELECTION] !gCaptain !t%s !yhas Decided to - !gSTAY",FirstCaptainName)

            if(get_user_team(id) == 1)
            {
                FirstCaptainTeamName = 1
                SecondCaptainTeamName = 2
            }

            if(get_user_team(id) == 2)
            {
                FirstCaptainTeamName = 2
                SecondCaptainTeamName = 1
            }

            PrepareMatch()


        }
        //Chosen SWAP.
        case 1:
        {

            if(get_user_team(id) == 1)
            {
                FirstCaptainTeamName = 2
                SecondCaptainTeamName = 1
            }

            if(get_user_team(id) == 2)
            {
                FirstCaptainTeamName = 1
                SecondCaptainTeamName = 2
            }
           

            ColorChat(0,"!t[ECS SIDE SELECTION] !gCaptain !t%s !yhas Decided to - !gSWAP",FirstCaptainName)
            
            cmdTeamSwap()

            PrepareMatch()
            
           
        }
    }
    return PLUGIN_HANDLED;
}

public PrepareMatch()
{

    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
    show_dhudmessage(0,"Teams are SET ! ^n ^n First Half will start Now.......")

    set_task(2.0, "GiveRestartRound"); 

    set_task(4.0,"LiveOnThreeRestart");

    set_task(8.0,"StartMatch")
}

public client_putinserver(id)
{
    new left[32]
	new right[32]

    new command[256]

    if(g_MatchStarted)
    {
        
        set_task( 5.0, "Record", id );
    }

    if(is_user_hltv(id))
    {
        hltv_id = id
        get_user_ip(hltv_id,hltv_ip,31)

        strtok (hltv_ip, left, 31, right, 31, ':')
		
		copy(hltv_ip, 31, left)
		hltv_port = str_to_num(right)

        format(command, 255, "say Configured correctly")
		hltv_rcon_command(command, 0)

        server_print("[HLTV-Tournament] - Connected and sending command.")

        format(command, 255, "delay 120")
		hltv_rcon_command(command, 0)

        if(g_MatchStarted)
        {
            RecordDemoHLTV()
        }

    }
}

public client_disconnected(id)
{
    if(CaptainSChosen || g_KnifeRound)
    {
        if(id == gCptCT || id == gCptT)
        {

            if(is_user_connected(MatchStarterOwner))
            {
                set_hudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8, -1)
                show_hudmessage(0,"Please restart the match because one of the captain left the game.")

                g_MatchStarted = false
            }
            else
            {

                g_MatchStarted = false
            }

        }
    }

}


// ====================== FUNCTIONS!! ===========================================================================================


//Checking for knife
public Event_CurWeapon_NotKnife(id)
{
    if ( !g_KnifeRound && !g_MapKnifeRound ) 
		return 

	if( !user_has_weapon(id, CSW_KNIFE ) )
		give_item(id, "weapon_knife") 
	    engclient_cmd(id, "weapon_knife")
}


//Swap teams.
public cmdTeamSwap()
{
	
	new players[32], num
	get_players(players, num)
	
	new player
	for(new i = 0; i < num; i++)
	{
		player = players[i]

        if(get_user_team(player) < 3)
        {
            cs_set_user_team(player, cs_get_user_team(player) == CS_TEAM_T ? CS_TEAM_CT:CS_TEAM_T)
        }
	}
	
	return PLUGIN_HANDLED
}



public StartMatch()
{

    server_cmd("mp_forcechasecam 2")
    server_cmd("mp_forcecamera 2")

    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    g_MatchInit = false
    
    CaptainSChosen = false
    
    ColorChat(0,"!t[ECS Tournament] !tFirst Half !gStarted")
    ColorChat(0,"!t[ECS Tournament] !gAttention ! !yThe !tMatch !yHas Been !g STARTED !")

    new ServerName[512]

    //change server name
    formatex(ServerName,charsmax(ServerName),"[TOURNAMENT]- %s VS. %s In Progress",FirstCaptainName,SecondCaptainName)

    server_cmd("hostname ^"%s^"",ServerName)

    ServerName[0] = 0

    set_task(11.0,"MatchStartedTrue")


    //Set the status of half to first half.
    isFirstHalfStarted = true

    set_task(12.0,"FirstHalfHUDMessage")

    //Record Demo.
    new Players[ MAX_PLAYERS ], iNum,id
    get_players( Players, iNum, "h" )
    
    for (new i=0; i<iNum; i++) 
    {
        id = Players[i]
        Record(id)
    }
    
    RecordDemoHLTV()

}

public RecordDemoHLTV()
{
    new hltv_command[512]

    new Now
	Now = get_systime()

    format(hltv_command, 511, "record %s-%i", szMapname,Now)

    hltv_rcon_command(hltv_command, 0)

}

public Record( id )
{
	
	new Now
	Now = get_systime()

	client_cmd( id, "stop; record  %s-%i",szMapname, Now )

	
}

//Swap teams for Overtime message.
public SwapTeamsOverTimeMessage()
{
    GiveRestartRound()

    set_task(3.0,"TeamSwapMessage")

    set_task(7.0,"FirstHalfOvertimeCompletedHUDMessage")

    set_task(12.0,"SwapTeamsAndRestartMatchOT") 
}

//Swap Team Message !.
public SwapTeamsMessage()
{

    GiveRestartRound()

    set_task(3.0,"TeamSwapMessage")

    set_task(7.0,"FirstHalfCompletedHUDMessage")

    set_task(12.0,"SwapTeamsAndRestartMatch")
}

//Swap teams and restart the match OT.
public SwapTeamsAndRestartMatchOT()
{
    //Swap Teams.
    cmdTeamSwap()

    GiveRestartRound();

    set_task(2.0,"LiveOnThreeRestart");

    //Give Restart
    set_task(4.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    ColorChat(0,"!t[ECS Tournament OVERTIME] !gTeams !yHave Been !gSwapped !");
    ColorChat(0,"!t[ECS Tournament OVERTIME] !gOver Time !y- !t%i !gSecond half !yhas been !gStarted !",OTCount);
    ColorChat(0,"!t[ECS Tournament OVERTIME] !gOver Time !y- !t%i !gSecond half !yhas been !gStarted !",OTCount);

    is_secondHalf       = true

    //Set first half status to zero.
    isFirstHalfStarted = false
    isSecondHalfStarted = true
    set_task(14.0,"SecondHalfOverTimeHUDMessage")

    LoadMatchSettings()
}

//Swap teams and restart the match.
public SwapTeamsAndRestartMatch()
{
    //Swap Teams.
    cmdTeamSwap()

    GiveRestartRound();

    set_task(2.0,"LiveOnThreeRestart");

    //Give Restart
    set_task(4.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    ColorChat(0,"!t[ECS Tournament] !gTeams !yHave Been !gSwapped !");
    ColorChat(0,"!t[ECS Tournament] !gSecond half !yhas been !gStarted !");
    
    is_secondHalf       = true

    //Set first half status to zero.
    isFirstHalfStarted = false
    isSecondHalfStarted = true
    set_task(14.0,"SecondHalfHUDMessage")

    LoadMatchSettings()

}


public ShowScoreHud()
{

    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "* [ECS-Tournament] Team [ %s ] winning %i to  %i ",FirstCaptainName,ScoreFtrstTeam,ScoreScondteam)

        set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "* [ECS-Tournament] Team [ %s ] winning %i To %i",SecondCaptainName,ScoreScondteam,ScoreFtrstTeam)

        set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "* [ECS-Tournament] Both Teams Have Won %i Rounds.",ScoreScondteam)

        set_dhudmessage(255, 255, 0, 0.0, 0.90, 0, 2.0, 5.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }
}

public CheckForWinningTeam()
{

    if(g_OverTime)
    {
        //Check for the overtime winners.
        if(ScoreFtrstTeam >= 4)
        {
            //First team won the match!       
            screenshot_setup()
           
            server_cmd("mp_freezetime 99999");
            set_task(7.0,"FirstTeamWinnerMessage")
        }

        if(ScoreScondteam >= 4)
        {
            //Second team won the match.
            screenshot_setup()
           
            server_cmd("mp_freezetime 99999");
            set_task(7.0,"SecondTeamWinnerMessage") 
        }

        if((ScoreFtrstTeam == 3) & (ScoreScondteam == 3))
        {


            //Draw. Start next OT. & OT count++.
            OTCount++
            RoundCounter = 0
            ScoreFtrstTeam = 0
            ScoreScondteam = 0


            server_cmd("mp_freezetime 99999");
            server_cmd("sv_restart 1");
            
            set_task(2.0,"MatchDrawMessageOT")
        }

    }
    else
    {
        if(ScoreFtrstTeam >= 16)
        {
            //Change description of the game.
        
            screenshot_setup()

            server_cmd("mp_freezetime 99999");
            set_task(7.0,"FirstTeamWinnerMessage")
            
        }

        if(ScoreScondteam >= 16)
        {   

            screenshot_setup()
            
            server_cmd("mp_freezetime 99999");
            set_task(7.0,"SecondTeamWinnerMessage") 
        }
    
        if((ScoreFtrstTeam == 15) & (ScoreScondteam == 15))
        {

            server_cmd("mp_freezetime 99999");
            server_cmd("sv_restart 1");

            g_MatchStarted = false
            
            //OT STEP 1
            set_task(2.0,"MatchDrawMessage")
        }
    }

}

//================== TAKE SCREENSHOTS ===============================================

public screenshot_setup()
{
	set_task(1.0,"show_scoreboard")
    set_task(3.0,"screenshot_take")
    set_task(5.0, "screenshot_scoreboard_remove")

}

public show_scoreboard()
{
    new players[32]
	new number
	
    
	get_players(players, number, "h")
	
	for(new i=0; i < number; i++)
	{
        new player = players[i]
		client_cmd(player,"+showscores")
	}
}

public screenshot_take()
{
    new players[32]
	new number
	
	get_players(players, number,"h")
	
	for(new i=0; i < number; i++)
	{	
        new player = players[i]
		client_cmd(player,"snapshot")
	}
}

public screenshot_scoreboard_remove()
{

    new players[32]
	new number
	
	get_players(players, number,"h")
	
	for(new i=0; i < number; i++)
	{	
        new player = players[i]
		client_cmd(player,"-showscores")
	}

}

//================== TAKE SCREENSHOTS ===============================================


//Winner message. - First team won!
public FirstTeamWonTheMatch()
{
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Team [ %s ]  Won The Match !! ^n GG WP To Team %s ..",FirstCaptainName,FirstCaptainName)
}

//Winner message. - Second team won!
public SecondTeamWonTheMatch()
{
    set_dhudmessage(0, 255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
	show_dhudmessage(0,"Team [ %s ] Won The Match !! ^n GG WP To Team %s  !",SecondCaptainName,SecondCaptainName)
}

//Load Match settings because match has been started !
public LoadMatchSettings()
{

    server_cmd("sv_alltalk 0")
    server_cmd("mp_freezetime 10")
}

//Load PuB settings because Match is over!
public LoadPubSettings()
{
    hltv_id = 0
    hltv_ip[0] = 0
    hltv_port = 0
    hltv_password[0] = 0
    Frags[0] = 0
    Deaths[0] = 0
    RestartGame = 0
    RestartTime = 0
    PlayerSpawn = 0
    is_timeout = false
    ct_timeout_count = 0
    ts_timeout_count = 0
    g_OverTime = false
    OTCount = 0
    is_freezetime = false
    is_player_selected[0] = 0
    isFirstHalfStarted = false
    isSecondHalfStarted = false
    gCptT = 0
    gCptCT = 0
    CaptainCount = 0
    g_KnifeRound = false
    g_MapKnifeRound = false
    g_MatchInit = false
    MatchStarterOwner = 0
    CaptainSChosen = false
    g_MatchStarted = false
    g_MainMatchStarted = false
    is_secondHalf = false
    ScoreFtrstTeam = 0
    ScoreScondteam = 0
    ShowMenuFirst = 0
    ShowMenuSecond = 0
    FirstCaptainTeamName = 0
    SecondCaptainTeamName = 0
    FirstCaptainName[0] = 0
    SecondCaptainName[0] = 0
    FirstCaptainAuthID[0] = 0
    SecondCaptainAuthID[0] = 0
    TempFirstCaptain[0] = 0
    TempSecondCaptain[0] = 0
    szMapname[0] = 0
    RoundCounter = 0
    CaptainChoosenID = 0
    WhoChoseThePlayer = 0

    server_cmd("exec server.cfg")
    set_task( 3.0, "GiveRestartRound", _, _, _, "a", 1 ); 
    

}

public FirstTeamWinnerMessage()
{

    GiveRestartRound()

    StopRecordingDemo()
    StopRecordingDemoHLTV()

    set_task(3.0,"MatchIsOverHUDMessage")
    set_task(7.0,"SecondHalfCompletedHUDMessage")
    set_task(13.0,"FirstTeamWonTheMatch")
    set_task(32.0,"LoadPubSettings")
}

public SecondTeamWinnerMessage()
{
    GiveRestartRound()

    StopRecordingDemo()
    StopRecordingDemoHLTV()

    set_task(3.0,"MatchIsOverHUDMessage")
    set_task(7.0,"SecondHalfCompletedHUDMessage")
    set_task(13.0,"SecondTeamWonTheMatch")
    set_task(32.0,"LoadPubSettings")
}

public StopRecordingDemoHLTV()
{
    new temp[64]
	hltv_rcon_command("stoprecording", 0)
	hltv_rcon_command(temp, 0)
}

public StopRecordingDemo()
{
    //Stop Recording a Demo.
    new Players[ MAX_PLAYERS ], iNum,id
    get_players( Players, iNum, "h" )
    
    for (new i=0; i<iNum; i++) 
    {
        id = Players[i]
        client_cmd( id, "stop")
    }
}

public MatchDrawMessage()
{
    set_task(3.0,"MatchIsDrawHUDMessage")
    set_task(7.0,"OverTimeStartMessage")

    //OT STEP 2
    OverTimeSettings()
    set_task(13.0,"SwapTeamsAndStartOverTimeFirstHalf")
}

// Over time Draw Message.
public MatchDrawMessageOT()
{
    set_task(3.0,"MatchIsDrawOTHUDMessage")
    set_task(7.0,"OverTimeStartMessage")

    set_task(13.0,"SwapTeamsAndStartOverTimeFirstHalf")
}

public OverTimeSettings()
{
    ScoreFtrstTeam = 0
    ScoreScondteam = 0
    g_OverTime = true
    RoundCounter = 0
    OTCount++
}

public SwapTeamsAndStartOverTimeFirstHalf()
{

    //OT STEP 3

    //Swap Teams.
    cmdTeamSwap()

    GiveRestartRound();

    set_task(2.0,"LiveOnThreeRestart");

    //Give Restart
    set_task(4.0, "GiveRestartRound", _, _, _, "a", 3 ); 

    ColorChat(0,"!t[ECS Tournament OVERTIME] !gTeams !yHave Been !gSwapped !");
    ColorChat(0,"!t[ECS Tournament OVERTIME] !gOver Time !y- !t%i !gFirst Half !yhas been !gStarted !",OTCount);
    ColorChat(0,"!t[ECS Tournament OVERTIME] !gOver Time !y- !t%i !gFirst Half !yhas been !gStarted !",OTCount);
    ColorChat(0,"!t[ECS Tournament OVERTIME] !gOverTime Number !y: !t%i",OTCount);

    g_MatchStarted = true

    is_secondHalf       = false

    //Set first half status to zero.
    isFirstHalfStarted = true
    isSecondHalfStarted = false
    set_task(14.0,"OverTimeFirstHalfLiveMessage")

    LoadMatchSettings()

}

public OverTimeStartMessage()
{
    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
    show_dhudmessage(0, "Teams will be Swapped Automatically. ^n OverTime [%i] Will Start Now!",OTCount) 
}

public SecondCaptWonKnifeRoundWonMessage(id)
{
    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"Captain [ %s ] Won the Knife Round !",FirstCaptainName)

    ColorChat(0,"!t[ECS Tournament] !gCaptain !t%s !gWon !ythe !tKnife Round !",FirstCaptainName)

    set_task(5.0,"ChooseTeam",gCptCT)
    
}

public SecondCaptainSelectMap(id)
{
    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"Captain [ %s ] Won the Knife Round and will select the first Map!",FirstCaptainName)

    ColorChat(0,"!t[ECS Tournament] !gCaptain !t%s !gWon !ythe !tKnife Round !",FirstCaptainName)

    set_task(5.0,"ChooseMapMenu",gCptCT)
}

public FirstCaptainWillSlectMap(id)
{
    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
	show_dhudmessage(0,"Captain [ %s ] Won the Knife Round and will select the first Map!",FirstCaptainName)

    ColorChat(0,"!t[ECS Tournament] !gCaptain !t%s !gWon !ythe !tKnife Round !",FirstCaptainName)

    set_task(5.0,"ChooseMapMenu",gCptT) 
}


public ChooseMapMenu(id)
{
	new menu = menu_create("Choose your map", "mh_MapSelection");

	menu_additem(menu, "de_dust2", "", 0); // case 0
	menu_additem(menu, "de_nuke", "", 0); // case 1
	menu_additem(menu, "de_inferno", "", 0); // case 2
	menu_additem(menu, "de_train", "", 0); // case 3
	menu_additem(menu, "de_mirage", "", 0); // case 4
	menu_additem(menu, "de_tuscan32", "", 0); // case 5

	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);

	menu_display(id, menu, 0);

	return PLUGIN_HANDLED;
}

public mh_MapSelection(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_cancel(id);
		return PLUGIN_HANDLED;
	}

	new command[6], name[64], access, callback;

	menu_item_getinfo(menu, item, access, command, sizeof command - 1, name, sizeof name - 1, callback);

	switch(item)
	{
		case 0:
        engine_changelevel("de_dust2")
		
        case 1:
        engine_changelevel("de_nuke")

		case 2:
        engine_changelevel("de_inferno")

		case 3:
        engine_changelevel("de_train")
            
		case 4:
        engine_changelevel("de_mirage")

		case 5:
        engine_changelevel("de_tuscan32")
	}

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public FirstCaptainWonKnifeRoundMessage(id)
{
    set_dhudmessage(255, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
	show_dhudmessage(0,"Captain [ %s ] Won the Knife Round !",FirstCaptainName)

    ColorChat(0,"!t[ECS Tournament] !gCaptain !t%s !gWon !ythe !tKnife Round !",FirstCaptainName)

    set_task(5.0,"ChooseTeam",gCptT)
    
}

public ShowScoreToUser(id)
{
    if(g_MatchStarted)
    {

        if(isFirstHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(id) == 2))
            {
                ColorChat(id,"!t[ECS Tournament] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(id) == 1)  )
            {    
                ColorChat(id,"!t[ECS Tournament] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(id)) == 2)
            {
               ColorChat(id,"!t[ECS Tournament] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(id) == 1) )
            {
                ColorChat(id,"!t[ECS Tournament] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }
        }

        if(isSecondHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(id) == 2))
            {
                ColorChat(id,"!t[ECS Tournament] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(id) == 1)  )
            {    
                ColorChat(id,"!t[ECS Tournament] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(id)) == 2)
            {
                ColorChat(id,"!t[ECS Tournament] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(id) == 1) )
            {
                ColorChat(id,"!t[ECS Tournament] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }
        }
    }
}

public ShowScoreOnRoundStart()
{

    new players[32],num,iPlayer
    get_players(players,num,"h");
    

    for(new i=0;i<num;i++)
    {
        iPlayer = players[i];

        if(isFirstHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(iPlayer) == 2))
            {
                ColorChat(iPlayer,"!t[ECS Tournamnt] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(iPlayer) == 1)  )
            {    
                ColorChat(iPlayer,"!t[ECS Tournamnt] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(iPlayer)) == 2)
            {
                ColorChat(iPlayer,"!t[ECS Tournamnt] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(iPlayer) == 1) )
            {
                ColorChat(iPlayer,"!t[ECS Tournamnt] !yYour !gTeam's Score !yis: !t%i | !gOpponents !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }
        }

        if(isSecondHalfStarted)
        {
            if(( FirstCaptainTeamName == 1) && (get_user_team(iPlayer) == 2))
            {
                ColorChat(iPlayer,"!t[ECS Tournamnt] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }
            
            if(( FirstCaptainTeamName == 1 ) && (get_user_team(iPlayer) == 1)  )
            {    
                ColorChat(iPlayer,"!t[ECS Tournamnt] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }

            if((FirstCaptainTeamName == 2) && (get_user_team(iPlayer)) == 2)
            {
                ColorChat(iPlayer,"!t[ECS Tournamnt] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreScondteam,ScoreFtrstTeam)
            }

            if( (FirstCaptainTeamName == 2) && (get_user_team(iPlayer) == 1) )
            {
                ColorChat(iPlayer,"!t[ECS Tournamnt] !yYour !gTeam's Score !yis: !t%i | !gOpponent's Team !tScore: !t %i",ScoreFtrstTeam,ScoreScondteam)
            }
        }
    }
    
}

//To restart the round.
public GiveRestartRound( ) 
{ 
    server_cmd( "sv_restartround ^"1^"" ); 
} 

//All MESSAGES.
public FirstHalfHUDMessage()
{
    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ First Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!! GL & HF","LIVE !!! GL & HF","LIVE !!! GL & HF")
}

public SecondHalfHUDMessage()
{
    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ Second Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!!","LIVE !!! ","LIVE !!! ")
}

public SecondHalfOverTimeHUDMessage()
{
    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ OT Second Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!!","LIVE !!! ","LIVE !!! ")
}

public OverTimeFirstHalfLiveMessage()
{
    set_dhudmessage(0, 255, 255, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ OT First Half Started ! }=^n --[ %s ]--^n--[ %s ]--^n--[ %s ]--","LIVE !!!","LIVE !!! ","LIVE !!! ")
}

//FirstHalfOvertimeCompletedHUDMessage
//SwapTeamsOverTimeMessage
public FirstHalfOvertimeCompletedHUDMessage()
{

    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "={ First Half OT }= ^n %s - %i ^n Winning to ^n %s - %i",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)


        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "={ First Falf OT }= ^n %s - %i ^n Winning to ^n %s - %i",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)


        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "OT - Both Teams Have Won %i Rounds.",ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

}

public FirstHalfCompletedHUDMessage()
{
    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "={ First Half Score }= ^n %s - %i ^n Winning to ^n %s - %i",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "={ First Falf Score }= ^n %s - %i ^n Winning to ^n %s - %i",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "Both Teams Have Won %i Rounds.",ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }
}

public SecondHalfCompletedHUDMessage()
{
    new score_message[1024]

    if(ScoreFtrstTeam > ScoreScondteam)
    {
        format(score_message, 1023, "={ Match Score }=^n %s - %i ^n Winning To ^n %s - %i",FirstCaptainName,ScoreFtrstTeam,SecondCaptainName,ScoreScondteam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreScondteam > ScoreFtrstTeam)
    {
        format(score_message, 1023, "={ Match Score }=^n %s - %i ^n Winning to ^n %s - %i",SecondCaptainName,ScoreScondteam,FirstCaptainName,ScoreFtrstTeam)

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 4.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

    if(ScoreFtrstTeam == ScoreScondteam)
    {
        format(score_message, 1023, "={ Match Score }=^n Both Teams Have Won %i Rounds.")

        set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 6.0, 0.8, 0.8)
        show_dhudmessage(0, score_message)
    }

}

public MatchIsOverHUDMessage()
{
    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ Match Is Over }=")
}

public MatchIsDrawHUDMessage()
{

    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ Match Is Draw!! }=")
}
//IF OT Match is Draw!
public MatchIsDrawOTHUDMessage()
{
    set_dhudmessage(0,255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"={ OverTime Match Draw!!^n Next OverTime Will start Now! }=")  
}

public TeamSwapMessage()
{
    set_dhudmessage(255, 255, 0, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"First Half Over! ^n Teams will be swapped Automatically. Please do not change the Team! ^n Second Half will start Now!")
}

public MatchStartedTrue()
{
    g_MatchStarted = true

    set_task(30.0,"SetMainMatchStartedTrue")

}


public SetMainMatchStartedTrue()
{
    g_MainMatchStarted = true
}


public LiveOnThreeRestart()
{

    set_dhudmessage(42, 255, 212, -1.0, -1.0, 0, 2.0, 3.0, 0.8, 0.8)
    show_dhudmessage(0,"-{ LiVe On 3 RestartS } - ^n -== LO3 =-")
}

public hltv_rcon_command(hltv_command[], id)
{
	// Declare variables
	new socket_address		// Contains the socket address of the hltv server 
	new socket_error = 0	// Contains the error code of the socket connection
	
	new receive[256]		// Contains the received socket command
	new send[256]			// Contains the send socket command	
	
	new hltv_challenge[13]	// Contains the hltv rcon challenge number

	// Set hltv rcon password
	hltv_set_password()
	
	// Connect to the HLTV Proxy
	socket_address = socket_open(hltv_ip, hltv_port, SOCKET_UDP, socket_error)
	
	
	// Send challenge rcon and receive response
	// Do NOT add spaces after the commas, you get an error about invalid function call
	setc(send, 4, 0xff)
	copy(send[4], 255, "challenge rcon")
	setc(send[18], 1, '^n')
	socket_send(socket_address, send, 255)
	socket_recv(socket_address, receive, 255)	
	
	
	// Get hltv rcon challenge number from response
	copy(hltv_challenge, 12, receive[19])
	replace(hltv_challenge, 255, "^n", "")
			
	// Set rcon command
	setc(send, 255, 0x00)
	setc(send, 4, 0xff)
	
	format(send[4],255,"rcon %s %s %s^n",hltv_challenge, hltv_password, hltv_command)
	
	// Send rcon command and close socket
	socket_send(socket_address, send, 255)
	socket_close(socket_address)
	
	
	return PLUGIN_CONTINUE
}

public hltv_set_password()
{
	new left[64]
	new right[64]
	new hltv_rconLen
	

    server_print("* [ECS TOURNAMENT] Setting HLTV Password Successfully!")
    copy(hltv_password,63,"ecsrocks555")
	
	
	return PLUGIN_CONTINUE
}



/*
*	STOCKS
*
*/
//For color chat

stock ColorChat(const id, const input[], any:...) 
{ 
    new count = 1, players[32]; 
    static msg[191]; 
    vformat(msg, 190, input, 3); 
    
    replace_all(msg, 190, "!y", "^x01");
    replace_all(msg, 190, "!g", "^x04");     
    replace_all(msg, 190, "!t", "^x03");
    
    if (id) players[0] = id; else get_players(players, count, "ch"); { 
        for (new i = 0; i < count; i++) 
        { 
            if (is_user_connected(players[i])) 
            { 
                message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i]); 
                write_byte(players[i]); 
                write_string(msg); 
                message_end(); 
            } 
        } 
    } 
}