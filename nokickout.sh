#!/bin/bash
# NOKICKOUT
# ---------
# Author: Marco A. Villena (mavillena@ugr.es)
# Date: 2023 - 2026

# Version
version="3.0"

# Colors
PURPLE='\e[0;95m'
GREEN='\e[0;92m'
RED='\e[0;91m'
REDYELLOW='\e[41;93m'
NC='\e[0m'

# Frames folder
FRAME_DIR="$HOME/bin/frames"

if [ -z $1 ]; then
    dela=60 # Refresh delay

    clear
    echo -e "${PURPLE}**** NO KICK OUT ****${NC}\nVersion $version"
    echo -e "\n${RED}Press Ctrl+c to exit.\n${NC}"
    
    while true; do
		echo $(TZ="Europe/Madrid" date) # "+%Y-%m-%d %H:%M:%S")
		sleep $dela
    done

elif [ $1 = '-w' ]; then
    # Check if directory exists
    if [ ! -d "$FRAME_DIR" ]; then
		echo -e "${REDYELLOW}ERROR: directory '$FRAME_DIR' does not exist.\n${NC}"
		exit 1
    fi
    
    dela=0.2 # Refresh delay
    while true; do
		for frame in "$FRAME_DIR"/*.frm; do
	    	[ -e "$frame" ] || echo -e "${REDYELLOW}ERROR: Frames files not found.\n${NC}", exit 1  # Skip if no *.frm files
	    
	    	clear
	    	echo -e "${PURPLE}**** NO KICK OUT ****\e[0m\nVersion $version\n"
	    	echo -e "${GREEN}"
	    	cat "$frame"
	    	echo -e "\n${RED}Press Ctrl+c to exit.${NC}"
	    	sleep $dela
		done
    done
fi
