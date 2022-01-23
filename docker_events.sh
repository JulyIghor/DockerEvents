#!/bin/bash
# https://github.com/JulyIghor/DockerEvents

shopt -s extglob
set +H

function printVersion {
echo -e 'Docker Events v1.0
https://github.com/JulyIghor/DockerEvents'
}

function printHelp {
printVersion
echo -e "Usage: `basename $0` [params]

TELEGRAM_API_TOKEN='..' - Telegram bot API key
TELEGRAM_GROUP_ID='..' - Telegram group id

FILTER_NAME='+(*)' - filter container name
FILTER_IMAGE='+(*)' - filter image name
FILTER_HEALTH='+(*)' - filter health status (default: !(healthy))
FILTER_EXITCODE='+(*)' - filter exit code (default: !(0|130))
FILTER_RESTART_POLICY='+(*)' - filter restart policy (default: !(no))

HOST_NAME='..' - define a host name for notifications, by default it reads the /etc/hostname file
"
}

function printError {
    echo -e "Error: $@\n"
    printHelp
}

function printConfig {
echo -e "
HOST_NAME: ${HOST_NAME}
DOCKER_SOCKET: ${DOCKER_SOCKET}

FILTER_TYPES: ${FILTER_TYPES[@]}
FILTER_EVENTS: ${FILTER_EVENTS[@]}
FILTER_NAME: ${FILTER_NAME}
FILTER_IMAGE: ${FILTER_IMAGE}
FILTER_HEALTH: ${FILTER_HEALTH}
FILTER_EXITCODE: ${FILTER_EXITCODE}
FILTER_RESTART_POLICY: ${FILTER_RESTART_POLICY}
"
}

[ -z "${FILTER_TYPES}" ]          && FILTER_TYPES=('container')
[ -z "${FILTER_EVENTS}" ]         && FILTER_EVENTS=('start' 'die' 'health_status')
[ -z "${FILTER_NAME}" ]           && FILTER_NAME='+(*)'
[ -z "${FILTER_IMAGE}" ]          && FILTER_IMAGE='+(*)'
[ -z "${FILTER_HEALTH}" ]         && FILTER_HEALTH='!(healthy)' # healthy, unhealthy
[ -z "${FILTER_EXITCODE}" ]       && FILTER_EXITCODE='!(0|130)' # 0, ..
[ -z "${FILTER_RESTART_POLICY}" ] && FILTER_RESTART_POLICY='!(no)' # exclude 'no'

[ -z "${HOST_NAME}" ]             && HOST_NAME=`cat /etc/hostname`
[ -z "${TELEGRAM_API_TOKEN}" ]    && { printError "TELEGRAM_API_TOKEN is not defined"; exit 1; }
[ -z "${TELEGRAM_GROUP_ID}" ]     && { printError "TELEGRAM_GROUP_ID is not defined"; exit 1; }
[ -z "${HOST_NAME}" ]             && { printError "HOST_NAME is not defined"; exit 1; }

[ -z "${DOCKER_SOCKET}" ]         && DOCKER_SOCKET='/var/run/docker.sock'

JQ_FORMAT_EVENT='.status,.Action,.Actor.Attributes.name,.Actor.Attributes.image,.Actor.Attributes.exitCode,.time,.from,.id'
JQ_FORMAT_INSPECT='[.][0]|.State.Error,.RestartCount,.HostConfig.RestartPolicy.Name'

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
    readarray -t PARAMS < <(echo -e "$@" | jq -r "${JQ_FORMAT_EVENT}")
    if [ "${#PARAMS[@]}" -ne 8 ]; then
        echo params missmatch "${#PARAMS[@]}", expected 8
        return;
    fi
    CONTAINER_NAME="${PARAMS[2]}"
    CONTAINER_IMAGE="${PARAMS[3]}"
    EVENT_EXITCODE="${PARAMS[4]}"
    CONTAINER_FROM="${PARAMS[6]}" # unused
    CONTAINER_ID="${PARAMS[7]}"

    [[ "${CONTAINER_NAME}" == ${FILTER_NAME} ]] || { echo "skipping ${CONTAINER_NAME} since FILTER_NAME not match filter ${FILTER_NAME}"; return; }
    [[ "${CONTAINER_IMAGE}" == ${FILTER_IMAGE} ]] || { echo "skipping ${CONTAINER_NAME} since CONTAINER_IMAGE (${CONTAINER_IMAGE}) not match filter ${FILTER_IMAGE}"; return; }
    readarray -t INSPECT < <(curl -s -XGET --unix-socket "${DOCKER_SOCKET}" "http://docker/containers/${CONTAINER_ID}/json" | jq -r "${JQ_FORMAT_INSPECT}")
    if [ "${#INSPECT[@]}" -eq 3 ]; then
        STATE_ERROR="${INSPECT[0]}"
        RESTART_COUNT="${INSPECT[1]}"
        RESTART_POLICY="${INSPECT[2]}"

        [[ "${RESTART_COUNT}" == +(0|null) ]] && RESTART_COUNT=''
        [[ "${RESTART_POLICY}" == +(null) ]] && RESTART_POLICY=''
        [[ "${STATE_ERROR}" == +(null) ]] && STATE_ERROR=''
    else
        STATE_ERROR=''
        RESTART_COUNT=''
        RESTART_POLICY=''
    fi
    [[ "${RESTART_POLICY}" == ${FILTER_RESTART_POLICY} ]] || { echo "skipping ${CONTAINER_NAME} since FILTER_RESTART_POLICY (${RESTART_POLICY}) not match filter ${FILTER_RESTART_POLICY}"; return; }

    EVENT_TIME=`date -u +"%Y-%m-%d %H:%M:%S UTC" -d '@'${PARAMS[5]}`

    MESSAGE=''
    case "${PARAMS[1]}" in
      start)
MESSAGE='
Container <b>STARTED</b>
'
        ;;
      die)
        [[ "${EVENT_EXITCODE}" == ${FILTER_EXITCODE} ]] || { echo "skipping ${CONTAINER_NAME} since EVENT_EXITCODE (${EVENT_EXITCODE}) not match filter ${FILTER_EXITCODE}"; return; }
        case "${EVENT_EXITCODE}" in
            132) EVENT_EXITCODE='SIGILL ('${EVENT_EXITCODE}')' ;;
            133) EVENT_EXITCODE='SIGTRAP ('${EVENT_EXITCODE}')' ;;
            134) EVENT_EXITCODE='SIGABRT ('${EVENT_EXITCODE}')' ;;
            136) EVENT_EXITCODE='SIGFPE ('${EVENT_EXITCODE}')' ;;
            137) EVENT_EXITCODE='SIGKILL ('${EVENT_EXITCODE}')' ;;
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
Exit code: <b>'"`htmlEscape ${EVENT_EXITCODE}`"'</b>
'
        ;;
      health_status:*)
        EVENT_STATUS="${PARAMS[0]:15}"
        [[ "${EVENT_STATUS}" == ${FILTER_HEALTH} ]] || { echo "skipping ${CONTAINER_NAME} since EVENT_STATUS (${EVENT_STATUS}) not match filter ${FILTER_HEALTH}"; return; }
MESSAGE='
Status <b>'"`htmlEscape ${EVENT_STATUS^^}`"'</b>
'
        ;;
      *)
        echo 'Unknown event action "'"${PARAMS[1]}"\"
        return
        ;;
    esac
    [ -z "${MESSAGE}" ] && { echo "skipping ${CONTAINER_NAME} since MESSAGE is empty"; return; }

    [ -z "${STATE_ERROR}" ] || STATE_ERROR="State error: <b>`htmlEscape ${STATE_ERROR}`</b>\n"
    [ -z "${RESTART_COUNT}" ] || RESTART_COUNT="Restarts: <b>`htmlEscape ${RESTART_COUNT}`</b>\n"
    [ -z "${CONTAINER_NAME}" ] || CONTAINER_NAME="Name: <code>`htmlEscape ${CONTAINER_NAME}`</code>\n"
    [ -z "${CONTAINER_IMAGE}" ] || CONTAINER_IMAGE="Image: <code>`htmlEscape ${CONTAINER_IMAGE}`</code>\n"
    [ -z "${RESTART_POLICY}" ] || RESTART_POLICY="Restart policy: <b>`htmlEscape ${RESTART_POLICY}`</b>\n"

    telegram_message "${TITLE}\n${MESSAGE}${CONTAINER_NAME}${CONTAINER_IMAGE}${RESTART_POLICY}${RESTART_COUNT}${STATE_ERROR}\n<code>${EVENT_TIME}</code>"
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
printConfig

curl -s --no-buffer -XGET --unix-socket "${DOCKER_SOCKET}" "${URL}" |
while read message; do docker_event ${message}; done;
