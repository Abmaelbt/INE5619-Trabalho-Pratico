#!/bin/bash

set -o pipefail

set +e

# Script trace mode
if [ "${DEBUG_MODE,,}" == "true" ]; then
    set -o xtrace
fi

# Default directories
# Internal directory for TLS related files, used when TLS*File specified as plain text values
ZABBIX_INTERNAL_ENC_DIR="${ZABBIX_USER_HOME_DIR}/enc_internal"

file_process_from_env() {
    local var_name=$1
    local file_name=$2
    local var_value=$3

    if [ ! -z "$var_value" ]; then
        echo -n "$var_value" > "${ZABBIX_INTERNAL_ENC_DIR}/$var_name"
        file_name="${ZABBIX_INTERNAL_ENC_DIR}/${var_name}"
    fi

    if [ -n "$var_value" ]; then
        export "$var_name"="$file_name"
    fi
    # Remove variable with plain text data
    unset "${var_name%%FILE}"
}

prepare_zbx_web_service_config() {
    export ZBX_ALLOWEDIP=${ZBX_ALLOWEDIP:="zabbix-server"}

    file_process_from_env "ZBX_TLSCAFILE" "${ZBX_TLSCAFILE}" "${ZBX_TLSCA}"

    file_process_from_env "ZBX_TLSCERTFILE" "${ZBX_TLSCERTFILE}" "${ZBX_TLSCERT}"
    file_process_from_env "ZBX_TLSKEYFILE" "${ZBX_TLSKEYFILE}" "${ZBX_TLSKEY}"
}

clear_zbx_env() {
    [[ "${ZBX_CLEAR_ENV}" == "false" ]] && return

    for env_var in $(env | grep -E "^ZABBIX_"); do
        unset "${env_var%%=*}"
    done
}

prepare_web_service() {
    echo "** Preparing Zabbix web service"
    prepare_zbx_web_service_config
    clear_zbx_env
}

#################################################

if [ "$1" == '/usr/sbin/zabbix_web_service' ]; then
    prepare_web_service
fi

exec "$@"

#################################################
