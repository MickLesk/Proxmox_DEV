#!/usr/bin/env bash

# Copyright (c) 2021-2024 community-scripts ORG
# Author: MickLesk
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info() {
  clear
  cat <<"EOF"
    __   _  ________   ________      _________   ______   
   / /  | |/ / ____/  /  _/ __ \    /_  __/   | / ____/   
  / /   |   / /       / // /_/ /_____/ / / /| |/ / __     
 / /___/   / /___   _/ // ____/_____/ / / ___ / /_/ /     
/_____/_/|_\____/  /___/_/         /_/ /_/  |_\____/      
                                                          
EOF
}

# Color definitions for output
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

# JSON file for storing container state
json_file="/opt/lxc-iptag/container_state.json"

# Function: Check and install dependencies
check_dependencies() {
    dependencies=("ipcalc" "jq")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            echo -e "${RD}[Error]${CL} Dependency '$dep' is missing."
            read -p "Install $dep? (y/n): " choice
            if [[ "$choice" == "y" ]]; then
                apt-get update && apt-get install -y "$dep"
            else
                echo -e "${RD}[Error]${CL} '$dep' is required. Exiting."
                exit 1
            fi
        fi
    done
    echo -e "${GN}[Info]${CL} All dependencies are installed."
}

# Function: Initialize the JSON file if missing or empty
initialize_json_file() {
    if [[ ! -f "$json_file" ]] || [[ ! -s "$json_file" ]]; then
        echo -e "${GN}[Info]${CL} JSON file is missing or empty. Initializing..."
        echo '{"containers":[]}' > "$json_file"
        update_json_with_current_containers
    fi
}

# Function: Update the JSON file with current containers
update_json_with_current_containers() {
    echo -e "${GN}[Info]${CL} Updating JSON file with current containers."

    while read -r id name ip; do
        [[ "$id" == "VMID" ]] && continue # Skip header row
        add_or_update_container_in_json "$id" "$name" "$ip" "initial"
    done < <(pct list | awk 'NR>1 {print $1, $2, $3}' | grep "running")
}

# Function: Add or update container information in JSON
add_or_update_container_in_json() {
    local id="$1"
    local name="$2"
    local ip="$3"
    local update_type="${4:-manual}"

    # Load the current JSON state
    json_state=$(jq '.' "$json_file")

    # Check if the container already exists
    container_data=$(echo "$json_state" | jq --arg id "$id" '.containers[] | select(.id == $id)')

    if [[ -n "$container_data" ]]; then
        # Update IP if it has changed
        current_ip=$(echo "$container_data" | jq -r '.tags[0]')
        if [[ "$current_ip" != "$ip" ]]; then
            echo -e "${BL}[Info]${CL} Container $name ($id) IP changed: $current_ip -> $ip"
            json_state=$(echo "$json_state" | jq --arg id "$id" --arg ip "$ip" '
                .containers |= map(if .id == $id then .tags = [$ip] | .last_update = now | todateiso8601 else . end)')
        fi
    else
        # Add new container
        echo -e "${GN}[Info]${CL} New container detected: $name ($id) with IP $ip"
        json_state=$(echo "$json_state" | jq --arg id "$id" --arg name "$name" --arg ip "$ip" '
            .containers += [{"id": $id, "name": $name, "tags": [$ip], "last_update": (now | todateiso8601)}]')
    fi

    # Save updated JSON state
    echo "$json_state" > "$json_file"
}

# Function: Validate IPs in JSON
validate_ips_in_json() {
    echo -e "${GN}[Info]${CL} Validating IPs in JSON file."
    json_state=$(jq '.' "$json_file")

    # Get all container IDs from JSON
    mapfile -t container_ids < <(echo "$json_state" | jq -r '.containers[].id')

    for id in "${container_ids[@]}"; do
        if pct status "$id" &>/dev/null; then
            # Get current IP for the container
            current_ip=$(pct exec "$id" ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

            # Update IP if needed
            add_or_update_container_in_json "$id" "" "$current_ip"
        else
            # Remove container if it no longer exists
            echo -e "${RD}[Info]${CL} Container $id no longer exists. Removing from JSON."
            json_state=$(echo "$json_state" | jq --arg id "$id" '.containers |= map(select(.id != $id))')
            echo "$json_state" > "$json_file"
        fi
    done
}

# Function: Select containers with Whiptail
select_containers() {
    EXCLUDE_MENU=()
    MSG_MAX_LENGTH=0
    while read -r TAG ITEM; do
        OFFSET=2
        ((${#ITEM} + OFFSET > MSG_MAX_LENGTH)) && MSG_MAX_LENGTH=${#ITEM}+OFFSET
        EXCLUDE_MENU+=("$TAG" "$ITEM " "OFF")
    done < <(pct list | awk 'NR>1 {print $1, $2}')

    selected_containers=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Select Containers" --checklist "\nSelect containers to tag IPs:\n" \
        16 $((MSG_MAX_LENGTH + 23)) 6 "${EXCLUDE_MENU[@]}" 3>&1 1>&2 2>&3 | tr -d '"') || exit

    # Return selected container IDs
    echo "$selected_containers"
}

# Function: Tag container IPs
tag_container_ip() {
    container_id=$1
    header_info
    name=$(pct exec "$container_id" hostname)
    echo -e "${BL}[Info]${GN} Tagging IP for ${name} ${CL} \n"

    # Get container IP
    container_ip=$(pct exec "$container_id" ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

    if [[ -z "$container_ip" ]]; then
        echo -e "${RD}[Error]${CL} No IP found for ${name}. Skipping...\n"
        return 1
    fi

    # Get existing tags and set new tags
    existing_tags=$(pct config "$container_id" | grep "^tags:" | cut -d: -f2 | tr -d '[:space:]')
    if [[ -n "$existing_tags" ]]; then
        new_tags="$existing_tags,$container_ip"
    else
        new_tags="$container_ip"
    fi

    pct set "$container_id" -tags "$new_tags"
    echo -e "${GN}[Info]${CL} IP $container_ip tagged for container $name."
}

# Main function
main() {
    check_dependencies
    initialize_json_file
    validate_ips_in_json

    selected_containers=$(select_containers)
    if [[ -z "$selected_containers" ]]; then
        echo -e "${RD}[Info]${CL} No containers selected. Exiting."
        exit 1
    fi

    for container_id in $selected_containers; do
        tag_container_ip "$container_id"
    done

    echo -e "${GN}[Info]${CL} Finished tagging IPs for selected containers."
}

# Run main
main
