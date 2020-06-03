#!/usr/bin/env sh

snippet_list() {
    snippet_curl | yush_json | grep -E '/[0-9]+/id' | awk '{print $3}'
}

snippet_get() {
    if [ "$#" = "0" ]; then
        yush_warn "You have to specify a snippet ID"
    else
        snippet_curl "${1}/raw"
    fi
}

snippet_details() {
    _json=0
    while [ $# -gt 0 ]; do
        case "$1" in
            -j | --json)
                _json=1; shift;;

            -h | --help)
                usage "" 0;;

            --)
                shift; break;;
            -*)
                usage "Unknown option: $1 !";;
            *)
                break;;
        esac
    done

    if [ "$#" = "0" ]; then
        yush_warn "You have to specify a snippet ID"
    else
        if [ "$_json" = "1" ]; then
            snippet_curl "${1}"
        else
            snippet_curl "${1}" | yush_json
        fi
    fi
}

_snippet_value() {
    printf %s\\n "$1" | grep -E "^/${2} " | cut -d " " -f 3-
}

snippet_search() {
    _title=".*"
    _description=".*"
    _filename=".*"
    _visibility=".*"
    while [ $# -gt 0 ]; do
        case "$1" in
            -t | --title)
                _title=$2; shift 2;;
            --title=*)
                _title="${1#*=}"; shift 1;;

            -d | --description)
                _description=$2; shift 2;;
            --description=*)
                _description="${1#*=}"; shift 1;;

            -f | --filename)
                _filename=$2; shift 2;;
            --filename=*)
                _filename="${1#*=}"; shift 1;;

            -v | --visibility)
                _visibility=$2; shift 2;;
            --visibility=*)
                _visibility="${1#*=}"; shift 1;;

            -h | --help)
                usage "" 0;;

            --)
                shift; break;;
            -*)
                usage "Unknown option: $1 !";;
            *)
                break;;
        esac
    done

    for _s in $(snippet_list); do
        _json=$(snippet_details "$_s")
        if _snippet_value "$_json" "title" | grep -Eq "$_title" \
            && _snippet_value "$_json" "description" | grep -Eq "$_description" \
            && _snippet_value "$_json" "file_name" | grep -Eq "$_filename" \
            && _snippet_value "$_json" "visibility" | grep -Eq "$_visibility"; then
            printf %d\\n "$_s"
        fi
    done
}