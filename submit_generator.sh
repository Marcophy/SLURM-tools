#!/usr/bin/env bash

# SUBMIT_GENERATOR
# ----------------
# Author: Marco A. Villena (mavillena@ugr.es)
# Date: 2020 - 2026

# This script helps the user create a Slurm submission file.
# It reads partition information from partitions.info and builds
# a submission script interactively.
#
# The design is modular so that new application profiles can be
# added easily in the future.

PARTITION_FILE="$JOBEXPLORERPATH/partitions.info"

declare -a PARTITION_NAMES=()
declare -a PARTITION_NODES=()
declare -a PARTITION_CORES=()

declare -a MODULE_NAMES=()
declare -A MODULE_INFO=()

PROGRAM_PROFILE="none"
PARALLEL_MODE=""
SELECTED_PARTITION=""
MAX_NODES=0
CORES_PER_NODE=0

JOB_NAME=""
OUTPUT_FILE=""
ERROR_FILE=""
WALLTIME=""
REQUESTED_NODES=1
NTASKS=1
CPUS_PER_TASK=1
TASKS_PER_NODE=""
MEMORY_PER_NODE=""
ACCOUNT_NAME=""
EMAIL_ADDRESS=""
MAIL_TYPE=""
RUN_COMMAND=""
SUBMISSION_FILE="submission.slurm"
VASP_MODULE=""
VASP_MODULE_PATH=""

# Function to print separators.
print_separator() {
    echo "------------------------------------------------------------"
}

# Function to ask questions that require a non-empty answer.
ask_nonempty() {
    local prompt="$1"
    local value=""

    while true; do
        read -r -p "$prompt" value
        if [[ -n "$value" ]]; then
            printf '%s' "$value"
            return
        fi
        echo "This field cannot be empty."
    done
}

# Function to ask questions with an optional answer.
ask_optional() {
    local prompt="$1"
    local value=""
    read -r -p "$prompt" value
    printf '%s' "$value"
}

# Function to ask questions with an integer answer in a range.
ask_integer_in_range() {
    local prompt="$1"
    local min_value="$2"
    local max_value="$3"
    local value=""

    while true; do
        read -r -p "$prompt" value
        if [[ "$value" =~ ^[0-9]+$ ]] && (( value >= min_value && value <= max_value )); then
            printf '%s' "$value"
            return
        fi
        echo "Please enter an integer between $min_value and $max_value."
    done
}

# Function to remove leading and trailing whitespace from a string.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s\n' "$s"
}

# Function to remove trailing separators from tokens and paths.
normalize_token() {
    local s="$1"
    s="$(trim "$s")"
    while [[ "$s" == */ || "$s" == *: || "$s" == *';' ]]; do
        s="${s%/}"
        s="${s%:}"
        s="${s%;}"
    done
    printf '%s\n' "$s"
}

# Function to check whether the shell provides the module command.
module_command_exists() {
    type module >/dev/null 2>&1
}

# Function to decide whether a candidate looks like a valid module name.
is_valid_module_name() {
    local name="$1"
    local base

    name="$(normalize_token "$name")"

    [[ -z "$name" ]] && return 1
    [[ "$name" == *" "* ]] && return 1
    [[ "$name" == *"("* ]] && return 1
    [[ "$name" == *")"* ]] && return 1
    [[ "$name" == *"'"* ]] && return 1
    [[ "$name" == *'"'* ]] && return 1
    [[ "$name" == *"*"* ]] && return 1
    [[ "$name" == *"?"* ]] && return 1
    [[ "$name" == *":"* ]] && return 1
    [[ "$name" =~ ^[A-Z]+$ ]] && return 1
    [[ "$name" =~ ^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)?$ ]] || return 1

    base="${name%%/*}"
    [[ "$base" == vasp* ]]
}

# Function to add a module candidate only if it is valid.
add_module_if_valid() {
    local name="$1"
    name="$(normalize_token "$name")"

    if is_valid_module_name "$name"; then
        MODULE_INFO["$name"]=""
    fi
}

# Function to collect matching VASP modules from the terse module avail output.
collect_vasp_modules_from_avail() {
    local output
    local line

    output="$(module -t avail 2>&1 || true)"

    while IFS= read -r line; do
        line="$(normalize_token "$line")"
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^-+$ ]] && continue
        [[ "$line" =~ ^Module ]] && continue
        [[ "$line" == */: ]] && continue
        [[ "$line" == *":" ]] && continue

        add_module_if_valid "$line"
    done <<< "$output"
}

# Function to collect additional VASP modules from module spider output.
collect_vasp_modules_from_spider() {
    local output
    local line
    local token

    output="$(module spider vasp 2>&1 || true)"

    while IFS= read -r line; do
        line="$(trim "$line")"
        [[ -z "$line" ]] && continue

        for token in $line; do
            token="$(normalize_token "$token")"
            add_module_if_valid "$token"
        done
    done <<< "$output"
}

# Function to extract the most useful path information from module show output.
extract_path_from_show() {
    local module_name="$1"
    local output
    local path=""

    output="$(module show "$module_name" 2>&1 || true)"

    path="$(awk '
        {
            if (match($0, /\/[^[:space:]:;]*(modulefiles?|modules?)\/[^[:space:]:;]+/)) {
                print substr($0, RSTART, RLENGTH)
                exit
            }
        }
    ' <<< "$output")"

    if [[ -z "$path" ]]; then
        path="$(awk '
            /setenv\(/ {
                if (match($0, /"\/[^"]+"/)) {
                    p = substr($0, RSTART + 1, RLENGTH - 2)
                    print p
                    exit
                }
            }
            /setenv[[:space:]]+/ {
                if ($3 ~ /^\//) {
                    print $3
                    exit
                }
            }
        ' <<< "$output")"
    fi

    if [[ -z "$path" ]]; then
        path="$(awk '
            /prepend_path\(/ && /PATH/ {
                if (match($0, /"\/[^"]+"/)) {
                    p = substr($0, RSTART + 1, RLENGTH - 2)
                    print p
                    exit
                }
            }
            /append_path\(/ && /PATH/ {
                if (match($0, /"\/[^"]+"/)) {
                    p = substr($0, RSTART + 1, RLENGTH - 2)
                    print p
                    exit
                }
            }
            /prepend-path[[:space:]]+PATH[[:space:]]+/ {
                if ($3 ~ /^\//) {
                    print $3
                    exit
                }
            }
            /append-path[[:space:]]+PATH[[:space:]]+/ {
                if ($3 ~ /^\//) {
                    print $3
                    exit
                }
            }
        ' <<< "$output")"
    fi

    if [[ -z "$path" ]]; then
        path="$(grep -oE '/[^[:space:]:;)"]+' <<< "$output" | head -n 1 || true)"
    fi

    path="$(normalize_token "$path")"
    [[ -z "$path" ]] && path="Path not found"
    printf '%s\n' "$path"
}

# Function to discover the available VASP modules and resolve their paths.
load_vasp_modules() {
    local name

    MODULE_NAMES=()
    MODULE_INFO=()

    if ! module_command_exists; then
        echo "Error: the 'module' command is not available in this shell."
        exit 1
    fi

    collect_vasp_modules_from_avail
    collect_vasp_modules_from_spider

    if (( ${#MODULE_INFO[@]} == 0 )); then
        echo "Error: no VASP modules were found in the module system."
        exit 1
    fi

    while IFS= read -r name; do
        [[ -n "$name" ]] && MODULE_NAMES+=("$name")
    done < <(printf '%s\n' "${!MODULE_INFO[@]}" | sort)

    if (( ${#MODULE_NAMES[@]} == 0 )); then
        echo "Error: no VASP modules were found in the module system."
        exit 1
    fi

    for name in "${MODULE_NAMES[@]}"; do
        MODULE_INFO["$name"]="$(extract_path_from_show "$name")"
    done
}

# Function to let the user select the VASP module to use.
choose_vasp_module() {
    local i
    local module_index

    load_vasp_modules

    print_separator
    echo "Available VASP modules:"
    echo

    for i in "${!MODULE_NAMES[@]}"; do
        printf "%d) %s\n" "$((i + 1))" "${MODULE_NAMES[$i]}"
        printf "   Path: %s\n" "${MODULE_INFO[${MODULE_NAMES[$i]}]}"
    done
    echo

    module_index=$(ask_integer_in_range "Choose a VASP module by number: " 1 "${#MODULE_NAMES[@]}")
    module_index=$((module_index - 1))

    VASP_MODULE="${MODULE_NAMES[$module_index]}"
    VASP_MODULE_PATH="${MODULE_INFO[$VASP_MODULE]}"
}

# Function to load partition information from the partition file.
load_partitions() {
    if [[ ! -f "$PARTITION_FILE" ]]; then
        echo "Error: $PARTITION_FILE was not found."
        exit 1
    fi

    PARTITION_NAMES=()
    PARTITION_NODES=()
    PARTITION_CORES=()

    while read -r name nodes cores; do
        [[ "$name" == "Name" ]] && continue
        [[ -z "$name" ]] && continue

        PARTITION_NAMES+=("$name")
        PARTITION_NODES+=("$nodes")
        PARTITION_CORES+=("$cores")
    done < <(awk 'NF >= 3 {print $1, $2, $3}' "$PARTITION_FILE")

    if [[ ${#PARTITION_NAMES[@]} -eq 0 ]]; then
        echo "Error: no valid partition data found in $PARTITION_FILE."
        exit 1
    fi
}

# Function to let the user choose the application profile.
choose_program_profile() {
    print_separator
    echo "Application profile:"
    echo "1) From scratch"
    echo "2) VASP"
    echo

    while true; do
        read -r -p "Choose an option [1-2]: " option
        case "$option" in
            1)
                PROGRAM_PROFILE="none"
                return
                ;;
            2)
                PROGRAM_PROFILE="vasp"
                return
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
    done
}

# Function to let the user choose the target partition.
choose_partition() {
    print_separator
    echo "Available partitions:"
    echo

    local i
    local partition_index

    for i in "${!PARTITION_NAMES[@]}"; do
        printf "%d) %s (max nodes: %s, cores/node: %s)\n" \
            "$((i + 1))" \
            "${PARTITION_NAMES[$i]}" \
            "${PARTITION_NODES[$i]}" \
            "${PARTITION_CORES[$i]}"
    done
    echo

    partition_index=$(ask_integer_in_range "Choose a partition by number: " 1 "${#PARTITION_NAMES[@]}")
    partition_index=$((partition_index - 1))

    SELECTED_PARTITION="${PARTITION_NAMES[$partition_index]}"
    MAX_NODES="${PARTITION_NODES[$partition_index]}"
    CORES_PER_NODE="${PARTITION_CORES[$partition_index]}"
}

# Function to let the user choose the parallel execution mode.
choose_parallel_mode() {
    print_separator
    echo "Parallel mode:"
    echo "1) None"
    echo "2) MPI"
    echo "3) OpenMP"
    echo "4) Hybrid MPI + OpenMP"
    echo

    while true; do
        read -r -p "Choose an option [1-4]: " option
        case "$option" in
            1)
                PARALLEL_MODE="none"
                return
                ;;
            2)
                PARALLEL_MODE="mpi"
                return
                ;;
            3)
                PARALLEL_MODE="openmp"
                return
                ;;
            4)
                PARALLEL_MODE="hybrid"
                return
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
    done
}

# Function to define general job parameters.
ask_general_job_options() {
    print_separator
    JOB_NAME=$(ask_nonempty "Job name: ")
    OUTPUT_FILE=$(ask_optional "Output file name [output-%j.log]: ")
    ERROR_FILE=$(ask_optional "Error file name [error-%j.log]: ")
    WALLTIME=$(ask_optional "Walltime (HH:MM:SS) [optional]: ")
    MEMORY_PER_NODE=$(ask_optional "Memory per node (e.g. 4G, 8000M) [optional]: ")
    ACCOUNT_NAME=$(ask_optional "Account name [optional]: ")

    [[ -z "$OUTPUT_FILE" ]] && OUTPUT_FILE="output-%j.log"
    [[ -z "$ERROR_FILE" ]] && ERROR_FILE="error-%j.log"
}

# Function to configure email notifications.
ask_email_options() {
    print_separator
    echo "Email notifications:"
    echo "1) No email"
    echo "2) Custom selection"
    echo "3) END,FAIL"
    echo "4) BEGIN"
    echo "5) END"
    echo "6) FAIL"
    echo "7) BEGIN,END,FAIL"
    echo "8) ALL"
    echo

    local option
    local default_email="${MYEMAIL:-}"

    while true; do
        read -r -p "Choose an option [1-8]: " option
        case "$option" in
            1)
                EMAIL_ADDRESS="$default_email"
                MAIL_TYPE=""
                return
                ;;
            2)
                EMAIL_ADDRESS=$(ask_optional "Email address [${default_email:-none}]: ")
                [[ -z "$EMAIL_ADDRESS" ]] && EMAIL_ADDRESS="$default_email"
                echo "Valid mail events include NONE, BEGIN, END, FAIL, REQUEUE, ALL."
                MAIL_TYPE=$(ask_nonempty "Enter a comma-separated mail-type value: ")
                return
                ;;
            3)
                EMAIL_ADDRESS=$(ask_optional "Email address [${default_email:-none}]: ")
                [[ -z "$EMAIL_ADDRESS" ]] && EMAIL_ADDRESS="$default_email"
                MAIL_TYPE="END,FAIL"
                return
                ;;
            4)
                EMAIL_ADDRESS=$(ask_optional "Email address [${default_email:-none}]: ")
                [[ -z "$EMAIL_ADDRESS" ]] && EMAIL_ADDRESS="$default_email"
                MAIL_TYPE="BEGIN"
                return
                ;;
            5)
                EMAIL_ADDRESS=$(ask_optional "Email address [${default_email:-none}]: ")
                [[ -z "$EMAIL_ADDRESS" ]] && EMAIL_ADDRESS="$default_email"
                MAIL_TYPE="END"
                return
                ;;
            6)
                EMAIL_ADDRESS=$(ask_optional "Email address [${default_email:-none}]: ")
                [[ -z "$EMAIL_ADDRESS" ]] && EMAIL_ADDRESS="$default_email"
                MAIL_TYPE="FAIL"
                return
                ;;
            7)
                EMAIL_ADDRESS=$(ask_optional "Email address [${default_email:-none}]: ")
                [[ -z "$EMAIL_ADDRESS" ]] && EMAIL_ADDRESS="$default_email"
                MAIL_TYPE="BEGIN,END,FAIL"
                return
                ;;
            8)
                EMAIL_ADDRESS=$(ask_optional "Email address [${default_email:-none}]: ")
                [[ -z "$EMAIL_ADDRESS" ]] && EMAIL_ADDRESS="$default_email"
                MAIL_TYPE="ALL"
                return
                ;;
            *)
                echo "Invalid option."
                ;;
        esac
    done
}

# Function to configure a pure MPI run.
configure_mpi_mode() {
    print_separator
    echo "MPI configuration for the selected partition:"
    echo "Partition: $SELECTED_PARTITION"
    echo "Maximum nodes: $MAX_NODES"
    echo "Cores per node: $CORES_PER_NODE"
    echo

    REQUESTED_NODES=$(ask_integer_in_range "Number of nodes [1-$MAX_NODES]: " 1 "$MAX_NODES")

    local max_total_tasks
    local max_tasks_per_node

    max_total_tasks=$((REQUESTED_NODES * CORES_PER_NODE))
    NTASKS=$(ask_integer_in_range "Total number of MPI tasks [1-$max_total_tasks]: " 1 "$max_total_tasks")
    CPUS_PER_TASK=1

    max_tasks_per_node="$CORES_PER_NODE"
    TASKS_PER_NODE=$(ask_optional "Tasks per node [optional, max $max_tasks_per_node]: ")

    if [[ -n "$TASKS_PER_NODE" ]]; then
        if [[ ! "$TASKS_PER_NODE" =~ ^[0-9]+$ ]] || (( TASKS_PER_NODE < 1 || TASKS_PER_NODE > max_tasks_per_node )); then
            echo "Invalid tasks-per-node value."
            exit 1
        fi
    fi
}

# Function to configure a pure OpenMP run.
configure_openmp_mode() {
    print_separator
    echo "OpenMP configuration for the selected partition:"
    echo "Partition: $SELECTED_PARTITION"
    echo "Maximum nodes: $MAX_NODES"
    echo "Cores per node: $CORES_PER_NODE"
    echo

    REQUESTED_NODES=$(ask_integer_in_range "Number of nodes [1-$MAX_NODES]: " 1 "$MAX_NODES")
    NTASKS=1
    CPUS_PER_TASK=$(ask_integer_in_range "OpenMP threads / CPUs per task [1-$CORES_PER_NODE]: " 1 "$CORES_PER_NODE")
    TASKS_PER_NODE=""
}

# Function to configure a hybrid MPI + OpenMP run.
configure_hybrid_mode() {
    print_separator
    echo "Hybrid MPI + OpenMP configuration for the selected partition:"
    echo "Partition: $SELECTED_PARTITION"
    echo "Maximum nodes: $MAX_NODES"
    echo "Cores per node: $CORES_PER_NODE"
    echo

    REQUESTED_NODES=$(ask_integer_in_range "Number of nodes [1-$MAX_NODES]: " 1 "$MAX_NODES")

    local max_total_tasks
    local max_tasks_per_node

    max_total_tasks=$((REQUESTED_NODES * CORES_PER_NODE))
    NTASKS=$(ask_integer_in_range "Total number of MPI tasks [1-$max_total_tasks]: " 1 "$max_total_tasks")
    CPUS_PER_TASK=$(ask_integer_in_range "OpenMP threads / CPUs per task [1-$CORES_PER_NODE]: " 1 "$CORES_PER_NODE")

    max_tasks_per_node=$((CORES_PER_NODE / CPUS_PER_TASK))
    (( max_tasks_per_node < 1 )) && max_tasks_per_node=1

    echo "Suggested maximum tasks per node for this setup: $max_tasks_per_node"
    TASKS_PER_NODE=$(ask_optional "Tasks per node [optional, recommended max $max_tasks_per_node]: ")

    if [[ -n "$TASKS_PER_NODE" ]]; then
        if [[ ! "$TASKS_PER_NODE" =~ ^[0-9]+$ ]] || (( TASKS_PER_NODE < 1 || TASKS_PER_NODE > max_tasks_per_node )); then
            echo "Invalid tasks-per-node value."
            exit 1
        fi
    fi
}

# Function to dispatch the parallel mode configuration.
configure_parallel_options() {
    case "$PARALLEL_MODE" in
        none)
            ;;
        mpi)
            configure_mpi_mode
            ;;
        openmp)
            configure_openmp_mode
            ;;
        hybrid)
            configure_hybrid_mode
            ;;
        *)
            echo "Error: unsupported parallel mode."
            exit 1
            ;;
    esac
}

# Function to build the default run command for the selected application profile.
build_default_run_command() {
    case "$PROGRAM_PROFILE" in
        none)
            RUN_COMMAND=$(ask_nonempty "Command or script to execute: ")
            ;;
        vasp)
            choose_vasp_module
            print_separator
            echo "VASP profile selected."
            echo "Selected VASP module: $VASP_MODULE"
            echo "VASP module path: $VASP_MODULE_PATH"
            echo "The script will define OMP_NUM_THREADS from Slurm when appropriate."
            RUN_COMMAND=$(ask_optional "VASP execution command [default: srun vasp_std]: ")
            [[ -z "$RUN_COMMAND" ]] && RUN_COMMAND="srun vasp_std"
            ;;
        *)
            echo "Error: unsupported application profile."
            exit 1
            ;;
    esac
}

# Function to write the final Slurm submission file.
write_submission_file() {
    SUBMISSION_FILE=$(ask_optional "Submission file name [submission.slurm]: ")
    [[ -z "$SUBMISSION_FILE" ]] && SUBMISSION_FILE="submission.slurm"

    {
        echo "#!/usr/bin/env bash"
        echo "#SBATCH --job-name=$JOB_NAME"
        echo "#SBATCH --partition=$SELECTED_PARTITION"
        echo "#SBATCH --nodes=$REQUESTED_NODES"
        echo "#SBATCH --ntasks=$NTASKS"
        echo "#SBATCH --cpus-per-task=$CPUS_PER_TASK"
        echo "#SBATCH --output=$OUTPUT_FILE"
        echo "#SBATCH --error=$ERROR_FILE"

        if [[ -n "$WALLTIME" ]]; then
            echo "#SBATCH --time=$WALLTIME"
        fi

        if [[ -n "$TASKS_PER_NODE" ]]; then
            echo "#SBATCH --ntasks-per-node=$TASKS_PER_NODE"
        fi

        if [[ -n "$MEMORY_PER_NODE" ]]; then
            echo "#SBATCH --mem=$MEMORY_PER_NODE"
        fi

        if [[ -n "$ACCOUNT_NAME" ]]; then
            echo "#SBATCH --account=$ACCOUNT_NAME"
        fi

        if [[ -n "$EMAIL_ADDRESS" && -n "$MAIL_TYPE" ]]; then
            echo "#SBATCH --mail-user=$EMAIL_ADDRESS"
            echo "#SBATCH --mail-type=$MAIL_TYPE"
        fi

        echo
        echo "echo \"Running on \$(hostname)\""
        echo "echo \"Start time: \$(date)\""

        if [[ "$PROGRAM_PROFILE" == "vasp" && -n "$VASP_MODULE" ]]; then
            echo "module purge"
            echo "module load $VASP_MODULE"
        fi

        case "$PARALLEL_MODE" in
            openmp|hybrid)
                echo "export OMP_NUM_THREADS=\${SLURM_CPUS_PER_TASK:-1}"
                ;;
        esac

        echo

        case "$PROGRAM_PROFILE" in
            none)
                echo "$RUN_COMMAND"
                ;;
            vasp)
                echo "# VASP profile"
                echo "$RUN_COMMAND"
                ;;
        esac

        echo
        echo "echo \"End time: \$(date)\""
    } > "$SUBMISSION_FILE"

    chmod +x "$SUBMISSION_FILE"
}

# Function to run the full interactive workflow.
main() {
    load_partitions
    choose_program_profile
    choose_partition
    choose_parallel_mode
    ask_general_job_options
    ask_email_options
    configure_parallel_options
    build_default_run_command
    write_submission_file

    print_separator
    echo "Submission file created successfully: $SUBMISSION_FILE"
    echo "Selected program profile: $PROGRAM_PROFILE"
    echo "Parallel mode: $PARALLEL_MODE"
    echo "Partition: $SELECTED_PARTITION"

    if [[ "$PROGRAM_PROFILE" == "vasp" ]]; then
        echo "Selected VASP module: $VASP_MODULE"
        echo "VASP module path: $VASP_MODULE_PATH"
    fi
}

main
