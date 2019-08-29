#!/bin/bash

PROGRAM_NAME=${0##*/}

print_help()
{
  # Keep the help string in its own variable because a single quote in a heredoc messes up syntax
  # highlighting.
  HELP_STRING="
Usage: $PROGRAM_NAME [-hp] [MOD...]
Launches The Simpsons: Hit & Run via Wine.

  -h    Show this help message and exit.
  -p    Print the path of the game working directory used if found and exits. Returns 1 if none
could be found.

First, this script will check to see if the game working directory
\"~/.local/share/the-simpsons-hit-and-run\" exists, and use it if it does. If not, this script will
check if \"/usr/share/the-simpsons-hit-and-run\" exists and use that. If no working directory was
found, an error will be outputted and 1 will be returned.

For more info, see the wiki:
https://gitlab.com/CodingKoopa/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wikis/Game-Launcher"
  echo "$HELP_STRING"
  exit 0
}

####################################################################################################
### Argument parsing.
####################################################################################################

PRINT_PATH=false

while getopts "hp" opt; do
  case $opt in
    h)
      print_help
      ;;
    p)
      PRINT_PATH=true
      ;;
    *)
      print_help
      ;;
  esac
done
# Shift the options over to the mod list.
shift "$((OPTIND-1))"

####################################################################################################
### Common variables.
####################################################################################################

declare SHAR_PATH
USER_SHAR_PATH="$HOME/.local/share/the-simpsons-hit-and-run"
SYSTEM_SHAR_PATH="/usr/share/the-simpsons-hit-and-run"

if [[ -d "$USER_SHAR_PATH" ]]; then
  SHAR_PATH=$USER_SHAR_PATH
elif [[ -d "$SYSTEM_SHAR_PATH" ]]; then
  SHAR_PATH=$SYSTEM_SHAR_PATH
else
  if [[ "$PRINT_PATH" = true ]]; then
    exit 1
  fi
  zenity --title "The Simpsons: Hit & Run" --width 500 --error --text "The Simpsons: Hit &amp; \
Run game working directory not found. Please move the contents of your installation to either \
$USER_SHAR_PATH or $SYSTEM_SHAR_PATH."
  exit 1
fi

####################################################################################################
### Execution.
####################################################################################################

if [[ "$PRINT_PATH" = true ]]; then
  echo $SHAR_PATH
else
  # Set the working directory to the game's directory because it's not able to access its files
  # otherwise.
  (cd "$SHAR_PATH" && taskset -c 0 wine "$SHAR_PATH/Simpsons.exe")
fi