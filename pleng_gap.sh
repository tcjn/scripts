#!/usr/bin/env bash

set -e

dir="/pleng/gap"
archive="Archive"
find_cmd="/usr/bin/find"
gzip_cmd="/usr/bin/gzip"
rm_cmd="/usr/bin/rm -rf"
mk_cmd="/usr/bin/mkdir -p"
mv_cmd="/usr/bin/mv"
du_cmd="/usr/bin/du -sh"

usage(){

    echo "Usage: $0 [--restore|-r] {from date} {to date} | [--clean|-c] {c} {r}"
    echo ""
    echo "where:"
    echo "     --restore - requires two date args in given format <YYYY-MM-DD> <YYYY-MM-DD>"
    echo "     --clean   - accepts optional parameters: "
    echo "                 * {c} - compress files older than (default 7) days,"
    echo "                 * {r} - remove files older than (default 370) days."
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

check_date(){

    local d="${1}"

    [[ "${d}" =~ ^[0-9]{4}\-[0-9]{2}\-[0-9]{2}$ ]] || {

        tPrint "Wrong date format! Accepted format <YYYY-MM-DD>" "DEBUG"
        exit 1

    }

    return 0

}

restore_files(){

    local from=${1}
    local to=${2}
    local range=${from}

    [[ "${from}" && "${to}" ]] || {

        tPrint "Restore parameter requires two dates in given format <YYYY-MM-DD> <YYYY-MM-DD>"
        exit 1

    }

    check_date "${from}" && check_date "${to}"

    tPrint "Looking for files to restore between ${from} and ${to} (...)"

    while [[ "${range}" < "${to}" || "${range}" == "${to}" ]]
    do
        mapfile -t -O "${#to_unzip[@]}" to_unzip < <($find_cmd "${dir}" -type f -name "*${range//-/}.gz" -print)
        range=$(date -I -d "$range + 1 day")
    done

    (( "${#to_unzip[@]}" > 0 )) && {

        tPrint "I've found ${#to_unzip[@]} file(s) to restore. Processing..."
        for f in "${to_unzip[@]}"
        do
            tPrint " - Restoring file ${f##*/}"
            ${gzip_cmd} -d "${f}" && ${mv_cmd} "${f%.*}" "${dir}/"
        done

    tPrint "--------------------------------------------------------"
    tPrint "Restore completed with status OK. Restored ${#to_unzip[@]} file(s)."
    tPrint "--------------------------------------------------------"
    exit 0

    }

    tPrint "Nothing found to restore." && exit 0

}

clean_files(){

    local fcompres=${1:-7}
    local fdelete=${2:-370}

    (( "${fdelete}" > "${fcompres}" )) || {
        tPrint "Parameter {c} cannot be greater or equal to {r}" "DEBUG"
        exit 1
    }

    (( "${fcompres}" == 1 )) && fcompres="-1" # Start compression from today.

    mapfile -t to_archive < <($find_cmd "${dir}" -type f -name "*BUZ0P*" -not -name "*.gz" -mtime +"${fcompres}" -print)

    (( "${#to_archive[@]}" > 0 )) && {

        tPrint "I've found ${#to_archive[@]} file(s) to archive. Processing..."
        for f in "${to_archive[@]}"
        do
            tPrint " - Archiving file ${f##*/}"
            ${gzip_cmd} "${f}" && ${mv_cmd} "${f}.gz" "${dir}/${archive}/"
        done

    } || tPrint "Nothing found to archive."

    mapfile -t to_remove < <($find_cmd "${dir}" -type f -name "*.gz" -mtime +"${fdelete}" -print)

    (( "${#to_remove[@]}" > 0 )) && {

        tPrint "I've found ${#to_remove[@]} file(s) to remove. Processing..."
        for f in "${to_remove[@]}"
        do
            tPrint " - Removing file ${f##*/}"
            ${rm_cmd} "${f}"
        done


    } || tPrint "Nothing found to remove."


    tPrint "Cleanup completed with status OK. Archieved: ${#to_archive[@]} file(s). Removed: ${#to_remove[@]} file(s)."

    exit 0

}

# Main

[[ -d "${dir}" ]] || {

    tPrint "Folder ${dir} does not exist. Leaving the script!" "FATAL"
    exit 1
}

[[ -w "${dir}" ]] || {

    tPrint "Folder ${dir} is not writable by user $(whoami). Leaving the script!" "FATAL"
    exit 1
}

[[ -d "${dir}/${archive}" ]] || {

    ${mk_cmd} "${dir}/${archive}"
    (( "${?}" == "0" )) && tPrint "Folder ${archive} sucessfully created."

}

[[ ${1} == "--restore" || ${1} == "-r" ]] && {

        from="${2}"
        to="${3}"
        shift

        tPrint "Starting script in RESTORE mode."
        tPrint "Current usage of ${dir}: $(${du_cmd} ${dir} |cut -f1)"
        restore_files "${1}" "${2}"

}

[[ ${1} == "--clean" || ${1} == "-c" ]] && {

        fcompres="${2}"
        fdelete="${3}"
        shift

        tPrint "Starting script in CLEAN mode."
        tPrint "Current usage of ${dir}: $(${du_cmd} ${dir} |cut -f1)"

        clean_files "${1}" "${2}"

}

tPrint "Provided argument ${1} is not valid!" "FATAL" && usage
