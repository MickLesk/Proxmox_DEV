whiptail --backtitle "Proxmox VE Helper Scripts" --msgbox --title "Default distribution for $APP" "${var_os} ${var_version} \n \nIf the default Linux distribution is not adhered to, script support will be discontinued. \n" 10 58

if [ "$var_os" != "alpine" ]; then
  var_os=""
  while [ -z "$var_os" ]; do
    if var_os=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "DISTRIBUTION" --radiolist "Choose Distribution:" 10 58 3 \
      "debian" "" OFF \
      "ubuntu" "" OFF \
      "Back" "Exit script" ON \
      3>&1 1>&2 2>&3); then
      if [ "$var_os" == "Back" ]; then
        exit_script  # Skript beenden oder zurück zum übergeordneten Menü
      fi
      if [ -n "$var_os" ]; then
        echo -e "${OS}${BOLD}${DGN}Operating System: ${BGN}$var_os${CL}"
      fi
    else
      exit_script
    fi
  done
fi

if [ "$var_os" == "debian" ]; then
  var_version=""
  while [ -z "$var_version" ]; do
    if var_version=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "DEBIAN VERSION" --radiolist "Choose Version:" 10 58 3 \
      "11" "Bullseye" OFF \
      "12" "Bookworm" OFF \
      "Back" "Return to Distribution selection" ON \
      3>&1 1>&2 2>&3); then
      if [ "$var_version" == "Back" ]; then
        var_os=""  # Zurücksetzen der Distribution, um zur vorherigen Auswahl zurückzukehren
        break      # Zurück zur vorherigen Schleife
      fi
      if [ -n "$var_version" ]; then
        echo -e "${OSVERSION}${BOLD}${DGN}Version: ${BGN}$var_version${CL}"
      fi
    else
      exit_script
    fi
  done
fi
