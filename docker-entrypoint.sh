#!/bin/bash
set -e

# if command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
        set -- mysqld "$@"
fi

if [ "$1" = 'mysqld' ]; then
        # Get config
        DATADIR="$("$@" --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"

        if [ ! -d "$DATADIR/mysql" ]; then
                if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ]; then
                        echo >&2 'error: database is uninitialized and MYSQL_ROOT_PASSWORD not set'
                        echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
                        exit 1
                fi

                mkdir -p "$DATADIR"
                chown -R mysql:mysql "$DATADIR"

                echo 'Initializing database'
                mysql_install_db --user=mysql --datadir="$DATADIR" --rpm --keep-my-cnf
                echo 'Database initialized'

                "$@" --skip-networking &
                pid="$!"

                mysql=( mysql --protocol=socket -uroot )

                for i in {30..0}; do
                        if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
                                break
                        fi
                        echo 'MySQL init process in progress...'
                        sleep 1
                done
