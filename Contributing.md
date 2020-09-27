# Contributing
All files in this repository should use 2 spaces for a level of indentation.

## Bash
For Bash scripts, the [Google Shell Style Guide](https://google.github.io/styleguide/shell.xml) should be followed. The exceptions to this reference are that `main` is not used in this repository, executable scripts should be named with kebab case, and commenting should be done as documented below.

### Function Documentation
Functions must have certain attributes marked, if applicable.

#### Description
The first line of a function's documentation must describe what the function does, briefly. Example:
```bash
# Sets up a new system.
```

##### TODOs
The lines proceeding a function's documentation must describe general TODOs for it, if there are any. Example:
```bash
# TODO: Add licensing info.
```

#### Variables Read
If a function reads any global variables, they must be documented. Example:
```bash
# Variables Read:
#   - DRY_RUN: Whether to actually perform actions.
```

#### Variables Written
If a function exports any global variables, they must be documented. Example:
```bash
# Variables Written:
#   - INSTALL_HOME: Location of the home directory of the current install user.
```

#### Arguments
If a function reads any arguments, they must be documented. Example:
```bash
# Arguments:
#   - Whether to require root or to require non root.
```

#### Outputs
If a function outputs anything, it must be documented. Example:
```bash
# Outputs:
#   - The bootnum of the boot entry.
```

#### Returns
If a function has cases in which it returns a non-0 exit code in any circumstances, , they must be documented. Example:
```bash
# Returns:
#   - 1 if the file couldn't be found.
```
Exiting with a non-0 value for fatal errors is permitted.
