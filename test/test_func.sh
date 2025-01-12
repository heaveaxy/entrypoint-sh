#!/usr/bin/env sh
# shellcheck shell=sh

WORKDIR=$(mktemp -d)
FIXTURE_CONFIG_TEMPLATE_FILE="${WORKDIR}/config_file.template"
FIXTURE_CONFIG_TARGET_FILE="${WORKDIR}/config_file.target"
FIXTURE_PASSWORD_FILE="${WORKDIR}/secret_file"

echo "test_password" > "${FIXTURE_PASSWORD_FILE}"

cat <<EOF > "${FIXTURE_CONFIG_TEMPLATE_FILE}"
option_password = "\${TEST_PASSWORD}"
option_hash = "\${TEST_HASH}"
option_host = "\${TEST_HOST}"
option_unknown = "\${TEST_UNKNWN:-disable}"
EOF

cat <<EOF > "${FIXTURE_CONFIG_TARGET_FILE}"
option_password = "test_password"
option_hash = "\$6\$test_salt\$aNni3BLA8N8DzrwFL7kBOUUj7nMi8wrrpxzvbuPuNowFXJVz5/qQirxEXmjuozg2auTw8OJz3Xa9OLG6cjNhl."
option_host = "8.47.69.5"
option_unknown = "disable"
EOF

# User defined options for init-sh

# test file_envvar
TEST_PASSWORD_FILE="$FIXTURE_PASSWORD_FILE"
# test preprocess_envvar
TEST_HASH_FILE="${WORKDIR}/secret_file"
TEST_HASH_PREPROCESS="openssl passwd -6 --salt test_salt \${TEST_HASH}"
# test resolve_envvar
TEST_HOST_RESOLVE="example.com"
# test config processing
OPT_TEMPLATE="$FIXTURE_CONFIG_TEMPLATE_FILE"

OPT_RUN_NEXT="/usr/bin/env echo All tests completed successfully"

export TEST_PASSWORD_FILE
export TEST_HASH_FILE
export TEST_HOST_RESOLVE
export TEST_HASH_PREPROCESS

# init-sh itself settings

OPT_LOGLEVEL=4
OPT_ENVVAR_PREFIX="TEST_"

export OPT_LOGLEVEL
export OPT_ENVVAR_PREFIX
export OPT_TEMPLATE
export OPT_RUN_NEXT

/usr/bin/env sh "$(dirname "$0")"/../entrypoint.sh "$*"

if ! cmp "$FIXTURE_CONFIG_TARGET_FILE" "${FIXTURE_CONFIG_TEMPLATE_FILE%.*}"; then
    echo "The file ${FIXTURE_CONFIG_TEMPLATE_FILE%.*} contents do not match what was expected."
    exit 1
fi
