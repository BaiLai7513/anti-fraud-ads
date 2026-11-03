#!/system/bin/sh
# anti_fraud_ads 公共函数（仅被 ads_lock.sh / rollback.sh source）
#
# 调用方必须先设置：
#   MODDIR      模块目录
#   DATA_ROOT   数据分区前缀（默认 /data；仅测试时可覆盖）
#   BACKUP_DIR  备份目录
#   STATE       修改记录文件
#   LOG         日志文件
#
# 安全约束：
#   - 只允许 /data/data/<pkg>/... 与 /data/user/<uid>/... 下的路径
#   - /data/media、/storage/emulated、/sdcard、/mnt/media_rw、/mnt/runtime
#     一律拒绝；即使配置写错也无法绕过
#   - 拒绝包含 ..、.、制表符、换行的路径
#   - 解析符号链接后再做一次白名单检查

TAB=$(printf '\t')
AFADS_LOG_TAG="${AFADS_LOG_TAG:-afads}"
chattr_failed="${chattr_failed:-0}"

log() {
    _msg="[$(date '+%F %T')] ${AFADS_LOG_TAG}: $*"
    echo "$_msg" >> "$LOG" 2>/dev/null || echo "$_msg"
}

# 返回 0: 合法；1: 非法；2: 共享存储（调用方只需跳过并计数）
# 合法时把规范化后的路径写到 stdout。
resolve_safe_path() {
    local _p _rp _parent _rp_parent
    _p="$1"
    [ -n "$_p" ] || return 1

    case "$_p" in
        *"$TAB"*) return 1 ;;
    esac
    case "$_p" in
        *'
'*) return 1 ;;
    esac
    case "/$_p/" in
        *"/../"*|*"/./"*) return 1 ;;
    esac

    case "$_p" in
        "$DATA_ROOT/media"|"$DATA_ROOT/media/"*|/storage|/storage/*|/sdcard|/sdcard/*|/mnt/media_rw|/mnt/media_rw/*|/mnt/runtime|/mnt/runtime/*)
            return 2 ;;
    esac

    case "$_p" in
        "$DATA_ROOT/data/"*|"$DATA_ROOT/user/"*) ;;
        *) return 1 ;;
    esac

    if [ -e "$_p" ] || [ -L "$_p" ]; then
        _rp=$(readlink -f "$_p" 2>/dev/null) || return 1
    else
        _parent=$(dirname "$_p")
        _rp_parent=$(readlink -f "$_parent" 2>/dev/null) || return 1
        _rp="$_rp_parent/$(basename "$_p")"
    fi
    [ -n "$_rp" ] || return 1

    case "$_rp" in
        "$DATA_ROOT/media"|"$DATA_ROOT/media/"*|/storage|/storage/*|/sdcard|/sdcard/*|/mnt/media_rw|/mnt/media_rw/*|/mnt/runtime|/mnt/runtime/*)
            return 2 ;;
    esac

    case "$_rp" in
        "$DATA_ROOT/data/"*|"$DATA_ROOT/user/"*) ;;
        *) return 1 ;;
    esac
    case "/$_rp/" in
        *"/../"*) return 1 ;;
    esac

    printf '%s\n' "$_rp"
    return 0
}

get_mode() {
    stat -c '%a' "$1" 2>/dev/null || printf '%s\n' '-'
}

get_owner() {
    stat -c '%u:%g' "$1" 2>/dev/null && return 0
    ls -ldn "$1" 2>/dev/null | awk '{print $3":"$4}'
}

get_immutable() {
    if command -v lsattr >/dev/null 2>&1; then
        _attr=$(lsattr -d "$1" 2>/dev/null | awk '{print $1}')
        case "$_attr" in
            *i*) printf '1\n'; return 0 ;;
        esac
    fi
    printf '0\n'
}

clear_immutable() {
    chattr -i "$1" 2>/dev/null
    return 0
}

set_immutable() {
    if chattr +i "$1" 2>/dev/null; then
        return 0
    fi
    chattr_failed=$((chattr_failed + 1))
    return 1
}

state_has_path() {
    [ -f "$STATE" ] || return 1
    cut -f2 "$STATE" 2>/dev/null | grep -Fxq -- "$1"
}

# op <TAB> path <TAB> mode <TAB> owner <TAB> immutable <TAB> backup
record() {
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$STATE"
}
