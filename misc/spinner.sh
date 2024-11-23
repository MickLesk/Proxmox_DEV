#!/bin/bash
# https://github.com/Kaderovski/shloader
# Improved version

set -Eeuo pipefail

# Predefined loaders
declare -A LOADERS=(
  [ball_wave]=('0.1' '𓃉𓃉𓃉' '𓃉𓃉∘' '𓃉∘°' '∘°∘' '°∘𓃉' '∘𓃉𓃉')
  [dots]=('0.2' '...' '..' '.' '...' '..')
  [spinner]=('0.1' '|' '/' '-' '\\')
)

# Print usage information
usage() {
  cat <<EOF
ShLoader - Bash Loading Animation Utility

Usage: $0 [OPTIONS]

Options:
  -h, --help            Display this help message
  -l, --loader <name>   Choose loader type (default: dots)
  -m, --message <text>  Text to display during loading
  -e, --ending <text>   Text to display when finished
EOF
  exit 0
}

# Error handling
die() {
  local message="${1:-An error occurred}"
  local code="${2:-1}"
  echo "ERROR: ${message}" >&2
  exit "${code}"
}

# Clean up function
cleanup() {
  kill "${loader_pid}" &>/dev/null 2>&1
  tput cnorm  # Restore cursor
}

# Play loader animation
play_loader() {
  local loader=("${@}")
  local speed="${loader[0]}"
  unset "loader[0]"

  while true; do
    for frame in "${loader[@]}"; do
      printf "\r%s" "${frame} ${message}"
      sleep "${speed}"
    done
  done
}

# Main loader function
shloader() {
  trap cleanup SIGINT SIGTERM ERR EXIT

  local loader_name="ball_wave"
  local message=""
  local ending=""

  # Parse command-line arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage ;;
      -l|--loader) 
        loader_name="${2:-ball_wave}"
        shift 2
        ;;
      -m|--message) 
        message="${2:-}"
        shift 2
        ;;
      -e|--ending) 
        ending="${2:-}"
        shift 2
        ;;
      *) die "Unknown option: $1" ;;
    esac
  done

  # Validate loader
  [[ -z "${LOADERS[${loader_name}]}" ]] && die "Invalid loader: ${loader_name}"

  # Hide cursor
  tput civis

  # Start loader
  play_loader "${LOADERS[${loader_name}][@]}" &
  local loader_pid=$!

  # Wait for termination
  wait "${loader_pid}"

  # Display ending message if provided
  [[ -n "${ending}" ]] && printf "\r%s\n" "${ending}"
}

# Run the loader
shloader "$@"