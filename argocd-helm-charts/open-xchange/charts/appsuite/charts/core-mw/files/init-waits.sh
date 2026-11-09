# Bounded readiness waits for the legacy bash init container, sourced into the
# init container command by templates/typed-resources.yaml. The Go init binary
# implements the same waits for the non-legacy path.
#
# Reads MYSQL_HOST, MYSQL_PORT, INIT_DB_WAIT_TIMEOUT and INIT_MW_WAIT_TIMEOUT.

DB_WAIT_INTERVAL=2
DB_DNS_TIMEOUT=30
MW_WAIT_INTERVAL=5

# Also records the reason in the pod status, which survives a restart.
fail() {
    echo "$1"
    { echo "$1" > /dev/termination-log; } 2>/dev/null || true
    exit 1
}

# curl exit code 6 means the name did not resolve. Used instead of getent,
# which the Wolfi base image does not ship.
resolves() {
    curl -s -o /dev/null --max-time 5 "http://${MYSQL_HOST}:${MYSQL_PORT}"
    [ "$?" -ne 6 ]
}

wait_for_db() {
    local timeout="${INIT_DB_WAIT_TIMEOUT}"
    local start=${SECONDS}
    # Set before the DNS grace so both phases share the one timeout.
    local deadline=$((SECONDS + timeout))
    local next_report=$((SECONDS + 30))
    local dns_deadline

    echo "Waiting up to ${timeout}s for the MySQL Server to be ready ... "
    if [ "${DB_DNS_TIMEOUT}" -gt 0 ] && command -v curl > /dev/null 2>&1; then
        dns_deadline=$((SECONDS + DB_DNS_TIMEOUT))
        while ! resolves; do
            if [ "${SECONDS}" -ge "${dns_deadline}" ]; then
                fail "The host name ${MYSQL_HOST} does not resolve after ${DB_DNS_TIMEOUT}s. Check the MYSQL_HOST setting, whether the database service exists in this namespace, and whether cluster DNS is answering"
            fi
            sleep "${DB_WAIT_INTERVAL}"
        done
    else
        echo "No curl available, skipping the DNS check. An unresolvable host name will only be reported after ${timeout}s"
    fi

    while ! nc -z -w 5 "${MYSQL_HOST}" "${MYSQL_PORT}" > /dev/null 2>&1; do
        if [ "${SECONDS}" -ge "${deadline}" ]; then
            fail "Could not connect to the MySQL Server at ${MYSQL_HOST}:${MYSQL_PORT} within ${timeout}s. Check that the database is running, that the port is correct, and that no network policy blocks it"
        fi
        if [ "${SECONDS}" -ge "${next_report}" ]; then
            echo "Still waiting for the MySQL Server at ${MYSQL_HOST}:${MYSQL_PORT} after $((SECONDS - start))s of ${timeout}s"
            next_report=$((SECONDS + 30))
        fi
        sleep "${DB_WAIT_INTERVAL}"
    done
    echo "The MySQL Server is up & running"
}

wait_for_middleware() {
    local timeout="${INIT_MW_WAIT_TIMEOUT}"
    local deadline=$((SECONDS + timeout))
    local status

    while true; do
        status=$(curl -sLI -w '%{http_code}' http://localhost:8009/health -o /dev/null)
        if [ "${status}" -eq 200 ]; then
            echo "Middleware is up & running"
            break
        fi
        echo "Middleware health status: ${status}"
        if [ "${SECONDS}" -ge "${deadline}" ]; then
            fail "The middleware did not become available within ${timeout}s. The last health check returned status ${status} - check the container log above for the reason it did not finish starting"
        fi
        sleep "${MW_WAIT_INTERVAL}"
    done
}
