#!/system/bin/sh
# 回滚 ads_lock.sh 记录的全部修改
#
# 用法:
#   sh mod/rollback.sh             恢复并清除成功记录
#   sh mod/rollback.sh --dry-run   只列出将要恢复的条目，不修改文件
#
# 恢复规则：
#   - 只处理 state.tsv 中记录过的路径，不做全盘搜索
#   - 目标路径必须仍在应用私有数据目录内；共享存储路径一律拒绝
#   - 备份字段必须是 backup/ 下的相对路径
#   - 恢复失败的条目会保留在 state.tsv，便于人工处理

MODDIR="${AFADS_MODDIR:-${0%/*}/..}"
LOG="$MODDIR/module.log"
DATA_ROOT="${AFADS_DATA_ROOT:-/data}"
BACKUP_DIR="$MODDIR/backup"
STATE="$BACKUP_DIR/state.tsv"
PAYLOAD_DIR="$BACKUP_DIR/payload"
SQLITE_DIR="$BACKUP_DIR/sqlite"
AFADS_LOG_TAG=rollback

. "$MODDIR/mod/afads_common.sh" || {
    echo "[$(date)] rollback: FATAL: cannot source afads_common.sh" >> "$LOG"
    exit 1
}

note() {
    log "$*"
    echo "$*"
}

restore_one() {
    local op path mode owner imm backup rp bp

    op="$1"
    path="$2"
    mode="$3"
    owner="$4"
    imm="$5"
    backup="$6"

    rp=$(resolve_safe_path "$path")
    if [ $? -ne 0 ]; then
        note "FAIL unsafe state path, manual fix required: $path"
        return 1
    fi
    path="$rp"

    case "$backup" in
        -|'')
            bp=""
            ;;
        payload/*|sqlite/*)
            case "/$backup/" in
                *"/../"*|*"/./"*)
                    note "FAIL unsafe backup field: $backup"
                    return 1
                    ;;
            esac
            bp="$BACKUP_DIR/$backup"
            ;;
        *)
            note "FAIL invalid backup field: $backup"
            return 1
            ;;
    esac

    if [ "$DRY_RUN" = "1" ]; then
        note "DRY-RUN: $op $path (backup=${backup:--})"
        return 0
    fi

    clear_immutable "$path"
    if [ -d "$path" ] && [ ! -L "$path" ]; then
        chmod 700 "$path" 2>/dev/null
    elif [ -e "$path" ] || [ -L "$path" ]; then
        chmod 600 "$path" 2>/dev/null
    fi

    case "$op" in
        dir_create)
            if [ -d "$path" ] && [ ! -L "$path" ]; then
                if [ -z "$(ls -A "$path" 2>/dev/null)" ]; then
                    rmdir "$path" 2>/dev/null || {
                        note "FAIL rmdir placeholder: $path"
                        return 1
                    }
                else
                    note "WARN placeholder not empty, keep: $path"
                    return 1
                fi
            elif [ -e "$path" ] || [ -L "$path" ]; then
                note "WARN placeholder changed type, keep: $path"
                return 1
            fi
            ;;
        file_create)
            if [ -f "$path" ] && [ ! -s "$path" ]; then
                rm -f "$path" 2>/dev/null || {
                    note "FAIL remove placeholder file: $path"
                    return 1
                }
            elif [ -e "$path" ] || [ -L "$path" ]; then
                note "WARN placeholder not empty or changed type, keep: $path"
                return 1
            fi
            ;;
        dir_move|file_move)
            if [ -n "$bp" ] && { [ -e "$bp" ] || [ -L "$bp" ]; }; then
                if [ -d "$path" ] && [ ! -L "$path" ]; then
                    rmdir "$path" 2>/dev/null || {
                        note "FAIL placeholder dir not empty, manual merge required: $path"
                        return 1
                    }
                elif [ -e "$path" ] || [ -L "$path" ]; then
                    rm -f "$path" 2>/dev/null || {
                        note "FAIL remove placeholder: $path"
                        return 1
                    }
                fi
                if ! mv "$bp" "$path" 2>/dev/null; then
                    note "FAIL restore backup: $bp -> $path"
                    return 1
                fi
            elif [ -e "$path" ] || [ -L "$path" ]; then
                if [ -d "$path" ] && [ ! -L "$path" ] && [ -z "$(ls -A "$path" 2>/dev/null)" ]; then
                    note "FAIL backup missing, empty placeholder remains (manual): $path"
                    return 1
                fi
                if [ -f "$path" ] && [ ! -s "$path" ]; then
                    note "FAIL backup missing, empty placeholder remains (manual): $path"
                    return 1
                fi
                note "SKIP operation was not applied: $path"
            else
                note "FAIL backup missing and target absent: $path ($backup)"
                return 1
            fi
            ;;
        sqlite_replace)
            if [ -n "$bp" ] && [ -f "$bp" ]; then
                if [ -d "$path" ] && [ ! -L "$path" ]; then
                    note "FAIL target became a directory, keep backup: $path"
                    return 1
                fi
                rm -f "$path" 2>/dev/null
                if ! cp -p "$bp" "$path" 2>/dev/null; then
                    note "FAIL restore sqlite: $bp -> $path"
                    return 1
                fi
                rm -f "$bp" 2>/dev/null
            else
                note "FAIL sqlite backup missing: $path ($backup)"
                return 1
            fi
            ;;
        *)
            note "FAIL unknown op '$op' for $path"
            return 1
            ;;
    esac

    if [ "$mode" != "-" ] && [ -n "$mode" ]; then
        chmod "$mode" "$path" 2>/dev/null || note "WARN chmod $mode failed: $path"
    fi
    if [ "$owner" != "-" ] && [ -n "$owner" ]; then
        chown "$owner" "$path" 2>/dev/null || note "WARN chown $owner failed: $path"
    fi

    note "RESTORE ok: $op $path"
    return 0
}

restore_all() {
    local total rev keep ok failed op path mode owner imm backup

    if [ ! -f "$STATE" ]; then
        note "no state file, nothing to rollback"
        return 0
    fi
    if [ ! -s "$STATE" ]; then
        note "state is empty, nothing to rollback"
        return 0
    fi

    total=$(wc -l < "$STATE" 2>/dev/null | tr -d ' ')
    note "rollback started: total=$total entries"

    if [ "$DRY_RUN" = "1" ]; then
        note "DRY-RUN: no files will be modified"
    else
        cp "$STATE" "$STATE.before-rollback" 2>/dev/null
    fi

    rev="$STATE.rev.$$"
    keep="$STATE.keep.$$"
    if ! awk '{ lines[NR] = $0 } END { for (i = NR; i >= 1; i--) print lines[i] }' "$STATE" > "$rev" 2>/dev/null; then
        note "WARN: cannot reverse state with awk, restore in forward order"
        cp "$STATE" "$rev" 2>/dev/null || {
            note "FAIL cannot create temporary restore list: $rev"
            return 1
        }
    fi

    ok=0
    failed=0
    : > "$keep" 2>/dev/null
    while IFS="$TAB" read -r op path mode owner imm backup; do
        [ -n "$op" ] || continue
        if restore_one "$op" "$path" "$mode" "$owner" "$imm" "$backup"; then
            ok=$((ok + 1))
        else
            failed=$((failed + 1))
            if [ "$DRY_RUN" != "1" ]; then
                printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$op" "$path" "$mode" "$owner" "$imm" "$backup" >> "$keep"
            fi
        fi
    done < "$rev"
    rm -f "$rev"

    if [ "$DRY_RUN" = "1" ]; then
        note "DRY-RUN finished: would restore=$ok would_fail=$failed"
        rm -f "$keep"
        return 0
    fi

    if [ -s "$keep" ]; then
        mv "$keep" "$STATE" 2>/dev/null || note "FAIL cannot update state file: $STATE"
    else
        rm -f "$keep"
        : > "$STATE" 2>/dev/null
    fi

    rmdir "$PAYLOAD_DIR" "$SQLITE_DIR" 2>/dev/null
    note "rollback finished: ok=$ok failed=$failed remaining=$(wc -l < "$STATE" 2>/dev/null | tr -d ' ')"

    if [ "$failed" -gt 0 ]; then
        note "WARN: some entries could not be restored; they remain in $STATE"
        note "      backups are under $BACKUP_DIR; inspect state.tsv before deleting the module"
        return 1
    fi
    return 0
}

DRY_RUN=0
case "${1:-}" in
    --dry-run|-n)
        DRY_RUN=1
        ;;
    "")
        ;;
    *)
        echo "usage: sh $0 [--dry-run]" >&2
        exit 2
        ;;
esac

restore_all
exit $?
