#!/bin/bash

# Überprüfen, ob der Benutzer root ist
if [ "$(id -u)" != "0" ]; then
    echo "Dieses Skript muss als root ausgeführt werden" 1>&2
    exit 1
fi

# Funktion zum Prüfen, ob die Container-ID bereits existiert
container_id_exists() {
    local id=$1
    if [ -f "/etc/pve/lxc/${id}.conf" ]; then
        return 0
    else
        return 1
    fi
}

# Funktion zum Prüfen, ob der Container läuft
container_running() {
    local status=$(pct status $1)
    if [[ $status == *"running"* ]]; then
        return 0
    else
        return 1
    fi
}

# Funktion zum Überprüfen des Container-Namens
validate_container_name() {
    local name=$1
    if [[ ! $name =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Ungültiger Container-Name. Es sind nur alphanumerische Zeichen, Bindestriche und Unterstriche erlaubt."
        exit 1
    fi
}

# Optionenmenü anzeigen
echo "Wählen Sie eine Option:"
echo "1. Ändern der Container-ID"
echo "2. Ändern des Container-Namens"
echo "3. Beenden"

# Eingabeaufforderung für die Option
read -p "Option (1/2/3): " OPTION

case $OPTION in
    1)
        # Option 1: Ändern der Container-ID

        # Eingabeaufforderung für die alte ID
        read -p "Geben Sie die ID des Containers ein, der eine neue ID bekommen soll: " OLD_ID

        # Überprüfen, ob die ID vorhanden ist
        if [ ! -f "/etc/pve/lxc/${OLD_ID}.conf" ]; then
            echo "Container mit der ID ${OLD_ID} existiert nicht."
            exit 1
        fi

        # Eingabeaufforderung für die neue ID
        read -p "Geben Sie die neue ID für den Container ein: " NEW_ID

        # Überprüfen, ob die neue ID numerisch ist und kleiner als 1000
        if ! [[ $NEW_ID =~ ^[0-9]+$ ]]; then
            echo "Ungültige ID. Es sind nur numerische Zeichen erlaubt."
            exit 1
        fi

        if [ $NEW_ID -ge 1000 ]; then
            echo "Die ID muss kleiner als 1000 sein."
            exit 1
        fi

        # Überprüfen, ob die neue ID bereits existiert
        if container_id_exists $NEW_ID; then
            echo "Die ID $NEW_ID ist bereits einem anderen Container zugewiesen."
            exit 1
        fi

        # Container stoppen, wenn er aktiv ist
        if container_running $OLD_ID; then
            echo "Container läuft, wird gestoppt..."
            pct stop $OLD_ID
        fi

        # Umbenennen der Container-ID
        mv /etc/pve/lxc/${OLD_ID}.conf /etc/pve/lxc/${NEW_ID}.conf
        mv /var/lib/lxc/${OLD_ID} /var/lib/lxc/${NEW_ID}

        # Konfigurationsdatei aktualisieren
        sed -i "s/${OLD_ID}/${NEW_ID}/g" /etc/pve/lxc/${NEW_ID}.conf

        # Container starten, wenn er zuvor lief und der Benutzer zustimmt
        if [ "$RESTART_CONTAINER" = true ]; then
            pct start $NEW_ID
        fi

        echo "LXC-Container-ID erfolgreich geändert von $OLD_ID zu $NEW_ID"
		# Fragen, ob der Container neu gestartet werden soll
        read -p "Der Container wurde gestoppt. Möchten Sie ihn neu starten? (y/n): " START_CONTAINER
        if [ "$START_CONTAINER" = "y" ]; then
                RESTART_CONTAINER=true
        fi
        ;;

    2)
        # Option 2: Ändern des Container-Namens

        # Eingabeaufforderung für die Container-ID
        read -p "Geben Sie die ID des Containers ein, den Sie umbenennen möchten: " CONTAINER_ID

        # Überprüfen, ob die ID vorhanden ist
        if [ ! -f "/etc/pve/lxc/${CONTAINER_ID}.conf" ]; then
            echo "Container mit der ID ${CONTAINER_ID} existiert nicht."
            exit 1
        fi

        # Wenn der Container läuft, stoppen
        if container_running $CONTAINER_ID; then
            echo "Container läuft, wird gestoppt..."
            pct stop $CONTAINER_ID
        fi

        # Eingabeaufforderung für den neuen Namen
        read -p "Geben Sie den neuen Namen für den Container ein: " NEW_NAME

        # Überprüfen, ob der neue Name bereits existiert
        if container_id_exists $NEW_NAME; then
            echo "Ein Container mit dem Namen $NEW_NAME existiert bereits."
            exit 1
        fi

        # Überprüfen, ob der neue Name alphanumerisch ist und keine Sonderzeichen enthält
        validate_container_name $NEW_NAME

        # Ändern des Hostnamens in der Konfigurationsdatei
        sed -i "s/hostname: .*/hostname: $NEW_NAME/g" /etc/pve/lxc/${CONTAINER_ID}.conf

        # Container starten, wenn er zuvor lief
        if container_running $CONTAINER_ID; then
            read -p "Container wurde gestoppt. Möchten Sie ihn neu starten? (y/n): " START_CONTAINER
            if [ "$START_CONTAINER" = "y" ]; then
                pct start $CONTAINER_ID
            fi
        fi

        echo "LXC-Container erfolgreich umbenannt von ID $CONTAINER_ID zu $NEW_NAME"
        ;;
        
    3)
        # Option 3: Beenden des Skripts
        echo "Skript wird beendet."
        exit 0
        ;;
    *)
        echo "Ungültige Option. Bitte wählen Sie eine der angegebenen Optionen."
        exit 1
        ;;
esac
