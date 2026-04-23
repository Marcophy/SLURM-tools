#!/bin/bash
# JOBEXPLORER
# -----------
# Author: Marco A. Villena (mavillena@ugr.es)
# Date: 2020 - 2026

VERSION="6.3"

# Colors
PURPLE='\e[0;95m'
YELLOW='\e[0;33m'
GREEN='\e[0;92m'
RED='\e[0;91m'
REDYELLOW='\e[41;93m'
NC='\e[0m'

while :
do
        clear
        echo -e "${PURPLE}########## JOBS EXPLORER ##########\nVersion $VERSION\n- Author: Marco A. Villena\n- Email: mavillena@ugr.es\n"
        echo -e "${YELLOW} OPTIONS"
        echo "---------"
        echo -e "1 - Display status of your jobs"
        echo -e "2 - Check in loop"
        echo -e "3 - Cancel a job"
        echo -e "4 - Cancel all jobs"
        echo -e "5 - Jobs folders"
        echo -e "6 - Jobs record"
        echo -e "7 - Job statistic"
        echo -e "8 - Partition load (${RED}aprox.${YELLOW})"
        echo -e "9 - User and partition"
        echo -e "0 - User and jobs (${RED}slow${YELLOW})"
        echo -e "=================================="
        echo -e "e - Exit${NC}"
        echo " "
        echo -n "Select one option [1-9,0]: "
        read option
        echo " "

        case $option in
        1) echo -e "\n${PURPLE}**** LIST OF JOBS STATUS ****${NC}\n"
           echo -e "${GREEN}$(squeue -u $USER -r -l -O jobid,name,state,timeused,Account,Reason)${NC}"
           echo -e "\nPress ENTER to continue ..."
           read foo;;

        2) echo -e "\n${PURPLE}**** LOOP SCAN ****${NC}\n"
            echo -n "Refresh rate (seconds): "
            read dela
            while true; do
                clear
                echo -e "${GREEN}$(squeue -u $USER -l -O jobarrayid,name,state,timeused)"

                echo -e "\n${RED}Press Ctrl+c to exit.${NC}"
                sleep $dela
            done
            read foo;;

        3) echo -e "\n${PURPLE}**** CANCEL A JOB ****${NC}\n"
           echo -e "${GREEN}$(squeue -u $USER -r -l -O jobid,jobarrayid,name,state,timeused)${NC}\n"
           echo -n "Write the ID of the job (C-Cancel): "
           read jcancel
           if [ $jcancel = "C" ]; then
               echo -e "\nOPERATION CANCELLED. Press enter to continue.\n"
           else
               if grep -q "$jcancel" <<< "$(squeue -r -u $USER --jobs $jcancel -l -O jobid,jobarrayid)"; then
                   echo -e "\nAre you sure you want to cancel the job ${YELLOW}$jcancel${NC}?"
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
                   echo -e "${REDYELLOW}ERROR! The jobID $jcancel does not match any submitted jobs.${NC}\n"
               fi
           fi
           read foo;;

        4) echo -e "\n${PURPLE}**** CANCEL ALL JOBS ****${NC}\n"
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

        5) echo -e "\n${PURPLE}**** JOBS FOLDER ****${NC}\n"
           printf "${GREEN}%-10s %-30s %s\n" "JOBID" "NAME" "WORKDIR"
           printf "%-10s %-30s %s\n" "-----" "----" "-------"
           squeue -u $USER --noheader --format="%.18A %.30j %Z" |
               while read -r jobid name workdir; do
                   printf "%-10s %-30s %s\n" "$jobid" "$name" "$workdir"
               done
           echo -e "\n${NC}Press ENTER to continue ..."
           read foo;;

        6) echo -e "\n${PURPLE}**** JOBS RECORDS ****${NC}\n"
           sacct -u $USER
           echo -e "\nPress ENTER to continue ..."
           read foo;;

        7) echo -e "\n${PURPLE}**** JOB STATISTIC ****${NC}\n"
           echo -e "${GREEN}$(squeue -u $USER -l -O jobid,jobarrayid,name,state,timeused,nodelist)${NC}\n"
           echo -n "Write the ID of the job: "
           read jstat
           echo " "
           sstat $jstat
           echo -e "\nPress ENTER to continue ..."
           read foo;;

        8) echo -e "\n${PURPLE}**** PARTITION LOAD ****${NC}\n"
           # Print table header
           printf "${GREEN}%-20s %6s / %-6s %10s" "PARTITION" "USING" "TOTAL" "USING(%)"
           echo -e "\n-----------------------------------------------"

           # Capture sinfo output and calculate server load
           sinfo -h -o "%P %C" | awk '{
               split($2, a, "/")
               alloc = a[1]        # Assigned CPUs
               total = a[4]        # Total CPUs
               if (total > 0) {
                   perc = 100 * alloc / total
               } else {
                   perc = 0
               }
               printf "%-20s %6d / %-6d  (%6.2f%%)\n", $1, alloc, total, perc
               }'

           echo -e "${NC}\nPress ENTER to continue ..."
           read foo;;

        9) echo -e "\n${PURPLE}**** USER and PARTITIONS ****${NC}\n"
           USER_W=15
           COL_W=14

           # Getting the partition list (default partition indicated by *)
           readarray -t PARTITIONS < <(
               sinfo -h -o "%P" | sed 's/\*//g' | sort -u
           )

           # Header
           printf "%-${USER_W}s" "USER"
           for p in "${PARTITIONS[@]}"; do
               printf " %-${COL_W}s" "$p"
           done
           echo "\n"

           # Separation line
           total_width=$USER_W
           for _ in "${PARTITIONS[@]}"; do
               total_width=$((total_width + 1 + COL_W))
           done
           printf '%*s\n' "$total_width" '' | tr ' ' '-'

           # Data user and jobs per partition
           squeue -h -o "%u %P" | \
           awk -v parts="$(IFS=' '; echo "${PARTITIONS[*]}")" -v user_w="$USER_W" -v col_w="$COL_W" '
           BEGIN {
                 n = split(parts, P, " ")
           }
           {
                 user = $1
                 part = $2
                 gsub(/\*/, "", part)

                 users[user] = 1
                 counts[user, part]++
           }
           END {
                for (u in users) {
                     line = sprintf("%-" user_w "s", u)
                     for (i = 1; i <= n; i++) {
                         pp = P[i]
                         c = counts[u, pp]
                         if (c == "") c = 0
                         line = sprintf("%s %-" col_w "d", line, c)
                     }
                     print line
                }
           }
           ' | sort

           echo -e "${NC}\nPress ENTER to continue ..."
           read foo;;

        0) echo -e "\n${PURPLE}**** USERS AND THEIR JOBS ****${NC}\n"
           # Define the states of interest
           STATES_OF_INTEREST=("RUNNING" "PENDING" "COMPLETING")

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
           printf "${GREEN}%-20s %10s %10s %12s %10s\n" "USER" "RUNNING" "PENDING" "COMPLETING" "OTHER"
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

           echo -e "${NC}\nPress ENTER to continue ..."
           read foo;;

        e) echo -e "${PURPLE}\nHave a good day!${NC}\n"
           exit 1;;

        *) echo " "
           echo -e "\n\e[41;93m$option is an invalid option. Please, try again!${NC}"
           read foo;;
        esac
done
