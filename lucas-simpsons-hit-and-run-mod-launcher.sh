#!/bin/bash

print_help() {
  echo "Usage: ${0##*/} [-hidr] [MOD/HACK...]
Launches Lucas' Simpsons Hit & Run Mod Launcher via Wine.

  -h    Show this help message and exit.
  -i    Force the initialization of the Wine prefix.
  -d    If initializing, force the deletion of the existing prefix, if present.
  -r    Force the setting of the mod launcher game executable path registry key.

If no arguments are specified, this script will check to see if the Wine prefix
~/.local/share/lucas-simpsons-hit-and-run-mod-launcher exists. If it doesn't exist, it will be
created using wineboot. Then, Microsoft's implementation of the .NET 3.5 runtime will be installed
to it. If it does exist, or if it has just been installed, the mod launcher will be launched.

Optionally, one or more mods or hacks can be specified at the end to be added to the mod listing.

For more info, see the wiki: https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/"
}

function lml_linux_launcher() {
  local force_init=false
  local force_delete_prefix=false
  local always_set_registry_key=false

  while getopts "hidr" opt; do
    case $opt in
    i)
      force_init=true
      ;;
    d)
      force_delete_prefix=true
      ;;
    r)
      always_set_registry_key=true
      ;;
    *)
      print_help
      return 0
      ;;
    esac
  done
  # Shift the options over to the mod list.
  shift "$((OPTIND - 1))"

  local -ra ZENITY_COMMON_ARGUMENTS=(
    --title "Lucas' Simpsons Hit & Run Mod Launcher First Time Initialization"
    --width 500
  )

  # Generate arguments for the mod launcher from the arguments passed to the end of this script.
  local -a mod_launcher_arguments
  for file in "$@"; do
    local extension=${file##*.}
    if [[ "$extension" = "lmlm" ]]; then
      mod_launcher_arguments+=("-mod")
      # By defualt, Wine maps the Z drive to "/" on the host filesystem.
      mod_launcher_arguments+=("Z:$file")
    elif [[ "$extension" = "lmlh" ]]; then
      mod_launcher_arguments+=("-hack")
      # By defualt, Wine maps the Z drive to "/" on the host filesystem.
      mod_launcher_arguments+=("Z:$file")
    else
      zenity "${ZENITY_COMMON_ARGUMENTS[@]}" --warning --text "File \"$file\" not recognized as a \
file handled by the mod launcher, ignoring."
    fi
  done

  # Suggested package name, reused for most of this launcher's support files.
  local -r PACKAGE_NAME="lucas-simpsons-hit-and-run-mod-launcher"

  # Path to directory within the user data directory for storing logs. This is something specific to
  # this Linux launcher, and is not a part of the original mod launcher.
  local -r log_dir="$HOME/Documents/My Games/Lucas' Simpsons Hit & Run Mod Launcher/Logs"
  # Path to the log file for when Wine is booting up.
  local -r wineboot_log_file="$log_dir/wine-wineboot.log"
  # Path to the log file for the mod launcher.
  local -r launcher_log_file="$log_dir/$PACKAGE_NAME.log"

  # Path to mod launcher executable in the system library folder.
  local -r MOD_LAUNCHER_EXECUTABLE="/usr/lib/$PACKAGE_NAME/$PACKAGE_NAME.exe"

  if [[ ! -f "$MOD_LAUNCHER_EXECUTABLE" ]]; then
    zenity --title "Lucas' Simpsons Hit & Run Mod Launcher" --width 500 --error --text "Lucas' \
Simpsons Hit &amp; Run Mod Launcher executable not found at $MOD_LAUNCHER_EXECUTABLE. The package \
may not be correctly installed."
    return 1
  fi

  # Architecture for Wine to use. The .NET 3.5 runtime only works on 32-bit.
  export WINEARCH='win32'
  # Path to the Wine prefix, in the user data directory.
  export WINEPREFIX="$HOME/.local/share/wineprefixes/$PACKAGE_NAME"

  # First, initialize the Wine prefix if we have to.

  # If the user forced initialization via the "-i" argument, or there's no existing user data
  # directory.
  if [[ "$force_init" = true || ! -d "$WINEPREFIX" ]]; then
    # We haven't yet started the mod launcher, so this directory probably doesn't exist yet.
    mkdir -p "$log_dir"

    # Remove the Wine prefix, if specfied.
    if [[ "$force_delete_prefix" = true ]]; then
      rm -rf "$WINEPREFIX"
    fi
    # First time initialization subshell, with progress tracked by Zenity's progress bar.
    (
      echo "# Booting up Wine."
      wineboot &>"$wineboot_log_file"

      # Path to the log file for when Winetricks is installing the .NET 3.5 runtime.
      local -r dotnet35_log_file="$log_dir/winetricks-dotnet35.log"

      if [[ $(winetricks list-installed) == *"dotnet35"* ]]; then
        echo "# Microsoft .NET 3.5 is already installed, skipping.."
      else
        echo "# Installing the Microsoft .NET 3.5 runtime. This may take a while, use \"tail -f \
$dotnet35_log_file\" to track internal status. If the installation hangs on \
\"Running /usr/bin/wineserver -w.\", run \"WINEPREFIX=$WINEPREFIX wine taskmgr\", and manually \
close each process. If an unidentified program encounters a fatal error, it's fine to continue the \
installation."
        if ! winetricks dotnet35 &>"$dotnet35_log_file"; then
          zenity "${ZENITY_COMMON_ARGUMENTS[@]}" --error --text "Failed to install the Microsoft \
.NET 3.5 runtime. See \"$dotnet35_log_file\" for more info."
          echo "# An error occured while initializing Lucas' Simpsons Hit & Run Mod Launcher. To \
reinitialize with a new Wine prefix, run \"$PROGRAM_NAME -i\"."
        fi
      fi

      echo EOF
    ) |
      zenity "${ZENITY_COMMON_ARGUMENTS[@]}" --progress --pulsate
  fi

  # Then, do some house keeping with the Wine prefix.

  # Technically, wineboot is executed both on a normal run and during the first time initialization,
  # but this one doesn't really warrant its own Zenity progress bar because Wine booting after the
  # prefix has been created is unsignifigant enough to not really matter, it's pretty quick.
  wineboot &>"$wineboot_log_file"

  # Enable font smoothing. Running this every launch is suboptimal, but necessary because winecfg
  # may reset the setting.
  winetricks fontsmooth=rgb &>"$log_dir/winetricks-fontsmooth.log"

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
  if [[ $always_set_registry_key = true ]] ||
    grep -Ezq "\[Software\\\\\\\\Lucas Stuff\\\\\\\\Lucas' Simpsons Hit & Run Tools\] [0-9]{10} \
[0-9]{7}.#time=([0-9]|[a-z]){15}.\
\"Game EXE Path\"=\".+\".\
\"Game Path\"=\".+\"" "$WINEPREFIX/user.reg"; then

    if GAME_WORKING_DIRECTORY=$(the-simpsons-hit-and-run -p); then
      zenity --width 500 --timeout 5 --info --text "Located a game working directory at \"\
$GAME_WORKING_DIRECTORY\". Configuring the mod launcher to use it."
      cat <<EOF >"$WINEPREFIX/drive_c/windows/temp/lml_set_game_exe_path.reg"
REGEDIT4

[HKEY_CURRENT_USER\\Software\\Lucas Stuff\\Lucas' Simpsons Hit & Run Tools]
"Game EXE Path"="$(winepath -w "$GAME_WORKING_DIRECTORY/Simpsons.exe" | sed -E "s/\\\/\\\\\\\\/g")"
"Game Path"="$(winepath -w "$GAME_WORKING_DIRECTORY" | sed -E "s/\\\/\\\\\\\\/g")"
EOF
      wine regedit "$WINEPREFIX/drive_c/windows/temp/lml_set_game_exe_path.reg"
    else
      zenity --width 500 --error --text "Failed to locate a game working directory. To learn how \
to set one up, see the wiki: \
https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/Game-Launcher#working-directories
Although you can manually select your game executable from the mod launcher interface, it is \
recommended to setup a working directory."
    fi
  fi

  # Finally, launch Wine with the mod launcher executable.

  # Launch the mod launcher in the background, using taskset to avoid a multicore issue.
  # We don't have to pass a hacks directory because, the way the structure works out, the launcher
  # can already see them anyways.
  taskset -c 0 wine "$MOD_LAUNCHER_EXECUTABLE" -mods "Z:/usr/share/$PACKAGE_NAME/mods/" \
    "${mod_launcher_arguments[@]}" &>"$launcher_log_file" &
}

lml_linux_launcher "$@"
