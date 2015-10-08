#!/bin/sh

### BEGIN INIT INFO
# Provides:          sainsbury
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Should-Start:      ssh
# Should-Stop:       ssh
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Sainsbury backend
# Description:       Sainsbury backend server
### END INIT INFO

# This is a sample service (SysV) for the sainsbury backend...

. /lib/lsb/init-functions

PATH=/sbin:/bin:/usr/sbin:/usr/bin
NAME=sainsbury
DESC="Sainsbury backend"
DAEMON=/usr/bin/sainsbury
# SAINSBURYCONF=/etc/sainsbury.conf

# Exit if the package is not installed
[ -x "$DAEMON" ] || exit 0

# Read configuration variable file if it is present
[ -r /etc/default/$NAME ] && . /etc/default/$NAME

PIDFILE=/var/run/sainsbury.pid

sainsbury_start () {
    log_daemon_msg "Starting $DESC" "$NAME"

    start-stop-daemon --start --quiet --oknodo --make-pidfile --pidfile "$PIDFILE" \
                      --background --exec "$DAEMON" -- $SAINSBURY_OPTS
    log_end_msg $?
}

sainsbury_stop () {
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
        sainsbury_start
        ;;
    stop)
        sainsbury_stop
        ;;
    status)
        status_of_proc -p $PIDFILE $DAEMON $NAME
        ;;
    restart)
        sainsbury_stop
        sainsbury_start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 2
        ;;
esac
