#!/bin/bash

PROGRAM_NAME=${0##*/}

print_help()
{
  # Keep the help string in its own variable because a single quote in a heredoc messes up syntax
  # highlighting.
  HELP_STRING="
Usage: $PROGRAM_NAME [-hios] [MOD...]
Sets up a Wine prefix and directory structure for and launches Lucas' Simpsons Hit & Run Mod
Launcher via Wine.

  -h    Show this help message and exit.
  -i    Reinitialize the data directory for the mod launcher, even if it already exists.
  -o    If initializing, overwrite the Wine prefix with a new one.
  -r    Set the mod launcher game executable path registry key, even if it looks to be already set.

If no arguments are specified, this script will check to see if the data directory,
~/.local/share/lucas-simpsons-hit-and-run-mod-launcher/, exists, and if not then it will install the
.NET 3.5 runtime and its Service Pack 1 that the mod launcher requiress is installed there. If the
directory does exist, it will be assumed that the runtime is already installed and skip the
installation. -i can be used to override this and force the runtime to be reinstalled.

Optionally, one or more mods or hacks can be specified at the end to be added to the mod listing.

In regards to the mod launcher executable, this script will check to see if the mod launcher
executable \"~/.local/share/lucas-simpsons-hit-and-run-mod-launcher/launcher/*.exe\" exists, and use
it if it does. If not, this script will check if
\"/usr/share/lucas-simpsons-hit-and-run-mod-launcher/*.exe\" exists and use that. If no executable
was found, an error will be outputted and 1 will be returned.

For more info, see the wiki:
https://gitlab.com/CodingKoopa/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wikis/Mod-Launcher-Launcher"
  echo "$HELP_STRING"
  exit 0
}

launch_mod_launcher()
{
  # Technically, wineboot is executed both on a normal run and during the first time initialization,
  # but this one doesn't really warrant its own Zenity progress bar because Wine booting after the
  # prefix has been created is unsignifigant enough to not really matter, it's pretty quick.
  wineboot &> "$WINE_WINEBOOT_LOG_FILE"

  # Enable font smoothing. Running this every launch is suboptimal, but necessary because winecfg
  # may reset the setting.
  winetricks fontsmooth=rgb &> "$LOG_DIRECTORY/winetricks-fontsmooth.log"

  # This regex matches the section of the Wine "reg" registry file where the mod launcher stores the
  # game EXE path.

  # Whenever it's necessary to input a registry path, eight backslashes are needed, \\\\\\\\. Here's
  # how it's processed:
  # - When interpreting this script, Bash escapes each couple of backslashes, becoming \\\\.
  # - When interpreting the temprary input "reg" file, regedit interprets \x, where x is a
  # character, as an escape sequence. Therefore, regedit also escapes each couple of backslashes,
  # becoming \\. I'm not entirely sure why, in the registry, it is stored like this.

  # TODO: Grep's "-z" option separates each line by a null character. This is necessary here to make
  # a multiline pattern. However, unless Perl mode is used, \x00 can't be used to match a NUL. To
  # get around this, "." is currently used to match the null character, but it might be better to
  # convert the pattern to that of Perl's and properly match it.
  grep -Ezq "\[Software\\\\\\\\Lucas Stuff\\\\\\\\Lucas' Simpsons Hit & Run Tools\] [0-9]{10} [0-9]{7}.\
#time=([0-9]|[a-z]){15}.\
\"Game EXE Path\"=\".+\".\
\"Game Path\"=\".+\"" $WINEPREFIX/user.reg
  if [[ $ALWAYS_SET_EXE_PATH_REGISTRY_KEY = true || $? -ne 0 ]]; then
    GAME_WORKING_DIRECTORY=$(the-simpsons-hit-and-run -p)
    if [[ $? -eq 0 ]]; then
      zenity --width 500 --timeout 5 --info --text "Located a game working directory at \"\
$GAME_WORKING_DIRECTORY\". Configuring the mod launcher to use it."
      cat << EOF > $WINEPREFIX/drive_c/windows/temp/lml_set_game_exe_path.reg
REGEDIT4

[HKEY_CURRENT_USER\\Software\\Lucas Stuff\\Lucas' Simpsons Hit & Run Tools]
"Game EXE Path"="$(winepath -w $GAME_WORKING_DIRECTORY/Simpsons.exe | sed -E "s/\\\/\\\\\\\\/g")"
"Game Path"="$(winepath -w $GAME_WORKING_DIRECTORY | sed -E "s/\\\/\\\\\\\\/g")"
EOF
      wine regedit $WINEPREFIX/drive_c/windows/temp/lml_set_game_exe_path.reg
    else
      zenity --width 500 --error --text "Failed to locate a game working directory. To learn how \
to set one up, see the wiki: \
https://github.com/CodingKoopa/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki/Game-Launcher#working-directories
Although you can manually select your game executable from the mod launcher interface, it is \
recommended to setup a working directory."
    fi
  fi

  # Launch the mod launcher in the background, using taskset to avoid a multicore issue.
  # We don't have to pass a hacks directory because, the way the structure works out, the launcher
  # can already see them anyways.
  taskset -c 0 wine "$MOD_LAUNCHER_EXECUTABLE" -mods "Z:/usr/share/$PACKAGE_NAME/mods/" \
      "${MOD_LAUNCHER_ARGUMENTS[@]}" &> "$MOD_LAUNCHER_LOG_FILE" &
}

####################################################################################################
### Argument parsing.
####################################################################################################

FORCE_INIT=false
OVEWRWRITE_WINE_PREFIX=false
ALWAYS_OVERWRITE_SYMLINKS=false
ALWAYS_SET_EXE_PATH_REGISTRY_KEY=false

while getopts "hiosr" opt; do
  case $opt in
  h)
    print_help
    ;;
  i)
    FORCE_INIT=true
    ;;
  o)
    OVEWRWRITE_WINE_PREFIX=true
    ;;
  r)
    ALWAYS_SET_EXE_PATH_REGISTRY_KEY=true
    ;;
  *)
    print_help
    ;;
  esac
done
# Shift the options over to the mod list.
shift "$((OPTIND-1))"

# Generate "-mod" arguments for the mod launcher from the arguments passed to the end of this
# script.
declare -a MOD_LAUNCHER_ARGUMENTS
for FILE in "$@"; do
  FILE_EXTENTION=${FILE##*.}
  if [[ "$FILE_EXTENTION" = "lmlm" ]]; then
    MOD_LAUNCHER_ARGUMENTS+=("-mod")
    # By defualt, Wine maps the Z drive to "/" on the host filesystem.
    MOD_LAUNCHER_ARGUMENTS+=("Z:$FILE")
  elif [[ "$FILE_EXTENTION" = "lmlh" ]]; then
    MOD_LAUNCHER_ARGUMENTS+=("-hack")
    # By defualt, Wine maps the Z drive to "/" on the host filesystem.
    MOD_LAUNCHER_ARGUMENTS+=("Z:$FILE")
  fi
done

####################################################################################################
### Common variables.
####################################################################################################

# Suggested package name, reused for most of this launcher's support files.
PACKAGE_NAME="lucas-simpsons-hit-and-run-mod-launcher"

# Path to directory within the user data directory for storing logs. This is something specific to
# this Linux launcher, and is not a part of the original mod launcher.
LOG_DIRECTORY="$HOME/Documents/My Games/Lucas' Simpsons Hit & Run Mod Launcher/Logs"
# Path to the log file for when Wine is booting up.
WINE_WINEBOOT_LOG_FILE="$LOG_DIRECTORY/wine-wineboot.log"
# Path to the log fike for the mod launcher.
MOD_LAUNCHER_LOG_FILE="$LOG_DIRECTORY/$PACKAGE_NAME.log"

function lazy-glob
{
  for FILE in $1; do
    break
  done
  if [[ "$FILE" != "$1" ]]; then
    echo "$FILE"
  fi
}
# Path to mod launcher executable in the user file folder.
USER_MOD_LAUNCHER_EXECUTABLE=$(lazy-glob "$NEW_USER_DATA_DIRECTORY/launcher/*.exe")
# Path to mod launcher executable in the system library folder.
SYSTEM_MOD_LAUNCHER_EXECUTABLE=$(lazy-glob "/usr/lib/$PACKAGE_NAME/*.exe")

if [[ -f "$USER_MOD_LAUNCHER_EXECUTABLE" ]]; then
  MOD_LAUNCHER_EXECUTABLE=$USER_MOD_LAUNCHER_EXECUTABLE
elif [[ -f "$SYSTEM_MOD_LAUNCHER_EXECUTABLE" ]]; then
  MOD_LAUNCHER_EXECUTABLE=$SYSTEM_MOD_LAUNCHER_EXECUTABLE
else
  zenity --title "Lucas' Simpsons Hit & Run Mod Launcher" --width 500 --error --text "Lucas' \
Simpsons Hit &amp; Run Mod Launcher executable not found. This package was likely incorrectly \
installed."
  exit 1
fi

# Architecture for Wine to use. The .NET 3.5 runtime only works on 32-bit.
export WINEARCH='win32'
# Path to the Wine prefix, in the user data directory.
export WINEPREFIX="$HOME/.local/share/wineprefixes/$PACKAGE_NAME"

####################################################################################################
### Initialization and execution.
####################################################################################################

# If the user forced initialization via the "-i" argument, or there's no existing user data
# directory.
if [[ "$FORCE_INIT" = true || ! -d "$NEW_USER_DATA_DIRECTORY" ]]; then
  # Arguments passed to Zenity that are always the same.
  ZENITY_COMMON_ARGUMENTS=(
      --title "Lucas' Simpsons Hit & Run Mod Launcher First Time Initialization"
      --width 500
  )
  # First time initialization subshell, with progress tracked by Zenity's progress bar.
  (
    # Our logging directory is independent of the mod launcher's original data directories.
    mkdir -p "$LOG_DIRECTORY"

    # Remove the Wine prefix, if specfied.
    if [[ "$OVEWRWRITE_WINE_PREFIX" = true ]]; then
      rm -rf "$WINEPREFIX"
    fi

    echo "# Booting up Wine."
    wineboot &> "$WINE_WINEBOOT_LOG_FILE"

    # Path to the log file for when Winetricks is installing the .NET 3.5 runtime.
    WINETRICKS_DOTNET35_LOG_FILE="$LOG_DIRECTORY/winetricks-dotnet35.log"

    SKIP_WINETRICKS_DOTNET35=false
    if [[ $(winetricks list-installed) == *"dotnet35"* ]]; then
      echo "# Skipping .NET 3.5 runtime installation."
      SKIP_WINETRICKS_DOTNET35=true
    else
      echo "# Installing the .NET 3.5 runtime. This may take a while, use \"tail -f \
$WINETRICKS_DOTNET35_LOG_FILE\" to track internal status. If the installation hangs on \
\"Running /usr/bin/wineserver -w.\", run \"WINEPREFIX=$WINEPREFIX wine taskmgr\", and manually \
close each process. If an unidentified program encounters a fatal error, it's fine to continue the \
installation."
    fi

    if [[ "$SKIP_WINETRICKS_DOTNET35" = true ]] || winetricks dotnet35 &> \
        "$WINETRICKS_DOTNET35_LOG_FILE" ; then
      echo "# Launching the mod launcher."
      launch_mod_launcher
    else
      zenity "${ZENITY_COMMON_ARGUMENTS[@]}" --error --text "Failed to install the .NET 3.5 \
runtime. See \"$WINETRICKS_DOTNET35_LOG_FILE\" for more info."
      echo "# An error occured while initializing Lucas' Simpsons Hit & Run Mod Launcher. To \
reinitialize with a new Wine prefix, run \"$PROGRAM_NAME -io\"."
    fi

    echo EOF
  ) |
  zenity "${ZENITY_COMMON_ARGUMENTS[@]}" --progress --pulsate
else
  # It's possible the logs have been cleared.
  mkdir -p "$LOG_DIRECTORY"

  launch_mod_launcher
fi
