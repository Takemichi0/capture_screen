#!/bin/bash

set -euo pipefail

readonly LABEL="com.user.screencapture"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly AGENT_DIR="${HOME}/Library/LaunchAgents"
readonly PLIST_PATH="${AGENT_DIR}/${LABEL}.plist"
readonly DEFAULT_INTERVAL_SECONDS=300
readonly INTERVAL_SECONDS="${CAPTURE_INTERVAL_SECONDS:-${DEFAULT_INTERVAL_SECONDS}}"
readonly DOMAIN="gui/$(id -u)"

validate_interval() {
	if [[ ! "${INTERVAL_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
		printf "CAPTURE_INTERVAL_SECONDS must be a positive integer.\n" >&2
		exit 1
	fi
}

create_plist() {
	/bin/mkdir -p "${AGENT_DIR}"
	/usr/bin/plutil -create xml1 "${PLIST_PATH}"
	/usr/bin/plutil -insert Label -string "${LABEL}" "${PLIST_PATH}"
	/usr/bin/plutil -insert ProgramArguments -array "${PLIST_PATH}"
	/usr/bin/plutil -insert ProgramArguments.0 -string "/bin/bash" "${PLIST_PATH}"
	/usr/bin/plutil -insert ProgramArguments.1 -string "${SCRIPT_DIR}/capture.sh" "${PLIST_PATH}"
	/usr/bin/plutil -insert StartInterval -integer "${INTERVAL_SECONDS}" "${PLIST_PATH}"
	/usr/bin/plutil -insert RunAtLoad -bool true "${PLIST_PATH}"
	/usr/bin/plutil -insert StandardOutPath -string "${SCRIPT_DIR}/launchagent_stdout.log" "${PLIST_PATH}"
	/usr/bin/plutil -insert StandardErrorPath -string "${SCRIPT_DIR}/launchagent_stderr.log" "${PLIST_PATH}"
	/usr/bin/plutil -insert WorkingDirectory -string "${SCRIPT_DIR}" "${PLIST_PATH}"
	/bin/chmod 600 "${PLIST_PATH}"
}

load_agent() {
	/bin/launchctl bootout "${DOMAIN}/${LABEL}" 2>/dev/null || true
	/bin/launchctl bootstrap "${DOMAIN}" "${PLIST_PATH}"
	/bin/launchctl enable "${DOMAIN}/${LABEL}"
	/bin/launchctl kickstart "${DOMAIN}/${LABEL}"
}

main() {
	validate_interval
	/bin/chmod +x "${SCRIPT_DIR}/capture.sh" "${SCRIPT_DIR}/install.sh" "${SCRIPT_DIR}/uninstall.sh"
	create_plist
	load_agent
	printf "Installed %s with a %s-second interval.\n" "${LABEL}" "${INTERVAL_SECONDS}"
	printf "Grant Screen Recording permission if macOS prompts for it.\n"
}

main "$@"
