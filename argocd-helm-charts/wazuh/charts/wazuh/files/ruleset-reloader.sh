#!/bin/sh
# Reload this worker's analysisd whenever the ruleset on its disk changes.
#
# A worker gets etc/rules, etc/decoders and etc/lists from the master by cluster
# integrity sync, and after a pod start that sync lands tens of seconds AFTER
# analysisd has loaded the stale copy on the PVC. Nothing reloads it, so a new
# rule stays inactive on the node that analyses the agents' events, silently.
# This loop watches those directories and asks the API to reload analysisd on
# this node once they have settled: once after every start, and again after any
# later sync that changes them.
#
# It talks to the worker's own API on localhost, so no NetworkPolicy change is
# needed; the worker forwards authentication and the reload to the master over
# the cluster port it already uses.
set -u

API="https://localhost:55000"
NODE="${HOSTNAME}"
SETTLE="${RELOAD_SETTLE_SECONDS:-90}"
POLL="${RELOAD_POLL_SECONDS:-30}"
DIRS="${RULESET_DIRS:-/var/ossec/etc/rules /var/ossec/etc/decoders /var/ossec/etc/lists}"

log() { echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') ruleset-reloader: $*"; }

# Name, size and mtime of the source files. The compiled *.cdb files are left
# out: analysisd rewrites them on every reload, which would retrigger this loop.
fingerprint() {
  find $DIRS -type f ! -name '*.cdb' -exec stat -c '%n %s %Y' {} + 2>/dev/null \
    | sort | sha256sum | cut -d' ' -f1
}

# Credentials and token go to curl on stdin (-K -), not argv, so ps never shows them.
reload() {
  # Escape \ and " for curl's config syntax; the password never becomes an argument.
  user=$(printf '%s:%s' "${API_USERNAME}" "${API_PASSWORD}" | sed 's/[\\"]/\\&/g')
  token=$(printf 'user = "%s"\n' "${user}" \
    | curl -skf --max-time 30 -K - -X POST "${API}/security/user/authenticate?raw=true") || return 1
  out=$(printf 'header = "Authorization: Bearer %s"\n' "${token}" \
    | curl -skf --max-time 60 -K - -X PUT "${API}/cluster/analysisd/reload?nodes_list=${NODE}") || return 1
  echo "${out}" | grep -Eq '"total_failed_items": ?0[,}]' || { log "API answered: ${out}"; return 1; }
}

log "watching ${DIRS} (settle ${SETTLE}s, poll ${POLL}s)"
last=""
while :; do
  cur=$(fingerprint)
  if [ "${cur}" != "${last}" ]; then
    # Wait until the tree has stopped changing, so the reload sees the whole sync.
    while sleep "${SETTLE}"; now=$(fingerprint); [ "${now}" != "${cur}" ]; do
      cur="${now}"
    done
    if reload; then
      last="${cur}"
      log "analysisd reloaded on ${NODE}"
    else
      log "reload failed (API not up yet, or worker not connected); retrying"
    fi
  fi
  sleep "${POLL}"
done
