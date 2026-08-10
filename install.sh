#!/bin/bash

set -euo pipefail

readonly LABEL="com.user.screencapture"
readonly HELPER_BUNDLE_ID="com.user.screencapture.helper"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly AGENT_DIR="${HOME}/Library/LaunchAgents"
readonly PLIST_PATH="${AGENT_DIR}/${LABEL}.plist"
readonly HELPER_SOURCE="${SCRIPT_DIR}/ScreenshotCaptureAgent.swift"
readonly HELPER_APP="${SCRIPT_DIR}/ScreenshotCaptureAgent.app"
readonly HELPER_EXECUTABLE="${HELPER_APP}/Contents/MacOS/ScreenshotCaptureAgent"
readonly DEFAULT_INTERVAL_SECONDS=300
readonly INTERVAL_SECONDS="${CAPTURE_INTERVAL_SECONDS:-${DEFAULT_INTERVAL_SECONDS}}"
readonly DOMAIN="gui/$(id -u)"

validate_interval() {
	if [[ ! "${INTERVAL_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
		printf "CAPTURE_INTERVAL_SECONDS must be a positive integer.\n" >&2
		exit 1
	fi
}

build_helper_app() {
	local info_plist="${HELPER_APP}/Contents/Info.plist"

	if [[ -x "${HELPER_EXECUTABLE}" && -f "${info_plist}" && "${HELPER_EXECUTABLE}" -nt "${HELPER_SOURCE}" ]]; then
		return 0
	fi

	if ! /usr/bin/xcrun --find swiftc > /dev/null 2>&1; then
		printf "Xcode Command Line Tools with the Swift compiler are required.\n" >&2
		printf "Install them with: xcode-select --install\n" >&2
		exit 1
	fi

	/bin/rm -rf "${HELPER_APP}"
	/bin/mkdir -p "${HELPER_APP}/Contents/MacOS"
	/usr/bin/xcrun swiftc "${HELPER_SOURCE}" -o "${HELPER_EXECUTABLE}"

	/usr/bin/plutil -create xml1 "${info_plist}"
	/usr/bin/plutil -insert CFBundleDevelopmentRegion -string "en" "${info_plist}"
	/usr/bin/plutil -insert CFBundleDisplayName -string "Screenshot Capture Agent" "${info_plist}"
	/usr/bin/plutil -insert CFBundleExecutable -string "ScreenshotCaptureAgent" "${info_plist}"
	/usr/bin/plutil -insert CFBundleIdentifier -string "${HELPER_BUNDLE_ID}" "${info_plist}"
	/usr/bin/plutil -insert CFBundleInfoDictionaryVersion -string "6.0" "${info_plist}"
	/usr/bin/plutil -insert CFBundleName -string "Screenshot Capture Agent" "${info_plist}"
	/usr/bin/plutil -insert CFBundlePackageType -string "APPL" "${info_plist}"
	/usr/bin/plutil -insert CFBundleShortVersionString -string "1.0" "${info_plist}"
	/usr/bin/plutil -insert CFBundleVersion -string "1" "${info_plist}"
	/usr/bin/plutil -insert LSBackgroundOnly -bool true "${info_plist}"

	/usr/bin/codesign --force --sign - --identifier "${HELPER_BUNDLE_ID}" "${HELPER_APP}"
}

create_plist() {
	/bin/mkdir -p "${AGENT_DIR}"
	/usr/bin/plutil -create xml1 "${PLIST_PATH}"
	/usr/bin/plutil -insert Label -string "${LABEL}" "${PLIST_PATH}"
	/usr/bin/plutil -insert ProgramArguments -array "${PLIST_PATH}"
	/usr/bin/plutil -insert ProgramArguments.0 -string "${HELPER_EXECUTABLE}" "${PLIST_PATH}"
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
	build_helper_app
	create_plist
	load_agent
	printf "Installed %s with a %s-second interval.\n" "${LABEL}" "${INTERVAL_SECONDS}"
	printf "Grant Screen Recording permission to ScreenshotCaptureAgent if macOS prompts for it.\n"
	printf "The next scheduled run will use the new permission; reinstalling is not required.\n"
}

main "$@"
