#!/bin/bash

set -o pipefail

set +e

# Script trace mode
if [ "${DEBUG_MODE,,}" == "true" ]; then
    set -o xtrace
fi

# Default Zabbix installation name
# Used only by Zabbix web-interface
: ${ZBX_SERVER_NAME:="Zabbix docker"}
# Default Zabbix server port number
: ${ZBX_SERVER_PORT:="10051"}

# Default timezone for web interface
: ${PHP_TZ:="Europe/Riga"}

# Default user settings
: ${DAEMON_USER:="www-data"}
: ${DAEMON_GROUP:="www-data"}

# DefaultRuntimeDir configuration option value
export APACHE_RUN_DIR="/tmp/apache2"

# Default directories
# Apache main configuration file
HTTPD_CONF_FILE="/etc/apache2/apache2.conf"
# Apache additional configuration files directory
APACHE_SITES_DIR="/etc/apache2/sites-enabled"
# Directory with SSL certificate files for Apache
APACHE_SSL_CONFIG_DIR="/etc/ssl/apache2"
# PHP-FPM configuration file
PHP_CONFIG_FILE="/etc/php/8.3/fpm/pool.d/zabbix.conf"

# usage: file_env VAR [DEFAULT]
# as example: file_env 'MYSQL_PASSWORD' 'zabbix'
#    (will allow for "$MYSQL_PASSWORD_FILE" to fill in the value of "$MYSQL_PASSWORD" from a file)
# unsets the VAR_FILE afterwards and just leaving VAR
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local defaultValue="${2:-}"

    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo "**** Both variables $var and $fileVar are set (but are exclusive)"
        exit 1
    fi

    local val="$defaultValue"

    if [ "${!var:-}" ]; then
        val="${!var}"
        echo "** Using ${var} variable from ENV"
    elif [ "${!fileVar:-}" ]; then
        if [ ! -f "${!fileVar}" ]; then
            echo "**** Secret file \"${!fileVar}\" is not found"
            exit 1
        fi
        val="$(< "${!fileVar}")"
        echo "** Using ${var} variable from secret file"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

# Check prerequisites for MySQL database
check_variables() {
    if [ ! -n "${DB_SERVER_SOCKET}" ]; then
        : ${DB_SERVER_HOST:="mysql-server"}
    else
        DB_SERVER_HOST="localhost"
    fi
    : ${DB_SERVER_PORT:="3306"}

    file_env MYSQL_USER
    file_env MYSQL_PASSWORD

    DB_SERVER_ZBX_USER=${MYSQL_USER:-"zabbix"}
    DB_SERVER_ZBX_PASS=${MYSQL_PASSWORD:-"zabbix"}

    DB_SERVER_DBNAME=${MYSQL_DATABASE:-"zabbix"}

    if [ ! -n "${DB_SERVER_SOCKET}" ]; then
        mysql_connect_args="-h ${DB_SERVER_HOST} -P ${DB_SERVER_PORT}"
    else
        mysql_connect_args="-S ${DB_SERVER_SOCKET}"
    fi
}

db_tls_params() {
    local result=""

    if [ "${ZBX_DB_ENCRYPTION,,}" == "true" ]; then
        result="--ssl-mode=required"

        if [ -n "${ZBX_DB_CA_FILE}" ]; then
            result="${result} --ssl-ca=${ZBX_DB_CA_FILE}"
        fi

        if [ -n "${ZBX_DB_KEY_FILE}" ]; then
            result="${result} --ssl-key=${ZBX_DB_KEY_FILE}"
        fi

        if [ -n "${ZBX_DB_CERT_FILE}" ]; then
            result="${result} --ssl-cert=${ZBX_DB_CERT_FILE}"
        fi
    fi

    echo $result
}

check_db_connect() {
    echo "********************"
    echo "* DB_SERVER_HOST: ${DB_SERVER_HOST}"
    echo "* DB_SERVER_PORT: ${DB_SERVER_PORT}"
    if [ -n "${DB_SERVER_SOCKET}" ]; then
        echo "* DB_SERVER_SOCKET: ${DB_SERVER_SOCKET}"
    fi
    echo "* DB_SERVER_DBNAME: ${DB_SERVER_DBNAME}"
    if [ "${DEBUG_MODE,,}" == "true" ]; then
        echo "* DB_SERVER_ZBX_USER: ${DB_SERVER_ZBX_USER}"
        echo "* DB_SERVER_ZBX_PASS: ${DB_SERVER_ZBX_PASS}"
    fi
    echo "********************"

    WAIT_TIMEOUT=5

    ssl_opts="$(db_tls_params)"

    export MYSQL_PWD="${DB_SERVER_ZBX_PASS}"

    while [ ! "$(mysqladmin ping $mysql_connect_args -u ${DB_SERVER_ZBX_USER} \
                --silent --connect_timeout=10 $ssl_opts)" ]; do
        echo "**** MySQL server is not available. Waiting $WAIT_TIMEOUT seconds..."
        sleep $WAIT_TIMEOUT
    done

    unset MYSQL_PWD
}

prepare_web_server() {
    if [ "$(id -u)" == '0' ]; then
        export APACHE_RUN_USER=${DAEMON_USER}
    else
        export APACHE_RUN_USER=$(id -n -u)
    fi
    export APACHE_RUN_GROUP=${DAEMON_GROUP}

    echo "** Adding Zabbix virtual host (HTTP)"
    if [ -f "$ZABBIX_CONF_DIR/apache.conf" ]; then
        ln -sfT "$ZABBIX_CONF_DIR/apache.conf" "$APACHE_SITES_DIR/zabbix.conf"
    else
        echo "**** Impossible to enable HTTP virtual host"
    fi

    if [ -f "$APACHE_SSL_CONFIG_DIR/ssl.crt" ] && [ -f "$APACHE_SSL_CONFIG_DIR/ssl.key" ]; then
        echo "** Adding Zabbix virtual host (HTTPS)"
        if [ -f "$ZABBIX_CONF_DIR/apache_ssl.conf" ]; then
            ln -sfT "$ZABBIX_CONF_DIR/apache_ssl.conf" "$APACHE_SITES_DIR/zabbix_ssl.conf"
        else
            echo "**** Impossible to enable HTTPS virtual host"
        fi
    else
        echo "**** Impossible to enable SSL support for Apache2. Certificates are missed."
    fi

    export HTTP_INDEX_FILE=${HTTP_INDEX_FILE:="index.php"}

    : ${ENABLE_WEB_ACCESS_LOG:="true"}
    export APACHE_CUSTOM_LOG="/proc/self/fd/1"
    if [ "${ENABLE_WEB_ACCESS_LOG,,}" == "false" ]; then
        export APACHE_CUSTOM_LOG="/dev/null"
    fi

    : ${EXPOSE_WEB_SERVER_INFO:="on"}
    export APACHE_SERVER_TOKENS="OS"
    export APACHE_SERVER_SIGNATURE="On"
    if [ "${EXPOSE_WEB_SERVER_INFO}" == "off" ]; then
        export APACHE_SERVER_TOKENS="Prod"
        export APACHE_SERVER_SIGNATURE="Off"
    fi

    mkdir -p "${APACHE_RUN_DIR}"
}

prepare_zbx_php_config() {
    echo "** Preparing PHP configuration"

    export PHP_FPM_PM=${PHP_FPM_PM:-"dynamic"}
    export PHP_FPM_PM_MAX_CHILDREN=${PHP_FPM_PM_MAX_CHILDREN:-"50"}
    export PHP_FPM_PM_START_SERVERS=${PHP_FPM_PM_START_SERVERS:-"5"}
    export PHP_FPM_PM_MIN_SPARE_SERVERS=${PHP_FPM_PM_MIN_SPARE_SERVERS:-"5"}
    export PHP_FPM_PM_MAX_SPARE_SERVERS=${PHP_FPM_PM_MAX_SPARE_SERVERS:-"35"}
    export PHP_FPM_PM_MAX_REQUESTS=${PHP_FPM_PM_MAX_REQUESTS:-"0"}

    if [ "$(id -u)" == '0' ]; then
        echo "user = ${DAEMON_USER}" >> "$PHP_CONFIG_FILE"
        echo "group = ${DAEMON_GROUP}" >> "$PHP_CONFIG_FILE"
        echo "listen.owner = ${DAEMON_USER}" >> "$PHP_CONFIG_FILE"
        echo "listen.group = ${DAEMON_GROUP}" >> "$PHP_CONFIG_FILE"
    fi

    : ${ZBX_DENY_GUI_ACCESS:="false"}
    export ZBX_DENY_GUI_ACCESS=${ZBX_DENY_GUI_ACCESS,,}
    export ZBX_GUI_ACCESS_IP_RANGE=${ZBX_GUI_ACCESS_IP_RANGE:-"['127.0.0.1']"}
    export ZBX_GUI_WARNING_MSG=${ZBX_GUI_WARNING_MSG:-"Zabbix is under maintenance."}

    export ZBX_MAXEXECUTIONTIME=${ZBX_MAXEXECUTIONTIME:-"600"}
    export ZBX_MEMORYLIMIT=${ZBX_MEMORYLIMIT:-"128M"}
    export ZBX_POSTMAXSIZE=${ZBX_POSTMAXSIZE:-"16M"}
    export ZBX_UPLOADMAXFILESIZE=${ZBX_UPLOADMAXFILESIZE:-"2M"}
    export ZBX_MAXINPUTTIME=${ZBX_MAXINPUTTIME:-"300"}
    export PHP_TZ=${PHP_TZ}

    export DB_SERVER_TYPE="MYSQL"
    export DB_SERVER_HOST=${DB_SERVER_HOST}
    export DB_SERVER_PORT=${DB_SERVER_PORT}
    export DB_SERVER_DBNAME=${DB_SERVER_DBNAME}
    export DB_SERVER_SCHEMA=${DB_SERVER_SCHEMA}
    export DB_SERVER_USER=${DB_SERVER_ZBX_USER}
    export DB_SERVER_PASS=${DB_SERVER_ZBX_PASS}
    export ZBX_SERVER_HOST=${ZBX_SERVER_HOST}
    export ZBX_SERVER_PORT=${ZBX_SERVER_PORT}
    export ZBX_SERVER_NAME=${ZBX_SERVER_NAME}

    : ${ZBX_DB_ENCRYPTION:="false"}
    export ZBX_DB_ENCRYPTION=${ZBX_DB_ENCRYPTION,,}
    export ZBX_DB_KEY_FILE=${ZBX_DB_KEY_FILE}
    export ZBX_DB_CERT_FILE=${ZBX_DB_CERT_FILE}
    export ZBX_DB_CA_FILE=${ZBX_DB_CA_FILE}
    : ${ZBX_DB_VERIFY_HOST:="false"}
    export ZBX_DB_VERIFY_HOST=${ZBX_DB_VERIFY_HOST,,}

    export ZBX_VAULT=${ZBX_VAULT}
    export ZBX_VAULTURL=${ZBX_VAULTURL}
    export ZBX_VAULTDBPATH=${ZBX_VAULTDBPATH}
    export VAULT_TOKEN=${VAULT_TOKEN}
    export ZBX_VAULTCERTFILE=${ZBX_VAULTCERTFILE}
    export ZBX_VAULTKEYFILE=${ZBX_VAULTKEYFILE}

    : ${DB_DOUBLE_IEEE754:="true"}
    export DB_DOUBLE_IEEE754=${DB_DOUBLE_IEEE754,,}

    export ZBX_HISTORYSTORAGEURL=${ZBX_HISTORYSTORAGEURL}
    export ZBX_HISTORYSTORAGETYPES=${ZBX_HISTORYSTORAGETYPES:-"[]"}

    export ZBX_SSO_SETTINGS=${ZBX_SSO_SETTINGS:-""}
    export ZBX_SSO_SP_KEY=${ZBX_SSO_SP_KEY}
    export ZBX_SSO_SP_CERT=${ZBX_SSO_SP_CERT}
    export ZBX_SSO_IDP_CERT=${ZBX_SSO_IDP_CERT}

    : ${ZBX_ALLOW_HTTP_AUTH:="true"}
    export ZBX_ALLOW_HTTP_AUTH=${ZBX_ALLOW_HTTP_AUTH}
}

prepare_zbx_config() {
    if [ -n "${ZBX_SESSION_NAME}" ]; then
        cp "$ZABBIX_WWW_ROOT/include/defines.inc.php" "/tmp/defines.inc.php_tmp"
        sed "/ZBX_SESSION_NAME/s/'[^']*'/'${ZBX_SESSION_NAME}'/2" "/tmp/defines.inc.php_tmp" > "$ZABBIX_WWW_ROOT/include/defines.inc.php"
        rm -f "/tmp/defines.inc.php_tmp"
    fi
}

#################################################

echo "** Deploying Zabbix web-interface (Apache) with MySQL database"

check_variables
check_db_connect
prepare_zbx_php_config
prepare_web_server
prepare_zbx_config

echo "########################################################"

if [ "$1" != "" ]; then
    echo "** Executing '$@'"
    exec "$@"
elif [ -f "/usr/bin/supervisord" ]; then
    echo "** Executing supervisord"
    exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf
else
    echo "Unknown instructions. Exiting..."
    exit 1
fi

#################################################
