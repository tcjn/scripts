#!/usr/bin/env bash

set -e

dir="/var/lib/docker/containers"
find_cmd="/usr/bin/find"
gzip_cmd="/usr/bin/gzip"
truncate_cmd="/usr/bin/truncate -s 0"

tPrint() {
    printf "%s %s %s\n" "$(date +%Y-%m-%dT%H:%M:%S%z)" "${2:-INFO}" "${1}"
}

send_email() {

        local subject="${1}"
        local body="${2}"
        local mail_cmd="/usr/bin/mailx -s"

        ${mail_cmd} "${subject}" -S smtp=smtp.oneadr.net -S from="dlpl-FRC-IT-DevOps@nordea.com" dlcomTOSITFRC@nordea.com  <<< "
Hello Team,

Please be informed that I have cleand up following files on ${HOSTNAME}:

"${body}"

Message generated automatically."

}

check_size(){

        local du_cmd="/usr/bin/du -k"
        local size=$(${du_cmd} "${1}" |cut -f1)

        echo "${size}"
}
clean_up(){


    mapfile -t to_check < <($find_cmd "${dir}" -type f -name "*-json.log" -size +1024M -print)

    (( "${#to_check[@]}" > 0 )) && {

        tPrint "I've found ${#to_check[@]} log file(s) to clean. Processing..."
        for f in "${to_check[@]}"
        do
                tPrint " - Cleaning file ${f##*/} with size $(check_size ${f}) MB."
                $truncate_cmd "${f}"
        done

        send_email "[DOCKER Logs cleaner]" "$(printf '%s\n' ${to_check[@]})"

    } || tPrint "Nothing found!"

    exit 0
}

[[ -d "${dir}" ]] && [[ -w "${dir}" ]] || {

    tPrint "Folder ${dir} does not exist or user $(whoami) cannot access it. Leaving the script!" "FATAL"
    exit 1
}

clean_up
