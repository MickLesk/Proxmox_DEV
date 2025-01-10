#!/usr/bin/env bash

output_file="./misc/combined.txt"
> "$output_file"  # Clear or create the file

# Search for regular .sh files in ./ct
find ./ct -type f -name "*.sh" | while read -r script; do
  # Extract the APP name from the APP line
  app_name=$(grep -oP '^APP="\K[^"]+' "$script" 2>/dev/null)

  if [[ -n "$app_name" ]]; then
    # Generate Figlet output for the app name
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

# Sort the file alphabetically (A-Z)
sort -o "$output_file" "$output_file"

echo "Generated combined file at $output_file"
