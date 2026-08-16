#!/system/bin/sh
# 文件清理/锁层 v1.0 — 清广告缓存 + 锁广告数据库 (移植自"去广告-特别版")
# 手段: 清空广告缓存目录并chattr锁死; 广告sqlite库替换为空壳锁死
# 注意: 通配符在调用处展开, 函数内不传通配符
MODDIR="${0%/*}/.."
LOG="$MODDIR/module.log"

lock_dir() {
    # 清空并锁死目录 (广告缓存目录)
    [ -d "$1" ] || return
    rm -f "$1"/* 2>/dev/null
    chmod 000 "$1" 2>/dev/null
    chattr +i "$1" 2>/dev/null
}

lock_file() {
    # 清空并锁死文件 (广告数据库)
    [ -f "$1" ] || return
    rm -f "$1" 2>/dev/null
    touch "$1" 2>/dev/null
    chmod 0000 "$1" 2>/dev/null
    chown root:root "$1" 2>/dev/null
    chattr +i "$1" 2>/dev/null
}

# --- 高德地图: 开屏/闪屏广告缓存 ---
for d in /data/media/*/autonavi/afpSplash /data/media/*/autonavi/splash /data/media/*/Android/data/com.autonavi.minimap/cache/ajxFileDownload /data/user/*/com.autonavi.minimap/files/splash; do
    [ -d "$d" ] && lock_dir "$d"
done

# --- 百度网盘: send_data 残留 ---
rm -f /data/user/*/com.baidu.netdisk/files/*_send_data* 2>/dev/null

# --- 酷安: 广告数据库清空+锁死 ---
for f in /data/user/*/com.coolapk.market/databases/beizi_ad.db \
         /data/user/*/com.coolapk.market/databases/ksadcache.db \
         /data/user/*/com.coolapk.market/databases/ksad_file_download.db \
         /data/user/*/com.coolapk.market/databases/jaddb.db \
         /data/user/*/com.coolapk.market/databases/ksadrep.db \
         /data/user/*/com.coolapk.market/databases/pangle*.db \
         /data/user/*/com.coolapk.market/databases/gdt_*.db \
         /data/user/*/com.coolapk.market/databases/anythink*.db \
         /data/user/*/com.coolapk.market/databases/*open_sdk.db; do
    [ -f "$f" ] && lock_file "$f"
done

# --- 酷安: 加固/上报残留 ---
rm -f /data/user/*/com.coolapk.market/files/com_baidu_*send_data* /data/user/*/com.coolapk.market/.jiagu 2>/dev/null

echo "[$(date)] file_clean: done (高德/百度网盘/酷安)" >> "$LOG"