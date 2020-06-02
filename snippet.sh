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
GITLAB_ROOT=${GITLAB_ROOT:-"https://gitlab.com/api/v4"}

# Token for accessing the API
GITLAB_TOKEN=${GITLAB_TOKEN:-}

# Project to access/modify snippets for
GITLAB_PROJECT=${GITLAB_PROJECT:-}


while [ $# -gt 0 ]; do
    case "$1" in
        -g | --gitlab)
            GITLAB_ROOT=$2; shift 2;;
        --gitlab=*)
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
    curl -sSL \
        --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
        "$@" \
        "${GITLAB_ROOT%/}/projects/${GITLAB_PROJECT}/snippets/${_path%/}"
}

json_generate() {
    _title=
    _description=
    _filename=
    _content=
    _visibility=
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

            -c | --content)
                _content=$2; shift 2;;
            --content=*)
                _content="${1#*=}"; shift 1;;

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
    _json=$(mktemp)
    printf \
        '{"title":"%s","description":"%s","file_name":"%s","content":"%s","visibility":"%s"}' \
        "$_title" "$_description" "$_filename" "$_content" "$_visibility" \
            > "$_json"
    printf %s\\n "$_json"
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
        callcurl "" \
            --header "Content-Type: application/json" \
            --request POST \
            -d @"$_json"
        rm -f "$_json"
        ;;
esac