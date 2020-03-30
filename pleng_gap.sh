#!/usr/bin/env bash

set -e

dir="/pleng/gap2"
find_cmd="/usr/bin/find"
gzip_cmd="/usr/bin/gzip"
rm_cmd="/usr/bin/rm -rf"

usage(){

    echo "Usage: $0 [--restore|-r] {from date} {to date} | [--clean|-c] {c} {r}"
    echo ""
    echo "where:"
    echo "     --restore - accepts given date format as <YYYY-MM-DD> only."
    echo "     --clean   - accepts optional parameters: "
    echo "                 * {c} - compress files older than (default 7),"
    echo "                 * {r} - remove files older than (default 360)."
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
    local mtime="00:00:01"
    local ntime="23:59:59"

    [[ "${from}" && "${to}" ]] || {

        tPrint "Restore parameter requires date range in given format <YYYY-MM-DD> <YYYY-MM-DD>." "DEBUG"
        exit 1

    }

    check_date "${from}" && check_date "${to}"

    mapfile -t to_unzip < <($find_cmd "${dir}" -type f -name "*.gz" -newermt "${from} ${mtime}" ! -newermt "${to} ${ntime}" -print)

    (( "${#to_unzip[@]}" > 0 )) && {

	tPrint "I've found ${#to_unzip[@]} file(s) to restore. Processing..."
	for f in "${to_unzip[@]}"
	do
	    tPrint " - Restoring file ${f##*/}"
	    $gzip_cmd -d "${f}"
	done

    exit 0

    }

    tPrint "Nothing found to restore." && exit 0

}

clean_files(){

    local fcompres=${1:-7}
    local fdelete=${2:-360}

    mapfile -t to_archive < <($find_cmd "${dir}" -type f -name "*BUZ0P*" -not -name "*.gz" -mtime +"${fcompres}" -print)

    (( "${#to_archive[@]}" > 0 )) && {

        tPrint "I've found ${#to_archive[@]} file(s) to archive. Processing..."
        for f in "${to_archive[@]}"
        do
	    tPrint " - Archiving file ${f##*/}"
            $gzip_cmd "${f}"
        done

    } || tPrint "Nothing found to archive."

    mapfile -t to_remove < <($find_cmd "${dir}" -type f -name "*.gz" -mtime +"${fdelete}" -print)

    (( "${#to_remove[@]}" > 0 )) && {

	tPrint "I've found ${#to_remove[@]} file(s) to remove. Processing..."
        for f in "${to_remove[@]}"
        do
    	    tPrint " - Removing file ${f##*/}"
            $rm_cmd "${f}"
        done


    } || tPrint "Nothing found to remove."

    exit 0

}

[[ -d "${dir}" ]] || {

    tPrint "Folder ${dir} does not exist or user $(whoami) cannot access it. Leaving the script!" "FATAL"
    exit 1
}

[[ ${1} == "--restore" || ${1} == "-r" ]] && {

        from="${2}"
        to="${3}"
        shift

        restore_files "${1}" "${2}"

}

[[ ${1} == "--clean" || ${1} == "-c" ]] && {

        fcompres="${2}"
        fdelete="${3}"
        shift

        clean_files "${1}" "${2}"

}

tPrint "Provided argument ${1} is not valid!" "FATAL" && usage
