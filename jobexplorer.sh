#!/bin/bash
# JOBEXPLORER
# -----------
# Author: Marco A. Villena (mavillena@ugr.es)
# Date: 2020 - 2026

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
	echo -e "8 - Users and jobs (slow)"
	echo -e "0 - Exit\e[0m"
	echo " "
	echo -n "Select one option [1-6,0]: "
	read option
	echo " "

	case $option in
	1) echo -e "\n\e[0;95m**** LIST OF JOBS STATUS ****\e[0m\n"
	   echo -e "\e[0;92m$(squeue -u $USER -r -l -O jobid,name,state,timeused,Account,Reason)\e[0m"
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
	   # Define the states of interest
	   STATES_OF_INTEREST=("RUNNING" "PENDING" "COMPLETING")
	   OTHER_STATES=("BOOT_FAIL" "CANCELLED" "COMPLETED" "CONFIGURING" "DEADLINE" "FAILED" "NODE_FAIL" "OUT_OF_MEMORY" "PREEMPTED" "RESV_DEL_HOLD" "REQUEUE_FED" "REQUEUE_HOLD" "REQUEUED" "RESIZING" "REVOKED" "SIGNALING" "SPECIAL_EXIT" "STAGE_OUT" "STOPPED" "SUSPENDED" "TIMEOUT")

	   # Variable for storing counters: user_status -> quantity
	   declare -A job_counts

	   # Variable for storing unique users
	   declare -A users

	   # Capture squeue output into variable
	   squeue_output=$(squeue -o %u,%T 2>/dev/null)

	   # Process line by line (skipping headers)
	   while IFS=',' read -r user state; do
	       # Skip header line
	       if [[ "$user" == "USER" ]]; then
		   continue
	       fi

	       # Remove blank spaces
	       user=$(echo "$user" | xargs)
	       state=$(echo "$state" | xargs)

	       # Mark user as read
	       users["$user"]=1

	       # Count in the appropriate category
	       if [[ " ${STATES_OF_INTEREST[@]} " =~ " ${state} " ]]; then
		   ((job_counts["${user}_${state}"]++))
	       else
		   ((job_counts["${user}_OTHER"]++))
	       fi
	   done <<< "$squeue_output"

	   # Sort users
	   printf '%s\n' "${!users[@]}" | sort > /tmp/users_sorted.tmp
	   mapfile -t sorted_users < /tmp/users_sorted.tmp
	   rm /tmp/users_sorted.tmp

	   # Print table header
	   printf "%-20s %10s %10s %12s %10s\n" "USER" "RUNNING" "PENDING" "COMPLETING" "OTHER"
	   printf "%s\n" "$(printf '%.0s-' {1..66})"

	   # Print rows
	   for user in "${sorted_users[@]}"; do
	       running=${job_counts["${user}_RUNNING"]:-0}
	       pending=${job_counts["${user}_PENDING"]:-0}
	       completing=${job_counts["${user}_COMPLETING"]:-0}
	       other=${job_counts["${user}_OTHER"]:-0}

	       printf "%-20s %10d %10d %12d %10d\n" "$user" "$running" "$pending" "$completing" "$other"
	   done

	   # Separation line
	   printf "%s\n" "$(printf '%.0s-' {1..66})"

	   # Totals
	   total_running=0
	   total_pending=0
	   total_completing=0
	   total_other=0

	   for key in "${!job_counts[@]}"; do
	       if [[ "$key" == *"_RUNNING" ]]; then
		   ((total_running += job_counts[$key]))
	       elif [[ "$key" == *"_PENDING" ]]; then
		   ((total_pending += job_counts[$key]))
	       elif [[ "$key" == *"_COMPLETING" ]]; then
		   ((total_completing += job_counts[$key]))
	       elif [[ "$key" == *"_OTHER" ]]; then
		   ((total_other += job_counts[$key]))
	       fi
	   done

	   printf "%-20s %10d %10d %12d %10d\n" "TOTAL" "$total_running" "$total_pending" "$total_completing" "$total_other"
	   read foo;;

	0) echo -e "\nHave a good day!\n"
	   exit 1;;

	*) echo " "
	   echo -e "\n\e[41;93m$option is an invalid option. Please, try again!\e[0m"
	   read foo;;
	esac
done
