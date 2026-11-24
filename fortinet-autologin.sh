#!/bin/bash
# Keeps this Mac logged in to the Bozok University FortiGate captive portal
# (https://fortinet.bozok.edu.tr:1003) so ZeroTier stays reachable.
#
# Run every minute by launchd. If the internet works, it does nothing
# (the probe itself also counts as traffic, which prevents idle timeouts).
# If the FortiGate intercepts traffic, it follows the redirect to the
# fgtauth page and submits it:
#   - disclaimer page  -> POST answer=1 (accept)
#   - username/password -> uses Keychain item "fortinet-portal" if present
#
# Usage: fortinet-autologin.sh [--dry-run]

PROBE_URL="http://captive.apple.com/hotspot-detect.html"
LOG="/var/log/fortinet-autologin.log"
[ -w "$(dirname "$LOG")" ] || LOG="$HOME/Library/Logs/fortinet-autologin.log"
DRY_RUN=0; [ "$1" = "--dry-run" ] && DRY_RUN=1

log() { echo "$(date '+%F %T') $*" | tee -a "$LOG"; }
CURL=(curl -s -m 10 --noproxy '*')

# 1. Are we online?
probe=$("${CURL[@]}" -D - "$PROBE_URL")
if [[ $probe == *"<TITLE>Success</TITLE>"* ]]; then
    [ $DRY_RUN = 1 ] && log "online, nothing to do"
    exit 0
fi
[ -z "$probe" ] && { log "no network response (link down?)"; exit 1; }

# 2. Find the FortiGate auth URL (Location header or JS redirect in body).
auth_url=$(grep -oE "https?://[^\"' <>]*:1003/fgtauth\?[0-9A-Za-z]+" <<<"$probe" | head -1)
if [ -z "$auth_url" ]; then
    log "offline but no fgtauth redirect found; response head:"
    head -c 500 <<<"$probe" >>"$LOG"; echo >>"$LOG"
    exit 1
fi
log "portal detected: $auth_url"

# 3. Fetch the auth page and read its form.
page=$("${CURL[@]}" "$auth_url")
field() { grep -oE "name=\"$1\"[^>]*value=\"[^\"]*\"" <<<"$page" | head -1 | sed -E 's/.*value="([^"]*)"/\1/'; }
magic=$(field magic)
redir=$(field 4Tredir)
base=$(grep -oE '^https?://[^/]+' <<<"$auth_url")
[ -z "$magic" ] && magic=$(grep -oE 'fgtauth\?[0-9A-Za-z]+' <<<"$auth_url" | cut -d'?' -f2)

args=(--data-urlencode "4Tredir=${redir:-$PROBE_URL}" --data-urlencode "magic=$magic")
if grep -q 'name="username"' <<<"$page"; then
    user=$(security find-generic-password -s fortinet-portal 2>/dev/null | sed -nE 's/.*"acct"<blob>="([^"]*)".*/\1/p')
    pass=$(security find-generic-password -s fortinet-portal -w 2>/dev/null)
    if [ -z "$user" ]; then
        log "portal asks for username/password but Keychain item 'fortinet-portal' is missing"
        exit 1
    fi
    args+=(--data-urlencode "username=$user" --data-urlencode "password=$pass")
    kind="credentials"
else
    args+=(--data-urlencode "answer=1")
    kind="disclaimer accept"
fi

if [ $DRY_RUN = 1 ]; then
    log "dry run: would POST ($kind) to $base/ with magic=$magic"
    exit 0
fi

# 4. Submit and verify.
"${CURL[@]}" -o /dev/null "${args[@]}" "$base/"
sleep 2
if [[ $("${CURL[@]}" "$PROBE_URL") == *Success* ]]; then
    log "logged in ($kind)"
else
    log "login attempt ($kind) failed"
    exit 1
fi
