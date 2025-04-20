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

escape_spec_char() {
    local var_value=$1

    var_value="${var_value//\\/\\\\}"
    var_value="${var_value//[$'\n']/}"
    var_value="${var_value//\//\\/}"
    var_value="${var_value//./\\.}"
    var_value="${var_value//\*/\\*}"
    var_value="${var_value//^/\\^}"
    var_value="${var_value//\$/\\\$}"
    var_value="${var_value//\&/\\\&}"
    var_value="${var_value//\[/\\[}"
    var_value="${var_value//\]/\\]}"

    echo "$var_value"
}

update_config_var() {
    local config_path=$1
    local var_name=$2
    local var_value=$3
    local is_multiple=$4

    local masklist=("TLSPSKIdentity")

    if [ ! -f "$config_path" ]; then
        echo "**** Configuration file '$config_path' does not exist"
        return
    fi

    if [[ " ${masklist[@]} " =~ " $var_name " ]] && [ ! -z "$var_value" ]; then
        echo -n "** Updating '$config_path' parameter \"$var_name\": '****'. Enable DEBUG_MODE to view value ..."
    else
        echo -n "** Updating '$config_path' parameter \"$var_name\": '$var_value'..."
    fi

    # Remove configuration parameter definition in case of unset or empty parameter value
    if [ -z "$var_value" ]; then
        sed -i -e "/^$var_name=/d" "$config_path"
        echo "removed"
        return
    fi

    # Remove value from configuration parameter in case of set to double quoted parameter value
    if [[ "$var_value" == '""' ]]; then
        if [ "$(grep -E "^$var_name=" $config_path)" ]; then
            sed -i -e "/^$var_name=/s/=.*/=/" "$config_path"
        else
            sed -i -e "/^[#;] $var_name=/s/.*/&\n$var_name=/" "$config_path"
        fi
        echo "undefined"
        return
    fi

    # Use full path to a file for TLS related configuration parameters
    if [[ $var_name =~ ^TLS.*File$ ]] && [[ ! $var_value =~ ^/.+$ ]]; then
        var_value=$ZABBIX_USER_HOME_DIR/enc/$var_value
    fi

    # Escaping characters in parameter value and name
    var_value=$(escape_spec_char "$var_value")
    var_name=$(escape_spec_char "$var_name")

    if [ "$(grep -E "^$var_name=$var_value$" $config_path)" ]; then
        echo "exists"
    elif [ "$(grep -E "^$var_name=" $config_path)" ] && [ "$is_multiple" != "true" ]; then
        sed -i -e "/^$var_name=/s/=.*/=$var_value/" "$config_path"
        echo "updated"
    elif [ "$(grep -Ec "^# $var_name=" $config_path)" -gt 1 ]; then
        sed -i -e  "/^[#;] $var_name=$/i\\$var_name=$var_value" "$config_path"
        echo "added first occurrence"
    else
        sed -i -e "/^[#;] $var_name=/s/.*/&\n$var_name=$var_value/" "$config_path"
        echo "added"
    fi

}

update_config_multiple_var() {
    local config_path=$1
    local var_name=$2
    local var_value=$3

    var_value="${var_value%\"}"
    var_value="${var_value#\"}"

    local IFS=,
    local OPT_LIST=($var_value)

    for value in "${OPT_LIST[@]}"; do
        update_config_var $config_path $var_name $value true
    done
}

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

update_zbx_config() {
    : ${ZBX_USE_NODE_NAME_AS_DB_NAME:="false"}
    if [ "${ZBX_USE_NODE_NAME_AS_DB_NAME,,}" == "false" ]; then
        export ZBX_DB_NAME="${ZABBIX_USER_HOME_DIR}/db_data/${ZBX_HOSTNAME:-"zabbix-proxy-sqlite3"}.sqlite"
    else
        node_name=$(uname -n)
        export ZBX_DB_NAME="${ZABBIX_USER_HOME_DIR}/db_data/$node_name.sqlite"
    fi
    unset ZBX_USE_NODE_NAME_AS_DB_NAME

    export ZBX_SERVER_HOST="${ZBX_SERVER_HOST:="zabbix-server"}"

    if [ ! -z "${ZBX_HOSTNAMEITEM}" ]; then
        export ZBX_HOSTNAME=""
    else
        export ZBX_HOSTNAME="${ZBX_HOSTNAME:-"zabbix-proxy-sqlite3"}"
    fi

    : ${ZBX_ENABLE_SNMP_TRAPS:="false"}
    [[ "${ZBX_ENABLE_SNMP_TRAPS,,}" == "true" ]] && export ZBX_STARTSNMPTRAPPER=1
    unset ZBX_ENABLE_SNMP_TRAPS

    update_config_multiple_var "${ZABBIX_CONF_DIR}/zabbix_proxy_modules.conf" "LoadModule" "${ZBX_LOADMODULE}"

    file_process_from_env "ZBX_TLSCAFILE" "${ZBX_TLSCAFILE}" "${ZBX_TLSCA}"
    file_process_from_env "ZBX_TLSCRLFILE" "${ZBX_TLSCRLFILE}" "${ZBX_TLSCRL}"

    file_process_from_env "ZBX_TLSCERTFILE" "${ZBX_TLSCERTFILE}" "${ZBX_TLSCERT}"
    file_process_from_env "ZBX_TLSKEYFILE" "${ZBX_TLSKEYFILE}" "${ZBX_TLSKEY}"

    file_process_from_env "ZBX_TLSPSKFILE" "${ZBX_TLSPSKFILE}" "${ZBX_TLSPSK}"

    if [ "$(id -u)" != '0' ]; then
        export ZBX_USER="$(whoami)"
    else
        export ZBX_ALLOWROOT=1
    fi

    command -v openssl >/dev/null 2>&1 && openssl rehash -v "${ZBX_SSLCALOCATION}" 1>/dev/null
}

clear_zbx_env() {
    [[ "${ZBX_CLEAR_ENV}" == "false" ]] && return

    for env_var in $(env | grep -E "^ZABBIX_"); do
        unset "${env_var%%=*}"
    done
}

prepare_proxy() {
    echo "Preparing Zabbix proxy"

    update_zbx_config
    clear_zbx_env
}

#################################################

if [ "${1#-}" != "$1" ]; then
    set -- /usr/sbin/zabbix_proxy "$@"
fi

if [ "$1" == '/usr/sbin/zabbix_proxy' ]; then
    prepare_proxy
fi

exec "$@"

#################################################
