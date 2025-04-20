#!/bin/bash

set -o pipefail

set +e

# Script trace mode
if [ "${DEBUG_MODE,,}" == "true" ]; then
    set -o xtrace
fi

# Default Zabbix installation name
# Default Zabbix server host
: ${ZBX_SERVER_HOST="zabbix-server"}
# Default Zabbix server port number
: ${ZBX_SERVER_PORT="10051"}

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
    elif [ "$(grep -Ec "^[#;] $var_name=" $config_path)" -gt 0 ]; then
        sed -i -e "/^[#;] $var_name=/s/.*/&\n$var_name=$var_value/" "$config_path"
        echo "added"
    else
        sed -i -e '$a\' -e "$var_name=$var_value" "$config_path"
        echo "added at the end"
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

prepare_zbx_agent_config() {
    : ${ZBX_PASSIVESERVERS=""}
    : ${ZBX_ACTIVESERVERS=""}

    if [ ! -z "$ZBX_SERVER_HOST" ] && [ ! -z "$ZBX_PASSIVESERVERS" ]; then
        ZBX_PASSIVESERVERS=$ZBX_SERVER_HOST","$ZBX_PASSIVESERVERS
    elif [ ! -z "$ZBX_SERVER_HOST" ]; then
        ZBX_PASSIVESERVERS=$ZBX_SERVER_HOST
    fi

    if [ ! -z "$ZBX_SERVER_HOST" ]; then
        if [ ! -z "$ZBX_SERVER_PORT" ] && [ "$ZBX_SERVER_PORT" != "10051" ]; then
            ZBX_SERVER_HOST=$ZBX_SERVER_HOST":"$ZBX_SERVER_PORT
        fi
        if [ ! -z "$ZBX_ACTIVESERVERS" ]; then
            ZBX_ACTIVESERVERS=$ZBX_SERVER_HOST","$ZBX_ACTIVESERVERS
        else
            ZBX_ACTIVESERVERS=$ZBX_SERVER_HOST
        fi
    fi

    : ${ZBX_PASSIVE_ALLOW:="true"}
    if [ "${ZBX_PASSIVE_ALLOW,,}" == "true" ] && [ ! -z "$ZBX_PASSIVESERVERS" ]; then
        echo "** Using '$ZBX_PASSIVESERVERS' servers for passive checks"
        export ZBX_PASSIVESERVERS="${ZBX_PASSIVESERVERS}"
    else
        unset ZBX_PASSIVESERVERS
    fi

    : ${ZBX_ACTIVE_ALLOW:="true"}
    if [ "${ZBX_ACTIVE_ALLOW,,}" == "true" ] && [ ! -z "$ZBX_ACTIVESERVERS" ]; then
        echo "** Using '$ZBX_ACTIVESERVERS' servers for active checks"
        export ZBX_ACTIVESERVERS="${ZBX_ACTIVESERVERS}"
    else
        unset ZBX_ACTIVESERVERS
    fi
    unset ZBX_SERVER_HOST
    unset ZBX_SERVER_PORT

    if [ "${ZBX_ENABLEPERSISTENTBUFFER,,}" == "true" ]; then
        export ZBX_ENABLEPERSISTENTBUFFER=1
    else
        unset ZBX_ENABLEPERSISTENTBUFFER
        unset ZBX_PERSISTENTBUFFERFILE
    fi

    if [ "${ZBX_ENABLESTATUSPORT,,}" == "true" ]; then
        export ZBX_STATUSPORT=${ZBX_STATUSPORT="31999"}
    else
        unset ZBX_STATUSPORT
    fi

    update_config_multiple_var "${ZABBIX_CONF_DIR}/zabbix_agent2_item_keys.conf" "DenyKey" "${ZBX_DENYKEY}"
    update_config_multiple_var "${ZABBIX_CONF_DIR}/zabbix_agent2_item_keys.conf" "AllowKey" "${ZBX_ALLOWKEY}"

    file_process_from_env "ZBX_TLSCAFILE" "${ZBX_TLSCAFILE}" "${ZBX_TLSCA}"
    file_process_from_env "ZBX_TLSCRLFILE" "${ZBX_TLSCRLFILE}" "${ZBX_TLSCRL}"
    file_process_from_env "ZBX_TLSCERTFILE" "${ZBX_TLSCERTFILE}" "${ZBX_TLSCERT}"
    file_process_from_env "ZBX_TLSKEYFILE" "${ZBX_TLSKEYFILE}" "${ZBX_TLSKEY}"
    file_process_from_env "ZBX_TLSPSKFILE" "${ZBX_TLSPSKFILE}" "${ZBX_TLSPSK}"
}

prepare_zbx_agent_plugin_config() {
    echo "** Preparing Zabbix agent plugin configuration files"

    update_config_var "${ZABBIX_CONF_DIR}/zabbix_agent2.d/plugins.d/mongodb.conf" "Plugins.MongoDB.System.Path" "/usr/sbin/zabbix-agent2-plugin/mongodb"
    update_config_var "${ZABBIX_CONF_DIR}/zabbix_agent2.d/plugins.d/postgresql.conf" "Plugins.PostgreSQL.System.Path" "/usr/sbin/zabbix-agent2-plugin/postgresql"
    update_config_var "${ZABBIX_CONF_DIR}/zabbix_agent2.d/plugins.d/mssql.conf" "Plugins.MSSQL.System.Path" "/usr/sbin/zabbix-agent2-plugin/mssql"
    update_config_var "${ZABBIX_CONF_DIR}/zabbix_agent2.d/plugins.d/ember.conf" "Plugins.EmberPlus.System.Path" "/usr/sbin/zabbix-agent2-plugin/ember-plus"
    if command -v nvidia-smi 2>&1 >/dev/null
    then
        update_config_var "${ZABBIX_CONF_DIR}/zabbix_agent2.d/plugins.d/nvidia.conf" "Plugins.NVIDIA.System.Path" "/usr/sbin/zabbix-agent2-plugin/nvidia-gpu"
    fi
}

clear_zbx_env() {
    [[ "${ZBX_CLEAR_ENV}" == "false" ]] && return

    for env_var in $(env | grep -E "^ZABBIX_"); do
        unset "${env_var%%=*}"
    done
}

prepare_agent() {
    echo "** Preparing Zabbix agent"
    prepare_zbx_agent_config
    prepare_zbx_agent_plugin_config
    clear_zbx_env
}

#################################################

if [ "${1#-}" != "$1" ]; then
    set -- /usr/sbin/zabbix_agent2 "$@"
fi

if [ "$1" == '/usr/sbin/zabbix_agent2' ]; then
    prepare_agent
fi

exec "$@"

#################################################
