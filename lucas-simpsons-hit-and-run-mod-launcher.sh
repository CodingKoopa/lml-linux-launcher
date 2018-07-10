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
  -s    If initializing, overwrite existing symlinks in the original data directory without
prompting.
  -r    Set the mod launcher game executable path registry key, even if it looks to be already set.

If no arguments are specified, this script will check to see if the data directory,
~/.local/share/lucas-simpsons-hit-and-run-mod-launcher/, exists, and if not then it will install the
.NET 3.5 runtime and its Service Pack 1 that the mod launcher requiress is installed there. If the
directory does exist, it will be assumed that the runtime is already installed and skip the
installation. -i can be used to override this and force the runtime to be reinstalled.

Optionally, one or more mods or hacks can be specified at the end to be added to the mod listing.

For more info, see the wiki:
https://github.com/CodingKoopa/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki/Mod-Launcher-Launcher"
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
  grep -Ezq "\[Software\\\\\\\\Lucas Stuff\\\\\\\\Lucas' Simpsons Hit & Run Tools\] [0-9]{10}.\
#time=([0-9]|[a-z]){15}.\
\"Game EXE Path\"=\".+\".\
\"Game Path\"=\".+\"" $WINEPREFIX/user.reg
  if [[ $ALWAYS_SET_EXE_PATH_REGISTRY_KEY = true || $? -ne 0 ]]; then
    GAME_WORKING_DIRECTORY=$(the-simpsons-hit-and-run.sh -p)
    if [[ $? -eq 0 ]]; then
      zenity --width 500 --timeout 5 --info --text "Located a game working directory at \"\
$GAME_WORKING_DIRECTORY\". Configuring the mod launcher to use it."
      cat << EOF > $WINEPREFIX/drive_c/windows/temp/lml_set_game_exe_path.reg
REGEDIT4

[HKEY_CURRENT_USER\\Software\\Lucas Stuff\\Lucas' Simpsons Hit & Run Tools]
"Game EXE Path"="$(winepath -w $GAME_WORKING_DIRECTORY/Simpsons.exe | sed -E "s/\\\/\\\\\\\\/g")"
"Game Path="$(winepath -w $GAME_WORKING_DIRECTORY/Simpsons.exe | sed -E "s/\\\/\\\\\\\\/g")"
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
    s)
      ALWAYS_OVERWRITE_SYMLINKS=true
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

# Path to mod launcher executable in the system library folder.
MOD_LAUNCHER_EXECUTABLE="/usr/lib/$PACKAGE_NAME/$PACKAGE_NAME.exe"
# Path to the directory where the mod launcher expects its user files to be. We will be symlinking
# the subdirectories here to NEW_USER_DATA_DIRECTORY.
ORIGINAL_USER_DATA_DIRECTORY="$HOME/Documents/My Games/Lucas' Simpsons Hit & Run Mod Launcher"

# Path to directory in the user's home folder for storing user specific data.
NEW_USER_DATA_DIRECTORY="$HOME/.local/share/$PACKAGE_NAME"
# Path to directory within the user data directory for storing logs. This is something specific to
# this Linux launcher, and is not a part of the original mod launcher.
LOG_DIRECTORY="$NEW_USER_DATA_DIRECTORY/logs"
# Path to the log file for when Wine is booting up.
WINE_WINEBOOT_LOG_FILE="$LOG_DIRECTORY/wine-wineboot.log"
# Path to the log fike for the mod launcher.
MOD_LAUNCHER_LOG_FILE="$LOG_DIRECTORY/$PACKAGE_NAME.log"

# Architecture for Wine to use. The .NET 3.5 SP1 runtime only works on 32-bit.
export WINEARCH='win32'
# Path to the Wine prefix, in the user data directory.0
export WINEPREFIX="$NEW_USER_DATA_DIRECTORY/wine/"

####################################################################################################
### Initialization and Execution
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
    echo "# Making data directory structure."

    # If the mod launcher has never before been ran, its original directory won't exist.
    mkdir -p "$ORIGINAL_USER_DATA_DIRECTORY"
    # Use -p to not throw an error if the directory already exists, in the case of forced
    # initialization.
    mkdir -p "$NEW_USER_DATA_DIRECTORY"

    # Paths to the normal mod launcher directories that will be linked to the user's data directory.
    declare -A LINKED_DATA_PATHS=(
      ["$NEW_USER_DATA_DIRECTORY/crashes/"]="$ORIGINAL_USER_DATA_DIRECTORY/Crashes"
      ["$NEW_USER_DATA_DIRECTORY/mods/"]="$ORIGINAL_USER_DATA_DIRECTORY/Mods"
      ["$NEW_USER_DATA_DIRECTORY/saves/"]="$ORIGINAL_USER_DATA_DIRECTORY/Saved Games"
      ["$NEW_USER_DATA_DIRECTORY/screenshots/"]="$ORIGINAL_USER_DATA_DIRECTORY/Screenshots"
    )

    for NEW_USER_DATA_SUBDIRECTORY in "${!LINKED_DATA_PATHS[@]}"; do
      ORIGINAL_USER_DATA_SUBDIRECTORY=${LINKED_DATA_PATHS[$NEW_USER_DATA_SUBDIRECTORY]}

      echo "# Linking original mod launcher data directory \"$ORIGINAL_USER_DATA_SUBDIRECTORY\" to \
new data directory $NEW_USER_DATA_SUBDIRECTORY."

      # Define the arguments to be passed to "ln" becuase we'll be appending to them later.
      LN_ARGS="-sT"
      # Options to change linking behavior.
      SKIP_LINK=false
      OVERWRITE_LINK=false

      # If there's already a preexisting mod launcher subdirectory that's not a symlink.
      if [[ -d "$ORIGINAL_USER_DATA_SUBDIRECTORY" && ! -L "$ORIGINAL_USER_DATA_SUBDIRECTORY" ]]; \
            then
        # If there's already a new user mod launcher file/directory/whatever.
        if [[ -e "$NEW_USER_DATA_SUBDIRECTORY" ]]; then
          if zenity "${ZENITY_COMMON_ARGUMENTS[@]}" --question --text "Both original mod launcher \
user data subdirectory \"${ORIGINAL_USER_DATA_SUBDIRECTORY/&/&amp;}\" and new user data \
subdirectory \"$NEW_USER_DATA_SUBDIRECTORY\" already exist. Do you want to use the existing new \
user data subdirectory (\"$NEW_USER_DATA_SUBDIRECTORY\")?"; then
            rm -rf "$ORIGINAL_USER_DATA_SUBDIRECTORY"
          else
            rm -rf "$NEW_USER_DATA_SUBDIRECTORY"
            mv "$ORIGINAL_USER_DATA_SUBDIRECTORY" "$NEW_USER_DATA_SUBDIRECTORY"
          fi
        fi

      # If there's a symlink/file where preexisting mod launcher data would be. -e isn't used
      # because it doesn't include broken symlinks.
      elif [[ -f "$ORIGINAL_USER_DATA_SUBDIRECTORY" || -L "$ORIGINAL_USER_DATA_SUBDIRECTORY" ]]; then
        if [[ "$ALWAYS_OVERWRITE_SYMLINKS" = true ]] || zenity "${ZENITY_COMMON_ARGUMENTS[@]}" \
            --question --text "Symlink or file at \"${ORIGINAL_USER_DATA_SUBDIRECTORY/&/&amp;}\" \
already exists. Do you want to replace it? If you're rerunning this after intializing the new \
directory before, you can click \"Yes\"."; then
          OVERWRITE_LINK=true
          mkdir -p "$NEW_USER_DATA_SUBDIRECTORY"
        else
          SKIP_LINK=true
        fi

      # If there's no preexisting original mod launcher data.
      else
        mkdir -p "$NEW_USER_DATA_SUBDIRECTORY"
      fi

      if [[ $OVERWRITE_LINK = true ]]; then
        LN_ARGS+="f"
      fi

      if [[ $SKIP_LINK = false ]]; then
        # Link the directory where the mod launcher expects its data to be to our new data
        # directory.
        ln "$LN_ARGS" "$NEW_USER_DATA_SUBDIRECTORY" "$ORIGINAL_USER_DATA_SUBDIRECTORY"
      fi
    done

    # Our logging directory is independent of the mod launcher's original data directories.
    mkdir -p "$LOG_DIRECTORY"

    # Remove the Wine prefix, if specfied.
    if [[ "$OVEWRWRITE_WINE_PREFIX" = true ]]; then
      rm -rf "$WINEPREFIX"
    fi

    echo "# Booting up Wine."
    wineboot &> "$WINE_WINEBOOT_LOG_FILE"

    # Path to the log file for when Winetricks is installing the .NET 3.5 SP1 runtime.
    WINETRICKS_DOTNET35SP1_LOG_FILE="$LOG_DIRECTORY/winetricks-dotnet35sp1.log"

    SKIP_WINETRICKS_DOTNET35SP1=false
    if [[ $(winetricks list-installed) == *"dotnet35sp1"* ]]; then
      echo "# Skipping .NET 3.5 SP1 runtime installation."
      SKIP_WINETRICKS_DOTNET35SP1=true
    else
      echo "# Installing the .NET 3.5 SP1 runtime. This may take a while, use \"tail -f \
$WINETRICKS_DOTNET35SP1_LOG_FILE\" to track internal status. If the installation hangs on \
\"Running /usr/bin/wineserver -w.\", run \"WINE_PREFIX=$WINEPREFIX wine taskmgr\", and manually \
close each process. If an unidentified program encounters a fatal error, it's fine to continue the \
installation."
    fi

    if [[ "$SKIP_WINETRICKS_DOTNET35SP1" = true ]] || winetricks dotnet35sp1 &> \
        "$WINETRICKS_DOTNET35SP1_LOG_FILE" ; then
      echo "# Launching the mod launcher."
      launch_mod_launcher
    else
      zenity "${ZENITY_COMMON_ARGUMENTS[@]}" --error --text "Failed to install the .NET 3.5 SP1 \
runtime. See \"$WINETRICKS_DOTNET35SP1_LOG_FILE\" for more info."
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
