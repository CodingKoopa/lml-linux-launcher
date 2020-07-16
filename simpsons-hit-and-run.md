The [game launcher](https://github.com/TheKoopaKingdom/lucas-simpsons-hit-and-run-mod-launcher-linux-launcher/blob/master/the-simpsons-hit-and-run.sh) is a [Bash](https://www.gnu.org/software/bash/) script that launches the game itself, *The Simpsons Hit & Run*. Assuming the [working-directory](#working-directories) is properly configured, executing this script will start the game in its directory. If not, a Zenity dialog will tell you to setup your working directory.

## Options
The game launcher takes the following arguments:

| Flag | Description                                                  |
| ---- | ------------------------------------------------------------ |
| `-h` | Show a help message and exit.                                |
| `-p` | Print the path of the game working directory used and exits. |

## Working Directories
The game script will look in two places for the game, in this order:
- The user SHAR path, `/.local/share/the-simpsons-hit-and-run/`.
- The system SHAR path, `/usr/share/the-simpsons-hit-and-run/`.

Although the user SHAR path should be preferred because it does not require root privileges to write to, there is one caveat that should be noted. The `.local` directory is, by design, hidden, which is a good thing. However, this means that, when using the mod launcher, you will be unable to navigate to this directory because Wine's file browser cannot see hidden directories. To get around this, you can put your SHAR installation in a place where Wine's file browser can see it, and then symlink it back to the user SHAR path. For example, if my SHAR installation path is `~/External/Games/PC/The\ Simpsons\ Hit\ \&\ Run/`, I would run this:
```bash
$ ln -s ~/External/Games/PC/The\ Simpsons\ Hit\ \&\ Run/ ~/.local/share/the-simpsons-hit-and-run
```
