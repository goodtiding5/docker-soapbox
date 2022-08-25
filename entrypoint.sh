#!/bin/ash

set -e

WORKDIR=/opt/pleroma
DATADIR=/var/lib/pleroma

PATH=$PATH:$WORKDIR/bin; export PATH

if [[ -t 0 || -p /dev/stdin ]]; then
    # we have an interactive session
    export PS1='[\u@\h : \w]\$ '
    if [[ $@ ]]; then
	eval "exec $@"
    else
	exec /bin/sh
    fi
else
    if [[ $@ ]]; then
	eval "exec $@"
    else
	/usr/local/bin/start_pleroma.sh
    fi
fi

# Will never reach here
exit 0



