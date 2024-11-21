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

# YAML file for storing container state
yaml_file="/opt/lxc-iptag/container_state.yaml"

# Function: Check and install dependencies
check_dependencies() {
    dependencies=("ipcalc" "jq" "yq")
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

# Function: Initialize the YAML file if missing or empty
initialize_yaml_file() {
    if [[ ! -f "$yaml_file" ]] || [[ ! -s "$yaml_file" ]]; then
        echo -e "[Info] YAML file is missing or empty. Initializing..."
        echo "containers: []" > "$yaml_file"
        update_yaml_with_current_containers
    fi
    echo "DEBUG: Contents of YAML file after initialization:"
    cat "$yaml_file"
}

# Function: Update YAML with current containers
update_yaml_with_current_containers() {
    echo "[Info] Updating YAML file with current containers."
    pct_list=$(pct list | tail -n +2)
    while IFS= read -r line; do
        id=$(echo "$line" | awk '{print $1}')
        name=$(echo "$line" | awk '{print $2}')
        ip=$(pct exec "$id" -- hostname -I 2>/dev/null | awk '{print $1}')
        tags=$(pct config "$id" | grep -oP "(?<=#Tags: ).*")
        [[ -z "$tags" ]] && tags="default"
        last_update=$(date --iso-8601=seconds)
        yq -y -i ".containers += [{id: \"$id\", name: \"$name\", ip: \"$ip\", tags: \"$tags\", last_update: \"$last_update\"}]" "$yaml_file"
        echo "DEBUG: YAML content after update:"
        cat "$yaml_file"
    done <<< "$pct_list"
}

# Function: Add or update a container in the YAML file
add_or_update_container_in_yaml() {
    local id="$1"
    local name="$2"
    local ip="$3"
    local tags="$4"
    local update_type="${5:-manual}"

    echo "DEBUG: Adding/updating container - ID: $id, Name: $name, IP: $ip, Tags: $tags, Update Type: $update_type"

    # Add or update the container in the YAML file
    yq eval -i \
        ".containers |= map(select(.id != \"$id\")) | .containers += [{id: \"$id\", name: \"$name\", ip: \"$ip\", tags: [\"$tags\"], last_update: \"$(date -Iseconds)\"}]" \
        "$yaml_file"

    # Debugging output
    echo -e "DEBUG: YAML content after update:"
    cat "$yaml_file"
}

# Function: Validate IPs in YAML
validate_ips_in_yaml() {
    echo -e "${GN}[Info]${CL} Validating IPs in YAML file."

    # Get all container IDs from YAML
    mapfile -t container_ids < <(yq eval ".containers[].id" "$yaml_file")

    for id in "${container_ids[@]}"; do
        if pct status "$id" &>/dev/null; then
            # Get current IP for the container
            current_ip=$(pct exec "$id" ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

            # Update IP if needed
            add_or_update_container_in_yaml "$id" "" "$current_ip"
        else
            # Remove container if it no longer exists
            echo -e "${RD}[Info]${CL} Container $id no longer exists. Removing from YAML."
            yq eval -i ".containers |= map(select(.id != \"$id\"))" "$yaml_file"
        fi
    done
}

select_containers() {
    echo "DEBUG: Selecting containers..."
    yq -r ".containers[].id" "$yaml_file"
}
tag_container_ip() {
    container_id="$1"
    echo "[Info] Tagging IP for container ID: $container_id"
    # Beispiel: Aktualisiere die Tags basierend auf bestimmten Bedingungen
    yq -y -i "(.containers[] | select(.id == \"$container_id\")).tags |= \"updated-tag\"" "$yaml_file"
}

# Main function
main() {
    initialize_yaml_file
    update_yaml_with_current_containers
    validate_ips_in_yaml
    selected_containers=$(select_containers)
    if [[ -z "$selected_containers" ]]; then
        echo "[Info] No containers selected. Exiting."
        exit 1
    fi
    for container_id in $selected_containers; do
        tag_container_ip "$container_id"
    done
    echo "[Info] Finished tagging IPs for selected containers."
}
main "$@"
