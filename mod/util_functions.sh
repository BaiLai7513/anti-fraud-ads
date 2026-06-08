#!/system/bin/sh
# util_functions.sh (精简版 — 仅日志函数)

function Log_10007_dmesg() {
    local log_type="${2}"
    local text="${1}"
    local time="$(date +'%F %T')"
    case "${log_type}" in
        W|w|warning|Warning) log_type="[W]" ;;
        E|e|error|Error)     log_type="[E]" ;;
        I|i|info|Info)       log_type="[I]" ;;
        *)                   log_type="[?]" ;;
    esac
    test "$text" = "" && return
    echo "${log_type}${time} ${text}"
    echo "${log_type}${time} ${text}" >> /dev/kmsg
}
