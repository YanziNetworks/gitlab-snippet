#!/usr/bin/env sh


# Find yu.sh and load modules. We support several locations to ease
# installation.
SCRIPT_DIR=$( cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P )
### AMLG_START
LIB_DIR=
for _lib in ../lib lib libexec; do
    [ -z "$LIB_DIR" ] && [ -d "$SCRIPT_DIR/$_lib" ] && LIB_DIR="$SCRIPT_DIR/$_lib"
done
[ -z "$LIB_DIR" ] && echo "Cannot find library directory!" >&2 && exit 1
YUSH_DIR="$LIB_DIR/yu.sh"
! [ -d "$YUSH_DIR" ] && echo "canno find yu.sh directory!" >&2 && exit 1
### AMLG_END

### AMLG_START ./lib/yu.sh/log.sh ./lib/yu.sh/file.sh
# shellcheck source=./lib/yu.sh/log.sh disable=SC1091
. "$YUSH_DIR/log.sh"
# shellcheck source=./lib/yu.sh/json.sh disable=SC1091
. "$YUSH_DIR/json.sh"
### AMLG_END

# Shell sanity
set -eu

# Print usage on stderr and exit
usage() {
    [ -n "$1" ] && echo "$1" >&2
    exitcode="${2:-1}"
    cat << USAGE >&2
    Yet to be documented
USAGE
    exit "$exitcode"
}

# Root of the gitlab API endpoint
GITLAB_HOST=${GITLAB_HOST:-gitlab.com}
GITLAB_ROOT=${GITLAB_ROOT:-}

# Token for accessing the API
GITLAB_TOKEN=${GITLAB_TOKEN:-}

# Project to access/modify snippets for
GITLAB_PROJECT=${GITLAB_PROJECT:-}


while [ $# -gt 0 ]; do
    case "$1" in
        -g | --gitlab)
            GITLAB_HOST=$2; shift 2;;
        --gitlab=*)
            GITLAB_HOST="${1#*=}"; shift 1;;

        -r | --root)
            GITLAB_ROOT=$2; shift 2;;
        --root=*)
            GITLAB_ROOT="${1#*=}"; shift 1;;

        -p | --project)
            GITLAB_PROJECT=$2; shift 2;;
        --project=*)
            GITLAB_PROJECT="${1#*=}"; shift 1;;

        -t | --token)
            GITLAB_TOKEN=$2; shift 2;;
        --token=*)
            GITLAB_TOKEN="${1#*=}"; shift 1;;

        -v | --verbose)
            # shellcheck disable=SC2034
            YUSH_LOG_LEVEL=$2; shift 2;;
        --verbose=*)
            # shellcheck disable=SC2034
            YUSH_LOG_LEVEL="${1#*=}"; shift 1;;

        --non-interactive | --no-colour | --no-color)
            # shellcheck disable=SC2034
            YUSH_LOG_COLOUR=0; shift 1;;

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

[ -z "$GITLAB_ROOT" ] && GITLAB_ROOT="https://${GITLAB_HOST}/api/v4"

if [ "$#" = "0" ]; then
    cmd=list
else
    cmd=$(printf %s\\n "$1" | tr '[:upper:]' '[:lower:]')
    shift
fi

# XX: Implement URL encoding of project and automatic transformation when
# project is not ID but path.

callcurl() {
    _path=
    if [ "$#" -gt "0" ]; then
        _path=${1:-}
        shift
    fi
    yush_debug "Calling ${GITLAB_ROOT%/}/projects/${GITLAB_PROJECT}/snippets/${_path%/}"
    curl -sSL \
        --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        "$@" \
        "${GITLAB_ROOT%/}/projects/${GITLAB_PROJECT}/snippets/${_path%/}"
}

json_generate() {
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
    _fpath=$(mktemp)
    _jsonpath=$(mktemp)
    # Print fields that were set in turns to the temporary _fpath
    printf '{\n' > $_fpath
    printf %s\\n "$_fields" | grep -q t && printf '"title":"%s",\n' "$_title" >> $_fpath
    printf %s\\n "$_fields" | grep -q d && printf '"description":"%s",\n' "$_description" >> $_fpath
    printf %s\\n "$_fields" | grep -q f && printf '"file_name":"%s",\n' "$_filename" >> $_fpath
    printf %s\\n "$_fields" | grep -q c && printf '"content":"%s",\n' "$_content" >> $_fpath
    printf %s\\n "$_fields" | grep -q v && printf '"visibility":"%s",\n' "$_visibility" >> $_fpath
    # Remove last , from last line of _fpath to create beginning of real JSON
    # file at _jsonpath
    head -n -1 $_fpath > $_jsonpath
    tail -n 1 $_fpath | sed -E 's/,$//' >> $_jsonpath
    # Close the JSON file and remove the temporary _fpath. We are done!
    printf '}' >> $_jsonpath
    rm -f "$_fpath"
    printf %s\\n "$_jsonpath"
}

case "$cmd" in
    list)
        callcurl | yush_json | grep -E '/[0-9]+/id' | awk '{print $3}';;
    get|read)
        callcurl "${1}/raw";;
    details)
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
        if [ "$_json" = "1" ]; then
            callcurl "${1}"
        else
            callcurl "${1}" | yush_json
        fi
        ;;
    create|add)
        _json=$(json_generate "$@")
        res=$(callcurl "" \
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
        ;;
    update|change)
        _json=$(json_generate "$@")
        if [ "$#" = "0" ]; then
            yush_warn "You have to specify a snippet ID"
        else
            res=$(callcurl "$(eval echo "\$$#")" \
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
        ;;
esac