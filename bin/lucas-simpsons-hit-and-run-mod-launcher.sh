#!/bin/bash

PROGRAM_NAME=${0##*/}

# Prints an info message.
# Arguments:
# 	- Info to be printed.
# Outputs:
# 	- The info message.
function info() {
	printf "[$(tput setaf 6)Info$(tput sgr0)] %s\n" "$*"
}

# Prints an warning message.
# Arguments:
#	- Warning to be printed.
# Outputs:
#	- The warning message.
function warning() {
	printf "[$(tput setaf 3)Warning$(tput sgr0)] %s\n" "$*" >&2
}

# Prints an error message.
# Arguments:
#	- Error to be printed.
# Outputs:
#	- The error message.
function error() {
	printf "[$(tput setaf 1)Error$(tput sgr0)] %s\n" "$*" >&2
}

# Prints a progress message.
# Arguments:
#	- Progress to be printed.
# Outputs:
#	- The progress message.
function progress() {
	printf "[$(tput setaf 2)Progress$(tput sgr0)] %s\n" "$*"
}

# Compares two semantic version strings. See: https://stackoverflow.com/a/4025065.
# Arguments:
#	- The first version.
#	- The second version.
# Returns:
#	- 0 if ver1 == ver2.
#	- 1 if ver1 > ver2.
#	- 2 if ver1 < ver2.
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
#	- The first version.
#	- The operator, one of "=", ">", or "<".
#	- The second version.
# Outputs:
#	- An error if an invalid operator was given.
# Returns:
#	- 0 if the expression given is true.
#	- 1 if the expression given is false.
#	- 2 if the expression given is invalid.
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
	if [[ $op == "$2" ]]; then
		return 0
	else
		return 1
	fi
}

# Increments a Zenity progress bar.
# Variables Read:
#	- NUM_STEPS: The total number of steps.
# Variables Written:
#	- step: The current step.
# Arguments:
#	- (Optional) Number of steps to advance by. Defaults to 1.
# Outputs:
#	- The percentage.
function advance_progress() {
	inc=${1:-1}
	((step += inc))
	# If the multiplication by 100 is done first, then the decimal number will be truncated to 0.
	echo $((step * 100 / NUM_STEPS))
}

# Sanitizes a string so that it may be displayed in Zenity without any problems. sed expression from
# https://unix.stackexchange.com/a/37663.
# Arguments:
#	- The input string.
# Outputs:
#	- The sanitized string.
function sanitize_zenity() {
	echo "$1" | sed -e 's/\\/\\\\/g' -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

# Echos output originally intended for Zenity. This function filters out percentages from
# advance_progress(), as well as the "# " prefix. This function also handles errors that arrise
# during the execution of the subshell, or from the cancel button being clicked. Finally, this
# handles our own "! " and "? " prefixes.
# Outputs:
#	- Filtered /dev/stdin contents.
# Returns:
#	- 0 if successful.
#	- 1 if EOF was never reached. This generally indicates that the process was cancelled.
#   - 2 if the subshell "return code" isn't an integer.
#	- Otherwise, returns whatever was the integer to be echoed after EOF.
function zenity_echo() {
	local ret=0
	local eof_reached=false
	while read -r line; do
		# Ignore display number percentages used by Zenity.
		if [[ $line =~ ^[0-9]+$ ]]; then
			continue
		fi
		# Break on the first EOF received.
		if [[ $line == EOF ]]; then
			eof_reached=true
			break
		fi
		# Identify any error messages, as the return codes from the subshell are otherwise lost.
		if [[ ${line,,} == error:* ]]; then
			ret=1
		fi
		if [[ $line =~ ^\# ]]; then
			# Remove the "# " used by Zenity to mark text to display.
			progress "${line#"# "}"
		elif [[ $line =~ ^\! ]]; then
			info "${line#"! "}"
		elif [[ $line =~ ^\? ]]; then
			text=${line#"? "}
			error "$text"
			zenity "${zenity_common_arguments[@]}" --error --text "$(sanitize_zenity "$text")" ||
				true
		else
			echo "$line"
		fi
	done </dev/stdin
	info "Subshell has finished."
	# If EOF was never reached, then the cancel button was probably clicked. In that case, make sure
	# this isn't considered a success.
	if [[ $eof_reached == false ]]; then
		error "EOF not reached. Either an error occurred in the subshell, or user cancelled."
		ret=1
	else
		read -r ret
		case "$ret" in
		'' | *[!0-9]*) ret=2 ;;
		esac
	fi
	return "$ret"
}

# Runs a command, redirecting log output to a file or to stdout.
# Variables Read:
#	- verbose: Whether to log to stdout.
# Outputs:
#	- Command output, if $verbose=true.
function run() {
	local command=$1
	local -r log_file=$2
	if [[ $verbose == true ]]; then
		# Big thanks to https://stackoverflow.com/a/30659751/5719930.
		# Redirect fd4 to stdout.
		exec 4>&1
		local -r exit_status=$(
			{
				{
					eval "$command"
					echo $? 1>&3            # Print the exit code to fd3.
				} | tee "$log_file" 1>&4 # Print stdin to fd4 = the real stdout.
			} 3>&1                    # Redirect fd3 to the fake stdout capturing the exit status.
		)
		return "$exit_status"
	else
		eval "$command" &>"$log_file"
	fi
}

# Prints the help message for this script.
# Outputs:
#	- The help message.
function print_help() {
	echo "Usage: $PROGRAM_NAME [-hlirm] [-o \"MOD LAUNCHER ARGUMENTS\"] [MOD/HACK/LAUNCHER EXE]
Launches Lucas' Simpsons Hit & Run Mod Launcher via Wine.

  -h    Show this help message and exit.
  -v    Enable logging of Wine and Winetricks to stdout, in addition to the log files.
  -i    Force the recreation + initialization of the Wine prefix.
  -d    If initializing, force the deletion of the existing prefix, if present.
  -m    Use Wine Mono rather than Microsoft .NET. Quicker installation, but slightly buggier UI.
  -r    Force the setting of the mod launcher game executable path registry key.
  -o    Passes command line arguments to the mod launcher.

When ran, this script will check to see if the Wine prefix ~/.local/share/lucas-simpsons-hit-and-run
-mod-launcher exists. If it doesn't exist, it will be created using wineboot. Then, either Wine Mono
or Microsoft's implementation of the .NET runtime will be installed to it. After this setup,
the mod launcher will be launched.

When launching the program, if ~/.local/share/the-simpsons-hit-and-run or
/usr/share/the-simpsons-hit-and-run exist (in that order), they will be used to set the path to
Simpsons.exe automatically.

For more info, see the wiki: https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/"
}

function has_dotnet() {
	[[ $(winetricks list-installed 2>/dev/null) == *"dotnet35"* ]]
}

function has_mono() {
	wine uninstaller --list 2>&1 | grep -q "Wine Mono"
}

# Launches Lucas' Simpsons Hit and Run Mod Launcher. See the readme, wiki, and above help message
# for more information.
# Arguments: See help message.
# Outputs:
#	- Prefix initialization progress.
#	- (Optional) Wine and Winetricks output.
# Variables Written:
#	- WINEARCH: See Wine documentation.
#	- WINEPREFIX: See Wine documentation.
function lml_linux_launcher() {
	info "Launching Lucas' Simpsons Hit and Run Mod Launcher..."

	local -r PACKAGE_NAME="lucas-simpsons-hit-and-run-mod-launcher"

	if ! command -v zenity &>/dev/null; then
		error "zenity not found. Please install it via your package manager to use this script. \
Exiting."
		return 1
	fi
	local detect_version=true
	if ! command -v wrestool &>/dev/null; then
		warning "wrestool not found; will assume a recent mod launcher is being used."
		detect_version=false
	fi

	# Set up some utilities for using Zenity.

	local -a zenity_common_arguments=(
		--title "Lucas' Simpsons Hit & Run Mod Launcher"
		--width 500
	)

	local verbose=false
	local force_init=false
	local always_set_registry_key=false
	local force_mono=false
	local -a mod_launcher_args

	while getopts "hvirmo:" opt; do
		case $opt in
		h)
			# Bail earlier than the default case.
			print_help
			return 0
			;;
		v)
			verbose=true
			;;
		i)
			force_init=true
			;;
		r)
			always_set_registry_key=true
			;;
		m)
			force_mono=true
			;;
		o)
			mod_launcher_args+=("$OPTARG")
			;;
		*)
			print_help
			return 0
			;;
		esac
	done

	# Shift the options over to the mod list.
	shift "$((OPTIND - 1))"
	# Generate arguments for the mod launcher from the arguments passed to the end of this script.
	# N.B. this is modified later, when applying workarounds.
	local cli_lml=""
	for arg in "$@"; do
		local extension=${arg##*.}
		if [[ "$extension" == "lmlm" ]]; then
			# By defualt, Wine maps the Z drive to "/" on the host filesystem.
			mod_launcher_args+=(-mod Z:"$arg")
		elif [[ "$extension" == "lmlh" ]]; then
			mod_launcher_args+=(-hack Z:"$arg")
		elif [[ "$extension" == "exe" ]]; then
			if [[ -z $cli_lml ]]; then
				cli_lml=$arg
			else
				info "More than one EXE passed, ignoring extras."
			fi
		else
			mod_launcher_args+=("$arg")
		fi
	done

	local mod_launcher_exe=""
	if [[ -f $cli_lml ]]; then
		mod_launcher_exe=$cli_lml
	else
		local user_lml_directory=$HOME/.local/lib/$PACKAGE_NAME
		local system_lml_directory=/usr/lib/$PACKAGE_NAME
		if [[ -d $user_lml_directory ]]; then
			lml_directory=$user_lml_directory
		elif [[ -d $system_lml_directory ]]; then
			lml_directory=$system_lml_directory
		fi
		mod_launcher_exe=$lml_directory/$PACKAGE_NAME.exe
		if [[ ! -f $mod_launcher_exe ]]; then
			local -r noexe_text="EXE \"$mod_launcher_exe\" not found. Quitting."
			error "$noexe_text"
			zenity "${zenity_common_arguments[@]}" --error --text "$(sanitize_zenity "$noexe_text")"
		fi
	fi
	info "Using mod launcher EXE \"$mod_launcher_exe\"."

	# Architecture for Wine to use. The mod launcher only works on 32-bit.
	export WINEARCH=win64
	# Path to the Wine prefix, in the user data directory.
	export WINEPREFIX=$HOME/.local/share/wineprefixes/$PACKAGE_NAME

	# Path to our working directory within the Wine prefix.
	local -r prefix_lmlll_dir=$WINEPREFIX/drive_c/ProgramData/lml-linux-launcher
	mkdir -p "$prefix_lmlll_dir"

	# File used to determine whether the prefix is already in a working state.
	initialized_stamp=$prefix_lmlll_dir/initialized.stamp
	# Indicator we place if things are broken.
	broken_stamp=$prefix_lmlll_dir/broken.stamp

	# Check this before entering the subshell so that we don't have multiple dialogs at once.
	if [[ -f $broken_stamp ]]; then
		if zenity "${zenity_common_arguments[@]}" --question --text \
			"It looks like the launcher previously failed to start. Would you like to try recreating the Wine prefix?

If you click \"Yes\", <b>mod launcher settings (other than the EXE path) will be reset</b>. Your saves, mods, and screenshots will remain!

You can also close this window and come back later."; then
			force_init=true
		fi
		rm "$broken_stamp"
	fi

	# This subshell is where all of the work with preparing the Wine prefix and launching the launcher
	# is done. It is piped to Zenity to provide a progress bar throughout the process, as well as
	# zenity_echo, to continue providing messages to the terminal.
	(
		local -r NUM_STEPS=5
		local step=0

		# Messages beginning with "# " are displayed in Zenity, as well as the terminal.
		echo "# Initializing..."

		# Path to directory within the user data directory for storing logs. This is something specific
		# to this Linux launcher, and is not a part of the original mod launcher.
		local -r log_dir="$HOME/Documents/My Games/Lucas' Simpsons Hit & Run Mod Launcher/Logs"
		mkdir -p "$log_dir"
		# Path to the log file for when Wine is booting up.
		local -r wineboot_log="$log_dir/wine-wineboot.log"
		# Path to the log file for the mod launcher.
		local -r launcher_log="$log_dir/wine-$PACKAGE_NAME.log"

		if [[ ! -f "$mod_launcher_exe" ]]; then
			echo "? Lucas' Simpsons Hit & Run Mod Launcher executable not found at \
$mod_launcher_exe. The package may not be correctly installed."
			return 1
		fi

		echo "! Environment: WINEARCH=$WINEARCH WINEPREFIX=$WINEPREFIX"

		# First, detect the version of the exe to see if we need any workarounds.

		# Unlike $force_microsoft_net, this variable takes effect when launching, not just when
		# initializing.
		local mono_possible=true
		local winetricks_verb="$system_lml_directory/my_dotnet.verb"
		if [[ $detect_version == true ]]; then
			# See: https://askubuntu.com/a/239722.
			local -r mod_launcher_version=$(wrestool --extract --raw --type=version \
				"$mod_launcher_exe" |
				tr '\0, ' '\t.\0' |
				sed 's/\t\t/_/g' |
				tr -c -d '[:print:]' |
				sed -r -n 's/.*Version[^0-9]*([0-9]+\.[0-9]+(\.[0-9][0-9]?)?).*/\1/p')
			echo "# Applying workarounds for mod launcher version $mod_launcher_version..."
			# Until version 1.25, Mono does not work with the mod launcher.
			if version_compare_operator "$mod_launcher_version" "<" "1.25"; then
				echo "! Mod launcher version is <1.25, disabling Mono support."
				mono_possible=false
			fi
			# Version 1.22 introduced jump lists, which throw an exception when used in Wine. 1.25
			# disables this automatically when running in Wine.
			if version_compare_operator "$mod_launcher_version" ">" "1.21" &&
				version_compare_operator "$mod_launcher_version" "<" "1.25"; then
				echo "! Mod launcher version is >=1.22 and <1.25, disabling jump list."
				mod_launcher_args+=(-noupdatejumplist)
			fi
			# Version 1.13 introduced a requirement for Service Pack 1, which was removed in 1.22.4.
			if version_compare_operator "$mod_launcher_version" ">" "1.12.1" &&
				version_compare_operator "$mod_launcher_version" "<" "1.22.4"; then
				echo "! Mod launcher version is >=1.13 and <1.22.4, requiring .NET 3.5 Service Pack 1."
				winetricks_verb=dotnet35sp1
			fi
		fi
		advance_progress

		# Then, initialize the Wine prefix if we have to.

		# If the user forced initialization via the "-i" argument, or there's no existing user data
		# directory.
		if [[ "$force_init" == true || ! -d "$WINEPREFIX" || ! -f $initialized_stamp ]]; then
			rm -rf "$WINEPREFIX"
			mkdir -p "$prefix_lmlll_dir"

			echo "# Creating Wine prefix..."
			# Thanks: https://wiki.archlinux.org/title/Wine#Prevent_installing_Mono/Gecko.
			run "WINEDLLOVERRIDES=\"mshtml=d;mscoree=d\" wineboot && wineserver -w" "$wineboot_log"
			advance_progress

			echo "# Looking for .NET runtime..."
			if [[ $force_mono == true ]] && [[ $mono_possible == true ]]; then
				if ! has_mono; then
					advance_progress
					echo "# Using Mono .NET runtime. <b>Click \"Install\" in the other window</b> if prompted!"
					# Thanks: https://github.com/Winetricks/winetricks/issues/1236#issuecomment-2145954802
					run "wine control.exe appwiz.cpl install_mono" "wine-mono"

					if ! has_mono; then
						echo "? Wine Mono still doesn't appear to be installed."
						return 1
					fi
				fi
			else
				if ! has_dotnet; then
					advance_progress
					echo "# Installing the Microsoft .NET runtime. You'll see some more progress windows pop up soon!"
					local -r winetricks_log="$log_dir/winetricks.log"
					# This cannot use -q (see the .verb).
					if ! run "winetricks \"$winetricks_verb\"" "$winetricks_log"; then
						echo "? Failed to install the Microsoft .NET runtime. See \"${winetricks_log}\" for more info."
						return 1
					fi
				fi
			fi
			touch "$initialized_stamp"
			advance_progress
		else
			advance_progress 3
		fi

		echo "# Checking registry..."

		user_reg="$WINEPREFIX/user.reg"
		# This regex matches the section of the Wine "reg" registry file where the mod launcher stores
		# the game EXE path.

		# Whenever it's necessary to input a registry path, eight backslashes are needed, \\\\\\\\.
		# Here's how it's processed:
		# - When interpreting this script, Bash escapes each couple of backslashes, becoming \\\\.
		# - When interpreting the temprary input "reg" file, regedit interprets \x, where x is a
		# character, as an escape sequence. Therefore, regedit also escapes each couple of backslashes,
		# becoming \\. I'm not entirely sure why, in the registry, it is stored like this.

		# TODO: Grep's "-z" option separates each line by a null character. This is necessary here to
		# make a multiline pattern. However, unless Perl mode is used, \x00 can't be used to match a
		# NUL. To get around this, "." is currently used to match the null character, but it might be
		# better to convert the pattern to that of Perl's and properly match it.
		if [[ $always_set_registry_key == true ]] || [[ ! -f $user_reg ]] ||
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
				echo "# Configuring the mod launcher to use SHAR directory \"$shar_directory\"..."
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
				zenity "${zenity_common_arguments[@]}" --warning --text "$(sanitize_zenity "Failed to find SHAR directory to \
	  use. To learn how to set this up, see the wiki: \
https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/Game-Launcher#working-directories. You \
may manually set the game path in the mod launcher interface.")"
			fi
		else
			echo "! SHAR path is already configured."
		fi
		advance_progress

		# Finally, launch Wine with the mod launcher executable.

		echo "# Starting launcher!"
		# At this point, the progress bar should be at 100%, and the dialog should have closed.

		# Launch the mod launcher.
		# We don't have to pass a hacks directory because, the way the structure works out, the launcher
		# can already see them anyways.
		verbose=true
		if ! run "wine \"$mod_launcher_exe\" -mods Z:/usr/share/\"$PACKAGE_NAME\"/mods/ \
	${mod_launcher_args[*]}" "$launcher_log"; then
			# Queue safe-mode for the next time we launch.
			touch "$broken_stamp"
			echo "? It looks like the launcher failed to start, or crashed. You may be able to fix this by rerunning this program to recreate the prefix."
			echo EOF
			echo 1
		else
			echo EOF
			echo 0
		fi
	) | tee >(zenity "${zenity_common_arguments[@]}" --progress --auto-close) |
		zenity_echo
}

lml_linux_launcher "$@"
