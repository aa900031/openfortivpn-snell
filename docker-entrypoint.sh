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

function _exec_start()
{
    _exec_snell &
    SNELL_PID=$!
    echo "Started snell-server with PID $SNELL_PID"

    _exec_openfortivpn &
    VPN_PID=$!
    echo "Started openfortivpn with PID $VPN_PID"

    trap "kill $SNELL_PID $VPN_PID; exit 0" SIGINT SIGTERM

    wait -n

    echo "One of the processes exited. Stopping all..."
    kill $SNELL_PID $VPN_PID 2>/dev/null || true
}

case "$@" in
    "start" )
        _exec_start
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
