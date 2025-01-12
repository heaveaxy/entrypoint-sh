#!/usr/bin/env sh
# shellcheck shell=sh

# shellcheck disable=SC1091
NORUN=1 . "$(dirname "$0")"/../entrypoint.sh

# shellcheck disable=SC2034
OPT_LOGLEVEL=4

# Logging
[ -n "$(OPT_LOGLEVEL=1 log "1" "test")" ] || exit 1
[ -z "$(OPT_LOGLEVEL=1 log "2" "test")" ] || exit 1
[ -z "$(OPT_LOGLEVEL=1 log "3" "test")" ] || exit 1
[ -z "$(OPT_LOGLEVEL=1 log "4" "test")" ] || exit 1

[ -n "$(OPT_LOGLEVEL=2 log "1" "test")" ] || exit 1
[ -n "$(OPT_LOGLEVEL=2 log "2" "test")" ] || exit 1
[ -z "$(OPT_LOGLEVEL=2 log "3" "test")" ] || exit 1
[ -z "$(OPT_LOGLEVEL=2 log "4" "test")" ] || exit 1

[ -n "$(OPT_LOGLEVEL=3 log "1" "test")" ] || exit 1
[ -n "$(OPT_LOGLEVEL=3 log "2" "test")" ] || exit 1
[ -n "$(OPT_LOGLEVEL=3 log "3" "test")" ] || exit 1
[ -z "$(OPT_LOGLEVEL=3 log "4" "test")" ] || exit 1

[ -n "$(OPT_LOGLEVEL=4 log "1" "test")" ] || exit 1
[ -n "$(OPT_LOGLEVEL=4 log "2" "test")" ] || exit 1
[ -n "$(OPT_LOGLEVEL=4 log "3" "test")" ] || exit 1
[ -n "$(OPT_LOGLEVEL=4 log "4" "test")" ] || exit 1

INIT_TEST_FILE="/etc/hostname"
export INIT_TEST_FILE
process_file_envvar "INIT_TEST_FILE"
if [ -z "$INIT_TEST" ]; then
    echo "FILE envvar test failed!"
    exit 1
fi

INIT_TEST_HOST_RESOLVE="example.com"
export INIT_TEST_HOST_RESOLVE
process_resolve_envvar "INIT_TEST_HOST_RESOLVE"
if [ -z "$INIT_TEST_HOST" ]; then
    echo "RESOLVE envvar test failed!"
    exit 1
fi

INIT_TEST_PWD="password"
# shellcheck disable=SC2016
# shellcheck disable=SC2089
INIT_TEST_PWD_PREPROCESS='echo "${INIT_TEST_PWD}" | base64'
export INIT_TEST_PWD
# shellcheck disable=SC2090
export INIT_TEST_PWD_PREPROCESS
process_preprocess_envvar "INIT_TEST_PWD_PREPROCESS"

if [ -z "$INIT_TEST_PWD" ]; then
    echo "INIT_TEST_PWD = $INIT_TEST_PWD"
    echo "PREPROCESS envvar test failed!"
    exit 1
fi

echo "All tests completed successfully"
