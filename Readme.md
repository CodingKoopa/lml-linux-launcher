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

**Don't see your distro listed?** Rep your favorite distro by creating a package for it! For more info, please see [Recommended Installation Specification](https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/Recommended-Installation-Specification).

## Usage
To get started with using *Lucas' Simpsons Hit & Run Mod Launcher Linux Launcher*:
- Install the mod launcher package as mentioned above.
- Click on the *Lucas' Simpsons Hit & Run Mod Launcher* application from your desktop's application launcher, or run `lucas-simpsons-hit-and-run-mod-launcher`.
- Allow the script to setup the launcher.
- Setup your `Simpsons.exe` path in the launcher UI.
- Launch the game.

This should be all that is required to get up and running. To import your mods, you can move them to `~/Documents/My Games/Lucas' Simpsons Hit & Run Mod Launcher/Mods/`, and run `check-for-duplicate-lmlms` in there to remove any mods that are already installed as a part of the mod launcher package.

## Contributing
For information on contributing, please see [Contributing.md](Contributing.md).

## Features
This section is an informal introduction to what this Linux launcher offers. Complete technical documentation is available on the [wiki](https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/Home).

### Launcher Script
The launcher script is a [Bash](https://www.gnu.org/software/bash/) script that does all of the work with setting up Wine and .NET.

For more info, see the [Mod Launcher Launcher](https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/Mod-Launcher-Launcher) page on the wiki.

### MIME Types
The `LMLM` and `LMLH` file types are foriegn to Linux, so this launcher bundles a MIME type `XML` to handle any files with these extentions.

For more info, see [MIME Types](https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/MIME-Types).

### Desktop Entries
To allow starting the launchers from your desktop environemnt as if it were any other application, this comes with desktop entries, including support for the MIME types.

For more info, see [Desktop Entries](https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/Desktop-Entries).

### Duplicate LMLM Checker
As a result of splitting up your mods into a system directory (for default mods) and user directory (for user added mods), you may have some leftover default mods into your user directory. To help keep your user mod directory clean, the duplicate LMLM checker fixes this for you.

For more info, see [Duplicate LMLM Checker](https://gitlab.com/CodingKoopa/lml-linux-launcher/-/wikis/Duplicate-LMLM-Checker).

## Compatability
This section will detail how well the mod launcher and game run with Wine.

### The Simpsons: Hit & Run
*The Simpsons: Hit & Run* itself pretty much runs exactly how you would expect it to. Performance parallels that of a Windows setup, as does the graphics and sound. The only thing that is sketchy is the game's built in fullscreen functionality. I recommend that you never use the built in fullscreen mode, and instead use the *Resizeable Window* mod with the mod launcher, combined with your window manager's fullscreen (Often binded to `Alt` + `F11`.).

## Lucas' Simpsons Hit & Run Mod Launcher
*Lucas' Simpsons Hit & Run Mod Launcher* uses some parts of the .NET runtime not yet implemented by Wine, but the core functionality is there. The most notable feature that does not work is that clicking on a mod for more details and changing settings does not work. Additionally, showing a mod in Windows Explorer does not work. Everything that has been tested and verified to work are launching the game with any mod, decompiling and compiling mods, categorizing mods, closing the mod launcher on game boot.
