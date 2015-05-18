#
#   Copyright (C) 2010  Jan Hoeppner ( hoeppner.jan@xurv.org )
#   http://xurv.org/ - #xurv on QuakeNet
#
#   Description:
#	Quakelive Statistics (qlstats.tcl) is used to get
#	some informations about playerstatistics from
#    	http://quakelive.com/ .
#
#   Usage: +ql <playername>   Displays a summary of playerstatistics
#	   +ql [option] <playername>
#
#   Options:
#       -last     Displays statistics of the recent match (result, scores, accuracy, etc.)
#	-status   Does inform you about Quakelive.com online/offline status
#	-help     Shows this help
#
#   Requirements:
#	Tcl >=8.5
#	fsck 1.17 (get it from http://perplexa.ugug.org/web/projects/)
#
#   License:
#
#   This program is free software; you can redistribute it and/or
#   modify it under the terms of the GNU General Public License
#   as published by the Free Software Foundation; either version 2 of the License,
#   or (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#   GNU General Public License for more details.
#
#   The GPL is written down at http://www.gnu.org/copyleft/gpl.html
#

package require Tcl 8.5;
package require fsck 1.17;
package require http;
package require json;

namespace eval qlstats {

    variable version "2.11";
    variable agent "Mozilla/5.0 (X11; U; Linux i686; en-GB; rv:1.8.1) Gecko/2006101023 Firefox/3.0";
    variable encoding "utf-8";
    variable trigger "+";

    bind pub -|- ${trigger}ql [namespace current]::requesthandle;

}

proc qlstats::requesthandle {nick host hand chan argv} {

    variable flood

    # flood protection
    if {![info exist flood($chan)]} {set flood($chan) 0;}
    if {[unixtime] - $flood($chan) <= 6} {
        putquick "NOTICE $nick :Please wait...only one request every 6 seconds allowed";
        return 0;
    }
    set flood($chan) [unixtime];

    # check if input is empty or at least a playername is given
    set usage_out "Not enough parameters. Usage: +ql \[-last|-status|-help\] <playername>";
    set argv [string trim $argv];
    if { $argv == ""} {
        putquick "NOTICE $nick :$usage_out";
        return 0;
    }
    if {[regexp -- {^-last$} [getword $argv 0]]} {
        if {[getword $argv 1] == ""} {
            putquick "NOTICE $nick :$usage_out";
            return 0;
        }
    }
    # filter playername
    set player [string tolower [regsub -- {(-last\s+)} $argv ""]];
    # check which informations are requested
    # 1st check if there is only the playername requested
    if {![regexp -- {^[^_[:alnum:]]} [getword $argv 0]]} {
        getSummary $player $chan;
    }
    # 2nd check if option for lastmatch, lastacc or overall acc information is requested
    switch -regexp [getword $argv 0] {
        ^-last$ { getLastMatch $player $chan; }
        #^-lastteams$ { getLastTeams $player $chan; }
        ^-status$ { status $chan; }
        ^-help$ { getHelp $nick $chan; }
        ^-. { putquick "NOTICE $nick :$usage_out"; }
    }
}

proc qlstats::getHelp {nick chan} {
    variable version
    putquick "NOTICE $nick :QuakeLive Statistics $version by Jan 'smove' Hoeppner";
    putquick "NOTICE $nick :QLStats provides several statistics taken from http://quakelive.com/";
    putquick "NOTICE $nick : ";
    putquick "NOTICE $nick :Usage:  +ql <playername>   Displays a summary of playerstatistics";
    putquick "NOTICE $nick :        +ql \[option\] <playername>";
    putquick "NOTICE $nick : ";
    putquick "NOTICE $nick :Options:";
    putquick "NOTICE $nick :         -last     Displays statistics of the latest match a player had (result, scores, accuracy, etc.)";
    putquick "NOTICE $nick :         -status   Does inform you about Quakelive.com online/offline status";
    putquick "NOTICE $nick :         -help     Displays this help";
    putquick "NOTICE $nick : ";
    putquick "NOTICE $nick :Source available at https://github.com/hjan/qlstats";
}

proc qlstats::status {chan} {
    set pageData [httpquery http://www.quakelive.com/];
    if {[regexp -all -- {<title>QUAKE LIVE is offline for maintenance...</title>} $pageData]} {
        putquick "PRIVMSG $chan :Quakelive is currently down. Join #quakelive for further informations. Quakelive will be back soon hopefully.";
        return 0;
    } else {
        putquick "PRIVMSG $chan :Quakelive is online. Enjoy the Game.";
    }
}

proc qlstats::getSummary {player chan} {

    set player_data [httpquery http://www.quakelive.com/profile/statistics/$player];
    if {![playerstatus $player $player_data $chan]} {
        return 0;
    }

    #
    # get overall statistics
    #
    regexp -all -- {<b>Accuracy:</b> (.*?)<br />} $player_data mAcc rAcc;
    regexp -all -- {<b>Hits / Shots:</b> (.*?)<br />} $player_data mHits rHits;
    regexp -all -- {<b>Frags / Deaths:</b> (.*?)<br />} $player_data mFrags rFrags;
    regexp -all -- {<b>Wins:</b> (.*?)<br />} $player_data mWin rWin;
    regexp -all -- {<b>Losses / Quits:</b> (.*?)<br />} $player_data mLoss rLoss;
    regexp -all -- {<div class=\"col_st_played\">(.*?)</div>} $player_data mTotal rTotal;
    regexp -all -- {<span class=\"text_tooltip\" title=\"Ranked Time: (.*?) Unranked} $player_data mRankedTime rRankedTime;
    regexp -all -- {Unranked Time: (.*?)\">} $player_data mUnrankedTime rUnrankedTime;

    # seperate hits and shots and filter , and / to calculate the acc with 2 chars after comma
    set hits [lrange [split [regsub -all -- {,|/} $rHits ""] " "] 0 0];
    set shots [lrange [split [regsub -all -- {,|/} $rHits ""] " "] 2 2];
    set acc_all [string range [expr (100.0 * $hits) / $shots] 0 4];

    # seperate frags and deaths and filter , and / to calculate the ratio with 2 chars after comma
    set frags [lrange [split [regsub -all -- {,|/} $rFrags ""] " "] 0 0];
    set deaths [lrange [split [regsub -all -- {,|/} $rFrags ""] " "] 2 2];
    set fdratio [string range [expr $frags.0 / $deaths.0] 0 3];

    # get wins and losses and filter , and / to calculate the ratio with 2 chars after comma
    set losses [lrange [split [regsub -all -- {,|/} $rLoss ""] " "] 0 0];
    set wins [regsub -all -- {,} $rWin ""];
    set wlratio [string range [expr $wins.0 / $losses.0] 0 3];

    # convert US format into EU format (1,000.0 -> 1.000,1)
    set rHits [regsub -all -- {,} $rHits "."];
    set rFrags [regsub -all -- {,} $rFrags "."];
    set rWin [regsub -all -- {,} $rWin "."];
    set rLoss [regsub -all -- {,} [lrange [split [regsub -all -- {/} $rLoss ""] " "] 0 0] "."];
    set rTotal [regsub -all -- {,} $rTotal "."];

    set acc_all [regsub -all -- {\.} $acc_all ","];
    set fdratio [regsub -all -- {\.} $fdratio ","];
    set wlratio [regsub -all -- {\.} $wlratio ","];

    #
    # get weapon overall accuracy/usage
    #

    set weaponsAcc [regexp -all -inline -- {<span class=\"text_tooltip\">(.*?)</span>} $player_data];

    # prepare list cause of missing GT accuracy
    set acc [list N/A N/A];
    foreach {match result} $weaponsAcc {
        lappend acc $result;
    }

    set weaponsUsage [regexp -all -inline -- {<div class=\"col_usage\">(.*?)</div>} $player_data];
    foreach {match result} $weaponsUsage {
        lappend usage $result;
    }

    set weaponsOverallList [list \0030GT\003 \0038MG\003 \0035SG\003 \0033GL\003 \0034RL\003 \0030LG\003 \0033RG\003 \0036PG\003];
    set i 1;
    foreach weaponColor $weaponsOverallList {
        lappend weaponsOverallStats "$weaponColor [lrange $acc $i $i] ([lrange $usage $i $i])";
        incr i;
    }
    set weaponsOverallStats [join $weaponsOverallStats " \002|\002 "];

    putquick "PRIVMSG $chan :\002Accuracy (Hits/Shots):\002 $acc_all% ($rHits) \002Frags / Deaths (Ratio):\002 $rFrags ($fdratio)";
    putquick "PRIVMSG $chan :\002Wins / Losses (Ratio):\002 $rWin / $losses ($wlratio) \002Total played:\002 $rTotal \002Time played Ranked / Unranked:\002 $rRankedTime / $rUnrankedTime";
    putquick "PRIVMSG $chan :\002Weapons:\002 $weaponsOverallStats";

}

proc qlstats::getLastMatch {player chan} {

    set player_data [httpquery http://www.quakelive.com/profile/summary/$player];
    if {![playerstatus $player $player_data $chan]} {
        return 0;
    }

    #
    # Figure out which gameID and gameType the
    # last match was a player played.
    #
    # After that, query quakelive.com to receive match data.
    #
    set gtype [lrange [split [lrange [regexp -inline -- {class=\"prf_map recent_match interactive\" id=\"(.*?)\">} $player_data] 1 1] _ ] 0 0];
    set gid [lrange [split [lrange [regexp -inline -- {class=\"prf_map recent_match interactive\" id=\"(.*?)\">} $player_data] 1 1] _ ] 1 1]

    set data [httpquery http://www.quakelive.com/stats/matchdetails/$gid/$gtype];
    if {[regexp -all -- {>An Error Has Occurred</div>} $data]} {
        putquick "PRIVMSG $chan :An error has occurred while handling your request. It's not possible to receive any data.";
        return 0;
    }

    #
    # Parsing json feed from the received data.
    #
    set data [json::json2dict $data];

    #
    # Check if gamestats are really available.
    # Sometimes they don't. o0
    #
    if {[regexp -- {UNAVAILABLE} [dict keys $data]] && [dict get $data UNAVAILABLE] == 1} {
        putquick "PRIVMSG $chan :The requested gamedata is not available for public view at the moment. Try again later.";
        return 0;
    }

    #
    # Set TEAM, WINTEAM, weaponsStats to prevent empty var issues.
    #
    set TEAM "";
    set WINTEAM "";
    set weaponsStats "";
    set PLAYER_CLAN_NMY "";
    #
    # Set up list for weaponName & weaponColor
    #
    set weaponList [list GAUNTLET \0030GT\003 MACHINEGUN \0038MG\003 HMG \0038HMG\003 SHOTGUN \0035SG\003 GRENADE \0033GL\003 ROCKET \0034RL\003 LIGHTNING \0030LG\003 RAILGUN \0033RG\003 PLASMA \0036PG\003 BFG \0032BFG\003 CHAINGUN \00314CG\003 NAILGUN	\00310NG\003 PROXMINE \00313PM\003];

    #
    # Get informations about the game,
    # player, team and statistics by
    # parsing the available scoreboards.
    #

    #
    # TeamScoreboards
    #
    set typesOfScoreboard [list RED_SCOREBOARD_QUITTERS BLUE_SCOREBOARD_QUITTERS RED_SCOREBOARD BLUE_SCOREBOARD];

    foreach scoreBoard $typesOfScoreboard {
        if {[string bytelength [dict keys $data $scoreBoard]] > 0} {
            foreach value [dict get $data $scoreBoard] {
                if {[string tolower [dict get $value PLAYER_NICK]] == $player} {
                    foreach var [list TEAM RANK ACCURACY KILLS DEATHS SCORE PLAY_TIME PLAYER_CLAN] {
                        set $var [dict get $value $var];
                        set userTimePlayed [clock format [dict get $value PLAY_TIME] -format %M:%S];
                    }
                    foreach {weaponName weaponColor} $weaponList {
                        if {[dict get $value ${weaponName}_KILLS] != 0 || [dict get $value ${weaponName}_ACCURACY] != 0} {
                            lappend weaponsStats "$weaponColor [regsub -all -- {\.} [format %.1f [dict get $value ${weaponName}_ACCURACY]] ","]% ([dict get $value ${weaponName}_KILLS]) ([dict get $value ${weaponName}_HITS]/[dict get $value ${weaponName}_SHOTS])";
                        }
                    }
                    if {[regexp -nocase -- {(CTF)|(DOM)|(FCTF)|(HARVESTER)} $gtype]} {
                        foreach var [list CAPTURES DEFENDS ASSISTS DAMAGE_DEALT DAMAGE_TAKEN] {
                            set $var [dict get $value $var];
                        }
                    }
                    if {![regexp -nocase -- {(CTF)|(DOM)|(FCTF)|(HARVESTER)} $gtype]} {
                        foreach var [list IMPRESSIVE EXCELLENT DAMAGE_DEALT DAMAGE_TAKEN] {
                            set $var [dict get $value $var];
                        }
                    }
                    if {[regexp -nocase -- {(FT)} $gtype]} {
                        foreach var [list IMPRESSIVE EXCELLENT THAWS DAMAGE_DEALT DAMAGE_TAKEN] {
                            set $var [dict get $value $var];
                        }
                    }
                }
            }
        }
    }

    #
    # Get specified score information from a particular gametype
    #
    if {[regexp -- {TEAM_SCOREBOARD\s+} [dict keys $data]]} {
        foreach value [dict get $data TEAM_SCOREBOARD] {
            # TeamDeathMatch
            if {[regexp -nocase -- {(TDM)} $gtype]} {
                if {[dict get $value TEAM] == "Red"} {
                    set rscore [dict get $value SCORE];
                }
                if {[dict get $value TEAM] == "Blue"} {
                    set bscore [dict get $value SCORE];
                }
            }
            # ClanArena & FreezeTag
            if {[regexp -nocase -- {(CA)|(FT)} $gtype]} {
                if {[dict get $value TEAM] == "Red"} {
                    set rscore [dict get $value ROUNDS_WON];
                }
                if {[dict get $value TEAM] == "Blue"} {
                    set bscore [dict get $value ROUNDS_WON];
                }
            }
            # CaptureTheFlag & 1FlagCTF
            if {[regexp -nocase -- {(CTF)|(FCTF)} $gtype]} {
                if {[dict get $value TEAM] == "Red"} {
                    set rscore [dict get $value CAPTURES];
                }
                if {[dict get $value TEAM] == "Blue"} {
                    set bscore [dict get $value CAPTURES];
                }
            }
            # Domination
            if {[regexp -nocase -- {(DOM)|(HARVESTER)} $gtype]} {
                if {[dict get $value TEAM] == "Red"} {
                    set rscore [dict get $value SCORE];
                    set rcaptures [dict get $value CAPTURES];
                }
                if {[dict get $value TEAM] == "Blue"} {
                    set bscore [dict get $value SCORE];
                    set bcaptures [dict get $value CAPTURES];
                }
            }
        }
    }

    #
    # FFA/Duel Scoreboards
    #
    set noneTeamScoreBoards [list SCOREBOARD RACE_SCOREBOARD];
    foreach scoreBoard $noneTeamScoreBoards {
        if {[string bytelength [dict keys $data $scoreBoard]] > 0} {
            foreach value [dict get $data $scoreBoard] {
                if {[string tolower [dict get $value PLAYER_NICK]] == $player} {
                    foreach var [list RANK ACCURACY KILLS DEATHS SCORE IMPRESSIVE EXCELLENT PLAY_TIME PLAYER_CLAN DAMAGE_DEALT DAMAGE_TAKEN] {
                        set $var [dict get $value $var];
                    }
                    if { $scoreBoard != "RACE_SCOREBOARD" } {
                        foreach {weaponName weaponColor} $weaponList {
                            if {[dict get $value ${weaponName}_KILLS] != 0 || [dict get $value ${weaponName}_ACCURACY] != 0} {
                                lappend weaponsStats "$weaponColor [regsub -all -- {\.} [format %.1f [dict get $value ${weaponName}_ACCURACY]] ","]% ([dict get $value ${weaponName}_KILLS]) ([dict get $value ${weaponName}_HITS]/[dict get $value ${weaponName}_SHOTS])";
                            }
                        }
                    }
                    set userTimePlayed [clock format [dict get $value PLAY_TIME] -format %M:%S];
                }

                #
                # Get some informations about the opponent if it is Duel game.
                #
                if {[regexp -nocase -- {(Duel)} $gtype]} {
                    if {[string tolower [dict get $value PLAYER_NICK]] != "" && [string tolower [dict get $value PLAYER_NICK]] != $player} {
                        foreach var [list PLAYER_NICK PLAYER_CLAN ACCURACY KILLS DEATHS SCORE RANK] {
                            set ${var}_NMY [dict get $value $var];
                        }
                        if {$RANK_NMY < 1} {
                            set nmyQuitTimePlayed [clock format [dict get $value PLAY_TIME] -format %M:%S];
                        }
                    }

                    if {[string tolower [dict get $value PLAYER_NICK]] == "" && [string tolower [dict get $value PLAYER_NICK]] != $player} {
                        # If an enemy disconnects too fast after timelimit hits, Quakelive is sometimes
                        # not able to get his statistic. So there wont be any informations.
                        # Setting NMY vars to '-' as an workaround.
                        foreach var [list PLAYER_NICK ACCURACY KILLS DEATHS SCORE] {
                            set ${var}_NMY "-";
                        }
                    }
                }
                #
                # count the players in the SCOREBORAD to get the real number of players in the end of a game
                #
                set playerInScoreboard [llength [lappend items $value]];
            }
        }
    }

    set scoreBoardQuitters [list SCOREBOARD_QUITTERS RACE_SCOREBOARD_QUITTERS];
    foreach scoreBoard $scoreBoardQuitters {
        if {[string bytelength [dict keys $data $scoreBoard]] > 0} {
            foreach value [dict get $data $scoreBoard] {
                if {[string tolower [dict get $value PLAYER_NICK]] == $player} {
                    foreach var [list RANK ACCURACY KILLS DEATHS SCORE IMPRESSIVE EXCELLENT PLAY_TIME PLAYER_CLAN DAMAGE_DEALT DAMAGE_TAKEN] {
                        set $var [dict get $value $var];
                    }
                    if { $scoreBoardQuitters != "RACE_SCOREBOARD_QUITTERS" } {
                        foreach {weaponName weaponColor} $weaponList {
                            if {[dict get $value ${weaponName}_KILLS] != 0 || [dict get $value ${weaponName}_ACCURACY] != 0} {
                                lappend weaponsStats "$weaponColor [regsub -all -- {\.} [format %.1f [dict get $value ${weaponName}_ACCURACY]] ","]% ([dict get $value ${weaponName}_KILLS]) ([dict get $value ${weaponName}_HITS]/[dict get $value ${weaponName}_SHOTS])";
                            }
                        }
                    }
                    if {[regexp -nocase -- {(FFA)|(RR)|(RACE)} $gtype]} {
                        set userTimePlayed [clock format [dict get $value PLAY_TIME] -format %M:%S];
                    }
                }
            }
        }
    }

    #
    # Get additional information about the game
    #
    set mapName [dict get $data MAP_NAME];
    if {[regexp -nocase -- {(CA)|(TDM)|(CTF)|(DOM)|(FCTF)|(HARVESTER)} $gtype ]} { set WINTEAM [dict get $data WINNING_TEAM] };
    set gamePlaytime [dict get $data GAME_LENGTH_NICE];
    set gameTypeFull [dict get $data GAME_TYPE_FULL];
    set gamePast [dict get $data GAME_TIMESTAMP_NICE];

    #
    # Set matchresult value according to player rank info
    #
    if {$RANK < 1 || $RANK == "Q"} {
        set result "quit at $userTimePlayed";
    } elseif {$RANK > 1 && ![regexp -nocase -- {(CA)|(TDM)|(CTF)|(DOM)|(FCTF)|(HARVESTER)} $gtype] || $TEAM != $WINTEAM} {
        set result "lost";
    } elseif {$RANK == 1 || $TEAM == $WINTEAM} {
        set result "won";
    }
    #
    # Set the time an opponent played if
    # he had quitted the game before timelimit hits.
    #
    set QUITTIME_NMY ".";
    if {[info exists nmyQuitTimePlayed]} {
        set QUITTIME_NMY " (Quit: $nmyQuitTimePlayed).";
    }
    #
    # Figure out which stats to display
    # for the specified gametype.
    #
    set CTF_STATS "";
    if {[regexp -nocase -- {(CTF)|(DOM)|(FCTF)|(HARVESTER)} $gtype]} {
        set CTF_STATS "C: $CAPTURES D: $DEFENDS A: $ASSISTS";
    }
    set TDMCA_STATS "";
    if {[regexp -nocase -- {(TDM)|(CA)} $gtype]} {
        set TDMCA_STATS "I: $IMPRESSIVE E: $EXCELLENT";
    }
    set FT_STATS "";
    if {[regexp -nocase -- {(FT)} $gtype]} {
        set FT_STATS "I: $IMPRESSIVE E: $EXCELLENT T: $THAWS";
    }

    set teamModeStats "";
    if {![string length $CTF_STATS] == 0} {
        set teamModeStats $CTF_STATS;
    }
    if {![string length $TDMCA_STATS] == 0} {
        set teamModeStats $TDMCA_STATS;
    }
    if {![string length $FT_STATS] == 0} {
        set teamModeStats $FT_STATS;
    }

    set damageStats "\002Damage:\002 $DAMAGE_DEALT / $DAMAGE_TAKEN ([expr $DAMAGE_DEALT - $DAMAGE_TAKEN])";

    #
    # Add clan-name to player-name if present
    #

    if {$PLAYER_CLAN != "None"} {
        set player "$PLAYER_CLAN $player";
    }

    if {[string length $PLAYER_CLAN_NMY] != 0 && $PLAYER_CLAN_NMY != "None"} {
        set PLAYER_NICK_NMY "$PLAYER_CLAN_NMY $PLAYER_NICK_NMY";
    }

    #
    # Figure out which gametype is specified
    # and display the right output.
    #
    if {[regexp -nocase -- {(Duel)} $gtype]} {
        puthelp "PRIVMSG $chan :\002$player\002 $result $gameTypeFull on $mapName $gamePast ago versus ${PLAYER_NICK_NMY}$QUITTIME_NMY";
        puthelp "PRIVMSG $chan :\002Scores:\002 $SCORE\:$SCORE_NMY \002Stats:\002 A: $ACCURACY% K/D: $KILLS/$DEATHS I: $IMPRESSIVE E: $EXCELLENT $damageStats";
    } elseif {[regexp -nocase -- {(FFA)|(RR)} $gtype]} {
        puthelp "PRIVMSG $chan :\002$player\002 $result $gameTypeFull on $mapName $gamePast ago. \002Rank:\002 $RANK of $playerInScoreboard";
        puthelp "PRIVMSG $chan :\002Scores:\002 $SCORE \002Time played:\002 $userTimePlayed of $gamePlaytime Min. \002Stats:\002 A: $ACCURACY% K/D: $KILLS/$DEATHS I: $IMPRESSIVE E: $EXCELLENT $damageStats";
    } elseif {[regexp -nocase -- {(CA)|(TDM)|(CTF)|(FT)|(FCTF)} $gtype]} {
        puthelp "PRIVMSG $chan :\002$player\002 $result $gameTypeFull on $mapName $gamePast ago with team $TEAM. \002Duration:\002 ${gamePlaytime}min";
        puthelp "PRIVMSG $chan :\002Scores:\002 (\0034Red\003) $rscore\:$bscore (\0032Blue\003) \002Stats:\002 A: $ACCURACY% S: $SCORE K/D: $KILLS/$DEATHS ([expr $KILLS - $DEATHS]) $teamModeStats $damageStats";
    } elseif {[regexp -nocase -- {(DOM)|(HARVESTER)} $gtype]} {
        puthelp "PRIVMSG $chan :\002$player\002 $result $gameTypeFull on $mapName $gamePast ago with team $TEAM. \002Duration:\002 ${gamePlaytime}min";
        puthelp "PRIVMSG $chan :\002Scores:\002 (\0034Red\003) $rscore ($rcaptures):\($bcaptures) $bscore (\0032Blue\003) \002Stats:\002 A: $ACCURACY% S: $SCORE K/D: $KILLS/$DEATHS ([expr $KILLS - $DEATHS]) $teamModeStats $damageStats";
    } elseif {[regexp -nocase -- {(Race)} $gtype]} {
        puthelp "PRIVMSG $chan :\002$player\002 $result $gameTypeFull on $mapName $gamePast ago. \002Rank:\002 $RANK of $playerInScoreboard";
        puthelp "PRIVMSG $chan :\002Time:\002 [regsub -all -- {\.} [expr $SCORE / 1000.0] ","]s \002Time played:\002 $userTimePlayed of $gamePlaytime Min.";
    }

    #
    # Prepare weaponsStats for output
    #

    if {![regexp -nocase -- {(Race)} $gtype]} {
        if {![string length $weaponsStats] == 0} {
            set weaponsStats [join $weaponsStats " \002|\002 "];
        } else {
            set weaponsStats "No weapon was used."
        }
        puthelp "PRIVMSG $chan :\002Weapons:\002 $weaponsStats";
    }
}

proc qlstats::playerstatus {player playerdata chan} {
    if {[string bytelength $playerdata] == 0} {
        putquick "PRIVMSG $chan :Request timeout. Please try again later.";
        return 0;
    }
    if {[regexp -all -- {<title>QUAKE LIVE is offline for maintenance...</title>} $playerdata]} {
        putquick "PRIVMSG $chan :Quakelive is currently down. Join #quakelive for further informations. Quakelive will be back soon hopefully.";
        return 0;
    }
    if {[regexp -all -- {Player not found:} $playerdata]} {
        putquick "PRIVMSG $chan :The requested player could not be found. Please check your spelling and try again.";
        return 0;
    }

    if {[regexp -all -- {<span title="">(.*?)months ago</span>} $playerdata]} {
        regexp -all -- {<span title="">(.*?)months ago</span>} $playerdata m monthAgo;
        set lastGame [expr $monthAgo / 12 * 365 * 24 * 360];
        set qlAvail [expr [unixtime] - [clock scan 2010-01-01 -format %Y-%m-%d -locale de_DE]];
        if {$lastGame > $qlAvail} {
            puthelp "PRIVMSG $chan :The statistics of \002$player\002 have been restored. No statistics available.";
            return 0;
        }
        return 1;
    }

    if {[regexp -all -- {Never played online} $playerdata]} {
        puthelp "PRIVMSG $chan :The player \002$player\002 never played a game. No statistics available.";
        return 0;
    }
    if {[regexp -all -- {>An Error Has Occurred</div>} $playerdata]} {
        puthelp "PRIVMSG $chan :Cannot receive any statistics of \002$player\002. Please try again later.";
        return 0;
    }
    if {![regexp -all -- {class=\"selected\">Statistics</a>} $playerdata]} {
        if {![regexp -all -- {class=\"prf_map recent_match interactive\" id=\"} $playerdata] && ![regexp -all -- {<div class=\"recent_match interactive firstrow\" id=\"} $playerdata]} {
            puthelp "PRIVMSG $chan :The player \002$player\002 does not have any recent matches.";
            return 0;
        }
    }
    return 1;
}

proc qlstats::httpquery {url} {
    variable agent
    variable encoding

    http::config -useragent $agent -urlencoding $encoding;
    if {[catch {http::geturl $url -method POST -timeout 20000} token]} {
        putlog "Error: $token";
    }
    set data [http::data $token];
    http::cleanup $token;
    return $data;
}

putlog "Script loaded: Quakelive Statistics (v$qlstats::version) by Jan 'smove' Hoeppner";
