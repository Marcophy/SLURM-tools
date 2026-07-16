#!/usr/bin/env bash

# SEARCH MODULE
# -------------
# Author: Marco A. Villena (mavillena@ugr.es)
# Date: 2020 - 2026

# This script searches for modules matching a user-provided name and prints
# a clean list with the module name and an associated path.
#
# The script is designed to work with common module systems such as Lmod
# and Environment Modules.

set -euo pipefail

declare -a MODULE_NAMES=()
declare -A MODULE_INFO=()
SEARCH_TERM=""

# Check whether the shell provides the module command.
module_command_exists() {
    type module >/dev/null 2>&1
}

# Remove leading and trailing whitespace from a string.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s\n' "$s"
}

# Remove a trailing slash or colon from a token or path.
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

# Ask the user for the module name to search and validate the input.
ask_search_term() {
    while true; do
        read -r -p "Enter the module name to search: " SEARCH_TERM
        SEARCH_TERM="$(trim "$SEARCH_TERM")"

        if [[ -n "$SEARCH_TERM" ]]; then
            return
        fi

        echo "The module name cannot be empty."
    done
}

# Check whether a string looks like a valid full module name and matches the search term.
is_valid_module_name() {
    local name="$1"
    local base
    local status

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

    # Accept only proper module names such as foo or foo/version.
    [[ "$name" =~ ^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)?$ ]] || return 1

    base="${name%%/*}"

    shopt -s nocasematch
    [[ "$base" == *"$SEARCH_TERM"* ]]
    status=$?
    shopt -u nocasematch

    return $status
}

# Add a module to the result set only if it passes validation.
add_module_if_valid() {
    local name="$1"
    name="$(normalize_token "$name")"

    if is_valid_module_name "$name"; then
        MODULE_INFO["$name"]=""
    fi
}

# Collect matching modules from the terse output of module avail.
collect_modules_from_avail() {
    local output

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

# Collect additional matching modules from module spider output.
collect_modules_from_spider() {
    local output
    local token

    output="$(module spider "$SEARCH_TERM" 2>&1 || true)"

    while IFS= read -r line; do
        line="$(trim "$line")"
        [[ -z "$line" ]] && continue

        for token in $line; do
            token="$(normalize_token "$token")"
            add_module_if_valid "$token"
        done
    done <<< "$output"
}

# Extract the most useful path information from module show output.
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

# Print the collected modules and their associated paths in list format.
print_results() {
    local name
    local i=1

    echo -e "\nModules found for search term: ${GREEN}$SEARCH_TERM${NC}"
    echo -e "--------------------------------------------------------\n"

    for name in "${MODULE_NAMES[@]}"; do
        echo -e "$i) Module: ${GREEN}$name${NC}"
        echo "   Path: ${MODULE_INFO[$name]}"
        echo
        ((i++))
    done
}

# Run the full workflow: validate environment, search modules, resolve paths,
# sort results, and print the final list.
main() {
    local name

    if ! module_command_exists; then
        echo -e "${REDYELLOW}ERROR: the 'module' command is not available in this shell.${NC}"
        exit 1
    fi

    ask_search_term
    collect_modules_from_avail
    collect_modules_from_spider

    if (( ${#MODULE_INFO[@]} == 0 )); then
        echo -e "\n${RED}No modules were found for: $SEARCH_TERM${NC}\n"
	return
    fi

    while IFS= read -r name; do
        [[ -n "$name" ]] && MODULE_NAMES+=("$name")
    done < <(printf '%s\n' "${!MODULE_INFO[@]}" | sort)

    if (( ${#MODULE_NAMES[@]} == 0 )); then
        echo -e "\n${RED}No modules were found for: $SEARCH_TERM${NC}\n"
        return
    fi

    for name in "${MODULE_NAMES[@]}"; do
        MODULE_INFO["$name"]="$(extract_path_from_show "$name")"
    done

    print_results
}

main
