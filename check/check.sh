#!/bin/sh
# SOA serial consistency check for lucos_dns_secondary.
# Compares the secondary's SOA serial against the primary nameserver for each
# managed zone and reports pass/fail to schedule_tracker.
#
# Failure modes detected:
#   - Stale: secondary serial behind primary  → status=error
#   - Zone missing: local serial absent       → status=error
#   - Primary unreachable: can't compare      → status=error
#   - Dead secondary: job stops pushing       → overdue in schedule_tracker
#
# SCHEDULE_TRACKER_ENDPOINT and BIND_HOST are injected by supercronic from the
# container environment set in docker-compose.yml.

set -u

ZONES="l42.eu s.l42.eu lukeblaney.co.uk rowanblaney.co.uk tfluke.uk"
FREQUENCY=300           # seconds — must match crontab cadence (*/5)
JOB_NAME="soa-serial-in-sync"
SYSTEM="lucos_dns_secondary"
BIND_HOST="${BIND_HOST:-bind}"
PRIMARY_NS="${PRIMARY_NS:-dns.l42.eu}"

status="success"
all_lines=""

for zone in $ZONES; do
    # +tries=1 avoids retries so a dead server fails fast (max ~5s per query).
    # awk filters out dig's `;;`-prefixed error lines (e.g. "no servers could be
    # reached") so that only genuine SOA records contribute to the serial.
    local_serial=$(dig +short +timeout=5 +tries=1 SOA "$zone" @"$BIND_HOST" 2>/dev/null | awk '!/^;/ && NF==7 {print $3; exit}')
    primary_serial=$(dig +short +timeout=10 +tries=1 SOA "$zone" @"$PRIMARY_NS" 2>/dev/null | awk '!/^;/ && NF==7 {print $3; exit}')

    if [ -z "$primary_serial" ]; then
        status="error"
        zone_line="$zone: local=${local_serial:-MISSING} primary=UNREACHABLE"
    elif [ -z "$local_serial" ]; then
        status="error"
        zone_line="$zone: local=MISSING primary=$primary_serial"
    elif [ "$local_serial" -lt "$primary_serial" ] 2>/dev/null; then
        status="error"
        zone_line="$zone: local=$local_serial primary=$primary_serial (BEHIND)"
    else
        zone_line="$zone: local=$local_serial primary=$primary_serial"
    fi

    if [ -n "$all_lines" ]; then
        all_lines="$all_lines; $zone_line"
    else
        all_lines="$zone_line"
    fi
done

# Build JSON payload. Zone names, serials, and status strings are ASCII-only
# and contain no quotes or backslashes, so printf expansion is safe.
payload=$(printf '{"system":"%s","job_name":"%s","frequency":%d,"status":"%s","message":"%s"}' \
    "$SYSTEM" "$JOB_NAME" "$FREQUENCY" "$status" "$all_lines")

curl -sf -X POST \
    -H "Content-Type: application/json" \
    -H "User-Agent: $SYSTEM" \
    -d "$payload" \
    "$SCHEDULE_TRACKER_ENDPOINT" \
    || printf '[%s] Warning: failed to post to schedule_tracker\n' "$(date -u +%H:%M:%S)" >&2
