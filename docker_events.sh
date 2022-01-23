#!/bin/bash
# https://github.com/JulyIghor/DockerEvents

function printVersion {
echo -e "Docker Events v1.0\nhttps://github.com/JulyIghor/DockerEvents\n"
}

function printHelp {
printVersion
echo -e "Usage: `basename $0` [params]

TELEGRAM_API_TOKEN='..' - Telegram bot API key
TELEGRAM_GROUP_ID='..' - Telegram group id

FILTER_NAME='.*' - filter container name
FILTER_IMAGE='.*' - filter image name
FILTER_HEALTH='.*' - filter health status (default: ^((?!healthy).)*$)
FILTER_EXITCODE='.*' - filter exit code (default: ^[^0]$|.{2,})
FILTER_PROJECT='.*' - filter project name (default: .{1,})"
}

function printError {
    echo -e "Error: $@\n"
    printHelp
}

[ -z "${FILTER_TYPES}" ]    && FILTER_TYPES=('container')
[ -z "${FILTER_EVENTS}" ]   && FILTER_EVENTS=('start' 'die' 'health_status')
[ -z "${FILTER_NAME}" ]     && FILTER_NAME='.*'
[ -z "${FILTER_IMAGE}" ]    && FILTER_IMAGE='.*'
[ -z "${FILTER_HEALTH}" ]   && FILTER_HEALTH='^((?!healthy).)*$' # healthy, unhealthy
[ -z "${FILTER_EXITCODE}" ] && FILTER_EXITCODE='^[^0]$|.{2,}' # 0, ..
[ -z "${FILTER_EVENTS}" ]   && FILTER_PROJECT='.{1,}' # any not empty

[ -z "${HOST_NAME}" ]      && HOST_NAME=`cat /etc/hostname`
[ -z "${TELEGRAM_API_TOKEN}" ] && { printError "TELEGRAM_API_TOKEN is not defined"; exit 1; }
[ -z "${TELEGRAM_GROUP_ID}" ] && { printError "TELEGRAM_GROUP_ID is not defined"; exit 1; }
[ -z "${HOST_NAME}" ]      && { printError "HOST_NAME is not defined"; exit 1; }

[ -z "${DOCKER_SOCKET}" ]  && DOCKER_SOCKET='/var/run/docker.sock'

JQ_FORMAT='.status,.Action,.Actor.Attributes.name,.Actor.Attributes.image,.Actor.Attributes.exitCode,.time,.from,.Actor.Attributes["com.docker.compose.project"]'

function htmlEscape {
    local s
    s=${1//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//'"'/&quot;}
    printf -- %s "$s"
}

TITLE="Docker on <b>`htmlEscape ${HOST_NAME}`</b>"

function telegram_message {
MESSAGE="$@"

echo -e "${MESSAGE}"
curl -X POST -s \
     -H 'Content-Type: application/json' \
     -d '{"chat_id": "'${TELEGRAM_GROUP_ID}'", "text": "'"${MESSAGE}"'", "parse_mode": "HTML"}' \
     'https://api.telegram.org/bot'${TELEGRAM_API_TOKEN}'/sendMessage' > /dev/null
}

function docker_event {
    [[ ${1:0:1} != "{" ]] && return

    readarray -t PARAMS < <(echo -e "$@" | jq -r "${JQ_FORMAT}")
    if [ "${#PARAMS[@]}" -ne 8 ]; then
        return;
    fi

    CONTAINER_NAME="${PARAMS[2]}"
    CONTAINER_IMAGE="${PARAMS[3]}"
    EVENT_EXITCODE="${PARAMS[4]}"
    CONTAINER_FROM="${PARAMS[6]}" # unused
    COMPOSE_PROJECT="${PARAMS[7]}"

    [[ "${COMPOSE_PROJECT}" == "null" ]] && COMPOSE_PROJECT=''

    [[ "${CONTAINER_NAME}" =~ ${FILTER_NAME} ]] || return
    [[ "${CONTAINER_IMAGE}" =~ ${FILTER_IMAGE} ]] || return
    [[ "${COMPOSE_PROJECT}" =~ ${FILTER_PROJECT} ]] || return

    EVENT_TIME=`date -u +"%Y-%m-%d %H:%M:%S UTC" -d '@'${PARAMS[5]}`

    MESSAGE=''
    case "${PARAMS[1]}" in
      start)
MESSAGE='
Container <b>STARTED</b>
Name: <code>'"`htmlEscape ${CONTAINER_NAME}`"'</code>
Project: <code>'"`htmlEscape ${COMPOSE_PROJECT}`"'</code>
Image: <code>'"`htmlEscape ${CONTAINER_IMAGE}`</code>"
        ;;
      die)
        [[ "${EVENT_EXITCODE}" =~ ${FILTER_EXITCODE} ]] || return
        case "${EVENT_EXITCODE}" in
            132) EVENT_EXITCODE='SIGILL ('${EVENT_EXITCODE}')' ;;
            133) EVENT_EXITCODE='SIGTRAP ('${EVENT_EXITCODE}')' ;;
            136) EVENT_EXITCODE='SIGFPE ('${EVENT_EXITCODE}')' ;;
            138) EVENT_EXITCODE='SIGBUS ('${EVENT_EXITCODE}')' ;;
            139) EVENT_EXITCODE='SIGSEGV ('${EVENT_EXITCODE}')' ;;
            152) EVENT_EXITCODE='SIGXCPU ('${EVENT_EXITCODE}')' ;;
            158) EVENT_EXITCODE='SIGXCPU ('${EVENT_EXITCODE}')' ;;
            153) EVENT_EXITCODE='SIGXFSZ ('${EVENT_EXITCODE}')' ;;
            159) EVENT_EXITCODE='SIGXFSZ ('${EVENT_EXITCODE}')' ;;
            *) ;;
        esac
MESSAGE='
Container <b>STOPPED</b>
Name: <code>'"`htmlEscape ${CONTAINER_NAME}`"'</code>
Project: <code>'"`htmlEscape ${COMPOSE_PROJECT}`"'</code>
Image: <code>'"`htmlEscape ${CONTAINER_IMAGE}`"'</code>
Exit code: <b>'"`htmlEscape ${EVENT_EXITCODE}`"'</b>'
        ;;
      health_status:*)
        EVENT_STATUS="${PARAMS[0]:15}"
        [[ "${EVENT_STATUS}" =~ ${FILTER_HEALTH} ]] || return
MESSAGE='
Status <b>'"`htmlEscape ${EVENT_STATUS^^}`"'</b>
Name: <code>'"`htmlEscape ${CONTAINER_NAME}`"'</code>
Project: <code>'"`htmlEscape ${COMPOSE_PROJECT}`"'</code>
Image: <code>'"`htmlEscape ${CONTAINER_IMAGE}`</code>"
        ;;
      *)
        echo 'Unknown event action "'"${PARAMS[1]}"\"
        return
        ;;
    esac
    [ -z "${MESSAGE}" ] && return

    telegram_message "${TITLE}\n${MESSAGE}\n<code>${EVENT_TIME}</code>"
}

function array2json { printf '%s\n' "$@" | jq -Rc . | jq -sc .; }

function urlencode {
    old_lc_collate=$LC_COLLATE
    LC_COLLATE=C
    ARG="$@"
    local length="${#ARG}"
    for (( i = 0; i < length; i++ )); do
        local c="${ARG:$i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf '%s' "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
    LC_COLLATE=$old_lc_collate
}

FILTERS=$(urlencode "{\"type\":`array2json ${FILTER_TYPES[@]}`,\"event\":`array2json ${FILTER_EVENTS[@]}`}")
URL="http://docker/events?filters=${FILTERS}"

printVersion
echo -e 'Listening '"${DOCKER_SOCKET}"

curl -s --no-buffer -XGET --unix-socket "${DOCKER_SOCKET}" "${URL}" |
while read message; do docker_event ${message}; done;
