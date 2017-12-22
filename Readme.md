# Lucas' Simpsons Hit & Run Mod Launcher Linux Launcher
*Lucas' Simpsons Hit & Run Mod Launcher Linux Launcher* is a collection of assets for using [*Lucas' Simpsons Hit & Run Mod Launcher*](https://donutteam.com/downloads/4/) on Linux. It aims to deliver the experience of playing mods for [*The Simpsons: Hit & Run*](https://en.wikipedia.org/wiki/The_Simpsons:_Hit_%26_Run) while integrating with your Linux system as tightly as possible.

## Installation
Due to differences between different Linux distributions, no installer is provided in this repo. Instead, it is encouraged to use a package specifically for your distribution. These are the current distributions for which *Lucas' Simpsons Hit & Run Mod Launcher Linux Launcher* is available:
<table>
  <tr>
    <td>
      <a href="https://aur.archlinux.org/packages/lucas-simpsons-hit-and-run-mod-launcher/">
        <img src="https://www.archlinux.org/static/logos/archlinux-logo-dark-scalable.518881f04ca9.svg" height="100" />
      </a>
    </td>
  </tr>
</table>

## Usage
To get started with using *Lucas' Simpsons Hit & Run Mod Launcher Linux Launcher*, here are some things should do:
- If you plan on using the Vanilla *Simpsons: Hit & Run* launcher, configure your game [working directory](https://github.com/TheKoopaKingdom/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki/Game-Launcher#working-directories).
- Start the *Lucas' Simpsons Hit & Run Mod Launcher* launcher to enter first time initialization. There will be several .NET installers, go through them and install all of the runtimes.
- If you have saved games or mods you would like to import, move them to the *Lucas' Simpsons Hit & Run Mod Launcher* launcher working directory, `/.local/share/lucas-simpsons-hit-and-run-mod-launcher`. Afterwards, run `check-for-duplicate-lmlms` to remove duplicate default mods leftover from the source mod folder.

## Features
This section is meant as an informal introduction to what this Linux launcher offers. Complete technical documentation is available on the [wiki](https://github.com/TheKoopaKingdom/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki).

### Launcher Scripts
Included are two [Bash](https://www.gnu.org/software/bash/) launcher scripts , one for *Lucas' Simpsons Hit & Run Mod Launcher* and one for *The Simpsons: Hit & Run* itself, the original game. These launchers manage the internals of the mod launcher and game for you, to ensure a smooth experience. They are also designed to do things "the linux way". The mod launcher in particular constructs a directory layout, using symlinks to redirect the traditional Windows `C:\Users\<USER>\Documents\My Games...` path to the `.local` directory in your home directory. Furthermore, the mod launcher accepts hacks and mods as parameters for convinience.

For more info, see [Mod Launcher Launcher](https://github.com/TheKoopaKingdom/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki/Mod-Launcher-Launcher) and [Game Launcher](https://github.com/TheKoopaKingdom/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki/Game-Launcher) on the wiki.

### MIME Types
The `LMLM` and `LMLH` file types are foriegn to Linux, so this launcher bundles a MIME type `XML` to handle any files with these extentions.

For more info, see [MIME Types](https://github.com/TheKoopaKingdom/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki/MIME-Types).

### Desktop Entries
To allow starting the launchers from your desktop environemnt as if it were any other application, this comes with desktop entries, including support for the MIME types.

For more info, see [Desktop Entries](https://github.com/TheKoopaKingdom/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki/Desktop-Entries).

### Duplicate LMLM Checker
As a result of splitting up your mods into a system directory (for default mods) and user directory (for user added mods), you may have some leftover default mods into your user directory. To help keep your user mod directory clean, the duplicate LMLM checker fixes this for you.

For more info, see [Duplicate LMLM Checker](https://github.com/TheKoopaKingdom/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/wiki/Duplicate-LMLM-Checker).