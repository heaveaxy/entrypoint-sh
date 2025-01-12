# entrypoint-sh

This script may be used in Docker images to prepare application configuration files even if the application is not designed to run in a container.

It is designed to be used as a container entrypoint. All arguments passed to the container (e.g., Docker CMD) may be passed to the target program after initialization completes.

To use this script, you need the following commands inside the container:
- `host` (only for `_RESOLVE` environment variables).
- `su-exec` or `gosu` (when context switching is required).

## Features
- Environment substitution in defined templated files using the common envvar `${VARNAME}` syntax.
- Substitution supports default values of variables (e.g., `${VARNAME:-default}`).
- Any environment variable may be a `_FILE` variable, which is filled with the file's content.
- Any environment variable may be a `_RESOLVE` variable, which is filled with the host IP as a result.
- Any environment variable may have an additional `_PREPROCESS` variable, which contains a shell command whose output redefines the variable's value (usable for password hashing).
- After initialization completes, the script may drop privileges to the specified UID and GID.
- After complete initialization, the script executes the target program.
- CMD arguments are taken into account.

The script is fully POSIX-compatible and should work on any distro.

## General settings
Settings are defined in the first section of the script. The following general settings may be changed:

* `OPT_LOGLEVEL` (default: `2`)

    One of: `1` (Error), `2` (Warning), `3` (Info), `4` (Debug).

* `OPT_ENVVAR_PREFIX` (default: `INIT_`)

    Prefix of environment variables processed by this script. Variables that do not start with this string are ignored.
    
* `OPT_TEMPLATE` (**required**)

    Path to the configuration file template (filled with environment variable references). This file is left untouched. All changes are prepared in a copy of it with the last extension dropped from the name. Therefore, it is necessary to use an additional file extension like `.template`.

* `OPT_RUN_NEXT` (**required**)

    The command that will be run after this entrypoint script completes its work. It may be the container's own entrypoint, the main application, or another configured copy of **entrypoint-sh**.

    **Note**: If you use **tini**, do not run it that way — run it first (as the entrypoint) and pass the **entrypoint-sh** script to it.

* `OPT_RUN_NEXT_CONTEXT` (**optional**)

    If it is necessary to drop privileges before executing the target program, you may define the UID and GID to drop privileges to. The format is: `UID:GID` (for example, `1000:1000`).

    When the next context is defined, `su-exec` or `gosu` must exist; otherwise, context switching will be skipped with a warning.

## Usage
The general purpose of this script is to prepare a configuration file before running the main application.

You simply fill the config file with variable references as follows:
- `${INIT_LOGLEVEL}` — this will be replaced with the value of the environment variable `INIT_LOGLEVEL`. If `INIT_LOGLEVEL` is undefined, it will be resolved to an empty string.
- `${INIT_LOGLEVEL:-error}` — this is the same, but if `INIT_LOGLEVEL` is undefined, the `error` value will be used.

That's all. Additionally, you may use the following features with your environment variables:
- **`_FILE` variable**

    The variable should contain a valid file path. The script will read this file and put its content into a new variable without `_FILE`.

    E.g.: you define `INIT_PASSWORD_FILE=/run/secrets/password`; the script reads the content of `/run/secrets/password` and saves it to a new variable `INIT_PASSWORD`. The `INIT_PASSWORD_FILE` gets unset. The `INIT_PASSWORD` variable may be referenced in the config and will be replaced with the password itself (not the path to the file).

- **`_RESOLVE` variable**

    The variable should contain a valid DNS name of a remote host. The script will try to resolve the A record of the hostname with a 1-second interval. When resolution completes, the resulting IP addresses are sorted and the first one is saved into a new variable without `_RESOLVE`.

    It is useful for running software that does not support DNS resolution and that requires specifying only IP addresses.

    E.g.: you define `INIT_DB_HOST_RESOLVE=db`; the script performs `host -t A db` every second until it gets an IP address and saves the IP address to the variable `INIT_DB_HOST`. The `INIT_DB_HOST_RESOLVE` gets unset. The `INIT_DB_HOST` may be referenced in the config and will be replaced with the IP address itself (not the hostname).

- **`_PREPROCESS` variable**

    The variable should contain a shell command. The command may contain environment variable references with the same rules as the config template. The result of executing this command will be saved to a new variable without `_PREPROCESS`.

    It is useful for speeding up the preparation of certain things, for example, hashing a password before putting it into the config file. **Warning** — writing commands in environment variables is generally dangerous, so be careful.

    E.g.: you define `INIT_PASSWORD_PREPROCESS="openssl passwd -6 '\${INIT_PASSWORD}'"` and `INIT_PASSWORD='p@$$w0rD'`. The script will run the command `openssl passwd -6 'p@$$w0rD'` and save the result to `INIT_PASSWORD` (redefining the original value). The `INIT_PASSWORD_PREPROCESS` gets unset. The `INIT_PASSWORD` may be referenced in the config and will be replaced with the hash of the password.

    Alternatively, instead of defining `INIT_PASSWORD='p@$$w0rD'`, you may define `INIT_PASSWORD_FILE`. In this case, `_FILE` will be resolved first, producing `INIT_PASSWORD` with the corresponding value, and preprocess action is performed.

## Processing order
1. `_FILE` variables.
2. `_RESOLVE` variables.
3. `_PREPROCESS` variables.
4. `OPT_TEMPLATE` (config file).
5. `OPT_RUN_NEXT` (run target program) with `OPT_RUN_NEXT_CONTEXT` (if defined).

## General notes
- You may process several configuration files with this script, not just one. Define `OPT_RUN_NEXT` as the path to another configured copy of **entrypoint-sh** with a different `OPT_TEMPLATE` and `OPT_ENVVAR_PREFIX`.
- All settings of **entrypoint-sh** may be defined as environment variables without the need to modify the script. This is applicable when one **entrypoint-sh** script is in use.
- Variables created by the `_FILE`, `_RESOLVE` and `_PREPROCESS` processing do not appear in the Env section of `docker inspect`.