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
        update_yaml_with_current_containers
    fi

    # Überprüfe, ob die Datei jetzt befüllt ist
    echo -e "DEBUG: Contents of YAML file after initialization:"
    cat "$yaml_file"
}

# Function: Update the YAML file with current containers
update_yaml_with_current_containers() {
    echo -e "${GN}[Info]${CL} Updating YAML file with current containers."
    
    # Ausgabe von pct list zur Debugging-Überprüfung
    pct list

    # Warten, falls keine Container vorhanden sind
    if [[ $(pct list | grep -c "running") -eq 0 ]]; then
        echo -e "${RD}[Warning]${CL} No running containers found."
        return 1
    fi

    # Iteration über alle laufenden Container
    while read -r id name; do
        echo -e "DEBUG: Processing Container - ID: $id, Name: $name"  # Debugging-Ausgabe

        # Holen der Konfiguration jedes Containers, um die IP und Tags zu erhalten
        container_ip=$(pct exec "$id" ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)
        container_tags=$(pct config "$id" | grep "^tags:" | cut -d: -f2 | tr -d '[:space:]')

        # Wenn keine IP gefunden wird, überspringen
        if [[ -z "$container_ip" ]]; then
            echo -e "${RD}[Error]${CL} No IP found for container $name. Skipping...\n"
            continue
        fi

        # Wenn keine Tags vorhanden sind, dann neue Tags setzen
        if [[ -z "$container_tags" ]]; then
            container_tags="$container_ip"
        else
            container_tags="$container_tags,$container_ip"
        fi

        # Container zur YAML-Datei hinzufügen
        add_or_update_container_in_yaml "$id" "$name" "$container_ip" "$container_tags" "initial"
    done < <(pct list | awk 'NR>1 {print $1, $2}' | grep "running")
}

# Funktion zum Hinzufügen oder Aktualisieren eines Containers in der YAML-Datei
add_or_update_container_in_yaml() {
    local id="$1"
    local name="$2"
    local ip="$3"
    local tags="$4"
    local update_type="${5:-manual}"

    # Debugging-Ausgabe
    echo "DEBUG: Adding/updating container - ID: $id, Name: $name, IP: $ip, Tags: $tags, Update Type: $update_type"

    # YAML-Eintrag hinzufügen oder aktualisieren
    yq eval ".containers += [{id: \"$id\", name: \"$name\", tags: [\"$tags\"], last_update: \"$(date -Iseconds)\"}]" "$yaml_file" -i

    echo -e "DEBUG: YAML content after update:"
    cat "$yaml_file"  # Ausgabe zur Überprüfung der Datei
}

# Function: Validate IPs in YAML
validate_ips_in_yaml() {
    echo -e "${GN}[Info]${CL} Validating IPs in YAML file."

    # Get all container IDs from YAML
    mapfile -t container_ids < <(yq ".containers[].id" "$yaml_file")

    for id in "${container_ids[@]}"; do
        if pct status "$id" &>/dev/null; then
            # Get current IP for the container
            current_ip=$(pct exec "$id" ip addr show eth0 | grep "inet " | awk '{print $2}' | cut -d/ -f1)

            # Update IP if needed
            add_or_update_container_in_yaml "$id" "" "$current_ip"
        else
            # Remove container if it no longer exists
            echo -e "${RD}[Info]${CL} Container $id no longer exists. Removing from YAML."
            yq -i ".containers |= map(select(.id != \"$id\"))" "$yaml_file"
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
    initialize_yaml_file
	add_or_update_container_in_yaml
    validate_ips_in_yaml

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
