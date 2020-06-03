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