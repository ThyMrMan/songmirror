#!/bin/sh
# Run SongMirror as the host user given by PUID/PGID.
#
# SongMirror keeps its data folder owner-only because it holds tokens and
# passwords. Running as root makes root that owner, which locks the host user
# out of a bind-mounted folder (for example over a network share). With
# PUID/PGID set, the data folder is handed to that user and the app runs as
# them. Without them, the container runs as root, as before.
set -eu

if [ "$(id -u)" != "0" ] || [ -z "${PUID:-}${PGID:-}" ]; then
    exec "$@"
fi

case "${PUID:-}:${PGID:-}" in
    *[!0-9:]* | :* | *:)
        echo "songmirror: set both PUID and PGID to numeric ids (got PUID='${PUID:-}' PGID='${PGID:-}')" >&2
        exit 1
        ;;
esac

data_dir="${SONGMIRROR_DATA_DIR:-/data}"
home_dir=/home/songmirror
mkdir -p "$data_dir" "$home_dir"
chown -R "$PUID:$PGID" "$data_dir" "$home_dir"

# spotDL and uv keep their config and cache under $HOME.
export HOME="$home_dir"
echo "songmirror: running as $PUID:$PGID"
exec setpriv --reuid="$PUID" --regid="$PGID" --clear-groups "$@"
