#!/system/bin/sh
# appops 权限层 v1.0 — 限制广告商获取敏感权限 (移植自"去广告-特别版")
# 原则: 不deny核心功能权限(高德定位/网盘存储), 只deny广告采集相关
# 幂等: appops set 可重复执行, 开机自动运行
MODDIR="${0%/*}/.."
LOG="$MODDIR/module.log"

# 广告商常用敏感权限 (振动/日历/传感器/浮窗/音量/手机信息/定位监控)
OPS="VIBRATE WRITE_CALENDAR ACTIVITY_RECOGNITION BODY_SENSORS SYSTEM_ALERT_WINDOW TAKE_AUDIO_FOCUS AUDIO_MEDIA_VOLUME READ_PHONE_STATE MOCK_LOCATION MONITOR_HIGH_POWER_LOCATION MONITOR_LOCATION"

apply_appops() {
    local pkg="$1"
    pm list packages 2>/dev/null | grep -q "^package:$pkg$" || return
    for op in $OPS; do
        cmd appops set "$pkg" "$op" ignore 2>/dev/null
    done
    echo "[$(date)] appops: $pkg denied(${#OPS}项)" >> "$LOG"
}

# 百度网盘 (不deny存储/相机, 网盘核心功能)
apply_appops com.baidu.netdisk

# 京东 (不deny存储/相机)
apply_appops com.jingdong.app.mall

# 酷安 (deny后恢复TOAST_WINDOW, 保持通知弹窗正常)
apply_appops com.coolapk.market
cmd appops set com.coolapk.market TOAST_WINDOW allow 2>/dev/null

# 高德地图 (只deny非定位权限, 定位/导航核心保留)
pm list packages 2>/dev/null | grep -q "^package:com.autonavi.minimap$" || exit 0
for op in VIBRATE WRITE_CALENDAR ACTIVITY_RECOGNITION BODY_SENSORS SYSTEM_ALERT_WINDOW READ_PHONE_STATE; do
    cmd appops set com.autonavi.minimap "$op" ignore 2>/dev/null
done
echo "[$(date)] appops: com.autonavi.minimap denied(非定位权限)" >> "$LOG"