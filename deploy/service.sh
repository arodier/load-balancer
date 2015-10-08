#!/bin/sh

### BEGIN INIT INFO
# Provides:          sains
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Should-Start:      ssh
# Should-Stop:       ssh
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Sains backend
# Description:       Sains backend server
### END INIT INFO

# This is a sample service (SysV) for the sains backend...

. /lib/lsb/init-functions

PATH=/sbin:/bin:/usr/sbin:/usr/bin
NAME=sains
DESC="Sains backend"
DAEMON=/usr/bin/sains
# SAINSCONF=/etc/sains.conf

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

PIDFILE=/var/run/sains.pid

sains_start () {
    log_daemon_msg "Starting $DESC" "$NAME"

    start-stop-daemon --start --quiet --oknodo --make-pidfile --pidfile "$PIDFILE" \
                      --background --exec "$DAEMON" -- $SAINS_OPTS
    log_end_msg $?
}

sains_stop () {
    if [ -z "$PIDFILE" ]; then
        log_failure_msg \
            "No pid file set"
        exit 1
    fi

    log_daemon_msg "Stopping $DESC" "$NAME"
    start-stop-daemon --stop --quiet --oknodo --retry 5 --pidfile "$PIDFILE" \
                      --remove-pidfile --exec $DAEMON
    log_end_msg $?
}

# Just a simple start/stop daemon for now...
case "$1" in
    start)
        sains_start
        ;;
    stop)
        sains_stop
        ;;
    status)
        status_of_proc -p $PIDFILE $DAEMON $NAME
        ;;
    restart)
        sains_stop
        sains_start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 2
        ;;
esac
