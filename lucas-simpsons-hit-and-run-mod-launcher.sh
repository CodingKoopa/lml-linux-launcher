#!/bin/bash

PROGRAM_NAME=${0##*/}

# Prints an info message.
# Arguments:
#   - Info to be printed.
# Outputs:
#   - The info message.
function info() {
  printf "[$(tput setaf 6)Info$(tput sgr0)] %s\n" "$*"
}

# Prints an error message.
# Arguments:
#   - Error to be printed.
# Outputs:
#   - The error message.
function error() {
  printf "[$(tput setaf 1)Error$(tput sgr0)] %s\n" "$*"
}

# Prints a progress message.
# Arguments:
#   - Progress to be printed.
# Outputs:
#   - The progress message.
function progress() {
  printf "[$(tput setaf 2)Progress$(tput sgr0)] %s\n" "$*"
}

# Prints a Wine message.
# Arguments:
#   - Wine/Winetricks message to be printed.
# Outputs:
#   - The Wine message.
function winemsg() {
  printf "[$(tput setaf 5)Wine$(tput sgr0)] %s\n" "$*"
}

# Compares two semantic version strings. See: https://stackoverflow.com/a/4025065.
# Arguments:
#   - The first version.
#   - The second version.
# Returns:
#   - 0 if ver1 == ver2.
#   - 1 if ver1 > ver2.
#   - 2 if ver1 < ver2.
function version_compare() {
  if [[ $1 == "$2" ]]; then
    return 0
  fi
  local i
  local IFS=.
  read -r -a ver1 <<<"$1"
  read -r -a ver2 <<<"$2"
  # Fill empty fields in ver1 with zeros.
  for ((i = ${#ver1[@]}; i < ${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i = 0; i < ${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      # Fill empty fields in ver2 with zeros.
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 2
    fi
  done
  return 0
}

# Convenience function for using version_compare().
# Arguments:
#   - The first version.
#   - The operator, one of "=", ">", or "<".
#   - The second version.
# Outputs:
#   - An error if an invalid operator was given.
# Returns:
#   - 0 if the expression given is true.
#   - 1 if the expression given is false.
#   - 2 if the expression given is invalid.
function version_compare_operator() {
  version_compare "$1" "$3"
  case $? in
  0) op='=' ;;
  1) op='>' ;;
  2) op='<' ;;
  *)
    echo "Error: invalid operator \"$op\"."
    return 2
    ;;
  esac
  if [[ $op = "$2" ]]; then
    return 0
  else
    return 1
  fi
}

# Increments a Zenity progress bar.
# Variables Read:
#   - NUM_STEPS: The total number of steps.
# Variables Written:
#   - step: The current step.
# Arguments:
#   - (Optional) Number of steps to advance by. Defaults to 1.
# Outputs:
#   - The percentage.
function increment_progress() {
  inc=${1:-1}
  ((step += inc))
  # If the multiplication by 100 is done first, then the decimal number will be truncated to 0.
  echo $((step * 100 / NUM_STEPS))
}

# Sanitizes a string so that it may be displayed in Zenity without any problems. sed expression from
# https://unix.stackexchange.com/a/37663.
# Arguments:
#   - The input string.
# Outputs:
#   - The sanitized string.
function sanitize_zenity() {
  echo "$1" | sed -e 's/\\/\\\\/g' -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Echos output originally intended for Zenity. This function filters out percentages from
# increment_progress(), as well as the "# " prefix. This function also handles errors that arrise
# during the execution of the subshell, or from the cancel button being clicked. Finally, this
# handles our own "! " and "? " prefixes.
# Outputs:
#   - Filtered /dev/stdin contents.
# Returns:
#   - 0 if successful.
#   - 1 if an error occurred during the execution of the subshell.
#   - 2 if EOF was never reached. This generally indicates that the process was cancelled.
function zenity_echo() {
  local ret=0
  local eof_reached=false
  while read -r line; do
    # Ignore display number percentages used by Zenity.
    if [[ $line =~ ^[0-9]+$ ]]; then
      continue
    fi
    # Break on the first EOF received.
    if [[ $line = EOF ]]; then
      eof_reached=true
      break
    fi
    # Identify any error messages, as the return codes from the subshell are otherwise lost.
    if [[ ${line,,} = error:* ]]; then
      ret=1
    fi
    if [[ $line =~ ^\# ]]; then
      # Remove the "# " used by Zenity to mark text to display.
      progress "${line#"# "}"
    elif [[ $line =~ ^\! ]]; then
      info "${line#"! "}"
    elif [[ $line =~ ^\? ]]; then
      error "${line#"? "}"
    else
      winemsg "$line"
    fi
  done </dev/stdin
  info "Zenity has finished."
  # If EOF was never reached, then the cancel button was probably clicked. In that case, make sure
  # this isn't considered a success.
  if [[ $eof_reached = false ]]; then
    error "EOF not reached. Either an error occurred in the subshell, or user cancelled."
    ret=1
  fi
  return $ret
}

# Runs a command, redirecting log output to a file and to stdout.
# Variables Read:
#   - log_to_stdout: Whether to log to stdout.
# Outputs:
#   - Command output, if $log_to_stdout=true.
function run() {
  local command=$1
  local -r log_file=$2
  if [[ $log_to_stdout = true ]]; then
    eval "$command" 2>&1 | tee "$log_file"
  else
    eval "$command" &>"$log_file"
  fi
}

# Prints the help message for this script.
# Outputs:
#   - The help message.
function print_help() {
  echo "Usage: $PROGRAM_NAME [-hidr] [MOD/HACK...]
Launches Lucas' Simpsons Hit & Run Mod Launcher via Wine.

  -h    Show this help message and exit.
  -l    Enable logging of Wine and Winetricks to stdout, in addition to the log files.
  -i    Force the initialization of the Wine prefix.
  -d    If initializing, force the deletion of the existing prefix, if present.
  -m    If iniitalizing, force the usage of Microsoft .NET even if Wine Mono is available.
  -r    Force the setting of the mod launcher game executable path registry key.

When ran, this script will check to see if the Wine prefix ~/.local/share/lucas-simpsons-hit-and-run
-mod-launcher exists. If it doesn't exist, it will be created using wineboot. Then, either Wine Mono
or Microsoft's implementation of the .NET 3.5 runtime will be installed to it. After this setup,
the mod launcher will be launched.

When launching the program, if ~/.local/share/the-simpsons-hit-and-run or
/usr/share/the-simpsons-hit-and-run exist (in that order), they will be used to set the path to
Simpsons.exe automatically.

For more info, see the wiki: https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/"
}

# Launches Lucas' Simpsons Hit and Run Mod Launcher. See the readme, wiki, and above help message
# for more information.
# Arguments: See help message.
# Outputs:
#   - Prefix initialization progress.
#   - (Optional) Wine and Winetricks output.
# Variables Written:
#   - WINEARCH: See Wine documentation.
#   - WINEPREFIX: See Wine documentation.
function lml_linux_launcher() {
  info "Lucas' Simpsons Hit and Run Mod Launcher Linux Launcher version v0.1.1 starting."

  if ! command -v zenity &>/dev/null; then
    error "zenity not found. Please install it via your package manager to use this script. \
Exiting."
    return 1
  fi
  local detect_version=true
  if ! command -v wrestool &>/dev/null; then
    error "wrestool not found, will assume latest mod launcher is being used."
    detect_version=false
  fi

  local log_to_stdout=false
  local force_init=false
  local force_delete_prefix=false
  local always_set_registry_key=false
  local force_microsoft_net=false

  while getopts "lidrm" opt; do
    case $opt in
    l)
      log_to_stdout=true
      ;;
    i)
      force_init=true
      ;;
    d)
      if [[ $force_init != true ]]; then
        error "\"-d\" doesn't do anything without \"-i\", ignoring."
      fi
      force_delete_prefix=true
      ;;
    r)
      always_set_registry_key=true
      ;;
    m)
      force_microsoft_net=true
      ;;
    *)
      print_help
      return 0
      ;;
    esac
  done
  # Shift the options over to the mod list.
  shift "$((OPTIND - 1))"

  # Set up some utilities for using Zenity.

  local -a zenity_common_arguments=(
    --title "Lucas' Simpsons Hit & Run Mod Launcher"
    --width 500
  )

  local -a zenity_progress_arguments=()

  # If we log to stdout, Zenity interprets some of Wine's output as percentages, which ruins the
  # progress bar, as well as --auto-close.
  if [[ $log_to_stdout = true ]]; then
    # Pulsate rather than having a fixed position bar.
    zenity_progress_arguments+=(--pulsate)
  else
    zenity_progress_arguments+=(--auto-close)
  fi

  # This subshell is where all of the work with preparing the Wine prefix and launching the launcher
  # is done. It is piped to Zenity to provide a progress bar throughout the process, as well as
  # zenity_echo, to continue providing messages to the terminal.
  (
    local -r NUM_STEPS=7
    local step=0

    # Messages beginning with "# " are displayed in Zenity, as well as the terminal.
    echo "# Initializing."

    # Suggested package name, reused for most of this launcher's support files.
    local -r PACKAGE_NAME="lucas-simpsons-hit-and-run-mod-launcher"

    # Path to directory within the user data directory for storing logs. This is something specific
    # to this Linux launcher, and is not a part of the original mod launcher.
    local -r log_dir="$HOME/Documents/My Games/Lucas' Simpsons Hit & Run Mod Launcher/Logs"
    mkdir -p "$log_dir"
    # Path to the log file for when Wine is booting up.
    local -r wineboot_log="$log_dir/wine-wineboot.log"
    # Path to the log file for the mod launcher.
    local -r launcher_log="$log_dir/wine-$PACKAGE_NAME.log"

    # Path to mod launcher executable in the system library folder.
    local -r MOD_LAUNCHER_EXECUTABLE="/usr/lib/$PACKAGE_NAME/$PACKAGE_NAME.exe"

    if [[ ! -f "$MOD_LAUNCHER_EXECUTABLE" ]]; then
      zenity --title "Lucas' Simpsons Hit & Run Mod Launcher" --width 500 --error --text \
        "$(sanitize_zenity "Lucas' Simpsons Hit & Run Mod Launcher executable not found at \
$MOD_LAUNCHER_EXECUTABLE. The package may not be correctly installed.")"
      return 1
    fi

    # Architecture for Wine to use. The mod launcher only works on 32-bit.
    export WINEARCH=win32
    # Path to the Wine prefix, in the user data directory.
    export WINEPREFIX=$HOME/.local/share/wineprefixes/$PACKAGE_NAME
    # Path to our working directory within the Wine prefix.
    local -r prefix_lmlll_dir=$WINEPREFIX/drive_c/ProgramData/lml-linux-launcher
    mkdir -p "$prefix_lmlll_dir"
    # File used to determine whether the prefix is already in a working state.
    working_file=$prefix_lmlll_dir/working

    # This will also be set when
    local assume_working=false
    if [[ -f $working_file ]]; then
      assume_working=true
    fi

    echo "! Environment: WINEARCH=$WINEARCH WINEPREFIX=$WINEPREFIX"

    increment_progress

    # First, detect the version of the exe to see if we need any workarounds.

    # Unlike $force_microsoft_net, this variable takes effect when launching, not just when
    # initializing.
    local need_msdotnet=false
    local noupdatejumplist=false
    local winetricks_verb="dotnet35"
    if [[ $detect_version = true ]]; then
      # See: https://askubuntu.com/a/239722.
      local -r mod_launcher_version=$(wrestool --extract --raw --type=version \
        "$MOD_LAUNCHER_EXECUTABLE" |
        tr '\0, ' '\t.\0' |
        sed 's/\t\t/_/g' |
        tr -c -d '[:print:]' |
        sed -r -n 's/.*Version[^0-9]*([0-9]+\.[0-9]+(\.[0-9][0-9]?)?).*/\1/p')
      echo "# Applying workarounds for mod launcher version $mod_launcher_version."
      # Until version 1.25, Mono does not work with the mod launcher.
      if version_compare_operator "$mod_launcher_version" "<" "1.25"; then
        echo "! Mod launcher version is <1.25, disabling Mono support."
        need_msdotnet=true
        force_microsoft_net=true
      fi
      # Version 1.22 introduced jump lists, which throw an exception when used in Wine. 1.25
      # disables this automatically when running in Wine.
      if version_compare_operator "$mod_launcher_version" ">" "1.21" &&
        version_compare_operator "$mod_launcher_version" "<" "1.25"; then
        echo "! Mod launcher version is >=1.22 and <1.25, disabling jump list."
        noupdatejumplist=true
      fi
      # Version 1.13 introduced a requirement for Service Pack 1, which was removed in 1.22.4.
      if version_compare_operator "$mod_launcher_version" ">" "1.12.1" &&
        version_compare_operator "$mod_launcher_version" "<" "1.22.4"; then
        echo "! Mod launcher version is >=1.13 and <1.22.4, requiring .NET 3.5 Service Pack 1."
        winetricks_verb=${winetricks_verb}sp1
      fi
    else
      echo "# Workaround detection disabled, skipping."
    fi
    increment_progress

    # Then, initialize the Wine prefix if we have to.

    # If the user forced initialization via the "-i" argument, or there's no existing user data
    # directory.
    if [[ "$force_init" = true || ! -d "$WINEPREFIX" ]]; then
      # Remove the Wine prefix, if specfied.
      if [[ "$force_delete_prefix" = true ]]; then
        echo "! Deleting Wine prefix."
        rm -rf "$WINEPREFIX"
        mkdir -p "$prefix_lmlll_dir"
      fi

      echo "# Booting up Wine. If prompted about Wine Mono being missing, click \"Install\"."
      run wineboot "$wineboot_log"
      increment_progress

      echo "# Looking for .NET runtime."
      if [[ $force_microsoft_net != true ]] && wine uninstaller --list | grep -q "Wine Mono"; then
        echo "# Using Mono .NET runtime."
        # No further action necessary. How nice ;)
      else
        if [[ $(winetricks list-installed) == *"dotnet35"* ]]; then
          echo "# Using Microsoft .NET 3.5 runtime."
        else
          # If Microsoft .NET is being forced, there's no need to warn against it.
          if [[ $force_microsoft_net = false ]]; then
            if ! zenity "${zenity_common_arguments[@]}" --question --text "$(sanitize_zenity \
              "Lucas' Simpsons Hit & Run Mod Launcher needs a .NET runtime to run, either Wine \
Mono or Microsoft's .NET implementation. Wine Mono was not found in the mod launcher Wine prefix, \
would you like to install Microsoft's implementation? This may provide less consistent \
results.")"; then
              return 1
            fi
          fi

          echo "# Installing Microsoft .NET 3.5 runtime. This will take a while."
          # Path to the log file for when Winetricks is installing the MS .NET 3.5 runtime.
          local -r dotnet35_log="$log_dir/winetricks-dotnet35.log"
          if ! run "winetricks -q \"$winetricks_verb\"" "$dotnet35_log"; then
            zenity "${zenity_common_arguments[@]}" --error --text "$(sanitize_zenity "Failed to \
install the Microsoft .NET 3.5 runtime. See \"${dotnet35_log}\" for more info.")"
            echo "# An error occured while initializing the Wine prefix."
            return 1
          fi
        fi
      fi
      increment_progress
      # We don't really need to check for .NET as we just installed it, and this code shouldn't be
      # executed if that failed.
      assume_working=true
    else
      # Skip over the Wine prefix initialization steps.
      increment_progress 2
    fi

    # Then, do some house keeping with the Wine prefix.

    if [[ $assume_working == false ]]; then
      echo "# Checking .NET runtime."
      echo "! Checking for Microsoft .NET."
      if ! [[ $(winetricks list-installed) == *"$winetricks_verb"* ]]; then
        echo "! Checking for Mono .NET."
        if ! wine uninstaller --list | grep -q "Wine Mono"; then
          local -r no_runtime_text="No .NET runtime installation found. You can try fixing this by \
  reinitializing with \"$PROGRAM_NAME -i\"."
          echo "? $no_runtime_text"
          zenity "${zenity_common_arguments[@]}" --error --text "$(sanitize_zenity \
            "$no_runtime_text")"
          return 1
        elif [[ $need_msdotnet = true ]]; then
          local -r need_msdotnet_text="Microsoft .NET 3.5 runtime installation not found. Wine \
Mono was found, but is not supported by mod launcher version $mod_launcher_version."
          echo "? $need_msdotnet_text"
          zenity "${zenity_common_arguments[@]}" --error --text "$(sanitize_zenity \
            "$need_msdotnet_text")"
          return 1
        fi
      fi
    else
      echo "# Assuming .NET runtime is working."
    fi
    increment_progress

    echo "# Checking registry."
    # This regex matches the section of the Wine "reg" registry file where the mod launcher stores
    # the game EXE path.

    # Whenever it's necessary to input a registry path, eight backslashes are needed, \\\\\\\\.
    # Here's how it's processed:
    # - When interpreting this script, Bash escapes each couple of backslashes, becoming \\\\.
    # - When interpreting the temprary input "reg" file, regedit interprets \x, where x is a
    # character, as an escape sequence. Therefore, regedit also escapes each couple of backslashes,
    # becoming \\. I'm not entirely sure why, in the registry, it is stored like this.

    user_reg="$WINEPREFIX/user.reg"
    # If the registry hasn't yet been created, then we definitely can't work with it.
    if [[ -f $user_reg ]]; then
      # TODO: Grep's "-z" option separates each line by a null character. This is necessary here to
      # make a multiline pattern. However, unless Perl mode is used, \x00 can't be used to match a
      # NUL. To get around this, "." is currently used to match the null character, but it might be
      # better to convert the pattern to that of Perl's and properly match it.
      if [[ $always_set_registry_key = true ]] ||
        ! grep -Ezq "\[Software\\\\\\\\Lucas Stuff\\\\\\\\Lucas' Simpsons Hit & Run Tools\] \
[0-9]{10}( [0-9]{7})*.\
#time=([0-9]|[a-z]){15}.\
\"Game EXE Path\"=\".+\".\
\"Game Path\"=\".+\"" "$user_reg"; then

        user_shar_directory=$HOME/.local/share/the-simpsons-hit-and-run
        system_shar_directory=/usr/share/the-simpsons-hit-and-run
        if [[ -d $user_shar_directory ]]; then
          shar_directory=$user_shar_directory
        elif [[ -d $system_shar_directory ]]; then
          shar_directory=$system_shar_directory
        fi

        if [[ -d $shar_directory ]]; then
          echo "# Configuring the mod launcher to use SHAR directory \"$shar_directory\"."
          reg=$prefix_lmlll_dir/lml_set_game_exe_path.reg
          cat <<EOF >"$reg"
REGEDIT4

[HKEY_CURRENT_USER\\Software\\Lucas Stuff\\Lucas' Simpsons Hit & Run Tools]
"Game EXE Path"="$(winepath -w "$shar_directory/Simpsons.exe" | sed -E "s/\\\/\\\\\\\\/g")"
"Game Path"="$(winepath -w "$shar_directory" | sed -E "s/\\\/\\\\\\\\/g")"
EOF
          wine regedit "$reg"
          rm "$reg"
        else
          zenity --width 500 --warning --text "$(sanitize_zenity "Failed to find SHAR directory to \
        use. To learn how to set this up, see the wiki: \
https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/Game-Launcher#working-directories. You \
may manually set the game path in the mod launcher interface.")"
        fi
      else
        echo "! SHAR path is already configured."
      fi
    fi
    increment_progress

    # Finally, launch Wine with the mod launcher executable.

    echo "# Launching launcher."

    # Generate arguments for the mod launcher from the arguments passed to the end of this script.
    local -a mod_launcher_arguments
    if [[ $noupdatejumplist = true ]]; then
      mod_launcher_arguments+=(-noupdatejumplist)
    fi
    for file in "$@"; do
      local extension=${file##*.}
      if [[ "$extension" = "lmlm" ]]; then
        # By defualt, Wine maps the Z drive to "/" on the host filesystem.
        mod_launcher_arguments+=(-mod Z:"$file")
      elif [[ "$extension" = "lmlh" ]]; then
        mod_launcher_arguments+=(-hack Z:"$file")
      else
        zenity "${zenity_common_arguments[@]}" --warning --text "$(sanitize_zenity "File \"$file\" \
not recognized as a file handled by the mod launcher, ignoring.")"
      fi
    done

    if [[ $log_to_stdout = true ]]; then
      echo "# Finished. Keep this dialog open to continue logging."
    else
      echo "# Finished."
    fi
    # This should get the progress bar to 100%. If --auto-close is being used, the dialog will be
    # closed at this point.
    increment_progress
    echo EOF

    # Launch the mod launcher.
    # We don't have to pass a hacks directory because, the way the structure works out, the launcher
    # can already see them anyways.
    if run "wine \"$MOD_LAUNCHER_EXECUTABLE\" -mods Z:/usr/share/\"$PACKAGE_NAME\"/mods/ \
      ${mod_launcher_arguments[*]}" "$launcher_log"; then
      # Indicate that the launcher successfully launched, and that we probably don't have to check
      # for .NET next time.
      touch "$working_file"
    else
      # Indicate that something here is broken.
      rm -f "$working_file"
    fi
  ) | tee >(zenity "${zenity_common_arguments[@]}" "${zenity_progress_arguments[@]}" --progress) |
    zenity_echo
}

lml_linux_launcher "$@"
