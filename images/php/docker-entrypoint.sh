#!/bin/sh
# vim:sw=4:ts=4:et

set -e

. /docker-entrypoint.functions

should_run_entrypoint() {
    # If DOCKER_ENTRYPOINT_COMMANDS is set, use it (comma-separated list)
    if [ -n "${DOCKER_ENTRYPOINT_COMMANDS:-}" ]; then
        commands=$(echo "$DOCKER_ENTRYPOINT_COMMANDS" | tr ',' ' ')
        for cmd in $commands; do
            if [ "$1" = "$cmd" ]; then
                return 0
            fi
        done
        return 1
    fi

    case "$1" in
        php|php-fpm|php-cgi|phpdbg|composer|composer.phar|artisan)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

if should_run_entrypoint "$1"; then
    if /usr/bin/find "/docker-entrypoint.d/" -mindepth 1 -maxdepth 1 -type f -print -quit 2>/dev/null | read v; then
        entrypoint_log "/docker-entrypoint.d/ is not empty, will attempt to perform configuration"
        entrypoint_log "Looking for shell scripts in /docker-entrypoint.d/"
        find "/docker-entrypoint.d/" -follow -type f -print | sort -V | while read -r f; do
            case "$f" in
                *.envsh)
                    if [ -x "$f" ]; then
                        entrypoint_log "Sourcing $f";
                        . "$f" "$@"
                    else
                        # warn on shell scripts without exec bit
                        entrypoint_warn "Ignoring $f, not executable";
                    fi
                    ;;
                *.sh)
                    if [ -x "$f" ]; then
                        entrypoint_log "Launching $f";
                        "$f" "$@"
                    else
                        # warn on shell scripts without exec bit
                        entrypoint_warn "Ignoring $f, not executable";
                    fi
                    ;;
                *) entrypoint_warn "Ignoring $f";;
            esac
        done
        entrypoint_log "Configuration complete; ready for start up"
    else
        entrypoint_log "No files found in /docker-entrypoint.d/ skipping configuration"
    fi
fi

exec "$@"
