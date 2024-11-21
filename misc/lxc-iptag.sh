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
        echo -e "${GN}[Info]${CL} YAML file is missing or empty. Initializing..."
        echo "containers: []" > "$yaml_file"
    fi

    # Debug output
    echo -e "DEBUG: Contents of YAML file after initialization:"
    cat "$yaml_file"
}

# Function: Update YAML with current containers
update_yaml_with_current_containers() {
    echo -e "${GN}[Info]${CL} Updating YAML file with current containers."

    # Iterate over all running containers
    pct list | awk 'NR>1 {print $1, $2}' | while read -r id name; do
        echo -e "DEBUG: Processing Container - ID: $id, Name: $name"

        # Get container details
        container_ip=$(pct exec "$id" -- ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        container_tags=$(pct config "$id" | grep "^tags:" | cut -d: -f2 | tr -d '[:space:]')

        # Debugging output
        echo "DEBUG: Container IP: $container_ip"
        echo "DEBUG: Container Tags: $container_tags"

        # Skip if no IP is found
        if [[ -z "$container_ip" ]]; then
            echo -e "${RD}[Error]${CL} No IP found for container $name. Skipping..."
            continue
        fi

        # Default tags to IP if none are present
        if [[ -z "$container_tags" ]]; then
            container_tags="$container_ip"
        fi

        # Add or update container in YAML
        add_or_update_container_in_yaml "$id" "$name" "$container_ip" "$container_tags" "initial"
    done
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

# Main function
main() {
    header_info
    check_dependencies
    initialize_yaml_file
    update_yaml_with_current_containers
    validate_ips_in_yaml
    echo -e "${GN}[Info]${CL} Finished updating YAML file."
}

main
