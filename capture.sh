#!/bin/bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OUTPUT_ROOT="${CAPTURE_OUTPUT_DIR:-${SCRIPT_DIR}}"
readonly LOG_FILE="${OUTPUT_ROOT}/capture.log"
readonly PAUSE_FILE="${OUTPUT_ROOT}/.capture-paused"

umask 077

log_message() {
	local level="$1"
	local message="$2"
	local timestamp
	timestamp=$(date "+%Y-%m-%d %H:%M:%S")
	printf "[%s] [%s] %s\n" "${timestamp}" "${level}" "${message}" >> "${LOG_FILE}"
}

notify_error() {
	local message="$1"
	/usr/bin/osascript -e "display notification \"${message}\" with title \"Screenshot capture error\"" 2>/dev/null || true
}

is_password_related_app_running() {
	local password_related_apps=(
		"1Password"
		"Bitwarden"
		"Keeper"
		"LastPass"
		"Keychain Access"
		"Notes"
	)
	local app

	for app in "${password_related_apps[@]}"; do
		if /usr/bin/pgrep -x "${app}" > /dev/null 2>&1; then
			log_message "INFO" "Capture skipped because password-related app ${app} is running"
			return 0
		fi
	done

	return 1
}

is_screen_locked() {
	/usr/sbin/ioreg -n Root -d1 2>/dev/null | /usr/bin/grep -q '"CGSSessionScreenIsLocked"=Yes\|"CGSSessionScreenIsLocked" = Yes'
}

is_display_asleep() {
	local power_state
	power_state=$(/usr/sbin/ioreg -n IODisplayWrangler 2>/dev/null | /usr/bin/grep -i "currentpowerstate" | /usr/bin/grep -oE "[0-9]+$" || true)

	if [[ -z "${power_state}" ]]; then
		log_message "WARN" "Display power state could not be determined; capture will continue"
		return 1
	fi

	[[ "${power_state}" -lt 4 ]]
}

capture_screen() {
	local date_folder
	local output_dir
	local output_file
	local timestamp
	local file_size

	if [[ -e "${PAUSE_FILE}" ]]; then
		log_message "INFO" "Capture skipped because capture is paused"
		return 0
	fi

	if is_password_related_app_running; then
		return 0
	fi

	if is_screen_locked; then
		log_message "INFO" "Capture skipped because the screen is locked"
		return 0
	fi

	if is_display_asleep; then
		log_message "INFO" "Capture skipped because the display is asleep"
		return 0
	fi

	date_folder=$(date "+%Y-%m-%d")
	output_dir="${OUTPUT_ROOT}/${date_folder}"
	if ! /bin/mkdir -p "${output_dir}"; then
		log_message "ERROR" "Could not create the output directory"
		notify_error "Could not create the output directory"
		return 1
	fi
	/bin/chmod 700 "${output_dir}"

	timestamp=$(date "+%Y-%m-%d_%H-%M-%S")
	output_file="${output_dir}/${timestamp}.png"

	if ! /usr/sbin/screencapture -x -C -m -t png "${output_file}"; then
		log_message "ERROR" "The screencapture command failed"
		notify_error "Screenshot capture failed"
		return 1
	fi

	if [[ ! -s "${output_file}" ]]; then
		log_message "ERROR" "The screenshot file was not created"
		notify_error "Screenshot file creation failed"
		return 1
	fi

	file_size=$(/usr/bin/stat -f%z "${output_file}")
	log_message "INFO" "Screenshot saved (${file_size} bytes)"
}

pause_capture() {
	/bin/mkdir -p "${OUTPUT_ROOT}"
	: > "${PAUSE_FILE}"
	printf "Capture paused.\n"
}

resume_capture() {
	/bin/rm -f "${PAUSE_FILE}"
	printf "Capture resumed.\n"
}

show_status() {
	if [[ -e "${PAUSE_FILE}" ]]; then
		printf "Capture is paused.\n"
	else
		printf "Capture is enabled.\n"
	fi
}

main() {
	local command="${1:-capture}"

	case "${command}" in
		capture)
			capture_screen
			;;
		pause)
			pause_capture
			;;
		resume)
			resume_capture
			;;
		status)
			show_status
			;;
		*)
			printf "Usage: %s [capture|pause|resume|status]\n" "$0" >&2
			return 2
			;;
	esac
}

main "$@"
