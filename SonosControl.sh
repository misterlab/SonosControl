#!/bin/bash

LOCKFILE=/tmp/$(basename $0).lock
LOGFILE=/var/log/$(basename $0).log
LOGGING=1 # 0 = no logging, 1 = logging

trap " [ -f $LOCKFILE ] && /bin/rm -f $LOCKFILE" 0 1 2 3 13 15 

: ${1?"Usage: $0 (play|pause|TTS}"}

# location of dropbox
DROPBOX=/Users/tobycole/Dropbox
# location of soco
SOCO=/usr/local/opt/SoCo

# dynamically discover zone ip's and build array
IFS="', '" read -a SONOSHOSTS <<< `$SOCO/sonoshell.py 1.1.1.1 discover | sed 's/^\[\(.*\)\]$/\1/'`
SONOSUID=()

# array where current player state is stored
CURRENTSTATEFILE=$DROPBOX/IFTTT/SonosControl/.sonos.currentstate
OCCUPANCYDIR=$DROPBOX/IFTTT/SonosControl/Occupancy

# TTS
TTSVOL=55 # volume to play TTS at
TTSFILE=$2
TTSSOURCEDIR=$DROPBOX/IFTTT/SonosControl/tts
TTSTARGETDIR=/Library/WebServer/Documents/xfer/tts
TTSURL=http://mrlab.co.uk/xfer/tts

# array helper function
containsElement () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

# builds an array of zone UID's to check when playing/bonding zones
function getUID {
    for i in ${SONOSHOSTS[@]}; do
    	current_speaker_info=`$SOCO/sonoshell.py $i get_speaker_info`
		SONOSUID+=(`echo $current_speaker_info|jsawk 'return this.uid'`)
	done
}

# persists player state to file
# ip|PLAYING_STATE|uid|uri_being_played|play_position|volume
#
function currentState {
    if ([ -e $CURRENTSTATEFILE ] && test `find "$CURRENTSTATEFILE" -mmin +2`) || [ ! -e $CURRENTSTATEFILE ]; then
    # remove current state file
    rm -f $CURRENTSTATEFILE

    # get current state before pausing
    for i in ${SONOSHOSTS[@]}; do
    
	    # find out what's currently playing
		current_track_info=`$SOCO/sonoshell.py $i get_current_track_info`
		current_speaker_info=`$SOCO/sonoshell.py $i get_speaker_info`
		
		SONOSUID+=`echo $current_speaker_info|jsawk 'return this.uid'`
		
		uri=`echo $current_track_info|jsawk 'return this.uri'`
		# fix for soundcloud - strips trailing &flags=32 resulting in 402 response
		uri=`echo ${uri%&*}`
		playlist_position=`echo $current_track_info|jsawk 'return this.playlist_position'`
		uid=`echo $current_speaker_info|jsawk 'return this.uid'`
		
		# find out if zone is playing
		cts=`$SOCO/sonoshell.py $i get_current_transport_info|grep current_transport_state`
		cts=${cts:25:${#cts}}
		
		volume=`$SOCO/sonoshell.py $i getvolume`
		mute=`$SOCO/sonoshell.py $i getmute`
		
		# persist to state file
		echo $i"|"$cts"|"$uid"|"$uri"|"$playlist_position"|"$volume"|"$mute >> $CURRENTSTATEFILE
	
    done
    fi
}

# function to resume playing status from persistent state file
function NEWresumeCurrent {
	# get array of zone uid's to check bonding against
	getUID

    # reset mute status for zones
    #	
    # parse current player state
    while read line; do
      	IFS='|' read -a array <<< "$line"
      	
    	# reset volume
    	if [ ${array[5]} != "100" ]; then
	         $SOCO/sonoshell.py ${array[0]} setvolume ${array[5]}
        fi
        
	# reset mute status
        if [ ${array[6]} == "0" ]; then
			$SOCO/sonoshell.py ${array[0]} muteoff
		else 
			$SOCO/sonoshell.py ${array[0]} muteon
       	fi
    done < $CURRENTSTATEFILE

    # unjoin zones that weren't playing previously
    #
    # parse current player state
    while read line; do
      	IFS='|' read -a array <<< "$line"
      	
	# if zone was STOPPED, then unjoin from any groups
        if [ ${array[1]} == "STOPPED" ]; then
			$SOCO/sonoshell.py ${array[0]} unjoin 
			$SOCO/sonoshell.py ${array[0]} clear_queue 
            # this needs fixing - only add to queue if something exists in array
            #echo ${array[3]}
		if test "${array[3]+isset}"; then
			$SOCO/sonoshell.py ${array[0]} add_to_queue ${array[3]} 
		fi
       	fi
    done < $CURRENTSTATEFILE

	# play whatever zone was previously playing
	#
	# parse current player state
    while read line; do
      	IFS='|' read -a array <<< "$line"

        # if zone is PLAYING
        if [ ${array[1]} == "PLAYING" ]; then
        
            # play content
            
        	# if zone is joined with another then don't process- x-rincon:RINCON
        	if ! containsElement "${array[3]#x-rincon:}" "${SONOSUID[@]}"; then

	        	# reset volume
	        	if [ ${array[5]} != "100" ]; then
		            $SOCO/sonoshell.py ${array[0]} setvolume ${array[5]}
	            fi
        	fi
	            
	        # start playing again
            	$SOCO/sonoshell.py ${array[0]} play_uri ${array[3]}
        fi
    done < $CURRENTSTATEFILE

	# re-group zones that were grouped (after we've started playing the master zone)
	#
	# parse current player state
    while read line; do
      	IFS='|' read -a array <<< "$line"
      	
		# if zone is PLAYING (in a group)
        if [ ${array[1]} == "PLAYING" ]; then
        
            # play content
        
        	# re-group zone if it was previously joined with another - x-rincon:RINCON
        	if containsElement "${array[3]#x-rincon:}" "${SONOSUID[@]}"; then
        	
	        	# reset volume
	        	if [ ${array[5]} != "100" ]; then
		            $SOCO/sonoshell.py ${array[0]} setvolume ${array[5]}
	            fi
	            
	            # re-group with master zone
            	$SOCO/sonoshell.py ${array[0]} join ${array[3]#x-rincon:}
        	fi
        fi
    done < $CURRENTSTATEFILE
}


# function to pause zones that are playing
function pauseCurrent {
    while read line; do
		IFS='|' read -a array <<< "$line"
		if [ ${array[1]} == "PLAYING" ]; then
          	$SOCO/sonoshell.py ${array[0]} pause 
		fi
    done < $CURRENTSTATEFILE
}

# function to resume zones that were playing
function resumeCurrent {
    while read line; do
		IFS='|' read -a array <<< "$line"
		if [ ${array[1]} == "PLAYING" ]; then
          	$SOCO/sonoshell.py ${array[0]} play 
		fi
    done < $CURRENTSTATEFILE
}

function log {
    if [ "$LOGGING" -eq "1" ]; then
    echo "`date +%Y.%m.%d-%H:%M:%S` [$$] $*" >> $LOGFILE
    fi
}

#
# main processing logic
#

log creating lockfile
lockfile -r -1 -l 300 $LOCKFILE

if [ $1 == "play" -o $1 == "PLAY" ]; then
log play command
    if [ ! -z "$2" ]; then 

        # if someone is in the house, don't play
        if [ "$(ls -A $OCCUPANCYDIR)" ]; then
log other occupants, not playing
            echo other occupants in house, not playing
            touch $OCCUPANCYDIR/$2.txt
            exit 0
        else
log no other occupants, should play
            touch $OCCUPANCYDIR/$2.txt
            CURRENTSTATEFILE="$CURRENTSTATEFILE.$2"
        fi
    fi 

log resuming play
    NEWresumeCurrent

elif [ $1 == "pause" -o $1 == "PAUSE" ]; then
    if [ ! -z "$2" ]; then
        CURRENTSTATEFILE="$CURRENTSTATEFILE.$2"
        currentState

        # delete occupier who is leaving before checking occupancy
        rm -f $OCCUPANCYDIR/$2.txt


	# if someone is in the house, don't pause
        if [ "$(ls -A $OCCUPANCYDIR)" ]; then
            exit 0
        fi
    fi

    # don't get current state if it has been stored within last 15 mins
    currentState

    # pause zones based on current state
    pauseCurrent

    exit 0
elif [ $1 == "TTS" ]; then # Perform text to speech
	# Set tts state file
	CURRENTSTATEFILE="$CURRENTSTATEFILE.tts"

	# ask google translate to produce TTS mp3 of file, and download
	wget -q -U Mozilla -O $TTSTARGETDIR/$(basename "$TTSFILE").mp3 "http://translate.google.com/translate_tts?tl=en&q=`cat $TTSFILE`"

	if [ -e "$TTSTARGETDIR/$(basename "$TTSFILE").mp3" ]; then
	# Persist current state
	currentState

	# Stop node 1 from playing and bond all other zones in partymode
	$SOCO/sonoshell.py ${SONOSHOSTS[1]} stop
	$SOCO/sonoshell.py ${SONOSHOSTS[1]} partymode

	# unMute and set volume
	for i in ${SONOSHOSTS[@]}; do
    		$SOCO/sonoshell.py $i muteoff
    		$SOCO/sonoshell.py $i setvolume $TTSVOL
	done

	# play tts file
	$SOCO/sonoshell.py ${SONOSHOSTS[1]} play_uri $TTSURL/$(basename "$TTSFILE").mp3

	# poll zone until stopped playing tts
	cts=PLAYING
	until [ "$cts" == "STOPPED" ]; do
		# find out if zone is playing
		cts=`$SOCO/sonoshell.py ${SONOSHOSTS[1]} get_current_transport_info|grep current_transport_state`
		cts=${cts:25:${#cts}}
		#echo $cts
		sleep 1
	done
	
    $SOCO/sonoshell.py ${SONOSHOSTS[1]} clear_queue

	# delete tts file
	rm $TTSTARGETDIR/$(basename "$TTSFILE").mp3

	NEWresumeCurrent
	fi
elif [ $1 == "test" ]; then
	echo "testing"
	
	# find out what's currently playing
	#tmp=`$SOCO/sonoshell.py $OFFICE get_current_track_info`
	#IFS=', ' read -a array <<< "$tmp"
	#uri=${array[7]:1:${#array[7]}-2}
	#playlist_position=${array[7]:1:${#array[7]}-2}
	#echo `$SOCO/sonoshell.py $OFFICE get_current_transport_info|grep current_transport_state|cut -c26-32`
	
	#NEWcurrentState
	#NEWresumeCurrent
else
    echo "Usage: $0 (play|pause|tts)"
fi

