#!/usr/bin/env sh
# shellcheck shell=sh

# This program is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation, either
# version 3 of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

# You should have received a copy of the GNU General Public License along with this
# program. If not, see <https://www.gnu.org/licenses/>.

# entrypoint.sh 1.0.0 <https://github.com/heaveaxy/entrypoint-sh>

##############################
########## SETTINGS ##########
##############################

L_ERR=1 L_WRN=2 L_INF=3 L_DBG=4

OPT_LOGLEVEL=${OPT_LOGLEVEL:-$L_WRN}
OPT_ENVVAR_PREFIX=${OPT_ENVVAR_PREFIX:-"INIT_"}

# Path to configuration file in container that will processed by container-init
# Note about extra extension. This file will be copied to another - without last extension in name.
OPT_TEMPLATE=${OPT_TEMPLATE:-"/path/to/config.conf.template"}

# Executable will be ran after container-init completes it's own work.
# Note about $* - cmdline arguments passed during running container. It may be important for application.
OPT_RUN_NEXT=${OPT_RUN_NEXT:-"/path/to/app $*"}

# Fill context for drop privileges to. Format: "uid:gid", i.e. "1000:1000"
OPT_RUN_NEXT_CONTEXT=""
CONTEXT_SWITCHER=$(command -v su-exec || command -v gosu)

################################
############ LOGIC #############
################################

log() {
    # $1 - log level string: 1 - ERR, 2 - WARN, 3 - INFO, 4 - DEBUG
    # $2 - message
    # shellcheck disable=SC2034
    L1="ERR" L2="WRN" L3="INF" L4="DBG"
	if [ "$1" -le "$OPT_LOGLEVEL" ] && [ "$OPT_LOGLEVEL" != 0 ]; then
		echo "$(date +"%Y-%m-%dT%H:%M:%S%z")  $(basename "$0")  $(eval "echo \$L$1")  $2"
	fi
}

process_file_envvar() {
    # $1 - envvar name
    _envvar_resolved=$(echo "$1" | sed 's/_FILE$//')
    _path=$(eval "echo \$$1")

    if [ -z "$_path" ] || [ ! -f "$_path" ]; then
        log "$L_ERR" "File defined in $1 ($_path) not exists"
        exit 1
    fi

    eval "${_envvar_resolved}='$(cat "$_path")'"
    export "${_envvar_resolved?}"
    unset "$1"
}

process_resolve_envvar() {
    # $1 - envvar name
    _envvar_resolved=$(echo "$1" | sed 's/_RESOLVE$//')
    _host=$(eval "echo \$$1")

    if [ -z "$(command -v host)" ]; then
        log "$L_ERR" "Command 'host' not found. This command is required for resolve hostname. Please install required packages to use _RESOLVE vars."
        exit 1
    fi

    while true; do
        if _resolve_result=$(host -t A "$_host"); then
            _resolved_addr=$(echo "$_resolve_result" | sort | head -n 1 | cut -d' ' -f4)
            log "$L_INF" "Host '$_host' resolved to $_resolved_addr"
            break
        fi

        log "$L_INF" "Host '$_host' seems unavailable. Waiting 1 second to retry..."
        sleep 1
    done

    eval "${_envvar_resolved}=\"$_resolved_addr\""
    export "${_envvar_resolved?}"
    unset "$1"
}

process_preprocess_envvar() {
    # $1 - preprocess envvar name

    _preprocess_cmd=$(eval "echo \$$1" | envsubst_awk)
    _processed_data_varname=$(echo "$1" | sed -e 's/_PREPROCESS$//')
    log "$L_DBG" "$1: result of preprocess will be saved to '$_processed_data_varname' variable"

    if [ -z "$_preprocess_cmd" ]; then
        log "$L_ERR" "$1: preprocess cmd is empty"
    fi

    log "$L_DBG" "$1: command will use for preprocessing: '$_preprocess_cmd'"

    if ! _preprocess_result=$(eval "$_preprocess_cmd"); then
        log "$L_ERR" "$1: preprocessing failed because of failed command"
        exit 1
    fi

    log "$L_DBG" "$1: preprocessing result is: $_preprocess_result"
    log "$L_DBG" "$1: eval string is: $_processed_data_varname = '$_preprocess_result'"
    eval "${_processed_data_varname}='$_preprocess_result'"
    export "${_processed_data_varname?}"
    unset "$1"
}

envsubst_awk() {
    awk '
    {
        line = $0

        while (match(line, /\$\{[A-Za-z_][A-Za-z0-9_]*:-[^}]*\}/)) {
            entry = substr(line, RSTART, RLENGTH)
            inner = substr(entry, 3, length(entry) - 3)
            sep_index = index(inner, ":-")
            varname  = substr(inner, 1, sep_index - 1)
            defval   = substr(inner, sep_index + 2)

            value = (varname in ENVIRON && ENVIRON[varname] != "") ? ENVIRON[varname] : defval
            line = substr(line, 1, RSTART - 1) value substr(line, RSTART + RLENGTH)
        }

        while (match(line, /\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) {
            entry = substr(line, RSTART, RLENGTH)
            varname  = substr(entry, 3, length(entry) - 3)
            line  = substr(line, 1, RSTART - 1) ENVIRON[varname] substr(line, RSTART + RLENGTH)
        }

        print line
    }
    '
}

process_config() {
    # $1 - config path
    _target_config=${1%.*}
    [ ! -f "$1" ] && log "$L_ERR" "Source config file $1 not exists" && exit 1
    if ! touch "$_target_config"; then
        log "$L_ERR" "Unable to create config file '$_target_config'"
        exit 1
    fi
    envsubst_awk < "$1" > "$_target_config"
}

main() {
    # $1 - all arguments for main script
    log "$L_DBG" "Passed CMD arguments: $*"
    log "$L_DBG" "Using context: $(id -u):$(id -g)"

    envvar_file=$(env | cut -d= -f1 | grep "$OPT_ENVVAR_PREFIX" | grep -E "_FILE$")

    for _envvar in $envvar_file; do
        log "$L_INF" "Processing FILE variable $_envvar"
        process_file_envvar "$_envvar"
    done

    unset envvar_file

    envvar_resolve=$(env | cut -d= -f1 | grep "$OPT_ENVVAR_PREFIX" | grep -E "_RESOLVE$")

    for _envvar in $envvar_resolve; do
        log "$L_INF" "Processing RESOLVE variable $_envvar"
        process_resolve_envvar "$_envvar"
    done

    unset envvar_resolve

    envvar_preprocess=$(env | cut -d= -f1 | grep "$OPT_ENVVAR_PREFIX" | grep -E "_PREPROCESS$")

    for _envvar in $envvar_preprocess; do
        log "$L_INF" "Processing PREPROCESS variable $_envvar"
        process_preprocess_envvar "$_envvar"
    done

    unset envvar_preprocess

    log "$L_INF" "Processing config file $OPT_TEMPLATE"

    process_config "$OPT_TEMPLATE"

    if [ -z "$CONTEXT_SWITCHER" ] && [ -n "$OPT_RUN_NEXT_CONTEXT" ]; then
        log "$L_WRN" "No context switcher executable found. Context will remain $(id -u):$(id -g)"
        log "$L_DBG" "Work done. Running next program: $OPT_RUN_NEXT"
        exec $OPT_RUN_NEXT
        exit 1
    fi

    if [ -n "$CONTEXT_SWITCHER" ] && [ -n "$OPT_RUN_NEXT_CONTEXT" ]; then
        log "$L_DBG" "Work done. Running next program with context $OPT_RUN_NEXT_CONTEXT: $OPT_RUN_NEXT"
        exec "$CONTEXT_SWITCHER" "$OPT_RUN_NEXT_CONTEXT $OPT_RUN_NEXT"
        exit 1
    fi

    if [ -n "$OPT_RUN_NEXT" ]; then
        log "$L_DBG" "Work done. Running next program: $OPT_RUN_NEXT"
        exec $OPT_RUN_NEXT
    fi

    log "$L_DBG" "Executing cmdline: $*"
    exec $1
}

[ -z "$NORUN" ] && main "$*"
