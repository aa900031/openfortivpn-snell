#!/bin/bash

set -e -o pipefail

function _exec_snell()
{
    local PATH_SNELL_ETC_DIR="/etc/snell"
    local PATH_SNELL_CONFIG="$PATH_SNELL_ETC_DIR/snell-server.conf"

    if [[ ! -f "$PATH_SNELL_CONFIG" ]]; then
        mkdir -p $PATH_SNELL_ETC_DIR
        cat <<EOF >>$PATH_SNELL_CONFIG
[snell-server]
listen = $SNELL_HOST:$SNELL_PORT
psk = $SNELL_PSK
obfs = $SNELL_OBFS
EOF
    fi

    /usr/bin/snell-server -c $PATH_SNELL_CONFIG
}

function _exec_openfortivpn ()
{
    if [[ ! -z "$OTP_SECRET" ]]; then
        local OTP_VALUE=$(oathtool $OTP_ARGS $OTP_SECRET)

        if [[ "$OTP_IS_OPENFORTIVPN_PASSWORD" == "true" ]]; then
            OPENFORTIVPN_PASSWORD=$OTP_VALUE
        fi
    fi

    if [[ -z "$OPENFORTIVPN_HOSTNAME" ]]; then
        echo "Please set env: OPENFORTIVPN_HOSTNAME"
        exit 1
    fi

    if [[ -z "$OPENFORTIVPN_ARGS" ]]; then
        OPENFORTIVPN_ARGS=""

        if [[ ! -z "$OPENFORTIVPN_USERNAME" ]]; then
            OPENFORTIVPN_ARGS="$OPENFORTIVPN_ARGS -u $OPENFORTIVPN_USERNAME"
        fi

        if [[ ! -z "$OPENFORTIVPN_PASSWORD" && "$OPENFORTIVPN_PASSWORD_STDIN" == "false" ]]; then
            OPENFORTIVPN_ARGS="$OPENFORTIVPN_ARGS -p $OPENFORTIVPN_PASSWORD"
        fi

        if [[ ! -z "$OTP_VALUE" && "$OPENFORTIVPN_PASSWORD_STDIN" == "false" ]]; then
            OPENFORTIVPN_ARGS="$OPENFORTIVPN_ARGS -o $OPENFORTIVPN_PASSWORD"
        fi

        OPENFORTIVPN_ARGS="$OPENFORTIVPN_ARGS $OPENFORTIVPN_EXTRA_ARGS"
    fi

    if [[ "$OPENFORTIVPN_PASSWORD_STDIN" == "true" ]]; then
        echo $OPENFORTIVPN_PASSWORD | /usr/bin/openfortivpn $OPENFORTIVPN_ARGS $OPENFORTIVPN_HOSTNAME
    else
        /usr/bin/openfortivpn $OPENFORTIVPN_ARGS $OPENFORTIVPN_HOSTNAME
    fi
}

function _exec_supervisor()
{
    local PATH_SUPERVISOR_CONFIG_DIR="/etc/supervisor/conf.d"
    local PATH_SUPERVISOR_CONFIG="$PATH_SUPERVISOR_CONFIG_DIR/supervisord.conf"
    local PATH_OPENFORTIVPN_LOG_DIR="/var/log/openfortivpn"
    local PATH_SNELL_LOG_DIR="/var/log/snell"

    mkdir -p $PATH_SUPERVISOR_CONFIG_DIR
    mkdir -p $PATH_OPENFORTIVPN_LOG_DIR
    mkdir -p $PATH_SNELL_LOG_DIR

    cat <<EOF >>$PATH_SUPERVISOR_CONFIG
[supervisord]
nodaemon=true

[program:openfortivpn]
command=/docker-entrypoint.sh openfortivpn

[program:snell]
command=/docker-entrypoint.sh snell
EOF

    /usr/bin/supervisord -c $PATH_SUPERVISOR_CONFIG
}

case "$@" in
    "supervisor" )
        _exec_supervisor
    ;;

    "snell" )
        _exec_snell
    ;;

    "openfortivpn" )
        _exec_openfortivpn
    ;;

    *)
        exec "$@"
esac
