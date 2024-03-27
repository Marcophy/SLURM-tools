#!/bin/bash
# JOBEXPLORER
# -----------

# Author: Marco A. Villena (@)
# Date: 2020 - 2024


version="6.0"

while :
do
	clear
	echo -e "\e[0;95m#### JOBS EXPLORER ####\nVersion $version\n"
	echo -e "\e[0;33m OPTIONS"
	echo "---------"
	echo -e "1 - Display status of your jobs"
	echo -e "2 - Check in loop"
	echo -e "3 - Cancel a job"
	echo -e "4 - Cancel all jobs"
	echo -e "5 - Jobs folders"
	echo -e "6 - Jobs record"
	echo -e "7 - Job statistic"
	echo -e "8 - Users and jobs"
	echo -e "0 - Exit\e[0m"
	echo " "
	echo -n "Select one option [1-6,0]: "
	read option
	echo " "

	case $option in
	1) echo -e "\n\e[0;95m**** LIST OF JOBS STATUS ****\e[0m\n"
	   echo -e "\e[0;92m$(squeue -u $USER -r -l -O jobid,name,state,timeused,EndTime,Account)\e[0m"
	   read foo;;

	2) echo -e "\n\e[0;95m**** LOOP SCAN ****\e[0m\n"
            echo -n "Refresh rate (seconds): "
            read dela
            while true; do
                clear
                echo -e "\e[0;32m$(squeue -u $USER -l -O jobarrayid,name,state,timeused)"

                echo -e "\n\e[0;91mPress Ctrl+c to exit.\e[0m"
                sleep $dela
            done
            read foo;;
	    
	3) echo -e "\n\e[0;95m**** CANCEL A JOB ****\e[0m\n"
	   echo -e "\e[0;92m$(squeue -u $USER -r -l -O jobid,jobarrayid,name,state,timeused)\e[0m\n"
	   echo -n "Write the ID of the job (C-Cancel): "
	   read jcancel
	   if [ $jcancel = "C" ]; then
	       echo -e "\nOPERATION CANCELLED. Press enter to continue.\n"
	   else
	       if grep -q "$jcancel" <<< "$(squeue -r -u $USER --jobs $jcancel -l -O jobid,jobarrayid)"; then
		   echo -e "\nAre you sure you want to cancel the job \e[0;33m$jcancel\e[0m?"
		   select QCON in "YES" "NO"; do
	       	       case $QCON in
			   YES)
			       scancel $jcancel
			       echo -e "\nJob ID = $jcancel cancelled successfully"
			       break;;
			   NO)
			       echo -e "\nJob NO cancelled"
			       break;;
		       esac
		   done
	       else
		   echo -e "\e[41;93mERROR! The jobID $jcancel does not match any submitted jobs.\e[0m\n"
	       fi
	   fi
	   read foo;;
	
	4) echo -e "\n\e[0;95m**** CANCEL ALL JOBS ****\e[0m\n"
	   echo "Are you sure you want to cancel all your jobs in squeue?"
	   select QCON in "Yes" "No"; do
	       case $QCON in
		   Yes)
		       scancel -u $USER
		       echo "Jobs canceled"
		       break;;
		   No)
		       echo "Jobs NO cancelled"
		       break;;
	       esac
	   done
	   read foo;;

	5) echo -e "\n\e[0;95m**** JOBS FOLDER ****\e[0m\n"
	   echo -e "\e[0;92m$(squeue -u $USER -o %i,%j,%Z)\e[0m"
	   read foo;;

	6) echo -e "\n\e[0;95m**** JOBS RECORDS ****\e[0m\n"
	   sacct -u $USER
	   read foo;;

	7) echo -e "\n\e[0;95m**** JOB STATISTIC ****\e[0m\n"
	   echo -e "\e[0;92m$(squeue -u $USER -l -O jobid,jobarrayid,name,state,timeused,nodelist)\e[0m\n"
	   echo -n "Write the ID of the job: "
	   read jstat
	   echo " "
	   sstat $jstat
	   read foo;;

	8) echo -e "\n\e[0;95m**** USERS AND THEIR JOBS ****\e[0m\n"
	   name_list=$(squeue -O UserName)
	   name_list="${name_list#* }"

	   declare -A counter

	   for name in $name_list; do
	       ((counter[$name]++))
	   done

	   echo -e "\e[0;92mUSER: Submitted jobs"
	   echo -e "--------------------\e[0m"
	   for name in "${!counter[@]}"; do
	       echo -e "$name: ${counter[$name]}"
	   done
           read foo;;

	0) echo -e "\nHave a good day!\n"
	   exit 1;;

	*) echo " "
	   echo -e "\n\e[41;93m$option is an invalid option. Please, try again!\e[0m"
	   read foo;;
	esac
done
