#!/system/bin/sh
# 广告缓存锁定 + SQLite 空壳替换
# 从 10007 模块提取，移除 MIUI 专用部分
MODDIR="${0%/*}/.."
LOG="$MODDIR/module.log"

echo "[$(date)] ads_lock.sh: started" >> $LOG

# ===== 辅助函数 =====
# 锁定文件/目录: 删除→创建空文件→chmod 000→chattr +i
lock_file() {
    if [ -e "$1" ]; then
        rm -rf "$1" 2>/dev/null
        touch "$1" 2>/dev/null
        chmod 000 "$1" 2>/dev/null
        chattr +i "$1" 2>/dev/null
    fi
}

# 锁定目录: 删除→创建空目录→chmod 000→chattr +i
lock_dir() {
    if [ -d "$1" ]; then
        rm -rf "$1" 2>/dev/null
    fi
    if [ -e "$1" ]; then
        rm -rf "$1" 2>/dev/null
    fi
    mkdir -p "$1" 2>/dev/null
    chmod 000 "$1" 2>/dev/null
    chattr +i "$1" 2>/dev/null
}

# 创建空SQLite文件 (只保留文件头，让SDK无法写数据)
empty_sqlite() {
    if [ -e "$1" ]; then
        chattr -i "$1" 2>/dev/null
        rm -rf "$1" 2>/dev/null
    fi
    # SQLite format 3 空壳header
    printf 'SQLite format 3\000' | dd of="$1" bs=1 count=16 2>/dev/null
    chmod 0444 "$1" 2>/dev/null
    chattr +i "$1" 2>/dev/null
}

locked=0
failed=0

# ===== 第一部分: 扫描所有app的广告SDK缓存目录 =====
# 穿山甲(Pangle/GDT)、快手、Sigmob、BeiZi 等广告SDK的通用缓存目录名
echo "[$(date)] ads_lock: scanning ad SDK cache dirs..." >> $LOG

ad_cache_names="ads splashCache SplashPreload splash_image SplashData TMEAds"
ad_cache_names="$ad_cache_names qad_cache splash_ad_cache GDTDOWNLOAD app_adnet tad_cache"
ad_cache_names="$ad_cache_names app_ad TTCache cachett_ad tt_tmpl_pkg com_qq_e_download"
ad_cache_names="$ad_cache_names pangle_com.byted.pangle ksadsdk kwad_ex BeiZi"
ad_cache_names="$ad_cache_names applog AMPS crashsdk app_baidu_sdk_remote app_e_qq_com_*"
ad_cache_names="$ad_cache_names ks_union noah_ads anythink_internal_video_resource"
ad_cache_names="$ad_cache_names anythink_internal_resource xm_ad_img_cache douban_ad"

for name in $ad_cache_names; do
    find /data/user /data/data /data/media/*/Android/data \
        -iname "$name" -type d 2>/dev/null | while read ad_dir; do
        lock_dir "$ad_dir" && locked=$((locked + 1)) || failed=$((failed + 1))
    done
done

echo "[$(date)] ads_lock: scanned common SDK dirs (locked=$locked failed=$failed)" >> $LOG

# ===== 第二部分: 各app专属广告文件路径 =====
# (已移除 MIUI 条目: miad, com.miui.systemAdSolution)

# 使用 glob 匹配多用户路径
for user_dir in /data/user/*; do
    uid=$(basename "$user_dir")
    [ "$uid" = "0" ] && continue
    media_dir="/data/media/$uid"

    # 豆瓣
    lock_file "$user_dir/com.douban.frodo/cache/douban_ad"

    # 驾考宝典
    lock_file "$user_dir/com.handsgo.jiakao.android/cache/GDTDOWNLOAD"
    lock_dir "$media_dir/Android/data/com.handsgo.jiakao.android/cache/reward_video_cache_"*
    lock_file "$media_dir/Android/data/com.handsgo.jiakao.android/cache/splash_ad_cache"

    # 百度地图
    lock_file "$user_dir/com.baidu.BaiduMap/files/AdvertData"

    # 抖音
    lock_file "$media_dir/Android/data/com.ss.android.ugc.aweme/awemeSplashCache"
    lock_file "$media_dir/Android/data/com.ss.android.ugc.aweme/liveSplashCache"
    lock_file "$media_dir/Android/data/com.ss.android.ugc.aweme/splashCache"

    # QQ浏览器
    lock_file "$user_dir/com.tencent.mtt/files/tad_cache"

    # QQ音乐
    lock_file "$user_dir/com.tencent.qqmusic/app_adnet"
    lock_file "$user_dir/com.tencent.qqmusic/files/tad_cache"
    lock_file "$media_dir/qqmusic/splash"

    # 酷安
    lock_file "$media_dir/Android/data/com.coolapk.market/cachett_ad"
    lock_file "$media_dir/Android/data/com.coolapk.market/cache/splash_image"
    lock_file "$media_dir/Android/data/com.coolapk.market/cache/com_qq_e_download"
    lock_file "$media_dir/Android/data/com.coolapk.market/cache/pangle_com.byted.pangle"
    lock_file "$media_dir/Android/data/com.coolapk.market/cache/tt_tmpl_pkg"
    lock_file "$media_dir/Android/data/com.coolapk.market/files/TTCache"

    # keep
    lock_file "$media_dir/Android/data/com.gotokeep.keep/files/keep/ads"

    # 网易云
    lock_file "$media_dir/Android/data/com.netease.cloudmusic/cache/Ad"
    lock_file "$media_dir/netease/adcache"
    lock_file "$media_dir/netease/cloudmusic/Ad"

    # 今日头条
    lock_file "$media_dir/Android/data/com.ss.android.article.news/splashCache"

    # QQ
    lock_file "$media_dir/Tencent/MobileQQ/splahAD"
    lock_file "$media_dir/Android/data/com.tencent.mobileqq/MobileQQ/splahAD"
    lock_file "$media_dir/Android/data/com.tencent.mobileqq/Tencent/MobileQQ/vasSplashAD"

    # 高德地图
    lock_file "$media_dir/autonavi/afpSplash"
    lock_file "$media_dir/autonavi/splash"
    lock_file "$user_dir/com.autonavi.minimap/files/splash"

    # 酷狗音乐
    lock_file "$media_dir/kugou/.splash"
    lock_file "$media_dir/Android/data/com.kugou.android/files/kugou/.splash"

    # 微博
    lock_file "$media_dir/sina/weibo/.weibo_ad_universal_cache"
    lock_file "$media_dir/sina/weibo/.weibo_refreshad_cache"
    lock_file "$media_dir/sina/weibo/.weibo_video_cache_new"
    lock_file "$media_dir/sina/weibo/.weiboadcache"
    lock_file "$media_dir/sina/weibo/storage/biz_keep/.weibo_ad_universal_cache"
    lock_file "$media_dir/sina/weibo/storage/biz_keep/.weibo_refreshad_cache"

    # 淘宝
    lock_file "$media_dir/Android/data/com.taobao.taobao/files/acds"
    lock_file "$user_dir/com.taobao.taobao/files/bootimageresources"

    # 咪咕
    lock_file "$media_dir/Mob"

    # bilibili
    lock_file "$user_dir/tv.danmaku.bili/files/res_cache"

    # 有道词典
    lock_file "$media_dir/Android/data/com.youdao.dict/files/yd_sdk_path"

    # 邮箱大师
    lock_file "$user_dir/com.netease.mail/cache/adcache1"
    lock_file "$user_dir/com.netease.mail/cache/adcache"

    # 美团
    lock_file "$user_dir/com.sankuai.meituan/files/cips/common/mtplatform_group/assets/startup"

    # 饿了么
    lock_file "$user_dir/me.ele/cache/splash"
    lock_file "$user_dir/me.ele/files/o2o_ad"

    # 百度网盘
    lock_file "$user_dir/com.baidu.netdisk/files/default_ad_caches"
    lock_file "$user_dir/com.baidu.netdisk/cache/wind"
    lock_file "$user_dir/com.baidu.netdisk/files/imgCache"
    lock_file "$user_dir/com.baidu.netdisk/files/splash_res_caches"
    lock_file "$user_dir/com.baidu.netdisk/files/video_front_ad_caches"
    lock_file "$user_dir/com.baidu.netdisk/files/splash"

    # 中国移动
    lock_file "$user_dir/com.greenpoint.android.mc10086.activity/cache/image_manager_disk_cache"

    # 移动云盘
    lock_file "$media_dir/Android/data/com.chinamobile.mcloud/files/boot_logo"

    # 飞猪旅行
    lock_file "$user_dir/com.taobao.trip/files/fliggy_splash"

    # 携程旅行
    lock_file "$media_dir/Android/data/ctrip.android.view/cache/CTADCache"

    # 汽水音乐
    lock_file "$media_dir/com.luna.music/cache/image_commercial_cache"
    lock_file "$media_dir/com.luna.music/cache/pangle_com.byted.pangle"
    lock_file "$media_dir/com.luna.music/files/splashCache"
done

echo "[$(date)] ads_lock: app-specific files locked" >> $LOG

# ===== 第三部分: SQLite 空壳替换 =====
# 替换广告SDK的SQLite数据库为空壳，防止SDK写膨胀（穿山甲写了10GB日志！）

echo "[$(date)] ads_lock: replacing ad SDK sqlite dbs..." >> $LOG

sqlite_shell=0
for user_dir in /data/user/*; do
    # 123云盘
    for f in "$user_dir"/com.mfcloudcalculate.networkdisk/files/gdt_database/*.db; do
        [ -f "$f" ] && empty_sqlite "$f" && sqlite_shell=$((sqlite_shell + 1))
    done
    empty_sqlite "$user_dir/com.mfcloudcalculate.networkdisk/databases/amps_ad.db"
    empty_sqlite "$user_dir/com.mfcloudcalculate.networkdisk/databases/ksadrep.db"
    empty_sqlite "$user_dir/com.mfcloudcalculate.networkdisk/databases/ksadcache.db"

    # 有道词典
    for f in "$user_dir"/com.youdao.dict/databases/ad_sdk_database*; do
        [ -f "$f" ] && empty_sqlite "$f" && sqlite_shell=$((sqlite_shell + 1))
    done

    # 邮箱大师
    for f in "$user_dir"/com.netease.mail/databases/ad_sdk_database*; do
        [ -f "$f" ] && empty_sqlite "$f" && sqlite_shell=$((sqlite_shell + 1))
    done

    # 腾讯地图
    empty_sqlite "$user_dir/com.tencent.map/databases/splash.db"
done

echo "[$(date)] ads_lock: sqlite shells created=$sqlite_shell" >> $LOG

# ===== 第四部分: 锁定穿山甲/BeiZi 日志数据库 (防10GB膨胀) =====
echo "[$(date)] ads_lock: locking pangle/beizi log dbs..." >> $LOG

for user_dir in /data/user/*; do
    uid=$(basename "$user_dir")
    [ "$uid" = "0" ] && continue

    for app_dir in "$user_dir"/*; do
        [ -d "$app_dir" ] || continue
        db_dir="$app_dir/databases"

        # 穿山甲日志数据库
        for db in beizi_ad pangle_com.byted.pangle_npth_log \
                   pangle_com.byted.pangle_ttopensdk \
                   pangle_com.byted.pangle_ttopensdk2 \
                   tt_mediation_open_sdk \
                   pangle_com.byted.pangle_tt_mediation_open_sdk; do
            empty_sqlite "$db_dir/${db}.db" 2>/dev/null
        done
    done
done

echo "[$(date)] ads_lock: pangle/beizi log dbs locked" >> $LOG
echo "[$(date)] ads_lock.sh: finished" >> $LOG
