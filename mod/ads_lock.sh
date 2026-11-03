#!/system/bin/sh
# 广告缓存锁定 + SQLite 空壳替换（可回滚版 v3）
#
# 设计约束：
#   1. 永不修改 /data/media、/storage/emulated、/sdcard 等共享存储路径。
#   2. 修改前把原目录/文件移动到 backup/payload（同一文件系统，O(1)），
#      或把 SQLite 复制到 backup/sqlite；并写入 backup/state.tsv。
#   3. 卸载时由 mod/rollback.sh 按记录恢复；手动回滚也可用同一脚本。
#   4. 任意路径失败只跳过当前路径，不中断整个脚本。
#   5. chattr 不可用时降级为 chmod，不视为致命错误。
#
# 仅测试用：AFADS_MODDIR / AFADS_DATA_ROOT 可覆盖模块与 /data 前缀。

MODDIR="${AFADS_MODDIR:-${0%/*}/..}"
LOG="$MODDIR/module.log"
DATA_ROOT="${AFADS_DATA_ROOT:-/data}"
CONFIG="$MODDIR/config.conf"
BACKUP_DIR="$MODDIR/backup"
STATE="$BACKUP_DIR/state.tsv"
PAYLOAD_DIR="$BACKUP_DIR/payload"
SQLITE_DIR="$BACKUP_DIR/sqlite"
AFADS_LOG_TAG=ads_lock

# ===== 配置 =====
AFADS_ADS_LOCK_ENABLED=1
AFADS_DRY_RUN=0
AFADS_MAX_DB_BACKUP_MB=64
if [ -f "$CONFIG" ]; then
    . "$CONFIG"
fi
case "$AFADS_MAX_DB_BACKUP_MB" in
    ''|*[!0-9]*) AFADS_MAX_DB_BACKUP_MB=64 ;;
esac

. "$MODDIR/mod/afads_common.sh" || {
    echo "[$(date)] ads_lock: FATAL: cannot source afads_common.sh" >> "$LOG"
    exit 1
}

# ===== 计数器 =====
locked=0
sqlite_locked=0
failed=0
tracked_skip=0
skipped_shared=0
skipped_unsafe=0
skipped_large=0
chattr_failed=0
backup_seq=0
TMPFILE="$MODDIR/.ads_scan.$$"
trap 'rm -f "$TMPFILE"' 0 1 2 15

log "started (dry_run=$AFADS_DRY_RUN root=$DATA_ROOT)"

if [ "$AFADS_ADS_LOCK_ENABLED" = "0" ]; then
    log "disabled by config (AFADS_ADS_LOCK_ENABLED=0)"
    exit 0
fi

# ===== 备份目录必须可写，否则任何修改都不能做 =====
if [ "$AFADS_DRY_RUN" != "1" ]; then
    mkdir -p "$BACKUP_DIR" "$PAYLOAD_DIR" "$SQLITE_DIR" 2>/dev/null
    if [ ! -d "$BACKUP_DIR" ] || [ ! -w "$BACKUP_DIR" ]; then
        log "FATAL: backup dir not writable: $BACKUP_DIR; abort"
        exit 1
    fi
    if [ ! -f "$STATE" ]; then
        : > "$STATE" 2>/dev/null || {
            log "FATAL: cannot create state file: $STATE; abort"
            exit 1
        }
    fi
fi

next_backup_rel() {
    backup_seq=$((backup_seq + 1))
    printf '%s/%s.%s.%s' "$1" "$(date +%s)" "$$" "$backup_seq"
}

# ===== 目录 =====
protect_dir() {
    local src path rc mode owner imm rel

    src="$1"
    path=$(resolve_safe_path "$src")
    rc=$?
    if [ "$rc" -eq 2 ]; then
        skipped_shared=$((skipped_shared + 1))
        return 0
    fi
    if [ "$rc" -ne 0 ]; then
        skipped_unsafe=$((skipped_unsafe + 1))
        log "SKIP unsafe path: $src"
        return 0
    fi
    if state_has_path "$path"; then
        tracked_skip=$((tracked_skip + 1))
        return 0
    fi
    if [ "$AFADS_DRY_RUN" = "1" ]; then
        log "DRY-RUN would lock dir: $path"
        return 0
    fi

    if [ -d "$path" ] && [ ! -L "$path" ]; then
        mode=$(get_mode "$path")
        owner=$(get_owner "$path")
        imm=$(get_immutable "$path")
        rel=$(next_backup_rel payload)
        if ! record dir_move "$path" "$mode" "$owner" "$imm" "$rel"; then
            log "FAIL write state: $path"
            failed=$((failed + 1))
            return 1
        fi
        clear_immutable "$path"
        if ! mv "$path" "$BACKUP_DIR/$rel" 2>/dev/null; then
            log "FAIL move dir to backup: $path"
            failed=$((failed + 1))
            return 1
        fi
        if ! mkdir "$path" 2>/dev/null; then
            log "FAIL create placeholder dir after move: $path"
            failed=$((failed + 1))
            return 1
        fi
    elif [ -e "$path" ] || [ -L "$path" ]; then
        # 类型不是目录（或为符号链接），交给文件路径处理
        protect_file "$path"
        return $?
    else
        if ! record dir_create "$path" "-" "-" "0" "-"; then
            log "FAIL write state: $path"
            failed=$((failed + 1))
            return 1
        fi
        if ! mkdir "$path" 2>/dev/null; then
            log "FAIL create placeholder dir: $path"
            failed=$((failed + 1))
            return 1
        fi
    fi

    chmod 000 "$path" 2>/dev/null
    set_immutable "$path"
    locked=$((locked + 1))
    log "LOCK dir: $path"
    return 0
}

# ===== 普通文件 =====
protect_file() {
    local src path rc mode owner imm rel

    src="$1"
    path=$(resolve_safe_path "$src")
    rc=$?
    if [ "$rc" -eq 2 ]; then
        skipped_shared=$((skipped_shared + 1))
        return 0
    fi
    if [ "$rc" -ne 0 ]; then
        skipped_unsafe=$((skipped_unsafe + 1))
        log "SKIP unsafe path: $src"
        return 0
    fi
    if state_has_path "$path"; then
        tracked_skip=$((tracked_skip + 1))
        return 0
    fi
    if [ ! -e "$path" ] && [ ! -L "$path" ]; then
        return 0
    fi
    if [ -L "$path" ]; then
        skipped_unsafe=$((skipped_unsafe + 1))
        log "SKIP symlink: $path"
        return 0
    fi
    if [ -d "$path" ]; then
        # 防御：目录不能按文件替换，否则会丢内容
        skipped_unsafe=$((skipped_unsafe + 1))
        log "SKIP unexpected directory in protect_file: $path"
        return 0
    fi
    if [ "$AFADS_DRY_RUN" = "1" ]; then
        log "DRY-RUN would lock file: $path"
        return 0
    fi

    mode=$(get_mode "$path")
    owner=$(get_owner "$path")
    imm=$(get_immutable "$path")
    rel=$(next_backup_rel payload)
    if ! record file_move "$path" "$mode" "$owner" "$imm" "$rel"; then
        log "FAIL write state: $path"
        failed=$((failed + 1))
        return 1
    fi
    clear_immutable "$path"
    if ! mv "$path" "$BACKUP_DIR/$rel" 2>/dev/null; then
        log "FAIL move file to backup: $path"
        failed=$((failed + 1))
        return 1
    fi
    if ! : > "$path" 2>/dev/null; then
        # 占位创建失败：尽量把原文件移回，避免数据留在备份里而原路径消失
        mv "$BACKUP_DIR/$rel" "$path" 2>/dev/null
        log "FAIL create placeholder file: $path"
        failed=$((failed + 1))
        return 1
    fi
    chmod 000 "$path" 2>/dev/null
    set_immutable "$path"
    locked=$((locked + 1))
    log "LOCK file: $path"
    return 0
}

protect_path() {
    if [ -d "$1" ] && [ ! -L "$1" ]; then
        protect_dir "$1"
    else
        protect_file "$1"
    fi
}

# ===== SQLite 数据库：复制备份后替换为空壳 =====
protect_sqlite() {
    local src path rc size max mode owner imm rel bsize

    src="$1"
    path=$(resolve_safe_path "$src")
    rc=$?
    if [ "$rc" -eq 2 ]; then
        skipped_shared=$((skipped_shared + 1))
        return 0
    fi
    if [ "$rc" -ne 0 ]; then
        skipped_unsafe=$((skipped_unsafe + 1))
        log "SKIP unsafe sqlite path: $src"
        return 0
    fi
    if state_has_path "$path"; then
        tracked_skip=$((tracked_skip + 1))
        return 0
    fi
    if [ -L "$path" ]; then
        skipped_unsafe=$((skipped_unsafe + 1))
        log "SKIP symlink sqlite: $path"
        return 0
    fi
    if [ ! -f "$path" ]; then
        return 0
    fi

    size=$(wc -c < "$path" 2>/dev/null | tr -d ' ')
    case "$size" in
        ''|*[!0-9]*) size=0 ;;
    esac
    max=$((AFADS_MAX_DB_BACKUP_MB * 1024 * 1024))
    if [ "$size" -gt "$max" ]; then
        skipped_large=$((skipped_large + 1))
        log "SKIP large sqlite (${size}B > ${max}B): $path"
        return 0
    fi
    if [ "$AFADS_DRY_RUN" = "1" ]; then
        log "DRY-RUN would replace sqlite (${size}B): $path"
        return 0
    fi

    mode=$(get_mode "$path")
    owner=$(get_owner "$path")
    imm=$(get_immutable "$path")
    rel=$(next_backup_rel sqlite)
    if ! cp -p "$path" "$BACKUP_DIR/$rel" 2>/dev/null; then
        log "FAIL backup sqlite: $path"
        failed=$((failed + 1))
        return 1
    fi
    bsize=$(wc -c < "$BACKUP_DIR/$rel" 2>/dev/null | tr -d ' ')
    if [ "$bsize" != "$size" ]; then
        log "FAIL sqlite backup size mismatch (${bsize}B != ${size}B): $path"
        rm -f "$BACKUP_DIR/$rel" 2>/dev/null
        failed=$((failed + 1))
        return 1
    fi
    if ! record sqlite_replace "$path" "$mode" "$owner" "$imm" "$rel"; then
        log "FAIL write state: $path"
        rm -f "$BACKUP_DIR/$rel" 2>/dev/null
        failed=$((failed + 1))
        return 1
    fi

    clear_immutable "$path"
    chmod u+w "$path" 2>/dev/null
    if ! : > "$path" 2>/dev/null; then
        log "FAIL truncate sqlite: $path"
        failed=$((failed + 1))
        return 1
    fi
    printf 'SQLite format 3\000' | dd of="$path" bs=1 count=16 conv=notrunc 2>/dev/null
    chmod 0444 "$path" 2>/dev/null
    set_immutable "$path"
    sqlite_locked=$((sqlite_locked + 1))
    log "LOCK sqlite: $path"
    return 0
}

# ===== 第一部分: 扫描应用私有目录中的广告 SDK 缓存目录 =====
# 只扫描 /data/data 与 /data/user；共享存储 /data/media 永不进入扫描范围。
log "scanning ad SDK cache dirs in private app data only..."

ad_cache_names="ads splashCache SplashPreload splash_image SplashData TMEAds"
ad_cache_names="$ad_cache_names qad_cache splash_ad_cache GDTDOWNLOAD app_adnet tad_cache"
ad_cache_names="$ad_cache_names app_ad TTCache cachett_ad tt_tmpl_pkg com_qq_e_download"
ad_cache_names="$ad_cache_names pangle_com.byted.pangle ksadsdk kwad_ex BeiZi"
ad_cache_names="$ad_cache_names applog AMPS crashsdk app_baidu_sdk_remote app_e_qq_com_*"
ad_cache_names="$ad_cache_names ks_union noah_ads anythink_internal_video_resource"
ad_cache_names="$ad_cache_names anythink_internal_resource xm_ad_img_cache douban_ad"

# 用位置参数组装 find 表达式，避免 eval；先关闭 pathname expansion，
# 防止 app_e_qq_com_* 在构建表达式时被当前目录的文件名替换。
set -f
set --
for name in $ad_cache_names; do
    if [ $# -eq 0 ]; then
        set -- -iname "$name"
    else
        set -- "$@" -o -iname "$name"
    fi
done
set +f

find "$DATA_ROOT/data" "$DATA_ROOT/user" -xdev \( "$@" \) -type d 2>/dev/null > "$TMPFILE"

while IFS= read -r ad_dir; do
    [ -z "$ad_dir" ] && continue
    protect_dir "$ad_dir" || true
done < "$TMPFILE"
rm -f "$TMPFILE"

log "scanned common SDK dirs (locked=$locked failed=$failed tracked=$tracked_skip shared_skipped=$skipped_shared)"

# ===== 第二部分: 各 app 私有目录中的专属广告文件 =====
# 注意：/data/media/*、/storage/emulated/* 下的路径已从执行清单中移除。
# 旧版本曾对这些共享存储路径执行 rm -rf / chmod 000 / chattr +i，
# 会破坏 MediaProvider / FUSE 的 emulated volume。

for user_dir in "$DATA_ROOT"/user/*; do
    [ -d "$user_dir" ] || continue

    # 豆瓣
    protect_path "$user_dir/com.douban.frodo/cache/douban_ad"

    # 驾考宝典
    protect_path "$user_dir/com.handsgo.jiakao.android/cache/GDTDOWNLOAD"

    # 百度地图
    protect_path "$user_dir/com.baidu.BaiduMap/files/AdvertData"

    # QQ浏览器
    protect_path "$user_dir/com.tencent.mtt/files/tad_cache"

    # QQ音乐
    protect_path "$user_dir/com.tencent.qqmusic/app_adnet"
    protect_path "$user_dir/com.tencent.qqmusic/files/tad_cache"

    # 高德地图
    protect_path "$user_dir/com.autonavi.minimap/files/splash"

    # 淘宝
    protect_path "$user_dir/com.taobao.taobao/files/bootimageresources"

    # bilibili
    protect_path "$user_dir/tv.danmaku.bili/files/res_cache"

    # 邮箱大师
    protect_path "$user_dir/com.netease.mail/cache/adcache1"
    protect_path "$user_dir/com.netease.mail/cache/adcache"

    # 美团
    protect_path "$user_dir/com.sankuai.meituan/files/cips/common/mtplatform_group/assets/startup"

    # 饿了么
    protect_path "$user_dir/me.ele/cache/splash"
    protect_path "$user_dir/me.ele/files/o2o_ad"

    # 百度网盘
    protect_path "$user_dir/com.baidu.netdisk/files/default_ad_caches"
    protect_path "$user_dir/com.baidu.netdisk/cache/wind"
    protect_path "$user_dir/com.baidu.netdisk/files/imgCache"
    protect_path "$user_dir/com.baidu.netdisk/files/splash_res_caches"
    protect_path "$user_dir/com.baidu.netdisk/files/video_front_ad_caches"
    protect_path "$user_dir/com.baidu.netdisk/files/splash"

    # 中国移动
    protect_path "$user_dir/com.greenpoint.android.mc10086.activity/cache/image_manager_disk_cache"

    # 飞猪旅行
    protect_path "$user_dir/com.taobao.trip/files/fliggy_splash"
done

log "app-specific private files locked"

# ===== 第三部分: SQLite 空壳替换（仅应用私有目录） =====
log "replacing ad SDK sqlite dbs in private app data..."

for user_dir in "$DATA_ROOT"/user/*; do
    [ -d "$user_dir" ] || continue

    # 123云盘
    for f in "$user_dir"/com.mfcloudcalculate.networkdisk/files/gdt_database/*.db; do
        [ -f "$f" ] || continue
        protect_sqlite "$f"
    done
    protect_sqlite "$user_dir/com.mfcloudcalculate.networkdisk/databases/amps_ad.db"
    protect_sqlite "$user_dir/com.mfcloudcalculate.networkdisk/databases/ksadrep.db"
    protect_sqlite "$user_dir/com.mfcloudcalculate.networkdisk/databases/ksadcache.db"

    # 有道词典
    for f in "$user_dir"/com.youdao.dict/databases/ad_sdk_database*; do
        [ -f "$f" ] || continue
        protect_sqlite "$f"
    done

    # 邮箱大师
    for f in "$user_dir"/com.netease.mail/databases/ad_sdk_database*; do
        [ -f "$f" ] || continue
        protect_sqlite "$f"
    done

    # 腾讯地图
    protect_sqlite "$user_dir/com.tencent.map/databases/splash.db"
done

log "sqlite shells created=$sqlite_locked"

# ===== 第四部分: 锁定穿山甲/BeiZi 日志数据库 =====
log "locking pangle/beizi log dbs..."

for user_dir in "$DATA_ROOT"/user/*; do
    [ -d "$user_dir" ] || continue

    for app_dir in "$user_dir"/*; do
        [ -d "$app_dir" ] || continue
        db_dir="$app_dir/databases"
        [ -d "$db_dir" ] || continue

        for db in beizi_ad pangle_com.byted.pangle_npth_log \
                   pangle_com.byted.pangle_ttopensdk \
                   pangle_com.byted.pangle_ttopensdk2 \
                   tt_mediation_open_sdk \
                   pangle_com.byted.pangle_tt_mediation_open_sdk; do
            protect_sqlite "$db_dir/${db}.db"
        done
    done
done

log "pangle/beizi log dbs locked"
log "finished: locked=$locked sqlite=$sqlite_locked failed=$failed already_tracked=$tracked_skip shared_skipped=$skipped_shared unsafe_skipped=$skipped_unsafe large_skipped=$skipped_large chattr_unsupported=$chattr_failed"
