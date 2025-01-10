#!/usr/bin/env bash

output_file="./misc/combined.txt"
> "$output_file"  # Clear or create the file

# Get the last Git commit hash
commit_hash=$(git log -1 --format=%h)

# Add header with commit hash as version
{
  echo "### Version $commit_hash"
  echo "##################################################"
  echo
}

# Find only regular .sh files in ./ct, sort them alphabetically
find ./ct -type f -name "*.sh" | sort | while read -r script; do
  # Extract the APP name from the APP line
  app_name=$(grep -oP '^APP="\K[^"]+' "$script" 2>/dev/null)

  if [[ -n "$app_name" ]]; then
    # Generate figlet output
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
