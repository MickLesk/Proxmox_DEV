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

BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
CL=$(echo "\033[m")

# Default CIDR ranges for allowed IPs
default_cidr_list=(
    "192.168.0.0/16"
    "100.64.0.0/10"
    "10.0.0.0/8"
)

# Path to store JSON state
json_file="/opt/lxc-iptag/container_state.json"

# Function to load or create the CIDR list
load_cidr_list() {
    local cidr_file="/opt/lxc-iptag/cidr_list.txt"
    local cidr_dir="/opt/lxc-iptag"

    # Create directory if it doesn't exist
    if [[ ! -d "$cidr_dir" ]]; then
        mkdir -p "$cidr_dir" || { echo "[Error] Failed to create directory: $cidr_dir"; exit 1; }
    fi

    # Create CIDR list file if it doesn't exist
    if [[ ! -f "$cidr_file" ]]; then
        for cidr in "${default_cidr_list[@]}"; do
            echo "$cidr" >> "$cidr_file"
        done
    fi

    # Load CIDR ranges into an array
    mapfile -t cidr_list < "$cidr_file"
}

# Load JSON state or initialize it
load_json_state() {
    if [[ ! -f "$json_file" ]]; then
        echo '{"containers":[]}' > "$json_file"
    fi
    json_state=$(cat "$json_file")
}

# Update JSON state with new container info
update_json_state() {
    local id="$1"
    local name="$2"
    local new_ip="$3"

    container_data=$(echo "$json_state" | jq ".containers[] | select(.id == \"$id\")")

    if [[ -n "$container_data" ]]; then
        # Update existing container's IP
        json_state=$(echo "$json_state" | jq --arg id "$id" --arg ip "$new_ip" '
            .containers |= map(if .id == $id then .tags = [$ip] | .last_update = now | todateiso8601 else . end)')
    else
        # Add new container to JSON state
        json_state=$(echo "$json_state" | jq --arg id "$id" --arg name "$name" --arg ip "$new_ip" '
            .containers += [{"id": $id, "name": $name, "tags": [$ip], "last_update": (now | todateiso8601)}]')
    fi

    # Save updated JSON state
    echo "$json_state" > "$json_file"
}

# Convert IP address to integer for CIDR matching
ip_to_int() {
    local ip="${1}"
    local a b c d
    IFS=. read -r a b c d <<< "${ip}"
    echo "$((a << 24 | b << 16 | c << 8 | d))"
}

# Check if IP belongs to a CIDR range
ip_in_cidr() {
    local ip="${1}"
    local cidr="${2}"
    ip_int=$(ip_to_int "${ip}")
    netmask_int=$(ip_to_int "$(ipcalc -b "${cidr}" | grep Broadcast | awk '{print $2}')")
    masked_ip_int=$(( "${ip_int}" & "${netmask_int}" ))
    [[ ${ip_int} -eq ${masked_ip_int} ]] && return 0 || return 1
}

# Check if IP belongs to any CIDR range
ip_in_cidrs() {
    local ip="${1}"
    for cidr in "${cidr_list[@]}"; do
        ip_in_cidr "${ip}" "${cidr}" && return 0
    done
    return 1
}

# Select containers using whiptail
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

    echo "$selected_containers"
}

# Function to tag container IPs
tag_container_ip() {
    local container_id="$1"
    local name=$(pct exec "$container_id" hostname)

    echo -e "${BL}[Info]${GN} Tagging IP for ${name} ${CL}"

    # Get container IP
    local container_ip=$(pct exec "$container_id" -- ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

    if [[ -z "$container_ip" ]]; then
        echo -e "${RD}[Error]${CL} No IP found for ${name}. Skipping..."
        return 1
    fi

    # Check if IP is in allowed CIDR ranges
    if ip_in_cidrs "$container_ip"; then
        echo -e "${BL}[Info]${GN} IP ${container_ip} for ${name} is within the CIDR range. Tagging... ${CL}"

        # Load JSON state
        load_json_state

        # Update JSON and tags
        update_json_state "$container_id" "$name" "$container_ip"
        pct set "$container_id" -tags "$container_ip"
    else
        echo -e "${RD}[Info]${CL} IP ${container_ip} for ${name} is outside the allowed CIDR range. Skipping..."
    fi
}

# Main function
main() {
    load_cidr_list
    selected_containers=$(select_containers)

    if [[ -z "$selected_containers" ]]; then
        echo -e "${RD}[Info]${CL} No containers selected. Exiting..."
        exit 1
    fi

    for container_id in $selected_containers; do
        tag_container_ip "$container_id"
    done

    echo -e "${GN} Finished tagging IPs for selected containers. ${CL}"
}

main
