#!/bin/bash
# NOKICKOUT
# ---------

# Author: Marco A. Villena (@)
# Date: 2023 - 2024


version="2.0"

if [ -z $1 ]; then
    dela=600

    clear
    echo -e "\e[0;95m**** NO KICK OUT ****\e[0m\nVersion $version\n"
    
    while true; do
	date
	sleep $dela
    done

elif [ $1 = '-w' ]; then
    dela=0.2
    search_dir=$HOME/My_scripts/frames
    while true; do
	for entry in "$search_dir"/*; do
	    clear
	    echo -e "\e[0;95m**** NO KICK OUT ****\e[0m\nVersion $version\n"
	    $entry
	    sleep $dela
	done
    done
fi

