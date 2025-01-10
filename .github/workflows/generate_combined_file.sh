#!/usr/bin/env bash

output_file="./misc/combined.txt"
> "$output_file"  # Datei leeren oder neu erstellen

# Holen des aktuellen Datums im amerikanischen Format
current_date=$(date +"%m-%d-%Y")

# Header mit Datum
{
  echo "### Generated on $current_date"
  echo
}

# Durchsuche nur reguläre Dateien mit der Endung .sh in ./ct, sortiere sie alphabetisch
find ./ct -type f -name "*.sh" | sort | while read -r script; do
  # Extrahiere den APP-Namen aus der APP-Zeile
  app_name=$(grep -oP '^APP="\K[^"]+' "$script" 2>/dev/null)

  if [[ -n "$app_name" ]]; then
    # Erzeuge Figlet-Ausgabe
    figlet_output=$(figlet -f slant "$app_name")
    {
      echo "### $(basename "$script")"
      echo "APP=$app_name"
      echo "$figlet_output"
      echo
    } >> "$output_file"
  else
    echo "No APP name found in $script, skipping."
  fi
done

echo "Generated combined file at $output_file"
