#!/usr/bin/env bash

set -e

usage(){

    echo "Usage: $0 [FILE] [EMAIL ADDRESS]"
    echo ""
    exit 1

}

(( ${#} > 0 )) || {

    echo "No arguments supplied!"
    usage
}

tPrint() {

        printf "%s %s %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "${2:-INFO}" "${1}"

}

check_size(){

	local du_cmd="/usr/bin/du -k"
	local size=$(${du_cmd} "${1}" |cut -f1)

	echo "${size}"
}

SendEmail(){

	local smtp="smtp=XXX"
	local from="me@company.com"
	local sub="[FILE2EMAIL] Shared file: $(basename ${1})"
	local att="${1}"
	local to="${2:-lukasz.kisiel@company.com}"
	local name="${to%%.*}"

	tPrint "Sending file ${att} to ${to} (...)"
	echo -e "Hello ${name^},\nShared file: $(basename ${1}) taken from $(hostname)\n\nMessage generated automatically." | $(command -v mailx) -a "${att}" -S "${smtp}" -r "${from}" -s "${sub}" "${to}"

}

[[ -e "${1}" ]] || {
	tPrint "Provided filename does not exist. Leaving the script."
	exit 1
}

(( "$(check_size ${1})" < 25000 )) || {
	tPrint "File is to large! Try to zip it!"
	exit 0
}

SendEmail "${1}" "${2}" && tPrint "DONE"
