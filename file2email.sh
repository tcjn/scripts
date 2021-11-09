#!/usr/bin/env bash

set -e

usage(){

    echo "Usage: $0 <file> <user@email.com>"
    echo ""
    exit 1

}

(( "${#}" > 0 )) || {

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

send_mail(){

	local from="me@company.com"
	local sub="File share robot"
	local att="${1}"
	local to="${2:-lukasz.kisiel@company.com}"
	local name="${to%%.*}"

	tPrint "Sending file ${att} to ${to} (...)"
	echo -e "Hello ${name^},\nShared file: $(basename ${1}) taken from $(hostname)\n\nMessage generated automatically." | $(command -v mailx) -a "${att}" -r "${from}" -s "${sub}" "${to}"

}

[[ -e "${1}" ]] || {
	tPrint "Provided filename does not exist. Leaving the script."
	exit 1
}

(( "$(check_size ${1})" < 25000 )) || {
	tPrint "File is to large!"
	exit 0
}

send_email "${1}" "${2}" && tPrint "DONE"
