#!/usr/bin/env sh


_snippet_jsongen() {
    _fields=
    _title=
    _description=
    _filename=
    _content=
    _visibility=
    while [ $# -gt 0 ]; do
        case "$1" in
            -t | --title)
                _title=$2; _fields="t${_fields}"; shift 2;;
            --title=*)
                _title="${1#*=}"; _fields="t${_fields}"; shift 1;;

            -d | --description)
                _description=$2; _fields="d${_fields}"; shift 2;;
            --description=*)
                _description="${1#*=}"; _fields="d${_fields}"; shift 1;;

            -f | --filename)
                _filename=$2; _fields="f${_fields}"; shift 2;;
            --filename=*)
                _filename="${1#*=}"; _fields="f${_fields}"; shift 1;;

            -c | --content)
                _content=$2; _fields="c${_fields}"; shift 2;;
            --content=*)
                _content="${1#*=}"; _fields="c${_fields}"; shift 1;;

            --content-file)
                _content=$(cat "$2"); _fields="c${_fields}"; shift 2;;
            --content-file=*)
                _content=$(cat "${1#*=}"); _fields="c${_fields}"; shift 1;;

            -v | --visibility)
                _visibility=$2; _fields="v${_fields}"; shift 2;;
            --visibility=*)
                _visibility="${1#*=}"; _fields="v${_fields}"; shift 1;;

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

    # Converts line endings to \n in content, this is what the snippet API
    # wants.
    _content=$(printf %s\\n "$_content"|sed -e 's/"/\\"/g' -e 's/$/\\n/g'|tr -d '\n')
    # Create a temporary file to host "almost JSON" content and the final JSON
    # file. We do this because we need to get rid of the last , at the end of
    # the last line of the JSON that we output, as we can't control which
    # options were set from the outside.
    _fpath=$(mktemp)
    _jsonpath=$(mktemp)
    # Print fields that were set from the outside in turns to the temporary,
    # almost JSON, _fpath
    printf '{\n' > "$_fpath"
    printf %s\\n "$_fields" | grep -q t && printf '"title":"%s",\n' "$_title" >> "$_fpath"
    printf %s\\n "$_fields" | grep -q d && printf '"description":"%s",\n' "$_description" >> "$_fpath"
    printf %s\\n "$_fields" | grep -q f && printf '"file_name":"%s",\n' "$_filename" >> "$_fpath"
    printf %s\\n "$_fields" | grep -q c && printf '"content":"%s",\n' "$_content" >> "$_fpath"
    printf %s\\n "$_fields" | grep -q v && printf '"visibility":"%s",\n' "$_visibility" >> "$_fpath"
    # Remove last , from last line of _fpath to create beginning of real JSON
    # file at _jsonpath
    head -n -1 "$_fpath" > "$_jsonpath"
    tail -n 1 "$_fpath" | sed -E 's/,$//' >> "$_jsonpath"
    # Close the JSON file and remove the temporary _fpath. We are done!
    printf '}' >> "$_jsonpath"
    rm -f "$_fpath"
    printf %s\\n "$_jsonpath"
    yush_trace "Generated: $(cat "$_jsonpath")"
}


snippet_create() {
    _json=$(_snippet_jsongen "$@")
    res=$(snippet_curl "" \
            --header "Content-Type: application/json" \
            --request POST \
            -d @"$_json")
    if printf %s\\n "$res" | grep -qE '"error"\s*:\s*"'; then
        if printf %s\\n "$res" | yush_json | grep -q '/error_description'; then
            yush_error "$(printf %s\\n "$res" | yush_json | grep '/error_description' | cut -d " " -f 3-)"
        else
            yush_error "$(printf %s\\n "$res" | yush_json | grep '/error' | cut -d " " -f 3-)"
        fi
        exit 1
    else
        printf %s\\n "$res" | yush_json | grep -E "^/id " | awk '{print $3}'
    fi
    rm -f "$_json"
}

snippet_update() {
    _json=$(_snippet_jsongen "$@")
    if [ "$#" = "0" ]; then
        yush_warn "You have to specify a snippet ID"
    else
        res=$(snippet_curl "$(eval echo "\$$#")" \
                --header "Content-Type: application/json" \
                --request PUT \
                -d @"$_json")
        if printf %s\\n "$res" | grep -qE '"error"\s*:\s*"'; then
            if printf %s\\n "$res" | yush_json | grep -q '/error_description'; then
                yush_error "$(printf %s\\n "$res" | yush_json | grep '/error_description' | cut -d " " -f 3-)"
            else
                yush_error "$(printf %s\\n "$res" | yush_json | grep '/error' | cut -d " " -f 3-)"
            fi
            exit 1
        else
            printf %s\\n "$res" | yush_json | grep -E "^/id " | awk '{print $3}'
        fi
    fi
    rm -f "$_json"
}

snippet_delete() {
    if [ "$#" = "0" ]; then
        yush_warn "You have to specify a snippet ID"
    else
        snippet_curl "$1" --request "DELETE"
    fi
}