#!/bin/bash

set -euo pipefail

readonly LABEL="com.user.screencapture"
readonly PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
readonly DOMAIN="gui/$(id -u)"

/bin/launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null || true
/bin/rm -f "${PLIST_PATH}"
printf "Uninstalled %s. Existing screenshots and logs were kept.\n" "${LABEL}"
